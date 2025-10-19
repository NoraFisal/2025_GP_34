import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/bg_scaffold.dart';
import '../ui/side_nav.dart';
import '../ui/theme.dart';

class ViewPlayerProfilePage extends StatelessWidget {
  final String userId;

  const ViewPlayerProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Player').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

       if (snapshot.connectionState == ConnectionState.waiting) {
  return const BgScaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

if (!snapshot.hasData || !snapshot.data!.exists) {
  return const BgScaffold(
    body: Center(child: Text('Player not found', style: TextStyle(color: Colors.white))),
  );
}


        final u = snapshot.data!.data() as Map<String, dynamic>;

        return BgScaffold(
          appBar: AppBar(
  backgroundColor: Colors.transparent, // يخلي البار شفاف
  elevation: 0, // يشيل الظل
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
        backgroundImage: (u['ProfilePhoto'] != null &&
                u['ProfilePhoto'].toString().isNotEmpty)
            ? NetworkImage(u['ProfilePhoto'])
            : null,
        child: (u['ProfilePhoto'] == null ||
                u['ProfilePhoto'].toString().isEmpty)
            ? const Icon(Icons.person, size: 48, color: Colors.white70)
            : null,
      ),
    ),
    const SizedBox(height: 12),
    Center(
      child: Text(
        u['Name'] ?? 'Player', // هنا اسم اللاعب يطلع من الداتا
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    const SizedBox(height: 16),
    _infoCard(
  age: u['Age']?.toString() ?? '—',
  city: u['City'] ?? '—',
  game: (u['Game'] != null && u['Game'].toString().isNotEmpty)
      ? u['Game'].toString()
      : '—',
),

    const SizedBox(height: 16),
    
    _section('Badges'),
    _section('League of Legends Performance stats'),
    _section('VALORANT Performance stats'),
    _section('My Team'),
  ],
),

              const Positioned(left: 0, top: 0, bottom: 0, child: SparkNavHandle()),
            ],
          ),
        );
      },
    );
  }

  static Widget _section(String title) => Card(
        color: AppColors.cardDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(title, style: TextStyle(color: Colors.white70)),
          ),
        ),
      );

  static Widget _infoCard({required String age, required String city, required String game}) {
    return Card(
      color: AppColors.cardDeep,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [_kv('Age', age), const SizedBox(width: 24), _kv('City', city)]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: _kv('Game', game)),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) => RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70),
          children: [
            TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: v),
          ],
        ),
      );
}
