import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class NewTournamentPage extends StatefulWidget {
  const NewTournamentPage({super.key});

  @override
  State<NewTournamentPage> createState() => _NewTournamentPageState();
}

class _NewTournamentPageState extends State<NewTournamentPage> {
  // ===== Brand =====
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  // ===== X-like palette =====
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _otherGameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  Uint8List? _pickedBytes;
  String _selectedGame = '';
  String _selectedTier = '';

  bool _hasChanges = false;

  final List<Map<String, dynamic>> _gameOptions = [
    {
      'value': 'PUBG',
      'label': 'PUBG',
      'desc': 'Battle Royale survival game',
      'image': 'assets/images/pubg.png',
      'color': const Color(0xFF3b82f6),
    },
    {
      'value': 'league of legends',
      'label': 'League of Legends',
      'desc': 'The classic MOBA experience',
      'image': 'assets/images/lol.png',
      'color': const Color(0xFFc9aa6c),
    },
    {
      'value': 'Dota 2',
      'label': 'Dota 2',
      'desc': 'Competitive MOBA by Valve',
      'image': 'assets/images/dota2.png',
      'color': const Color(0xFFb91c1c),
    },
    {
      'value': 'Other',
      'label': 'Other',
      'desc': 'Add a different game',
      'image': '',
      'color': const Color(0xFF64748b),
    },
  ];

  final List<Map<String, dynamic>> _tierOptions = [
    {
      'value': 'Beginner',
      'label': 'Beginner',
      'desc': 'For newcomers and casual players',
      'icon': Icons.shield_outlined,
      'color': const Color(0xFF22c55e),
    },
    {
      'value': 'Intermediate',
      'label': 'Intermediate',
      'desc': 'Players with solid fundamentals',
      'icon': Icons.shield,
      'color': const Color(0xFFf59e0b),
    },
    {
      'value': 'Pro',
      'label': 'Pro',
      'desc': 'Top-tier competitive players',
      'icon': Icons.shield_moon,
      'color': const Color(0xFFef4444),
    },
  ];

