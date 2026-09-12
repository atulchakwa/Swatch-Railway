import 'package:crm_train/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../passenger/passenger_task_screen.dart';
import '../../../providers/auth_provider.dart';
import 'package:crm_train/model/user_model.dart';

import 'forgot_passowrd_screen.dart';
import 'package:get/get.dart';
import '../../../utills/app_colors.dart';
import '../../../utills/validators.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  bool _obscurePassword = true;
  bool _otpSent = false;
  bool _rememberMe = false;

  String _loginMethod = 'mobile_otp'; // default to OTP

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }


  Future<void> _onMainButtonPressed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    final isOtp = _loginMethod.contains('otp');
    final isMobile = _loginMethod.contains('mobile');

    if (isOtp) {
      if (isMobile) {
        if (!_otpSent) {
          final success = await authProvider.sendOtp(_mobile.text);
          if (success) {
            setState(() => _otpSent = true);
            _showSuccess('OTP sent successfully!');
          } else {
            _showError(authProvider.errorMessage ?? 'Failed to send OTP');
          }
        } else {
          final success = await authProvider.verifyOtp(_mobile.text, _otp.text);
          if (success) {
            await authProvider.saveUserSession(rememberMe: _rememberMe);
            _showSuccess('Login Successful!');
            _navigateToRoleBasedScreen(authProvider);
          } else {
            _showError(authProvider.errorMessage ?? 'Invalid OTP');
          }
        }
      } else {
        if (!_otpSent) {
          final success = await authProvider.sendEmailOtp(_email.text);
          if (success) {
            setState(() => _otpSent = true);
            _showSuccess('OTP sent to your email!');
          } else {
            _showError(authProvider.errorMessage ?? 'Failed to send OTP');
          }
        } else {
          final success = await authProvider.verifyEmailOtp(_email.text, _otp.text);
          if (success) {
            await authProvider.saveUserSession(rememberMe: _rememberMe);
            _showSuccess('Login Successful!');
            _navigateToRoleBasedScreen(authProvider);
          } else {
            _showError(authProvider.errorMessage ?? 'Invalid OTP');
          }
        }
      }
      return;
    }

    else {
      final password = _password.text;
      bool success = false;

      if (isMobile) {
        success = await authProvider.loginWithMobile(_mobile.text, password);
      } else {
        success = await authProvider.loginWithPassword(_email.text, password);
      }

      if (success) {
        await authProvider.saveUserSession(rememberMe: _rememberMe);
        _showSuccess('Login Successful!');
        _navigateToRoleBasedScreen(authProvider);
      } else {
        _showError(authProvider.errorMessage ?? 'Invalid credentials');
      }
    }
  }


  void _navigateToRoleBasedScreen(AuthProvider authProvider) {
    if (authProvider.userData == null) {
      _showError('User data not available');
      return;
    }

    try {
      final user = UserModel.fromApiResponse(authProvider.userData!);

      navigateUser(context, user);
    } catch (e) {
      _showError('Failed to process user data: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildInputFields() {
    final isMobile = _loginMethod.contains('mobile');
    final isOtp = _loginMethod.contains('otp');

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position:
              Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: isMobile
              ? _buildMobileField()
              : _buildEmailField(),
        ),
        const SizedBox(height: 16),
        if (!isOtp) _buildPasswordField(),
        if (isOtp && _otpSent) ..._buildOtpField(),
      ],
    );
  }

  Widget _buildMobileField() => TextFormField(
    key: const ValueKey('mobile'),
    controller: _mobile,
    keyboardType: TextInputType.phone,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10),
    ],
    decoration: InputDecoration(
      labelText: 'Mobile Number',
      prefixText: '+91 ',
      prefixIcon: const Icon(Icons.phone),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    ),
    validator: (v) {
      if (v == null || v.isEmpty) return 'Enter mobile number';
      if (v.length != 10) return 'Enter valid 10-digit number';
      return null;
    },
  );

  Widget _buildEmailField() => TextFormField(
    key: const ValueKey('email'),
    controller: _email,
    keyboardType: TextInputType.emailAddress,
    decoration: InputDecoration(
      labelText: 'Email Address',
      prefixIcon: const Icon(Icons.email_outlined),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    ),
validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter email';
                  if (AppValidators.email(v) != null) return 'Enter valid email';
                  return null;
                },
  );

  Widget _buildPasswordField() => TextFormField(
    key: const ValueKey('password'),
    controller: _password,
    obscureText: _obscurePassword,
    decoration: InputDecoration(
      labelText: 'Password',
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    ),
    validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
  );

  List<Widget> _buildOtpField() => [
    const SizedBox(height: 16),
    TextFormField(
      key: const ValueKey('otp'),
      controller: _otp,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: 'Enter OTP',
        prefixIcon: const Icon(Icons.sms_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter OTP';
        if (v.length != 6) return 'Enter valid 6-digit OTP';
        return null;
      },
    ),
    const SizedBox(height: 8),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Didn\'t receive OTP?',
            style: TextStyle(color: Colors.grey)),
        TextButton(
          onPressed: () async {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final isMobile = _loginMethod.contains('mobile');

            bool success = false;
            if (isMobile) {
              success = await authProvider.sendOtp(_mobile.text);
            } else {
              success = await authProvider.sendEmailOtp(_email.text);
            }

            if (success) {
              _showSuccess('OTP resent successfully!');
            } else {
              _showError('Failed to resend OTP');
            }
          },
          child: const Text(
            'Resend OTP',
            style: TextStyle(
                color: Color(0xFF0B63FF), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.06),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Hero(
                      tag: 'app_logo',
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor:
                        const Color(0xFF0B63FF).withOpacity(0.1),
                        backgroundImage: AssetImage('assets/images/indian_railway.png'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text("Swachh Railways",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A1B2B))),
                    const SizedBox(height: 8),
                    const Text("Swachh Bharat, Swachh Railways",
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 28),
                    _buildLoginCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Welcome Back",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF0A1B2B))),
        const Text("Choose your login method",
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 15),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: [
            _buildMethodTile('Mobile + OTP', 'mobile_otp'),
            _buildMethodTile('Mobile + Password', 'mobile_password'),
            _buildMethodTile('Email + Password', 'email_password'),
            _buildMethodTile('Email + OTP', 'email_otp'),
          ],
        ),
        const SizedBox(height: 30),
        Form(key: _formKey, child: _buildInputFields()),
        const SizedBox(height: 10),
        _buildBottomActions(),
      ],
    ),
  );

  Widget _buildBottomActions() => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (v) =>
                    setState(() => _rememberMe = v ?? false),
                activeColor: const Color(0xFF0B63FF),
              ),
              const Text('Remember me'),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ForgotPasswordPage()),
              );
            },
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                  color: Color(0xFF0B63FF),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: authProvider.isLoading
                  ? Colors.grey
                  : const Color(0xFF0B63FF),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: authProvider.isLoading
                  ? null
                  : _onMainButtonPressed,
              child: authProvider.isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Text(
                _loginMethod.contains('otp')
                    ? (_otpSent ? 'Verify OTP' : 'Send OTP')
                    : 'Sign In',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 30),
      const Center(
        child: Text(
          textAlign: TextAlign.center,
          'Not registered? Contact your admin to create an account.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
      const SizedBox(height: 15),
      const Divider(),
      const SizedBox(height: 15),
      OutlinedButton.icon(
        onPressed: () {
           Get.to(() => const PassengerTaskScreen());
        },
        icon: const Icon(Icons.person_pin_outlined, color: kRailwayBlue),
        label: const Text(
          'Passenger Service Portal',
          style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kRailwayBlue),
          minimumSize: const Size(double.infinity, 45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ],
  );

  Widget _buildMethodTile(String title, String keyValue) {
    final isSelected = _loginMethod == keyValue;
    return GestureDetector(
      onTap: () => setState(() {
        _loginMethod = keyValue;
        _otpSent = false;
        _otp.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? const Color(0xFF0B63FF) : Colors.grey.shade100,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}