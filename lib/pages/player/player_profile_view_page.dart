import 'dart:convert'; // for base64 avatar fallback
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '/ui/theme.dart';

class ViewPlayerProfilePage extends StatelessWidget {
  final String userId;

  const ViewPlayerProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Player').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BgScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const BgScaffold(
            body: Center(
              child: Text('Player not found', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        final u = snapshot.data!.data() as Map<String, dynamic>;

        
        String rawPhoto = (u['ProfilePhoto'] ?? '').toString().trim();
        if (rawPhoto.length >= 2 && rawPhoto.startsWith('"') && rawPhoto.endsWith('"')) {
          rawPhoto = rawPhoto.substring(1, rawPhoto.length - 1).trim();
        }
        ImageProvider<Object>? avatarProvider;
        if (rawPhoto.isNotEmpty) {
          if (rawPhoto.startsWith('http')) {
            avatarProvider = NetworkImage(rawPhoto);
          } else {
            try {
              avatarProvider = MemoryImage(base64Decode(rawPhoto));
            } catch (_) {
              avatarProvider = null;
            }
          }
        }

        final ageRaw = u['Age'];
        final String ageStr = (ageRaw == null) ? '' : ageRaw.toString().trim();
        final bool showAge = ageStr.isNotEmpty && ageStr != '0';

        final cityStr   = (u['City'] ?? '').toString().trim();
        final genderStr = (u['Gender'] ?? '').toString().trim();

        String gamesStr = '';
        final gameRaw = u['Game'];
        if (gameRaw is List) {
          final list = gameRaw
              .map((e) => e?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          if (list.isNotEmpty) gamesStr = list.join(', ');
        } else {
          final s = (gameRaw ?? '').toString().trim();
          if (s.isNotEmpty && s != '[]') {
           
            gamesStr = s.replaceAll(RegExp(r'^\[\s*|\s*\]$'), '').trim();
            if (gamesStr == ',') gamesStr = '';
          }
        }

        final infoRows = <Widget>[
          if (showAge) _kv('Age', ageStr),
          if (cityStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            _kv('City', cityStr),
          ],
          if (genderStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            _kv('Gender', genderStr),
          ],
          if (gamesStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            _kv('Games', gamesStr),
          ],
        ];

        return BgScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Player Profile',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                onPressed: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;
                  
                  // إنشاء chatId من userId الحالي والآخر
                  final ids = [currentUser.uid, userId];
                  ids.sort();
                  final chatId = ids.join('_');
                  
                  try {
                    // التأكد من وجود document الشات أو إنشاءه
                    final chatDoc = FirebaseFirestore.instance
                        .collection('PlayerChat')
                        .doc(chatId);
                    
                    final chatSnapshot = await chatDoc.get();
                    
                    if (!chatSnapshot.exists) {
                      // إنشاء document جديد للشات
                      await chatDoc.set({
                        'participants': [currentUser.uid, userId],
                        'createdAt': FieldValue.serverTimestamp(),
                        'lastMessage': '',
                        'lastMessageTime': FieldValue.serverTimestamp(),
                      });
                    }
                    
                    // الانتقال لصفحة الشات
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'chatId': chatId,
                        'currentUserId': currentUser.uid,
                        'otherUserId': userId,
                        'otherUserName': u['Name'] ?? 'Player',
                        'otherUserImage': rawPhoto,
                      },
                    );
                  } catch (e) {
                    print('Error opening chat: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error opening chat. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: AppColors.card,
                              backgroundImage: avatarProvider,
                              child: (avatarProvider == null)
                                  ? const Icon(Icons.person, size: 42, color: Colors.white70)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              (u['Name'] ?? 'Player').toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Info Panel (only shows non-empty fields)
                      Card(
                        color: AppColors.cardDeep,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: infoRows.isEmpty
                                ? [const Text('No profile details yet', style: TextStyle(color: Colors.white70))]
                                : infoRows,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                     
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Badges',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double availableWidth = constraints.maxWidth;
                          final int badgeCount = 4;
                          final double spacing = 10;
                          final double totalSpacing = spacing * (badgeCount - 1);
                          final double badgeWidth = (availableWidth - totalSpacing) / badgeCount;
                          
                          return Row(
                            children: List.generate(
                              badgeCount,
                              (i) => Container(
                                margin: EdgeInsets.only(right: i == badgeCount - 1 ? 0 : spacing),
                                height: 56,
                                width: badgeWidth,
                                decoration: BoxDecoration(
                                  color: AppColors.pill,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      _statsCard('League of Legends Performance stats'),
                      const SizedBox(height: 12),
                      _statsCard('VALORANT Performance stats'),

                      const SizedBox(height: 24),
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
        );
      },
    );
  }

  static Widget _kv(String k, String v) => RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: v, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );

  static Widget _statsCard(String title) => Card(
        color: AppColors.cardDeep,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 10),
              const SizedBox(height: 10),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [Color(0xFF1C2430), Color(0xFF1B2028)],
                  ),
                ),
                child: const Center(
                  child: Text('chart', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      );
}