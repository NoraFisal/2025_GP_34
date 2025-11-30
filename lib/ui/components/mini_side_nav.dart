import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/pages/start_page.dart';
import '/pages/home_page.dart';
import '/pages/organizer/organizer_home_page.dart';
import '/pages/player/player_profile_page.dart';
import '/pages/organizer/organizer_profile_page.dart';
import '/pages/contact_us_page.dart';
import '/pages/chat/chat_list_page.dart';
import '/pages/team/my_teams_page.dart';

class MiniSideNav extends StatefulWidget {
  const MiniSideNav({
    super.key,
    required this.top,
    required this.left,
  });

  final double top;
  final double left;

  @override
  State<MiniSideNav> createState() => _MiniSideNavState();
}

class _MiniSideNavState extends State<MiniSideNav> {
  bool _open = false;
  bool? isOrganizer;
  List<String> items = [];

  static const double _collapsedWidth = 32;
  static const double _collapsedHeight = 82;
  static const double _panelWidth = 190;
  static const double _panelMinHeight = 240;
  static const double _radius = 24;

  final Map<String, IconData> _icons = const {
    'Home': Icons.home_outlined,
    'Teams': Icons.groups_2_outlined,
    'Tournaments': Icons.emoji_events_outlined,
    'Messages': Icons.message_outlined,
    'Profile': Icons.person_outline,
    'Contact': Icons.mail_outline,
    'Logout': Icons.logout_outlined,
  };

  @override
  void initState() {
    super.initState();
    _detectUserType();
  }

  Future<void> _detectUserType() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final orgDoc = await FirebaseFirestore.instance.collection('Organizer').doc(uid).get();

    setState(() {
      isOrganizer = orgDoc.exists;
      if (isOrganizer == true) {
        items = ["Home", "Profile", "Contact", "Logout"];
      } else {
        items = ["Home", "Teams", "Tournaments", "Messages", "Profile", "Contact", "Logout"];
      }
    });
  }

  void _handleNavPress(String label) {
    switch (label) {
      case "Home":
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    isOrganizer == true ? const organizerHomePage() : const HomePage()));
        break;

      case "Teams":
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamsPage()));
        break;

      case "Messages":
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListPage()));
        break;

      case "Profile":
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    isOrganizer == true ? const OrganizerProfilePage() : const PlayerProfilePage()));
        break;

      case "Contact":
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsPage()));
        break;

      case "Logout":
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.35),
          builder: (context) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Are you sure you want to log out?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: Colors.white.withOpacity(0.3)),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "Cancel",
                                        style:
                                            TextStyle(color: Colors.white70, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await FirebaseAuth.instance.signOut();

                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (_) => const StartPage()),
                                      (route) => false,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFB3261E), Color(0xFFD94835)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "Log out",
                                      style:
                                          TextStyle(color: Colors.white, fontSize: 14),
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
                ),
              ),
            );
          },
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return Positioned(
      top: widget.top,
      left: widget.left,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: _open ? _panelWidth : _collapsedWidth,
        height: _open
            ? (_panelMinHeight + items.length * 42).clamp(_panelMinHeight, maxHeight)
            : _collapsedHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_open)
              _buildGlassPanel(context, maxHeight),
            Positioned(
              top: 0,
              left: 0,
              child: _CollapsedGrabber(
                onTap: () => setState(() => _open = !_open),
                open: _open,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassPanel(BuildContext context, double maxHeight) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          margin: const EdgeInsets.only(left: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),

          // HERE: Scrollable menu content
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _open = false),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...items.map((label) {
                  return _NavItem(
                    text: label,
                    icon: _icons[label] ?? Icons.circle_outlined,
                    onTap: () {
                      setState(() => _open = false);
                      _handleNavPress(label);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedGrabber extends StatelessWidget {
  const _CollapsedGrabber({required this.onTap, required this.open});

  final VoidCallback onTap;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 82,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 26,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB3261E), Color(0xFFD94835)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              open ? Icons.chevron_left : Icons.chevron_right,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.text, required this.icon, required this.onTap});
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      splashColor: Colors.white.withOpacity(0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
