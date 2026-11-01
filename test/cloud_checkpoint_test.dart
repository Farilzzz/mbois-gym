import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/cloud/cloud_session.dart';

class FakeGateway implements CloudGateway {
  final identities = StreamController<String?>.broadcast();
  final profiles = <String, Completer<CloudProfile?>>{};
  @override
  Stream<String?> get authChanges => identities.stream;
  @override
  String? get currentUid => null;
  @override
  Future<CloudProfile?> profile(String uid) =>
      (profiles[uid] ??= Completer<CloudProfile?>()).future;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async => identities.add(null);
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {}
  @override
  Future<List<CloudClient>> clients(String uid) async => [];
  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String phone,
    double? heightCm,
    double? weightKg,
    String? specialization,
    int? experienceYears,
    String? certifications,
    String? bio,
    String? photoUrl,
  }) async {}
}

void main() {
  test(
    'late profile response cannot restore signed-out cloud session',
    () async {
      final gateway = FakeGateway();
      final session = CloudSession(gateway);
      gateway.identities.add('a');
      await Future<void>.delayed(Duration.zero);
      gateway.identities.add(null);
      await Future<void>.delayed(Duration.zero);
      gateway.profiles['a']!.complete(const CloudProfile('a', 'PT A', true));
      await Future<void>.delayed(Duration.zero);
      expect(session.profile, isNull);
      session.dispose();
      await gateway.identities.close();
    },
  );
}
