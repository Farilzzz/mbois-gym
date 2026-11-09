import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/features/manager_dashboard_screen.dart';

void main() {
  ManagerClientItem item(String status, int remaining) => ManagerClientItem(
    id: status,
    name: 'Client $status',
    status: status,
    packageName: 'Paket 4 Sesi',
    totalSessions: 4,
    attendedSessions: 4 - remaining,
    remainingSessions: remaining,
  );
  test('only explicit active lifecycle with quota is active', () {
    expect(item('active', 1).isActive, isTrue);
    for (final status in [
      'completed',
      'cancelled',
      'discontinued',
      'unknown',
    ]) {
      expect(item(status, 1).isActive, isFalse);
    }
    expect(item('active', 0).isActive, isFalse);
    expect(item('unknown', 4).statusLabel, 'Status belum tersedia');
  });
  testWidgets(
    'production roster separates active and history with status labels',
    (tester) async {
      final clients = [
        item('active', 4),
        item('completed', 0),
        item('cancelled', 4),
      ];
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: ManagerClientHistoryScreen(
            trainer: TrainerPerformance(
              id: 'pt',
              name: 'Trainer',
              specialization: 'PT',
              activeClients: 1,
              packagesSold: 0,
              totalSales: 0,
              clients: clients,
            ),
            onAttendance: (_, client) => selected = client.id,
          ),
        ),
      );
      expect(find.textContaining('Selesai •'), findsOneWidget);
      expect(find.textContaining('Dibatalkan •'), findsOneWidget);
      await tester.tap(find.text('Aktif'));
      await tester.pumpAndSettle();
      expect(find.text('Client active'), findsOneWidget);
      expect(find.text('Client completed'), findsNothing);
      expect(find.text('Client cancelled'), findsNothing);
      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Client active'), findsNothing);
      await tester.tap(find.text('Client completed'));
      expect(selected, 'completed');
      expect(tester.takeException(), isNull);
    },
  );
}
