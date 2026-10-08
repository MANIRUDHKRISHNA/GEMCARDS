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
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _visible = true); });
  }

  void _start() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const KycFlowScreen()));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500), opacity: _visible ? 1 : 0,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            Container(width: 58, height: 58, decoration: BoxDecoration(color: AppTheme.accentDark, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 30)),
            const SizedBox(height: 26),
            const Text('GEMCARDS', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Retail Payment Suite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.accentDark)),
            const SizedBox(height: 8),
            const Text('by Gemini Software Solutions', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 32),
            const Text('Welcome to GEMCARDS', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('Complete your onboarding to get started. Secure, simple and seamless digital onboarding.', style: TextStyle(color: AppTheme.muted, height: 1.5, fontSize: 16)),
            const Spacer(),
            SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(onPressed: _start, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Begin onboarding'), style: FilledButton.styleFrom(backgroundColor: AppTheme.accentDark, foregroundColor: Colors.white))),
            const SizedBox(height: 14),
            const Center(child: Text('DEMO PROTOTYPE', style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: AppTheme.muted, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    ),
  );
}
