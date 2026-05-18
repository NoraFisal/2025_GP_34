// lib/pages/player/player_report_page.dart
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// PDF + share
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'report_chatbot_page.dart';
import '../../services/chat/unified_chat_service.dart';

class PlayerReportPage extends StatefulWidget {
  const PlayerReportPage({super.key});

  @override
  State<PlayerReportPage> createState() => _PlayerReportPageState();
}

class _PlayerReportPageState extends State<PlayerReportPage> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  int _recentN = 20;

  Future<_ReportData>? _future;
  _ReportData? _lastData;

  bool _fabOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null) {
      final args =
          (ModalRoute.of(context)?.settings.arguments as Map?) ?? const {};
      final gameId = _normalizeGameId((args['gameId'] ?? '').toString());
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null && gameId.isNotEmpty) {
        _future = _loadReport(uid: uid, gameId: gameId, recentN: _recentN);
      }
    }
  }

  static String _normalizeGameId(String raw) {
    final v = raw.toLowerCase().trim();
    if (v == 'league of legends' || v == 'leagueoflegends' || v == 'lol') {
      return 'lol';
    }
    if (v == 'dota 2' || v == 'dota' || v == 'dota2') return 'dota2';
    if (v == 'pubg' || v == 'playerunknown\'s battlegrounds') return 'pubg';
    return v;
  }

  static String _gameTitle(String gameId) {
    final g = _normalizeGameId(gameId);
    if (g == 'lol') return 'League of Legends';
    if (g == 'dota2') return 'Dota 2';
    if (g == 'pubg') return 'PUBG';
    return gameId.toUpperCase();
  }

  Future<void> _updateFocusStatus({
  required String uid,
  required String gameId,
  required String status,
  required _Goal? currentGoal,
}) async {
  final docRef = FirebaseFirestore.instance
      .collection('Player')
      .doc(uid)
      .collection('linkedGames')
      .doc(gameId);

  if (status == 'done') {
    await docRef.set({
      'reportFocus': {
        'status': 'done',
        'title': '',
        'description': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  } else {
    await docRef.set({
      'reportFocus': {
        'status': status,
        'title': currentGoal?.title ?? '',
        'description': currentGoal?.description ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  setState(() {
    _future = _loadReport(uid: uid, gameId: gameId, recentN: _recentN);
  });
}

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map?) ?? const {};
    final gameId = _normalizeGameId((args['gameId'] ?? '').toString());
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || gameId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Missing user or gameId")),
      );
    }

    _future ??= _loadReport(uid: uid, gameId: gameId, recentN: _recentN);

     return Scaffold(
  backgroundColor: _bg,

  floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  floatingActionButton: SizedBox(
    width: MediaQuery.of(context).size.width,
    height: 300,
    child: _buildSpeedDial(context, uid, gameId),
  ),

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
  title: Text(
    '${_gameTitle(gameId)} Report',
    style: const TextStyle(
      fontFamily: 'Inter',
      color: _accent,
      fontSize: 22,
      fontWeight: FontWeight.w900,
    ),
  ),
),
      body: FutureBuilder<_ReportData>(
        future: _future,
        builder: (context, snap) {
          final isWaiting = snap.connectionState == ConnectionState.waiting;
          final data = snap.data ?? _lastData;

          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasData) _lastData = snap.data;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _loadReport(uid: uid, gameId: gameId, recentN: _recentN);
              });
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (isWaiting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),

                const SizedBox(height: 18),
                const _SectionTitle("Overview"),
                const SizedBox(height: 10),
                _OverviewCards(data: data),

                const SizedBox(height: 18),
                const _SectionTitle("Strengths & Weaknesses"),
                const SizedBox(height: 10),
                _StrengthWeakness(data: data),

                const SizedBox(height: 18),
                const _SectionTitle("Trends (recent vs previous)"),
                const SizedBox(height: 10),
                _Trends(data: data),

                const SizedBox(height: 18),
const _SectionTitle("Current Focus Status"),
const SizedBox(height: 10),

if (data.focusStatus != 'done')
  _FocusStatusCard(
    currentGoal: data.goals.isNotEmpty ? data.goals.first : null,
    status: data.focusStatus,
    onStatusChanged: (status) async {
      await _updateFocusStatus(
        uid: uid,
        gameId: gameId,
        status: status,
        currentGoal: data.goals.isNotEmpty ? data.goals.first : null,
      );
    },
  )
else
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      "Current focus completed. Update your game data to generate a new focus.",
      style: TextStyle(
        fontFamily: 'Inter',
        color: _muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),

const SizedBox(height: 18),
const _SectionTitle("Next Focus"),
const SizedBox(height: 10),

_FocusGoals(data: data),

const SizedBox(height: 18),
_MetaInfo(data: data),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_ReportData> _loadReport({
    required String uid,
    required String gameId,
    required int recentN,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('Player')
        .doc(uid)
        .collection('linkedGames')
        .doc(gameId);

    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      return _ReportData.empty(gameId: gameId);
    }

    final m = (docSnap.data() as Map<String, dynamic>);
    final dashboard = (m['dashboard'] as Map?)?.cast<String, dynamic>() ?? {};
    final stats =
        (dashboard['stats'] as Map?)?.cast<String, dynamic>() ?? const {};

    final rootValues = (m['values'] as Map?)?.cast<String, dynamic>() ?? {};
    final dashValues =
        (dashboard['values'] as Map?)?.cast<String, dynamic>() ?? {};

    final values = <String, dynamic>{...rootValues, ...dashValues};
    if (values.isEmpty) {
      values.addAll(stats);
    }

    final overallScore = (dashboard['overallScore'] ?? m['score'] ?? 0);
    final computedAt = m['dashboardComputedAt'];
    final lastFetchedAt = m['lastFetchedAt'];

    final int totalToFetch = recentN * 2;
    final matchesQuery = await docRef
        .collection('matches')
        .orderBy('timestamp', descending: true)
        .limit(totalToFetch)
        .get();

    final matches = matchesQuery.docs
        .map((d) => d.data().cast<String, dynamic>())
        .toList();

    final recent = matches.take(recentN).toList();
    final previous = matches.skip(recentN).take(recentN).toList();

    final cfg = _GameReportConfig.forGame(gameId);

    final recentAgg = _aggregateMatches(cfg, recent);
    final prevAgg = _aggregateMatches(cfg, previous);

    final strengths = _pickTop(values, cfg.metricOrder, top: true, count: 3);
    final weaknesses = _pickTop(values, cfg.metricOrder, top: false, count: 3);
    final trends = _computeTrends(cfg, recentAgg, prevAgg);
    final goals = _makeGoals(cfg, recentAgg, weaknesses);

    final reportFocus =
        (m['reportFocus'] as Map?)?.cast<String, dynamic>();

  
    // ✅ auto-create only if there is NO focus at all
final reportFocusStatus = (reportFocus?['status'] ?? '').toString();
final reportFocusTitle = (reportFocus?['title'] ?? '').toString().trim();
final reportFocusUpdatedAt = _asDateTime(reportFocus?['updatedAt']);

final dataUpdatedAfterDone =
    reportFocusStatus == 'done' &&
    lastFetchedAt is Timestamp &&
    reportFocusUpdatedAt != null &&
    lastFetchedAt.toDate().isAfter(reportFocusUpdatedAt);

final shouldCreateFocus =
    (reportFocus == null || reportFocus.isEmpty) ||
    (reportFocusStatus != 'done' && reportFocusTitle.isEmpty) ||
    dataUpdatedAfterDone;

if (shouldCreateFocus && goals.isNotEmpty) {
  final g = goals.first;

  await docRef.set({
    'reportFocus': {
      'status': 'not_started',
      'title': g.title,
      'description': g.description,
      'updatedAt': FieldValue.serverTimestamp(),
    }
  }, SetOptions(merge: true));
}

    final refreshedSnap = await docRef.get();
    final refreshedData = (refreshedSnap.data() as Map<String, dynamic>);
    final refreshedReportFocus =
        (refreshedData['reportFocus'] as Map?)?.cast<String, dynamic>() ?? const {};
    final focusStatus = (refreshedReportFocus['status'] ?? 'not_started').toString();
    final focusUpdatedAt = _asDateTime(refreshedReportFocus['updatedAt']);
    

    return _ReportData(
      gameId: gameId,
      overallScore: (overallScore is num) ? overallScore.toDouble() : 0.0,
      stats: stats,
      values: values,
      computedAt: _asDateTime(computedAt),
      lastFetchedAt: _asDateTime(lastFetchedAt),
      focusUpdatedAt: focusUpdatedAt,
      recentMatches: recent,
      prevMatches: previous,
      recentAgg: recentAgg,
      prevAgg: prevAgg,
      strengths: strengths,
      weaknesses: weaknesses,
      trends: trends,
      goals: goals,
      focusStatus: focusStatus,
    );
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static Map<String, double> _aggregateMatches(
    _GameReportConfig cfg,
    List<Map<String, dynamic>> matches,
  ) {
    if (matches.isEmpty) return {};

    final out = <String, double>{};

    for (final k in cfg.matchNumericKeys) {
      final nums = <double>[];
      for (final m in matches) {
        final v = m[k];
        if (v is num) nums.add(v.toDouble());
      }
      if (nums.isNotEmpty) {
        out[k] = nums.reduce((a, b) => a + b) / nums.length;
      }
    }

    final wins = matches.where((m) => m['win'] == true).length;
    out['winRate'] = wins / max(1, matches.length);

    return out;
  }

  static List<_Pick> _pickTop(
    Map<String, dynamic> values,
    List<String> orderedKeys, {
    required bool top,
    required int count,
  }) {
    final picks = <_Pick>[];
    for (final k in orderedKeys) {
      final v = values[k];
      if (v is num) picks.add(_Pick(key: k, normalized: v.toDouble()));
    }

    picks.sort(
      (a, b) => top
          ? b.normalized.compareTo(a.normalized)
          : a.normalized.compareTo(b.normalized),
    );
    return picks.take(count).toList();
  }

  static List<_Trend> _computeTrends(
    _GameReportConfig cfg,
    Map<String, double> recentAgg,
    Map<String, double> prevAgg,
  ) {
    final items = <_Trend>[];
    for (final k in cfg.trendKeys) {
      final r = recentAgg[k];
      final p = prevAgg[k];
      if (r == null || p == null) continue;

      items.add(_Trend(key: k, recent: r, previous: p, delta: r - p));
    }
    items.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
    return items;
  }

  static List<_Goal> _makeGoals(
    _GameReportConfig cfg,
    Map<String, double> recentAgg,
    List<_Pick> weaknesses,
  ) {
    switch (cfg.gameId) {
      case 'lol':
        return _makeLolGoals(cfg, recentAgg, weaknesses);
      case 'dota2':
        return _makeDotaGoals(cfg, recentAgg, weaknesses);
      case 'pubg':
        return _makePubgGoals(cfg, recentAgg, weaknesses);
      default:
        return _makeGenericGoals(cfg, recentAgg, weaknesses);
    }
  }

  static List<_Goal> _makeLolGoals(
    _GameReportConfig cfg,
    Map<String, double> recentAgg,
    List<_Pick> weaknesses,
  ) {
    final goals = <_Goal>[];

    for (final w in weaknesses.take(3)) {
      final key = w.key;
      final matchKey = cfg.normalizedToMatchKey[key] ?? key;
      final current = recentAgg[matchKey];

      switch (key) {
        case 'csPerMin':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Farming',
            description:
                'Stay in lane longer and collect more minions before roaming. Try not to leave waves unfinished.',
          ));
          break;
        case 'visionPerMin':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Map Vision',
            description:
                'Place more vision before fights and around important areas so your team can see danger earlier.',
          ));
          break;
        case 'kp':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Fight Participation',
            description:
                'Stay closer to your team during skirmishes so you can help in more kills and team fights.',
          ));
          break;
        case 'kda':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Safer Fighting',
            description:
                'Avoid risky fights when alone. Only commit when teammates are nearby and the fight looks favorable.',
          ));
          break;
        case 'goldPerMin':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Gold Income',
            description:
                'Spend more time farming safely and avoid wasting time on low-value movement around the map.',
          ));
          break;
        case 'winRate':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Game Decisions',
            description:
                'Play more safely when behind and avoid unnecessary fights that can swing the game against your team.',
          ));
          break;
      }
    }

    return goals.isEmpty ? _makeGenericGoals(cfg, recentAgg, weaknesses) : goals;
  }

  static List<_Goal> _makeDotaGoals(
    _GameReportConfig cfg,
    Map<String, double> recentAgg,
    List<_Pick> weaknesses,
  ) {
    final goals = <_Goal>[];

    for (final w in weaknesses.take(3)) {
      final key = w.key;
      final matchKey = cfg.normalizedToMatchKey[key] ?? key;
      final current = recentAgg[matchKey];

      switch (key) {
        case 'gpm':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Gold Farm',
            description:
                'Spend more time farming safely between fights so your item progression stays on track.',
          ));
          break;
        case 'xpm':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Experience Gain',
            description:
                'Avoid missing lane or jungle time so you keep leveling up at a steady pace.',
          ));
          break;
        case 'lastHits':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Last Hitting',
            description:
                'Focus more on securing creep kills during lane and quiet moments instead of forcing low-value fights.',
          ));
          break;
        case 'kda':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Safer Engagements',
            description:
                'Be more selective with fights. Join when your team is ready instead of taking isolated risks.',
          ));
          break;
        case 'winRate':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Cleaner Team Play',
            description:
                'Play around your team’s timing and avoid solo decisions that can cost map control.',
          ));
          break;
      }
    }

    return goals.isEmpty ? _makeGenericGoals(cfg, recentAgg, weaknesses) : goals;
  }

  static List<_Goal> _makePubgGoals(
    _GameReportConfig cfg,
    Map<String, double> recentAgg,
    List<_Pick> weaknesses,
  ) {
    final goals = <_Goal>[];

    for (final w in weaknesses.take(3)) {
      final key = w.key;
      final matchKey = cfg.normalizedToMatchKey[key] ?? key;
      final current = recentAgg[matchKey];

      switch (key) {
        case 'placement':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Survival',
            description:
                'Try to stay alive longer before taking risky fights. Better positioning can improve placement a lot.',
          ));
          break;
        case 'damage':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Damage Output',
            description:
                'Take more safe shots from distance and pressure enemies before pushing into close fights.',
          ));
          break;
        case 'kills':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Fight Finishing',
            description:
                'Look for better timing when enemies are already weak instead of forcing difficult fights too early.',
          ));
          break;
        case 'winRate':
          goals.add(_buildGoal(
            cfg: cfg,
            key: key,
            current: current,
            title: 'Match Outcomes',
            description:
                'Play for stronger positions and avoid unnecessary exposure in the middle of the match.',
          ));
          break;
      }
    }

    return goals.isEmpty ? _makeGenericGoals(cfg, recentAgg, weaknesses) : goals;
  }

  static List<_Goal> _makeGenericGoals(
    _GameReportConfig cfg,
    Map<String, double> recentAgg,
    List<_Pick> weaknesses,
  ) {
    final goals = <_Goal>[];

    for (final w in weaknesses.take(3)) {
      final key = w.key;
      final matchKey = cfg.normalizedToMatchKey[key] ?? key;
      final current = recentAgg[matchKey];

      goals.add(_buildGoal(
        cfg: cfg,
        key: key,
        current: current,
        title: cfg.labelFor(key),
        description:
            'Focus on improving this area in your next matches and try to play more consistently.',
      ));
    }

    return goals;
  }

  static _Goal _buildGoal({
    required _GameReportConfig cfg,
    required String key,
    required double? current,
    required String title,
    required String description,
  }) {
    final metric = cfg.metrics[key];
    if (current == null) {
      return _Goal(
        title: title,
        description: description,
        targetText: 'Target: improve by ~10%',
      );
    }

    final higherIsBetter = metric?.higherIsBetter ?? true;
    final target = higherIsBetter ? current * 1.10 : current * 0.90;

    return _Goal(
      title: title,
      description: description,
      targetText:
          'Now: ${cfg.format(key, current)}  ->  Goal: ${cfg.format(key, target)}',
    );
  }

  Widget _buildSpeedDial(BuildContext context, String uid, String gameId) {
  return Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 8),
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          right: _fabOpen ? 150 : 0,
bottom: _fabOpen ? 8 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _fabOpen ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: _SquareActionButton(
                icon: Icons.smart_toy_rounded,
                label: 'AI',
                onTap: () {
                  setState(() => _fabOpen = false);
                  final data = _lastData;
                  if (data != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportChatbotPage(reportData: data),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
         right: _fabOpen ? 110 : 0,
bottom: _fabOpen ? 80 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _fabOpen ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: _SquareActionButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                onTap: () async {
                  setState(() => _fabOpen = false);
                  final data = _lastData;
                  if (data != null) await _exportPdf(context, data);
                },
              ),
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          right: _fabOpen ? 35 : 0,
bottom: _fabOpen ? 120 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _fabOpen ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: _SquareActionButton(
                icon: Icons.send_rounded,
                label: 'Chat',
                onTap: () {
                  setState(() => _fabOpen = false);
                  final data = _lastData;
                  if (data != null) _showChatPicker(context, data);
                },
              ),
            ),
          ),
        ),

        AnimatedContainer(
  duration: const Duration(milliseconds: 220),
 width: _fabOpen ? 52 : 56,
height: _fabOpen ? 52 : 56,
  child: FloatingActionButton(
    backgroundColor: _fabOpen
        ? const Color(0xFF363435)
        : _accent,
    elevation: _fabOpen ? 2 : 5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabOpen ? 14 : 16),
    ),
    onPressed: () => setState(() => _fabOpen = !_fabOpen),
    child: Icon(
      _fabOpen ? Icons.close_rounded : Icons.add_rounded,
      color: Colors.white,
      size: _fabOpen ? 28 : 30,
    ),
  ),
),
      ],
    ),
  );
}

  /// Shows a bottom sheet listing the player's conversations.
  ///
  /// Direct mode  → send button per row → sends + navigates to that chat page.
  /// Select mode  → multi-select → batch send → closes sheet (no navigation).
  void _showChatPicker(BuildContext context, _ReportData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ChatPickerSheet(
        // Direct mode: single chat, close sheet then navigate to it.
        onChatSelected: (chatId, chatName, {bool navigateToChat = true}) async {
          Navigator.pop(sheetCtx);
          await _sendReportToChat(
            context,
            data,
            chatId,
            chatName,
            navigateToChat: navigateToChat,
          );
        },
        // Multi-select mode: close sheet ONCE then send to all ids.
        onBatchSelected: (ids, names) async {
          Navigator.pop(sheetCtx); // close sheet exactly once
          for (final id in ids) {
            await _sendReportToChat(
              context,
              data,
              id,
              names[id] ?? '',
              navigateToChat: false, // stay on report page
            );
          }
          // Show a single combined confirmation.
          if (context.mounted) {
            _showSentDialog(
              context,
              ids.length == 1
                  ? (names[ids.first] ?? '')
                  : '${ids.length} chats',
            );
          }
        },
      ),
    );
  }

  Future<void> _sendReportToChat(
    BuildContext context,
    _ReportData data,
    String chatId,
    String chatName, {
    bool navigateToChat = true,
  }) async {
    final cfg = _GameReportConfig.forGame(data.gameId);
    final now = DateFormat("d MMM yyyy • HH:mm").format(DateTime.now());
    final pct = (double v) => "${(v * 100).clamp(0, 100).toStringAsFixed(0)}%";

    // Build structured report data for the card bubble
    final reportData = <String, dynamic>{
      'gameTitle': _gameTitle(data.gameId),
      'matchCount': _recentN,
      'generatedAt': now,
      'overallScore': data.overallScore,
      'winRate': data.recentAgg['winRate'] != null
          ? cfg.format('winRate', data.recentAgg['winRate']!)
          : '',
      'kda': data.recentAgg['kda'] != null
          ? cfg.format('kda', data.recentAgg['kda']!)
          : '',
      'recentScore': data.recentAgg['performanceScore'] != null
          ? cfg.format('performanceScore', data.recentAgg['performanceScore']!)
          : '',
      'strengths': data.strengths
          .map((s) => {'label': cfg.labelFor(s.key), 'value': pct(s.normalized)})
          .toList(),
      'weaknesses': data.weaknesses
          .map((w) => {'label': cfg.labelFor(w.key), 'value': pct(w.normalized)})
          .toList(),
      'trends': data.trends.take(4).map((t) {
        final up = t.delta >= 0;
        final good = cfg.metrics[t.key]?.higherIsBetter ?? true;
        final isPos = (up && good) || (!up && !good);
        return {
          'label': cfg.labelFor(t.key),
          'prev': cfg.format(t.key, t.previous),
          'recent': cfg.format(t.key, t.recent),
          'isPositive': isPos,
        };
      }).toList(),
      'focusTitle': data.goals.isNotEmpty ? data.goals.first.title : '',
      'focusDesc': data.goals.isNotEmpty ? data.goals.first.description : '',
      'focusStatus': _focusStatusLabel(data.focusStatus),
      'goals': data.goals
          .map((g) => {'title': g.title, 'target': g.targetText})
          .toList(),
    };

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await Future.wait([
        FirebaseFirestore.instance
            .collection('Chat')
            .doc(chatId)
            .collection('message')
            .add({
          'senderId': uid,
          'text': '📊 ${_gameTitle(data.gameId)} Performance Report',
          'type': 'report',
          'reportData': reportData,
          'timestamp': FieldValue.serverTimestamp(),
          'readBy': [uid],
        }),
        FirebaseFirestore.instance.collection('Chat').doc(chatId).update({
          'lastMessage': '📊 ${_gameTitle(data.gameId)} Performance Report',
          'lastMessageSender': uid,
          'lastTimestamp': FieldValue.serverTimestamp(),
          'isEmpty': false,
        }),
      ]);

      if (!context.mounted) return;

      if (navigateToChat) {
        // Direct mode: go straight to the chat page.
        Navigator.pushNamed(context, '/chat', arguments: chatId);
      }
      // Batch mode: caller (_showChatPicker) shows the combined dialog.
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, '$e');
      }
    }
  }

  void _showSentDialog(BuildContext context, String chatName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF16A34A),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Report Sent!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F1419),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your report was sent to\n$chatName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF536471),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            backgroundColor: _accent,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFEB3D24),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Failed to Send',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F1419),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF536471),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            backgroundColor: _accent,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportPdf(BuildContext context, _ReportData data) async {
    final cfg = _GameReportConfig.forGame(data.gameId);
    final fileName =
        "spark_${data.gameId}_report_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final now = DateFormat("d MMM yyyy  -  HH:mm").format(DateTime.now());

    // ── Palette ────────────────────────────────────────────────────────────
    const pAccent  = PdfColor.fromInt(0xFFEB3D24);
    const pBg      = PdfColor.fromInt(0xFFFAFAFA);
    const pSurface = PdfColor.fromInt(0xFFF0F3F4);
    const pText    = PdfColor.fromInt(0xFF0F1419);
    const pMuted   = PdfColor.fromInt(0xFF536471);
    const pLine    = PdfColor.fromInt(0xFFCFD9DE);
    const pGreen   = PdfColor.fromInt(0xFF16A34A);
    const pRed     = PdfColor.fromInt(0xFFEB3D24);
    const pWhite   = PdfColors.white;

    // ── Helpers ────────────────────────────────────────────────────────────
    String pct(double v) => "${(v * 100).clamp(0, 100).toStringAsFixed(0)}%";
    String fmtDt(DateTime? dt) =>
        dt == null ? "—" : DateFormat("d MMM yyyy  -  HH:mm").format(dt);

    // Section header with left accent bar
    pw.Widget sectionHeader(String label) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 20, bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 3,
                height: 14,
                decoration: pw.BoxDecoration(
                  color: pAccent,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                label.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: pText,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );

    // Key-value row inside a surface card
    pw.Widget statRow(String label, String value, {bool isLast = false}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: pw.BoxDecoration(
            border: isLast
                ? null
                : pw.Border(
                    bottom: pw.BorderSide(color: pLine, width: 0.5),
                  ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 10, color: pMuted)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: pText)),
            ],
          ),
        );

    // Card wrapper
    pw.Widget card(List<pw.Widget> children) => pw.Container(
          decoration: pw.BoxDecoration(
            color: pSurface,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: pLine, width: 0.5),
          ),
          child: pw.Column(children: children),
        );

    // Two-column pill row (strengths / weaknesses)
    pw.Widget pillRow(String label, String value, PdfColor dotColor) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(
                  color: dotColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 7),
              pw.Expanded(
                child: pw.Text(label,
                    style: const pw.TextStyle(fontSize: 10, color: pMuted)),
              ),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: dotColor)),
            ],
          ),
        );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),

        // ── Page Header ───────────────────────────────────────────────────
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Top banner
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: pw.BoxDecoration(
                color: pAccent,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "${_gameTitle(data.gameId)} Performance Report",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: pWhite,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Generated by Spark Platform  -  $now",
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColor.fromInt(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Last $_recentN matches",
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: pWhite),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "Overall Score  ${data.overallScore.toStringAsFixed(1)}",
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: pWhite),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
          ],
        ),

        // ── Page Footer ───────────────────────────────────────────────────
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Auto-generated by Spark - Real in-game data - Not manually written",
                style: const pw.TextStyle(fontSize: 8, color: pMuted),
              ),
              pw.Text(
                "Page ${ctx.pageNumber} / ${ctx.pagesCount}",
                style: const pw.TextStyle(fontSize: 8, color: pMuted),
              ),
            ],
          ),
        ),

        // ── Body ──────────────────────────────────────────────────────────
        build: (ctx) => [

          // ── Overview ────────────────────────────────────────────────────
          sectionHeader("Overview"),
          card([
            if (data.recentAgg['winRate'] != null)
              statRow("Win Rate",
                  cfg.format('winRate', data.recentAgg['winRate']!)),
            if (data.recentAgg['kda'] != null)
              statRow("KDA",
                  cfg.format('kda', data.recentAgg['kda']!)),
            if (data.recentAgg['performanceScore'] != null)
              statRow(
                "Recent Score",
                cfg.format('performanceScore',
                    data.recentAgg['performanceScore']!),
                isLast: true,
              ),
          ]),

          // ── Strengths & Weaknesses side by side ─────────────────────────
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Strengths
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    sectionHeader("Strengths"),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: pSurface,
                        borderRadius: pw.BorderRadius.circular(10),
                        border: pw.Border.all(color: pLine, width: 0.5),
                      ),
                      child: data.strengths.isEmpty
                          ? pw.Text("No data yet.",
                              style:
                                  const pw.TextStyle(fontSize: 10, color: pMuted))
                          : pw.Column(
                              children: [
                                for (int i = 0;
                                    i < data.strengths.length;
                                    i++)
                                  pillRow(
                                    cfg.labelFor(data.strengths[i].key),
                                    pct(data.strengths[i].normalized),
                                    pGreen,
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              // Weaknesses
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    sectionHeader("Areas to Improve"),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: pSurface,
                        borderRadius: pw.BorderRadius.circular(10),
                        border: pw.Border.all(color: pLine, width: 0.5),
                      ),
                      child: data.weaknesses.isEmpty
                          ? pw.Text("No data yet.",
                              style:
                                  const pw.TextStyle(fontSize: 10, color: pMuted))
                          : pw.Column(
                              children: [
                                for (int i = 0;
                                    i < data.weaknesses.length;
                                    i++)
                                  pillRow(
                                    cfg.labelFor(data.weaknesses[i].key),
                                    pct(data.weaknesses[i].normalized),
                                    pRed,
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Trends ──────────────────────────────────────────────────────
          sectionHeader("Trends  (Previous -> Recent)"),
          data.trends.isEmpty
              ? pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: pSurface,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: pLine, width: 0.5),
                  ),
                  child: pw.Text("Not enough match history.",
                      style: const pw.TextStyle(fontSize: 10, color: pMuted)),
                )
              : card([
                  for (int i = 0; i < data.trends.take(6).length; i++) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: pw.BoxDecoration(
                        border: i < data.trends.take(6).length - 1
                            ? pw.Border(
                                bottom:
                                    pw.BorderSide(color: pLine, width: 0.5))
                            : null,
                      ),
                      child: pw.Row(
                        children: [
                          () {
                            final t = data.trends.toList()[i];
                            final up = t.delta >= 0;
                            final good =
                                cfg.metrics[t.key]?.higherIsBetter ?? true;
                            final isPos =
                                (up && good) || (!up && !good);
                            return pw.Container(
                              width: 6,
                              height: 6,
                              decoration: pw.BoxDecoration(
                                color: isPos ? pGreen : pRed,
                                shape: pw.BoxShape.circle,
                              ),
                            );
                          }(),
                          pw.SizedBox(width: 9),
                          pw.Expanded(
                            child: pw.Text(
                              cfg.labelFor(data.trends.toList()[i].key),
                              style: const pw.TextStyle(
                                  fontSize: 10, color: pMuted),
                            ),
                          ),
                          pw.Text(
                            "${cfg.format(data.trends.toList()[i].key, data.trends.toList()[i].previous)}  ->  ${cfg.format(data.trends.toList()[i].key, data.trends.toList()[i].recent)}",
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: () {
                                final t = data.trends.toList()[i];
                                final up = t.delta >= 0;
                                final good =
                                    cfg.metrics[t.key]?.higherIsBetter ?? true;
                                return (up && good) || (!up && !good)
                                    ? pGreen
                                    : pRed;
                              }(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),

          // ── Current Focus ────────────────────────────────────────────────
          sectionHeader("Current Focus"),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: pSurface,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: pAccent, width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (data.goals.isNotEmpty) ...[
                      pw.Text(data.goals.first.title,
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: pText)),
                      pw.SizedBox(height: 4),
                      pw.Text(data.goals.first.description,
                          style:
                              const pw.TextStyle(fontSize: 10, color: pMuted)),
                    ] else
                      pw.Text("No active focus.",
                          style:
                              const pw.TextStyle(fontSize: 10, color: pMuted)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: pAccent,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    _focusStatusLabel(data.focusStatus).toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: pWhite),
                  ),
                ),
              ],
            ),
          ),

          // ── Next Goals ───────────────────────────────────────────────────
          sectionHeader("Next Goals"),
          if (data.goals.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: pSurface,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: pLine, width: 0.5),
              ),
              child: pw.Text("No goals available.",
                  style: const pw.TextStyle(fontSize: 10, color: pMuted)),
            )
          else
            pw.Column(
              children: [
                for (int i = 0; i < data.goals.length; i++)
                  pw.Container(
                    margin: pw.EdgeInsets.only(
                        bottom: i < data.goals.length - 1 ? 8 : 0),
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: pSurface,
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: pLine, width: 0.5),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Number badge
                        pw.Container(
                          width: 22,
                          height: 22,
                          decoration: pw.BoxDecoration(
                            color: pAccent,
                            shape: pw.BoxShape.circle,
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            "${i + 1}",
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: pWhite),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(data.goals[i].title,
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: pText)),
                              pw.SizedBox(height: 3),
                              pw.Text(data.goals[i].description,
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: pMuted)),
                              pw.SizedBox(height: 5),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromInt(0x1AEB3D24),
                                  borderRadius: pw.BorderRadius.circular(6),
                                  border: pw.Border.all(
                                      color: PdfColor.fromInt(0x33EB3D24),
                                      width: 0.5),
                                ),
                                child: pw.Text(
                                  "Target: ${data.goals[i].targetText}",
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: pAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          // ── Data timestamps ──────────────────────────────────────────────
          sectionHeader("Data"),
          card([
            statRow("Dashboard computed", fmtDt(data.computedAt)),
            statRow("Last fetched", fmtDt(data.lastFetchedAt), isLast: true),
          ]),

          pw.SizedBox(height: 8),
        ],
      ),
    );

    final bytes = await pdf.save();
    if (kIsWeb) {
      await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  static String _focusStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In progress';
      case 'done':
        return 'Done';
      default:
        return 'Not started';
    }
  }
}

