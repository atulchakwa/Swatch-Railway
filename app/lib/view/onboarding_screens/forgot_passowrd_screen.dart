import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../../../utills/validators.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool isEmail = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _isLoading = false;
  String? _resetToken;

  int _resendTimer = 0;
  Timer? _timer;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    _inputCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendTimer = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  void _switchMode(bool toEmail) {
    setState(() {
      isEmail = toEmail;
      _otpSent = false;
      _otpVerified = false;
      _inputCtrl.clear();
      _otpCtrl.clear();
      _passCtrl.clear();
      _confirmCtrl.clear();
      _resetToken = null;
      _resendTimer = 0;
      _timer?.cancel();
    });
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final response = isEmail
        ? await _authService.forgotPasswordSendOtpEmail(_inputCtrl.text.trim())
        : await _authService.forgotPasswordSendOtpMobile(_inputCtrl.text.trim());

    setState(() => _isLoading = false);

    if (response.success) {
      setState(() => _otpSent = true);
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleResendOtp()  async{
    setState(() => _isLoading = true);

    final response = isEmail
        ? await _authService.forgotPasswordSendOtpEmail(_inputCtrl.text.trim())
        : await _authService.forgotPasswordSendOtpMobile(_inputCtrl.text.trim());

    setState(() => _isLoading = false);

    if (response.success) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid 6-digit OTP')));
      return;
    }

    setState(() => _isLoading = true);

    final response = isEmail
        ? await _authService.forgotPasswordVerifyOtpEmail(
        _inputCtrl.text.trim(), _otpCtrl.text.trim())
        : await _authService.forgotPasswordVerifyOtpMobile(
        _otpCtrl.text.trim(), _inputCtrl.text.trim());

    setState(() => _isLoading = false);

    if (response.success) {
      _resetToken = response.resetToken;
      _timer?.cancel();
      setState(() => _otpVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleResetPassword() async {
    if (_passCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (_resetToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid session. Please try again.')));
      return;
    }

    setState(() => _isLoading = true);

    final response =
    await _authService.resetPassword(_passCtrl.text, _resetToken!);

    setState(() => _isLoading = false);

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final cardWidth = width > 560 ? 420.0 : width * 0.94;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 38,
                        backgroundColor: Color(0xFF0B63FF),
                        child: Icon(Icons.lock_reset,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text('Reset Password',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose your preferred method to reset password',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero)
                                    .animate(anim),
                                child: child,
                              ),
                            ),
                            child: !_otpSent
                                ? _buildInputStage()
                                : !_otpVerified
                                ? _buildOtpStage()
                                : _buildPasswordStage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputStage() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('input_stage'),
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchMode(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isEmail
                          ? const Color(0xFF0B63FF)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Mobile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: !isEmail ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchMode(true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isEmail
                          ? const Color(0xFF0B63FF)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isEmail ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(isEmail ? 'Email Address' : 'Mobile Number',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey(isEmail ? 'email_input' : 'mobile_input'),
            controller: _inputCtrl,
            keyboardType:
            isEmail ? TextInputType.emailAddress : TextInputType.phone,
            inputFormatters: isEmail
                ? null
                : [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)
            ],
            decoration: InputDecoration(
              hintText: isEmail
                  ? 'you@example.com'
                  : 'Enter 10-digit mobile number',
              prefixIcon: Icon(isEmail ? Icons.email_outlined : Icons.phone,
                  color: const Color(0xFF0B63FF)),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) {
if (isEmail) {
      if (v == null || v.isEmpty) return 'Enter email';
      if (AppValidators.email(v) != null) return 'Enter valid email';
    } else {
                if (v == null || v.isEmpty) return 'Enter mobile number';
                if (v.length != 10) return 'Enter valid 10-digit mobile';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B63FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: _isLoading ? null : _handleSendOtp,
              child: const Text('Send OTP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Login',
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStage() {
    return Column(
      key: const ValueKey('otp_stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter OTP', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6)
          ],
          decoration: InputDecoration(
            hintText: '6-digit OTP',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _resendTimer > 0
                ? Text(
              'Resend in ${_resendTimer}s',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            )
                : TextButton(
              onPressed: _isLoading ? null : _handleResendOtp,
              child: const Text('Resend OTP'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _otpSent = false;
                  _otpCtrl.clear();
                  _resendTimer = 0;
                });
              },
              child: const Text('Change Number/Email'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B63FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _isLoading ? null : _handleVerifyOtp,
            child: const Text('Verify OTP',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Login',
                style: TextStyle(color: Colors.black)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStage() {
    return Column(
      key: const ValueKey('password_stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter New Password',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'New password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Confirm Password',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Confirm password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B63FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _isLoading ? null : _handleResetPassword,
            child: const Text('Reset Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Login',
                style: TextStyle(color: Colors.black)),
          ),
        ),
      ],
    );
  }
}