import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'room_screen.dart';
import '../services/websocket_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String _mode = 'join'; // 'join' or 'create'
  final _usernameController = TextEditingController();
  final _roomIdController = TextEditingController();
  final _roomNameController = TextEditingController();

  final _wsService = WebSocketService();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _roomIdController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  void _switchMode(String mode) {
    setState(() {
      _mode = mode;
    });
  }

  void _submit() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showError('Введите ваше имя.');
      return;
    }

    final String roomId;
    final String roomName;

    if (_mode == 'join') {
      roomId = _roomIdController.text.trim();
      roomName = ''; // Not needed for joining
      if (roomId.isEmpty) {
        _showError('Введите ID комнаты.');
        return;
      }
    } else {
      roomName = _roomNameController.text.trim();
      // Generate a 6-digit room ID
      final random = Random();
      roomId = (100000 + random.nextInt(900000)).toString();
      
      if (roomName.isEmpty) {
        _showError('Введите название комнаты.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final connectionId = const Uuid().v4();
    final isConnected = await _wsService.connect(username, roomId, connectionId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (isConnected) {
      _enterRoom(username, roomId, roomName);
    } else {
      _showError('Не удалось подключиться к серверу. Проверьте ID комнаты и ваше соединение.');
    }
  }

  void _enterRoom(String username, String roomId, String roomName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RoomScreen(
          username: username,
          roomId: roomId,
          roomName: roomName.isEmpty ? 'Untitled Room' : roomName,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Viewsync',
                style: TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Watch movies together, in real time',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              // Mode toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'Join Room',
                        isActive: _mode == 'join',
                        onTap: () => _switchMode('join'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ModeButton(
                        label: 'Create Room',
                        isActive: _mode == 'create',
                        onTap: () => _switchMode('create'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Username field
              _TextField(
                label: 'USERNAME',
                controller: _usernameController,
                placeholder: 'Enter your name',
              ),
              const SizedBox(height: 12),
              // Conditional fields
              if (_mode == 'join')
                _TextField(
                  label: 'ROOM ID',
                  controller: _roomIdController,
                  placeholder: 'Enter room code',
                )
              else
                _TextField(
                  label: 'ROOM NAME',
                  controller: _roomNameController,
                  placeholder: 'Enter room name',
                ),
              const SizedBox(height: 12),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_mode == 'join' ? 'Join Room' : 'Create Room'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF004E55) : const Color(0xFF666666),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;

  const _TextField({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: Color(0xFF444444),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: const Color(0xFFE9F0F0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD0D8DA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD0D8DA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF004E55), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

