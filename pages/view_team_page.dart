import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/bg_scaffold.dart';
import '../ui/side_nav.dart';
import '../ui/theme.dart';

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
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const BgScaffold(
            body: Center(child: Text('Team not found', style: TextStyle(color: Colors.white))),
          );
        }

        final t = snapshot.data!.data() as Map<String, dynamic>;

        return BgScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: (t['Logo'] != null && t['Logo'].toString().isNotEmpty)
                          ? NetworkImage(t['Logo'])
                          : null,
                      child: (t['Logo'] == null || t['Logo'].toString().isEmpty)
                          ? const Icon(Icons.groups_rounded, size: 48, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      t['Name'] ?? 'Team Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: AppColors.cardDeep,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        t['Description'] ?? 'No description available.',
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Team Members',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTeamMembers(teamId),
                ],
              ),
              const Positioned(left: 0, top: 0, bottom: 0, child: SparkNavHandle()),
            ],
          ),
        );
      },
    );
  }

 Widget _buildTeamMembers(String? teamId) {
  if (teamId == null) {
    return const Text('No members', style: TextStyle(color: Colors.white70));
  }

  return FutureBuilder<QuerySnapshot>(
    future: FirebaseFirestore.instance
        .collection('playerTeams')
        .where('teamID', isEqualTo: teamId)
        .get(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final playerTeamDocs = snapshot.data!.docs;
      if (playerTeamDocs.isEmpty) {
        return const Text('No members found', style: TextStyle(color: Colors.white70));
      }

      // استرجاع كل playerId
      final playerIds = playerTeamDocs.map((doc) => doc['playerID']).toList();

      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('Player')
            .where(FieldPath.documentId, whereIn: playerIds)
            .get(),
        builder: (context, playerSnapshot) {
          if (!playerSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final players = playerSnapshot.data!.docs;
          return Wrap(
            spacing: 20,
            runSpacing: 20,
            children: players.map((doc) {
              final p = doc.data() as Map<String, dynamic>;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white24,
                    backgroundImage: NetworkImage(
                      p['ProfilePhoto'] ?? 'https://picsum.photos/200',
                    ),
                    onBackgroundImageError: (exception, stackTrace) {
                      print('⚠️ خطأ تحميل الصورة: $exception');
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p['Name'] ?? 'Player',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
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
