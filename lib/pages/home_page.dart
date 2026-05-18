import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/player/image_helper.dart';
import 'organizer/organizer_profile_view_page.dart';
import 'player/player_profile_view_page.dart';
import 'view_team_page.dart';
import 'accepted_teams_page.dart';
import 'organizer/view_tournament_page.dart';
import 'all_tournaments_page.dart';
import 'leaderboard_page.dart';

enum UserType { player, organizer, unknown }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  UserType userType = UserType.unknown;
  bool isLoadingUserType = true;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  void initState() {
    super.initState();
    _detectUserType();
  }

  Future<void> _detectUserType() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        userType = UserType.unknown;
        isLoadingUserType = false;
      });
      return;
    }
    try {
      final organizerDoc = await FirebaseFirestore.instance
          .collection('Organizer')
          .doc(userId)
          .get();
      if (organizerDoc.exists) {
        setState(() {
          userType = UserType.organizer;
          isLoadingUserType = false;
        });
        return;
      }
      final playerDoc = await FirebaseFirestore.instance
          .collection('Player')
          .doc(userId)
          .get();
      if (playerDoc.exists) {
        setState(() {
          userType = UserType.player;
          isLoadingUserType = false;
        });
        return;
      }
      setState(() {
        userType = UserType.unknown;
        isLoadingUserType = false;
      });
    } catch (e) {
      debugPrint('Error detecting user type: $e');
      setState(() {
        userType = UserType.unknown;
        isLoadingUserType = false;
      });
    }
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> _searchData(String query) async {
    final q = _normalize(query);

    if (q.isEmpty) {
      setState(() {
        searchResults.clear();
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    try {
      final snapshots = await Future.wait([
        FirebaseFirestore.instance.collection('Player').get(),
        FirebaseFirestore.instance.collection('Organizer').get(),
        FirebaseFirestore.instance.collection('Team').get(),
        FirebaseFirestore.instance.collection('Tournament').get(),
      ]);

      final playersSnapshot = snapshots[0];
      final organizersSnapshot = snapshots[1];
      final teamsSnapshot = snapshots[2];
      final tournamentsSnapshot = snapshots[3];

      bool matches(String value) {
        return _normalize(value).contains(q);
      }

      final results = <Map<String, dynamic>>[
        ...playersSnapshot.docs
            .where((doc) => matches((doc.data()['Name'] ?? '').toString()))
            .map(
              (doc) => {
                'id': doc.id,
                'type': 'Player',
                'name': (doc.data()['Name'] ?? 'Unknown Player').toString(),
                'image': (doc.data()['ProfilePhoto'] ?? '').toString(),
              },
            ),

        ...organizersSnapshot.docs
            .where((doc) => matches((doc.data()['Name'] ?? '').toString()))
            .map(
              (doc) => {
                'id': doc.id,
                'type': 'Organizer',
                'name': (doc.data()['Name'] ?? 'Unknown Organizer').toString(),
                'image': (doc.data()['ProfilePhoto'] ?? '').toString(),
              },
            ),

        ...teamsSnapshot.docs
            .where((doc) => matches((doc.data()['name'] ?? '').toString()))
            .map(
              (doc) => {
                'id': doc.id,
                'type': 'Team',
                'name': (doc.data()['name'] ?? 'Unknown Team').toString(),
                'image': (doc.data()['logoUrl'] ?? '').toString(),
              },
            ),

        ...tournamentsSnapshot.docs
            .where((doc) => matches((doc.data()['Title'] ?? '').toString()))
            .map(
              (doc) => {
                'id': doc.id,
                'type': 'Tournament',
                'name': (doc.data()['Title'] ?? 'Unknown Tournament')
                    .toString(),
                'image': '',
              },
            ),
      ];
      results.sort((a, b) {
        final aName = _normalize(a['name'].toString());
        final bName = _normalize(b['name'].toString());

        final aStarts = aName.startsWith(q);
        final bStarts = bName.startsWith(q);

        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;

        return aName.compareTo(bName);
      });

      if (!mounted) return;
      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      if (!mounted) return;
      setState(() => isSearching = false);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SMART SPOTLIGHT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<List<Map<String, dynamic>>> _fetchSpotlightPlayers() async {
    try {
      final playersSnap = await FirebaseFirestore.instance
          .collection('Player')
          .get();
      final List<Map<String, dynamic>> scored = [];

      for (final playerDoc in playersSnap.docs) {
        final data = playerDoc.data();
        final uid = playerDoc.id;

        final badgesSnap = await FirebaseFirestore.instance
            .collection('Player')
            .doc(uid)
            .collection('badges')
            .get();

        double score = 0;
        String topBadgeLabel = '';
        String topBadgeType = '';

        for (final badge in badgesSnap.docs) {
          final bd = badge.data();
          final type = (bd['type'] ?? '').toString();

          if (type == 'spark_mvp') {
            score += 100;
            if (topBadgeLabel.isEmpty) {
              topBadgeLabel = 'SPARK MVP';
              topBadgeType = 'trophy';
            }
          } else if (type == 'win_rate_rank') {
            final label = (bd['label'] ?? '').toString();
            if (label == 'Diamond') {
              score += 80;
              if (topBadgeLabel.isEmpty) {
                topBadgeLabel = 'Diamond';
                topBadgeType = 'diamond';
              }
            } else if (label == 'Gold') {
              score += 60;
              if (topBadgeLabel.isEmpty) {
                topBadgeLabel = 'Gold';
                topBadgeType = 'medal';
              }
            } else if (label == 'Silver') {
              score += 40;
              if (topBadgeLabel.isEmpty) {
                topBadgeLabel = 'Silver';
                topBadgeType = 'medal';
              }
            } else if (label == 'Bronze') {
              score += 20;
              if (topBadgeLabel.isEmpty) {
                topBadgeLabel = 'Bronze';
                topBadgeType = 'medal';
              }
            }
          } else if (type == 'streak') {
            final flames = (bd['flameCount'] as num?)?.toInt() ?? 0;
            score += flames * 8.0;
            if (topBadgeLabel.isEmpty && flames >= 3) {
              topBadgeLabel = (bd['label'] ?? 'Streak').toString();
              topBadgeType = 'fire';
            }
          }
          score += 5;
        }

        scored.add({
          'id': uid,
          'name': (data['Name'] ?? 'Player').toString(),
          'photo': (data['ProfilePhoto'] ?? '').toString(),
          'score': score,
          'badgeCount': badgesSnap.docs.length,
          'topBadgeLabel': topBadgeLabel,
          'topBadgeType': topBadgeType,
        });
      }

      scored.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );
      return scored.take(3).toList();
    } catch (e) {
      debugPrint('Error fetching spotlight players: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLatestAcceptedTeams() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Team')
          .where('status', isEqualTo: 'Accepted')
          .get();

      final teams = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['name'] ?? 'Unknown Team').toString(),
          'logo': (data['logoUrl'] ?? '').toString(),
          'createdAt': data['createdAt'],
        };
      }).toList();

      teams.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return teams.take(3).toList();
    } catch (e) {
      debugPrint('Error fetching teams: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingUserType) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _TopBar(
                controller: _searchController,
                onChanged: _searchData,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (searchResults.isNotEmpty || isSearching)
                      _buildSearchResults()
                    else ...[
                      if (userType == UserType.organizer)
                        _buildOrganizerContent()
                      else
                        _buildPlayerContent(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildPlayerContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildSection(
        title: 'Players Spotlight',
        onSeeAll: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardPage()),
        ),
        content: _buildPlayersRow(),
      ),
      const SizedBox(height: 35),
      _buildSection(
        title: 'Upcoming Tournaments',
        onSeeAll: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllTournamentsPage()),
        ),
        content: _buildTournamentsGrid(),
      ),
      const SizedBox(height: 35),
      _buildSection(
        title: 'Explore Teams',
        onSeeAll: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AcceptedTeamsPage()),
        ),
        content: _buildTeamsRow(),
      ),
      const SizedBox(height: 30),
    ],
  );
}

