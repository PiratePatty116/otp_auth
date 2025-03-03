// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

// Define app color scheme
class AppColors {
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color background = Color(0xFFF5F5F5);
  static const Color card = Colors.white;
  static const Color error = Color(0xFFB00020);
  static const Color text = Color(0xFF333333);
  static const Color textLight = Color(0xFF757575);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          background: AppColors.background,
          error: AppColors.error,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: AppColors.text,
                displayColor: AppColors.text,
              ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.all(20),
          labelStyle: const TextStyle(color: AppColors.textLight),
        ),
      ),
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // States
  bool _isLoading = false;
  bool _otpSent = false;
  String _verificationId = '';
  bool _isSignup = false;
  UserCredential? _tempUserCredential;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // Twilio credentials
  final String _twilioSid = 'ENTER_YOUR_SID';
  final String _twilioAuth = 'ENTER_YOUR_AUTH';
  final String _twilioPhone = 'ENTER_PHONE_NUMBER';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SizedBox(
              height: screenHeight - 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Logo/Header section
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    isLogin
                        ? (_otpSent ? 'Verify Your Identity' : 'Welcome Back')
                        : (_otpSent
                            ? 'Verify Your Phone'
                            : 'Create Your Account'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Subtitle
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text(
                      _otpSent
                          ? 'Enter the OTP code sent to your phone'
                          : (isLogin
                              ? 'Sign in to continue'
                              : 'Fill in your details to get started'),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form fields
                  Expanded(
                    child: _buildFormFields(),
                  ),

                  // Bottom section with buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        )
                      else if (_otpSent)
                        _buildPrimaryButton('Verify OTP', _verifyOtp)
                      else
                        _buildPrimaryButton(
                            isLogin ? 'Login' : 'Send OTP & Sign Up',
                            isLogin ? _login : _sendSignupOtp),
                      if (!_otpSent)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                              _otpSent = false;
                              _clearFields();
                              _animationController.reset();
                              _animationController.forward();
                            });
                          },
                          child: Text(
                            isLogin
                                ? 'Need to create an account? Sign Up'
                                : 'Already have an account? Login',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_otpSent || isLogin)
          _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: !_otpSent,
          ),
        if (!_otpSent || isLogin)
          _buildInputField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
            enabled: !_otpSent,
          ),
        if (!isLogin && !_otpSent)
          _buildInputField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
        if (!isLogin && !_otpSent)
          _buildInputField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            helperText:
                'Enter your phone number with country code (e.g., +1234567890)',
          ),
        if (_otpSent)
          _buildInputField(
            controller: _otpController,
            label: 'OTP Code',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            helperText: 'Enter the 6-digit code sent to your phone',
          ),
        const Spacer(),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool enabled = true,
    String? helperText,
  }) {
    // For password fields, we'll handle a suffix icon
    Widget? suffixIcon;

    // Check if this is a password field
    if (obscureText) {
      // Determine which password field we're dealing with
      bool isPasswordVisible = false;
      VoidCallback toggleVisibility;

      if (controller == _passwordController) {
        isPasswordVisible = _passwordVisible;
        toggleVisibility = () {
          setState(() {
            _passwordVisible = !_passwordVisible;
          });
        };
      } else if (controller == _confirmPasswordController) {
        isPasswordVisible = _confirmPasswordVisible;
        toggleVisibility = () {
          setState(() {
            _confirmPasswordVisible = !_confirmPasswordVisible;
          });
        };
      } else {
        // Default case (should not happen)
        toggleVisibility = () {};
      }

      suffixIcon = IconButton(
        icon: Icon(
          isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textLight,
        ),
        onPressed: toggleVisibility,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.textLight),
          suffixIcon: suffixIcon,
          enabled: enabled,
          helperText: helperText,
        ),
        keyboardType: keyboardType,
        obscureText: obscureText &&
            ((controller == _passwordController && !_passwordVisible) ||
                (controller == _confirmPasswordController &&
                    !_confirmPasswordVisible)),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _phoneController.clear();
    _otpController.clear();
  }

  Future<void> _sendSignupOtp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Email and password are required');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (_phoneController.text.isEmpty) {
      _showSnackBar('Phone number is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Send OTP via Twilio
      await _sendTwilioOtp(_phoneController.text);

      setState(() {
        _isLoading = false;
        _otpSent = true;
        _isSignup = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      // Create user with email and password
      _tempUserCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Save phone number to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'phone_${_emailController.text}', _phoneController.text);

      // Send email verification
      await _tempUserCredential!.user!.sendEmailVerification();

      _showSnackBar(
          'Account created! Please verify your email before logging in.');
      setState(() {
        isLogin = true;
        _isLoading = false;
        _otpSent = false;
      });
      _clearFields();
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.message ?? 'An error occurred during signup');
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      // Attempt to sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        setState(() => _isLoading = false);
        _showSnackBar('Please verify your email before logging in');
        await _auth.signOut();
        return;
      }

      // Get stored phone number
      final prefs = await SharedPreferences.getInstance();
      final storedPhone = prefs.getString('phone_${_emailController.text}');

      if (storedPhone == null) {
        setState(() => _isLoading = false);
        _showSnackBar('Phone number not found. Please sign up again.');
        await _auth.signOut();
        return;
      }

      // Set phone controller with the stored phone
      _phoneController.text = storedPhone;

      // Send OTP via Twilio
      await _sendTwilioOtp(storedPhone);

      setState(() {
        _isLoading = false;
        _otpSent = true;
        _isSignup = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.message ?? 'An error occurred during login');
    }
  }

  Future<void> _sendTwilioOtp(String phoneNumber) async {
    try {
      // Generate a random 6-digit OTP
      final otp =
          (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();

      // Save OTP locally (in a real app, use a secure method)
      _verificationId = otp;

      // Twilio API endpoint
      final url =
          'https://api.twilio.com/2010-04-01/Accounts/$_twilioSid/Messages.json';

      // Make the API request to Twilio
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_twilioSid:$_twilioAuth'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': _twilioPhone,
          'To': phoneNumber,
          'Body': 'Your OTP for ${_isSignup ? 'sign up' : 'login'} is: $otp',
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to send OTP: ${response.body}');
      }

      _showSnackBar('OTP sent to your phone number');
    } catch (e) {
      _showSnackBar('Error sending OTP: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);

    try {
      if (_otpController.text == _verificationId) {
        if (_isSignup) {
          // OTP verified for signup, proceed with creating account
          await _signUp();
        } else {
          // OTP verified for login, navigate to home screen
          _showSnackBar('Login successful!');

          // Navigate to home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }

        setState(() {
          _isLoading = false;
          _otpSent = false;
        });

        if (!_isSignup) {
          _clearFields();
        }
      } else {
        _showSnackBar('Invalid OTP');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error verifying OTP: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            message.contains('Error') ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// Home screen after successful login
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // User welcome card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF8A80FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome, ${user?.email?.split('@')[0] ?? 'User'}!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You are logged in successfully.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Account info card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person, color: AppColors.primary),
                          SizedBox(width: 12),
                          Text(
                            'Account Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        subtitle: user?.email ?? 'Not available',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.phone_outlined,
                        title: 'Phone',
                        subtitle: 'Your verified phone number',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Additional cards or features can be added here
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.security_outlined,
                      title: 'Security',
                      subtitle: 'Manage account security',
                      color: const Color(0xFFFFF8E1),
                      iconColor: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'App preferences',
                      color: const Color(0xFFE3F2FD),
                      iconColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
  }) {
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
