// lib/pages/organizer/my_tournaments_page.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'view_tournament_page.dart';

class MyTournamentsPage extends StatefulWidget {
  const MyTournamentsPage({super.key});

  @override
  State<MyTournamentsPage> createState() => _MyTournamentsPageState();
}

class _MyTournamentsPageState extends State<MyTournamentsPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  Stream<List<Map<String, dynamic>>> _getMyTournaments() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance.collection('Tournament').snapshots().map((
      snapshot,
    ) {
      final tournaments = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Check multiple possible field names for organizer ID
        final organizerId =
            data['organizerID'] ??
            data['organizerId'] ??
            data['OrganizerID'] ??
            data['OrganizerId'] ??
            '';

        // Only include tournaments created by current user
        if (organizerId == currentUser!.uid) {
          tournaments.add({
            'id': doc.id,
            'title': data['Title'] ?? data['title'] ?? 'Tournament',
            'time': data['time'] ?? '10:00 PM',
            'date': data['date'] ?? '17/11/2026',
            'image': data['image'] ?? '',
            'game': data['game'] ?? '',
            'createdAt': data['createdAt'],
          });
        }
      }

      // Sort by creation date (newest first)
      tournaments.sort((a, b) {
        final aTime =
            (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bTime =
            (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      return tournaments;
    });
  }

  ImageProvider<Object>? _tournamentImageProvider(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    if (s.startsWith('http')) {
      return NetworkImage(s);
    }

    try {
      final cleaned = s.contains(',') ? s.split(',').last : s;
      return MemoryImage(base64Decode(cleaned));
    } catch (_) {
      return null;
    }
  }

  String _getGameLogo(String gameName) {
    final lowerGame = gameName.toLowerCase();

    if (lowerGame.contains('pubg')) {
      return 'assets/images/pubg.png';
    }

    if (lowerGame.contains('lol') || lowerGame.contains('league of legends')) {
      return 'assets/images/lol.png';
    }

    if (lowerGame.contains('valorant')) {
      return 'assets/images/valorant.png';
    }

    if (lowerGame.contains('call of duty') || lowerGame.contains('cod')) {
      return 'assets/images/cod.png';
    }

    if (lowerGame.contains('fortnite')) {
      return 'assets/images/fortnite.png';
    }
      if (lowerGame.contains('dota')|| lowerGame.contains('dota2')) {
    return 'assets/images/dota2.png';
  }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Tournaments',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _accent,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getMyTournaments(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _accent),
              );
            }

            if (!snap.hasData || snap.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 80,
                      color: _muted.withOpacity(0.4),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Tournaments Yet',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first tournament to get started',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final tournaments = snap.data!;

            return ListView.separated(
              itemCount: tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final tournament = tournaments[i];
                return _tournamentCard(
                  tournamentId: tournament['id'],
                  title: tournament['title'],
                  timeText: tournament['time'],
                  dateText: tournament['date'],
                  imageBase64: tournament['image'],
                  game: tournament['game'],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _tournamentCard({
    required String tournamentId,
    required String title,
    required String timeText,
    required String dateText,
    required String imageBase64,
    required String game,
  }) {
    final img = imageBase64.isNotEmpty
        ? _tournamentImageProvider(imageBase64)
        : null;

    return _HoverTap(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewTournamentPage(tournamentId: tournamentId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image
            if (img != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: img, fit: BoxFit.cover),

                      // Dark gradient for text visibility
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.65),
                              Colors.black.withOpacity(0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Tournament Image Container with Logo Badge
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Stack(
                      children: [
                        // Background Box
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                        ),

                        // Logo badge only
                        if (game.isNotEmpty)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _accent, width: 2),
                              ),
                              child: ClipOval(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Builder(
                                    builder: (context) {
                                      final logoPath = _getGameLogo(game);

                                      if (logoPath.isEmpty) {
                                        return const Icon(
                                          Icons.sports_esports_rounded,
                                          color: _accent,
                                          size: 16,
                                        );
                                      }

                                      return Image.asset(
                                        logoPath,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.sports_esports_rounded,
                                              color: _accent,
                                              size: 16,
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Tournament Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 15,
                              color: Colors.white,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              timeText,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(width: 12),

                            const Icon(
                              Icons.calendar_month,
                              size: 15,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
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
          child: widget.child,
        ),
      ),
    );
  }
}
