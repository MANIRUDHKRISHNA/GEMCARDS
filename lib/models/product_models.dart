enum CardStatus { active, frozen, pending, replaced, closed }

enum TransactionStatus { approved, declined, flagged }

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.email,
    this.kycStatus = 'pending',
    this.memberSince = '',
    this.applicationStatus = 'draft',
  });

  final String id;
  final String name;
  final String email;
  final String kycStatus;
  final String memberSince;
  final String applicationStatus;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    kycStatus: json['kyc_status'] as String? ?? 'pending',
    memberSince: json['member_since'] as String? ?? '',
    applicationStatus: json['application_status'] as String? ?? 'draft',
  );
}

class Card {
  const Card({
    required this.id,
    required this.lastFour,
    required this.type,
    required this.status,
    required this.virtual,
    this.network = 'Visa',
    this.expiry = '',
    this.customerId = '',
    this.dailyLimit = 0,
    this.internationalEnabled = false,
    this.contactlessEnabled = true,
    this.onlineEnabled = true,
    this.atmEnabled = true,
  });

  final String id;
  final String lastFour;
  final String type;
  final CardStatus status;
  final bool virtual;
  final String network;
  final String expiry;
  final String customerId;
  final double dailyLimit;
  final bool internationalEnabled;
  final bool contactlessEnabled;
  final bool onlineEnabled;
  final bool atmEnabled;

  factory Card.fromJson(Map<String, dynamic> json) {
    final maskedNumber = json['masked_number'] as String? ?? '';
    final status = (json['status'] as String? ?? 'active').toLowerCase();
    final digits = maskedNumber.replaceAll(RegExp(r'\D'), '');
    return Card(
      id: json['id'] as String? ?? '',
      lastFour: digits.length <= 4
          ? digits
          : digits.substring(digits.length - 4),
      type:
          json['product'] as String? ??
          (json['card_type'] as String? ?? 'GEMCARDS'),
      status: switch (status) {
        'frozen' => CardStatus.frozen,
        'pending' => CardStatus.pending,
        'replaced' => CardStatus.replaced,
        'closed' => CardStatus.closed,
        _ => CardStatus.active,
      },
      virtual:
          (json['card_type'] as String? ?? json['type'] as String? ?? '')
              .toLowerCase() ==
          'virtual',
      network: json['network'] as String? ?? 'Visa',
      expiry: json['expiry'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      dailyLimit: _number(json['daily_limit'] ?? json['limit']),
      internationalEnabled: json['international_enabled'] as bool? ?? false,
      contactlessEnabled: json['contactless_enabled'] as bool? ?? true,
      onlineEnabled: json['online_enabled'] as bool? ?? true,
      atmEnabled: json['atm_enabled'] as bool? ?? true,
    );
  }
}

class CardTransaction {
  const CardTransaction({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.status,
    required this.time,
    this.country = '',
    this.channel = '',
    this.authorizationId = '',
    this.currency = 'INR',
    this.reasons = const [],
    this.cardId = '',
  });

  final String id;
  final String merchant;
  final double amount;
  final TransactionStatus status;
  final DateTime time;
  final String country;
  final String channel;
  final String authorizationId;
  final String currency;
  final List<String> reasons;
  final String cardId;

  factory CardTransaction.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        (json['decision'] as String? ?? json['status'] as String? ?? 'approved')
            .toLowerCase();
    final rawReasons = json['reasons'] as List<dynamic>? ?? const [];
    return CardTransaction(
      id: json['id'] as String? ?? json['authorization_id'] as String? ?? '',
      merchant: json['merchant'] as String? ?? '',
      amount: _number(json['amount']),
      status: switch (rawStatus) {
        'declined' => TransactionStatus.declined,
        'flagged' => TransactionStatus.flagged,
        _ => TransactionStatus.approved,
      },
      time:
          DateTime.tryParse(
            json['occurred_at'] as String? ??
                json['timestamp'] as String? ??
                '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      country: json['country'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      authorizationId: json['authorization_id'] as String? ?? '',
      currency: json['currency'] as String? ?? 'INR',
      reasons: rawReasons.map((value) => value.toString()).toList(),
      cardId: json['card_id'] as String? ?? '',
    );
  }
}

class FraudAlert {
  const FraudAlert({
    required this.id,
    required this.title,
    required this.severity,
    required this.customer,
    required this.amount,
    required this.location,
    required this.reason,
    this.status = 'open',
    this.transactionId = '',
  });

