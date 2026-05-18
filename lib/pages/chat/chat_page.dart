import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/chat/unified_chat_service.dart';
import '../team/team_details_page.dart';
import '../organizer/organizer_profile_view_page.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:gal/gal.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  const ChatPage({super.key, required this.chatId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _scrollCtrl = ScrollController();

  
  final List<_OptimisticMessage> _optimisticMessages = [];

  Uint8List? _pendingBytes;
  String? _pendingFileName;

  
  final Map<String, Map<String, String>> _localProfileCache = {};

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _chip = Color(0xFFF0F3F4);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  void initState() {
    super.initState();
    
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      UnifiedChatService.markChatAsRead(widget.chatId, uid);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Uint8List? _decodeBase64Image(String s) {
    try {
      final cleaned = s.contains(',') ? s.split(',').last : s;
      return base64.decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  ImageProvider? _getImageProvider(String photo) {
    if (photo.isEmpty) return null;
    if (photo.startsWith('http')) return NetworkImage(photo);
    final bytes = _decodeBase64Image(photo);
    if (bytes != null) return MemoryImage(bytes);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('Chat').doc(widget.chatId).snapshots(),
      builder: (context, chatSnap) {
        if (!chatSnap.hasData) {
          return Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(backgroundColor: _bg, elevation: 0),
            body: Center(child: CircularProgressIndicator(color: _accent)),
          );
        }

        final chatData = chatSnap.data!.data() as Map<String, dynamic>? ?? {};
        final chatType = chatData['type'] ?? '';
        final teamId = chatData['teamId'] ?? '';
        final participants =
            List<String>.from(chatData['participants'] ?? []);
        final otherUid = chatType == 'private'
            ? participants.firstWhere((id) => id != uid, orElse: () => '')
            : '';

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF363435),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: _buildAppBarTitle(
              chatType: chatType,
              teamId: teamId,
              otherUid: otherUid,
              chatId: widget.chatId,
              uid: uid,
            ),
          ),
          body: Column(
            children: [
              Expanded(child: _buildMessageList(uid, participants, chatType)),
              _buildMessageInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBarTitle({
    required String chatType,
    required String teamId,
    required String otherUid,
    required String chatId,
    required String uid,
  }) {
    if (chatType == 'team' && teamId.isNotEmpty) {
      return StreamBuilder<Map<String, String>>(
        stream: UnifiedChatService.listenTeamInfo(teamId),
        builder: (context, teamSnap) {
          final teamName = teamSnap.data?['name'] ?? 'Team';
          final teamLogo = teamSnap.data?['logo'] ?? '';
          final photoProvider = _getImageProvider(teamLogo);

          return StreamBuilder<List<String>>(
            stream: UnifiedChatService.listenChatMemberNames(chatId, uid),
            builder: (context, namesSnap) {
              final memberNames = namesSnap.data ?? [];

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamDetailsPage(
                      teamId: teamId,
                      teamName: teamName,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _accent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFEFEFEF),
                        backgroundImage: photoProvider,
                        child: photoProvider == null
                            ? Icon(Icons.group, color: _muted, size: 18)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            teamName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: _text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (memberNames.isNotEmpty)
                            Text(
                              memberNames.join(', '),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } else if (chatType == 'private' && otherUid.isNotEmpty) {
      return StreamBuilder<Map<String, String>>(
        stream: UnifiedChatService.listenUserProfile(otherUid),
        builder: (context, profileSnap) {
          final name = profileSnap.data?['name'] ?? 'User';
          final photo = profileSnap.data?['photo'] ?? '';
          final photoProvider = _getImageProvider(photo);

          final isOrg = (profileSnap.data?['role'] ?? 'player') == 'organizer';

          return GestureDetector(
            onTap: () {
              if (isOrg) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewOrganizerProfilePage(
                      organizerId: otherUid,
                    ),
                  ),
                );
              } else {
                Navigator.pushNamed(
                  context,
                  '/player-profile',
                  arguments: otherUid,
                );
              }
            },
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFEFEF),
                    backgroundImage: photoProvider,
                    child: photoProvider == null
                        ? Icon(Icons.person, color: _muted, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return const Text(
      'Chat',
      style: TextStyle(
        fontFamily: 'Inter',
        color: _text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildMessageList(
      String uid, List<String> participants, String chatType) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('Chat')
          .doc(widget.chatId)
          .collection('message')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator(color: _accent));
        }

        final firestoreMessages = snap.data!.docs;

        
        for (final doc in firestoreMessages) {
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'] ?? '';
          if (senderId.isNotEmpty && !_localProfileCache.containsKey(senderId)) {
            // Seed from service-level cache (no network call).
            final cached = UnifiedChatService.profileCache[senderId];
            if (cached != null && !cached.isExpired) {
              _localProfileCache[senderId] = cached.data;
            }
          }
        }

        
        final confirmedTexts =
            firestoreMessages.map((d) => (d.data() as Map)['text'] ?? '').toSet();
        _optimisticMessages.removeWhere((m) => confirmedTexts.contains(m.text));

        if (firestoreMessages.isEmpty && _optimisticMessages.isEmpty) {
          return Center(
            child: Text(
              "No messages yet.",
              style: TextStyle(
                fontFamily: 'Inter',
                color: _muted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

       
        final reversedMessages = firestoreMessages.reversed.toList();
        final totalCount = reversedMessages.length + _optimisticMessages.length;

        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: const EdgeInsets.all(10),
          itemCount: totalCount,
          itemBuilder: (context, i) {
            
            if (i < _optimisticMessages.length) {
              final opt = _optimisticMessages[_optimisticMessages.length - 1 - i];
              return _buildOptimisticBubble(opt, uid);
            }

            final msgDoc = reversedMessages[i - _optimisticMessages.length];
            final msg = msgDoc.data() as Map<String, dynamic>;
            final msgId = msgDoc.id;
            final type = msg['type'] ?? 'text';

            if (type == 'system') {
              return _buildSystemMessage(
                text: msg['text'] ?? '',
                timestamp: msg['timestamp'],
              );
            }

            final senderId = msg['senderId'] ?? '';
            final isMe = senderId == uid;
            final readBy = List<String>.from(msg['readBy'] ?? []);

            
            final profile = _localProfileCache[senderId] ??
                {'name': 'User', 'photo': '', 'role': 'player'};
            final name = profile['name'] ?? 'User';
            final photo = profile['photo'] ?? '';

            
            if (!_localProfileCache.containsKey(senderId)) {
              _loadProfileAndRebuild(senderId);
            }

            if (type == 'image') {
              return _buildImageBubble(
                mediaUrl: msg['mediaUrl'] ?? '',
                isMe: isMe,
                name: name,
                photo: photo,
                timestamp: msg['timestamp'],
                readBy: readBy,
                messageId: msgId,
                senderId: senderId,
                participants: participants,
                chatType: chatType,
                uid: uid,
              );
            }

            if (type == 'report') {
              return _buildReportBubble(
                reportData: (msg['reportData'] as Map?)?.cast<String, dynamic>() ?? {},
                isMe: isMe,
                name: name,
                photo: photo,
                timestamp: msg['timestamp'],
              );
            }

            return _buildChatBubble(
              text: msg['text'] ?? '',
              isMe: isMe,
              name: name,
              photo: photo,
              timestamp: msg['timestamp'],
              readBy: readBy,
              messageId: msgId,
              senderId: senderId,
              participants: participants,
              chatType: chatType,
              uid: uid,
            );
          },
        );
      },
    );
  }

  
  void _loadProfileAndRebuild(String senderId) {
    UnifiedChatService.getUserProfileOnce(senderId).then((profile) {
      if (mounted && !_localProfileCache.containsKey(senderId)) {
        setState(() => _localProfileCache[senderId] = profile);
      }
    });
  }

  
  Widget _buildOptimisticBubble(_OptimisticMessage opt, String uid) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.07),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: _accent.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              opt.text,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: _text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TimeOfDay.fromDateTime(opt.sentAt).format(context),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: _muted.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _muted.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble({
    required String text,
    required bool isMe,
    required String name,
    required String photo,
    required Timestamp? timestamp,
    required List<String> readBy,
    required String messageId,
    required String senderId,
    required List<String> participants,
    required String chatType,
    required String uid,
  }) {
    final photoProvider = _getImageProvider(photo);
    final isRead = readBy.length > 1;
    final timeStr = timestamp != null
        ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFEFEF),
                    backgroundImage: photoProvider,
                    child: photoProvider == null
                        ? Icon(Icons.person, color: _muted, size: 16)
                        : null,
                  ),
                ),
              Flexible(
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: 4,
                    left: isMe ? 50 : 0,
                    right: isMe ? 0 : 50,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _accent.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isMe ? _accent.withOpacity(0.3) : _line,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _accent,
                            ),
                          ),
                        ),
                      Text(
                        text,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: _muted.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
                right: isMe ? 4 : 0, left: isMe ? 0 : 42, bottom: 4),
            child: chatType == 'private'
                ? (isMe
                    ? Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 16,
                        color: isRead ? Colors.blue : Colors.grey,
                      )
                    : const SizedBox.shrink())
                : (isMe
                    ? _buildTeamReadIndicator(
                        readBy, messageId, senderId, participants)
                    : const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamReadIndicator(
    List<String> readBy,
    String messageId,
    String senderId,
    List<String> participants,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db
          .collection('Chat')
          .doc(widget.chatId)
          .collection('message')
          .doc(messageId)
          .snapshots(),
      builder: (context, msgSnap) {
        final liveReadBy = msgSnap.hasData && msgSnap.data!.exists
            ? List<String>.from(
                (msgSnap.data!.data() as Map<String, dynamic>?)?['readBy'] ??
                    readBy)
            : readBy;

        final otherMembers =
            participants.where((id) => id != senderId).toList();
        final readCount =
            liveReadBy.where((id) => id != senderId).length;
        final allRead = readCount >= otherMembers.length;

        return GestureDetector(
          onTap: () => _showReadStatusDialog(
              messageId, senderId, participants, liveReadBy),
          child: Icon(
            allRead ? Icons.done_all : Icons.done,
            size: 16,
            color: allRead ? Colors.blue : Colors.grey,
          ),
        );
      },
    );
  }

  // ─── Report Card Bubble ────────────────────────────────────────────────────
  Widget _buildReportBubble({
    required Map<String, dynamic> reportData,
    required bool isMe,
    required String name,
    required String photo,
    required Timestamp? timestamp,
  }) {
    final timeStr = timestamp != null
        ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
        : '';
    final photoProvider = _getImageProvider(photo);

    final gameTitle = reportData['gameTitle'] as String? ?? 'Game';
    final matchCount = reportData['matchCount'] as int? ?? 0;
    final generatedAt = reportData['generatedAt'] as String? ?? '';
    final overallScore = (reportData['overallScore'] as num?)?.toStringAsFixed(1) ?? '—';
    final winRate = reportData['winRate'] as String? ?? '';
    final kda = reportData['kda'] as String? ?? '';
    final recentScore = reportData['recentScore'] as String? ?? '';
    final strengths = List<Map>.from(reportData['strengths'] ?? []);
    final weaknesses = List<Map>.from(reportData['weaknesses'] ?? []);
    final trends = List<Map>.from(reportData['trends'] ?? []);
    final focusTitle = reportData['focusTitle'] as String? ?? '';
    final focusDesc = reportData['focusDesc'] as String? ?? '';
    final focusStatus = reportData['focusStatus'] as String? ?? '';
    final goals = List<Map>.from(reportData['goals'] ?? []);

    const cardBg = Color(0xFFFFFFFF);
    const cardAccent = Color.fromRGBO(235, 61, 36, 1);
    const cardSurface = Color(0xFFF6F7F8);
    const cardMuted = Color(0xFF536471);
    const cardText = Color(0xFF0F1419);
    const cardGreen = Color(0xFF16A34A);
    const cardRed = Color.fromRGBO(235, 61, 36, 1);

    Widget statRow(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: cardMuted,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: cardText,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        );

    Widget sectionHeader(String emoji, String label) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                  color: cardAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cardText,
                      letterSpacing: 0.5)),
            ],
          ),
        );

    final card = Container(
      width: 280,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFD9DE), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: cardAccent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$gameTitle Performance Report',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Spark Platform  •  $matchCount matches  •  $generatedAt',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview
                sectionHeader('🏆', 'OVERVIEW'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      statRow('Overall Score', overallScore),
                      if (winRate.isNotEmpty) statRow('Win Rate', winRate),
                      if (kda.isNotEmpty) statRow('KDA', kda),
                      if (recentScore.isNotEmpty)
                        statRow('Recent Score', recentScore),
                    ],
                  ),
                ),

                // Strengths & Weaknesses
                if (strengths.isNotEmpty || weaknesses.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionHeader('💪', 'STRENGTHS'),
                            ...strengths.take(3).map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                              color: cardGreen,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${s['label']}',
                                          style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: cardMuted,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Text('${s['value']}',
                                          style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: cardGreen,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionHeader('⚠️', 'IMPROVE'),
                            ...weaknesses.take(3).map((w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                              color: cardRed,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${w['label']}',
                                          style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: cardMuted,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Text('${w['value']}',
                                          style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: cardRed,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // Trends
                if (trends.isNotEmpty) ...[
                  sectionHeader('📈', 'TRENDS'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: trends.take(4).map((t) {
                        final isPos = t['isPositive'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isPos ? cardGreen : cardRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text('${t['label']}',
                                      style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          color: cardMuted,
                                          fontWeight: FontWeight.w600))),
                              Text('${t['prev']} → ${t['recent']}',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: isPos ? cardGreen : cardRed,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // Focus
                if (focusTitle.isNotEmpty) ...[
                  sectionHeader('🎯', 'CURRENT FOCUS  ·  ${focusStatus.toUpperCase()}'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: cardAccent.withOpacity(0.4), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(focusTitle,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: cardText)),
                        if (focusDesc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(focusDesc,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: cardMuted,
                                  height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],

                // Goals
                if (goals.isNotEmpty) ...[
                  sectionHeader('🚀', 'NEXT GOALS'),
                  ...goals.take(2).map((g) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${g['title']}',
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: cardText)),
                            const SizedBox(height: 3),
                            Text('${g['target']}',
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: cardAccent,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                ],

                // Footer stamp
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: cardAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardAccent.withOpacity(0.15)),
                  ),
                  child: const Text(
                    'Auto-generated by Spark · Real in-game data',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: cardMuted,
                        fontWeight: FontWeight.w500),
                  ),
                ),

                // Time
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(timeStr,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: cardMuted.withOpacity(0.6))),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFFEFEFEF),
                      backgroundImage: _getImageProvider(photo),
                    ),
                    const SizedBox(width: 6),
                    Text(name,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _accent)),
                  ],
                ),
              ),
            card,
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage({
    required String text,
    required Timestamp? timestamp,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: _accent,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _showReadStatusDialog(
    String messageId,
    String senderId,
    List<String> participants,
    List<String> readBy,
  ) {
    final isMySentMessage = senderId == _auth.currentUser!.uid;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _db
              .collection('Chat')
              .doc(widget.chatId)
              .collection('message')
              .doc(messageId)
              .snapshots(),
          builder: (context, msgSnap) {
            final liveReadBy = msgSnap.hasData && msgSnap.data!.exists
                ? List<String>.from(
                    (msgSnap.data!.data() as Map<String, dynamic>?)?['readBy'] ??
                        readBy)
                : readBy;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.remove_red_eye_outlined,
                        color: _accent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Read Status',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${liveReadBy.where((id) => id != senderId).length} of ${participants.where((id) => id != senderId).length} read',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: _line, thickness: 1),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: participants.length,
                        itemBuilder: (context, i) {
                          final userId = participants[i];
                          if (userId == senderId) return const SizedBox.shrink();

                          final hasRead = liveReadBy.contains(userId);
                          // Use cached profile — no StreamBuilder here.
                          final profile = _localProfileCache[userId] ??
                              {'name': 'User', 'photo': '', 'role': 'player'};
                          final name = profile['name'] ?? 'User';
                          final photo = profile['photo'] ?? '';
                          final photoProvider = _getImageProvider(photo);

                          IconData statusIcon;
                          Color statusColor;
                          if (hasRead) {
                            statusIcon = Icons.done_all;
                            statusColor = Colors.blue;
                          } else if (isMySentMessage) {
                            statusIcon = Icons.done;
                            statusColor = Colors.grey;
                          } else {
                            statusIcon = Icons.remove_red_eye_outlined;
                            statusColor = Colors.grey;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: hasRead ? Colors.blue : _line,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        const Color(0xFFEFEFEF),
                                    backgroundImage: photoProvider,
                                    child: photoProvider == null
                                        ? Icon(Icons.person,
                                            color: _muted, size: 20)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: _text,
                                    ),
                                  ),
                                ),
                                Icon(statusIcon,
                                    size: 18, color: statusColor),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(54, 52, 53, 1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Got it',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageBubble({
    required String mediaUrl,
    required bool isMe,
    required String name,
    required String photo,
    required Timestamp? timestamp,
    required List<String> readBy,
    required String messageId,
    required String senderId,
    required List<String> participants,
    required String chatType,
    required String uid,
  }) {
    final photoProvider = _getImageProvider(photo);
    final isRead = readBy.length > 1;
    final timeStr = timestamp != null
        ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFEFEF),
                    backgroundImage: photoProvider,
                    child: photoProvider == null
                        ? Icon(Icons.person, color: _muted, size: 16)
                        : null,
                  ),
                ),
              Flexible(
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: 4,
                    left: isMe ? 50 : 0,
                    right: isMe ? 0 : 50,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? _accent.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isMe ? _accent.withOpacity(0.3) : _line,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(15),
                      topRight: const Radius.circular(15),
                      bottomLeft: Radius.circular(isMe ? 15 : 3),
                      bottomRight: Radius.circular(isMe ? 3 : 15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => _openImageViewer(context, mediaUrl),
                          child: mediaUrl.startsWith('data:')
                              ? Image.memory(
                                  base64Decode(mediaUrl.split(',').last),
                                  width: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 220,
                                    height: 100,
                                    color: _chip,
                                    child: Icon(Icons.broken_image_rounded,
                                        color: _muted),
                                  ),
                                )
                              : Image.network(
                                  mediaUrl,
                                  width: 220,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: 220,
                                      height: 160,
                                      color: _chip,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: _accent,
                                          value: progress.expectedTotalBytes !=
                                                  null
                                              ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 220,
                                    height: 100,
                                    color: _chip,
                                    child: Icon(Icons.broken_image_rounded,
                                        color: _muted),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: _muted.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
                right: isMe ? 4 : 0, left: isMe ? 0 : 42, bottom: 4),
            child: chatType == 'private'
                ? (isMe
                    ? Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 16,
                        color: isRead ? Colors.blue : Colors.grey,
                      )
                    : const SizedBox.shrink())
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pendingBytes != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _pendingImageTooLarge
                  ? const Color(0xFFFFF0EE)
                  : _chip,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _pendingImageTooLarge ? _accent : _line,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColorFiltered(
                        colorFilter: _pendingImageTooLarge
                            ? const ColorFilter.matrix([
                                0.3, 0, 0, 0, 0,
                                0, 0.3, 0, 0, 0,
                                0, 0, 0.3, 0, 0,
                                0, 0,   0, 1, 0,
                              ])
                            : const ColorFilter.matrix([
                                1, 0, 0, 0, 0,
                                0, 1, 0, 0, 0,
                                0, 0, 1, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                        child: Image.memory(
                          _pendingBytes!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (_pendingImageTooLarge)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pendingImageTooLarge
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Image too large',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Max size is 700KB. Please choose a smaller image.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _pendingFileName ?? '',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (_pendingImageTooLarge) ...[
                  // Pick another image
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _pendingBytes = null;
                        _pendingFileName = null;
                        _pendingImageTooLarge = false;
                      });
                      _pickImage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
                GestureDetector(
                  onTap: () => setState(() {
                    _pendingBytes = null;
                    _pendingFileName = null;
                    _pendingImageTooLarge = false;
                  }),
                  child: Icon(Icons.close_rounded, color: _muted, size: 20),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.image_rounded, color: _muted, size: 22),
                onPressed: _pickImage,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _chip,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _line),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    cursorColor: _accent,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _text,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openImageViewer(BuildContext context, String mediaUrl) {
    final imageBytes = mediaUrl.startsWith('data:')
        ? base64Decode(mediaUrl.split(',').last)
        : null;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: imageBytes != null
                    ? Image.memory(imageBytes, fit: BoxFit.contain)
                    : Image.network(mediaUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 16,
              child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  if (imageBytes != null) {
                    await _downloadImage(mediaUrl,
                        'image_${DateTime.now().millisecondsSinceEpoch}.jpg');
                  } else {
                    launchUrl(Uri.parse(mediaUrl),
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage(String mediaUrl, String fileName) async {
    try {
      final bytes = mediaUrl.startsWith('data:')
          ? base64Decode(mediaUrl.split(',').last)
          : null;

      if (bytes == null) {
        launchUrl(Uri.parse(mediaUrl), mode: LaunchMode.externalApplication);
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      } else {
        await Gal.putImageBytes(bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery ✓')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  
  bool _pendingImageTooLarge = false;


  static const int _maxImageBytes = 700 * 1024;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    Uint8List bytes;
    if (kIsWeb) {
      bytes = await picked.readAsBytes();
    } else {
      bytes = await File(picked.path).readAsBytes();
    }

    if (bytes.lengthInBytes > _maxImageBytes) {
      
      setState(() {
        _pendingBytes = bytes;
        _pendingFileName = picked.name;
        _pendingImageTooLarge = true;
      });
      return;
    }

    setState(() {
      _pendingBytes = bytes;
      _pendingFileName = picked.name;
      _pendingImageTooLarge = false;
    });
  }

  Future<void> _uploadAndSendImage(
      {required Uint8List bytes, required String fileName}) async {
    final uid = _auth.currentUser!.uid;
    final ext = fileName.split('.').last;
    final base64Image = 'data:image/$ext;base64,${base64Encode(bytes)}';

    final msgRef = _db
        .collection('Chat')
        .doc(widget.chatId)
        .collection('message')
        .doc();

   
    await Future.wait([
      msgRef.set({
        'senderId': uid,
        'text': '',
        'type': 'image',
        'mediaUrl': base64Image,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [uid],
      }),
      _db.collection('Chat').doc(widget.chatId).update({
        'lastMessage': '📷 Image',
        'lastMessageSender': uid,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'isEmpty': false,
      }),
    ]);
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    final hasPending = _pendingBytes != null;

    if (text.isEmpty && !hasPending) return;

    
    if (_pendingImageTooLarge) return;

    final capturedBytes = _pendingBytes;
    final capturedFileName = _pendingFileName;

    
    if (text.isNotEmpty) {
      setState(() {
        _optimisticMessages.add(_OptimisticMessage(text: text));
        _pendingBytes = null;
        _pendingFileName = null;
        _pendingImageTooLarge = false;
      });
    } else {
      setState(() {
        _pendingBytes = null;
        _pendingFileName = null;
        _pendingImageTooLarge = false;
      });
    }

    _msgCtrl.clear();

   
    _doSend(
      text: text,
      hasPending: hasPending,
      bytes: capturedBytes,
      fileName: capturedFileName,
    );
  }

  Future<void> _doSend({
    required String text,
    required bool hasPending,
    required Uint8List? bytes,
    required String? fileName,
  }) async {
    try {
      final uid = _auth.currentUser!.uid;

      if (hasPending && bytes != null) {
        await _uploadAndSendImage(bytes: bytes, fileName: fileName!);
      }

      if (text.isNotEmpty) {
        final msgRef = _db
            .collection('Chat')
            .doc(widget.chatId)
            .collection('message')
            .doc();

       
        await Future.wait([
          msgRef.set({
            'senderId': uid,
            'text': text,
            'type': 'text',
            'timestamp': FieldValue.serverTimestamp(),
            'readBy': [uid],
          }),
          _db.collection('Chat').doc(widget.chatId).update({
            'lastMessage': text,
            'lastMessageSender': uid,
            'lastTimestamp': FieldValue.serverTimestamp(),
            'isEmpty': false,
          }),
        ]);
      }
    } catch (e) {

      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.text == text);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }
}

// ─── Optimistic Message Model ──────────────────────────────────────────────────

class _OptimisticMessage {
  final String text;
  final DateTime sentAt;
  _OptimisticMessage({required this.text}) : sentAt = DateTime.now();
}
