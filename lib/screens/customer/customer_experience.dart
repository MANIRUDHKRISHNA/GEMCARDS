import 'package:flutter/material.dart' hide Card;

import '../../core/theme/app_theme.dart';
import '../../models/product_models.dart';
import '../../services/demo_product_service.dart';
import '../../widgets/customer/gem_card_visual.dart';

class CustomerExperienceScreen extends StatefulWidget {
  const CustomerExperienceScreen({super.key, this.repository});
  final ProductRepository? repository;
  @override
  State<CustomerExperienceScreen> createState() =>
      _CustomerExperienceScreenState();
}

class _CustomerExperienceScreenState extends State<CustomerExperienceScreen> {
  late Future<DashboardSummary> _summary;
  int _index = 0;
  final Map<String, bool> _frozenOverrides = {};

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
  }

  Future<DashboardSummary> _loadSummary() =>
      (widget.repository ?? DemoProductRepository()).loadCustomerSummary();

  bool _isFrozen(Card card) =>
      _frozenOverrides[card.id] ?? card.status == CardStatus.frozen;

  void _setFrozen(Card card, bool frozen) {
    setState(() => _frozenOverrides[card.id] = frozen);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardSummary>(
    future: _summary,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          backgroundColor: AppTheme.surface,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(height: 18),
                Text('Preparing your dashboard'),
              ],
            ),
          ),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Scaffold(
          backgroundColor: AppTheme.surface,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 34,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Dashboard unavailable',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We couldn’t load your demo account right now.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _summary = _loadSummary();
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final summary = snapshot.requireData;
      if (summary.cards.isEmpty) {
        return const Scaffold(
          backgroundColor: AppTheme.surface,
          body: _EmptyState(
            icon: Icons.credit_card_off_outlined,
            title: 'No cards yet',
            message: 'Cards for this demo profile will appear here.',
          ),
        );
      }
      final primaryCard = summary.cards.first;
      Card? virtualCard;
      for (final card in summary.cards) {
        if (card.virtual) {
          virtualCard = card;
          break;
        }
      }
      final pages = [
        _Home(
          summary: summary,
          frozen: _isFrozen(primaryCard),
          onCards: () => setState(() => _index = 1),
          onActivity: () => setState(() => _index = 2),
        ),
        _Cards(
          summary: summary,
          primaryCard: primaryCard,
          frozen: _isFrozen(primaryCard),
          onFrozen: (value) => _setFrozen(primaryCard, value),
          virtualCard: virtualCard,
          virtualFrozen: virtualCard == null ? false : _isFrozen(virtualCard),
          onVirtualFrozen: virtualCard == null
              ? null
              : (value) => _setFrozen(virtualCard!, value),
        ),
        _Transactions(summary: summary),
        _More(
          summary: summary,
          virtualCard: virtualCard,
          virtualFrozen: virtualCard == null ? false : _isFrozen(virtualCard),
          onVirtualFrozen: virtualCard == null
              ? null
              : (value) => _setFrozen(virtualCard!, value),
        ),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('GEMCARDS'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 18),
              child: Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(.015, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
        ),
        bottomNavigationBar: NavigationBar(
          height: 72,
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.credit_card_outlined),
              label: 'Cards',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'More',
            ),
          ],
        ),
      );
    },
  );
}

