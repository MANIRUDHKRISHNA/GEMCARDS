import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/product_repositories.dart';
import '../../services/api/gemcards_api_client.dart';
import '../../services/demo_product_service.dart';

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key, this.repository});
  final AdminRepository? repository;
  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  int tab = 0;
  late final AdminRepository repository =
      widget.repository ??
      AdminRepository(GemcardsApiClient(), DemoProductRepository());
  late Future<_AdminData> _data = _loadData();
  _AdminData? _loaded;
  final labels = const [
    'Overview',
    'Customers',
    'Cards',
    'Transactions',
    'Simulator',
    'Fraud & risk',
    'Disputes',
    'Reports',
  ];

  Future<_AdminData> _loadData() async {
    final responses = await Future.wait<Object>([
      repository.getMetrics(),
      repository.getCustomers(),
      repository.getCards(),
      repository.getTransactions(),
      repository.getFraud(),
      repository.getDisputes(),
    ]);
    return _AdminData(
      metrics: responses[0] as Map<String, dynamic>,
      customers: responses[1] as List<Map<String, dynamic>>,
      cards: responses[2] as List<Map<String, dynamic>>,
      transactions: responses[3] as List<Map<String, dynamic>>,
      fraud: responses[4] as List<Map<String, dynamic>>,
      disputes: responses[5] as List<Map<String, dynamic>>,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('GEMCARDS Ops'),
      actions: const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'SYNTHETIC DEMO',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
    body: FutureBuilder<_AdminData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Operations data unavailable'),
                TextButton.icon(
                  onPressed: () => setState(() => _data = _loadData()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        _loaded = snapshot.requireData;
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        for (var index = 0; index < labels.length; index++) ...[
                          if (index > 0) const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: Icon(_icon(labels[index]), size: 17),
                            label: Text(labels[index]),
                            selected: tab == index,
                            onSelected: (_) => setState(() => tab = index),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _body(),
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: tab,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (value) => setState(() => tab = value),
                  destinations: labels
                      .map(
                        (label) => NavigationRailDestination(
                          icon: Icon(_icon(label)),
                          label: Text(label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: _body(),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
  Widget _body() {
    final data = _loaded!;
    if (tab == 0) {
      return _page(
        'Portfolio overview',
        'Deterministic synthetic operations snapshot',
        ListView(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final columns = constraints.maxWidth >= 920
                    ? 4
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * gap) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final item in [
                      _Kpi(_metric('total_customers'), 'Total customers'),
                      _Kpi(_metric('active_cards'), 'Active cards'),
                      _Kpi(_metric('transactions_today'), 'Transactions today'),
                      _Kpi(_volume(), 'Transaction volume'),
                      _Kpi(_metric('pending_kyc'), 'Pending KYC'),
                      _Kpi(_metric('fraud_alerts'), 'Fraud alerts'),
                      _Kpi(_metric('open_disputes'), 'Open disputes'),
                      _Kpi(_metric('cards_issued_today'), 'Cards issued today'),
                    ])
                      SizedBox(width: width, child: item),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const _Chart(),
            const SizedBox(height: 16),
            if (data.fraud.isNotEmpty)
              _surface(
                ListTile(
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.error,
                  ),
                  title: Text(
                    data.fraud.first['reason']?.toString() ?? 'Fraud signal',
                  ),
                  subtitle: Text(
                    '${data.fraud.first['customer'] ?? data.fraud.first['customer_id'] ?? 'Demo customer'} · '
                    '${data.fraud.first['country'] ?? data.fraud.first['location'] ?? ''} · '
                    '₹${data.fraud.first['amount'] ?? 0}',
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (tab == 1) {
      return _queue(
        'Customers',
        'Name · ID · KYC · cards · transactions · risk',
        data.customers
            .map(
              (item) =>
                  '${item['name']} · ${item['id']} · ${item['kyc_status']} · '
                  '${item['cards'] ?? 0} cards · ${item['transactions'] ?? 0} transactions · '
                  '${item['risk'] ?? 'demo'} risk',
            )
            .toList(),
      );
    }
    if (tab == 2) {
      return _cards(data.cards);
    }
    if (tab == 3) {
      return _queue(
        'Transaction operations',
        'Merchant · customer · card · timestamp · status · risk',
        data.transactions
            .map(
              (item) =>
                  '${item['merchant']} · ${item['customer'] ?? item['card_id'] ?? ''} · '
                  '${item['timestamp'] ?? item['occurred_at'] ?? ''} · '
                  '₹${item['amount'] ?? 0} · ${item['status'] ?? item['decision']}',
            )
            .toList(),
      );
    }
    if (tab == 4) {
      return _page(
        'Authorization simulator',
        'Deterministic card-status, limit and international rules',
        _Simulator(repository: repository),
      );
    }
    if (tab == 5) {
      return _fraud(data.fraud);
    }
    if (tab == 6) {
      return _disputes(data.disputes);
    }
    return _queue('Reports', 'Concise synthetic portfolio reporting', const [
      'Card issuance · 42 cards issued today',
      'Transaction volume · ₹12.8L processed today',
      'Customer growth · +128 customers this week',
      'Fraud summary · 1 open high-risk alert',
    ]);
  }

  Widget _page(String title, String subtitle, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
      ),
      const SizedBox(height: 20),
      Expanded(child: child),
    ],
  );
  Widget _queue(String title, String subtitle, List<String> rows) => _page(
    title,
    subtitle,
    ListView(
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search or filter',
          ),
        ),
        const SizedBox(height: 14),
        ...rows.map(
          (x) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _surface(
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(
                  x,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  String _metric(String name) => (_loaded!.metrics[name] ?? 0).toString();

  String _volume() {
    final volume = _loaded!.metrics['transaction_volume'];
    if (volume is num) return '₹${(volume / 100000).toStringAsFixed(1)}L';
    return '₹0';
  }

  Widget _cards(List<Map<String, dynamic>> cards) => _page(
    'Card management',
    'Masked cards, lifecycle, controls and limits',
    ListView(
      children: [
        if (cards.isEmpty)
          const ListTile(title: Text('No cards in the demo portfolio.'))
        else
          ...cards.map((card) {
            final frozen = card['status'] == 'frozen';
            final cardId = card['id']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _surface(
                ListTile(
                  leading: const Icon(Icons.credit_card_rounded),
                  title: Text(
                    '${card['masked_number'] ?? ''} · ${card['product'] ?? 'GEM card'}',
                  ),
                  subtitle: Text(
                    '${card['customer'] ?? 'Demo customer'} · '
                    '${card['network'] ?? ''} · ${card['status']} · '
                    '₹${card['limit'] ?? card['daily_limit'] ?? 0} limit',
                  ),
                  trailing: FilledButton(
                    onPressed: cardId.isEmpty
                        ? null
                        : () async {
                            try {
                              await repository.setCardFrozen(
                                cardId,
                                frozen: !frozen,
                              );
                              if (mounted) {
                                setState(() => _data = _loadData());
                              }
                            } on GemcardsApiException catch (error) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.message)),
                                );
                              }
                            }
                          },
                    child: Text(frozen ? 'Unfreeze' : 'Freeze'),
                  ),
                ),
              ),
            );
          }),
      ],
    ),
  );
  Widget _fraud(List<Map<String, dynamic>> alerts) => _page(
    'Fraud & risk',
    'Signals prioritized for operations decisions',
    alerts.isEmpty
        ? const Center(child: Text('No fraud alerts to review.'))
        : ListView(
            children: [
              for (final alert in alerts)
                _surface(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['reason']?.toString() ?? 'Fraud signal',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${alert['customer'] ?? alert['customer_id'] ?? 'Demo customer'} · '
                        '${alert['country'] ?? alert['location'] ?? ''} · '
                        '₹${alert['amount'] ?? 0} · ${alert['severity'] ?? ''}',
                      ),
                      const SizedBox(height: 12),
                      Text('Status: ${alert['status'] ?? 'open'}'),
                    ],
                  ),
                ),
            ],
          ),
  );
  Widget _disputes(List<Map<String, dynamic>> disputes) => _page(
    'Disputes',
    'Status and timeline from the GEMCARDS demo service',
    disputes.isEmpty
        ? const Center(child: Text('No disputes to review.'))
        : ListView(
            children: [
              for (final dispute in disputes)
                _surface(
                  ListTile(
                    title: Text(
                      '${dispute['id']} · ${dispute['reason'] ?? 'Dispute'}',
                    ),
                    subtitle: Text(
                      '${dispute['transaction_id'] ?? ''} · ${dispute['status'] ?? 'open'}',
                    ),
                  ),
                ),
            ],
          ),
  );
  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
  IconData _icon(String x) => x == 'Overview'
      ? Icons.grid_view
      : x == 'Customers'
      ? Icons.people_outline
      : x == 'Cards'
      ? Icons.credit_card_outlined
      : x == 'Transactions'
      ? Icons.receipt_long_outlined
      : x == 'Simulator'
      ? Icons.play_circle_outline
      : x == 'Fraud & risk'
      ? Icons.shield_outlined
      : x == 'Disputes'
      ? Icons.gavel_outlined
      : Icons.insights_outlined;
}

class _Simulator extends StatefulWidget {
  const _Simulator({required this.repository});
  final AdminRepository repository;
  @override
  State<_Simulator> createState() => _SimulatorState();
}

class _SimulatorState extends State<_Simulator> {
  final amount = TextEditingController(text: '1200');
  String country = 'India';
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? inputError;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      TextField(
        controller: amount,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() => inputError = null),
        decoration: const InputDecoration(labelText: 'Amount (₹)'),
      ),
      if (inputError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            inputError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: country,
        decoration: const InputDecoration(labelText: 'Country'),
        items: const [
          'India',
          'Singapore',
        ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => country = value);
          }
        },
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () async {
                final parsedAmount = double.tryParse(amount.text);
                if (parsedAmount == null || parsedAmount <= 0) {
                  setState(() {
                    inputError = 'Enter a valid amount greater than zero.';
                    _result = null;
                  });
                  return;
                }
                setState(() {
                  inputError = null;
                  _busy = true;
                });
                try {
                  final result = await widget.repository.simulateAuthorization(
                    cardId: 'CARD-001',
                    merchant: 'GEM Demo Merchant',
                    amount: parsedAmount,
                    country: country,
                  );
                  if (mounted) setState(() => _result = result);
                } on GemcardsApiException catch (error) {
                  if (mounted) setState(() => inputError = error.message);
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        icon: const Icon(Icons.play_arrow),
        label: Text(_busy ? 'Checking rules…' : 'Simulate authorization'),
      ),
      if (_result != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _result!['decision']?.toString() ?? 'NO DECISION',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result!['authorization_id']?.toString() ?? 'Offline demo',
                  ),
                  const Divider(),
                  Text(
                    _result!['explanation']?.toString() ??
                        'No funds were moved.',
                  ),
                  for (final rule
                      in (_result!['rules'] as List<dynamic>? ??
                          _result!['rule_results'] as List<dynamic>? ??
                          const []))
                    if (rule is Map<String, dynamic>)
                      Text(
                        '${rule['rule'] ?? rule['name']}: '
                        '${rule['passed'] == true ? 'passed' : 'failed'} · '
                        '${rule['detail'] ?? rule['explanation'] ?? ''}',
                      ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _AdminData {
  const _AdminData({
    required this.metrics,
    required this.customers,
    required this.cards,
    required this.transactions,
    required this.fraud,
    required this.disputes,
  });

  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> cards;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> fraud;
  final List<Map<String, dynamic>> disputes;
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(c).textTheme.titleLarge?.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: AppTheme.muted)),
      ],
    ),
  );
}

class _Chart extends StatelessWidget {
  const _Chart();
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction volume',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [42, 58, 49, 74, 68, 91, 83]
                .map(
                  (x) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        height: x.toDouble(),
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}
