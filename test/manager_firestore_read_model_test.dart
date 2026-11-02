// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';
import 'package:mbois_gym_pt/widgets/initial_avatar.dart';

// A path-enforcing Firestore boundary: any attempted source/private read fails.
class _Store extends Fake implements FirebaseFirestore {
  final reads = <String>[];
  final documents = <String, Map<String, dynamic>>{
    'manager_dashboard/2026-Q1': {
      'totalActivePt': 1,
      'totalActiveClients': 1,
      'totalPackagesSold': 2,
      'totalSales': 5100000,
      'monthlySales': [1000000, 2000000, 2100000],
    },
    'manager_dashboard/2026-Q1/trainers/pt1': {
      'name': 'Coach',
      'activeClients': 1,
      'packagesSold': 2,
      'totalSales': 5100000,
      'monthlySales': [1000000, 2000000, 2100000],
    },
    'manager_dashboard/2026-Q1/trainers/pt1/clients/c1': {
      'name': 'Klien',
      'packageName': 'Paket 10 Sesi',
      'totalSessions': 10,
      'attendedSessions': 1,
      'remainingSessions': 9,
    },
    'manager_dashboard/2026-Q1/trainers/pt1/clients/c1/attendance/s1': {
      'sessionNumber': 1,
      'scheduledTime': Timestamp.fromDate(DateTime(2026, 1, 4, 10)),
      'status': 'completed',
    },
  };
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path != 'manager_dashboard' && path != 'users') {
      throw StateError('Private read: $path');
    }
    return _Collection(this, path);
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Store store;
  @override
  final String path;
  final filters = <Object, Object?>{};
  @override
  Query<Map<String, dynamic>> where(Object field, {Object? isEqualTo,
    Object? isNotEqualTo, Object? isLessThan, Object? isLessThanOrEqualTo,
    Object? isGreaterThan, Object? isGreaterThanOrEqualTo,
    Object? arrayContains, Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn, Iterable<Object?>? whereNotIn, bool? isNull}) {
    filters[field] = isEqualTo;
    return this;
  }
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Document(store, '$path/$id');
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.reads.add(path);
    return _QueryResult(
      store.documents.keys
          .where(
            (p) =>
                p.startsWith('$path/') &&
                p.split('/').length == path.split('/').length + 1,
          )
          .map((p) => _Snapshot(store, p))
          .where((snap) {
            for (final entry in filters.entries) {
              if (snap.data()[entry.key] != entry.value) return false;
            }
            return true;
          })
          .toList(),
    );
  }
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(store, '$path/$collectionPath');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.reads.add(path);
    return _Snapshot(store, path);
  }
}

class _Snapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.store, this.path);
  final _Store store;
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  bool get exists => store.documents.containsKey(path);
  @override
  Map<String, dynamic> data() => store.documents[path]!;
  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      _Document(store, path);
}

class _QueryResult extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _QueryResult(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

void main() {
  test('active staff count is independent of missing quarterly sales', () async {
    final store = _Store();
    store.documents['users/pt1'] = {
      'role': 'trainer',
      'status': 'active',
      'displayName': 'Coach 1',
    };
    store.documents['users/pt2'] = {
      'role': 'trainer',
      'status': 'active',
      'displayName': 'Coach 2',
    };
    store.documents['users/pt3_inactive'] = {
      'role': 'trainer',
      'status': 'inactive',
      'displayName': 'Coach Inactive',
    };
    store.documents['users/c1'] = {
      'role': 'client',
      'status': 'active',
      'displayName': 'Client',
    };
    final result = await FirestoreManagerDashboardRepository(store)
        .fetchDashboardData(year: 2026, quarter: 4);
    expect(result.totalActivePt, 2);
    expect(result.projectionPending, isTrue);
    expect(result.isEmpty, isFalse);
    expect(store.reads, ['manager_dashboard/2026-Q4', 'users']);
  });

  test('Firestore manager reads isolated projection and preserves PT target/attendance', () async {
    final store = _Store();
    final result = await FirestoreManagerDashboardRepository(store)
        .fetchDashboardData(year: 2026, quarter: 1);
    expect(result.totalSales, 5100000);
    expect(result.trainers.single.quarterlyTarget, 5000000);
    expect(result.trainers.single.isTargetAchieved, isTrue);
    final client = result.trainers.single.clients.single;
    expect(client.remainingSessions, 9);
    expect(client.attendanceRecords.single.statusLabel, 'Hadir');
    expect(store.reads, [
      'manager_dashboard/2026-Q1',
      'manager_dashboard/2026-Q1/trainers',
      'manager_dashboard/2026-Q1/trainers/pt1/clients',
      'manager_dashboard/2026-Q1/trainers/pt1/clients/c1/attendance',
    ]);
  });
  test(
    'missing trusted projection is empty, never falls back to private data',
    () async {
      final store = _Store();
      final result = await FirestoreManagerDashboardRepository(store)
          .fetchDashboardData(year: 2025, quarter: 4);
      expect(result.isEmpty, isTrue);
      expect(result.projectionPending, isTrue);
      expect(store.reads, ['manager_dashboard/2025-Q4', 'users']);
    },
  );

  testWidgets('manager dashboard profile icon navigates to /settings', (tester) async {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => ManagerDashboardScreen(
            repository: InMemoryManagerDashboardRepository(),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('Manager Profile Screen Destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Manager Profile Screen Destination'), findsOneWidget);
  });

  testWidgets('displays projection pending warning and no dummy data when projectionPending is true', (tester) async {
    final repo = InMemoryManagerDashboardRepository(
      initialData: const ManagerDashboardData(
        totalActivePt: 2,
        totalActiveClients: 0,
        totalPackagesSold: 0,
        totalSales: 0,
        monthlySales: [0, 0, 0],
        trainers: [],
        projectionPending: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ManagerDashboardScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proyeksi Dashboard Belum Tersedia'), findsOneWidget);
    expect(find.textContaining('Tercatat 2 Personal Trainer aktif'), findsOneWidget);
    expect(find.textContaining('bukan nol penjualan riil'), findsOneWidget);
    expect(find.text('Menunggu sinkronisasi'), findsNWidgets(3));
  });

  testWidgets('renders InitialAvatar for trainers in trainer list', (tester) async {
    final repo = InMemoryManagerDashboardRepository(
      initialData: const ManagerDashboardData(
        totalActivePt: 1,
        totalActiveClients: 1,
        totalPackagesSold: 1,
        totalSales: 1000000,
        monthlySales: [1000000, 0, 0],
        trainers: [
          TrainerPerformance(
            id: 'pt1',
            name: 'Coach Sarah',
            specialization: 'HIIT & Strength',
            activeClients: 1,
            packagesSold: 1,
            totalSales: 1000000,
          ),
        ],
        projectionPending: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ManagerDashboardScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InitialAvatar), findsWidgets);
    expect(find.text('Coach Sarah'), findsOneWidget);
  });
}
