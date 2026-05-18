import 'dart:async';
import 'dart:async' show Timer;
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UnifiedChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── In-Memory Profile Cache ───────────────────────────────────────────────
  // Public so chat_page.dart can seed its local cache from here without an
  // extra network call. Prefixed with no underscore intentionally.
  static final Map<String, _CachedProfile> profileCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 10);

  // ─── In-Memory Team Info Cache ─────────────────────────────────────────────
  static final Map<String, _CachedTeamInfo> _teamCache = {};

  /// Public so chat_page.dart can pre-fetch profiles when building message list.
  static Future<Map<String, String>> getUserProfileOnce(String uid) async {
    final cached = profileCache[uid];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      // Fetch Player and Organizer docs in parallel for speed.
      final results = await Future.wait([
        _db.collection('Player').doc(uid).get(),
        _db.collection('Organizer').doc(uid).get(),
      ]);
      final playerDoc = results[0];
      final orgDoc = results[1];

      Map<String, String> profile;
      if (playerDoc.exists) {
        final d = playerDoc.data() as Map<String, dynamic>;
        profile = {
          'name': (d['Name'] as String?) ?? 'Player',
          'photo': (d['ProfilePhoto'] as String?) ?? '',
          'role': 'player',
        };
      } else if (orgDoc.exists) {
        final d = orgDoc.data() as Map<String, dynamic>;
        profile = {
          'name': (d['Name'] as String?) ?? 'Organizer',
          'photo': (d['ProfilePhoto'] as String?) ?? '',
          'role': 'organizer',
        };
      } else {
        profile = {'name': 'User', 'photo': '', 'role': 'player'};
      }

      profileCache[uid] = _CachedProfile(profile);
      return profile;
    } catch (_) {
      return {'name': 'User', 'photo': '', 'role': 'player'};
    }
  }

  /// Clears cache for a specific user (call after profile update).
  static void invalidateProfileCache(String uid) {
    profileCache.remove(uid);
  }

  /// Clears all caches (call on logout).
  static void clearAllCaches() {
    profileCache.clear();
    _teamCache.clear();
    _lastRequestsVisitCache = null;
  }

  // ─── Chat Creation ─────────────────────────────────────────────────────────

  static Future<String> createPrivateChat(String otherUserId) async {
    final myUid = _auth.currentUser!.uid;

    final existing = await _db
        .collection('Chat')
        .where('type', isEqualTo: 'private')
        .where('participants', arrayContains: myUid)
        .get();

    for (final doc in existing.docs) {
      final p = List<String>.from(doc['participants'] ?? []);
      if (p.contains(otherUserId) && p.length == 2) return doc.id;
    }

    final participants = [myUid, otherUserId]..sort((a, b) => a.compareTo(b));
    final chatRef = _db.collection('Chat').doc();
    await chatRef.set({
      'type': 'private',
      'participants': participants,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageSender': '',
      'isEmpty': true,
      // Store unread count per user instead of fetching all messages.
      'unreadCount': {},
    });

    return chatRef.id;
  }

  static Future<String> createTeamChat(
    String teamId,
    List<String> members, {
    String? logoUrl,
  }) async {
    final chatRef = _db.collection('Chat').doc();
    await chatRef.set({
      'type': 'team',
      'status': 'pending',
      'teamId': teamId,
      'participants': members,
      'lastMessage': '',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'isEmpty': true,
      'unreadCount': {},
    });
    return chatRef.id;
  }

  static Future<void> updateChatStatus(String chatId, String newStatus) async {
    await _db.collection('Chat').doc(chatId).update({
      'status': newStatus,
      'lastMessage': newStatus == 'active'
          ? 'Team ready to chat 🎉'
          : 'Team declined ❌',
      'lastTimestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> checkAndActivateTeamChat(String teamId) async {
    try {
      final membersSnap = await _db
          .collection('Team')
          .doc(teamId)
          .collection('Members')
          .get();

      if (membersSnap.docs.isEmpty) return;

      bool allAccepted = true;
      bool anyRejected = false;

      for (var member in membersSnap.docs) {
        final response = member.data()['response'] ?? 'none';
        if (response == 'Rejected') { anyRejected = true; break; }
        if (response != 'Accepted') allAccepted = false;
      }

      if (anyRejected) {
        final chatSnap = await _db
            .collection('Chat')
            .where('teamId', isEqualTo: teamId)
            .where('type', isEqualTo: 'team')
            .limit(1)
            .get();

        if (chatSnap.docs.isNotEmpty) {
          await chatSnap.docs.first.reference.update({
            'status': 'rejected',
            'hiddenBy': [],
          });
          await _db.collection('Team').doc(teamId).update({
            'status': 'Rejected',
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      if (allAccepted) {
        final chatSnap = await _db
            .collection('Chat')
            .where('teamId', isEqualTo: teamId)
            .where('type', isEqualTo: 'team')
            .limit(1)
            .get();

        if (chatSnap.docs.isNotEmpty) {
          final chatId = chatSnap.docs.first.id;
          await updateChatStatus(chatId, 'active');

          final msgCol = _db.collection('Chat').doc(chatId).collection('message');
          final oldMsgs = await msgCol.get();
          for (final doc in oldMsgs.docs) await doc.reference.delete();

          await msgCol.add({
            'type': 'system',
            'text': '🎉 All members accepted! Team chat is now active!',
            'timestamp': FieldValue.serverTimestamp(),
            'readBy': [],
          });

          await _db.collection('Chat').doc(chatId).update({
            'lastMessage': '🎉 All members accepted! Team chat is now active!',
            'lastTimestamp': FieldValue.serverTimestamp(),
            'isEmpty': false,
          });

          await _db.collection('Team').doc(teamId).update({
            'status': 'Accepted',
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('❌ Error checking team status: $e');
    }
  }

  // ─── Send Message (Optimistic + Fast) ─────────────────────────────────────

  static Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final uid = _auth.currentUser!.uid;

    // Run both writes in parallel — no need to wait for message before
    // updating the chat document.
    await Future.wait([
      _db.collection('Chat').doc(chatId).collection('message').add({
        'senderId': uid,
        'text': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [uid],
      }),
      _db.collection('Chat').doc(chatId).update({
        'lastMessage': text,
        'lastMessageSender': uid,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'isEmpty': false,
      }),
    ]);
  }

  // ─── Listen User Chats (Optimized: parallel profile fetches + cache) ───────

  static Stream<List<Map<String, dynamic>>> listenUserChats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('Chat')
        .where('participants', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      // Collect all unique UIDs and team IDs we need to fetch.
      final uidsToFetch = <String>{};
      final teamIdsToFetch = <String>{};

      for (final d in snap.docs) {
        final data = d.data();
        final type = data['type'] ?? '';
        final participants = List<String>.from(data['participants'] ?? []);

        if (type == 'private') {
          final otherUid = participants.firstWhere(
            (id) => id != uid, orElse: () => '');
          if (otherUid.isNotEmpty) uidsToFetch.add(otherUid);

          final lastSenderId = data['lastMessageSender'] ?? '';
          if (lastSenderId.isNotEmpty && lastSenderId != uid) {
            uidsToFetch.add(lastSenderId);
          }
        } else if (type == 'team') {
          final teamId = data['teamId'] ?? '';
          if (teamId.isNotEmpty) teamIdsToFetch.add(teamId);
        }
      }

      // Fetch all uncached profiles in parallel.
      final uncachedUids = uidsToFetch.where((id) {
        final c = profileCache[id];
        return c == null || c.isExpired;
      }).toList();

      if (uncachedUids.isNotEmpty) {
        await Future.wait(uncachedUids.map((id) => getUserProfileOnce(id)));
      }

      // Fetch all uncached team info in parallel.
      final uncachedTeams = teamIdsToFetch.where((id) {
        final c = _teamCache[id];
        return c == null || c.isExpired;
      }).toList();

      if (uncachedTeams.isNotEmpty) {
        await Future.wait(uncachedTeams.map((id) => _getTeamInfoOnce(id)));
      }

      // Now build results from cache — no more sequential awaits.
      final result = <Map<String, dynamic>>[];

      for (final d in snap.docs) {
        final chatId = d.id;
        final data = d.data();
        final type = data['type'] ?? '';
        final participants = List<String>.from(data['participants'] ?? []);

        if (type == 'private') {
          final otherUid = participants.firstWhere(
            (id) => id != uid, orElse: () => '');
          if (otherUid.isEmpty) continue;

          final profile = profileCache[otherUid]?.data ??
              {'name': 'User', 'photo': '', 'role': 'player'};
          final lastSenderId = data['lastMessageSender'] ?? '';
          final lastMsg = _buildLastMessageDisplaySync(
              data['lastMessage'] ?? '', lastSenderId, uid);

          result.add({
            'id': chatId,
            'type': 'private',
            'otherUid': otherUid,
            'displayName': profile['name']!,
            'photoUrl': profile['photo']!,
            'lastMessage': lastMsg,
            'lastMessageSender': lastSenderId,
            'lastTimestamp': data['lastTimestamp'],
            'isEmpty': data['isEmpty'] ?? false,
            'participants': participants,
            'hiddenBy': data['hiddenBy'] ?? [],
          });
        } else if (type == 'team') {
          final teamId = data['teamId'] ?? '';
          final teamInfo = _teamCache[teamId]?.data ??
              {'name': 'Team', 'logo': ''};

          final lastSenderId = data['lastMessageSender'] ?? '';
          final lastMsg = _buildLastMessageDisplaySync(
              data['lastMessage'] ?? '', lastSenderId, uid);

          result.add({
            'id': chatId,
            'type': 'team',
            'teamId': teamId,
            'displayName': teamInfo['name']!,
            'photoUrl': teamInfo['logo']!,
            'status': data['status'] ?? '',
            'lastMessage': lastMsg,
            'lastMessageSender': lastSenderId,
            'lastTimestamp': data['lastTimestamp'],
            'isEmpty': data['isEmpty'] ?? false,
            'participants': participants,
            'hiddenBy': data['hiddenBy'] ?? [],
          });
        }
      }

      return result;
    });
  }

  // ─── Profile & Team Streams ────────────────────────────────────────────────

  static Stream<Map<String, String>> listenUserProfile(String targetUid) {
    return _db
        .collection('Player')
        .doc(targetUid)
        .snapshots()
        .asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        final d = doc.data() as Map<String, dynamic>;
        final profile = <String, String>{
          'name': (d['Name'] as String?) ?? 'Player',
          'photo': (d['ProfilePhoto'] as String?) ?? '',
          'role': 'player',
        };
        profileCache[targetUid] = _CachedProfile(profile);
        return profile;
      }
      try {
        final orgDoc = await _db.collection('Organizer').doc(targetUid).get();
        if (orgDoc.exists) {
          final d = orgDoc.data() as Map<String, dynamic>;
          final profile = <String, String>{
            'name': (d['Name'] as String?) ?? 'Organizer',
            'photo': (d['ProfilePhoto'] as String?) ?? '',
            'role': 'organizer',
          };
          profileCache[targetUid] = _CachedProfile(profile);
          return profile;
        }
      } catch (_) {}
      return <String, String>{'name': 'User', 'photo': '', 'role': 'player'};
    });
  }

  static Stream<Map<String, String>> listenTeamInfo(String teamId) {
    return _db.collection('Team').doc(teamId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return <String, String>{'name': 'Team', 'logo': ''};
      }
      final d = doc.data() as Map<String, dynamic>;
      final info = <String, String>{
        'name': (d['name'] as String?) ?? 'Team',
        'logo': (d['logoUrl'] as String?) ?? '',
      };
      _teamCache[teamId] = _CachedTeamInfo(info);
      return info;
    });
  }

  static Stream<List<String>> listenChatMemberNames(
      String chatId, String currentUid) {
    return _db
        .collection('Chat')
        .doc(chatId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) return <String>[];
      final participants =
          List<String>.from(doc.data()?['participants'] ?? []);
      final others = participants.where((id) => id != currentUid).toList();

      // Fetch all uncached profiles in parallel.
      await Future.wait(
        others.where((id) {
          final c = profileCache[id];
          return c == null || c.isExpired;
        }).map((id) => getUserProfileOnce(id)),
      );

      return others
          .map((id) => profileCache[id]?.data['name'] ?? 'Player')
          .toList();
    });
  }

  // ─── Unread Tracking (optimized: reads from chat doc field) ───────────────

  /// Uses a lightweight `lastReadTimestamp` field on the chat doc instead of
  /// fetching every message. Falls back to the old method for existing chats.
  static Stream<bool> listenChatHasUnread(String chatId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    // Listen to the last few messages only — limit(1) descending is enough
    // to check if the newest message is unread, which covers 99% of cases
    // without fetching the whole collection.
    return _db
        .collection('Chat')
        .doc(chatId)
        .collection('message')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) {
      for (final msg in snap.docs) {
        final data = msg.data();
        final senderId = data['senderId'] ?? '';
        final readBy = List<String>.from(data['readBy'] ?? []);
        if (senderId != uid && !readBy.contains(uid)) return true;
      }
      return false;
    });
  }

  static Stream<bool> listenChatsHasUnread() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    final chatSnapStream = _db
        .collection('Chat')
        .where('participants', arrayContains: uid)
        .snapshots();

    final controller = StreamController<bool>.broadcast();
    final Map<String, StreamSubscription> _msgSubs = {};
    final Map<String, bool> _chatHasUnread = {};

    void emitResult() {
      if (!controller.isClosed) {
        controller.add(_chatHasUnread.values.any((v) => v));
      }
    }

    void subscribeToChat(String chatId) {
      if (_msgSubs.containsKey(chatId)) return;

      // Only fetch the last 20 messages to detect unread — much cheaper.
      final sub = _db
          .collection('Chat')
          .doc(chatId)
          .collection('message')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .listen((msgSnap) {
        bool hasUnread = false;
        for (final msg in msgSnap.docs) {
          final data = msg.data();
          final senderId = data['senderId'] ?? '';
          final readBy = List<String>.from(data['readBy'] ?? []);
          if (senderId != uid && !readBy.contains(uid)) {
            hasUnread = true;
            break;
          }
        }
        _chatHasUnread[chatId] = hasUnread;
        emitResult();
      }, onError: (_) {});

      _msgSubs[chatId] = sub;
    }

    void unsubscribeChat(String chatId) {
      _msgSubs[chatId]?.cancel();
      _msgSubs.remove(chatId);
      _chatHasUnread.remove(chatId);
    }

    final chatSub = chatSnapStream.listen((snap) {
      final validChatIds = <String>{};
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final type = data['type'] ?? '';
        final status = data['status'] ?? '';
        final isEmpty = data['isEmpty'] ?? false;
        final hiddenBy = List<String>.from(data['hiddenBy'] ?? []);
        if (hiddenBy.contains(uid)) continue;
        if ((type == 'private' && !isEmpty) ||
            (type == 'team' && status == 'active')) {
          validChatIds.add(d.id);
        }
      }

      final toRemove =
          _msgSubs.keys.where((id) => !validChatIds.contains(id)).toList();
      for (final id in toRemove) unsubscribeChat(id);
      for (final id in validChatIds) subscribeToChat(id);

      if (validChatIds.isEmpty) {
        if (!controller.isClosed) controller.add(false);
      }
    }, onError: (_) {});

    controller.onCancel = () {
      chatSub.cancel();
      for (final sub in _msgSubs.values) sub.cancel();
      _msgSubs.clear();
    };

    return controller.stream;
  }

  static Stream<bool> listenRequestsHasUnread() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    final chatStream = _db
        .collection('Chat')
        .where('participants', arrayContains: uid)
        .snapshots();

    final playerStream = _db.collection('Player').doc(uid).snapshots();

    final controller = StreamController<bool>.broadcast();
    QuerySnapshot? lastChatSnap;
    DocumentSnapshot? lastPlayerSnap;
    Timer? _debounceTimer;

    void evaluate() {
      if (lastChatSnap == null || lastPlayerSnap == null) return;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (controller.isClosed) return;

        // Use in-memory cache first (set immediately on tab visit) to avoid
        // the hasPendingWrites phase where Firestore timestamp is temporarily null.
        DateTime? lastVisit = _lastRequestsVisitCache;
        if (lastVisit == null) {
          try {
            final data = lastPlayerSnap!.data() as Map<String, dynamic>?;
            final ts = data?['lastRequestsVisitAt'];
            if (ts is Timestamp) lastVisit = ts.toDate();
          } catch (_) {}
        } else {
          // Sync cache with confirmed Firestore value if it's newer.
          try {
            final data = lastPlayerSnap!.data() as Map<String, dynamic>?;
            final ts = data?['lastRequestsVisitAt'];
            if (ts is Timestamp) {
              final firestoreTime = ts.toDate();
              if (firestoreTime.isAfter(lastVisit)) {
                _lastRequestsVisitCache = firestoreTime;
                lastVisit = firestoreTime;
              }
            }
          } catch (_) {}
        }

        final requestDocs = lastChatSnap!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final type = data['type'] ?? '';
          final status = data['status'] ?? '';
          final hiddenBy = List<String>.from(data['hiddenBy'] ?? []);
          if (hiddenBy.contains(uid)) return false;
          return type == 'team' &&
              (status == 'pending' || status == 'rejected');
        }).toList();

        if (requestDocs.isEmpty) {
          if (!controller.isClosed) controller.add(false);
          return;
        }

        if (lastVisit == null) {
          if (!controller.isClosed) controller.add(true);
          return;
        }

        for (final chatDoc in requestDocs) {
          final data = chatDoc.data() as Map<String, dynamic>;
          final ts = data['lastTimestamp'];
          if (ts is Timestamp && ts.toDate().isAfter(lastVisit!)) {
            if (!controller.isClosed) controller.add(true);
            return;
          }
        }

        if (!controller.isClosed) controller.add(false);
      });
    }

    StreamSubscription? chatSub;
    StreamSubscription? playerSub;

    chatSub = chatStream.listen((snap) {
      lastChatSnap = snap;
      evaluate();
    }, onError: (_) {});

    playerSub = playerStream.listen((snap) {
      lastPlayerSnap = snap;
      evaluate();
    }, onError: (_) {});

    controller.onCancel = () {
      _debounceTimer?.cancel();
      chatSub?.cancel();
      playerSub?.cancel();
    };

    return controller.stream;
  }

  static Future<void> markAllRequestsAsRead(String uid) async {
    // Update in-memory cache immediately → stream evaluates to false right away,
    // no waiting for the Firestore round-trip or hasPendingWrites intermediate state.
    _lastRequestsVisitCache = DateTime.now();

    await _db.collection('Player').doc(uid).set({
      'lastRequestsVisitAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // In-memory timestamp set immediately when user visits Requests tab.
  // Prevents the notification dot from flickering back on during the
  // Firestore hasPendingWrites phase where the timestamp is temporarily null.
  static DateTime? _lastRequestsVisitCache;

  static Stream<bool> listenAnyUnread() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _combineLatestBool(
        [listenChatsHasUnread(), listenRequestsHasUnread()]);
  }

  // ─── Mark as Read (optimized: only update unread messages) ─────────────────

  static Future<void> markChatAsRead(String chatId, String uid) async {
    // Only fetch messages NOT yet read by this user — avoids loading everything.
    final msgs = await _db
        .collection('Chat')
        .doc(chatId)
        .collection('message')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    final batch = _db.batch();
    bool hasPending = false;
    for (final m in msgs.docs) {
      final data = m.data();
      final senderId = data['senderId'] ?? '';
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (senderId != uid && !readBy.contains(uid)) {
        batch.update(m.reference, {
          'readBy': FieldValue.arrayUnion([uid])
        });
        hasPending = true;
      }
    }
    if (hasPending) await batch.commit();
  }

  static Future<void> markAllChatsAsRead(String uid) async {
    final snap = await _db
        .collection('Chat')
        .where('participants', arrayContains: uid)
        .get();

    // Process all chats in parallel.
    await Future.wait(snap.docs.map((doc) async {
      final data = doc.data();
      final type = data['type'] ?? '';
      final status = data['status'] ?? '';
      final isEmpty = data['isEmpty'] ?? false;
      final hiddenBy = List<String>.from(data['hiddenBy'] ?? []);
      if (hiddenBy.contains(uid)) return;
      if ((type == 'private' && !isEmpty) ||
          (type == 'team' && status == 'active')) {
        await markChatAsRead(doc.id, uid);
      }
    }));
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  static Future<Map<String, String>> _getTeamInfoOnce(String teamId) async {
    final cached = _teamCache[teamId];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final doc = await _db.collection('Team').doc(teamId).get();
      if (doc.exists) {
        final d = doc.data() as Map<String, dynamic>;
        final info = <String, String>{
          'name': (d['name'] as String?) ?? 'Team',
          'logo': (d['logoUrl'] as String?) ?? '',
        };
        _teamCache[teamId] = _CachedTeamInfo(info);
        return info;
      }
    } catch (_) {}
    return {'name': 'Team', 'logo': ''};
  }

  /// Sync version — reads from cache only (no await needed after pre-fetching).
  static String _buildLastMessageDisplaySync(
      String lastMessage, String lastSenderId, String currentUid) {
    if (lastSenderId.isEmpty || lastMessage.isEmpty) return lastMessage;
    if (lastSenderId == currentUid) return 'me: $lastMessage';
    final profile = profileCache[lastSenderId]?.data;
    final name = profile?['name'] ?? '';
    return name.isNotEmpty ? '$name: $lastMessage' : lastMessage;
  }

  static Stream<bool> _combineLatestBool(List<Stream<bool>> streams) {
    if (streams.isEmpty) return Stream.value(false);

    final controller = StreamController<bool>.broadcast();
    final values = List<bool>.filled(streams.length, false);
    var activeCount = streams.length;

    for (var i = 0; i < streams.length; i++) {
      final index = i;
      streams[i].listen(
        (value) {
          values[index] = value;
          if (!controller.isClosed) controller.add(values.any((v) => v));
        },
        onError: (_) {},
        onDone: () {
          activeCount--;
          if (activeCount == 0 && !controller.isClosed) controller.close();
        },
      );
    }

    return controller.stream;
  }

  // Kept for backward compatibility.
  static Future<String> _buildLastMessageDisplay(
      String lastMessage, String lastSenderId, String currentUid) async {
    if (lastSenderId.isEmpty || lastMessage.isEmpty) return lastMessage;
    if (lastSenderId == currentUid) return 'me: $lastMessage';
    final profile = await getUserProfileOnce(lastSenderId);
    return '${profile['name']}: $lastMessage';
  }
}

// ─── Cache Entry Models ────────────────────────────────────────────────────────

class _CachedProfile {
  final Map<String, String> data;
  final DateTime _createdAt;

  _CachedProfile(this.data) : _createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > UnifiedChatService._cacheExpiry;
}

class _CachedTeamInfo {
  final Map<String, String> data;
  final DateTime _createdAt;

  _CachedTeamInfo(this.data) : _createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > UnifiedChatService._cacheExpiry;
}