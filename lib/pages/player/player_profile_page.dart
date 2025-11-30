// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; 
import '/data/riot_link_service.dart';
import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '/ui/theme.dart';
import '../../services/player/player_service.dart';
import '../team/create_team_page.dart';
import '../team/edit_team_page.dart';
import '../team/team_details_page.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key});

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _showAge = true;
  bool _showCity = true;
  bool _showGender = true;

  int _unreadPlayer = 0;
  int _unreadTeam = 0;

  @override
  void initState() {
    super.initState();
    _listenUnreadNotifications();
  }

  void _listenUnreadNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Player Chats
    FirebaseFirestore.instance
        .collection('PlayerChat')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((chatSnap) async {
      int total = 0;
      for (var chat in chatSnap.docs) {
        final msgsSnap = await chat.reference
            .collection('PlayerMessage')
            .where('ReceiverID', isEqualTo: user.uid)
            .where('status', isEqualTo: 'sent')
            .get();
        total += msgsSnap.docs.length;
      }
      if (mounted) setState(() => _unreadPlayer = total);
    });

    // Team Chats
    FirebaseFirestore.instance.collection('TeamChat').snapshots().listen((teamChats) async {
      int totalT = 0;
      for (var chat in teamChats.docs) {
        final msgs = await chat.reference.collection('TeamMessage').get();
        for (var m in msgs.docs) {
          final readBy = List<String>.from(m['readBy'] ?? []);
          if (!readBy.contains(user.uid)) totalT++;
        }
      }
      if (mounted) setState(() => _unreadTeam = totalT);
    });
  }

  int get _totalUnread => _unreadPlayer + _unreadTeam;

  // NEW PROGRESS BAR UPDATE DIALOG
  Future<void> _showProgressDialog(Stream<double> progressStream) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) {
        return StreamBuilder<double>(
          stream: progressStream,
          initialData: 0.0,
          builder: (context, snap) {
            double v = snap.data ?? 0;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.cardDeep,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Updating... ${(v * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateLolStats(String playerId) async {
    final svc = RiotLinkService(FirebaseFirestore.instance);

    final controller = StreamController<double>();
    _showProgressDialog(controller.stream);

    try {
      controller.add(0.1);
      await svc.clearRoleStats(playerId);

      controller.add(0.45);
      await svc.buildSeedsForLinkedLol(
        playerId: playerId,
        maxMatches: 50,
        forceRefresh: true,
        allowNonRankedIfEmpty: true,
      );

      controller.add(0.85);
      await Future.delayed(const Duration(milliseconds: 400));

      controller.add(1.0);
      await Future.delayed(const Duration(milliseconds: 400));

      Navigator.of(context, rootNavigator: true).pop();
      controller.close();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Done! Stats updated 🎉")));

      setState(() {});
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      controller.close();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Widget _chart() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF1C2430), Color(0xFF1B2028)],
        ),
      ),
      child: const Center(
        child: Text("chart", style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _gameCard(String gameId, PlayerData user) {
    final id = gameId.toLowerCase();
    final isLol = id == "lol" || id == "leagueoflegends";

    return Card(
      color: AppColors.cardDeep,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${gameId[0].toUpperCase()}${gameId.substring(1)} Performance stats",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              _glowRectButton(
                "Update",
                onTap: () {
                  if (isLol) {
                    _updateLolStats(user.uid);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$gameId update coming soon")),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _chart(),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BgScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, "/homepage", (_) => false),
        ),
        title: const Text("Player Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, "/chatList"),
              ),
              if (_totalUnread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      "$_totalUnread",
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 6),
          _glowRectButton("Edit", onTap: () => Navigator.pushNamed(context, "/playerEdit")),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<PlayerData?>(    
            stream: PlayerService.watchMe(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
              final user = userSnap.data!;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("Player")
                    .doc(user.uid)
                    .collection("linkedGames")
                    .snapshots(),
                builder: (context, gameSnap) {
                  final games = gameSnap.data?.docs ?? [];

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          const SizedBox(height: 8),
                          _profileHeader(user),
                          const SizedBox(height: 14),
                          _infoCard(user),
                          const SizedBox(height: 14),
                          const Text(
                            "Suggestions",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          _roundedTiles(3),
                          const SizedBox(height: 20),

                          Align(
                            alignment: Alignment.centerRight,
                            child: _glowRectButton(
                              "Add New Game",
                              onTap: () => Navigator.pushNamed(context, "/connect-game"),
                            ),
                          ),

                          const SizedBox(height: 16),

                          ...games.map((g) => Column(
                                children: [
                                  _gameCard(g.id, user),
                                  const SizedBox(height: 12),
                                ],
                              )),

                          const SizedBox(height: 22),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "My Teams",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              _glowRectButton(
                                "Create Team",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CreateTeamPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          _teamsSection(user.uid),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            left: 0,
            top: kToolbarHeight + 20,
            child: MiniSideNav(top: kToolbarHeight + 20, left: 0),
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(PlayerData u) {
    return Center(
      child: Column(children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: AppColors.card,
          backgroundImage:
              u.profilePhoto.isNotEmpty ? MemoryImage(base64Decode(u.profilePhoto)) : null,
          child: u.profilePhoto.isEmpty
              ? const Icon(Icons.person, size: 42, color: Colors.white70)
              : null,
        ),
        const SizedBox(height: 10),
        Text(u.username,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  Widget _infoCard(PlayerData u) {
    return Card(
      color: AppColors.cardDeep,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showAge) _kv("Age", "${u.age}"),
            if (_showCity && u.city.isNotEmpty) _kv("City", u.city),
            if (_showGender && u.gender.isNotEmpty) _kv("Gender", u.gender),
            if (u.games.isNotEmpty) _kv("Games", u.games.join(", ")),
          ],
        ),
      ),
    );
  }

  Widget _teamsSection(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(    
      stream: PlayerService.watchMyAcceptedTeams(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final teams = snap.data!;
        if (teams.isEmpty) {
          return const Text("No teams", style: TextStyle(color: Colors.white70));
        }

        return Column(children: teams.map((t) => _teamCard(t)).toList());
      },
    );
  }

  Widget _teamCard(Map<String, dynamic> team) {
    return FutureBuilder<List<PlayerData?>>(
      future: Future.wait(
        (team['members'] as List).map((m) => PlayerService.getPlayerData(m['userId'])),
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Card(
            color: AppColors.card,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          );
        }

        final members = snap.data!.where((p) => p != null).toList();
        final teamId = team['teamId'];
        final teamName = team['teamName'];

        return InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TeamDetailsPage(teamId: teamId, teamName: teamName))),
          child: Card(
            color: AppColors.card,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(teamName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: members.map((p) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.pill,
                            backgroundImage: p!.profilePhoto.isNotEmpty
                                ? MemoryImage(base64Decode(p.profilePhoto))
                                : null,
                            child: p.profilePhoto.isEmpty
                                ? const Icon(Icons.person, size: 16, color: Colors.white70)
                                : null,
                          ),
                        );
                      }).toList(),
                    )
                  ]),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, "/teamChat",
                      arguments: {"teamId": teamId, "teamName": teamName}),
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => EditTeamPage(teamId: teamId))),
                  child: const Icon(Icons.settings, color: Colors.white70),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  static Widget _roundedTiles(int c) => Row(
        children: List.generate(
          c,
          (i) => Container(
            margin: EdgeInsets.only(right: i == c - 1 ? 0 : 10),
            height: 56,
            width: 76,
            decoration: BoxDecoration(color: AppColors.pill, borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            children: [
              TextSpan(text: "$k: ", style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: v, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );

  static Widget _glowRectButton(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF9E2819),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(.4), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
