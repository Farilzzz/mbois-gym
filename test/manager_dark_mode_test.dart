import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';
import 'package:mbois_gym_pt/features/manager_profile_screen.dart';
import 'package:mbois_gym_pt/cloud/cloud_session.dart';
import 'package:mbois_gym_pt/app.dart'
    show CloudAuthController, cloudAuthProvider;

class _ManagerAuth extends CloudAuthController {
  @override
  Future<CloudProfile?> build() async => const CloudProfile(
    'uid',
    'Maya Manager',
    true,
    email: 'maya@example.com',
    role: 'manager',
  );
}

void main() {
  testWidgets('profile name follows a custom dark color scheme', (
    tester,
  ) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cloudAuthProvider.overrideWith(_ManagerAuth.new)],
        child: MaterialApp(theme: theme, home: const ManagerProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final name = tester.widgetList<Text>(find.text('Maya Manager')).first;
    expect(name.style?.color, theme.colorScheme.onSurface);
  });

  testWidgets('trainer detail header follows the dark surface scheme', (
    tester,
  ) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      ),
    );
    final repo = InMemoryManagerDashboardRepository(
      initialData: const ManagerDashboardData(
        totalActivePt: 1,
        totalActiveClients: 1,
        totalPackagesSold: 1,
        totalSales: 100,
        monthlySales: [100, 0, 0],
        trainers: [
          TrainerPerformance(
            id: 'pt',
            name: 'Coach',
            specialization: 'Strength',
            activeClients: 1,
            packagesSold: 1,
            totalSales: 100,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          home: ManagerDashboardScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Detail PT & Klien'));
    await tester.tap(find.text('Detail PT & Klien'));
    await tester.pumpAndSettle();
    final whiteSurfaces = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (widget) =>
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == Colors.white,
        );
    expect(whiteSurfaces, isEmpty);
  });

  testWidgets('manager dashboard uses dark theme colors for KPI and dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const ManagerDashboardScreen(
            initialYear: 2026,
            initialQuarter: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find
        .ancestor(
          of: find.text('Total PT Aktif'),
          matching: find.byType(Container),
        )
        .first;
    final card = tester.widget<Container>(cardFinder);
    expect((card.decoration as BoxDecoration).color, isNot(Colors.white));
  });
}
