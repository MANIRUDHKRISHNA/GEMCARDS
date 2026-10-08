import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/repositories/product_repositories.dart';
import 'package:gemcards_onboarding_prototype/screens/admin/admin_console.dart';
import 'package:gemcards_onboarding_prototype/services/api/gemcards_api_client.dart';
import 'package:gemcards_onboarding_prototype/services/demo_product_service.dart';

void main() {
  testWidgets('operations console adapts to a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: AdminConsoleScreen(repository: _StubAdminRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Portfolio overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operations console renders dashboard and simulator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminConsoleScreen(repository: _StubAdminRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Portfolio overview'), findsOneWidget);
    expect(find.text('Total customers'), findsOneWidget);
    await tester.tap(find.text('Simulator'));
    await tester.pumpAndSettle();
    expect(find.text('Authorization simulator'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'not-a-number');
    await tester.tap(find.text('Simulate authorization'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid amount greater than zero.'),
      findsOneWidget,
    );
    expect(find.text('APPROVED'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _StubAdminRepository extends AdminRepository {
  _StubAdminRepository()
    : super(
        GemcardsApiClient(baseUrl: 'http://localhost'),
        DemoProductRepository(),
      );

  @override
  Future<Map<String, dynamic>> getMetrics() async => const {
    'total_customers': 12480,
    'active_cards': 18340,
    'transactions_today': 918,
    'transaction_volume': 1284500,
    'pending_kyc': 24,
    'fraud_alerts': 1,
    'open_disputes': 1,
    'cards_issued_today': 42,
  };

  @override
  Future<List<Map<String, dynamic>>> getCustomers() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getCards() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getTransactions() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getFraud() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getDisputes() async => const [];
}
