// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:gemcards_onboarding_prototype/main.dart';
import 'package:gemcards_onboarding_prototype/screens/camera_capture_screen.dart';
import 'package:gemcards_onboarding_prototype/screens/kyc_flow_screen.dart';
import 'package:gemcards_onboarding_prototype/screens/liveness_screen.dart';
import 'package:gemcards_onboarding_prototype/repositories/kyc_repository.dart';
import 'package:gemcards_onboarding_prototype/services/demo_product_service.dart';

void main() {
  testWidgets('launches on the customer dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GemcardsApp(repository: DemoProductRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text('Available balance'), findsOneWidget);
    expect(find.textContaining('Complete application'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.textContaining('Complete application'));
    await tester.tap(find.textContaining('Complete application'));
    await tester.pumpAndSettle();
    expect(find.text('Passport'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('identity selection fits a compact phone screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: KycFlowScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Customer onboarding'), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    expect(find.text("Driver's License"), findsOneWidget);
    expect(find.text('National ID'), findsOneWidget);
    expect(find.text('Continue to verification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('document, liveness, and address steps fit a compact phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: KycFlowScreen(repository: MockKycRepository())),
    );
    await tester.tap(find.text('Continue to verification'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your document'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final sampleCapture = find.text('Camera unavailable? Use sample capture');
    await tester.ensureVisible(sampleCapture);
    await tester.tap(sampleCapture);
    await tester.pump();
    expect(find.text('Captured'), findsNWidgets(2));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('A quick face check'), findsOneWidget);

    await tester.tap(find.text('Need an accessible alternative?'));
    await tester.pump(const Duration(milliseconds: 300));
    final assistedCheck = find.text('Continue with sample check');
    await tester.ensureVisible(assistedCheck);
    await tester.tap(assistedCheck);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Where can we reach you?'), findsOneWidget);
    expect(find.text('Proof of address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('document capture adapts to a compact phone screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CameraCaptureScreen(
          title: 'Capture front',
          instruction: 'Fit the front of your ID inside the frame',
          lensDirection: CameraLensDirection.back,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Capture front'), findsOneWidget);
    expect(find.text('ALIGN YOUR DOCUMENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'liveness screen fits a compact phone and exposes an alternative',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: LivenessScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Face verification'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('Use accessible alternative'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
