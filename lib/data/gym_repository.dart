import 'dart:async';
import 'dart:ui' show Offset;

import 'package:drift/drift.dart' show Value;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:mbois_gym_pt/data/pt_packages.dart';

abstract class GymRepository {
  Future<List<Client>> allClients(int trainerId);
  Future<Client?> getClient(int clientId);
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
  });
  Future<void> updateClient(Client client);
  Future<bool> deleteClient(int clientId);
  Future<PtPackage?> currentPackage(int clientId);
  Future<PtPackage?> latestPackage(int clientId);
  Future<String> getClientLifecycleStatus(int clientId);
  Future<List<Session>> packageSessions(int packageId);
  Future<int> completedCount(int packageId);
  Future<int> schedule(int packageId, DateTime time);
  Future<bool> cancelSession(
    int sessionId, {
    String? cancelledBy,
    String? cancelReason,
  });
  Future<bool> rescheduleSession(
    int sessionId,
    DateTime time, {
    String? rescheduledBy,
    String? reason,
    String? notes,
  });
  Future<PtPackage> renewPackage(int clientId, int sessionsCount);
  Future<bool> completeSession(
    int sessionId,
    String notes, {
    List<List<Offset>>? clientStrokes,
    List<List<Offset>>? coachStrokes,
    String? clientName,
    String? trainerName,
  });
  Future<Map<String, dynamic>?> getSessionDetails(int sessionId);
  Future<int> saveWorkout({
    required int clientId,
    required int packageId,
    int? sessionId,
    required String notes,
    required List<ExerciseDraft> exercises,
  });
  Future<void> updateWorkout({
    required int logId,
    required String notes,
    int? sessionId,
    required List<ExerciseDraft> exercises,
  });
  Future<bool> deleteWorkout(int logId);
  Future<bool> deleteWorkoutExercise(int exerciseId);
  Future<bool> deleteWorkoutSet(int setId);
  Future<List<WorkoutLog>> logsForClient(int clientId);
  Future<List<WorkoutExercise>> exercisesForLog(int logId);
  Future<List<WorkoutSet>> setsForExercise(int exerciseId);
  Future<WorkoutLog?> getWorkoutLog(int logId);
  Future<PostPtEvaluation?> getEvaluationForPackage(int packageId);
  Future<void> finalizePackage(int packageId, PostPtEvaluationsCompanion eval);
  Future<List<PtPackage>> allPackagesForTrainer(int trainerId);
  Future<List<Session>> allSessionsForTrainer(int trainerId);
  Future<void> closePackage(int packageId);
  Future<void> cancelPackage(int packageId, {String? reason});
  Future<List<ExerciseCatalogData>> get exerciseCatalog;

  // Attendance & Package Sales Methods
  Future<List<AttendanceRecord>> getAttendanceRecords({
    int? trainerId,
    int? clientId,
    int? packageId,
    String? status,
  });
  Future<bool> updateAttendanceRecord(AttendanceRecord record);
  Future<bool> cancelAttendanceRecord(
    int id, {
    String? cancelledBy,
    String? cancelReason,
  });
  Future<PackageSaleRecord> recordPackageSale(PackageSaleRecord sale);
  Future<List<PackageSaleRecord>> getPackageSales({
    String? trainerId,
    int? year,
    int? quarter,
    String? status,
  });
}

/// Model presensi/kehadiran sesi PT.
class AttendanceRecord {
  final int id;
  final int packageId;
  final int clientId;
  final String clientName;
  final int trainerId;
  final String trainerName;
  final int sessionNumber;
  final DateTime date;
  final String status;
  final String notes;
  final String? cancelReason;
  final String? cancelledBy;

  const AttendanceRecord({
    required this.id,
    required this.packageId,
    required this.clientId,
    this.clientName = '',
    required this.trainerId,
    this.trainerName = '',
    this.sessionNumber = 1,
    required this.date,
    this.status = 'scheduled',
    this.notes = '',
    this.cancelReason,
    this.cancelledBy,
  });

  AttendanceRecord copyWith({
    int? id,
    int? packageId,
    int? clientId,
    String? clientName,
    int? trainerId,
    String? trainerName,
    int? sessionNumber,
    DateTime? date,
    String? status,
    String? notes,
    String? cancelReason,
    String? cancelledBy,
  }) => AttendanceRecord(
    id: id ?? this.id,
    packageId: packageId ?? this.packageId,
    clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName,
    trainerId: trainerId ?? this.trainerId,
    trainerName: trainerName ?? this.trainerName,
    sessionNumber: sessionNumber ?? this.sessionNumber,
    date: date ?? this.date,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    cancelReason: cancelReason ?? this.cancelReason,
    cancelledBy: cancelledBy ?? this.cancelledBy,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'packageId': packageId,
    'clientId': clientId,
    'clientName': clientName,
    'trainerId': trainerId,
    'trainerName': trainerName,
    'sessionNumber': sessionNumber,
    'date': date,
    'status': status,
    'notes': notes,
    'cancelReason': cancelReason,
    'cancelledBy': cancelledBy,
  };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, {int? id}) {
    DateTime parseTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return AttendanceRecord(
      id:
          id ??
          (map['id'] as num?)?.toInt() ??
          int.tryParse(map['id']?.toString() ?? '') ??
          0,
      packageId:
          (map['packageId'] as num?)?.toInt() ??
          (map['packageIntId'] as num?)?.toInt() ??
          0,
      clientId:
          (map['clientId'] as num?)?.toInt() ??
          (map['clientIntId'] as num?)?.toInt() ??
          0,
      clientName: map['clientName']?.toString() ?? '',
      trainerId:
          (map['trainerId'] as num?)?.toInt() ??
          (map['trainerIntId'] as num?)?.toInt() ??
          0,
      trainerName: map['trainerName']?.toString() ?? '',
      sessionNumber: (map['sessionNumber'] as num?)?.toInt() ?? 1,
      date: parseTime(
        map['date'] ?? map['scheduledTime'] ?? map['completedAt'],
      ),
      status: map['status']?.toString() ?? 'scheduled',
      notes: map['notes']?.toString() ?? '',
      cancelReason: map['cancelReason']?.toString(),
      cancelledBy: map['cancelledBy']?.toString(),
    );
  }
}

/// SQLite Repository: wraps local Drift AppDatabase
class SqliteGymRepository implements GymRepository {
  final AppDatabase db;
  SqliteGymRepository(this.db);

  @override
  Future<List<Client>> allClients(int trainerId) => db.allClients(trainerId);

