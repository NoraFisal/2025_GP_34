import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with SingleTickerProviderStateMixin {
  bool? isOrganizer;
  late AnimationController _slideController;
  int _previousIndex = 0;

  static const Color kRed = Color.fromRGBO(235, 61, 36, 1);
  static const Color kWhite = Color(0xFFFFFFFF);

  final List<IconData> _playerIcons = [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  final List<IconData> _organizerIcons = [
    Icons.home_rounded,
    Icons.emoji_events_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0, 
    );
    _detectUserType();
  }

  @override
  void didUpdateWidget(BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _slideController.forward(from: 0);
    }
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
      isOrganizer = orgDoc.exists;
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isOrganizer == null) {
      return Container(
        height: 65,
        color: kWhite,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(kRed),
            ),
          ),
        ),
      );
    }

    final icons = isOrganizer! ? _organizerIcons : _playerIcons;
    final itemCount = icons.length;

    return SizedBox(
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background bar with bubble
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _slideController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 56),
                  painter: _BubbleBarPainter(
                    selectedIndex: widget.currentIndex,
                    itemCount: itemCount,
                    animationProgress: _slideController.value,
                    previousIndex: _previousIndex,
                    color: kWhite,
                    shadowColor: Colors.black.withOpacity(0.08),
                  ),
                );
              },
            ),
          ),
          // Icons
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(itemCount, (index) {
                final isSelected = widget.currentIndex == index;
                return Expanded(
                  child: _NavItem(
                    icon: icons[index],
                    isSelected: isSelected,
                    animationProgress: _slideController.value,
                    onTap: () => widget.onTap(index),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleBarPainter extends CustomPainter {
  final int selectedIndex;
  final int previousIndex;
  final int itemCount;
  final double animationProgress;
  final Color color;
  final Color shadowColor;

  _BubbleBarPainter({
    required this.selectedIndex,
    required this.previousIndex,
    required this.itemCount,
    required this.animationProgress,
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    final itemWidth = size.width / itemCount;

    final moveT = Curves.easeInOut.transform(animationProgress);

    final liftT = Curves.easeOutBack.transform(
      math.min(animationProgress * 1.4, 1.0),
    );

    final prevX = previousIndex * itemWidth + itemWidth / 2;
    final currX = selectedIndex * itemWidth + itemWidth / 2;
    final centerX = prevX + (currX - prevX) * moveT;

    final barHeight = size.height;

    final domeHeight = 25.0 * liftT;
    final domeRadius = 20.0;
    final domeWidth = 65.0;

    final path = Path();

    path.moveTo(0, barHeight);
    path.lineTo(0, 0);
    path.lineTo(centerX - domeWidth, 0);

    // left dome
    path.cubicTo(
      centerX - domeWidth * 0.55, 0,
      centerX - domeRadius, -domeHeight,
      centerX, -domeHeight,
    );

    // right dome
    path.cubicTo(
      centerX + domeRadius, -domeHeight,
      centerX + domeWidth * 0.55, 0,
      centerX + domeWidth, 0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, barHeight);
    path.close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleBarPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.animationProgress != animationProgress;
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final double animationProgress;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.animationProgress,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _liftAnimation;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  static const Color kRed = Color.fromRGBO(235, 61, 36, 1);
  static const Color kGray = Color(0xFF9E9E9E);
  static const Color kWhite = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _liftAnimation = Tween<double>(begin: 0.0, end: -14.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          height: 65,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Icon inside circle (when selected)
                  if (widget.isSelected)
                    Positioned(
                      top: 5 + _liftAnimation.value,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: kRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kRed.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Icon(
                              widget.icon,
                              size: 22,
                              color: kWhite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Regular icon (when not selected)
                  if (!widget.isSelected)
                    Icon(
                      widget.icon,
                      size: 22,
                      color: kGray,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
