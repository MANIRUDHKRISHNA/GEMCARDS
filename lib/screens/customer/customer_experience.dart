import 'package:flutter/material.dart' hide Card;

import '../../core/theme/app_theme.dart';
import '../../models/product_models.dart';
import '../../repositories/product_repositories.dart';
import '../../screens/admin/admin_console.dart';
import '../../screens/kyc_flow_screen.dart';
import '../../services/api/gemcards_api_client.dart';
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
  late final ProductRepository _repository =
      widget.repository ?? ApiProductRepository(api: GemcardsApiClient());
  int _index = 0;
  final Map<String, bool> _frozenOverrides = {};
  List<Card>? _cardsOverride;
  bool _cardsLoading = false;
  String? _cardsError;

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
  }

  Future<DashboardSummary> _loadSummary() => _repository.loadCustomerSummary();

  Future<void> _startKyc() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const KycFlowScreen()),
    );
    if (!mounted) return;
    setState(() {
      _summary = _loadSummary();
      _cardsOverride = null;
      _index = 0;
    });
  }

  bool _isFrozen(Card card) =>
      _frozenOverrides[card.id] ?? card.status == CardStatus.frozen;

  Future<void> _setFrozen(Card card, bool frozen) async {
    try {
      final updated = await _repository.setCardFrozen(card, frozen);
      if (mounted) {
        setState(() {
          _frozenOverrides[updated.id] = updated.status == CardStatus.frozen;
          if (_cardsOverride != null) {
            _cardsOverride = [
              for (final current in _cardsOverride!)
                if (current.id == updated.id) updated else current,
            ];
          }
        });
      }
    } on GemcardsApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openCards() async {
    setState(() {
      _index = 1;
      _cardsLoading = true;
      _cardsError = null;
    });
    try {
      final cards = await _repository.loadCards();
      if (mounted) setState(() => _cardsOverride = cards);
    } on GemcardsApiException catch (error) {
      if (mounted) {
        setState(() => _cardsError = error.message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _cardsLoading = false);
    }
  }

  Future<void> _createVirtualCard() async {
    try {
      final existingCards = _cardsOverride ?? await _repository.loadCards();
      final card = await _repository.createVirtualCard();
      if (mounted) {
        setState(() {
          _cardsOverride = [...existingCards, card];
          _index = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _repository.isOffline
                  ? 'Virtual card added to offline sample data.'
                  : 'Virtual card created.',
            ),
          ),
        );
      }
    } on GemcardsApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
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
                      'We couldn’t load your account right now.',
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
      if (summary.cards.isEmpty || (_cardsOverride?.isEmpty ?? false)) {
        return Scaffold(
          backgroundColor: AppTheme.surface,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EmptyState(
                      icon: Icons.credit_card_off_outlined,
                      title: 'No cards yet',
                      message:
                          'Complete your application to continue with a card.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _startKyc,
                      child: const Text('Complete application'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final visibleCards = _cardsOverride ?? summary.cards;
      final primaryCard = visibleCards.first;
      Card? virtualCard;
      for (final card in visibleCards) {
        if (card.virtual) {
          virtualCard = card;
          break;
        }
      }
      final pages = [
        _Home(
          summary: summary,
          frozen: _isFrozen(primaryCard),
          onCards: _openCards,
          onActivity: () => setState(() => _index = 2),
          onApply: _startKyc,
          repository: _repository,
          isOffline: _repository.isOffline,
        ),
        _cardsLoading
            ? const Center(child: CircularProgressIndicator())
            : _cardsError != null
            ? _RetryPanel(message: _cardsError!, onRetry: _openCards)
            : _Cards(
                cards: visibleCards,
                isFrozen: _isFrozen,
                onFrozen: _setFrozen,
                onCardUpdated: (updated) => setState(() {
                  _cardsOverride = [
                    for (final card in visibleCards)
                      if (card.id == updated.id) updated else card,
                  ];
                }),
                repository: _repository,
                onCreateVirtual: _createVirtualCard,
                isOffline: _repository.isOffline,
              ),
        _Transactions(summary: summary, repository: _repository),
        _More(
          summary: summary,
          virtualCard: virtualCard,
          virtualFrozen: virtualCard == null ? false : _isFrozen(virtualCard),
          onVirtualFrozen: virtualCard == null
              ? null
              : (value) => _setFrozen(virtualCard!, value),
          repository: _repository,
          onCreateVirtual: _createVirtualCard,
          onStartKyc: _startKyc,
        ),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('GEMCARDS'),
          actions: [
            if (_repository.isOffline)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: 'Offline sample data',
                  child: Icon(Icons.cloud_off_outlined, size: 20),
                ),
              ),
            IconButton(
              tooltip: 'Open admin console',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminConsoleScreen(),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
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
          onDestinationSelected: (value) {
            if (value == 1) {
              _openCards();
            } else {
              setState(() => _index = value);
            }
          },
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
    required this.onApply,
    required this.repository,
    required this.isOffline,
  });
  final DashboardSummary summary;
  final bool frozen;
  final VoidCallback onCards;
  final VoidCallback onActivity;
  final VoidCallback onApply;
  final ProductRepository repository;
  final bool isOffline;
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
          if (isOffline)
            const Text(
              'Offline sample data · changes stay on this device',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          Text(
            summary.customer.kycStatus == 'verified'
                ? 'Your card application is ready'
                : 'Continue your card application',
            style: const TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Complete application · Verify identity'),
          ),
          const SizedBox(height: 20),
          Text('Available balance', style: Theme.of(c).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            '${summary.currency == 'INR' ? '₹' : '${summary.currency} '}${summary.availableBalance.toStringAsFixed(2)}',
            style: Theme.of(c).textTheme.displaySmall,
          ),
          const SizedBox(height: 20),
          GemCardVisual(card: summary.cards.first, frozen: frozen),
          const SizedBox(height: 20),
          _QuickActions(
            onCards: onCards,
            onActivity: onActivity,
            repository: repository,
          ),
          const SizedBox(height: 26),
          if (summary.alerts.isNotEmpty)
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.accentDark,
                ),
                title: Text(
                  '${summary.alerts.length} security ${summary.alerts.length == 1 ? 'alert' : 'alerts'}',
                ),
                subtitle: const Text('Review recent account activity'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(c).push(
                  MaterialPageRoute(
                    builder: (_) => FraudActivityScreen(repository: repository),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
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
                        builder: (_) => TransactionDetailsScreen(
                          transaction: transaction,
                          repository: repository,
                        ),
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
  const _QuickActions({
    required this.onCards,
    required this.onActivity,
    required this.repository,
  });
  final VoidCallback onCards;
  final VoidCallback onActivity;
  final ProductRepository repository;
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
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) => SpendingScreen(repository: repository),
            ),
          ),
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
    required this.cards,
    required this.isFrozen,
    required this.onFrozen,
    required this.onCardUpdated,
    required this.repository,
    required this.onCreateVirtual,
    required this.isOffline,
  });
  final List<Card> cards;
  final bool Function(Card card) isFrozen;
  final void Function(Card card, bool frozen) onFrozen;
  final ValueChanged<Card> onCardUpdated;
  final ProductRepository repository;
  final VoidCallback onCreateVirtual;
  final bool isOffline;
  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  bool _updating = false;
  late bool _offline;
  String? _selectedCardId;
  final ScrollController _scrollController = ScrollController();

  Card get _card => widget.cards.firstWhere(
    (card) => card.id == _selectedCardId,
    orElse: () => widget.cards.first,
  );

  @override
  void initState() {
    super.initState();
    _offline = widget.isOffline;
    _selectedCardId = widget.cards.first.id;
  }

  @override
  void didUpdateWidget(covariant _Cards oldWidget) {
    super.didUpdateWidget(oldWidget);
    _offline = widget.isOffline;
    final oldIds = oldWidget.cards.map((card) => card.id).toSet();
    for (final card in widget.cards) {
      if (!oldIds.contains(card.id)) {
        _selectedCardId = card.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
        break;
      }
    }
    if (!widget.cards.any((card) => card.id == _selectedCardId)) {
      _selectedCardId = widget.cards.first.id;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateControl(String name, Object value) async {
    setState(() => _updating = true);
    try {
      final updated = await widget.repository.updateCardControls(_card.id, {
        name: value,
      });
      if (mounted) {
        setState(() {
          _offline = widget.repository.isOffline;
        });
        widget.onCardUpdated(updated);
      }
    } on GemcardsApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _editDailyLimit() async {
    var valueText = _card.dailyLimit.toStringAsFixed(0);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Daily spending limit'),
        content: TextFormField(
          initialValue: valueText,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (value) => valueText = value,
          decoration: const InputDecoration(
            labelText: 'Limit in INR',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, valueText.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final limit = int.tryParse(value);
    if (limit == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid whole-number limit.')),
        );
      }
      return;
    }
    await _updateControl('daily_limit', limit);
  }

  @override
  Widget build(BuildContext c) => SafeArea(
    child: ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text('My cards', style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 18),
        if (widget.cards.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.cards
                .map(
                  (card) => ChoiceChip(
                    label: Text(
                      card.virtual
                          ? 'Virtual · ${card.lastFour}'
                          : '${card.type} · ${card.lastFour}',
                    ),
                    selected: card.id == _card.id,
                    onSelected: (_) =>
                        setState(() => _selectedCardId = card.id),
                  ),
                )
                .toList(),
          ),
        if (widget.cards.length > 1) const SizedBox(height: 14),
        GemCardVisual(card: _card, frozen: widget.isFrozen(_card)),
        const SizedBox(height: 12),
        Text(
          '•••• ${_card.lastFour}  •  ${_card.type}',
          style: const TextStyle(color: AppTheme.muted),
        ),
        if (_offline)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Offline mode · card changes stay on this device',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 18),
        SwitchListTile(
          isThreeLine: true,
          key: const ValueKey('freeze-card-control'),
          value: widget.isFrozen(_card),
          onChanged:
              _updating ||
                  !const {
                    CardStatus.active,
                    CardStatus.frozen,
                  }.contains(_card.status)
              ? null
              : (value) => widget.onFrozen(_card, value),
          title: const Text('Freeze card'),
          subtitle: Text(
            const {CardStatus.active, CardStatus.frozen}.contains(_card.status)
                ? widget.isFrozen(_card)
                      ? 'Card is temporarily frozen'
                      : 'Card is active'
                : 'Controls unavailable for ${_card.status.name} cards',
          ),
        ),
        _toggle(
          'Online payments',
          _card.onlineEnabled,
          (v) => _updateControl('online_enabled', v),
          enabled:
              !_updating &&
              const {
                CardStatus.active,
                CardStatus.frozen,
              }.contains(_card.status),
        ),
        _toggle(
          'Contactless payments',
          _card.contactlessEnabled,
          (v) => _updateControl('contactless_enabled', v),
          enabled:
              !_updating &&
              const {
                CardStatus.active,
                CardStatus.frozen,
              }.contains(_card.status),
        ),
        _toggle(
          'International payments',
          _card.internationalEnabled,
          (v) => _updateControl('international_enabled', v),
          enabled:
              !_updating &&
              const {
                CardStatus.active,
                CardStatus.frozen,
              }.contains(_card.status),
        ),
        _toggle(
          'ATM withdrawals',
          _card.atmEnabled,
          (v) => _updateControl('atm_enabled', v),
          enabled:
              !_updating &&
              const {
                CardStatus.active,
                CardStatus.frozen,
              }.contains(_card.status),
        ),
        ListTile(
          title: const Text('Daily spending limit'),
          trailing: Text('₹${_card.dailyLimit.toStringAsFixed(0)}'),
          onTap:
              _updating ||
                  !const {
                    CardStatus.active,
                    CardStatus.frozen,
                  }.contains(_card.status)
              ? null
              : _editDailyLimit,
        ),
        const Divider(),
        if (!widget.cards.any((card) => card.virtual))
          OutlinedButton.icon(
            onPressed: widget.onCreateVirtual,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Create virtual card'),
          ),
      ],
    ),
  );
}

Widget _toggle(
  String label,
  bool value,
  ValueChanged<bool> onChanged, {
  bool enabled = true,
}) => SwitchListTile(
  value: value,
  onChanged: enabled ? onChanged : null,
  title: Text(label),
);

class _Transactions extends StatefulWidget {
  const _Transactions({required this.summary, required this.repository});
  final DashboardSummary summary;
  final ProductRepository repository;
  @override
  State<_Transactions> createState() => _TransactionsState();
}

class _TransactionsState extends State<_Transactions> {
  String query = '';
  String filter = 'All';
  late Future<List<CardTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadTransactions();
  }

  void _retry() => setState(() {
    _future = widget.repository.loadTransactions();
  });

  @override
  Widget build(BuildContext c) => FutureBuilder<List<CardTransaction>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Activity unavailable'),
              TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        );
      }
      return _transactionList(context, snapshot.requireData);
    },
  );

  Widget _transactionList(BuildContext c, List<CardTransaction> transactions) {
    final items = transactions
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
                  children: ['All', 'approved', 'flagged', 'declined']
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
                          builder: (_) => TransactionDetailsScreen(
                            transaction: items[i],
                            repository: widget.repository,
                          ),
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
    required this.repository,
    required this.onCreateVirtual,
    required this.onStartKyc,
  });
  final DashboardSummary summary;
  final Card? virtualCard;
  final bool virtualFrozen;
  final ValueChanged<bool>? onVirtualFrozen;
  final ProductRepository repository;
  final VoidCallback onCreateVirtual;
  final VoidCallback onStartKyc;
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
            MaterialPageRoute(
              builder: (_) =>
                  RewardsScreen(summary: summary, repository: repository),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Security activity'),
          subtitle: const Text('Review security alerts'),
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) => FraudActivityScreen(repository: repository),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('Disputes'),
          subtitle: const Text('Track transaction review requests'),
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) => DisputesScreen(repository: repository),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart_outlined),
          title: const Text('Spending insights'),
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) => SpendingScreen(repository: repository),
            ),
          ),
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
                  repository: repository,
                ),
              ),
            ),
          ),
        if (virtualCard == null)
          ListTile(
            leading: const Icon(Icons.add_card_outlined),
            title: const Text('Create virtual card'),
            onTap: onCreateVirtual,
          ),
        ListTile(
          leading: const Icon(Icons.assignment_outlined),
          title: const Text('Application status'),
          subtitle: Text('Identity status: ${summary.customer.kycStatus}'),
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) =>
                  ApplicationStatusScreen(
                    customer: summary.customer,
                    onStartKyc: onStartKyc,
                  ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Profile'),
          subtitle: Text(summary.customer.email),
          onTap: () => Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                customer: summary.customer,
                repository: repository,
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.support_agent_outlined),
          title: const Text('Support'),
          subtitle: const Text('Help and account information'),
          onTap: () => Navigator.of(
            c,
          ).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
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

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppTheme.muted, size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
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

