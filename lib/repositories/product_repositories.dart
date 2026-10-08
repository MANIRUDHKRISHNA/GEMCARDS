import '../models/product_models.dart';
import '../services/api/gemcards_api_client.dart';
import '../services/demo_product_service.dart';

class CustomerRepository {
  CustomerRepository(this.api);
  final GemcardsApiClient api;

  Future<Customer> getMe() async => Customer.fromJson(await api.customer());

  Future<DashboardSummary> getDashboard() async {
    final values = await Future.wait([api.dashboard(), api.customer()]);
    final dashboard = DashboardSummary.fromJson(values[0]);
    return DashboardSummary(
      customer: Customer.fromJson(values[1]),
      cards: dashboard.cards,
      transactions: dashboard.transactions,
      alerts: dashboard.alerts,
      rewards: dashboard.rewards,
      availableBalance: dashboard.availableBalance,
      currency: dashboard.currency,
    );
  }

  Future<RewardSummary> getRewards() async =>
      RewardSummary.fromJson(await api.rewards());
}

class CardRepository {
  CardRepository(this.api);
  final GemcardsApiClient api;

  Future<List<Card>> getCards() async =>
      (await api.cards()).map(Card.fromJson).toList();

  Future<List<Card>> getCustomerCards() async {
    final customer = await api.customer();
    final cards = await api.cards();
    final customerId = customer['id'] as String? ?? '';
    return cards
        .where((card) => card['customer_id'] == customerId)
        .map(Card.fromJson)
        .toList();
  }

  Future<Card> getCard(String id) async => Card.fromJson(await api.card(id));

  Future<Card> setFrozen(Card card, bool frozen) async =>
      Card.fromJson(await api.freezeCard(card.id, frozen: frozen));

  Future<Card> updateControls(String id, Map<String, Object> controls) async =>
      Card.fromJson(await api.updateCardControls(id, controls));

  Future<Card> createVirtual() async =>
      Card.fromJson(await api.createVirtualCard());
}

class TransactionRepository {
  TransactionRepository(this.api);
  final GemcardsApiClient api;

  Future<List<CardTransaction>> getTransactions() async =>
      (await api.transactions()).map(CardTransaction.fromJson).toList();

  Future<List<CardTransaction>> getCustomerTransactions() async {
    final customer = await api.customer();
    final cards = await api.cards();
    final customerId = customer['id'] as String? ?? '';
    final customerCardIds = cards
        .where((card) => card['customer_id'] == customerId)
        .map((card) => card['id'] as String?)
        .whereType<String>()
        .toSet();
    final transactions = await api.transactions();
    return transactions
        .where(
          (transaction) => customerCardIds.contains(transaction['card_id']),
        )
        .map(CardTransaction.fromJson)
        .toList();
  }

  Future<CardTransaction> getTransaction(String id) async =>
      CardTransaction.fromJson(await api.transaction(id));

  Future<AuthorizationResult> simulate({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
    required String channel,
  }) async => AuthorizationResult.fromJson(
    await api.simulateAuthorization(
      cardId: cardId,
      merchant: merchant,
      amount: amount,
      country: country,
      channel: channel,
    ),
  );
}

class AdminRepository {
  AdminRepository(this.api, this.offline);
  final GemcardsApiClient api;
  final ProductRepository offline;
  bool _offline = false;

  bool get isOffline => _offline;

  Future<T> _request<T>(
    Future<T> Function() request,
    Future<T> Function() fallback,
  ) async {
    try {
      final result = await request();
      _offline = false;
      return result;
    } on GemcardsApiException catch (error) {
      if (!error.allowOfflineFallback) rethrow;
      _offline = true;
      return fallback();
    }
  }

  Future<Map<String, dynamic>> getMetrics() => _request(
    api.adminMetrics,
    () async => const {
      'total_customers': 12480,
      'active_cards': 18340,
      'transactions_today': 918,
      'transaction_volume': 1284500,
      'pending_kyc': 24,
      'fraud_alerts': 1,
      'open_disputes': 1,
      'cards_issued_today': 42,
    },
  );

  Future<List<Map<String, dynamic>>> getCustomers() => _request(
    api.adminCustomers,
    () async => (await offline.customers())
        .map(
          (customer) => {
            'id': customer.id,
            'name': customer.name,
            'email': customer.email,
            'kyc_status': customer.kycStatus,
            'cards': 0,
            'transactions': 0,
            'risk': 'low',
          },
        )
        .toList(),
  );

  Future<List<Map<String, dynamic>>> getCards() => _request(
    api.adminCards,
    () async => (await offline.loadCards())
        .map(
          (card) => {
            'id': card.id,
            'masked_number': '•••• ${card.lastFour}',
            'customer': 'Alex Morgan',
            'product': card.type,
            'type': card.virtual ? 'virtual' : 'physical',
            'status': card.status.name,
            'limit': card.dailyLimit,
            'expiry': card.expiry,
          },
        )
        .toList(),
  );

  Future<List<Map<String, dynamic>>> getTransactions() => _request(
    api.adminTransactions,
    () async => (await offline.loadTransactions())
        .map(
          (transaction) => {
            'id': transaction.id,
            'merchant': transaction.merchant,
            'amount': transaction.amount,
            'timestamp': transaction.time.toIso8601String(),
            'status': transaction.status.name,
          },
        )
        .toList(),
  );

  Future<List<Map<String, dynamic>>> getFraud() => _request(
    api.adminFraud,
    () async => (await offline.loadFraudAlerts())
        .map(
          (alert) => {
            'id': alert.id,
            'severity': alert.severity,
            'customer': alert.customer,
            'amount': alert.amount,
            'location': alert.location,
            'reason': alert.reason,
            'status': alert.status,
          },
        )
        .toList(),
  );

