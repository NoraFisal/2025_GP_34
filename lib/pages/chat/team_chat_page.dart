import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '/ui/theme.dart';
import '/pages/player/player_profile_view_page.dart';
import '/pages/team/edit_team_page.dart'; // ✅ لزر إعدادات الفريق

class TeamChatPage extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamChatPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamChatPage> createState() => _TeamChatPageState();
}

class _TeamChatPageState extends State<TeamChatPage> {
  final _controller = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _markTeamMessagesAsRead();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final teamRef =
          FirebaseFirestore.instance.collection('Team').doc(widget.teamId);
      final membersSnap = await teamRef.collection('Members').get();

      List<Map<String, dynamic>> members = [];
      for (var doc in membersSnap.docs) {
        final userId = doc.id;
        final playerDoc =
            await FirebaseFirestore.instance.collection('Player').doc(userId).get();
        if (!playerDoc.exists) continue;
        final data = playerDoc.data()!;
        members.add({
          'uid': userId,
          'name': data['Name'] ?? '',
          'photo': data['ProfilePhoto'] ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _teamMembers = members;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading team members: $e');
    }
  }

  @override
  void dispose() {
    _markTeamMessagesAsRead();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markTeamMessagesAsRead() async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final chatRef = FirebaseFirestore.instance
        .collection('TeamChat')
        .doc(widget.teamId)
        .collection('TeamMessage');

    final snapshot = await chatRef.get();
    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (!readBy.contains(uid)) {
        readBy.add(uid);
        batch.update(doc.reference, {'readBy': readBy});
      }
    }
    await batch.commit();
  }

  Future<void> _respondToInvitation(bool accepted) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final teamRef = FirebaseFirestore.instance.collection('Team').doc(widget.teamId);
    final memberRef = teamRef.collection('Members').doc(uid);
    final chatRef = FirebaseFirestore.instance.collection('TeamChat').doc(widget.teamId);

    final memberSnap = await memberRef.get();
    final memberData = memberSnap.data() as Map<String, dynamic>? ?? {};
    final existingResponse = (memberData['response'] ?? '').toString();
    if (existingResponse == 'Accepted' || existingResponse == 'Rejected') {
      _showSnackBar('تم تسجيل ردك مسبقاً: $existingResponse');
      return;
    }

    final newResponse = accepted ? 'Accepted' : 'Rejected';
    await memberRef.update({'response': newResponse});

    String playerName = 'Player';
    try {
      final playerDoc = await FirebaseFirestore.instance.collection('Player').doc(uid).get();
      final pData = playerDoc.data() as Map<String, dynamic>? ?? {};
      playerName = (pData['Name'] ?? 'Player').toString();
    } catch (_) {}

    await chatRef.collection('TeamMessage').add({
      'senderId': 'system',
      'contact': accepted
          ? '✅ $playerName accepted the team invitation.'
          : '❌ $playerName rejected the team invitation.',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
      'readBy': [uid],
    });

    _showSnackBar(accepted ? '✅ You accepted the invitation.' : '❌ You rejected the invitation.');

    final membersSnap = await teamRef.collection('Members').get();
    final membersData = membersSnap.docs.map((d) => d.data()).toList();

    final allAccepted =
        membersData.isNotEmpty && membersData.every((m) => m['response'] == 'Accepted');
    final anyRejected = membersData.any((m) => m['response'] == 'Rejected');

