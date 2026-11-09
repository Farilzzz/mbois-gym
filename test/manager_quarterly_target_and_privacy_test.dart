import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';

void main() {
  group('Target Penjualan Triwulan Rp 5 Juta & Harga Paket PT', () {
    test('Formula harga paket resmi sesuai instruksi', () {
      expect(
        SqliteManagerDashboardRepository.priceForSessions(4),
        equals(500000.0),
      );
      expect(
        SqliteManagerDashboardRepository.priceForSessions(10),
        equals(1000000.0),
      );
      expect(
        SqliteManagerDashboardRepository.priceForSessions(16),
        equals(1600000.0),
      );
      expect(
        SqliteManagerDashboardRepository.priceForSessions(24),
        equals(2000000.0),
      );
    });

    test('DashboardPeriod memetakan kuartal Q1-Q4 dengan benar', () {
      final q1 = DashboardPeriod(year: 2026, quarter: 1);
      expect(q1.monthLabels, equals(['Jan', 'Feb', 'Mar']));

      final q2 = DashboardPeriod(year: 2026, quarter: 2);
      expect(q2.monthLabels, equals(['Apr', 'Mei', 'Jun']));

      final q3 = DashboardPeriod(year: 2026, quarter: 3);
      expect(q3.monthLabels, equals(['Jul', 'Agu', 'Sep']));

      final q4 = DashboardPeriod(year: 2026, quarter: 4);
      expect(q4.monthLabels, equals(['Okt', 'Nov', 'Des']));
    });

    test('Perhitungan capaian target Rp 5.000.000 individual per PT', () {
      final ptA = TrainerPerformance(
        id: 'pt-1',
        name: 'Coach Budi',
        specialization: 'Hypertrophy & Strength',
        activeClients: 3,
        packagesSold: 4,
        totalSales: 5100000.0, // Melebihi 5.000.000
        quarterlyTarget: 5000000.0,
        monthlySales: [1500000.0, 1600000.0, 2000000.0],
        clients: [],
      );

      expect(ptA.isTargetAchieved, isTrue);
      expect(ptA.achievementPercentage, closeTo(102.0, 0.1));
      expect(ptA.remainingAmount, equals(0.0));

      final ptB = TrainerPerformance(
        id: 'pt-2',
        name: 'Coach Sari',
        specialization: 'Fat Loss & HIIT',
        activeClients: 1,
        packagesSold: 2,
        totalSales: 2500000.0, // 50% dari target
        quarterlyTarget: 5000000.0,
        monthlySales: [1000000.0, 1500000.0, 0.0],
        clients: [],
      );

      expect(ptB.isTargetAchieved, isFalse);
      expect(ptB.achievementPercentage, closeTo(50.0, 0.1));
      expect(ptB.remainingAmount, equals(2500000.0));
    });
  });

  group('Isolasi Privasi Absensi Klien Role Manager', () {
    testWidgets(
      'Alur navigasi nyata ManagerDashboardScreen: buka detail PT -> daftar klien -> dialog absensi read-only tanpa kebocoran data sensitif',
      (tester) async {
        final clientItem = ManagerClientItem(
          id: 'c-101',
          name: 'Klien Uji Rahasia',
          packageName: 'Paket 10 Sesi',
          totalSessions: 10,
          attendedSessions: 4,
          remainingSessions: 6,
          attendanceRecords: [
            ManagerClientAttendanceRecord(
              sessionNumber: 1,
              scheduledTime: DateTime(2026, 3, 10, 14, 0),
              status: 'completed',
            ),
            ManagerClientAttendanceRecord(
              sessionNumber: 2,
              scheduledTime: DateTime(2026, 3, 12, 14, 0),
              status: 'scheduled',
            ),
          ],
        );

        final repo = InMemoryManagerDashboardRepository(
          initialData: ManagerDashboardData(
            totalActivePt: 1,
            totalActiveClients: 1,
            totalPackagesSold: 1,
            totalSales: 1000000.0,
            monthlySales: const [0.0, 0.0, 1000000.0],
            trainers: [
              TrainerPerformance(
                id: 'pt-1',
                name: 'Coach Faril',
                specialization: 'Strength & Conditioning',
                activeClients: 1,
                packagesSold: 1,
                totalSales: 1000000.0,
                quarterlyTarget: 5000000.0,
                monthlySales: const [0.0, 0.0, 1000000.0],
                clients: [clientItem],
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

        // Pastikan layar utama dashboard ter-render
        expect(find.text('Dashboard Manajemen PT'), findsOneWidget);
        expect(find.text('Coach Faril'), findsOneWidget);

        // Buka bottom sheet "Detail PT & Klien"
        final detailPtButton = find.widgetWithText(
          TextButton,
          'Detail PT & Klien',
        );
        expect(detailPtButton, findsOneWidget);
        await tester.ensureVisible(detailPtButton);
        await tester.pumpAndSettle();
        await tester.tap(detailPtButton);
        await tester.pumpAndSettle();

        // Bottom sheet terbuka: tampil nama PT dan daftar klien yang ditangani
        expect(find.text('Daftar Klien yang Ditangani'), findsOneWidget);
        await tester.tap(find.text('Daftar Klien yang Ditangani'));
        await tester.pumpAndSettle();
        expect(find.text('Klien Uji Rahasia'), findsOneWidget);
        expect(find.textContaining('4 dari 10 sesi dihadiri'), findsOneWidget);

        // Tekan klien untuk membuka dialog absensi riil
        await tester.tap(find.text('Klien Uji Rahasia'));
        await tester.pumpAndSettle();

        // Verifikasi dialog nyata "Detail Absensi Klien"
        expect(find.text('Detail Absensi Klien'), findsOneWidget);
        expect(
          find.textContaining('Read-Only • Klien Uji Rahasia'),
          findsOneWidget,
        );
        expect(find.text('Paket 10 Sesi'), findsOneWidget);
        expect(find.text('4 Sesi'), findsOneWidget);
        expect(find.text('6 Sesi'), findsOneWidget);
        expect(find.text('Riwayat Jadwal & Kehadiran Sesi'), findsOneWidget);
        expect(find.text('Sesi 1'), findsOneWidget);
        expect(find.text('Hadir'), findsOneWidget);
        expect(find.text('Sesi 2'), findsOneWidget);
        expect(find.text('Direncanakan'), findsOneWidget);
        expect(
          find.textContaining(
            'Catatan Privasi: Asesmen kesehatan, catatan latihan rahasia, dan tanda tangan klien tidak ditampilkan.',
          ),
          findsOneWidget,
        );

        // Verifikasi tidak ada field medis, riwayat latihan privat, atau tanda tangan
        expect(find.text('Riwayat Medis Klien'), findsNothing);
        expect(find.text('Tanda Tangan Digital'), findsNothing);
        expect(find.text('Program Latihan Beban'), findsNothing);
        expect(find.text('Asesmen Kesehatan'), findsNothing);
        expect(find.text('Catatan Latihan'), findsNothing);

        // Tutup dialog
        await tester.tap(find.widgetWithText(FilledButton, 'Tutup'));
        await tester.pumpAndSettle();

        expect(find.text('Detail Absensi Klien'), findsNothing);
      },
    );
  });
}
