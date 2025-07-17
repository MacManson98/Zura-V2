// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';
import 'utils/debug_loader.dart';
import 'utils/themed_notifications.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              SizedBox(height: 60.h),
              _buildHeader(),
              SizedBox(height: 48.h),
              _buildAuthForm(),
              SizedBox(height: 24.h),
              _buildAuthButton(),
              SizedBox(height: 24.h),
              _buildDivider(),
              SizedBox(height: 24.h),
              _buildToggleAuth(),
              SizedBox(height: 24.h),
              _buildDevSignIn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            color: const Color(0xFFE5A00D),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Icon(
            Icons.movie,
            size: 40.sp,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          'Welcome to Zura',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Discover movies with friends',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Column(
      children: [
        if (!_isLogin) ...[
          _buildTextField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.person,
            keyboardType: TextInputType.name,
          ),
          SizedBox(height: 16.h),
        ],
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 16.h),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey[400],
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[400],
          fontSize: 14.sp,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.grey[400],
          size: 20.sp,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: const Color(0xFFE5A00D),
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 16.h,
        ),
      ),
    );
  }

  Widget _buildAuthButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAuth,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE5A00D),
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          disabledBackgroundColor: Colors.grey[700],
        ),
        child: _isLoading
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Text(
                _isLogin ? 'Sign In' : 'Sign Up',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey[700],
            thickness: 1,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'or',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey[700],
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleAuth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? "Don't have an account? " : "Already have an account? ",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14.sp,
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _toggleAuthMode,
          child: Text(
            _isLogin ? 'Sign Up' : 'Sign In',
            style: TextStyle(
              color: const Color(0xFFE5A00D),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevSignIn() {
    return TextButton(
      onPressed: _isLoading ? null : _handleDevSignIn,
      child: Text(
        'Dev Sign In',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12.sp,
        ),
      ),
    );
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ThemedNotifications.showError(context, 'Please fill in all fields');
      return;
    }

    if (!_isLogin && name.isEmpty) {
      ThemedNotifications.showError(context, 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? user;
      
      if (_isLogin) {
        user = await _authService.loginWithUsernameOrEmail(email, password);
      } else {
        user = await _authService.registerWithEmail(email, password);
      }

      if (user != null) {
        DebugLogger.log("✅ Auth successful: ${user.email}");
        // Navigation will be handled by MainNavigationV2 listening to auth state
      }
    } catch (e) {
      DebugLogger.log("❌ Auth error: $e");
      
      String errorMessage = 'Authentication failed';
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'No account found with this email';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Incorrect password';
      } else if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'An account with this email already exists';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password is too weak';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address';
      }
      
      // ignore: use_build_context_synchronously
      ThemedNotifications.showError(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDevSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInAsTestUser();
      
      if (user != null) {
        DebugLogger.log("✅ Dev sign in successful: ${user.email}");
        // Navigation will be handled by MainNavigationV2 listening to auth state
      }
    } catch (e) {
      DebugLogger.log("❌ Dev sign in error: $e");
      // ignore: use_build_context_synchronously
      ThemedNotifications.showError(context, 'Dev sign in failed');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}