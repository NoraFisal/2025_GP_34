import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerData {
  final String uid;
  final String username;
  final int age;
  final String city;
  final String gender;
  final List<String> games;
  final String profilePhoto;  // Base64

  PlayerData({
    required this.uid,
    required this.username,
    required this.age,
    required this.city,
    required this.gender,
    required this.games,
    required this.profilePhoto,
  });

  static PlayerData fromMap(String uid, Map<String, dynamic> m) {
    return PlayerData(
      uid: uid,
      username: (m['Name'] ?? '') as String,
      age: (m['Age'] ?? 0) as int,
      city: (m['City'] ?? '') as String,
      gender: (m['Gender'] ?? '') as String,
      games: m['Game'] is Iterable ? List<String>.from(m['Game']) : const <String>[],
      profilePhoto: (m['ProfilePhoto'] ?? '') as String, // Base64
    );
  }

  Map<String, dynamic> toMap() => {
        'Name': username,
        'Age': age,
        'City': city,
        'Gender': gender,
        'Game': games,
        'ProfilePhoto': profilePhoto,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class PlayerService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col => _db.collection('Player');

  static String get myUid => _auth.currentUser!.uid;

  static Future<void> ensureMeDoc() async {
    final doc = _col.doc(myUid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'Name': 'Player',
        'Age': 18,
        'City': '',
        'Game': <String>[],
        'ProfilePhoto': '', 
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Stream<PlayerData?> watchMe() {
    return _col.doc(myUid).snapshots().map(
          (s) => s.exists ? PlayerData.fromMap(s.id, s.data()!) : null,
        );
  }

  static Future<PlayerData?> getMe() async {
    final s = await _col.doc(myUid).get();
    if (!s.exists) return null;
    return PlayerData.fromMap(s.id, s.data()!);
  }

  static Stream<PlayerData?> watchByUid(String uid) {
    return _col.doc(uid).snapshots().map(
          (s) => s.exists ? PlayerData.fromMap(s.id, s.data()!) : null,
        );
  }

  static Future<void> updateMe({
    required String username,
    required int age,
    required String city,
    required List<String> games,
    String? profilePhoto, // Base64
  }) async {
    final update = {
      'Name': username,
      'Age': age,
      'City': city,
      'Game': games,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profilePhoto != null) update['ProfilePhoto'] = profilePhoto;
    await _col.doc(myUid).set(update, SetOptions(merge: true));
  }
  static Stream<List<Map<String, dynamic>>> watchMyAcceptedTeams(String userId) {
  final teamsRef = FirebaseFirestore.instance.collection('Team');

  return teamsRef
      .where('status', isEqualTo: 'Accepted')  // ✅ نفلتر هنا مباشرة
      .snapshots()
      .asyncMap((query) async {
    List<Map<String, dynamic>> myTeams = [];

    for (var doc in query.docs) {
      final data = doc.data();

      // نتحقق: هل اللاعب عضو في هذا الفريق؟
      final memberDoc = await teamsRef
          .doc(doc.id)
          .collection('Members')
          .doc(userId)
          .get();

      if (!memberDoc.exists) continue; // إذا مو عضو → تجاهل

      // جلب جميع الأعضاء
      final membersSnap = await teamsRef
          .doc(doc.id)
          .collection('Members')
          .get();

      myTeams.add({
        'teamId': doc.id,
        'teamName': data['name'] ?? '',
        'description': data['description'] ?? '',
        'winRate': data['winRate'] ?? 0,
        'members': membersSnap.docs.map((e) {
          return {
            'userId': e.id,
            'role': e.data()['role'] ?? '',
            'response': e.data()['response'] ?? 'none',
          };
        }).toList(),
      });
    }

    return myTeams;
  });
}
static Future<PlayerData?> getPlayerData(String uid) async {
  try {
    final s = await _col.doc(uid).get();
    if (!s.exists) return null;
    return PlayerData.fromMap(s.id, s.data()!);
  } catch (e) {
    print('Error getting player data: $e');
    return null;
  }
}
static Future<Map<String, dynamic>?> getPlayer(String uid) async {
  final doc = await _col.doc(uid).get();
  
  if (!doc.exists) return null;
  
  final data = doc.data()!;
  return {
    'uid': uid,
    'Name': data['Name'] ?? '',
    'ProfilePhoto': data['ProfilePhoto'] ?? '',
    'Age': data['Age'] ?? 0,
    'City': data['City'] ?? '',
    'Gender': data['Gender'] ?? '',
    'Game': data['Game'] ?? [],
  };
}

}
