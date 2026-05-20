import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditTeamPage extends StatefulWidget {
  final String teamId;

  const EditTeamPage({super.key, required this.teamId});

  @override
  State<EditTeamPage> createState() => _EditTeamPageState();
}

class _EditTeamPageState extends State<EditTeamPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  Uint8List? _logoBytes;
  bool _loading = false;

  // ===== Login / Signup palette =====
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _grayBtn = Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
Future<bool> _confirmExitEdit() async {
  final shouldLeave = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (ctx) {
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
            border: Border.all(color: const Color(0xFFCFD9DE)),
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
                  border: Border.all(color: _accent, width: 2),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your changes will not be saved. Are you sure you want to leave?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
                        side: const BorderSide(color: Color(0xFFCFD9DE)),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Leave'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return shouldLeave ?? false;
}
  // ======================
  // Load team 
  // ======================
  Future<void> _loadTeam() async {
    final doc =
        await FirebaseFirestore.instance.collection('Team').doc(widget.teamId).get();

    if (!doc.exists) return;

    final d = doc.data() ?? {};
    _nameCtrl.text = (d['name'] ?? '').toString();
    _descCtrl.text = (d['description'] ?? '').toString();

    final logo = (d['logoUrl'] ?? '').toString();
    if (logo.isNotEmpty && !logo.startsWith('http')) {
      try {
        final cleaned = logo.contains(',') ? logo.split(',').last : logo;
        _logoBytes = base64Decode(cleaned);
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  // ======================
  // Pick logo 
  // ======================
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (xf == null) return;

    final bytes = await xf.readAsBytes();
    if (mounted) setState(() => _logoBytes = bytes);
  }

  // ======================
  // Save 
  // ======================
  Future<void> _save() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('Team').doc(widget.teamId).update({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_logoBytes != null)
          'logoUrl': 'data:image/png;base64,${base64Encode(_logoBytes!)}',
      });

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ======================
  // UI
  // ======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,

       
       leading: IconButton(
  icon: const Icon(
    Icons.arrow_back_ios_new_rounded,
    size: 18,
    color: Color(0xFF6B7280),
  ),
 onPressed: () async {
  if (await _confirmExitEdit()) {
    if (mounted) Navigator.pop(context);
  }
},
),


        title: const Text(
          'Team Management',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _accent,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== LOGO =====
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _accent, width: 3),
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: _logoBytes == null
                          ? const Icon(Icons.groups, size: 48, color: Colors.black38)
                          : Image.memory(_logoBytes!, fit: BoxFit.cover),
                    ),
                  ),

                  // Edit pill
                  Positioned(
                    right: -4,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ===== NAME FIELD =====
            _UnderlineField(
              label: 'Team name',
              controller: _nameCtrl,
            ),

            const SizedBox(height: 26),

            // ===== DESCRIPTION FIELD =====
            _UnderlineField(
              label: 'Description',
              controller: _descCtrl,
              maxLines: 3,
            ),

            const SizedBox(height: 40),

            // ===== SAVE BUTTON =====
            Center(
              child: SizedBox(
                width: 210,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _grayBtn,
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
                          'Save',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// Login / Signup underline field
// ======================================================
class _UnderlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _UnderlineField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF0F1419),
      ),
      decoration: const InputDecoration(
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color.fromRGBO(235, 61, 36, 1),
            width: 1.6,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFFCED4DA),
            width: 1,
          ),
        ),
      ).copyWith(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF536471),
        ),
      ),
    );
  }
}
