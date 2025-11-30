import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '../../services/player/image_helper.dart';

class ViewTeamPage extends StatelessWidget {
  final String teamId;

  const ViewTeamPage({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Team').doc(teamId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BgScaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const BgScaffold(
            body: Center(
              child: Text('Team not found', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final logoImage = getProfileImage(data['logoUrl']);

        return BgScaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false, // FIX black arrow bug
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Team Details', style: TextStyle(color: Colors.white)),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // TEAM LOGO
                  Center(
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: const Color(0xFF3A3A3A),
                      backgroundImage: logoImage,
                      child: logoImage == null
                          ? const Icon(Icons.groups_rounded, size: 50, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TEAM NAME
                  Center(
                    child: Text(
                      data['name'] ?? 'Team Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // DESCRIPTION
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      data['description'] ?? "No description.",
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    "Team Members",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildTeamMembers(teamId),
                ],
              ),

              // SIDE NAV
              Positioned(
                left: 0,
                top: kToolbarHeight + 20,
                child: MiniSideNav(top: kToolbarHeight + 20, left: 0),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- TEAM MEMBERS ---------------------

  Widget _buildTeamMembers(String teamId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('Team')
          .doc(teamId)
          .collection('Members')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final memberDocs = snapshot.data!.docs;

        if (memberDocs.isEmpty) {
          return const Text('No members found', style: TextStyle(color: Colors.white70));
        }

        final roles = <String, String>{};
        final ids = <String>[];

        for (var doc in memberDocs) {
          final role = (doc.data() as Map)['role'] ?? 'Member';
          roles[doc.id] = role;
          ids.add(doc.id);
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('Player')
              .where(FieldPath.documentId, whereIn: ids)
              .get(),
          builder: (context, playerSnap) {
            if (!playerSnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final players = playerSnap.data!.docs;

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 20,
              children: players.map((playerDoc) {
                final p = playerDoc.data() as Map<String, dynamic>;
                final img = getProfileImage(p['ProfilePhoto']);

                return Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white12,
                      backgroundImage: img,
                      child: img == null
                          ? const Icon(Icons.person, color: Colors.white70, size: 30)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 90,
                      child: Text(
                        p['Name'] ?? "Player",
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9E2819).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9E2819)),
                      ),
                      child: Text(
                        roles[playerDoc.id] ?? "role",
                        style: const TextStyle(
                          color: Color(0xFF9E2819),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
