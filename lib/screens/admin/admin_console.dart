import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});
  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  int tab = 0;
  bool frozen = false;
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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('GEMCARDS / OPERATIONS'),
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
    body: Row(
      children: [
        NavigationRail(
          selectedIndex: tab,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: labels
              .map(
                (x) => NavigationRailDestination(
                  icon: Icon(_icon(x)),
                  label: Text(x),
                ),
              )
              .toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(padding: const EdgeInsets.all(28), child: _body()),
        ),
      ],
    ),
  );
  Widget _body() {
    if (tab == 0)
      return _page(
        'Portfolio overview',
        'Deterministic synthetic operations snapshot',
        ListView(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _Kpi('12,480', 'Total customers'),
                _Kpi('18,340', 'Active cards'),
                _Kpi('918', 'Transactions today'),
                _Kpi('₹12.8L', 'Transaction volume'),
                _Kpi('24', 'Pending KYC'),
                _Kpi('1', 'Fraud alert'),
                _Kpi('1', 'Open disputes'),
                _Kpi('42', 'Cards issued today'),
              ],
            ),
            const SizedBox(height: 24),
            const _Chart(),
            const SizedBox(height: 16),
            _surface(
              const ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.error,
                ),
                title: Text('High-risk transaction requires review'),
                subtitle: Text('Priya Shah · Singapore · ₹9,800 · score 91'),
              ),
            ),
          ],
        ),
      );
    if (tab == 1)
      return _queue(
        'Customers',
        'Name · ID · KYC · cards · transactions · risk',
        const [
          'Alex Morgan · CUS-DEMO-001 · Verified · 2 cards · 18 transactions · Low risk',
          'Priya Shah · CUS-DEMO-002 · Under review · 1 card · 7 transactions · Medium risk',
          'Jordan Lee · CUS-DEMO-003 · Pending · 0 cards · 0 transactions · Low risk',
        ],
      );
    if (tab == 2) return _cards();
    if (tab == 3)
      return _queue(
        'Transaction operations',
        'Merchant · customer · card · timestamp · status · risk',
        const [
          'Metro Mart · Alex Morgan · •••• 4821 · 10:42 · ₹1,240 · Approved · risk 8',
          'CloudStream · Alex Morgan · •••• 4821 · 20:11 · ₹299 · Approved · risk 4',
          'Northstar Electronics · Priya Shah · •••• 7730 · 08:16 · ₹9,800 · Declined · risk 91',
        ],
      );
    if (tab == 4)
      return _page(
        'Authorization simulator',
        'Deterministic card-status, limit and international rules',
        _Simulator(frozen: frozen),
      );
    if (tab == 5) return _fraud();
    if (tab == 6) return _disputes();
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
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: AppTheme.muted)),
      const SizedBox(height: 22),
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
  Widget _cards() => _page(
    'Card management',
    'Masked cards, lifecycle, controls and limits',
    ListView(
      children: [
        _surface(
          ListTile(
            leading: const Icon(Icons.credit_card_rounded),
            title: const Text('•••• 4821 · GEMCARDS Platinum'),
            subtitle: Text(
              frozen
                  ? 'Alex Morgan · Visa · Frozen · ₹50,000 limit'
                  : 'Alex Morgan · Visa · Active · ₹50,000 limit',
            ),
            trailing: FilledButton(
              onPressed: () => setState(() => frozen = !frozen),
              child: Text(frozen ? 'Unfreeze' : 'Freeze'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _surface(
          const ListTile(
            title: Text('•••• 9104 · GEM Virtual'),
            subtitle: Text('Alex Morgan · Visa · Active · Expiry 09/30'),
          ),
        ),
        const SizedBox(height: 12),
        _surface(
          const ListTile(
            title: Text('•••• 7730 · GEM Classic'),
            subtitle: Text('Priya Shah · RuPay · Frozen · Expiry 10/30'),
          ),
        ),
      ],
    ),
  );
  Widget _fraud() => _page(
    'Fraud & risk',
    'Signals prioritized for operations decisions',
    ListView(
      children: [
        _surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Large foreign purchase on a frozen card',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Priya Shah · Singapore · ₹9,800 · Risk score 91'),
              const SizedBox(height: 12),
              const Text(
                'Why flagged: high-value foreign attempt after the card was frozen.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Block card'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Dismiss'),
                  ),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Mark investigating'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _disputes() => _page(
    'Disputes',
    'Status and timeline simulation',
    ListView(
      children: [
        _surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DSP-01 · Merchant recognition',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('TXN-101 · Alex Morgan · Open · 09 Oct 2026'),
              const Divider(height: 24),
              const Text(
                'Timeline: opened by customer → awaiting operations review',
              ),
              DropdownButtonFormField(
                value: 'Open',
                items: const ['Open', 'Investigating', 'Resolved']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
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
  const _Simulator({required this.frozen});
  final bool frozen;
  @override
  State<_Simulator> createState() => _SimulatorState();
}

class _SimulatorState extends State<_Simulator> {
  final amount = TextEditingController(text: '1200');
  String country = 'India';
  String? decision;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      TextField(
        controller: amount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Amount (₹)'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField(
        value: country,
        decoration: const InputDecoration(labelText: 'Country'),
        items: const [
          'India',
          'Singapore',
        ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
        onChanged: (x) => setState(() => country = x!),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: () => setState(() {
          final n = double.tryParse(amount.text) ?? 0;
          decision = widget.frozen || n > 50000 || country != 'India'
              ? 'DECLINED'
              : 'APPROVED';
        }),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Simulate authorization'),
      ),
      if (decision != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    decision!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('AUTH-DEMO-4821'),
                  const Divider(),
                  Text(
                    widget.frozen
                        ? 'Card status: failed'
                        : 'Card status: passed',
                  ),
                  Text(
                    (double.tryParse(amount.text) ?? 0) > 50000
                        ? 'Spending limit: failed'
                        : 'Spending limit: passed',
                  ),
                  Text(
                    country == 'India'
                        ? 'International controls: passed'
                        : 'International controls: failed',
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext c) => Container(
    width: 180,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
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
      borderRadius: BorderRadius.circular(18),
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
