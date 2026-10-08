import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/kyc_flow_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GemcardsApp());
}

class GemcardsApp extends StatelessWidget {
  const GemcardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GEMCARDS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _WelcomeScreen(),
    );
  }
}

class _WelcomeScreen extends StatefulWidget {
  const _WelcomeScreen();

  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  void _start() => Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => const KycFlowScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 46,
              ),
              child: IntrinsicHeight(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 450),
                  opacity: _visible ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GEMCARDS',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontSize: 24,
                                      letterSpacing: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Retail Payment Suite',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 42),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 18,
                                  color: AppTheme.accentDark,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'A considered start to your application',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: AppTheme.accentDark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            Text(
                              'Customer\nonboarding',
                              style: Theme.of(
                                context,
                              ).textTheme.displaySmall?.copyWith(height: 1.05),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Complete your verification to continue with your card application.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(height: 1.55),
                            ),
                            const SizedBox(height: 26),
                            const Divider(height: 1),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 18,
                              runSpacing: 10,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      color: AppTheme.muted,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 9),
                                    Text(
                                      'About 2 min',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'DEMO FLOW',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppTheme.accentDark),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Begin onboarding'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Demo only • please do not submit real identity documents.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
