import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/repositories/product_repositories.dart';
import 'package:gemcards_onboarding_prototype/screens/admin/admin_console.dart';
import 'package:gemcards_onboarding_prototype/services/api/gemcards_api_client.dart';

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

  testWidgets('failed operations load exposes retry and recovers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminConsoleScreen(repository: _FailOnceAdminRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Operations data unavailable'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'operations console renders dashboard and simulator input errors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminConsoleScreen(repository: _StubAdminRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Portfolio overview'), findsOneWidget);
      expect(find.text('Total customers'), findsOneWidget);
      await tester.tap(find.text('Simulator'));
      await tester.pumpAndSettle();
      expect(find.text('Authorization simulator'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'not-a-number');
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate authorization'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid amount greater than zero.'),
        findsOneWidget,
      );
      expect(find.text('APPROVED'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('customer search, KYC filtering, and detail use API results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminConsoleScreen(repository: _StubAdminRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Priya Shah'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search name, customer ID, or email'),
      'Priya',
    );
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsNothing);
    expect(find.text('Priya Shah'), findsOneWidget);
    await tester.tap(find.text('Priya Shah'));
    await tester.pumpAndSettle();
    expect(find.text('Customer details'), findsOneWidget);
    expect(find.text('KYC: under_review'), findsOneWidget);
    expect(find.text('Risk: medium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card actions, fraud resolution, and dispute status update', (
    tester,
  ) async {
    final repository = _StubAdminRepository();
    await tester.pumpWidget(
      MaterialApp(home: AdminConsoleScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('Card management'), findsOneWidget);
    await tester.tap(find.text('•••• 4821 · GEMCARDS Platinum'));
    await tester.pumpAndSettle();
    expect(find.text('Card details'), findsOneWidget);
    expect(find.text('Daily limit: ₹50000'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Card operations').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change limit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '75000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.updatedLimit, 75000);

    await tester.tap(find.text('Fraud & risk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolve alert'));
    await tester.pumpAndSettle();
    expect(repository.fraudResolved, isTrue);
    expect(find.text('No fraud alerts to review.'), findsOneWidget);

    await tester.tap(find.text('Disputes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investigating').last);
    await tester.pumpAndSettle();
    expect(repository.disputeStatus, 'investigating');
    expect(tester.takeException(), isNull);
  });

  testWidgets('simulator sends channel and renders backend rule results', (
    tester,
  ) async {
    final repository = _StubAdminRepository();
    await tester.pumpWidget(
      MaterialApp(home: AdminConsoleScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B · ₹80,000'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate authorization'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(repository.simulationAmount, 80000);
    expect(repository.simulationChannel, 'ONLINE');
    expect(tester.takeException(), isNull);
    expect(find.text('DECLINED'), findsOneWidget);
    expect(find.textContaining('Daily limit: failed'), findsOneWidget);
    expect(find.text('Reason: Amount exceeds the daily limit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FailOnceAdminRepository extends _StubAdminRepository {
  var _attempts = 0;

  @override
  Future<Map<String, dynamic>> getMetrics() async {
    _attempts++;
    if (_attempts == 1) {
      throw const GemcardsApiException('Synthetic operations error');
    }
    return super.getMetrics();
  }
}

class _StubAdminRepository extends AdminRepository {
  _StubAdminRepository()
    : super(GemcardsApiClient(baseUrl: 'http://localhost'));

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
    'volume_series': [2, 3],
    'issuance_series': [1, 4],
  };

  @override
  Future<List<Map<String, dynamic>>> getCustomers({
    String query = '',
    String kycStatus = '',
  }) async => const [
    {
      'id': 'CUS-01',
      'name': 'Alex Morgan',
      'email': 'alex@example.demo',
      'kyc_status': 'verified',
      'cards': 1,
      'transactions': 2,
      'risk': 'low',
    },
    {
      'id': 'CUS-02',
      'name': 'Priya Shah',
      'email': 'priya@example.demo',
      'kyc_status': 'under_review',
      'cards': 1,
      'transactions': 1,
      'risk': 'medium',
    },
  ];

  @override
  Future<Map<String, dynamic>> getCustomer(String id) async => const {
    'id': 'CUS-02',
    'name': 'Priya Shah',
    'email': 'priya@example.demo',
    'kyc_status': 'under_review',
    'cards': 1,
    'transactions': 1,
    'risk': 'medium',
    'cards_detail': [],
    'transactions_detail': [],
    'disputes': [],
  };

  @override
  Future<List<Map<String, dynamic>>> getCards() async => const [
    {
      'id': 'CARD-001',
      'masked_number': '•••• 4821',
      'customer': 'Alex Morgan',
      'product': 'GEMCARDS Platinum',
      'status': 'active',
      'limit': 50000,
    },
  ];

  @override
  Future<Map<String, dynamic>> getCard(String id) async => const {
    'id': 'CARD-001',
    'customer': 'Alex Morgan',
    'product': 'GEMCARDS Platinum',
    'status': 'active',
    'limit': 50000,
  };

  int? updatedLimit;

  @override
  Future<Map<String, dynamic>> updateCardLimit(String id, int limit) async {
    updatedLimit = limit;
    return {'id': id, 'limit': limit};
  }

  @override
  Future<Map<String, dynamic>> replaceCard(String id) async => {
    'card': {'id': id, 'status': 'replaced'},
    'message': 'Demo replacement requested',
  };

  @override
  Future<Map<String, dynamic>> setCardFrozen(
    String cardId, {
    required bool frozen,
  }) async => {'id': cardId, 'status': frozen ? 'frozen' : 'active'};

  @override
  Future<List<Map<String, dynamic>>> getTransactions() async => const [];

  bool fraudResolved = false;

  @override
  Future<List<Map<String, dynamic>>> getFraud() async => fraudResolved
      ? const []
      : const [
          {
            'id': 'FRA-01',
            'reason': 'Review alert',
            'severity': 'high',
            'status': 'open',
          },
        ];

  @override
  Future<Map<String, dynamic>> resolveFraud(String id) async {
    fraudResolved = true;
    return {'id': id, 'status': 'resolved'};
  }

  String? disputeStatus;

  @override
  Future<List<Map<String, dynamic>>> getDisputes() async => [
    {
      'id': 'DSP-01',
      'transaction_id': 'TXN-101',
      'reason': 'Merchant recognition',
      'status': disputeStatus ?? 'open',
    },
  ];

  @override
  Future<Map<String, dynamic>> updateDisputeStatus(
    String id,
    String status,
  ) async {
    disputeStatus = status;
    return {'id': id, 'status': status};
  }

  double? simulationAmount;
  String? simulationChannel;

  @override
  Future<Map<String, dynamic>> simulateAuthorization({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
    required String channel,
  }) async {
    simulationAmount = amount;
    simulationChannel = channel;
    return {
      'decision': 'DECLINED',
      'authorization_id': 'AUTH-TEST',
      'reasons': ['Amount exceeds the daily limit'],
      'rule_results': [
        {
          'rule': 'Daily limit',
          'passed': false,
          'detail': 'Amount exceeds the daily limit',
        },
      ],
    };
  }
}
