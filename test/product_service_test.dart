import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/models/product_models.dart';
import 'package:gemcards_onboarding_prototype/services/demo_product_service.dart';

void main() {
  test(
    'offline demo data and authorization fallback are deterministic',
    () async {
      final repository = DemoProductRepository();
      final summary = await repository.loadCustomerSummary();
      expect(summary.cards, hasLength(2));
      expect(summary.cards.any((card) => card.virtual), isTrue);
      final approved = await repository.simulateAuthorization(
        cardId: 'CARD-001',
        merchant: 'Demo',
        amount: 1200,
        country: 'IN',
        channel: 'ONLINE',
      );
      final fallback = await repository.simulateAuthorization(
        cardId: 'CARD-001',
        merchant: 'Demo',
        amount: 6000,
        country: 'IN',
        channel: 'ONLINE',
      );
      expect(approved.decision, TransactionStatus.approved);
      expect(fallback.decision, TransactionStatus.approved);
      expect(fallback.reasons.single, contains('Offline demo'));
    },
  );

  test('offline cards, transactions, disputes and virtual creation are stateful', () async {
    final repository = DemoProductRepository();
    final initialCards = await repository.loadCards();
    final frozen = await repository.setCardFrozen(initialCards.first, true);
    expect(frozen.status, CardStatus.frozen);
    final controls = await repository.updateCardControls(frozen.id, {
      'online_enabled': false,
      'contactless_enabled': false,
      'international_enabled': true,
      'atm_enabled': false,
      'daily_limit': 42000,
    });
    expect(controls.onlineEnabled, isFalse);
    expect(controls.dailyLimit, 42000);
    final virtual = await repository.createVirtualCard();
    expect(virtual.virtual, isTrue);
    expect((await repository.loadCards()), hasLength(3));
    expect((await repository.loadTransactions()).first.merchant, 'Metro Mart');
    final dispute = await repository.createDispute(
      transactionId: 'TXN-101',
      reason: 'Merchant recognition',
    );
    expect(dispute.status, 'open');
  });
}