class VirtualCardScreen extends StatefulWidget {
  const VirtualCardScreen({
    required this.card,
    required this.frozen,
    required this.onFrozen,
    required this.repository,
    super.key,
  });
  final Card card;
  final bool frozen;
  final ValueChanged<bool> onFrozen;
  final ProductRepository repository;

  @override
  State<VirtualCardScreen> createState() => _VirtualCardScreenState();
}

class _VirtualCardScreenState extends State<VirtualCardScreen> {
  late Future<Card> _card;

  @override
  void initState() {
    super.initState();
    _card = widget.repository.loadCard(widget.card.id);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Virtual card')),
    body: SafeArea(
      child: FutureBuilder<Card>(
        future: _card,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: TextButton(
                onPressed: () => setState(
                  () => _card = widget.repository.loadCard(widget.card.id),
                ),
                child: const Text('Card unavailable · Try again'),
              ),
            );
          }
          final card = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GemCardVisual(card: card, frozen: widget.frozen),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Card number'),
                subtitle: Text('•••• •••• •••• ${card.lastFour}'),
              ),
              ListTile(
                title: const Text('Expiry'),
                trailing: Text(card.expiry),
              ),
              const ListTile(title: Text('CVV'), trailing: Text('•••')),
              FilledButton.icon(
                onPressed:
                    card.status == CardStatus.active ||
                        card.status == CardStatus.frozen
                    ? () => widget.onFrozen(!widget.frozen)
                    : null,
                icon: Icon(
                  widget.frozen
                      ? Icons.play_arrow_rounded
                      : Icons.ac_unit_rounded,
                ),
                label: Text(
                  widget.frozen
                      ? 'Unfreeze virtual card'
                      : 'Freeze virtual card',
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class TransactionDetailsScreen extends StatefulWidget {
  const TransactionDetailsScreen({
    required this.transaction,
    this.repository,
    super.key,
  });
  final CardTransaction transaction;
  final ProductRepository? repository;

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  late Future<CardTransaction> _transaction;

  @override
  void initState() {
    super.initState();
    _transaction =
        widget.repository?.loadTransaction(widget.transaction.id) ??
        Future.value(widget.transaction);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Transaction details')),
    body: FutureBuilder<CardTransaction>(
      future: _transaction,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _transaction =
                    widget.repository?.loadTransaction(widget.transaction.id) ??
                    Future.value(widget.transaction),
              ),
              child: const Text('Could not load · Try again'),
            ),
          );
        }
        return _transactionDetails(context, snapshot.requireData);
      },
    ),
  );

  Widget _transactionDetails(
    BuildContext c,
    CardTransaction transaction,
  ) => ListView(
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
      _detail(c, 'Country', transaction.country),
      _detail(c, 'Channel', transaction.channel),
      _detail(c, 'Authorization ID', transaction.authorizationId),
      _detail(c, 'Reference ID', transaction.id),
      if (transaction.reasons.isNotEmpty)
        _detail(c, 'Decision notes', transaction.reasons.join('\n')),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: widget.repository == null
            ? null
            : () => _showDisputeForm(c, transaction),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Report or dispute'),
      ),
    ],
  );

  Widget _detail(BuildContext c, String a, String b) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 8,
    title: Text(a),
    subtitle: Text(b, style: Theme.of(c).textTheme.bodyMedium),
  );

  Future<void> _showDisputeForm(
    BuildContext context,
    CardTransaction transaction,
  ) async {
    var reasonValue = 'Unrecognized transaction';
    var detailsValue = '';
    String? validationError;
    final submission = await showDialog<({String reason, String details})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${transaction.merchant} · ₹${transaction.amount.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: reasonValue,
                autofocus: true,
                maxLength: 120,
                onChanged: (value) => reasonValue = value,
                decoration: InputDecoration(
                  labelText: 'Reason for review',
                  errorText: validationError,
                ),
              ),
              TextFormField(
                initialValue: detailsValue,
                maxLines: 3,
                maxLength: 500,
                onChanged: (value) => detailsValue = value,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = reasonValue.trim();
                if (value.length < 3) {
                  setDialogState(
                    () => validationError = 'Enter at least 3 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, (
                  reason: value,
                  details: detailsValue.trim(),
                ));
              },
              child: const Text('Submit dispute'),
            ),
          ],
        ),
      ),
    );
    if (submission == null || !context.mounted) return;
    try {
      await widget.repository!.createDispute(
        transactionId: transaction.id,
        reason: submission.reason,
        details: submission.details,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.repository!.isOffline
                  ? 'Dispute added to offline sample data.'
                  : 'Dispute submitted.',
            ),
          ),
        );
      }
    } on GemcardsApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class SpendingScreen extends StatefulWidget {
  const SpendingScreen({required this.repository, super.key});
  final ProductRepository repository;

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  late Future<List<CardTransaction>> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = widget.repository.loadTransactions();
  }

  void _retry() => setState(() {
    _transactions = widget.repository.loadTransactions();
  });

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Spending')),
    body: FutureBuilder<List<CardTransaction>>(
      future: _transactions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _RetryPanel(
            message: 'Spending data is unavailable.',
            onRetry: _retry,
          );
        }
        final transactions = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '₹${transactions.fold<double>(0, (sum, item) => sum + item.amount).toStringAsFixed(0)}',
              style: Theme.of(c).textTheme.displaySmall,
            ),
            const Text(
              'Total card activity',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            _SpendSummary(transactions: transactions),
            const SizedBox(height: 20),
            if (transactions.isEmpty)
              const _EmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No spending to summarize',
                message: 'Card activity will appear here when available.',
              )
            else
              ...transactions.map(
                (transaction) => _TransactionTile(
                  transaction: transaction,
                  onTap: () => Navigator.of(c).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailsScreen(
                        transaction: transaction,
                        repository: widget.repository,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({
    required this.summary,
    required this.repository,
    super.key,
  });
  final DashboardSummary summary;
  final ProductRepository repository;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<RewardSummary> _rewards;

  @override
  void initState() {
    super.initState();
    _rewards = widget.repository.loadRewards();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('GEM Rewards')),
    body: FutureBuilder<RewardSummary>(
      future: _rewards,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _rewards = widget.repository.loadRewards()),
              child: const Text('Rewards unavailable · Try again'),
            ),
          );
        }
        final rewards = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${rewards.points} points',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            Text(
              'Estimated value: ${rewards.currency} ${rewards.availableValue.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            const Text('Sample rewards balance. Redemption is not connected.'),
          ],
        );
      },
    ),
  );
}

