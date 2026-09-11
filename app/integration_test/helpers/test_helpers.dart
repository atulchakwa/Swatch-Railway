import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> loginAsEmailPassword(WidgetTester tester, String email, String password) async {
  // Wait for the login screen to settle
  await tester.pumpAndSettle();
  
  // Find and tap the Email + Password login method
  final emailPasswordTile = find.text('Email + Password');
  if (emailPasswordTile.evaluate().isNotEmpty) {
    await tester.tap(emailPasswordTile);
    await tester.pumpAndSettle();
  }

  // Find text fields
  final emailField = find.byKey(const ValueKey('email'));
  final passwordField = find.byKey(const ValueKey('password'));

  // Enter credentials
  await tester.enterText(emailField, email);
  await tester.pumpAndSettle();
  await tester.enterText(passwordField, password);
  await tester.pumpAndSettle();

  // Tap Sign In button
  final signInBtn = find.text('Sign In');
  await tester.tap(signInBtn);
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> logoutUser(WidgetTester tester) async {
  // Go to profile screen
  final profileAvatar = find.byType(CircleAvatar);
  if (profileAvatar.evaluate().isNotEmpty) {
    await tester.tap(profileAvatar.first);
    await tester.pumpAndSettle();
  } else {
    return;
  }

  // Tap logout
  final logoutBtn = find.text('Log out');
  if (logoutBtn.evaluate().isNotEmpty) {
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();
    // Confirm dialog
    final confirmBtn = find.text('Logout');
    if (confirmBtn.evaluate().isNotEmpty) {
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }
}

Future<void> cleanupTestData() async {
   final db = FirebaseFirestore.instance;
   
   try {
     // 1. Clean up Station Cleaning Runs
     final runsSnap = await db.collection('train_run_instances')
         .where('trainName', isGreaterThanOrEqualTo: 'TEST-')
         .where('trainName', isLessThan: 'TEST-\uf8ff')
         .get();
     for (var doc in runsSnap.docs) {
       await doc.reference.delete();
     }

     // 2. Clean up Complaints
     final compSnap = await db.collection('obhsComplaints')
         .where('trainNo', isGreaterThanOrEqualTo: 'TEST-')
         .where('trainNo', isLessThan: 'TEST-\uf8ff')
         .get();
     for (var doc in compSnap.docs) {
       await doc.reference.delete();
     }

     // 3. Clean up Master Data (Trains)
     final masterTrainSnap = await db.collection('trains')
         .where('trainNo', isGreaterThanOrEqualTo: 'TEST-')
         .where('trainNo', isLessThan: 'TEST-\uf8ff')
         .get();
     for (var doc in masterTrainSnap.docs) {
       await doc.reference.delete();
     }
     
     // Note: Attendance and Tasks tied to specific Run IDs can be queried 
     // and deleted if needed, but since the Run instance is deleted, 
     // they become orphaned and won't show up in the app UI.
     debugPrint('TEST- cleanup completed successfully.');
   } catch (e) {
     debugPrint('Cleanup failed: $e');
   }
 }
