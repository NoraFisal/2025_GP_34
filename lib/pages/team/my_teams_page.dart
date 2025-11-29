
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import 'team_details_page.dart'; 

class MyTeamsPage extends StatefulWidget {
  const MyTeamsPage({super.key});

  @override
  State<MyTeamsPage> createState() => _MyTeamsPageState();
}

class _MyTeamsPageState extends State<MyTeamsPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  /// Fetch all teams where current user is a member with Accepted status
  Stream<List<Map<String, dynamic>>> _getMyTeams() {
    if (currentUser == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('Team')
        .where('status', isEqualTo: 'Accepted')
        .snapshots()
        .asyncMap((snapshot) async {
      final teams = <Map<String, dynamic>>[];

      for (final teamDoc in snapshot.docs) {
        final teamId = teamDoc.id;
        final teamData = teamDoc.data();

        // Check if current user is a member with Accepted response
        final memberDoc = await FirebaseFirestore.instance
            .collection('Team')
            .doc(teamId)
            .collection('Members')
            .doc(currentUser!.uid)
            .get();

        if (memberDoc.exists) {
          final memberData = memberDoc.data();
          final response = memberData?['response'] ?? '';

          if (response == 'Accepted') {
            teams.add({
              'id': teamId,
              'name': teamData['name'] ?? 'Unnamed Team',
              'description': teamData['description'] ?? '',
              'logo': teamData['logoUrl'],
              'createdAt': teamData['createdAt'],
              'createdBy': teamData['createdBy'],
            });
          }
        }
      }

      // Sort by creation date (newest first)
      teams.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      return teams;
    });
  }

  void _navigateToTeamDetails(String teamId, String teamName) {  // ✅ غيّر الاسم
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDetailsPage(  // ✅ غيّر الصفحة
          teamId: teamId,
          teamName: teamName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'My Teams',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getMyTeams(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading teams',
                        style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    );
                  }

                  final teams = snapshot.data ?? [];

                  if (teams.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups_2_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No Teams Yet',
                            style: t.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You haven\'t joined any teams yet.\nCreate or join a team to get started!',
                            textAlign: TextAlign.center,
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: Colors.white60,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: teams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final team = teams[index];
                      return _buildTeamCard(team, t);
                    },
                  );
                },
              ),
            ),
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

  Widget _buildTeamCard(Map<String, dynamic> team, ThemeData t) {
    final logo = team['logo'];
    ImageProvider? logoImage;

    if (logo != null && logo.toString().isNotEmpty) {
      try {
        logoImage = MemoryImage(base64Decode(logo));
      } catch (_) {
        // If decode fails, ignore
      }
    }

    return InkWell(
      onTap: () => _navigateToTeamDetails(team['id'], team['name']),  // ✅ استخدم الدالة الجديدة
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            // Team Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
                image: logoImage != null
                    ? DecorationImage(
                        image: logoImage,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: logoImage == null
                  ? const Icon(
                      Icons.groups_2_outlined,
                      color: Colors.white54,
                      size: 28,
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Team Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team['name'],
                    style: t.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (team['description'] != null && 
                      team['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      team['description'],
                      style: t.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Arrow Icon
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}