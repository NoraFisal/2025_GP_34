// lib/pages/team/my_teams_page.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'team_details_page.dart';

class MyTeamsPage extends StatefulWidget {
  const MyTeamsPage({super.key});

  @override
  State<MyTeamsPage> createState() => _MyTeamsPageState();
}

class _MyTeamsPageState extends State<MyTeamsPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

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

        final memberDoc = await FirebaseFirestore.instance
            .collection('Team')
            .doc(teamId)
            .collection('Members')
            .doc(currentUser!.uid)
            .get();

        if (!memberDoc.exists) continue;

        final response = memberDoc.data()?['response'];
        if (response != 'Accepted') continue;

        teams.add({
          'id': teamId,
          'name': teamData['name'] ?? 'Team',
          'logo': teamData['logoUrl'],
          'createdAt': teamData['createdAt'],
        });
      }

      teams.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      return teams;
    });
  }

  ImageProvider<Object>? _teamLogoProvider(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    if (s.startsWith('http')) {
      return NetworkImage(s);
    }

    try {
      final cleaned = s.contains(',') ? s.split(',').last : s;
      return MemoryImage(base64Decode(cleaned));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,

        title: const Text(
          'My Teams',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _accent,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getMyTeams(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _accent),
              );
            }

            final teams = snap.data!;
            if (teams.isEmpty) {
              return const Center(
                child: Text(
                  'No Teams Yet',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _teamCard(teams[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _teamCard(Map<String, dynamic> team) {
    final img = _teamLogoProvider(team['logo']);
    final name = team['name'].toString();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailsPage(
              teamId: team['id'],
              teamName: name,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
                image: img != null
                    ? DecorationImage(image: img, fit: BoxFit.cover)
                    : null,
              ),
              child: img == null
                  ? const Icon(Icons.groups_2_outlined, color: _muted)
                  : null,
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}