import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/features/screens.dart';

void main() {
  testWidgets('setup tidak memuat password demo', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SetupScreen())),
    );
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    for (final field in fields) {
      expect(field.controller?.text ?? '', isEmpty);
    }
    expect(find.text('Default demo: MboisGym2026!'), findsNothing);
  });
}
