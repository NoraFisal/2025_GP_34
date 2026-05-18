import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/chat/unified_chat_service.dart';
import '../team/create_team_page.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  String _query = '';
  final _auth = FirebaseAuth.instance;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _chip = Color(0xFFF0F3F4);
  static const Color _line = Color(0xFFCFD9DE);

  
  Future<void> _showNoLinkDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                    Icons.link_off_rounded,
                    color: _accent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                const Text(
                  'No Linked Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1419),
                  ),
                ),
                const SizedBox(height: 8),

                // Message
                const Text(
                  'You must link a game account before creating a team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF536471),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

             
                SizedBox(
                  width: 100,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'OK',
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
          ),
        );
      },
    );
  }

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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF363435),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
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

          // ===== Create Team Button =====
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Player')
                .doc(currentUid)
                .collection('linkedGames')
                .limit(1)
                .snapshots(),
            builder: (context, linkedSnap) {
              final isLinked = (linkedSnap.data?.docs.isNotEmpty) == true;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Opacity(
                  opacity: isLinked ? 1.0 : 0.45,
                  child: InkWell(
                    
                    onTap: () {
                      if (!isLinked) {
                        _showNoLinkDialog(context);
                        return;
                      }
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
                              border: Border.all(
                                color: isLinked ? _accent : _muted,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  (isLinked ? _accent : _muted).withOpacity(0.1),
                              child: Icon(
                                Icons.group_add,
                                color: isLinked ? _accent : _muted,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Team',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isLinked ? _text : _muted,
                                  ),
                                ),
                                if (!isLinked) ...[
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Link a game account first',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

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
                          try {
                            final chatId =
                                await UnifiedChatService.createPrivateChat(uid);
                            if (!mounted) return;
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
                                    ? Icon(Icons.person, color: _muted, size: 26)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
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
