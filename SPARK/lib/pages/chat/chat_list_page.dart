import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/player/chat/chat_model.dart' as model;
import '../../services/player/chat/message_service.dart';
import '../../services/player/team/team_service.dart';
import '../chat/team_chat_page.dart';
import 'chat_page.dart' as screen;
import 'new_chat_page.dart';
import '/ui/components/mini_side_nav.dart';
import '/ui/theme.dart';
import '../player/player_profile_page.dart';
import '/ui/components/bg_scaffold.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  String? profileImageUrl;
  String _selectedTab = 'player'; 
  bool _isLoading = false;
  String _searchQuery = '';

  int _playerUnreadCount = 0; // 🔴 عدد إشعارات Player
  int _teamUnreadCount = 0;   // 🔴 عدد إشعارات Team

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _listenUnreadCounts(); // ✅ مراقبة الإشعارات لحظيًا
  }

  /// ✓ تحميل صورة المستخدم الحالي
  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('Player').doc(user.uid).get();
      if (snap.exists) {
        setState(() {
          profileImageUrl = snap.data()?['ProfilePhoto'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
    }
  }

  /// ✅ مراقبة عدد الرسائل غير المقروءة لحظياً (Player + Team)
  void _listenUnreadCounts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔹 مراقبة محادثات الـ Player
    FirebaseFirestore.instance
        .collection('PlayerChat')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((chatsSnap) async {
      int totalPlayerUnread = 0;
      for (var chat in chatsSnap.docs) {
        final msgsSnap = await chat.reference
            .collection('PlayerMessage')
            .where('ReceiverID', isEqualTo: user.uid)
            .where('status', isEqualTo: 'sent')
            .get();
        totalPlayerUnread += msgsSnap.docs.length;
      }

      if (mounted) {
        setState(() => _playerUnreadCount = totalPlayerUnread);
      }
    });

    // 🔹 مراقبة محادثات الـ Team
    FirebaseFirestore.instance.collection('TeamChat').snapshots().listen((teamChats) async {
      int totalTeamUnread = 0;
      for (var chat in teamChats.docs) {
        final msgsSnap = await chat.reference.collection('TeamMessage').get();
        for (var msg in msgsSnap.docs) {
          final data = msg.data();
          final readBy = List<String>.from(data['readBy'] ?? []);
          if (!readBy.contains(user.uid)) totalTeamUnread++;
        }
      }

      if (mounted) {
        setState(() => _teamUnreadCount = totalTeamUnread);
      }
    });
  }

  ImageProvider? _getImage(String? img) {
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return NetworkImage(img);
    try {
      return MemoryImage(base64Decode(img));
    } catch (_) {
      return null;
    }
  }

  void _onTabChange(String value) async {
    if (_selectedTab == value) return;
    setState(() {
      _selectedTab = value;
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _isLoading = false;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? '';

    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Padding(
          padding: EdgeInsets.only(top: 24.0),
          child: Text(
            'Messaging',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 20,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const PlayerProfilePage()));
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
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
            padding: const EdgeInsets.only(top: kToolbarHeight + 48, left: 20, right: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(28, 30, 40, 1).withAlpha(90),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ أزرار Player/Team
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: _buildModeSelector(),
                  ),

                  // ✅ البحث
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _buildSearchBar(),
                  ),

                  // ✅ مسافة إضافية بين البحث والقائمة
                  const SizedBox(height: 16),

                  // ✅ القائمة
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                          : (_selectedTab == 'player'
                              ? _buildPlayerChats(uid)
                              : _buildTeamChats(uid)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ✅ السايد نافي
          Positioned(
            top: kToolbarHeight + 20,
            left: 0,
            child: MiniSideNav(top: kToolbarHeight + 20, left: 0),
          ),
        ],
      ),

      // ✅ الزر السفلي
      floatingActionButton: _selectedTab == 'player'
          ? Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 25,
                    spreadRadius: 6,
                  ),
                ],
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NewChat(currentUserId: uid)),
                ),
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E2819),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                      Positioned(
                        top: 20.5,
                        child: Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // 🔘 تبويبات Player/Team مع البادج
  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildToggleButton('Player', 'player'),
                if (_playerUnreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 25,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration:
                          const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        _playerUnreadCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildToggleButton('Team', 'team'),
                if (_teamUnreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 25,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration:
                          const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        _teamUnreadCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String title, String value) {
    final bool isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => _onTabChange(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.transparent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // 🔍 شريط البحث
  Widget _buildSearchBar() {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Search ${_selectedTab == 'player' ? 'players' : 'teams'}...",
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(.08),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white54),
        ),
      ),
    );
  }

  // 📩 Player Chats
  Widget _buildPlayerChats(String uid) {
    return StreamBuilder<List<model.Chat>>(
      stream: MessageService.getUserChats(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white70));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child:
                  Text('No private chats', style: TextStyle(color: Colors.white60)));
        }

        final chats = snapshot.data!;
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _filterPlayerChats(chats, uid),
          builder: (context, asyncSnap) {
            if (!asyncSnap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white70));
            }

            final filteredData = asyncSnap.data!;
            if (filteredData.isEmpty) {
              return const Center(
                  child: Text('No results found',
                      style: TextStyle(color: Colors.white60)));
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredData.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final chat = filteredData[i];
                final otherId = chat['otherId'];
                final name = chat['name'];
                final photo = chat['photo'];
                final chatId = chat['chatId'];
                final unread = chat['unreadCount'];

                return InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => screen.Chat(
                          chatId: chatId,
                          currentUserId: uid,
                          otherUserId: otherId,
                          otherUserName: name,
                          otherUserImage: photo,
                        ),
                      ),
                    );
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white12,
                          backgroundImage: _getImage(photo),
                          child: (photo == null || photo.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white54)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                chat['lastMessage'].isNotEmpty
                                    ? chat['lastMessage']
                                    : 'Start chatting...',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontStyle: chat['lastMessage'].isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread.toString(),
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 12,
                                fontWeight: FontWeight.bold
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
      },
    );
  }

  Future<List<Map<String, dynamic>>> _filterPlayerChats(
      List<model.Chat> chats, String uid) async {
    List<Map<String, dynamic>> result = [];

    for (var chat in chats) {
      final otherId = chat.participants.firstWhere((id) => id != uid, orElse: () => '');
      if (otherId.isEmpty) continue;

      final playerSnap =
          await FirebaseFirestore.instance.collection('Player').doc(otherId).get();
      if (!playerSnap.exists) continue;

      final data = playerSnap.data()!;
      final name = data['Name']?.toString() ?? 'Unknown';
      final photo = data['ProfilePhoto']?.toString() ?? '';
      final unread = await MessageService.getUnreadPlayerMessagesCount(chat.id, uid);

      if (_searchQuery.isEmpty || name.toLowerCase().contains(_searchQuery)) {
        result.add({
          'chatId': chat.id,
          'otherId': otherId,
          'name': name,
          'photo': photo,
          'lastMessage': chat.lastMessage,
          'unreadCount': unread,
        });
      }
    }

    return result;
  }

  // 👥 Team Chats
  Widget _buildTeamChats(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: TeamService.getUserTeams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white70));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child:
                  Text('No team chats found', style: TextStyle(color: Colors.white60)));
        }

        final teams = snapshot.data!
            .where((team) =>
                _searchQuery.isEmpty ||
                (team['teamName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery))
            .toList();

        if (teams.isEmpty) {
          return const Center(
              child:
                  Text('No results found', style: TextStyle(color: Colors.white60)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: teams.length,
          itemBuilder: (context, i) {
            final team = teams[i];
            final name = team['teamName'] ?? 'Unnamed Team';
            final logo = team['logoUrl'] ?? '';
            final teamId = team['teamId'] ?? '';

            return FutureBuilder<int>(
              future: TeamService.getUnreadTeamMessagesCount(teamId, uid),
              builder: (context, unreadSnap) {
                final unread = unreadSnap.data ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TeamChatPage(teamId: teamId, teamName: name)),
                      );
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: logo.isNotEmpty ? _getImage(logo) : null,
                            child: logo.isEmpty
                                ? const Icon(Icons.groups, color: Colors.white70)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        color: Colors.white, 
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                const Text('Team group chat',
                                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}