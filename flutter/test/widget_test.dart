// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beans_music_flutter/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Beans Music app mounts', (WidgetTester tester) async {
    await tester.pumpWidget(const BeansMusicApp());
    expect(find.byType(BeansMusicApp), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
