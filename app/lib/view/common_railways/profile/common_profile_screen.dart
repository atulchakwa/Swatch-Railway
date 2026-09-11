import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/services/dashboard_counts_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../controller/contractor_nav_controller.dart';
import '../../onboarding_screens/login_screen.dart';
import '../alert/common_alert_screen.dart';
import 'profile_edit_screen.dart';
import 'change_password_screen.dart';
import '../settings/settings_screen.dart';

class CommonProfileScreen extends StatefulWidget {
  const CommonProfileScreen({super.key,});

  @override
  State<CommonProfileScreen> createState() => _CommonProfileScreenState();
}

class _CommonProfileScreenState extends State<CommonProfileScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

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
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      const CircleAvatar(
                        backgroundColor: kRailwayBlue,
                        radius: 36,
                        child: Icon(Icons.person,size: 40,color: Colors.white,),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _statusChip(user.role,
                                Colors.blue.shade100, Colors.blue),
                            const SizedBox(width: 8),
                            _statusChip(user.status ?? 'Active',
                                Colors.green.shade100, Colors.green),
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
                  _infoTile('Zone', user.zone ?? 'N/A', Colors.purple[50]!),
                  const SizedBox(height: 8),
                  _infoTile('Division', user.division ?? 'N/A', Colors.blue[50]!),
                  const SizedBox(height: 8),
                  _infoTile('Depot', user.depot ?? 'N/A', Colors.green[50]!),
                  if (user.contractType != null) ...[
                    const SizedBox(height: 8),
                    _infoTile('Contract Type', _formatContractType(user.contractType!), Colors.orange[50]!),
                  ],
                  if (user.contractId != null) ...[
                    const SizedBox(height: 8),
                    _infoTile('Contract ID', user.contractId!, Colors.teal[50]!),
                  ],
                  if (user.entityId != null) ...[
                    const SizedBox(height: 8),
                    _infoTile('Company ID', user.entityId!, Colors.indigo[50]!),
                  ],
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
                      user.fullName),
                  _detailRow(Icons.email, 'Email', user.email),
                  _detailRow(Icons.phone, 'Mobile',
                      user.mobile ?? 'N/A'),
                  _detailRow(Icons.assignment_ind, 'Designation',
                      user.designation ?? 'N/A'),
                  _detailRow(Icons.map, 'Zone', user.zone ?? 'N/A'),
                  _detailRow(Icons.business, 'Division',
                      user.division ?? 'N/A'),
                  _detailRow(Icons.business, 'Depot',
                      user.depot ?? 'N/A'),
                  _detailRow(Icons.shield, 'Role', user.role),
                  _detailRow(Icons.person_pin, 'User Type',
                      user.userType),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _actionTile(Icons.description_outlined, 'My Forms',
                Colors.blue.shade50, Colors.blue, () {
                  final navController = Get.find<ContractorNavController>();
                  navController.changeTab(1);
                  Navigator.pop(context);
                }),
            const SizedBox(height: 10),
            _actionTile(Icons.bar_chart_outlined, 'My Reports',
                Colors.purple.shade50, Colors.purple, () {
                  final navController = Get.find<ContractorNavController>();
                  navController.changeTab(4);
                  Navigator.pop(context);
                }),
            const SizedBox(height: 10),
            _actionTile(Icons.edit_outlined, 'Edit Profile',
                Colors.indigo.shade50, Colors.indigo, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
                }),
            const SizedBox(height: 10),
            _actionTile(Icons.lock_outline, 'Change Password',
                Colors.orange.shade50, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                }),
            const SizedBox(height: 10),
            _actionTile(Icons.settings_outlined, 'Settings',
                Colors.blueGrey.shade50, Colors.blueGrey, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }),
            const SizedBox(height: 10),
            _actionTile(Icons.notifications_outlined, 'Notifications',
                Colors.orange.shade50, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CommonAlertScreen()));
                }),
            const SizedBox(height: 10),
            _actionTile(
              Icons.logout_outlined,
              'Logout',
              Colors.red.shade50,
              Colors.red,
                  () {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.of(context, rootNavigator: true)
                    .pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              },
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
    boxShadow: [
      BoxShadow(
          color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))
    ],
  );

  static Widget _statusChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
      BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(
          text,
          style: TextStyle(
              color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  static Widget _infoTile(String title, String value, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
      BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
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
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w600)),
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

  static Widget _statBoxLoading(Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: const Column(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 6),
          Text('Loading...',
              style: TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }

  static String _formatContractType(String type) {
    switch (type) {
      case 'station_cleaning':
        return 'Station Cleaning';
      case 'coach_cleaning':
        return 'Coach Cleaning';
      case 'premises_cleaning':
        return 'Premises Cleaning';
      case 'cts':
        return 'CTS';
      case 'obhs':
        return 'OBHS';
      default:
        return type;
    }
  }

  static Widget _actionTile(
      IconData icon, String label, Color bgColor, Color textColor, VoidCallback onTap) {
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
