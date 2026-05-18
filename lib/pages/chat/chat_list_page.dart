// lib/pages/chat/chat_list_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/chat/unified_chat_service.dart';
import '../../services/player/team/team_status_service.dart';
import '../player/player_profile_page.dart';
import 'new_chat_page.dart';

class ChatListPage extends StatefulWidget {
  final int? initialTab;
  const ChatListPage({super.key, this.initialTab});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late int _index;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  StreamSubscription<List<TeamStatusUpdate>>? _teamStatusSub;
  bool _alertIsShowing = false;

  
  late final Stream<bool> _chatsUnreadStream;
  late final Stream<bool> _requestsUnreadStream;


  bool _chatsHasUnread = false;
  bool _requestsHasUnread = false;

  StreamSubscription<bool>? _chatsUnreadSub;
  StreamSubscription<bool>? _requestsUnreadSub;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _chip = Color(0xFFF0F3F4);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _notificationGreen = Color(0xFF34C759);

  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab ?? 0;

    
    _chatsUnreadStream = UnifiedChatService.listenChatsHasUnread();
    _requestsUnreadStream = UnifiedChatService.listenRequestsHasUnread();

  
    _chatsUnreadSub = _chatsUnreadStream.listen((value) {
      if (mounted && _chatsHasUnread != value) {
        setState(() => _chatsHasUnread = value);
      }
    });

    _requestsUnreadSub = _requestsUnreadStream.listen((value) {
      if (mounted && _requestsHasUnread != value) {
        setState(() => _requestsHasUnread = value);
      }
    });

