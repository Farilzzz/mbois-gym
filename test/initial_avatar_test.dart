import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/widgets/initial_avatar.dart';

void main() {
  group('InitialAvatar TDD Suite', () {
    testWidgets('displays capital first grapheme from name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: InitialAvatar(name: 'budi santoso')),
        ),
      );

      expect(find.text('B'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
      final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circle.radius, 24.0);
    });

    testWidgets('falls back to email when name is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InitialAvatar(name: '   ', email: 'coach@mboisgym.com'),
          ),
        ),
      );

      expect(find.text('C'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets(
      'falls back to person icon when both name and email are empty',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: InitialAvatar(name: '', email: null)),
          ),
        );

        expect(find.byIcon(Icons.person), findsOneWidget);
      },
    );

    testWidgets('respects custom radius and colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InitialAvatar(
              name: 'Dewi',
              radius: 40.0,
              backgroundColor: Colors.purple,
              foregroundColor: Colors.yellow,
            ),
          ),
        ),
      );

      final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circle.radius, 40.0);
      expect(circle.backgroundColor, Colors.purple);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('supports large text scale factor without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const Scaffold(
              body: InitialAvatar(name: 'Zahra', radius: 18.0),
            ),
          ),
        ),
      );

      expect(find.text('Z'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('correctly displays C for Coach Faril and Coach Akbar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                InitialAvatar(name: 'Coach Faril'),
                InitialAvatar(name: 'Coach Akbar'),
              ],
            ),
          ),
        ),
      );

      // Both start with C
      expect(find.text('C'), findsNWidgets(2));
    });
  });
}
