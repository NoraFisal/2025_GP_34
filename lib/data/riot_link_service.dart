// DIRECT version (no Cloud Functions) — FOR TESTING ONLY
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class RiotLinkService {
  final FirebaseFirestore db;
  RiotLinkService(this.db);

  // 24h dev key (or pass with --dart-define=RIOT_KEY=RGAPI-xxxx)
  static const String _riotKey =
      String.fromEnvironment('RIOT_KEY', defaultValue: 'RGAPI-9e16d7d9-11c8-4480-8f3e-98268c9a9668');

  // 'auto' infers americas|europe|asia; or force a value via --dart-define
  static const String _routingOverride =
      String.fromEnvironment('RIOT_ROUTING', defaultValue: 'auto');

  // ---------------------------------------------------------------------------
  // Link LoL (writes PUUID + routing). When auto, try all clusters until 200 OK
  // ---------------------------------------------------------------------------
  Future<void> connectLoL({
    required String playerId,
    required String gameName,
    required String tagLine,
  }) async {
    if (_riotKey.isEmpty) {
      throw Exception('Missing RIOT_KEY (use --dart-define).');
    }

    final user = gameName.trim();
    final tag  = tagLine.trim().toUpperCase();

    final preferred = _routingOverride.toLowerCase();
    // try all three when auto (this fixes cases like Z10 / NA1)
    final candidates = (preferred == 'auto')
        ? const ['europe', 'americas', 'asia']
        : [preferred];

    Map<String, dynamic>? acct;
    String? routingUsed;

    for (final rgn in candidates) {
      final url =
          'https://$rgn.api.riotgames.com/riot/account/v1/accounts/by-riot-id/'
          '${Uri.encodeComponent(user)}/${Uri.encodeComponent(tag)}';

      final resp = await http.get(Uri.parse(url), headers: {'X-Riot-Token': _riotKey});

      if (resp.statusCode == 200) {
        acct = jsonDecode(resp.body) as Map<String, dynamic>;
        routingUsed = rgn;
        break;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception('Invalid/expired Riot key.');
      }
      if (resp.statusCode == 429) {
        throw Exception('Rate limited by Riot (429). Try later.');
      }
      // 404 here may just mean "not this cluster" — keep trying others.
    }

    if (acct == null || routingUsed == null) {
      throw Exception('Riot account not found on any cluster. Check Username/Tag.');
    }

    final puuid = (acct['puuid'] as String?) ?? '';
    if (puuid.isEmpty) throw Exception('Riot response missing puuid.');

    final ref = db.collection('Player').doc(playerId).collection('linkedGames').doc('lol');
    await ref.set({
      'game': 'lol',
      'gameName': user,
      'tagLine': tag,
      'puuid': puuid,
      'region': routingUsed, // save the confirmed cluster
      'verified': true,
      'status': 'linked',
      'connectedAt': FieldValue.serverTimestamp(),
      'lastFetchedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // debug
    // ignore: avoid_print
    print('LINKED LoL: uid=$playerId puuid=$puuid region=$routingUsed');
  }

  // ---------------------------------------------------------------------------
  // OPTIONAL: clear manual roleStats you added, so results become accurate
  // ---------------------------------------------------------------------------
  Future<void> clearRoleStats(String playerId) async {
    final base = db.collection('Player').doc(playerId).collection('linkedGames').doc('lol');
    final snap = await base.collection('roleStats').get();
    final batch = db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    // ignore: avoid_print
    print('Cleared roleStats for $playerId');
  }

  // ---------------------------------------------------------------------------
  // Build per-role seeds under roleStats/{role}
  // ---------------------------------------------------------------------------
  Future<void> buildSeedsForLinkedLol({
    required String playerId,
    int maxMatches = 50,                              // pull 50 like your Colab
    Duration freshness = const Duration(days: 14),
    bool forceRefresh = false,
    bool allowNonRankedIfEmpty = true,                // helpful for NA1 tests
  }) async {
    final lolRef = db.collection('Player').doc(playerId)
        .collection('linkedGames').doc('lol');
    final lolDoc = await lolRef.get();
    if (!lolDoc.exists) {
      throw Exception('LoL link not found. Call connectLoL() first.');
    }

    final map = lolDoc.data()!;
    final puuid  = (map['puuid']  ?? '').toString();
    final region = (map['region'] ?? '').toString();
    if (puuid.isEmpty || region.isEmpty) {
      throw Exception('Missing puuid/region on linkedGames/lol.');
    }
    // ignore: avoid_print
    print('SEEDS: using puuid=$puuid region=$region');

    // Freshness gate (skip only when NOT forced)
    final rs = await lolRef.collection('roleStats').get();
    final now = DateTime.now();
    final isFresh = rs.docs.isNotEmpty && rs.docs.every((d) {
      final ts = (d.data()['computedAt'] as Timestamp?)?.toDate();
      return ts != null && now.difference(ts) < freshness;
    });
    if (!forceRefresh && isFresh) {
      await lolRef.set({'lastFetchedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      // ignore: avoid_print
      print('Seeds fresh; skipping. Use forceRefresh:true to override.');
      return;
    }

    // 1) recent ranked match IDs
    var ids = await _getMatchIds(region, puuid, maxMatches, rankedOnly: true);
    // ignore: avoid_print
    print('RIOT: got ${ids.length} ranked match IDs');
    if (ids.isEmpty && allowNonRankedIfEmpty) {
      // helpful for accounts with no ranked; for production you can disable this.
      // ignore: avoid_print
      print('No recent ranked matches; testing with ANY queue…');
      ids = await _getMatchIds(region, puuid, maxMatches, rankedOnly: false);
      // ignore: avoid_print
      print('RIOT: got ${ids.length} ANY-queue match IDs');
    }

    // 2) aggregate
    final seeds = await _buildSeedsFromMatches(region, puuid, ids);

    // 3) write roleStats
    final batch = db.batch();
    for (final s in seeds) {
      final ref = lolRef.collection('roleStats').doc(s.role);
      // ignore: avoid_print
      print('WRITE role=${s.role} games=${s.games} wins=${s.wins}');
      batch.set(ref, {
        'puuid': puuid,
        'region': region,
        'role': s.role,
        'sampleMatches': s.games,
        'games_played': s.games,
        'wins': s.wins,
        'winrate': s.winrate,
        'avg_kills': s.avgKills,
        'avg_deaths': s.avgDeaths,
        'avg_assists': s.avgAssists,
        'avg_cs': s.avgCs,
        'avg_gold': s.avgGold,
        'computedAt': FieldValue.serverTimestamp(),
        'source': 'riot_api',
      }, SetOptions(merge: true));
    }
    batch.set(lolRef, {'lastFetchedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await batch.commit();

    // ignore: avoid_print
    print('FIRESTORE: wrote roleStats for ${seeds.length} roles.');
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------
  Future<List<String>> _getMatchIds(
    String routing,
    String puuid,
    int count, {
    required bool rankedOnly,
  }) async {
    final qs = rankedOnly ? '?type=ranked&start=0&count=$count'
                          : '?start=0&count=$count';
    final u = Uri.parse(
      'https://$routing.api.riotgames.com/lol/match/v5/matches/by-puuid/$puuid/ids$qs',
    );
    final res = await _withRetry(() => http.get(u, headers: {'X-Riot-Token': _riotKey}));
    return (jsonDecode(res.body) as List).cast<String>();
  }

  Future<List<_RoleSeed>> _buildSeedsFromMatches(
    String routing,
    String puuid,
    List<String> matchIds,
  ) async {
    final acc = <String, _Acc>{
      'top': _Acc(), 'jungle': _Acc(), 'middle': _Acc(), 'bottom': _Acc(), 'support': _Acc(),
    };

    const perReqDelay = Duration(milliseconds: 1200);
    final max = matchIds.length > 50 ? 50 : matchIds.length;

    for (var i = 0; i < max; i++) {
      final mid = matchIds[i];
      // ignore: avoid_print
      print('RIOT: fetching match ${i + 1}/$max id=$mid');

      final url = Uri.parse('https://$routing.api.riotgames.com/lol/match/v5/matches/$mid');

      Map<String, dynamic> m;
      try {
        final res = await _withRetry(() => http.get(url, headers: {'X-Riot-Token': _riotKey}));
        m = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        // ignore: avoid_print
        print('RIOT: match fetch failed ($mid): $e');
        await Future.delayed(perReqDelay);
        continue;
      }

      final parts = (m['info']?['participants'] as List?) ?? const [];
      final meDyn = parts.cast<Map>().firstWhere((p) => p['puuid'] == puuid, orElse: () => {});
      final Map<String, dynamic> me = Map<String, dynamic>.from(meDyn);
      if (me.isEmpty || me['puuid'] == null) {
        await Future.delayed(perReqDelay);
        continue;
      }

      // EXACT Colab mapping
      final raw = ((me['teamPosition'] ?? me['individualPosition'] ?? '') as String).toUpperCase();
      String? role;
      switch (raw) {
        case 'UTILITY': role = 'support'; break;
        case 'BOTTOM':  role = 'bottom';  break;
        case 'MIDDLE':  role = 'middle';  break;
        case 'JUNGLE':  role = 'jungle';  break;
        case 'TOP':     role = 'top';     break;
        default:        role = null;      break; // NONE/UNKNOWN → skip
      }
      if (role == null) {
        await Future.delayed(perReqDelay);
        continue;
      }

      final a = acc[role]!;
      a.games += 1;
      if ((me['win'] as bool?) == true) a.wins += 1;
      a.k += (me['kills'] ?? 0) as int;
      a.d += (me['deaths'] ?? 0) as int;
      a.a += (me['assists'] ?? 0) as int;
      a.cs += ((me['totalMinionsKilled'] ?? 0) as int) + ((me['neutralMinionsKilled'] ?? 0) as int);
      a.gold += (me['goldEarned'] ?? 0) as int;

      await Future.delayed(perReqDelay);
    }

    final out = <_RoleSeed>[];
    acc.forEach((role, a) {
      if (a.games == 0) return;
      out.add(_RoleSeed(
        role: role,
        games: a.games,
        wins: a.wins,
        winrate: a.wins / a.games,
        avgKills: a.k / a.games,
        avgDeaths: a.d / a.games,
        avgAssists: a.a / a.games,
        avgCs: a.cs / a.games,
        avgGold: a.gold / a.games,
      ));
    });
    return out;
  }

  Future<http.Response> _withRetry(Future<http.Response> Function() req) async {
    const maxAttempts = 5;
    var attempt = 0, delayMs = 800;
    while (true) {
      attempt++;
      try {
        final r = await req().timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) return r;

        if (r.statusCode == 429) {
          final ra = int.tryParse(r.headers['retry-after'] ?? '');
          final waitMs = ra != null ? (ra * 1000) : (delayMs * attempt);
          await Future.delayed(Duration(milliseconds: waitMs));
          continue;
        }
        if (r.statusCode == 401 || r.statusCode == 403) {
          throw Exception('Riot key invalid/expired (${r.statusCode}).');
        }
        if (r.statusCode >= 500 && r.statusCode <= 599 && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
          continue;
        }
        throw Exception('HTTP ${r.statusCode}: ${r.body}');
      } on TimeoutException {
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      }
    }
  }
}

// accumulators & struct
class _Acc { int games=0, wins=0, k=0, d=0, a=0, cs=0, gold=0; }

class _RoleSeed {
  _RoleSeed({
    required this.role,
    required this.games,
    required this.wins,
    required this.winrate,
    required this.avgKills,
    required this.avgDeaths,
    required this.avgAssists,
    required this.avgCs,
    required this.avgGold,
  });
  final String role;
  final int games, wins;
  final double winrate, avgKills, avgDeaths, avgAssists, avgCs, avgGold;
}
