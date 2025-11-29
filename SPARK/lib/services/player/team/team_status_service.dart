import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeamStatusService {
  static final _db = FirebaseFirestore.instance;
  
  /// 🔔 راقب حالة الفِرَق اللي المستخدم عضو فيها
  static Stream<TeamStatusUpdate?> listenToUserTeams(String userId) {
    return _db
        .collection('Team')
        .snapshots()
        .asyncMap((snapshot) async {
      for (var teamDoc in snapshot.docs) {
        // تحقق إذا المستخدم عضو في هذا الفريق
        final memberDoc = await teamDoc.reference
            .collection('Members')
            .doc(userId)
            .get();
        
        if (!memberDoc.exists) continue;
        
        final teamData = teamDoc.data();
        final status = teamData['status'] ?? '';
        final statusUpdatedAt = teamData['statusUpdatedAt'] as Timestamp?;
        
        // تحقق إذا الحالة تغيرت مؤخراً (آخر 5 ثواني)
        if (statusUpdatedAt != null) {
          final diff = DateTime.now().difference(statusUpdatedAt.toDate());
          if (diff.inSeconds < 5 && (status == 'Accepted' || status == 'Rejected')) {
            return TeamStatusUpdate(
              teamId: teamDoc.id,
              teamName: teamData['name'] ?? 'Team',
              status: status,
              isForCurrentUser: true,
            );
          }
        }
      }
      return null;
    }).distinct();
  }

  /// 📢 عرض تنبيه للمستخدم
  static void showTeamStatusAlert(
    BuildContext context,
    TeamStatusUpdate update,
  ) {
    final isAccepted = update.status == 'Accepted';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isAccepted ? Colors.green : Colors.red,
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Icon(
              isAccepted ? Icons.check_circle : Icons.cancel,
              color: isAccepted ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAccepted ? 'Team Complete! 🎉' : 'Team Declined ⚠️',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isAccepted
              ? 'Great news! All players accepted the invitation for "${update.teamName}". Your team is now complete!'
              : 'Unfortunately, one of the players declined the invitation for "${update.teamName}".',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: isAccepted ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  /// 🎨 بديل: SnackBar بدل Dialog
  static void showTeamStatusSnackBar(
    BuildContext context,
    TeamStatusUpdate update,
  ) {
    final isAccepted = update.status == 'Accepted';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isAccepted 
            ? Colors.green.shade700 
            : Colors.red.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              isAccepted ? Icons.celebration : Icons.warning_amber,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAccepted ? '🎉 Team Complete!' : '⚠️ Team Declined',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    isAccepted
                        ? 'All players accepted "${update.teamName}"!'
                        : 'Someone declined "${update.teamName}"',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}

/// 📦 Model للتحديث
class TeamStatusUpdate {
  final String teamId;
  final String teamName;
  final String status;
  final bool isForCurrentUser;

  TeamStatusUpdate({
    required this.teamId,
    required this.teamName,
    required this.status,
    required this.isForCurrentUser,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamStatusUpdate &&
          teamId == other.teamId &&
          status == other.status;

  @override
  int get hashCode => teamId.hashCode ^ status.hashCode;
}