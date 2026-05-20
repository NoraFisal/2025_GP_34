// lib/pages/player/player_profile_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '/data/riot_link_service.dart';
import '../../services/player/player_service.dart';
import '../organizer/View_tournament_page.dart';
import '../settings_page.dart';
import '../team/create_team_page.dart';
import '../team/team_details_page.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RECOMMENDATION ENGINE 
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecommendationEngine {
  static const Map<String, int> _tierOrder = {
    'Beginner': 0,
    'Intermediate': 1,
    'Pro': 2,
  };

  static String _lolTier(Map<String, dynamic> stats) {
    final wr  = _d(stats['winRate']);
    final kda = _d(stats['kda']);
    final cs  = _d(stats['csPerMin']);
    if (wr >= 0.54 && kda >= 3.0 && cs >= 7.0) return 'Pro';
    if (wr >= 0.44 && kda >= 2.0 && cs >= 5.5) return 'Intermediate';
    return 'Beginner';
  }

  static String _pubgTier(Map<String, dynamic> stats) {
    final wr        = _d(stats['winRate']);
    final kills     = _d(stats['kills']);
    final damage    = _d(stats['damage']);
    final placement = _d(stats['placement']);
    if (wr >= 0.15 && kills >= 5.0 && damage >= 500 && placement <= 10) return 'Pro';
    if (wr >= 0.05 && kills >= 2.5 && damage >= 250 && placement <= 25) return 'Intermediate';
    return 'Beginner';
  }

  static String _dotaTier(Map<String, dynamic> stats) {
    final wr  = _d(stats['winRate']);
    final kda = _d(stats['kda']);
    final gpm = _d(stats['gpm']);
    final xpm = _d(stats['xpm']);
    if (wr >= 0.55 && kda >= 4.0 && gpm >= 500 && xpm >= 600) return 'Pro';
    if (wr >= 0.42 && kda >= 2.5 && gpm >= 350 && xpm >= 450) return 'Intermediate';
    return 'Beginner';
  }

  static String classifyTier(String gameId, Map<String, dynamic> stats) {
    final id = _normalizeGame(gameId);
    if (id == 'lol')   return _lolTier(stats);
    if (id == 'pubg')  return _pubgTier(stats);
    if (id == 'dota2') return _dotaTier(stats);
    return 'Beginner';
  }

  static Map<String, dynamic>? scoreTournament({
    required List<Map<String, dynamic>> linkedAccounts,
    required Map<String, dynamic> tournament,
  }) {
    final tournGame = _normalizeGame((tournament['game'] ?? '').toString());
    final tournTier = (tournament['tier'] ?? 'Beginner').toString();

    Map<String, dynamic>? acc;
    for (final a in linkedAccounts) {
      if (_normalizeGame((a['game'] ?? '').toString()) == tournGame) {
        acc = a;
        break;
      }
    }
    if (acc == null) return null;

    final dashStats =
        (acc['dashboard'] is Map ? acc['dashboard']['stats'] : null)
            as Map<String, dynamic>?;
    final statsToUse = dashStats ?? acc;

    final overallScore = (acc['dashboard'] is Map)
        ? _d(acc['dashboard']['overallScore'])
        : null;

    final playerTier = classifyTier(tournGame, statsToUse);

    double score = 0;
    final reasons = <String>[];

    score += 40;
    reasons.add('Game Match ✓');

    final pIdx = _tierOrder[playerTier] ?? 0;
    final tIdx = _tierOrder[tournTier]  ?? 0;
    final diff = (pIdx - tIdx).abs();
    if (diff == 0) {
      score += 35;
      reasons.add('Tier Match ($playerTier)');
    } else if (diff == 1) {
      score += 18;
      reasons.add('Close Tier ($playerTier → $tournTier)');
    } else {
      score += 5;
    }

    if (overallScore != null) {
      const Map<String, double> idealScore = {
        'Beginner': 35.0,
        'Intermediate': 55.0,
        'Pro': 75.0,
      };
      final target = idealScore[tournTier] ?? 55.0;
      final gap    = (overallScore - target).abs();
      final bonus  = (25.0 - gap * 0.5).clamp(0.0, 25.0);
      score += bonus;
      if (bonus >= 20) reasons.add('Strong Performance ✓');
    }

    return {
      'tournament': tournament,
      'score':      double.parse(score.toStringAsFixed(2)),
      'reasons':    reasons,
      'playerTier': playerTier,
    };
  }

  static List<Map<String, dynamic>> recommend({
    required List<Map<String, dynamic>> linkedAccounts,
    required List<Map<String, dynamic>> tournaments,
  }) {
    final results = <Map<String, dynamic>>[];
    for (final t in tournaments) {
      final r = scoreTournament(linkedAccounts: linkedAccounts, tournament: t);
      if (r != null) results.add(r);
    }
    results.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return results;
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _normalizeGame(String g) {
    final s = g.toLowerCase().trim();
    if (s == 'lol' || s == 'league of legends' || s == 'leagueoflegends') return 'lol';
    if (s == 'dota' || s == 'dota 2' || s == 'dota2') return 'dota2';
    if (s == 'pubg') return 'pubg';
    return s;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BADGES ENGINE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BadgesEngine {
  static Map<String, dynamic> getWinRateRank(double winRate) {
    if (winRate >= 0.65) {
      return {
        'label': 'Diamond',
        'type': 'diamond',
        'color': const Color(0xFFEB3D24),
        'bgColor': const Color(0xFFFFEDE9),
        'gradientStart': const Color(0xFFFF6B4A),
        'gradientEnd': const Color(0xFFEB3D24),
      };
    } else if (winRate >= 0.60) {
      return {
        'label': 'Gold',
        'type': 'medal',
        'color': const Color(0xFFE8790A),
        'bgColor': const Color(0xFFFFF3E0),
        'gradientStart': const Color(0xFFFFB347),
        'gradientEnd': const Color(0xFFE8790A),
      };
    } else if (winRate >= 0.55) {
      return {
        'label': 'Silver',
        'type': 'medal',
        'color': const Color(0xFFD4501A),
        'bgColor': const Color(0xFFFFF0E8),
        'gradientStart': const Color(0xFFFF8C42),
        'gradientEnd': const Color(0xFFD4501A),
      };
    } else if (winRate >= 0.50) {
      return {
        'label': 'Bronze',
        'type': 'medal',
        'color': const Color(0xFFC0392B),
        'bgColor': const Color(0xFFFFEBE8),
        'gradientStart': const Color(0xFFE74C3C),
        'gradientEnd': const Color(0xFFC0392B),
      };
    }
    return {
      'label': 'Unranked',
      'type': 'medal',
      'color': const Color(0xFFB84A2E),
      'bgColor': const Color(0xFFFFF0EC),
      'gradientStart': const Color(0xFFD4714A),
      'gradientEnd': const Color(0xFFB84A2E),
    };
  }

  static Map<String, dynamic> getStreakBadge(int streak) {
    if (streak >= 15) {
      return {
        'flames': 5,
        'label': 'Legendary',
        'color': const Color(0xFFEB3D24),
        'bgColor': const Color(0xFFFFEDE9),
        'gradientStart': const Color(0xFFFF5722),
        'gradientEnd': const Color(0xFFEB3D24),
      };
    } else if (streak >= 10) {
      return {
        'flames': 4,
        'label': 'Unstoppable',
        'color': const Color(0xFFE64A19),
        'bgColor': const Color(0xFFFFF0EB),
        'gradientStart': const Color(0xFFFF7043),
        'gradientEnd': const Color(0xFFE64A19),
      };
    } else if (streak >= 7) {
      return {
        'flames': 3,
        'label': 'On Fire',
        'color': const Color(0xFFD84315),
        'bgColor': const Color(0xFFFFF3EE),
        'gradientStart': const Color(0xFFFF8A65),
        'gradientEnd': const Color(0xFFD84315),
      };
    } else if (streak >= 5) {
      return {
        'flames': 2,
        'label': 'Heating Up',
        'color': const Color(0xFFE67E22),
        'bgColor': const Color(0xFFFFF8F0),
        'gradientStart': const Color(0xFFFFAB40),
        'gradientEnd': const Color(0xFFE67E22),
      };
    } else if (streak >= 3) {
      return {
        'flames': 1,
        'label': 'Streak',
        'color': const Color(0xFFF39C12),
        'bgColor': const Color(0xFFFFFBF0),
        'gradientStart': const Color(0xFFFFCC02),
        'gradientEnd': const Color(0xFFF39C12),
      };
    }
    return {
      'flames': 0,
      'label': '',
      'color': Colors.transparent,
      'bgColor': Colors.transparent,
      'gradientStart': Colors.transparent,
      'gradientEnd': Colors.transparent,
    };
  }
}


class BadgePersistenceService {
  static final _db = FirebaseFirestore.instance;
 
  static Future<void> saveBadge({
    required String uid,
    required String badgeId,
    required Map<String, dynamic> data,
  }) async {
    final ref = _db
        .collection('Player')
        .doc(uid)
        .collection('badges')
        .doc(badgeId);
 
    await ref.set({
      ...data,
      'badgeId': badgeId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
 
  static Future<void> removeBadge({
    required String uid,
    required String badgeId,
  }) async {
    await _db
        .collection('Player')
        .doc(uid)
        .collection('badges')
        .doc(badgeId)
        .delete()
        .catchError((_) {});
  }
 
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchBadges(String uid) {
    return _db
        .collection('Player')
        .doc(uid)
        .collection('badges')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }
 
static Future<void> syncAllBadges({
  required String uid,
  required List<_BadgeRecord> earned,
  required List<String> removedIds,
}) async {
  final batch = _db.batch();
  final playerBadgesRef =
      _db.collection('Player').doc(uid).collection('badges');

  final existingSnapshots = await playerBadgesRef.get();
  final existingMap = {
    for (var doc in existingSnapshots.docs) doc.id: doc.data()
  };

  for (final badge in earned) {
    final ref = playerBadgesRef.doc(badge.badgeId);
    final existing = existingMap[badge.badgeId];
    final alreadySeen = existing?['seen'] == true;

    final dataToWrite = Map<String, dynamic>.from(badge.data);
    if (existing != null) {
      dataToWrite.remove('earnedAt'); // ✅ لا تلمس التاريخ القديم
    }

    batch.set(
      ref,
      {
       ...dataToWrite,
    'badgeId': badge.badgeId,
    'updatedAt': FieldValue.serverTimestamp(),
    if (existing == null) 'seen': false,
    if (existing == null) 'earnedAt': FieldValue.serverTimestamp(), // ✅ فقط أول مرة
    if (alreadySeen) 'seen': true,
      },
      SetOptions(merge: true),
    );
  }

  for (final id in removedIds) {
    batch.delete(playerBadgesRef.doc(id));
  }

  await batch.commit();
}
}
 
class _BadgeRecord {
  final String badgeId;
  final Map<String, dynamic> data;
  const _BadgeRecord({required this.badgeId, required this.data});
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BADGE HEX ICON WIDGET
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
class _BadgeHexIcon extends StatelessWidget {
  final String iconType;
  final Color  primaryColor;
  final Color  secondaryColor;
  final String label;
  final String sublabel;
  final DateTime? earnedAt;
  final Map<String, dynamic> rawData;
  final String uid;
 
  const _BadgeHexIcon({
    required this.iconType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.label,
    required this.sublabel,
    required this.rawData,
    required this.uid,          
    this.earnedAt,
  });
 
  static const Map<String, IconData> _iconMap = {
    'diamond': Icons.diamond_rounded,
    'fire':    Icons.local_fire_department_rounded,
    'trophy':  Icons.emoji_events_rounded,
    'medal':   Icons.military_tech_rounded,
  };
 
  
  void _onTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.40,
        maxChildSize: 0.78,
        expand: false,
        builder: (ctx, scrollController) => _BadgeDetailSheetLoader(
          uid:              uid,
          badgeId:          rawData['type']?.toString() ?? 'win_rate_rank',
          iconType:         iconType,
          primaryColor:     primaryColor,
          secondaryColor:   secondaryColor,
          label:            label,
          sublabel:         sublabel,
          localRawData:     rawData,
          scrollController: scrollController,
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[iconType] ?? Icons.star_rounded;
 
    return GestureDetector(
      onTap: () => _onTap(context),
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(80, 88),
              painter: _HexBadgePainter(
                primaryColor:   primaryColor,
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
              sublabel,
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
      ),
    );
  }
}
class _BadgeDetailSheet extends StatelessWidget {
  final String    iconType;
  final Color     primaryColor;
  final Color     secondaryColor;
  final String    label;
  final String    sublabel;
  final Map<String, dynamic> rawData;
  final ScrollController scrollController;
 
  static const Color _bodyBg   = Colors.white;
  static const Color _text     = Color(0xFF0F1419);
  static const Color _muted    = Color(0xFF536471);
  static const Color _line     = Color(0xFFCFD9DE);
  static const Color _subtleBg = Color(0xFFF7F9FA);
 
  static const Map<String, IconData> _iconMap = {
    'diamond': Icons.diamond_rounded,
    'fire':    Icons.local_fire_department_rounded,
    'trophy':  Icons.emoji_events_rounded,
    'medal':   Icons.military_tech_rounded,
  };
 
  const _BadgeDetailSheet({
    required this.iconType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.label,
    required this.sublabel,
    required this.rawData,
    required this.scrollController,
  });
 
  String get _howToEarn {
    final type = (rawData['type'] ?? '').toString();
    if (type == 'spark_mvp') {
      return 'Earn this badge by being part of a team with a 90% or higher win rate in SPARK.';
    } else if (type == 'win_rate_rank') {
      final lbl = (rawData['label'] ?? '').toString();
      return switch (lbl) {
        'Diamond' => 'Achieve a win rate of 65% or higher across at least 5 matches.',
        'Gold'    => 'Achieve a win rate between 60% and 64% across at least 5 matches.',
        'Silver'  => 'Achieve a win rate between 55% and 59% across at least 5 matches.',
        'Bronze'  => 'Achieve a win rate between 50% and 54% across at least 5 matches.',
        _         => 'Play at least 5 matches and reach an appropriate win rate.',
      };
    } else if (type == 'streak') {
      final flames = (rawData['flameCount'] as num?)?.toInt() ?? 0;
      return switch (flames) {
        5 => 'Win 15 or more consecutive matches in the same game.',
        4 => 'Win 10 or more consecutive matches in the same game.',
        3 => 'Win 7 or more consecutive matches in the same game.',
        2 => 'Win 5 or more consecutive matches in the same game.',
        _ => 'Win 3 or more consecutive matches in the same game.',
      };
    }
    return 'Play and achieve milestones to earn this badge.';
  }
 
  String get _formattedDate {
    final updatedAt = rawData['updatedAt'];
    final earnedAt  = rawData['earnedAt'];
    DateTime? dt;
    if (updatedAt is Timestamp) {
      dt = updatedAt.toDate();
    } else if (earnedAt is Timestamp) {
      dt = earnedAt.toDate();
    }
    if (dt == null) return 'Fetching…';
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
 
  String get _gameLabel {
    final g = (rawData['game'] ?? sublabel).toString().toLowerCase().trim();
    return switch (g) {
      'lol'   => 'League of Legends',
      'pubg'  => 'PUBG',
      'dota2' => 'Dota 2',
      'team'  => 'Team Achievement',
      'all'   => 'All Games',
      _       => sublabel.isNotEmpty ? sublabel : g.toUpperCase(),
    };
  }
 
  List<_StatRow> get _stats {
    final type = (rawData['type'] ?? '').toString();
    final rows = <_StatRow>[];
    if (type == 'win_rate_rank') {
      final wr    = (rawData['winRate']    as num?)?.toStringAsFixed(1) ?? '0';
      final games = (rawData['totalGames'] as num?)?.toString()         ?? '0';
      rows.add(_StatRow(icon: Icons.percent_rounded,        label: 'Win Rate', value: '$wr%'));
      rows.add(_StatRow(icon: Icons.sports_esports_rounded, label: 'Matches',  value: games));
    } else if (type == 'streak') {
      final streak = (rawData['streak']     as num?)?.toString() ?? '0';
      final flames = (rawData['flameCount'] as num?)?.toString() ?? '0';
      rows.add(_StatRow(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '$streak wins'));
      rows.add(_StatRow(icon: Icons.whatshot_rounded,               label: 'Flames', value: '🔥 × $flames'));
    } else if (type == 'spark_mvp') {
      final wr   = (rawData['teamWinRate'] as num?)?.toStringAsFixed(1) ?? '0';
      final team = (rawData['teamName'] ?? '').toString();
      rows.add(_StatRow(icon: Icons.groups_rounded,  label: 'Team',    value: team.isNotEmpty ? team : '—'));
      rows.add(_StatRow(icon: Icons.percent_rounded, label: 'Team WR', value: '$wr%'));
    }
    return rows;
  }
 
  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[iconType] ?? Icons.star_rounded;
 
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
 
            // Drag handle – white on gradient
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
 
            CustomPaint(
              size: const Size(72, 80),
              painter: _HexBadgePainter(
                primaryColor:   primaryColor,
                secondaryColor: secondaryColor,
              ),
              child: SizedBox(
                width: 72, height: 80,
                child: Align(
                  alignment: const Alignment(0, -0.10),
                  child: Icon(
                    icon, color: Colors.white, size: 32,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
 
            // Badge name – white on gradient
            Text(label,
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 22,
                fontWeight: FontWeight.w900, color: Colors.white, height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
 
            // Game label – white 85%
            Text(_gameLabel,
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 24),
 
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: _bodyBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
 
                  // Date Earned
                  _InfoTile(
                    icon: Icons.calendar_today_rounded,
                    iconColor: primaryColor,
                    label: 'Date Earned',
                    value: _formattedDate,
                  ),
                  const SizedBox(height: 10),
 
                  // Stats
                  ..._stats.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InfoTile(
                      icon: s.icon, iconColor: primaryColor,
                      label: s.label, value: s.value,
                    ),
                  )),
 
                  // How to Earn
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primaryColor.withOpacity(0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.info_outline_rounded, color: primaryColor, size: 15),
                          const SizedBox(width: 6),
                          Text('How to Earn',
                            style: TextStyle(
                              fontFamily: 'Inter', fontSize: 11,
                              fontWeight: FontWeight.w800, color: primaryColor,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(_howToEarn,
                          style: const TextStyle(
                            fontFamily: 'Inter', fontSize: 13,
                            fontWeight: FontWeight.w500, color: _text, height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
 
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: _subtleBg,
                        foregroundColor: _muted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: _line),
                        ),
                      ),
                      child: const Text('Close',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
 // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
class _BadgeDetailSheetLoader extends StatefulWidget {
  final String   uid;
  final String   badgeId;
  final String   iconType;
  final Color    primaryColor;
  final Color    secondaryColor;
  final String   label;
  final String   sublabel;
  final Map<String, dynamic> localRawData;
  final ScrollController scrollController;
 
  const _BadgeDetailSheetLoader({
    required this.uid,
    required this.badgeId,
    required this.iconType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.label,
    required this.sublabel,
    required this.localRawData,
    required this.scrollController,
  });
 
  @override
  State<_BadgeDetailSheetLoader> createState() =>
      _BadgeDetailSheetLoaderState();
}
 
class _BadgeDetailSheetLoaderState extends State<_BadgeDetailSheetLoader> {
  Map<String, dynamic>? _firestoreData;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Player')
          .doc(widget.uid)
          .collection('badges')
          .doc(widget.badgeId)
          .get();
      if (doc.exists && mounted) {
        setState(() => _firestoreData = doc.data());
      }
    } catch (_) {}
  }
 
  @override
  Widget build(BuildContext context) {
    // Merge: Firestore Timestamps win for date; local stats fill everything else
    final merged = <String, dynamic>{...widget.localRawData};
    if (_firestoreData != null) {
      final ts = _firestoreData!['updatedAt'];
      final ea = _firestoreData!['earnedAt'];
      if (ts is Timestamp) merged['updatedAt'] = ts;
      if (ea is Timestamp) merged['earnedAt']  = ea;
    }
 
    return _BadgeDetailSheet(
      iconType:         widget.iconType,
      primaryColor:     widget.primaryColor,
      secondaryColor:   widget.secondaryColor,
      label:            widget.label,
      sublabel:         widget.sublabel,
      rawData:          merged,
      scrollController: widget.scrollController,
    );
  }
}
// ── Info tile ──────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
 
  static const Color _text  = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line  = Color(0xFFCFD9DE);
 
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 12,
                fontWeight: FontWeight.w600, color: _muted,
              ),
            ),
          ),
          Text(value,
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 14,
              fontWeight: FontWeight.w800, color: _text,
            ),
          ),
        ],
      ),
    );
  }
}
 
// ── Stat row model ─────────────────────────────────────────────────────────
class _StatRow {
  final IconData icon;
  final String   label;
  final String   value;
  const _StatRow({required this.icon, required this.label, required this.value});
}
 
// ── Hex path helper ────────────────────────────────────────────────────────
Path _hexPath(Offset center, double r, {double rotation = 0}) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = rotation + (pi / 3) * i;
    final x = center.dx + r * cos(angle);
    final y = center.dy + r * sin(angle);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  path.close();
  return path;
}
 
// ── HexBadgePainter ────────────────────────────────────────────────────────
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
    canvas.drawPath(_hexPath(center, R * 0.96, rotation: -pi / 6), shadowPaint);
 
    final outerPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: R))
      ..style = PaintingStyle.fill;
    canvas.drawPath(_hexPath(center, R, rotation: -pi / 6), outerPaint);
 
    final ringPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(_hexPath(center, R * 0.80, rotation: -pi / 6), ringPaint);
 
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
    canvas.drawPath(_hexPath(center, R * 0.78, rotation: -pi / 6), innerPaint);
 
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final shinePath = Path()
      ..moveTo(cx - R * 0.5, cy - R * 0.55)
      ..cubicTo(cx - R * 0.1, cy - R * 0.85, cx + R * 0.3, cy - R * 0.75, cx + R * 0.45, cy - R * 0.40)
      ..cubicTo(cx + R * 0.20, cy - R * 0.15, cx - R * 0.25, cy - R * 0.10, cx - R * 0.5, cy - R * 0.20)
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
  bool shouldRepaint(_HexBadgePainter old) =>
      old.primaryColor != primaryColor || old.secondaryColor != secondaryColor;
}
 
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BADGES SECTION INNER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
class _BadgesSectionInner extends StatelessWidget {
  final String uid;
  static const Color _muted = Color(0xFF536471);
 
