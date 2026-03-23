import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:pressure_sensor_remote/main.dart';

void main() {
  testWidgets('app renders shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PressureSensorApp());
    await tester.pump();

    expect(find.text('WaterMaker'), findsOneWidget);
  });

  testWidgets('app renders on xcover 7 portrait width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PressureSensorApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('WaterMaker'), findsOneWidget);
  });
}
