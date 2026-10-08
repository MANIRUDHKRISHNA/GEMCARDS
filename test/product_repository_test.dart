import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/models/product_models.dart';
import 'package:gemcards_onboarding_prototype/repositories/product_repositories.dart';
import 'package:gemcards_onboarding_prototype/services/api/gemcards_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('decodes the backend dashboard and delegates card controls', () async {
    final requests = <http.Request>[];
    final repository = ApiProductRepository(
      api: GemcardsApiClient(
        baseUrl: 'http://gemcards.test',
        httpClient: MockClient((request) async {
          requests.add(request);
          final body = switch (request.url.path) {
            '/api/v1/customer/dashboard' => _dashboard,
            '/api/v1/customer/me' => _customer,
            '/api/v1/cards' => [_card],
            '/api/v1/cards/CARD-001/freeze' => _cardFrozen,
            _ => <String, Object>{},
          };
          return http.Response.bytes(
            utf8.encode(jsonEncode(body)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    final summary = await repository.loadCustomerSummary();
    expect(summary.customer.name, 'Alex Morgan');
    expect(summary.cards.single.lastFour, '4821');
    expect(summary.transactions.single.status, TransactionStatus.flagged);
    expect(summary.alerts.single.title, 'Northstar Electronics');
    expect(repository.isOffline, isFalse);

    final cards = await repository.loadCards();
    expect(cards.single.dailyLimit, 50000);
    final updated = await repository.setCardFrozen(cards.single, true);
    expect(updated.status, CardStatus.frozen);
    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      contains('POST /api/v1/cards/CARD-001/freeze'),
    );
  });

  test('falls back to the local demo when the API is unreachable', () async {
    final repository = ApiProductRepository(
      api: GemcardsApiClient(
        baseUrl: 'http://gemcards.test',
        httpClient: MockClient(
          (_) => throw http.ClientException('service unavailable'),
        ),
      ),
    );

    final summary = await repository.loadCustomerSummary();
    expect(summary.customer.id, 'CUS-DEMO-001');
    expect(repository.isOffline, isTrue);
  });
}

const _customer = {
  'id': 'CUS-DEMO-001',
  'name': 'Alex Morgan',
  'email': 'alex@example.demo',
  'kyc_status': 'verified',
  'member_since': '2026-10-01',
};

const _card = {
  'id': 'CARD-001',
  'customer_id': 'CUS-DEMO-001',
  'product': 'GEMCARDS Platinum',
  'card_type': 'physical',
  'network': 'Visa',
  'masked_number': '•••• 4821',
  'expiry': '09/30',
  'status': 'active',
  'daily_limit': 50000,
  'international_enabled': false,
  'contactless_enabled': true,
  'online_enabled': true,
  'atm_enabled': true,
};

final _cardFrozen = {..._card, 'status': 'frozen'};

const _dashboard = {
  'customer': _customer,
  'cards': [_card],
  'recent_transactions': [
    {
      'id': 'TXN-103',
      'authorization_id': 'AUTH-SEED-103',
      'card_id': 'CARD-001',
      'merchant': 'Northstar Electronics',
      'amount': 9800,
      'currency': 'INR',
      'country': 'SG',
      'channel': 'ONLINE',
      'decision': 'FLAGGED',
      'occurred_at': '2026-10-09T08:16:00Z',
      'reasons': ['High-value transaction from a foreign location'],
    },
  ],
  'open_fraud_alerts': [
    {
      'id': 'FRA-01',
      'transaction_id': 'TXN-103',
      'customer_id': 'CUS-DEMO-001',
      'merchant': 'Northstar Electronics',
      'amount': 9800,
      'country': 'SG',
      'severity': 'high',
      'reason': 'High-value foreign transaction needs review',
      'status': 'open',
      'created_at': '2026-10-09T08:16:00Z',
    },
  ],
  'rewards': {
    'customer_id': 'CUS-DEMO-001',
    'points': 1240,
    'available_value': 124,
    'currency': 'INR',
  },
};
