import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/ui/components/mini_side_nav.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  static const Color _chipRed = Color(0xFF9E2819);

  final String email = 'sparktesport@gmail.com';
  final String phone = '+966551343813';
  final String instagram = 'https://instagram.com/spar.kteam';
  final String twitter = 'https://x.com/sparktesport';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Contact Us',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _contactTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email,
                      onTap: () => _launch('mailto:$email'),
                    ),

                    const SizedBox(height: 18),

                    _contactTile(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone,
                      onTap: () => _launch('tel:$phone'),
                    ),

                    const SizedBox(height: 18),

                    _contactTile(
                      icon: Icons.close,
                      label: 'Instagram',
                      value: 'spar.kteam',
                      onTap: () => _launch(instagram),
                    ),

                    const SizedBox(height: 18),

                    _contactTile(
                      icon: Icons.alternate_email,
                      label: 'X',
                      value: 'sparktesport',
                      onTap: () => _launch(twitter),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// ⭐ ADD MINI NAV HERE
          Positioned(
            left: 0,
            top: kToolbarHeight + 20,
            child: MiniSideNav(
              top: kToolbarHeight + 20,
              left: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _chipRed.withOpacity(0.9),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
