import 'dart:async';
import 'dart:convert';

import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:nostr_bunker/src/models/app.dart';
import 'package:nostr_bunker/src/models/bunker_url.dart';
import 'package:nostr_bunker/src/models/nip46_request.dart';
import 'package:nostr_bunker/src/models/nostr_connect_url.dart';
import 'package:nostr_bunker/src/models/permission.dart';
import 'package:nostr_bunker/src/utils/generate_secret.dart';
import 'package:nostr_bunker/src/utils/nip46_encryption.dart';
import 'package:nostr_bunker/src/utils/nip46_parser.dart';
import 'package:nostr_bunker/src/utils/no_event_verifier.dart';

class Bunker {
  late Ndk ndk;
  late List<App> apps = [];
  late List<String> defaultBunkerRelays = [];

  NdkResponse? signingRequestsSubscription;
  List<NdkResponse> bunkerUrlSubs = [];

  final _pendingRequestsController = StreamController<Nip46Request>();
  final _blockedRequestsController = StreamController<Nip46Request>();
  final _processedRequestsController = StreamController<Nip46Request>();

  /// Trigger on new unprocessed request
  Stream<Nip46Request> get pendingRequestsStream =>
      _pendingRequestsController.stream;

  /// Trigger on new blocked request
  Stream<Nip46Request> get blockedRequestsStream =>
      _blockedRequestsController.stream;

  /// Trigger on new processed request
  Stream<Nip46Request> get processedRequestsStream =>
      _processedRequestsController.stream;

  List<String> get privateKeys => ndk.accounts.accounts.values
      .where((account) => account.signer is Bip340EventSigner)
      .map((account) => (account.signer as Bip340EventSigner).privateKey!)
      .toList();

  bool get isStarted => signingRequestsSubscription != null;

  Bunker({
    List<String> privateKeys = const <String>[],
    List<App> apps = const <App>[],
    List<String> defaultBunkerRelays = const [
      "wss://relay.nsec.app",
      "wss://offchain.pub",
    ],
    Ndk? ndk,
  }) {
    this.apps.addAll(apps);
    this.defaultBunkerRelays.addAll(defaultBunkerRelays);

    this.ndk =
        ndk ??
        Ndk(
          NdkConfig(
            eventVerifier: NoEventVerifier(),
            cache: MemCacheManager(),
            bootstrapRelays: [...defaultBunkerRelays],
          ),
        );

    for (var pk in privateKeys) {
      addPrivateKey(pk);
    }
  }

  void allowForever({required String command, required App app}) {
    final matchingPermissions = app.getMatchingPermissions(command);

    if (matchingPermissions.isEmpty) {
      app.permissions.add(Permission(command: command));
    } else {
      matchingPermissions.map((perm) => perm.isAllowed = true);
    }
  }

  void rejectForever({required String command, required App app}) {
    final matchingPermissions = app.getMatchingPermissions(command);

    if (matchingPermissions.isEmpty) {
      app.permissions.add(Permission(command: command, isAllowed: false));
    } else {
      matchingPermissions.map((perm) => perm.isAllowed = false);
    }
  }

  void addPrivateKey(String privateKey) {
    final pubkey = Bip340.getPublicKey(privateKey);
    final signer = Bip340EventSigner(privateKey: privateKey, publicKey: pubkey);
    ndk.accounts.addAccount(
      pubkey: pubkey,
      type: AccountType.privateKey,
      signer: signer,
    );
  }

  void removePrivateKey(String pubkey) {
    ndk.accounts.removeAccount(pubkey: pubkey);
  }

  void removeApp(App app) {
    apps.removeWhere((e) => e.bunkerPubkey == app.bunkerPubkey);
  }

  void start() {
    _listenSigningRequests();
  }

  void stop() {
    _stopSigningRequestsSubscription();
  }

  void restart() {
    _listenSigningRequests();
  }

  Future<void> _listenSigningRequests() async {
    _stopSigningRequestsSubscription();

    // Get all unique relays from authorized apps
    final Set<String> allRelays = {};
    final Set<String> allPubkeys = {};
    for (final app in apps) {
      allRelays.addAll(app.relays);
      allPubkeys.add(app.bunkerPubkey);
      //! added to comply with bad nip46 implementation
      allPubkeys.add(app.userPubkey);
      //!
    }

    // Add default bunker relays as fallback
    allRelays.addAll(defaultBunkerRelays);

    signingRequestsSubscription = ndk.requests.subscription(
      filters: [
        Filter(kinds: [24133], pTags: allPubkeys.toList()),
      ],
      explicitRelays: allRelays.toList(),
    );

    signingRequestsSubscription!.stream.listen(_processIncomingRequestEvent);
  }

  Future<void> _stopSigningRequestsSubscription() async {
    if (signingRequestsSubscription == null) return;

    final subId = signingRequestsSubscription!.requestId;
    await ndk.requests.closeSubscription(subId);
    signingRequestsSubscription = null;
  }

