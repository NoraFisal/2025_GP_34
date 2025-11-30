import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'chat_model.dart';

class MessageService {
  static final _db = FirebaseFirestore.instance;

  /// 💬 توليد معرف محادثة ثابت بين المستخدمين
  static String _generateChatId(String a, String b) {
    return (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';
  }

  /// 🔹 جلب قائمة المحادثات الخاصة بالمستخدم
  static Stream<List<Chat>> getUserChats(String uid) {
    debugPrint('📡 Fetching user chats for UID: $uid');

    return _db
        .collection('PlayerChat')
        .where('participants', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('✅ Loaded ${snapshot.docs.length} chat(s) from Firestore');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Chat(
          id: doc.id,
          participants: List<String>.from(data['participants'] ?? []),
          lastMessage: data['lastMessage'] ?? '',
          lastTimestamp: data['lastTimestamp'] ?? Timestamp.now(),
        );
      }).toList();
    });
  }

  /// 🔹 جلب الرسائل عبر chatId مباشرة
  static Stream<List<Message>> getMessagesByChatId(String chatId) {
    debugPrint('📡 Listening to messages for chatId: $chatId');
    return _db
        .collection('PlayerChat')
        .doc(chatId)
        .collection('PlayerMessage')
        .orderBy('Timestamp', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromDoc(doc)).toList());
  }

  /// 🔹 إرسال رسالة عادية
  static Future<void> sendMessageByChatId(
    String chatId,
    String senderId,
    String receiverId,
    String contact,
  ) async {
    final chatRef = _db.collection('PlayerChat').doc(chatId);

    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [senderId, receiverId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': contact,
        'lastTimestamp': Timestamp.now(),
      });
    }

    final msgData = {
      'SenderID': senderId,
      'ReceiverID': receiverId,
      'contact': contact,
      'Timestamp': Timestamp.now(),
      'status': 'sent',
    };

    await chatRef.collection('PlayerMessage').add(msgData);
    await chatRef.update({
      'lastMessage': contact,
      'lastTimestamp': Timestamp.now(),
    });
  }

  /// ✅ حساب عدد الرسائل غير المقروءة في PlayerChat
  static Future<int> getUnreadPlayerMessagesCount(
      String chatId, String userId) async {
    final snapshot = await _db
        .collection('PlayerChat')
        .doc(chatId)
        .collection('PlayerMessage')
        .where('ReceiverID', isEqualTo: userId)
        .where('status', isEqualTo: 'sent')
        .get();

    return snapshot.docs.length;
  }
}