import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import '../../services/player/chat/message_service.dart';
import '../../services/player/chat/chat_model.dart';
import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '/ui/theme.dart';
import '../player/player_profile_page.dart';

class Chat extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const Chat({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final _controller = TextEditingController();
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadMyProfileImage();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _markMessagesAsRead(); // 👈 تأكيد تعليم الرسائل كمقروءة عند مغادرة الشاشة
    _controller.dispose();
    super.dispose();
  }

  /// 🔹 تحميل صورة المستخدم الحالية
  Future<void> _loadMyProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Player')
          .doc(user.uid)
          .get();
      if (snap.exists) {
        setState(() {
          profileImageUrl = snap.data()?['ProfilePhoto'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
    }
  }

  /// 🔹 تعليم الرسائل غير المقروءة كـ "read"
  Future<void> _markMessagesAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chatRef = FirebaseFirestore.instance
        .collection('PlayerChat')
        .doc(widget.chatId)
        .collection('PlayerMessage');

    final snapshot = await chatRef
        .where('ReceiverID', isEqualTo: user.uid)
        .where('status', isEqualTo: 'sent')
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }

    await batch.commit();
    debugPrint('✅ All player messages marked as READ for ${widget.chatId}');
  }

  /// 🔹 التعامل مع الصور سواء Base64 أو URL
  ImageProvider? _getImage(String? img) {
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return NetworkImage(img);
    try {
      return MemoryImage(base64Decode(img));
    } catch (e) {
      debugPrint('⚠️ Error decoding base64 image: $e');
      return null;
    }
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    final senderImage = isMe ? profileImageUrl : widget.otherUserImage;

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey[700],
      backgroundImage: _getImage(senderImage),
      child: (senderImage == null || senderImage.isEmpty)
          ? const Icon(Icons.person, color: Colors.white70)
          : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? "You" : widget.otherUserName,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[avatar, const SizedBox(width: 8)],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 250),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.accent.withOpacity(0.9)
                            : AppColors.cardDeep.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg.contact,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isMe)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.done_all,
                            size: 16,
                            color: msg.status == 'read'
                                ? Colors.blueAccent
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            msg.status == 'read' ? 'Read' : 'Sent',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (isMe) ...[const SizedBox(width: 8), avatar],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return BgScaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.otherUserName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            _markMessagesAsRead();
            Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerProfilePage()),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[700],
                backgroundImage: _getImage(profileImageUrl),
                child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 8),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<Message>>(
                      stream: MessageService.getMessagesByChatId(widget.chatId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white70),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text('No messages yet... start chatting 👋',
                                style: TextStyle(color: Colors.white70)),
                          );
                        }

                        final messages = snapshot.data!;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final msg = messages[i];
                            final isMe = msg.senderId == widget.currentUserId;
                            return _buildMessageBubble(msg, isMe);
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardDeep.withOpacity(0.9),
                      borderRadius:
                          const BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle:
                                  TextStyle(color: Colors.white70, fontSize: 14),
                              border: InputBorder.none,
                            ),
                            onTap: _markMessagesAsRead,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: () async {
                            final text = _controller.text.trim();
                            if (text.isEmpty) return;
                            await MessageService.sendMessageByChatId(
                              widget.chatId,
                              currentUser!.uid,
                              widget.otherUserId,
                              text,
                            );
                            _controller.clear();
                            await _markMessagesAsRead(); // 👈 بعد الإرسال
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: kToolbarHeight + 20,
            left: 0,
            child: MiniSideNav(top: kToolbarHeight + 20, left: 0),
          ),
        ],
      ),
    );
  }
}