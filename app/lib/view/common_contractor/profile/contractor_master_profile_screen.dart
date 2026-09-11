import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:get/get.dart';
import '../../../controller/contractor_nav_controller.dart';
import '../../onboarding_screens/login_screen.dart';
import '../alert/contractor_master_alert_screen.dart';

class ContractorMasterProfileScreen extends StatefulWidget {
  const ContractorMasterProfileScreen({super.key});

  @override
  State<ContractorMasterProfileScreen> createState() =>
      _ContractorMasterProfileScreenState();
}

class _ContractorMasterProfileScreenState
    extends State<ContractorMasterProfileScreen> {
  UserModel? _currentUser;
  Map<String, dynamic>? _userData;
  String? _token;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }


  Future<void> _loadUserSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      _token = prefs.getString('token');

      final userDataStr = prefs.getString('userData');
      if (userDataStr != null) {
        _userData = jsonDecode(userDataStr);
      }

      final currentUserStr = prefs.getString('currentUser');
      if (currentUserStr != null) {
        try {
          _currentUser = UserModel.fromJson(jsonDecode(currentUserStr));
        } catch (e) {
          debugPrint('Error parsing UserModel: $e');
        }
      }

      if (_currentUser == null && _userData == null) {
        _errorMessage = 'No user session found. Please login again.';
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
      _errorMessage = 'Failed to load profile data';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getUserField(String field, [String defaultValue = 'N/A']) {
    var value = _currentUser?.toJson()[field]?.toString();
    if (value != null && value != 'N/A') return value;

    value = _userData?[field]?.toString();
    if (value != null && value != 'N/A') return value;

    if (field == 'companyName') {
      value = _userData?['entityDetails']?['companyName']?.toString();
      if (value != null) return value;
    }

    return defaultValue;
  }

  // The common nav bar hides Forms/Contracts/Users and keeps only
  // [Dashboard, Report] (0,1) for Contractor Supervisors, while full
  // contractors get the full list where Report sits at index 3.
  bool get _isContractorSupervisor =>
      _getUserField('role') == 'Contractor Supervisor';

  int get _reportsTabIndex => _isContractorSupervisor ? 1 : 3;

  String _getInitials() {
    final name = _getUserField('fullName', 'U');
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Logout error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during logout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          title: const Text(
            'Profile',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: kRailwayBlue,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          title: const Text(
            'Profile',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: kRailwayBlue,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadUserSession,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRailwayBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true)
                        .pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUserSession,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          _getInitials(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            _getUserField('status') == 'APPROVED'
                                ? Icons.check_circle
                                : Icons.pending,
                            color: _getUserField('status') == 'APPROVED'
                                ? Colors.green
                                : Colors.orange,
                            size: 18,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getUserField('fullName'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_getUserField('companyName', 'No company assigned'),
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _statusChip(
                              _getUserField('userType', 'User'),
                              Colors.blue.shade100,
                              Colors.blue,
                            ),
                            _statusChip(
                              _getUserField('status', 'PENDING'),
                              _getUserField('status') == 'APPROVED'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              _getUserField('status') == 'APPROVED'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.location_on, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Assignment Details',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_getUserField('zone', '') != 'N/A' &&
                      _getUserField('zone', '') != '')
                    _infoTile('Zone', _getUserField('zone'),
                        Colors.purple[50]!),
                  if (_getUserField('zone', '') != 'N/A' &&
                      _getUserField('zone', '') != '')
                    const SizedBox(height: 8),
                  if (_getUserField('division', '') != 'N/A' &&
                      _getUserField('division', '') != '')
                    _infoTile('Division', _getUserField('division'),
                        Colors.blue[50]!),
                  if (_getUserField('division', '') != 'N/A' &&
                      _getUserField('division', '') != '')
                    const SizedBox(height: 8),
                  if (_getUserField('depot', '') != 'N/A' &&
                      _getUserField('depot', '') != '')
                    _infoTile(
                        'Depot', _getUserField('depot'), Colors.green[50]!),

                  if (_getUserField('zone', '') == 'N/A' &&
                      _getUserField('division', '') == 'N/A' &&
                      _getUserField('depot', '') == 'N/A')
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'No assignment details available',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_outline, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text('Personal Information',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailRow(Icons.person_outline, 'Full Name',
                      _getUserField('fullName')),
                  _detailRow(Icons.badge, 'Role', _getUserField('role')),
                  if (_getUserField('company', '') != 'N/A' &&
                      _getUserField('company', '') != '')
                    _detailRow(Icons.business_center, 'Company',
                        _getUserField('company')),
                  if (_getUserField('designation', '') != 'N/A' &&
                      _getUserField('designation', '') != '')
                    _detailRow(Icons.work_outline, 'Designation',
                        _getUserField('designation')),
                  _detailRow(
                      Icons.email, 'Email', _getUserField('email')),
                  if (_getUserField('mobile', '') != 'N/A' &&
                      _getUserField('mobile', '') != '')
                    _detailRow(Icons.phone, 'Mobile Number',
                        _getUserField('mobile')),
                  if (_getUserField('zone', '') != 'N/A' &&
                      _getUserField('zone', '') != '')
                    _detailRow(
                        Icons.train, 'Zone', _getUserField('zone')),
                  if (_getUserField('division', '') != 'N/A' &&
                      _getUserField('division', '') != '')
                    _detailRow(Icons.location_on_outlined, 'Division',
                        _getUserField('division')),
                  if (_getUserField('depot', '') != 'N/A' &&
                      _getUserField('depot', '') != '')
                    _detailRow(Icons.home_work_outlined, 'Depot',
                        _getUserField('depot')),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (!_isContractorSupervisor) ...[
              _actionTile(Icons.description_outlined, 'My Forms',
                  Colors.blue.shade50, Colors.blue, () {
                    final navController = Get.find<ContractorNavController>();
                    navController.changeTab(1);
                    Navigator.pop(context);
                  }),
              const SizedBox(height: 10),
            ],
            _actionTile(Icons.bar_chart_outlined, 'My Reports',
                Colors.purple.shade50, Colors.purple, () {
                  final navController = Get.find<ContractorNavController>();
                  navController.changeTab(_reportsTabIndex);
                  Navigator.pop(context);
                }),
            const SizedBox(height: 10),
            _actionTile(Icons.notifications_outlined, 'Notifications',
                Colors.orange.shade50, Colors.orange, () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ContractorMasterAlertScreen()),
                  );
                }),
            const SizedBox(height: 10),
            _actionTile(
              Icons.logout_outlined,
              'Logout',
              Colors.red.shade50,
              Colors.red,
              _handleLogout,
            ),

            const SizedBox(height: 30),

            const Center(
              child: Text(
                'Swachh Railways – Contractor Employee Portal\n© 2024 Indian Railways. All rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(
          color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
    ],
  );

  static Widget _statusChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  static Widget _infoTile(String title, String value, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static Widget _statBox(
      String value, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }

  static Widget _actionTile(IconData icon, String label, Color bgColor,
      Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}