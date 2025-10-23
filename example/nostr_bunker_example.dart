import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:nostr_bunker/nostr_bunker.dart';

void main() async {
  final userKeyPair = Bip340.generatePrivateKey();
  final bunker = Bunker(privateKeys: [userKeyPair.privateKey!]);

  final bunkerUrl = bunker.getBunkerUrl(userPubkey: userKeyPair.publicKey);

  final ndkClient = Ndk.defaultConfig();

  final connection = await ndkClient.bunkers.connectWithBunkerUrl(bunkerUrl);

  print("Connected: ${connection != null}");
}
