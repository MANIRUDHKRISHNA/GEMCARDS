import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/models/product_models.dart';
import 'package:gemcards_onboarding_prototype/repositories/product_repositories.dart';
import 'package:gemcards_onboarding_prototype/services/api/gemcards_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('preserves the replaced card lifecycle state from the API', () {
    final card = Card.fromJson({..._card, 'status': 'replaced'});
    expect(card.status, CardStatus.replaced);
  });

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
    expect(summary.availableBalance, 24680);
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

  test(
    'scopes customer data and delegates card, dispute, and virtual flows',
    () async {
      final requests = <http.Request>[];
      final repository = ApiProductRepository(
        api: GemcardsApiClient(
          baseUrl: 'http://gemcards.test',
          httpClient: MockClient((request) async {
            requests.add(request);
            final path = request.url.path;
            final response = switch ('${request.method} $path') {
              'GET /api/v1/customer/me' => _customer,
              'GET /api/v1/cards' => [_card, _otherCustomerCard],
              'GET /api/v1/transactions' => [_transaction, _otherTransaction],
              'GET /api/v1/transactions/TXN-101' => _transaction,
              'POST /api/v1/cards/CARD-001/freeze' => _cardFrozen,
              'POST /api/v1/cards/CARD-001/unfreeze' => _card,
              'PATCH /api/v1/cards/CARD-001/controls' => {
                ..._card,
                'daily_limit': 75000,
                'online_enabled': false,
              },
              'POST /api/v1/cards/virtual' => _virtualCard,
              'POST /api/v1/disputes' => _dispute,
              _ => <String, Object>{},
            };
            return http.Response(
              jsonEncode(response),
              request.method == 'POST' && path.endsWith('/virtual') ? 201 : 200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );

      final cards = await repository.loadCards();
      expect(cards.map((card) => card.id), ['CARD-001']);
      expect(
        (await repository.setCardFrozen(cards.single, true)).status,
        CardStatus.frozen,
      );
      expect(
        (await repository.setCardFrozen(cards.single, false)).status,
        CardStatus.active,
      );

      final changed = await repository.updateCardControls('CARD-001', {
        'daily_limit': 75000,
        'online_enabled': false,
      });
      expect(changed.dailyLimit, 75000);
      expect(changed.onlineEnabled, isFalse);

      final transactions = await repository.loadTransactions();
      expect(transactions.map((transaction) => transaction.id), ['TXN-101']);
      expect(
        (await repository.loadTransaction('TXN-101')).authorizationId,
        'AUTH-101',
      );
      expect((await repository.createVirtualCard()).virtual, isTrue);
      final dispute = await repository.createDispute(
        transactionId: 'TXN-101',
        reason: 'Unrecognized merchant',
        details: 'I do not recognize this purchase.',
      );
      expect(dispute.details, 'I do not recognize this purchase.');

      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        containsAll([
          'POST /api/v1/cards/CARD-001/freeze',
          'POST /api/v1/cards/CARD-001/unfreeze',
          'PATCH /api/v1/cards/CARD-001/controls',
          'POST /api/v1/cards/virtual',
          'POST /api/v1/disputes',
        ]),
      );
      final controlsRequest = requests.singleWhere(
        (request) => request.method == 'PATCH',
      );
      expect(jsonDecode(controlsRequest.body), {
        'daily_limit': 75000,
        'online_enabled': false,
      });
      final disputeRequest = requests.singleWhere(
        (request) => request.url.path == '/api/v1/disputes',
      );
      expect(jsonDecode(disputeRequest.body), {
        'transaction_id': 'TXN-101',
        'reason': 'Unrecognized merchant',
        'details': 'I do not recognize this purchase.',
      });
    },
  );

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
  'application_status': 'card_active',
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
  'available_balance': 24680,
  'currency': 'INR',
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

final _otherCustomerCard = {
  ..._card,
  'id': 'CARD-OTHER',
  'customer_id': 'CUS-DEMO-002',
};

const _transaction = {
  'id': 'TXN-101',
  'authorization_id': 'AUTH-101',
  'card_id': 'CARD-001',
  'merchant': 'Metro Mart',
  'amount': 1240,
  'country': 'IN',
  'channel': 'POS',
  'decision': 'APPROVED',
  'occurred_at': '2026-10-09T08:16:00Z',
  'reasons': <String>[],
};

final _otherTransaction = {
  ..._transaction,
  'id': 'TXN-OTHER',
  'card_id': 'CARD-OTHER',
};

final _virtualCard = {
  ..._card,
  'id': 'CARD-V02',
  'product': 'GEM Virtual',
  'card_type': 'virtual',
  'masked_number': '•••• 1102',
};

const _dispute = {
  'id': 'DSP-101',
  'transaction_id': 'TXN-101',
  'customer_id': 'CUS-DEMO-001',
  'reason': 'Unrecognized merchant',
  'details': 'I do not recognize this purchase.',
  'status': 'open',
  'created_at': '2026-10-09T12:00:00Z',
};
