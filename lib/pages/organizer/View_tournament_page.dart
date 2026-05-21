import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'Edit_tournament_page.dart';
import 'organizer_profile_view_page.dart';

class ViewTournamentPage extends StatefulWidget {
  final String tournamentId;

  const ViewTournamentPage({super.key, required this.tournamentId});

  @override
  State<ViewTournamentPage> createState() => _ViewTournamentPageState();
}

class _ViewTournamentPageState extends State<ViewTournamentPage> {
  Map<String, dynamic>? _tournamentData;
  bool _loading = true;
  bool _isOwner = false;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  String _calculateStatus(String date, String time, String currentStatus) {
    if (date.isEmpty || time.isEmpty) return currentStatus;

    try {
      // إذا كانت مكتملة يدوياً، تبقى مكتملة
      if (currentStatus.toLowerCase() == 'completed') {
        return 'completed';
      }

      DateTime tournamentDateTime;

      // محاولة parse التاريخ بصيغ مختلفة
      try {
        // جرب الصيغة yyyy-MM-dd أولاً
        tournamentDateTime = DateTime.parse(date);
      } catch (e) {
        // جرب صيغ أخرى
        try {
          tournamentDateTime = DateFormat('dd/MM/yyyy').parse(date);
        } catch (e2) {
          try {
            tournamentDateTime = DateFormat('MM/dd/yyyy').parse(date);
          } catch (e3) {
            debugPrint('Could not parse date: $date');
            return currentStatus;
          }
        }
      }

      // Parse الوقت وإضافته للتاريخ
      try {
        final timeParts = time.split(':');
        int hour = 0;
        int minute = 0;

        // التعامل مع صيغة 12 ساعة (AM/PM)
        if (time.toUpperCase().contains('AM') ||
            time.toUpperCase().contains('PM')) {
          final timeFormat = DateFormat.jm(); // 12-hour format
          final parsedTime = timeFormat.parse(time);
          hour = parsedTime.hour;
          minute = parsedTime.minute;
        } else {
          // صيغة 24 ساعة
          hour = int.parse(timeParts[0].trim());
          minute = int.parse(timeParts[1].trim());
        }

        tournamentDateTime = DateTime(
          tournamentDateTime.year,
          tournamentDateTime.month,
          tournamentDateTime.day,
          hour,
          minute,
        );
      } catch (e) {
        debugPrint('Could not parse time: $time, Error: $e');
        // استخدم التاريخ فقط بدون الوقت
      }

      final now = DateTime.now();

      debugPrint('Tournament DateTime: $tournamentDateTime');
      debugPrint('Current DateTime: $now');
      debugPrint(
        'Difference: ${now.difference(tournamentDateTime).inHours} hours',
      );

      // التحقق من الحالة
      if (now.isAfter(tournamentDateTime.add(const Duration(hours: 3)))) {
        // افترض أن التورنمنت تستمر 3 ساعات
        return 'completed';
      } else if (now.isAfter(tournamentDateTime)) {
        return 'ongoing';
      } else {
        return 'upcoming';
      }
    } catch (e) {
      debugPrint('Error calculating status: $e');
      return currentStatus;
    }
  }

  Future<void> _loadTournament() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('Loading tournament with ID: ${widget.tournamentId}');
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Tournament')
          .doc(widget.tournamentId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final organizerId = data['organizerID'] ?? '';

        // احسب الحالة الفعلية
        final currentStatus = data['status'] ?? 'upcoming';
        final actualStatus = _calculateStatus(
          data['date'] ?? '',
          data['time'] ?? '',
          currentStatus,
        );

        debugPrint('Current status: $currentStatus');
        debugPrint('Calculated status: $actualStatus');
        debugPrint('Date: ${data['date']}');
        debugPrint('Time: ${data['time']}');

        // إذا تغيرت الحالة، حدّث Firestore
        if (actualStatus != currentStatus) {
          await FirebaseFirestore.instance
              .collection('Tournament')
              .doc(widget.tournamentId)
              .update({'status': actualStatus});

          data['status'] = actualStatus;
        }

        setState(() {
          _tournamentData = data;
          _isOwner = organizerId == user.uid;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tournament: $e');
      setState(() => _loading = false);
    }
  }

  // دالة لعرض رسالة منبثقة
  void _showCompletedTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6b7280).withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF6b7280),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cannot Edit',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This tournament has been completed and cannot be edited.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

