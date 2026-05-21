import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

  final Set<String> _gameIds = {};

  String _currentPhotoB64 = '';
  Uint8List? _pickedBytes;

  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  bool _showAge = true;
  bool _showCity = true;
  bool _showGender = true;

  String _originalName = '';
  String _originalCity = '';
  String _originalDobText = '';
  String _originalPhotoB64 = '';
  bool _originalShowAge = true;
  bool _originalShowCity = true;
  bool _originalShowGender = true;
  Set<String> _originalGameIds = {};

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);

  bool _autoPopupOpen = false;

  String _normalizeGameId(String raw) {
    final s = raw.toLowerCase().trim();

    if (s == 'lol' ||
        s == 'leagueoflegends' ||
        s == 'league of legends' ||
        s == 'league of legend' ||
        s == 'league') {
      return 'lol';
    }

    if (s == 'pubg' || s == 'playerunknown battlegrounds') return 'pubg';

    if (s == 'dota' || s == 'dota2' || s == 'dota 2') return 'dota2';

    if (s == 'valorant' || s == 'val') return '';

    return s;
  }

  String _gameLabelFromId(String id) {
    switch (id) {
      case 'lol':
        return 'League of Legends';
      case 'pubg':
        return 'PUBG';
      case 'dota2':
        return 'Dota 2';
      default:
        return id;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();

    _nameCtrl.addListener(_checkChanges);
    _cityCtrl.addListener(_checkChanges);
    _dobCtrl.addListener(_checkChanges);
  }

  void _checkChanges() {
    final hasChanges =
        _nameCtrl.text.trim() != _originalName.trim() ||
        _cityCtrl.text.trim() != _originalCity.trim() ||
        _dobCtrl.text.trim() != _originalDobText.trim() ||
        _pickedBytes != null ||
        _showAge != _originalShowAge ||
        _showCity != _originalShowCity ||
        _showGender != _originalShowGender ||
        !_setsEqual(_gameIds, _originalGameIds);

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  bool _setsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b) && b.containsAll(a);
  }

  Future<void> _load() async {
    try {
      await PlayerService.ensureMeDoc();
      final me = await PlayerService.getMe();

      if (me != null) {
        _nameCtrl.text = me.username;
        _cityCtrl.text = me.city;

        _gameIds
          ..clear()
          ..addAll(
            (me.games)
                .map((e) => _normalizeGameId(e))
                .where((id) => id.isNotEmpty),
          );

        _currentPhotoB64 = me.profilePhoto ?? '';
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('Player').doc(uid).get();
        final data = doc.data() ?? {};

        final rawDob = data['dob'] ?? data['BirthDate'] ?? data['dobText'];
        DateTime? parsedDob;
        if (rawDob is Timestamp) parsedDob = rawDob.toDate();
        if (rawDob is String) parsedDob = _tryParseDob(rawDob);

        if (parsedDob != null) {
          _dob = parsedDob;
          _dobCtrl.text = _formatDob(parsedDob);
        }

        final vAge = data['showAge'];
        final vCity = data['showCity'];
        final vGender = data['showGender'];

        if (vAge is bool) _showAge = vAge;
        if (vCity is bool) _showCity = vCity;
        if (vGender is bool) _showGender = vGender;

        if (vCity == null) {
          _showCity = _cityCtrl.text.trim().isNotEmpty;
        }

        final ids = data['gameIds'];
        if (ids is List) {
          _gameIds
            ..clear()
            ..addAll(ids.map((e) => _normalizeGameId('$e')).where((id) => id.isNotEmpty));
        } else {
          final legacyGame = data['Game'];
          final newGames = data['games'];

          List<dynamic>? rawGames;
          if (newGames is List) rawGames = newGames;
          if (rawGames == null && legacyGame is List) rawGames = legacyGame;

          if (rawGames != null) {
            _gameIds
              ..clear()
              ..addAll(
                rawGames
                    .map((e) => _normalizeGameId((e ?? '').toString()))
                    .where((id) => id.isNotEmpty),
              );
          }
        }

        final p = data['profilePhoto'] ?? data['ProfilePhoto'];
        if (p is String && p.isNotEmpty) _currentPhotoB64 = p;
      }

      _originalName = _nameCtrl.text;
      _originalCity = _cityCtrl.text;
      _originalDobText = _dobCtrl.text;
      _originalPhotoB64 = _currentPhotoB64;
      _originalShowAge = _showAge;
      _originalShowCity = _showCity;
      _originalShowGender = _showGender;
      _originalGameIds = Set<String>.from(_gameIds);
    } catch (e) {
      if (mounted) {
        await _showAutoPopup("Load error", danger: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _tryParseDob(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    try {
      return DateFormat('dd/MM/yyyy').parseStrict(s);
    } catch (_) {}

    try {
      return DateFormat('yyyy-MM-dd').parseStrict(s);
    } catch (_) {}

    return null;
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
    if (_saving) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 21, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
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
      _checkChanges();
    }
  }

  Future<void> _pickImage() async {
    if (_saving) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _pickedBytes = bytes);
    _checkChanges();
  }

  String? _nameErrorText(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Name is required';
    if (t.length > 24) return 'Name is too long';
    return null;
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

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final computedAge = _dob != null ? _calcAge(_dob!) : null;

      var photoB64 = _currentPhotoB64;
      if (_pickedBytes != null) {
        photoB64 = base64Encode(_pickedBytes!);
      }

      final ids = _gameIds.toList();
      final labels = ids.map(_gameLabelFromId).toList();

      await PlayerService.updateMe(
        username: _nameCtrl.text.trim(),
        age: computedAge ?? 18,
        city: _cityCtrl.text.trim(),
        games: labels,
        profilePhoto: photoB64,
      );

      final update = <String, dynamic>{
        'username': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'age': computedAge ?? 18,
        'gameIds': ids,
        'games': labels,
        'profilePhoto': photoB64,

        'Name': _nameCtrl.text.trim(),
        'City': _cityCtrl.text.trim(),
        'Age': computedAge ?? 18,
        'Game': labels,
        'ProfilePhoto': photoB64,

        'showAge': _showAge,
        'showCity': _showCity,
        'showGender': _showGender,

        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_dob != null) {
        update['dob'] = Timestamp.fromDate(_dob!);
        update['dobText'] = _formatDob(_dob!);
        update['BirthDate'] = Timestamp.fromDate(_dob!);
      }

      await FirebaseFirestore.instance.collection('Player').doc(uid).set(
            update,
            SetOptions(merge: true),
          );

      if (!mounted) return;

      await _showAutoPopup("Saved successfully", success: true);

      Navigator.pop(context, {
        'showAge': _showAge,
        'showCity': _showCity,
        'showGender': _showGender,
      });
    } catch (e) {
      if (!mounted) return;
      await _showAutoPopup("Save failed", danger: true);
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

  TextStyle get _sectionLabel => const TextStyle(
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
      errorStyle: const TextStyle(height: 0.0, fontSize: 0.0),
    );
  }

  BoxDecoration _xCard() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _lineDivider() => Container(height: 1, color: _line);

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
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _saving ? null : _showExitDialog,
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
                                controller: _cityCtrl,
                                enabled: !_saving,
                                style: _fieldText,
                                cursorColor: _accent,
                                decoration: _xField('City'),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _pickDob,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: _dobCtrl,
                                    enabled: !_saving,
                                    style: _fieldText,
                                    cursorColor: _accent,
                                    decoration: _xField('Birth date'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                decoration: _xCard(),
                                child: Column(
                                  children: [
                                    _switchRow('Show Age', _showAge, (v) {
                                      setState(() => _showAge = v);
                                      _checkChanges();
                                    }),
                                    _lineDivider(),
                                    _switchRow('Show City', _showCity, (v) {
                                      setState(() => _showCity = v);
                                      _checkChanges();
                                    }),
                                    _lineDivider(),
                                    _switchRow('Gender', _showGender, (v) {
                                      setState(() => _showGender = v);
                                      _checkChanges();
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text('Game', style: _sectionLabel),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: _xCard(),
                                child: Column(
                                  children: [
                                    _gameTile('lol'),
                                    _lineDivider(),
                                    _gameTile('pubg'),
                                    _lineDivider(),
                                    _gameTile('dota2'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
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
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _text,
              ),
            ),
          ),
          XSwitch(
            value: value,
            onChanged: _saving ? null : onChanged,
            accent: _accent,
            border: _line,
            onTrack: _dark,
            offTrack: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _gameTile(String id) {
    final label = _gameLabelFromId(id);
    final checked = _gameIds.contains(id);

    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      value: checked,
      onChanged: _saving
          ? null
          : (v) {
              setState(() {
                if (v == true) {
                  _gameIds.add(id);
                } else {
                  _gameIds.remove(id);
                }
              });
              _checkChanges();
            },
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: _text,
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) return _accent;
        return Colors.white;
      }),
      checkColor: Colors.white,
      side: const BorderSide(color: _line, width: 2),
      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
    if (_pickedBytes != null) return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    if (_currentPhotoB64.isNotEmpty) {
      try {
        return Image.memory(base64Decode(_currentPhotoB64), fit: BoxFit.cover);
      } catch (_) {}
    }
    return const Icon(Icons.person, color: Colors.black45, size: 56);
  }
}

class XSwitch extends StatelessWidget {
  const XSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
    required this.border,
    required this.onTrack,
    required this.offTrack,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  final Color accent;
  final Color border;
  final Color onTrack;
  final Color offTrack;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;

    final trackColor = value ? accent : const Color(0xFFD1D5DB);
    final thumbColor = Colors.white;

    return Opacity(
      opacity: disabled ? 0.65 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged?.call(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: thumbColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
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
                    color: const Color.fromRGBO(246, 195, 188, 1)
                        .withOpacity(_hover ? 0.8 : 0.5),
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
