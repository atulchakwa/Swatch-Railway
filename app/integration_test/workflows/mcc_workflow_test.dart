import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crm_train/main.dart' as app;
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MCC Workflow Tests', () {
    setUpAll(() async {
      // Ensure clean state before tests
      app.main();
      await Future.delayed(const Duration(seconds: 2));
    });

    tearDownAll(() async {
      // Clean up garbage data created during this test
      await cleanupTestData();
    });

    testWidgets('MCC creates a new OBHS Run Instance', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Log in as MCC 
      // Replace with an actual MCC account email and password
      await loginAsEmailPassword(tester, 'mcc_test@swachhrailways.com', 'password123');

      // 2. Navigate to OBHS Management
      final obhsTab = find.text('OBHS');
      if (obhsTab.evaluate().isNotEmpty) {
        await tester.tap(obhsTab);
        await tester.pumpAndSettle();
      }

      // 3. Tap on "Create New OBHS Run"
      // (This assumes there's a specific button or FAB for creating runs)
      // Example:
      // final createFab = find.byTooltip('Create New Run');
      // await tester.tap(createFab);
      // await tester.pumpAndSettle();

      // 4. Fill details
      // await tester.enterText(find.byKey(const ValueKey('trainName')), 'TEST-EXPRESS');
      // ... more interactions

      // 5. Assert run was created
      // expect(find.text('TEST-EXPRESS'), findsOneWidget);

      // Clean up by logging out
      await logoutUser(tester);
    });
  });
}