    _listenToTeamStatus();
  }

  void _listenToTeamStatus() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _teamStatusSub = TeamStatusService.listenToUserTeamsAll(userId).listen(
      (updates) {
        if (updates.isNotEmpty && mounted && !_alertIsShowing) {
          _alertIsShowing = true;
          TeamStatusService.showBatchTeamStatusAlert(context, updates, userId);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) _alertIsShowing = false;
          });
        }
      },
      onError: (e) => debugPrint('TeamStatus error: $e'),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _teamStatusSub?.cancel();
    _chatsUnreadSub?.cancel();
    _requestsUnreadSub?.cancel();
    super.dispose();
  }

  void _onTabChanged(int newIndex) {
    if (_index == newIndex) return;
    setState(() => _index = newIndex);
    if (newIndex == 1) {
      UnifiedChatService.markAllRequestsAsRead(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Login required'));

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Organizer')
          .doc(user.uid)
          .get(),
      builder: (context, snap) {
        final isOrganizer = snap.data?.exists ?? false;

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              'Messaging',
              style: TextStyle(
                fontFamily: 'Inter',
                color: _accent,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _chip,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: _muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                            cursorColor: _accent,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _text,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search...',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _muted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

             
              if (!isOrganizer) _buildTabsBar(),

              const SizedBox(height: 20),
              Expanded(child: _buildChats(uid, isOrganizer)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: _accent,
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewChatPage()),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTabsBar() {
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tab('Chats', 0, _chatsHasUnread),
        const SizedBox(width: 12),
        _tab('Requests', 1, _requestsHasUnread),
      ],
    );
  }

  Widget _tab(String title, int index, bool hasUnread) {
    final selected = _index == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _text : _chip,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _text : _line,
                width: 1,
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                color: selected ? Colors.white : _text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _notificationGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChats(String uid, bool isOrganizer) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: UnifiedChatService.listenUserChats(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
              child: CircularProgressIndicator(color: _accent));
        }

        final all = snap.data!;
        var filtered = all.where((c) {
          final isEmpty = c['isEmpty'] ?? false;
          final type = c['type'] ?? '';
          final hiddenBy = List<String>.from(c['hiddenBy'] ?? []);
          if (hiddenBy.contains(uid)) return false;

          if (isOrganizer) {
            return type == 'private' && !isEmpty;
          } else {
            if (_index == 0) {
              return (type == 'private' && !isEmpty) ||
                  (type == 'team' && c['status'] == 'active');
            } else {
              return type == 'team' &&
                  (c['status'] == 'pending' ||
                      c['status'] == 'rejected');
            }
          }
        }).toList();

        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((c) {
            final displayName =
                (c['displayName'] ?? '').toString().toLowerCase();
            return displayName.contains(_searchQuery);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'No results found'
                  : isOrganizer
                      ? 'No active chats yet'
                      : _index == 0
                          ? 'No active chats yet'
                          : 'No requests yet',
              style: const TextStyle(
                fontFamily: 'Inter',
                color: _muted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final chat = filtered[i];
            if (!isOrganizer && _index == 1 && chat['type'] == 'team') {
              return _inviteCard(chat);
            } else {
              return _chatCard(chat);
            }
          },
        );
      },
    );
  }

  Uint8List? _decodeBase64Image(String base64String) {
    try {
      final cleaned = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      return base64.decode(cleaned);
    } catch (e) {
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

  Widget _chatCard(Map<String, dynamic> chat) {
    final isTeam = chat['type'] == 'team';
    final nameRaw = (chat['displayName'] ?? '').toString();
    final photoRaw = (chat['photoUrl'] ?? '').toString();
    final lastMessage = (chat['lastMessage'] ?? '').toString();
    final photoProvider = _getImageProvider(photoRaw);
    final lastTimestamp = chat['lastTimestamp'] as Timestamp?;

    String timeStr = '';
    if (lastTimestamp != null) {
      final date = lastTimestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        timeStr = '$hour:$minute';
      } else if (diff.inDays == 1) {
        timeStr = 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        timeStr = days[date.weekday - 1];
      } else {
        timeStr = '${date.day}/${date.month}/${date.year}';
      }
    }

   
   
    return StreamBuilder<bool>(
      stream: UnifiedChatService.listenChatHasUnread(chat['id']),
      builder: (context, unreadSnap) {
        final hasUnread = unreadSnap.data ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFCFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.pushNamed(context, '/chat',
                  arguments: chat['id']);
            },
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _accent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFEFEFEF),
                        backgroundImage: photoProvider,
                        child: photoProvider == null
                            ? Icon(
                                isTeam ? Icons.groups : Icons.person,
                                color: _muted,
                                size: 26,
                              )
                            : null,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _notificationGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFFCFCFC), width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameRaw.isEmpty
                            ? (isTeam ? 'Team Name' : 'Player Name')
                            : nameRaw,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: hasUnread
                              ? FontWeight.w800
                              : FontWeight.w700,
                          fontSize: 15,
                          color: _text,
                        ),
                      ),
                      if (lastMessage.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: hasUnread ? _text : _muted,
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: hasUnread ? _accent : _muted,
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (hasUnread)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: _notificationGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _inviteStatusBadge(String myResponse, String chatStatus) {
    // Determine label, color, and icon based on status
    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (chatStatus == 'rejected') {
      label = 'Rejected by Team';
      bgColor = _accent.withOpacity(0.10);
      textColor = _accent;
      icon = Icons.cancel_outlined;
    } else if (myResponse == 'Accepted') {
      label = 'You Accepted';
      bgColor = const Color(0xFF34C759).withOpacity(0.12);
      textColor = const Color(0xFF1A8C3A);
      icon = Icons.check_circle_outline;
    } else if (myResponse == 'Rejected') {
      label = 'You Declined';
      bgColor = _accent.withOpacity(0.10);
      textColor = _accent;
      icon = Icons.cancel_outlined;
    } else {
      // pending
      label = 'Awaiting Response';
      bgColor = const Color(0xFFF5A623).withOpacity(0.12);
      textColor = const Color(0xFFB36A00);
      icon = Icons.schedule_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteCard(Map<String, dynamic> chat) {
    final teamId = chat['teamId'] ?? '';
    if (teamId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Team')
          .doc(teamId)
          .get(),
      builder: (context, teamSnap) {
        if (!teamSnap.hasData || !teamSnap.data!.exists) {
          return const SizedBox.shrink();
        }

        final teamData =
            teamSnap.data!.data() as Map<String, dynamic>? ?? {};
        final teamName = teamData['name'] ?? 'Team';
        final photo = teamData['logoUrl'] ?? '';
        final photoProvider = _getImageProvider(photo);
        final winRate = (teamData['winRate'] ?? 0).toDouble();
        final createdBy = teamData['createdBy'] ?? '';
        final currentUser = FirebaseAuth.instance.currentUser;
        final isOwner =
            currentUser != null && createdBy == currentUser.uid;
        final uid = currentUser?.uid ?? '';
        final chatStatus = chat['status'] ?? 'pending';

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Team')
              .doc(teamId)
              .collection('Members')
              .doc(uid)
              .snapshots(),
          builder: (context, mySnap) {
            final myData =
                mySnap.data?.data() as Map<String, dynamic>? ?? {};
            final myResponse =
                (myData['response'] ?? 'none').toString();
            final showButtons = !isOwner && myResponse == 'none';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFCFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      chatStatus == 'rejected' ? _accent : _line,
                  width: chatStatus == 'rejected' ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header Row: Logo + Team Info + WinRate ──
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _accent, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor:
                                    const Color(0xFFEFEFEF),
                                backgroundImage: photoProvider,
                                child: photoProvider == null
                                    ? Icon(Icons.groups,
                                        color: _muted, size: 26)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teamName,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: _text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _inviteStatusBadge(myResponse, chatStatus),
                                ],
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.10),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        _accent.withOpacity(0.25)),
                              ),
                              child: Text(
                                '🏆 ${winRate.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w800,
                                  color: _accent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── Members Row: Horizontal avatars beside logo ──
                        FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('Team')
                              .doc(teamId)
                              .collection('Members')
                              .get(),
                          builder: (context, memberSnap) {
                            if (!memberSnap.hasData ||
                                memberSnap.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final members = memberSnap.data!.docs;

                            return _MembersHorizontalRow(
                              members: members,
                              getImageProvider: _getImageProvider,
                              muted: _muted,
                              accent: _accent,
                              text: _text,
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        if (showButtons && chatStatus != 'rejected')
                          _RespondButtons(
                            chat: chat,
                            onRespond: _respond,
                          ),
                      ],
                    ),
                  ),
                  if (chatStatus == 'rejected')
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => _deleteRejectedRequest(
                            chat['id'], teamId),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _respond(
      Map<String, dynamic> chat, bool accept) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final teamId = chat['teamId'];

    db
        .collection('Team')
        .doc(teamId)
        .collection('Members')
        .doc(uid)
        .update({'response': accept ? 'Accepted' : 'Rejected'}).then((_) {
      UnifiedChatService.checkAndActivateTeamChat(teamId);
    });
  }

  Future<void> _deleteRejectedRequest(
      String chatId, String teamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 2),
                  ),
                  child: const Icon(
                    Icons.visibility_off_rounded,
                    color: _accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to hide this team request?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: _text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _muted,
                          side: const BorderSide(color: _line),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Hide',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final chatDoc =
          await db.collection('Chat').doc(chatId).get();
      final data = chatDoc.data();

      if (data != null) {
        if (data.containsKey('hiddenBy')) {
          await db.collection('Chat').doc(chatId).update({
            'hiddenBy': FieldValue.arrayUnion([uid]),
          });
        } else {
          await db.collection('Chat').doc(chatId).update({
            'hiddenBy': [uid],
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error hiding request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


class _MembersHorizontalRow extends StatefulWidget {
  final List<QueryDocumentSnapshot> members;
  final ImageProvider? Function(String) getImageProvider;
  final Color muted;
  final Color accent;
  final Color text;

  const _MembersHorizontalRow({
    required this.members,
    required this.getImageProvider,
    required this.muted,
    required this.accent,
    required this.text,
  });

  @override
  State<_MembersHorizontalRow> createState() => _MembersHorizontalRowState();
}

class _MembersHorizontalRowState extends State<_MembersHorizontalRow> {
  // Stores fetched player data keyed by playerId.
  final Map<String, Map<String, dynamic>> _playerCache = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchAllPlayers();
  }

  Future<void> _fetchAllPlayers() async {
    final futures = widget.members.map((m) async {
      final playerId = m.id;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('Player')
            .doc(playerId)
            .get();
        return MapEntry(playerId, doc.data() as Map<String, dynamic>? ?? {});
      } catch (_) {
        return MapEntry(playerId, <String, dynamic>{});
      }
    });

    final results = await Future.wait(futures);
    if (mounted) {
      setState(() {
        for (final entry in results) {
          _playerCache[entry.key] = entry.value;
        }
        _loaded = true;
      });
    }
  }

  Widget _statusIndicator(String status) {
    Color bgColor;
    IconData icon;

    if (status == 'Accepted') {
      bgColor = const Color(0xFF34C759);
      icon = Icons.check;
    } else if (status == 'Rejected') {
      bgColor = const Color(0xFFEB3D24);
      icon = Icons.close;
    } else {
      bgColor = const Color(0xFF8E8E93);
      icon = Icons.hourglass_bottom_rounded;
    }

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      
      return SizedBox(
        height: 72,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: widget.members.length,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFEFEF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 36,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFEF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: Center(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: widget.members.length,
          itemBuilder: (context, i) {
          final m = widget.members[i];
          final memberData = m.data() as Map<String, dynamic>;
          final status = (memberData['response'] ?? 'none').toString();
          final role = (memberData['role'] ?? '').toString();
          final playerId = m.id;
          final pData = _playerCache[playerId] ?? {};
          final name = (pData['Name'] ?? 'Player').toString();
          final profile = (pData['ProfilePhoto'] ?? '').toString();
          final profileProvider = widget.getImageProvider(profile);


          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PlayerProfilePage(),
                  settings: RouteSettings(arguments: playerId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFEFEFEF),
                        backgroundImage: profileProvider,
                        child: profileProvider == null
                            ? Icon(Icons.person,
                                color: widget.muted, size: 20)
                            : null,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: _statusIndicator(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 52,
                    child: Text(
                      name.split(' ').first,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.text,
                      ),
                    ),
                  ),
                  if (role.isNotEmpty)
                    SizedBox(
                      width: 52,
                      child: Text(
                        role,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: widget.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

class _RespondButtons extends StatefulWidget {
  final Map<String, dynamic> chat;
  final Future<void> Function(Map<String, dynamic>, bool) onRespond;

  const _RespondButtons({
    required this.chat,
    required this.onRespond,
  });

  @override
  State<_RespondButtons> createState() => _RespondButtonsState();
}

class _RespondButtonsState extends State<_RespondButtons> {
  bool _loading = false;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  Future<void> _handle(bool accept) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onRespond(widget.chat, accept);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _loading ? null : () => _handle(true),
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Accept',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _loading ? null : () => _handle(false),
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Reject',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