class _ReportData {
  final String gameId;
  final double overallScore;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> values;
  final DateTime? computedAt;
  final DateTime? lastFetchedAt;
  final DateTime? focusUpdatedAt;
  final List<Map<String, dynamic>> recentMatches;
  final List<Map<String, dynamic>> prevMatches;
  final Map<String, double> recentAgg;
  final Map<String, double> prevAgg;
  final List<_Pick> strengths;
  final List<_Pick> weaknesses;
  final List<_Trend> trends;
  final List<_Goal> goals;
  final String focusStatus;
  
  const _ReportData({
    required this.gameId,
    required this.overallScore,
    required this.stats,
    required this.values,
    required this.computedAt,
    required this.lastFetchedAt,
    required this.focusUpdatedAt,
    required this.recentMatches,
    required this.prevMatches,
    required this.recentAgg,
    required this.prevAgg,
    required this.strengths,
    required this.weaknesses,
    required this.trends,
    required this.goals,
    required this.focusStatus,
  });

  factory _ReportData.empty({required String gameId}) => _ReportData(
        gameId: gameId,
        overallScore: 0,
        stats: const {},
        values: const {},
        computedAt: null,
        lastFetchedAt: null,
        recentMatches: const [],
        prevMatches: const [],
        recentAgg: const {},
        prevAgg: const {},
        strengths: const [],
        weaknesses: const [],
        trends: const [],
        goals: const [],
        focusStatus: 'not_started',
        focusUpdatedAt: null,
      );
}

