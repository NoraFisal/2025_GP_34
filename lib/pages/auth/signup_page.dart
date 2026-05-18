import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _danger = Color.fromRGBO(199, 0, 0, 1);
  static const Color _success = Color(0xFF00BA7C);

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _birthDateTextController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  String _role = 'Player';
  String? _gender;
  DateTime? _birthDate;

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;

  bool hasLower = false;
  bool hasUpper = false;
  bool hasSpecial = false;
  bool hasMinLength = false;
  bool _passwordsMatch = true;

  bool emailNotEmpty = false;
  bool emailHasAt = false;
  bool emailHasDot = false;
  bool emailValidFormat = false;

  bool _emailFocused = false;
  bool _passwordFocused = false;

  String? _birthDateError;

  @override
  void initState() {
    super.initState();
    _recalcEmail(_emailController.text);
    _recalcPassword(_passwordController.text);
    _recalcMatch(_confirmPasswordController.text);
    _emailFocusNode.addListener(() {
      setState(() => _emailFocused = _emailFocusNode.hasFocus);
    });
    _passwordFocusNode.addListener(() {
      setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateTextController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showPopup(String message, {bool success = false, bool danger = false}) async {
    if (!mounted) return;
    final Color ring = danger ? _danger : (success ? _success : _accent);
    final IconData icon = danger
        ? Icons.error_rounded
        : (success ? Icons.check_circle_rounded : Icons.info_rounded);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
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
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
                child: Icon(icon, color: ring, size: 32),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center, style: _bodyStyle),
              const SizedBox(height: 14),
              SizedBox(
                width: 140, height: 36,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _line),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _titleStyle => const TextStyle(
        fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w900,
        letterSpacing: -0.5, color: _accent,
      );
  TextStyle get _fieldText => const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w400, color: _text);
  TextStyle get _labelInside => const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w400, color: _muted);
  TextStyle get _floatingLabel => const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400, color: _muted);
  TextStyle get _errorStyle => const TextStyle(color: _danger, fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w400, height: 1.2);
  TextStyle get _bodyStyle => const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400, color: _text, height: 1.25);

  InputDecoration _xField(String labelText, {Widget? suffix}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: _labelInside,
      floatingLabelStyle: _floatingLabel,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 22, bottom: 10),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _line)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _accent, width: 2)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _danger)),
      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _danger, width: 2)),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      errorStyle: const TextStyle(height: 0.0, fontSize: 0.0),
    );
  }

  Widget _fieldBlock({required Widget field, String? errorText, double gapAfter = 16}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        if (errorText != null && errorText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(errorText, style: _errorStyle),
        ],
        SizedBox(height: gapAfter),
      ],
    );
  }

  void _recalcEmail(String email) {
    final e = email.trim();
    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    setState(() {
      emailNotEmpty = e.isNotEmpty;
      emailHasAt = e.contains('@');
      emailHasDot = e.contains('.');
      emailValidFormat = RegExp(pattern).hasMatch(e);
    });
  }

  void _recalcPassword(String password) {
    setState(() {
      hasLower = RegExp(r'[a-z]').hasMatch(password);
      hasUpper = RegExp(r'[A-Z]').hasMatch(password);
      hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
      hasMinLength = password.length >= 8;
    });
  }

  void _recalcMatch(String confirmValue) {
    setState(() => _passwordsMatch = confirmValue == _passwordController.text);
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) age--;
    return age;
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2010, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent, onPrimary: Colors.white, onSurface: Colors.black),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateError = null;
        _birthDateTextController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String? _nameErrorText() {
    if (!_submitted) return null;
    final v = _fullNameController.text.trim();
    if (v.isEmpty) return 'Full name is required';
    if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(v)) return 'Only letters and numbers allowed';
    return null;
  }

  String? _emailErrorText() {
    if (!_submitted) return null;
    final v = _emailController.text.trim();
    if (v.isEmpty) return 'Email is required';
    const p = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    if (!RegExp(p).hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  String? _passwordErrorText() {
    if (!_submitted) return null;
    final v = _passwordController.text;
    if (v.isEmpty) return 'Password is required';
    if (!hasMinLength) return 'Password must be at least 8 characters';
    if (!hasLower) return 'Must contain lowercase letter';
    if (!hasUpper) return 'Must contain uppercase letter';
    if (!hasSpecial) return 'Must contain special character';
    return null;
  }

  String? _confirmErrorText() {
    if (!_submitted) return null;
    final v = _confirmPasswordController.text;
    if (v.isEmpty) return 'Please confirm your password';
    if (!_passwordsMatch) return 'Passwords do not match';
    return null;
  }

  Future<void> _handleSignup() async {
    setState(() => _submitted = true);
    _recalcEmail(_emailController.text);
    _recalcPassword(_passwordController.text);
    _recalcMatch(_confirmPasswordController.text);

    final hasErrors = _nameErrorText() != null || _emailErrorText() != null ||
        _passwordErrorText() != null || _confirmErrorText() != null;
    if (hasErrors) return;

    if (_role == 'Player') {
      setState(() => _birthDateError = null);
      if (_birthDate == null) { setState(() => _birthDateError = 'Date of birth is required'); return; }
      final age = _calculateAge(_birthDate!);
      if (age < 13) { setState(() => _birthDateError = 'Not eligible — must be 13 or older'); return; }
      if (_gender == null) { await _showPopup('Please select your gender', danger: true); return; }
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user!.uid;

      if (_role == 'Player') {
        final age = _calculateAge(_birthDate!);
        await FirebaseFirestore.instance.collection('Player').doc(uid).set({
          'Name': _fullNameController.text.trim(),
          'Email': _emailController.text.trim(),
          'Age': age,
          'BirthDate': Timestamp.fromDate(_birthDate!),
          'Gender': _gender,
          'City': '',
          'Game': <String>[],
          'ProfilePhoto': "",
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('Organizer').doc(uid).set({
          'Name': _fullNameController.text.trim(),
          'Email': _emailController.text.trim(),
          'ProfilePhoto': "",
          'Info': 'Manages tournaments',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await cred.user!.updateDisplayName(_fullNameController.text.trim());
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/a');
    } on FirebaseAuthException catch (e) {
      String msg = 'Sign up failed';
      switch (e.code) {
        case 'email-already-in-use': msg = 'The email address is already in use'; break;
        case 'weak-password': msg = 'Password is too weak (minimum 8 characters)'; break;
        case 'invalid-email': msg = 'Please enter a valid email'; break;
        default: msg = 'Authentication error: ${e.message}';
      }
      await _showPopup(msg, danger: true);
    } catch (e) {
      await _showPopup('Unexpected error: $e', danger: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _checkItem(String text, bool ok) {
    const Color inactive = Color.fromRGBO(136, 153, 166, 1);
    final Color active = ok ? const Color.fromARGB(255, 4, 154, 104) : inactive;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: ok ? active : inactive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400, height: 1.2, color: ok ? active : inactive)),
          ),
        ],
      ),
    );
  }

  Widget _pillChoice({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF3C4043) : Colors.white,
              border: Border.all(color: const Color(0xFF8899A6), width: selected ? 0 : 2),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: _muted, fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400, height: 1)),
        ],
      ),
    );
  }

  Widget _roleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role', style: _labelInside),
        const SizedBox(height: 12),
        Row(
          children: [
            _pillChoice(label: 'Player', selected: _role == 'Player', onTap: () => setState(() { _role = 'Player'; _birthDateError = null; })),
            const SizedBox(width: 20),
            _pillChoice(label: 'Organizer', selected: _role == 'Organizer', onTap: () => setState(() {
              _role = 'Organizer'; _gender = null; _birthDate = null;
              _birthDateTextController.text = ''; _birthDateError = null;
            })),
          ],
        ),
      ],
    );
  }

  Widget _genderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: _labelInside),
        const SizedBox(height: 12),
        Row(
          children: [
            _pillChoice(label: 'Male', selected: _gender == 'Male', onTap: () => setState(() => _gender = 'Male')),
            const SizedBox(width: 20),
            _pillChoice(label: 'Female', selected: _gender == 'Female', onTap: () => setState(() => _gender = 'Female')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxW = math.min(600.0, w - 48);

    final nameErr = _nameErrorText();
    final emailErr = _emailErrorText();
    final passErr = _passwordErrorText();
    final confirmErr = _confirmErrorText();

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

                  // ===== HEADER - السهم + العنوان + اللوقو على نفس المستوى =====
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // السهم - ثابت الحجم
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        splashRadius: 18,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF536471)),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      ),
                      const SizedBox(width: 4),

                      // العنوان - يأخذ كل المساحة ويتكيف مع حجم الشاشة
                      Expanded(
  child: Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'Create account',
        textAlign: TextAlign.center,
        style: _titleStyle,
      ),
    ),
  ),
),

                      // اللوقو - صغير ومتناسب
                      Image.asset(
                        'assets/images/Logo_Spark.png',
                        width: 75,
                        height: 75,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _roleSelection(),
                          const SizedBox(height: 22),

                          _fieldBlock(
                            errorText: nameErr,
                            field: TextField(
                              controller: _fullNameController,
                              style: _fieldText,
                              cursorColor: _accent,
                              decoration: _xField('Name'),
                              onChanged: (_) { if (_submitted) setState(() {}); },
                            ),
                          ),

                          _fieldBlock(
                            errorText: emailErr,
                            gapAfter: 10,
                            field: TextField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              style: _fieldText,
                              cursorColor: _accent,
                              decoration: _xField('Email'),
                              onChanged: (v) { _recalcEmail(v); if (_submitted) setState(() {}); },
                            ),
                          ),

                          if (_emailFocused || _emailController.text.isNotEmpty) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _checkItem("Email is not empty", emailNotEmpty),
                                _checkItem("Contains @", emailHasAt),
                                _checkItem("Contains domain (.com, .sa, ...)", emailHasDot),
                                _checkItem("Valid email format", emailValidFormat),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],

                          _fieldBlock(
                            errorText: passErr,
                            gapAfter: 10,
                            field: TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: _obscurePassword,
                              style: _fieldText,
                              cursorColor: _accent,
                              decoration: _xField('Password',
                                suffix: IconButton(
                                  padding: EdgeInsets.zero,
                                  splashRadius: 18,
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: _muted),
                                ),
                              ),
                              onChanged: (v) {
                                _recalcPassword(v);
                                _recalcMatch(_confirmPasswordController.text);
                                if (_submitted) setState(() {});
                              },
                            ),
                          ),

                          if (_passwordFocused || _passwordController.text.isNotEmpty) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _checkItem("At least 8 characters", hasMinLength),
                                _checkItem("Lowercase letter", hasLower),
                                _checkItem("Uppercase letter", hasUpper),
                                _checkItem("Special character", hasSpecial),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],

                          _fieldBlock(
                            errorText: confirmErr,
                            field: TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: _fieldText,
                              cursorColor: _accent,
                              decoration: _xField('Confirm password',
                                suffix: IconButton(
                                  padding: EdgeInsets.zero,
                                  splashRadius: 18,
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 18, color: _muted),
                                ),
                              ),
                              onChanged: (v) { _recalcMatch(v); if (_submitted) setState(() {}); },
                            ),
                          ),

                          if (_role == 'Player') ...[
                            _fieldBlock(
                              errorText: _submitted ? _birthDateError : null,
                              field: GestureDetector(
                                onTap: _selectBirthDate,
                                child: AbsorbPointer(
                                  child: TextField(
                                    controller: _birthDateTextController,
                                    style: _fieldText,
                                    cursorColor: _accent,
                                    decoration: _xField('Date of birth'),
                                  ),
                                ),
                              ),
                            ),
                            _genderSelection(),
                            const SizedBox(height: 22),
                          ],

                          const SizedBox(height: 10),

                          Center(
                            child: SizedBox(
                              width: 176,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleSignup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Create', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                        ],
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
}