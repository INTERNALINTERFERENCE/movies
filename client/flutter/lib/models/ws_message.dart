class WSMessage {
  final String type;
  final String? connectionId;
  final String? username;
  final String? roomId;
  final String? text;
  final String? action;
  final double? time;
  final Map<String, dynamic>? payload;

  WSMessage({
    required this.type,
    this.connectionId,
    this.username,
    this.roomId,
    this.text,
    this.action,
    this.time,
    this.payload,
  });

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    return WSMessage(
      type: json['type'] as String,
      connectionId: json['connectionId'] as String?,
      username: json['username'] as String?,
      roomId: json['roomId'] as String?,
      text: json['text'] as String?,
      action: json['action'] as String?,
      time: json['time'] != null ? (json['time'] as num).toDouble() : null,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (connectionId != null) map['connectionId'] = connectionId;
    if (username != null) map['username'] = username;
    if (roomId != null) map['roomId'] = roomId;
    if (text != null) map['text'] = text;
    if (action != null) map['action'] = action;
    if (time != null) map['time'] = time;
    if (payload != null) map['payload'] = payload;
    return map;
  }
}

