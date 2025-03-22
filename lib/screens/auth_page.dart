import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:otp_auth/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otp_auth/screens/home_screen.dart';

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
  final String _twilioSid = 'ENTER_SID';
  final String _twilioAuth = 'ENTER_AUTH';
  final String _twilioPhone = 'ENTER_PHONE_NUMBER';

  //country codes
  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'country': 'India'},
    {'code': '+1', 'country': 'USA'},
    {'code': '+44', 'country': 'UK'},
    {'code': '+61', 'country': 'Australia'},
    {'code': '+86', 'country': 'China'},
    {'code': '+49', 'country': 'Germany'},
    {'code': '+81', 'country': 'Japan'},
    {'code': '+33', 'country': 'France'},
    {'code': '+7', 'country': 'Russia'},
    {'code': '+55', 'country': 'Brazil'},
    // Add more country codes as needed
  ];

// Add this variable to track the selected country code
  String _selectedCountryCode = '+91'; // Default to India's code

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

  Widget _buildPhoneInputField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country code dropdown
          Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                icon: const Icon(Icons.arrow_drop_down,
                    color: AppColors.textLight),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                borderRadius: BorderRadius.circular(12),
                isExpanded: true,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCountryCode = newValue;
                    });
                  }
                },
                items: _countryCodes.map<DropdownMenuItem<String>>(
                    (Map<String, String> country) {
                  return DropdownMenuItem<String>(
                    value: country['code'],
                    child: Text(
                      "${country['code']} ${country['country']}",
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Phone number input field (without country code)
          Expanded(
            child: TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon:
                    Icon(Icons.phone_outlined, color: AppColors.textLight),
                helperText: 'Enter your phone number without country code',
              ),
              keyboardType: TextInputType.phone,
            ),
          ),
        ],
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
        // Replace the phone input field with our new custom widget
        if (!isLogin && !_otpSent) _buildPhoneInputField(),
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
      // Concatenate the selected country code with the phone number
      final completePhoneNumber = _selectedCountryCode + _phoneController.text;

      // Send OTP via Twilio
      await _sendTwilioOtp(completePhoneNumber);

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

      // Save phone number with country code to shared preferences
      final prefs = await SharedPreferences.getInstance();
      final completePhoneNumber = _selectedCountryCode + _phoneController.text;
      await prefs.setString(
          'phone_${_emailController.text}', completePhoneNumber);
      // Save country code separately for future use
      await prefs.setString(
          'country_code_${_emailController.text}', _selectedCountryCode);

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

      // Get stored phone number and country code
      final prefs = await SharedPreferences.getInstance();
      final storedPhone = prefs.getString('phone_${_emailController.text}');
      // ignore: unused_local_variable
      final storedCountryCode =
          prefs.getString('country_code_${_emailController.text}') ?? '+91';

      if (storedPhone == null) {
        setState(() => _isLoading = false);
        _showSnackBar('Phone number not found. Please sign up again.');
        await _auth.signOut();
        return;
      }

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
