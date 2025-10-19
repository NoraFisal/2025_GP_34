// … imports الموجودة عندك …
import 'dart:convert';
import 'package:flutter/material.dart';
import 'ui/bg_scaffold.dart';
import 'ui/side_nav.dart';
import 'ui/theme.dart';
import 'data/player_service.dart';

class PlayerProfilePage extends StatelessWidget {
  const PlayerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
  Navigator.pushNamedAndRemoveUntil(context, '/homepage', (route) => false);
},

        ),
        title: const Text('Player Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Colors.white), onPressed: () {}),
          const SizedBox(width: 6),
          _glowRectButton('Edit', onTap: () => Navigator.pushNamed(context, '/playerEdit')),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<PlayerData?>(
            stream: PlayerService.watchMe(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final u = snapshot.data;
              if (u == null) {
                return const Center(child: Text('No profile found'));
              }
              final gamesText = u.games.join(', ');

              return Center(
                
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
                              backgroundImage: (u.photoBase64.isNotEmpty)
                                  ? MemoryImage(base64Decode(u.photoBase64))
                                  : null,
                              child: (u.photoBase64.isEmpty)
                                  ? const Icon(Icons.person, size: 42, color: Colors.white70)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              u.username,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      _infoPanel(age: '${u.age}', city: u.city, gender: u.gender, games: gamesText),

                      const SizedBox(height: 14),
                      const Text('Suggestions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 8),
                      _roundedTiles(3),

                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Badges', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          _glowRectButton('Add New Game', onTap: () {}),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          _Badge('assets/badges/badge_1.png'),
                          _Badge('assets/badges/badge_2.png'),
                          _Badge('assets/badges/badge_3.png'),
                          _Badge('assets/badges/badge_4.png'),
                        ],
                      ),

                      const SizedBox(height: 16),
                      _statsCard('League of Legends Performance stats'),
                      const SizedBox(height: 12),
                      _statsCard('VALORANT Performance stats'),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('My Team', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          Row(
                            children: [
                              _glowRectButton('Create Team', onTap: () {}),
                              const SizedBox(width: 8),
                              _roundIcon(Icons.chat_bubble_outline, onTap: () {}),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: AppColors.card,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Team Name', style: TextStyle(color: AppColors.textSecondary)),
                                    SizedBox(height: 8),
                                    _TeamAvatars(),
                                  ],
                                ),
                              ),
                              Icon(Icons.settings, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),

          const Positioned(
            left: 0,
            top: kToolbarHeight + 20,
            child: SparkNavHandle(),
          ),
        ],
      ),
    );
  }

  static Widget _glowRectButton(String text, {required VoidCallback onTap}) {
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF9E2819),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // باقي الميثودز عندك نفسها، بس تأكد الألوان نصوصها بيضاء:
  static Widget _roundedTiles(int count) => Row(
        children: List.generate(
          count,
          (i) => Container(
            margin: EdgeInsets.only(right: i == count - 1 ? 0 : 10),
            height: 56,
            width: 76,
            decoration: BoxDecoration(
              color: AppColors.pill,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );

  static Widget _infoPanel({required String age, required String city, required String gender, required String games}) {
    return Card(
      color: AppColors.cardDeep,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Age', age),
            const SizedBox(height: 6),
            _kv('City', city),
            const SizedBox(height: 6),
            _kv('Gender',gender),
            const SizedBox(height: 6),
            _kv('Games', games),
            
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) => RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          children: [
            TextSpan(text: '$k: ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
              const Text('Suggestions', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                child: const Center(child: Text('chart', style: TextStyle(color: AppColors.textSecondary))),
              ),
            ],
          ),
        ),
      );

  static Widget _roundIcon(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String path;
  const _Badge(this.path);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
      child: Image.asset(path, width: 32, height: 32, fit: BoxFit.contain),
    );
  }
}

class _TeamAvatars extends StatelessWidget {
  const _TeamAvatars();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        4,
        (i) => Container(
          margin: EdgeInsets.only(right: i == 3 ? 0 : 8),
          child: const CircleAvatar(radius: 16, backgroundColor: AppColors.pill),
        ),
      ),
    );
  }
  
}
