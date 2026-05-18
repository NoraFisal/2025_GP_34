// lib/pages/player/connect_game_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'player_profile_page.dart';
import '/data/riot_link_service.dart';

enum GamePick { lol, pubg, dota2 }
enum PubgPlatform { steam, xbox, psn, kakao, stadia }

class ConnectGamePage extends StatefulWidget {
  const ConnectGamePage({super.key});

  @override
  State<ConnectGamePage> createState() => _ConnectGamePageState();
}

class _ConnectGamePageState extends State<ConnectGamePage> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _error;
  Timer? _duplicateCheckTimer;
  String? _lolDuplicateError;
  String? _pubgDuplicateError;
  String? _dotaDuplicateError;
  GamePick _pick = GamePick.lol;

  late final PageController _pageCtrl;
  int _pageIndex = 0;

  // LoL
  final _riotNameCtrl = TextEditingController();
  final _riotTagCtrl = TextEditingController();

  // PUBG
  final _pubgNameCtrl = TextEditingController();
  PubgPlatform _pubgPlatform = PubgPlatform.steam;

  // Dota2
  final _dotaQueryCtrl = TextEditingController(); 

  // Theme
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  // PUBG ONLY: paste your PUBG Developer API key here (testing).
  // DOTA DOES NOT NEED ANY KEY.
  // NOTE: On Flutter Web, PUBG calls can fail due to CORS even if the key is correct.
  static const String _pubgKey = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI3YjE2M2I3MC0zMDkyLTAxM2YtNGFjMS0wMjNkNWUxZGUzOTEiLCJpc3MiOiJnYW1lbG9ja2VyIiwiaWF0IjoxNzc4NjMyOTIyLCJwdWIiOiJibHVlaG9sZSIsInRpdGxlIjoicHViZyIsImFwcCI6InNwYXJrMyJ9.SxfAfxJYDrFQlhg7fV67uyJwaLvLsIwj-O8HC9QGtJ4';

  @override
  void initState() {
    super.initState();
    _pageIndex = _pick.index;
    _pageCtrl = PageController(
      initialPage: _pageIndex,
      viewportFraction: 0.78,
    );
    _riotNameCtrl.addListener(_scheduleDuplicateCheck);
_riotTagCtrl.addListener(_scheduleDuplicateCheck);
_pubgNameCtrl.addListener(_scheduleDuplicateCheck);
_dotaQueryCtrl.addListener(_scheduleDuplicateCheck);
  }

  @override
void dispose() {
  _duplicateCheckTimer?.cancel();
  _pageCtrl.dispose();
  _riotNameCtrl.dispose();
  _riotTagCtrl.dispose();
  _pubgNameCtrl.dispose();
  _dotaQueryCtrl.dispose();
  super.dispose();
}

  void _scheduleDuplicateCheck() {
  _duplicateCheckTimer?.cancel();
  _duplicateCheckTimer = Timer(const Duration(milliseconds: 500), () {
    _checkDuplicateAccountLive();
  });
}

Future<void> _checkDuplicateAccountLive() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  setState(() {
    _lolDuplicateError = null;
    _pubgDuplicateError = null;
    _dotaDuplicateError = null;
  });

  try {
    final players = await FirebaseFirestore.instance.collection('Player').get();

    for (final p in players.docs) {
      if (p.id == uid) continue;

      if (_pick == GamePick.lol) {
        final name = _riotNameCtrl.text.trim().toLowerCase();
        final tag = _riotTagCtrl.text.trim().toLowerCase();

        if (name.isEmpty || tag.isEmpty) continue;

        final doc = await FirebaseFirestore.instance
            .collection('Player')
            .doc(p.id)
            .collection('linkedGames')
            .doc('lol')
            .get();

        final data = doc.data();
        if (data == null) continue;

        final existingName =
            (data['gameName'] ?? '').toString().trim().toLowerCase();
        final existingTag =
            (data['tagLine'] ?? '').toString().trim().toLowerCase();

        if (existingName == name && existingTag == tag) {
          _lolDuplicateError =
              'This League of Legends account is already used.';
          break;
        }
      }

      if (_pick == GamePick.pubg) {
        final name = _pubgNameCtrl.text.trim().toLowerCase();
        if (name.isEmpty) continue;

        final doc = await FirebaseFirestore.instance
            .collection('Player')
            .doc(p.id)
            .collection('linkedGames')
            .doc('pubg')
            .get();

        final data = doc.data();
        if (data == null) continue;

        final existingName =
            (data['playerName'] ?? '').toString().trim().toLowerCase();

        if (existingName == name) {
          _pubgDuplicateError =
              'This PUBG account is already used.';
          break;
        }
      }

      if (_pick == GamePick.dota2) {
        final q = _dotaQueryCtrl.text.trim().toLowerCase();
        if (q.isEmpty) continue;

        final doc = await FirebaseFirestore.instance
            .collection('Player')
            .doc(p.id)
            .collection('linkedGames')
            .doc('dota2')
            .get();

        final data = doc.data();
        if (data == null) continue;

        final existingQuery =
            (data['query'] ?? '').toString().trim().toLowerCase();
        final existingAccountId =
            (data['accountId'] ?? '').toString().trim().toLowerCase();

        if (existingQuery == q || existingAccountId == q) {
          _dotaDuplicateError =
              'This Dota 2 account is already used.';
          break;
        }
      }
    }
  } finally {
  if (!mounted) return;
  setState(() {});

  if (_lolDuplicateError != null ||
      _pubgDuplicateError != null ||
      _dotaDuplicateError != null) {
    _formKey.currentState?.validate();
  }
}
}

  // ─────────────────────────────────────────────────────────────
  // Validators
  // ─────────────────────────────────────────────────────────────

  String? _vRiotName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter Riot username';
    if (_lolDuplicateError != null) return _lolDuplicateError;
