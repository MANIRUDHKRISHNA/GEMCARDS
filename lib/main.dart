import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'repositories/product_repositories.dart';
import 'screens/customer/customer_experience.dart';
import 'services/api/gemcards_api_client.dart';
import 'services/demo_customer_identity.dart';
import 'services/demo_product_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DemoCustomerIdentity.initialize();
  runApp(const GemcardsApp());
}

class GemcardsApp extends StatelessWidget {
  const GemcardsApp({super.key, this.repository});
  final ProductRepository? repository;

  static final _repository = ApiProductRepository(api: GemcardsApiClient());

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GEMCARDS',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: CustomerExperienceScreen(repository: repository ?? _repository),
  );
}
