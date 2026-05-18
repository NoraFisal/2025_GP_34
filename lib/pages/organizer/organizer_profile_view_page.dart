import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/player/image_helper.dart';
import 'view_tournament_page.dart';

class ViewOrganizerProfilePage extends StatefulWidget {
  const ViewOrganizerProfilePage({super.key, required this.organizerId});

  final String organizerId;

  @override
  State<ViewOrganizerProfilePage> createState() =>
      _ViewOrganizerProfilePageState();
}

class _ViewOrganizerProfilePageState extends State<ViewOrganizerProfilePage> {
  String get organizerId => widget.organizerId;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  ImageProvider? _avatarProviderFromRaw(String raw) {
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) {
      return NetworkImage(s);
    }

    try {
      return MemoryImage(base64Decode(s));
    } catch (_) {
      return null;
    }
  }

  Widget _profileAvatar({
    required ImageProvider? img,
    required double outer,
    required double inner,
  }) {
    return Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: img != null
            ? Image(image: img, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFFEFEFEF),
                child: const Icon(
                  Icons.person,
                  color: Colors.black38,
                  size: 36,
                ),
              ),
      ),
    );
  }

  Widget _infoBlock(String name, String info, String email) {
    const label = TextStyle(
      color: _text,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1,
    );
    const value = TextStyle(
      color: _text,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );

    Widget item(String l, String v, {TextAlign align = TextAlign.left}) {
      return Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : align == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(l, style: label, textAlign: align),
          const SizedBox(height: 6),
          Text(
            v.isEmpty ? '-' : v,
            style: value,
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [Expanded(child: item("Email", email))]),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _muted.withOpacity(0.55)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: item("Bio", info),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat({
    required String otherId,
    required String otherName,
    required String otherPhotoRaw,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final db = FirebaseFirestore.instance;

    final existing = await db
        .collection('Chat')
        .where('type', isEqualTo: 'private')
        .where('participants', arrayContains: me.uid)
        .get();

    String? chatId;
    for (final doc in existing.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(otherId)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final newChat = await db.collection('Chat').add({
        'type': 'private',
        'participants': [me.uid, otherId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'isEmpty': true,
      });
      chatId = newChat.id;
    }

    if (!mounted) return;
    Navigator.pushNamed(context, '/chat', arguments: chatId);
  }

  @override
  Widget build(BuildContext context) {
    const actionBtnSize = 34.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('Organizer')
                .doc(organizerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: Text("Organizer not found")),
                );
              }

              final data = snapshot.data!.data() ?? {};
              final name = (data['Name'] ?? 'Organizer').toString();
              final info = (data['Info'] ?? '').toString();
              final email = (data['Email'] ?? '').toString();
              final photoData = (data['ProfilePhoto'] ?? '').toString();

              final avatarProvider = _avatarProviderFromRaw(photoData);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _HoverTap(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF536471),
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Profile Header Card
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFCFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _profileAvatar(
                              img: avatarProvider,
                              outer: 80,
                              inner: 70,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: _text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _accent.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Text(
                                      'Organizer',
                                      style: TextStyle(
                                        color: _accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _circleButton(
                              size: actionBtnSize,
                              icon: Icons.chat_bubble_outline_rounded,
                              onTap: () => _openChat(
                                otherId: organizerId,
                                otherName: name,
                                otherPhotoRaw: photoData,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _infoBlock(name, info, email),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tournaments Section
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFCFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Tournaments",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTournamentsGrid(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _circleButton({
    required double size,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _HoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _accent,
          border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }

  Widget _buildTournamentsGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Tournament')
          .where('organizerID', isEqualTo: organizerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 48,
                    color: _muted.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tournaments yet',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return Padding(
                padding: EdgeInsets.only(
                  right: index < docs.length - 1 ? 10 : 0,
                ),
                child: _TournamentCardX(
                  tournamentId: docs[index].id,
                  title: (data['Title'] ?? data['title'] ?? 'Tournament')
                      .toString(),
                  timeText: (data['time'] ?? '10:00 PM').toString(),
                  dateText: (data['date'] ?? '17/11/2026').toString(),
                  imageBase64: (data['image'] ?? '').toString(),
                  game: (data['game'] ?? '').toString(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TournamentCardX extends StatelessWidget {
  final String tournamentId;
  final String title;
  final String timeText;
  final String dateText;
  final String imageBase64;
  final String game;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _line = Color(0xFFCFD9DE);

  const _TournamentCardX({
    required this.tournamentId,
    required this.title,
    required this.timeText,
    required this.dateText,
    this.imageBase64 = '',
    this.game = '',
  });

  String _getGameLogo(String gameName) {
    final g = gameName.toLowerCase();

    if (g.contains('pubg')) return 'assets/images/pubg.png';
    if (g.contains('lol') || g.contains('league')) return 'assets/images/lol.png';
    if (g.contains('valorant')) return 'assets/images/valorant.png';
    if (g.contains('call of duty') || g.contains('cod')) return 'assets/images/cod.png';
    if (g.contains('fortnite')) return 'assets/images/fortnite.png';
    if (g.contains('dota')|| g.contains('dota2')) {
    return 'assets/images/dota2.png';
  }

    return '';
  }

  Widget _gameBadge() {
    final logoPath = _getGameLogo(game);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: logoPath.isEmpty
              ? const Icon(
                  Icons.sports_esports_rounded,
                  color: _accent,
                  size: 16,
                )
              : Image.asset(
                  logoPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sports_esports_rounded,
                    color: _accent,
                    size: 16,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HoverScale(
      scale: 1.03,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewTournamentPage(
              tournamentId: tournamentId,
            ),
          ),
        );
      },
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF2F2F2F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              if (imageBase64.isNotEmpty)
                Positioned.fill(
                  child: Image.memory(
                    base64Decode(imageBase64),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.70),
                        Colors.black.withOpacity(0.30),
                        Colors.black.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _gameBadge(),

                    const SizedBox(height: 8),

                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black87,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            timeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                              shadows: [
                                Shadow(
                                  blurRadius: 5,
                                  color: Colors.black87,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                              shadows: [
                                Shadow(
                                  blurRadius: 5,
                                  color: Colors.black87,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const _HoverScale({required this.child, this.onTap, this.scale = 1.03});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final canHover =
        Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;

    Widget content = AnimatedScale(
      scale: (_hover && canHover) ? widget.scale : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    );

    content = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: content,
    );

    if (widget.onTap != null) {
      content = GestureDetector(onTap: widget.onTap, child: content);
    }

    return content;
  }
}

class _HoverTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _HoverTap({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<_HoverTap> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final canHover =
        Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;

    final scale = _down ? 0.98 : (_hover && canHover ? 1.02 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: (_hover && canHover)
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
