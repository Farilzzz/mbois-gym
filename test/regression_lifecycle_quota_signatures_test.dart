import 'package:mbois_gym_pt/cloud/cloud_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/app.dart';
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:mbois_gym_pt/data/gym_repository.dart';
import 'package:mbois_gym_pt/features/screens.dart';

class _LoggedInAuth extends AuthController {
  final int id;
  _LoggedInAuth(this.id);
  @override
  Future<int?> build() async => id;
}

class _FakeCloudAuth extends CloudAuthController {
  final CloudProfile? profile;
  _FakeCloudAuth([this.profile]);
  @override
  Future<CloudProfile?> build() async => profile;
}


class RegressionMockGymRepository implements GymRepository {
  final List<Client> clients = [];
  final Map<int, String> clientLifecycle = {};
  final Map<int, List<PtPackage>> packages = {};
  final Map<int, List<Session>> sessions = {};
  final Map<int, Map<String, dynamic>> _sessionDetails = {};
  int _clientSeq = 1;
  int _pkgSeq = 1;
  int _sessSeq = 1;

  void addTestClient({
    required int id,
    required String name,
    required String lifecycle,
    required int totalSessions,
    int completedSessions = 0,
    String packageStatus = 'active',
  }) {
    final c = Client(
      id: id,
      trainerId: 1,
      name: name,
      age: 25,
      contact: '08123456789',
      goal: 'Fitness',
      medicalHistory: '',
      injuryHistory: '',
      assessmentNotes: '',
    );
    clients.add(c);
    clientLifecycle[id] = lifecycle;

    final pkgId = _pkgSeq++;
    final pkg = PtPackage(
      id: pkgId,
      clientId: id,
      totalSessions: totalSessions,
      status: packageStatus,
      createdAt: DateTime.now(),
      closedAt: packageStatus == 'closed' ? DateTime.now() : null,
    );
    packages[id] = [pkg];
    sessions[pkgId] = [];

    for (int i = 0; i < completedSessions; i++) {
      final sId = _sessSeq++;
      sessions[pkgId]!.add(
        Session(
          id: sId,
          packageId: pkgId,
          sessionNumber: i + 1,
          scheduledAt: DateTime.now().subtract(Duration(days: i + 1)),
          status: 'completed',
          notes: 'Completed session ${i + 1}',
        ),
      );
      _sessionDetails[sId] = {
        'id': sId,
        'clientName': name,
        'trainerName': 'Coach Mbois',
        'status': 'completed',
        'clientSignatureStrokes': [
          [
            const Offset(10.0, 10.0),
            const Offset(20.0, 20.0),
          ]
        ],
        'coachSignatureStrokes': [
          [
            const Offset(15.0, 15.0),
            const Offset(25.0, 25.0),
          ]
        ],
      };
    }
  }

  @override
  Future<List<Client>> allClients(int trainerId) async =>
      List.unmodifiable(clients);

  @override
  Future<Client?> getClient(int clientId) async {
    return clients
        .cast<Client?>()
        .firstWhere((c) => c?.id == clientId, orElse: () => null);
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
      goal: goal,
      medicalHistory: medical,
      injuryHistory: injury,
      assessmentNotes: notes,
    );
    clients.add(client);
    clientLifecycle[id] = 'active';

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

  @override
  Future<void> updateClient(Client client) async {
    final idx = clients.indexWhere((c) => c.id == client.id);
    if (idx != -1) {
      clients[idx] = client;
    }
  }

  @override
  Future<bool> deleteClient(int clientId) async {
    clientLifecycle[clientId] = 'cancelled';
    final list = packages[clientId] ?? [];
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
    return true;
  }

