import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player/player_profile_view_page.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DATA MODEL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PlayerRank {
  final String uid, name, photo;
  final double score;
  final List<_BadgeItem> badges;
  const _PlayerRank({
    required this.uid,
    required this.name,
    required this.photo,
    required this.score,
    required this.badges,
  });
}

class _BadgeItem {
  final String type, label, detail;
  final Color color, bg;
  const _BadgeItem({
    required this.type,
    required this.label,
    required this.color,
    required this.bg,
    required this.detail,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BADGE FACTORY
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _BadgeVisual {
  final IconData icon;
  final Color color, bg;
  const _BadgeVisual({required this.icon, required this.color, required this.bg});
}

class _BadgeFactory {
  static const Map<String, _BadgeVisual> _visuals = {
    'trophy': _BadgeVisual(
        icon: Icons.emoji_events_rounded,
        color: Color(0xFFEB3D24),
        bg: Color(0xFFFFEDE9)),
    'diamond': _BadgeVisual(
        icon: Icons.diamond_rounded,
        color: Color(0xFF1565C0),
        bg: Color(0xFFE3F2FD)),
    'fire': _BadgeVisual(
        icon: Icons.local_fire_department,
        color: Color(0xFFE64A19),
        bg: Color(0xFFFFF0EB)),
    'medal': _BadgeVisual(
        icon: Icons.military_tech_rounded,
        color: Color(0xFFE8790A),
        bg: Color(0xFFFFF3E0)),
  };

  static _BadgeVisual visualFor(String type) =>
      _visuals[type] ?? _visuals['medal']!;

  static ({_BadgeItem item, double score}) fromDoc(Map<String, dynamic> bd) {
    final type  = (bd['type']  ?? '').toString();
    final label = (bd['label'] ?? '').toString();

    double score    = 5;
    String iconType = 'medal';
    String detail   = '';

    if (type == 'spark_mvp') {
      score += 100;
      iconType = 'trophy';
      final wr   = (bd['teamWinRate'] as num?)?.toStringAsFixed(1) ?? '0';
      final team = (bd['teamName'] ?? '').toString();
      detail = team.isNotEmpty ? '"$team" · $wr% WR' : '$wr% team WR';
    } else if (type == 'win_rate_rank') {
      iconType = label == 'Diamond' ? 'diamond' : 'medal';
      final wr    = (bd['winRate']    as num?)?.toStringAsFixed(1) ?? '0';
      final games = (bd['totalGames'] as num?)?.toString()         ?? '0';
      detail = '$wr% win rate · $games matches';
      if (label == 'Diamond')     score += 80;
      else if (label == 'Gold')   score += 60;
      else if (label == 'Silver') score += 40;
      else if (label == 'Bronze') score += 20;
    } else if (type == 'streak') {
      iconType = 'fire';
      final flames = (bd['flameCount'] as num?)?.toInt() ?? 0;
      final streak = (bd['streak']     as num?)?.toInt() ?? 0;
      final game   = _gameLabel((bd['game'] ?? '').toString());
      score += flames * 8.0;
      detail = '$streak wins in a row · $game';
    }

    final vis = visualFor(iconType);
    return (
      item: _BadgeItem(
        type: iconType,
        label: label.isEmpty ? _typeLabel(type) : label,
        color: vis.color,
        bg: vis.bg,
        detail: detail,
      ),
      score: score,
    );
  }

  static String _typeLabel(String t) => switch (t) {
        'spark_mvp'     => 'SPARK MVP',
        'win_rate_rank' => 'Rank',
        'streak'        => 'Streak',
        _               => t,
      };

  static String _gameLabel(String g) => switch (g.toLowerCase().trim()) {
        'lol'   => 'LoL',
        'pubg'  => 'PUBG',
        'dota2' => 'Dota 2',
        _       => g.toUpperCase(),
      };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LEADERBOARD PAGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  // ── colour palette ────────────────────────────
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1); 
  static const Color _bg     = Color(0xFFFAFAFA);
  static const Color _text   = Color(0xFF0F1419);
  static const Color _muted  = Color(0xFF536471);
  static const Color _line   = Color(0xFFCFD9DE);

  late final Future<List<_PlayerRank>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadLeaderboard();
  }

  Future<List<_PlayerRank>> _loadLeaderboard() async {
    final db   = FirebaseFirestore.instance;
    final snap = await db.collection('Player').get();
    final result = <_PlayerRank>[];

    for (final doc in snap.docs) {
      final uid  = doc.id;
      final data = doc.data();
      final badgesSnap = await db
          .collection('Player')
          .doc(uid)
          .collection('badges')
          .get();
      if (badgesSnap.docs.isEmpty) continue;

      double total = 0;
      final badges = <_BadgeItem>[];
      for (final bd in badgesSnap.docs) {
        final r = _BadgeFactory.fromDoc(bd.data());
        total += r.score;
        badges.add(r.item);
      }
      badges.sort((a, b) {
        const order = ['trophy', 'diamond', 'fire', 'medal'];
        return order.indexOf(a.type).compareTo(order.indexOf(b.type));
      });
      result.add(_PlayerRank(
        uid: uid,
        name: (data['Name'] ?? 'Player').toString(),
        photo: (data['ProfilePhoto'] ?? '').toString(),
        score: total,
        badges: badges,
      ));
    }
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<List<_PlayerRank>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: _accent, strokeWidth: 2.5));
                  }
                  if (snap.hasError) return _buildError();
                  final players = snap.data ?? [];
                  if (players.isEmpty) return _buildEmpty();
                  return _buildContent(players);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Center(
            child: Text(
              'Leaderboard',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _accent,
                height: 1,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _HoverTap(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: _muted, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── error / empty ─────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded,
            size: 64, color: _muted.withOpacity(0.5)),
        const SizedBox(height: 16),
        const Text('Something went wrong',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text)),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: _accent.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_outlined,
                color: _accent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No ranked players yet',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text)),
          const SizedBox(height: 8),
          const Text('Play matches to earn badges and appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _muted)),
        ]),
      ),
    );
  }

  // ── main content list ─────────────────────────
  Widget _buildContent(List<_PlayerRank> players) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: players.length + 3,
      itemBuilder: (context, i) {
        if (i == 0) return _buildPodium(players);
        if (i == 1) return _buildTop3List(players);
        if (i == 2) return const SizedBox(height: 4);

        final idx  = i - 3;
        if (idx >= players.length) return null;
        final p    = players[idx];
        final rank = idx + 1;

        if (rank <= 3) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _PlayerCard(
            rank: rank,
            player: p,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ViewPlayerProfilePage(userId: p.uid)),
            ),
          ),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PODIUM 
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildPodium(List<_PlayerRank> players) {
    final p1 = players.isNotEmpty ? players[0] : null;
    final p2 = players.length > 1 ? players[1] : null;
    final p3 = players.length > 2 ? players[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── #2 ────────────────────────
          Expanded(
            child: _PodiumCol(
              player: p2,
              rank: 2,
              platformHeight: 65,
              avatarSize: 54,
              onTap: p2 == null
                  ? null
                  : () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ViewPlayerProfilePage(userId: p2.uid))),
            ),
          ),
          const SizedBox(width: 8),
          // ── #1 ────────────────────────
          Expanded(
            child: _PodiumCol(
              player: p1,
              rank: 1,
              platformHeight: 90,
              avatarSize: 64,
              onTap: p1 == null
                  ? null
                  : () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ViewPlayerProfilePage(userId: p1.uid))),
            ),
          ),
          const SizedBox(width: 8),
          // ── #3 ────────────────────────
          Expanded(
            child: _PodiumCol(
              player: p3,
              rank: 3,
              platformHeight: 50,
              avatarSize: 50,
              onTap: p3 == null
                  ? null
                  : () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ViewPlayerProfilePage(userId: p3.uid))),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TOP-3 LIST
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTop3List(List<_PlayerRank> players) {
    final top = players.take(3).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...top.asMap().entries.map((e) {
            final rank   = e.key + 1;
            final player = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlayerCard(
                rank: rank,
                player: player,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ViewPlayerProfilePage(userId: player.uid)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PODIUM COLUMN 
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PodiumCol extends StatelessWidget {
  final _PlayerRank?  player;
  final int           rank;
  final double        platformHeight;
  final double        avatarSize;
  final VoidCallback? onTap;

  // All podium colours map to the system red.
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _platformBg     = Color(0xFFFFEDE9);
  static const Color _platformBorder = Color(0xFFEB3D24);
  static const Color _text           = Color(0xFF0F1419);

  const _PodiumCol({
    required this.player,
    required this.rank,
    required this.platformHeight,
    required this.avatarSize,
    required this.onTap,
  });

  ImageProvider? _img(String photo) {
    if (photo.trim().isEmpty) return null;
    try { return MemoryImage(base64Decode(photo)); } catch (_) {}
    if (photo.startsWith('http')) return NetworkImage(photo);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final img  = player != null ? _img(player!.photo) : null;
    final name = player?.name ?? '—';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
         

          // Avatar
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 2.2),
              boxShadow: [
                BoxShadow(
                    color: _accent.withOpacity(0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: ClipOval(
              child: img != null
                  ? Image(image: img!, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFEFEFEF),
                      child: const Icon(Icons.person,
                          color: Colors.black38, size: 24),
                    ),
            ),
          ),
          const SizedBox(height: 6),

          // Name
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: rank == 1 ? 12 : 11,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),

          // Platform block
          Container(
            width: double.infinity,
            height: platformHeight,
            decoration: BoxDecoration(
              color: _platformBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                top:   BorderSide(color: _platformBorder, width: 1.5),
                left:  BorderSide(color: _platformBorder, width: 1.5),
                right: BorderSide(color: _platformBorder, width: 1.5),
              ),
            ),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: _accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _accent,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PLAYER CARD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PlayerCard extends StatefulWidget {
  final int          rank;
  final _PlayerRank  player;
  final VoidCallback onTap;

  const _PlayerCard({
    required this.rank,
    required this.player,
    required this.onTap,
  });

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _pressed = false;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text   = Color(0xFF0F1419);
  static const Color _muted  = Color(0xFF536471);
  static const Color _line   = Color(0xFFCFD9DE);

  @override
  Widget build(BuildContext context) {
    final p   = widget.player;
    final pct = (p.score / 315.0).clamp(0.0, 1.0);

    ImageProvider? img;
    if (p.photo.trim().isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(p.photo));
      } catch (_) {
        if (p.photo.startsWith('http')) img = NetworkImage(p.photo);
      }
    }

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFCFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#${widget.rank}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                        color: _accent.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipOval(
                  child: img != null
                      ? Image(image: img!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFEFEFEF),
                          child: const Icon(Icons.person,
                              color: Colors.black38, size: 22),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _BadgesRow(badges: p.badges),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.score.toStringAsFixed(0),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _accent,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'pts',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 3,
                        backgroundColor: _line,
                        color: _accent,
                      ),
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BADGES ROW + CHIP  
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _BadgesRow extends StatelessWidget {
  final List<_BadgeItem> badges;
  const _BadgesRow({required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: badges.take(3).map((b) => _BadgeChip(badge: b)).toList(),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final _BadgeItem badge;

  static const Map<String, IconData> _icons = {
    'trophy':  Icons.emoji_events_rounded,
    'diamond': Icons.diamond_rounded,
    'fire':    Icons.local_fire_department,
    'medal':   Icons.military_tech_rounded,
  };

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.detail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: badge.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: badge.color.withOpacity(0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_icons[badge.type] ?? Icons.military_tech_rounded,
              color: badge.color, size: 11),
          const SizedBox(width: 3),
         
          Text(
            badge.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,           
              fontWeight: FontWeight.w700,
              color: badge.color,
              letterSpacing: 0,
            ),
          ),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HOVER TAP
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HoverTap extends StatefulWidget {
  final Widget       child;
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
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final canHover = Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;
    final scale = _down ? 0.98 : (_hover && canHover ? 1.02 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() {
        _hover = false;
        _down  = false;
      }),
      child: GestureDetector(
        onTap:       widget.onTap,
        onTapDown:   (_) => setState(() => _down = true),
        onTapCancel: ()  => setState(() => _down = false),
        onTapUp:     (_) => setState(() => _down = false),
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
