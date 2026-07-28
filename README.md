With this package your app can act as a bunker and will be able to sign events from others Nostr apps.

## Usage

This package is stateless so you need to store the apps and the signers (private keys) yourself.

```dart
final bunker = Bunker(
    ndk: yourNdk,
    privateKeys: ["private_key"],
);

bunker.start();
bunker.stop();
bunker.restart();

// add and remove accounts
bunker.addPrivateKey("private_key");
bunker.removePrivateKey("public_key")

// connect an app with bunker://
final bunkerUrl = bunker.getBunkerUrl(signerPubkey: "public_key_to_connect");

// connect an app with nostrconnect://
final nostrConnect = NostrConnectUrl.fromUrl("nostrconnect://");
nostrConnect.name = "new_name"; // rename the app
nostrConnect.permissions.first.isAllowed = false; // remove a permission
bunker.connectApp(
    signerPubkey: "public_key_to_connect",
    nostrConnect: nostrConnect,
);

// listen to pending requests
bunker.pendingRequestsStream.listen((request) {
    // process them conditionaly
    if (request.useNip44) bunker.processRequest(request);
});

// store this
bunker.apps;
bunker.privateKeys;

bunker.dispose();
```

## Additional information

This package use [NDK](https://pub.dev/packages/ndk) internally, so you have to provide the `Ndk` instance yourself.

```dart
final bunker = Bunker(ndk: Ndk.defaultConfig());
```

In a Flutter app, use the platform aware verifier from [ndk_flutter](https://pub.dev/packages/ndk_flutter), it is much faster than `Bip340EventVerifier` on web.

```dart
final ndk = Ndk(
    NdkConfig(
        cache: MemCacheManager(),
        eventVerifier: NdkEventVerifier(),
    ),
);
final bunker = Bunker(ndk: ndk);
```
