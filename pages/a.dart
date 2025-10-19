import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class APage extends StatefulWidget {
  const APage({Key? key}) : super(key: key);

  @override
  State<APage> createState() => _APageState();
}

class _APageState extends State<APage> {
  bool _loading = false;

  Future<void> _handleContinue(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is signed in.')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome back, Player!')),
          );
          Navigator.pushReplacementNamed(context, '/homepage');
        } else if (organizerDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome back, Organizer!')),
          );
          Navigator.pushReplacementNamed(context, '/organizerProfile');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User role not found. Contact support.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your email is not verified yet. Please check your inbox.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const Color accentColor = Color(0xFF9E2819);

    return Scaffold(
      body: Stack(
        children: [
          // 🔹 الخلفية
          Image.asset(
            'assets/images/Background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // 🔹 طبقة شفافية فقط للتأثير (لا تمنع الضغط)
          IgnorePointer(
            ignoring: true,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          // 🔹 المحتوى الأساسي
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const SizedBox(height: 100),
                const Center(
                  child: Text(
                    'Verified Page',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                Center(
                  child: user != null
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 30, 36, 43),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Welcome, ${user.email}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),

                              user.emailVerified
                                  ? const Text(
                                      "Your email is verified!",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.green,
                                      ),
                                    )
                                  : const Text(
                                      "Please verify your email.",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),

                              const SizedBox(height: 20),

                              MaterialButton(
                                textColor: Colors.white,
                                color: accentColor,
                                onPressed: () async {
                                  await user.sendEmailVerification();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Verification email sent!')),
                                  );
                                },
                                child: const Text("Click to Send Verification Email"),
                              ),
                              const SizedBox(height: 10),

                              MaterialButton(
                                textColor: Colors.white,
                                color: Colors.green,
                                onPressed: _loading
                                    ? null
                                    : () async {
                                        await _handleContinue(context);
                                      },
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text("Continue"),
                              ),
                            ],
                          ),
                        )
                      : const Text(
                          "No user is signed in.",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),

          // 🔹 الشعار
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

          // 🔹 زر الرجوع (في الأعلى دوماً)
          Positioned(
            top: 40,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/signup');
                },
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}