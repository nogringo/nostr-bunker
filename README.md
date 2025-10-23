With this package your app can act as a bunker and will be able to sign events from others Nostr apps.

## Usage

This package is stateless so you need to store the apps and the signers (private keys) yourself.

```dart
final bunker = Bunker(privateKeys: ["private_key"]);

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

This package use [NDK](https://pub.dev/packages/ndk) internally.

```dart
final yourGlobalNdk = Ndk.defaultConfig();
final bunker = Bunker(ndk: yourGlobalNdk);
```
