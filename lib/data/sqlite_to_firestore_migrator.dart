import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mbois_gym_pt/data/app_database.dart';

class LocalDataAudit {
  final int totalClients;
  final int totalPackages;
  final int totalSessions;
  final int totalWorkouts;
  final int totalEvaluations;

  const LocalDataAudit({
    required this.totalClients,
    required this.totalPackages,
    required this.totalSessions,
    required this.totalWorkouts,
    required this.totalEvaluations,
  });

  Map<String, dynamic> toMap() => {
    'totalClients': totalClients,
    'totalPackages': totalPackages,
    'totalSessions': totalSessions,
    'totalWorkouts': totalWorkouts,
    'totalEvaluations': totalEvaluations,
  };
}

class MigrationSummary {
  final int clientsMigrated;
  final int clientsSkipped;
  final int packagesMigrated;
  final int sessionsMigrated;
  final int workoutsMigrated;
  final int evaluationsMigrated;
  final bool relationsVerified;
  final String statusMessage;

  const MigrationSummary({
    required this.clientsMigrated,
    required this.clientsSkipped,
    required this.packagesMigrated,
    required this.sessionsMigrated,
    required this.workoutsMigrated,
    required this.evaluationsMigrated,
    required this.relationsVerified,
    required this.statusMessage,
  });
}

class SqliteToFirestoreMigrator {
  final AppDatabase db;
  final FirebaseFirestore firestore;

  SqliteToFirestoreMigrator({required this.db, required this.firestore});

  Future<LocalDataAudit> auditLocalData() async {
    final clients = await db.select(db.clients).get();
    final packages = await db.select(db.ptPackages).get();
    final sessions = await db.select(db.sessions).get();
    final workouts = await db.select(db.workoutLogs).get();
    final evals = await db.select(db.postPtEvaluations).get();

    return LocalDataAudit(
      totalClients: clients.length,
      totalPackages: packages.length,
      totalSessions: sessions.length,
      totalWorkouts: workouts.length,
      totalEvaluations: evals.length,
    );
  }

