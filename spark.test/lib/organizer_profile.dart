import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'organizer_management.dart';
import 'ui/organizer_side_nav.dart';

class OrganizerProfilePage extends StatelessWidget {
  const OrganizerProfilePage({super.key});

  static const double _contentWidth = 320;
  static const double _infoHeight = 110;
  static const double _tileSize = 140;
  static const Color _chipRed = Color(0xFF9E2819);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Future.microtask(() {
        if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final uid = user.uid;
    final docRef = FirebaseFirestore.instance.collection('Organizer').doc(uid);
    final tournamentsQuery = FirebaseFirestore.instance
        .collection('Tournament')
        .where('organizerID', isEqualTo: uid)
        .limit(20);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Organizer Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Stack(
          children: [
            Container(color: Colors.black.withOpacity(0.25)),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 6),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: docRef.snapshots(),
                          builder: (context, snap) {
                            final data = snap.data?.data() ?? {};
                            final name = (data['Name'] ?? 'Username').toString();
                            final photo = (data['ProfilePhoto'] ?? '').toString();
                            final photoB64 = (data['ProfilePhotoBase64'] ?? '').toString();
                            final info = (data['Info'] ?? '').toString();

                            ImageProvider? avatar;
                            if (photoB64.isNotEmpty) {
                              avatar = MemoryImage(base64Decode(photoB64));
                            } else if (photo.isNotEmpty) {
                              avatar = NetworkImage(photo);
                            }

                            return Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.white, shape: BoxShape.circle),
                                  child: CircleAvatar(
                                    radius: 44,
                                    backgroundColor: Colors.white,
                                    backgroundImage: avatar,
                                    child: (avatar == null)
                                        ? const Icon(Icons.person,
                                            color: Colors.black38, size: 44)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Edit
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _glowRectButton('Edit', () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const OrganizerManagementPage()),
                                      );
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('info',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 16)),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: _infoHeight,
                                  width: _contentWidth,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    info.isEmpty ? ' ' : info,
                                    style: const TextStyle(
                                        color: Colors.white, height: 1.35),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _glowRectButton('Add New', () {
                                      // اربطيه بالروت المناسب عندك:
                                      // Navigator.pushNamed(context, '/createTournament');
                                    }),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: tournamentsQuery.snapshots(),
                          builder: (context, snap) {
                            final docs = snap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('No tournaments yet',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.85))),
                              );
                            }
                            return Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 16,
                              runSpacing: 16,
                              children: docs.map((d) {
                                final dd = d.data();
                                final title =
                                    (dd['Title'] ?? dd['title'] ?? 'Untitled')
                                        .toString();
                                final cover =
                                    (dd['TourImg'] ?? dd['cover'] ?? '').toString();
                                return Container(
                                  width: _tileSize,
                                  height: _tileSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      if (cover.isNotEmpty)
                                        Positioned.fill(
                                            child: Image.network(cover,
                                                fit: BoxFit.cover)),
                                      Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.all(10.0),
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              top: kToolbarHeight + 20,
              child: OrganizerNavHandle(),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _glowRectButton(String label, VoidCallback onTap) {
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
      child: Material(
        color: _chipRed,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
