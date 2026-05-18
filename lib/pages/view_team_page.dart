import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewTeamPage extends StatelessWidget {
  final String teamId;

  const ViewTeamPage({super.key, required this.teamId});

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Team').doc(teamId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: _bg,
            body: const Center(child: CircularProgressIndicator(color: _accent)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: _bg,
            body: const Center(
              child: Text(
                'Team not found',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final status = (data['status'] ?? '').toString().trim();

        final statusLabel = status.isEmpty
            ? 'Active'
            : (status[0].toUpperCase() + status.substring(1).toLowerCase());

        final logoRaw = (data['logoUrl'] ?? '').toString();
        final logoProvider = _imageProvider(logoRaw);

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: SingleChildScrollView(
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
                                    name.isEmpty ? 'Team Name' : name,
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
                        _buildTeamMembers(teamId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _buildTeamMembers(String teamId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('Team')
          .doc(teamId)
          .collection('Members')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 20, bottom: 20),
              child: CircularProgressIndicator(color: _accent),
            ),
          );
        }

        final memberDocs = snapshot.data!.docs;

        if (memberDocs.isEmpty) {
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

        const roles = ['top', 'jungle', 'middle', 'bottom', 'support'];

        final byRole = <String, String>{};
        for (final d in memberDocs) {
          final role = (d.data() as Map)['role']?.toString().toLowerCase().trim() ?? '';
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

        final ids = orderedUids.toList();

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('Player')
              .where(FieldPath.documentId, whereIn: ids)
              .get(),
          builder: (context, playerSnap) {
            if (!playerSnap.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 10),
                  child: CircularProgressIndicator(color: _accent),
                ),
              );
            }

            final playerMap = <String, Map<String, dynamic>>{};
            for (final doc in playerSnap.data!.docs) {
              playerMap[doc.id] = doc.data() as Map<String, dynamic>;
            }

            return Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 28,
                runSpacing: 20,
                children: ids.map((uid) {
                  String role = '';
                  for (final d in memberDocs) {
                    if (d.id == uid) {
                      role = (d.data() as Map)['role']?.toString() ?? '';
                      break;
                    }
                  }

                  final pd = playerMap[uid] ?? {};
                  final playerName = (pd['Name'] ?? '').toString().trim();
                  final photo = (pd['ProfilePhoto'] ?? '').toString();
                  final provider = _imageProvider(photo);

                  return SizedBox(
                    width: 100,
                    child: Column(
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
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
                          softWrap: true,
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
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
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