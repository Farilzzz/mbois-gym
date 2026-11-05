import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/data/gym_repository.dart';
import 'package:mbois_gym_pt/data/pt_packages.dart';
import 'firestore_session_repository_test.dart' show MemoryStore, TestAuth;

PackageSaleRecord sale({String status = 'valid'}) => PackageSaleRecord(
  id: 'sale', clientId: 'client-1', clientName: 'Client',
  trainerId: 'coach', trainerName: 'Coach', tierName: 'Paket 4 Sesi',
  sessionsCount: 4, durationWeeks: 4, price: 500000,
  timestamp: DateTime(2026, 11), status: status,
);

void main() {
  test('client SDK cannot create a canonical paid sale and adapts to pending semantics', () async {
    final store = MemoryStore();
    final repo = FirestoreGymRepository(firestore: store, auth: TestAuth());
    final recorded = await repo.recordPackageSale(sale(status: 'valid'));
    expect(recorded.status, 'pending');
    expect(recorded.isValid, isFalse);
    expect(store.rows['package_sales/sale']?['status'], 'pending');
  });

  test('pending, missing and unknown sale statuses fail closed', () {
    for (final status in ['pending', 'recorded', '', 'unknown', 'cancelled']) {
      expect(sale(status: status).isValid, isFalse, reason: status);
    }
    final map = sale().toMap()..remove('status');
    expect(PackageSaleRecord.fromMap(map).isValid, isFalse);
  });

  test('missing sale timestamp never becomes today or valid revenue', () {
    final map = sale().toMap()..remove('timestamp');
    final record = PackageSaleRecord.fromMap(map);
    expect(record.isValid, isFalse);
    expect(record.timestamp.year, 1970);
  });

  test('renewal carries canonical client and trainer, not paid status', () async {
    final store = MemoryStore();
    store.rows['clients/client-1'] = {'id': 10, 'assignedTrainerIds': ['coach']};
    final repo = FirestoreGymRepository(firestore: store, auth: TestAuth());
    await repo.renewPackage(10, 4);
    final package = store.rows.entries.singleWhere((e) => e.key.contains('/packages/')).value;
    expect(package['clientId'], 'client-1');
    expect(package['trainerId'], 'coach');
    expect(package['paymentStatus'], 'pending');
    expect(store.rows.keys.where((k) => k.startsWith('package_sales/')), isEmpty);
  });

  test('renewal cannot resolve another trainers legacy integer client ID', () async {
    final store = MemoryStore();
    store.rows['clients/client-1'] = {'id': 10, 'assignedTrainerIds': ['other']};
    final repo = FirestoreGymRepository(firestore: store, auth: TestAuth());
    await expectLater(repo.renewPackage(10, 4), throwsStateError);
    expect(store.rows.length, 1);
  });
}
