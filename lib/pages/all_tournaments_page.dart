import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/organizer/View_tournament_page.dart';

class AllTournamentsPage extends StatefulWidget {
  const AllTournamentsPage({super.key});

  @override
  State<AllTournamentsPage> createState() => _AllTournamentsPageState();
}

class _AllTournamentsPageState extends State<AllTournamentsPage> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  String _selectedGame = 'All';
  String _sortOrder = 'newest'; // 'newest' or 'oldest'

  final List<String> _games = [
    'All',
    'PUBG',
    'League of Legends',
    'Valorant',
    'Dota 2',
    'Fortnite',
    'Other',
  ];

  DateTime _parseTournamentDate(dynamic value) {
    if (value == null) return DateTime(1900);

    if (value is Timestamp) {
      return value.toDate();
    }

    final text = value.toString().trim();

    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;
      return DateTime(year, month, day);
    }

    return DateTime.tryParse(text) ?? DateTime(1900);
  }

  String _normalizeGame(String game) {
    final lower = game.toLowerCase().trim();

    if (lower.contains('pubg')) return 'pubg';
    if (lower.contains('league') || lower.contains('lol')) {
      return 'league of legends';
    }
    if (lower.contains('valorant')) return 'valorant';
    if (lower.contains('dota')) return 'dota 2';
    if (lower.contains('fortnite')) return 'fortnite';

    return lower;
  }

  bool _isGameInFilterOptions(String game) {
    final normalized = _normalizeGame(game);

    final filterGames = _games
        .where((g) => g != 'All' && g != 'Other')
        .map((g) => _normalizeGame(g))
        .toList();

    return filterGames.contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and centered title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centered title
                  const Center(
                    child: Text(
                      'Upcoming Tournaments',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        height: 1,
                      ),
                    ),
                  ),
                  // Back button on the left
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _HoverTap(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _muted,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filters Section
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort Order
                  Row(
                    children: [
                      const Icon(Icons.sort_rounded, size: 18, color: _muted),
                      const SizedBox(width: 8),
                      const Text(
                        'Sort by:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'Newest',
                              isSelected: _sortOrder == 'newest',
                              onTap: () =>
                                  setState(() => _sortOrder = 'newest'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Oldest',
                              isSelected: _sortOrder == 'oldest',
                              onTap: () =>
                                  setState(() => _sortOrder = 'oldest'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: _line.withOpacity(0.5)),
                  const SizedBox(height: 12),

                  // Game Filter
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_esports_rounded,
                        size: 18,
                        color: _muted,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Game:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _games.map((game) {
                      return _FilterChip(
                        label: game,
                        isSelected: _selectedGame == game,
                        onTap: () => setState(() => _selectedGame = game),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Tournaments Grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Tournament')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 64,
                              color: _muted.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading tournaments',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
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
                              'No tournaments yet',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Check back later for upcoming events',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Filter tournaments by selected game
                  var tournaments = snapshot.data!.docs;

                  if (_selectedGame != 'All') {
                    tournaments = tournaments.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final game = (data['game'] ?? '').toString();

                      if (_selectedGame == 'Other') {
                        return !_isGameInFilterOptions(game);
                      }

                      return _normalizeGame(game) ==
                          _normalizeGame(_selectedGame);
                    }).toList();
                  }

                  tournaments.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;

                    final dateA = _parseTournamentDate(dataA['date']);
                    final dateB = _parseTournamentDate(dataB['date']);

                    if (_sortOrder == 'newest') {
                      return dateB.compareTo(dateA);
                    } else {
                      return dateA.compareTo(dateB);
                    }
                  });

                  if (tournaments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 80,
                              color: _muted.withOpacity(0.4),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No tournaments found',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No $_selectedGame tournaments available',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.15,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: tournaments.length,
                    itemBuilder: (context, index) {
                      final data =
                          tournaments[index].data() as Map<String, dynamic>;
                      return _TournamentCard(
                        tournamentId: tournaments[index].id,
                        title: data['Title'] ?? data['title'] ?? 'Tournament',
                        timeText: data['time'] ?? '10:00 PM',
                        dateText: data['date'] ?? '17/11/2026',
                        imageBase64: data['image'] ?? '',
                        game: data['game'] ?? '',
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);

  @override
  Widget build(BuildContext context) {
    return _HoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? _accent : _muted.withOpacity(0.3),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accent.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : _text,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final String tournamentId;
  final String title;
  final String timeText;
  final String dateText;
  final String imageBase64;
  final String game;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  const _TournamentCard({
    required this.tournamentId,
    required this.title,
    required this.timeText,
    required this.dateText,
    this.imageBase64 = '',
    this.game = '',
  });

  String _getGameLogo(String gameName) {
    final lowerGame = gameName.toLowerCase();

    if (lowerGame.contains('pubg')) return 'assets/images/pubg.png';

    if (lowerGame.contains('lol') || lowerGame.contains('league')) {
      return 'assets/images/lol.png';
    }

    if (lowerGame.contains('valorant')) return 'assets/images/valorant.png';

    if (lowerGame.contains('call of duty') || lowerGame.contains('cod')) {
      return 'assets/images/cod.png';
    }

    if (lowerGame.contains('fortnite')) return 'assets/images/fortnite.png';
    if (lowerGame.contains('dota') || lowerGame.contains('dota2')) {
      return 'assets/images/dota2.png';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return _HoverScale(
      scale: 1.03,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ViewTournamentPage(tournamentId: tournamentId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Background image with opacity
              // Background image
              if (imageBase64.isNotEmpty)
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        base64Decode(imageBase64),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(color: Colors.grey[100]);
                        },
                      ),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.60),
                              Colors.black.withOpacity(0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Game logo badge
              if (game.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Builder(
                          builder: (context) {
                            final logoPath = _getGameLogo(game);

                            if (logoPath.isEmpty) {
                              return const Icon(
                                Icons.sports_esports_rounded,
                                color: _accent,
                                size: 20,
                              );
                            }

                            return Image.asset(
                              logoPath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.sports_esports_rounded,
                                  color: _accent,
                                  size: 20,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            timeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              height: 1,
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
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              height: 1,
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
          child: widget.child,
        ),
      ),
    );
  }
}
