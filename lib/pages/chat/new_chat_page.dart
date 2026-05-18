// 📄 lib/pages/chat/new_chat_page.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/chat/unified_chat_service.dart';
import '../team/create_team_page.dart'; // ✅ Import CreateTeamPage

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  String _query = '';
  final _auth = FirebaseAuth.instance;

  // ✅ نفس ألوان HomePage و ChatListPage
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _chip = Color(0xFFF0F3F4);
  static const Color _line = Color(0xFFCFD9DE);

  /// Fetch all players and organizers
  Stream<List<QueryDocumentSnapshot>> _mergedUserStream() async* {
    final players =
        await FirebaseFirestore.instance.collection('Player').get();
    final organizers =
        await FirebaseFirestore.instance.collection('Organizer').get();

    yield [...players.docs, ...organizers.docs];
  }

  Uint8List? _decodeBase64Image(String base64String) {
    try {
      final cleaned = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
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
    final currentUid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        // ✅ نفس سهم الرجوع من ChatPage
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF363435),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Chat',
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
          // Search bar - نفس حجم وتصميم ChatListPage
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
                    Icon(Icons.search, size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
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
                        onChanged: (v) => setState(() {
                          _query = v.trim().toLowerCase();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ✅ NEW TEAM OPTION - Simple button that navigates to CreateTeamPage
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () {
                // ✅ Navigate to CreateTeamPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTeamPage(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
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
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _accent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: _accent.withOpacity(0.1),
                        child: Icon(Icons.group_add, color: _accent, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Team',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ❌ Removed arrow icon
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Divider with text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: _line, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR START CHAT WITH',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: _line, thickness: 1)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // User list
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _mergedUserStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }

                final docs = snap.data!.where((d) {
                  // Don't show current user
                  if (d.id == currentUid) return false;

                  final name = (d['Name'] ?? '').toString().toLowerCase();
                  return _query.isEmpty || name.contains(_query);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found.',
                      style: TextStyle(
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
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final uid = d.id;
                    final name = d['Name'] ?? 'Player';
                    final photo = d['ProfilePhoto'] ?? '';
                    final isOrganizer = d.reference.parent.id
                        .toLowerCase()
                        .contains('organizer');

                    final photoProvider = _getImageProvider(photo);

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
                        onTap: () async {
                          // Create or get existing chat
                          try {
                            final chatId = await UnifiedChatService.createPrivateChat(uid);
                            
                            if (!mounted) return;
                            
                            // Navigate to chat page
                            Navigator.pop(context); // Close new chat page
                            Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: chatId,
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error opening chat: $e'),
                                backgroundColor: _accent,
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            // Avatar with border
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFFEFEFEF),
                                backgroundImage: photoProvider,
                                child: photoProvider == null
                                    ? Icon(Icons.person, color: _muted, size: 26)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // User info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: _text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isOrganizer ? 'Organizer' : 'Player',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: _muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // ❌ Removed arrow icon
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
    );
  }
}