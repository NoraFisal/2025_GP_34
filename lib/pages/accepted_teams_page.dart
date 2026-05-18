// lib/pages/team/accepted_teams_page.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'view_team_page.dart';

class AcceptedTeamsPage extends StatefulWidget {
  const AcceptedTeamsPage({super.key});

  @override
  State<AcceptedTeamsPage> createState() => _AcceptedTeamsPageState();
}

class _AcceptedTeamsPageState extends State<AcceptedTeamsPage> {
  static const Color _accent = Color(0xFFEB3D24);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _cardBg = Color(0xFFFFFCFB);

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ImageProvider? _decodeTeamImage(dynamic v) {
    if (v == null) return null;

    try {
      if (v is Blob) return MemoryImage(v.bytes);
      if (v is Uint8List) return MemoryImage(v);
      if (v is List<int>) return MemoryImage(Uint8List.fromList(v));

      if (v is String) {
        var s = v.trim();
        if (s.isEmpty) return null;

        if (s.startsWith('http://') || s.startsWith('https://')) {
          return NetworkImage(s);
        }

        if (s.startsWith('data:image')) {
          final idx = s.indexOf('base64,');
          if (idx != -1) s = s.substring(idx + 7);
        }

        return MemoryImage(base64Decode(s));
      }
    } catch (_) {}

    return null;
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        cursorColor: _accent,
        onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        style: const TextStyle(
          fontFamily: 'Inter',
          color: _text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search teams...',
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _muted,
            size: 22,
          ),
          suffixIcon: null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _muted,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Explore Teams',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _accent,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Team')
                    .where('status', isEqualTo: 'Accepted')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }

                  var docs = snapshot.data!.docs.toList();

                  docs.sort((a, b) {
                    final aT = a.data()['createdAt'] as Timestamp?;
                    final bT = b.data()['createdAt'] as Timestamp?;
                    if (aT == null || bT == null) return 0;
                    return bT.compareTo(aT);
                  });

                  if (_search.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data();
                      final name = (data['name'] ??
                              data['teamName'] ??
                              data['TeamName'] ??
                              '')
                          .toString()
                          .toLowerCase();

                      return name.contains(_search);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(
  child: Text(
    'No teams match your search.',
    style: TextStyle(
      fontFamily: 'Inter',
      color: _muted,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  ),
);
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;

                      final crossAxisCount = w < 430
                          ? 2
                          : w < 760
                              ? 3
                              : w < 1100
                                  ? 4
                                  : 5;

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: docs.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 178,
                        ),
                        itemBuilder: (context, i) {
                          final data = docs[i].data();
                          final teamId = docs[i].id;

                          final name = (data['name'] ??
                                  data['teamName'] ??
                                  data['TeamName'] ??
                                  'Team')
                              .toString();

                          final rawLogo = data['logoUrl'] ??
                              data['Logo'] ??
                              data['logo'] ??
                              data['teamLogo'];

                          return _TeamExploreCard(
                            name: name,
                            imageProvider: _decodeTeamImage(rawLogo),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ViewTeamPage(teamId: teamId),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamExploreCard extends StatelessWidget {
  final String name;
  final ImageProvider? imageProvider;
  final VoidCallback onTap;

  const _TeamExploreCard({
    required this.name,
    required this.imageProvider,
    required this.onTap,
  });

  static const Color _accent = Color(0xFFEB3D24);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _cardBg = Color(0xFFFFFCFB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: _accent, width: 2.5),
                      image: imageProvider != null
                          ? DecorationImage(
                              image: imageProvider!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageProvider == null
                        ? const Icon(
                            Icons.groups_rounded,
                            color: _muted,
                            size: 32,
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),

              
            ],
          ),
        ),
      ),
    );
  }
}