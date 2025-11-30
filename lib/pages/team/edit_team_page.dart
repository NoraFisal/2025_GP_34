// lib/pages/team/edit_team_page.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/ui/components/mini_side_nav.dart';

class EditTeamPage extends StatefulWidget {
  final String teamId;

  const EditTeamPage({super.key, required this.teamId});

  @override
  State<EditTeamPage> createState() => _EditTeamPageState();
}

class _EditTeamPageState extends State<EditTeamPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  Uint8List? _logoBytes; 
  String? _existingLogo; 

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("Team")
          .doc(widget.teamId)
          .get();

      if (snap.exists) {
        final data = snap.data()!;
        _nameCtrl.text = data["name"] ?? "";
        _descCtrl.text = data["description"] ?? "";
        _existingLogo = data["logoUrl"]; 
      }
    } catch (e) {
      debugPrint("❌ Error loading team: $e");
    }

    if (mounted) setState(() => _loading = false);
  }

  ImageProvider? _getTeamImage() {
    if (_logoBytes != null) {
      return MemoryImage(_logoBytes!);
    }

    if (_existingLogo != null && _existingLogo!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_existingLogo!));
      } catch (e) {
        debugPrint("❌ decode error: $e");
      }
    }

    return null;
  }

  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);

    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() {
        _logoBytes = bytes; 
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError("Team name cannot be empty");
      return;
    }

    setState(() => _saving = true);

    try {
      final updateData = {
        "name": _nameCtrl.text.trim(),
        "description": _descCtrl.text.trim(),
      };

      if (_logoBytes != null) {
        try {
          final b64 = base64Encode(_logoBytes!);
          updateData["logoUrl"] = b64;
        } catch (e) {
          debugPrint("❌ Base64 encode error: $e");
        }
      }

      await FirebaseFirestore.instance
          .collection("Team")
          .doc(widget.teamId)
          .update(updateData);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("❌ Save error: $e");
      if (mounted) _showError("Failed to save changes.\n$e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final teamImage = _getTeamImage();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Edit Team"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/background.png",
              fit: BoxFit.cover,
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      image: teamImage != null
                          ? DecorationImage(
                              image: teamImage,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: teamImage == null
                        ? const Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 30),

                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle("Team Name"),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: _inputStyle("Description"),
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _saving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB6382B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),

          /// ⭐ Add MiniSideNav HERE
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

  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }
}