Widget _buildOrganizerContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildSection(
        title: 'Players Spotlight',
        onSeeAll: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardPage()),
        ),
        content: _buildPlayersRow(),
      ),
      const SizedBox(height: 35),
      _buildSection(
        title: 'All Tournaments',
        onSeeAll: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllTournamentsPage()),
        ),
        content: _buildTournamentsGrid(),
      ),
      const SizedBox(height: 35),
      _buildSection(
        title: 'Explore Teams',
        onSeeAll: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AcceptedTeamsPage()),
        ),
        content: _buildTeamsRow(),
      ),
      const SizedBox(height: 30),
    ],
  );
}

 

  Widget _buildSection({
    required String title,
    required VoidCallback onSeeAll,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text,
                    height: 1,
                  ),
                ),
              ),
              _SeeAllPill(onTap: onSeeAll),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: searchResults.map((result) {
        final imageProvider = getProfileImage(result['image']);
        return GestureDetector(
          onTap: () {
            if (result['type'] == 'Player') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewPlayerProfilePage(userId: result['id']),
                ),
              );
            } else if (result['type'] == 'Team') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewTeamPage(teamId: result['id']),
                ),
              );
            } else if (result['type'] == 'Tournament') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ViewTournamentPage(tournamentId: result['id']),
                ),
              );
            } else if (result['type'] == 'Organizer') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ViewOrganizerProfilePage(organizerId: result['id']),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEFEFEF),
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Icon(
                          result['type'] == 'Player'
                              ? Icons.person
                              : Icons.group,
                          color: Colors.black38,
                          size: 18,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _text,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result['type'],
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _muted,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: _muted, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Players Row — rank number badge instead of trophy icon
  //               red border for all (no gold)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildPlayersRow() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchSpotlightPlayers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 110,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final players = snapshot.data ?? [];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final p = (i < players.length) ? players[i] : null;
            final img = p == null ? null : getProfileImage(p['photo']);
            final topBadgeLabel = (p?['topBadgeLabel'] ?? '').toString();
            final rank = i + 1; // 1, 2, 3

            return GestureDetector(
              onTap: p == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ViewPlayerProfilePage(userId: p['id']),
                        ),
                      );
                    },
              child: Column(
                children: [
                  // Avatar with rank number badge in corner
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Red border for everyone (no gold)
                      _CircleStrokeImage(
                        size: 80,
                        borderWidth: 2.5,
                        imageProvider: img,
                      ),
                      // Rank number in top-right corner
                      if (p != null)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: _accent, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: _accent,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (p != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        p['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ),
                    if (topBadgeLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _accent.withOpacity(0.25)),
                        ),
                        child: Text(
                          topBadgeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          }),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Teams Row
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTeamsRow() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchLatestAcceptedTeams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final teams = snapshot.data ?? [];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final t = (i < teams.length) ? teams[i] : null;
            final img = t == null ? null : getProfileImage(t['logo']);

            return GestureDetector(
              onTap: t == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewTeamPage(teamId: t['id']),
                        ),
                      );
                    },
              child: Column(
                children: [
                  _CircleStrokeImage(
                    size: 80,
                    borderWidth: 2.5,
                    imageProvider: img,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _accent.withOpacity(0.2)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (t?['name'] ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'In
