import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:mbois_gym_pt/data/gym_repository.dart';
import 'package:mbois_gym_pt/data/manager_metrics.dart';
import 'package:mbois_gym_pt/data/pt_packages.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SqliteGymRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = SqliteGymRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('UAT Regression Suite - Mbois Gym PT Management 2026', () {
    test('1 & 2. Edit workout tanpa crash & Simpan perubahan berhasil tersimpan', () async {
      final trainerId = await db.into(db.trainers).insert(
            TrainersCompanion.insert(
              name: 'Coach UAT',
              email: 'coach.uat@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final clientId = await repo.addClient(
        name: 'Klien UAT Latihan',
        contact: '081234567890',
        age: 26,
        trainerId: trainerId,
        sessionsCount: 8,
        goal: 'Hypertrophy',
        medical: 'None',
      );

      final pkg = await repo.currentPackage(clientId);
      expect(pkg, isNotNull);

      // Simpan workout awal
      final logId = await repo.saveWorkout(
        clientId: clientId,
        packageId: pkg!.id,
        notes: 'Sesi Bench Press awal',
        exercises: [
          ExerciseDraft(
            name: 'Bench Press',
            method: 'Straight Set',
            equipment: 'Barbell',
            groupKey: 'Chest',
            rpe: 8.0,
            rir: 2,
            notes: 'Pemanasan cukup',
            sets: [
              SetDraft(10, 60.0, stage: 1),
              SetDraft(8, 70.0, stage: 2),
            ],
          ),
        ],
      );

      expect(logId, greaterThan(0));

      // Verifikasi baca workout awal
      final logBefore = await repo.getWorkoutLog(logId);
      expect(logBefore, isNotNull);
      expect(logBefore!.notes, 'Sesi Bench Press awal');

      final exercisesBefore = await repo.exercisesForLog(logId);
      expect(exercisesBefore.length, 1);
      final setsBefore = await repo.setsForExercise(exercisesBefore.first.id);
      expect(setsBefore.length, 2);

      // Edit Workout: ubah repetisi, beban, dan catatan
      await repo.updateWorkout(
        logId: logId,
        notes: 'Sesi Bench Press terupdate - intensitas tinggi',
        sessionId: null,
        exercises: [
          ExerciseDraft(
            id: exercisesBefore.first.id,
            name: 'Incline Bench Press',
            method: 'Drop Set',
            equipment: 'Dumbbell',
            groupKey: 'Upper Chest',
            rpe: 9.0,
            rir: 1,
            notes: 'Target kontraksi maksimal',
            sets: [
              SetDraft(12, 65.0, stage: 1, id: setsBefore[0].id),
              SetDraft(10, 75.0, stage: 2, id: setsBefore[1].id),
              SetDraft(8, 80.0, stage: 3), // tambah set ke-3
            ],
          ),
        ],
      );

      // Verifikasi konsistensi data setelah edit
      final logAfter = await repo.getWorkoutLog(logId);
      expect(logAfter!.notes, 'Sesi Bench Press terupdate - intensitas tinggi');

      final exercisesAfter = await repo.exercisesForLog(logId);
      expect(exercisesAfter.length, 1);
      expect(exercisesAfter.first.name, 'Incline Bench Press');
      expect(exercisesAfter.first.method, 'Drop Set');

      final setsAfter = await repo.setsForExercise(exercisesAfter.first.id);
      expect(setsAfter.length, 3);
      expect(setsAfter[0].reps, 12);
      expect(setsAfter[0].weightKg, 65.0);
      expect(setsAfter[2].reps, 8);
      expect(setsAfter[2].weightKg, 80.0);
    });

    test('3. Hapus workout tetap berfungsi dan menghapus exercise & sets terkait', () async {
      final trainerId = await db.into(db.trainers).insert(
            TrainersCompanion.insert(
              name: 'Coach Delete',
              email: 'coach.del@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final clientId = await repo.addClient(
        name: 'Klien Hapus',
        contact: '081234567891',
        age: 22,
        trainerId: trainerId,
        sessionsCount: 8,
        goal: 'Strength',
        medical: '',
      );

      final pkg = await repo.currentPackage(clientId);
      final logId = await repo.saveWorkout(
        clientId: clientId,
        packageId: pkg!.id,
        notes: 'Akan dihapus',
        exercises: [
          ExerciseDraft(
            name: 'Deadlift',
            method: 'Standard',
            equipment: 'Barbell',
            sets: [SetDraft(5, 100.0, stage: 1)],
          ),
        ],
      );

      final exercises = await repo.exercisesForLog(logId);
      expect(exercises.length, 1);

      // Hapus workout
      await repo.deleteWorkout(logId);

      final logAfter = await repo.getWorkoutLog(logId);
      expect(logAfter, isNull);

      final exercisesAfter = await repo.exercisesForLog(logId);
      expect(exercisesAfter, isEmpty);
    });

    test('4, 5 & 6. Progress paket sesuai completedCount, pembatalan tidak memotong kuota, dan paket batal keluar dari operasional', () async {
      final trainerId = await db.into(db.trainers).insert(
            TrainersCompanion.insert(
              name: 'Coach Lifecycle',
              email: 'coach.life@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final clientId = await repo.addClient(
        name: 'Klien Lifecycle',
        contact: '081234567892',
        age: 30,
        trainerId: trainerId,
        sessionsCount: 8,
        goal: 'Endurance',
        medical: '',
      );

      final pkg = await repo.currentPackage(clientId);
      expect(pkg!.totalSessions, 8);

      // Awal: 0 sesi selesai
      var completed = await repo.completedCount(pkg.id);
      expect(completed, 0);

      // Buat jadwal sesi 1
      final sess1Id = await repo.schedule(
        pkg.id,
        DateTime.now().add(const Duration(days: 1)),
      );

      // Jadwal dibatalkan
      await repo.cancelSession(sess1Id, cancelReason: 'Klien ada halangan mendadak');

      // Kuota completed tetap 0, sesi batal tidak memotong kuota
      completed = await repo.completedCount(pkg.id);
      expect(completed, 0);

      // Jadwal sesi pengganti dan selesaikan secara sah
      final sess2Id = await repo.schedule(
        pkg.id,
        DateTime.now().add(const Duration(days: 2)),
      );
      final ok = await repo.completeSession(sess2Id, 'Sesi pengganti terlaksana sempurna');
      expect(ok, isTrue);

      completed = await repo.completedCount(pkg.id);
      expect(completed, 1);
      final progress = completed / pkg.totalSessions;
      expect(progress, 0.125);

      // Klien masih berstatus 'active'
      var status = await repo.getClientLifecycleStatus(clientId);
      expect(status, 'active');

      // Batalkan seluruh paket pendaftaran
      await repo.cancelPackage(pkg.id, reason: 'Pindah domisili luar kota');

      // Klien berstatus 'cancelled', bukan 'active' dan bukan 'completed'
      status = await repo.getClientLifecycleStatus(clientId);
      expect(status, 'cancelled');

      // Kuota completed tetap tercatat 1 untuk audit historis
      completed = await repo.completedCount(pkg.id);
      expect(completed, 1);
    });

    test('7. Klien selesai tetap memiliki riwayat absensi dan sesi', () async {
      final trainerId = await db.into(db.trainers).insert(
            TrainersCompanion.insert(
              name: 'Coach Selesai',
              email: 'coach.selesai@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final clientId = await repo.addClient(
        name: 'Klien Lulus',
        contact: '081234567893',
        age: 28,
        trainerId: trainerId,
        sessionsCount: 8,
        goal: 'Tone',
        medical: '',
      );

      final pkg = await repo.currentPackage(clientId);

      // Selesaikan seluruh 8 sesi
      for (int i = 1; i <= 8; i++) {
        final sessId = await repo.schedule(
          pkg!.id,
          DateTime.now().add(Duration(days: i)),
        );
        await repo.completeSession(sessId, 'Sesi $i selesai');
      }

      final completed = await repo.completedCount(pkg!.id);
      expect(completed, 8);

      // Status klien otomatis 'completed'
      final status = await repo.getClientLifecycleStatus(clientId);
      expect(status, 'completed');

      // Sesi tetap lengkap tercatat di database
      final sessions = await repo.packageSessions(pkg.id);
      expect(sessions.length, 8);
      expect(sessions.every((s) => s.status == 'completed'), isTrue);
    });

    test('8 & 9. Manager menghitung seluruh PT aktif (termasuk tanpa penjualan)', () async {
      // Buat 2 trainer aktif
      await db.into(db.trainers).insert(
            TrainersCompanion.insert(
              name: 'Coach Akbar (Aktif, ada klien)',
              email: 'akbar@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.trainers).insert(
            TrainersCompanion.insert(
              name: 'Coach Faril (Aktif, baru masuk/tanpa penjualan)',
              email: 'faril@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final managerRepo = SqliteManagerDashboardRepository(db);
      final data = await managerRepo.fetchDashboardData(year: 2026, quarter: 1);

      // Total PT aktif harus 2, bukan 0 atau 1
      expect(data.totalActivePt, 2);
      expect(data.trainers.length, 2);

      final ptFaril = data.trainers.firstWhere((t) => t.name.contains('Coach Faril'));
      expect(ptFaril.totalSales, 0.0);
      expect(ptFaril.packagesSold, 0);
      expect(ptFaril.quarterlyTarget, 5000000.0);
      expect(ptFaril.achievementPercentage, 0.0);
    });

    test('10 & 11. Target Rp 5 Juta per PT per Triwulan hanya menghitung transaksi valid', () {
      final target = const QuarterlyTarget(year: 2026, quarter: 1, targetAmount: 5000000);

      final sales = [
        PackageSaleRecord(
          id: 's-1',
          clientId: 'c-1',
          clientName: 'Budi',
          trainerId: 'pt-1',
          trainerName: 'Coach Budi',
          tierName: 'Paket 10 Sesi',
          sessionsCount: 10,
          durationWeeks: 4,
          price: 1000000,
          timestamp: DateTime(2026, 1, 15),
          status: 'valid',
        ),
        PackageSaleRecord(
          id: 's-2',
          clientId: 'c-2',
          clientName: 'Doni',
          trainerId: 'pt-1',
          trainerName: 'Coach Budi',
          tierName: 'Paket 16 Sesi',
          sessionsCount: 16,
          durationWeeks: 8,
          price: 1600000,
          timestamp: DateTime(2026, 2, 20),
          status: 'valid',
        ),
        PackageSaleRecord(
          id: 's-3',
          clientId: 'c-3',
          clientName: 'Batal',
          trainerId: 'pt-1',
          trainerName: 'Coach Budi',
          tierName: 'Paket 4 Sesi',
          sessionsCount: 4,
          durationWeeks: 4,
          price: 500000,
          timestamp: DateTime(2026, 3, 10),
          status: 'cancelled', // DIBATALKAN: tidak boleh masuk hitungan
        ),
        PackageSaleRecord(
          id: 's-4',
          clientId: 'c-4',
          clientName: 'Luar Kuartal',
          trainerId: 'pt-1',
          trainerName: 'Coach Budi',
          tierName: 'Paket 24 Sesi',
          sessionsCount: 24,
          durationWeeks: 8,
          price: 2000000,
          timestamp: DateTime(2026, 5, 5), // Q2: tidak boleh masuk Q1
          status: 'valid',
        ),
      ];

      final metrics = calculateQuarterlyMetrics(sales: sales, target: target);

      // Hanya 2 transaksi valid di Q1: 1.000.000 + 1.600.000 = 2.600.000
      expect(metrics.totalSales, 2600000);
      expect(metrics.validSalesCount, 2);
      expect(metrics.achievementPercentage, (2600000 / 5000000) * 100.0);
      expect(metrics.remainingTarget, 5000000 - 2600000);

      // Rincian 3 bulan: Jan = 1jt, Feb = 1.6jt, Mar = 0 (karena s-3 cancelled)
      expect(metrics.monthlyBreakdown[0].totalSales, 1000000);
      expect(metrics.monthlyBreakdown[1].totalSales, 1600000);
      expect(metrics.monthlyBreakdown[2].totalSales, 0);
    });

    test('12. Preferensi Dark Mode persisten di SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', ThemeMode.dark.name);

      final loaded = prefs.getString('theme_mode');
      expect(loaded, 'dark');

      final mode = ThemeMode.values.firstWhere((m) => m.name == loaded);
      expect(mode, ThemeMode.dark);
    });
  });
}
