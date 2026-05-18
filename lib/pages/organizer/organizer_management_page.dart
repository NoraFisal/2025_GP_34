import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class OrganizerManagementPage extends StatefulWidget {
  const OrganizerManagementPage({super.key});

  @override
  State<OrganizerManagementPage> createState() =>
      _OrganizerManagementPageState();
}

class _OrganizerManagementPageState extends State<OrganizerManagementPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  Uint8List? _pickedBytes;
  String _photoBase64 = '';
  String? _photoUrl;

  DocumentReference<Map<String, dynamic>>? _docRef;

  bool _loading = true;
  bool _saving = false;

  // ===== Brand =====
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  // ===== X-like palette =====
  static const Color _bg = Color(0xFFF7F7F7); // off-white
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);

  bool _autoPopupOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _docRef = FirebaseFirestore.instance.collection('Organizer').doc(user.uid);
    final snap = await _docRef!.get();
    final data = snap.data() ?? {};

    _nameCtrl.text = (data['Name'] ?? '').toString();
    _bioCtrl.text = (data['Info'] ?? '').toString();

    final photo = (data['ProfilePhoto'] ?? '').toString();
    if (photo.startsWith('http')) {
      _photoUrl = photo;
    } else {
      _photoBase64 = photo;
    }

    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    if (_saving) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );

    if (file == null) return;
    final bytes = await file.readAsBytes();

    setState(() {
      _pickedBytes = bytes;
    });
  }

  String? _nameErrorText(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Name is required';
    if (t.length > 24) return 'Name is too long';
    return null;
  }

  // ===== Auto popup (like player edit) =====
  Future<void> _showAutoPopup(
    String message, {
    bool success = false,
    bool danger = false,
  }) async {
    if (!mounted) return;
    if (_autoPopupOpen) return;

    _autoPopupOpen = true;

    final Color ring = danger ? _danger : _accent;
    final IconData icon = danger ? Icons.error_rounded : Icons.check_rounded;

    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.08),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
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
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: _text,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }

    _autoPopupOpen = false;
  }

  Future<void> _save() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      String photo = _photoBase64;
      if (_pickedBytes != null) {
        photo = base64Encode(_pickedBytes!);
      }

      await _docRef!.set({
        'Name': _nameCtrl.text.trim(),
        'Info': _bioCtrl.text.trim(),
        'ProfilePhoto': photo,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      await _showAutoPopup("Saved successfully", success: true);

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await _showAutoPopup("Save failed", danger: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== Typography (same style as player edit) =====
  TextStyle get _titleStyle => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
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
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _danger),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _danger, width: 2),
      ),
      errorStyle: const TextStyle(height: 0.0, fontSize: 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

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

                  // Back arrow: same feel as player edit
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
  onTap: _saving ? null : () => Navigator.pop(context),
  child: const Padding(
    padding: EdgeInsets.all(8),
    child: Icon(
      Icons.arrow_back_ios_new_rounded,
      color: _muted,
      size: 20,
    ),
  ),
),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Edit profile',
                          style: _titleStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 46),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _avatarBlock(),
                            const SizedBox(height: 22),

                            TextFormField(
                              controller: _nameCtrl,
                              enabled: !_saving,
                              maxLength: 24,
                              style: _fieldText,
                              cursorColor: _accent,
                              validator: (v) => _nameErrorText(v ?? ''),
                              decoration: _xField('Name'),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _bioCtrl,
                              enabled: !_saving,
                              maxLines: 3,
                              style: _fieldText,
                              cursorColor: _accent,
                              decoration: _xField('Bio'),
                            ),

                            const SizedBox(height: 26),

                            // Save button EXACT like player edit
                            Center(
                              child: SizedBox(
                                width: 176,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Save',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarBlock() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 152,
            height: 152,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accent, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.25),
                    blurRadius: 4,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(child: _buildAvatarPreview()),
            ),
          ),
          Positioned(
            right: -2,
            bottom: 18,
            child: _HoverPressPill(
              label: _saving ? '...' : 'Edit',
              onTap: _saving ? null : _pickImage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    ImageProvider? img;

    if (_pickedBytes != null) {
      img = MemoryImage(_pickedBytes!);
    } else if (_photoBase64.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(_photoBase64));
      } catch (_) {}
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      img = NetworkImage(_photoUrl!);
    }

    if (img != null) {
      return Image(image: img, fit: BoxFit.cover);
    }

    return const Icon(Icons.person, color: Colors.black45, size: 56);
  }
}

class _HoverPressPill extends StatefulWidget {
  const _HoverPressPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_HoverPressPill> createState() => _HoverPressPillState();
}

class _HoverPressPillState extends State<_HoverPressPill> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _down = false;
        }),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: _down ? 0.95 : (_hover ? 1.06 : 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(235, 61, 36, 1),
                borderRadius: BorderRadius.circular(46.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(246, 195, 188, 1).withOpacity(_hover ? 0.8 : 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}