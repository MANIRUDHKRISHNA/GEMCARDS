import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/screens/customer/customer_experience.dart';

void main() {
  testWidgets('customer home and card controls fit a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: CustomerExperienceScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('My cards'), findsOneWidget);
    expect(find.text('Online payments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
