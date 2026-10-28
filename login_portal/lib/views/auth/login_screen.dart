import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../controllers/auth_controller.dart';
import 'signup_screen.dart';
import '../dashboard/dashboard_wrapper.dart';
import 'forgot_password_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthController _authController = AuthController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateLockoutMessage(),
    );
  }

  Future<void> _updateLockoutMessage() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    final status = await _authController.checkLockoutStatus(email);
    if (status.isLocked && status.lockoutEnd != null) {
      final remaining = status.lockoutEnd!.difference(DateTime.now());
      if (remaining.isNegative) {
        if (mounted) setState(() => _errorMessage = null);
        _lockoutTimer?.cancel();
      } else {
        String formatted = '';
        if (remaining.inHours > 0) formatted += '${remaining.inHours}h ';
        final minutes = remaining.inMinutes.remainder(60);
        final seconds = remaining.inSeconds.remainder(60);
        formatted +=
            '${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
        if (mounted) {
          setState(() =>
              _errorMessage = 'Too many failed attempts. Try again in $formatted.');
        }
      }
    } else if (status.isLocked && status.lockoutEnd == null) {
      if (mounted) setState(() => _errorMessage = status.message);
      _lockoutTimer?.cancel();
    } else {
      if (_errorMessage != null &&
          (_errorMessage!.contains('Try again in') ||
              _errorMessage!.contains('account has been locked'))) {
        if (mounted) setState(() => _errorMessage = null);
      }
      _lockoutTimer?.cancel();
    }
  }

  // --- Login logic using AuthController (MVC) ---
  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await _authController.signIn(
      email: email,
      password: password,
    );

    if (!result.success) {
      if (mounted) {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
        if (result.isLocked && result.lockoutEnd != null) {
          _startLockoutTimer();
        }
      }
      return;
    }

    _lockoutTimer?.cancel();

    if (mounted) {
      final role = result.role ?? 'user';
      final roleDisplay =
          role == 'admin' ? 'Admin' : (role == 'teacher' ? 'Teacher' : 'Student');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, $roleDisplay!'),
          backgroundColor: AppColors.primaryPurple,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardWrapper()),
      );
    }
  }

  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 30),
                    Hero(
                      tag: 'app-logo',
                      child: Image.asset(
                        'assets/logo/logo.png',
                        height: 200,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.medical_services, size: 100, color: AppColors.primaryPurple),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Login In Now',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Please enter your details to access your account',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Error Message Display
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Email Input
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password Input
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        elevation: 5,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        child: Container(
                          height: 55,
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Login In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Sign Up Row at bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpPage()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
