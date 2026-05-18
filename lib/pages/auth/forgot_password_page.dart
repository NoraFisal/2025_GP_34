// forgot_password_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);
static const Color _success = _accent;


  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  TextStyle get _titleStyle => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: _accent,
      );

  TextStyle get _fieldText => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _text,
      );

  TextStyle get _labelInside => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: _muted,
      );

  TextStyle get _floatingLabel => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _muted,
      );

  TextStyle get _bodyStyle => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _text,
        height: 1.25,
      );

  InputDecoration _xField(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: _labelInside,
      floatingLabelStyle: _floatingLabel,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 22, bottom: 10),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _line),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _accent, width: 2),
      ),
    );
  }

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

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      await _showPopup('Please enter your email.', danger: true);
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await _showPopup('A password reset email has been sent successfully', success: true);
    } on FirebaseAuthException catch (e) {
      await _showPopup(e.message ?? 'Something went wrong.', danger: true);
    } catch (e) {
      await _showPopup('Error: $e', danger: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

@override
Widget build(BuildContext context) {
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

                // Header
               Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      splashRadius: 18,
      icon: const Icon(
        Icons.arrow_back_ios_new,
        size: 18,
        color: _muted,
      ),
      onPressed: () =>
          Navigator.pushReplacementNamed(context, '/login'),
    ),
    Expanded(
      child: Text(
        'Forgot password',
        style: _titleStyle,
        
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    Image.asset(
      'assets/images/Logo_Spark.png',
      width: 75,
      height: 75,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const SizedBox.shrink(),
    ),
  ],
),

                const SizedBox(height: 20),

                // هذا اللي ينزل المحتوى لتحت
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60), // ← هنا النزول

                        TextField(
                          controller: _emailCtrl,
                          style: _fieldText,
                          cursorColor: _accent,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _xField('Email'),
                        ),

                        const SizedBox(height: 24),

                        Center(
                          child: SizedBox(
                            width: 240,
                            height: 44,
                            child: ElevatedButton(
                              onPressed:
                                  _loading ? null : _sendResetEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: const StadiumBorder(),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Send reset email',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                            ),
                          ),
                        ),
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
