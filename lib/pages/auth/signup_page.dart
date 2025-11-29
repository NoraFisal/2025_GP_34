//new
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _role = 'Player';
  String? _gender;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _birthDate;
  String? _birthDateError; 

 
  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2010, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9E2819), 
              surface: Color(0xFF1E1E1E), 
              onSurface: Colors.white,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF2C2C2C),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF9E2819),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'Player') {
  setState(() => _birthDateError = null); 

  if (_birthDate == null) {
    setState(() => _birthDateError = 'Date of birth is required');
    return;
  }

  int age = _calculateAge(_birthDate!);
  if (age < 13) {
    setState(() => _birthDateError = 'Not eligible — must be 13 or older');
    return;
  }

  if (_gender == null) {
    _showMessage('Please select your gender');
    return;
  }
}

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user!.uid;

      if (_role == 'Player') {
        final int age = _calculateAge(_birthDate!);
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
      _showMessage('Account created successfully as $_role ✅');
    } on FirebaseAuthException catch (e) {
      String msg = 'Sign up failed';
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'The email address is already in use';
          break;
        case 'weak-password':
          msg = 'Password is too weak (minimum 8 characters)';
          break;
        case 'invalid-email':
          msg = 'Please enter a valid email';
          break;
        default:
          msg = 'Authentication error: ${e.message}';
      }
      _showMessage(msg);
    } catch (e) {
      _showMessage('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF9E2819);

    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withOpacity(0.35)),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 0, right: 4),
              child: const CircleAvatar(
                radius: 40,
                backgroundImage: AssetImage('assets/images/logo.png'),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 30),
                          _label('Role Selection'),
                          Row(
                            children: [
                              Radio<String>(
                                value: 'Player',
                                groupValue: _role,
                                onChanged: (v) => setState(() => _role = v!),
                                activeColor: Colors.white,
                              ),
                              const Text('Player',
                                  style: TextStyle(color: Colors.white)),
                              const SizedBox(width: 20),
                              Radio<String>(
                                value: 'Organizer',
                                groupValue: _role,
                                onChanged: (v) => setState(() => _role = v!),
                                activeColor: Colors.white,
                              ),
                              const Text('Organizer',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _label('Name'),
                          const SizedBox(height: 8),
                          _textField(
                            controller: _fullNameController,
                            hint: 'Enter your name',
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Full name is required';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(v)) {
                                return 'Only letters and numbers allowed';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _label('Email'),
                          const SizedBox(height: 8),
                          _textField(
                            controller: _emailController,
                            hint: 'Enter your email',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email is required';
                              }
                              final pattern =
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
                              if (!RegExp(pattern).hasMatch(v)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _label('Password'),
                          const SizedBox(height: 8),
                          _textField(
                            controller: _passwordController,
                            hint: 'Enter your password',
                            obscure: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey.shade700,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              if (v.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              if (!RegExp(r'(?=.*[a-z])').hasMatch(v)) {
                                return 'Password must contain at least one lowercase letter';
                              }
                              if (!RegExp(r'(?=.*[A-Z])').hasMatch(v)) {
                                return 'Password must contain at least one uppercase letter';
                              }
                              if (!RegExp(r'(?=.*[!@#\$%^&*(),.?":{}|<>])')
                                  .hasMatch(v)) {
                                return 'Password must contain at least one special character';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _label('Confirm Password'),
                          const SizedBox(height: 8),
                          _textField(
                            controller: _confirmPasswordController,
                            hint: 'Re-enter your password',
                            obscure: _obscureConfirmPassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey.shade700,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                        
                          if (_role == 'Player') ...[
                            _label('Date of Birth'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _selectBirthDate,
                              child: AbsorbPointer(
                                child: _textField(
                                  controller: TextEditingController(
                                    text: _birthDate == null
                                        ? ''
                                        : DateFormat('yyyy-MM-dd')
                                            .format(_birthDate!),
                                  ),
                                  hint: 'Select your date of birth',
                                  validator: (v) {
                                    if (_birthDate == null) {
                                      return 'Date of birth is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            if (_birthDateError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _birthDateError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                           ),


                            const SizedBox(height: 20),
                            _label('Gender'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _gender,
                              hint: const Text(
                                'Select your gender',
                                style: TextStyle(color: Colors.black54),
                              ),
                              decoration: _fieldDecoration(''),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Male', child: Text('Male')),
                                DropdownMenuItem(
                                    value: 'Female', child: Text('Female')),
                              ],
                              onChanged: (value) =>
                                  setState(() => _gender = value),
                              validator: (v) {
                                if (v == null) {
                                  return 'Gender is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),
                          ],

                          _customButton(
                            title: 'Sign Up',
                            color: accentColor,
                            onPressed: _loading ? null : _handleSignup,
                            loading: _loading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

Positioned(
  top: 0,
  left: 16,
  child: SafeArea(
    child: Material(
      color: Colors.transparent, 
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 26,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    ),
  ),
),
        ],
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black87),
      decoration: _fieldDecoration(hint).copyWith(suffixIcon: suffix),
      validator: validator,
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      );

  Widget _customButton({
    required String title,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.6),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}