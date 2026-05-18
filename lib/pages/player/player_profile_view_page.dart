import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ViewPlayerProfilePage extends StatefulWidget {
  final String userId;
  const ViewPlayerProfilePage({super.key, required this.userId});

  @override
  State<ViewPlayerProfilePage> createState() => _ViewPlayerProfilePageState();
}

class _ViewPlayerProfilePageState extends State<ViewPlayerProfilePage> {
  // Brand
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  // X-like background palette
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _listenUnread();
  }

  void _listenUnread() {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    FirebaseFirestore.instance
        .collection('PlayerChat')
        .where('participants', arrayContains: me.uid)
        .snapshots()
        .listen((chatSnap) async {
      int total = 0;
      for (final chat in chatSnap.docs) {
        final msgsSnap = await chat.reference
            .collection('PlayerMessage')
            .where('ReceiverID', isEqualTo: me.uid)
            .where('status', isEqualTo: 'sent')
            .get();
        total += msgsSnap.docs.length;
      }
      if (mounted) setState(() => _unread = total);
    });
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
  Navigator.pushNamed(
    context,
    '/chat',
    arguments: chatId,
  );
}

  // ---- helpers (flexible field reading) ----

  String _s(Map<String, dynamic> m, List<String> keys, {String fallback = ''}) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return fallback;
  }

  int _i(Map<String, dynamic> m, List<String> keys, {int fallback = 0}) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is int) return v;
      final s = v.toString().trim();
      final parsed = int.tryParse(s);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  List<String> _list(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;

      if (v is List) {
        return v
            .map((e) => (e ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final s = v.toString().trim();
      if (s.isEmpty || s == '[]' || s == 'null') continue;

      final cleaned = s.replaceAll(RegExp(r'^\[\s*|\s*\]$'), '').trim();
      if (cleaned.isEmpty) continue;

      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

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

  // ---- UI Components ----

  Widget _profileAvatar({
    required ImageProvider? img,
    required double outer,
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
                child: const Icon(Icons.person,
                    color: Colors.black38, size: 36),
              ),
      ),
    );
  }

  Widget _circleButton({
    required double size,
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
  }) {
    return _HoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
          if (badge != null)
            Positioned(
              right: -3,
              top: -6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoBlockX({
    required String age,
    required String city,
    required String gender,
    required List<String> games,
  }) {
    final ageV = age.isEmpty ? "-" : age;
    final cityV = city.isEmpty ? "-" : city;
    final genderV = gender.isEmpty ? "-" : gender;
    final gamesV = games.isEmpty ? "-" : games.join(", ");

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
            v,
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
            child: Row(
              children: [
                Expanded(child: item("Age", ageV)),
                Expanded(child: item("City", cityV, align: TextAlign.center)),
                Expanded(child: item("Gender", genderV, align: TextAlign.right)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _muted.withOpacity(0.55)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: item("Games", gamesV),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const actionBtnSize = 34.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('Player')
                .doc(widget.userId)
                .get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snap.hasData || !snap.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: Text("Player not found")),
                );
              }

              final u = snap.data!.data() ?? {};

              final name = _s(u, ['username', 'Username', 'Name', 'name'],
                  fallback: 'Player');

              final rawPhoto = _s(
                u,
                ['profilePhoto', 'ProfilePhoto', 'photo', 'Photo', 'image', 'Image'],
                fallback: '',
              );

              final avatarProvider = _avatarProviderFromRaw(rawPhoto);

              final age = _i(u, ['age', 'Age'], fallback: 0);
              final city = _s(u, ['city', 'City'], fallback: '');
              final gender = _s(u, ['gender', 'Gender'], fallback: '');
              final games = _list(u, ['games', 'Games', 'Game']);

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
                            _profileAvatar(img: avatarProvider, outer: 80),
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
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: _accent.withOpacity(0.3)),
                                    ),
                                    child: const Text(
                                      'Player',
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
                              badge: _unread > 0 ? "$_unread" : null,
                              onTap: () => _openChat(
                                otherId: widget.userId,
                                otherName: name,
                                otherPhotoRaw: rawPhoto,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _infoBlockX(
                          age: age <= 0 ? "" : "$age",
                          city: city,
                          gender: gender,
                          games: games,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // ✅ Badges Section
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
                          "Badges",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ViewBadgesSection(uid: widget.userId),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // ✅ Performance Section (real dashboards)
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
                          "Performance",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ViewPerformanceTabs(uid: widget.userId),
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
    final canHover = Theme.of(context).platform != TargetPlatform.android &&
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
                      )
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

class _ViewBadgesSection extends StatelessWidget {
  final String uid;

  const _ViewBadgesSection({required this.uid});

  static const Color _muted = Color(0xFF536471);

  static const Map<String, IconData> _iconMap = {
    'diamond': Icons.diamond_rounded,
    'fire': Icons.local_fire_department_rounded,
    'trophy': Icons.emoji_events_rounded,
    'medal': Icons.military_tech_rounded,
  };

  Color _primary(Map<String, dynamic> data) {
    final label = (data['label'] ?? '').toString().toLowerCase();

    if (label.contains('diamond')) return const Color(0xFFFF6B4A);
    if (label.contains('gold') || label.contains('heating')) return const Color(0xFFFFAB40);
    if (label.contains('spark')) return const Color(0xFFFF6B35);
    return const Color(0xFFD4714A);
  }

  Color _secondary(Map<String, dynamic> data) {
    final label = (data['label'] ?? '').toString().toLowerCase();

    if (label.contains('diamond')) return const Color(0xFFEB3D24);
    if (label.contains('gold') || label.contains('heating')) return const Color(0xFFE67E22);
    if (label.contains('spark')) return const Color(0xFFEB3D24);
    return const Color(0xFFB84A2E);
  }

  String _subLabel(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();

    if (type == 'win_rate_rank') return 'All Games';
    if (type == 'streak') {
      final g = (data['game'] ?? '').toString();
      if (g == 'lol') return 'League of Legends';
      if (g == 'pubg') return 'PUBG';
      if (g == 'dota2') return 'Dota 2';
      return g.isEmpty ? 'Game' : g;
    }
    if (type == 'spark_mvp') {
      return (data['teamName'] ?? 'Team').toString();
    }

    return 'Badge';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Player')
          .doc(uid)
          .collection('badges')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];

        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (docs.isEmpty) {
          return SizedBox(
            height: 70,
            child: Center(
              child: Text(
                'No badges yet.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final label = (data['label'] ?? 'Badge').toString();
              final iconType = (data['iconType'] ?? 'medal').toString();

              final primaryColor = _primary(data);
              final secondaryColor = _secondary(data);
              final icon = _iconMap[iconType] ?? Icons.star_rounded;

              return SizedBox(
                width: 90,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(80, 88),
                      painter: _HexBadgePainter(
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                      ),
                      child: SizedBox(
                        width: 80,
                        height: 88,
                        child: Align(
                          alignment: const Alignment(0, -0.10),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 34,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subLabel(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF536471),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// VIEW MODE PERFORMANCE TABS (LOL / PUBG / DOTA2)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ViewPerformanceTabs extends StatefulWidget {
  final String uid;
  const _ViewPerformanceTabs({required this.uid});

  @override
  State<_ViewPerformanceTabs> createState() => _ViewPerformanceTabsState();
}


class _ViewPerformanceTabsState extends State<_ViewPerformanceTabs> {
  int _selectedIndex = 0;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  Future<List<String>> _gamesWithMatches(
    String uid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final ids = docs.map((d) => d.id.toLowerCase().trim()).toSet();
    final result = <String>[];

    Future<bool> hasMatches(String gameId) async {
      final snap = await FirebaseFirestore.instance
          .collection('Player')
          .doc(uid)
          .collection('linkedGames')
          .doc(gameId)
          .collection('matches')
          .limit(1)
          .get();

      return snap.docs.isNotEmpty;
    }

    if ((ids.contains('lol') ||
            ids.contains('leagueoflegends') ||
            ids.contains('league of legends')) &&
        await hasMatches('lol')) {
      result.add('lol');
    }

    if (ids.contains('pubg') && await hasMatches('pubg')) {
      result.add('pubg');
    }

    if ((ids.contains('dota2') ||
            ids.contains('dota') ||
            ids.contains('dota 2')) &&
        await hasMatches('dota2')) {
      result.add('dota2');
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final linkedRef = FirebaseFirestore.instance
        .collection('Player')
        .doc(widget.uid)
        .collection('linkedGames');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: linkedRef.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];

        return FutureBuilder<List<String>>(
          future: _gamesWithMatches(widget.uid, docs),
          builder: (context, gameSnap) {
            if (gameSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final supported = gameSnap.data ?? [];

            if (supported.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No connected games for this player.',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            _selectedIndex = _selectedIndex.clamp(0, supported.length - 1);
            final selected = supported[_selectedIndex];

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFCFCFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: Column(
                children: [
                  Container(
                    height: 44,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: _line, width: 1),
                      ),
                    ),
                    child: Row(
                      children: List.generate(supported.length, (i) {
                        final id = supported[i];
                        final isSelected = i == _selectedIndex;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : _bg,
                              border: Border(
                                right: const BorderSide(
                                  color: _line,
                                  width: 0.5,
                                ),
                                bottom: isSelected
                                    ? const BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            child: Text(
                              id.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? _accent
                                    : _text.withOpacity(0.6),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _ViewGameDashboard(
                      uid: widget.uid,
                      gameId: selected,
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
}

class _ViewGameDashboard extends StatelessWidget {
  final String uid;
  final String gameId;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  const _ViewGameDashboard({required this.uid, required this.gameId});

  bool get _isLol {
    final id = gameId.toLowerCase().trim();
    return id == 'lol' || id == 'leagueoflegends' || id == 'league of legends';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 230, // bigger than placeholder
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: _isLol
          ? _LolRadarDashboard(uid: uid, accent: _accent, muted: _muted)
          : (gameId.toLowerCase().trim() == 'pubg'
              ? _PubgRadarDashboard(uid: uid, accent: _accent, muted: _muted)
              : _DotaRadarDashboard(uid: uid, accent: _accent, muted: _muted)),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LOL RADAR (same colab normalization)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LolRadarDashboard extends StatelessWidget {
  final String uid;
  final Color accent;
  final Color muted;

  const _LolRadarDashboard({
    required this.uid,
    required this.accent,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('Player')
        .doc(uid)
        .collection('linkedGames')
        .doc('lol')
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .limit(20);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return Center(
            child: Text('No LOL matches yet.',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
          );
        }

        double wins = 0;
        double kda = 0, cs = 0, gold = 0, dmg = 0, kp = 0, vision = 0;

        for (final d in docs) {
          final m = d.data();
          if (m['win'] == true) wins += 1;

          kda += _num(m['kda']);
          cs += _num(m['csPerMin']);
          gold += _num(m['goldPerMin']);
          dmg += _num(m['damagePerMin']);

          final kpRaw = _num(m['kp']);
          kp += (kpRaw <= 1.01) ? (kpRaw * 100.0) : kpRaw;

          vision += _num(m['visionPerMin']);
        }

        final n = docs.length.toDouble();
        final winRate = wins / n;
        final avgKda = kda / n;
        final avgCs = cs / n;
        final avgGold = gold / n;
        final avgDmg = dmg / n;
        final avgKp = kp / n;
        final avgVision = vision / n;

        final vWin = winRate.clamp(0.0, 1.0);
        final vKda = (avgKda / 4.0).clamp(0.0, 1.0);
        final vCs = (avgCs / 9.0).clamp(0.0, 1.0);
        final vGold = (avgGold / 450.0).clamp(0.0, 1.0);
        final vDmg = (avgDmg / 700.0).clamp(0.0, 1.0);
        final vKp = (avgKp / 70.0).clamp(0.0, 1.0);
        final vVision = (avgVision / 1.5).clamp(0.0, 1.0);

        return _RadarStar(
          labels: const [
            'Win Rate',
            'KDA',
            'CS/min',
            'Gold/min',
            'Damage/min',
            'KP%',
            'Vision/min',
          ],
          values: [vWin, vKda, vCs, vGold, vDmg, vKp, vVision],
          accent: accent,
          muted: muted,
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PUBG RADAR
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PubgRadarDashboard extends StatelessWidget {
  final String uid;
  final Color accent;
  final Color muted;

  const _PubgRadarDashboard({
    required this.uid,
    required this.accent,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('Player')
        .doc(uid)
        .collection('linkedGames')
        .doc('pubg')
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .limit(20);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return Center(
            child: Text('No PUBG matches yet.',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
          );
        }

        double wins = 0;
        double kills = 0, assists = 0, damage = 0, placement = 0, score = 0;

        for (final d in docs) {
          final m = d.data();
          if (m['win'] == true) wins += 1;
          kills += _num(m['kills']);
          assists += _num(m['assists']);
          damage += _num(m['damage']);
          placement += _num(m['placement']);
          score += _num(m['performanceScore']);
        }

        final n = docs.length.toDouble();
        final winRate = wins / n;
        final avgKills = kills / n;
        final avgAssists = assists / n;
        final avgDamage = damage / n;
        final avgPlacement = placement / n;
        final avgScore = score / n;

        final vWin = winRate.clamp(0.0, 1.0);
        final vKills = (avgKills / 10.0).clamp(0.0, 1.0);
        final vAssists = (avgAssists / 5.0).clamp(0.0, 1.0);
        final vDmg = (avgDamage / 1500.0).clamp(0.0, 1.0);
        final vPlace =
            (1.0 - ((avgPlacement - 1.0) / 99.0)).clamp(0.0, 1.0);
        final vScore = (avgScore / 100.0).clamp(0.0, 1.0);

        return _RadarStar(
          labels: const [
            'Win Rate',
            'Kills',
            'Assists',
            'Damage',
            'Placement',
            'Score',
          ],
          values: [vWin, vKills, vAssists, vDmg, vPlace, vScore],
          accent: accent,
          muted: muted,
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DOTA2 RADAR (based on your saved fields)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _DotaRadarDashboard extends StatelessWidget {
  final String uid;
  final Color accent;
  final Color muted;

  const _DotaRadarDashboard({
    required this.uid,
    required this.accent,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('Player')
        .doc(uid)
        .collection('linkedGames')
        .doc('dota2')
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .limit(20);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return Center(
            child: Text('No Dota matches yet.',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
          );
        }

        double wins = 0;
        double kda = 0, kills = 0, deaths = 0, assists = 0, gpm = 0, xpm = 0, lh = 0;

        for (final d in docs) {
          final m = d.data();
          if (m['win'] == true) wins += 1;
          kda += _num(m['kda']);
          kills += _num(m['kills']);
          deaths += _num(m['deaths']);
          assists += _num(m['assists']);
          gpm += _num(m['gpm']);
          xpm += _num(m['xpm']);
          lh += _num(m['lastHits']);
        }

        final n = docs.length.toDouble();
        final winRate = wins / n;
        final avgKda = kda / n;
        final avgKills = kills / n;
        final avgDeaths = deaths / n;
        final avgAssists = assists / n;
        final avgGpm = gpm / n;
        final avgXpm = xpm / n;
        final avgLh = lh / n;

        // reasonable normalizations (0..1)
        final vWin = winRate.clamp(0.0, 1.0);
        final vKda = (avgKda / 5.0).clamp(0.0, 1.0);
        final vKills = (avgKills / 15.0).clamp(0.0, 1.0);
        final vDeaths = (1.0 - (avgDeaths / 15.0)).clamp(0.0, 1.0); // lower deaths better
        final vAssists = (avgAssists / 20.0).clamp(0.0, 1.0);
        final vGpm = (avgGpm / 700.0).clamp(0.0, 1.0);
        final vXpm = (avgXpm / 750.0).clamp(0.0, 1.0);
        final vLh = (avgLh / 250.0).clamp(0.0, 1.0);

        return _RadarStar(
          labels: const [
            'Win Rate',
            'KDA',
            'Kills',
            'Deaths',
            'Assists',
            'GPM',
            'XPM',
            'Last Hits',
          ],
          values: [vWin, vKda, vKills, vDeaths, vAssists, vGpm, vXpm, vLh],
          accent: accent,
          muted: muted,
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RADAR STAR (white bg, orange polygon)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RadarStar extends StatelessWidget {
  final List<String> labels;
  final List<double> values; // 0..1
  final Color accent;
  final Color muted;

  const _RadarStar({
    required this.labels,
    required this.values,
    required this.accent,
    required this.muted,
  }) : assert(labels.length == values.length);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarStarPainter(
        labels: labels,
        values: values,
        accent: accent,
        muted: muted,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RadarStarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values; // 0..1
  final Color accent;
  final Color muted;

  _RadarStarPainter({
    required this.labels,
    required this.values,
    required this.accent,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;

    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = min(size.width, size.height) * 0.42;

    final gridPaint = Paint()
      ..color = const Color(0xFFCFD9DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = const Color(0xFFCFD9DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const rings = 5;
    for (int r = 1; r <= rings; r++) {
      final rr = radius * (r / rings);
      final ringPts = List.generate(n, (i) {
        final a = _angle(i, n);
        return Offset(center.dx + rr * cos(a), center.dy + rr * sin(a));
      });
      canvas.drawPath(_polyPath(ringPts), gridPaint);
    }

    for (int i = 0; i < n; i++) {
      final a = _angle(i, n);
      final p =
          Offset(center.dx + radius * cos(a), center.dy + radius * sin(a));
      canvas.drawLine(center, p, axisPaint);
    }

    final pts = List.generate(n, (i) {
      final v = values[i].clamp(0.0, 1.0);
      final rr = radius * v;
      final a = _angle(i, n);
      return Offset(center.dx + rr * cos(a), center.dy + rr * sin(a));
    });

    final fill = Paint()
      ..color = accent.withOpacity(0.20)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = accent.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(_polyPath(pts), fill);
    canvas.drawPath(_polyPath(pts), stroke);

    final dot = Paint()..color = accent.withOpacity(0.95);
    final dotStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final p in pts) {
      canvas.drawCircle(p, 4.2, dot);
      canvas.drawCircle(p, 4.2, dotStroke);
    }

    for (int i = 0; i < n; i++) {
      final a = _angle(i, n);
      final lp = Offset(center.dx + (radius + 20) * cos(a),
          center.dy + (radius + 20) * sin(a));

      final textSpan = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: muted,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);

      tp.paint(canvas, Offset(lp.dx - tp.width / 2, lp.dy - tp.height / 2));
    }
  }

  double _angle(int i, int n) => -pi / 2 + (2 * pi * i / n);

  Path _polyPath(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant _RadarStarPainter oldDelegate) {
    if (oldDelegate.labels.length != labels.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return oldDelegate.accent != accent || oldDelegate.muted != muted;
  }
}
Path _hexPath(Offset center, double r, {double rotation = 0}) {
  final path = Path();

  for (int i = 0; i < 6; i++) {
    final angle = rotation + (pi / 3) * i;
    final x = center.dx + r * cos(angle);
    final y = center.dy + r * sin(angle);

    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }

  path.close();
  return path;
}
class _HexBadgePainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  const _HexBadgePainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R = size.width * 0.46;
    final center = Offset(cx, cy);

    final shadowPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawPath(
      _hexPath(center, R * 0.96, rotation: -pi / 6),
      shadowPaint,
    );

    final outerPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: R))
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      _hexPath(center, R, rotation: -pi / 6),
      outerPaint,
    );

    final ringPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(
      _hexPath(center, R * 0.80, rotation: -pi / 6),
      ringPaint,
    );

    final innerPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withOpacity(0.85),
          secondaryColor.withOpacity(0.85),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: R * 0.78))
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      _hexPath(center, R * 0.78, rotation: -pi / 6),
      innerPaint,
    );

    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final shinePath = Path()
      ..moveTo(cx - R * 0.5, cy - R * 0.55)
      ..cubicTo(
        cx - R * 0.1,
        cy - R * 0.85,
        cx + R * 0.3,
        cy - R * 0.75,
        cx + R * 0.45,
        cy - R * 0.40,
      )
      ..cubicTo(
        cx + R * 0.20,
        cy - R * 0.15,
        cx - R * 0.25,
        cy - R * 0.10,
        cx - R * 0.5,
        cy - R * 0.20,
      )
      ..close();

    canvas.drawPath(shinePath, shinePaint);

    canvas.drawPath(
      _hexPath(center, R, rotation: -pi / 6),
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_HexBadgePainter old) {
    return old.primaryColor != primaryColor ||
        old.secondaryColor != secondaryColor;
  }
}
double _num(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
