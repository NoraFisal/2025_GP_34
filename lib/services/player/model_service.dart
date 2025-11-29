

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/team/team_model_v5.dart';  


class PickedPlayer {
  final String uid;
  final String name;
  final String photoUrl;

  PickedPlayer({
    required this.uid,
    required this.name,
    required this.photoUrl,
  });
}

class TeamAssignment {
  final Map<String, String> roleToUid;
  final double winrate;

  TeamAssignment(this.roleToUid, this.winrate);
}


class ModelService {
  static const _modelJsonPath = 'assets/model/random_forest_v5.json';
  static const _featPath = 'assets/model/feature_cols_v5.txt';

  Map<String, dynamic>? _rf;
  late final List<String> _featureOrder;

  List<String> get featureOrder => _featureOrder;


  Future<void> ensureLoaded() async {
    if (_rf != null) return;

    
    String jsonStr = await rootBundle.loadString(_modelJsonPath);

  
    jsonStr = jsonStr
        .replaceAll('Infinity', '1e300')
        .replaceAll('-Infinity', '-1e300')
        .replaceAll('NaN', '0');

    _rf = jsonDecode(jsonStr);

  
    final featText = await rootBundle.loadString(_featPath);
    _featureOrder = featText
        .split(RegExp(r'\r?\n'))
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toList();

    print("🎯 Model v5 loaded: ${_featureOrder.length} features");
  }


  List<double> buildVector(Map<String, double> fmap) {
    final vec = List<double>.filled(_featureOrder.length, 0.0);

    for (int i = 0; i < _featureOrder.length; i++) {
      final key = _featureOrder[i];
      vec[i] = fmap[key] ?? 0.0;
    }
    return vec;
  }


  double predict(List<double> vec) {
    final p = rfPredict(vec);
    return p.clamp(0.0, 1.0);
  }


  double rfPredict(List<double> x) {
    double _toDouble(dynamic v, {double or = 0}) {
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
      return or;
    }

    final trees = (_rf!['trees'] as List).cast<Map<String, dynamic>>();
    double sum = 0.0;

    for (final t in trees) {
      final nodes = (t['nodes'] as List).cast<Map<String, dynamic>>();
      int idx = 0;

      while (true) {
        final n = nodes[idx];

        
        if (n.containsKey('v') ||
            n.containsKey('value') ||
            n.containsKey('prob')) {
          sum += _toDouble(n['v'] ?? n['value'] ?? n['prob']);
          break;
        }

     
        final i = _toDouble(n['i'] ?? n['feature']).round();
        final thr = _toDouble(n['t'] ?? n['threshold']);
        final left = _toDouble(n['l'] ?? n['left']).round();
        final right = _toDouble(n['r'] ?? n['right']).round();

        if (i < 0 || i >= x.length) break;

        idx = (x[i] <= thr) ? left : right;
      }
    }

    return trees.isEmpty ? 0.0 : sum / trees.length;
  }



  List<TeamAssignment> rankAssignments(
      List<Map<String, String>> assignments,
      List<double> winrates,
  ) {
    final out = <TeamAssignment>[];

    for (int i = 0; i < assignments.length; i++) {
      out.add(TeamAssignment(assignments[i], winrates[i]));
    }

    out.sort((a, b) => b.winrate.compareTo(a.winrate));
    return out;
  }
}
