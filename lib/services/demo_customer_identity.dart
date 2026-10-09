import 'package:shared_preferences/shared_preferences.dart';

class DemoCustomerIdentity {
  DemoCustomerIdentity._();

  static const _preferenceKey = 'gemcards.demo_customer_id';
  static const _configuredCustomerId = String.fromEnvironment(
    'DEMO_CUSTOMER_ID',
    defaultValue: 'CUS-DEMO-001',
  );

  static String _customerId = _configuredCustomerId;

  static String get customerId => _customerId;

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _customerId =
        preferences.getString(_preferenceKey) ?? _configuredCustomerId;
  }

  static Future<void> selectCustomer(String customerId) async {
    final normalizedId = customerId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(customerId, 'customerId', 'Must not be empty');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, normalizedId);
    _customerId = normalizedId;
  }
}