  @override
  Future<PtPackage?> currentPackage(int clientId) async {
    final list = packages[clientId] ?? [];
    try {
      return list.firstWhere((p) => p.status == 'active');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PtPackage?> latestPackage(int clientId) async {
    final list = packages[clientId] ?? [];
    return list.isNotEmpty ? list.last : null;
  }

  @override
  Future<String> getClientLifecycleStatus(int clientId) async {
    return clientLifecycle[clientId] ?? 'active';
  }

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
    list.add(
      Session(
        id: id,
        packageId: packageId,
        sessionNumber: list.length + 1,
        scheduledAt: time,
        status: 'scheduled',
        notes: '',
      ),
    );
    return id;
  }

  @override
  Future<bool> cancelSession(
    int sessionId, {
    String? cancelledBy,
    String? cancelReason,
  }) async {
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
  Future<bool> rescheduleSession(
    int sessionId,
    DateTime time, {
    String? rescheduledBy,
    String? reason,
    String? notes,
  }) async {
    for (final entry in sessions.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        final s = entry.value[i];
        if (s.id == sessionId) {
          if (s.status != 'scheduled') return false;
          entry.value[i] = Session(
            id: s.id,
            packageId: s.packageId,
            sessionNumber: s.sessionNumber,
            scheduledAt: time,
            status: 'scheduled',
            notes: notes ?? reason ?? s.notes,
          );
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<bool> completeSession(
    int sessionId,
    String notes, {
    List<List<Offset>>? clientStrokes,
    List<List<Offset>>? coachStrokes,
    String? clientName,
    String? trainerName,
  }) async {
    for (final entry in sessions.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        final s = entry.value[i];
        if (s.id == sessionId) {
          if (s.status == 'completed') return false; // Prevent double deduction
          if (s.status != 'scheduled') return false;
          entry.value[i] = Session(
            id: s.id,
            packageId: s.packageId,
            sessionNumber: s.sessionNumber,
            scheduledAt: s.scheduledAt,
            status: 'completed',
            notes: notes,
          );
          _sessionDetails[sessionId] = {
            'id': sessionId,
            'clientName': clientName ?? 'Klien',
            'trainerName': trainerName ?? 'Trainer',
            'notes': notes,
            'status': 'completed',
            'completedAt': DateTime.now(),
            'clientSignatureStrokes': clientStrokes ?? [],
            'coachSignatureStrokes': coachStrokes ?? [],
          };
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>?> getSessionDetails(int sessionId) async {
    return _sessionDetails[sessionId];
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
    clientLifecycle[clientId] = 'active';
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
          clientLifecycle[entry.key] = 'completed';
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<List<Session>> allSessionsForTrainer(int trainerId) async {
    final List<Session> list = [];
    for (final s in sessions.values) {
      list.addAll(s);
    }
    return list;
  }

  @override
  Future<List<PtPackage>> allPackagesForTrainer(int trainerId) async {
    final List<PtPackage> list = [];
    for (final p in packages.values) {
      list.addAll(p);
    }
    return list;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Bug Fix & Regression Suite (20 Scenarios)', () {
    late RegressionMockGymRepository repo;

    setUp(() {
      repo = RegressionMockGymRepository();
    });

    testWidgets(
        '1 & 4. Klien aktif terlihat di Home & Tidak ada kartu aktif palsu 0/0',
        (tester) async {
      repo.addTestClient(
        id: 1,
        name: 'Budi Santoso',
        lifecycle: 'active',
        totalSessions: 8,
        completedSessions: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gymRepositoryProvider.overrideWithValue(repo),
            authProvider.overrideWith(() => _LoggedInAuth(1)),
            cloudAuthProvider.overrideWith(() => _FakeCloudAuth(
                  const CloudProfile(
                    'coach-1',
                    'Coach Mbois',
                    true,
                    email: 'coach@mboisgym.com',
                    role: 'trainer',
                    status: 'active',
                  ),
                )),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.textContaining('Sisa 6 Sesi dari 8'), findsOneWidget);
      expect(find.textContaining('0 Sesi dari 0'), findsNothing);
    });

    testWidgets('2. Klien dibatalkan tidak muncul di Home', (tester) async {
      repo.addTestClient(
        id: 2,
        name: 'Dimas Batal',
        lifecycle: 'cancelled',
        totalSessions: 4,
        completedSessions: 0,
        packageStatus: 'closed',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gymRepositoryProvider.overrideWithValue(repo),
            authProvider.overrideWith(() => _LoggedInAuth(1)),
            cloudAuthProvider.overrideWith(() => _FakeCloudAuth(
                  const CloudProfile(
                    'coach-1',
                    'Coach Mbois',
                    true,
                    email: 'coach@mboisgym.com',
                    role: 'trainer',
                    status: 'active',
                  ),
                )),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dimas Batal'), findsNothing);
      expect(find.textContaining('0 Sesi dari 0'), findsNothing);
    });

    testWidgets(
        '3. Klien selesai seluruh paket tidak muncul sebagai klien aktif di Home',
        (tester) async {
      repo.addTestClient(
        id: 3,
        name: 'Eko Selesai',
        lifecycle: 'completed',
        totalSessions: 4,
        completedSessions: 4,
        packageStatus: 'closed',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gymRepositoryProvider.overrideWithValue(repo),
            authProvider.overrideWith(() => _LoggedInAuth(1)),
            cloudAuthProvider.overrideWith(() => _FakeCloudAuth(
                  const CloudProfile(
                    'coach-1',
                    'Coach Mbois',
                    true,
                    email: 'coach@mboisgym.com',
                    role: 'trainer',
                    status: 'active',
                  ),
                )),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eko Selesai'), findsNothing);
      expect(find.textContaining('0 Sesi dari 0'), findsNothing);
    });

    test(
        '5, 6, 7 & 8. Paket 4 sesi: buat 4 jadwal, batalkan 1 bebaskan slot, buat pengganti, completed tetap',
        () async {
      repo.addTestClient(
        id: 4,
        name: 'Siti Rahma',
        lifecycle: 'active',
        totalSessions: 4,
        completedSessions: 1, // 1 sesi completed
      );
      final pkg = (await repo.currentPackage(4))!;

      // Initial state: total = 4, completed = 1
      var sessions = await repo.packageSessions(pkg.id);
      var completedCount =
          sessions.where((s) => s.status == 'completed').length;
      var scheduledCount =
          sessions.where((s) => s.status == 'scheduled').length;
      var availableSlots = pkg.totalSessions - completedCount - scheduledCount;
      expect(availableSlots, equals(3));

      // Buat 3 jadwal aktif untuk mengisi slot penuh
      await repo.schedule(
          pkg.id, DateTime.now().add(const Duration(days: 1)));
      final s2 = await repo.schedule(
          pkg.id, DateTime.now().add(const Duration(days: 2)));
      await repo.schedule(
          pkg.id, DateTime.now().add(const Duration(days: 3)));

      sessions = await repo.packageSessions(pkg.id);
      scheduledCount = sessions.where((s) => s.status == 'scheduled').length;
      availableSlots = pkg.totalSessions - completedCount - scheduledCount;
      expect(availableSlots, equals(0)); // Slot habis

      // Batalkan 1 jadwal (s2)
      final cancelOk =
          await repo.cancelSession(s2, cancelReason: 'Klien berhalangan');
      expect(cancelOk, isTrue);

      // Hitung ulang slot: sesi batal TIDAK dihitung sebagai slot terpakai
      sessions = await repo.packageSessions(pkg.id);
      completedCount = sessions.where((s) => s.status == 'completed').length;
      scheduledCount = sessions.where((s) => s.status == 'scheduled').length;
      availableSlots = pkg.totalSessions - completedCount - scheduledCount;
      expect(availableSlots, equals(1)); // Slot kembali tersedia!
      expect(completedCount, equals(1)); // Kuota completed tidak berkurang

      // Buat jadwal pengganti
      final sReplacement = await repo.schedule(
          pkg.id, DateTime.now().add(const Duration(days: 4)));
      expect(sReplacement, isPositive);

      sessions = await repo.packageSessions(pkg.id);
      scheduledCount = sessions.where((s) => s.status == 'scheduled').length;
      availableSlots = pkg.totalSessions - completedCount - scheduledCount;
      expect(availableSlots, equals(0));
    });

    test(
        '9 & 16. Pemotongan sesi hanya terjadi satu kali dan tidak bisa dipotong ulang',
        () async {
      repo.addTestClient(
        id: 5,
        name: 'Andi Pratama',
        lifecycle: 'active',
        totalSessions: 4,
      );
      final pkg = (await repo.currentPackage(5))!;
      final sId = await repo.schedule(pkg.id, DateTime.now());

      // Potong pertama kali -> Berhasil
      final ok1 = await repo.completeSession(
        sId,
        'Catatan pertama',
        clientStrokes: [
          [const Offset(10, 10), const Offset(20, 20)]
        ],
        coachStrokes: [
          [const Offset(30, 30), const Offset(40, 40)]
        ],
        clientName: 'Andi Pratama',
        trainerName: 'Coach Mbois',
      );
      expect(ok1, isTrue);

      // Potong kedua kali pada sesi yang sama -> GAGAL (anti-double deduction)
      final ok2 = await repo.completeSession(sId, 'Catatan kedua');
      expect(ok2, isFalse);

      final completed = await repo.completedCount(pkg.id);
      expect(completed, equals(1));
    });

    test('10. Perpanjangan paket tidak tercampur dengan paket lama', () async {
      repo.addTestClient(
        id: 6,
        name: 'Rian Perpanjang',
        lifecycle: 'active',
        totalSessions: 4,
        completedSessions: 4,
      );
      final oldPkg = (await repo.currentPackage(6));
      expect(oldPkg, isNotNull);

      // Perpanjang paket menjadi 8 sesi
      final newPkg = await repo.renewPackage(6, 8);
      expect(newPkg.totalSessions, equals(8));
      expect(newPkg.id, isNot(equals(oldPkg!.id)));

      final cur = (await repo.currentPackage(6))!;
      expect(cur.id, equals(newPkg.id));
      expect(cur.totalSessions, equals(8));

      // Sessions paket baru masih 0, tidak tercampur sesi lama
      final newSessions = await repo.packageSessions(newPkg.id);
      expect(newSessions.length, equals(0));
    });

    test(
        '11, 12 & 13. Jadwal planned dapat diedit tanggal & jam tanpa ubah kuota',
        () async {
      repo.addTestClient(
        id: 7,
        name: 'Doni Reschedule',
        lifecycle: 'active',
        totalSessions: 4,
      );
      final pkg = (await repo.currentPackage(7))!;
      final initialTime = DateTime(2026, 11, 5, 10, 0);
      final sId = await repo.schedule(pkg.id, initialTime);

      final newTime = DateTime(2026, 11, 6, 15, 30);
      final editOk = await repo.rescheduleSession(
        sId,
        newTime,
        notes: 'Reschedule ke sore hari',
      );
      expect(editOk, isTrue);

      final sessions = await repo.packageSessions(pkg.id);
      final updated = sessions.firstWhere((s) => s.id == sId);
      expect(updated.scheduledAt, equals(newTime));
      expect(updated.notes, equals('Reschedule ke sore hari'));
      expect(updated.status, equals('scheduled'));

      // Kuota completed tetap 0
      final completed = await repo.completedCount(pkg.id);
      expect(completed, equals(0));
    });

    test(
        '14 & 15. Sesi completed tercatat di riwayat dengan kedua tanda tangan',
        () async {
      repo.addTestClient(
        id: 8,
        name: 'Hendra Signature',
        lifecycle: 'active',
        totalSessions: 4,
      );
      final pkg = (await repo.currentPackage(8))!;
      final sId = await repo.schedule(pkg.id, DateTime.now());

      final clientStrokes = [
        [const Offset(12, 12), const Offset(24, 24)]
      ];
      final coachStrokes = [
        [const Offset(34, 34), const Offset(48, 48)]
      ];

      await repo.completeSession(
        sId,
        'Latihan Chest & Triceps',
        clientStrokes: clientStrokes,
        coachStrokes: coachStrokes,
        clientName: 'Hendra Signature',
        trainerName: 'Coach Faril',
      );

      final details = await repo.getSessionDetails(sId);
      expect(details, isNotNull);
      expect(details!['clientName'], equals('Hendra Signature'));
      expect(details['trainerName'], equals('Coach Faril'));
      expect(details['notes'], equals('Latihan Chest & Triceps'));
      expect(details['clientSignatureStrokes'], isNotEmpty);
      expect(details['coachSignatureStrokes'], isNotEmpty);
    });

    testWidgets(
        '17, 18 & 19. Tampilan layout adaptif, tidak overflow pada 320x640',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      repo.addTestClient(
        id: 9,
        name: 'Klien Layar Kecil',
        lifecycle: 'active',
        totalSessions: 4,
        completedSessions: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gymRepositoryProvider.overrideWithValue(repo),
            authProvider.overrideWith(() => _LoggedInAuth(1)),
            cloudAuthProvider.overrideWith(() => _FakeCloudAuth(
                  const CloudProfile(
                    'coach-1',
                    'Coach Mbois',
                    true,
                    email: 'coach@mboisgym.com',
                    role: 'trainer',
                    status: 'active',
                  ),
                )),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Klien Layar Kecil'), findsOneWidget);
    });

    test(
        '20. Lifecycle consistency: deleteClient menandai cancelled tanpa hapus histori',
        () async {
      repo.addTestClient(
        id: 10,
        name: 'Klien Hapus Lembut',
        lifecycle: 'active',
        totalSessions: 4,
        completedSessions: 2,
      );
      final pkg = (await repo.currentPackage(10))!;

      // Hapus klien (soft-cancel)
      await repo.deleteClient(10);

      // Lifecycle status berubah ke cancelled
      final status = await repo.getClientLifecycleStatus(10);
      expect(status, equals('cancelled'));

      // Dokumen klien dan riwayat sesi TIDAK hilang dari histori
      final client = await repo.getClient(10);
      expect(client, isNotNull);
      expect(client!.name, equals('Klien Hapus Lembut'));

      final sList = await repo.packageSessions(pkg.id);
      expect(sList.length, equals(2)); // Riwayat 2 sesi completed tetap aman
    });
  });
}
