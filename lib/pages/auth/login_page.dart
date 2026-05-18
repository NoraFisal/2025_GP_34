import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ===== Brand =====
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);

  // ===== X-like palette =====
  static const Color _bg = Color(0xFFF7F7F7); // off-white
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);

  // ===== Controllers / Focus =====
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  // Show required errors only after pressing Login
  bool _submitted = false;
  String? _emailLoginError;
  String? _passwordLoginError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ===== Typography (match signup) =====
  TextStyle get _titleStyle => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 31,
        fontWeight: FontWeight.w900, // only bold thing
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

  TextStyle get _errorStyle => const TextStyle(
        color: _danger,
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.2,
      );

  // ===== Input Decor (match signup) =====
  InputDecoration _xField(String labelText, {Widget? suffix}) {
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
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _danger),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _danger, width: 2),
      ),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      // Hide Flutter default error line; we show our own text under field.
      errorStyle: const TextStyle(height: 0.0, fontSize: 0.0),
    );
  }

  Widget _fieldBlock({
    required Widget field,
    String? errorText,
    double gapAfter = 16,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        if (errorText != null && errorText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(errorText, style: _errorStyle),
        ],
        SizedBox(height: gapAfter),
      ],
    );
  }

  String? _emailErrorText() {
  if (_emailLoginError != null) return _emailLoginError;

  if (!_submitted) return null;

  final v = _emailCtrl.text.trim();

  if (v.isEmpty) return 'Email is required';

final emailRegex =
    RegExp(r'^[^@]+@[^@]+\.[^@]+');

if (!emailRegex.hasMatch(v)) {
  return 'Please enter a valid email';
}

  return null;
}

  String? _passwordErrorText() {
  if (_passwordLoginError != null) return _passwordLoginError;

  if (!_submitted) return null;

  final v = _passwordCtrl.text;

  if (v.isEmpty) return 'Password is required';

  return null;
}


  Future<void> _handleLogin() async {
  setState(() {
    _submitted = true;
    _emailLoginError = null;
    _passwordLoginError = null;
  });

  final email = _emailCtrl.text.trim();
  final password = _passwordCtrl.text.trim();

  final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  if (email.isEmpty) {
    setState(() => _emailLoginError = 'Email is required');
    return;
  }

  if (!emailRegex.hasMatch(email)) {
    setState(() => _emailLoginError = 'Please enter a valid email');
    return;
  }

  if (password.isEmpty) {
    setState(() => _passwordLoginError = 'Password is required');
    return;
  }

  setState(() => _loading = true);

  try {
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user!;
    await user.reload();

    if (!user.emailVerified) {
      await user.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _emailLoginError =
            'Your account is not verified yet. Please check your email.';
      });
      return;
    }

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    final playerDoc = await firestore.collection('Player').doc(uid).get();
    final organizerDoc = await firestore.collection('Organizer').doc(uid).get();

    if (!mounted) return;

    if (playerDoc.exists) {
      Navigator.pushReplacementNamed(context, '/homepage');
      return;
    }

    if (organizerDoc.exists) {
      Navigator.pushReplacementNamed(context, '/organizerHome');
      return;
    }

  } on FirebaseAuthException catch (e) {
  if (!mounted) return;

  switch (e.code) {
    case 'invalid-email':
      setState(() {
        _emailLoginError = 'Please enter a valid email';
      });
      break;

    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
    default:
      setState(() {
        _emailLoginError = 'Invalid email or password';
        _passwordLoginError = 'Invalid email or password';
      });
  }

  } catch (_) {
    if (!mounted) return;
    setState(() => _emailLoginError = 'Something went wrong. Please try again.');
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
  }
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxW = math.min(600.0, w - 48);

    final emailErr = _emailErrorText();
    final passErr = _passwordErrorText();

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

                  // Title + Logo (match signup layout)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Welcome back..',
                          style: _titleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                         
                        ),
                      ),
                      const SizedBox(width: 24),
                      Image.asset(
                        'assets/images/Logo_Spark.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

Expanded(
  child: LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2), 

                _fieldBlock(
                  errorText: emailErr,
                  gapAfter: 16,
                  field: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: _fieldText,
                    cursorColor: _accent,
                    decoration: _xField('Email'),
                    onChanged: (_) {
  setState(() {
    _emailLoginError = null;
  });

  if (_submitted) setState(() {});
},
                  ),
                ),

                _fieldBlock(
                  errorText: passErr,
                  gapAfter: 10,
                  field: TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: _fieldText,
                    cursorColor: _accent,
                    decoration: _xField(
                      'Password',
                      suffix: IconButton(
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                        onPressed: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: _muted,
                        ),
                      ),
                    ),
                    onChanged: (_) {
  setState(() {
    _passwordLoginError = null;
  });

  if (_submitted) setState(() {});
},
                  ),
                ),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forgotPassword'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: _text,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Center(
                  child: SizedBox(
                    width: 176,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleLogin,
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
                              'Login',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Center(
                  child: SizedBox(
                    width: 176,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        side: const BorderSide(color: _line),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Signup',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 8), 
              ],
            ),
          ),
        ),
      );
    },
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
