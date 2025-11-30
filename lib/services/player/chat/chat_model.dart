
import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔹 نموذج الرسالة (محدّث)
class Message {
  final String id; // ✅ أضفنا id
  final String senderId;
  final String receiverId;
  final String contact ;
  final Timestamp timestamp;
  final String status;
  final String? type;
 
  final String? teamId; // ✅ معرف الفريق
 

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.contact ,
    required this.timestamp,
    required this.status,
    this.type,
  
    this.teamId,
    
  });

  Map<String, dynamic> toMap() {
    return {
      'SenderID': senderId,
      'ReceiverID': receiverId,
      'contact': contact ,
      'Timestamp': timestamp,
      'status': status,
      'type': type,
      
      'teamId': teamId,
      
    };
  }

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id, // ✅ نحصل على id من document
      senderId: data['SenderID'] ?? '',
      receiverId: data['ReceiverID'] ?? '',
      contact : data['contact'] ?? '',
      timestamp: data['Timestamp'] ?? Timestamp.now(),
      status: data['status'] ?? 'sent',
      type: data['type'],
      
      
      teamId: data['teamId'],
     
    );
  }
}

/// 🔹 نموذج المحادثة (PlayerChat)
class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final Timestamp lastTimestamp;

  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastTimestamp': lastTimestamp,
    };
  }

  factory Chat.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastTimestamp: data['lastTimestamp'] ?? Timestamp.now(),
    );
  }
}
