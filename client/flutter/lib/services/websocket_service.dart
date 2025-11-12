import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ws_message.dart';
import '../models/message_types.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  static const String wsUrl = 'wss://bentlee-gloomful-unvividly.ngrok-free.dev/stream';
  WebSocketChannel? _channel;
  String? _connectionId;
  String? _roomId;
  String? _username;

  Function(List<String>)? onUserListUpdate;
  Function(String, String, bool)? onChatMessage;
  Function(String, double?)? onVideoAction;

  Future<bool> connect(String username, String roomId, String connectionId) async {
    try {
      _username = username;
      _roomId = roomId;
      _connectionId = connectionId;

      print('Attempting to connect to $wsUrl...');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            final wsMessage = WSMessage.fromJson(data);
            _handleMessage(wsMessage);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
        },
      );

      print('Channel created. Waiting for connection to be ready...');
      await _channel!.ready.timeout(const Duration(seconds: 10));
      print('Connection ready!');

      _sendInit(username, roomId, connectionId);
      print('Init message sent.');
      return true;
    } on TimeoutException catch (e) {
      print('Connection timed out after 10 seconds: $e');
      _channel?.sink.close();
      _channel = null;
      return false;
    } catch (e) {
      print('Failed to connect to WebSocket with error: $e');
      _channel?.sink.close();
      _channel = null;
      return false;
    }
  }

  void _sendInit(String username, String roomId, String connectionId) {
    final message = WSMessage(
      type: MessageTypes.init,
      connectionId: connectionId,
      username: username,
      roomId: roomId,
    );
    send(message);
  }

  void _handleMessage(WSMessage message) {
    final isOwn = message.connectionId == _connectionId;

    switch (message.type) {
      case MessageTypes.userListUpdate:
        if (message.payload != null && message.payload!['usernames'] != null) {
          final usernames = (message.payload!['usernames'] as List)
              .map((e) => e.toString())
              .toList();
          onUserListUpdate?.call(usernames);
        }
        break;

      case MessageTypes.chatMessage:
        if (message.username != null && message.text != null) {
          onChatMessage?.call(message.username!, message.text!, isOwn);
        }
        break;

      case MessageTypes.videoAction:
        if (!isOwn && message.action != null) {
          onVideoAction?.call(message.action!, message.time);
        }
        break;
    }
  }

  void send(WSMessage message) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(message.toJson()));
    }
  }

  void sendChatMessage(String text) {
    final message = WSMessage(
      type: MessageTypes.chatMessage,
      connectionId: _connectionId,
      text: text,
    );
    send(message);
  }

  void sendVideoAction(String action, [double? time]) {
    final message = WSMessage(
      type: MessageTypes.videoAction,
      connectionId: _connectionId,
      action: action,
      time: time,
    );
    send(message);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}

