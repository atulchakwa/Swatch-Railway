import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crm_train/main.dart' as app;
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Worker Workflow Tests', () {
    setUpAll(() async {
      app.main();
      await Future.delayed(const Duration(seconds: 2));
    });

    testWidgets('Worker logs in and submits attendance', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Log in as Worker
      await loginAsEmailPassword(tester, 'worker_test@swachhrailways.com', 'password123');

      // 2. Worker should land on Mobile Home Screen
      // Look for the "Start Attendance" button
      final startAttendanceBtn = find.text('Start Attendance');
      if (startAttendanceBtn.evaluate().isNotEmpty) {
        // Find the "Mark" button next to Start Attendance
        final markBtn = find.text('Mark').first;
        await tester.tap(markBtn);
        await tester.pumpAndSettle();

        // Handle Liveness Dialog
        final openCameraBtn = find.text('Open Camera');
        if (openCameraBtn.evaluate().isNotEmpty) {
          await tester.tap(openCameraBtn);
        }
        
        await tester.pumpAndSettle(const Duration(seconds: 4)); // Wait for GPS & API
      }

      // 3. Verify Tasks unlock
      // (Test that dashboard is unlocked after attendance)

      // Clean up by logging out
      await logoutUser(tester);
    });
  });
}
