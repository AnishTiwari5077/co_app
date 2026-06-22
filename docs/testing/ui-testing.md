# SahakariMS — Testing: UI Testing

## Overview

UI tests validate that the Flutter application renders correctly and behaves as expected from the user's perspective. We use **flutter_test** for widget tests and **integration_test** for end-to-end app flows.

---

## Testing Levels

| Level | Tool | Speed | Scope |
|-------|------|-------|-------|
| Widget Tests | flutter_test | Fast | Single widgets |
| Screen Tests | flutter_test | Medium | Full screens (mocked API) |
| E2E Tests | integration_test | Slow | Real app + real backend |

---

## Widget Tests

### Testing a Reusable Component

```dart
// test/widgets/amount_display_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sahakarims/shared/widgets/amount_display.dart';

void main() {
  group('AmountDisplay', () {
    testWidgets('displays positive amount with credit style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountDisplay(amount: 5000, isCredit: true),
          ),
        ),
      );

      expect(find.text('+5,000.00'), findsOneWidget);
      expect(find.byType(AmountDisplay), findsOneWidget);

      // Verify color (credit = green)
      final text = tester.firstWidget<Text>(find.text('+5,000.00'));
      expect(text.style?.color, AppColors.creditAmount);
    });

    testWidgets('displays negative amount with debit style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountDisplay(amount: 2000, isCredit: false),
          ),
        ),
      );

      expect(find.text('-2,000.00'), findsOneWidget);
      final text = tester.firstWidget<Text>(find.text('-2,000.00'));
      expect(text.style?.color, AppColors.debitAmount);
    });

    testWidgets('formats large amounts with NPR lakh notation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountDisplay(amount: 1250000, isCredit: true),
          ),
        ),
      );

      expect(find.text('+12,50,000.00'), findsOneWidget);
    });
  });
}
```

---

### Testing a Form Widget

```dart
// test/widgets/deposit_form_test.dart
void main() {
  group('DepositForm', () {
    late MockSavingsApiService mockApi;

    setUp(() {
      mockApi = MockSavingsApiService();
    });

    testWidgets('submit button disabled when amount is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savingsApiServiceProvider.overrideWithValue(mockApi),
          ],
          child: MaterialApp(
            home: DepositScreen(accountId: 'test-account-id'),
          ),
        ),
      );

      // Initially the submit button should be disabled
      final button = find.byKey(const Key('deposit_submit_button'));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    });

    testWidgets('shows error when amount below minimum', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DepositScreen(accountId: 'test-account-id'),
          ),
        ),
      );

      // Enter an amount below minimum
      await tester.enterText(find.byKey(const Key('amount_field')), '50');
      await tester.tap(find.byKey(const Key('deposit_submit_button')));
      await tester.pump();

      expect(find.text('Minimum deposit is NPR 100.00'), findsOneWidget);
    });

    testWidgets('calls API and shows success on valid deposit', (tester) async {
      when(mockApi.deposit(any, any)).thenAnswer(
        (_) async => DepositResponse(
          receiptNumber: 'RCP-KTM-2081-001',
          balanceAfter: 6000,
        ),
      );

      await tester.pumpWidget(/* ... */);

      await tester.enterText(find.byKey(const Key('amount_field')), '1000');
      await tester.tap(find.byKey(const Key('deposit_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Deposit successful'), findsOneWidget);
      expect(find.text('RCP-KTM-2081-001'), findsOneWidget);
      verify(mockApi.deposit(any, any)).called(1);
    });
  });
}
```

---

## Screen Tests (Golden Tests)

Golden tests capture a visual snapshot and detect unintended UI changes:

```dart
// test/screens/dashboard_screen_test.dart
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  group('Dashboard Screen Golden Tests', () {
    testGoldens('renders correctly on tablet', (tester) async {
      await loadAppFonts();

      await tester.pumpWidgetBuilder(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith((ref) => AsyncValue.data(
              DashboardState.fixture(),
            )),
          ],
          child: const DashboardScreen(),
        ),
        surfaceSize: const Size(1280, 800),  // Tablet/desktop
      );

      await screenMatchesGolden(tester, 'dashboard_tablet');
    });

    testGoldens('renders loading state', (tester) async {
      await tester.pumpWidgetBuilder(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith((ref) =>
              const AsyncValue.loading()),
          ],
          child: const DashboardScreen(),
        ),
        surfaceSize: const Size(1280, 800),
      );

      await screenMatchesGolden(tester, 'dashboard_loading');
    });
  });
}

// Update golden files:
// flutter test --update-goldens test/screens/dashboard_screen_test.dart
```

---

## Integration Tests (E2E)

```dart
// integration_test/deposit_flow_test.dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahakarims/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deposit Flow E2E', () {
    testWidgets('cashier can deposit to member account', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Login as cashier
      await tester.enterText(
          find.byKey(const Key('username_field')),
          'cashier01@sahakarims.np');
      await tester.enterText(
          find.byKey(const Key('password_field')),
          'TestPass@123');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to savings
      await tester.tap(find.byIcon(Icons.savings));
      await tester.pumpAndSettle();

      // Search for member
      await tester.enterText(
          find.byKey(const Key('member_search')),
          'KTM-2081-00001');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('SAV-KTM-2081-00456'));
      await tester.pumpAndSettle();

      // Tap deposit
      await tester.tap(find.byKey(const Key('deposit_button')));
      await tester.pumpAndSettle();

      // Enter amount
      await tester.enterText(find.byKey(const Key('amount_field')), '5000');
      await tester.tap(find.byKey(const Key('confirm_deposit_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify success
      expect(find.text('Deposit Successful'), findsOneWidget);
      expect(find.textContaining('NPR 5,000.00'), findsWidgets);
    });
  });
}
```

---

## Running UI Tests

```bash
# Widget and screen tests (fast, no device needed)
flutter test test/

# Run golden tests
flutter test test/screens/

# Update golden screenshots
flutter test --update-goldens test/screens/

# Integration tests (requires device or emulator)
flutter test integration_test/ \
  --device-id android \
  -d emulator-5554

# Run integration tests on CI (headless)
flutter test integration_test/ \
  --headless \
  --machine \
  > test_results.json

# Generate coverage report
flutter test --coverage test/
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Accessibility Tests

```dart
// Automated accessibility checking
testWidgets('deposit form meets accessibility standards', (tester) async {
  await tester.pumpWidget(/* ... */);

  // Check for semantic labels
  final SemanticsHandle handle = tester.ensureSemantics();

  expect(
    tester.getSemantics(find.byKey(const Key('amount_field'))),
    matchesSemantics(label: 'Deposit Amount', isTextField: true),
  );

  handle.dispose();
});
```