String _getGameLogo(String gameName) {
  final lowerGame = gameName.toLowerCase();

  if (lowerGame.contains('pubg')) {
    return 'assets/images/pubg.png';
  }

  if (lowerGame.contains('lol') ||
      lowerGame.contains('league of legends') ||
      lowerGame.contains('league')) {
    return 'assets/images/lol.png';
  }

  if (lowerGame.contains('valorant')) {
    return 'assets/images/valorant.png';
  }

  if (lowerGame.contains('call of duty') ||
      lowerGame.contains('cod')) {
    return 'assets/images/cod.png';
  }

  if (lowerGame.contains('fortnite')) {
    return 'assets/images/fortnite.png';
  }

  if (lowerGame.contains('dota') || lowerGame.contains('dota2')) {
    return 'assets/images/dota2.png';
  }

  return '';
}

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    if (_tournamentData == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(child: Text('Tournament not found')),
      );
    }

    final title = _tournamentData!['Title'] ?? 'Tournament';
    final description = _tournamentData!['description'] ?? '';
    final details = _tournamentData!['details'] ?? '';
    final date = _tournamentData!['date'] ?? '';
    final time = _tournamentData!['time'] ?? '';
    final imageBase64 = _tournamentData!['image'] ?? '';
    final game = _tournamentData!['game'] ?? '';
    final status = _tournamentData!['status'] ?? '';
    final organizerId = _tournamentData!['organizerID'] ?? '';

    const actionBtnSize = 34.0;
    final isCompleted = status.toLowerCase() == 'completed';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _HoverTap(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: _muted,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),

              // Header Card
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _tournamentImage(
                          imageBase64: imageBase64,
                          game: game,
                          size: 80,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (_isOwner && !isCompleted) ...[
                          _circleButton(
                            size: actionBtnSize,
                            icon: Icons.edit_rounded,
                            onTap: () async {
                              // تحقق من حالة البطولة
                              if (isCompleted) {
                                _showCompletedTournamentDialog();
                                return;
                              }

                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditTournamentPage(
                                    tournamentId: widget.tournamentId,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadTournament();
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    _scheduleAndStatusBlock(date, time, status),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Description Section
              if (description.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFCFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Description",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _text,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _line),
                        ),
                        child: Text(
                          description,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _text,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (description.isNotEmpty) const SizedBox(height: 18),

              // Details Section
              if (details.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFCFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Details",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _text,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _line),
                        ),
                        child: Text(
                          details,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _text,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (details.isNotEmpty) const SizedBox(height: 18),

              // Organizer Section
              if (!_isOwner && organizerId.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFCFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Organized By",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _text,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _OrganizerCard(organizerId: organizerId),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleAndStatusBlock(String date, String time, String status) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'upcoming':
        statusColor = const Color(0xFF3b82f6);
        statusIcon = Icons.schedule;
        statusText = 'Upcoming';
        break;
      case 'ongoing':
        statusColor = const Color(0xFF22c55e);
        statusIcon = Icons.play_circle_filled;
        statusText = 'Ongoing';
        break;
      case 'completed':
        statusColor = const Color(0xFF6b7280);
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      default:
        statusColor = _muted;
        statusIcon = Icons.help_outline;
        statusText = status.isEmpty ? 'Unknown' : status;
    }

    const label = TextStyle(
      color: _text,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1,
    );
    const value = TextStyle(
      color: _text,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Date", style: label),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 16,
                            color: _accent,
                          ),
                          const SizedBox(width: 6),
                          Text(date.isEmpty ? '-' : date, style: value),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Time",
                        style: label,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: _accent,
                          ),
                          const SizedBox(width: 6),
                          Text(time.isEmpty ? '-' : time, style: value),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: _muted.withOpacity(0.55)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tournamentImage({
    required String imageBase64,
    required String game,
    required double size,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _accent, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.15),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: imageBase64.isNotEmpty
                ? Image.memory(
                    base64Decode(imageBase64),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _defaultTrophyIcon();
                    },
                  )
                : _defaultTrophyIcon(),
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Builder(
                  builder: (context) {
                    final logoPath = _getGameLogo(game);

                    if (logoPath.isEmpty) {
                      return const Icon(
                        Icons.sports_esports_rounded,
                        color: _accent,
                        size: 16,
                      );
                    }

                    return Image.asset(
                      logoPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.sports_esports_rounded,
                          color: _accent,
                          size: 16,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultTrophyIcon() {
    return Container(
      color: const Color(0xFFEFEFEF),
      child: const Icon(Icons.emoji_events, color: _accent, size: 40),
    );
  }

  Widget _circleButton({
    required double size,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _HoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _accent,
          border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final String organizerId;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

  const _OrganizerCard({required this.organizerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Organizer')
          .doc(organizerId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = (data['Name'] ?? 'Organizer').toString();
        final info = (data['Info'] ?? '').toString();
        final photo = (data['ProfilePhoto'] ?? '').toString();

        ImageProvider? imageProvider;
        if (photo.isNotEmpty) {
          try {
            if (photo.startsWith('http://') || photo.startsWith('https://')) {
              imageProvider = NetworkImage(photo);
            } else {
              imageProvider = MemoryImage(base64Decode(photo));
            }
          } catch (e) {
            debugPrint('Error loading organizer image: $e');
          }
        }

        return _HoverTap(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ViewOrganizerProfilePage(organizerId: organizerId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 2.5),
                    color: const Color(0xFFEFEFEF),
                  ),
                  child: ClipOval(
                    child: imageProvider != null
                        ? Image(image: imageProvider, fit: BoxFit.cover)
                        : const Icon(
                            Icons.person,
                            color: Colors.black38,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _text,
                          height: 1.1,
                        ),
                      ),
                      if (info.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          info,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: _muted, size: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HoverTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _HoverTap({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<_HoverTap> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final canHover =
        Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;

    final scale = _down ? 0.98 : (_hover && canHover ? 1.02 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: (_hover && canHover)
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
