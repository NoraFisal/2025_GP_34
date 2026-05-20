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
                'image': (doc.data()['image'] ?? '').toString(),
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
                              : result['type'] == 'Team'
                              ? Icons.groups_rounded
                              : result['type'] == 'Tournament'
                              ? Icons.emoji_events_rounded
                              : Icons.business_rounded,
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
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Tournaments — horizontal scroll, big image card
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTournamentsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Tournament')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Error loading tournaments',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: _muted,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No tournaments yet',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: _muted,
                ),
              ),
            ),
          );
        }

        final tournaments = snapshot.data!.docs;
        final count = tournaments.length > 5 ? 5 : tournaments.length;

        return SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final t = tournaments[index];
              final data = t.data() as Map<String, dynamic>;
              return _TournamentCard(
                tournamentId: t.id,
                title: data['Title'] ?? 'Tournament',
                timeText: data['time'] ?? '',
                dateText: data['date'] ?? '',
                imageBase64: data['image'] ?? '',
                game: data['game'] ?? '',
                organizerId: data['organizerID'] ?? '',
              );
            },
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TOURNAMENT CARD — big image top, info below
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TournamentCard extends StatelessWidget {
  final String tournamentId;
  final String title;
  final String timeText;
  final String dateText;
  final String imageBase64;
  final String game;
  final String organizerId;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  const _TournamentCard({
    required this.tournamentId,
    required this.title,
    required this.timeText,
    required this.dateText,
    this.imageBase64 = '',
    this.game = '',
    this.organizerId = '',
  });

  String _getGameLogo(String gameName) {
    final g = gameName.toLowerCase();
    if (g.contains('pubg')) return 'assets/images/pubg.png';
    if (g.contains('lol') || g.contains('league'))
      return 'assets/images/lol.png';
    if (g.contains('valorant')) return 'assets/images/valorant.png';
    if (g.contains('call of duty') || g.contains('cod'))
      return 'assets/images/cod.png';
    if (g.contains('fortnite')) return 'assets/images/fortnite.png';
    return 'assets/images/pubg.png';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewTournamentPage(tournamentId: tournamentId),
        ),
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Big image on top ──────────────────
            Stack(
              children: [
                // Background image
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: imageBase64.isNotEmpty
                      ? Image.memory(
                          base64Decode(imageBase64),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderBg(game: game),
                        )
                      : _PlaceholderBg(game: game),
                ),
                // Dark gradient so text would be readable if needed
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.28),
                        ],
                      ),
                    ),
                  ),
                ),
                // Game logo pill — bottom-left of image
                if (game.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: Image.asset(
                              _getGameLogo(game),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.sports_esports_rounded,
                                color: _accent,
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            game,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info below image ──────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Time & date row
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: _muted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            timeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 11,
                          color: _muted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Organizer chip — at the bottom
                    if (organizerId.isNotEmpty)
                      _OrganizerChip(organizerId: organizerId),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder when no image
class _PlaceholderBg extends StatelessWidget {
  final String game;
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  const _PlaceholderBg({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFEDE9),
      child: Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: _accent.withOpacity(0.3),
          size: 40,
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ORGANIZER CHIP  (compact, shown at bottom of card)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _OrganizerChip extends StatelessWidget {
  final String organizerId;
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _line = Color(0xFFCFD9DE);

  const _OrganizerChip({required this.organizerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Organizer')
          .doc(organizerId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = (data['Name'] ?? 'Organizer').toString();
        final photo = (data['ProfilePhoto'] ?? '').toString();
        final imageProvider = getProfileImage(photo);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small avatar
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accent, width: 1.2),
                color: const Color(0xFFEFEFEF),
              ),
              child: ClipOval(
                child: imageProvider != null
                    ? Image(image: imageProvider, fit: BoxFit.cover)
                    : const Icon(Icons.person, color: Colors.black38, size: 11),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _text,
                  height: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============ UI Components ============

class _TopBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _chip = Color(0xFFF0F3F4);
  static const Color _line = Color(0xFFCFD9DE);

  const _TopBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: _chip,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: _accent,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _text,
              ),
              decoration: const InputDecoration(
                hintText: 'Search players, teams, organizers, tournaments...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
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
    );
  }
}

class _SeeAllPill extends StatelessWidget {
  final VoidCallback onTap;
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  const _SeeAllPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: const Text(
          'See all',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CIRCLE STROKE IMAGE — always red border, no gold
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _CircleStrokeImage extends StatelessWidget {
  final double size;
  final double borderWidth;
  final ImageProvider? imageProvider;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  const _CircleStrokeImage({
    required this.size,
    required this.borderWidth,
    required this.imageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final inner = size - (borderWidth * 2) - 6;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent, width: borderWidth),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Container(
          color: const Color(0xFFEFEFEF),
          child: imageProvider == null
              ? const Icon(Icons.person, color: Colors.black38, size: 26)
              : Image(
                  image: imageProvider!,
                  width: inner,
                  height: inner,
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}