  Future<List<Map<String, dynamic>>> getDisputes() => _request(
    api.adminDisputes,
    () async => (await offline.disputes())
        .map(
          (dispute) => {
            'id': dispute.id,
            'transaction_id': dispute.transactionId,
            'reason': dispute.reason,
            'status': dispute.status,
          },
        )
        .toList(),
  );

  Future<Map<String, dynamic>> simulateAuthorization({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
  }) => _request(
    () => api.adminSimulateAuthorization(
      cardId: cardId,
      merchant: merchant,
      amount: amount,
      country: country,
    ),
    () async => {
      'decision': 'APPROVED',
      'authorization_id': 'AUTH-OFFLINE-DEMO',
      'explanation': 'Offline demo only; no payment was processed.',
    },
  );

  Future<Map<String, dynamic>> setCardFrozen(
    String cardId, {
    required bool frozen,
  }) => _request(() => api.adminFreezeCard(cardId, frozen: frozen), () async {
    final current = await offline.loadCard(cardId);
    final updated = await offline.setCardFrozen(current, frozen);
    return {'id': updated.id, 'status': updated.status.name};
  });
}

class ApiProductRepository implements ProductRepository {
  ApiProductRepository({GemcardsApiClient? api, ProductRepository? offline})
    : api = api ?? GemcardsApiClient(),
      offline = offline ?? DemoProductRepository() {
    customersApi = CustomerRepository(this.api);
    cardsApi = CardRepository(this.api);
    transactionsApi = TransactionRepository(this.api);
    adminApi = AdminRepository(this.api, this.offline);
  }

  final GemcardsApiClient api;
  final ProductRepository offline;
  late final CustomerRepository customersApi;
  late final CardRepository cardsApi;
  late final TransactionRepository transactionsApi;
  late final AdminRepository adminApi;
  bool _offline = false;

  @override
  bool get isOffline => _offline;

  Future<T> _read<T>(Future<T> Function() request, Future<T> Function() demo) =>
      _run(request, demo);

  Future<T> _run<T>(
    Future<T> Function() request,
    Future<T> Function() demo,
  ) async {
    try {
      final result = await request();
      _offline = false;
      return result;
    } on GemcardsApiException catch (error) {
      if (!error.allowOfflineFallback) rethrow;
      _offline = true;
      return demo();
    }
  }

  @override
  Future<DashboardSummary> loadCustomerSummary() =>
      _read(customersApi.getDashboard, offline.loadCustomerSummary);

  @override
  Future<Customer> loadCustomer() =>
      _read(customersApi.getMe, offline.loadCustomer);

  @override
  Future<List<Card>> loadCards() =>
      _read(cardsApi.getCustomerCards, offline.loadCards);

  @override
  Future<Card> loadCard(String cardId) =>
      _read(() => cardsApi.getCard(cardId), () => offline.loadCard(cardId));

  @override
  Future<Card> setCardFrozen(Card card, bool frozen) => _read(
    () => cardsApi.setFrozen(card, frozen),
    () => offline.setCardFrozen(card, frozen),
  );

  @override
  Future<Card> updateCardControls(
    String cardId,
    Map<String, Object> controls,
  ) => _read(
    () => cardsApi.updateControls(cardId, controls),
    () => offline.updateCardControls(cardId, controls),
  );

  @override
  Future<Card> createVirtualCard() =>
      _read(cardsApi.createVirtual, offline.createVirtualCard);

  @override
  Future<List<CardTransaction>> loadTransactions() =>
      _read(transactionsApi.getCustomerTransactions, offline.loadTransactions);

  @override
  Future<CardTransaction> loadTransaction(String transactionId) =>
      _read(() async {
        final transaction = await transactionsApi.getTransaction(transactionId);
        final cards = await cardsApi.getCustomerCards();
        if (!cards.any((card) => card.id == transaction.cardId)) {
          throw const GemcardsApiException(
            'This transaction is not part of your customer account.',
            statusCode: 403,
          );
        }
        return transaction;
      }, () => offline.loadTransaction(transactionId));

  @override
  Future<RewardSummary> loadRewards() =>
      _read(customersApi.getRewards, offline.loadRewards);

  @override
  Future<List<FraudAlert>> loadFraudAlerts() async => _read(
    () async => (await api.fraud()).map(FraudAlert.fromJson).toList(),
    offline.loadFraudAlerts,
  );

  @override
  Future<List<Customer>> customers() async => _read(
    () => api.adminCustomers().then(
      (items) => items.map(Customer.fromJson).toList(),
    ),
    offline.customers,
  );

  @override
  Future<List<Dispute>> disputes() async => _read(
    () async => (await api.disputes()).map(Dispute.fromJson).toList(),
    offline.disputes,
  );

  @override
  Future<Dispute> createDispute({
    required String transactionId,
    required String reason,
    String details = '',
  }) => _read(
    () async => Dispute.fromJson(
      await api.createDispute(
        transactionId: transactionId,
        reason: reason,
        details: details,
      ),
    ),
    () => offline.createDispute(
      transactionId: transactionId,
      reason: reason,
      details: details,
    ),
  );

  @override
  Future<AuthorizationResult> simulateAuthorization({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
    required String channel,
  }) => _read(
    () => transactionsApi.simulate(
      cardId: cardId,
      merchant: merchant,
      amount: amount,
      country: country,
      channel: channel,
    ),
    () => offline.simulateAuthorization(
      cardId: cardId,
      merchant: merchant,
      amount: amount,
      country: country,
      channel: channel,
    ),
  );
}
