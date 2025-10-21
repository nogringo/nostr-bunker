import 'dart:async';

import 'package:ndk/data_layer/repositories/signers/nip46_event_signer.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:nostr_bunker/src/models/app.dart';
import 'package:nostr_bunker/src/models/permission.dart';
import 'package:nostr_bunker/src/nostr_bunker_base.dart';
import 'package:test/test.dart';
import 'package:nostr_bunker/src/models/nostr_connect_url.dart';

void main() {
  test("Test nostr connect url", () async {
    final userKeyPair = Bip340.generatePrivateKey();

    final bunker = Bunker();
    bunker.addPrivateKey(userKeyPair.privateKey!);

    final ndkClient = Ndk.defaultConfig();

    final appName = "Test 123";

    final clientSideGeneratedNostrConnect = NostrConnect(
      relays: ["wss://relay.nsec.app", "wss://offchain.pub"],
      appName: appName,
    );

    Future<void> runBunker() async {
      final app = await bunker.connectApp(
        nostrConnect: NostrConnectUrl.fromUrl(
          clientSideGeneratedNostrConnect.nostrConnectURL,
        ),
        userPubkey: userKeyPair.publicKey,
      );

      expect(app.name!, equals(appName));
    }

    Future<void> runApp() async {
      await ndkClient.accounts.loginWithNostrConnect(
        nostrConnect: clientSideGeneratedNostrConnect,
        bunkers: ndkClient.bunkers,
      );

      expect(ndkClient.accounts.getPublicKey(), equals(userKeyPair.publicKey));
    }

    await Future.wait([runApp(), runBunker()]);
  });

  test("Test bunker url", () async {
    final userKeyPair = Bip340.generatePrivateKey();

    final bunker = Bunker(privateKeys: [userKeyPair.privateKey!]);

    final bunkerUrl = bunker.getBunkerUrl(userPubkey: userKeyPair.publicKey);

    final ndkClient = Ndk.defaultConfig();

    final connection = await ndkClient.bunkers.connectWithBunkerUrl(bunkerUrl);

    expect(connection, isNotNull);
  });

  test("Test bunker url 2", () async {
    final userKeyPair = Bip340.generatePrivateKey();

    final bunker = Bunker(privateKeys: [userKeyPair.privateKey!]);

    final bunkerUrl = bunker.getBunkerUrl(
      userPubkey: userKeyPair.publicKey,
      appAuthorisationMode: AuthorisationMode.fullyTrust,
      enableApp: true,
    );

    final ndkClient = Ndk.defaultConfig();

    await ndkClient.accounts.loginWithBunkerUrl(
      bunkerUrl: bunkerUrl,
      bunkers: ndkClient.bunkers,
    );

    expect(ndkClient.accounts.getPublicKey(), equals(userKeyPair.publicKey));
  });

  test("Test nostr connect url with asked permission", () async {
    final userKeyPair = Bip340.generatePrivateKey();

    final bunker = Bunker();
    bunker.addPrivateKey(userKeyPair.privateKey!);

    final ndkClient = Ndk.defaultConfig();

    final clientSideGeneratedNostrConnect = NostrConnect(
      relays: ["wss://relay.nsec.app", "wss://offchain.pub"],
      perms: ["nip44_encrypt", "nip44_decrypt"],
    );

    final recipientKeyPair = Bip340.generatePrivateKey();
    final recipientSigner = Bip340EventSigner(
      privateKey: recipientKeyPair.privateKey,
      publicKey: recipientKeyPair.publicKey,
    );

    Future<void> runBunker() async {
      final app = await bunker.connectApp(
        nostrConnect: NostrConnectUrl.fromUrl(
          clientSideGeneratedNostrConnect.nostrConnectURL,
        ),
        userPubkey: userKeyPair.publicKey,
      );
      app.isEnabled = true;
      app.authorisationMode = AuthorisationMode.fullyTrust;
      for (var req in bunker.blockedRequests) {
        bunker.processRequest(req);
      }
    }

    Future<void> runApp() async {
      await ndkClient.accounts.loginWithNostrConnect(
        nostrConnect: clientSideGeneratedNostrConnect,
        bunkers: ndkClient.bunkers,
      );

      final clearMessage = "Hello";

      final encryptedMessage = await recipientSigner.encryptNip44(
        plaintext: clearMessage,
        recipientPubKey: ndkClient.accounts.getPublicKey()!,
      );

      final decryptedMessage = await ndkClient.accounts
          .getLoggedAccount()!
          .signer
          .decryptNip44(
            ciphertext: encryptedMessage!,
            senderPubKey: recipientSigner.publicKey,
          );

      expect(decryptedMessage, equals(clearMessage));
    }

    await Future.wait([runApp(), runBunker()]);
  });

  test("Test nostr connect url without asked permission", () async {
    final userKeyPair = Bip340.generatePrivateKey();

    final bunker = Bunker();
    bunker.addPrivateKey(userKeyPair.privateKey!);

    final ndkClient = Ndk.defaultConfig();

    final clientSideGeneratedNostrConnect = NostrConnect(
      relays: ["wss://relay.nsec.app", "wss://offchain.pub"],
    );

    final recipientKeyPair = Bip340.generatePrivateKey();
    final recipientSigner = Bip340EventSigner(
      privateKey: recipientKeyPair.privateKey,
      publicKey: recipientKeyPair.publicKey,
    );

    Future<void> runBunker() async {
      await bunker.connectApp(
        nostrConnect: NostrConnectUrl.fromUrl(
          clientSideGeneratedNostrConnect.nostrConnectURL,
        ),
        userPubkey: userKeyPair.publicKey,
      );
    }

    Future<void> runApp() async {
      await ndkClient.accounts.loginWithNostrConnect(
        nostrConnect: clientSideGeneratedNostrConnect,
        bunkers: ndkClient.bunkers,
      );

      final clearMessage = "Hello";

      final encryptedMessage = await recipientSigner.encryptNip44(
        plaintext: clearMessage,
        recipientPubKey: ndkClient.accounts.getPublicKey()!,
      );

      final decryptedMessage = await ndkClient.accounts
          .getLoggedAccount()!
          .signer
          .decryptNip44(
            ciphertext: encryptedMessage!,
            senderPubKey: recipientSigner.publicKey,
          );

      expect(decryptedMessage, equals(clearMessage));
    }

    expect(
      () => Future.wait([
        runApp(),
        runBunker(),
      ]).timeout(const Duration(seconds: 5)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test("Test all bunker commands", () async {
    final userKeyPair = Bip340.generatePrivateKey();

    final bunker = Bunker();
    bunker.addPrivateKey(userKeyPair.privateKey!);

    final ndkClient = Ndk.defaultConfig();

    final clientSideGeneratedNostrConnect = NostrConnect(
      relays: ["wss://relay.nsec.app", "wss://offchain.pub"],
      perms: [
        "connect",
        "sign_event:1",
        "ping",
        "get_public_key",
        "nip04_encrypt",
        "nip04_decrypt",
        "nip44_encrypt",
        "nip44_decrypt",
      ],
    );

    final recipientKeyPair = Bip340.generatePrivateKey();
    final recipientSigner = Bip340EventSigner(
      privateKey: recipientKeyPair.privateKey,
      publicKey: recipientKeyPair.publicKey,
    );

    Future<void> runBunker() async {
      await bunker.connectApp(
        nostrConnect: NostrConnectUrl.fromUrl(
          clientSideGeneratedNostrConnect.nostrConnectURL,
        ),
        userPubkey: userKeyPair.publicKey,
        appAuthorisationMode: AuthorisationMode.fullyTrust,
        enableApp: true,
      );
    }

    Future<void> runApp() async {
      await ndkClient.accounts.loginWithNostrConnect(
        nostrConnect: clientSideGeneratedNostrConnect,
        bunkers: ndkClient.bunkers,
      );

      final clientSigner =
          ndkClient.accounts.getLoggedAccount()!.signer as Nip46EventSigner;

      // sign_event:1
      final nostrEvent = Nip01Event(
        pubKey: clientSigner.getPublicKey(),
        kind: 1,
        tags: [],
        content: "Hello",
      );
      expect(nostrEvent.sig, equals(""));
      await clientSigner.sign(nostrEvent);
      expect(nostrEvent.sig, isNotEmpty);

      // ping
      final pingRes = await clientSigner.ping();
      expect(pingRes, equals("pong"));

      // get_public_key
      final clientPubkey = await clientSigner.getPublicKeyAsync();
      expect(clientPubkey, equals(userKeyPair.publicKey));

      final clearMessage = "Hello";

      // nip04_encrypt
      final userEncryptedNip04Message = await clientSigner.encrypt(
        clearMessage,
        recipientSigner.getPublicKey(),
      );
      final recipientDecryptedNip04Message = await recipientSigner.decrypt(
        userEncryptedNip04Message!,
        clientSigner.getPublicKey(),
      );
      expect(recipientDecryptedNip04Message, equals(clearMessage));

      // nip04_decrypt
      final encryptedNip04Message = await recipientSigner.encrypt(
        clearMessage,
        ndkClient.accounts.getPublicKey()!,
      );
      final decryptedNip04Message = await clientSigner.decrypt(
        encryptedNip04Message!,
        recipientSigner.publicKey,
      );
      expect(decryptedNip04Message, equals(clearMessage));

      // nip44_encrypt
      final userEncryptedNip44Message = await clientSigner.encryptNip44(
        plaintext: clearMessage,
        recipientPubKey: recipientSigner.getPublicKey(),
      );
      final recipientDecryptedNip44Message = await recipientSigner.decryptNip44(
        ciphertext: userEncryptedNip44Message!,
        senderPubKey: clientSigner.getPublicKey(),
      );
      expect(recipientDecryptedNip44Message, equals(clearMessage));

      // nip44_decrypt
      final encryptedNip44Message = await recipientSigner.encryptNip44(
        plaintext: clearMessage,
        recipientPubKey: ndkClient.accounts.getPublicKey()!,
      );
      final decryptedNip44Message = await clientSigner.decryptNip44(
        ciphertext: encryptedNip44Message!,
        senderPubKey: recipientSigner.publicKey,
      );
      expect(decryptedNip44Message, equals(clearMessage));
    }

    await Future.wait([runApp(), runBunker()]);
  });

  test("Test with apps", () async {
    final userKeyPair = Bip340.generatePrivateKey();
    final bunkerKeyPair = Bip340.generatePrivateKey();
    final appKeyPair = Bip340.generatePrivateKey();

    final app = App(
      appPubkey: appKeyPair.publicKey,
      bunkerPubkey: bunkerKeyPair.publicKey,
      userPubkey: userKeyPair.publicKey,
      relays: ["wss://relay.nsec.app", "wss://offchain.pub"],
      permissions: [
        Permission(command: "connect"),
        Permission(command: "sign_event:1"),
        Permission(command: "ping"),
        Permission(command: "get_public_key"),
        Permission(command: "nip04_encrypt"),
        Permission(command: "nip04_decrypt"),
        Permission(command: "nip44_encrypt"),
        Permission(command: "nip44_decrypt"),
      ],
      authorisationMode: AuthorisationMode.fullyTrust,
      isEnabled: true,
    );

    final bunker = Bunker(
      apps: [app],
      privateKeys: [userKeyPair.privateKey!, bunkerKeyPair.privateKey!],
    );

    bunker.start();

    final ndkClient = Ndk.defaultConfig();

    await ndkClient.accounts.loginWithBunkerConnection(
      connection: BunkerConnection(
        privateKey: appKeyPair.privateKey!,
        remotePubkey: bunkerKeyPair.publicKey,
        relays: app.relays,
      ),
      bunkers: ndkClient.bunkers,
    );

    final clientSigner =
        ndkClient.accounts.getLoggedAccount()!.signer as Nip46EventSigner;

    final pingRes = await clientSigner.ping();
    expect(pingRes, equals("pong"));
  });
}
