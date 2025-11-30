import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '/ui/theme.dart';
import '../chat/team_chat_page.dart';

class TeamDetailsPage extends StatelessWidget {
  final String teamId;
  final String teamName;

  const TeamDetailsPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  Future<Map<String, dynamic>> _getTeamDetails() async {
    final teamDoc = await FirebaseFirestore.instance
        .collection('Team')
        .doc(teamId)
        .get();

    if (!teamDoc.exists) {
      throw Exception('Team not found');
    }

    final teamData = teamDoc.data()!;
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('Team')
        .doc(teamId)
        .collection('Members')
        .get();

    final members = <Map<String, dynamic>>[];
    for (final memberDoc in membersSnapshot.docs) {
      final memberData = memberDoc.data();
      final uid = memberDoc.id;
      
      // Get player info
      final playerDoc = await FirebaseFirestore.instance
          .collection('Player')
          .doc(uid)
          .get();

      if (playerDoc.exists) {
        final playerData = playerDoc.data()!;
        members.add({
          'uid': uid,
          'name': playerData['Name'] ?? 'Unknown',
          'photo': playerData['ProfilePhoto'],
          'role': memberData['role'] ?? 'Unknown',
          'response': memberData['response'] ?? 'none',
        });
      }
    }

    // Sort members by role order
    const roleOrder = ['top', 'jungle', 'middle', 'bottom', 'support'];
    members.sort((a, b) {
      final aIndex = roleOrder.indexOf(a['role'].toString().toLowerCase());
      final bIndex = roleOrder.indexOf(b['role'].toString().toLowerCase());
      return aIndex.compareTo(bIndex);
    });

    return {
      'name': teamData['name'] ?? 'Unnamed Team',
      'description': teamData['description'] ?? '',
      'logo': teamData['logoUrl'],
      'winRate': (teamData['winRate'] ?? 0.0).toDouble(),
      'status': teamData['status'] ?? 'pending',
      'createdBy': teamData['createdBy'],
      'members': members,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Team Details',
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
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getTeamDetails(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading team details',
                      style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  );
                }

                final data = snapshot.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTeamHeader(data, t),
                      const SizedBox(height: 24),
                      _buildMembersSection(data['members'], t),
                      const SizedBox(height: 24),
                      _buildActionButtons(context, data),
                    ],
                  ),
                );
              },
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

  Widget _buildTeamHeader(Map<String, dynamic> data, ThemeData t) {
    final logo = data['logo'];
    final winRate = data['winRate'];
    final description = data['description'];

    ImageProvider? logoImage;
    if (logo != null && logo.toString().isNotEmpty) {
      if (logo.toString().startsWith('http')) {
        logoImage = NetworkImage(logo);
      } else {
        try {
          logoImage = MemoryImage(base64Decode(logo));
        } catch (_) {}
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Team Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
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
                        size: 40,
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Team Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'],
                      style: t.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                            size: 14,
                            color: Colors.green.shade300,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green.shade300,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Win Rate Ring
              _buildWinRateRing(winRate),
            ],
          ),

          // Description
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                description,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWinRateRing(double winRate) {
    final p = winRate.clamp(0, 100);
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(60, 60),
            painter: _RingPainter(
              percent: p / 100.0,
              trackColor: Colors.white.withOpacity(.18),
              progressColor: const Color(0xFFB6382B),
              stroke: 6,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${p.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Win',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(List<Map<String, dynamic>> members, ThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Members',
          style: t.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: members.map((member) {
              return _buildMemberRow(member, t);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member, ThemeData t) {
    final photo = member['photo'];
    ImageProvider? photoImage;

    if (photo != null && photo.toString().isNotEmpty) {
      if (photo.toString().startsWith('http')) {
        photoImage = NetworkImage(photo);
      } else {
        try {
          photoImage = MemoryImage(base64Decode(photo));
        } catch (_) {}
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Player Photo
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withOpacity(.12),
            backgroundImage: photoImage,
            child: photoImage == null
                ? const Icon(Icons.person, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 12),

          // Player Name
          Expanded(
            child: Text(
              member['name'],
              style: t.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(.4)),
            ),
            child: Text(
              member['role'].toString().toUpperCase(),
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamChatPage(
                    teamId: teamId,
                    teamName: teamName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB6382B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color progressColor;
  final double stroke;

  _RingPainter({
    required this.percent,
    required this.trackColor,
    required this.progressColor,
    this.stroke = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r - stroke / 2);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final prog = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(rect, -1.5708, 6.28318, false, track);
    final sweep = 6.28318 * percent;
    canvas.drawArc(rect, -1.5708, sweep, false, prog);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}