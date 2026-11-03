import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/app.dart';
import 'package:mbois_gym_pt/data/app_database.dart';
import 'package:mbois_gym_pt/features/screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Post PT requires confirmation before finalization and displays saved evaluation after closure',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final trainerId = await db
          .into(db.trainers)
          .insert(
            TrainersCompanion.insert(
              name: 'Coach Test',
              email: 'coach@test.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final clientId = await db.addClient(
        trainerId: trainerId,
        name: 'Budi Member',
        age: 28,
        sessionsCount: 8,
      );

      final pkg = (await db.currentPackage(clientId))!;
      for (int i = 0; i < 8; i++) {
        final sId = await db.schedule(
          pkg.id,
          DateTime.now().add(Duration(days: i)),
        );
        await db.completeSession(sId, 'Selesai');
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(home: ClientDetailScreen(clientId: clientId)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Post PT'));
      await tester.pumpAndSettle();

      // Fill in evaluation
      final achFinder = find.widgetWithText(
        TextField,
        'Pencapaian Tujuan Klien',
      );
      await tester.ensureVisible(achFinder);
      await tester.enterText(achFinder, 'Berhasil turun 5 kg');
      final evalFinder = find.widgetWithText(TextField, 'Evaluasi Coach PT');
      await tester.ensureVisible(evalFinder);
      await tester.enterText(evalFinder, 'Disiplin latihan sangat baik');
      final recFinder = find.widgetWithText(
        TextField,
        'Rekomendasi Latihan Selanjutnya',
      );
      await tester.ensureVisible(recFinder);
      await tester.enterText(recFinder, 'Lanjut program hipertrofi');
      final concFinder = find.widgetWithText(TextField, 'Kesimpulan Program');
      await tester.ensureVisible(concFinder);
      await tester.enterText(concFinder, 'Sangat memuaskan');

      // Tap Finalize button
      final finalizeBtn = find.text('SIMPAN & TUTUP PAKET');
      await tester.ensureVisible(finalizeBtn);
      await tester.tap(finalizeBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog MUST appear
      expect(find.textContaining('Konfirmasi Finalisasi'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Ya, Finalisasi'), findsOneWidget);

      // Cancel first
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Konfirmasi Finalisasi'), findsNothing);
      expect((await db.currentPackage(clientId))!.status, 'active');

      // Tap Finalize again and confirm
      await tester.tap(finalizeBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Finalisasi'));
      await tester.pumpAndSettle();

      // Package is now closed and saved evaluation is displayed
      expect((await db.currentPackage(clientId))!.status, 'closed');
      expect(
        find.textContaining('Paket PT Selesai & Terevaluasi'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.textContaining('Berhasil turun 5 kg'), findsOneWidget);
      expect(
        find.textContaining('Disiplin latihan sangat baik'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Assessment tab allows editing client profile and persists changes',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final trainerId = await db
          .into(db.trainers)
          .insert(
            TrainersCompanion.insert(
              name: 'Coach Test',
              email: 'coach@test.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final clientId = await db.addClient(
        trainerId: trainerId,
        name: 'Rian Antara',
        age: 25,
        sessionsCount: 8,
        contact: '08123456789',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(home: ClientDetailScreen(clientId: clientId)),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Asesmen tab (index 4)
      await tester.drag(find.byType(TabBar), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asesmen'));
      await tester.pumpAndSettle();

      expect(find.text('Rian Antara'), findsOneWidget);
      expect(find.text('25 tahun'), findsOneWidget);

      // Tap Edit Asesmen / Profil
      await tester.tap(find.text('Edit Asesmen'));
      await tester.pumpAndSettle();

      // Edit Name and Age
      final nameField = find.widgetWithText(TextField, 'Nama Lengkap *');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Rian Perkasa');

      final ageField = find.widgetWithText(TextField, 'Usia (tahun) *');
      expect(ageField, findsOneWidget);
      await tester.enterText(ageField, '26');

      // Save
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      final saveBtn = find.text('Simpan Perubahan Asesmen');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify UI updated
      expect(find.text('Rian Perkasa'), findsOneWidget);
      expect(find.text('26 tahun'), findsOneWidget);

      // Verify DB updated
      final updated = await (db.select(
        db.clients,
      )..where((c) => c.id.equals(clientId))).getSingle();
      expect(updated.name, 'Rian Perkasa');
      expect(updated.age, 26);
    },
  );

  testWidgets('Attendance tab allows package renewal and cancellation', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final trainerId = await db
        .into(db.trainers)
        .insert(
          TrainersCompanion.insert(
            name: 'Coach Test',
            email: 'coach@test.com',
            passwordSalt: 'salt',
            passwordHash: 'hash',
          ),
        );

    final clientId = await db.addClient(
      trainerId: trainerId,
      name: 'Siti Member',
      age: 22,
      sessionsCount: 8,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: ClientDetailScreen(clientId: clientId)),
      ),
    );
    await tester.pumpAndSettle();

    // Active package should have "Batalkan Paket"
    final cancelBtn = find.text('Batalkan Paket');
    expect(cancelBtn, findsOneWidget);
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Dialog appears, confirm cancel
    expect(find.textContaining('Konfirmasi Batalkan Paket'), findsOneWidget);
    await tester.tap(find.text('Ya, Batalkan Paket'));
    await tester.pumpAndSettle();

    // Status should be cancelled/closed in DB
    final pkg = await db.currentPackage(clientId);
    expect(pkg!.status == 'cancelled' || pkg.status == 'closed', isTrue);

    // Now "Perpanjang Paket PT" should be visible
    final renewBtn = find.text('Perpanjang Paket PT');
    expect(renewBtn, findsOneWidget);
    await tester.tap(renewBtn);
    await tester.pumpAndSettle();

    // Choose 12 sessions and renew
    await tester.tap(find.text('Perpanjang'));
    await tester.pumpAndSettle();

    final newPkg = await db.currentPackage(clientId);
    expect(newPkg!.totalSessions, 8); // default was 8
    expect(newPkg.status, 'active');
  });

  testWidgets(
    'Workout editor supports nullable weight, editable sets, RIR and groupKey, and unsaved back confirmation',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final trainerId = await db
          .into(db.trainers)
          .insert(
            TrainersCompanion.insert(
              name: 'Coach Test',
              email: 'coach@test.com',
              passwordSalt: 'salt',
              passwordHash: 'hash',
            ),
          );

      final clientId = await db.addClient(
        trainerId: trainerId,
        name: 'Doni Pratama',
        age: 30,
        sessionsCount: 8,
      );

      final pkg = (await db.currentPackage(clientId))!;
      await db.schedule(pkg.id, DateTime.now());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(home: WorkoutEditorScreen(clientId: clientId)),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Session selection dropdown exists
      expect(find.textContaining('Pilih Sesi Appointment'), findsOneWidget);

      // 2. Add an exercise with nullable weight (BW), RIR, and groupKey
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama Exercise *'),
        'Pull Up',
      );
      // Clear weight for bodyweight exercise (nullable weight)
      await tester.enterText(
        find.widgetWithText(TextField, 'Beban (kg) (kosongkan jika BW)'),
        '',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'RIR (Reps in Reserve)'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Group / Superset Key'),
        'A1',
      );

      await tester.tap(find.text('Tambahkan ke Daftar'));
      await tester.pumpAndSettle();

      // Verify nullable volume presentation: shows Beban Tubuh / BW, not 0 kg
      expect(find.textContaining('Beban Tubuh (BW)'), findsOneWidget);
      expect(find.textContaining('Group: A1'), findsOneWidget);
      expect(find.textContaining('RIR: 2'), findsOneWidget);

      // 3. Edit set
      final editSetBtn = find.byTooltip('Edit Set');
      expect(editSetBtn, findsOneWidget);
      await tester.tap(editSetBtn);
      await tester.pumpAndSettle();

      // Change reps to 12
      await tester.enterText(
        find.widgetWithText(TextField, 'Repetisi *'),
        '12',
      );
      await tester.tap(find.text('Simpan Set'));
      await tester.pumpAndSettle();

      expect(find.textContaining('12 rep'), findsOneWidget);

      // 4. Add another set then remove it
      await tester.tap(find.text('Tambah Set / Drop Stage'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Set 2'), findsOneWidget);

      // Remove set 2
      final removeSetBtn = find.byTooltip('Hapus Set');
      expect(removeSetBtn, findsNWidgets(2));
      await tester.tap(removeSetBtn.last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Set 2'), findsNothing);

      // 5. Unsaved back confirmation
      // Trigger back
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Buang Perubahan?'), findsOneWidget);
      // Tap Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Buang Perubahan?'), findsNothing);
      expect(find.text('Pencatatan Latihan'), findsOneWidget);
    },
  );
}
