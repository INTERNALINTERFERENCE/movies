import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatWidget extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;

  const ChatWidget({
    super.key,
    required this.messages,
    required this.onSendMessage,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _messageController.clear();
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final message = widget.messages[index];
              return _ChatBubble(message: message);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: const Color(0xFF334155).withOpacity(0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF334155).withOpacity(0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Написать сообщение...',
                      hintStyle: TextStyle(
                        color: Color(0xFFCBD5E1),
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '→',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isOwn = message.isOwn;
    
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: isOwn
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.15),
                    const Color(0xFF6366F1).withOpacity(0.05),
                  ],
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(isOwn ? 10 : 4),
            bottomRight: Radius.circular(isOwn ? 4 : 10),
          ),
          border: isOwn
              ? null
              : Border(
                  left: BorderSide(
                    color: const Color(0xFF818CF8).withOpacity(0.5),
                    width: 2,
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.isOwn ? 'Я' : message.username,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isOwn
                    ? Colors.white.withOpacity(0.7)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13,
                color: isOwn ? Colors.white : const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

