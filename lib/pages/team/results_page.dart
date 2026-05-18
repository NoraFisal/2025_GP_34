// lib/pages/team/results_page.dart

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/player/model_service.dart';
import '../../services/player/player_role_stats.dart';
import '../../services/team/team_model_v5.dart';
import '../../services/player/team/team_service.dart';
import '../../services/chat/unified_chat_service.dart';
import '../chat/chat_list_page.dart';
import '../main_navigation_page.dart';
class ResultsPage extends StatefulWidget {
  final List<PickedPlayer> roster;
  final String teamName;
  final String description;
  final Uint8List? logoBytes;

  const ResultsPage({
    super.key,
    required this.roster,
    required this.teamName,
    required this.description,
    required this.logoBytes,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  // ✅ Simple button styles - NO hover/press effects
  ButtonStyle _darkButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: _dark,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const StadiumBorder(),
    );
  }

  ButtonStyle _whiteButton() {
    return OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: _dark,
      side: BorderSide(color: _dark.withOpacity(0.3), width: 1.3),
      elevation: 0,
      shape: const StadiumBorder(),
    );
  }

  ButtonStyle _redButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: _accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const StadiumBorder(),
    );
  }

bool _loading = true;

final Map<String, List<PlayerRoleStats>> _statsByPlayer = {};
List<Map<String, dynamic>> top3 = [];

// Reserved lineups = already used by pending or accepted teams
final Set<String> _reservedLineupKeys = {};

// ✅ FAST card flipping with spacing between cards
final PageController _pageCtrl = PageController(viewportFraction: 0.88);

@override
void initState() {
  super.initState();
  _loadStats();
}

@override
void dispose() {
  _pageCtrl.dispose();
  super.dispose();
}

Future<void> _loadStats() async {
  try {
    for (final p in widget.roster) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('Player')
            .doc(p.uid)
            .collection('linkedGames')
            .doc('lol')
            .collection('roleStats')
            .get();

        if (snap.docs.isEmpty) continue;

        final list = <PlayerRoleStats>[];
        for (final d in snap.docs) {
          list.add(PlayerRoleStats.fromFirestore(d.id, d.data()));
        }
        _statsByPlayer[p.uid] = list;
      } catch (_) {}
    }

    await computeTop3();
    await _loadReservedLineups();
  } catch (_) {}

  if (mounted) setState(() => _loading = false);
}

Future<void> computeTop3() async {
  final roles = ['top', 'jungle', 'middle', 'bottom', 'support'];
  final players = widget.roster;

  final perms = _permutePlayers(players);

  final model = ModelService();
  await model.ensureLoaded();
  await loadGlobalMeans();

  final results = <Map<String, dynamic>>[];

  for (final perm in perms) {
    final map = <String, String>{};
    bool valid = true;

    for (int i = 0; i < 5; i++) {
      final p = perm[i];
      final role = roles[i];

      final list = _statsByPlayer[p.uid] ?? [];
      final match = list.where((s) => s.role == role);

      if (match.isEmpty) {
        valid = false;
        break;
      }

      map[role] = p.uid;
    }

    if (!valid) continue;

    final team = <AssignedPlayer>[];

    for (final r in roles) {
      final uid = map[r]!;
      final stats = _statsByPlayer[uid]!.firstWhere((x) => x.role == r);

      team.add(
        AssignedPlayer(
          stats: stats,
          assignedRole: r,
        ),
      );
    }

    final tf = buildTeamFeatures(team, isBlueTeam: true);
    final vector = model.buildVector(tf.features);

    final prob = model.predict(vector);
    final wrNum = (prob * 100).clamp(0, 100);
    final wr = (wrNum as num).toDouble();

    final sortedEntries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final lineupKey =
        sortedEntries.map((e) => '${e.key}:${e.value}').join('|');

    results.add({
      'map': map,
      'winrate': wr,
      'lineupKey': lineupKey,
    });
  }

  results.sort((a, b) {
    final aw = (a['winrate'] as num).toDouble();
    final bw = (b['winrate'] as num).toDouble();
    return bw.compareTo(aw);
  });

  top3 = results.take(3).toList();
}

