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
      const MaterialApp(home: CustomerExperienceScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('My cards'), findsOneWidget);
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('View virtual card'), findsOneWidget);
    await tester.tap(find.text('Freeze card'));
    await tester.pumpAndSettle();
    expect(find.text('View virtual card'), findsOneWidget);
    await tester.tap(find.text('View virtual card'));
    await tester.pumpAndSettle();

    expect(find.text('Freeze virtual card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StubProductRepository implements ProductRepository {
  _StubProductRepository({this.failFirstLoad = false, this.virtualCard = true});

  final bool failFirstLoad;
  final bool virtualCard;
  int loadCount = 0;

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
      ),
      cards: cards,
      transactions: const [],
      alerts: const [],
      rewards: const RewardSummary(points: 0, availableValue: 0),
    );
  }

  @override
  Future<List<Customer>> customers() async => const [];

  @override
  Future<List<Dispute>> disputes() async => const [];

  @override
  Future<TransactionStatus> authorize({
    required double amount,
    required String merchant,
  }) async => TransactionStatus.approved;
}
