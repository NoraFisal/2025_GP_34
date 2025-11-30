// lib/pages/team/results_page.dart
//
// FINAL MERGED VERSION — SPARK Team Winrate V5
// - Notebook logic 1:1
// - New Card UI
// - Status-aware duplicate logic with 3 popups
// - Sends invitations and goes to TeamChatPage after creation
// -------------------------------------------------------------

import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';

import '../../services/player/model_service.dart';
import '../../services/player/player_role_stats.dart';
import '../../services/team/team_model_v5.dart';
import '../../services/player/team/team_service.dart';
import '../chat/team_chat_page.dart';

import '../player/player_profile_page.dart'; // still used elsewhere

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
  bool _loading = true;

  final Map<String, List<PlayerRoleStats>> _statsByPlayer = {};

  List<Map<String, dynamic>> top3 = [];

  final PageController _pageCtrl = PageController(viewportFraction: 0.78);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // -------------------------------------------------------------
  // LOAD PLAYER ROLE STATS FROM FIREBASE
  // -------------------------------------------------------------
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

          if (snap.docs.isEmpty) {
            print("⚠ No roleStats for ${p.uid} → skip");
            continue;
          }

          final list = <PlayerRoleStats>[];
          for (final d in snap.docs) {
            list.add(PlayerRoleStats.fromFirestore(d.id, d.data()));
          }

          _statsByPlayer[p.uid] = list;
        } catch (e) {
          print("❌ Error loading roleStats for ${p.uid}: $e");
        }
      }

      await computeTop3();
    } catch (e) {
      print("❌ Error in _loadStats(): $e");
    }

    if (mounted) setState(() => _loading = false);
  }

  // -------------------------------------------------------------
  // COMPUTE TOP 3 COMPOSITIONS
  // -------------------------------------------------------------
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
        team.add(AssignedPlayer(stats: stats, assignedRole: r));
      }

      final tf = buildTeamFeatures(team, isBlueTeam: true);
      final vector = model.buildVector(tf.features);

      final prob = model.predict(vector);
      final wr = (prob * 100).clamp(0, 100);

      results.add({'map': map, 'winrate': wr});
    }

    results.sort((a, b) => b['winrate'].compareTo(a['winrate']));
    top3 = results.take(3).toList();
  }

  // -------------------------------------------------------------
  // BUILD UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Team Winrate'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Top 3 Compositions',
                      style: t.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: top3.isEmpty
                          ? Center(
                              child: Text(
                                'No valid compositions found',
                                style: t.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : PageView.builder(
                              controller: _pageCtrl,
                              itemCount: top3.length,
                              itemBuilder: (_, i) =>
                                  _animatedCard(context, top3[i], i),
                            ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: kToolbarHeight + 20,
                  child: MiniSideNav(
                    top: kToolbarHeight + 20,
                    left: 0,
                  ),
                ),
              ],
            ),
    );
  }

  // -------------------------------------------------------------
  // Animated swipe card
  // -------------------------------------------------------------
  Widget _animatedCard(
      BuildContext context, Map<String, dynamic> comp, int index) {
    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (context, child) {
        double value = 1.0;

        if (_pageCtrl.position.haveDimensions) {
          value = (_pageCtrl.page! - index).abs();
          value = (1 - value * 0.18).clamp(0.82, 1.0);
        }

        return Center(
          child: Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: _compCard(context, comp),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // One composition card
  // -------------------------------------------------------------
  Widget _compCard(BuildContext context, Map<String, dynamic> comp) {
    final t = Theme.of(context);
    const roles = ['top', 'jungle', 'middle', 'bottom', 'support'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title + winrate
          Row(
            children: [
              Expanded(
                child: Text(
                  "Composition",
                  style: t.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              _winrateCircle(comp['winrate']),
            ],
          ),
          const SizedBox(height: 22),

          // roles list
          Column(
            children: roles.map((r) {
              final uid = comp['map'][r];
              final name = _playerName(uid);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        r.toUpperCase(),
                        style: t.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      name,
                      style: t.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Select button
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB6382B).withOpacity(.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _saveTeamToFirestore(
                    context, comp['map'], comp['winrate']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB6382B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Select",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Winrate circle
  // -------------------------------------------------------------
  Widget _winrateCircle(double wr) {
    wr = wr.clamp(0, 100);

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: wr / 100,
            strokeWidth: 6,
            color: const Color(0xFFB6382B),
            backgroundColor: Colors.white24,
          ),
          Text(
            "${wr.toStringAsFixed(0)}%",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          )
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SAVE TEAM TO FIREBASE — 3 POPUP CASES
  // -------------------------------------------------------------
  Future<void> _saveTeamToFirestore(
    BuildContext context,
    Map<String, String> mapping,
    double winrate,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!context.mounted) return;
      await _showErrorPopup(
        context,
        title: 'Login required',
        message: 'You must be logged in to create a team.',
      );
      return;
    }

    final trimmedName = widget.teamName.trim();
    if (trimmedName.isEmpty) {
      if (!context.mounted) return;
      await _showErrorPopup(
        context,
        title: 'Add team name',
        message: 'Please enter a team name before creating your team.',
      );
      return;
    }

    // Build lineupKey from roles + uids
    final sortedEntries = mapping.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final lineupKey =
        sortedEntries.map((e) => '${e.key}:${e.value}').join('|');

    final db = FirebaseFirestore.instance;

    // ---------- CHECK EXISTING TEAMS ----------
    try {
      final snap = await db
          .collection('Team')
          .where('lineupKey', isEqualTo: lineupKey)
          .get();

      bool hasAcceptedSameWr = false;
      bool hasPendingSameWr = false;

      for (final doc in snap.docs) {
        final data = doc.data();
        final status =
            (data['status'] ?? '').toString().toLowerCase().trim();
        final oldWR = (data['winRate'] ?? 0).toDouble();

        final sameWR =
            oldWR.toStringAsFixed(0) == winrate.toStringAsFixed(0);

        if (!sameWR) continue;

        if (status == 'accepted') {
          hasAcceptedSameWr = true;
        } else if (status == 'pending') {
          hasPendingSameWr = true;
        }
      }

      // 1️⃣ Used & ACCEPTED → block with message
      if (hasAcceptedSameWr) {
        if (!context.mounted) return;
        await _showErrorPopup(
          context,
          title: 'Already used lineup',
          message:
              'This exact lineup and winrate has already been accepted.\nPlease choose a different combination.',
        );
        return;
      }

      // 2️⃣ Used & PENDING → special confirm
      if (hasPendingSameWr) {
        if (!context.mounted) return;
        final again = await _confirmPendingLineup(context);
        if (!again) return;
      } else {
        // 3️⃣ Not used with this winrate (new or different WR) → normal "New Lineup" confirm
        if (!context.mounted) return;
        final confirmNew = await _confirmNewLineup(context);
        if (!confirmNew) return;
      }
    } catch (e) {
      if (!context.mounted) return;
      await _showErrorPopup(
        context,
        title: 'Error',
        message: e.toString(),
      );
      return;
    }

    // ---------- Logo encoding ----------
    String? logoBase64;
    if (widget.logoBytes != null && widget.logoBytes!.isNotEmpty) {
      try {
        logoBase64 = base64Encode(widget.logoBytes!);
      } catch (_) {}
    }

    // Loading popup
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      // -------- Create team doc --------
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

      // -------- Add Members --------
      for (final entry in mapping.entries) {
        await teamRef.collection('Members').doc(entry.value).set({
          'role': entry.key,
          'response':
              entry.value == currentUser.uid ? 'Accepted' : 'none',
        });
      }

      // -------- Create TeamChat --------
      await db.collection('TeamChat').doc(teamRef.id).set({
        'teamId': teamRef.id,
        'lastMessage': '🎮 Team invitation sent!',
        'lastTime': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // -------- Send invitations --------
      await TeamService.sendTeamInvitations(teamRef.id);

      if (context.mounted) Navigator.pop(context); // close loading

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            logoBase64 != null
                ? 'Team created with logo!'
                : 'Team created!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Go directly to Team Chat after creation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => TeamChatPage(
            teamId: teamRef.id,
            teamName: trimmedName,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);

      if (!context.mounted) return;
      await _showErrorPopup(
        context,
        title: 'Error',
        message: 'Failed to create team.\n$e',
      );
    }
  }

  // -------------------------------------------------------------
  // Helper: return player's name by uid
  // -------------------------------------------------------------
  String _playerName(String uid) {
    final p = widget.roster.firstWhere(
      (x) => x.uid == uid,
      orElse: () =>
          PickedPlayer(uid: uid, name: 'Unknown', photoUrl: ''),
    );
    return p.name;
  }

  // -------------------------------------------------------------
  // Generate all permutations (Notebook logic 1:1)
  // -------------------------------------------------------------
  List<List<PickedPlayer>> _permutePlayers(List<PickedPlayer> players) {
    if (players.length < 5) return [];

    final list = players.take(5).toList();

    List<List<PickedPlayer>> results = [];

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

  // -------------------------------------------------------------
  // Error popup
  // -------------------------------------------------------------
  Future<void> _showErrorPopup(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(.15), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color.fromARGB(255, 213, 18, 31), size: 40),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 213, 18, 31),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Ok", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Confirm New Lineup popup  (case 2 / orange style)
  // -------------------------------------------------------------
  Future<bool> _confirmNewLineup(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(.15), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline,
                  color: Color.fromARGB(255, 213, 18, 31), size: 40),
              const SizedBox(height: 16),
              const Text(
                "New Lineup",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "This combination of players hasn't been used before.\nAre you sure you want to continue?",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:  Color.fromARGB(255, 213, 18, 31),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Yes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }

  // -------------------------------------------------------------
  // Confirm Pending Lineup popup (case 3)
  // -------------------------------------------------------------
  Future<bool> _confirmPendingLineup(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(.15), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_bottom,
                  color:  Color.fromARGB(255, 213, 18, 31), size: 40),
              const SizedBox(height: 16),
              const Text(
                "Lineup already pending",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "You already have a team with this lineup and winrate that is still pending.\nDo you want to send another set of invitations?",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        "No",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:  Color.fromARGB(255, 213, 18, 31),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Yes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }
}
