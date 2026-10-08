import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/models/product_models.dart';
import 'package:gemcards_onboarding_prototype/services/demo_product_service.dart';

void main() {
  test('demo product data and authorization decisions are deterministic', () async {
    final repository = DemoProductRepository();
    final summary = await repository.loadCustomerSummary();
    expect(summary.cards, hasLength(2));
    expect(summary.cards.any((card) => card.virtual), isTrue);
    expect(await repository.authorize(amount: 1200, merchant: 'Demo'), TransactionStatus.approved);
    expect(await repository.authorize(amount: 6000, merchant: 'Demo'), TransactionStatus.declined);
  });
}