  bool _saving = false;
  bool _autoPopupOpen = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_checkChanges);
    _descCtrl.addListener(_checkChanges);
    _detailsCtrl.addListener(_checkChanges);
    _dateCtrl.addListener(_checkChanges);
    _timeCtrl.addListener(_checkChanges);
    _otherGameCtrl.addListener(_checkChanges);
    _locationCtrl.addListener(_checkChanges);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _detailsCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _otherGameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _checkChanges() {
    final hasChanges =
        _nameCtrl.text.trim().isNotEmpty ||
        _descCtrl.text.trim().isNotEmpty ||
        _detailsCtrl.text.trim().isNotEmpty ||
        _dateCtrl.text.trim().isNotEmpty ||
        _timeCtrl.text.trim().isNotEmpty ||
        _selectedGame.isNotEmpty ||
        _selectedTier.isNotEmpty ||
        _pickedBytes != null ||
        _otherGameCtrl.text.trim().isNotEmpty ||
        _locationCtrl.text.trim().isNotEmpty;

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _showExitDialog() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
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
                    border: Border.all(color: _accent, width: 2),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: _accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Leave Create Tournament?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your progress will not be saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _muted,
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
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _muted,
                          side: const BorderSide(color: _line),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Leave',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
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
  }

  // ===== Image Picker =====
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
    setState(() => _pickedBytes = bytes);
  }

  // ===== Date & Time =====
  Future<void> _selectDate() async {
    if (_saving) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2030),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _accent,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  Future<void> _selectTime() async {
    if (_saving) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _accent,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Colors.white,
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            hourMinuteTextStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 36,
              fontWeight: FontWeight.w600,
            ),
            dayPeriodTextStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            helpTextStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _timeCtrl.text = picked.format(context);
      setState(() {});
    }
  }

  // ===== Auto popup =====
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

  // ===== Save =====
  Future<void> _createTournament() async {
    if (_saving) return;

    // Validation: Game
    if (_selectedGame.isEmpty) {
      await _showAutoPopup("Please select a game", danger: true);
      return;
    }

    final finalGame = _selectedGame == 'Other'
        ? _otherGameCtrl.text.trim()
        : _selectedGame;

    if (_selectedGame == 'Other' && finalGame.isEmpty) {
      await _showAutoPopup("Please enter the game name", danger: true);
      return;
    }

    // Validation: Tier
    if (_selectedTier.isEmpty) {
      await _showAutoPopup("Please select a tier", danger: true);
      return;
    }

    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final details = _detailsCtrl.text.trim();
    final date = _dateCtrl.text.trim();
    final time = _timeCtrl.text.trim();
    final location = _locationCtrl.text.trim();

    if (name.isEmpty) {
      await _showAutoPopup("Tournament name is required", danger: true);
      return;
    }

    if (description.isEmpty) {
      await _showAutoPopup("Description is required", danger: true);
      return;
    }

    if (description.length < 10) {
      await _showAutoPopup(
        "Description must be at least 10 characters",
        danger: true,
      );
      return;
    }

    if (description.length > 500) {
      await _showAutoPopup(
        "Description must not exceed 500 characters",
        danger: true,
      );
      return;
    }

    if (details.isEmpty) {
      await _showAutoPopup("Details are required", danger: true);
      return;
    }

    if (details.length < 10) {
      await _showAutoPopup(
        "Details must be at least 10 characters",
        danger: true,
      );
      return;
    }

    if (details.length > 2000) {
      await _showAutoPopup(
        "Details must not exceed 2000 characters",
        danger: true,
      );
      return;
    }

    if (date.isEmpty) {
      await _showAutoPopup("Date is required", danger: true);
      return;
    }

    if (time.isEmpty) {
      await _showAutoPopup("Time is required", danger: true);
      return;
    }

    if (location.isEmpty) {
      await _showAutoPopup("Location is required", danger: true);
      return;
    }

    try {
      final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
      final now = DateTime.now();

      if (parsedDate.isBefore(DateTime(now.year, now.month, now.day))) {
        await _showAutoPopup(
          "Tournament date cannot be in the past",
          danger: true,
        );
        return;
      }
    } catch (e) {
      await _showAutoPopup("Invalid date format", danger: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      final image = _pickedBytes != null ? base64Encode(_pickedBytes!) : '';

      await FirebaseFirestore.instance.collection('Tournament').add({
        'Title': name,
        'description': description,
        'details': details,
        'date': date,
        'time': time,
        'game': finalGame,
        'location': location,
        'tier': _selectedTier,
        'image': image,
        'organizerID': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'upcoming',
      });

      if (!mounted) return;

      await _showAutoPopup("Tournament created successfully!", success: true);

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await _showAutoPopup("Failed to create tournament", danger: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== Typography =====
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
      errorStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: _danger,
        height: 1.2,
      ),
      counterStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: _muted,
      ),
      helperStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: _muted,
      ),
    );
  }

  // ===== Section Label =====
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxW = math.min(600.0, w - 48);

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          await _showExitDialog();
          return false;
        }
        return true;
      },
      child: Scaffold(
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

                    // Back arrow
                    Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _HoverTap(
                            onTap: _saving ? () {} : _showExitDialog,
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: _muted,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'New Tournament',
                              style: _titleStyle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
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
                                style: _fieldText,
                                cursorColor: _accent,
                                decoration: _xField('Tournament name'),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _descCtrl,
                                enabled: !_saving,
                                maxLines: 3,
                                maxLength: 500,
                                style: _fieldText,
                                cursorColor: _accent,
                                decoration: _xField('Description'),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (value.trim().length < 10) {
                                    return 'Min 10 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _detailsCtrl,
                                enabled: !_saving,
                                maxLines: 3,
                                maxLength: 2000,
                                style: _fieldText,
                                cursorColor: _accent,
                                decoration: _xField('Details'),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (value.trim().length < 10) {
                                    return 'Min 10 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              GestureDetector(
                                onTap: _selectDate,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _dateCtrl,
                                    enabled: !_saving,
                                    style: _fieldText,
                                    cursorColor: _accent,
                                    decoration: _xField('Date').copyWith(
                                      helperText: 'yyyy-MM-dd format',
                                      suffixIcon: const Icon(
                                        Icons.calendar_today,
                                        color: _accent,
                                        size: 20,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      try {
                                        DateFormat('yyyy-MM-dd').parse(value);
                                      } catch (e) {
                                        return 'Invalid format';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              GestureDetector(
                                onTap: _selectTime,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _timeCtrl,
                                    enabled: !_saving,
                                    style: _fieldText,
                                    cursorColor: _accent,
                                    decoration: _xField('Time').copyWith(
                                      suffixIcon: const Icon(
                                        Icons.access_time,
                                        color: _accent,
                                        size: 20,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _locationCtrl,
                                enabled: !_saving,
                                style: _fieldText,
                                cursorColor: _accent,
                                decoration: _xField('Location').copyWith(
                                  helperText:
                                      'Example: Riyadh Boulevard / Online',
                                  suffixIcon: const Icon(
                                    Icons.location_on_outlined,
                                    color: _accent,
                                    size: 20,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // ─── Game Selection ───
                              _sectionLabel('SELECT GAME'),
                              Column(
                                children: List.generate(_gameOptions.length, (
                                  i,
                                ) {
                                  final game = _gameOptions[i];
                                  final isSelected =
                                      _selectedGame == game['value'];

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i < _gameOptions.length - 1
                                          ? 10
                                          : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: _saving
                                          ? null
                                          : () => setState(
                                              () =>
                                                  _selectedGame = game['value'],
                                            ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _accent.withOpacity(0.07)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected ? _accent : _line,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Image
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? _accent.withOpacity(0.12)
                                                    : _muted.withOpacity(0.12),
                                              ),
                                              child: ClipOval(
                                                child:
                                                    game['image']
                                                        .toString()
                                                        .isNotEmpty
                                                    ? Image.asset(
                                                        game['image'],
                                                        width: 42,
                                                        height: 42,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .sports_esports_rounded,
                                                        color: isSelected
                                                            ? _accent
                                                            : _muted,
                                                        size: 22,
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Label + Desc
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    game['label'],
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 15,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: isSelected
                                                          ? _accent
                                                          : _text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    game['desc'],
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 12,
                                                      color: _muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Radio indicator
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? _accent
                                                      : _line,
                                                  width: isSelected ? 2 : 1.5,
                                                ),
                                                color: isSelected
                                                    ? _accent
                                                    : Colors.transparent,
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 14,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              if (_selectedGame == 'Other') ...[
                                const SizedBox(height: 14),

                                TextFormField(
                                  controller: _otherGameCtrl,
                                  enabled: !_saving,
                                  style: _fieldText,
                                  cursorColor: _accent,
                                  decoration: _xField('Game name').copyWith(
                                    suffixIcon: const Icon(
                                      Icons.sports_esports_rounded,
                                      color: _accent,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_selectedGame == 'Other' &&
                                        (value == null ||
                                            value.trim().isEmpty)) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 24),

                              // ─── Tier Selection ───
                              _sectionLabel('SELECT TIER'),
                              Column(
                                children: List.generate(_tierOptions.length, (
                                  i,
                                ) {
                                  final tier = _tierOptions[i];
                                  final isSelected =
                                      _selectedTier == tier['value'];
                                  final Color tierColor = tier['color'];

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i < _tierOptions.length - 1
                                          ? 10
                                          : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: _saving
                                          ? null
                                          : () => setState(
                                              () =>
                                                  _selectedTier = tier['value'],
                                            ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? tierColor.withOpacity(0.07)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? tierColor
                                                : _line,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Icon
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: tierColor.withOpacity(
                                                  0.12,
                                                ),
                                              ),
                                              child: Icon(
                                                tier['icon'],
                                                color: tierColor,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Label + Desc
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tier['label'],
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 15,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: isSelected
                                                          ? tierColor
                                                          : _text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    tier['desc'],
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 12,
                                                      color: _muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Radio indicator
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? tierColor
                                                      : _line,
                                                  width: isSelected ? 2 : 1.5,
                                                ),
                                                color: isSelected
                                                    ? tierColor
                                                    : Colors.transparent,
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 14,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 28),

                              // Create button
                              Center(
                                child: SizedBox(
                                  width: 176,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _saving
                                        ? null
                                        : _createTournament,
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
                                            'Create',
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
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    }
    return const Icon(Icons.emoji_events, color: Colors.black45, size: 56);
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
                    color: const Color.fromRGBO(
                      246,
                      195,
                      188,
                      1,
                    ).withOpacity(_hover ? 0.8 : 0.5),
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

class _HoverTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _HoverTap({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<_HoverTap> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final canHover =
        Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;

    final scale = _down ? 0.98 : (_hover && canHover ? 1.02 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: (_hover && canHover)
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
