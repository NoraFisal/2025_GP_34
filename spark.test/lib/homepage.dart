import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'view_player_profile_page.dart';
import 'view_team_page.dart';
import '../ui/side_nav.dart'; // استدعاء SparkNavHandle

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;

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

    // البحث عن اللاعبين
    final playersSnapshot = await FirebaseFirestore.instance
        .collection('Player')
        .where('Name', isGreaterThanOrEqualTo: searchQuery)
        .where('Name', isLessThanOrEqualTo: '${searchQuery}\uf8ff')
        .get();

    // البحث عن الفرق
    final teamsSnapshot = await FirebaseFirestore.instance
        .collection('Team')
        .where('Name', isGreaterThanOrEqualTo: searchQuery)
        .where('Name', isLessThanOrEqualTo: '${searchQuery}\uf8ff')
        .get();

    // دمج النتائج مع التأكد من أن الحقول النصية صحيحة
    final results = [
      ...playersSnapshot.docs.map((doc) => {
            'id': doc.id,
            'type': 'Player',
            'name': doc['Name'] ?? 'Unknown Player',
            'image': doc['ProfilePhoto'] != null ? doc['ProfilePhoto'].toString() : '',
          }),
      ...teamsSnapshot.docs.map((doc) => {
            'id': doc.id,
            'type': 'Team',
            'name': doc['Name'] ?? 'Unknown Team',
            'image': doc['Logo'] != null ? doc['Logo'].toString() : '',
          }),
    ];

    setState(() {
      searchResults = results;
      isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage('assets/background.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    searchResults.clear();
                    isSearching = false;
                  });
                },
              ),
              titleSpacing: 0,
              title: Container(
                height: 38,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 60, 60, 60).withAlpha(100),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchData,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: Colors.white70),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: InputBorder.none,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {},
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.person, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
           Expanded(
  child: Stack(
    children: [
      // المحتوى القابل للتمرير
      Positioned.fill(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (searchResults.isNotEmpty || isSearching)
                buildSearchResults()
              else ...[
                buildSection(context, "Players Spotlight", buildPlayersRow()),
                const SizedBox(height: 20),
                buildSection(context, "Upcoming Tournaments", buildTournamentsGrid()),
                const SizedBox(height: 20),
                buildSection(context, "Recommended Teams", buildTeamsRow()),
              ],
            ],
          ),
        ),
      ),

      // SparkNavHandle ثابت على اليسار
      const Positioned(
  left: 0,
  top: kToolbarHeight + 20,
  child: SparkNavHandle(),
),

    ],
  ),
),

          ],
        ),
      ),
    );
  }

 Widget buildSearchResults() {
  return Column(
    children: searchResults.map((result) {
      ImageProvider imageProvider;

      // تحقق من وجود الصورة، إذا لا استخدم صورة افتراضية
      if (result['image'] != null && result['image'].isNotEmpty) {
        imageProvider = NetworkImage(result['image']);
      } else {
        imageProvider = AssetImage(
          result['type'] == 'Player'
              ? 'assets/default_player.png' // صورة افتراضية للاعب
              : 'assets/default_team.png',  // صورة افتراضية للفريق
        );
      }

      return ListTile(
        leading: CircleAvatar(
          backgroundImage: imageProvider,
          backgroundColor: Colors.grey[800],
        ),
        title: Text(result['name'], style: const TextStyle(color: Colors.white)),
        subtitle: Text(result['type'], style: const TextStyle(color: Colors.white70)),
        onTap: () {
          if (result['type'] == 'Player') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewPlayerProfilePage(userId: result['id']),
              ),
            );
          } else if (result['type'] == 'Team') {
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

  Widget buildSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // لتوسيط العناوين
      children: [
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

  Widget buildPlayersRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (index) => const CircleAvatar(
                  radius: 45,
                  backgroundColor: Color(0xFF3A3A3A),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTournamentsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(89),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget buildTeamsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (index) => Column(
                  children: [
                    const CircleAvatar(
                      radius: 45,
                      backgroundColor: Color(0xFF3A3A3A),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 70,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

