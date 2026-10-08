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
}
