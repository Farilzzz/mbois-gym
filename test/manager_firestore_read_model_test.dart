// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';

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
    if (path != 'manager_dashboard') throw StateError('Private read: $path');
    return _Collection(this, path);
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Store store;
  @override
  final String path;
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
      expect(store.reads, ['manager_dashboard/2025-Q4']);
    },
  );
}
