import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/models/product_models.dart';
import 'package:gemcards_onboarding_prototype/screens/customer/customer_experience.dart';
import 'package:gemcards_onboarding_prototype/services/demo_product_service.dart';

void main() {
  testWidgets('customer home and card controls fit a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerExperienceScreen(repository: DemoProductRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('My cards'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Online payments'));
    expect(find.text('Online payments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard load failure exposes retry and recovers', (
    tester,
  ) async {
    final repository = _StubProductRepository(failFirstLoad: true);
    await tester.pumpWidget(
      MaterialApp(home: CustomerExperienceScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard unavailable'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(repository.loadCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single-card profile avoids virtual-card index failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerExperienceScreen(
          repository: _StubProductRepository(virtualCard: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cards').last);
    await tester.pumpAndSettle();
    expect(find.text('View virtual card'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('Virtual card'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('freezing the physical card does not freeze the virtual card', (
    tester,
  ) async {
    final repository = _StubProductRepository();
    final summary = await repository.loadCustomerSummary();
    expect(summary.cards, hasLength(2));
    expect(summary.cards.last.virtual, isTrue);
    await tester.pumpWidget(
      MaterialApp(home: CustomerExperienceScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cards').last);
    await tester.pumpAndSettle();
    expect(find.text('My cards'), findsOneWidget);
    await tester.ensureVisible(find.text('Freeze card'));
    await tester.tap(find.text('Freeze card'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Virtual card'));
    await tester.tap(find.text('Virtual card'));
    await tester.pumpAndSettle();
    expect(find.text('Freeze virtual card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card controls send changes and display returned values', (
    tester,
  ) async {
    final repository = _StubProductRepository();
    await tester.pumpWidget(
      MaterialApp(home: CustomerExperienceScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cards').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Online payments'));
    await tester.tap(find.text('Online payments'));
    await tester.pumpAndSettle();
    expect(repository.lastControls, {'online_enabled': false});

    await tester.ensureVisible(find.text('Daily spending limit'));
    await tester.tap(find.text('Daily spending limit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '75000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastControls, {'daily_limit': 75000});
    expect(find.text('₹75000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('virtual card creation displays the returned card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerExperienceScreen(
          repository: _StubProductRepository(virtualCard: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cards').last);
    await tester.pumpAndSettle();
    expect(find.text('My cards'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create virtual card'));
    await tester.tap(find.text('Create virtual card'));
    await tester.pumpAndSettle();

    expect(find.text('Virtual · 9105'), findsOneWidget);
    expect(find.text('•••• 9105  •  GEM Virtual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'transaction details render backend metadata and submit a dispute',
    (tester) async {
      final repository = _StubProductRepository(
        transactions: [
          CardTransaction(
            id: 'TXN-101',
            merchant: 'Metro Mart',
            amount: 1240,
            status: TransactionStatus.approved,
            time: DateTime(2026, 10, 9, 8, 16),
            country: 'IN',
            channel: 'POS',
            authorizationId: 'AUTH-101',
            cardId: 'CARD-001',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: CustomerExperienceScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metro Mart'));
      await tester.pumpAndSettle();

      expect(find.text('AUTH-101'), findsOneWidget);
      expect(find.text('IN'), findsOneWidget);
      expect(find.text('POS'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Report or dispute'));
      await tester.tap(find.text('Report or dispute'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason for review'),
        'Unrecognized merchant',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Additional details (optional)'),
        'I do not recognize this purchase.',
      );
      await tester.tap(find.text('Submit dispute'));
      await tester.pumpAndSettle();

      expect(repository.lastDisputeReason, 'Unrecognized merchant');
      expect(
        repository.lastDisputeDetails,
        'I do not recognize this purchase.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _StubProductRepository extends DemoProductRepository {
  _StubProductRepository({
    this.failFirstLoad = false,
    this.virtualCard = true,
    this.transactions = const [],
  });

  final bool failFirstLoad;
  final bool virtualCard;
  final List<CardTransaction> transactions;
  int loadCount = 0;
  Map<String, Object>? lastControls;
  String? lastDisputeReason;
  String? lastDisputeDetails;

  @override
  Future<DashboardSummary> loadCustomerSummary() async {
    loadCount++;
    if (failFirstLoad && loadCount == 1) {
      throw StateError('Synthetic test failure');
    }
    final cards = <Card>[
      const Card(
        id: 'CARD-001',
        lastFour: '4821',
        type: 'GEMCARDS Platinum',
        status: CardStatus.active,
        virtual: false,
      ),
      if (virtualCard)
        const Card(
          id: 'CARD-V01',
          lastFour: '9104',
          type: 'Virtual card',
          status: CardStatus.active,
          virtual: true,
        ),
    ];
    return DashboardSummary(
      customer: const Customer(
        id: 'CUS-DEMO-001',
        name: 'Alex Morgan',
        email: 'alex.morgan@example.demo',
        kycStatus: 'verified',
        applicationStatus: 'card_active',
      ),
      cards: cards,
      transactions: transactions,
      alerts: const [],
      rewards: const RewardSummary(points: 0, availableValue: 0),
      availableBalance: 24680,
    );
  }

  @override
  Future<List<Card>> loadCards() async => (await loadCustomerSummary()).cards;

  @override
  Future<List<CardTransaction>> loadTransactions() async => transactions;

  @override
  Future<CardTransaction> loadTransaction(String transactionId) async =>
      transactions.firstWhere((item) => item.id == transactionId);

  @override
  Future<Card> updateCardControls(
    String cardId,
    Map<String, Object> controls,
  ) async {
    lastControls = controls;
    final current = (await loadCards()).firstWhere((card) => card.id == cardId);
    return Card(
      id: current.id,
      lastFour: current.lastFour,
      type: current.type,
      status: current.status,
      virtual: current.virtual,
      dailyLimit:
          (controls['daily_limit'] as num?)?.toDouble() ?? current.dailyLimit,
      onlineEnabled:
          controls['online_enabled'] as bool? ?? current.onlineEnabled,
      contactlessEnabled:
          controls['contactless_enabled'] as bool? ??
          current.contactlessEnabled,
      internationalEnabled:
          controls['international_enabled'] as bool? ??
          current.internationalEnabled,
      atmEnabled: controls['atm_enabled'] as bool? ?? current.atmEnabled,
    );
  }

  @override
  Future<Dispute> createDispute({
    required String transactionId,
    required String reason,
    String details = '',
  }) async {
    lastDisputeReason = reason;
    lastDisputeDetails = details;
    return Dispute(
      id: 'DSP-TEST',
      transactionId: transactionId,
      reason: reason,
      details: details,
      status: 'open',
    );
  }
}