  @override
  Future<Client?> getClient(int clientId) => (db.select(
    db.clients,
  )..where((c) => c.id.equals(clientId))).getSingleOrNull();

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
  }) => db.addClient(
    trainerId: trainerId,
    name: name,
    age: age,
    sessionsCount: sessionsCount,
    contact: contact,
    height: height,
    weight: weight,
    goal: goal,
    medical: medical,
    injury: injury,
    notes: notes,
  );

  @override
  Future<void> updateClient(Client client) =>
      db.update(db.clients).replace(client).then((_) {});

  @override
  Future<bool> deleteClient(int clientId) async {
    final count = await (db.delete(
      db.clients,
    )..where((c) => c.id.equals(clientId))).go();
    return count > 0;
  }

  @override
  Future<PtPackage?> currentPackage(int clientId) =>
      db.currentPackage(clientId);

  @override
  Future<PtPackage?> latestPackage(int clientId) =>
      db.currentPackage(clientId);

  @override
  Future<String> getClientLifecycleStatus(int clientId) async {
    final client = await getClient(clientId);
    if (client == null) return 'unknown';
    final pkg = await latestPackage(clientId);
    if (pkg == null) return 'no_package';
    if (pkg.status == 'cancelled') return 'cancelled';
    if (pkg.status == 'inactive') return 'inactive';
    final completed = await completedCount(pkg.id);
    if (pkg.status == 'closed') {
      if (completed < pkg.totalSessions) {
        return 'discontinued';
      }
      return 'completed';
    }
    if (completed >= pkg.totalSessions) {
      return 'completed';
    }
    return 'active';
  }

  @override
  Future<List<Session>> packageSessions(int packageId) =>
      db.packageSessions(packageId);

  @override
  Future<int> completedCount(int packageId) => db.completedCount(packageId);

  @override
  Future<int> schedule(int packageId, DateTime time) =>
      db.schedule(packageId, time);

  @override
  Future<bool> cancelSession(
    int sessionId, {
    String? cancelledBy,
    String? cancelReason,
  }) => db.cancelSession(sessionId);

  @override
  Future<bool> rescheduleSession(
    int sessionId,
    DateTime time, {
    String? rescheduledBy,
    String? reason,
    String? notes,
  }) => db.rescheduleSession(sessionId, time);

  @override
  Future<PtPackage> renewPackage(int clientId, int sessionsCount) =>
      db.renewPackage(clientId, sessionsCount);

  @override
  Future<bool> completeSession(
    int sessionId,
    String notes, {
    List<List<Offset>>? clientStrokes,
    List<List<Offset>>? coachStrokes,
    String? clientName,
    String? trainerName,
  }) => db.completeSession(sessionId, notes);

  @override
  Future<Map<String, dynamic>?> getSessionDetails(int sessionId) async {
    final sList = await db.select(db.sessions).get();
    final match = sList.where((s) => s.id == sessionId);
    if (match.isEmpty) return null;
    final s = match.first;
    return {
      'id': s.id,
      'sessionNumber': s.sessionNumber,
      'scheduledTime': s.scheduledAt,
      'completedAt': s.completedAt,
      'status': s.status,
      'notes': s.notes,
    };
  }

  @override
  Future<int> saveWorkout({
    required int clientId,
    required int packageId,
    int? sessionId,
    required String notes,
    required List<ExerciseDraft> exercises,
  }) => db.saveWorkout(
    clientId: clientId,
    packageId: packageId,
    sessionId: sessionId,
    notes: notes,
    exercises: exercises,
  );

  @override
  Future<void> updateWorkout({
    required int logId,
    required String notes,
    int? sessionId,
    required List<ExerciseDraft> exercises,
  }) => db.updateWorkout(
    logId: logId,
    notes: notes,
    sessionId: sessionId,
    exercises: exercises,
  );

  @override
  Future<bool> deleteWorkout(int logId) => db.deleteWorkout(logId);

  @override
  Future<bool> deleteWorkoutExercise(int exerciseId) =>
      db.deleteWorkoutExercise(exerciseId);

  @override
  Future<bool> deleteWorkoutSet(int setId) => db.deleteWorkoutSet(setId);

  @override
  Future<List<WorkoutLog>> logsForClient(int clientId) =>
      db.logsForClient(clientId);

  @override
  Future<List<WorkoutExercise>> exercisesForLog(int logId) =>
      db.exercisesForLog(logId);

  @override
  Future<List<WorkoutSet>> setsForExercise(int exerciseId) =>
      db.setsForExercise(exerciseId);

  @override
  Future<WorkoutLog?> getWorkoutLog(int logId) => db.getWorkoutLog(logId);

  @override
  Future<PostPtEvaluation?> getEvaluationForPackage(int packageId) =>
      (db.select(
        db.postPtEvaluations,
      )..where((e) => e.packageId.equals(packageId))).getSingleOrNull();

  @override
  Future<void> finalizePackage(
    int packageId,
    PostPtEvaluationsCompanion eval,
  ) => db.finalizePackage(packageId, eval);

  @override
  Future<List<PtPackage>> allPackagesForTrainer(int trainerId) =>
      db.select(db.ptPackages).get();

  @override
  Future<List<Session>> allSessionsForTrainer(int trainerId) =>
      db.select(db.sessions).get();

  @override
  Future<void> closePackage(int packageId) async {
    await (db.update(
      db.ptPackages,
    )..where((p) => p.id.equals(packageId))).write(
      PtPackagesCompanion(
        status: const Value('closed'),
        closedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> cancelPackage(int packageId, {String? reason}) async {
    await (db.update(
      db.ptPackages,
    )..where((p) => p.id.equals(packageId))).write(
      PtPackagesCompanion(
        status: const Value('cancelled'),
        closedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<List<ExerciseCatalogData>> get exerciseCatalog =>
      db.select(db.exerciseCatalog).get();

  final List<PackageSaleRecord> _packageSales = [];

  @override
  Future<PackageSaleRecord> recordPackageSale(PackageSaleRecord sale) async {
    final id = sale.id.isNotEmpty
        ? sale.id
        : 'sale_${DateTime.now().millisecondsSinceEpoch}_${_packageSales.length + 1}';
    final record = sale.copyWith(id: id);
    _packageSales.removeWhere((s) => s.id == id);
    _packageSales.add(record);
    return record;
  }

  @override
  Future<List<PackageSaleRecord>> getPackageSales({
    String? trainerId,
    int? year,
    int? quarter,
    String? status,
  }) async {
    var list = List<PackageSaleRecord>.from(_packageSales);
    if (trainerId != null) {
      list = list.where((s) => s.trainerId == trainerId).toList();
    }
    if (status != null) {
      list = list
          .where((s) => s.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (year != null) {
      list = list.where((s) => s.timestamp.year == year).toList();
    }
    if (quarter != null) {
      list = list
          .where((s) => ((s.timestamp.month - 1) ~/ 3) + 1 == quarter)
          .toList();
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords({
    int? trainerId,
    int? clientId,
    int? packageId,
    String? status,
  }) async {
    final sessions = await db.select(db.sessions).get();
    final packages = await db.select(db.ptPackages).get();
    final clients = await db.select(db.clients).get();
    final trainers = await db.select(db.trainers).get();

    final packageMap = {for (final p in packages) p.id: p};
    final clientMap = {for (final c in clients) c.id: c};
    final trainerMap = {for (final t in trainers) t.id: t};

    final List<AttendanceRecord> records = [];
    for (final s in sessions) {
      final pkg = packageMap[s.packageId];
      final client = pkg != null ? clientMap[pkg.clientId] : null;
      final trainer = client != null ? trainerMap[client.trainerId] : null;

      final rec = AttendanceRecord(
        id: s.id,
        packageId: s.packageId,
        clientId: client?.id ?? 0,
        clientName: client?.name ?? '',
        trainerId: client?.trainerId ?? 0,
        trainerName: trainer?.name ?? '',
        sessionNumber: s.sessionNumber,
        date: s.completedAt ?? s.scheduledAt,
        status: s.status,
        notes: s.notes,
      );
      records.add(rec);
    }

    var result = records;
    if (clientId != null) {
      result = result.where((r) => r.clientId == clientId).toList();
    }
    if (trainerId != null) {
      result = result.where((r) => r.trainerId == trainerId).toList();
    }
    if (packageId != null) {
      result = result.where((r) => r.packageId == packageId).toList();
    }
    if (status != null) {
      result = result
          .where((r) => r.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<bool> updateAttendanceRecord(AttendanceRecord record) async {
    final count =
        await (db.update(
          db.sessions,
        )..where((s) => s.id.equals(record.id))).write(
          SessionsCompanion(
            scheduledAt: Value(record.date),
            status: Value(record.status),
            notes: Value(record.notes),
            completedAt: record.status == 'completed'
                ? Value(record.date)
                : const Value.absent(),
          ),
        );
    return count > 0;
  }

  @override
  Future<bool> cancelAttendanceRecord(
    int id, {
    String? cancelledBy,
    String? cancelReason,
  }) async {
    return cancelSession(
      id,
      cancelledBy: cancelledBy,
      cancelReason: cancelReason,
    );
  }
}

/// Firestore Operational Repository: Primary cloud data store
class FirestoreGymRepository implements GymRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  // In-memory mapping between UI int IDs and Firestore String doc IDs
  final Map<int, String> _clientDocIdByInt = {};
  final Map<int, String> _pkgDocIdByInt = {};
  final Map<int, String> _sessionDocIdByInt = {};
  final Map<int, String> _workoutDocIdByInt = {};
  final Map<int, String> _clientStringIdByPkgInt = {};
  final Map<int, String> _clientStringIdBySessionInt = {};
  final Map<int, String> _clientStringIdByWorkoutInt = {};
  final Map<int, List<WorkoutSet>> _cachedSetsByExerciseId = {};

  FirestoreGymRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : firestore = firestore ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  String? get currentUid => auth.currentUser?.uid;

  int _deriveIntId(String strId, {int? existing}) {
    if (existing != null && existing > 0) return existing;
    return (strId.hashCode.abs() % 900000) + 100000;
  }

  @override
  Future<List<Client>> allClients(int trainerId) async {
    final uid = currentUid;
    if (uid == null) return [];

    final querySnap = await firestore
        .collection('clients')
        .where('assignedTrainerIds', arrayContains: uid)
        .get();

    final List<Client> result = [];
    for (final doc in querySnap.docs) {
      final data = doc.data();
      final intId = _deriveIntId(
        doc.id,
        existing: (data['id'] as num?)?.toInt(),
      );
      _clientDocIdByInt[intId] = doc.id;

      result.add(
        Client(
          id: intId,
          trainerId: trainerId,
          name: data['name'] as String? ?? 'Klien',
          age: (data['age'] as num?)?.toInt() ?? 25,
          contact: data['contact'] as String? ?? '',
          heightCm: (data['heightCm'] as num?)?.toDouble(),
          initialWeightKg: (data['initialWeightKg'] as num?)?.toDouble(),
          goal: data['goal'] as String? ?? '',
          medicalHistory: data['medicalHistory'] as String? ?? '',
          injuryHistory: data['injuryHistory'] as String? ?? '',
          assessmentNotes: data['assessmentNotes'] as String? ?? '',
        ),
      );
    }
    return result;
  }

  @override
  Future<Client?> getClient(int clientId) async {
    var docId = _clientDocIdByInt[clientId];
    DocumentSnapshot<Map<String, dynamic>>? snap;

    if (docId != null) {
      snap = await firestore.collection('clients').doc(docId).get();
    } else {
      final q = await firestore
          .collection('clients')
          .where('id', isEqualTo: clientId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        snap = q.docs.first;
        docId = snap.id;
        _clientDocIdByInt[clientId] = docId;
      }
    }

    if (snap == null || !snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    return Client(
      id: clientId,
      trainerId: (data['trainerIntId'] as num?)?.toInt() ?? 1,
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      contact: data['contact'] as String? ?? '',
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      initialWeightKg: (data['initialWeightKg'] as num?)?.toDouble(),
      goal: data['goal'] as String? ?? '',
      medicalHistory: data['medicalHistory'] as String? ?? '',
      injuryHistory: data['injuryHistory'] as String? ?? '',
      assessmentNotes: data['assessmentNotes'] as String? ?? '',
    );
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
    final uid = currentUid;
    if (uid == null) throw StateError('User unauthenticated');

    final clientRef = firestore.collection('clients').doc();
    final clientIntId =
        (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
    _clientDocIdByInt[clientIntId] = clientRef.id;

    await clientRef.set({
      'id': clientIntId,
      'clientId': clientRef.id,
      'assignedTrainerIds': [uid],
      'creatorTrainerId': uid,
      'trainerIntId': trainerId,
      'name': name,
      'age': age,
      'contact': contact,
      'heightCm': height,
      'initialWeightKg': weight,
      'goal': goal,
      'medicalHistory': medical,
      'injuryHistory': injury,
      'assessmentNotes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create initial package in subcollection
    final pkgRef = clientRef.collection('packages').doc();
    final pkgIntId = clientIntId + 1;
    _pkgDocIdByInt[pkgIntId] = pkgRef.id;
    _clientStringIdByPkgInt[pkgIntId] = clientRef.id;

    await pkgRef.set({
      'id': pkgIntId,
      'packageId': pkgRef.id,
      'clientIntId': clientIntId,
      'clientId': clientRef.id,
      'trainerId': uid,
      'totalSessions': sessionsCount,
      'completedCount': 0,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return clientIntId;
  }

  @override
  Future<void> updateClient(Client client) async {
    final docId = _clientDocIdByInt[client.id];
    if (docId == null) {
      final q = await firestore
          .collection('clients')
          .where('id', isEqualTo: client.id)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        await q.docs.first.reference.update({
          'name': client.name,
          'age': client.age,
          'contact': client.contact,
          'heightCm': client.heightCm,
          'initialWeightKg': client.initialWeightKg,
          'goal': client.goal,
          'medicalHistory': client.medicalHistory,
          'injuryHistory': client.injuryHistory,
          'assessmentNotes': client.assessmentNotes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    await firestore.collection('clients').doc(docId).update({
      'name': client.name,
      'age': client.age,
      'contact': client.contact,
      'heightCm': client.heightCm,
      'initialWeightKg': client.initialWeightKg,
      'goal': client.goal,
      'medicalHistory': client.medicalHistory,
      'injuryHistory': client.injuryHistory,
      'assessmentNotes': client.assessmentNotes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> deleteClient(int clientId) async {
    final docId =
        _clientDocIdByInt[clientId] ?? await _findClientDocId(clientId);
    if (docId != null) {
      final pkg = await currentPackage(clientId);
      if (pkg != null) {
        await closePackage(pkg.id);
      }
      await firestore.collection('clients').doc(docId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
    return false;
  }

  @override
  Future<PtPackage?> currentPackage(int clientId) async {
    final clientDocId =
        _clientDocIdByInt[clientId] ?? await _findClientDocId(clientId);
    if (clientDocId == null) return null;

    final q = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('packages')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    final data = doc.data();
    final pkgIntId = _deriveIntId(
      doc.id,
      existing: (data['id'] as num?)?.toInt(),
    );
    _pkgDocIdByInt[pkgIntId] = doc.id;
    _clientStringIdByPkgInt[pkgIntId] = clientDocId;

    return PtPackage(
      id: pkgIntId,
      clientId: clientId,
      totalSessions: (data['totalSessions'] as num?)?.toInt() ?? 12,
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<PtPackage?> latestPackage(int clientId) async {
    final clientDocId =
        _clientDocIdByInt[clientId] ?? await _findClientDocId(clientId);
    if (clientDocId == null) return null;

    final q = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('packages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    final data = doc.data();
    final pkgIntId = _deriveIntId(
      doc.id,
      existing: (data['id'] as num?)?.toInt(),
    );
    _pkgDocIdByInt[pkgIntId] = doc.id;
    _clientStringIdByPkgInt[pkgIntId] = clientDocId;

    return PtPackage(
      id: pkgIntId,
      clientId: clientId,
      totalSessions: (data['totalSessions'] as num?)?.toInt() ?? 12,
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<String> getClientLifecycleStatus(int clientId) async {
    final clientDocId =
        _clientDocIdByInt[clientId] ?? await _findClientDocId(clientId);
    if (clientDocId == null) return 'unknown';

    final clientSnap =
        await firestore.collection('clients').doc(clientDocId).get();
    if (!clientSnap.exists || clientSnap.data() == null) return 'unknown';
    final clientData = clientSnap.data()!;
    final clientDocStatus = clientData['status'] as String? ?? 'active';
    if (clientDocStatus == 'inactive') return 'inactive';
    if (clientDocStatus == 'cancelled') return 'cancelled';

    final pkg = await latestPackage(clientId);
    if (pkg == null) return 'no_package';
    if (pkg.status == 'cancelled') return 'cancelled';
    if (pkg.status == 'inactive') return 'inactive';

    final sList = await packageSessions(pkg.id);
    final completed = sList.where((s) => s.status == 'completed').length;
    if (pkg.status == 'closed') {
      if (completed < pkg.totalSessions) {
        return 'discontinued';
      }
      return 'completed';
    }

    if (completed >= pkg.totalSessions) {
      return 'completed';
    }
    return 'active';
  }

  Future<String?> _findClientDocId(int clientIntId) async {
    final q = await firestore
        .collection('clients')
        .where('id', isEqualTo: clientIntId)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final id = q.docs.first.id;
      _clientDocIdByInt[clientIntId] = id;
      return id;
    }
    return null;
  }

  Future<({String clientDocId, String packageDocId})?> _resolvePackage(
    int packageIntId,
  ) async {
    final cachedClient = _clientStringIdByPkgInt[packageIntId];
    final cachedPackage = _pkgDocIdByInt[packageIntId];
    if (cachedClient != null && cachedPackage != null) {
      return (clientDocId: cachedClient, packageDocId: cachedPackage);
    }

    final clients = await firestore
        .collection('clients')
        .where('assignedTrainerIds', arrayContains: currentUid)
        .get();
    for (final client in clients.docs) {
      final packages = await client.reference
          .collection('packages')
          .where('id', isEqualTo: packageIntId)
          .limit(1)
          .get();
      if (packages.docs.isEmpty) continue;
      final packageDocId = packages.docs.first.id;
      _pkgDocIdByInt[packageIntId] = packageDocId;
      _clientStringIdByPkgInt[packageIntId] = client.id;
      return (clientDocId: client.id, packageDocId: packageDocId);
    }
    return null;
  }

  Future<({String clientDocId, String sessionDocId})?> _resolveSession(
    int sessionIntId,
  ) async {
    final cachedClient = _clientStringIdBySessionInt[sessionIntId];
    final cachedSession = _sessionDocIdByInt[sessionIntId];
    if (cachedClient != null && cachedSession != null) {
      return (clientDocId: cachedClient, sessionDocId: cachedSession);
    }

    final clients = await firestore
        .collection('clients')
        .where('assignedTrainerIds', arrayContains: currentUid)
        .get();
    for (final client in clients.docs) {
      final sessions = await client.reference
          .collection('sessions')
          .where('id', isEqualTo: sessionIntId)
          .limit(1)
          .get();
      if (sessions.docs.isEmpty) continue;
      final sessionDocId = sessions.docs.first.id;
      _sessionDocIdByInt[sessionIntId] = sessionDocId;
      _clientStringIdBySessionInt[sessionIntId] = client.id;
      return (clientDocId: client.id, sessionDocId: sessionDocId);
    }
    return null;
  }

  Future<({String clientDocId, String workoutDocId})?> _resolveWorkout(
    int workoutIntId,
  ) async {
    final cachedClient = _clientStringIdByWorkoutInt[workoutIntId];
    final cachedWorkout = _workoutDocIdByInt[workoutIntId];
    if (cachedClient != null && cachedWorkout != null) {
      return (clientDocId: cachedClient, workoutDocId: cachedWorkout);
    }

    final uid = currentUid;
    final clientsQuery = uid != null
        ? await firestore
            .collection('clients')
            .where('assignedTrainerIds', arrayContains: uid)
            .get()
        : await firestore.collection('clients').get();

    for (final client in clientsQuery.docs) {
      final workouts = await client.reference
          .collection('workouts')
          .where('id', isEqualTo: workoutIntId)
          .limit(1)
          .get();
      if (workouts.docs.isEmpty) continue;
      final workoutDocId = workouts.docs.first.id;
      _workoutDocIdByInt[workoutIntId] = workoutDocId;
      _clientStringIdByWorkoutInt[workoutIntId] = client.id;
      return (clientDocId: client.id, workoutDocId: workoutDocId);
    }
    return null;
  }

  @override
  Future<List<Session>> packageSessions(int packageId) async {
    final resolved = await _resolvePackage(packageId);
    if (resolved == null) return [];
    final clientDocId = resolved.clientDocId;

    var q = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('sessions')
        .where('packageIntId', isEqualTo: packageId)
        .get();

    if (q.docs.isEmpty) {
      try {
        final qFallback = await firestore
            .collection('clients')
            .doc(clientDocId)
            .collection('sessions')
            .where('packageDocId', isEqualTo: resolved.packageDocId)
            .get();
        if (qFallback.docs.isNotEmpty) {
          q = qFallback;
        }
      } catch (_) {}
    }

    final List<Session> list = [];
    for (final doc in q.docs) {
      final data = doc.data();
      final sessionIntId = _deriveIntId(
        doc.id,
        existing: (data['id'] as num?)?.toInt(),
      );
      _sessionDocIdByInt[sessionIntId] = doc.id;
      _clientStringIdBySessionInt[sessionIntId] = clientDocId;

      list.add(
        Session(
          id: sessionIntId,
          packageId: packageId,
          sessionNumber: (data['sessionNumber'] as num?)?.toInt() ?? 1,
          scheduledAt:
              (data['scheduledTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
          status: data['status'] as String? ?? 'scheduled',
          notes: data['notes'] as String? ?? '',
        ),
      );
    }
    list.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
    return list;
  }

  @override
  Future<int> completedCount(int packageId) async {
    final resolved = await _resolvePackage(packageId);
    if (resolved == null) return 0;
    final clientDocId = resolved.clientDocId;

    final q = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('sessions')
        .where('packageIntId', isEqualTo: packageId)
        .where('status', isEqualTo: 'completed')
        .get();

    int count = q.docs.length;

    if (count == 0) {
      try {
        final qFallback = await firestore
            .collection('clients')
            .doc(clientDocId)
            .collection('sessions')
            .where('packageDocId', isEqualTo: resolved.packageDocId)
            .where('status', isEqualTo: 'completed')
            .get();
        if (qFallback.docs.isNotEmpty) {
          count = qFallback.docs.length;
        }
      } catch (_) {}
    }

    // Safety fallback: if session collection is partially synced, check package completedCount
    try {
      final pkgSnap = await firestore
          .collection('clients')
          .doc(clientDocId)
          .collection('packages')
          .doc(resolved.packageDocId)
          .get();
      if (pkgSnap.exists && pkgSnap.data() != null) {
        final recordedCount =
            (pkgSnap.data()!['completedCount'] as num?)?.toInt() ?? 0;
        if (recordedCount > count) {
          count = recordedCount;
        }
      }
    } catch (_) {}

    return count;
  }

  @override
  Future<int> schedule(int packageId, DateTime time) async {
    final resolved = await _resolvePackage(packageId);
    if (resolved == null) throw StateError('Package not resolved');
    final clientDocId = resolved.clientDocId;
    final packageRef = firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('packages')
        .doc(resolved.packageDocId);
    final packageSnap = await packageRef.get();
    final packageData = packageSnap.data();
    if (!packageSnap.exists ||
        packageData == null ||
        packageData['status'] != 'active') {
      throw StateError('Package is not active');
    }

    // Get current session count to number next session.
    final existing = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('sessions')
        .where('packageIntId', isEqualTo: packageId)
        .get();

    final sessionNumber = existing.docs.length + 1;
    final sessionRef = firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('sessions')
        .doc();

    final sessionIntId =
        (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
    _sessionDocIdByInt[sessionIntId] = sessionRef.id;
    _clientStringIdBySessionInt[sessionIntId] = clientDocId;

    await firestore.runTransaction((tx) async {
      final snap = await tx.get(packageRef);
      final data = snap.data();
      if (!snap.exists || data == null || data['status'] != 'active') {
        throw StateError('Package is not active');
      }
      tx.set(sessionRef, {
        'id': sessionIntId,
        'sessionId': sessionRef.id,
        'packageIntId': packageId,
        'packageDocId': resolved.packageDocId,
        'sessionNumber': sessionNumber,
        'scheduledTime': Timestamp.fromDate(time),
        'status': 'scheduled',
        'notes': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return sessionIntId;
  }

  @override
  Future<bool> cancelSession(
    int sessionId, {
    String? cancelledBy,
    String? cancelReason,
  }) async {
    final resolved = await _resolveSession(sessionId);
    if (resolved == null) return false;
    final ref = firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('sessions')
        .doc(resolved.sessionDocId);
    return firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null || data['status'] != 'scheduled') {
        return false;
      }
      tx.update(ref, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': cancelledBy ?? currentUid ?? 'system',
        'cancelReason': cancelReason ?? 'Dibatalkan oleh pelatih',
      });
      return true;
    });
  }

  @override
  Future<bool> rescheduleSession(
    int sessionId,
    DateTime time, {
    String? rescheduledBy,
    String? reason,
    String? notes,
  }) async {
    final resolved = await _resolveSession(sessionId);
    if (resolved == null) return false;
    final ref = firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('sessions')
        .doc(resolved.sessionDocId);

    return firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null || data['status'] != 'scheduled') {
        return false;
      }
      final updateData = <String, dynamic>{
        'scheduledTime': Timestamp.fromDate(time),
        'rescheduledAt': FieldValue.serverTimestamp(),
        'rescheduledBy': rescheduledBy ?? currentUid ?? 'system',
        'rescheduleReason': reason ?? 'Dijadwalkan ulang oleh pelatih',
      };
      if (notes != null) {
        updateData['notes'] = notes;
      }
      tx.update(ref, updateData);
      return true;
    });
  }

  @override
  Future<PtPackage> renewPackage(int clientId, int sessionsCount) async {
    final clientDocId =
        _clientDocIdByInt[clientId] ?? await _findClientDocId(clientId);
    if (clientDocId == null) throw StateError('Client doc not found');

    // Archive current package
    final currentQ = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('packages')
        .where('status', isEqualTo: 'active')
        .get();

    for (final doc in currentQ.docs) {
      await doc.reference.update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
    }

    // Ensure client document itself is active
    await firestore.collection('clients').doc(clientDocId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create new package
    final newPkgRef = firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('packages')
        .doc();

    final newPkgIntId =
        (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
    _pkgDocIdByInt[newPkgIntId] = newPkgRef.id;
    _clientStringIdByPkgInt[newPkgIntId] = clientDocId;

    await newPkgRef.set({
      'id': newPkgIntId,
      'packageId': newPkgRef.id,
      'clientIntId': clientId,
      'totalSessions': sessionsCount,
      'completedCount': 0,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return PtPackage(
      id: newPkgIntId,
      clientId: clientId,
      totalSessions: sessionsCount,
      status: 'active',
      createdAt: DateTime.now(),
      closedAt: null,
    );
  }

  void _logSafeFirebaseException(String operation, Object error) {
    if (error is FirebaseException) {
      // Log sanitized diagnostics; never emit private payload (strokes, medical notes, client details)
      // ignore: avoid_print
      print(
        '[FirestoreSafeLog] $operation failed: plugin=${error.plugin}, code=${error.code}, message=${error.message}',
      );
    } else {
      // ignore: avoid_print
      print('[FirestoreSafeLog] $operation failed: ${error.runtimeType}');
    }
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
    final resolved = await _resolveSession(sessionId);
    if (resolved == null) return false;
    final clientDocId = resolved.clientDocId;
    final sessionDocId = resolved.sessionDocId;

    final sessionDocRef = firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('sessions')
        .doc(sessionDocId);

    // Initial check outside transaction
    final initial = await sessionDocRef.get();
    final initialData = initial.data();
    if (initialData == null) return false;

    // Idempotent completion: prevent double deduction if already completed
    final currentStatus = initialData['status'] as String? ?? 'scheduled';
    if (currentStatus != 'scheduled') {
      return false;
    }

    final legacyPackageId = (initialData['packageIntId'] as num?)?.toInt();
    final resolvedPackage = legacyPackageId == null
        ? null
        : await _resolvePackage(legacyPackageId);

    // Firestore-compatible validated signature structure:
    // Format: Array of maps with points: [{points: [{x, y}]}]
    // Absolutely NO nested arrays (unsupported by Firestore).
    final clientStrokesJson = clientStrokes == null
        ? <Map<String, dynamic>>[]
        : clientStrokes
            .where((stroke) => stroke.isNotEmpty)
            .map(
              (stroke) => <String, dynamic>{
                'points': stroke
                    .where((p) => p.dx.isFinite && p.dy.isFinite)
                    .map((p) => <String, dynamic>{'x': p.dx, 'y': p.dy})
                    .toList(),
              },
            )
            .where((m) => (m['points'] as List).isNotEmpty)
            .toList();

    final coachStrokesJson = coachStrokes == null
        ? <Map<String, dynamic>>[]
        : coachStrokes
            .where((stroke) => stroke.isNotEmpty)
            .map(
              (stroke) => <String, dynamic>{
                'points': stroke
                    .where((p) => p.dx.isFinite && p.dy.isFinite)
                    .map((p) => <String, dynamic>{'x': p.dx, 'y': p.dy})
                    .toList(),
              },
            )
            .where((m) => (m['points'] as List).isNotEmpty)
            .toList();

    try {
      return await firestore.runTransaction<bool>((tx) async {
        final sessionSnap = await tx.get(sessionDocRef);
        if (!sessionSnap.exists || sessionSnap.data() == null) return false;

        final data = sessionSnap.data()!;
        final txStatus = data['status'] as String? ?? 'scheduled';
        if (txStatus != 'scheduled') {
          return false;
        }

        final packageIntId = (data['packageIntId'] as num?)?.toInt();
        final packageDocId =
            data['packageDocId'] as String? ??
            (packageIntId == null ? null : resolvedPackage?.packageDocId);
        if (packageDocId == null) return false;

        final pkgDocRef = firestore
            .collection('clients')
            .doc(clientDocId)
            .collection('packages')
            .doc(packageDocId);
        final pkgSnap = await tx.get(pkgDocRef);
        final pkgData = pkgSnap.data();
        if (!pkgSnap.exists ||
            pkgData == null ||
            pkgData['status'] != 'active') {
          return false;
        }
        final maxSessions = (pkgData['totalSessions'] as num?)?.toInt() ?? 0;
        final currentCompleted =
            (pkgData['completedCount'] as num?)?.toInt() ?? 0;
        if (currentCompleted >= maxSessions) return false;

        final newCompleted = currentCompleted + 1;
        final isLastSession = newCompleted >= maxSessions;

        tx.update(pkgDocRef, {
          'completedCount': newCompleted,
          'lastCompletedSessionId': sessionDocId,
          if (isLastSession) 'status': 'closed',
          if (isLastSession) 'closedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(sessionDocRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'notes': notes,
          'packageDocId': packageDocId,
          'clientSignatureStatus': 'verified',
          'coachSignatureStatus': 'verified',
          'clientSignatureStrokes': clientStrokesJson,
          'coachSignatureStrokes': coachStrokesJson,
          'clientName': ?clientName,
          'trainerName': ?trainerName,
        });

        return true;
      });
    } catch (e) {
      // Server reconciliation on uncertain failure (e.g. deadline exceeded or socket abort)
      try {
        final serverDoc = await sessionDocRef.get(
          const GetOptions(source: Source.server),
        );
        if (serverDoc.exists && serverDoc.data()?['status'] == 'completed') {
          return true;
        }
      } catch (_) {}

      _logSafeFirebaseException('completeSession', e);
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getSessionDetails(int sessionId) async {
    final resolved = await _resolveSession(sessionId);
    if (resolved == null) return null;
    final doc = await firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('sessions')
        .doc(resolved.sessionDocId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);

    dynamic unpackStrokes(dynamic raw) {
      if (raw is List) {
        return raw.map((item) {
          if (item is Map &&
              item.containsKey('points') &&
              item['points'] is List) {
            return item['points'];
          }
          return item;
        }).toList();
      }
      return raw;
    }

    if (data.containsKey('clientSignatureStrokes')) {
      data['clientSignatureStrokes'] = unpackStrokes(
        data['clientSignatureStrokes'],
      );
    }
    if (data.containsKey('coachSignatureStrokes')) {
      data['coachSignatureStrokes'] = unpackStrokes(
        data['coachSignatureStrokes'],
      );
    }

    return data;
  }

  @override
  Future<int> saveWorkout({
    required int clientId,
    required int packageId,
    int? sessionId,
    required String notes,
    required List<ExerciseDraft> exercises,
  }) async {
    final clientDocId =
        _clientDocIdByInt[clientId] ?? await _findClientDocId(clientId);
    if (clientDocId == null) throw StateError('Client doc not found');

    final workoutRef = firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('workouts')
        .doc();

    final logIntId = (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
    _workoutDocIdByInt[logIntId] = workoutRef.id;
    _clientStringIdByWorkoutInt[logIntId] = clientDocId;

    double totalVolume = 0.0;
    final List<Map<String, dynamic>> exercisesJson = [];

    int exCounter = 1;
    for (final ex in exercises) {
      final List<Map<String, dynamic>> setsJson = [];
      int setCounter = 1;
      for (final s in ex.sets) {
        final double weight = s.weightKg ?? 0.0;
        final int reps = s.reps;
        totalVolume += (weight * reps);
        setsJson.add({
          'id': (logIntId * 100) + (exCounter * 10) + setCounter,
          'setNumber': setCounter,
          'stage': s.stage,
          'reps': reps,
          'weightKg': weight,
        });
        setCounter++;
      }
      exercisesJson.add({
        'id': (logIntId * 10) + exCounter,
        'name': ex.name,
        'method': ex.method,
        'equipment': ex.equipment,
        'groupKey': ex.groupKey,
        'rpe': ex.rpe,
        'rir': ex.rir,
        'notes': ex.notes,
        'sets': setsJson,
      });
      exCounter++;
    }

    await workoutRef.set({
      'id': logIntId,
      'logId': workoutRef.id,
      'clientIntId': clientId,
      'packageIntId': packageId,
      'sessionIntId': sessionId,
      'performedAt': FieldValue.serverTimestamp(),
      'notes': notes,
      'totalVolume': totalVolume,
      'exercises': exercisesJson,
    });

    return logIntId;
  }

  @override
  Future<void> updateWorkout({
    required int logId,
    required String notes,
    int? sessionId,
    required List<ExerciseDraft> exercises,
  }) async {
    final resolved = await _resolveWorkout(logId);
    if (resolved == null) return;

    final workoutRef = firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('workouts')
        .doc(resolved.workoutDocId);

    double totalVolume = 0.0;
    final List<Map<String, dynamic>> exercisesJson = [];

    int exCounter = 1;
    for (final ex in exercises) {
      final List<Map<String, dynamic>> setsJson = [];
      int setCounter = 1;
      final List<WorkoutSet> setsCache = [];
      for (final s in ex.sets) {
        final double weight = s.weightKg ?? 0.0;
        final int reps = s.reps;
        totalVolume += (weight * reps);
        final setId = (logId * 100) + (exCounter * 10) + setCounter;
        setsJson.add({
          'id': setId,
          'setNumber': setCounter,
          'stage': s.stage,
          'reps': reps,
          'weightKg': weight,
        });
        setsCache.add(
          WorkoutSet(
            id: setId,
            exerciseId: ex.id ?? ((logId * 10) + exCounter),
            setNumber: setCounter,
            stage: s.stage,
            reps: reps,
            weightKg: weight,
          ),
        );
        setCounter++;
      }
      final exId = ex.id ?? ((logId * 10) + exCounter);
      _cachedSetsByExerciseId[exId] = setsCache;

      exercisesJson.add({
        'id': exId,
        'name': ex.name,
        'method': ex.method,
        'equipment': ex.equipment,
        'groupKey': ex.groupKey,
        'rpe': ex.rpe,
        'rir': ex.rir,
        'notes': ex.notes,
        'sets': setsJson,
      });
      exCounter++;
    }

    // In-place update preserving document identity without creating duplicate workout
    await workoutRef.update({
      'notes': notes,
      'sessionIntId': sessionId,
      'totalVolume': totalVolume,
      'exercises': exercisesJson,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> deleteWorkout(int logId) async {
    final resolved = await _resolveWorkout(logId);
    if (resolved == null) return false;

    await firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('workouts')
        .doc(resolved.workoutDocId)
        .delete();

    _workoutDocIdByInt.remove(logId);
    _clientStringIdByWorkoutInt.remove(logId);
    return true;
  }

  @override
  Future<bool> deleteWorkoutExercise(int exerciseId) async {
    _cachedSetsByExerciseId.remove(exerciseId);

    var entries = _clientStringIdByWorkoutInt.entries.toList();
    if (entries.isEmpty) {
      final uid = currentUid;
      final q = uid != null
          ? await firestore
              .collection('clients')
              .where('assignedTrainerIds', arrayContains: uid)
              .get()
          : await firestore.collection('clients').get();
      for (final cDoc in q.docs) {
        final wDocs = await cDoc.reference.collection('workouts').get();
        for (final wDoc in wDocs.docs) {
          final wId =
              (wDoc.data()['id'] as num?)?.toInt() ?? _deriveIntId(wDoc.id);
          _clientStringIdByWorkoutInt[wId] = cDoc.id;
          _workoutDocIdByInt[wId] = wDoc.id;
        }
      }
      entries = _clientStringIdByWorkoutInt.entries.toList();
    }

    for (final entry in entries) {
      final logIntId = entry.key;
      final clientDocId = entry.value;
      final workoutDocId = _workoutDocIdByInt[logIntId];
      if (workoutDocId == null) continue;

      final workoutRef = firestore
          .collection('clients')
          .doc(clientDocId)
          .collection('workouts')
          .doc(workoutDocId);

      final snap = await workoutRef.get();
      if (!snap.exists || snap.data() == null) continue;
      final exercises = List<Map<String, dynamic>>.from(
        snap.data()!['exercises'] ?? [],
      );
      final initialLen = exercises.length;
      exercises.removeWhere((e) => (e['id'] as num?)?.toInt() == exerciseId);

      if (exercises.length != initialLen) {
        double totalVolume = 0.0;
        for (final ex in exercises) {
          for (final s in (ex['sets'] as List? ?? [])) {
            final w = (s['weightKg'] as num?)?.toDouble() ?? 0.0;
            final r = (s['reps'] as num?)?.toInt() ?? 0;
            totalVolume += (w * r);
          }
        }
        await workoutRef.update({
          'exercises': exercises,
          'totalVolume': totalVolume,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> deleteWorkoutSet(int setId) async {
    var entries = _clientStringIdByWorkoutInt.entries.toList();
    if (entries.isEmpty) {
      final uid = currentUid;
      final q = uid != null
          ? await firestore
              .collection('clients')
              .where('assignedTrainerIds', arrayContains: uid)
              .get()
          : await firestore.collection('clients').get();
      for (final cDoc in q.docs) {
        final wDocs = await cDoc.reference.collection('workouts').get();
        for (final wDoc in wDocs.docs) {
          final wId =
              (wDoc.data()['id'] as num?)?.toInt() ?? _deriveIntId(wDoc.id);
          _clientStringIdByWorkoutInt[wId] = cDoc.id;
          _workoutDocIdByInt[wId] = wDoc.id;
        }
      }
      entries = _clientStringIdByWorkoutInt.entries.toList();
    }

    for (final entry in entries) {
      final logIntId = entry.key;
      final clientDocId = entry.value;
      final workoutDocId = _workoutDocIdByInt[logIntId];
      if (workoutDocId == null) continue;

      final workoutRef = firestore
          .collection('clients')
          .doc(clientDocId)
          .collection('workouts')
          .doc(workoutDocId);

      final snap = await workoutRef.get();
      if (!snap.exists || snap.data() == null) continue;
      final exercises = List<Map<String, dynamic>>.from(
        snap.data()!['exercises'] ?? [],
      );

      bool modified = false;
      for (final ex in exercises) {
        final sets = List<Map<String, dynamic>>.from(ex['sets'] ?? []);
        final initialSetsLen = sets.length;
        sets.removeWhere((s) => (s['id'] as num?)?.toInt() == setId);
        if (sets.length != initialSetsLen) {
          ex['sets'] = sets;
          modified = true;
          final exId = (ex['id'] as num?)?.toInt();
          if (exId != null) {
            _cachedSetsByExerciseId.remove(exId);
          }
        }
      }

      if (modified) {
        double totalVolume = 0.0;
        for (final ex in exercises) {
          for (final s in (ex['sets'] as List? ?? [])) {
            final w = (s['weightKg'] as num?)?.toDouble() ?? 0.0;
            final r = (s['reps'] as num?)?.toInt() ?? 0;
            totalVolume += (w * r);
          }
        }
        await workoutRef.update({
          'exercises': exercises,
          'totalVolume': totalVolume,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<WorkoutLog>> logsForClient(int clientId) async {
    final clientDocId =
        _clientDocIdByInt[clientId] ?? await _findClientDocId(clientId);
    if (clientDocId == null) return [];

    final q = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('workouts')
        .get();

    final List<WorkoutLog> list = [];
    for (final doc in q.docs) {
      final data = doc.data();
      final logIntId = _deriveIntId(
        doc.id,
        existing: (data['id'] as num?)?.toInt(),
      );
      _workoutDocIdByInt[logIntId] = doc.id;
      _clientStringIdByWorkoutInt[logIntId] = clientDocId;

      list.add(
        WorkoutLog(
          id: logIntId,
          clientId: clientId,
          packageId: (data['packageIntId'] as num?)?.toInt() ?? 1,
          sessionId: (data['sessionIntId'] as num?)?.toInt(),
          performedAt:
              (data['performedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          notes: data['notes'] as String? ?? '',
        ),
      );
    }
    list.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return list;
  }

  @override
  Future<List<WorkoutExercise>> exercisesForLog(int logId) async {
    final resolved = await _resolveWorkout(logId);
    if (resolved == null) return [];

    final snap = await firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('workouts')
        .doc(resolved.workoutDocId)
        .get();

    if (!snap.exists || snap.data() == null) return [];
    final rawExercises = snap.data()!['exercises'] as List? ?? [];

    final List<WorkoutExercise> result = [];
    for (final item in rawExercises) {
      final exId = (item['id'] as num?)?.toInt() ?? 1;
      final rawSets = item['sets'] as List? ?? [];
      final List<WorkoutSet> sets = [];
      for (final s in rawSets) {
        sets.add(
          WorkoutSet(
            id: (s['id'] as num?)?.toInt() ?? 1,
            exerciseId: exId,
            setNumber: (s['setNumber'] as num?)?.toInt() ?? 1,
            stage: (s['stage'] as num?)?.toInt() ?? 1,
            reps: (s['reps'] as num?)?.toInt() ?? 10,
            weightKg: (s['weightKg'] as num?)?.toDouble(),
          ),
        );
      }
      _cachedSetsByExerciseId[exId] = sets;

      result.add(
        WorkoutExercise(
          id: exId,
          logId: logId,
          catalogId: (item['catalogId'] as num?)?.toInt(),
          name: item['name'] as String? ?? 'Exercise',
          equipment: item['equipment'] as String? ?? '',
          method: item['method'] as String? ?? 'Straight Set',
          groupKey: item['groupKey'] as String?,
          rpe: (item['rpe'] as num?)?.toDouble(),
          rir: (item['rir'] as num?)?.toInt(),
          notes: item['notes'] as String? ?? '',
        ),
      );
    }
    return result;
  }

  @override
  Future<List<WorkoutSet>> setsForExercise(int exerciseId) async {
    if (_cachedSetsByExerciseId.containsKey(exerciseId)) {
      return _cachedSetsByExerciseId[exerciseId]!;
    }

    for (final entry in _clientStringIdByWorkoutInt.entries) {
      final logIntId = entry.key;
      final clientDocId = entry.value;
      final workoutDocId = _workoutDocIdByInt[logIntId];
      if (workoutDocId == null) continue;

      final snap = await firestore
          .collection('clients')
          .doc(clientDocId)
          .collection('workouts')
          .doc(workoutDocId)
          .get();

      if (!snap.exists || snap.data() == null) continue;
      final rawExercises = snap.data()!['exercises'] as List? ?? [];
      for (final ex in rawExercises) {
        final exId = (ex['id'] as num?)?.toInt();
        final rawSets = ex['sets'] as List? ?? [];
        final List<WorkoutSet> sets = [];
        for (final s in rawSets) {
          sets.add(
            WorkoutSet(
              id: (s['id'] as num?)?.toInt() ?? 1,
              exerciseId: exId ?? exerciseId,
              setNumber: (s['setNumber'] as num?)?.toInt() ?? 1,
              stage: (s['stage'] as num?)?.toInt() ?? 1,
              reps: (s['reps'] as num?)?.toInt() ?? 10,
              weightKg: (s['weightKg'] as num?)?.toDouble(),
            ),
          );
        }
        if (exId != null) {
          _cachedSetsByExerciseId[exId] = sets;
        }
        if (exId == exerciseId) {
          return sets;
        }
      }
    }
    return [];
  }

  @override
  Future<WorkoutLog?> getWorkoutLog(int logId) async {
    final resolved = await _resolveWorkout(logId);
    if (resolved == null) return null;

    final snap = await firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('workouts')
        .doc(resolved.workoutDocId)
        .get();

    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    return WorkoutLog(
      id: logId,
      clientId: (data['clientIntId'] as num?)?.toInt() ?? 1,
      packageId: (data['packageIntId'] as num?)?.toInt() ?? 1,
      sessionId: (data['sessionIntId'] as num?)?.toInt(),
      performedAt:
          (data['performedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] as String? ?? '',
    );
  }

  @override
  Future<PostPtEvaluation?> getEvaluationForPackage(int packageId) async {
    final clientDocId = _clientStringIdByPkgInt[packageId];
    if (clientDocId == null) return null;

    final q = await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('evaluations')
        .where('packageIntId', isEqualTo: packageId)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    final data = doc.data();

    return PostPtEvaluation(
      id: (data['id'] as num?)?.toInt() ?? 1,
      packageId: packageId,
      finalWeightKg: (data['finalWeightKg'] as num?)?.toDouble(),
      bodyFatStart: (data['bodyFatStart'] as num?)?.toDouble(),
      bodyFatEnd: (data['bodyFatEnd'] as num?)?.toDouble(),
      muscleStart: (data['muscleStart'] as num?)?.toDouble(),
      muscleEnd: (data['muscleEnd'] as num?)?.toDouble(),
      armRight: (data['armRight'] as num?)?.toDouble(),
      armLeft: (data['armLeft'] as num?)?.toDouble(),
      thighRight: (data['thighRight'] as num?)?.toDouble(),
      thighLeft: (data['thighLeft'] as num?)?.toDouble(),
      achievement: data['achievement'] as String? ?? '',
      evaluation: data['evaluation'] as String? ?? '',
      recommendation: data['recommendation'] as String? ?? '',
      conclusion: data['conclusion'] as String? ?? '',
      finalizedAt:
          (data['finalizedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<void> finalizePackage(
    int packageId,
    PostPtEvaluationsCompanion eval,
  ) async {
    final clientDocId = _clientStringIdByPkgInt[packageId];
    final pkgDocId = _pkgDocIdByInt[packageId];
    if (clientDocId == null || pkgDocId == null) return;

    final evalRef = firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('evaluations')
        .doc();

    await evalRef.set({
      'id': (DateTime.now().millisecondsSinceEpoch % 900000) + 100000,
      'evalId': evalRef.id,
      'packageIntId': packageId,
      'finalWeightKg': eval.finalWeightKg.value,
      'bodyFatStart': eval.bodyFatStart.value,
      'bodyFatEnd': eval.bodyFatEnd.value,
      'muscleStart': eval.muscleStart.value,
      'muscleEnd': eval.muscleEnd.value,
      'armRight': eval.armRight.value,
      'armLeft': eval.armLeft.value,
      'thighRight': eval.thighRight.value,
      'thighLeft': eval.thighLeft.value,
      'achievement': eval.achievement.value,
      'evaluation': eval.evaluation.value,
      'recommendation': eval.recommendation.value,
      'conclusion': eval.conclusion.value,
      'finalizedAt': FieldValue.serverTimestamp(),
    });

    await firestore
        .collection('clients')
        .doc(clientDocId)
        .collection('packages')
        .doc(pkgDocId)
        .update({'status': 'closed', 'closedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<List<PtPackage>> allPackagesForTrainer(int trainerId) async {
    final clients = await allClients(trainerId);
    final List<PtPackage> result = [];
    for (final c in clients) {
      final pkg = await currentPackage(c.id);
      if (pkg != null) result.add(pkg);
    }
    return result;
  }

  @override
  Future<List<Session>> allSessionsForTrainer(int trainerId) async {
    final clients = await allClients(trainerId);
    final List<Session> result = [];
    for (final c in clients) {
      final pkg = await currentPackage(c.id);
      if (pkg != null) {
        final sessions = await packageSessions(pkg.id);
        result.addAll(sessions);
      }
    }
    return result;
  }

  @override
  Future<void> closePackage(int packageId) async {
    final resolved = await _resolvePackage(packageId);
    if (resolved == null) return;
    await firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('packages')
        .doc(resolved.packageDocId)
        .update({'status': 'closed', 'closedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> cancelPackage(int packageId, {String? reason}) async {
    final resolved = await _resolvePackage(packageId);
    if (resolved == null) return;

    await firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('packages')
        .doc(resolved.packageDocId)
        .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
        });

    // Mark client document status as cancelled so it is excluded from operational views
    await firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<List<ExerciseCatalogData>> get exerciseCatalog async {
    return [
      const ExerciseCatalogData(
        id: 1,
        name: 'Barbell Back Squat',
        category: 'Legs',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 2,
        name: 'Romanian Deadlift',
        category: 'Legs',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 3,
        name: 'Leg Press',
        category: 'Legs',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 4,
        name: 'Leg Extension',
        category: 'Legs',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 5,
        name: 'Leg Curl',
        category: 'Legs',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 6,
        name: 'Barbell Bench Press',
        category: 'Chest',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 7,
        name: 'Incline Dumbbell Press',
        category: 'Chest',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 8,
        name: 'Cable Fly',
        category: 'Chest',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 9,
        name: 'Overhead Press',
        category: 'Shoulders',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 10,
        name: 'Lateral Raise',
        category: 'Shoulders',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 11,
        name: 'Barbell Bent-Over Row',
        category: 'Back',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 12,
        name: 'Lat Pulldown',
        category: 'Back',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 13,
        name: 'Seated Cable Row',
        category: 'Back',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 14,
        name: 'Barbell Biceps Curl',
        category: 'Arms',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 15,
        name: 'Triceps Pushdown',
        category: 'Arms',
        source: 'local',
      ),
      const ExerciseCatalogData(
        id: 16,
        name: 'Plank',
        category: 'Core',
        source: 'local',
      ),
    ];
  }

  @override
  Future<PackageSaleRecord> recordPackageSale(PackageSaleRecord sale) async {
    final docRef = sale.id.isNotEmpty
        ? firestore.collection('package_sales').doc(sale.id)
        : firestore.collection('package_sales').doc();
    final finalSale = sale.copyWith(id: docRef.id);
    await docRef.set(finalSale.toMap());
    return finalSale;
  }

  @override
  Future<List<PackageSaleRecord>> getPackageSales({
    String? trainerId,
    int? year,
    int? quarter,
    String? status,
  }) async {
    final snap = await firestore.collection('package_sales').get();
    var list = snap.docs
        .map((d) => PackageSaleRecord.fromMap(d.data(), id: d.id))
        .toList();

    if (trainerId != null) {
      list = list.where((s) => s.trainerId == trainerId).toList();
    }
    if (status != null) {
      list = list
          .where((s) => s.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (year != null) {
      list = list.where((s) => s.timestamp.year == year).toList();
    }
    if (quarter != null) {
      list = list
          .where((s) => ((s.timestamp.month - 1) ~/ 3) + 1 == quarter)
          .toList();
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords({
    int? trainerId,
    int? clientId,
    int? packageId,
    String? status,
  }) async {
    final List<AttendanceRecord> list = [];
    final clientDocs = await firestore.collection('clients').get();
    for (final cDoc in clientDocs.docs) {
      final cData = cDoc.data();
      final cIntId = (cData['id'] as num?)?.toInt() ?? 0;
      final cName = cData['name'] as String? ?? '';
      final tIntId = (cData['trainerIntId'] as num?)?.toInt() ?? 0;

      if (clientId != null && cIntId != clientId) continue;
      if (trainerId != null && tIntId != trainerId) continue;

      final sDocs = await cDoc.reference.collection('sessions').get();
      for (final sDoc in sDocs.docs) {
        final sData = sDoc.data();
        final pIntId = (sData['packageIntId'] as num?)?.toInt() ?? 0;
        if (packageId != null && pIntId != packageId) continue;
        final sStatus = sData['status'] as String? ?? 'scheduled';
        if (status != null && sStatus.toLowerCase() != status.toLowerCase()) {
          continue;
        }

        final sId = (sData['id'] as num?)?.toInt() ?? _deriveIntId(sDoc.id);
        final date =
            (sData['scheduledTime'] as Timestamp?)?.toDate() ??
            (sData['completedAt'] as Timestamp?)?.toDate() ??
            DateTime.now();

        list.add(
          AttendanceRecord(
            id: sId,
            packageId: pIntId,
            clientId: cIntId,
            clientName: cName,
            trainerId: tIntId,
            trainerName: '',
            sessionNumber: (sData['sessionNumber'] as num?)?.toInt() ?? 1,
            date: date,
            status: sStatus,
            notes: sData['notes'] as String? ?? '',
            cancelReason: sData['cancelReason'] as String?,
            cancelledBy: sData['cancelledBy'] as String?,
          ),
        );
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<bool> updateAttendanceRecord(AttendanceRecord record) async {
    final resolved = await _resolveSession(record.id);
    if (resolved == null) return false;
    final ref = firestore
        .collection('clients')
        .doc(resolved.clientDocId)
        .collection('sessions')
        .doc(resolved.sessionDocId);

    await ref.update({
      'scheduledTime': Timestamp.fromDate(record.date),
      'status': record.status,
      'notes': record.notes,
      if (record.status == 'completed')
        'completedAt': Timestamp.fromDate(record.date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  @override
  Future<bool> cancelAttendanceRecord(
    int id, {
    String? cancelledBy,
    String? cancelReason,
  }) async {
    return cancelSession(
      id,
      cancelledBy: cancelledBy,
      cancelReason: cancelReason,
    );
  }
}
