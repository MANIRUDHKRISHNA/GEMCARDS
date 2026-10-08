import 'package:flutter/material.dart' hide Card;

import '../core/theme/app_theme.dart';
import '../models/product_models.dart';
import '../repositories/product_repositories.dart';
import '../services/demo_product_service.dart';

class GemcardsProductShell extends StatefulWidget {
  const GemcardsProductShell({super.key, this.repository});
  final ProductRepository? repository;
  @override
  State<GemcardsProductShell> createState() => _GemcardsProductShellState();
}

class _GemcardsProductShellState extends State<GemcardsProductShell> {
  late final ProductRepository _repository =
      widget.repository ?? ApiProductRepository();
  late final Future<DashboardSummary> _summary = _repository
      .loadCustomerSummary();
  bool _admin = false;
  int _tab = 0;
  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardSummary>(
    future: _summary,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final summary = snapshot.data!;
      final labels = _admin
          ? const [
              'Dashboard',
              'Customers',
              'Cards',
              'Transactions',
              'Fraud',
              'Disputes',
              'Reports',
            ]
          : const ['Home', 'Cards', 'Activity', 'More'];
      final body = _admin
          ? _AdminView(index: _tab, summary: summary, repository: _repository)
          : _CustomerView(
              index: _tab,
              summary: summary,
              onAdmin: () => setState(() {
                _admin = true;
                _tab = 0;
              }),
            );
      return Scaffold(
        appBar: AppBar(
          title: Text(_admin ? 'GEMCARDS Admin' : 'GEMCARDS'),
          actions: [
            if (_admin)
              PopupMenuButton<int>(
                tooltip: 'Admin navigation',
                onSelected: (value) => setState(() => _tab = value),
                itemBuilder: (_) => List.generate(
                  labels.length,
                  (index) =>
                      PopupMenuItem(value: index, child: Text(labels[index])),
                ),
              ),
            TextButton(
              onPressed: () => setState(() {
                _admin = !_admin;
                _tab = 0;
              }),
              child: Text(_admin ? 'Customer' : 'Admin'),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.clamp(0, (_admin ? 5 : 4) - 1),
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: labels
              .take(_admin ? 5 : 4)
              .map(
                (label) => NavigationDestination(
                  icon: Icon(_icon(label)),
                  label: label,
                ),
              )
              .toList(),
        ),
      );
    },
  );
  IconData _icon(String label) => switch (label) {
    'Home' || 'Dashboard' => Icons.home_outlined,
    'Cards' => Icons.credit_card_outlined,
    'Activity' || 'Transactions' => Icons.receipt_long_outlined,
    'Fraud' => Icons.shield_outlined,
    _ => Icons.more_horiz,
  };
}

class _CustomerView extends StatelessWidget {
  const _CustomerView({
    required this.index,
    required this.summary,
    required this.onAdmin,
  });
  final int index;
  final DashboardSummary summary;
  final VoidCallback onAdmin;
  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(context),
      _cards(context),
      _activity(context),
      _more(context),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: pages[index],
      ),
    );
  }

  Widget _home(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Good morning, ${summary.customer.name.split(' ').first}',
        style: Theme.of(c).textTheme.headlineSmall,
      ),
      const SizedBox(height: 18),
      _card(c, summary.cards.first),
      const SizedBox(height: 16),
      Text(
        '${summary.rewards.points} reward points',
        style: Theme.of(c).textTheme.titleMedium,
      ),
      Text(
        '₹${summary.rewards.availableValue.toStringAsFixed(0)} available value',
        style: const TextStyle(color: AppTheme.muted),
      ),
      const SizedBox(height: 22),
      const Text(
        'Demo card lifecycle data. No real funds or cards are involved.',
        style: TextStyle(color: AppTheme.muted),
      ),
    ],
  );
  Widget _cards(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Your cards', style: Theme.of(c).textTheme.headlineSmall),
      const SizedBox(height: 16),
      ...summary.cards.map(
        (card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(c, card),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Virtual card details are masked in this demo.',
        style: TextStyle(color: AppTheme.muted),
      ),
    ],
  );
  Widget _activity(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Recent activity', style: Theme.of(c).textTheme.headlineSmall),
      const SizedBox(height: 16),
      ...summary.transactions.map(
        (t) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
          title: Text(t.merchant),
          subtitle: Text(t.status.name),
          trailing: Text('₹${t.amount.toStringAsFixed(0)}'),
        ),
      ),
    ],
  );
  Widget _more(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('More', style: Theme.of(c).textTheme.headlineSmall),
      const SizedBox(height: 18),
      ListTile(
        leading: const Icon(Icons.admin_panel_settings_outlined),
        title: const Text('Open admin demo'),
        subtitle: const Text('Customer, card, fraud and operations view'),
        onTap: onAdmin,
      ),
    ],
  );
  Widget _card(BuildContext c, Card card) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.accentDark,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.type.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '•••• ${card.lastFour}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          card.virtual ? 'VIRTUAL • ACTIVE' : 'PHYSICAL • ACTIVE',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    ),
  );
}

class _AdminView extends StatelessWidget {
  const _AdminView({
    required this.index,
    required this.summary,
    required this.repository,
  });
  final int index;
  final DashboardSummary summary;
  final ProductRepository repository;
  @override
  Widget build(BuildContext c) {
    final labels = [
      'Portfolio overview',
      'Customers',
      'Cards',
      'Transaction simulator',
      'Fraud alerts',
      'Disputes',
      'Reports',
    ];
    final title = labels[index];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 18),
            if (index == 3) _simulator(c) else _summary(c, title),
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext c, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title == 'Fraud alerts'
            ? '${summary.alerts.length} alert requires review'
            : '${summary.cards.length} active demo cards',
        style: Theme.of(c).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Deterministic in-memory demo data for product presentation.',
        style: TextStyle(color: AppTheme.muted),
      ),
      const SizedBox(height: 18),
      ...summary.alerts.map(
        (alert) => ListTile(
          leading: const Icon(Icons.shield_outlined, color: AppTheme.warning),
          title: Text(alert.title),
          subtitle: const Text('Synthetic fraud signal'),
        ),
      ),
    ],
  );
  Widget _simulator(BuildContext c) =>
      _AuthorizationSimulator(repository: repository);
}

class _AuthorizationSimulator extends StatefulWidget {
  const _AuthorizationSimulator({required this.repository});
  final ProductRepository repository;
  @override
  State<_AuthorizationSimulator> createState() =>
      _AuthorizationSimulatorState();
}

class _AuthorizationSimulatorState extends State<_AuthorizationSimulator> {
  final _amount = TextEditingController(text: '1200');
  String _result = 'Ready';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _amount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Synthetic amount (₹)'),
      ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: () async {
          final parsedAmount = double.tryParse(_amount.text);
          if (parsedAmount == null || parsedAmount <= 0) {
            setState(() => _result = 'Enter a valid amount greater than zero.');
            return;
          }
          final result = await widget.repository.simulateAuthorization(
            cardId: 'CARD-001',
            merchant: 'Demo merchant',
            amount: parsedAmount,
            country: 'IN',
            channel: 'ONLINE',
          );
          if (mounted) {
            setState(() => _result = result.decision.name.toUpperCase());
          }
        },
        child: const Text('Simulate authorization'),
      ),
      const SizedBox(height: 16),
      Text('Result: $_result', style: Theme.of(c).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'The backend returns the authorization decision; no payment is processed.',
        style: TextStyle(color: AppTheme.muted),
      ),
    ],
  );
}
