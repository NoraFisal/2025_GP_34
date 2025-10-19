// lib/ui/side_nav.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';

/// Little red handle on the left edge
class SparkNavHandle extends StatelessWidget {
  const SparkNavHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(_SideNavRoute()),
          child: Container(
            width: 24,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(2, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-opaque page route so taps outside close it and nothing gets blocked.
class _SideNavRoute extends PageRoute<void> {
  @override
  bool get opaque => false;
  @override
  bool get barrierDismissible => true;
  @override
  Color get barrierColor => Colors.transparent;
  @override
  String get barrierLabel => 'spark-nav';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);
  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> _, Animation<double> __) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(onTap: () => Navigator.of(context).pop()),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: _NavPanel(onClose: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext _,
    Animation<double> anim,
    Animation<double> __,
    Widget child,
  ) {
    final slide = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(anim);
    return SlideTransition(position: slide, child: child);
  }
}

class _NavPanel extends StatelessWidget {
  final VoidCallback onClose;
  const _NavPanel({required this.onClose});

  static const double _panelWidth = 210;
  static const double _radius = 22;
  static const Color _maroon = Color(0xFF84281E);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(_radius),
            bottomRight: Radius.circular(_radius),
          ),
          child: Container(
            width: _panelWidth,
            decoration: const BoxDecoration(
              color: _maroon,
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Stack(
              children: [
                // ⭐ your small star art
                Positioned(
                  left: -6,
                  bottom: 10,
                  child: Image.asset(
                    'assets/images/nav_spark.png',
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                ),

                // محتوى القائمة
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 22),
                        onPressed: onClose,
                      ),
                    ),
                    const SizedBox(height: 4),

                    _NavTile(
                      text: 'Home',
                      onTap: () {
                        onClose();
                        Navigator.pushReplacementNamed(context, '/homepage');
                      },
                    ),

                    _NavTile(text: 'Teams', onTap: onClose),
                    _NavTile(text: 'Tournaments', onTap: onClose),
                    _NavTile(text: 'Messages', onTap: onClose),

                    _NavTile(
                      text: 'Profile',
                      onTap: () {
                        onClose();
                        Navigator.pushReplacementNamed(context, '/playerProfile');
                      },
                    ),

                    _NavTile(text: 'Contact', onTap: onClose),

                    // ✅ Logout تحت Contact مباشرة
                    _NavTile(
                      text: 'Logout',
                      onTap: () async {
                        final ok = await _confirmLogout(context);
                        if (ok != true) return;
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        }
                      },
                    ),

                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔒 رسالة تأكيد تسجيل الخروج
  static Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

class _NavTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _NavTile({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashFactory: InkSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