  void _processIncomingRequestEvent(Nip01Event event) async {
    final nip46Request = await parseNip46Request(ndk: ndk, event: event);
    if (nip46Request == null) return;

    final app = getApp(nip46Request);
    if (app == null) return;

    final command = commandFromNip46Request(nip46Request);
    if (app.isCommandBlocked(command)) {
      _blockedRequestsController.sink.add(nip46Request);

      // TODO send an error

      return;
    }

    if (!app.canAutoProcess(command)) {
      _pendingRequestsController.sink.add(nip46Request);

      // TODO send an error
      // await _sendNip46Response(
      //   signer: signer,
      //   app: app,
      //   requestId: nip46Request.id,
      //   error: 'Permission denied for $commandString',
      // );

      return;
    }

    processRequest(nip46Request);
  }

  void processRequest(Nip46Request request) async {
    final app = getApp(request);
    if (app == null) return;

    final userSigner = _getSigner(ndk: ndk, pubkey: app.userPubkey);
    if (userSigner == null) return;
    final bunkerSigner = _getSigner(ndk: ndk, pubkey: request.bunkerPubkey);
    if (bunkerSigner == null) return;

    try {
      String? result;

      switch (request.command) {
        case Nip46Commands.connect:
          result = 'ack';
          break;

        case Nip46Commands.getPublicKey:
          result = userSigner.getPublicKey();
          break;

        case Nip46Commands.signEvent:
          if (request.params.isNotEmpty) {
            final eventData = jsonDecode(request.params[0]);
            final event = Nip01Event(
              pubKey: userSigner.getPublicKey(),
              kind: eventData['kind'] ?? 1,
              tags: List<List<String>>.from(
                (eventData['tags'] ?? []).map((tag) => List<String>.from(tag)),
              ),
              content: eventData['content'] ?? '',
              createdAt: eventData['created_at'],
            );
            await userSigner.sign(event);
            result = jsonEncode(event.toJson());
          }
          break;

        case Nip46Commands.ping:
          result = 'pong';
          break;

        case Nip46Commands.nip04Encrypt:
          if (request.params.length >= 2) {
            final pubkey = request.params[0];
            final plaintext = request.params[1];
            result = await userSigner.encrypt(plaintext, pubkey);
          }
          break;

        case Nip46Commands.nip04Decrypt:
          if (request.params.length >= 2) {
            final pubkey = request.params[0];
            final ciphertext = request.params[1];
            result = await userSigner.decrypt(ciphertext, pubkey);
          }
          break;

        case Nip46Commands.nip44Encrypt:
          if (request.params.length >= 2) {
            final pubkey = request.params[0];
            final plaintext = request.params[1];
            result = await userSigner.encryptNip44(
              plaintext: plaintext,
              recipientPubKey: pubkey,
            );
          }
          break;

        case Nip46Commands.nip44Decrypt:
          if (request.params.length >= 2) {
            final pubkey = request.params[0];
            final ciphertext = request.params[1];
            result = await userSigner.decryptNip44(
              ciphertext: ciphertext,
              senderPubKey: pubkey,
            );
          }
          break;
      }

      await _sendNip46Response(
        bunkerSigner: bunkerSigner,
        app: app,
        requestId: request.id,
        result: result,
      );

      _processedRequestsController.sink.add(request);
    } catch (e) {
      await _sendNip46Response(
        bunkerSigner: bunkerSigner,
        app: app,
        requestId: request.id,
        error: 'Error executing command: $e',
      );
    }
  }

  Future<void> _sendNip46Response({
    required EventSigner bunkerSigner,
    required App app,
    required String requestId,
    String? result,
    String? error,
  }) async {
    final response = {
      'id': requestId,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
    };

    final encryptedContent = await encryptNip46(
      bunkerSigner,
      jsonEncode(response),
      app.appPubkey,
      true, // Use NIP-44
    );

    if (encryptedContent == null) return;

    final responseEvent = Nip01Event(
      pubKey: bunkerSigner.getPublicKey(),
      kind: 24133,
      tags: [
        ["p", app.appPubkey],
      ],
      content: encryptedContent,
    );

    await bunkerSigner.sign(responseEvent);

    final broadcastRes = ndk.broadcast.broadcast(
      nostrEvent: responseEvent,
      specificRelays: app.relays,
    );
    await broadcastRes.broadcastDoneFuture;
  }