class _Home extends StatelessWidget {
  const _Home({
    required this.summary,
    required this.frozen,
    required this.onCards,
    required this.onActivity,
  });
  final DashboardSummary summary;
  final bool frozen;
  final VoidCallback onCards;
  final VoidCallback onActivity;
  @override
  Widget build(BuildContext c) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good morning, ${summary.customer.name.split(' ').first}',
            style: Theme.of(c).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Your card application is ready',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          Text('Available balance', style: Theme.of(c).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('₹ 24,680.00', style: Theme.of(c).textTheme.displaySmall),
          const SizedBox(height: 20),
          GemCardVisual(card: summary.cards.first, frozen: frozen),
          const SizedBox(height: 20),
          _QuickActions(onCards: onCards, onActivity: onActivity),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent transactions',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
              ),
              TextButton(onPressed: onActivity, child: const Text('See all')),
            ],
          ),
          if (summary.transactions.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No activity yet',
              message: 'Your card transactions will appear here.',
            )
          else
            ...summary.transactions
                .take(3)
                .map(
                  (transaction) => _TransactionTile(
                    transaction: transaction,
                    onTap: () => Navigator.of(c).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TransactionDetailsScreen(transaction: transaction),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 18),
          _SpendSummary(transactions: summary.transactions),
        ],
      ),
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onCards, required this.onActivity});
  final VoidCallback onCards;
  final VoidCallback onActivity;
  @override
  Widget build(BuildContext c) => Row(
    children: [
      Expanded(
        child: _Action(
          icon: Icons.ac_unit_rounded,
          label: 'Card controls',
          onTap: onCards,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Action(
          icon: Icons.bar_chart_rounded,
          label: 'Spending',
          onTap: () => Navigator.of(
            c,
          ).push(MaterialPageRoute(builder: (_) => const SpendingScreen())),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Action(
          icon: Icons.receipt_long_rounded,
          label: 'Activity',
          onTap: onActivity,
        ),
      ),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    child: Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentDark.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: AppTheme.accentDark, size: 19),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(c).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Cards extends StatefulWidget {
  const _Cards({
    required this.summary,
    required this.primaryCard,
    required this.frozen,
    required this.onFrozen,
    required this.virtualCard,
    required this.virtualFrozen,
    required this.onVirtualFrozen,
  });
  final DashboardSummary summary;
  final Card primaryCard;
  final bool frozen;
  final ValueChanged<bool> onFrozen;
  final Card? virtualCard;
  final bool virtualFrozen;
  final ValueChanged<bool>? onVirtualFrozen;
  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  bool online = true, contactless = true, international = false, atm = true;
  @override
  Widget build(BuildContext c) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('My cards', style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 18),
        GemCardVisual(card: widget.primaryCard, frozen: widget.frozen),
        const SizedBox(height: 12),
        Text(
          '•••• ${widget.primaryCard.lastFour}  •  ${widget.primaryCard.type}',
          style: const TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        SwitchListTile(
          isThreeLine: true,
          value: widget.frozen,
          onChanged: widget.onFrozen,
          title: const Text('Freeze card'),
          subtitle: Text(
            widget.frozen ? 'Card is temporarily frozen' : 'Card is active',
          ),
        ),
        _toggle('Online payments', online, (v) => setState(() => online = v)),
        _toggle(
          'Contactless payments',
          contactless,
          (v) => setState(() => contactless = v),
        ),
        _toggle(
          'International payments',
          international,
          (v) => setState(() => international = v),
        ),
        _toggle('ATM withdrawals', atm, (v) => setState(() => atm = v)),
        const ListTile(
          title: Text('Monthly spending limit'),
          trailing: Text('₹50,000'),
        ),
        const Divider(),
        if (widget.virtualCard != null)
          ListTile(
            leading: const Icon(Icons.credit_card_rounded),
            title: const Text('View virtual card'),
            onTap: () => Navigator.of(c).push(
              MaterialPageRoute(
                builder: (_) => VirtualCardScreen(
                  card: widget.virtualCard!,
                  frozen: widget.virtualFrozen,
                  onFrozen: widget.onVirtualFrozen!,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
    SwitchListTile(value: value, onChanged: onChanged, title: Text(label));

class _Transactions extends StatefulWidget {
  const _Transactions({required this.summary});
  final DashboardSummary summary;
  @override
  State<_Transactions> createState() => _TransactionsState();
}

class _TransactionsState extends State<_Transactions> {
  String query = '';
  String filter = 'All';
  @override
  Widget build(BuildContext c) {
    final items = widget.summary.transactions
        .where(
          (t) =>
              (filter == 'All' || t.status.name == filter.toLowerCase()) &&
              t.merchant.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transactions',
                  style: Theme.of(c).textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search merchant',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['All', 'approved', 'pending', 'declined']
                      .map(
                        (label) => ChoiceChip(
                          label: Text(
                            label == 'All'
                                ? label
                                : label[0].toUpperCase() + label.substring(1),
                          ),
                          selected: filter == label,
                          onSelected: (_) => setState(() => filter = label),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching transactions',
                    message: 'Try another merchant or status filter.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _TransactionTile(
                      transaction: items[i],
                      onTap: () => Navigator.of(c).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              TransactionDetailsScreen(transaction: items[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _More extends StatelessWidget {
  const _More({
    required this.summary,
    required this.virtualCard,
    required this.virtualFrozen,
    required this.onVirtualFrozen,
  });
  final DashboardSummary summary;
  final Card? virtualCard;
  final bool virtualFrozen;
  final ValueChanged<bool>? onVirtualFrozen;
  @override
  Widget build(BuildContext c) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('More', style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('GEM Rewards'),
          subtitle: Text('${summary.rewards.points} points available'),
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute(builder: (_) => RewardsScreen(summary: summary)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart_outlined),
          title: const Text('Spending insights'),
          onTap: () => Navigator.of(
            c,
          ).push(MaterialPageRoute(builder: (_) => const SpendingScreen())),
        ),
        if (virtualCard != null)
          ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: const Text('Virtual card'),
            onTap: () => Navigator.of(c).push(
              MaterialPageRoute(
                builder: (_) => VirtualCardScreen(
                  card: virtualCard!,
                  frozen: virtualFrozen,
                  onFrozen: onVirtualFrozen!,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onTap});
  final CardTransaction transaction;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => ListTile(
    onTap: onTap,
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    leading: CircleAvatar(
      radius: 21,
      backgroundColor: AppTheme.accentDark.withValues(alpha: .07),
      child: const Icon(Icons.storefront_outlined, color: AppTheme.accentDark),
    ),
    title: Text(
      transaction.merchant,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      '${transaction.status.name.toUpperCase()}  ·  ${MaterialLocalizations.of(c).formatMediumDate(transaction.time)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(c).textTheme.bodySmall,
    ),
    trailing: Text(
      '₹${transaction.amount.toStringAsFixed(0)}',
      style: Theme.of(c).textTheme.titleMedium?.copyWith(fontSize: 14),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    ),
  );
}

class _SpendSummary extends StatelessWidget {
  const _SpendSummary({required this.transactions});
  final List<CardTransaction> transactions;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent spend', style: Theme.of(c).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          '₹${transactions.fold<double>(0, (total, transaction) => total + transaction.amount).toStringAsFixed(0)}',
          style: Theme.of(c).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${transactions.length} recent ${transactions.length == 1 ? 'transaction' : 'transactions'}',
          style: Theme.of(c).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class VirtualCardScreen extends StatelessWidget {
  const VirtualCardScreen({
    required this.card,
    required this.frozen,
    required this.onFrozen,
    super.key,
  });
  final Card card;
  final bool frozen;
  final ValueChanged<bool> onFrozen;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Virtual card')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GemCardVisual(card: card, frozen: frozen),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Card number'),
            subtitle: Text('•••• •••• •••• ${card.lastFour}'),
          ),
          const ListTile(title: Text('Expiry'), trailing: Text('09/30')),
          const ListTile(title: Text('CVV'), trailing: Text('•••')),
          FilledButton.icon(
            onPressed: () => onFrozen(!frozen),
            icon: Icon(
              frozen ? Icons.play_arrow_rounded : Icons.ac_unit_rounded,
            ),
            label: Text(
              frozen ? 'Unfreeze virtual card' : 'Freeze virtual card',
            ),
          ),
          TextButton.icon(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(
              const SnackBar(
                content: Text(
                  'Virtual card deletion is simulated in this demo.',
                ),
              ),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete virtual card'),
          ),
        ],
      ),
    ),
  );
}

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({required this.transaction, super.key});
  final CardTransaction transaction;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Transaction details')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '₹${transaction.amount.toStringAsFixed(0)}',
          style: Theme.of(c).textTheme.displaySmall,
        ),
        const SizedBox(height: 18),
        _detail(c, 'Merchant', transaction.merchant),
        _detail(
          c,
          'Date & time',
          '${MaterialLocalizations.of(c).formatMediumDate(transaction.time)}, ${TimeOfDay.fromDateTime(transaction.time).format(c)}',
        ),
        _detail(c, 'Status', transaction.status.name.toUpperCase()),
        _detail(c, 'Reference ID', transaction.id),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(c).showSnackBar(
            const SnackBar(
              content: Text('Dispute request saved as a demo action.'),
            ),
          ),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Report or dispute'),
        ),
      ],
    ),
  );
  Widget _detail(BuildContext c, String a, String b) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 8,
    title: Text(a),
    subtitle: Text(b, style: Theme.of(c).textTheme.bodyMedium),
  );
}

class SpendingScreen extends StatelessWidget {
  const SpendingScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Spending')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('₹1,539', style: Theme.of(c).textTheme.displaySmall),
        const Text('Monthly spend', style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 24),
        const _SpendSummary(transactions: []),
        const SizedBox(height: 20),
        const ListTile(title: Text('Shopping'), trailing: Text('₹1,240')),
        const ListTile(title: Text('Subscriptions'), trailing: Text('₹299')),
        const ListTile(
          title: Text('Largest transaction'),
          subtitle: Text('Metro Mart'),
          trailing: Text('₹1,240'),
        ),
      ],
    ),
  );
}

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({required this.summary, super.key});
  final DashboardSummary summary;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('GEM Rewards')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${summary.rewards.points} points',
          style: Theme.of(c).textTheme.displaySmall,
        ),
        Text(
          'Worth ₹${summary.rewards.availableValue.toStringAsFixed(0)} in this demo',
          style: const TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 24),
        const ListTile(
          title: Text('+240 points'),
          subtitle: Text('Metro Mart purchase'),
        ),
        const ListTile(
          title: Text('+60 points'),
          subtitle: Text('CloudStream purchase'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => ScaffoldMessenger.of(c).showSnackBar(
            const SnackBar(
              content: Text('Redemption is simulated for this demo.'),
            ),
          ),
          child: const Text('Redeem 500 points'),
        ),
      ],
    ),
  );
}
