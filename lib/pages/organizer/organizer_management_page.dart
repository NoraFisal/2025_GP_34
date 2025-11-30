import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/theme.dart';
import '/ui/components/mini_side_nav.dart';

class OrganizerManagementPage extends StatefulWidget {
  const OrganizerManagementPage({super.key});

  @override
  State<OrganizerManagementPage> createState() => _OrganizerManagementPageState();
}

class _OrganizerManagementPageState extends State<OrganizerManagementPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _infoCtrl = TextEditingController();

  Uint8List? _pickedBytes;
  String _photoBase64 = '';
  String? _photoUrl;
  DocumentReference<Map<String, dynamic>>? _docRef;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final uid = user.uid;
    _docRef = FirebaseFirestore.instance.collection('Organizer').doc(uid);

    final snap = await _docRef!.get();
    if (!snap.exists) {
      await _docRef!.set({
        'Name': 'Organizer',
        'Info': '',
        'ProfilePhoto': '',
        'ownerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final data = (await _docRef!.get()).data() ?? {};
    _nameCtrl.text = (data['Name'] ?? '').toString();
    _infoCtrl.text = (data['Info'] ?? '').toString();
   final photoData = (data['ProfilePhoto'] ?? '').toString();
if (photoData.startsWith('http')) {
  _photoUrl = photoData;
  _photoBase64 = '';
} else {
  _photoBase64 = photoData;
  _photoUrl = '';
}

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _infoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(' $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(' Make sure all required fields are completed ')));
      return;
    }
    if (_docRef == null) return;

    setState(() => _saving = true);
    try {
      String photoToSave = _photoBase64;
      if (_pickedBytes != null) {
        photoToSave = base64Encode(_pickedBytes!);
      }

      await _docRef!.set({
        'Name': _nameCtrl.text.trim(),
        'Info': _infoCtrl.text.trim(),
        'ProfilePhoto': photoToSave,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/organizerProfile');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profile Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          SafeArea(
            bottom: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const SizedBox(height: 12),

                // Avatar + Change
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: _buildAvatarPreview(),
                      ),
                      Positioned(
                        bottom: -8,
                        right: 10,
                        child: _glowPillButton(
                          label: _saving ? '...' : 'Change',
                          onTap: _saving ? null : _pickImage,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // fields
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Name'),
                      _field(_nameCtrl, maxLen: 32),

                      _label('Info'),
                      _field(_infoCtrl,
                          maxLines: 3,
                          hint: 'About the organizer (optional)',
                          validator: (v) => null),

                      const SizedBox(height: 18),

                      // Save: full width + glow
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9E2819),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          
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

  Widget _buildAvatarPreview() {
  
  if (_pickedBytes != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
    );
  }

 
  if (_photoBase64.isNotEmpty) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.memory(base64Decode(_photoBase64), fit: BoxFit.cover),
      );
    } catch (_) {}
  }

 
  if (_photoUrl != null && _photoUrl!.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(_photoUrl!, fit: BoxFit.cover),
    );
  }

 
  return const Icon(Icons.person, color: Colors.black45, size: 56);
}


  Widget _glowPillButton({required String label, VoidCallback? onTap}) {
    return Opacity(
      opacity: onTap == null ? 0.7 : 1,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
        ),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF9E2819),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c, {
    bool isNumber = false,
    int? maxLen,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLength: maxLen,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: AppColors.card,
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 6),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      );
}
