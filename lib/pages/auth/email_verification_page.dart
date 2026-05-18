// email_verification_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class APage extends StatefulWidget {
  const APage({super.key});

  @override
  State<APage> createState() => _APageState();
}

class _APageState extends State<APage> {
  bool _loading = false;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);
  static const Color _success = Color(0xFF00BA7C);

  TextStyle get _titleStyle => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: _accent,
      );

  TextStyle get _bodyStyle => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _text,
        height: 1.25,
      );

  TextStyle get _mutedStyle => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _muted,
        height: 1.25,
      );

  Future<void> _showPopup(
    String message, {
    bool success = false,
    bool danger = false,
  }) async {
    if (!mounted) return;

    final Color ring = danger ? _danger : (success ? _success : _accent);
    final IconData icon = danger
        ? Icons.error_rounded
        : (success ? Icons.check_circle_rounded : Icons.info_rounded);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
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
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ring, width: 2),
                  ),
                  child: Icon(icon, color: ring, size: 32),
                ),
                const SizedBox(height: 14),
                Text(message, textAlign: TextAlign.center, style: _bodyStyle),
                const SizedBox(height: 14),
                SizedBox(
                  width: 140,
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _line),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'OK',
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
          ),
        );
      },
    );
  }

  Future<void> _handleContinue(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await _showPopup('No user is signed in.', danger: true);
      return;
    }

    setState(() => _loading = true);

    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser!.emailVerified) {
        final uid = refreshedUser.uid;
        final firestore = FirebaseFirestore.instance;

        final playerDoc = await firestore.collection('Player').doc(uid).get();
        final organizerDoc = await firestore.collection('Organizer').doc(uid).get();

        if (playerDoc.exists) {
          await _showPopup('Welcome back, Player!', success: true);
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/homepage');
        } else if (organizerDoc.exists) {
          await _showPopup('Welcome back, Organizer!', success: true);
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/organizerHome');
        } else {
          await _showPopup('User role not found. Contact support.', danger: true);
        }
      } else {
        await _showPopup('Your email is not verified yet. Please check your inbox.');
      }
    } catch (e) {
      await _showPopup('Error: $e', danger: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final w = MediaQuery.of(context).size.width;
    final maxW = math.min(600.0, w - 48);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),

                  // ===== HEADER =====
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        splashRadius: 18,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _muted),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                      ),
                      const SizedBox(width: 4),

                      Expanded(
  child: Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'Verified Page',
        style: _titleStyle,
      ),
    ),
  ),
),
                      const SizedBox(width: 8),

                      Image.asset(
                        'assets/images/Logo.png',
                        width: 75,
                        height: 75,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user != null
                                      ? "Welcome, ${user.displayName ?? user.email}"
                                      : "No user is signed in.",
                                  style: _bodyStyle.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 10),
                                if (user != null) ...[
                                  user.emailVerified
                                      ? Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: _success, size: 18),
                                            const SizedBox(width: 8),
                                            Text("Your email is verified!", style: _mutedStyle.copyWith(color: _success)),
                                          ],
                                        )
                                      : Text(
                                          "Please verify your email: ${user.email}",
                                          style: _mutedStyle,
                                        ),
                                ] else ...[
                                  Text("Please go back and sign in.", style: _mutedStyle),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (user != null) ...[
                            Center(
                              child: SizedBox(
                                width: 240,
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: () async {
                                    await user.sendEmailVerification();
                                    await _showPopup('Verification email sent!', success: true);
                                  },
                                  child: const Text(
                                    "Send verification email",
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: SizedBox(
                                width: 240,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _loading ? null : () async => _handleContinue(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _accent,
                                    side: const BorderSide(color: _line),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                                        )
                                      : const Text(
                                          "Continue",
                                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
