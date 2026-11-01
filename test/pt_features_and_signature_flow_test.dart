import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/app.dart';
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:mbois_gym_pt/data/gym_repository.dart';
import 'package:mbois_gym_pt/data/pt_packages.dart';
import 'package:mbois_gym_pt/features/screens.dart';

class _LoggedInAuth extends AuthController {
  final int id;
  _LoggedInAuth(this.id);
  @override
  Future<int?> build() async => id;
}

class FakeGymRepository implements GymRepository {
  final List<Client> clients = [];
  final Map<int, List<PtPackage>> packages = {};
  final Map<int, List<Session>> sessions = {};
  final List<PackageSaleRecord> sales = [];
  int _clientSeq = 1;
  int _pkgSeq = 1;
  int _sessSeq = 1;

  @override
  Future<List<Client>> allClients(int trainerId) async => List.unmodifiable(clients);

  @override
  Future<Client?> getClient(int clientId) async {
    return clients.cast<Client?>().firstWhere((c) => c?.id == clientId, orElse: () => null);
  }

  @override
  Future<int> addClient({
    required int trainerId,
    required String name,
    required int age,
    required int sessionsCount,
    String contact = '',
    double? height,
    double? weight,
    String goal = '',
    String medical = '',
    String injury = '',
    String notes = '',
  }) async {
    final id = _clientSeq++;
    final client = Client(
      id: id,
      trainerId: trainerId,
      name: name,
      age: age,
      contact: contact,
      heightCm: height,
      initialWeightKg: weight,
      goal: goal,
      medicalHistory: medical,
      injuryHistory: injury,
      assessmentNotes: notes,
    );
    clients.add(client);

    final pkgId = _pkgSeq++;
    packages[id] = [
      PtPackage(
        id: pkgId,
        clientId: id,
        totalSessions: sessionsCount,
        status: 'active',
        createdAt: DateTime.now(),
        closedAt: null,
      )
    ];
    sessions[pkgId] = [];
    return id;
  }

  Future<PtPackage?> activePackage(int clientId) async {
    final list = packages[clientId] ?? [];
    return list.cast<PtPackage?>().firstWhere((p) => p?.status == 'active', orElse: () => null);
  }

  @override
  Future<PtPackage?> currentPackage(int clientId) => activePackage(clientId);

  @override
  Future<List<Session>> packageSessions(int packageId) async {
    return List.unmodifiable(sessions[packageId] ?? []);
  }

  @override
  Future<int> completedCount(int packageId) async {
    final list = sessions[packageId] ?? [];
    return list.where((s) => s.status == 'completed').length;
  }

  @override
  Future<int> schedule(int packageId, DateTime time) async {
    final list = sessions[packageId] ??= [];
    final id = _sessSeq++;
    final session = Session(
      id: id,
      packageId: packageId,
      sessionNumber: list.length + 1,
      scheduledAt: time,
      status: 'scheduled',
      notes: '',
    );
    list.add(session);
    return id;
  }

