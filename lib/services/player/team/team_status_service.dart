// 📄 lib/services/player/team/team_status_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ===== Palette — مطابق تماماً لـ SettingsPage =====
const Color _accent = Color(0xFFEB3D24);
const Color _bg    = Color(0xFFF7F7F7);
const Color _text  = Color(0xFF0F1419);
const Color _muted = Color(0xFF536471);
const Color _line  = Color(0xFFCFD9DE);

class TeamStatusService {
  static final _db = FirebaseFirestore.instance;

  // ==========================================================
  // Stream يُرجع كل التحديثات غير المشاهدة دفعةً واحدة
  // ==========================================================
  static Stream<List<TeamStatusUpdate>> listenToUserTeamsAll(String userId) {
    return _db.collection('Team').snapshots().asyncMap((snapshot) async {
      final updates = <TeamStatusUpdate>[];
      for (var teamDoc in snapshot.docs) {
        final memberDoc = await teamDoc.reference
            .collection('Members')
            .doc(userId)
            .get();
        if (!memberDoc.exists) continue;

        final teamData = teamDoc.data();
        final status = teamData['status'] ?? '';
        if (status != 'Accepted' && status != 'Rejected') continue;

        final seenBy = List<String>.from(teamData['statusSeenBy'] ?? []);
        if (seenBy.contains(userId)) continue;

        updates.add(TeamStatusUpdate(
          teamId: teamDoc.id,
          teamName: teamData['name'] ?? 'Team',
          status: status,
          isForCurrentUser: true,
        ));
      }
      return updates;
    });
  }

  // للتوافق مع الكود القديم
  static Stream<TeamStatusUpdate?> listenToUserTeams(String userId) {
    return listenToUserTeamsAll(userId)
        .map((list) => list.isEmpty ? null : list.first);
  }

  static Future<void> markStatusAsSeen(String teamId, String userId) async {
    await _db.collection('Team').doc(teamId).update({
      'statusSeenBy': FieldValue.arrayUnion([userId]),
    });
  }

  // ==========================================================
  // نقطة دخول واحدة — فريق واحد أو متعدد، نفس الشكل دائماً
  // ==========================================================
  static void showBatchTeamStatusAlert(
    BuildContext context,
    List<TeamStatusUpdate> updates,
    String userId,
  ) {
    if (updates.isEmpty) return;
    if (updates.length == 1) {
      _showSingleAlert(context, updates.first, userId);
    } else {
      _showMultiAlert(context, updates, userId);
    }
  }

  // ==========================================================
  // Alert فريق واحد — نفس تنسيق Logout تماماً
  // ==========================================================
  static void _showSingleAlert(
    BuildContext context,
    TeamStatusUpdate update,
    String userId,
  ) {
    final isAccepted = update.status == 'Accepted';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Circle — نفس حجم وشكل Logout
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent, width: 2),
                ),
                child: Icon(
                  isAccepted ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: _accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),

              // Message — نفس style الـ Logout
              Text(
                isAccepted
                    ? 'All players accepted "${update.teamName}". Your team is now complete!'
                    : 'One of the players declined the invitation for "${update.teamName}".',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),

              // زر واحد — Got it
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        markStatusAsSeen(update.teamId, userId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Got it!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // Alert متعدد — نفس التنسيق بالضبط مع قائمة الفرق
  // ==========================================================
  static void _showMultiAlert(
    BuildContext context,
    List<TeamStatusUpdate> updates,
    String userId,
  ) {
    final accepted = updates.where((u) => u.status == 'Accepted').toList();
    final rejected = updates.where((u) => u.status == 'Rejected').toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Circle — نفس حجم وشكل Logout
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent, width: 2),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: _accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),

              // Message
              const Text(
                "Here's what happened with your teams while you were away:",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),

              // قائمة الفرق المقبولة
              if (accepted.isNotEmpty) ...[
                _teamSection(
                  icon: Icons.check_circle_outline,
                  label: accepted.length == 1
                      ? 'Accepted'
                      : 'Accepted (${accepted.length})',
                  teams: accepted.map((u) => u.teamName).toList(),
                ),
              ],

              // قائمة الفرق المرفوضة
              if (rejected.isNotEmpty) ...[
                if (accepted.isNotEmpty) const SizedBox(height: 8),
                _teamSection(
                  icon: Icons.cancel_outlined,
                  label: rejected.length == 1
                      ? 'Declined'
                      : 'Declined (${rejected.length})',
                  teams: rejected.map((u) => u.teamName).toList(),
                ),
              ],

              const SizedBox(height: 14),

              // زر Got it — نفس style الـ Logout
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final batch = FirebaseFirestore.instance.batch();
                        for (final u in updates) {
                          batch.update(
                            FirebaseFirestore.instance
                                .collection('Team')
                                .doc(u.teamId),
                            {'statusSeenBy': FieldValue.arrayUnion([userId])},
                          );
                        }
                        batch.commit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Got it!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: صف فريق واحد
  static Widget _teamSection({
    required IconData icon,
    required String label,
    required List<String> teams,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _line.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: _accent, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
          ]),
          ...teams.map((name) => Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  '• $name',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _text,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // الدالتان القديمتان محفوظتان للتوافق
  static void showTeamStatusAlert(
    BuildContext context,
    TeamStatusUpdate update,
    String userId,
  ) => _showSingleAlert(context, update, userId);

  static void showTeamStatusSnackBar(
    BuildContext context,
    TeamStatusUpdate update,
  ) {
    final isAccepted = update.status == 'Accepted';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isAccepted ? Colors.green.shade700 : Colors.red.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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