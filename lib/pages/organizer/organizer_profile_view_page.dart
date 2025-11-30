import 'dart:convert'; // for base64Decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewOrganizerProfilePage extends StatelessWidget {
  const ViewOrganizerProfilePage({
    super.key,
    required this.organizerId,
  });

  final String organizerId;

  static const double _contentWidth = 320;
  static const double _infoHeight = 110;
  static const double _tileSize = 140;

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('Organizer').doc(organizerId);
    final tournamentsQuery = FirebaseFirestore.instance
        .collection('Tournament')
        .where('organizerID', isEqualTo: organizerId)
        .limit(20);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
              // طبقة تعتيم خفيفة
              Container(color: Colors.black.withOpacity(0.25)),

              // المحتوى
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _contentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),

                          // الهيدر
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: docRef.snapshots(),
                            builder: (context, snap) {
                              final data = snap.data?.data() ?? {};
                              final name  = (data['Name'] ?? 'Username').toString().trim();
                              final info  = (data['Info'] ?? '').toString().trim();
                              final photoB64 = (data['ProfilePhotoBase64'] ?? '').toString().trim();
                              final photoUrl  = (data['ProfilePhoto'] ?? '').toString().trim();

                              final ImageProvider? avatar = _pickAvatar(photoB64: photoB64, photoUrl: photoUrl);

                              return Column(
                                children: [
                                  // أفاتار بدائرة وحلقة بيضاء
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircleAvatar(
                                      radius: 44,
                                      backgroundColor: Colors.white,
                                      backgroundImage: avatar,
                                      child: avatar == null
                                          ? const Icon(Icons.person, color: Colors.black38, size: 44)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Text(
                                    name.isEmpty ? 'Username' : name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'info',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Container(
                                    height: _infoHeight,
                                    width: _contentWidth,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      info.isEmpty ? ' ' : info,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          // البطولات
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: tournamentsQuery.snapshots(),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 24.0),
                                  child: CircularProgressIndicator(color: Colors.white),
                                );
                              }

                              final docs = snap.data?.docs ?? [];

                              if (docs.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Text(
                                    'No tournaments yet',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }

                              return Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 16,
                                runSpacing: 16,
                                children: docs.map((d) {
                                  final title = (d.data()['Title'] ?? d.data()['title'] ?? 'Untitled').toString();
                                  final cover = (d.data()['TourImg'] ?? d.data()['cover'] ?? '').toString();

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
                                            child: Image.network(cover, fit: BoxFit.cover),
                                          ),
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
            ],
          ),
        ),
      ),
    );
  }

  static ImageProvider? _pickAvatar({required String photoB64, required String photoUrl}) {
    if (photoB64.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoB64));
      } catch (_) {}
    }
    if (photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return null;
  }
}