class _Pick {
  final String key;
  final double normalized;
  const _Pick({required this.key, required this.normalized});
}

class _Trend {
  final String key;
  final double recent;
  final double previous;
  final double delta;
  const _Trend({
    required this.key,
    required this.recent,
    required this.previous,
    required this.delta,
  });
}

class _Goal {
  final String title;
  final String description;
  final String targetText;
  const _Goal({
    required this.title,
    required this.description,
    required this.targetText,
  });
}

class _MetricDef {
  final String label;
  final bool higherIsBetter;
  const _MetricDef({required this.label, required this.higherIsBetter});
}

class _GameReportConfig {
  final String gameId;
  final List<String> matchNumericKeys;
  final List<String> trendKeys;
  final List<String> metricOrder;
  final Map<String, String> normalizedToMatchKey;
  final Map<String, _MetricDef> metrics;

  const _GameReportConfig({
    required this.gameId,
    required this.matchNumericKeys,
    required this.trendKeys,
    required this.metricOrder,
    required this.normalizedToMatchKey,
    required this.metrics,
  });

  static _GameReportConfig forGame(String gameId) {
    final g = gameId.toLowerCase().trim();

    if (g == 'dota2') {
      return _GameReportConfig(
        gameId: g,
        matchNumericKeys: const [
          'kda',
          'gpm',
          'xpm',
          'kills',
          'deaths',
          'assists',
          'lastHits',
          'performanceScore',
        ],
        trendKeys: const [
          'winRate',
          'kda',
          'gpm',
          'xpm',
          'performanceScore',
        ],
        metricOrder: const [
          'score',
          'winRate',
          'kda',
          'gpm',
          'xpm',
          'lastHits',
        ],
        normalizedToMatchKey: const {
          'score': 'performanceScore',
          'performanceScore': 'performanceScore',
          'winRate': 'winRate',
          'kda': 'kda',
          'gpm': 'gpm',
          'xpm': 'xpm',
          'lastHits': 'lastHits',
        },
        metrics: const {
          'score': _MetricDef(label: 'Performance Score', higherIsBetter: true),
          'performanceScore':
              _MetricDef(label: 'Performance Score', higherIsBetter: true),
          'winRate': _MetricDef(label: 'Win Rate', higherIsBetter: true),
          'kda': _MetricDef(label: 'KDA', higherIsBetter: true),
          'gpm': _MetricDef(label: 'GPM', higherIsBetter: true),
          'xpm': _MetricDef(label: 'XPM', higherIsBetter: true),
          'lastHits': _MetricDef(label: 'Last Hits', higherIsBetter: true),
          'deaths': _MetricDef(label: 'Deaths', higherIsBetter: false),
        },
      );
    }

    if (g == 'lol') {
      return _GameReportConfig(
        gameId: g,
        matchNumericKeys: const [
          'kda',
          'csPerMin',
          'goldPerMin',
          'kills',
          'deaths',
          'assists',
          'visionPerMin',
          'kp',
          'performanceScore',
        ],
        trendKeys: const [
          'winRate',
          'kda',
          'csPerMin',
          'goldPerMin',
          'performanceScore',
        ],
        metricOrder: const [
          'score',
          'winRate',
          'kda',
          'csPerMin',
          'goldPerMin',
          'visionPerMin',
          'kp',
        ],
        normalizedToMatchKey: const {
          'score': 'performanceScore',
          'performanceScore': 'performanceScore',
          'winRate': 'winRate',
          'kda': 'kda',
          'csPerMin': 'csPerMin',
          'goldPerMin': 'goldPerMin',
          'visionPerMin': 'visionPerMin',
          'kp': 'kp',
        },
        metrics: const {
          'score': _MetricDef(label: 'Performance Score', higherIsBetter: true),
          'performanceScore':
              _MetricDef(label: 'Performance Score', higherIsBetter: true),
          'winRate': _MetricDef(label: 'Win Rate', higherIsBetter: true),
          'kda': _MetricDef(label: 'KDA', higherIsBetter: true),
          'csPerMin': _MetricDef(label: 'CS / min', higherIsBetter: true),
          'goldPerMin': _MetricDef(label: 'Gold / min', higherIsBetter: true),
          'visionPerMin': _MetricDef(label: 'Vision / min', higherIsBetter: true),
          'kp': _MetricDef(label: 'Kill Participation', higherIsBetter: true),
          'deaths': _MetricDef(label: 'Deaths', higherIsBetter: false),
        },
      );
    }

    return _GameReportConfig(
      gameId: g,
      matchNumericKeys: const [
        'kills',
        'assists',
        'damage',
        'placement',
        'performanceScore',
      ],
      trendKeys: const [
        'winRate',
        'kills',
        'damage',
        'placement',
        'performanceScore',
      ],
      metricOrder: const ['score', 'winRate', 'kills', 'damage', 'placement'],
      normalizedToMatchKey: const {
        'score': 'performanceScore',
        'performanceScore': 'performanceScore',
        'winRate': 'winRate',
        'kills': 'kills',
        'damage': 'damage',
        'placement': 'placement',
      },
      metrics: const {
        'score': _MetricDef(label: 'Performance Score', higherIsBetter: true),
        'performanceScore':
            _MetricDef(label: 'Performance Score', higherIsBetter: true),
        'winRate': _MetricDef(label: 'Win Rate', higherIsBetter: true),
        'kills': _MetricDef(label: 'Kills', higherIsBetter: true),
        'damage': _MetricDef(label: 'Damage', higherIsBetter: true),
        'placement': _MetricDef(label: 'Placement', higherIsBetter: false),
        'assists': _MetricDef(label: 'Assists', higherIsBetter: true),
      },
    );
  }

