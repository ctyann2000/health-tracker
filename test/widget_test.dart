// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:health_tracker/main.dart';
import 'package:health_tracker/providers/health_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => HealthProvider()),
        ],
        child: const HealthTrackerApp(),
      ),
    );

    expect(find.byType(HealthTrackerApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
