import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '../core/app_colors.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../core/dashboard_wrapper.dart';
import 'login_screen.dart'; 

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _auth = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedRole = 'user';

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    final pwd = _passwordController.text;
    setState(() {
      _hasMinLength = pwd.length >= 8;
      _hasUppercase = pwd.contains(RegExp(r'[A-Z]'));
      _hasLowercase = pwd.contains(RegExp(r'[a-z]'));
      _hasDigit = pwd.contains(RegExp(r'[0-9]'));
      _hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordStrong =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasDigit && _hasSpecial;

  // Form validators
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

  // 🔥 Sign up using AuthService (creates Auth + Firestore)
  Future<void> _handleSignUp() async {
    // Validate all fields using the form
    if (!_formKey.currentState!.validate()) {
      return;
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

    try {
      final AppUser? user = await _auth.signUpWithEmailPassword(
        email: email,
        password: password,
        name: name,
        nic: nic,
        mobile: mobile,
        role: _selectedRole,
      );

      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: AppColors.primaryPurple,
          ),
        );
        // Navigate directly to dashboard (DashboardWrapper handles role-based UI)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardWrapper()),
        );
      } else {
        setState(() => _errorMessage = 'Sign‑up failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      // Now this works because we imported firebase_auth
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

                  // Role
                  _buildRoleDropdown(),
                  const SizedBox(height: 16),

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

  // ----- Widget builders (unchanged) -----
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
            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              prefixIcon: Icon(icon, color: AppColors.primaryPurple),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
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
            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            validator: validator,
            decoration: InputDecoration(
              hintText: '*********',
              hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
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
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
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

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Role', style: TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
              prefixIcon: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primaryPurple),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (value) => setState(() => _selectedRole = value!),
            style: const TextStyle(color: AppColors.darkText),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryPurple),
          ),
        ),
      ],
    );
  }

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
              : [BoxShadow(color: AppColors.buttonGradientEnd.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
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