  Future<App> connectApp({
    required String userPubkey,
    required NostrConnectUrl nostrConnect,
    String? appName,
    AuthorisationMode appAuthorisationMode = AuthorisationMode.allwaysAsk,
    bool enableApp = false,
  }) async {
    if (!ndk.accounts.hasAccount(userPubkey)) {
      throw "No account found for this pubkey";
    }

    final signer = ndk.accounts.accounts[userPubkey]!.signer;

    final bunkerKeyPair = Bip340.generatePrivateKey();

    final bunkerSigner = Bip340EventSigner(
      privateKey: bunkerKeyPair.privateKey!,
      publicKey: bunkerKeyPair.publicKey,
    );
    ndk.accounts.addAccount(
      pubkey: bunkerSigner.publicKey,
      type: AccountType.privateKey,
      signer: bunkerSigner,
    );

    final app = App(
      appPubkey: nostrConnect.clientPubkey,
      bunkerPubkey: bunkerKeyPair.publicKey,
      userPubkey: userPubkey,
      relays: nostrConnect.relays,
      permissions: nostrConnect.permissions,
      name: appName ?? nostrConnect.name,
      authorisationMode: appAuthorisationMode,
      isEnabled: enableApp,
    );

    final connectEvent = Nip01Event(
      pubKey: bunkerSigner.getPublicKey(),
      kind: 24133,
      tags: [
        ["p", app.appPubkey],
      ],
      content: (await bunkerSigner.encryptNip44(
        plaintext: jsonEncode({
          "id": generateSecret(),
          "result": nostrConnect.secret,
        }),
        recipientPubKey: app.appPubkey,
      ))!,
    );

    bunkerSigner.sign(connectEvent);

    final broadcastRes = ndk.broadcast.broadcast(
      nostrEvent: connectEvent,
      specificRelays: app.relays,
    );
    await broadcastRes.broadcastDoneFuture;

    final sub = ndk.requests.subscription(
      filters: [
        Filter(
          kinds: [24133],
          authors: [app.appPubkey],
          pTags: [bunkerKeyPair.publicKey],
        ),
      ],
      explicitRelays: app.relays,
    );

    await for (var event in sub.stream) {
      final nip46Request = await parseNip46Request(ndk: ndk, event: event);
      if (nip46Request == null) continue;

      apps.add(app);
      _listenSigningRequests();

      await _sendNip46Response(
        bunkerSigner: bunkerSigner,
        app: app,
        requestId: nip46Request.id,
        result: signer.getPublicKey(),
      );
      break;
    }

    return app;
  }

  String getBunkerUrl({
    required String userPubkey,
    String? appName,
    AuthorisationMode appAuthorisationMode = AuthorisationMode.allwaysAsk,
    bool enableApp = false,
    void Function(App app)? onConnected,
  }) {
    if (!ndk.accounts.hasAccount(userPubkey)) {
      throw "No account found for this pubkey";
    }

    final bunkerKeyPair = Bip340.generatePrivateKey();

    final bunkerSigner = Bip340EventSigner(
      privateKey: bunkerKeyPair.privateKey!,
      publicKey: bunkerKeyPair.publicKey,
    );
    ndk.accounts.addAccount(
      pubkey: bunkerSigner.publicKey,
      type: AccountType.privateKey,
      signer: bunkerSigner,
    );

    final bunkerUrl = BunkerUrl(
      pubkey: bunkerKeyPair.publicKey,
      relays: defaultBunkerRelays,
    );

    final sub = ndk.requests.subscription(
      filters: [
        Filter(kinds: [24133], pTags: [bunkerKeyPair.publicKey]),
      ],
      explicitRelays: bunkerUrl.relays,
    );

    bunkerUrlSubs.add(sub);

    sub.stream.listen((event) async {
      final nip46Request = await parseNip46Request(ndk: ndk, event: event);

      if (nip46Request == null) return;
      if (nip46Request.command != Nip46Commands.connect) return;
      if (nip46Request.params[1] != bunkerUrl.secret) return;

      final app = App(
        appPubkey: nip46Request.appPubkey,
        bunkerPubkey: bunkerKeyPair.publicKey,
        userPubkey: userPubkey,
        name: appName,
        relays: bunkerUrl.relays,
        permissions: [
          Permission(command: "connect"),
          Permission(command: "get_public_key"),
          Permission(command: "ping"),
        ],
        authorisationMode: appAuthorisationMode,
        isEnabled: enableApp,
      );

      apps.add(app);
      _listenSigningRequests();

      await _sendNip46Response(
        bunkerSigner: bunkerSigner,
        app: app,
        requestId: nip46Request.id,
        result: 'ack',
      );

      ndk.requests.closeSubscription(sub.requestId);
      bunkerUrlSubs.removeWhere((e) => e.requestId == sub.requestId);

      if (onConnected != null) onConnected(app);
    });

    return bunkerUrl.url;
  }

  EventSigner? _getSigner({required Ndk ndk, required String pubkey}) {
    final account = ndk.accounts.accounts[pubkey];
    if (account == null) return null;
    return account.signer;
  }

  App? getApp(Nip46Request request) {
    //! For compatibility "app.bunkerPubkey == request.bunkerPubkey" was removed, it may be a security issue.
    return apps.where((app) => app.appPubkey == request.appPubkey).firstOrNull;
  }

  void dispose() {
    _pendingRequestsController.close();
    _blockedRequestsController.close();
    _processedRequestsController.close();
    _stopSigningRequestsSubscription();
  }
}