  const _BadgesSectionInner({super.key, required this.uid});
 
  static Map<String, dynamic> _buildWinRateBadgeData({
    required Map<String, dynamic> rankBadge,
    required double winRate,
    required int totalGames,
  }) {
    return {
      'type': 'win_rate_rank',
      'label': rankBadge['label'] as String,
      'iconType': rankBadge['type'] as String,
      'winRate': double.parse((winRate * 100).toStringAsFixed(1)),
      'totalGames': totalGames,
      'colorHex': (rankBadge['color'] as Color).value.toRadixString(16),
      'bgColorHex': (rankBadge['bgColor'] as Color).value.toRadixString(16),
      'game': 'all',
      
    };
  }
 
  static Map<String, dynamic> _buildStreakBadgeData({
    required Map<String, dynamic> streakBadge,
    required int streak,
    required String streakGame,
  }) {
    return {
      'type': 'streak',
      'label': streakBadge['label'] as String,
      'iconType': 'fire',
      'flameCount': streakBadge['flames'] as int,
      'streak': streak,
      'colorHex': (streakBadge['color'] as Color).value.toRadixString(16),
      'bgColorHex': (streakBadge['bgColor'] as Color).value.toRadixString(16),
      'game': streakGame,
      
    };
  }
 
  static Map<String, dynamic> _buildMvpBadgeData({
    required double mvpWinRate,
    required String mvpTeamName,
  }) {
    return {
      'type': 'spark_mvp',
      'label': 'SPARK MVP',
      'iconType': 'trophy',
      'teamWinRate': double.parse(mvpWinRate.toStringAsFixed(1)),
      'teamName': mvpTeamName,
      'colorHex': const Color(0xFFEB3D24).value.toRadixString(16),
      'bgColorHex': const Color(0xFFFFEDE9).value.toRadixString(16),
      'game': 'team',
      
    };
  }
Future<Map<String, dynamic>> _loadAndSyncBadges() async {
  return await _BadgesSectionInner.computeAndSyncBadges(uid);
}

static Future<Map<String, dynamic>> computeAndSyncBadges(String uid) async {
  final db = FirebaseFirestore.instance;
  final games = ['lol', 'pubg', 'dota2'];

  int totalWins = 0;
  int totalGames = 0;
  int bestStreak = 0;
  String bestStreakGame = '';

  for (final game in games) {
    try {
      final snap = await db
          .collection('Player')
          .doc(uid)
          .collection('linkedGames')
          .doc(game)
          .collection('matches')
          .limit(30)
          .get();

      final docs = snap.docs.toList()
        ..sort((a, b) {
          final ta = (a.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (b.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });

      final recent = docs.take(20).toList();

      int gameStreak = 0;
      for (final m in recent) {
        if (m.data()['win'] == true) {
          gameStreak++;
        } else {
          break;
        }
      }

      if (gameStreak > bestStreak) {
        bestStreak = gameStreak;
        bestStreakGame = game;
      }

      for (final m in recent) {
        if (m.data()['win'] == true) totalWins++;
        totalGames++;
      }
    } catch (_) {}
  }

  bool hasMvp = false;
  double mvpWinRate = 0;
  String mvpTeamName = '';

  try {
    final allTeamsSnap = await db.collection('Team').get();
    for (final teamDoc in allTeamsSnap.docs) {
      final memberDoc = await teamDoc.reference.collection('Members').doc(uid).get();
      if (!memberDoc.exists) continue;
      if ((memberDoc.data()?['response'] ?? '') != 'Accepted') continue;
      final winRate = (teamDoc.data()['winRate'] as num?)?.toDouble() ?? 0.0;
      if (winRate >= 90.0) {
        hasMvp = true;
        mvpWinRate = winRate;
        mvpTeamName = (teamDoc.data()['name'] ?? '').toString();
        break;
      }
    }
  } catch (_) {}

  final winRate = totalGames > 0 ? totalWins / totalGames : 0.0;
  final rankBadge   = BadgesEngine.getWinRateRank(winRate);
  final streakBadge = BadgesEngine.getStreakBadge(bestStreak);
  final hasRank   = totalGames >= 5;
  final hasStreak = bestStreak >= 3;

  final earned  = <_BadgeRecord>[];
  final removed = <String>[];

  if (hasRank) {
    earned.add(_BadgeRecord(
      badgeId: 'win_rate_rank',
      data: _buildWinRateBadgeData(
        rankBadge: rankBadge,
        winRate: winRate,
        totalGames: totalGames,
      ),
    ));
  } else {
    removed.add('win_rate_rank');
  }

  if (hasStreak) {
    earned.add(_BadgeRecord(
      badgeId: 'streak',
      data: _buildStreakBadgeData(
        streakBadge: streakBadge,
        streak: bestStreak,
        streakGame: bestStreakGame,
      ),
    ));
  } else {
    removed.add('streak');
  }

  if (hasMvp) {
    earned.add(_BadgeRecord(
      badgeId: 'spark_mvp',
      data: _buildMvpBadgeData(
        mvpWinRate: mvpWinRate,
        mvpTeamName: mvpTeamName,
      ),
    ));
  } else {
    removed.add('spark_mvp');
  }

  await BadgePersistenceService.syncAllBadges(
    uid: uid,
    earned: earned,
    removedIds: removed,
  );

  return {
    'totalWins':     totalWins,
    'totalGames':    totalGames,
    'hasMvp':        hasMvp,
    'mvpWinRate':    mvpWinRate,
    'mvpTeamName':   mvpTeamName,
    'bestStreak':    bestStreak,
    'bestStreakGame': bestStreakGame,
  };
}
 
  String _gameDisplayLabel(String g) {
    switch (g.toLowerCase().trim()) {
      case 'lol':   return 'League of Legends';
      case 'pubg':  return 'PUBG';
      case 'dota2': return 'Dota 2';
      default:      return g.toUpperCase();
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadAndSyncBadges(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
 
        final totalWins   = snap.data!['totalWins']      as int;
        final totalGames  = snap.data!['totalGames']     as int;
        final hasMvp      = snap.data!['hasMvp']         as bool;
        final mvpWinRate  = snap.data!['mvpWinRate']     as double;
        final mvpTeamName = snap.data!['mvpTeamName']    as String;
        final streak      = snap.data!['bestStreak']     as int;
        final streakGame  = snap.data!['bestStreakGame'] as String;
 
        final winRate     = totalGames > 0 ? totalWins / totalGames : 0.0;
        final rankBadge   = BadgesEngine.getWinRateRank(winRate);
        final streakBadge = BadgesEngine.getStreakBadge(streak);
        final hasRank     = totalGames >= 5;
        final hasStreak   = streak >= 3;
 
        if (!hasRank && !hasStreak && !hasMvp) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'Play more matches to earn badges!',
                style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
 
        final badges = <Widget>[];
 
        if (hasRank) {
          final rankRawData = {
            'type': 'win_rate_rank',
            'label': rankBadge['label'],
            'winRate': double.parse((winRate * 100).toStringAsFixed(1)),
            'totalGames': totalGames,
          };
          badges.add(_BadgeHexIcon(
            uid:            uid,           // ✅ passed down
            iconType:       rankBadge['type'] as String,
            primaryColor:   rankBadge['gradientStart'] as Color,
            secondaryColor: rankBadge['gradientEnd'] as Color,
            label:          rankBadge['label'] as String,
            sublabel:       'All Games',
            rawData:        rankRawData,
          ));
        }
 
        if (hasStreak) {
          final streakRawData = {
            'type': 'streak',
            'flameCount': streakBadge['flames'],
            'streak': streak,
            'game': streakGame,
          };
          badges.add(_BadgeHexIcon(
            uid:            uid,           // ✅ passed down
            iconType:       'fire',
            primaryColor:   streakBadge['gradientStart'] as Color,
            secondaryColor: streakBadge['gradientEnd'] as Color,
            label:          streakBadge['label'] as String,
            sublabel:       _gameDisplayLabel(streakGame),
            rawData:        streakRawData,
          ));
        }
 
        if (hasMvp) {
          final mvpRawData = {
            'type': 'spark_mvp',
            'teamWinRate': mvpWinRate,
            'teamName': mvpTeamName,
            'game': 'team',
          };
          badges.add(_BadgeHexIcon(
            uid:            uid,           // ✅ passed down
            iconType:       'trophy',
            primaryColor:   const Color(0xFFFF6B35),
            secondaryColor: const Color(0xFFEB3D24),
            label:          'SPARK MVP',
            sublabel:       mvpTeamName.isNotEmpty ? mvpTeamName : 'Team',
            rawData:        mvpRawData,
          ));
        }
 
        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => badges[i],
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PLAYER PROFILE PAGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key});

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  int _badgesRefreshKey = 0;

  static const Map<String, Color> _tierColors = {
    'Beginner': Color(0xFF22c55e),
    'Intermediate': Color(0xFFf59e0b),
    'Pro': Color(0xFFef4444),
  };

  static const Map<String, String> _gameImages = {
    'lol': 'assets/images/lol.png',
    'league of legends': 'assets/images/lol.png',
    'pubg': 'assets/images/pubg.png',
    'dota2': 'assets/images/dota2.png',
    'dota 2': 'assets/images/dota2.png',
  };



  @override
  Widget build(BuildContext context) {
    const actionBtnSize = 34.0;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
          child: StreamBuilder<PlayerData?>(
            stream: PlayerService.watchMe(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final user = userSnap.data!;

              final privacyRef = (uid == null)
                  ? null
                  : FirebaseFirestore.instance.collection('Player').doc(uid);

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: privacyRef?.snapshots(),
                builder: (context, privacySnap) {
                  final pdata =
                      privacySnap.data?.data() ?? const <String, dynamic>{};
                  final showAge =
                      (pdata['showAge'] is bool) ? pdata['showAge'] as bool : true;
                  final showCity =
                      (pdata['showCity'] is bool) ? pdata['showCity'] as bool : true;
                  final showGender = (pdata['showGender'] is bool)
                      ? pdata['showGender'] as bool
                      : true;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Profile Header Card ──
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
                                  b64: (user.profilePhoto ?? ''),
                                  outer: 80,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    user.username,
                                    style: const TextStyle(
                                      color: _text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                _circleButton(
                                  size: actionBtnSize,
                                  icon: Icons.edit_rounded,
                                  onTap: () =>
                                      Navigator.pushNamed(context, "/playerEdit"),
                                ),
                                const SizedBox(width: 10),
                                _circleButton(
                                  size: actionBtnSize,
                                  icon: Icons.settings_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsPage(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _infoBlockX(
                              user,
                              uid: user.uid,
                              showAge: showAge,
                              showCity: showCity,
                              showGender: showGender,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Suggestions Section ──
                      _SuggestionsContainer(uid: user.uid),

                      // ── Badges Section ──
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
                            _BadgesSectionInner(
  key: ValueKey(_badgesRefreshKey),
  uid: user.uid,
), 
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Performance Stats ──
                      _PerformanceTabsSection(uid: user.uid),

                      const SizedBox(height: 18),

                      // ── My Team Section ──
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
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "My Team",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                    height: 1,
                                  ),
                                ),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('Player')
                                      .doc(uid)
                                      .collection('linkedGames')
                                      .limit(1)
                                      .snapshots(),
                                  builder: (context, linkedSnap) {
                                    final isLinked = (linkedSnap.data?.docs.isNotEmpty) == true;
                                    return _darkPillButton(
                                      "Create Team",
                                      compact: true,
                                      icon: Icons.groups_rounded,
                                      enabled: isLinked,
                                      onTap: () {
                                        if (isLinked) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const CreateTeamPage(),
                                            ),
                                          );
                                        } else {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (dialogCtx) => Dialog(
                                              backgroundColor: Colors.transparent,
                                              elevation: 0,
                                              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                                              child: Container(
                                                width: 320,
                                                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: const Color(0xFFCFD9DE)),
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
                                                        border: Border.all(color: const Color(0xFFEB3D24), width: 2),
                                                      ),
                                                      child: const Icon(
                                                        Icons.link_off_rounded,
                                                        color: Color(0xFFEB3D24),
                                                        size: 30,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),
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
                                                        onPressed: () => Navigator.pop(dialogCtx),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFFEB3D24),
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
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _teamsStripLikeX(user.uid),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PROFILE UI HELPERS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _infoBlockX(
    PlayerData u, {
    required String uid,
    required bool showAge,
    required bool showCity,
    required bool showGender,
  }) {
    final ageV    = showAge    ? "${u.age}"                        : "-";
    final cityV   = showCity   ? (u.city.isEmpty   ? "-" : u.city)   : "-";
    final genderV = showGender ? (u.gender.isEmpty ? "-" : u.gender) : "-";

    const label = TextStyle(
      color: _text, fontSize: 12, fontWeight: FontWeight.w600, height: 1,
    );
    const value = TextStyle(
      color: _text, fontSize: 13, fontWeight: FontWeight.w800, height: 1.1,
    );

    Widget item(String l, Widget v, {TextAlign align = TextAlign.left}) {
      return Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : align == TextAlign.center
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
        children: [
          Text(l, style: label, textAlign: align),
          const SizedBox(height: 6),
          v,
        ],
      );
    }

    final playerDocRef =
        FirebaseFirestore.instance.collection('Player').doc(uid);

    Widget gamesWidget = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: playerDocRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final ids = (data['gameIds'] is List) ? (data['gameIds'] as List) : null;
        List<String> labels = [];

        if (ids != null) {
          final normalized = ids
              .map((e) => (e ?? '').toString().toLowerCase().trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          if (normalized.contains('lol'))   labels.add('League of Legends');
          if (normalized.contains('pubg'))  labels.add('PUBG');
          if (normalized.contains('dota2')) labels.add('Dota 2');
        } else {
          final raw = (data['games'] is List)
              ? (data['games'] as List)
              : (data['Game'] is List)
                  ? (data['Game'] as List)
                  : const [];
          final set = raw
              .map((e) => (e ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          set.removeWhere((s) => s.toLowerCase().contains('valorant'));
          labels = set.toList()..sort();
        }

        final gamesV = labels.isEmpty ? "-" : labels.join(", ");
        return Text(
          gamesV,
          style: value,
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );

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
                Expanded(child: item("Age",    Text(ageV,    style: value))),
                Expanded(child: item("City",   Text(cityV,   style: value, textAlign: TextAlign.center), align: TextAlign.center)),
                Expanded(child: item("Gender", Text(genderV, style: value, textAlign: TextAlign.right),  align: TextAlign.right)),
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
              child: item("Game", gamesWidget),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileAvatar({required String b64, required double outer}) {
    ImageProvider? img;
    if (b64.trim().isNotEmpty) {
      try { img = MemoryImage(base64Decode(b64)); } catch (_) {}
    }
    return Container(
      width: outer, height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent, width: 3),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.15), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: ClipOval(
        child: img != null
            ? Image(image: img, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFFEFEFEF),
                child: const Icon(Icons.person, color: Colors.black38, size: 36),
              ),
      ),
    );
  }

  Widget _circleButton({required double size, required IconData icon, required VoidCallback onTap}) {
    return _HoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _accent,
          border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: _accent.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }

  Widget _darkPillButton(
    String text, {
    required VoidCallback onTap,
    bool compact = false,
    IconData? icon,
    bool enabled = true,
  }) {
    final color = enabled ? _accent : const Color(0xFFB0B0B0);
    return _HoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 7 : 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: compact ? 14 : 16),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamsStripLikeX(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: PlayerService.watchMyAcceptedTeams(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 92, child: Center(child: CircularProgressIndicator()));
        }
        final teams = snap.data!;
        if (teams.isEmpty) {
  return SizedBox(
    height: 72,
    child: Center(
      child: Text(
        'You are not in a team yet.',
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
        final shown = teams.take(4).toList();
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(shown.length, (i) {
              return Padding(
                padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 16),
                child: _TeamSmallFromFirestore(team: shown[i]),
              );
            }),
          ),
        );
      },
    );
  }

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && mounted) {
      await BadgeUnlockNotifier.checkAndNotify(context: context, uid: uid);
    }
  });
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final route = ModalRoute.of(context);
  if (route?.isCurrent == true) {
    setState(() => _badgesRefreshKey++);
  }
}
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BADGE UNLOCK NOTIFIER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


List<Offset> _hexPoints(Offset center, double r, {double rotation = 0}) {
  return List.generate(6, (i) {
    final angle = rotation + (pi / 3) * i;
    return Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DIAMOND BADGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
class _DiamondPainter extends CustomPainter {
  final Color color;
  const _DiamondPainter({required this.color});
 
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R  = size.width * 0.46;
    final center = Offset(cx, cy);
 
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(_hexPath(center, R * 0.95, rotation: -pi / 6), shadowPaint);
 
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(_hexPath(center, R, rotation: -pi / 6), outerPaint);
 
    final innerPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(_hexPath(center, R * 0.72, rotation: -pi / 6), innerPaint);
 
    final rayPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final a1 = -pi / 6 + (pi / 3) * i;
      final a2 = a1 + pi / 6;
      final ray = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + R * 0.72 * cos(a1), cy + R * 0.72 * sin(a1))
        ..lineTo(cx + R * 0.50 * cos(a2), cy + R * 0.50 * sin(a2))
        ..close();
      canvas.drawPath(ray, rayPaint);
    }
 
    final dCx = cx;
    final dCy = cy + size.height * 0.02;
    final dR  = size.width * 0.20;
 
    final topFace = Path()
      ..moveTo(dCx,        dCy - dR)
      ..lineTo(dCx - dR,  dCy)
      ..lineTo(dCx,        dCy - dR * 0.1)
      ..lineTo(dCx + dR,  dCy)
      ..close();
    canvas.drawPath(topFace, Paint()..color = Colors.white.withOpacity(0.75)..style = PaintingStyle.fill);
 
    final leftFace = Path()
      ..moveTo(dCx - dR,  dCy)
      ..lineTo(dCx,        dCy - dR * 0.1)
      ..lineTo(dCx,        dCy + dR)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = Colors.white.withOpacity(0.45)..style = PaintingStyle.fill);
 
    final rightFace = Path()
      ..moveTo(dCx + dR,  dCy)
      ..lineTo(dCx,        dCy - dR * 0.1)
      ..lineTo(dCx,        dCy + dR)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = Colors.white.withOpacity(0.30)..style = PaintingStyle.fill);
 
    final dStroke = Paint()
      ..color = Colors.white.withOpacity(0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final dOutline = Path()
      ..moveTo(dCx,       dCy - dR)
      ..lineTo(dCx - dR,  dCy)
      ..lineTo(dCx,       dCy + dR)
      ..lineTo(dCx + dR,  dCy)
      ..close();
    canvas.drawPath(dOutline, dStroke);
 
    canvas.drawPath(
      _hexPath(center, R, rotation: -pi / 6),
      Paint()
        ..color = Colors.white.withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawPath(
      _hexPath(center, R * 0.80, rotation: -pi / 6),
      Paint()
        ..color = Colors.white.withOpacity(0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
 
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - R * 0.18, cy - R * 0.48),
      Offset(cx - R * 0.32, cy - R * 0.22),
      shinePaint,
    );
  }
 
  @override
  bool shouldRepaint(_DiamondPainter old) => old.color != color;
}
 
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLAME BADGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
class _FlamePainter extends CustomPainter {
  final Color color;
  const _FlamePainter({required this.color});
 
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R  = size.width * 0.46;
    final center = Offset(cx, cy);
 
    canvas.drawPath(
      _hexPath(center, R * 0.95, rotation: -pi / 6),
      Paint()..color = color.withOpacity(0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
 
    canvas.drawPath(_hexPath(center, R, rotation: -pi / 6), Paint()..color = color..style = PaintingStyle.fill);
 
    canvas.drawPath(
      _hexPath(center, R * 0.72, rotation: -pi / 6),
      Paint()..color = Colors.black.withOpacity(0.20)..style = PaintingStyle.fill,
    );
 
    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(cx, cy + size.height * 0.05), size.width * 0.22, glowPaint);
 
    final w = size.width * 0.52;
    final flameTop = cy - size.height * 0.26;
    final flameBot = cy + size.height * 0.28;
 
    final outerFlame = Path()
      ..moveTo(cx, flameTop)
      ..cubicTo(cx + w * 0.52, cy - size.height * 0.08, cx + w * 0.55, cy + size.height * 0.05, cx + w * 0.42, cy + size.height * 0.14)
      ..cubicTo(cx + w * 0.50, cy, cx + w * 0.32, cy - size.height * 0.02, cx + w * 0.32, cy + size.height * 0.12)
      ..cubicTo(cx + w * 0.32, cy + size.height * 0.22, cx + w * 0.45, cy + size.height * 0.25, cx, flameBot)
      ..cubicTo(cx - w * 0.45, cy + size.height * 0.25, cx - w * 0.32, cy + size.height * 0.22, cx - w * 0.32, cy + size.height * 0.12)
      ..cubicTo(cx - w * 0.32, cy - size.height * 0.02, cx - w * 0.50, cy, cx - w * 0.42, cy + size.height * 0.14)
      ..cubicTo(cx - w * 0.55, cy + size.height * 0.05, cx - w * 0.52, cy - size.height * 0.08, cx, flameTop)
      ..close();
    canvas.drawPath(outerFlame, Paint()..color = Colors.white.withOpacity(0.85)..style = PaintingStyle.fill);
 
    final innerFlame = Path()
      ..moveTo(cx, cy - size.height * 0.08)
      ..cubicTo(cx + w * 0.28, cy + size.height * 0.02, cx + w * 0.22, cy + size.height * 0.12, cx + w * 0.18, cy + size.height * 0.16)
      ..cubicTo(cx + w * 0.26, cy + size.height * 0.08, cx + w * 0.14, cy + size.height * 0.06, cx + w * 0.14, cy + size.height * 0.16)
      ..cubicTo(cx + w * 0.14, cy + size.height * 0.24, cx + w * 0.22, cy + size.height * 0.25, cx, flameBot - size.height * 0.06)
      ..cubicTo(cx - w * 0.22, cy + size.height * 0.25, cx - w * 0.14, cy + size.height * 0.24, cx - w * 0.14, cy + size.height * 0.16)
      ..cubicTo(cx - w * 0.14, cy + size.height * 0.06, cx - w * 0.26, cy + size.height * 0.08, cx - w * 0.18, cy + size.height * 0.16)
      ..cubicTo(cx - w * 0.22, cy + size.height * 0.12, cx - w * 0.28, cy + size.height * 0.02, cx, cy - size.height * 0.08)
      ..close();
    canvas.drawPath(innerFlame, Paint()..color = Colors.white.withOpacity(0.45)..style = PaintingStyle.fill);
 
    canvas.drawPath(
      _hexPath(center, R, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.28)..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    canvas.drawPath(
      _hexPath(center, R * 0.80, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.15)..style = PaintingStyle.stroke..strokeWidth = 0.5,
    );
  }
 
  @override
  bool shouldRepaint(_FlamePainter old) => old.color != color;
}
 
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TROPHY BADGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
class _TrophyPainter extends CustomPainter {
  final Color color;
  const _TrophyPainter({required this.color});
 
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R  = size.width * 0.46;
    final center = Offset(cx, cy);
 
    canvas.drawPath(
      _hexPath(center, R * 0.95, rotation: -pi / 6),
      Paint()..color = color.withOpacity(0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
 
    canvas.drawPath(_hexPath(center, R, rotation: -pi / 6), Paint()..color = color..style = PaintingStyle.fill);
 
    canvas.drawPath(
      _hexPath(center, R * 0.72, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.15)..style = PaintingStyle.fill,
    );
 
    final tW = size.width * 0.44;
    final tH = size.height * 0.38;
    final tX = cx - tW / 2;
    final tY = cy - size.height * 0.26;
 
    final cupBody = Path()
      ..moveTo(tX,        tY)
      ..lineTo(tX + tW,   tY)
      ..lineTo(tX + tW * 0.80, tY + tH)
      ..quadraticBezierTo(cx, tY + tH + size.height * 0.06, tX + tW * 0.20, tY + tH)
      ..close();
    canvas.drawPath(cupBody, Paint()..color = Colors.white.withOpacity(0.90)..style = PaintingStyle.fill);
 
    final cupShine = Path()
      ..moveTo(tX + tW * 0.15, tY + size.height * 0.03)
      ..lineTo(tX + tW * 0.38, tY + size.height * 0.03)
      ..lineTo(tX + tW * 0.30, tY + tH * 0.55)
      ..lineTo(tX + tW * 0.10, tY + tH * 0.55)
      ..close();
    canvas.drawPath(cupShine, Paint()..color = Colors.white.withOpacity(0.35)..style = PaintingStyle.fill);
 
    final lHandle = Path()
      ..moveTo(tX,             tY + size.height * 0.03)
      ..quadraticBezierTo(tX - tW * 0.24, tY + size.height * 0.10, tX - tW * 0.20, tY + tH * 0.55)
      ..quadraticBezierTo(tX - tW * 0.16, tY + tH * 0.72, tX + tW * 0.10, tY + tH * 0.68)
      ..lineTo(tX + tW * 0.10, tY + tH * 0.52)
      ..quadraticBezierTo(tX - tW * 0.02, tY + tH * 0.55, tX - tW * 0.04, tY + tH * 0.38)
      ..quadraticBezierTo(tX - tW * 0.06, tY + size.height * 0.12, tX + tW * 0.06, tY + size.height * 0.08)
      ..close();
    canvas.drawPath(lHandle, Paint()..color = Colors.white.withOpacity(0.55)..style = PaintingStyle.fill);
 
    final rHandle = Path()
      ..moveTo(tX + tW,        tY + size.height * 0.03)
      ..quadraticBezierTo(tX + tW * 1.24, tY + size.height * 0.10, tX + tW * 1.20, tY + tH * 0.55)
      ..quadraticBezierTo(tX + tW * 1.16, tY + tH * 0.72, tX + tW * 0.90, tY + tH * 0.68)
      ..lineTo(tX + tW * 0.90, tY + tH * 0.52)
      ..quadraticBezierTo(tX + tW * 1.02, tY + tH * 0.55, tX + tW * 1.04, tY + tH * 0.38)
      ..quadraticBezierTo(tX + tW * 1.06, tY + size.height * 0.12, tX + tW * 0.94, tY + size.height * 0.08)
      ..close();
    canvas.drawPath(rHandle, Paint()..color = Colors.white.withOpacity(0.40)..style = PaintingStyle.fill);
 
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - tW * 0.10, tY + tH + size.height * 0.06, tW * 0.20, size.height * 0.13),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withOpacity(0.80)..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - tW * 0.30, tY + tH + size.height * 0.19, tW * 0.60, size.height * 0.09),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withOpacity(0.80)..style = PaintingStyle.fill,
    );
 
    final starCx = cx;
    final starCy = tY + tH * 0.36;
    final starPath = Path();
    for (int i = 0; i < 5; i++) {
      final outerA = -pi / 2 + (2 * pi * i / 5);
      final innerA = outerA + pi / 5;
      final ox = starCx + size.width * 0.10 * cos(outerA);
      final oy = starCy + size.width * 0.10 * sin(outerA);
      final ix = starCx + size.width * 0.042 * cos(innerA);
      final iy = starCy + size.width * 0.042 * sin(innerA);
      i == 0 ? starPath.moveTo(ox, oy) : starPath.lineTo(ox, oy);
      starPath.lineTo(ix, iy);
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = color.withOpacity(0.55)..style = PaintingStyle.fill);
 
    canvas.drawPath(
      _hexPath(center, R, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.30)..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    canvas.drawPath(
      _hexPath(center, R * 0.80, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.18)..style = PaintingStyle.stroke..strokeWidth = 0.5,
    );
  }
 
  @override
  bool shouldRepaint(_TrophyPainter old) => old.color != color;
}
 
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MEDAL BADGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
class _MedalPainter extends CustomPainter {
  final Color color;
  const _MedalPainter({required this.color});
 
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R  = size.width * 0.46;
    final center = Offset(cx, cy);
 
    canvas.drawPath(
      _hexPath(center, R * 0.95, rotation: -pi / 6),
      Paint()..color = color.withOpacity(0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
 
    canvas.drawPath(_hexPath(center, R, rotation: -pi / 6), Paint()..color = color..style = PaintingStyle.fill);
 
    canvas.drawPath(
      _hexPath(center, R * 0.72, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.18)..style = PaintingStyle.fill,
    );
 
    final ribbonL = Path()
      ..moveTo(cx - size.width * 0.18, cy - R * 0.54)
      ..lineTo(cx,                     cy - R * 0.54)
      ..lineTo(cx - size.width * 0.04, cy - R * 0.12)
      ..lineTo(cx - size.width * 0.26, cy - R * 0.12)
      ..close();
    canvas.drawPath(ribbonL, Paint()..color = Colors.white.withOpacity(0.55)..style = PaintingStyle.fill);
 
    final ribbonR = Path()
      ..moveTo(cx + size.width * 0.18, cy - R * 0.54)
      ..lineTo(cx,                     cy - R * 0.54)
      ..lineTo(cx + size.width * 0.04, cy - R * 0.12)
      ..lineTo(cx + size.width * 0.26, cy - R * 0.12)
      ..close();
    canvas.drawPath(ribbonR, Paint()..color = Colors.white.withOpacity(0.35)..style = PaintingStyle.fill);
 
    final medalCy = cy + size.height * 0.10;
    final medalR  = size.width * 0.26;
 
    canvas.drawCircle(
      Offset(cx, medalCy), medalR,
      Paint()..color = Colors.white.withOpacity(0.90)..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, medalCy), medalR * 0.78,
      Paint()..color = Colors.white.withOpacity(0.50)..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, medalCy), medalR * 0.30,
      Paint()..color = Colors.white.withOpacity(0.90)..style = PaintingStyle.fill,
    );
 
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx - medalR * 0.28, medalCy - medalR * 0.28), radius: medalR * 0.28),
      -pi * 0.9, pi * 0.5, false,
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
 
    canvas.drawPath(
      _hexPath(center, R, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.28)..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    canvas.drawPath(
      _hexPath(center, R * 0.80, rotation: -pi / 6),
      Paint()..color = Colors.white.withOpacity(0.16)..style = PaintingStyle.stroke..strokeWidth = 0.5,
    );
  }
 
  @override
  bool shouldRepaint(_MedalPainter old) => old.color != color;
}

class BadgeUnlockNotifier {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  static Future<void> checkAndNotify({
    required BuildContext context,
    required String uid,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      final savedSnap = await db
          .collection('Player')
          .doc(uid)
          .collection('badges')
          .get();

      final newBadges = savedSnap.docs
          .where((d) => d.data()['seen'] != true)
          .toList();

      if (newBadges.isEmpty) return;

      for (final badgeDoc in newBadges) {
        if (!context.mounted) return;
        final data = badgeDoc.data();
        await _showBadgeDialog(context: context, data: data);

        await badgeDoc.reference.update({'seen': true});
      }
    } catch (e) {
      debugPrint('BadgeUnlockNotifier error: $e');
    }
  }

  static Future<void> _showBadgeDialog({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) async {
    final label    = (data['label']    ?? 'New Badge').toString();
    final iconType = (data['iconType'] ?? 'medal').toString();
    final type     = (data['type']     ?? '').toString();

    String subtitle = '';
    String detail   = '';

    if (type == 'win_rate_rank') {
      final wr    = (data['winRate']    as num?)?.toStringAsFixed(1) ?? '0';
      final games = (data['totalGames'] as num?)?.toString()         ?? '0';
      subtitle = 'Win Rate Rank';
      detail   = '$wr% win rate across $games matches';
    } else if (type == 'streak') {
      final streak = (data['streak'] as num?)?.toString() ?? '0';
      final game   = _gameLabel((data['game'] ?? '').toString());
      subtitle = 'Win Streak';
      detail   = '$streak wins in a row · $game';
    } else if (type == 'spark_mvp') {
      final wr   = (data['teamWinRate'] as num?)?.toStringAsFixed(1) ?? '0';
      final team = (data['teamName'] ?? '').toString();
      subtitle = 'Team Achievement';
      detail   = team.isNotEmpty ? '"$team" · $wr% WR' : '$wr% team win rate';
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Badge',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (ctx, anim, _, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(scale: curve, child: FadeTransition(opacity: anim, child: child));
      },
      pageBuilder: (ctx, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: _BadgeUnlockCard(
            label: label,
            subtitle: subtitle,
            detail: detail,
            iconType: iconType,
            onClaim: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  static String _gameLabel(String g) {
    switch (g.toLowerCase().trim()) {
      case 'lol':   return 'League of Legends';
      case 'pubg':  return 'PUBG';
      case 'dota2': return 'Dota 2';
      case 'team':  return 'Team';
      default:      return g.toUpperCase();
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BADGE UNLOCK CARD WIDGET
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _BadgeUnlockCard extends StatefulWidget {
  final String label;
  final String subtitle;
  final String detail;
  final String iconType;
  final VoidCallback onClaim;

  const _BadgeUnlockCard({
    required this.label,
    required this.subtitle,
    required this.detail,
    required this.iconType,
    required this.onClaim,
  });

  @override
  State<_BadgeUnlockCard> createState() => _BadgeUnlockCardState();
}

class _BadgeUnlockCardState extends State<_BadgeUnlockCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  static const Color _accent  = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark    = Color(0xFF0F1419);
  static const Color _muted   = Color(0xFF536471);
  static const Color _line    = Color(0xFFCFD9DE);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildIcon() {
    const color = _accent;
    CustomPainter painter;
    switch (widget.iconType) {
      case 'diamond': painter = _DiamondPainter(color: color); break;
      case 'fire':    painter = _FlamePainter(color: color);   break;
      case 'trophy':  painter = _TrophyPainter(color: color);  break;
      default:        painter = _MedalPainter(color: color);
    }
    return CustomPaint(size: const Size(100, 100), painter: painter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
_buildIcon(),

          const SizedBox(height: 16),

          Text(
            'Badge Unlocked!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _accent,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _dark,
              height: 1.1,
            ),
          ),

          if (widget.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ],

          if (widget.detail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Text(
                widget.detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: _HoverTap(
              onTap: widget.onClaim,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Text(
                  'Awesome!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
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
// SUGGESTIONS CONTAINER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SuggestionsContainer extends StatelessWidget {
  final String uid;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text   = Color(0xFF0F1419);
  static const Color _line   = Color(0xFFCFD9DE);

  const _SuggestionsContainer({required this.uid});

  static Color _scoreBarColor(double score) {
    final t = (score / 100.0).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFFF8A80), const Color(0xFFB71C1C), t)!;
  }

  static const Map<String, Color> _tierColors = {
    'Beginner': Color(0xFF22c55e),
    'Intermediate': Color(0xFFf59e0b),
    'Pro': Color(0xFFef4444),
  };

  static const Map<String, String> _gameImages = {
    'lol': 'assets/images/lol.png',
    'league of legends': 'assets/images/lol.png',
    'pubg': 'assets/images/pubg.png',
    'dota2': 'assets/images/dota2.png',
    'dota 2': 'assets/images/dota2.png',
  };

  static String _normalizeGameName(String g) {
    final s = g.toLowerCase().trim();
    if (s == 'lol' || s == 'leagueoflegends' || s == 'league of legends') return 'league of legends';
    if (s == 'dota' || s == 'dota 2') return 'dota2';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Player').doc(uid).collection('linkedGames').snapshots(),
      builder: (context, linkedSnap) {
  final linkedDocs = linkedSnap.data?.docs ?? [];
  if (linkedDocs.isEmpty) return const SizedBox.shrink();

  final verifiedDocs = linkedDocs.where((d) {
    final data = d.data() as Map<String, dynamic>;
    return data['lastFetchedAt'] != null;
  }).toList();
  if (verifiedDocs.isEmpty) return const SizedBox.shrink(); // ← الشرط الجديد

  final linkedAccounts =
      linkedDocs.map((d) => d.data() as Map<String, dynamic>).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Tournament').where('status', isEqualTo: 'upcoming').snapshots(),
          builder: (context, tournSnap) {
            final tournDocs = tournSnap.data?.docs ?? [];
            if (tournDocs.isEmpty) return const SizedBox.shrink();

            final tournaments = tournDocs
                .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
                .toList();

            final recommendations = RecommendationEngine.recommend(
              linkedAccounts: linkedAccounts, tournaments: tournaments,
            );

            if (recommendations.isEmpty) return const SizedBox.shrink();

            final shown = recommendations.take(5).toList();

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFCFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Suggestions",
                        style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: _text, height: 1),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: shown.length,
                          itemBuilder: (context, i) => Padding(
                            padding: EdgeInsets.only(right: i < shown.length - 1 ? 10 : 0),
                            child: _suggestionCard(context, shown[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            );
          },
        );
      },
    );
  }

  Widget _suggestionCard(BuildContext context, Map<String, dynamic> rec) {
    final Map<String, dynamic> tournament = rec['tournament'];
    final double score    = (rec['score'] as num).toDouble();
    final String tournTier = (tournament['tier']  ?? 'Beginner').toString();
    final String game      = (tournament['game']  ?? '').toString();
    final String title     = (tournament['Title'] ?? '').toString();
    final String tournId   = (tournament['id']    ?? '').toString();

    final Color  tierColor     = _tierColors[tournTier] ?? _accent;
    final String? gameImagePath = _gameImages[_normalizeGameName(game)];
    final Color  barColor      = _scoreBarColor(score);

    final tournImage = tournament['image'] ?? tournament['imageUrl'] ??
        tournament['tournamentImage'] ?? tournament['tournamentPhoto'] ??
        tournament['photo'] ?? tournament['imageBase64'];

    ImageProvider? tournImageProvider;
    if (tournImage != null && tournImage.toString().trim().isNotEmpty) {
      final s = tournImage.toString().trim();
      if (s.startsWith('http://') || s.startsWith('https://')) {
        tournImageProvider = NetworkImage(s);
      } else {
        try { tournImageProvider = MemoryImage(base64Decode(s)); } catch (_) {}
      }
    }

    return _HoverTap(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ViewTournamentPage(tournamentId: tournId),
      )),
      borderRadius: BorderRadius.circular(14),
      child: Container(
  width: 160,
  height: 130,
  decoration: BoxDecoration(
    color: Colors.white,
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
  clipBehavior: Clip.hardEdge,
  child: Stack(
    children: [
      if (tournImageProvider != null)
        Positioned.fill(
          child: Image(
            image: tournImageProvider,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),

      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.20),
                Colors.black.withOpacity(0.35),
                Colors.black.withOpacity(0.65),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: tierColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: gameImagePath != null
                      ? ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Image.asset(
                              gameImagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.sports_esports,
                                color: tierColor,
                                size: 16,
                              ),
                            ),
                          ),
                        )
                      : Icon(Icons.sports_esports, color: tierColor, size: 16),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tierColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    tournTier,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: tierColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Text(
              game,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white70,
                height: 1,
              ),
            ),

            const Spacer(),

            Text(
              'Match',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.75),
                height: 1,
              ),
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.30),
                      color: barColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${score.toInt()}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TEAM CARDS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TeamSmallFromFirestore extends StatelessWidget {
  final Map<String, dynamic> team;
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text   = Color(0xFF0F1419);

  const _TeamSmallFromFirestore({required this.team});

  ImageProvider? _decodeAnyImage(dynamic v) {
    if (v == null) return null;
    try {
      if (v is Blob) return MemoryImage(v.bytes);
      if (v is Uint8List) return MemoryImage(v);
      if (v is List<int>) return MemoryImage(Uint8List.fromList(v));
      if (v is Map && v['bytes'] is List) {
        return MemoryImage(Uint8List.fromList((v['bytes'] as List).cast<int>()));
      }
      if (v is String) {
        var s = v.trim();
        if (s.isEmpty) return null;
        if (s.startsWith('http://') || s.startsWith('https://')) return NetworkImage(s);
        if (s.startsWith('data:image')) {
          final idx = s.indexOf('base64,');
          if (idx != -1) s = s.substring(idx + 7);
        }
        return MemoryImage(base64Decode(s));
      }
    } catch (_) { return null; }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final teamId       = (team['teamId']   ?? '').toString();
    final fallbackName = (team['teamName'] ?? 'Team').toString();
    if (teamId.isEmpty) return const _TeamSmallPlaceholder();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('Team').doc(teamId).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = (data?['name'] ?? fallbackName).toString();
        ImageProvider? img;
        final candidates = [data?['logoUrl']];
        for (final v in candidates) { img = _decodeAnyImage(v); if (img != null) break; }

        return _HoverTap(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => TeamDetailsPage(teamId: teamId, teamName: name))),
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 76,
            child: Column(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 2.2),
                    color: Colors.white,
                    image: img != null ? DecorationImage(image: img!, fit: BoxFit.cover) : null,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 6))],
                  ),
                  child: img == null ? const Center(child: Icon(Icons.groups_rounded, color: _accent, size: 22)) : null,
                ),
                const SizedBox(height: 8),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800, color: _text, height: 1)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TeamSmallPlaceholder extends StatelessWidget {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  const _TeamSmallPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.white,
              border: Border.all(color: _accent, width: 2.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 6))],
            ),
            child: const Center(child: Icon(Icons.groups_rounded, color: _accent, size: 22)),
          ),
          const SizedBox(height: 8),
          const Text("Team", maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54, height: 1)),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HOVER TAP
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HoverTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _HoverTap({required this.child, required this.onTap, required this.borderRadius});

  @override
  State<_HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<_HoverTap> {
  bool _hover = false;
  bool _down  = false;

  @override
  Widget build(BuildContext context) {
    final canHover = Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;
    final scale = _down ? 0.98 : (_hover && canHover ? 1.02 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() { _hover = false; _down = false; }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown:   (_) => setState(() => _down = true),
        onTapCancel: ()  => setState(() => _down = false),
        onTapUp:     (_) => setState(() => _down = false),
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
                  ? [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 8))]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PERFORMANCE TABS + UPDATE + DASHBOARDS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _PerformanceTabsSection extends StatefulWidget {
  final String uid;

  const _PerformanceTabsSection({required this.uid});

  @override
  State<_PerformanceTabsSection> createState() =>
      _PerformanceTabsSectionState();
}

class _PerformanceTabsSectionState extends State<_PerformanceTabsSection> {
  int _selectedIndex = 0;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg     = Color(0xFFFAFAFA);
  static const Color _text   = Color(0xFF0F1419);
  static const Color _muted  = Color(0xFF536471);
  static const Color _line   = Color(0xFFCFD9DE);

  Widget _addGameButton(BuildContext context) {
    return _HoverTap(
      onTap: () async {
  final result = await Navigator.pushNamed(context, "/connect-game");

  if (result == true && mounted) {
    setState(() {});
  }
  if (!context.mounted) return;

  if (result == true && mounted) {
  setState(() {});
}

final uid = FirebaseAuth.instance.currentUser?.uid;

if (result == true && uid != null) {
  await Future.delayed(const Duration(milliseconds: 800));

  if (!mounted) return;

  await BadgeUnlockNotifier.checkAndNotify(
    context: context,
    uid: uid,
  );
}
},
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              "Add New Game",
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        _addGameButton(context),
      ],
    );
  }

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

    if ((ids.contains('dota2') || ids.contains('dota')) &&
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
              return Container(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 22,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: const Text(
                        'No connected games for this player.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            _selectedIndex = _selectedIndex.clamp(0, supported.length - 1);
            final selected = supported[_selectedIndex];

            return Container(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: _header(context),
                  ),
                  Container(
                    height: 44,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: _line, width: 1),
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
                                fontWeight:
                                    isSelected ? FontWeight.w800 : FontWeight.w600,
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
                    padding: const EdgeInsets.all(14),
                    child: _GamePerformanceBody(
                      uid: widget.uid,
                      gameId: selected,
                      accent: _accent,
                      text: _text,
                      muted: _muted,
                      line: _line,
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

class _GamePerformanceBody extends StatelessWidget {
  final String uid;
  final String gameId;
  final Color accent, text, muted, line;

  const _GamePerformanceBody({
    required this.uid, required this.gameId,
    required this.accent, required this.text, required this.muted, required this.line,
  });

  bool get _isLol  { final id = gameId.toLowerCase().trim(); return id == 'lol' || id == 'leagueoflegends' || id == 'league of legends'; }
  bool get _isPubg => gameId.toLowerCase().trim() == 'pubg';
  bool get _isDota => gameId.toLowerCase().trim() == 'dota2';

  @override
  Widget build(BuildContext context) {
    final title = _isLol ? 'LOL Performance' : '${gameId.toUpperCase()} Performance';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w800, color: text, height: 1)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniPill(label: 'Update', icon: Icons.sync_rounded, onTap: () async {
                  await _UpdateRunner.run(context: context, uid: uid, gameId: gameId);
                }),
                const SizedBox(width: 8),
                _MiniPill(label: 'Report', icon: Icons.analytics_rounded, onTap: () {
                  Navigator.pushNamed(context, "/player-report", arguments: {"gameId": gameId});
                }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity, height: 230,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
          child: _isLol
              ? _LolRadarDashboard(uid: uid, accent: accent, muted: muted)
              : _isPubg
                  ? _PubgRadarDashboard(uid: uid, accent: accent, muted: muted)
                  : _isDota
                      ? _DotaRadarDashboard(uid: uid, accent: accent, muted: muted)
                      : Center(child: Icon(Icons.show_chart_rounded, color: accent.withOpacity(0.7), size: 44)),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  static const Color _chip = Color(0xFFF0F3F4);
  static const Color _text = Color(0xFF0F1419);
  static const Color _line = Color(0xFFCFD9DE);

  const _MiniPill({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _HoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: _chip, borderRadius: BorderRadius.circular(999), border: Border.all(color: _line)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _text, size: 14),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w800, height: 1)),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// UPDATE RUNNER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ProgressState {
  final double value;
  final String label;
  const _ProgressState({required this.value, required this.label});
}

class _UpdateRunner {
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  static const String _pubgKey =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJqdGkiOiJkNjM0OWVhMC1lYjlkLTAxM2UtNzM5NC0wYTAyZmMzNTQ4YTUiLCJpc3MiOiJnYW1lbG9ja2VyIiwiaWF0IjoxNzcxMDUxMTY5LCJwdWIiOiJibHVlaG9sZSIsInRpdGxlIjoicHViZyIsImFwcCI6Ii0xOTJjY2U1My01NzEwLTRiODUtOWZhYi1hNWYyOTg5ZGEyOWUifQ.SgZMHWwwFED8JTyKgGe9mAYSBZE0cqc6fR8on7rj_EA';

  static Map<String, String> _pubgHeaders() => {
    'Authorization': 'Bearer ${_pubgKey.trim()}',
    'Accept': 'application/vnd.api+json',
  };
static String _friendlyUpdateError(Object e) {
  final msg = e.toString().toLowerCase();

  if (msg.contains('failed to fetch') || msg.contains('clientexception')) {
    return 'This game data could not be updated from browser testing. Please try again on the mobile app or emulator.';
  }

  if (msg.contains('timeout')) {
    return 'The game server took too long to respond. Please check your connection and try again.';
  }

  if (msg.contains('bad request') || msg.contains('decrypting')) {
    return 'This saved account link is no longer valid. Please reconnect the game account.';
  }

  if (msg.contains('no matches') || msg.contains('recentmatches')) {
    return 'No recent matches were found for this account. Try another active account.';
  }

  if (msg.contains('invalid') || msg.contains('expired') || msg.contains('auth')) {
    return 'The game API key is invalid or expired. Please update the key and try again.';
  }

  return 'Something went wrong while updating the game data. Please try again later.';
}
static Future<void> _showUpdateErrorDialog(
  BuildContext context,
  Object error,
) async {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCFD9DE)),
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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEB3D24).withOpacity(0.10),
                border: Border.all(
                  color: const Color(0xFFEB3D24).withOpacity(0.25),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEB3D24),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not update',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F1419),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _friendlyUpdateError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF536471),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEB3D24),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
static const Color _text   = Color(0xFF0F1419);
static const Color _muted  = Color(0xFF536471);
static const Color _line   = Color(0xFFCFD9DE);
  static Future<void> run({required BuildContext context, required String uid, required String gameId}) async {
    final ctrl = StreamController<_ProgressState>();
BuildContext? updateDialogContext;
    showDialog(
  context: context,
  barrierDismissible: false,
  builder: (dialogCtx) {
    updateDialogContext = dialogCtx;

    return StreamBuilder<_ProgressState>(
      stream: ctrl.stream,
      initialData: const _ProgressState(
        value: 0.02,
        label: 'Starting update...',
      ),
      builder: (context, snap) {
        final st = snap.data ?? const _ProgressState(value: 0.0, label: '');
        final v = st.value.clamp(0.0, 1.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withOpacity(0.10),
                    border: Border.all(
                      color: _accent.withOpacity(0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.sync_rounded,
                    color: _accent,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  "Updating Game Data",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  st.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 18),

                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: _accent,
                    backgroundColor: _accent.withOpacity(0.12),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "${(v * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
    

Future<void> closeOk() async {
  ctrl.add(const _ProgressState(value: 1.0, label: 'Done'));
  await Future.delayed(const Duration(milliseconds: 250));

  final dialogCtx = updateDialogContext;

  if (dialogCtx != null && dialogCtx.mounted) {
    Navigator.of(dialogCtx).pop();
  }
}

    try {
      final gid = gameId.toLowerCase().trim();

      if (gid == 'lol' || gid == 'leagueoflegends' || gid == 'league of legends') {
        final svc = RiotLinkService(FirebaseFirestore.instance);
        ctrl.add(const _ProgressState(value: 0.12, label: 'Clearing old stats...'));
        await svc.clearRoleStats(uid);
        ctrl.add(const _ProgressState(value: 0.45, label: 'Fetching match history...'));
        await svc.buildSeedsForLinkedLol(playerId: uid, maxMatches: 50, forceRefresh: true, allowNonRankedIfEmpty: true);
        ctrl.add(const _ProgressState(value: 0.78, label: 'Saving last 20 matches...'));
        await svc.saveLolMatchSummaries(playerId: uid, maxMatches: 20, forceRefresh: true);

await FirebaseFirestore.instance
    .collection('Player')
    .doc(uid)
    .collection('linkedGames')
    .doc('lol')
    .set({
  'lastFetchedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

await closeOk();
await _BadgesSectionInner.computeAndSyncBadges(uid); // ✅
if (context.mounted) {
  await BadgeUnlockNotifier.checkAndNotify(context: context, uid: uid); // ✅ يظهر popup
}
return;
      }

      if (gid == 'pubg') {
        print('UPDATE PUBG: started uid=$uid');
        ctrl.add(const _ProgressState(value: 0.10, label: 'Reading linked PUBG account...'));
        final linkDoc = await FirebaseFirestore.instance.collection('Player').doc(uid).collection('linkedGames').doc('pubg').get();
        final link = linkDoc.data() ?? <String, dynamic>{};
        final platform     = (link['platform']    ?? 'steam').toString().trim();
        final playerName   = (link['playerName']  ?? '').toString().trim();
        final pubgPlayerId = (link['pubgPlayerId'] ?? '').toString().trim();
        print('UPDATE PUBG: linked player=$playerName platform=$platform playerId=$pubgPlayerId');
        if (playerName.isEmpty || pubgPlayerId.isEmpty) throw Exception('PUBG not linked correctly. Reconnect PUBG.');

        ctrl.add(const _ProgressState(value: 0.22, label: 'Loading recent match ids...'));
        final matchIds = await _pubgFetchMatchIds(platform: platform, pubgPlayerId: pubgPlayerId, limit: 20);
        print('UPDATE PUBG: got ${matchIds.length} match IDs');
        final matchesRef = FirebaseFirestore.instance.collection('Player').doc(uid).collection('linkedGames').doc('pubg').collection('matches');

        for (int i = 0; i < matchIds.length; i++) {
          final matchId = matchIds[i];
          print('UPDATE PUBG: fetching ${i + 1}/${matchIds.length} id=$matchId');
          ctrl.add(_ProgressState(value: 0.22 + (i / matchIds.length) * 0.70, label: 'Fetching match ${i + 1}/${matchIds.length}...'));
          final matchJson = await _pubgFetchMatch(platform: platform, matchId: matchId);
          final created   = _pubgMatchCreatedAt(matchJson);
          final stats     = _pubgExtractMyParticipantStats(matchJson: matchJson, playerName: playerName);
          if (stats == null) continue;
          final kills     = (stats['kills']       as num?)?.toInt()    ?? 0;
          final assists   = (stats['assists']     as num?)?.toInt()    ?? 0;
          final damage    = (stats['damageDealt'] as num?)?.toDouble() ?? 0.0;
          final placement = (stats['winPlace']    as num?)?.toInt()    ?? 999;
          final score     = _pubgPerformanceScore(kills: kills, assists: assists, damage: damage, placement: placement);
          await matchesRef.doc(matchId).set({
            'matchId': matchId, 'platform': platform,
            'playerName': playerName, 'pubgPlayerId': pubgPlayerId,
            'kills': kills, 'assists': assists, 'damage': damage,
            'placement': placement, 'win': placement == 1,
            'performanceScore': score,
            'timestamp': Timestamp.fromDate(created),
            'source': 'pubg_api',
          }, SetOptions(merge: true));
          print(
  'UPDATE PUBG: saved match $matchId kills=$kills assists=$assists damage=$damage placement=$placement score=$score',
);
        }

        await FirebaseFirestore.instance
            .collection('Player')
            .doc(uid)
            .collection('linkedGames')
            .doc('pubg')
            .set({
          'lastFetchedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('UPDATE PUBG: finished for $uid');
        await closeOk();

        await _BadgesSectionInner.computeAndSyncBadges(uid);

        if (context.mounted) {
          await BadgeUnlockNotifier.checkAndNotify(context: context, uid: uid);
        }

        return;
      }

      if (gid == 'dota2' || gid == 'dota') {
        print('UPDATE DOTA: started uid=$uid');
        ctrl.add(const _ProgressState(value: 0.10, label: 'Reading linked Dota2 account...'));
        final linkDoc = await FirebaseFirestore.instance.collection('Player').doc(uid).collection('linkedGames').doc('dota2').get();
        final link      = linkDoc.data() ?? <String, dynamic>{};
        final accountId = (link['accountId'] is num) ? (link['accountId'] as num).toInt() : int.tryParse('${link['accountId']}');
        if (accountId == null || accountId <= 0) throw Exception('Dota2 not linked correctly. Reconnect Dota2.');
        print('UPDATE DOTA: accountId=$accountId');
        ctrl.add(const _ProgressState(value: 0.22, label: 'Fetching recent matches...'));
        final recent = await _dotaFetchRecentMatches(accountId, limit: 20);
        print('UPDATE DOTA: got ${recent.length} matches');
        final matchesRef = FirebaseFirestore.instance.collection('Player').doc(uid).collection('linkedGames').doc('dota2').collection('matches');

        for (int i = 0; i < recent.length; i++) {
          final row     = recent[i];
          final matchId = (row['match_id'] as num?)?.toInt() ?? 0;
          print('UPDATE DOTA: saving ${i + 1}/${recent.length} id=$matchId');
          if (matchId <= 0) continue;
          ctrl.add(_ProgressState(value: 0.22 + (i / recent.length) * 0.70, label: 'Saving match ${i + 1}/${recent.length}...'));
          final kills    = (row['kills']        as num?)?.toInt() ?? 0;
          final deaths   = (row['deaths']       as num?)?.toInt() ?? 0;
          final assists  = (row['assists']      as num?)?.toInt() ?? 0;
          final gpm      = (row['gold_per_min'] as num?)?.toInt() ?? 0;
          final xpm      = (row['xp_per_min']   as num?)?.toInt() ?? 0;
          final lastHits = (row['last_hits']    as num?)?.toInt() ?? 0;
          final score    = _dotaPerformanceScore(kills: kills, deaths: deaths, assists: assists, gpm: gpm, xpm: xpm, lastHits: lastHits);
          final startTime = (row['start_time'] as num?)?.toInt();
          final timestamp = (startTime != null) ? Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(startTime * 1000)) : Timestamp.now();
          final radiantWin = row['radiant_win'] == true;
          final playerSlot = (row['player_slot'] as num?)?.toInt() ?? 0;
          final isRadiant  = playerSlot < 128;
          final win = (isRadiant && radiantWin) || (!isRadiant && !radiantWin);
          await matchesRef.doc('$matchId').set({
            
            'matchId': matchId.toString(), 'accountId': accountId,
            'kills': kills, 'deaths': deaths, 'assists': assists,
            'gpm': gpm, 'xpm': xpm, 'lastHits': lastHits,
            'kda': ((kills + assists) / max(1, deaths)).toDouble(),
            'performanceScore': score, 'win': win,
            'timestamp': timestamp, 'source': 'opendota',
          }, SetOptions(merge: true));
          print(
  'UPDATE DOTA: saved match $matchId kills=$kills deaths=$deaths assists=$assists gpm=$gpm xpm=$xpm lastHits=$lastHits score=$score win=$win',
);
        }
      await FirebaseFirestore.instance
    .collection('Player')
    .doc(uid)
    .collection('linkedGames')
    .doc('dota2')
    .set({
  'lastFetchedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

print('UPDATE DOTA: finished for $uid');

await closeOk();

await _BadgesSectionInner.computeAndSyncBadges(uid);

if (context.mounted) {
  await BadgeUnlockNotifier.checkAndNotify(
    context: context,
    uid: uid,
  );
}

return;}

      await closeOk();
    } catch (e) {
      final dialogCtx = updateDialogContext;

if (dialogCtx != null && dialogCtx.mounted) {
  Navigator.of(dialogCtx).pop();
}
      if (!context.mounted) return;
      _showUpdateErrorDialog(context, e);
    } finally {
      await ctrl.close();
    }
  }

  static Future<List<String>> _pubgFetchMatchIds({required String platform, required String pubgPlayerId, int limit = 20}) async {
    final url = Uri.parse('https://api.pubg.com/shards/$platform/players/$pubgPlayerId');
    final res = await http.get(url, headers: _pubgHeaders());
    if (res.statusCode != 200) throw Exception('PUBG player fetch failed (${res.statusCode}).');
    final js        = jsonDecode(res.body) as Map<String, dynamic>;
    final dataObj   = js['data'] as Map<String, dynamic>;
    final rel       = dataObj['relationships'] as Map<String, dynamic>;
    final matches   = rel['matches'] as Map<String, dynamic>;
    final matchData = (matches['data'] as List?) ?? const [];
    return matchData.map((m) => (m as Map<String, dynamic>)['id']?.toString() ?? '').where((id) => id.isNotEmpty).take(limit).toList();
  }

  static Future<Map<String, dynamic>> _pubgFetchMatch({required String platform, required String matchId}) async {
    final url = Uri.parse('https://api.pubg.com/shards/$platform/matches/$matchId');
    final res = await http.get(url, headers: _pubgHeaders());
    if (res.statusCode != 200) throw Exception('PUBG match fetch failed (${res.statusCode}).');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Map<String, dynamic>? _pubgExtractMyParticipantStats({required Map<String, dynamic> matchJson, required String playerName}) {
    final included = matchJson['included'];
    if (included is! List) return null;
    final target = playerName.trim().toLowerCase();
    for (final item in included) {
      final m     = item as Map<String, dynamic>;
      if (m['type'] != 'participant') continue;
      final attrs = (m['attributes'] as Map?)?.cast<String, dynamic>();
      final stats = (attrs?['stats']  as Map?)?.cast<String, dynamic>();
      if (stats == null) continue;
      final n = (stats['name'] ?? '').toString().trim().toLowerCase();
      if (n == target) return stats;
    }
    return null;
  }

  static DateTime _pubgMatchCreatedAt(Map<String, dynamic> matchJson) {
    try {
      final dynamic raw = (matchJson['data'] as Map?)?['attributes']?['createdAt'];
      final createdAt = raw?.toString().trim();
      if (createdAt == null || createdAt.isEmpty) return DateTime.now();
      return DateTime.parse(createdAt).toLocal();
    } catch (_) { return DateTime.now(); }
  }

  static int _pubgPerformanceScore({required int kills, required int assists, required double damage, required int placement}) {
    final placementScore = max(0, 60 - (placement - 1) * 2);
    final killScore      = min(30, kills * 6);
    final assistScore    = min(10, assists * 3);
    final damageScore    = min(20, (damage / 50).round());
    return (placementScore + killScore + assistScore + damageScore).clamp(0, 100).toInt();
  }

  static Future<List<Map<String, dynamic>>> _dotaFetchRecentMatches(int accountId, {int limit = 20}) async {
    final url = Uri.parse('https://api.opendota.com/api/players/$accountId/recentMatches');
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('OpenDota recentMatches failed (${res.statusCode}).');
    final raw = jsonDecode(res.body);
    if (raw is! List) return const [];
    return raw.cast<Map<String, dynamic>>().take(limit).toList();
  }

  static int _dotaPerformanceScore({required int kills, required int deaths, required int assists, required int gpm, required int xpm, required int lastHits}) {
    final kda      = (kills + assists) / max(1, deaths);
    final kdaScore = (kda / 5.0 * 40).clamp(0, 40);
    final gpmScore = (gpm / 600.0 * 20).clamp(0, 20);
    final xpmScore = (xpm / 700.0 * 20).clamp(0, 20);
    final lhScore  = (lastHits / 250.0 * 20).clamp(0, 20);
    return (kdaScore + gpmScore + xpmScore + lhScore).round().clamp(0, 100);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DASHBOARDS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LolRadarDashboard extends StatelessWidget {
  final String uid; final Color accent, muted;
  const _LolRadarDashboard({required this.uid, required this.accent, required this.muted});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('Player').doc(uid)
        .collection('linkedGames').doc('lol').collection('matches')
        .orderBy('timestamp', descending: true).limit(20);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (docs.isEmpty) return Center(child: Text('No LOL matches yet.', style: TextStyle(color: muted, fontWeight: FontWeight.w700)));

        double wins = 0, kda = 0, cs = 0, gold = 0, dmg = 0, kp = 0, vision = 0;
        for (final d in docs) {
          final m = d.data();
          if (m['win'] == true) wins += 1;
          kda    += _num(m['kda']); cs += _num(m['csPerMin']); gold += _num(m['goldPerMin']);
          dmg    += _num(m['damagePerMin']);
          final kpRaw = _num(m['kp']);
          kp     += (kpRaw <= 1.01) ? (kpRaw * 100.0) : kpRaw;
          vision += _num(m['visionPerMin']);
        }
        final n = docs.length.toDouble();
        return _RadarStar(
          labels: ['Win Rate', 'KDA', 'CS/min', 'Gold/min', 'Damage/min', 'KP%', 'Vision/min'],
          values: [
            (wins / n).clamp(0.0, 1.0),
            (_num(kda / n) / 4.0).clamp(0.0, 1.0),
            (_num(cs / n)  / 9.0).clamp(0.0, 1.0),
            (_num(gold / n) / 450.0).clamp(0.0, 1.0),
            (_num(dmg / n)  / 700.0).clamp(0.0, 1.0),
            (_num(kp / n)   / 70.0).clamp(0.0, 1.0),
            (_num(vision / n) / 1.5).clamp(0.0, 1.0),
          ],
          accent: accent, muted: muted,
        );
      },
    );
  }
}

class _PubgRadarDashboard extends StatelessWidget {
  final String uid; final Color accent, muted;
  const _PubgRadarDashboard({required this.uid, required this.accent, required this.muted});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('Player').doc(uid)
        .collection('linkedGames').doc('pubg').collection('matches')
        .orderBy('timestamp', descending: true).limit(20);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (docs.isEmpty) return Center(child: Text('No PUBG matches yet.', style: TextStyle(color: muted, fontWeight: FontWeight.w700)));

        double wins = 0, kills = 0, assists = 0, damage = 0, placement = 0, score = 0;
        for (final d in docs) {
          final m = d.data();
          if (m['win'] == true) wins += 1;
          kills += _num(m['kills']); assists += _num(m['assists']); damage += _num(m['damage']);
          placement += _num(m['placement']); score += _num(m['performanceScore']);
        }
        final n = docs.length.toDouble();
        return _RadarStar(
          labels: ['Win Rate', 'Kills', 'Assists', 'Damage', 'Placement', 'Score'],
          values: [
            (wins / n).clamp(0.0, 1.0),
            (_num(kills / n)   / 10.0).clamp(0.0, 1.0),
            (_num(assists / n) / 5.0).clamp(0.0, 1.0),
            (_num(damage / n)  / 1500.0).clamp(0.0, 1.0),
            (1.0 - ((_num(placement / n) - 1.0) / 99.0)).clamp(0.0, 1.0),
            (_num(score / n)   / 100.0).clamp(0.0, 1.0),
          ],
          accent: accent, muted: muted,
        );
      },
    );
  }
}

class _DotaRadarDashboard extends StatelessWidget {
  final String uid; final Color accent, muted;
  const _DotaRadarDashboard({required this.uid, required this.accent, required this.muted});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('Player').doc(uid)
        .collection('linkedGames').doc('dota2').collection('matches')
        .orderBy('timestamp', descending: true).limit(20);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (docs.isEmpty) return Center(child: Text('No Dota matches yet.', style: TextStyle(color: muted, fontWeight: FontWeight.w700)));

        double wins = 0, kda = 0, gpm = 0, xpm = 0, lh = 0, score = 0;
        for (final d in docs) {
          final m = d.data();
          if (m['win'] == true) wins += 1;
          kda += _num(m['kda']); gpm += _num(m['gpm']); xpm += _num(m['xpm']);
          lh  += _num(m['lastHits']); score += _num(m['performanceScore']);
        }
        final n = docs.length.toDouble();
        return _RadarStar(
          labels: ['Win Rate', 'KDA', 'GPM', 'XPM', 'LastHits', 'Score'],
          values: [
            (wins / n).clamp(0.0, 1.0),
            (_num(kda / n)   / 5.0).clamp(0.0, 1.0),
            (_num(gpm / n)   / 600.0).clamp(0.0, 1.0),
            (_num(xpm / n)   / 700.0).clamp(0.0, 1.0),
            (_num(lh / n)    / 250.0).clamp(0.0, 1.0),
            (_num(score / n) / 100.0).clamp(0.0, 1.0),
          ],
          accent: accent, muted: muted,
        );
      },
    );
  }
}

class _RadarStar extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color accent, muted;

  const _RadarStar({required this.labels, required this.values, required this.accent, required this.muted})
      : assert(labels.length == values.length);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarStarPainter(labels: labels, values: values, accent: accent, muted: muted),
      child: const SizedBox.expand(),
    );
  }
}

class _RadarStarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color accent, muted;

  _RadarStarPainter({required this.labels, required this.values, required this.accent, required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final radius = min(size.width, size.height) * 0.40;
    final gridPaint = Paint()..color = const Color(0xFFCFD9DE)..style = PaintingStyle.stroke..strokeWidth = 1;

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
      canvas.drawLine(center, Offset(center.dx + radius * cos(a), center.dy + radius * sin(a)), gridPaint);
    }

    final pts = List.generate(n, (i) {
      final rr = radius * values[i].clamp(0.0, 1.0);
      final a  = _angle(i, n);
      return Offset(center.dx + rr * cos(a), center.dy + rr * sin(a));
    });

    canvas.drawPath(_polyPath(pts), Paint()..color = accent.withOpacity(0.20)..style = PaintingStyle.fill);
    canvas.drawPath(_polyPath(pts), Paint()..color = accent.withOpacity(0.95)..style = PaintingStyle.stroke..strokeWidth = 2.2);

    for (final p in pts) {
      canvas.drawCircle(p, 4.2, Paint()..color = accent.withOpacity(0.95));
      canvas.drawCircle(p, 4.2, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    for (int i = 0; i < n; i++) {
      final a  = _angle(i, n);
      final lp = Offset(center.dx + (radius + 20) * cos(a), center.dy + (radius + 20) * sin(a));
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800, color: muted)),
        textAlign: TextAlign.center, textDirection: TextDirection.ltr,
      )..layout(maxWidth: 96);
      tp.paint(canvas, Offset(lp.dx - tp.width / 2, lp.dy - tp.height / 2));
    }
  }

  double _angle(int i, int n) => -pi / 2 + (2 * pi * i / n);

  Path _polyPath(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) p.lineTo(pts[i].dx, pts[i].dy);
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant _RadarStarPainter old) {
    if (old.labels.length != labels.length) return true;
    for (int i = 0; i < values.length; i++) { if (old.values[i] != values[i]) return true; }
    return old.accent != accent || old.muted != muted;
  }
}

double _num(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
Future<void> computeAndSyncBadgesGlobal(String uid) async {
  await _BadgesSectionInner.computeAndSyncBadges(uid);
}
