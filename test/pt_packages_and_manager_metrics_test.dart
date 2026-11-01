import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:mbois_gym_pt/data/gym_repository.dart';
import 'package:mbois_gym_pt/data/manager_metrics.dart';
import 'package:mbois_gym_pt/data/pt_packages.dart';

void main() {
  group('1. PT Packages & formatRupiah', () {
    test('4 paket resmi individu terdefinisi dengan parameter tepat', () {
      expect(officialPtPackages.length, 4);

      final pkg4 = officialPtPackages.firstWhere((p) => p.sessionsCount == 4);
      expect(pkg4.sessionsCount, 4);
      expect(pkg4.durationWeeks, 4);
      expect(pkg4.price, 500000);

      final pkg10 = officialPtPackages.firstWhere((p) => p.sessionsCount == 10);
      expect(pkg10.sessionsCount, 10);
      expect(pkg10.durationWeeks, 4);
      expect(pkg10.price, 1000000);

      final pkg16 = officialPtPackages.firstWhere((p) => p.sessionsCount == 16);
      expect(pkg16.sessionsCount, 16);
      expect(pkg16.durationWeeks, 8);
      expect(pkg16.price, 1600000);

      final pkg24 = officialPtPackages.firstWhere((p) => p.sessionsCount == 24);
      expect(pkg24.sessionsCount, 24);
      expect(pkg24.durationWeeks, 8);
      expect(pkg24.price, 2000000);
    });

    test('Helper formatRupiah memformat angka dengan pemisah ribuan titik', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(500000), 'Rp 500.000');
      expect(formatRupiah(1000000), 'Rp 1.000.000');
      expect(formatRupiah(1600000), 'Rp 1.600.000');
      expect(formatRupiah(2000000), 'Rp 2.000.000');
      expect(formatRupiah(5000000), 'Rp 5.000.000');
    });

    test('Model PackageSaleRecord menyimpan semua atribut dan serialisasi', () {
      final now = DateTime(2027, 2, 15, 10, 30);
      final sale = PackageSaleRecord(
        id: 'sale-1',
        clientId: 'client-101',
        clientName: 'Budi Santoso',
        trainerId: 'pt-01',
        trainerName: 'Coach Faril',
        tierName: 'Paket 10 Sesi',
        sessionsCount: 10,
        durationWeeks: 4,
        price: 1000000,
        timestamp: now,
        status: 'valid',
      );

      expect(sale.id, 'sale-1');
      expect(sale.clientId, 'client-101');
      expect(sale.clientName, 'Budi Santoso');
      expect(sale.trainerId, 'pt-01');
      expect(sale.trainerName, 'Coach Faril');
      expect(sale.tierName, 'Paket 10 Sesi');
      expect(sale.sessionsCount, 10);
      expect(sale.durationWeeks, 4);
      expect(sale.price, 1000000);
      expect(sale.timestamp, now);
      expect(sale.status, 'valid');
      expect(sale.isValid, isTrue);

      final map = sale.toMap();
      expect(map['id'], 'sale-1');
      expect(map['price'], 1000000);

      final restored = PackageSaleRecord.fromMap(map);
      expect(restored.id, sale.id);
      expect(restored.price, sale.price);
      expect(restored.clientName, sale.clientName);
    });
  });

  group('2. Manager Metrics & Filter Triwulan', () {
    test('Model QuarterlyTarget memiliki default target 5.000.000 dan validasi quarter 1-4', () {
      const targetDefault = QuarterlyTarget(year: 2027, quarter: 1);
      expect(targetDefault.year, 2027);
      expect(targetDefault.quarter, 1);
      expect(targetDefault.targetAmount, 5000000);

      expect(
        () => QuarterlyTarget(year: 2027, quarter: 0),
        throwsAssertionError,
      );
      expect(
        () => QuarterlyTarget(year: 2027, quarter: 5),
        throwsAssertionError,
      );
    });

    test('Filter triwulan mengelompokkan bulan Q1..Q4 dengan akurat', () {
      expect(getQuarter(DateTime(2027, 1, 15)), 1);
      expect(getQuarter(DateTime(2027, 3, 31)), 1);
      expect(getQuarter(DateTime(2027, 4, 1)), 2);
      expect(getQuarter(DateTime(2027, 6, 30)), 2);
      expect(getQuarter(DateTime(2027, 7, 1)), 3);
      expect(getQuarter(DateTime(2027, 9, 30)), 3);
      expect(getQuarter(DateTime(2027, 10, 1)), 4);
      expect(getQuarter(DateTime(2027, 12, 31)), 4);

      final sales = [
        PackageSaleRecord(
          id: 's1',
          clientId: 'c1',
          clientName: 'A',
          trainerId: 'pt1',
          trainerName: 'Coach A',
          tierName: 'Paket 4 Sesi',
          sessionsCount: 4,
          durationWeeks: 4,
          price: 500000,
          timestamp: DateTime(2027, 1, 10),
        ),
        PackageSaleRecord(
          id: 's2',
          clientId: 'c2',
          clientName: 'B',
          trainerId: 'pt1',
          trainerName: 'Coach A',
          tierName: 'Paket 10 Sesi',
          sessionsCount: 10,
          durationWeeks: 4,
          price: 1000000,
          timestamp: DateTime(2027, 4, 15),
        ),
      ];

      final q1Sales = filterSalesByQuarter(sales, year: 2027, quarter: 1);
      expect(q1Sales.length, 1);
      expect(q1Sales.first.id, 's1');

      final q2Sales = filterSalesByQuarter(sales, year: 2027, quarter: 2);
      expect(q2Sales.length, 1);
      expect(q2Sales.first.id, 's2');
    });

    test('Fungsi hitung metrik triwulan menghitung total sales valid, pencapaian %, sisa target, fl_chart breakdown, dan perbandingan PT', () {
      final sales = [
        // Q1 PT 1: Jan Rp500.000, Feb Rp1.000.000
        PackageSaleRecord(
          id: 's1',
          clientId: 'c1',
          clientName: 'Klien 1',
          trainerId: 'pt1',
          trainerName: 'Coach Anton',
          tierName: 'Paket 4 Sesi',
          sessionsCount: 4,
          durationWeeks: 4,
          price: 500000,
          timestamp: DateTime(2027, 1, 15),
          status: 'valid',
        ),
        PackageSaleRecord(
          id: 's2',
          clientId: 'c2',
          clientName: 'Klien 2',
          trainerId: 'pt1',
          trainerName: 'Coach Anton',
          tierName: 'Paket 10 Sesi',
          sessionsCount: 10,
          durationWeeks: 4,
          price: 1000000,
          timestamp: DateTime(2027, 2, 10),
          status: 'valid',
        ),
        // Q1 PT 2: Feb Rp1.600.000
        PackageSaleRecord(
          id: 's3',
          clientId: 'c3',
          clientName: 'Klien 3',
          trainerId: 'pt2',
          trainerName: 'Coach Bima',
          tierName: 'Paket 16 Sesi',
          sessionsCount: 16,
          durationWeeks: 8,
          price: 1600000,
          timestamp: DateTime(2027, 2, 20),
          status: 'valid',
        ),
        // Q1 Dibatalkan: Mar Rp2.000.000 (tidak boleh masuk total valid!)
        PackageSaleRecord(
          id: 's4',
          clientId: 'c4',
          clientName: 'Klien 4',
          trainerId: 'pt2',
          trainerName: 'Coach Bima',
          tierName: 'Paket 24 Sesi',
          sessionsCount: 24,
          durationWeeks: 8,
          price: 2000000,
          timestamp: DateTime(2027, 3, 5),
          status: 'cancelled',
        ),
        // Di luar Q1 (Bulan April / Q2): Rp2.000.000
        PackageSaleRecord(
          id: 's5',
          clientId: 'c5',
          clientName: 'Klien 5',
          trainerId: 'pt1',
          trainerName: 'Coach Anton',
          tierName: 'Paket 24 Sesi',
          sessionsCount: 24,
          durationWeeks: 8,
          price: 2000000,
          timestamp: DateTime(2027, 4, 1),
          status: 'valid',
        ),
      ];

      const target = QuarterlyTarget(
        year: 2027,
        quarter: 1,
        targetAmount: 5000000,
      );
      final metrics = calculateQuarterlyMetrics(sales: sales, target: target);

      // 1. Total sales valid: 500.000 + 1.000.000 + 1.600.000 = 3.100.000 (cancelled excluded)
      expect(metrics.totalSales, 3100000);
      expect(metrics.validSalesCount, 3);

      // 2. Pencapaian %: (3.100.000 / 5.000.000) * 100 = 62.0%
      expect(metrics.achievementPercentage, closeTo(62.0, 0.01));

      // 3. Sisa target: 5.000.000 - 3.100.000 = 1.900.000
      expect(metrics.remainingTarget, 1900000);

      // 4. Breakdown 3 bulan untuk fl_chart: Jan (x:0), Feb (x:1), Mar (x:2)
      expect(metrics.monthlyBreakdown.length, 3);
      expect(metrics.monthlyBreakdown[0].month, 1);
      expect(metrics.monthlyBreakdown[0].totalSales, 500000);
      expect(metrics.monthlyBreakdown[0].x, 0.0);
      expect(metrics.monthlyBreakdown[0].y, 500000.0);

      expect(metrics.monthlyBreakdown[1].month, 2);
      expect(
        metrics.monthlyBreakdown[1].totalSales,
        2600000,
      ); // 1.000.000 + 1.600.000
      expect(metrics.monthlyBreakdown[1].x, 1.0);
      expect(metrics.monthlyBreakdown[1].y, 2600000.0);

      expect(metrics.monthlyBreakdown[2].month, 3);
      expect(metrics.monthlyBreakdown[2].totalSales, 0); // s4 dibatalkan -> 0
      expect(metrics.monthlyBreakdown[2].x, 2.0);
      expect(metrics.monthlyBreakdown[2].y, 0.0);

      // 5. Perbandingan performa per PT (terurut total sales tertinggi)
      expect(metrics.ptPerformances.length, 2);
      // Coach Bima: Rp1.600.000 vs Coach Anton: Rp1.500.000
      expect(metrics.ptPerformances[0].trainerId, 'pt2');
      expect(metrics.ptPerformances[0].trainerName, 'Coach Bima');
      expect(metrics.ptPerformances[0].totalSales, 1600000);
      expect(metrics.ptPerformances[0].packagesSold, 1);
      expect(metrics.ptPerformances[0].totalSessions, 16);
      expect(
        metrics.ptPerformances[0].contributionPercentage,
        closeTo(51.61, 0.1),
      );

      expect(metrics.ptPerformances[1].trainerId, 'pt1');
      expect(metrics.ptPerformances[1].trainerName, 'Coach Anton');
      expect(metrics.ptPerformances[1].totalSales, 1500000);
      expect(metrics.ptPerformances[1].packagesSold, 2);
      expect(metrics.ptPerformances[1].totalSessions, 14); // 4 + 10
      expect(
        metrics.ptPerformances[1].contributionPercentage,
        closeTo(48.39, 0.1),
      );
    });

    test(
      'Target terlampaui menghasilkan sisa target 0 dan pencapaian > 100%',
      () {
        final sales = [
          PackageSaleRecord(
            id: 's1',
            clientId: 'c1',
            clientName: 'Klien 1',
            trainerId: 'pt1',
            trainerName: 'Coach Anton',
            tierName: 'Paket 24 Sesi',
            sessionsCount: 24,
            durationWeeks: 8,
            price: 2000000,
            timestamp: DateTime(2027, 1, 10),
          ),
          PackageSaleRecord(
            id: 's2',
            clientId: 'c2',
            clientName: 'Klien 2',
            trainerId: 'pt1',
            trainerName: 'Coach Anton',
            tierName: 'Paket 24 Sesi',
            sessionsCount: 24,
            durationWeeks: 8,
            price: 2000000,
            timestamp: DateTime(2027, 2, 10),
          ),
          PackageSaleRecord(
            id: 's3',
            clientId: 'c3',
            clientName: 'Klien 3',
            trainerId: 'pt1',
            trainerName: 'Coach Anton',
            tierName: 'Paket 24 Sesi',
            sessionsCount: 24,
            durationWeeks: 8,
            price: 2000000,
            timestamp: DateTime(2027, 3, 10),
          ),
        ];

        const target = QuarterlyTarget(
          year: 2027,
          quarter: 1,
          targetAmount: 5000000,
        );
        final metrics = calculateQuarterlyMetrics(sales: sales, target: target);

        expect(metrics.totalSales, 6000000);
        expect(metrics.achievementPercentage, 120.0);
        expect(metrics.remainingTarget, 0);
      },
    );
  });

  group('3. GymRepository Package Sales & Attendance CRUD', () {
    late AppDatabase db;
    late SqliteGymRepository repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = SqliteGymRepository(db);

      // Seed trainer & client in SQLite
      await db
          .into(db.trainers)
          .insert(
            TrainersCompanion.insert(
              name: 'Coach Faril',
              email: 'faril@mboisgym.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'SqliteGymRepository recordPackageSale dan getPackageSales dengan filter',
      () async {
        final sale1 = PackageSaleRecord(
          id: 'sale-001',
          clientId: '1',
          clientName: 'Budi Santoso',
          trainerId: '1',
          trainerName: 'Coach Faril',
          tierName: 'Paket 10 Sesi',
          sessionsCount: 10,
          durationWeeks: 4,
          price: 1000000,
          timestamp: DateTime(2027, 2, 1),
          status: 'valid',
        );

        final sale2 = PackageSaleRecord(
          id: 'sale-002',
          clientId: '2',
          clientName: 'Citra Dewi',
          trainerId: '2',
          trainerName: 'Coach Bima',
          tierName: 'Paket 16 Sesi',
          sessionsCount: 16,
          durationWeeks: 8,
          price: 1600000,
          timestamp: DateTime(2027, 5, 10),
          status: 'valid',
        );

        await repo.recordPackageSale(sale1);
        await repo.recordPackageSale(sale2);

        final allSales = await repo.getPackageSales();
        expect(allSales.length, 2);

        // Filter by trainer
        final pt1Sales = await repo.getPackageSales(trainerId: '1');
        expect(pt1Sales.length, 1);
        expect(pt1Sales.first.id, 'sale-001');

        // Filter by quarter
        final q1Sales = await repo.getPackageSales(year: 2027, quarter: 1);
        expect(q1Sales.length, 1);
        expect(q1Sales.first.id, 'sale-001');

        final q2Sales = await repo.getPackageSales(year: 2027, quarter: 2);
        expect(q2Sales.length, 1);
        expect(q2Sales.first.id, 'sale-002');
      },
    );

    test('SqliteGymRepository attendance CRUD: getAttendanceRecords, updateAttendanceRecord, cancelAttendanceRecord', () async {
      final clientId = await repo.addClient(
        trainerId: 1,
        name: 'Budi Santoso',
        age: 28,
        sessionsCount: 12,
      );
      final pkg = (await repo.currentPackage(clientId))!;
      final sId = await repo.schedule(pkg.id, DateTime(2027, 2, 20, 14, 0));

      // Get attendance records
      final records = await repo.getAttendanceRecords(clientId: clientId);
      expect(records.length, 1);
      final first = records.first;
      expect(first.id, sId);
      expect(first.status, 'scheduled');
      expect(first.clientName, 'Budi Santoso');

      // Update attendance record (e.g. mark attended / add notes)
      final updated = first.copyWith(
        status: 'completed',
        notes: 'Sesi latihan dada selesai',
      );
      final okUpdate = await repo.updateAttendanceRecord(updated);
      expect(okUpdate, isTrue);

      final recordsAfterUpdate = await repo.getAttendanceRecords(
        clientId: clientId,
      );
      expect(recordsAfterUpdate.first.status, 'completed');
      expect(recordsAfterUpdate.first.notes, 'Sesi latihan dada selesai');

      // Cancel attendance record
      final sId2 = await repo.schedule(pkg.id, DateTime(2027, 2, 22, 14, 0));
      final okCancel = await repo.cancelAttendanceRecord(
        sId2,
        cancelledBy: 'Coach Faril',
        cancelReason: 'Klien berhalangan sakit',
      );
      expect(okCancel, isTrue);

      final recordsAfterCancel = await repo.getAttendanceRecords(
        clientId: clientId,
      );
      final cancelled = recordsAfterCancel.firstWhere((r) => r.id == sId2);
      expect(cancelled.status, 'cancelled');
    });

    test(
      'FirestoreGymRepository recordPackageSale dan getPackageSales',
      () async {
        final store = FakeFirestore();
        final auth = FakeAuth();
        final firestoreRepo = FirestoreGymRepository(
          firestore: store,
          auth: auth,
        );

        final sale = PackageSaleRecord(
          id: 'sale-cloud-1',
          clientId: 'c10',
          clientName: 'Siti Aminah',
          trainerId: 'pt-cloud',
          trainerName: 'Coach Sarah',
          tierName: 'Paket 4 Sesi',
          sessionsCount: 4,
          durationWeeks: 4,
          price: 500000,
          timestamp: DateTime(2027, 3, 1),
        );

        final recorded = await firestoreRepo.recordPackageSale(sale);
        expect(recorded.id, 'sale-cloud-1');

        final sales = await firestoreRepo.getPackageSales();
        expect(sales.length, 1);
        expect(sales.first.id, 'sale-cloud-1');
        expect(sales.first.clientName, 'Siti Aminah');

        // Filter by quarter Q1
        final q1 = await firestoreRepo.getPackageSales(year: 2027, quarter: 1);
        expect(q1.length, 1);

        // Filter by quarter Q2 (should be empty)
        final q2 = await firestoreRepo.getPackageSales(year: 2027, quarter: 2);
        expect(q2, isEmpty);
      },
    );
  });
}

