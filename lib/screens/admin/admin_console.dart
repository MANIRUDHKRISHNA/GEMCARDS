import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/product_repositories.dart';
import '../../services/api/gemcards_api_client.dart';

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key, this.repository});
  final AdminRepository? repository;
  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  int tab = 0;
  late final AdminRepository repository =
      widget.repository ?? AdminRepository(GemcardsApiClient());
  late Future<_AdminData> _data = _loadData();
  _AdminData? _loaded;
  String _customerQuery = '';
  String _kycFilter = 'All';
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
                  onPressed: () => setState(() {
                    _data = _loadData();
                  }),
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
            _Chart(
              volumeSeries: _series('volume_series'),
              issuanceSeries: _series('issuance_series'),
            ),
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
      return _customers(data.customers);
    }
    if (tab == 2) {
      return _cards(data.cards);
    }
    if (tab == 3) {
      return _transactions(data.transactions);
    }
    if (tab == 4) {
      return _page(
        'Authorization simulator',
        'Deterministic card-status, limit and international rules',
        _Simulator(repository: repository, cards: data.cards),
      );
    }
    if (tab == 5) {
      return _fraud(data.fraud);
    }
    if (tab == 6) {
      return _disputes(data.disputes);
    }
    return _reports(data.metrics);
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
  String _metric(String name) => (_loaded!.metrics[name] ?? 0).toString();

  String _volume() {
    final volume = _loaded!.metrics['transaction_volume'];
    if (volume is num) return '₹${(volume / 100000).toStringAsFixed(1)}L';
    return '₹0';
  }

  List<double> _series(String name) =>
      (_loaded!.metrics[name] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList();

  Widget _customers(List<Map<String, dynamic>> customers) {
    final visible = customers.where((customer) {
      final query = _customerQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          ['name', 'id', 'email'].any(
            (field) =>
                customer[field]?.toString().toLowerCase().contains(query) ??
                false,
          );
      final matchesStatus =
          _kycFilter == 'All' || customer['kyc_status'] == _kycFilter;
      return matchesQuery && matchesStatus;
    }).toList();

    return _page(
      'Customers',
      'Search and review customer onboarding and risk',
      ListView(
        children: [
          TextField(
            onChanged: (value) => setState(() => _customerQuery = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, customer ID, or email',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kycFilter,
            decoration: const InputDecoration(labelText: 'KYC status'),
            items: const ['All', 'verified', 'under_review', 'pending']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value == 'All' ? value : _titleCase(value)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _kycFilter = value);
            },
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const ListTile(title: Text('No matching customers.'))
          else
            for (final customer in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _surface(
                  ListTile(
                    onTap: () =>
                        _showCustomerDetail(customer['id']?.toString() ?? ''),
                    leading: const Icon(Icons.account_circle_outlined),
                    title: Text(customer['name']?.toString() ?? 'Customer'),
                    subtitle: Text(
                      '${customer['id'] ?? ''} · ${customer['kyc_status'] ?? 'unknown'} · '
                      '${customer['cards'] ?? 0} cards · ${customer['transactions'] ?? 0} transactions · '
                      '${customer['risk'] ?? 'unknown'} risk',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _showCustomerDetail(String customerId) async {
    if (customerId.isEmpty) return;
    var detailFuture = repository.getCustomer(customerId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Customer details'),
          content: SizedBox(
            width: 520,
            child: FutureBuilder<Map<String, dynamic>>(
              future: detailFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Customer details unavailable.'),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          detailFuture = repository.getCustomer(customerId);
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                }
                final customer = snapshot.requireData;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${customer['email'] ?? ''}'),
                      Text('KYC: ${customer['kyc_status'] ?? 'unknown'}'),
                      Text('Risk: ${customer['risk'] ?? 'unknown'}'),
                      const SizedBox(height: 12),
                      _detailSection('Cards', customer['cards_detail']),
                      _detailSection(
                        'Transactions',
                        customer['transactions_detail'],
                      ),
                      _detailSection('Disputes', customer['disputes']),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCardDetail(String cardId) async {
    var detailFuture = repository.getCard(cardId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Card details'),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<Map<String, dynamic>>(
              future: detailFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Card details unavailable.'),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          detailFuture = repository.getCard(cardId);
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                }
                final card = snapshot.requireData;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${card['product'] ?? 'GEM card'} · ${card['id']}'),
                    Text(
                      'Customer: ${card['customer'] ?? card['customer_id']}',
                    ),
                    Text('Status: ${card['status']}'),
                    Text(
                      'Daily limit: ₹${card['limit'] ?? card['daily_limit'] ?? 0}',
                    ),
                    Text('Type: ${card['type'] ?? 'unknown'}'),
                    Text('Expiry: ${card['expiry'] ?? '—'}'),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, Object? records) {
    final items = records is List<dynamic>
        ? records.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('None'))
          else
            for (final item in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item['merchant']?.toString() ??
                      item['product']?.toString() ??
                      item['reason']?.toString() ??
                      item['id']?.toString() ??
                      title,
                ),
                subtitle: Text(
                  '${item['status'] ?? item['timestamp'] ?? ''} · '
                  '${item['amount'] == null ? '' : '₹${item['amount']}'}',
                ),
              ),
        ],
      ),
    );
  }

  Widget _transactions(List<Map<String, dynamic>> transactions) => _page(
    'Transaction operations',
    'Customer · merchant · card · amount · decision · risk · timestamp',
    transactions.isEmpty
        ? const Center(child: Text('No transactions in the demo portfolio.'))
        : ListView(
            children: [
              for (final item in transactions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _surface(
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        '${item['merchant'] ?? 'Merchant'} · ₹${item['amount'] ?? 0}',
                      ),
                      subtitle: Text(
                        '${item['customer'] ?? 'Customer'} · '
                        '${item['card'] ?? item['card_id'] ?? 'Card'} · '
                        '${_titleCase(item['status']?.toString() ?? item['decision']?.toString() ?? 'unknown')} · '
                        'Risk ${item['risk_score'] ?? '—'} · '
                        '${item['timestamp'] ?? item['occurred_at'] ?? ''}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );

  Widget _reports(Map<String, dynamic> metrics) => _page(
    'Reports',
    'Portfolio summary sourced from operations metrics',
    ListView(
      children: [
        for (final metric in [
          ('total_customers', 'Total customers'),
          ('active_cards', 'Active cards'),
          ('transactions_today', 'Transactions today'),
          ('transaction_volume', 'Transaction volume (INR)'),
          ('pending_kyc', 'Pending KYC'),
          ('fraud_alerts', 'Open fraud alerts'),
          ('open_disputes', 'Open disputes'),
          ('cards_issued_today', 'Cards issued today'),
        ])
          _surface(
            ListTile(
              title: Text(metric.$2),
              trailing: Text('${metrics[metric.$1] ?? '—'}'),
            ),
          ),
      ],
    ),
  );

  void _reload() {
    setState(() {
      _data = _loadData();
    });
  }

  Future<void> _changeCardLimit(String cardId, Object? currentLimit) async {
    var value = currentLimit?.toString() ?? '';
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change card limit'),
        content: TextFormField(
          initialValue: value,
          keyboardType: TextInputType.number,
          onChanged: (next) => value = next,
          decoration: const InputDecoration(
            labelText: 'Daily limit (INR)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (entered == null) return;
    final limit = int.tryParse(entered.trim());
    if (limit == null || limit < 1000 || limit > 250000) {
      _showMessage('Enter a limit between ₹1,000 and ₹250,000.');
      return;
    }
    try {
      await repository.updateCardLimit(cardId, limit);
      if (mounted) _reload();
    } on GemcardsApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _replaceCard(String cardId) async {
    try {
      final response = await repository.replaceCard(cardId);
      if (mounted) {
        _showMessage(
          response['message']?.toString() ?? 'Replacement simulated.',
        );
        _reload();
      }
    } on GemcardsApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _setCardFrozen(String cardId, {required bool frozen}) async {
    try {
      await repository.setCardFrozen(cardId, frozen: frozen);
      if (mounted) _reload();
    } on GemcardsApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _resolveFraud(String alertId) async {
    try {
      await repository.resolveFraud(alertId);
      if (mounted) _reload();
    } on GemcardsApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _updateDispute(String disputeId, String status) async {
    try {
      await repository.updateDisputeStatus(disputeId, status);
      if (mounted) _reload();
    } on GemcardsApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
            final status = card['status']?.toString() ?? 'unknown';
            final frozen = status == 'frozen';
            final cardId = card['id']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _surface(
                ListTile(
                  onTap: cardId.isEmpty ? null : () => _showCardDetail(cardId),
                  leading: const Icon(Icons.credit_card_rounded),
                  title: Text(
                    '${card['masked_number'] ?? ''} · ${card['product'] ?? 'GEM card'}',
                  ),
                  subtitle: Text(
                    '${card['customer'] ?? 'Demo customer'} · '
                    '${card['network'] ?? ''} · ${card['status']} · '
                    '₹${card['limit'] ?? card['daily_limit'] ?? 0} limit',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Card operations',
                    onSelected: (action) {
                      if (action == 'freeze') {
                        _setCardFrozen(cardId, frozen: true);
                      } else if (action == 'unfreeze') {
                        _setCardFrozen(cardId, frozen: false);
                      } else if (action == 'limit') {
                        _changeCardLimit(
                          cardId,
                          card['limit'] ?? card['daily_limit'],
                        );
                      } else if (action == 'replace') {
                        _replaceCard(cardId);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!frozen)
                        const PopupMenuItem(
                          value: 'freeze',
                          child: Text('Freeze card'),
                        ),
                      if (frozen)
                        const PopupMenuItem(
                          value: 'unfreeze',
                          child: Text('Unfreeze card'),
                        ),
                      const PopupMenuItem(
                        value: 'limit',
                        child: Text('Change limit'),
                      ),
                      const PopupMenuItem(
                        value: 'replace',
                        child: Text('Simulate replacement'),
                      ),
                    ],
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
                      Row(
                        children: [
                          Expanded(
                            child: Text('Status: ${alert['status'] ?? 'open'}'),
                          ),
                          if (alert['status'] == 'open')
                            TextButton(
                              onPressed: () =>
                                  _resolveFraud(alert['id']?.toString() ?? ''),
                              child: const Text('Resolve alert'),
                            ),
                        ],
                      ),
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
                    trailing: DropdownButton<String>(
                      value:
                          const [
                            'open',
                            'investigating',
                            'resolved',
                          ].contains(dispute['status'])
                          ? dispute['status'] as String
                          : 'open',
                      underline: const SizedBox.shrink(),
                      items: const ['open', 'investigating', 'resolved']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_titleCase(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (status) {
                        if (status != null &&
                            status != dispute['status'] &&
                            dispute['id'] != null) {
                          _updateDispute(dispute['id'].toString(), status);
                        }
                      },
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
    child: Material(color: AppTheme.surface, child: child),
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
  const _Simulator({required this.repository, required this.cards});
  final AdminRepository repository;
  final List<Map<String, dynamic>> cards;
  @override
  State<_Simulator> createState() => _SimulatorState();
}

class _SimulatorState extends State<_Simulator> {
  final amount = TextEditingController(text: '1200');
  final merchant = TextEditingController(text: 'GEM Demo Merchant');
  String country = 'India';
  String channel = 'ONLINE';
  String cardId = 'CARD-001';
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? inputError;

  @override
  void dispose() {
    amount.dispose();
    merchant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      TextField(
        controller: merchant,
        decoration: const InputDecoration(labelText: 'Merchant'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: widget.cards.any((card) => card['id'] == cardId)
            ? cardId
            : widget.cards.isEmpty
            ? null
            : widget.cards.first['id']?.toString(),
        decoration: const InputDecoration(labelText: 'Card'),
        items: widget.cards
            .map(
              (card) => DropdownMenuItem(
                value: card['id']?.toString() ?? '',
                child: Text(
                  '${card['id']} · ${card['status']} · ₹${card['limit'] ?? card['daily_limit'] ?? 0}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => cardId = value);
        },
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: channel,
        decoration: const InputDecoration(labelText: 'Channel'),
        items: const ['ONLINE', 'POS', 'ATM']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => channel = value);
        },
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          _scenario('A · ₹2,000 India', 2000, 'India'),
          _scenario('B · ₹80,000', 80000, country),
          _scenario('C · ₹9,800 Singapore', 9800, 'Singapore'),
        ],
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
                    cardId: cardId,
                    merchant: merchant.text.trim(),
                    amount: parsedAmount,
                    country: country,
                    channel: channel,
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
                  if ((_result!['reasons'] as List<dynamic>? ?? const [])
                      .isNotEmpty)
                    for (final reason in _result!['reasons'] as List<dynamic>)
                      Text('Reason: $reason'),
                  if ((_result!['reasons'] as List<dynamic>? ?? const [])
                      .isEmpty)
                    const Text('No funds were moved.'),
                  for (final rule
                      in (_result!['rule_results'] as List<dynamic>? ??
                          _result!['rules'] as List<dynamic>? ??
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

  Widget _scenario(String label, double amountValue, String countryValue) =>
      ActionChip(
        label: Text(label),
        onPressed: () => setState(() {
          amount.text = amountValue.toStringAsFixed(0);
          country = countryValue;
        }),
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
  const _Chart({required this.volumeSeries, required this.issuanceSeries});
  final List<double> volumeSeries;
  final List<double> issuanceSeries;

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
        _seriesChart('Transaction volume', volumeSeries),
        const SizedBox(height: 18),
        _seriesChart('Cards issued', issuanceSeries),
      ],
    ),
  );

  Widget _seriesChart(String title, List<double> values) {
    final maximum = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (values.isEmpty)
          const Text('No series data available.')
        else
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: values
                  .map(
                    (value) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Tooltip(
                          message: value.toStringAsFixed(0),
                          child: Container(
                            height: maximum == 0 ? 2 : 82 * value / maximum,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

String _titleCase(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
