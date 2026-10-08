import '../models/product_models.dart';

abstract class ProductRepository {
  bool get isOffline;
  Future<DashboardSummary> loadCustomerSummary();
  Future<Customer> loadCustomer();
  Future<List<Card>> loadCards();
  Future<Card> loadCard(String cardId);
  Future<Card> setCardFrozen(Card card, bool frozen);
  Future<Card> updateCardControls(String cardId, Map<String, Object> controls);
  Future<Card> createVirtualCard();
  Future<List<CardTransaction>> loadTransactions();
  Future<CardTransaction> loadTransaction(String transactionId);
  Future<RewardSummary> loadRewards();
  Future<List<FraudAlert>> loadFraudAlerts();
  Future<List<Customer>> customers();
  Future<List<Dispute>> disputes();
  Future<Dispute> createDispute({
    required String transactionId,
    required String reason,
    String details = '',
  });
  Future<AuthorizationResult> simulateAuthorization({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
    required String channel,
  });
}

class DemoProductRepository implements ProductRepository {
  final Customer _customer = const Customer(
    id: 'CUS-DEMO-001',
    name: 'Alex Morgan',
    email: 'alex.morgan@example.demo',
    kycStatus: 'verified',
    memberSince: '2024',
    applicationStatus: 'card_active',
  );
  final List<Card> _cards = [
    const Card(
      id: 'CARD-001',
      lastFour: '4821',
      type: 'GEMCARDS Platinum',
      status: CardStatus.active,
      virtual: false,
      dailyLimit: 50000,
      onlineEnabled: true,
      contactlessEnabled: true,
    ),
    const Card(
      id: 'CARD-V01',
      lastFour: '9104',
      type: 'Virtual card',
      status: CardStatus.active,
      virtual: true,
      dailyLimit: 25000,
      onlineEnabled: true,
      contactlessEnabled: false,
    ),
  ];

  final List<CardTransaction> _transactions = [
    CardTransaction(
      id: 'TXN-101',
      merchant: 'Metro Mart',
      amount: 1240,
      status: TransactionStatus.approved,
      time: DateTime(2026, 10, 9),
      cardId: 'CARD-001',
    ),
    CardTransaction(
      id: 'TXN-102',
      merchant: 'CloudStream',
      amount: 299,
      status: TransactionStatus.approved,
      time: DateTime(2026, 10, 8),
      cardId: 'CARD-001',
    ),
  ];
  final List<Dispute> _disputes = [
    const Dispute(
      id: 'DSP-01',
      transactionId: 'TXN-101',
      reason: 'Demo merchant query',
      status: 'open',
    ),
  ];
  int _virtualCardSequence = 1;
  @override
  bool get isOffline => true;

  @override
  Future<DashboardSummary> loadCustomerSummary() async => DashboardSummary(
    customer: _customer,
    cards: List.unmodifiable(_cards),
    transactions: List.unmodifiable(_transactions),
    alerts: const [
      FraudAlert(
        id: 'FRA-01',
        title: 'New merchant detected',
        severity: 'low',
        customer: 'Alex Morgan',
        amount: 0,
        location: 'India',
        reason: 'Synthetic fraud signal',
      ),
    ],
    rewards: const RewardSummary(points: 1240, availableValue: 124),
    availableBalance: 24680,
  );

  @override
  Future<Customer> loadCustomer() async => _customer;

  @override
  Future<List<Card>> loadCards() async => List.unmodifiable(_cards);

  @override
  Future<Card> loadCard(String cardId) async =>
      _cards.firstWhere((item) => item.id == cardId);

  @override
  Future<Card> setCardFrozen(Card card, bool frozen) async {
    final updated = _copyCard(
      card,
      status: frozen ? CardStatus.frozen : CardStatus.active,
    );
    _replaceCard(updated);
    return updated;
  }

  @override
  Future<Card> updateCardControls(
    String cardId,
    Map<String, Object> controls,
  ) async {
    final current = _cards.firstWhere((item) => item.id == cardId);
    final updated = _copyCard(
      current,
      dailyLimit: controls['daily_limit'] as num?,
      internationalEnabled: controls['international_enabled'] as bool?,
      contactlessEnabled: controls['contactless_enabled'] as bool?,
      onlineEnabled: controls['online_enabled'] as bool?,
      atmEnabled: controls['atm_enabled'] as bool?,
    );
    _replaceCard(updated);
    return updated;
  }

  @override
  Future<Card> createVirtualCard() async {
    _virtualCardSequence++;
    final card = Card(
      id: 'CARD-V${_virtualCardSequence.toString().padLeft(2, '0')}',
      lastFour: '910${_virtualCardSequence + 3}',
      type: 'GEM Virtual',
      status: CardStatus.active,
      virtual: true,
      dailyLimit: 25000,
    );
    _cards.add(card);
    return card;
  }

  @override
  Future<List<CardTransaction>> loadTransactions() async =>
      List.unmodifiable(_transactions);

  @override
  Future<CardTransaction> loadTransaction(String transactionId) async =>
      _transactions.firstWhere((item) => item.id == transactionId);

  @override
  Future<RewardSummary> loadRewards() async =>
      const RewardSummary(points: 1240, availableValue: 124);

  @override
  Future<List<FraudAlert>> loadFraudAlerts() async =>
      (await loadCustomerSummary()).alerts;

  @override
  Future<List<Customer>> customers() async => [
    _customer,
    const Customer(
      id: 'CUS-DEMO-002',
      name: 'Priya Shah',
      email: 'priya.shah@example.demo',
      kycStatus: 'under_review',
    ),
  ];

  @override
  Future<List<Dispute>> disputes() async => List.unmodifiable(_disputes);

  @override
  Future<Dispute> createDispute({
    required String transactionId,
    required String reason,
    String details = '',
  }) async {
    final dispute = Dispute(
      id: 'DSP-DEMO-${(_disputes.length + 1).toString().padLeft(3, '0')}',
      transactionId: transactionId,
      reason: reason,
      status: 'open',
      details: details,
    );
    _disputes.add(dispute);
    return dispute;
  }

  @override
  Future<AuthorizationResult> simulateAuthorization({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
    required String channel,
  }) async {
    const status = TransactionStatus.approved;
    return const AuthorizationResult(
      decision: status,
      authorizationId: 'AUTH-OFFLINE-DEMO',
      reasons: ['Offline demo authorization; no payment was processed.'],
      ruleResults: [],
    );
  }

  void _replaceCard(Card updated) {
    final index = _cards.indexWhere((item) => item.id == updated.id);
    if (index >= 0) _cards[index] = updated;
  }
}

Card _copyCard(
  Card card, {
  CardStatus? status,
  num? dailyLimit,
  bool? internationalEnabled,
  bool? contactlessEnabled,
  bool? onlineEnabled,
  bool? atmEnabled,
}) => Card(
  id: card.id,
  lastFour: card.lastFour,
  type: card.type,
  status: status ?? card.status,
  virtual: card.virtual,
  network: card.network,
  expiry: card.expiry,
  dailyLimit: dailyLimit?.toDouble() ?? card.dailyLimit,
  internationalEnabled: internationalEnabled ?? card.internationalEnabled,
  contactlessEnabled: contactlessEnabled ?? card.contactlessEnabled,
  onlineEnabled: onlineEnabled ?? card.onlineEnabled,
  atmEnabled: atmEnabled ?? card.atmEnabled,
);
