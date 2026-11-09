import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/app.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';
import 'package:mbois_gym_pt/features/manager_profile_screen.dart';
import 'package:mbois_gym_pt/design_system/app_design_system.dart';
import 'package:mbois_gym_pt/features/screens.dart';

import 'manager_navigation_profile_test.dart' show MockManagerAuthController;

class SignedOutLocalAuth extends AuthController {
  @override
  Future<int?> build() async => null;
}

void main() {
  testWidgets(
    'real router manager flow, detail back, profile back, exit and logout',
    (tester) async {
      final auth = MockManagerAuthController();
      final repository = InMemoryManagerDashboardRepository(
        initialData: ManagerDashboardData(
          totalActivePt: 1,
          totalActiveClients: 1,
          totalPackagesSold: 1,
          totalSales: 1000000,
          monthlySales: const [1000000, 0, 0],
          trainers: [
            TrainerPerformance(
              id: 'pt',
              name: 'Coach Flow',
              specialization: 'Trainer',
              activeClients: 1,
              packagesSold: 1,
              totalSales: 1000000,
              clients: [
                ManagerClientItem(
                  id: 'client',
                  status: 'active',
                  name: 'Client Flow',
                  packageName: 'Paket 10 Sesi',
                  totalSessions: 10,
                  attendedSessions: 1,
                  remainingSessions: 9,
                  attendanceRecords: [
                    ManagerClientAttendanceRecord(
                      sessionNumber: 1,
                      scheduledTime: DateTime(2026, 1, 4, 10),
                      status: 'completed',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          cloudAuthProvider.overrideWith(() => auth),
          authProvider.overrideWith(SignedOutLocalAuth.new),
          databaseProvider.overrideWithValue(db),
          managerDashboardRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ManagerDashboardScreen), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('client'), findsNothing);
      final button = find.text('Detail PT & Klien');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsNothing);
      expect(find.text('Daftar Klien yang Ditangani'), findsOneWidget);
      await tester.tap(find.text('Daftar Klien yang Ditangani'));
      await tester.pumpAndSettle();
      expect(find.byType(ManagerClientHistoryScreen), findsOneWidget);
      await tester.tap(find.text('Client Flow'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('Detail Absensi Klien'), findsOneWidget);
      expect(find.text('04/01/2026 • 10:00'), findsOneWidget);
      expect(find.text('Hadir'), findsOneWidget);
      expect(find.text('1 Sesi'), findsOneWidget);
      expect(find.text('9 Sesi'), findsOneWidget);
      for (final forbidden in [
        'Asesmen Kesehatan',
        'Tanda Tangan Digital',
        'Catatan Latihan',
        'BMI',
      ]) {
        expect(find.text(forbidden), findsNothing);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ManagerClientHistoryScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Daftar Klien yang Ditangani'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ManagerDashboardScreen), findsOneWidget);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ManagerProfileScreen), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ManagerDashboardScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Keluar'), findsOneWidget);
      expect(find.textContaining('keluar dari aplikasi'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(ManagerDashboardScreen), findsOneWidget);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Keluar dari Akun'));
      await tester.tap(find.text('Keluar dari Akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(router.canPop(), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ManagerDashboardScreen), findsNothing);
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}
