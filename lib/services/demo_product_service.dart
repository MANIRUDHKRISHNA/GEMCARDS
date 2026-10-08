import '../models/product_models.dart';

abstract class ProductRepository { Future<DashboardSummary> loadCustomerSummary(); Future<List<Customer>> customers(); Future<List<Dispute>> disputes(); Future<TransactionStatus> authorize({required double amount, required String merchant}); }

class DemoProductRepository implements ProductRepository {
  final _customer = const Customer(id: 'CUS-DEMO-001', name: 'Alex Morgan', email: 'alex.morgan@example.demo');
  @override Future<DashboardSummary> loadCustomerSummary() async => DashboardSummary(customer: _customer, cards: const [Card(id: 'CARD-001', lastFour: '4821', type: 'GEMCARDS Platinum', status: CardStatus.active, virtual: false), Card(id: 'CARD-V01', lastFour: '9104', type: 'Virtual card', status: CardStatus.active, virtual: true)], transactions: [CardTransaction(id: 'TXN-101', merchant: 'Metro Mart', amount: 1240, status: TransactionStatus.approved, time: DateTime(2026, 10, 9)), CardTransaction(id: 'TXN-102', merchant: 'CloudStream', amount: 299, status: TransactionStatus.approved, time: DateTime(2026, 10, 8))], alerts: const [FraudAlert(id: 'FRA-01', title: 'New merchant detected', severity: FraudSeverity.low, resolved: false)], rewards: const RewardSummary(points: 1240, availableValue: 124));
  @override Future<List<Customer>> customers() async => [_customer, const Customer(id: 'CUS-DEMO-002', name: 'Priya Shah', email: 'priya.shah@example.demo')];
  @override Future<List<Dispute>> disputes() async => const [Dispute(id: 'DSP-01', transactionId: 'TXN-101', reason: 'Demo merchant query', status: 'Open')];
  @override Future<TransactionStatus> authorize({required double amount, required String merchant}) async => amount <= 5000 ? TransactionStatus.approved : TransactionStatus.declined;
}
