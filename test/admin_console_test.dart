import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/screens/admin/admin_console.dart';

void main() {
  testWidgets('operations console adapts to a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AdminConsoleScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Portfolio overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await tester.enterText(find.byType(TextField).first, 'not-a-number');
    await tester.tap(find.text('Simulate authorization'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid amount greater than zero.'),
      findsOneWidget,
    );
    expect(find.text('APPROVED'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
