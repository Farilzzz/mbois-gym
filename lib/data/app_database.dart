import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Trainers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text().unique()();
  TextColumn get passwordSalt => text()();
  TextColumn get passwordHash => text()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().nullable()();
}

class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trainerId => integer().references(Trainers, #id)();
  TextColumn get name => text()();
  IntColumn get age => integer()();
  TextColumn get contact => text().withDefault(const Constant(''))();
  RealColumn get heightCm => real().nullable()();
  RealColumn get initialWeightKg => real().nullable()();
  TextColumn get goal => text().withDefault(const Constant(''))();
  TextColumn get medicalHistory => text().withDefault(const Constant(''))();
  TextColumn get injuryHistory => text().withDefault(const Constant(''))();
  TextColumn get assessmentNotes => text().withDefault(const Constant(''))();
}

class PtPackages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  IntColumn get totalSessions => integer()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get packageId => integer().references(PtPackages, #id)();
  IntColumn get sessionNumber => integer()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  @override
  List<Set<Column>> get uniqueKeys => [
    {packageId, sessionNumber},
  ];
}

class ExerciseCatalog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  IntColumn get externalId => integer().nullable()();
  @override
  List<Set<Column>> get uniqueKeys => [
    {name, category},
  ];
}

class WorkoutLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  IntColumn get packageId => integer().references(PtPackages, #id)();
  IntColumn get sessionId => integer().nullable().references(Sessions, #id)();
  DateTimeColumn get performedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get logId => integer().references(WorkoutLogs, #id)();
  IntColumn get catalogId =>
      integer().nullable().references(ExerciseCatalog, #id)();
  TextColumn get name => text()();
  TextColumn get equipment => text().withDefault(const Constant(''))();
  TextColumn get method => text().withDefault(const Constant('Straight Set'))();
  TextColumn get groupKey => text().nullable()();
  RealColumn get rpe => real().nullable()();
  IntColumn get rir => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(WorkoutExercises, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get stage => integer().withDefault(const Constant(1))();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real().nullable()();
}

class PostPtEvaluations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get packageId => integer().unique().references(PtPackages, #id)();
  RealColumn get finalWeightKg => real().nullable()();
  RealColumn get bodyFatStart => real().nullable()();
  RealColumn get bodyFatEnd => real().nullable()();
  RealColumn get muscleStart => real().nullable()();
  RealColumn get muscleEnd => real().nullable()();
  RealColumn get armRight => real().nullable()();
  RealColumn get armLeft => real().nullable()();
  RealColumn get thighRight => real().nullable()();
  RealColumn get thighLeft => real().nullable()();
  TextColumn get achievement => text()();
  TextColumn get evaluation => text()();
  TextColumn get recommendation => text()();
  TextColumn get conclusion => text()();
  DateTimeColumn get finalizedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Trainers,
    Clients,
    PtPackages,
    Sessions,
    ExerciseCatalog,
    WorkoutLogs,
    WorkoutExercises,
    WorkoutSets,
    PostPtEvaluations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return AppDatabase(
      NativeDatabase.createInBackground(
        File(p.join(dir.path, 'mbois_gym.sqlite')),
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX idx_sessions_package_status ON sessions (package_id, status)',
      );
      await customStatement(
        'CREATE INDEX idx_logs_client_date ON workout_logs (client_id, performed_at)',
      );
      for (final item in initialExercises) {
        await into(exerciseCatalog).insert(
          ExerciseCatalogCompanion.insert(name: item.$1, category: item.$2),
        );
      }
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(trainers, trainers.phone);
        await m.addColumn(trainers, trainers.avatarUrl);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static const initialExercises = <(String, String)>[
    ('Bench Press', 'Chest'),
    ('Incline Dumbbell Press', 'Chest'),
    ('Lat Pulldown', 'Back'),
    ('Seated Row', 'Back'),
    ('Shoulder Press', 'Shoulder'),
    ('Lateral Raise', 'Shoulder'),
    ('Bicep Curl', 'Arms'),
    ('Triceps Pushdown', 'Arms'),
    ('Squat', 'Legs'),
    ('Leg Extension', 'Legs'),
    ('Plank', 'Core'),
    ('Crunch', 'Core'),
    ('Treadmill', 'Cardio'),
    ('Stationary Bike', 'Cardio'),
  ];

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
  }) => transaction(() async {
    if (age <= 0 || !const {8, 12, 16}.contains(sessionsCount)) {
      throw ArgumentError(
        'Age must be positive and package must be 8, 12, or 16 sessions',
      );
    }
    if ([
      height,
      weight,
    ].whereType<double>().any((v) => !v.isFinite || v <= 0)) {
      throw ArgumentError('Measurements must be finite and positive');
    }
    final clientId = await into(clients).insert(
      ClientsCompanion.insert(
        trainerId: trainerId,
        name: name.trim(),
        age: age,
        contact: Value(contact),
        heightCm: Value(height),
        initialWeightKg: Value(weight),
        goal: Value(goal),
        medicalHistory: Value(medical),
        injuryHistory: Value(injury),
        assessmentNotes: Value(notes),
      ),
    );
    await into(ptPackages).insert(
      PtPackagesCompanion.insert(
        clientId: clientId,
        totalSessions: sessionsCount,
      ),
    );
    return clientId;
  });

  Future<List<Client>> allClients(int trainerId) =>
      (select(clients)
            ..where((c) => c.trainerId.equals(trainerId))
            ..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .get();
  Future<PtPackage?> currentPackage(int clientId) =>
      (select(ptPackages)
            ..where((t) => t.clientId.equals(clientId))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();
  Future<List<Session>> packageSessions(int packageId) =>
      (select(sessions)
            ..where((s) => s.packageId.equals(packageId))
            ..orderBy([(s) => OrderingTerm(expression: s.sessionNumber)]))
          .get();
  Future<int> completedCount(int packageId) async =>
      (select(sessions)..where(
            (s) => s.packageId.equals(packageId) & s.status.equals('completed'),
          ))
          .get()
          .then((v) => v.length);

  Future<int> schedule(int packageId, DateTime time) => transaction(() async {
    final pkg = await (select(
      ptPackages,
    )..where((p) => p.id.equals(packageId))).getSingle();
    if (pkg.status != 'active') throw StateError('Paket sudah ditutup');
    final items = await packageSessions(packageId);
    if (items.where((s) => s.status != 'cancelled').length >=
        pkg.totalSessions) {
      throw StateError('Semua slot sesi sudah terjadwal');
    }
    final next = items.isEmpty
        ? 1
        : items.map((s) => s.sessionNumber).reduce(max) + 1;
    return into(sessions).insert(
      SessionsCompanion.insert(
        packageId: packageId,
        sessionNumber: next,
        scheduledAt: time,
      ),
    );
  });

  Future<bool> cancelSession(int sessionId) => transaction(() async {
    final session = await (select(
      sessions,
    )..where((s) => s.id.equals(sessionId))).getSingleOrNull();
    if (session == null || session.status != 'scheduled') {
      throw StateError('Hanya sesi terjadwal yang bisa dibatalkan');
    }
    final pkg = await (select(
      ptPackages,
    )..where((p) => p.id.equals(session.packageId))).getSingle();
    if (pkg.status != 'active') throw StateError('Paket tidak aktif');
    await (update(sessions)..where((s) => s.id.equals(sessionId))).write(
      const SessionsCompanion(status: Value('cancelled')),
    );
    return true;
  });

  Future<bool> rescheduleSession(int sessionId, DateTime time) =>
      transaction(() async {
        final session = await (select(
          sessions,
        )..where((s) => s.id.equals(sessionId))).getSingleOrNull();
        if (session == null || session.status != 'scheduled') {
          throw StateError('Hanya sesi terjadwal yang bisa dijadwalkan ulang');
        }
        final pkg = await (select(
          ptPackages,
        )..where((p) => p.id.equals(session.packageId))).getSingle();
        if (pkg.status != 'active') throw StateError('Paket tidak aktif');
        await (update(sessions)..where((s) => s.id.equals(sessionId))).write(
          SessionsCompanion(scheduledAt: Value(time)),
        );
        return true;
      });

  Future<PtPackage> renewPackage(int clientId, int sessionsCount) =>
      transaction(() async {
        if (!const {8, 12, 16}.contains(sessionsCount)) {
          throw ArgumentError('Package must be 8, 12, or 16 sessions');
        }
        final latest = await currentPackage(clientId);
        if (latest == null ||
            (latest.status != 'closed' && latest.status != 'cancelled')) {
          throw StateError(
            'Paket aktif harus ditutup atau dibatalkan sebelum perpanjangan',
          );
        }
        final id = await into(ptPackages).insert(
          PtPackagesCompanion.insert(
            clientId: clientId,
            totalSessions: sessionsCount,
          ),
        );
        return (select(ptPackages)..where((p) => p.id.equals(id))).getSingle();
      });

  /// Idempotent: confirmation of a completed session never consumes a second slot.
  Future<bool> completeSession(int sessionId, String notes) =>
      transaction(() async {
        final s = await (select(
          sessions,
        )..where((s) => s.id.equals(sessionId))).getSingle();
        if (s.status == 'completed') return false;
        if (s.status != 'scheduled') {
          throw StateError('Hanya sesi terjadwal yang bisa diselesaikan');
        }
        final pkg = await (select(
          ptPackages,
        )..where((p) => p.id.equals(s.packageId))).getSingle();
        if (pkg.status != 'active') throw StateError('Paket tidak aktif');
        final count = await completedCount(pkg.id);
        if (count >= pkg.totalSessions) throw StateError('Kuota sesi habis');
        final changed =
            await (update(sessions)..where(
                  (row) =>
                      row.id.equals(sessionId) & row.status.equals('scheduled'),
                ))
                .write(
                  SessionsCompanion(
                    status: const Value('completed'),
                    notes: Value(notes),
                    completedAt: Value(DateTime.now()),
                  ),
                );
        return changed == 1;
      });

  Future<int> saveWorkout({
    required int clientId,
    required int packageId,
    int? sessionId,
    required String notes,
    required List<ExerciseDraft> exercises,
  }) => transaction(() async {
    if (exercises.isEmpty ||
        exercises.any(
          (e) =>
              e.name.trim().isEmpty ||
              e.sets.isEmpty ||
              (e.rpe != null && !e.rpe!.isFinite) ||
              e.sets.any(
                (s) =>
                    s.reps <= 0 ||
                    (s.weightKg != null &&
                        (!s.weightKg!.isFinite || s.weightKg! < 0)),
              ),
        )) {
      throw StateError('Latihan harus berisi exercise dan set valid');
    }
    final pkg = await (select(
      ptPackages,
    )..where((p) => p.id.equals(packageId))).getSingleOrNull();
    if (pkg == null || pkg.clientId != clientId) {
      throw StateError('Paket tidak sesuai dengan klien');
    }
    if (sessionId != null) {
      final s = await (select(
        sessions,
      )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
      if (s == null || s.packageId != packageId) {
        throw StateError('Sesi tidak sesuai dengan paket');
      }
    }
    final logId = await into(workoutLogs).insert(
      WorkoutLogsCompanion.insert(
        clientId: clientId,
        packageId: packageId,
        sessionId: Value(sessionId),
        notes: Value(notes),
      ),
    );
    for (final e in exercises) {
      final exerciseId = await into(workoutExercises).insert(
        WorkoutExercisesCompanion.insert(
          logId: logId,
          name: e.name.trim(),
          equipment: Value(e.equipment),
          method: Value(e.method),
          groupKey: Value(e.groupKey),
          rpe: Value(e.rpe),
          rir: Value(e.rir),
          notes: Value(e.notes),
        ),
      );
      for (var index = 0; index < e.sets.length; index++) {
        final set = e.sets[index];
        await into(workoutSets).insert(
          WorkoutSetsCompanion.insert(
            exerciseId: exerciseId,
            setNumber: index + 1,
            stage: Value(set.stage),
            reps: set.reps,
            weightKg: Value(set.weightKg),
          ),
        );
      }
    }
    return logId;
  });

  Future<List<WorkoutLog>> logsForClient(int clientId) =>
      (select(workoutLogs)
            ..where((l) => l.clientId.equals(clientId))
            ..orderBy([(l) => OrderingTerm.desc(l.performedAt)]))
          .get();
  Future<List<WorkoutExercise>> exercisesForLog(int logId) =>
      (select(workoutExercises)..where((e) => e.logId.equals(logId))).get();
  Future<List<WorkoutSet>> setsForExercise(int exerciseId) =>
      (select(workoutSets)
            ..where((s) => s.exerciseId.equals(exerciseId))
            ..orderBy([
              (s) => OrderingTerm(expression: s.setNumber),
              (s) => OrderingTerm(expression: s.stage),
            ]))
          .get();

  Future<Trainer?> getTrainerById(int id) =>
      (select(trainers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateTrainer({
    required int id,
    required String name,
    required String email,
    String phone = '',
    String? avatarUrl,
  }) => transaction(() async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Nama lengkap PT tidak boleh kosong');
    }
    final cleanEmail = email.trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) {
      throw ArgumentError('Format email tidak valid');
    }
    final cleanPhone = normalizePhoneNumber(phone);
    if (cleanPhone.isNotEmpty && !isValidPhoneNumber(cleanPhone)) {
      throw ArgumentError('Format nomor WhatsApp tidak valid');
    }
    final existing =
        await (select(
              trainers,
            )..where((t) => t.email.equals(cleanEmail) & t.id.equals(id).not()))
            .getSingleOrNull();
    if (existing != null) {
      throw StateError('Email sudah digunakan oleh akun lain');
    }

    await (update(trainers)..where((t) => t.id.equals(id))).write(
      TrainersCompanion(
        name: Value(trimmedName),
        email: Value(cleanEmail),
        phone: Value(cleanPhone),
        avatarUrl: Value(avatarUrl),
      ),
    );
  });

  Future<WorkoutLog?> getWorkoutLog(int logId) =>
      (select(workoutLogs)..where((l) => l.id.equals(logId))).getSingleOrNull();

  Future<void> updateWorkout({
    required int logId,
    required String notes,
    int? sessionId,
    required List<ExerciseDraft> exercises,
  }) => transaction(() async {
    if (exercises.isEmpty ||
        exercises.any(
          (e) =>
              e.name.trim().isEmpty ||
              e.sets.isEmpty ||
              (e.rpe != null && !e.rpe!.isFinite) ||
              e.sets.any(
                (s) =>
                    s.reps <= 0 ||
                    (s.weightKg != null &&
                        (!s.weightKg!.isFinite || s.weightKg! < 0)),
              ),
        )) {
      throw StateError('Latihan harus berisi exercise dan set valid');
    }
    final log = await (select(
      workoutLogs,
    )..where((l) => l.id.equals(logId))).getSingleOrNull();
    if (log == null) throw StateError('Workout log tidak ditemukan');

    if (sessionId != null) {
      final s = await (select(
        sessions,
      )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
      if (s == null || s.packageId != log.packageId) {
        throw StateError('Sesi tidak sesuai dengan paket');
      }
    }

    // 1. Update workout log row (notes, sessionId) - preserves client_id, package_id, performed_at, and logId
    await (update(workoutLogs)..where((l) => l.id.equals(logId))).write(
      WorkoutLogsCompanion(notes: Value(notes), sessionId: Value(sessionId)),
    );

    // 2. Query existing exercises in database for this log
    final existingExercises = await (select(
      workoutExercises,
    )..where((e) => e.logId.equals(logId))).get();
    final existingExerciseIds = existingExercises.map((e) => e.id).toSet();
    final submittedExerciseIds = exercises
        .map((e) => e.id)
        .whereType<int>()
        .toSet();

    // Delete exercises that are removed
    final exercisesToDelete = existingExerciseIds.difference(
      submittedExerciseIds,
    );
    for (final exId in exercisesToDelete) {
      await (delete(workoutSets)..where((s) => s.exerciseId.equals(exId))).go();
      await (delete(workoutExercises)..where((e) => e.id.equals(exId))).go();
    }

    // 3. Update or Insert exercises and their sets
    for (final e in exercises) {
      int currentExerciseId;
      if (e.id != null && existingExerciseIds.contains(e.id)) {
        currentExerciseId = e.id!;
        await (update(
          workoutExercises,
        )..where((ex) => ex.id.equals(currentExerciseId))).write(
          WorkoutExercisesCompanion(
            name: Value(e.name.trim()),
            equipment: Value(e.equipment),
            method: Value(e.method),
            groupKey: Value(e.groupKey),
            rpe: Value(e.rpe),
            rir: Value(e.rir),
            notes: Value(e.notes),
          ),
        );
      } else {
        currentExerciseId = await into(workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            logId: logId,
            name: e.name.trim(),
            equipment: Value(e.equipment),
            method: Value(e.method),
            groupKey: Value(e.groupKey),
            rpe: Value(e.rpe),
            rir: Value(e.rir),
            notes: Value(e.notes),
          ),
        );
      }

      final existingSets = await (select(
        workoutSets,
      )..where((s) => s.exerciseId.equals(currentExerciseId))).get();
      final existingSetIds = existingSets.map((s) => s.id).toSet();
      final submittedSetIds = e.sets.map((s) => s.id).whereType<int>().toSet();

      final setsToDelete = existingSetIds.difference(submittedSetIds);
      for (final sId in setsToDelete) {
        await (delete(workoutSets)..where((s) => s.id.equals(sId))).go();
      }

      for (var index = 0; index < e.sets.length; index++) {
        final s = e.sets[index];
        if (s.id != null && existingSetIds.contains(s.id)) {
          await (update(
            workoutSets,
          )..where((row) => row.id.equals(s.id!))).write(
            WorkoutSetsCompanion(
              setNumber: Value(index + 1),
              stage: Value(s.stage),
              reps: Value(s.reps),
              weightKg: Value(s.weightKg),
            ),
          );
        } else {
          await into(workoutSets).insert(
            WorkoutSetsCompanion.insert(
              exerciseId: currentExerciseId,
              setNumber: index + 1,
              stage: Value(s.stage),
              reps: s.reps,
              weightKg: Value(s.weightKg),
            ),
          );
        }
      }
    }
  });

  Future<bool> deleteWorkout(int logId) => transaction(() async {
    final exercises = await (select(
      workoutExercises,
    )..where((e) => e.logId.equals(logId))).get();
    for (final ex in exercises) {
      await (delete(
        workoutSets,
      )..where((s) => s.exerciseId.equals(ex.id))).go();
    }
    await (delete(workoutExercises)..where((e) => e.logId.equals(logId))).go();
    final count = await (delete(
      workoutLogs,
    )..where((l) => l.id.equals(logId))).go();
    return count > 0;
  });

  Future<bool> deleteWorkoutExercise(int exerciseId) => transaction(() async {
    await (delete(
      workoutSets,
    )..where((s) => s.exerciseId.equals(exerciseId))).go();
    final count = await (delete(
      workoutExercises,
    )..where((e) => e.id.equals(exerciseId))).go();
    return count > 0;
  });

  Future<bool> deleteWorkoutSet(int setId) => (delete(
    workoutSets,
  )..where((s) => s.id.equals(setId))).go().then((c) => c > 0);

  Future<void> finalizePackage(
    int packageId,
    PostPtEvaluationsCompanion evaluation,
  ) => transaction(() async {
    if (evaluation.packageId.present &&
        evaluation.packageId.value != packageId) {
      throw ArgumentError(
        'Evaluasi packageId tidak sesuai dengan paket yang diselesaikan',
      );
    }
    final numbers = [
      evaluation.finalWeightKg,
      evaluation.bodyFatStart,
      evaluation.bodyFatEnd,
      evaluation.muscleStart,
      evaluation.muscleEnd,
      evaluation.armRight,
      evaluation.armLeft,
      evaluation.thighRight,
      evaluation.thighLeft,
    ];
    if (numbers.any(
      (v) =>
          v.present && v.value != null && (!v.value!.isFinite || v.value! < 0),
    )) {
      throw ArgumentError(
        'Evaluation measurements must be finite and non-negative',
      );
    }
    final pkg = await (select(
      ptPackages,
    )..where((p) => p.id.equals(packageId))).getSingle();
    if (pkg.status != 'active') throw StateError('Paket telah ditutup');
    if (await completedCount(packageId) != pkg.totalSessions) {
      throw StateError('Seluruh sesi harus selesai sebelum Post PT');
    }
    final evalToInsert = evaluation.copyWith(packageId: Value(packageId));
    await into(postPtEvaluations).insert(evalToInsert);
    await (update(ptPackages)..where((p) => p.id.equals(packageId))).write(
      PtPackagesCompanion(
        status: const Value('closed'),
        closedAt: Value(DateTime.now()),
      ),
    );
  });
}

class SetDraft {
  const SetDraft(this.reps, this.weightKg, {this.stage = 1, this.id});
  final int? id;
  final int reps;
  final double? weightKg;
  final int stage;
  double? get volume => weightKg == null ? null : reps * weightKg!;

  SetDraft copyWith({int? reps, double? weightKg, int? stage, int? id}) =>
      SetDraft(
        reps ?? this.reps,
        weightKg ?? this.weightKg,
        stage: stage ?? this.stage,
        id: id ?? this.id,
      );
}

class ExerciseDraft {
  ExerciseDraft({
    this.id,
    required this.name,
    required this.method,
    required this.sets,
    this.equipment = '',
    this.groupKey,
    this.rpe,
    this.rir,
    this.notes = '',
  });
  final int? id;
  String name, method, equipment, notes;
  String? groupKey;
  double? rpe;
  int? rir;
  List<SetDraft> sets;
  double get volume => sets.fold(0, (sum, item) => sum + (item.volume ?? 0));
}

double trainingVolume(Iterable<ExerciseDraft> exercises) =>
    exercises.fold(0, (sum, e) => sum + e.volume);

String normalizePhoneNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (hasPlus) {
    return '+$digits';
  }
  return digits;
}

bool isValidPhoneNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return true;
  if (!RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(trimmed)) return false;
  final clean = normalizePhoneNumber(trimmed);
  return RegExp(r'^(\+?[0-9]{8,18})$').hasMatch(clean);
}

bool isValidEmail(String raw) {
  final trimmed = raw.trim();
  return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
      .hasMatch(trimmed);
}
