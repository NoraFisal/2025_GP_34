import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/ui/components/bottom_nav_bar.dart';
import '/services/chat/unified_chat_service.dart'; 


import '/pages/home_page.dart';
import '/pages/team/my_teams_page.dart';
import '/pages/chat/chat_list_page.dart';
import '/pages/player/player_profile_page.dart';
import '/pages/organizer/organizer_profile_page.dart';
import '/pages/organizer/my_tournaments_page.dart';

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;
  const MainNavigationPage({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _currentIndex;
  bool? _isOrganizer;


  bool _hasChatUnread = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _detectUserType();
    _listenChatUnread();
  }

 
  void _listenChatUnread() {
    UnifiedChatService.listenAnyUnread().listen((hasUnread) {
      if (mounted) {
        setState(() => _hasChatUnread = hasUnread);
      }
    });
  }

  Future<void> _detectUserType() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final orgDoc = await FirebaseFirestore.instance
        .collection('Organizer')
        .doc(uid)
        .get();

    if (!mounted) return;
    setState(() {
      _isOrganizer = orgDoc.exists;
    });
  }

  List<Widget> _getPlayerPages() {
    return [
      const HomePage(),
      const MyTeamsPage(),
      const ChatListPage(),
      const PlayerProfilePage(),
    ];
  }

  List<Widget> _getOrganizerPages() {
    return [
      const HomePage(),              // 🏠 Home
      const MyTournamentsPage(),     // 🏆 My Tournaments
      const ChatListPage(),          // 💬 Messages
      const OrganizerProfilePage(),  // 👤 Profile
    ];
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }


  static const int _chatTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    if (_isOrganizer == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(235, 61, 36, 1)),
          ),
        ),
      );
    }

    final pages = _isOrganizer! ? _getOrganizerPages() : _getPlayerPages();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavWithDot(),
    );
  }


  Widget _buildBottomNavWithDot() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
      
        Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
          ),
        ),

        
        if (_hasChatUnread)
          _buildDotPositioned(context),
      ],
    );
  }

 
  Widget _buildDotPositioned(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    
    final itemWidth = screenWidth / 4;

    
    final iconCenterX = (_chatTabIndex * itemWidth) + (itemWidth / 2);


    final navHeight = kBottomNavigationBarHeight + bottomPadding;

 
    const double iconTopInNav = 8.0;
    const double dotOffset = -4.0; 

    return Positioned(
      
      left: iconCenterX + 8,
      top: iconTopInNav + dotOffset,
      child: _buildGreenDot(),
    );
  }

  
  Widget _buildGreenDot() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFF34C759),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFAFAFA), 
          width: 2,
        ),
      ),
    );
  }
}