Future<void> _loadReservedLineups() async {
  _reservedLineupKeys.clear();

  try {
    final snap = await FirebaseFirestore.instance
        .collection('Team')
        .where(
          'status',
          whereIn: ['pending', 'Pending', 'accepted', 'Accepted'],
        )
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();

      final key = (data['lineupKey'] ?? '')
          .toString()
          .trim();

      final status = (data['status'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      final oldWR =
          ((data['winRate'] ?? 0) as num).toDouble();

      if (key.isEmpty) continue;

      // Pending = always reserved
      if (status == 'pending') {
        _reservedLineupKeys.add(key);
        continue;
      }

      // Accepted = reserve only if old WR >= new WR
      if (status == 'accepted') {
        final currentComp = top3.firstWhere(
          (c) => c['lineupKey'] == key,
          orElse: () => {},
        );

        if (currentComp.isNotEmpty) {
          final newWR =
              ((currentComp['winrate'] ?? 0) as num)
                  .toDouble();

          if (oldWR.round() >= newWR.round()) {
            _reservedLineupKeys.add(key);
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Error loading reserved lineups: $e');
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: Color(0xFF363435),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Top 3 Compositions',
        style: TextStyle(
          fontFamily: 'Inter',
          color: _accent,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _accent))
        : (top3.isEmpty
            ? const Center(
                child: Text(
                  'No valid compositions found',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _muted,
                    fontSize: 14,
                  ),
                ),
              )
            : Column(
                children: [
                  const SizedBox(height: 14),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: top3.length,
                      physics: const ClampingScrollPhysics(),
                      pageSnapping: true,
                      itemBuilder: (_, i) => _animatedCard(context, top3[i], i),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              )),
  );
}

// ✅ FAST with minimal smooth animation
Widget _animatedCard(BuildContext context, Map<String, dynamic> comp, int index) {
  return AnimatedBuilder(
    animation: _pageCtrl,
    builder: (context, child) {
      double value = 1.0;

      if (_pageCtrl.position.haveDimensions) {
        final p = (_pageCtrl.page ?? _pageCtrl.initialPage.toDouble());
        value = (p - index).abs();
        value = (1 - value * 0.05).clamp(0.95, 1.0);
      }

      return Center(
        child: Transform.scale(
          scale: value,
          child: _compositionCard(context, comp, index),
        ),
      );
    },
  );
}

// ✅ WHITE CARD with reserved-lineup disabled state
Widget _compositionCard(BuildContext context, Map<String, dynamic> comp, int index) {
  final lineupKey = (comp['lineupKey'] ?? '').toString();
  final isReserved = _reservedLineupKeys.contains(lineupKey);

  final winrate = (comp['winrate'] as num).toDouble().clamp(0.0, 100.0);
  final percent = (winrate / 100.0).clamp(0.0, 1.0);

  const roles = ['top', 'jungle', 'middle', 'bottom', 'support'];
  final map = (comp['map'] as Map).cast<String, String>();

  return LayoutBuilder(
    builder: (context, c) {
      final cardW = c.maxWidth;
      final cardH = math.min(MediaQuery.of(context).size.height * 0.70, 580.0);
      final gaugeSize = math.min(cardW * 0.52, 240.0);

      return SizedBox(
        width: cardW,
        height: cardH,
        child: Container(
          decoration: BoxDecoration(
            color: isReserved
                ? Colors.grey.shade200.withOpacity(0.75)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isReserved ? Colors.grey.shade400 : _line,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: isReserved ? Colors.grey : _accent,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableHeight = constraints.maxHeight;
                      final adjustedGaugeSize =
                          math.min(gaugeSize, availableHeight * 0.85);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: adjustedGaugeSize,
                            height: adjustedGaugeSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: adjustedGaugeSize,
                                  height: adjustedGaugeSize,
                                  child: _DonutGauge(
                                    percent: percent,
                                    thickness: 18,
                                    accent: isReserved ? Colors.grey : _accent,
                                    baseColor: isReserved
                                        ? Colors.grey.withOpacity(0.18)
                                        : _accent.withOpacity(0.12),
                                  ),
                                ),
                                Text(
                                  '${winrate.round()}%',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: isReserved ? Colors.grey.shade700 : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final r in roles)
                      _playerAvatarWithPill(uid: map[r] ?? '', roleLabel: r),
                  ],
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: 210,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isReserved
                        ? null
                        : () => _saveTeamToFirestore(context, map, winrate),
                    style: isReserved
                        ? ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          )
                        : _darkButton(),
                    child: Text(
                      isReserved ? 'Unavailable' : 'Select',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  // ✅ BIGGER player avatars (52 instead of 44)
  Widget _playerAvatarWithPill({required String uid, required String roleLabel}) {
    final p = widget.roster.firstWhere(
      (x) => x.uid == uid,
      orElse: () => PickedPlayer(uid: uid, name: 'Player', photoUrl: ''),
    );

    final name = (p.name).trim().isEmpty ? 'Player' : p.name.trim();
    final role = _displayRole(roleLabel);
    final provider = _avatarProvider(p.photoUrl);

    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ BIGGER avatar: 52 instead of 44
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 2.4),
              color: Colors.white,
            ),
            child: ClipOval(
              child: provider == null
                  ? const Icon(Icons.person, color: Colors.black38, size: 26)
                  : Image(image: provider, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withOpacity(0.25), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  name,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _avatarProvider(String raw) {
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

  String _displayRole(String role) {
    switch (role) {
      case 'top':
        return 'TOP';
      case 'jungle':
        return 'JUNGLE';
      case 'middle':
        return 'MIDDLE';
      case 'bottom':
        return 'BOTTOM';
      case 'support':
        return 'SUPPORT';
      default:
        return role.toUpperCase();
    }
  }

  Future<void> _saveTeamToFirestore(
  BuildContext context,
  Map<String, String> mapping,
  double winrate,
) async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    if (!context.mounted) return;
    await _showInfoPopup(
      context,
      title: 'Login required',
      message: 'You must be logged in to create a team.',
    );
    return;
  }

  final trimmedName = widget.teamName.trim();
  if (trimmedName.isEmpty) {
    if (!context.mounted) return;
    await _showInfoPopup(
      context,
      title: 'Add team name',
      message: 'Please enter a team name before creating your team.',
    );
    return;
  }

  final sortedEntries = mapping.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final lineupKey = sortedEntries.map((e) => '${e.key}:${e.value}').join('|');

  final db = FirebaseFirestore.instance;

  try {
    final snap = await db
        .collection('Team')
        .where('lineupKey', isEqualTo: lineupKey)
        .get();

    bool hasAcceptedSameWr = false;
    bool hasPendingSameWr = false;

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase().trim();
      final oldWR = (data['winRate'] ?? 0 as num).toDouble();

      final sameWR = oldWR.toStringAsFixed(0) == winrate.toStringAsFixed(0);
      if (!sameWR) continue;

      if (status == 'accepted') {
        hasAcceptedSameWr = true;
      } else if (status == 'pending') {
        hasPendingSameWr = true;
      }
    }

    if (hasAcceptedSameWr) {
      if (!context.mounted) return;
      await _showInfoPopup(
        context,
        title: 'Already used lineup',
        message:
            'This exact lineup and winrate has already been accepted.\nPlease choose a different combination.',
      );
      return;
    }

    if (hasPendingSameWr) {
      if (!context.mounted) return;
      final again = await _confirmPopup(
        context,
        title: 'Lineup already pending',
        message:
            'You already have a team with this lineup and winrate that is still pending.\nDo you want to send another set of invitations?',
        leftText: 'No',
        rightText: 'Yes',
      );
      if (!again) return;
    } else {
      if (!context.mounted) return;
      final confirmNew = await _confirmPopup(
        context,
        title: 'New Lineup',
        message:
            "This combination of players hasn't been used before.\nAre you sure you want to continue?",
        leftText: 'Cancel',
        rightText: 'Yes',
      );
      if (!confirmNew) return;
    }
  } catch (e) {
    if (!context.mounted) return;
    await _showInfoPopup(context, title: 'Error', message: e.toString());
    return;
  }

  String? logoBase64;
  if (widget.logoBytes != null && widget.logoBytes!.isNotEmpty) {
    try {
      logoBase64 = base64Encode(widget.logoBytes!);
    } catch (_) {}
  }

  // 🔄 عرض مؤشّر التحميل
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.25),
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: _accent),
    ),
  );

  try {
    // ✅ إنشاء مستند الفريق
    final teamRef = db.collection('Team').doc();

    await teamRef.set({
      'name': trimmedName,
      'description': widget.description,
      'winRate': winrate,
      'lineupKey': lineupKey,
      'status': 'pending',
      'createdBy': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      if (logoBase64 != null) 'logoUrl': logoBase64,
    });

    // ✅ إضافة الأعضاء للأعضاء الفرعية
    for (final entry in mapping.entries) {
      await teamRef.collection('Members').doc(entry.value).set({
        'role': entry.key,
        'response': entry.value == currentUser.uid ? 'Accepted' : 'none',
      });
    }

    // ✅ إنشاء محادثة الفريق في النظام الجديد الموحّد
    final membersSnap =
        await db.collection('Team').doc(teamRef.id).collection('Members').get();
    final members = membersSnap.docs.map((d) => d.id).toList();

    // إنشاء الشات عبر UnifiedChatService
    await UnifiedChatService.createTeamChat(
      teamRef.id,
      members,
      logoUrl: logoBase64,
    );

    // ✅ إغلاق المؤشر ثم التوجيه لقائمة المحادثات -> تبويب Requests
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainNavigationPage(initialIndex: 2),
      ),
      (route) => false, // clear all previous routes
    );
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;
    await _showInfoPopup(
      context,
      title: 'Error',
      message: 'Failed to create team.\n$e',
    );
  }
}

  // ✅ Unified style matching Logout dialog
  Future<void> _showInfoPopup(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
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
                  child: const Icon(Icons.info_outline_rounded, color: _accent, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: _text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
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
                          'Got it',
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmPopup(
    BuildContext context, {
    required String title,
    required String message,
    required String leftText,
    required String rightText,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
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
                  child: const Icon(Icons.help_outline_rounded, color: _accent, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: _text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF536471),
                          side: const BorderSide(color: Color(0xFFCFD9DE)),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          leftText,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          rightText,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return res ?? false;
  }

  List<List<PickedPlayer>> _permutePlayers(List<PickedPlayer> players) {
    if (players.length < 5) return [];

    final list = players.take(5).toList();
    final results = <List<PickedPlayer>>[];

    void permute(int start) {
      if (start == list.length) {
        results.add(List.from(list));
        return;
      }
      for (int i = start; i < list.length; i++) {
        final tmp = list[start];
        list[start] = list[i];
        list[i] = tmp;

        permute(start + 1);

        final tmp2 = list[start];
        list[start] = list[i];
        list[i] = tmp2;
      }
    }

    permute(0);
    return results;
  }
}

class _DonutGauge extends StatelessWidget {
  final double percent;
  final double thickness;
  final Color accent;
  final Color baseColor;

  const _DonutGauge({
    required this.percent,
    required this.thickness,
    required this.accent,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(
        percent: percent,
        thickness: thickness,
        accent: accent,
        baseColor: baseColor,
      ),
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
    final sweep = 2 * math.pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.thickness != thickness ||
        oldDelegate.accent != accent ||
        oldDelegate.baseColor != baseColor;
  }
}