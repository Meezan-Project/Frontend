// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mezaan/main.dart' as app;
import 'package:mezaan/shared/navigation/app_routes.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Pump app widget directly to avoid plugin initialization in tests.
    await tester.pumpWidget(const app.MezaanApp(initialRoute: AppRoutes.login));
    await tester.pump();

    // Verify no build/runtime exception occurred during startup.
    expect(tester.takeException(), isNull);
  });
}
