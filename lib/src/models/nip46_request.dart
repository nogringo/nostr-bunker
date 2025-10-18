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

  Nip46Request({
    required this.id,
    required this.command,
    required this.params,
    required this.appPubkey,
    required this.bunkerPubkey,
    required this.useNip44,
  });
}
