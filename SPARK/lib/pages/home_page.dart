// lib/ui/home_page.dart  (path name may differ in your project)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'player/player_profile_view_page.dart';
import 'player/player_profile_page.dart';
import 'view_team_page.dart';
import '/ui/components/mini_side_nav.dart';
import '../../../services/player/team/team_status_service.dart';
import '../../../services/player/image_helper.dart';
import 'accepted_teams_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  String? profileImageUrl;

  // listen for team status updates
  StreamSubscription<TeamStatusUpdate?>? _teamStatusSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _listenToTeamStatus();
  }

  void _listenToTeamStatus() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _teamStatusSubscription =
        TeamStatusService.listenToUserTeams(userId).listen(
      (update) {
        if (update != null && mounted) {
          // dark-themed alert dialog
          TeamStatusService.showTeamStatusAlert(context, update);
        }
      },
      onError: (error) {
        debugPrint('❌ Error listening to team status: $error');
      },
    );
  }

  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Player')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        setState(() {
          profileImageUrl = snapshot.data()?['ProfilePhoto'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("error downloading photo $e");
    }
  }

  Future<void> _searchData(String query) async {
    final searchQuery = query.trim();

    if (searchQuery.isEmpty) {
      setState(() {
        searchResults.clear();
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    final playersSnapshot = await FirebaseFirestore.instance
        .collection('Player')
        .where('Name', isGreaterThanOrEqualTo: searchQuery)
        .where('Name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
        .get();

    final teamsSnapshot = await FirebaseFirestore.instance
        .collection('Team')
        .where('name', isGreaterThanOrEqualTo: searchQuery)
        .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
        .get();

    final results = [
      ...playersSnapshot.docs.map((doc) => {
            'id': doc.id,
            'type': 'Player',
            'name': doc['Name'] ?? 'Unknown Player',
            'image': doc['ProfilePhoto'] ?? '',
          }),
      ...teamsSnapshot.docs.map((doc) => {
            'id': doc.id,
            'type': 'Team',
            'name': doc['name'] ?? 'Unknown Team',
            'image': doc['logoUrl'] ?? '',
          }),
    ];

    setState(() {
      searchResults = results;
      isSearching = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchLatestAcceptedTeams() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Team')
          .where('status', isEqualTo: 'Accepted')
          .get(); // no orderBy (no index needed)

      debugPrint('✅ Found ${snapshot.docs.length} accepted teams');

      final teams = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Team',
          'logo': data['logoUrl'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();

      // sort newest first
      teams.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return teams.take(3).toList();
    } catch (e) {
      debugPrint('❌ Error fetching teams: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _teamStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  height: 32,
                  width: MediaQuery.of(context).size.width * 0.90,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchData,
                      style:
                          const TextStyle(color: Colors.black, fontSize: 13),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search,
                            size: 17, color: Colors.black54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: -5),
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 10.0, top: 6.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlayerProfilePage(),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: getProfileImage(profileImageUrl),
                      child: (profileImageUrl == null ||
                              profileImageUrl!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.black54)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (searchResults.isNotEmpty || isSearching)
                            buildSearchResults()
                          else ...[
                            buildSection(
                                context, "Players Spotlight", buildPlayersRow()),
                            const SizedBox(height: 20),
                            buildSection(context, "Upcoming Tournaments",
                                buildTournamentsGrid()),
                            const SizedBox(height: 20),
                            buildSection(
                                context, "Explore Teams", buildTeamsRow()),
                          ],
                        ],
                      ),
                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  // ---------- SEARCH RESULTS ----------

  Widget buildSearchResults() {
    return Column(
      children: searchResults.map((result) {
        final imageProvider = getProfileImage(result['image']);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: imageProvider,
            backgroundColor: Colors.grey[800],
            child: imageProvider == null
                ? Icon(
                    result['type'] == 'Player'
                        ? Icons.person
                        : Icons.group,
                    color: Colors.white54,
                  )
                : null,
          ),
          title: Text(result['name'],
              style: const TextStyle(color: Colors.white)),
          subtitle: Text(result['type'],
              style: const TextStyle(color: Colors.white70)),
          onTap: () {
            if (result['type'] == 'Player') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ViewPlayerProfilePage(userId: result['id']),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewTeamPage(teamId: result['id']),
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }

  // ---------- SECTIONS ----------

  Widget buildSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 30,
          child: Stack(
            children: [
              const SizedBox.shrink(),
              Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: _glowRectButton(
                  'See All',
                  onTap: () {
                    if (title == "Explore Teams") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AcceptedTeamsPage(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(28, 30, 40, 1).withAlpha(89),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: content,
        ),
      ],
    );
  }

  static Widget _glowRectButton(String text, {required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        borderRadius: BorderRadius.circular(8),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF9E2819),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  // ---------- PLAYERS / TOURNAMENTS / TEAMS ----------

  Widget buildPlayersRow() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (_) =>
              const CircleAvatar(radius: 45, backgroundColor: Color(0xFF3A3A3A)),
        ),
      );

  Widget buildTournamentsGrid() => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(89),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

  Widget buildTeamsRow() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchLatestAcceptedTeams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              "No teams available",
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final teams = snapshot.data!;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: teams.map((team) {
            final image = getProfileImage(team['logo']);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewTeamPage(teamId: team['id']),
                  ),
                );
              },
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFF3A3A3A),
                    backgroundImage: image,
                    child: image == null
                        ? const Icon(Icons.group,
                            size: 35, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 80,
                    child: Text(
                      team['name'],
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
