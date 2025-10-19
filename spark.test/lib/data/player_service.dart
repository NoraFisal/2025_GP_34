import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerData {
  final String uid;
  final String username;
  final int age;
  final String city;
  final String gender;
  final List<String> games;
  final String? photoLocal;   // أصول قديمة (اختياري)
  final String photoBase64;   // ✅ صورتنا محفوظة كنص

  PlayerData({
    required this.uid,
    required this.username,
    required this.age,
    required this.city,
    required this.gender,
    required this.games,
    required this.photoLocal,
    required this.photoBase64,
  });

  static PlayerData fromMap(String uid, Map<String, dynamic> m) {
    return PlayerData(
      uid: uid,
      username: (m['Name'] ?? '') as String,
      age: (m['Age'] ?? 0) as int,
      city: (m['City'] ?? '') as String,
      gender: (m['Gender'] ?? '') as String,
      games: m['Game'] is Iterable ? List<String>.from(m['Game']) : const <String>[],
      photoLocal: m['ProfliePhoto'] as String?,
      photoBase64: (m['photoBase64'] ?? '') as String, // ✅
    );
  }

  Map<String, dynamic> toMap() => {
        'Name': username,
        'Age': age,
        'City': city,
        'Gender':gender,
        'Game': games,
        'ProfliePhoto': photoLocal,
        'photoBase64': photoBase64, // ✅
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
        'ProfliePhoto': null,
        'photoBase64': '', // ✅
        'ownerUid': myUid,
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
    String? photoLocal,
    String? photoBase64, // ✅
  }) async {
    final update = {
      'Nmae': username,
      'Age': age,
      'City': city,
      'Game': games,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoLocal != null) update['ProfliePhoto'] = photoLocal;
    if (photoBase64 != null) update['photoBase64'] = photoBase64; // ✅
    await _col.doc(myUid).set(update, SetOptions(merge: true));
  }
}
