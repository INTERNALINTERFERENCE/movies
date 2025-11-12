import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../services/websocket_service.dart';
import '../models/chat_message.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/participants_list.dart';
import '../widgets/chat_widget.dart';

class RoomScreen extends StatefulWidget {
  final String username;
  final String roomId;
  final String roomName;

  const RoomScreen({
    super.key,
    required this.username,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with SingleTickerProviderStateMixin {
  late WebSocketService _wsService;
  
  List<String> _participants = [];
  List<ChatMessage> _chatMessages = [];
  
  VideoPlayerWidgetState? _videoPlayerState;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _tabController = TabController(length: 2, vsync: this);
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    _wsService.onUserListUpdate = (usernames) {
      setState(() {
        _participants = usernames;
      });
    };

    _wsService.onChatMessage = (username, text, isOwn) {
      setState(() {
        _chatMessages.add(ChatMessage(
          username: username,
          text: text,
          isOwn: isOwn,
        ));
      });
    };

    _wsService.onVideoAction = (action, time) {
      if (_videoPlayerState != null) {
        switch (action) {
          case 'play':
            _videoPlayerState!.handlePlay();
            break;
          case 'pause':
            _videoPlayerState!.handlePause();
            break;
          case 'seek':
            if (time != null) {
              _videoPlayerState!.handleSeek(time);
            }
            break;
        }
      }
    };
  }

  void _onVideoAction(String action, double? time) {
    _wsService.sendVideoAction(action, time);
  }

  void _onSendChatMessage(String text) {
    _wsService.sendChatMessage(text);
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildRoomInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎬 ${widget.roomName}',
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.roomId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ID комнаты скопирован!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ID: ${widget.roomId}',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy, color: Color(0xFFCBD5E1), size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEC4899), Color(0xFFD9145D)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection({bool isPortrait = false}) {
    if (isPortrait) {
      // Video with natural aspect ratio for portrait mode
      return Stack(
        children: [
          // Background blur area at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Video player offset by 2cm from top
          Padding(
            padding: const EdgeInsets.only(top: 50), // 2 cm offset from top
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 16 / 9, // Standard video aspect ratio
                child: VideoPlayerWidget(
                  videoUrl:
                      'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                  onVideoAction: _onVideoAction,
                  onStateCreated: (state) {
                    _videoPlayerState = state;
                  },
                  isPortrait: false, // Use contain fit to show full video
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Landscape mode with padding
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Video player
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.1),
                      const Color(0xFFEC4899).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF334155).withOpacity(0.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: VideoPlayerWidget(
                    videoUrl:
                        'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                    onVideoAction: _onVideoAction,
                    onStateCreated: (state) {
                      _videoPlayerState = state;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildRoomInfo(),
          ],
        ),
      );
    }
  }

  Widget _buildSidebar() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Participants panel
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF334155).withOpacity(0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF334155).withOpacity(0.5),
                          ),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1).withOpacity(0.05),
                            const Color(0xFFEC4899).withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            '👥 УЧАСТНИКИ',
                            style: TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ParticipantsList(participants: _participants),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Chat panel
            Expanded(
              flex: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF334155).withOpacity(0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF334155).withOpacity(0.5),
                          ),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1).withOpacity(0.05),
                            const Color(0xFFEC4899).withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            '💬 ЧАТ',
                            style: TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ChatWidget(
                        messages: _chatMessages,
                        onSendMessage: _onSendChatMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Video player at the top
        _buildVideoSection(isPortrait: true),
        // Room info below video
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF334155).withOpacity(0.3),
              ),
            ),
          ),
          child: _buildRoomInfo(),
        ),
        // Tabs with chat and participants
        Expanded(
          child: Container(
            color: const Color(0xFF0F172A),
            child: Column(
              children: [
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF334155).withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFEC4899),
                    indicatorWeight: 3,
                    labelColor: const Color(0xFFF1F5F9),
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.chat_bubble_outline, size: 20),
                        text: 'Чат',
                      ),
                      Tab(
                        icon: Icon(Icons.people_outline, size: 20),
                        text: 'Участники',
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Chat tab
                      ChatWidget(
                        messages: _chatMessages,
                        onSendMessage: _onSendChatMessage,
                      ),
                      // Participants tab
                      ParticipantsList(participants: _participants),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Main player section
        Expanded(
          child: _buildVideoSection(isPortrait: false),
        ),
        // Sidebar
        _buildSidebar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: isPortrait 
        ? _buildPortraitLayout() 
        : SafeArea(
            child: _buildLandscapeLayout(),
          ),
    );
  }
}

