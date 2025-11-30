//new
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _handleSendResetEmail() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _loading = true);

  try {
    final email = _emailCtrl.text.trim();

    // 🔍 Check if the email exists in either Player or Organizer collections
    final playerSnapshot = await FirebaseFirestore.instance
        .collection('Player')
        .where('Email', isEqualTo: email)
        .limit(1)
        .get();

    final organizerSnapshot = await FirebaseFirestore.instance
        .collection('Organizer')
        .where('Email', isEqualTo: email)
        .limit(1)
        .get();

    // ✅ Determine if the email exists in any of the two collections
    final emailExists =
        playerSnapshot.docs.isNotEmpty || organizerSnapshot.docs.isNotEmpty;

    if (!emailExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No account found with this email ❌',
          ),
        ),
      );
      setState(() => _loading = false);
      return;
    }

    // ✅ If the email exists, send the password reset email
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A password reset email has been sent to your inbox ✅',
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unexpected error: $e')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF9E2819); 

    return Scaffold(
      body: Stack(
        children: [
          
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withOpacity(0.35)),

         
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 0, right: 4),
              child: const CircleAvatar(
                radius: 40,
                backgroundImage: AssetImage('assets/images/logo.png'),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),

          // المحتوى الرئيسي
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Forgot Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // عنوان الحقل
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Email',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.black87),
                            decoration: _fieldDecoration('Enter your registered email'),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                                return 'Invalid email';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 40),

                          
                          _customButton(
                            title: 'Send Reset Email',
                            color: accentColor,
                            onPressed: _loading ? null : _handleSendResetEmail,
                            loading: _loading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

                                  
                  Positioned(
                    top: 0,
                    left: 16,
                    child: SafeArea(
                      child: Material(
                        color: Colors.transparent, 
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
   
        ],
      ),
    );
  }

  
  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.white.withOpacity(0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }

  Widget _customButton({
    required String title,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.6),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}