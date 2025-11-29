import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamService {

  static Stream<List<Map<String, dynamic>>> getUserTeams() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    final db = FirebaseFirestore.instance;

    return db.collection('Team').snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> userTeams = [];

      for (var teamDoc in snapshot.docs) {
        final teamId = teamDoc.id;
        final teamData = teamDoc.data();

      
        final memberSnap =
            await teamDoc.reference.collection('Members').doc(uid).get();

        if (!memberSnap.exists) continue;

 
        final name = teamData['name'] ?? 'Unnamed Team';
        final desc = teamData['description'] ?? '';
        final status = teamData['status'] ?? 'pending';
        final logo = teamData['logoUrl'] ?? '';
        final createdBy = teamData['createdBy'] ?? '';

   
        final chatSnap = await db.collection('TeamChat').doc(teamId).get();
        final chatData = chatSnap.exists ? chatSnap.data() ?? {} : {};

        userTeams.add({
          'teamId': teamId,
          'teamName': name,
          'logoUrl': logo,
          'description': desc,
          'status': status,
          'createdBy': createdBy,
          'chatStatus': chatData['status'] ?? 'pending',
          'lastMessage': chatData['lastMessage'] ?? '',
          'lastTime': chatData['lastTime'],
        });
      }

      return userTeams;
    });
  }


  static Future<void> sendTeamInvitations(String teamId) async {
    final db = FirebaseFirestore.instance;
    final teamDoc = await db.collection('Team').doc(teamId).get();

    if (!teamDoc.exists) return;

    final teamData = teamDoc.data()!;
    final teamName = teamData['name'];
    final createdBy = teamData['createdBy'];

    final membersSnap =
        await db.collection('Team').doc(teamId).collection('Members').get();


    final teamChatRef = db.collection('TeamChat').doc(teamId);
    final teamChatSnap = await teamChatRef.get();

    if (!teamChatSnap.exists) {
      await teamChatRef.set({
        'teamId': teamId,
        'lastMessage': '🎮 Team invitation has been sent!',
        'lastTime': Timestamp.now(),
        'status': 'pending',
      });
    }

    await teamChatRef.collection('TeamMessage').add({
      'senderId': createdBy,
      'contact':
          '🎮 The team "$teamName" has been created! Please accept or reject the invitation to join.',
      'timestamp': Timestamp.now(),
      'readBy': [createdBy],
      'type': 'invitation',
    });
  }


  static Future<int> getUnreadTeamMessagesCount(
      String teamId, String userId) async {
    final db = FirebaseFirestore.instance;

    final allMessagesSnap = await db
        .collection('TeamChat')
        .doc(teamId)
        .collection('TeamMessage')
        .get();

    int unread = 0;
    for (var doc in allMessagesSnap.docs) {
      final data = doc.data();
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (!readBy.contains(userId)) unread++;
    }

    return unread;
  }
}
