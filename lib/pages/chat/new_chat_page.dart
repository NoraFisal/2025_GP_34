import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import 'chat_page.dart';

class NewChat extends StatefulWidget {
  final String currentUserId;

  const NewChat({super.key, required this.currentUserId});

  @override
  State<NewChat> createState() => _NewChatState();
}

class _NewChatState extends State<NewChat> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _existingChatUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadExistingChats();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  /// تحميل المحادثات السابقة
  Future<void> _loadExistingChats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chats = await FirebaseFirestore.instance
        .collection('PlayerChat')
        .where('participants', arrayContains: user.uid)
        .get();

    final ids = <String>{};
    for (var doc in chats.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      for (final id in participants) {
        if (id != user.uid) ids.add(id);
      }
    }

    setState(() {
      _existingChatUserIds = ids;
    });
  }

  /// إنشاء محادثة جديدة أو الحصول على الموجودة
  Future<String> _getOrCreateChat(String otherUserId) async {
    final db = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) throw Exception('User not logged in.');

    final existing = await db
        .collection('PlayerChat')
        .where('participants', arrayContains: user.uid)
        .get();

    for (var doc in existing.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(otherUserId)) return doc.id;
    }

    final newChat = await db.collection('PlayerChat').add({
      'participants': [user.uid, otherUserId],
      'lastMessage': '',
      'lastTimestamp': Timestamp.now(),
    });

    return newChat.id;
  }

  /// تجهيز الصورة من رابط أو Base64
  ImageProvider? _getImage(String? img) {
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return NetworkImage(img);
    try {
      return MemoryImage(base64Decode(img));
    } catch (_) {
      return null;
    }
  }

  /// تسليط الضوء على الجزء المطابق
  Widget _buildHighlightedText(String fullText, String query) {
    if (query.isEmpty) {
      return Text(
        fullText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      );
    }

    final lowerText = fullText.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        fullText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      );
    }

    final start = matchIndex;
    final end = matchIndex + query.length;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: fullText.substring(0, start),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          TextSpan(
            text: fullText.substring(start, end),
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          TextSpan(
            text: fullText.substring(end),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// ترتيب الأسماء بحيث اللي تبدأ بالبحث تطلع أولاً
  List<QueryDocumentSnapshot> _sortPlayers(List<QueryDocumentSnapshot> players) {
    if (_searchQuery.isEmpty) return players;

    final lowerQuery = _searchQuery.toLowerCase();
    players.sort((a, b) {
      final nameA = ((a.data() as Map<String, dynamic>)['Name'] ?? '')
          .toString()
          .toLowerCase();
      final nameB = ((b.data() as Map<String, dynamic>)['Name'] ?? '')
          .toString()
          .toLowerCase();

      final aStarts = nameA.startsWith(lowerQuery);
      final bStarts = nameB.startsWith(lowerQuery);

      if (aStarts && !bStarts) return -1;
      if (bStarts && !aStarts) return 1;

      // fallback إلى الترتيب الأبجدي
      return nameA.compareTo(nameB);
    });

    return players;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    
    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Start New Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  _searchBar(t),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('Player').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        var players = snapshot.data!.docs.where((p) {
                          final id = p.id;
                          if (id == widget.currentUserId) return false;
                          if (_existingChatUserIds.contains(id)) return false;
                          final data = p.data() as Map<String, dynamic>;
                          final name = (data['Name'] ?? '').toString().toLowerCase();
                          if (_searchQuery.isEmpty) return true;
                          return name.contains(_searchQuery.toLowerCase());
                        }).toList();

                        players = _sortPlayers(players);

                        if (players.isEmpty) {
                          return Center(
                            child: Text('No players found',
                              style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                          );
                        }

                        return ListView.separated(
                          itemCount: players.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = players[i];
                            final data = p.data() as Map<String, dynamic>;
                            final name = data['Name'] ?? 'Unknown';
                            final photo = data['ProfilePhoto'] ?? '';
                            
                            return InkWell(
                              onTap: () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                );
                                try {
                                  final chatId = await _getOrCreateChat(p.id);
                                  if (context.mounted) Navigator.of(context).pop();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => Chat(
                                        chatId: chatId,
                                        currentUserId:
                                            FirebaseAuth.instance.currentUser!.uid,
                                        otherUserId: p.id,
                                        otherUserName: name,
                                        otherUserImage: photo.isNotEmpty ? photo : null,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (context.mounted) Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
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
                                      child: (photo.isEmpty)
                                          ? const Icon(Icons.person, color: Colors.white54)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildHighlightedText(name, _searchQuery),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: kToolbarHeight + 20,
            child: MiniSideNav(top: kToolbarHeight + 20, left: 0),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(ThemeData t) {
    return TextField(
      controller: _searchController,
      style: t.textTheme.bodyLarge?.copyWith(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        hintText: 'Search players',
        hintStyle: t.textTheme.bodyLarge?.copyWith(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      ),
    );
  }
}