import 'package:nostr_bunker/src/config.dart';
import 'package:nostr_bunker/src/models/permission.dart';

/// [allwaysAsk] Every requests are queued
/// [allowCommonRequests] Common requests are automatically processed, others are queued
/// [fullyTrust] Every requests are automatically processed
enum AuthorisationMode { allwaysAsk, allowCommonRequests, fullyTrust }

class App {
  String appPubkey;
  String bunkerPubkey;
  String userPubkey;
  String? name;
  List<String> relays;
  List<Permission> permissions;
  AuthorisationMode authorisationMode;
  bool isEnabled;

  App({
    required this.appPubkey,
    required this.bunkerPubkey,
    required this.userPubkey,
    this.name,
    required this.relays,
    required this.permissions,
    this.authorisationMode = AuthorisationMode.allwaysAsk,
    this.isEnabled = false,
  });

  factory App.fromJson(Map<String, dynamic> json) {
    return App(
      appPubkey: json['appPubkey'],
      bunkerPubkey: json['bunkerPubkey'],
      userPubkey: json['userPubkey'],
      name: json['name'],
      relays: List<String>.from(json['relays']),
      permissions: (json['permissions'] as List)
          .map((permission) => Permission.fromJson(permission))
          .toList(),
      authorisationMode: AuthorisationMode.values.firstWhere(
        (e) => e.toString() == json['authorisationMode'],
      ),
      isEnabled: json['isEnabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appPubkey': appPubkey,
      'bunkerPubkey': bunkerPubkey,
      'userPubkey': userPubkey,
      'name': name,
      'relays': relays,
      'permissions': permissions
          .map((permission) => permission.toJson())
          .toList(),
      'authorisationMode': authorisationMode.toString(),
      'isEnabled': isEnabled,
    };
  }

  List<Permission> getMatchingPermissions(String command) {
    return permissions
        .where((permission) => permission.command == command)
        .toList();
  }

  bool isCommandBlocked(String command) {
    if (!isEnabled) return true;

    final matchingPermissions = getMatchingPermissions(command);
    if (matchingPermissions
        .where((permission) => !permission.isAllowed)
        .isNotEmpty) {
      return true;
    }

    return false;
  }

  bool canAutoProcess(String command) {
    if (!isEnabled) return false;
    if (authorisationMode == AuthorisationMode.fullyTrust) return true;

    final matchingPermissions = getMatchingPermissions(command);

    if (matchingPermissions
        .where((permission) => !permission.isAllowed)
        .isNotEmpty) {
      return false;
    }

    if (matchingPermissions
        .where((permission) => permission.isAllowed)
        .isNotEmpty) {
      return true;
    }

    if (authorisationMode == AuthorisationMode.allwaysAsk) return false;

    if (matchingPermissions.isEmpty) {
      if (authorisationMode == AuthorisationMode.allowCommonRequests) {
        if (commonCommands.contains(command)) return true;
      }
    }

    return false;
  }
}
