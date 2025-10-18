With this package your app can act as a bunker and will be able to sign events from others Nostr apps.

## Usage

```dart
final bunker = Bunker();
bunker.addPrivateKey("private_key");
bunker.start();

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
```

## Additional information

This package use [NDK](https://pub.dev/packages/ndk) internally.

```dart
final yourGlobalNdk = Ndk.defaultConfig();
final bunker = Bunker(ndk: yourGlobalNdk);
```