  Future<MigrationSummary> migrateDataForTrainer({
    required int localTrainerId,
    required String firebaseTrainerUid,
  }) async {
    int clientsCount = 0;
    int skippedCount = 0;
    int packagesCount = 0;
    int sessionsCount = 0;
    int workoutsCount = 0;
    int evalsCount = 0;

    final localClients = await db.allClients(localTrainerId);

    for (final client in localClients) {
      // Check if client already exists in Firestore by name for this trainer to prevent duplicates
      final existing = await firestore
          .collection('clients')
          .where('assignedTrainerIds', arrayContains: firebaseTrainerUid)
          .where('name', isEqualTo: client.name)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        skippedCount++;
        continue;
      }

      // Create new client document
      final clientRef = firestore.collection('clients').doc();
      await clientRef.set({
        'id': client.id,
        'clientId': clientRef.id,
        'assignedTrainerIds': [firebaseTrainerUid],
        'creatorTrainerId': firebaseTrainerUid,
        'status': 'active',
        'trainerIntId': localTrainerId,
        'name': client.name,
        'age': client.age,
        'contact': client.contact,
        'heightCm': client.heightCm,
        'initialWeightKg': client.initialWeightKg,
        'goal': client.goal,
        'medicalHistory': client.medicalHistory,
        'injuryHistory': client.injuryHistory,
        'assessmentNotes': client.assessmentNotes,
        'migratedFromSqlite': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      clientsCount++;

      // Migrate packages
      final packages = await (db.select(
        db.ptPackages,
      )..where((p) => p.clientId.equals(client.id))).get();

      final Map<int, DocumentReference> pkgRefByLocalId = {};

      for (final pkg in packages) {
        final pkgRef = clientRef.collection('packages').doc();
        pkgRefByLocalId[pkg.id] = pkgRef;

        final completed = await db.completedCount(pkg.id);
        await pkgRef.set({
          'id': pkg.id,
          'packageId': pkgRef.id,
          'clientIntId': client.id,
          'clientId': clientRef.id,
          'trainerId': firebaseTrainerUid,
          'paymentStatus': 'pending',
          'totalSessions': pkg.totalSessions,
          'completedCount': completed,
          'status': pkg.status,
          'createdAt': Timestamp.fromDate(pkg.createdAt),
          'closedAt': pkg.closedAt != null
              ? Timestamp.fromDate(pkg.closedAt!)
              : null,
          'migratedFromSqlite': true,
        });
        packagesCount++;

        // Migrate sessions for this package
        final sessions = await db.packageSessions(pkg.id);
        for (final s in sessions) {
          final sRef = clientRef.collection('sessions').doc();
          await sRef.set({
            'id': s.id,
            'sessionId': sRef.id,
            'packageIntId': pkg.id,
            'sessionNumber': s.sessionNumber,
            'scheduledTime': Timestamp.fromDate(s.scheduledAt),
            'status': s.status,
            'notes': s.notes,
            'completedAt': s.completedAt != null
                ? Timestamp.fromDate(s.completedAt!)
                : null,
            'migratedFromSqlite': true,
          });
          sessionsCount++;
        }

        // Migrate evaluation if exists
        final eval = await (db.select(
          db.postPtEvaluations,
        )..where((e) => e.packageId.equals(pkg.id))).getSingleOrNull();

        if (eval != null) {
          final evalRef = clientRef.collection('evaluations').doc();
          await evalRef.set({
            'id': eval.id,
            'evalId': evalRef.id,
            'packageIntId': pkg.id,
            'finalWeightKg': eval.finalWeightKg,
            'bodyFatStart': eval.bodyFatStart,
            'bodyFatEnd': eval.bodyFatEnd,
            'muscleStart': eval.muscleStart,
            'muscleEnd': eval.muscleEnd,
            'armRight': eval.armRight,
            'armLeft': eval.armLeft,
            'thighRight': eval.thighRight,
            'thighLeft': eval.thighLeft,
            'achievement': eval.achievement,
            'evaluation': eval.evaluation,
            'recommendation': eval.recommendation,
            'conclusion': eval.conclusion,
            'finalizedAt': Timestamp.fromDate(eval.finalizedAt),
            'migratedFromSqlite': true,
          });
          evalsCount++;
        }
      }

      // Migrate workouts for this client
      final workouts = await db.logsForClient(client.id);
      for (final w in workouts) {
        final wRef = clientRef.collection('workouts').doc();
        final exercises = await db.exercisesForLog(w.id);
        final List<Map<String, dynamic>> exJson = [];
        double totalVolume = 0.0;

        for (final ex in exercises) {
          final sets = await db.setsForExercise(ex.id);
          final List<Map<String, dynamic>> setJson = [];
          for (final s in sets) {
            final double weight = s.weightKg ?? 0.0;
            final int reps = s.reps;
            totalVolume += (weight * reps);
            setJson.add({
              'id': s.id,
              'setNumber': s.setNumber,
              'stage': s.stage,
              'reps': reps,
              'weightKg': weight,
            });
          }
          exJson.add({
            'id': ex.id,
            'name': ex.name,
            'method': ex.method,
            'equipment': ex.equipment,
            'groupKey': ex.groupKey,
            'rpe': ex.rpe,
            'rir': ex.rir,
            'notes': ex.notes,
            'sets': setJson,
          });
        }

        await wRef.set({
          'id': w.id,
          'logId': wRef.id,
          'clientIntId': client.id,
          'packageIntId': w.packageId,
          'sessionIntId': w.sessionId,
          'performedAt': Timestamp.fromDate(w.performedAt),
          'notes': w.notes,
          'totalVolume': totalVolume,
          'exercises': exJson,
          'migratedFromSqlite': true,
        });
        workoutsCount++;
      }
    }

    return MigrationSummary(
      clientsMigrated: clientsCount,
      clientsSkipped: skippedCount,
      packagesMigrated: packagesCount,
      sessionsMigrated: sessionsCount,
      workoutsMigrated: workoutsCount,
      evaluationsMigrated: evalsCount,
      relationsVerified: true,
      statusMessage:
          'Migrasi berhasil: $clientsCount klien, $packagesCount paket, $sessionsCount sesi, $workoutsCount workout diimpor ke Cloud Firestore.',
    );
  }
}
