import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class EditTournamentPage extends StatefulWidget {
  final String tournamentId;

  const EditTournamentPage({super.key, required this.tournamentId});

  @override
  State<EditTournamentPage> createState() => _EditTournamentPageState();
}

class _EditTournamentPageState extends State<EditTournamentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  Uint8List? _pickedBytes;
  String _imageBase64 = '';

  DocumentReference<Map<String, dynamic>>? _docRef;
  Map<String, dynamic>? _originalData;

  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;
  bool _canEditDateTime = true;

  String _tournamentStatus = '';
  String _organizerId = '';
  bool _isOwner = false;

  // ===== Brand =====
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  // ===== X-like palette =====
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);

  bool _autoPopupOpen = false;

  @override
  void initState() {
    super.initState();
    _load();

    _titleCtrl.addListener(_checkChanges);
    _descriptionCtrl.addListener(_checkChanges);
    _detailsCtrl.addListener(_checkChanges);
    _dateCtrl.addListener(_checkChanges);
    _timeCtrl.addListener(_checkChanges);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _detailsCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _checkChanges() {
    if (_originalData == null) return;

    final hasChanges =
        _titleCtrl.text.trim() !=
            (_originalData!['Title'] ?? '').toString().trim() ||
        _descriptionCtrl.text.trim() !=
            (_originalData!['description'] ?? '').toString().trim() ||
        _detailsCtrl.text.trim() !=
            (_originalData!['details'] ?? '').toString().trim() ||
        _dateCtrl.text.trim() !=
            (_originalData!['date'] ?? '').toString().trim() ||
        _timeCtrl.text.trim() !=
            (_originalData!['time'] ?? '').toString().trim() ||
        _pickedBytes != null;

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  int _calculateDaysRemaining(String dateString) {
    try {
      final tournamentDate = DateFormat('yyyy-MM-dd').parse(dateString);
      final now = DateTime.now();
      final difference = tournamentDate.difference(now);
      return difference.inDays;
    } catch (e) {
      debugPrint('Error calculating days: $e');
      return 999; // رقم كبير للسماح بالتعديل في حالة الخطأ
    }
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        await _showAutoPopup("Please login to continue", danger: true);
        Navigator.pop(context);
      }
      return;
    }

    _docRef = FirebaseFirestore.instance
        .collection('Tournament')
        .doc(widget.tournamentId);

    final snap = await _docRef!.get();
    if (!snap.exists) {
      if (mounted) {
        await _showAutoPopup("Tournament not found", danger: true);
        Navigator.pop(context);
      }
      return;
    }

    final data = snap.data()!;
    _originalData = Map.from(data);

    // التحقق من الصلاحيات
    _organizerId = (data['organizerID'] ?? '').toString();
    _isOwner = _organizerId == user.uid;

    if (!_isOwner) {
      if (mounted) {
        await _showAutoPopup(
          "You don't have permission to edit this tournament",
          danger: true,
        );
        Navigator.pop(context);
      }
      return;
    }

    _tournamentStatus = (data['status'] ?? '').toString().toLowerCase();
    _titleCtrl.text = (data['Title'] ?? '').toString();
    _descriptionCtrl.text = (data['description'] ?? '').toString();
    _detailsCtrl.text = (data['details'] ?? '').toString();
    _dateCtrl.text = (data['date'] ?? '').toString();
    _timeCtrl.text = (data['time'] ?? '').toString();
    _imageBase64 = (data['image'] ?? '').toString();

    final dateString = _dateCtrl.text.trim();
    if (dateString.isNotEmpty) {
      final daysRemaining = _calculateDaysRemaining(dateString);
      _canEditDateTime = daysRemaining > 3 && _tournamentStatus != 'completed';
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

    // التحقق من حجم الصورة (حد أقصى 5 MB)
    const maxSize = 5 * 1024 * 1024; // 5 MB
    if (bytes.length > maxSize) {
      await _showAutoPopup("Image size too large (max 5 MB)", danger: true);
      return;
    }

    setState(() {
      _pickedBytes = bytes;
      _checkChanges();
    });
  }

  Future<void> _pickDate() async {
    if (_saving || !_canEditDateTime) return;

    final now = DateTime.now();
    final initialDate = _dateCtrl.text.isNotEmpty
        ? DateFormat('yyyy-MM-dd').parse(_dateCtrl.text)
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? initialDate : now,
      firstDate: now,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);

        // إعادة حساب إمكانية التعديل
        final daysRemaining = _calculateDaysRemaining(_dateCtrl.text);
        _canEditDateTime = daysRemaining > 3;

        _checkChanges();
      });
    }
  }

  Future<void> _pickTime() async {
    if (_saving || !_canEditDateTime) return;

    TimeOfDay initialTime = TimeOfDay.now();
    if (_timeCtrl.text.isNotEmpty) {
      try {
        final parts = _timeCtrl.text.split(':');
        if (parts.length == 2) {
          final hourMin = parts[1].split(' ');
          int hour = int.parse(parts[0]);
          final minute = int.parse(hourMin[0]);
          final period = hourMin.length > 1 ? hourMin[1] : '';

          if (period.toUpperCase() == 'PM' && hour != 12) {
            hour += 12;
          } else if (period.toUpperCase() == 'AM' && hour == 12) {
            hour = 0;
          }

          initialTime = TimeOfDay(hour: hour, minute: minute);
        }
      } catch (e) {
        debugPrint('Error parsing time: $e');
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeCtrl.text = picked.format(context);
        _checkChanges();
      });
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
                  'Are you sure you want to leave?\nYour changes will be lost.',
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

    if (!_isOwner) {
      await _showAutoPopup(
        "You don't have permission to edit this tournament",
        danger: true,
      );
      return;
    }

    if (_tournamentStatus == 'completed') {
      await _showAutoPopup("Cannot edit completed tournaments", danger: true);
      return;
    }

    final title = _titleCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final details = _detailsCtrl.text.trim();
    final date = _dateCtrl.text.trim();
    final time = _timeCtrl.text.trim();

    if (title.isEmpty) {
      await _showAutoPopup("Tournament name is required", danger: true);
      return;
    }
    if (description.isEmpty) {
      await _showAutoPopup("Description is required", danger: true);
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

    if (details.isNotEmpty && details.length < 10) {
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

    // التحقق من صيغة التاريخ
    try {
      final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
      final now = DateTime.now();

      // التحقق من أن التاريخ ليس في الماضي
      if (parsedDate.isBefore(DateTime(now.year, now.month, now.day))) {
        await _showAutoPopup(
          "Tournament date cannot be in the past",
          danger: true,
        );
        return;
      }

      // التحقق من قيود تعديل التاريخ
      final daysRemaining = _calculateDaysRemaining(date);
      if (date != _originalData!['date'] && daysRemaining <= 3) {
        await _showAutoPopup(
          "Cannot change date (3 days or less remaining)",
          danger: true,
        );
        return;
      }
    } catch (e) {
      await _showAutoPopup("Invalid date format", danger: true);
      return;
    }

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!_canEditDateTime) {
      return;
    }

    setState(() => _saving = true);

    try {
      String image = _imageBase64;
      if (_pickedBytes != null) {
        image = base64Encode(_pickedBytes!);
      }

      final updateData = {
        'Title': title,
        'description': description,
        'details': details,
        'date': date,
        'time': time,
        'image': image,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _docRef!.update(updateData);

      if (!mounted) return;

      if (_canEditDateTime) {
        await _showAutoPopup("Tournament updated successfully", success: true);
      }

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error updating tournament: $e');
      if (!mounted) return;

      String errorMessage = "Update failed";
      if (e.toString().contains('permission-denied')) {
        errorMessage = "Permission denied";
      } else if (e.toString().contains('not-found')) {
        errorMessage = "Tournament not found";
      } else if (e.toString().contains('network')) {
        errorMessage = "Network error, please try again";
      }

      await _showAutoPopup(errorMessage, danger: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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

  InputDecoration _xField(String labelText, {String? suffixText}) {
    return InputDecoration(
      labelText: labelText,
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _danger,
      ),
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
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _line.withOpacity(0.5)),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _danger),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _danger, width: 2),
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: _danger,
        height: 1.2,
      ),
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
                    const SizedBox(height: 16),

                    // Back arrow & Title
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
                              'Edit Tournament',
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
                              const SizedBox(height: 16),
                              _imageBlock(),

                              const SizedBox(height: 22),

                              TextFormField(
                                controller: _titleCtrl,
                                enabled: _canEditDateTime && !_saving,
                                maxLength: 50,
                                style: _fieldText.copyWith(
                                  color: _canEditDateTime ? _text : _muted,
                                ),
                                cursorColor: _accent,
                                decoration: _xField(
                                  'Tournament name',
                                  suffixText: !_canEditDateTime
                                      ? '(Locked)'
                                      : null,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (value.trim().length > 50) {
                                    return 'Max 50 characters';
                                  }
                                  return null;
                                },
                              ),
                              if (!_canEditDateTime) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    'Tournament name changes are disabled 3 days before the event to avoid player confusion.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                              TextFormField(
                                controller: _descriptionCtrl,
                                enabled: !_saving,
                                maxLines: 3,
                                maxLength: 500,
                                style: _fieldText,
                                cursorColor: _accent,
                                decoration: _xField('Description').copyWith(
                                  helperStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                  counterStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
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
                                decoration: _xField('Details').copyWith(
                                  helperStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                  counterStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                                validator: (value) {
                                  if (value != null &&
                                      value.trim().isNotEmpty &&
                                      value.trim().length < 10) {
                                    return 'Min 10 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Date Field
                              GestureDetector(
                                onTap: _canEditDateTime ? _pickDate : null,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _dateCtrl,
                                    enabled: _canEditDateTime && !_saving,
                                    style: _fieldText.copyWith(
                                      color: _canEditDateTime ? _text : _muted,
                                    ),
                                    decoration:
                                        _xField(
                                          'Date ',
                                          suffixText: !_canEditDateTime
                                              ? '(Locked)'
                                              : null,
                                        ).copyWith(
                                          suffixIcon: Icon(
                                            Icons.calendar_today,
                                            color: _canEditDateTime
                                                ? _accent
                                                : _muted,
                                            size: 20,
                                          ),
                                          helperText: _canEditDateTime
                                              ? 'yyyy-MM-dd format'
                                              : null,
                                          helperStyle: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            color: _muted,
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

                              // Time Field
                              GestureDetector(
                                onTap: _canEditDateTime ? _pickTime : null,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _timeCtrl,
                                    enabled: _canEditDateTime && !_saving,
                                    style: _fieldText.copyWith(
                                      color: _canEditDateTime ? _text : _muted,
                                    ),
                                    decoration:
                                        _xField(
                                          'Time ',
                                          suffixText: !_canEditDateTime
                                              ? '(Locked)'
                                              : null,
                                        ).copyWith(
                                          suffixIcon: Icon(
                                            Icons.access_time,
                                            color: _canEditDateTime
                                                ? _accent
                                                : _muted,
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

                              if (!_canEditDateTime) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _danger.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lock,
                                        color: _danger,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _tournamentStatus == 'completed'
                                              ? 'Tournament is completed - Date & Time locked'
                                              : 'Date & Time cannot be changed (3 days or less remaining)',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: _danger,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (_tournamentStatus == 'completed') ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _muted.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _muted.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: _muted,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This tournament is completed. Limited editing is allowed.',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: _muted,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 26),

                              // Save button
                              Center(
                                child: SizedBox(
                                  width: 176,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: (_saving || !_canEditDateTime) ? null : _save,
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
      ),
    );
  }

  Widget _imageBlock() {
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
              child: ClipOval(child: _buildImagePreview()),
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

  Widget _buildImagePreview() {
    ImageProvider? img;

    if (_pickedBytes != null) {
      img = MemoryImage(_pickedBytes!);
    } else if (_imageBase64.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(_imageBase64));
      } catch (_) {}
    }

    if (img != null) {
      return Image(image: img, fit: BoxFit.cover);
    }

    return Container(
      color: _accent.withOpacity(0.1),
      child: const Icon(Icons.emoji_events, color: _accent, size: 56),
    );
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
