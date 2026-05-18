import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/pages/start_page.dart';
import '/pages/home_page.dart';

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
  bool? isOrganizer;
  List<String> items = [];

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

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

    final orgDoc =
        await FirebaseFirestore.instance.collection('Organizer').doc(uid).get();

    if (!mounted) return;
    setState(() {
      isOrganizer = orgDoc.exists;
      if (isOrganizer == true) {
        items = ["Home", "Profile", "Contact", "Logout"];
      } else {
        items = [
          "Home",
          "Teams",
          "Tournaments",
          "Messages",
          "Profile",
          "Contact",
          "Logout"
        ];
      }
    });
  }

  void _openMenu() {
    final rootContext = context;

    showGeneralDialog(
      context: rootContext,
      barrierLabel: 'menu',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) {
        return _SideMenuDialog(
          rootContext: rootContext,
          items: items,
          icons: _icons,
          accent: _accent,
          isOrganizer: isOrganizer == true,
          onNavigate: (label) => _handleNavPress(rootContext, label),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.05, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _handleNavPress(BuildContext rootContext, String label) {
    switch (label) {
     

      case "Teams":
        Navigator.push(
          rootContext,
          MaterialPageRoute(builder: (_) => const MyTeamsPage()),
        );
        break;

      case "Tournaments":
        Navigator.push(
          rootContext,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;

      case "Messages":
        Navigator.push(
          rootContext,
          MaterialPageRoute(builder: (_) => const ChatListPage()),
        );
        break;

      case "Profile":
        Navigator.push(
          rootContext,
          MaterialPageRoute(
            builder: (_) => isOrganizer == true
                ? const OrganizerProfilePage()
                : const PlayerProfilePage(),
          ),
        );
        break;

      case "Contact":
        Navigator.push(
          rootContext,
          MaterialPageRoute(builder: (_) => const ContactUsPage()),
        );
        break;

      case "Logout":
        _showLogoutDialog(rootContext);
        break;
    }
  }

  void _showLogoutDialog(BuildContext rootContext) {
    showDialog(
      context: rootContext,
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
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
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
                                if (!rootContext.mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  rootContext,
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
                                  style: TextStyle(color: Colors.white, fontSize: 14),
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
  }

  @override
  Widget build(BuildContext context) {
    const double edgePaddingRight = 18;
    const double edgePaddingTopExtra = 12;

    return Positioned(
      right: edgePaddingRight,
      top: widget.top + edgePaddingTopExtra,
      child: _HamburgerButton(onTap: _openMenu),
    );
  }
}

class _SideMenuDialog extends StatelessWidget {
  const _SideMenuDialog({
    required this.rootContext,
    required this.items,
    required this.icons,
    required this.accent,
    required this.isOrganizer,
    required this.onNavigate,
  });

  final BuildContext rootContext;
  final List<String> items;
  final Map<String, IconData> icons;
  final Color accent;
  final bool isOrganizer;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final h = MediaQuery.of(context).size.height;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topRight,
        child: SizedBox(
          height: h,
          child: Container(
            width: 240,
            margin: EdgeInsets.only(top: topInset + 6, right: 10, bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(44),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3A000000),
                  blurRadius: 18,
                  offset: Offset(-6, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: items.map((label) {
                            return _NavRow(
                              label: label,
                              icon: icons[label] ?? Icons.circle_outlined,
                              accent: accent,
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).pop();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  onNavigate(label);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HamburgerButton extends StatefulWidget {
  const _HamburgerButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton> {
  bool _hover = false;
  bool _down = false;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  @override
  Widget build(BuildContext context) {
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
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: _down ? 0.96 : (_hover ? 1.03 : 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hover ? 0.30 : 0.20),
                  blurRadius: _hover ? 16 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.menu_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatefulWidget {
  const _NavRow({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover ? const Color(0xFFF6F6F6) : Colors.transparent;
    final textColor = _hover ? const Color(0xFF111111) : Colors.black87;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: widget.accent,
                  shape: BoxShape.circle,
                  boxShadow: _hover
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          )
                        ]
                      : const [],
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: textColor,
                    fontWeight: _hover ? FontWeight.w700 : FontWeight.w600,
                  ),
                  child: Text(widget.label),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                opacity: _hover ? 1 : 0,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
