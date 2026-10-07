import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/kyc_flow_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JiffyKycApp());
}

class JiffyKycApp extends StatelessWidget {
  const JiffyKycApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jiffy KYC Prototype',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const KycFlowScreen(),
    );
  }
}
