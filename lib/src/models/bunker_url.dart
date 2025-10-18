import 'package:nostr_bunker/src/utils/generate_secret.dart';

class BunkerUrl {
  final String pubkey;
  final List<String> relays;
  final String secret;

  String get url {
    final params = <String>[];

    for (final relay in relays) {
      params.add('relay=$relay');
    }

    params.add('secret=$secret');

    final queryString = params.join('&');
    return 'bunker://$pubkey?$queryString';
  }

  BunkerUrl({required this.pubkey, required this.relays, String? secret})
    : secret = secret ?? generateSecret();
}
