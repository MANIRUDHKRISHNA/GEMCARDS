import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/repositories/product_repositories.dart';
import 'package:gemcards_onboarding_prototype/services/api/gemcards_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'admin repository delegates operational actions to backend endpoints',
    () async {
      final requests = <http.Request>[];
      final repository = AdminRepository(
        GemcardsApiClient(
          baseUrl: 'http://ops.test',
          httpClient: MockClient((request) async {
            requests.add(request);
            final body = switch (request.url.path) {
              '/api/v1/admin/metrics' => {'total_customers': 3},
              '/api/v1/admin/customers' => [
                {'id': 'CUS-01', 'name': 'Alex'},
              ],
              '/api/v1/admin/customers/CUS-01' => {
                'id': 'CUS-01',
                'cards_detail': [],
              },
              '/api/v1/admin/cards' => [
                {'id': 'CARD-01', 'status': 'active'},
              ],
              '/api/v1/admin/cards/CARD-01' => {
                'id': 'CARD-01',
                'status': 'active',
              },
              '/api/v1/admin/cards/CARD-01/limit' => {
                'id': 'CARD-01',
                'limit': 75000,
              },
              '/api/v1/admin/cards/CARD-01/replace' => {
                'card': {'id': 'CARD-01', 'status': 'replaced'},
                'message': 'Demo replacement requested',
              },
              '/api/v1/admin/cards/CARD-01/freeze' => {
                'id': 'CARD-01',
                'status': 'frozen',
              },
              '/api/v1/admin/cards/CARD-01/unfreeze' => {
                'id': 'CARD-01',
                'status': 'active',
              },
              '/api/v1/admin/transactions' => [],
              '/api/v1/admin/fraud' => [],
              '/api/v1/fraud/FRA-01/resolve' => {
                'id': 'FRA-01',
                'status': 'resolved',
              },
              '/api/v1/admin/disputes' => [],
              '/api/v1/disputes/DSP-01/status' => {
                'id': 'DSP-01',
                'status': 'investigating',
              },
              '/api/v1/transactions/simulate' => {
                'decision': 'DECLINED',
                'authorization_id': 'AUTH-01',
                'reasons': ['Amount exceeds the daily limit'],
                'rule_results': [
                  {
                    'rule': 'Daily limit',
                    'passed': false,
                    'detail': 'Amount exceeds the daily limit',
                  },
                ],
              },
              _ => <String, Object>{},
            };
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );

      expect((await repository.getMetrics())['total_customers'], 3);
      await repository.getCustomers(query: 'Alex', kycStatus: 'verified');
      await repository.getCustomer('CUS-01');
      await repository.getCards();
      await repository.getCard('CARD-01');
      expect(
        (await repository.updateCardLimit('CARD-01', 75000))['limit'],
        75000,
      );
      expect(
        (await repository.replaceCard('CARD-01'))['message'],
        'Demo replacement requested',
      );
      await repository.setCardFrozen('CARD-01', frozen: true);
      await repository.setCardFrozen('CARD-01', frozen: false);
      await repository.getTransactions();
      await repository.getFraud();
      await repository.resolveFraud('FRA-01');
      await repository.getDisputes();
      await repository.updateDisputeStatus('DSP-01', 'investigating');
      final simulation = await repository.simulateAuthorization(
        cardId: 'CARD-01',
        merchant: 'Demo merchant',
        amount: 80000,
        country: 'India',
        channel: 'ONLINE',
      );
      expect(simulation['decision'], 'DECLINED');
      expect(simulation['rule_results'], isNotEmpty);

      final customerListRequest = requests.singleWhere(
        (request) => request.url.path == '/api/v1/admin/customers',
      );
      expect(customerListRequest.url.queryParameters, {
        'query': 'Alex',
        'kyc_status': 'verified',
      });
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        containsAll([
          'GET /api/v1/admin/customers/CUS-01',
          'GET /api/v1/admin/cards/CARD-01',
          'POST /api/v1/admin/cards/CARD-01/limit',
          'POST /api/v1/admin/cards/CARD-01/replace',
          'POST /api/v1/fraud/FRA-01/resolve',
          'POST /api/v1/disputes/DSP-01/status',
          'POST /api/v1/transactions/simulate',
        ]),
      );
      expect(
        jsonDecode(
          requests
              .singleWhere((request) => request.url.path.endsWith('/limit'))
              .body,
        ),
        {'limit': 75000},
      );
      expect(
        jsonDecode(
          requests
              .singleWhere((request) => request.url.path.endsWith('/simulate'))
              .body,
        ),
        {
          'card_id': 'CARD-01',
          'merchant': 'Demo merchant',
          'amount': 80000,
          'country': 'India',
          'channel': 'ONLINE',
        },
      );
      expect(repository.isOffline, isFalse);
    },
  );

  test(
    'admin repository surfaces backend failures without local mock data',
    () async {
      final repository = AdminRepository(
        GemcardsApiClient(
          baseUrl: 'http://ops.test',
          httpClient: MockClient(
            (_) async => http.Response(
              '{"detail":"Operations service unavailable"}',
              503,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );

      await expectLater(
        repository.getMetrics(),
        throwsA(
          isA<GemcardsApiException>().having(
            (error) => error.message,
            'message',
            'Operations service unavailable',
          ),
        ),
      );
      expect(repository.isOffline, isTrue);
    },
  );
}