    if (anyRejected) {
      await teamRef.update({
        'status': 'Rejected',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      await chatRef.update({'status': 'rejected'});

      await chatRef.collection('TeamMessage').add({
        'senderId': 'system',
        'contact': '❌ One of the players rejected the team invitation. Chat closed.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'readBy': [uid],
      });
    } else if (allAccepted) {
      await teamRef.update({
        'status': 'Accepted',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      await chatRef.update({'status': 'active'});

      await chatRef.collection('TeamMessage').add({
        'senderId': 'system',
        'contact': '🎉 All players accepted! The team chat is now active.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'readBy': [uid],
      });
    }
  }

void _handleBackNavigation() async {
  await _markTeamMessagesAsRead();

  if (!mounted) return;

  // ✅ نعيد البناء نظيفًا حتى الهوم بيج فقط
  Navigator.pushNamedAndRemoveUntil(context, '/homepage', (route) => false);

  // ✅ تأخير بسيط لتجنب الوميض (نستخدم Future.microtask بدل delay)
  Future.microtask(() {
    if (!mounted) return;
    Navigator.pushNamed(context, '/playerProfile');
  });

  Future.microtask(() {
    if (!mounted) return;
    Navigator.pushNamed(context, '/chatList');
  });
}

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final chatRef =
        FirebaseFirestore.instance.collection('TeamChat').doc(widget.teamId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;

    final status = chatDoc['status'] ?? 'pending';
    if (status != 'active') {
      _showSnackBar('⚠ Chat is locked until all members accept.');
      return;
    }

    await chatRef.collection('TeamMessage').add({
      'senderId': currentUser!.uid,
      'contact': text,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [currentUser!.uid],
      'type': 'text',
    });

    await chatRef.update({
      'lastMessage': text,
      'lastTime': FieldValue.serverTimestamp(),
    });

    _controller.clear();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

/// ✅ رسالة الدعوة بشكل أنيق وواضح بدون إيموجي كثيرة
  Widget _buildInvitationMessage(String text) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Team')
          .doc(widget.teamId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final teamData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final createdBy = teamData['createdBy'];
        final isCreator = currentUser?.uid == createdBy;
        final winRate = (teamData['winRate'] ?? 0).toDouble();
        final currentUid = currentUser?.uid;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Team')
              .doc(widget.teamId)
              .collection('Members')
              .snapshots(),
          builder: (context, memberSnap) {
            if (!memberSnap.hasData) return const SizedBox();
            final members = memberSnap.data!.docs;

            // معرفة رد اللاعب الحالي إن وجد
            String myResponse = '';
            if (currentUid != null) {
              final meDoc = members.cast<QueryDocumentSnapshot>().firstWhere(
                    (m) => m.id == currentUid,
                    orElse: () => null as QueryDocumentSnapshot<Object?>,
                  );
              if (meDoc != null) {
                final meData = meDoc.data() as Map<String, dynamic>;
                myResponse = (meData['response'] ?? '').toString();
              }
            }
            final hasResponded =
                myResponse == 'Accepted' || myResponse == 'Rejected';

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDeep.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👇 عرض معلومات المنشئ
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('Player')
                        .doc(createdBy)
                        .get(),
                    builder: (context, creatorSnap) {
                      final creatorData =
                          creatorSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final creatorName = creatorData['Name'] ?? 'Unknown';
                      return Text(
                        'Team created by: $creatorName (auto accepted)',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // نص الدعوة الأصلي
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Current Win Rate: ${winRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 10),

                  const Text(
                    'Team Members:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 👇 أسماء الأعضاء بدون إيموجي
                  ...members.map((m) {
                    final data = m.data() as Map<String, dynamic>;
                    final role = data['role'] ?? '';
                    final userId = m.id;
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('Player')
                          .doc(userId)
                          .get(),
                      builder: (context, snap) {
                        final pdata =
                            snap.data?.data() as Map<String, dynamic>? ?? {};
                        final name = pdata['Name'] ?? 'Player';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• $role - $name',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        );
                      },
                    );
                  }),

                  const SizedBox(height: 15),

                  // 👇 حالة اللاعب الحالي
                  if (isCreator)
                    const Text(
                      'You are the team creator — waiting for others to respond.',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                      ),
                    )
                  else if (hasResponded)
                    Text(
                      myResponse == 'Accepted'
                          ? 'You have accepted the invitation. Waiting for others to respond.'
                          : 'You have rejected the invitation.',
                      style: TextStyle(
                        color: myResponse == 'Accepted'
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 13,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => _respondToInvitation(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => _respondToInvitation(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msgData, bool isMe) {
    final type = msgData['type'] ?? '';
    final text = msgData['contact'] ?? '';
    final senderId = msgData['senderId'] ?? '';

    if (type == 'invitation') return _buildInvitationMessage(text);

    if (type == 'system') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('Player').doc(senderId).get(),
      builder: (context, snapshot) {
        final userData =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final senderName = isMe ? 'You' : userData['Name'] ?? 'Unknown';
        final senderImage = userData['ProfilePhoto'] ?? '';

        ImageProvider? avatarImg;
        if (senderImage.toString().startsWith('http')) {
          avatarImg = NetworkImage(senderImage);
        } else if (senderImage.isNotEmpty) {
          try {
            avatarImg = MemoryImage(base64Decode(senderImage));
          } catch (e) {
            debugPrint('⚠️ Error decoding base64 image');
          }
        }

        final avatar = CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[700],
          backgroundImage: avatarImg,
          child: avatarImg == null
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
                senderName,
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 250),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.accent.withOpacity(0.9)
                            : AppColors.cardDeep.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  if (isMe) ...[const SizedBox(width: 8), avatar],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ تم تعديل صف الأفاتارات ليكون في المنتصف
  Widget _buildTeamAvatarsRow() {
    if (_teamMembers.isEmpty) return const SizedBox(height: 60);

    return SizedBox(
      height: 80,
      child: Center(
        child: ListView.separated(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: _teamMembers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final m = _teamMembers[i];
            ImageProvider? avatar;
            final p = m['photo'] ?? '';
            if (p.toString().startsWith('http')) {
              avatar = NetworkImage(p);
            } else if (p.isNotEmpty) {
              try {
                avatar = MemoryImage(base64Decode(p));
              } catch (_) {}
            }

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewPlayerProfilePage(userId: m['uid']),
                  ),
                );
              },
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white24,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? const Icon(Icons.person,
                            color: Colors.white70, size: 25)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    child: Text(
                      m['name'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('TeamChat')
          .doc(widget.teamId)
          .snapshots(),
      builder: (context, chatSnap) {
        final chatStatus = chatSnap.data?['status'] ?? 'pending';
        final isLocked = chatStatus != 'active';

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: BgScaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Column(
                children: [
                  Text(widget.teamName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  Text('(${chatStatus.toUpperCase()})',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: _handleBackNavigation,
              ),
              // ✅ زر إعدادات الفريق للانتقال إلى EditTeamPage
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditTeamPage(teamId: widget.teamId),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: kToolbarHeight + 8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        _buildTeamAvatarsRow(),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('TeamChat')
                                .doc(widget.teamId)
                                .collection('TeamMessage')
                                .orderBy('timestamp')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final messages = snapshot.data!.docs;
                              if (messages.isEmpty) {
                                return const Center(
                                    child: Text('No messages yet',
                                        style:
                                            TextStyle(color: Colors.white70)));
                              }

                              bool invitationShown = false;
                              return ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                itemCount: messages.length,
                                itemBuilder: (context, i) {
                                  final msg =
                                      messages[i].data() as Map<String, dynamic>;
                                  if (msg['type'] == 'invitation') {
                                    if (invitationShown) {
                                      return const SizedBox.shrink();
                                    }
                                    invitationShown = true;
                                  }
                                  final isMe = msg['senderId'] == uid;
                                  return _buildMessageBubble(msg, isMe);
                                },
                              );
                            },
                          ),
                        ),
                        if (!isLocked) _chatInputBox(),
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.black26,
                            alignment: Alignment.center,
                            child: const Text(
                              '🕓 Chat locked until all members respond.',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                    top: kToolbarHeight + 20,
                    left: 0,
                    child: MiniSideNav(top: kToolbarHeight + 20, left: 0)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chatInputBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDeep.withOpacity(0.9),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white70),
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onTap: _markTeamMessagesAsRead,
            ),
          ),
          IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage),
        ],
      ),
    );
  }
}