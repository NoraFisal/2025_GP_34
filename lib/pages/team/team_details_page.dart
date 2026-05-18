// lib/pages/team/team_details_page.dart

import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'edit_team_page.dart';
import '../../services/chat/unified_chat_service.dart';

class TeamDetailsPage extends StatelessWidget {
  final String teamId;
  final String? teamName;

  const TeamDetailsPage({
    super.key,
    required this.teamId,
    this.teamName,
  });

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color(0xFF363435);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  ImageProvider<Object>? _imageProvider(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http')) return NetworkImage(v);

    try {
      final cleaned = v.contains(',') ? v.split(',').last : v;
      return MemoryImage(base64Decode(cleaned));
    } catch (_) {
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _teamStream() {
    return FirebaseFirestore.instance.collection('Team').doc(teamId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream() {
    return FirebaseFirestore.instance
        .collection('Team')
        .doc(teamId)
        .collection('Members')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _teamStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _accent));
            }

            final doc = snap.data;
            if (doc == null || !doc.exists) {
              return const Center(
                child: Text(
                  'Team not found',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            final data = doc.data() ?? {};
            final name = (data['name'] ?? '').toString();
            final description = (data['description'] ?? '').toString();
            final status = (data['status'] ?? '').toString().trim();
            final winRate = (data['winRate'] ?? 0).toDouble().clamp(0.0, 100.0);

            final statusLabel = status.isEmpty
                ? 'Active'
                : (status[0].toUpperCase() + status.substring(1).toLowerCase());

            final logoRaw = (data['logoUrl'] ?? '').toString();
            final logoProvider = _imageProvider(logoRaw);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back Button
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
                              img: logoProvider,
                              outer: 80,
                              inner: 70,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? (teamName ?? 'Team Name') : name,
                                    style: const TextStyle(
                                      color: _text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _accent.withOpacity(0.3)),
                                    ),
                                    child: const Text(
                                      'Team',
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
                            Row(
                              children: [
                                _circleButton(
                                  size: 34,
                                  icon: Icons.edit_rounded,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditTeamPage(teamId: teamId),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                _circleButton(
                                  size: 34,
                                  icon: Icons.chat_bubble_outline_rounded,
                                  onTap: () async {
                                    try {
                                      final membersSnap = await FirebaseFirestore.instance
                                          .collection('Team')
                                          .doc(teamId)
                                          .collection('Members')
                                          .get();

                                      final members = membersSnap.docs.map((d) => d.id).toList();

                                      final chatSnap = await FirebaseFirestore.instance
                                          .collection('Chat')
                                          .where('type', isEqualTo: 'team')
                                          .where('status', isEqualTo: 'active')  
                                          .where('teamId', isEqualTo: teamId)
                                          .limit(1)
                                          .get();

                                      final chatId = chatSnap.docs.first.id;

                                      if (context.mounted) {
                                        Navigator.pushNamed(context, '/chat', arguments: chatId);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to open team chat: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _infoBlock(
                          description: description,
                          statusLabel: statusLabel,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Winrate Section
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
                          "Team Winrate",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(200, 200),
                                  painter: _DonutPainter(
                                    percent: (winRate / 100.0).clamp(0.0, 1.0),
                                    thickness: 28,
                                    accent: _accent,
                                    baseColor: _accent.withOpacity(0.25),
                                  ),
                                ),
                                Text(
                                  '${winRate.round()}%',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Members Section
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
                          "Team Members",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _membersStream(),
                          builder: (context, memSnap) {
                            if (!memSnap.hasData) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 20, bottom: 20),
                                  child: CircularProgressIndicator(color: _accent),
                                ),
                              );
                            }
                            return _membersGrid(memSnap.data!.docs);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
                child: const Icon(Icons.groups_2_outlined, color: Colors.black38, size: 36),
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

  Widget _infoBlock({
    required String description,
    required String statusLabel,
  }) {
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
            child: Row(
              children: [
                Expanded(child: item("Status", statusLabel)),
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
              child: item("Description", description),
            ),
          ),
        ],
      ),
    );
  }

  Widget _membersGrid(List<QueryDocumentSnapshot<Map<String, dynamic>>> memberDocs) {
    const roles = ['top', 'jungle', 'middle', 'bottom', 'support'];

    final byRole = <String, String>{};
    for (final d in memberDocs) {
      final role = (d.data()['role'] ?? '').toString().toLowerCase().trim();
      if (role.isNotEmpty) byRole[role] = d.id;
    }

    final orderedUids = <String>[];
    for (final r in roles) {
      final uid = byRole[r];
      if (uid != null) orderedUids.add(uid);
    }
    for (final d in memberDocs) {
      if (!orderedUids.contains(d.id)) orderedUids.add(d.id);
    }

    if (orderedUids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: _muted.withOpacity(0.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'No members yet',
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

    final memberCards = orderedUids.map((uid) {
  String role = '';
  for (final d in memberDocs) {
    if (d.id == uid) {
      role = (d.data()['role'] ?? '').toString();
      break;
    }
  }

  return SizedBox(
    width: 100,
    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Player').doc(uid).snapshots(),
      builder: (context, pSnap) {
        final pd = pSnap.data?.data() ?? {};
        final playerName = (pd['Name'] ?? '').toString().trim();
        final photo = (pd['ProfilePhoto'] ?? '').toString();
        final provider = _imageProvider(photo);

        return Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accent, width: 2.8),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: provider == null
                    ? const Icon(Icons.person, color: Colors.black38, size: 32)
                    : Image(image: provider, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                role.isEmpty ? 'MEMBER' : role.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              playerName.isEmpty ? 'Player' : playerName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        );
      },
    ),
  );
}).toList();

return Column(
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: memberCards.take(2).map((card) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: card,
        );
      }).toList(),
    ),
    const SizedBox(height: 20),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: memberCards.skip(2).take(3).map((card) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: card,
        );
      }).toList(),
    ),
  ],
);
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;
  final double thickness;
  final Color accent;
  final Color baseColor;

  _DonutPainter({
    required this.percent,
    required this.thickness,
    required this.accent,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (s / 2) - (thickness / 2);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = baseColor;

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = accent;

    canvas.drawCircle(center, radius, basePaint);

    final start = -math.pi / 2;
    final sweep = 2 * math.pi * percent.clamp(0.0, 1.0);

    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.thickness != thickness ||
        oldDelegate.accent != accent ||
        oldDelegate.baseColor != baseColor;
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
