import 'package:nostr_bunker/src/utils/nip46_parser.dart';

enum Nip46Commands {
  connect,
  signEvent,
  ping,
  getPublicKey,
  nip04Encrypt,
  nip04Decrypt,
  nip44Encrypt,
  nip44Decrypt,
}

class Nip46Request {
  final String id;
  final Nip46Commands command;
  final List<String> params;
  final String appPubkey;
  final String bunkerPubkey;
  final bool useNip44;

  String get commandString => commandFromNip46Request(this);

  Nip46Request({
    required this.id,
    required this.command,
    required this.params,
    required this.appPubkey,
    required this.bunkerPubkey,
    required this.useNip44,
  });

  factory Nip46Request.fromJson(Map<String, dynamic> json) {
    return Nip46Request(
      id: json['id'],
      command: stringToNip46Command(json['command'])!,
      params: List<String>.from(json['params']),
      appPubkey: json['appPubkey'],
      bunkerPubkey: json['bunkerPubkey'],
      useNip44: json['useNip44'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'command': nip46CommandToString(command),
      'params': params,
      'appPubkey': appPubkey,
      'bunkerPubkey': bunkerPubkey,
      'useNip44': useNip44,
    };
  }
}