class FraudActivityScreen extends StatefulWidget {
  const FraudActivityScreen({required this.repository, super.key});
  final ProductRepository repository;

  @override
  State<FraudActivityScreen> createState() => _FraudActivityScreenState();
}

class _FraudActivityScreenState extends State<FraudActivityScreen> {
  late Future<List<FraudAlert>> _alerts;

  @override
  void initState() {
    super.initState();
    _alerts = widget.repository.loadFraudAlerts();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security activity')),
    body: FutureBuilder<List<FraudAlert>>(
      future: _alerts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _alerts = widget.repository.loadFraudAlerts()),
              child: const Text('Security activity unavailable · Retry'),
            ),
          );
        }
        if (snapshot.requireData.isEmpty) {
          return const _EmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No open alerts',
            message: 'There are no open alerts to review.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final alert in snapshot.requireData)
              ListTile(
                leading: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.warning,
                ),
                title: Text(alert.title),
                subtitle: Text(
                  '${alert.reason} · ${alert.location} · ${alert.status}',
                ),
                trailing: Text('₹${alert.amount.toStringAsFixed(0)}'),
              ),
          ],
        );
      },
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.customer,
    required this.repository,
    super.key,
  });
  final Customer customer;
  final ProductRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Customer> _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.repository.loadCustomer();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: FutureBuilder<Customer>(
      future: _customer,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _customer = widget.repository.loadCustomer()),
              child: const Text('Profile unavailable · Try again'),
            ),
          );
        }
        final customer = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(title: const Text('Name'), subtitle: Text(customer.name)),
            ListTile(
              title: const Text('Email'),
              subtitle: Text(customer.email),
            ),
            ListTile(
              title: const Text('Customer ID'),
              subtitle: Text(customer.id),
            ),
            ListTile(
              title: const Text('Identity status'),
              subtitle: Text(customer.kycStatus),
            ),
          ],
        );
      },
    ),
  );
}