  String labelFor(String key) => metrics[key]?.label ?? key;

  String format(String key, double v) {
    if (key == 'winRate' || key.toLowerCase().contains('winrate')) {
      return "${(v * 100).toStringAsFixed(0)}%";
    }
    if (key.toLowerCase().contains('permin')) return v.toStringAsFixed(2);
    if (key.toLowerCase().contains('score')) return v.toStringAsFixed(1);
    if (key.toLowerCase().contains('placement')) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  static const Color _text = Color(0xFF0F1419);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _text,
      ),
    );
  }
}



class _OverviewCards extends StatelessWidget {
  final _ReportData data;
  const _OverviewCards({required this.data});

  @override
  Widget build(BuildContext context) {
    final cfg = _GameReportConfig.forGame(data.gameId);

    final overall = data.overallScore;
    final wr = data.recentAgg['winRate'] ??
        (data.stats['winRate'] is num
            ? (data.stats['winRate'] as num).toDouble()
            : null);
    final kda = data.recentAgg['kda'] ??
        (data.stats['kda'] is num ? (data.stats['kda'] as num).toDouble() : null);
    final perf = data.recentAgg['performanceScore'];

    final cards = <_MiniCard>[
      _MiniCard(
        title: "Overall",
        value: overall.toStringAsFixed(1),
        icon: Icons.star_rounded,
      ),
      if (wr != null)
        _MiniCard(
          title: "Win Rate",
          value: cfg.format('winRate', wr),
          icon: Icons.emoji_events_rounded,
        ),
      if (kda != null)
        _MiniCard(
          title: "KDA",
          value: cfg.format('kda', kda),
          icon: Icons.sports_mma_rounded,
        ),
      if (perf != null)
        _MiniCard(
          title: "Recent",
          value: cfg.format('performanceScore', perf),
          icon: Icons.bolt_rounded,
        ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w < 380 ? 2 : (w < 720 ? 2 : 4);
        const mainExtent = 84.0;

        return GridView.builder(
          itemCount: cards.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: mainExtent,
          ),
          itemBuilder: (_, i) => cards[i],
        );
      },
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      color: _text,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthWeakness extends StatelessWidget {
  final _ReportData data;
  const _StrengthWeakness({required this.data});

  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  Widget build(BuildContext context) {
    final cfg = _GameReportConfig.forGame(data.gameId);

    Widget list(String title, List<_Pick> picks, Color dot, IconData badgeIcon) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w900,
                      color: _text,
                    ),
                  ),
                ),
                Icon(badgeIcon, size: 18, color: _muted),
              ],
            ),
            const SizedBox(height: 10),
            if (picks.isEmpty)
              const Text(
                "No data yet.",
                style: TextStyle(fontFamily: 'Inter', color: _muted),
              ),
            ...picks.map((p) {
              final label = cfg.labelFor(p.key);
              final pct = (p.normalized * 100).clamp(0, 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dot,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                    ),
                    Text(
                      "$pct%",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: list(
              "Strengths",
              data.strengths,
              const Color(0xFF22c55e),
              Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: list(
              "Weaknesses",
              data.weaknesses,
              const Color(0xFFef4444),
              Icons.warning_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _Trends extends StatelessWidget {
  final _ReportData data;
  const _Trends({required this.data});

  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  Widget build(BuildContext context) {
    final cfg = _GameReportConfig.forGame(data.gameId);

    if (data.trends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          "Not enough match history to calculate trends (need at least 2× the selected range).",
          style: TextStyle(fontFamily: 'Inter', color: _muted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: data.trends.take(6).map((t) {
          final label = cfg.labelFor(t.key);
          final recent = cfg.format(t.key, t.recent);
          final prev = cfg.format(t.key, t.previous);

          final up = t.delta >= 0;
          final good = cfg.metrics[t.key]?.higherIsBetter ?? true;
          final isPositive = (up && good) || (!up && !good);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                ),
                Text(
                  "$prev → $recent",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    color: _muted,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 18,
                  color: isPositive
                      ? const Color(0xFF22c55e)
                      : const Color(0xFFef4444),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FocusStatusCard extends StatelessWidget {
  final _Goal? currentGoal;
  final String status;
  final ValueChanged<String> onStatusChanged;

  const _FocusStatusCard({
    required this.currentGoal,
    required this.status,
    required this.onStatusChanged,
  });

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentGoal?.title ?? "No current focus",
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currentGoal?.description ?? "No focus available yet.",
            style: const TextStyle(
              fontFamily: 'Inter',
              color: _muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text("Not started"),
                selected: status == 'not_started',
                onSelected: (_) => onStatusChanged('not_started'),
              ),
              ChoiceChip(
                label: const Text("In progress"),
                selected: status == 'in_progress',
                selectedColor: _accent.withOpacity(0.15),
                onSelected: (_) => onStatusChanged('in_progress'),
              ),
              ChoiceChip(
                label: const Text("Done"),
                selected: status == 'done',
                selectedColor: const Color(0xFFDCFCE7),
                checkmarkColor: const Color(0xFF15803D),
                labelStyle: TextStyle(
                  color: status == 'done' ? const Color(0xFF166534) : null,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: status == 'done'
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFCFD9DE),
                ),
                onSelected: (_) => onStatusChanged('done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusGoals extends StatelessWidget {
  final _ReportData data;
  const _FocusGoals({required this.data});

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  Widget build(BuildContext context) {
    if (data.goals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          "No goals yet (missing data).",
          style: TextStyle(fontFamily: 'Inter', color: _muted),
        ),
      );
    }

    return Column(
      children: data.goals.map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g.title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                g.description,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _muted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.08),
                  border: Border.all(color: _accent.withOpacity(0.35)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  g.targetText,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MetaInfo extends StatelessWidget {
  final _ReportData data;
  const _MetaInfo({required this.data});

  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d MMM yyyy • HH:mm");
    String line(DateTime? dt) => dt == null ? "—" : fmt.format(dt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Data",
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Dashboard computed: ${line(data.computedAt)}",
            style: const TextStyle(fontFamily: 'Inter', color: _muted),
          ),
          const SizedBox(height: 4),
          Text(
            "Last fetched: ${line(data.lastFetchedAt)}",
            style: const TextStyle(fontFamily: 'Inter', color: _muted),
          ),
        ],
      ),
    );
  }
}
class _SquareActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SquareActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: _accent,
          borderRadius: BorderRadius.circular(20),
          elevation: 5,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(icon, color: Colors.white, size: 27),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF536471),
          ),
        ),
      ],
    );
  }
}

// ─── Mini Speed Dial Button ────────────────────────────────────────────────

class _MiniSpeedDialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniSpeedDialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label pill
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1419),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Mini FAB
        Material(
          color: _accent,
          borderRadius: BorderRadius.circular(16),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Chat Picker Bottom Sheet ──────────────────────────────────────────────

class _ChatPickerSheet extends StatefulWidget {
  /// Called when the user taps the direct-send button on a single row.
  /// The caller is responsible for closing the sheet then navigating.
  final void Function(String chatId, String chatName,
      {bool navigateToChat}) onChatSelected;

  /// Called when the user confirms a multi-select batch send.
  /// The caller closes the sheet once and sends to all ids.
  final void Function(List<String> ids, Map<String, String> names)
      onBatchSelected;

  const _ChatPickerSheet({
    required this.onChatSelected,
    required this.onBatchSelected,
  });

  @override
  State<_ChatPickerSheet> createState() => _ChatPickerSheetState();
}

class _ChatPickerSheetState extends State<_ChatPickerSheet> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  String _search = '';
  final _ctrl = TextEditingController();

  // When true → multi-select mode (tap toggles selection, send button appears).
  // When false → direct mode (send button on each row sends immediately and
  // navigates to that chat).
  bool _selectMode = false;

  final Set<String> _selectedIds = {};
  final Map<String, String> _selectedNames = {};

  ImageProvider? _getImageProvider(String photo) {
    if (photo.isEmpty) return null;
    if (photo.startsWith('http')) return NetworkImage(photo);
    try {
      final cleaned =
          photo.contains(',') ? photo.split(',').last : photo;
      final bytes = base64.decode(cleaned);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleSelection(String chatId, String chatName) {
    setState(() {
      if (_selectedIds.contains(chatId)) {
        _selectedIds.remove(chatId);
        _selectedNames.remove(chatId);
      } else {
        _selectedIds.add(chatId);
        _selectedNames[chatId] = chatName;
      }
    });
  }

  void _sendToSelected() {
    // Snapshot the selection, then fire a single batch callback so the sheet
    // is closed exactly once regardless of how many chats are selected.
    final ids = List<String>.from(_selectedIds);
    final names = Map<String, String>.from(_selectedNames);
    widget.onBatchSelected(ids, names);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.6, 0.95],
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ───────────────────────────────────────────────
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title + Select toggle ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectMode
                            ? '${_selectedIds.length} Selected'
                            : 'Send Report to Chat',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _accent,
                        ),
                      ),
                    ),
                    // Select / Cancel button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectMode = !_selectMode;
                          if (!_selectMode) {
                            _selectedIds.clear();
                            _selectedNames.clear();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _selectMode
                              ? _accent.withOpacity(0.10)
                              : const Color(0xFFF0F3F4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectMode ? _accent : _line,
                          ),
                        ),
                        child: Text(
                          _selectMode ? 'Cancel' : 'Select',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectMode ? _accent : _text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectMode
                        ? 'Tap to select, then press Send.'
                        : 'Tap send to share the report directly.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Search ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3F4),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: _muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onChanged: (v) =>
                                setState(() => _search = v.toLowerCase()),
                            cursorColor: _accent,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F1419),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search chats...',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _muted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Chat List ─────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: UnifiedChatService.listenUserChats(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final chats = (snap.data ?? []).where((c) {
                      final name =
                          (c['displayName'] ?? '').toString().toLowerCase();
                      return _search.isEmpty || name.contains(_search);
                    }).toList();

                    if (chats.isEmpty) {
                      return Center(
                        child: Text(
                          _search.isEmpty
                              ? 'No conversations yet.'
                              : 'No chats match "$_search".',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: _muted,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final chat = chats[i];
                        final chatId = chat['id'] as String? ?? '';
                        final name =
                            chat['displayName'] as String? ?? 'Chat';
                        final photoRaw =
                            (chat['photoUrl'] ?? chat['photo'] ?? '')
                                .toString();
                        final photoProvider = _getImageProvider(photoRaw);
                        final isGroup = chat['type'] == 'group' ||
                            chat['type'] == 'team';
                        final isSelected = _selectedIds.contains(chatId);

                        return GestureDetector(
                          // In select-mode tapping the row toggles selection.
                          // In direct-mode tapping the row does nothing —
                          // only the send button acts.
                          onTap: _selectMode
                              ? () => _toggleSelection(chatId, name)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _accent.withOpacity(0.06)
                                  : const Color(0xFFFCFCFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? _accent : _line,
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // ── Avatar ──────────────────────────────
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _accent, width: 2),
                                      ),
                                      child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            const Color(0xFFEFEFEF),
                                        backgroundImage: photoProvider,
                                        child: photoProvider == null
                                            ? Icon(
                                                isGroup
                                                    ? Icons.groups
                                                    : Icons.person,
                                                color: _muted,
                                                size: 22,
                                              )
                                            : null,
                                      ),
                                    ),
                                    // Check badge in select-mode
                                    if (_selectMode && isSelected)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: _accent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // ── Name ────────────────────────────────
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color:
                                          isSelected ? _accent : _text,
                                    ),
                                  ),
                                ),

                                // ── Action button ───────────────────────
                                // Select-mode → checkbox circle
                                // Direct-mode → send button (navigates)
                                if (_selectMode)
                                  GestureDetector(
                                    onTap: () =>
                                        _toggleSelection(chatId, name),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _accent
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? _accent
                                              : _line,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () {
                                      // Send directly to this chat only,
                                      // then navigate into the chat page.
                                      widget.onChatSelected(chatId, name,
                                          navigateToChat: true);
                                    },
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: const BoxDecoration(
                                        color: _accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Send Button (select-mode only) ────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: (_selectMode && _selectedIds.isNotEmpty)
                    ? Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _sendToSelected,
                            icon: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                            label: Text(
                              'Send to ${_selectedIds.length} chat${_selectedIds.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}