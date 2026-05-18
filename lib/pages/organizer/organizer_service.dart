import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrganizerData {
  final String uid;
  final String name;
  final String info;
  final String profilePhoto; 

  OrganizerData({
    required this.uid,
    required this.name,
    required this.info,
    required this.profilePhoto,
  });

  static OrganizerData fromMap(String uid, Map<String, dynamic> m) {
    return OrganizerData(
      uid: uid,
      name: (m['Name'] ?? '').toString(),
      info: (m['Info'] ?? '').toString(),
      profilePhoto: (m['ProfilePhoto'] ?? '').toString(), 
    );
  }

  Map<String, dynamic> toMap() => {
        'Name': name,
        'Info': info,
        'ProfilePhoto': profilePhoto, 
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class OrganizerService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('Organizer');

  static String get myUid => _auth.currentUser!.uid;

  static Future<void> ensureMeDoc() async {
    final doc = _col.doc(myUid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'Name': 'Organizer',
        'Info': '',
        'ProfilePhoto': '', 
        'ownerUid': myUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Stream<OrganizerData?> watchMe() {
    return _col.doc(myUid).snapshots().map(
          (s) => s.exists ? OrganizerData.fromMap(s.id, s.data()!) : null,
        );
  }

  static Future<OrganizerData?> getMe() async {
    final s = await _col.doc(myUid).get();
    if (!s.exists) return null;
    return OrganizerData.fromMap(s.id, s.data()!);
  }

  static Stream<OrganizerData?> watchByUid(String uid) {
    return _col.doc(uid).snapshots().map(
          (s) => s.exists ? OrganizerData.fromMap(s.id, s.data()!) : null,
        );
  }

  static Future<void> updateMe({
    required String name,
    required String info,
    String? profilePhoto, 
  }) async {
    final update = {
      'Name': name,
      'Info': info,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profilePhoto != null) update['ProfilePhoto'] = profilePhoto;
    await _col.doc(myUid).set(update, SetOptions(merge: true));
  }
}
