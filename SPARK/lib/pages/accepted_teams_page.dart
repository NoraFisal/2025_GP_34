import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'view_team_page.dart';
import '/ui/components/mini_side_nav.dart';
import '../../services/player/image_helper.dart';

class AcceptedTeamsPage extends StatelessWidget {
  const AcceptedTeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Explore Teams",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        // ✅ same background style as HomePage
        decoration: const BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection("Team")
                    .where("status", isEqualTo: "Accepted")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  // manual sorting by createdAt (desc)
                  docs.sort((a, b) {
                    final aT = a['createdAt'] as Timestamp?;
                    final bT = b['createdAt'] as Timestamp?;
                    if (aT == null || bT == null) return 0;
                    return bT.compareTo(aT);
                  });

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No teams found",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
                    itemCount: docs.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                    ),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final teamId = docs[i].id;

                      // ✅ support multiple possible logo fields
                      final rawLogo = (data['logoUrl'] ??
                              data['Logo'] ??
                              data['logo'] ??
                              '') as String;
                      final img = getProfileImage(rawLogo);

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewTeamPage(teamId: teamId),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFF3A3A3A),
                                backgroundImage: img,
                                child: img == null
                                    ? const Icon(
                                        Icons.groups_rounded,
                                        size: 40,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                data['name'] ?? 'Team',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data['description'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9E2819)
                                      .withOpacity(0.2),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(18),
                                    bottomRight: Radius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  "View Team →",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // SIDE NAV
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
    );
  }
}