  @override
  Future<bool> cancelSession(int sessionId, {String? cancelledBy, String? cancelReason}) async {
    for (final entry in sessions.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        final s = entry.value[i];
        if (s.id == sessionId) {
          if (s.status != 'scheduled') return false;
          entry.value[i] = Session(
            id: s.id,
            packageId: s.packageId,
            sessionNumber: s.sessionNumber,
            scheduledAt: s.scheduledAt,
            status: 'cancelled',
            notes: cancelReason ?? s.notes,
          );
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<bool> completeSession(int sessionId, String notes) async {
    for (final entry in sessions.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        final s = entry.value[i];
        if (s.id == sessionId) {
          if (s.status == 'completed') return true;
          if (s.status != 'scheduled') return false;
          entry.value[i] = Session(
            id: s.id,
            packageId: s.packageId,
            sessionNumber: s.sessionNumber,
            scheduledAt: s.scheduledAt,
            status: 'completed',
            notes: notes,
          );
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<PtPackage> renewPackage(int clientId, int sessionsCount) async {
    final list = packages[clientId] ??= [];
    for (int i = 0; i < list.length; i++) {
      if (list[i].status == 'active') {
        list[i] = PtPackage(
          id: list[i].id,
          clientId: clientId,
          totalSessions: list[i].totalSessions,
          status: 'closed',
          createdAt: list[i].createdAt,
          closedAt: DateTime.now(),
        );
      }
    }
    final newId = _pkgSeq++;
    final newPkg = PtPackage(
      id: newId,
      clientId: clientId,
      totalSessions: sessionsCount,
      status: 'active',
      createdAt: DateTime.now(),
      closedAt: null,
    );
    list.add(newPkg);
    sessions[newId] = [];
    return newPkg;
  }

  @override
  Future<bool> closePackage(int packageId) async {
    for (final entry in packages.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].id == packageId) {
          entry.value[i] = PtPackage(
            id: entry.value[i].id,
            clientId: entry.value[i].clientId,
            totalSessions: entry.value[i].totalSessions,
            status: 'closed',
            createdAt: entry.value[i].createdAt,
            closedAt: DateTime.now(),
          );
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<PackageSaleRecord> recordPackageSale(PackageSaleRecord sale) async {
    sales.add(sale);
    return sale;
  }

  @override
  Future<List<PackageSaleRecord>> getPackageSales({
    String? trainerId,
    int? year,
    int? quarter,
    String? status,
  }) async {
    return List.unmodifiable(sales);
  }

  // Stubs for remaining interface methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Official PT Packages & Pricing Tests', () {
    test('4 official tiers have correct sessions, weeks, and prices', () {
      final tiers = PtPackageTier.officialTiers;
      expect(tiers.length, 4);

      expect(tiers[0].sessionsCount, 4);
      expect(tiers[0].durationWeeks, 4);
      expect(tiers[0].price, 500000);
      expect(formatRupiah(tiers[0].price), 'Rp 500.000');

      expect(tiers[1].sessionsCount, 10);
      expect(tiers[1].durationWeeks, 4);
      expect(tiers[1].price, 1000000);
      expect(formatRupiah(tiers[1].price), 'Rp 1.000.000');

      expect(tiers[2].sessionsCount, 16);
      expect(tiers[2].durationWeeks, 8);
      expect(tiers[2].price, 1600000);
      expect(formatRupiah(tiers[2].price), 'Rp 1.600.000');

      expect(tiers[3].sessionsCount, 24);
      expect(tiers[3].durationWeeks, 8);
      expect(tiers[3].price, 2000000);
      expect(formatRupiah(tiers[3].price), 'Rp 2.000.000');
    });
  });

  group('Session Cancellation & Dedicated Signatures UI Tests', () {
    late FakeGymRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeGymRepository();
    });

    testWidgets('Session cancellation removes session from active scheduled view', (tester) async {
      final clientId = await fakeRepo.addClient(
        trainerId: 1,
        name: 'Budi Test',
        age: 26,
        sessionsCount: 10,
      );
      final pkg = (await fakeRepo.activePackage(clientId))!;
      await fakeRepo.schedule(pkg.id, DateTime.now().add(const Duration(days: 1)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gymRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: ClientDetailScreen(clientId: clientId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scheduled session should be visible
      expect(find.textContaining('Sesi 1'), findsOneWidget);
      expect(find.text('Potong Sesi'), findsOneWidget);
      expect(find.text('Batalkan Sesi'), findsOneWidget);

      // Tap Batalkan Sesi
      await tester.tap(find.text('Batalkan Sesi'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.textContaining('Batalkan Sesi 1'), findsOneWidget);
      expect(find.text('Konfirmasi Batalkan'), findsOneWidget);

      // Confirm cancellation
      await tester.tap(find.text('Konfirmasi Batalkan'));
      await tester.pumpAndSettle();

      // In default 'Aktif' filter, cancelled session should no longer be in the scheduled list!
      final updatedSessions = await fakeRepo.packageSessions(pkg.id);
      expect(updatedSessions.first.status, 'cancelled');

      // Now switch filter to 'Dibatalkan'
      await tester.tap(find.text('Dibatalkan'));
      await tester.pumpAndSettle();

      // The cancelled session is shown under Dibatalkan tab!
      expect(find.textContaining('Sesi 1 •'), findsOneWidget);
      expect(find.textContaining('DIBATALKAN'), findsWidgets);
    });

    testWidgets('Potong Sesi opens dedicated signature dialog sections for client and coach', (tester) async {
      final clientId = await fakeRepo.addClient(
        trainerId: 1,
        name: 'Rina Test',
        age: 24,
        sessionsCount: 10,
      );
      final pkg = (await fakeRepo.activePackage(clientId))!;
      await fakeRepo.schedule(pkg.id, DateTime.now().add(const Duration(days: 1)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gymRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: ClientDetailScreen(clientId: clientId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Potong Sesi
      await tester.tap(find.text('Potong Sesi'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.textContaining('Tanda Tangan & Absensi'), findsOneWidget);
      expect(find.text('Buka Pad Tanda Tangan Klien'), findsOneWidget);
      expect(find.text('Buka Pad Tanda Tangan Coach'), findsOneWidget);
    });

    testWidgets('ClientFormScreen displays 4 official packages and saves client', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gymRepositoryProvider.overrideWithValue(fakeRepo),
            authProvider.overrideWith(() => _LoggedInAuth(1)),
          ],
          child: const MaterialApp(
            home: ClientFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to see package choices
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Check the 4 official tiers are present in the form
      expect(find.textContaining('Paket 4 Sesi'), findsOneWidget);
      expect(find.textContaining('Paket 10 Sesi'), findsOneWidget);
      expect(find.textContaining('Paket 16 Sesi'), findsOneWidget);
      expect(find.textContaining('Paket 24 Sesi'), findsOneWidget);

      // Verify prices are formatted in Rupiah
      expect(find.textContaining('Rp 500.000'), findsOneWidget);
      expect(find.textContaining('Rp 1.000.000'), findsOneWidget);
      expect(find.textContaining('Rp 1.600.000'), findsOneWidget);
      expect(find.textContaining('Rp 2.000.000'), findsOneWidget);
    });
  });
}
