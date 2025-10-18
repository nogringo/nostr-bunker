class Permission {
  String command;
  bool isAllowed;

  Permission({required this.command, this.isAllowed = true});

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(command: json['command'], isAllowed: json['isAllowed']);
  }

  Map<String, dynamic> toJson() {
    return {'command': command, 'isAllowed': isAllowed};
  }
}
