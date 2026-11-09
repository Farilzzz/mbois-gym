import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/features/screens.dart';

void main() {
  testWidgets(
    'LoginScreen does not render public registration or legacy archive entrypoints',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('WELCOME BACK,\nCOACH'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Lupa Password?'), findsOneWidget);

      expect(find.text('Belum punya akun? '), findsNothing);
      expect(find.text('Informasi Akun'), findsNothing);
      expect(find.textContaining('Arsip'), findsNothing);
      expect(find.textContaining('Riwayat & Arsip Latihan'), findsNothing);
    },
  );
}