  final String id;
  final String title;
  final String severity;
  final String customer;
  final double amount;
  final String location;
  final String reason;
  final String status;
  final String transactionId;

  factory FraudAlert.fromJson(Map<String, dynamic> json) => FraudAlert(
    id: json['id'] as String? ?? '',
    title:
        json['merchant'] as String? ??
        json['reason'] as String? ??
        'Fraud alert',
    severity: json['severity'] as String? ?? 'low',
    customer: json['customer'] as String? ?? '',
    amount: _number(json['amount']),
    location: json['location'] as String? ?? json['country'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    transactionId: json['transaction_id'] as String? ?? '',
  );
}

class Dispute {
  const Dispute({
    required this.id,
    required this.transactionId,
    required this.reason,
    required this.status,
    this.details = '',
    this.customer = '',
    this.date = '',
    this.notes = const [],
  });

  final String id;
  final String transactionId;
  final String reason;
  final String status;
  final String details;
  final String customer;
  final String date;
  final List<String> notes;

  factory Dispute.fromJson(Map<String, dynamic> json) => Dispute(
    id: json['id'] as String? ?? '',
    transactionId: json['transaction_id'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    details: json['details'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    customer: json['customer'] as String? ?? '',
    date: json['created_at'] as String? ?? json['date'] as String? ?? '',
    notes: (json['notes'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(),
  );
}

class RewardSummary {
  const RewardSummary({
    required this.points,
    required this.availableValue,
    this.currency = 'INR',
  });

  final int points;
  final double availableValue;
  final String currency;

  factory RewardSummary.fromJson(Map<String, dynamic> json) => RewardSummary(
    points: (json['points'] as num?)?.toInt() ?? 0,
    availableValue: _number(json['available_value']),
    currency: json['currency'] as String? ?? 'INR',
  );
}

class DashboardSummary {
  const DashboardSummary({
    required this.customer,
    required this.cards,
    required this.transactions,
    required this.alerts,
    required this.rewards,
    this.availableBalance = 0,
    this.currency = 'INR',
  });

  final Customer customer;
  final List<Card> cards;
  final List<CardTransaction> transactions;
  final List<FraudAlert> alerts;
  final RewardSummary rewards;
  final double availableBalance;
  final String currency;

  factory DashboardSummary.fromJson(
    Map<String, dynamic> json,
  ) => DashboardSummary(
    customer: Customer.fromJson(
      json['customer'] as Map<String, dynamic>? ?? const {},
    ),
    cards: (json['cards'] as List<dynamic>? ?? const [])
        .map((item) => Card.fromJson(item as Map<String, dynamic>))
        .toList(),
    transactions: (json['recent_transactions'] as List<dynamic>? ?? const [])
        .map((item) => CardTransaction.fromJson(item as Map<String, dynamic>))
        .toList(),
    alerts: (json['open_fraud_alerts'] as List<dynamic>? ?? const [])
        .map((item) => FraudAlert.fromJson(item as Map<String, dynamic>))
        .toList(),
    rewards: RewardSummary.fromJson(
      json['rewards'] as Map<String, dynamic>? ?? const {},
    ),
    availableBalance: _number(json['available_balance']),
    currency: json['currency'] as String? ?? 'INR',
  );
}

class AuthorizationResult {
  const AuthorizationResult({
    required this.decision,
    required this.authorizationId,
    required this.reasons,
    required this.ruleResults,
  });

  final TransactionStatus decision;
  final String authorizationId;
  final List<String> reasons;
  final List<Map<String, dynamic>> ruleResults;

  factory AuthorizationResult.fromJson(Map<String, dynamic> json) {
    final decision = (json['decision'] as String? ?? 'DECLINED').toLowerCase();
    final rules =
        (json['rule_results'] as List<dynamic>? ??
                json['rules'] as List<dynamic>? ??
                const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    return AuthorizationResult(
      decision: switch (decision) {
        'approved' => TransactionStatus.approved,
        'flagged' => TransactionStatus.flagged,
        _ => TransactionStatus.declined,
      },
      authorizationId: json['authorization_id'] as String? ?? '',
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      ruleResults: rules,
    );
  }
}

double _number(Object? value) => value is num ? value.toDouble() : 0;
