import 'package:flutter/material.dart';
import 'package:crm_train/model/user_model.dart';

import '../view/common_railways/main_nav_screen.dart';
import '../view/common_workers/worker_mobile_nav_bar.dart';
import '../view/obhs_screens/mcc/obhs_mcc_router.dart';

void navigateUser(BuildContext context, UserModel user) {
  final mccRoles = [
    'CTS',
    'Janitor', 'JANITOR',
    'Attendant', 'ATTENDANT',
    'Worker', 'WORKER'
  ];

  if (mccRoles.contains(user.role)) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ObhsMccRouter(user: user),
      ),
    );
  } else if (user.role == 'Railway Worker' || user.role == 'RAILWAY_WORKER') {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerMobileNavBar(user: user),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavScreen(user: user),
      ),
    );
  }
}

