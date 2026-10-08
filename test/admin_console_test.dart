import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/screens/admin/admin_console.dart';

void main() {
  testWidgets('operations console renders dashboard and simulator', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminConsoleScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio overview'), findsOneWidget);
    expect(find.text('Total customers'), findsOneWidget);
    await tester.tap(find.text('Simulator'));
    await tester.pumpAndSettle();
    expect(find.text('Authorization simulator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