class ApplicationStatusScreen extends StatelessWidget {
  const ApplicationStatusScreen({
    required this.customer,
    this.onStartKyc,
    super.key,
  });

  final Customer customer;
  final VoidCallback? onStartKyc;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Application status')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          _titleForStatus(customer.applicationStatus),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Application stage: ${customer.applicationStatus.replaceAll('_', ' ')}',
          style: const TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 24),
        ...const [
          'draft',
          'kyc_in_progress',
          'kyc_verified',
          'card_pending',
          'card_active',
        ].map(
          (stage) => ListTile(
            dense: true,
            leading: Icon(
              _stages.indexOf(stage) <=
                      _stages.indexOf(customer.applicationStatus)
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: AppTheme.success,
            ),
            title: Text(stage.replaceAll('_', ' ')),
          ),
        ),
        FilledButton.icon(
          onPressed:
              onStartKyc ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const KycFlowScreen(),
                ),
              ),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Continue identity verification'),
        ),
      ],
    ),
  );

  static const _stages = [
    'draft',
    'kyc_in_progress',
    'kyc_verified',
    'card_pending',
    'card_active',
  ];
  String _titleForStatus(String status) => status == 'card_active'
      ? 'Your GEMCARD is active'
      : status == 'card_pending'
      ? 'Your card is being prepared'
      : status == 'kyc_verified'
      ? 'Identity verified'
      : 'Identity verification needed';
}

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({required this.repository, super.key});
  final ProductRepository repository;

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  late Future<List<Dispute>> _disputes;

  @override
  void initState() {
    super.initState();
    _disputes = widget.repository.disputes();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Disputes')),
    body: FutureBuilder<List<Dispute>>(
      future: _disputes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _disputes = widget.repository.disputes()),
              child: const Text('Disputes unavailable · Try again'),
            ),
          );
        }
        if (snapshot.requireData.isEmpty) {
          return const _EmptyState(
            icon: Icons.gavel_outlined,
            title: 'No disputes',
            message: 'Transaction review requests will appear here.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final dispute in snapshot.requireData)
              ListTile(
                title: Text(dispute.reason),
                subtitle: Text('${dispute.transactionId} · ${dispute.status}'),
                trailing: Text(dispute.id),
              ),
          ],
        );
      },
    ),
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'GEMCARDS is a product of Gemini Software Solutions. '
        'Support requests are not connected in this sample app.',
      ),
    ),
  );
}
