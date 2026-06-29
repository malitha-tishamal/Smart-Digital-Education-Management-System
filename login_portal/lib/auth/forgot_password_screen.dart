import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _message;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Please enter your email.');
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await _auth.sendPasswordResetEmail(email: email);
      setState(() => _message = 'Password reset link sent to $email');
    } catch (e) {
      setState(() => _message = 'Failed to send reset email. Try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_reset, color: AppColors.primaryPurple, size: 24),
            SizedBox(width: 8),
            Text('Reset Password', style: TextStyle(color: AppColors.darkText)),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            Hero(
              tag: 'app-logo',
              child: Image.asset(
                'assets/logo/logo.png',
                height: 200,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.medical_services, size: 80, color: AppColors.primaryPurple),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter your email and we\'ll send you a link to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Email address',
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _message!,
                  style: TextStyle(color: _message!.contains('sent') ? Colors.green : Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            _buildGradientButton(
              text: _isLoading ? 'Sending...' : 'Send Reset Link',
              onPressed: _isLoading ? null : _resetPassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback? onPressed}) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
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
    );
  }
}