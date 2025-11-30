import 'package:flutter/material.dart';
import 'auth/login_page.dart'; 

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
         
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SPARK',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Saudi Platform for AI-Driven\nRecognition & Knowledge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromARGB(179, 255, 255, 255),
                    height: 1.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 30),
                
                SizedBox(
                  width: 200,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B2E2E),
                    ),
                    child: const Text(
                      'START',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ), 
        ],
      ),
    );
  }
}