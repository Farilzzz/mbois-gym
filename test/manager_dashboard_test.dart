import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/app.dart' show databaseProvider;
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';

void main() {
  testWidgets(
    'ManagerDashboardScreen renders header Dashboard Manajemen PT, Triwulan and Tahun selectors',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ManagerDashboardScreen(initialYear: 2026, initialQuarter: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Manajemen PT'), findsOneWidget);
      expect(find.text('Q1'), findsWidgets);
      expect(find.text('2026'), findsWidgets);
    },
  );

  testWidgets(
    'Ringkasan 4 Kartu KPI menampilkan Total PT Aktif, Klien Aktif, Paket Terjual, dan Total Penjualan format Rupiah',
    (tester) async {
      final repo = InMemoryManagerDashboardRepository(
        initialData: const ManagerDashboardData(
          totalActivePt: 4,
          totalActiveClients: 15,
          totalPackagesSold: 10,
          totalSales: 15000000.0,
          monthlySales: [5000000.0, 5000000.0, 5000000.0],
          trainers: [
            TrainerPerformance(
              id: '1',
              name: 'Coach Faril',
              specialization: 'Strength & Conditioning',
              activeClients: 8,
              packagesSold: 6,
              totalSales: 9000000.0,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ManagerDashboardScreen(
              repository: repo,
              initialYear: 2026,
              initialQuarter: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total PT Aktif'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      expect(find.text('Total Klien Aktif'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      expect(find.text('Paket PT Terjual'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      expect(find.text('Total Penjualan'), findsOneWidget);
      expect(find.text('Nilai Paket Terjual'), findsOneWidget);
      expect(find.text('Rp 15.000.000'), findsOneWidget);
    },
  );

  testWidgets(
    'Kartu Target Triwulan menampilkan default Rp 5.000.000, persentase, sisa target, LinearProgressIndicator, dan tombol Ubah Target berfungsi',
    (tester) async {
      final repo = InMemoryManagerDashboardRepository(
        initialData: const ManagerDashboardData(
          totalActivePt: 2,
          totalActiveClients: 5,
          totalPackagesSold: 3,
          totalSales: 3000000.0,
          monthlySales: [1000000.0, 1000000.0, 1000000.0],
          trainers: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ManagerDashboardScreen(
              repository: repo,
              initialYear: 2026,
              initialQuarter: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check default target Rp 5.000.000
      expect(find.text('Target Triwulan'), findsOneWidget);
      expect(find.text('Target: Rp 5.000.000'), findsOneWidget);
      expect(find.text('Pencapaian: 60.0%'), findsOneWidget);
      expect(find.text('Sisa Menuju Target: Rp 2.000.000'), findsOneWidget);

      final progressFinder = find.byType(LinearProgressIndicator);
      expect(progressFinder, findsOneWidget);
      final progressWidget = tester.widget<LinearProgressIndicator>(
        progressFinder,
      );
      expect(progressWidget.value, closeTo(0.6, 0.01));

      // Tap Ubah Target
      final editBtn = find.widgetWithText(TextButton, 'Ubah Target');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Ubah Target Triwulan'), findsOneWidget);
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Enter new target: 6000000
      await tester.enterText(textField, '6000000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();

      // Assert target updated
      expect(find.text('Target: Rp 6.000.000'), findsOneWidget);
      expect(find.text('Pencapaian: 50.0%'), findsOneWidget);
      expect(find.text('Sisa Menuju Target: Rp 3.000.000'), findsOneWidget);

      final updatedProgress = tester.widget<LinearProgressIndicator>(
        progressFinder,
      );
      expect(updatedProgress.value, closeTo(0.5, 0.01));
    },
  );

  testWidgets(
    'Grafik Penjualan Bulanan menggunakan fl_chart BarChart dengan label 3 bulan sesuai triwulan terpilih',
    (tester) async {
      final repo = InMemoryManagerDashboardRepository(
        initialData: const ManagerDashboardData(
          totalActivePt: 2,
          totalActiveClients: 5,
          totalPackagesSold: 3,
          totalSales: 3000000.0,
          monthlySales: [1000000.0, 1500000.0, 500000.0],
          trainers: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ManagerDashboardScreen(
              repository: repo,
              initialYear: 2026,
              initialQuarter: 1, // Q1 -> Jan, Feb, Mar
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grafik Penjualan Bulanan'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);

      // Check month labels for Q1
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
      expect(find.text('Mar'), findsOneWidget);

      // Switch to Q2
      final qDropdown = find.text('Q1');
      await tester.tap(qDropdown);
      await tester.pumpAndSettle();

      final q2Item = find.text('Q2').last;
      await tester.tap(q2Item);
      await tester.pumpAndSettle();

      // Check month labels for Q2
      expect(find.text('Apr'), findsOneWidget);
      expect(find.text('Mei'), findsOneWidget);
      expect(find.text('Jun'), findsOneWidget);
    },
  );

  testWidgets(
    'Daftar Perbandingan Kinerja PT menampilkan nama PT, spesialisasi, klien aktif, paket terjual, dan total penjualan format Rupiah',
    (tester) async {
      final repo = InMemoryManagerDashboardRepository(
        initialData: const ManagerDashboardData(
          totalActivePt: 2,
          totalActiveClients: 13,
          totalPackagesSold: 10,
          totalSales: 15000000.0,
          monthlySales: [5000000.0, 5000000.0, 5000000.0],
          trainers: [
            TrainerPerformance(
              id: '1',
              name: 'Coach Faril',
              specialization: 'Strength & Conditioning',
              activeClients: 8,
              packagesSold: 6,
              totalSales: 9000000.0,
            ),
            TrainerPerformance(
              id: '2',
              name: 'Coach Dimas',
              specialization: 'Fat Loss & HIIT',
              activeClients: 5,
              packagesSold: 4,
              totalSales: 6000000.0,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ManagerDashboardScreen(
              repository: repo,
              initialYear: 2026,
              initialQuarter: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daftar Perbandingan Kinerja PT'), findsOneWidget);

      // Verify Coach Faril
      expect(find.text('Coach Faril'), findsOneWidget);
      expect(find.text('Strength & Conditioning'), findsOneWidget);
      expect(find.text('Klien Aktif: 8'), findsOneWidget);
      expect(find.text('Paket Terjual: 6'), findsOneWidget);
      expect(find.text('Rp 9.000.000'), findsOneWidget);

      // Verify Coach Dimas
      expect(find.text('Coach Dimas'), findsOneWidget);
      expect(find.text('Fat Loss & HIIT'), findsOneWidget);
      expect(find.text('Klien Aktif: 5'), findsOneWidget);
      expect(find.text('Paket Terjual: 4'), findsOneWidget);
      expect(find.text('Rp 6.000.000'), findsOneWidget);
    },
  );

  testWidgets(
    'Empty state ditampilkan dengan rapi ketika belum ada data kinerja PT',
    (tester) async {
      final repo = InMemoryManagerDashboardRepository(
        initialData: const ManagerDashboardData.empty(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ManagerDashboardScreen(
              repository: repo,
              initialYear: 2026,
              initialQuarter: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada data kinerja PT pada periode ini.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);

      // KPI cards should show 0 values
      expect(find.text('0'), findsNWidgets(3)); // PT, Klien, Paket
      expect(find.text('Rp 0'), findsOneWidget); // Total Penjualan
    },
  );

  testWidgets('Loading indicator ditampilkan saat data sedang dimuat', (
    tester,
  ) async {
    // Use an async delayed repo that hasn't completed yet
    final repo = DelayedManagerDashboardRepository();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ManagerDashboardScreen(
            repository: repo,
            initialYear: 2026,
            initialQuarter: 1,
          ),
        ),
      ),
    );

    // Verify CircularProgressIndicator is shown during loading (pump without settle)
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let delayed future complete
    repo.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'Error handling menampilkan pesan error dan tombol Coba Lagi dapat ditekan untuk recovery',
    (tester) async {
      int attempt = 0;
      final repo = RecoverableManagerDashboardRepository(
        onFetch: () {
          attempt++;
          if (attempt == 1) {
            throw Exception('Gagal memuat data dashboard');
          }
          return const ManagerDashboardData(
            totalActivePt: 3,
            totalActiveClients: 10,
            totalPackagesSold: 8,
            totalSales: 12000000.0,
            monthlySales: [4000000.0, 4000000.0, 4000000.0],
            trainers: [],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ManagerDashboardScreen(
              repository: repo,
              initialYear: 2026,
              initialQuarter: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat data dashboard'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Coba Lagi'), findsOneWidget);

      // Tap Coba Lagi -> succeeds on 2nd attempt
      await tester.tap(find.widgetWithText(ElevatedButton, 'Coba Lagi'));
      await tester.pumpAndSettle();

      // Error message is gone, dashboard loads
      expect(find.text('Gagal memuat data dashboard'), findsNothing);
      expect(find.text('Total PT Aktif'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    'Responsif dan bebas overflow pada compact screen 320x568 dan large font scale 1.5x',
    (tester) async {
      final repo = InMemoryManagerDashboardRepository(
        initialData: const ManagerDashboardData(
          totalActivePt: 2,
          totalActiveClients: 6,
          totalPackagesSold: 4,
          totalSales: 6000000.0,
          monthlySales: [2000000.0, 2000000.0, 2000000.0],
          trainers: [
            TrainerPerformance(
              id: '1',
              name: 'Coach Faril Super Long Name For Testing Responsive UI',
              specialization: 'Strength & Conditioning Specialist',
              activeClients: 4,
              packagesSold: 3,
              totalSales: 4500000.0,
            ),
          ],
        ),
      );

      // Set small physical size: 320 x 568
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: ManagerDashboardScreen(
                repository: repo,
                initialYear: 2026,
                initialQuarter: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and KPI cards are visible
      expect(find.text('Dashboard Manajemen PT'), findsOneWidget);
      expect(find.text('Total PT Aktif'), findsOneWidget);

      // Scroll through screen to ensure all widgets layout without overflow
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grafik Penjualan Bulanan'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daftar Perbandingan Kinerja PT'), findsOneWidget);
    },
  );

  testWidgets(
    'Integrasi Riverpod databaseProvider: memuat data nyata dari SQLite database',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      // Seed trainer
      final trainerId = await db
          .into(db.trainers)
          .insert(
            TrainersCompanion.insert(
              name: 'Coach Faril',
              email: 'faril@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
              phone: const Value('+628123456789'),
            ),
          );

      // Seed client
      final clientId = await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              trainerId: trainerId,
              name: 'Budi Santoso',
              age: 25,
            ),
          );

      // Seed package (12 sessions = Rp 1.500.000) created in Feb 2026 (Q1)
      await db
          .into(db.ptPackages)
          .insert(
            PtPackagesCompanion.insert(
              clientId: clientId,
              totalSessions: 12,
              status: const Value('active'),
              createdAt: Value(DateTime(2026, 2, 15)),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: ManagerDashboardScreen(initialYear: 2026, initialQuarter: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Dashboard Manajemen PT'), findsOneWidget);

      // Check KPI Cards derived from SQLite
      expect(find.text('Total PT Aktif'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(3)); // 1 PT, 1 Klien, 1 Paket
      expect(find.text('Total Penjualan'), findsOneWidget);
      expect(find.text('Rp 1.500.000'), findsWidgets);

      // Check PT Performance List
      expect(find.text('Coach Faril'), findsOneWidget);
      expect(find.text('Klien Aktif: 1'), findsOneWidget);
      expect(find.text('Paket Terjual: 1'), findsOneWidget);
    },
  );
}

class RecoverableManagerDashboardRepository
    implements ManagerDashboardRepository {
  RecoverableManagerDashboardRepository({required this.onFetch});

  final ManagerDashboardData Function() onFetch;

  @override
  Future<ManagerDashboardData> fetchDashboardData({
    required int year,
    required int quarter,
  }) async {
    return onFetch();
  }
}

class DelayedManagerDashboardRepository implements ManagerDashboardRepository {
  late void Function() complete;

  @override
  Future<ManagerDashboardData> fetchDashboardData({
    required int year,
    required int quarter,
  }) {
    final completer = Completer<ManagerDashboardData>();
    complete = () {
      completer.complete(const ManagerDashboardData.empty());
    };
    return completer.future;
  }
}
