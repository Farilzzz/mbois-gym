// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/data/gym_repository.dart';

class MemoryStore extends Fake implements FirebaseFirestore {
  final rows = <String, Map<String, dynamic>>{};
  int queries = 0;
  int transactions = 0;
  bool throwOnTransaction = false;
  void Function()? beforeTransaction;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      MemoryCollection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    beforeTransaction?.call();
    transactions++;
    if (throwOnTransaction) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'deadline-exceeded',
        message: 'The transaction was aborted by timeout',
      );
    }
    final tx = MemoryTransaction(this);
    final result = await transactionHandler(tx);
    for (final change in tx.changes.entries) {
      rows[change.key] = {...?rows[change.key], ...change.value};
    }
    return result;
  }
}

class MemoryCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  MemoryCollection(this.store, this.path);
  final MemoryStore store;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) => MemoryDocument(
        store,
        '$path/${id ?? 'generated-${store.rows.length + 1}'}',
      );

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) =>
      MemoryQuery(
        store,
        path,
        const [],
        orderField: field.toString(),
        descending: descending,
      );

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) =>
      MemoryQuery(store, path, [
        (field.toString(), arrayContains ?? isEqualTo),
      ]);
}

class MemoryQuery extends Fake implements Query<Map<String, dynamic>> {
  MemoryQuery(
    this.store,
    this.path,
    this.filters, {
    this.orderField,
    this.descending = false,
  });
  final MemoryStore store;
  final String path;
  final List<(String, Object?)> filters;
  final String? orderField;
  final bool descending;

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) =>
      MemoryQuery(
        store,
        path,
        filters,
        orderField: field.toString(),
        descending: descending,
      );

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) =>
      MemoryQuery(
        store,
        path,
        [...filters, (field.toString(), isEqualTo)],
        orderField: orderField,
        descending: descending,
      );

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.queries++;
    var docs = store.rows.entries
        .where(
          (e) =>
              e.key.startsWith('$path/') &&
              !e.key.substring(path.length + 1).contains('/') &&
              filters.every(
                (f) =>
                    e.value[f.$1] == f.$2 ||
                    (e.value[f.$1] is List &&
                        (e.value[f.$1] as List).contains(f.$2)),
              ),
        )
        .map((e) => MemoryQueryDocument(store, e.key, e.value))
        .toList();

    if (orderField != null) {
      docs.sort((a, b) {
        final aVal = a.data()[orderField!];
        final bVal = b.data()[orderField!];
        if (aVal == null || bVal == null) return 0;
        final cmp = (aVal as Comparable).compareTo(bVal);
        return descending ? -cmp : cmp;
      });
    }

    return MemoryQuerySnapshot(docs);
  }
}

class MemoryDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  MemoryDocument(this.store, this.path);
  final MemoryStore store;
  @override
  final String path;

  @override
  String get id => path.split('/').last;

  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      MemoryCollection(store, '$path/$name');

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async =>
      MemoryDocumentSnapshot(this, store.rows[path]);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.rows[path] = {...data};
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.rows[path] = {...?store.rows[path], ...data.cast<String, dynamic>()};
  }
}

class MemoryDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  MemoryDocumentSnapshot(this.reference, this.value);
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? value;

  @override
  bool get exists => value != null;

  @override
  String get id => reference.id;

  @override
  Map<String, dynamic>? data() => value;
}

class MemoryQueryDocument extends MemoryDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  MemoryQueryDocument(
    MemoryStore store,
    String path,
    Map<String, dynamic> value,
  ) : super(MemoryDocument(store, path), value);

  @override
  Map<String, dynamic> data() => value!;
}

class MemoryQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  MemoryQuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class MemoryTransaction extends Fake implements Transaction {
  MemoryTransaction(this.store);
  final MemoryStore store;
  final changes = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async =>
      MemoryDocumentSnapshot(
        reference as DocumentReference<Map<String, dynamic>>,
        store.rows[reference.path],
      ) as DocumentSnapshot<T>;

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    changes[reference.path] = {
      ...?changes[reference.path],
      ...data.cast<String, dynamic>(),
    };
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    changes[reference.path] = {...(data as Map<String, dynamic>)};
    return this;
  }
}

class TestAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => TestUser();
}

class TestUser extends Fake implements User {
  @override
  String get uid => 'coach';
}

void main() {
  late MemoryStore store;
  FirestoreGymRepository repo() =>
      FirestoreGymRepository(firestore: store, auth: TestAuth());

  setUp(() {
    store = MemoryStore();
    store.rows['clients/client-1'] = {
      'id': 10,
      'status': 'active',
      'assignedTrainerIds': ['coach'],
    };
    store.rows['clients/client-1/packages/pkg-1'] = {
      'id': 20,
      'totalSessions': 2,
      'completedCount': 0,
      'status': 'active',
    };
    store.rows['clients/client-1/sessions/sess-1'] = {
      'id': 30,
      'packageIntId': 20,
      'packageDocId': 'pkg-1',
      'status': 'scheduled',
    };
  });

  group('completeSession atomic transaction and signatures', () {
    test('encodes signature strokes as array of maps with points without nested arrays', () async {
      final repository = repo();
      final clientStrokes = [
        [const Offset(10.5, 20.0), const Offset(15.0, 25.5)],
        [const Offset(30.0, 40.0)],
      ];
      final coachStrokes = [
        [const Offset(50.0, 60.0)],
      ];

      final success = await repository.completeSession(
        30,
        'Notes on workout completion',
        clientStrokes: clientStrokes,
        coachStrokes: coachStrokes,
        clientName: 'Client Alpha',
        trainerName: 'Coach Beta',
      );

      expect(success, isTrue);

      final sessionDoc = store.rows['clients/client-1/sessions/sess-1']!;
      expect(sessionDoc['status'], 'completed');
      expect(sessionDoc['notes'], 'Notes on workout completion');
      expect(sessionDoc['clientSignatureStatus'], 'verified');
      expect(sessionDoc['coachSignatureStatus'], 'verified');

      // Verify signature strokes structure: array of maps with points
      final clientSerialized = sessionDoc['clientSignatureStrokes'] as List;
      expect(clientSerialized, isA<List<Map<String, dynamic>>>());
      expect(clientSerialized.length, 2);
      expect(clientSerialized[0], isA<Map<String, dynamic>>());
      expect(clientSerialized[0]['points'], isA<List>());
      expect(clientSerialized[0]['points'][0], {'x': 10.5, 'y': 20.0});

      // Verify package atomic update
      final pkgDoc = store.rows['clients/client-1/packages/pkg-1']!;
      expect(pkgDoc['completedCount'], 1);
      expect(pkgDoc['lastCompletedSessionId'], 'sess-1');
      expect(pkgDoc['status'], 'active');
    });

    test('completing final session atomically transitions package status to closed', () async {
      store.rows['clients/client-1/packages/pkg-1']!['completedCount'] = 1;
      final repository = repo();

      final success = await repository.completeSession(30, 'Final session done');
      expect(success, isTrue);

      final pkgDoc = store.rows['clients/client-1/packages/pkg-1']!;
      expect(pkgDoc['completedCount'], 2);
      expect(pkgDoc['status'], 'closed');
      expect(pkgDoc['closedAt'], isNotNull);
    });

    test('idempotent completion prevents double deduction on repeat call', () async {
      final repository = repo();
      final first = await repository.completeSession(30, 'First completion');
      expect(first, isTrue);

      final second = await repository.completeSession(30, 'Duplicate completion');
      expect(second, isFalse);

      final pkgDoc = store.rows['clients/client-1/packages/pkg-1']!;
      expect(pkgDoc['completedCount'], 1); // Quota was NOT incremented again
    });

    test('getSessionDetails unpacks stroke points for UI consumers', () async {
      final repository = repo();
      await repository.completeSession(
        30,
        'Notes',
        clientStrokes: [
          [const Offset(10.0, 20.0)],
        ],
      );

      final details = await repository.getSessionDetails(30);
      expect(details, isNotNull);
      expect(details!['clientSignatureStrokes'], isA<List>());
      final strokes = details['clientSignatureStrokes'] as List;
      expect(strokes[0], isA<List>());
      expect(strokes[0][0], {'x': 10.0, 'y': 20.0});
    });

    test('reconciles cleanly if transaction throws but session is completed on server', () async {
      final repository = repo();
      store.beforeTransaction = () {
        // Simulate server committing the session before network aborts
        store.rows['clients/client-1/sessions/sess-1']!['status'] = 'completed';
      };
      store.throwOnTransaction = true;

      final result = await repository.completeSession(30, 'Notes');
      expect(result, isTrue);
    });

    test('safe logging captures sanitized exception without leaking payload', () async {
      final repository = repo();
      store.throwOnTransaction = true;
      final printLogs = <String>[];

      // Run with custom print interception
      final spec = ZoneSpecification(
        print: (self, parent, zone, line) {
          printLogs.add(line);
        },
      );

      final result = await runZoned(
        () => repository.completeSession(
          30,
          'SECRET_MEDICAL_NOTES_SHOULD_NEVER_LEAK',
          clientStrokes: [
            [const Offset(999.0, 888.0)],
          ],
        ),
        zoneSpecification: spec,
      );

      expect(result, isFalse);
      expect(printLogs.any((l) => l.contains('[FirestoreSafeLog] completeSession failed')), isTrue);
      expect(printLogs.any((l) => l.contains('SECRET_MEDICAL_NOTES')), isFalse);
      expect(printLogs.any((l) => l.contains('999.0')), isFalse);
    });
  });

  group('Lifecycle status evaluation', () {
    test('closed package with 0/4 completed is discontinued (not completed)', () async {
      store.rows['clients/client-1/packages/pkg-1']!['status'] = 'closed';
      store.rows['clients/client-1/packages/pkg-1']!['completedCount'] = 0;
      store.rows['clients/client-1/packages/pkg-1']!['totalSessions'] = 4;
      // No completed sessions
      store.rows['clients/client-1/sessions/sess-1']!['status'] = 'cancelled';

      final repository = repo();
      final status = await repository.getClientLifecycleStatus(10);
      expect(status, 'discontinued');
    });

    test('closed package with 4/4 completed is completed', () async {
      store.rows['clients/client-1/packages/pkg-1']!['status'] = 'closed';
      store.rows['clients/client-1/packages/pkg-1']!['completedCount'] = 4;
      store.rows['clients/client-1/packages/pkg-1']!['totalSessions'] = 4;
      store.rows['clients/client-1/sessions/sess-1']!['status'] = 'completed';
      store.rows['clients/client-1/sessions/sess-2'] = {
        'id': 31,
        'packageIntId': 20,
        'packageDocId': 'pkg-1',
        'status': 'completed',
      };
      store.rows['clients/client-1/sessions/sess-3'] = {
        'id': 32,
        'packageIntId': 20,
        'packageDocId': 'pkg-1',
        'status': 'completed',
      };
      store.rows['clients/client-1/sessions/sess-4'] = {
        'id': 33,
        'packageIntId': 20,
        'packageDocId': 'pkg-1',
        'status': 'completed',
      };

      final repository = repo();
      final status = await repository.getClientLifecycleStatus(10);
      expect(status, 'completed');
    });

    test('client status inactive returns inactive', () async {
      store.rows['clients/client-1']!['status'] = 'inactive';
      final repository = repo();
      final status = await repository.getClientLifecycleStatus(10);
      expect(status, 'inactive');
    });

    test('client status cancelled returns cancelled', () async {
      store.rows['clients/client-1']!['status'] = 'cancelled';
      final repository = repo();
      final status = await repository.getClientLifecycleStatus(10);
      expect(status, 'cancelled');
    });

    test('client with no package returns no_package', () async {
      store.rows.remove('clients/client-1/packages/pkg-1');
      final repository = repo();
      final status = await repository.getClientLifecycleStatus(10);
      expect(status, 'no_package');
    });

    test('client with active package returns active', () async {
      final repository = repo();
      final status = await repository.getClientLifecycleStatus(10);
      expect(status, 'active');
    });
  });
}
