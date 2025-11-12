import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'room_screen.dart';
import '../services/websocket_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _createUsernameController = TextEditingController();
  final _createRoomNameController = TextEditingController();
  final _joinUsernameController = TextEditingController();
  final _joinRoomIdController = TextEditingController();

  final _wsService = WebSocketService();
  bool _isJoining = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createUsernameController.dispose();
    _createRoomNameController.dispose();
    _joinUsernameController.dispose();
    _joinRoomIdController.dispose();
    super.dispose();
  }

  void _joinRoom() async {
    final username = _joinUsernameController.text.trim();
    if (username.isEmpty) {
      _showError('Please enter your name.');
      return;
    }

    final roomId = _joinRoomIdController.text.trim();
    if (roomId.isEmpty) {
      _showError('Please enter a room ID.');
      return;
    }

    setState(() => _isJoining = true);

    final connectionId = const Uuid().v4();
    final isConnected = await _wsService.connect(username, roomId, connectionId);

    if (!mounted) return;

    setState(() => _isJoining = false);

    if (isConnected) {
      _enterRoom(username, roomId, 'Public Room');
    } else {
      _showError('Failed to connect. Check the room ID and your connection.');
    }
  }

  void _createRoom() async {
    final username = _createUsernameController.text.trim();
    if (username.isEmpty) {
      _showError('Please enter your name.');
      return;
    }

    final roomName = _createRoomNameController.text.trim();
    if (roomName.isEmpty) {
      _showError('Please enter a room name.');
      return;
    }

    setState(() => _isCreating = true);

    final roomId = (100000 + Random().nextInt(900000)).toString();
    final connectionId = const Uuid().v4();
    final isConnected = await _wsService.connect(username, roomId, connectionId);

    if (!mounted) return;

    setState(() => _isCreating = false);

    if (isConnected) {
      _enterRoom(username, roomId, roomName);
    } else {
      _showError('Failed to create room. Please try again.');
    }
  }

  void _enterRoom(String username, String roomId, String roomName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RoomScreen(
          username: username,
          roomId: roomId,
          roomName: roomName,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Color.fromARGB((255 * 0.8).round(), 0xFF, 0x52, 0x52),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const _AuroraBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400), // Limit width for desktop/tablet
                child: _MainCard(
                  tabController: _tabController,
                  createUsernameController: _createUsernameController,
                  createRoomNameController: _createRoomNameController,
                  joinUsernameController: _joinUsernameController,
                  joinRoomIdController: _joinRoomIdController,
                  isCreating: _isCreating,
                  isJoining: _isJoining,
                  onCreate: _createRoom,
                  onJoin: _joinRoom,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1e3a8a), Color(0xff312e81), Color(0xff4c1d95)],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Stack(
          children: [
            _buildGradientCircle(const Color(0x663B82F6), const Alignment(0.8, -0.8)),
            _buildGradientCircle(const Color(0x4DA855F7), const Alignment(-0.8, 0.2)),
            _buildGradientCircle(const Color(0x59DB7093), const Alignment(0.9, 0.9)),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientCircle(Color color, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  final TabController tabController;
  final TextEditingController createUsernameController;
  final TextEditingController createRoomNameController;
  final TextEditingController joinUsernameController;
  final TextEditingController joinRoomIdController;
  final bool isCreating;
  final bool isJoining;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _MainCard({
    required this.tabController,
    required this.createUsernameController,
    required this.createRoomNameController,
    required this.joinUsernameController,
    required this.joinRoomIdController,
    required this.isCreating,
    required this.isJoining,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassmorphicContainer(
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'RoomHub',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect, create, and collaborate',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: Color.fromARGB((255 * 0.7).round(), 255, 255, 255)),
            ),
            const SizedBox(height: 24),
            _GlassmorphicContainer(
              borderRadius: 12,
              color: Color.fromARGB((255 * 0.1).round(), 255, 255, 255),
              child: TabBar(
                controller: tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Color.fromARGB((255 * 0.2).round(), 255, 255, 255),
                ),
                indicatorPadding: const EdgeInsets.all(4),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                unselectedLabelColor: Color.fromARGB((255 * 0.8).round(), 255, 255, 255),
                labelColor: Colors.white,
                tabs: const [
                  _Tab(icon: Icons.add, text: 'Create'),
                  _Tab(icon: Icons.login, text: 'Join'),
                  _Tab(icon: Icons.people_outline, text: 'Public'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 280, // Give TabBarView a fixed height
              child: TabBarView(
                controller: tabController,
                children: [
                  _buildCreateTab(),
                  _buildJoinTab(),
                  _buildPublicRoomsTab(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your privacy matters. All data is encrypted.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Color.fromARGB((255 * 0.5).round(), 255, 255, 255)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CustomTextField(controller: createUsernameController, label: 'Username', hintText: 'Enter your name'),
        const SizedBox(height: 16),
        _CustomTextField(controller: createRoomNameController, label: 'Room Name', hintText: 'Give your room a name'),
        const Spacer(),
        _ActionButton(label: 'Create Room', onTap: onCreate, isLoading: isCreating),
      ],
    );
  }

  Widget _buildJoinTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CustomTextField(controller: joinUsernameController, label: 'Username', hintText: 'Enter your name'),
        const SizedBox(height: 16),
        _CustomTextField(controller: joinRoomIdController, label: 'Room ID', hintText: 'Enter room ID'),
        const Spacer(),
        _ActionButton(label: 'Join Room', onTap: onJoin, isLoading: isJoining),
      ],
    );
  }

  Widget _buildPublicRoomsTab() {
    final publicRooms = [
      {'name': 'General Chat', 'members': 24},
      {'name': 'Gaming Zone', 'members': 18},
      {'name': 'Music Lovers', 'members': 32},
      {'name': 'Dev Community', 'members': 41},
    ];

    return ListView.separated(
      itemCount: publicRooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final room = publicRooms[index];
        return _PublicRoomTile(name: room['name'] as String, memberCount: room['members'] as int);
      },
    );
  }
}

class _GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? color;

  const _GlassmorphicContainer({required this.child, this.borderRadius = 16, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Color.fromARGB((255 * 0.08).round(), 255, 255, 255),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(width: 1, color: Color.fromARGB((255 * 0.2).round(), 255, 255, 255)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;

  const _CustomTextField({required this.controller, required this.label, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Color.fromARGB((255 * 0.7).round(), 255, 255, 255))),
        const SizedBox(height: 8),
        _GlassmorphicContainer(
          borderRadius: 12,
          color: Color.fromARGB((255 * 0.1).round(), 255, 255, 255),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: hintText,
              hintStyle: TextStyle(color: Color.fromARGB((255 * 0.4).round(), 255, 255, 255), fontWeight: FontWeight.w300),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: _GlassmorphicContainer(
            borderRadius: 12,
            color: Color.fromARGB((255 * 0.2).round(), 255, 255, 255),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicRoomTile extends StatelessWidget {
  final String name;
  final int memberCount;

  const _PublicRoomTile({required this.name, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    return _GlassmorphicContainer(
      borderRadius: 12,
      color: Color.fromARGB((255 * 0.1).round(), 255, 255, 255),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400)),
                const SizedBox(height: 2),
                Text('$memberCount members', style: TextStyle(fontSize: 12, color: Color.fromARGB((255 * 0.5).round(), 255, 255, 255))),
              ],
            ),
            Material(
              color: Color.fromARGB((255 * 0.2).round(), 255, 255, 255),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('Join', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tab({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}
