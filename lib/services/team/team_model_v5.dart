// lib/services/team/team_model_v5.dart
//
// Team synergy + feature builder (same logic as notebook).
// Uses PlayerRoleStats from player_role_stats.dart.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import '../player/player_role_stats.dart';

/// ------------- AssignedPlayer: player + assigned in this team -------------
class AssignedPlayer {
  final PlayerRoleStats stats;
  final String assignedRole; // top / jungle / middle / bottom / support

  AssignedPlayer({
    required this.stats,
    required this.assignedRole,
  });
}

/// ------------- TeamFeatures wrapper -------------
class TeamFeatures {
  final Map<String, double> features;
  TeamFeatures(this.features);

  @override
  String toString() => features.toString();
}

/// ------------- Feature names (same order as feature_cols_v5.txt) -------------
const List<String> modelV5FeatureNames = [
  'MinionsKilled_mean',
  'assists_mean',
  'deaths_mean',
  'is_blue_team',
  'kills_mean',
  'syn_assist_share_max',
  'syn_assist_share_std',
  'syn_assists_mean',
  'syn_assists_std',
  'syn_deaths_mean',
  'syn_deaths_std',
  'syn_gold_share_max',
  'syn_gold_share_std',
  'syn_kda_mean',
  'syn_kda_std',
  'syn_kill_share_max',
  'syn_kill_share_std',
  'syn_kills_mean',
  'syn_kills_std',
  'syn_minion_share_max',
  'syn_minion_share_std',
  'syn_minions_mean',
  'syn_minions_std',
  'syn_n_players',
  'syn_role_entropy',
  'syn_role_imbalance',
  'syn_role_max_count',
  'syn_role_min_count',
  'syn_role_nunique',
  'dataset_source',
];

/// ------------- Global means (from feature_means_v5.json) -------------
Map<String, double> globalMeans = {};

Future<void> loadGlobalMeans() async {
  if (globalMeans.isNotEmpty) return;
  final str =
      await rootBundle.loadString('assets/json/feature_means_v5.json');
  final jsonData = json.decode(str) as Map<String, dynamic>;
  globalMeans = jsonData.map(
    (key, value) => MapEntry(key, (value as num).toDouble()),
  );
  // ignore: avoid_print
  print('🌟 Global means loaded (${globalMeans.length} entries)');
}

/// ------------- Helpers -------------
double? _mean(List<double> v) {
  if (v.isEmpty) return null;
  return v.reduce((a, b) => a + b) / v.length;
}

double? _std(List<double> v) {
  if (v.length <= 1) return 0.0;
  final m = _mean(v);
  if (m == null) return null;
  double s = 0.0;
  for (final x in v) {
    s += math.pow(x - m, 2) as double;
  }
  return math.sqrt(s / v.length);
}

double? _entropy(Map<String, int> counts) {
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return 0.0;
  double e = 0.0;
  for (final c in counts.values) {
    if (c <= 0) continue;
    final p = c / total;
    e += -p * (math.log(p) / math.log(2));
  }
  return e;
}

/// ------------- Build synergy features for one team -------------
TeamFeatures buildTeamFeatures(
  List<AssignedPlayer> team, {
  required bool isBlueTeam,
}) {
  final kills = <double>[];
  final deaths = <double>[];
  final assists = <double>[];
  final minions = <double>[];
  final gold = <double>[];
  final kdas = <double>[];

  final roleCounts = <String, int>{};

  for (final ap in team) {
    final s = ap.stats;

    kills.add(s.avgKills);
    deaths.add(s.avgDeaths);
    assists.add(s.avgAssists);
    minions.add(s.avgCs);
    gold.add(s.avgGold);

    final d = s.avgDeaths <= 0 ? 1e-3 : s.avgDeaths;
    kdas.add((s.avgKills + s.avgAssists) / d);

    roleCounts[ap.assignedRole] = (roleCounts[ap.assignedRole] ?? 0) + 1;
  }

  final killsMean = _mean(kills);
  final deathsMean = _mean(deaths);
  final assistsMean = _mean(assists);
  final minionsMean = _mean(minions);

  final killsStd = _std(kills);
  final deathsStd = _std(deaths);
  final assistsStd = _std(assists);
  final minionsStd = _std(minions);

  final kdaMean = _mean(kdas);
  final kdaStd = _std(kdas);

  List<double> _buildShares(List<double> values) {
    final total = values.fold<double>(0.0, (a, b) => a + b);
    if (total <= 0) return List.filled(values.length, 0.0);
    return values.map((v) => v / total).toList();
  }

  final killShare = _buildShares(kills);
  final assistShare = _buildShares(assists);
  final minionShare = _buildShares(minions);
  final goldShare = _buildShares(gold);

  final killShareMax = killShare.isEmpty ? 0.0 : killShare.reduce(math.max);
  final assistShareMax =
      assistShare.isEmpty ? 0.0 : assistShare.reduce(math.max);
  final minionShareMax =
      minionShare.isEmpty ? 0.0 : minionShare.reduce(math.max);
  final goldShareMax = goldShare.isEmpty ? 0.0 : goldShare.reduce(math.max);

  final killShareStd = _std(killShare);
  final assistShareStd = _std(assistShare);
  final minionShareStd = _std(minionShare);
  final goldShareStd = _std(goldShare);

  final synRoleEntropy = _entropy(roleCounts);
  final synRoleNunique =
      roleCounts.values.where((c) => c > 0).length.toDouble();

  final synRoleMax = roleCounts.values.isEmpty
      ? 0.0
      : roleCounts.values.reduce((a, b) => a > b ? a : b).toDouble();

  final synRoleMin = roleCounts.values.isEmpty
      ? 0.0
      : roleCounts.values.reduce((a, b) => a < b ? a : b).toDouble();

  final synRoleImbalance = synRoleMax - synRoleMin;

  final raw = <String, double?>{
    'MinionsKilled_mean': minionsMean,
    'assists_mean': assistsMean,
    'deaths_mean': deathsMean,
    'is_blue_team': isBlueTeam ? 1.0 : 0.0,
    'kills_mean': killsMean,

    'syn_assist_share_max': assistShareMax,
    'syn_assist_share_std': assistShareStd,
    'syn_assists_mean': assistsMean,
    'syn_assists_std': assistsStd,

    'syn_deaths_mean': deathsMean,
    'syn_deaths_std': deathsStd,

    'syn_gold_share_max': goldShareMax,
    'syn_gold_share_std': goldShareStd,

    'syn_kda_mean': kdaMean,
    'syn_kda_std': kdaStd,

    'syn_kill_share_max': killShareMax,
    'syn_kill_share_std': killShareStd,
    'syn_kills_mean': killsMean,
    'syn_kills_std': killsStd,

    'syn_minion_share_max': minionShareMax,
    'syn_minion_share_std': minionShareStd,
    'syn_minions_mean': minionsMean,
    'syn_minions_std': minionsStd,

    'syn_n_players': team.length.toDouble(),

    'syn_role_entropy': synRoleEntropy,
    'syn_role_imbalance': synRoleImbalance,
    'syn_role_max_count': synRoleMax,
    'syn_role_min_count': synRoleMin,
    'syn_role_nunique': synRoleNunique,

    'dataset_source': globalMeans['dataset_source'],
  };

  final finalMap = <String, double>{};
  for (final f in modelV5FeatureNames) {
    final val = raw[f];
    if (val == null || val.isNaN || val.isInfinite) {
      final fallback = globalMeans[f];
      finalMap[f] = fallback ?? 0.0;
    } else {
      finalMap[f] = val;
    }
  }

  return TeamFeatures(finalMap);
}
