import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ForgotPswdScreen extends StatefulWidget {
  const ForgotPswdScreen({Key? key}) : super(key: key);

  @override
  _ForgotPswdScreenState createState() => _ForgotPswdScreenState();
}

class _ForgotPswdScreenState extends State<ForgotPswdScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isLoading = false;

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    ThemeProvider themeProvider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        style: TextStyle(color: themeProvider.textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white60 : Colors.black45,
          ),
          filled: true,
          fillColor:
              themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      _showErrorDialog('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );
      setState(() => _isOtpSent = true);
      _showSuccessDialog('Password reset email sent! Check your inbox.');
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? 'An error occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _verifyOTP() {
    if (_otpController.text.isEmpty) {
      _showErrorDialog('Please enter the OTP');
      return;
    }
    // Note: Firebase's default password reset flow uses email links rather than OTP
    // This is a placeholder for custom OTP verification logic
    _showSuccessDialog('OTP verified successfully!');
  }

  void _showErrorDialog(String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Error',
              style: TextStyle(color: themeProvider.textColor),
            ),
            content: Text(
              message,
              style: TextStyle(color: themeProvider.textColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog(String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Success',
              style: TextStyle(color: themeProvider.textColor),
            ),
            content: Text(
              message,
              style: TextStyle(color: themeProvider.textColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Forgot Password',
          style: TextStyle(color: themeProvider.textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Enter your registered email',
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
            ),
            const SizedBox(height: 10),
            _buildTextField('Email', _emailController, themeProvider),
            const SizedBox(height: 20),
            if (!_isOtpSent)
              ElevatedButton(
                onPressed: _isLoading ? null : _sendPasswordResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2296F3),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send Reset Email'),
              ),
            if (_isOtpSent) ...[
              const SizedBox(height: 20),
              Text(
                'Enter OTP sent to your email',
                style: TextStyle(fontSize: 16, color: themeProvider.textColor),
              ),
              const SizedBox(height: 10),
              _buildTextField('Enter OTP', _otpController, themeProvider),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2296F3),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Verify OTP'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
