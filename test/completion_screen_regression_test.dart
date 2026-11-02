import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/app.dart';
import 'package:mbois_gym_pt/cloud/cloud_session.dart';
import 'package:mbois_gym_pt/features/screens.dart';

import 'regression_lifecycle_quota_signatures_test.dart'
    show RegressionMockGymRepository;

class TestAuth extends CloudAuthController {
  @override
  Future<CloudProfile?> build() async => null;
}

class RefusingRepository extends RegressionMockGymRepository {
  Object? error;
  int calls = 0;
  @override
  Future<bool> completeSession(
    int id,
    String notes, {
    List<List<Offset>>? clientStrokes,
    List<List<Offset>>? coachStrokes,
    String? clientName,
    String? trainerName,
  }) async {
    calls++;
    if (error != null) throw error!;
    return false;
  }
}

Future<void> openCompletion(
  WidgetTester tester,
  RefusingRepository repo,
) async {
  repo.addTestClient(
    id: 1,
    name: 'Test Client',
    lifecycle: 'active',
    totalSessions: 4,
  );
  await repo.schedule(1, DateTime(2026, 11, 2));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gymRepositoryProvider.overrideWithValue(repo),
        cloudAuthProvider.overrideWith(TestAuth.new),
      ],
      child: const MaterialApp(home: ClientDetailScreen(clientId: 1)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -250));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Potong Sesi'));
  await tester.pumpAndSettle();
}

Future<void> sign(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  final rect = tester.getRect(find.byKey(const Key('signature_canvas')));
  final gesture = await tester.startGesture(
    rect.topLeft + const Offset(30, 30),
  );
  for (var i = 1; i < 12; i++) {
    await gesture.moveBy(const Offset(3, 2));
    await tester.pump();
  }
  await gesture.up();
  await tester.tap(find.text('Simpan'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact confirmation keeps actions visible with keyboard and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openCompletion(tester, RefusingRepository());
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final action = find.text('Verifikasi & Potong Sesi');
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(568));
    expect(action.hitTestable(), findsOneWidget);
  });

  testWidgets('closed unfinished package is history not completed', (tester) async {
    final repo = RefusingRepository()..addTestClient(id: 1, name: 'Stopped', lifecycle: 'discontinued', totalSessions: 4, packageStatus: 'closed');
    await tester.pumpWidget(ProviderScope(overrides: [gymRepositoryProvider.overrideWithValue(repo), cloudAuthProvider.overrideWith(TestAuth.new)], child: const MaterialApp(home: ClientListScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SELESAI'));
    await tester.pumpAndSettle();
    expect(find.text('Dihentikan'), findsOneWidget);
    expect(find.text('Sesi: 0 / 4 selesai'), findsOneWidget);
    expect(find.text('Selesai'), findsNothing);
  });

  testWidgets(
    'repository false keeps confirmation and never announces success',
    (tester) async {
      final repo = RefusingRepository();
      await openCompletion(tester, repo);
      await sign(tester, 'Buka Pad Tanda Tangan Klien');
      await sign(tester, 'Buka Pad Tanda Tangan Coach');
      await tester.tap(find.text('Verifikasi & Potong Sesi'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('Verifikasi & Potong Sesi'), findsOneWidget);
      expect(find.textContaining('Sesi berhasil diverifikasi'), findsNothing);
      expect(find.textContaining('Status sesi telah berubah'), findsAtLeastNWidgets(1));
    },
  );
}
