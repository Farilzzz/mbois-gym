// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/data/gym_repository.dart';

// A narrow Firestore fake: the repository executes its actual queries and
// transaction callback; writes commit only when the callback succeeds.
class MemoryStore extends Fake implements FirebaseFirestore {
  final rows = <String, Map<String, dynamic>>{};
  int queries = 0;
  int transactions = 0;
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
  }) => MemoryQuery(store, path, [
    (field.toString(), arrayContains ?? isEqualTo),
  ]);
}

class MemoryQuery extends Fake implements Query<Map<String, dynamic>> {
  MemoryQuery(this.store, this.path, this.filters);
  final MemoryStore store;
  final String path;
  final List<(String, Object?)> filters;
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
  }) => MemoryQuery(store, path, [...filters, (field.toString(), isEqualTo)]);
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.queries++;
    final docs = store.rows.entries
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
  ]) async => MemoryDocumentSnapshot(this, store.rows[path]);
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
  ) async => MemoryDocumentSnapshot(
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
      'assignedTrainerIds': ['coach'],
    };
    store.rows['clients/client-1/packages/pkg-1'] = {
      'id': 20,
      'totalSessions': 2,
      'completedCount': 0,
      'status': 'active',
    };
  });

  test('schedule resolves package after restart and saves immutable package document ID', () async {
    final id = await repo().schedule(20, DateTime(2027));
    final row = store.rows['clients/client-1/sessions/generated-3']!;
    expect(row['id'], id);
    expect(row['packageDocId'], 'pkg-1');
    expect(row['packageIntId'], 20);
    expect(store.transactions, 1);
  });

  test(
    'schedule rejects package closed between lookup and transaction',
    () async {
      store.beforeTransaction = () {
        store.rows['clients/client-1/packages/pkg-1']!['status'] = 'closed';
      };
      await expectLater(repo().schedule(20, DateTime(2027)), throwsStateError);
      expect(
        store.rows.keys.where((key) => key.contains('/sessions/')),
        isEmpty,
      );
    },
  );

  test('completion never substitutes legacy mapping for missing stable package ref', () async {
    store.rows['clients/client-1/sessions/sess-missing'] = {
      'id': 33,
      'packageIntId': 20,
      'packageDocId': 'deleted-pkg',
      'status': 'scheduled',
    };
    expect(await repo().completeSession(33, 'done'), isFalse);
    expect(store.rows['clients/client-1/packages/pkg-1']!['completedCount'], 0);
    expect(
      store.rows['clients/client-1/sessions/sess-missing']!['status'],
      'scheduled',
    );
  });

  test('completion cannot deduct twice on repeat invocation', () async {
    store.rows['clients/client-1/sessions/sess-once'] = {
      'id': 34,
      'packageIntId': 20,
      'packageDocId': 'pkg-1',
      'status': 'scheduled',
    };
    final r = repo();
    expect(await r.completeSession(34, 'first'), isTrue);
    expect(await r.completeSession(34, 'repeat'), isFalse);
    expect(store.rows['clients/client-1/packages/pkg-1']!['completedCount'], 1);
  });

  test('packageSessions and completedCount resolve after restart', () async {
    store.rows['clients/client-1/sessions/sess-listed'] = {
      'id': 35,
      'packageIntId': 20,
      'packageDocId': 'pkg-1',
      'sessionNumber': 1,
      'status': 'completed',
    };
    final fresh = repo();
    expect((await fresh.packageSessions(20)).single.id, 35);
    expect(await fresh.completedCount(20), 1);
  });

  test(
    'new session uses its stable package ref despite wrong legacy integer',
    () async {
      store.rows['clients/client-1/sessions/sess-stable'] = {
        'id': 36,
        'packageIntId': 999,
        'packageDocId': 'pkg-1',
        'status': 'scheduled',
      };
      expect(await repo().completeSession(36, 'done'), isTrue);
      expect(
        store.rows['clients/client-1/packages/pkg-1']!['completedCount'],
        1,
      );
    },
  );

  test(
    'complete resolves legacy session and package on fresh instance atomically',
    () async {
      store.rows['clients/client-1/sessions/sess-1'] = {
        'id': 30,
        'packageIntId': 20,
        'status': 'scheduled',
      };
      expect(await repo().completeSession(30, 'done'), isTrue);
      expect(
        store.rows['clients/client-1/packages/pkg-1']!['completedCount'],
        1,
      );
      expect(
        store.rows['clients/client-1/sessions/sess-1']!['status'],
        'completed',
      );
    },
  );

  test('missing package aborts completion without changing session', () async {
    store.rows['clients/client-1/sessions/sess-1'] = {
      'id': 30,
      'packageIntId': 99,
      'status': 'scheduled',
    };
    expect(await repo().completeSession(30, 'done'), isFalse);
    expect(
      store.rows['clients/client-1/sessions/sess-1']!['status'],
      'scheduled',
    );
  });

  test(
    'package not active aborts completion without changing session or quota',
    () async {
      store.rows['clients/client-1/packages/pkg-inactive'] = {
        'id': 21,
        'totalSessions': 5,
        'completedCount': 1,
        'status': 'closed',
      };
      store.rows['clients/client-1/sessions/sess-inactive'] = {
        'id': 31,
        'packageIntId': 21,
        'status': 'scheduled',
      };
      expect(await repo().completeSession(31, 'done'), isFalse);
      expect(
        store.rows['clients/client-1/packages/pkg-inactive']!['completedCount'],
        1,
      );
      expect(
        store.rows['clients/client-1/sessions/sess-inactive']!['status'],
        'scheduled',
      );
    },
  );

  test(
    'exhausted package quota aborts completion without changing session',
    () async {
      store.rows['clients/client-1/packages/pkg-full'] = {
        'id': 22,
        'totalSessions': 2,
        'completedCount': 2,
        'status': 'active',
      };
      store.rows['clients/client-1/sessions/sess-full'] = {
        'id': 32,
        'packageIntId': 22,
        'packageDocId': 'pkg-full',
        'status': 'scheduled',
      };
      expect(await repo().completeSession(32, 'done'), isFalse);
      expect(
        store.rows['clients/client-1/packages/pkg-full']!['completedCount'],
        2,
      );
      expect(
        store.rows['clients/client-1/sessions/sess-full']!['status'],
        'scheduled',
      );
    },
  );

  test('resolver caches mapping so second schedule/resolve does not re-query clients', () async {
    final r = repo();
    await r.schedule(20, DateTime(2027));
    final initialQueries = store.queries;
    // Next schedule on same repository instance must reuse cached docId mapping
    await r.schedule(20, DateTime(2027, 2));
    // It should query existing sessions to count them, but NOT query clients collection!
    // clients query would add to store.queries
    expect(
      store.queries,
      initialQueries + 1,
    ); // only 1 query for existing sessions count
  });

  test('cancelSession resolves fallback, sets audit metadata, and validates status', () async {
    store.rows['clients/client-1/sessions/sess-c'] = {
      'id': 40,
      'packageIntId': 20,
      'status': 'scheduled',
    };
    final freshRepo = repo();
    expect(await freshRepo.cancelSession(40), isTrue);
    final row = store.rows['clients/client-1/sessions/sess-c']!;
    expect(row['status'], 'cancelled');
    expect(row['cancelledBy'], 'coach');
    expect(row['cancelReason'], isNotEmpty);

    // Second cancel must fail status validation (already cancelled)
    expect(await freshRepo.cancelSession(40), isFalse);
  });

  test('cancelSession accepts optional audit parameters', () async {
    store.rows['clients/client-1/sessions/sess-audit'] = {
      'id': 42,
      'packageIntId': 20,
      'status': 'scheduled',
    };
    final freshRepo = repo();
    expect(
      await freshRepo.cancelSession(
        42,
        cancelledBy: 'custom-admin',
        cancelReason: 'Member requested refund',
      ),
      isTrue,
    );
    final row = store.rows['clients/client-1/sessions/sess-audit']!;
    expect(row['status'], 'cancelled');
    expect(row['cancelledBy'], 'custom-admin');
    expect(row['cancelReason'], 'Member requested refund');
  });

  test('rescheduleSession accepts optional audit parameters', () async {
    final newTime = DateTime(2027, 2, 1);
    store.rows['clients/client-1/sessions/sess-resched-audit'] = {
      'id': 51,
      'packageIntId': 20,
      'status': 'scheduled',
      'scheduledTime': Timestamp.fromDate(DateTime(2027, 1, 1)),
    };
    final freshRepo = repo();
    expect(
      await freshRepo.rescheduleSession(
        51,
        newTime,
        rescheduledBy: 'custom-admin',
        reason: 'Coach sick leave',
      ),
      isTrue,
    );
    final row = store.rows['clients/client-1/sessions/sess-resched-audit']!;
    expect((row['scheduledTime'] as Timestamp).toDate(), newTime);
    expect(row['rescheduledBy'], 'custom-admin');
    expect(row['rescheduleReason'], 'Coach sick leave');
  });

  test('cancelSession rejects completed sessions', () async {
    store.rows['clients/client-1/sessions/sess-comp'] = {
      'id': 41,
      'packageIntId': 20,
      'status': 'completed',
    };
    expect(await repo().cancelSession(41), isFalse);
    expect(
      store.rows['clients/client-1/sessions/sess-comp']!['status'],
      'completed',
    );
  });

  test('rescheduleSession resolves fallback and validates status', () async {
    final initialTime = DateTime(2027, 1, 1);
    final newTime = DateTime(2027, 1, 10);
    store.rows['clients/client-1/sessions/sess-r'] = {
      'id': 50,
      'packageIntId': 20,
      'status': 'scheduled',
      'scheduledTime': Timestamp.fromDate(initialTime),
    };
    final freshRepo = repo();
    expect(await freshRepo.rescheduleSession(50, newTime), isTrue);
    final row = store.rows['clients/client-1/sessions/sess-r']!;
    expect((row['scheduledTime'] as Timestamp).toDate(), newTime);
    expect(row['rescheduledAt'], isNotNull);

    // Cancel the session, then verify reschedule fails
    store.rows['clients/client-1/sessions/sess-r']!['status'] = 'cancelled';
    expect(
      await freshRepo.rescheduleSession(50, DateTime(2027, 2, 1)),
      isFalse,
    );
  });
}