// ignore: subtype_of_sealed_class
class FakeFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> data = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      FakeCollectionReference(this, path);
}

// ignore: subtype_of_sealed_class
class FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final FakeFirestore fakeStore;
  @override
  final String path;
  FakeCollectionReference(this.fakeStore, this.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) {
    final docId = id ?? 'doc_${fakeStore.data.length + 1}';
    return FakeDocumentReference(fakeStore, '$path/$docId');
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = fakeStore.data.entries
        .where(
          (e) =>
              e.key.startsWith('$path/') &&
              !e.key.substring(path.length + 1).contains('/'),
        )
        .map((e) => FakeQueryDocumentSnapshot(e.key.split('/').last, e.value))
        .toList();
    return FakeQuerySnapshot(docs);
  }
}

// ignore: subtype_of_sealed_class
class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final FakeFirestore fakeStore;
  @override
  final String path;
  FakeDocumentReference(this.fakeStore, this.path);

  @override
  String get id => path.split('/').last;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    fakeStore.data[path] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final current = fakeStore.data[path] ?? {};
    current.addAll(data.cast<String, dynamic>());
    fakeStore.data[path] = current;
  }
}

// ignore: subtype_of_sealed_class
class FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  FakeQuerySnapshot(this.docs);
}

// ignore: subtype_of_sealed_class
class FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;
  FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;
}

// ignore: subtype_of_sealed_class
class FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => FakeUser();
}

// ignore: subtype_of_sealed_class
class FakeUser extends Fake implements User {
  @override
  String get uid => 'pt-cloud';
}
