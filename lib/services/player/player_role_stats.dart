

class PlayerRoleStats {
  final String role;
  final double avgKills;
  final double avgDeaths;
  final double avgAssists;
  final double avgCs;
  final double avgGold;
  final double winrate;         
  final int gamesPlayed;

  PlayerRoleStats({
    required this.role,
    required this.avgKills,
    required this.avgDeaths,
    required this.avgAssists,
    required this.avgCs,
    required this.avgGold,
    required this.winrate,
    required this.gamesPlayed,
  });


  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory PlayerRoleStats.fromFirestore(String role, Map<String, dynamic> data) {
    return PlayerRoleStats(
      role: role,
      avgKills: _num(data['avg_kills']),
      avgDeaths: _num(data['avg_deaths']),
      avgAssists: _num(data['avg_assists']),
      avgCs: _num(data['avg_cs']),
      avgGold: _num(data['avg_gold']),
      winrate: _num(data['winrate']),
      gamesPlayed: _int(data['games_played']),
    );
  }
}