return null;
  }

  String? _vRiotTag(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter tag';
    if (!RegExp(r'^[A-Za-z0-9]{2,5}$').hasMatch(s)) return '2–5 letters/numbers';
    return null;
  }

  String? _vPubgName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter PUBG username';
    if (_pubgDuplicateError != null) return _pubgDuplicateError;
return null;
  }

  String? _vDotaQuery(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter Steam32 ID or player name';
    if (_dotaDuplicateError != null) return _dotaDuplicateError;
return null;
  }

  // ─────────────────────────────────────────────────────────────
  // Progress dialog
  // ─────────────────────────────────────────────────────────────

  Future<void> _showProgressDialog(
  Stream<_ProgressState> progressStream, {
  String title = "Working...",
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) {
      return StreamBuilder<_ProgressState>(
        stream: progressStream,
        initialData: const _ProgressState(value: 0.0, label: 'Starting...'),
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
                      border: Border.all(color: _accent.withOpacity(0.25)),
                    ),
                    child: const Icon(
                      Icons.sync_rounded,
                      color: _accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
}
  Future<void> _runWithProgress({
    required Future<void> Function(StreamController<_ProgressState> ctrl) task,
    String title = "Connecting...",
  }) async {
    final ctrl = StreamController<_ProgressState>();

    // show dialog (don’t await)
    _showProgressDialog(ctrl.stream, title: title);

    try {
      ctrl.add(const _ProgressState(value: 0.05, label: 'Starting...'));
      await task(ctrl);
      ctrl.add(const _ProgressState(value: 1.0, label: 'Done'));
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      rethrow;
    } finally {
      await ctrl.close();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Firestore helper
  // ─────────────────────────────────────────────────────────────

  Future<void> _setLinkedGame({
    required String uid,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('Player')
        .doc(uid)
        .collection('linkedGames')
        .doc(docId);

    await ref.set({
      ...data,
      'connectedAt': FieldValue.serverTimestamp(),
      'lastFetchedAt': FieldValue.serverTimestamp(),
      'verified': true,
      'status': 'linked',
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────
  // LoL
  // ─────────────────────────────────────────────────────────────

  Future<void> _connectLoL(String uid, StreamController<_ProgressState> ctrl) async {
    final svc = RiotLinkService(FirebaseFirestore.instance);

    ctrl.add(const _ProgressState(value: 0.12, label: 'Linking LoL account...'));
    await svc.connectLoL(
      playerId: uid,
      gameName: _riotNameCtrl.text,
      tagLine: _riotTagCtrl.text,
    );
final lolDoc = await FirebaseFirestore.instance
    .collection('Player')
    .doc(uid)
    .collection('linkedGames')
    .doc('lol')
    .get();

final puuid = (lolDoc.data()?['puuid'] ?? '').toString();

await _ensureGameAccountNotUsed(
  currentUid: uid,
  gameId: 'lol',
  field: 'puuid',
  value: puuid,
);
    ctrl.add(const _ProgressState(value: 0.28, label: 'Clearing old stats...'));
    await svc.clearRoleStats(uid);

    ctrl.add(const _ProgressState(value: 0.55, label: 'Fetching match history...'));
    await svc.buildSeedsForLinkedLol(
      playerId: uid,
      maxMatches: 50,
      forceRefresh: true,
      allowNonRankedIfEmpty: true,
    );

    ctrl.add(const _ProgressState(value: 0.82, label: 'Saving performance matches...'));
    await svc.saveLolMatchSummaries(
      playerId: uid,
      maxMatches: 20,
      forceRefresh: true,
      allowNonRankedIfEmpty: true,
    );

    ctrl.add(const _ProgressState(value: 0.95, label: 'Finalizing...'));
  }

Future<void> _ensureGameAccountNotUsed({
  required String currentUid,
  required String gameId,
  required String field,
  required String value,
}) async {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return;

  final players = await FirebaseFirestore.instance.collection('Player').get();

  for (final p in players.docs) {
    if (p.id == currentUid) continue;

    final gameDoc = await FirebaseFirestore.instance
        .collection('Player')
        .doc(p.id)
        .collection('linkedGames')
        .doc(gameId)
        .get();

    final data = gameDoc.data();
    if (data == null) continue;

    final existing = (data[field] ?? '').toString().trim().toLowerCase();

    if (existing == normalized) {
      throw Exception(
        'This $gameId account is already connected to another SPARK profile.',
      );
    }
  }
}
  // ─────────────────────────────────────────────────────────────
  // PUBG 
  // ─────────────────────────────────────────────────────────────

  Map<String, String> _pubgHeaders() {
    final key = _pubgKey.trim();
    if (key.isEmpty || key == 'PASTE_YOUR_PUBG_KEY_HERE') {
      throw Exception('PUBG API key is missing. Paste it into _pubgKey.');
    }
    return <String, String>{
      'Authorization': 'Bearer $key',
      'Accept': 'application/vnd.api+json',
    };
  }

  String _shortBody(String body, [int maxLen = 220]) {
    if (body.isEmpty) return '';
    final m = min(maxLen, body.length);
    return body.substring(0, m);
  }

  Future<http.Response> _get(Uri url, Map<String, String> headers) async {
    try {
      return await http.get(url, headers: headers).timeout(const Duration(seconds: 18));
    } on TimeoutException {
      throw Exception('Request timed out. Check internet and try again.');
    } on Exception catch (e) {
      // Flutter Web often shows as "Failed to fetch" (CORS)
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> _pubgFindPlayer({
    required String platform,
    required String playerName,
  }) async {
    final headers = _pubgHeaders();
    final url = Uri.parse(
      'https://api.pubg.com/shards/$platform/players?filter[playerNames]=${Uri.encodeComponent(playerName)}',
    );

    final res = await _get(url, headers);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('PUBG auth failed (${res.statusCode}).\n${_shortBody(res.body)}');
    }
    if (res.statusCode == 429) throw Exception('PUBG rate limit (429). Try again later.');
    if (res.statusCode != 200) {
      throw Exception('PUBG verify failed (${res.statusCode}).\n${_shortBody(res.body)}');
    }

    final js = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (js['data'] as List?) ?? const [];
    if (data.isEmpty) throw Exception('PUBG player not found. Check name & platform.');
    return data.first as Map<String, dynamic>;
  }

  Future<List<String>> _pubgFetchMatchIds({
    required String platform,
    required String pubgPlayerId,
    int limit = 20,
  }) async {
    final headers = _pubgHeaders();
    final url = Uri.parse('https://api.pubg.com/shards/$platform/players/$pubgPlayerId');

    final res = await _get(url, headers);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('PUBG auth failed (${res.statusCode}).\n${_shortBody(res.body)}');
    }
    if (res.statusCode == 429) throw Exception('PUBG rate limit (429). Try again later.');
    if (res.statusCode != 200) {
      throw Exception('Failed to load PUBG profile (${res.statusCode}).\n${_shortBody(res.body)}');
    }

    final js = jsonDecode(res.body) as Map<String, dynamic>;

    final dataObj = js['data'];
    if (dataObj is! Map<String, dynamic>) return const [];

    final rel = dataObj['relationships'];
    if (rel is! Map<String, dynamic>) return const [];

    final matches = rel['matches'];
    if (matches is! Map<String, dynamic>) return const [];

    final matchData = matches['data'];
    if (matchData is! List) return const [];

    return matchData
        .map((m) => (m is Map<String, dynamic>) ? (m['id']?.toString() ?? '') : '')
        .where((id) => id.isNotEmpty)
        .take(limit)
        .toList();
  }

  Future<Map<String, dynamic>> _pubgFetchMatch({
    required String platform,
    required String matchId,
  }) async {
    final headers = _pubgHeaders();
    final url = Uri.parse('https://api.pubg.com/shards/$platform/matches/$matchId');

    final res = await _get(url, headers);

    if (res.statusCode == 429) throw Exception('PUBG rate limit (429).');
    if (res.statusCode != 200) {
      throw Exception('Failed to load match ($matchId) [${res.statusCode}].\n${_shortBody(res.body)}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  int _pubgPerformanceScore({
    required int kills,
    required int assists,
    required double damage,
    required int placement,
  }) {
    final placementScore = max(0, 60 - (placement - 1) * 2); // 1st=60
    final killScore = min(30, kills * 6);
    final assistScore = min(10, assists * 3);
    final damageScore = min(20, (damage / 50).round());
    return (placementScore + killScore + assistScore + damageScore).clamp(0, 100);
  }

  Map<String, dynamic>? _pubgExtractMyParticipantStats({
    required Map<String, dynamic> matchJson,
    required String playerName,
  }) {
    final included = matchJson['included'];
    if (included is! List) return null;

    final target = playerName.trim().toLowerCase();

    for (final item in included) {
      if (item is! Map<String, dynamic>) continue;
      if (item['type'] != 'participant') continue;

      final attrs = item['attributes'];
      if (attrs is! Map<String, dynamic>) continue;

      final stats = attrs['stats'];
      if (stats is! Map<String, dynamic>) continue;

      final n = (stats['name'] ?? '').toString().trim().toLowerCase();
      if (n == target) return stats;
    }
    return null;
  }

  DateTime _pubgMatchCreatedAt(Map<String, dynamic> matchJson) {
    try {
      final createdAt = matchJson['data']?['attributes']?['createdAt']?.toString();
      if (createdAt == null || createdAt.isEmpty) return DateTime.now();
      return DateTime.parse(createdAt).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _pubgSaveMatchSummaries({
  required String uid,
  required String platform,
  required String playerName,
  required String pubgPlayerId,
  required StreamController<_ProgressState> ctrl,
  int maxMatches = 20,
}) async {
  ctrl.add(const _ProgressState(value: 0.35, label: 'Loading recent matches...'));

  final matchIds = await _pubgFetchMatchIds(
    platform: platform,
    pubgPlayerId: pubgPlayerId,
    limit: maxMatches,
  );

  print('PUBG: playerName=$playerName platform=$platform playerId=$pubgPlayerId');
  print('PUBG: got ${matchIds.length} match IDs');

  if (matchIds.isEmpty) {
    throw Exception('No matches returned.\nIf you are on Flutter Web, this can also be CORS.');
  }

  final matchesRef = FirebaseFirestore.instance
      .collection('Player')
      .doc(uid)
      .collection('linkedGames')
      .doc('pubg')
      .collection('matches');

  for (int i = 0; i < matchIds.length; i++) {
    ctrl.add(_ProgressState(
      value: 0.35 + (i / matchIds.length) * 0.55,
      label: 'Fetching match ${i + 1}/${matchIds.length}...',
    ));

    final matchId = matchIds[i];

    print('PUBG: fetching match ${i + 1}/${matchIds.length} id=$matchId');

    final matchJson = await _pubgFetchMatch(
      platform: platform,
      matchId: matchId,
    );

    final created = _pubgMatchCreatedAt(matchJson);

    final stats = _pubgExtractMyParticipantStats(
      matchJson: matchJson,
      playerName: playerName,
    );

    if (stats == null) {
      print('PUBG: participant stats not found for $matchId');

      await matchesRef.doc(matchId).set({
        'matchId': matchId,
        'platform': platform,
        'playerName': playerName,
        'pubgPlayerId': pubgPlayerId,
        'performanceScore': 0,
        'win': false,
        'kills': 0,
        'assists': 0,
        'damage': 0.0,
        'placement': 999,
        'timestamp': Timestamp.fromDate(created),
        'source': 'pubg_api',
        'raw': {'note': 'participant not found by name'},
      }, SetOptions(merge: true));

      continue;
    }

    int asInt(dynamic x, {int def = 0}) =>
        (x is num) ? x.toInt() : int.tryParse('$x') ?? def;

    double asDouble(dynamic x, {double def = 0.0}) =>
        (x is num) ? x.toDouble() : double.tryParse('$x') ?? def;

    final kills = asInt(stats['kills']);
    final assists = asInt(stats['assists']);
    final damage = asDouble(stats['damageDealt']);
    final placement = asInt(stats['winPlace'], def: 999);

    final score = _pubgPerformanceScore(
      kills: kills,
      assists: assists,
      damage: damage,
      placement: placement,
    );

    await matchesRef.doc(matchId).set({
      'matchId': matchId,
      'platform': platform,
      'playerName': playerName,
      'pubgPlayerId': pubgPlayerId,
      'kills': kills,
      'assists': assists,
      'damage': damage,
      'placement': placement,
      'win': placement == 1,
      'performanceScore': score,
      'timestamp': Timestamp.fromDate(created),
      'source': 'pubg_api',
    }, SetOptions(merge: true));

    print(
      'PUBG: saved match $matchId kills=$kills assists=$assists damage=$damage placement=$placement score=$score',
    );
  }

  print('PUBG: wrote ${matchIds.length} matches for $uid');

  ctrl.add(const _ProgressState(
    value: 0.92,
    label: 'Saved matches to Firestore.',
  ));
}

  Future<void> _connectPUBG(String uid, StreamController<_ProgressState> ctrl) async {
    final platform = _pubgPlatform.name;
    final name = _pubgNameCtrl.text.trim();

    ctrl.add(const _ProgressState(value: 0.15, label: 'Verifying PUBG account...'));
    final player = await _pubgFindPlayer(platform: platform, playerName: name);

    final pubgPlayerId = player['id']?.toString().trim() ?? '';
    await _ensureGameAccountNotUsed(
  currentUid: uid,
  gameId: 'pubg',
  field: 'pubgPlayerId',
  value: pubgPlayerId,
);
    if (pubgPlayerId.isEmpty) throw Exception('PUBG response missing player id.');

    final attrs = (player['attributes'] is Map)
        ? (player['attributes'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final returnedName = (attrs['name'] ?? name).toString();

    print('LINKED PUBG: uid=$uid player=$returnedName platform=$platform playerId=$pubgPlayerId');
    
    ctrl.add(const _ProgressState(value: 0.25, label: 'Saving account link...'));
    await _setLinkedGame(
      uid: uid,
      docId: 'pubg',
      data: {
        'game': 'pubg',
        'playerName': returnedName,
        'platform': platform,
        'pubgPlayerId': pubgPlayerId,
        'source': 'pubg_api',
      },
    );

    await _pubgSaveMatchSummaries(
      uid: uid,
      platform: platform,
      playerName: returnedName,
      pubgPlayerId: pubgPlayerId,
      ctrl: ctrl,
      maxMatches: 20,
    );

    ctrl.add(const _ProgressState(value: 0.97, label: 'Finalizing...'));
  }

  // ─────────────────────────────────────────────────────────────
  // Dota2 
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _dotaFetchRecentMatches(int accountId, {int limit = 20}) async {
    final url = Uri.parse('https://api.opendota.com/api/players/$accountId/recentMatches');
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('OpenDota recentMatches failed (${res.statusCode}).');
    }

    final arr = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    // Sort newest first (OpenDota usually is, but keep it safe)
    arr.sort((a, b) => (b['start_time'] ?? 0).compareTo(a['start_time'] ?? 0));
    return arr.take(limit).toList();
  }

  int _dotaPerformanceScore({
    required int kills,
    required int deaths,
    required int assists,
    required int gpm,
    required int xpm,
    required int lastHits,
  }) {
    final kda = (kills + assists) / max(1, deaths);
    final kdaScore = (kda / 5.0 * 40).clamp(0, 40); // up to 40
    final gpmScore = (gpm / 600.0 * 20).clamp(0, 20); // up to 20
    final xpmScore = (xpm / 700.0 * 20).clamp(0, 20); // up to 20
    final lhScore = (lastHits / 250.0 * 20).clamp(0, 20); // up to 20
    return (kdaScore + gpmScore + xpmScore + lhScore).round().clamp(0, 100);
  }

  Future<void> _dotaSaveMatchSummaries({
  required String uid,
  required int accountId,
  required StreamController<_ProgressState> ctrl,
  int maxMatches = 20,
}) async {
  ctrl.add(const _ProgressState(value: 0.35, label: 'Loading recent matches...'));

  print('DOTA: accountId=$accountId uid=$uid');

  final recent = await _dotaFetchRecentMatches(accountId, limit: maxMatches);

  print('DOTA: got ${recent.length} matches');

  if (recent.isEmpty) throw Exception('No recent matches found for this account.');

  final matchesRef = FirebaseFirestore.instance
      .collection('Player')
      .doc(uid)
      .collection('linkedGames')
      .doc('dota2')
      .collection('matches');

  for (int i = 0; i < recent.length; i++) {
    final row = recent[i];
    final matchId = (row['match_id'] as num?)?.toInt() ?? 0;

    print('DOTA: saving match ${i + 1}/${recent.length} id=$matchId');

    if (matchId <= 0) {
      print('DOTA: skipped invalid match id');
      continue;
    }

    ctrl.add(_ProgressState(
      value: 0.35 + (i / recent.length) * 0.55,
      label: 'Saving match ${i + 1}/${recent.length}...',
    ));

    final kills = (row['kills'] as num?)?.toInt() ?? 0;
    final deaths = (row['deaths'] as num?)?.toInt() ?? 0;
    final assists = (row['assists'] as num?)?.toInt() ?? 0;
    final gpm = (row['gold_per_min'] as num?)?.toInt() ?? 0;
    final xpm = (row['xp_per_min'] as num?)?.toInt() ?? 0;
    final lastHits = (row['last_hits'] as num?)?.toInt() ?? 0;

    final score = _dotaPerformanceScore(
      kills: kills,
      deaths: deaths,
      assists: assists,
      gpm: gpm,
      xpm: xpm,
      lastHits: lastHits,
    );

    final startTime = (row['start_time'] as num?)?.toInt();
    final timestamp = (startTime != null)
        ? Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(startTime * 1000))
        : Timestamp.now();

    final radiantWin = row['radiant_win'] == true;
    final playerSlot = (row['player_slot'] as num?)?.toInt() ?? 0;
    final isRadiant = playerSlot < 128;
    final win = (isRadiant && radiantWin) || (!isRadiant && !radiantWin);

    await matchesRef.doc('$matchId').set({
      'matchId': matchId.toString(),
      'accountId': accountId,
      'kills': kills,
      'deaths': deaths,
      'assists': assists,
      'gpm': gpm,
      'xpm': xpm,
      'lastHits': lastHits,
      'kda': ((kills + assists) / max(1, deaths)).toDouble(),
      'performanceScore': score,
      'win': win,
      'timestamp': timestamp,
      'source': 'opendota',
    }, SetOptions(merge: true));

    print(
      'DOTA: saved match $matchId kills=$kills deaths=$deaths assists=$assists gpm=$gpm xpm=$xpm lastHits=$lastHits score=$score win=$win',
    );
  }

  print('DOTA: wrote ${recent.length} matches for $uid');

  ctrl.add(const _ProgressState(value: 0.92, label: 'Saved Dota matches to Firestore.'));
}

  Future<void> _connectDota2(String uid, StreamController<_ProgressState> ctrl) async {
    final q = _dotaQueryCtrl.text.trim();

    ctrl.add(const _ProgressState(value: 0.18, label: 'Finding Dota account...'));
    int? accountId;

    if (RegExp(r'^\d+$').hasMatch(q)) {
      accountId = int.tryParse(q);
    } else {
      final searchUrl = Uri.parse('https://api.opendota.com/api/search?q=${Uri.encodeComponent(q)}');

      print('DOTA: searching OpenDota for query=$q');
print('DOTA: url=$searchUrl');

final res = await http.get(searchUrl).timeout(
  const Duration(seconds: 15),
);

print('DOTA: statusCode=${res.statusCode}');
print('DOTA: body=${res.body}');
      if (res.statusCode != 200) {
        throw Exception('OpenDota search failed (${res.statusCode}). Try Steam32 ID.');
      }
      final arr = jsonDecode(res.body) as List;
      if (arr.isEmpty) throw Exception('Dota player not found. Try Steam32 ID.');

      final top = arr.first as Map<String, dynamic>;
      accountId = (top['account_id'] is num)
          ? (top['account_id'] as num).toInt()
          : int.tryParse('${top['account_id']}');
    }

    if (accountId == null || accountId <= 0) {
      throw Exception('Invalid Dota account id. Try Steam32 ID.');
    }
    await _ensureGameAccountNotUsed(
  currentUid: uid,
  gameId: 'dota2',
  field: 'accountId',
  value: accountId.toString(),
);
print('LINKED DOTA: uid=$uid query=$q accountId=$accountId');
    ctrl.add(const _ProgressState(value: 0.28, label: 'Saving Dota link...'));
    await _setLinkedGame(
      uid: uid,
      docId: 'dota2',
      data: {
        'game': 'dota2',
        'query': q,
        'accountId': accountId,
        'source': 'opendota',
      },
    );

    await _dotaSaveMatchSummaries(
      uid: uid,
      accountId: accountId,
      ctrl: ctrl,
      maxMatches: 20,
    );

    ctrl.add(const _ProgressState(value: 0.97, label: 'Finalizing...'));
  }
  String _friendlyConnectError(Object e) {
  final msg = e.toString().toLowerCase();

  if (msg.contains('failed to fetch') || msg.contains('cors')) {
    return 'Connection blocked on browser. Please try again on the mobile app or emulator.';
  }

  if (msg.contains('timeout')) {
    return 'Connection timed out. Please check your internet and try again.';
  }

  if (msg.contains('no matches returned') || msg.contains('no recent matches')) {
    return 'No recent matches were found for this account. Try another active account.';
  }

  if (msg.contains('player not found') || msg.contains('account not found')) {
    return 'Account not found. Please check the username, tag, or platform.';
  }

  if (msg.contains('invalid') || msg.contains('expired') || msg.contains('auth failed')) {
    return 'The game API key is invalid or expired. Please update the key and try again.';
  }

  if (msg.contains('bad request') || msg.contains('exception decrypting')) {
    return 'This saved account link is no longer valid. Please reconnect the account.';
  }

  return 'Something went wrong while connecting. Please try again.';
}

  // ─────────────────────────────────────────────────────────────
  // Connect handler
  // ─────────────────────────────────────────────────────────────

  Future<void> _onConnect() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('You must be signed in.');

    await _runWithProgress(
      title: _pick == GamePick.lol
          ? "Connecting LoL..."
          : _pick == GamePick.pubg
              ? "Connecting PUBG..."
              : "Connecting Dota 2...",
      task: (ctrl) async {
        if (_pick == GamePick.lol) {
          await _connectLoL(uid, ctrl);
        } else if (_pick == GamePick.pubg) {
          await _connectPUBG(uid, ctrl);
        } else {
          await _connectDota2(uid, ctrl);
        }
      },
    );

    
await computeAndSyncBadgesGlobal(uid);
if (!mounted) return;
Navigator.pop(context);
await Future.delayed(const Duration(milliseconds: 400));
if (context.mounted) {
  await BadgeUnlockNotifier.checkAndNotify(context: context, uid: uid);
}
  } catch (e) {
    setState(() => _error = _friendlyConnectError(e));
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  // ─────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────

  List<Widget> _buildAccountFields() {
    if (_pick == GamePick.lol) {
      return [
        _buildTextField(
  label: 'Riot Username',
  controller: _riotNameCtrl,
  hint: 'Enter username',
  validator: _vRiotName,
  onChanged: (_) => _scheduleDuplicateCheck(),
),

const SizedBox(height: 16),

_buildTextField(
  label: 'Tag',
  controller: _riotTagCtrl,
  hint: 'EUW, NA, etc.',
  validator: _vRiotTag,
  textCapitalization: TextCapitalization.characters,
  onChanged: (_) => _scheduleDuplicateCheck(),
),
      ];
    }

    if (_pick == GamePick.pubg) {
      return [
        _buildTextField(
  label: 'PUBG Username',
  controller: _pubgNameCtrl,
  hint: 'Enter PUBG name',
  validator: _vPubgName,
  onChanged: (_) => _scheduleDuplicateCheck(),
),
        const SizedBox(height: 16),
        _buildDropdown<PubgPlatform>(
          label: 'Platform',
          value: _pubgPlatform,
          items: PubgPlatform.values,
          titleBuilder: (p) {
            switch (p) {
              case PubgPlatform.steam:
                return 'Steam (PC)';
              case PubgPlatform.xbox:
                return 'Xbox';
              case PubgPlatform.psn:
                return 'PlayStation';
              case PubgPlatform.kakao:
                return 'Kakao';
              case PubgPlatform.stadia:
                return 'Stadia';
            }
          },
          onChanged: (v) => setState(() => _pubgPlatform = v),
          helper: (_pubgKey.trim().isEmpty || _pubgKey == 'PASTE_YOUR_PUBG_KEY_HERE')
              ? 'Paste your PUBG key in _pubgKey (for testing).'
              : '',
          helperIsWarning: (_pubgKey.trim().isEmpty || _pubgKey == 'PASTE_YOUR_PUBG_KEY_HERE'),
        ),
      ];
    }

    // Dota2
    return [
      _buildTextField(
  label: 'Steam32 ID or Player Name',
  controller: _dotaQueryCtrl,
  hint: 'Example: 87278757',
  validator: _vDotaQuery,
  onChanged: (_) => _scheduleDuplicateCheck(),
),
      const SizedBox(height: 10),
      
    ];
  }

  List<_GameSlide> get _slides => const [
        _GameSlide(
          pick: GamePick.lol,
          label: 'League of Legends',
          asset: 'assets/images/lol.png',
          fallbackText: 'LoL',
        ),
        _GameSlide(
          pick: GamePick.pubg,
          label: 'PUBG',
          asset: 'assets/images/pubg.png',
          fallbackText: 'PUBG',
        ),
        _GameSlide(
          pick: GamePick.dota2,
          label: 'Dota 2',
          asset: 'assets/images/dota2.png',
          fallbackText: 'Dota',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final slides = _slides;

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
          'Connect Game',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _accent,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Game',
              style: TextStyle(
                fontFamily: 'Inter',
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: slides.length,
                onPageChanged: (i) {
                  _formKey.currentState?.reset();
                  setState(() {
                    _pageIndex = i;
                    _pick = slides[i].pick;
                    _error = null;
                  });
                },
                itemBuilder: (context, i) {
                  final s = slides[i];
                  final selected = i == _pageIndex;

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: selected ? 6 : 16,
                    ),
                    child: _gameCard(
                      label: s.label,
                      asset: s.asset,
                      selected: selected,
                      fallbackText: s.fallbackText,
                      onTap: () {
                        _pageCtrl.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        );
                        _formKey.currentState?.reset();
                        setState(() {
                          _pageIndex = i;
                          _pick = s.pick;
                          _error = null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (i) {
                final isOn = i == _pageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isOn ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOn ? _accent : _line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),

            const SizedBox(height: 26),

            const Text(
              'Account Details',
              style: TextStyle(
                fontFamily: 'Inter',
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._buildAccountFields(),
                    if (_error != null && _error!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFB3261E),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: SizedBox(
                width: 230,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _onConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    disabledBackgroundColor: _dark.withOpacity(0.55),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _pick == GamePick.lol
                              ? 'Connect LoL'
                              : _pick == GamePick.pubg
                                  ? 'Connect PUBG'
                                  : 'Connect Dota 2',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameCard({
    required String label,
    required String asset,
    required bool selected,
    required VoidCallback onTap,
    String? fallbackText,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _accent : _line,
            width: selected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.08 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        fallbackText ?? label.substring(0, min(3, label.length)),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: selected ? _accent : _line,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
  required String label,
  required TextEditingController controller,
  required String hint,
  String? Function(String?)? validator,
  TextCapitalization textCapitalization = TextCapitalization.none,
  ValueChanged<String>? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: _text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),

      const SizedBox(height: 8),

      TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        textCapitalization: textCapitalization,
        cursorColor: _muted,

        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _text,
        ),

        decoration: InputDecoration(
          hintText: hint,

          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _muted,
          ),

          filled: true,
          fillColor: _bg,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _line,
              width: 1.2,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _line,
              width: 1.2,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: _accent,
              width: 2,
            ),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFB3261E),
              width: 1.6,
            ),
          ),

          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFB3261E),
              width: 2,
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) titleBuilder,
    required ValueChanged<T> onChanged,
    String? helper,
    bool helperIsWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line, width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: items
                  .map(
                    (e) => DropdownMenuItem<T>(
                      value: e,
                      child: Text(
                        titleBuilder(e),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(v);
              },
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 8),
          Text(
            helper,
            style: TextStyle(
              fontFamily: 'Inter',
              color: helperIsWarning ? const Color(0xFFB3261E) : _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _GameSlide {
  final GamePick pick;
  final String label;
  final String asset;
  final String fallbackText;
  const _GameSlide({
    required this.pick,
    required this.label,
    required this.asset,
    required this.fallbackText,
  });
}

class _ProgressState {
  final double value; // 0..1
  final String label;
  const _ProgressState({required this.value, required this.label});
}
