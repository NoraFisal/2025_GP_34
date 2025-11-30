import 'dart:typed_data';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '/ui/theme.dart';
import '../../services/player/player_service.dart';

class PlayerProfileEditPage extends StatefulWidget {
  const PlayerProfileEditPage({super.key});
  @override
  State<PlayerProfileEditPage> createState() => _PlayerProfileEditPageState();
}

class _PlayerProfileEditPageState extends State<PlayerProfileEditPage> {
  
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  final _dobCtrl = TextEditingController();
  DateTime? _dob;

  final Set<String> _games = {};

  
  String _currentPhotoB64 = '';   
  Uint8List? _pickedBytes;       

  bool _loading = true;
  bool _saving = false;

  // NEW: visibility toggles (passed back to profile page; NOT saved to DB)
  bool _showAge = true;
  bool _showCity = true;
  bool _showGender = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PlayerService.ensureMeDoc();
    final me = await PlayerService.getMe();
    if (me != null) {
      _nameCtrl.text = me.username;
      _cityCtrl.text = me.city;
      _games..clear()..addAll(me.games);
     _currentPhotoB64 = me.profilePhoto ??'';
      // reasonable defaults when opening editor
      _showCity = me.city.trim().isNotEmpty;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  
  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    final hadBirthday =
        (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) years--;
    return years.clamp(0, 200);
  }

  String _formatDob(DateTime dob) => DateFormat('dd/MM/yyyy').format(dob);

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 21, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.cardDeep,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = _formatDob(picked);
      });
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر اختيار الصورة: $e')),
      );
    }
  }

  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكمل الحقول المطلوبة')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final computedAge = _dob != null ? _calcAge(_dob!) : 18;

                String photoB64ToSave = _currentPhotoB64;
          if (_pickedBytes != null) {
            photoB64ToSave = base64Encode(_pickedBytes!); 
          }

          await PlayerService.updateMe(
            username: _nameCtrl.text.trim(),
            age: computedAge,
            city: _cityCtrl.text.trim(),
            games: _games.toList(),
            profilePhoto: photoB64ToSave,
          );


      if (!mounted) return;
      // Return visibility choices to the profile page (no DB changes)
      Navigator.pop(context, {
        'showAge': _showAge,
        'showCity': _showCity,
        'showGender': _showGender,
      });
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
        centerTitle: true, // CENTERED TITLE (requested)
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: const Text('Profile Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: const [SizedBox(width: 12)],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          _formBody(context),
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

  Widget _formBody(BuildContext context) {
    return SafeArea(
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

       
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Name'),
                _field(_nameCtrl, maxLen: 24), // Name required (default validator)

                _label('City'),
                _field(_cityCtrl, validator: (v) => null), // City OPTIONAL

                _label('Birth date (dd/mm/yyyy)'),
                GestureDetector(
                  onTap: _saving ? null : _pickDob,
                  child: AbsorbPointer(
                    child: _field(
                      _dobCtrl,
                      hint: 'Tap to pick your birth date',
                      validator: (v) => null,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                // NEW: visibility toggles (only UI; not stored in DB)
                SwitchListTile.adaptive(
                  value: _showAge,
                  onChanged: _saving ? null : (v) => setState(() => _showAge = v),
                  title: const Text('Show Age ', style: TextStyle(color: Colors.white)),
                  activeColor: AppColors.accent,
                ),
                SwitchListTile.adaptive(
                  value: _showCity,
                  onChanged: _saving ? null : (v) => setState(() => _showCity = v),
                  title: const Text('Show City ', style: TextStyle(color: Colors.white)),
                  activeColor: AppColors.accent,
                ),
                SwitchListTile.adaptive(
                  value: _showGender,
                  onChanged: _saving ? null : (v) => setState(() => _showGender = v),
                  title: const Text('Show Gender ', style: TextStyle(color: Colors.white)),
                  activeColor: AppColors.accent,
                ),

                const SizedBox(height: 12),
                const Text('Game',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),

                Card(
                  color: AppColors.cardDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _gameTile('League of Legends'),
                      _divider(),
                      _gameTile('VALORANT'),
                      _divider(),
                      _gameTile('CS2'),
                    ],
                  ),
                ),

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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildAvatarPreview() {
  if (_pickedBytes != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
    );
  }
  if (_currentPhotoB64.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.memory(base64Decode(_currentPhotoB64), fit: BoxFit.cover),
    );
  }
  return const Icon(Icons.person, color: Colors.black45, size: 56);
}



  // Game checkbox
  Widget _gameTile(String name) {
    final checked = _games.contains(name);
    return CheckboxListTile(
      value: checked,
      onChanged: (v) {
        setState(() {
          if (v == true) {
            _games.add(name);
          } else {
            _games.remove(name);
          }
        });
      },
      title: Text(name, style: const TextStyle(color: Colors.white)),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.accent,
      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _divider() => const Divider(height: 0, color: Colors.white24);

  Widget _field(
    TextEditingController c, {
    bool isNumber = false,
    int? maxLen,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLength: maxLen,
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
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
