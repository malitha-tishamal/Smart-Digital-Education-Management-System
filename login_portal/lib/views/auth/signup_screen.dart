import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // added for Firestore
import '../../core/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';


import 'login_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthController _authController = AuthController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // UI state
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Role & Stream
  String _selectedRole = 'user';
  String? _selectedStream;
  List<String> _selectedSubjects = [];

  // AL Year for students
  String? _selectedALYear;
  final List<String> _alYears = List.generate(11, (i) => (2020 + i).toString());

  // ---- Student ID ----
  String _generatedStudentId = '';
  bool _isGeneratingId = false;

  // Password strength
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;

  // Subjects per stream
  final Map<String, List<String>> _subjectsByStream = {
    'Science': [
      'Biology / Combined Maths',
      'Physics',
      'Chemistry / Agriculture / ICT',
    ],
    'Commerce': [
      'Accounting',
      'Business Studies',
      'Economics / ICT',
    ],
    'Arts': [
      'Sinhala / Tamil / English',
      'Geography',
      'History',
      'Political Science',
      'Economics',
      'Logic',
      'Media Studies',
      'Music / Dancing / Drama / Art',
      'Languages (French, Japanese, etc.)',
    ],
    'Technology': [
      'Science for Technology (compulsory)',
      'Engineering Technology',
      'Bio Systems Technology',
      'ICT',
    ],
  };

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    final pwd = _passwordController.text;
    final strength = _authController.calculatePasswordStrength(pwd);
    setState(() {
      _hasMinLength = strength.hasMinLength;
      _hasUppercase = strength.hasUppercase;
      _hasLowercase = strength.hasLowercase;
      _hasDigit = strength.hasDigit;
      _hasSpecial = strength.hasSpecial;
    });
  }

  bool get _isPasswordStrong =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasDigit && _hasSpecial;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nicController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    super.dispose();
  }

  // ---------- Validators ----------
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your full name';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validateNIC(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your NIC';
    final nicRegex = RegExp(r'^[0-9]{9}[Vv]$|^[0-9]{12}$');
    if (!nicRegex.hasMatch(value.trim())) {
      return 'Enter a valid NIC (e.g., 123456789V or 12 digits)';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your mobile number';
    final mobileRegex = RegExp(r'^[0-9]{10}$');
    if (!mobileRegex.hasMatch(value.trim())) return 'Enter a valid 10‑digit mobile number';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (!_isPasswordStrong) return 'Password is not strong enough (see requirements below)';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ---- Generate Student ID ----
  Future<void> _generateStudentId(String stream) async {
    if (_selectedRole != 'user') return;
    if (stream.isEmpty) {
      setState(() => _generatedStudentId = '');
      return;
    }

    setState(() => _isGeneratingId = true);
    final studentId = await _authController.generateStudentId(
      stream: stream,
      role: _selectedRole,
    );
    if (mounted) {
      setState(() {
        _generatedStudentId = studentId;
        _isGeneratingId = false;
      });
    }
  }

  // ---------- Sign-up logic ----------
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate stream & subjects for non-admin
    if (_selectedRole != 'admin') {
      if (_selectedStream == null || _selectedStream!.isEmpty) {
        setState(() => _errorMessage = 'Please select a stream');
        return;
      }
      if (_selectedSubjects.isEmpty) {
        setState(() => _errorMessage = 'Please select at least one subject');
        return;
      }
    }

    // Validate AL Year only for students
    if (_selectedRole == 'user' && (_selectedALYear == null || _selectedALYear!.isEmpty)) {
      setState(() => _errorMessage = 'Please select your A/L Year');
      return;
    }

    // Ensure student ID is generated (for students)
    if (_selectedRole == 'user' && _generatedStudentId.isEmpty) {
      // Generate now if not generated (e.g., if stream was selected but ID not generated)
      await _generateStudentId(_selectedStream!);
      if (_generatedStudentId.isEmpty) {
        setState(() => _errorMessage = 'Failed to generate Student ID. Please try again.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final nic = _nicController.text.trim();
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text;
    final stream = (_selectedRole == 'admin') ? '' : _selectedStream!;
    final subjects = (_selectedRole == 'admin') ? <String>[] : _selectedSubjects;
    final alYear = (_selectedRole == 'user') ? _selectedALYear! : '';
    final studentId = (_selectedRole == 'user') ? _generatedStudentId : '';

    try {
      final AppUser? appUser = await _authController.signUp(
        email: email,
        password: password,
        name: name,
        nic: nic,
        mobile: mobile,
        role: _selectedRole,
        stream: stream,
        subjects: subjects,
        alYear: alYear,
        studentId: studentId,
      );

      if (appUser != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please wait for admin approval.'),
            backgroundColor: AppColors.primaryPurple,
            duration: Duration(seconds: 3),
          ),
        );

        await _authController.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        setState(() => _errorMessage = 'Sign‑up failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Please login.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Please choose a stronger one.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection and try again.';
          break;
        default:
          message = e.message ?? 'Sign‑up failed. Please try again.';
      }
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fill in your details to get started',
                    style: TextStyle(color: AppColors.darkText, fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  // Name
                  _buildInputField(
                    label: 'Full Name',
                    hint: 'John Doe',
                    icon: Icons.person_outline,
                    controller: _nameController,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _buildInputField(
                    label: 'Email',
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // NIC
                  _buildInputField(
                    label: 'NIC',
                    hint: '123456789V or 12 digits',
                    icon: Icons.badge_outlined,
                    controller: _nicController,
                    validator: _validateNIC,
                  ),
                  const SizedBox(height: 16),

                  // Mobile
                  _buildInputField(
                    label: 'Mobile Number',
                    hint: '0712345678',
                    icon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                    controller: _mobileController,
                    validator: _validateMobile,
                  ),
                  const SizedBox(height: 16),

                  // Role dropdown
                  _buildRoleDropdown(),
                  const SizedBox(height: 16),

                  // Stream & Subjects (hidden for admin)
                  if (_selectedRole != 'admin') ...[
                    _buildStreamDropdown(),
                    const SizedBox(height: 16),
                    if (_selectedStream != null) _buildSubjectSelection(),
                    const SizedBox(height: 16),
                  ],

                  // ---- Student ID (only for students) ----
                  if (_selectedRole == 'user')
                    _buildStudentIdField(),

                  // AL Year dropdown (only for students)
                  if (_selectedRole == 'user') _buildALYearDropdown(),
                  if (_selectedRole == 'user') const SizedBox(height: 16),

                  // Password
                  _buildPasswordField(
                    label: 'Password',
                    controller: _passwordController,
                    obscure: !_isPasswordVisible,
                    onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 8),

                  // Strength indicators
                  _buildStrengthIndicator('At least 8 characters', _hasMinLength),
                  _buildStrengthIndicator('At least one uppercase letter', _hasUppercase),
                  _buildStrengthIndicator('At least one lowercase letter', _hasLowercase),
                  _buildStrengthIndicator('At least one digit', _hasDigit),
                  _buildStrengthIndicator('At least one special character', _hasSpecial),
                  const SizedBox(height: 12),

                  // Confirm Password
                  _buildPasswordField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    obscure: !_isConfirmPasswordVisible,
                    onToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 12),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),

                  _buildGradientButton(
                    text: _isLoading ? 'Creating Account...' : 'Sign Up',
                    onPressed: _isLoading ? null : _handleSignUp,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(fontSize: 14, color: AppColors.darkText),
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginPage()),
                                ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Widget Builders ----------

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.inputBorder.withValues(alpha: 0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              prefixIcon: Icon(icon, color: AppColors.primaryPurple),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            validator: validator,
            decoration: InputDecoration(
              hintText: '*********',
              hintStyle: TextStyle(color: AppColors.inputBorder.withValues(alpha: 0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryPurple),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
                onPressed: onToggle,
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Student ID field ----
  Widget _buildStudentIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Student ID',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: TextFormField(
            controller: TextEditingController(text: _generatedStudentId),
            enabled: false,
            style: TextStyle(
              color: _generatedStudentId.isNotEmpty ? AppColors.primaryPurple : Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: _isGeneratingId ? 'Generating...' : 'Select stream to generate ID',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primaryPurple),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.2), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (_generatedStudentId.isNotEmpty)
          const Text(
            'This ID will be permanently assigned to you.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }

  // ----- Role dropdown -----
  Widget _buildRoleDropdown() {
    return _buildDropdownField(
      label: 'Role',
      value: _selectedRole,
      items: const [
        DropdownMenuItem(value: 'user', child: Text('Student')),
        DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
        DropdownMenuItem(value: 'admin', child: Text('Admin')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedRole = value!;
          if (_selectedRole == 'admin') {
            _selectedStream = null;
            _selectedSubjects.clear();
          }
          if (_selectedRole != 'user') {
            _selectedALYear = null;
            _generatedStudentId = '';
          } else {
            // If switching to student and stream is selected, generate ID
            if (_selectedStream != null && _selectedStream!.isNotEmpty) {
              _generateStudentId(_selectedStream!);
            }
          }
        });
      },
      icon: Icons.admin_panel_settings_outlined,
    );
  }

  // ----- Stream dropdown -----
  Widget _buildStreamDropdown() {
    final label = _selectedRole == 'teacher' ? 'Teaching Stream' : 'Stream';
    return _buildDropdownField(
      label: label,
      value: _selectedStream,
      items: _subjectsByStream.keys.map((stream) {
        return DropdownMenuItem<String>(
          value: stream,
          child: Text(stream),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedStream = value;
          _selectedSubjects.clear();
          // If student, regenerate ID with new stream
          if (_selectedRole == 'user' && value != null && value.isNotEmpty) {
            _generateStudentId(value);
          } else {
            _generatedStudentId = '';
          }
        });
      },
      icon: Icons.school_outlined,
    );
  }

  // ----- AL Year dropdown -----
  Widget _buildALYearDropdown() {
    return _buildDropdownField(
      label: 'A/L Year',
      value: _selectedALYear,
      items: _alYears.map((year) {
        return DropdownMenuItem<String>(
          value: year,
          child: Text(year),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedALYear = value;
        });
      },
      icon: Icons.calendar_today_outlined,
    );
  }

  // ----- Generic dropdown -----
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
              prefixIcon: Icon(icon, color: AppColors.primaryPurple),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
            items: items,
            onChanged: onChanged,
            validator: validator,
            style: const TextStyle(color: AppColors.darkText),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryPurple),
          ),
        ),
      ],
    );
  }

  // ----- Subject checkboxes -----
  Widget _buildSubjectSelection() {
    if (_selectedStream == null) return const SizedBox.shrink();
    final subjects = _subjectsByStream[_selectedStream!] ?? [];
    if (subjects.isEmpty) return const SizedBox.shrink();

    final title = _selectedRole == 'teacher' ? 'Select Teaching Subjects' : 'Select Subjects';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        ...subjects.map((subject) {
          return CheckboxListTile(
            title: Text(subject),
            value: _selectedSubjects.contains(subject),
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  _selectedSubjects.add(subject);
                } else {
                  _selectedSubjects.remove(subject);
                }
              });
            },
            activeColor: AppColors.primaryPurple,
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }).toList(),
        if (_selectedSubjects.isEmpty && _errorMessage != null && _errorMessage!.contains('subject'))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Please select at least one subject',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    );
  }

  // ----- Strength indicator -----
  Widget _buildStrengthIndicator(String label, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(satisfied ? Icons.check_circle : Icons.cancel,
              color: satisfied ? Colors.green : Colors.grey, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: satisfied ? Colors.green : Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  // ----- Gradient button -----
  Widget _buildGradientButton({required String text, required VoidCallback? onPressed}) {
    final bool isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isDisabled
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600])
              : const LinearGradient(
                  colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: isDisabled
              ? []
              : [BoxShadow(color: AppColors.buttonGradientEnd.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}