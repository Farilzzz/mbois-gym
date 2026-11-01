import 'dart:async';

enum CloudRole {
  trainer, manager;

  static CloudRole? parse(Object? value) => switch (value) {
    'trainer' => CloudRole.trainer,
    'manager' => CloudRole.manager,
    _ => null,
  };
}

/// Cloud session and profile representing authenticated Firebase Personal Trainer.
class CloudProfile {
  const CloudProfile(
    this.uid,
    this.name,
    this.active, {
    this.email = '',
    this.phone = '',
    this.role = 'trainer',
    this.heightCm,
    this.weightKg,
    this.specialization = '',
    this.experienceYears,
    this.certifications = '',
    this.bio = '',
    this.photoUrl,
    String? status,
  }) : status = status ?? (active ? 'active' : 'inactive');
  final String uid;
  final String name;
  final bool active;
  final String email;
  final String phone;
  final String role;
  final double? heightCm;
  final double? weightKg;
  final String specialization;
  final int? experienceYears;
  final String certifications;
  final String bio;
  final String? photoUrl;
  final String status;
  CloudRole? get typedRole => CloudRole.parse(role);
  bool get isManager => typedRole == CloudRole.manager;
  bool get isTrainer => typedRole == CloudRole.trainer;
  bool get canAccess => active && typedRole != null;
}

class CloudClient {
  const CloudClient(this.id, this.name);
  final String id;
  final String name;
}

abstract interface class CloudGateway {
  Stream<String?> get authChanges;
  String? get currentUid;
  Future<CloudProfile?> profile(String uid);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> changePassword(String oldPassword, String newPassword);
  Future<List<CloudClient>> clients(String uid);
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
  });
}

/// Discards stale profile loads on sign-out/account switch, including A-B-A.
class CloudSession {
  CloudSession(this.gateway) {
    _subscription = gateway.authChanges.listen((uid) async {
      final generation = ++_generation;
      profile = null;
      onChanged?.call();
      if (uid == null) return;
      try {
        final found = await gateway.profile(uid);
        if (generation == _generation) {
          profile = found != null && found.canAccess ? found : null;
          onChanged?.call();
        }
      } catch (_) {
        if (generation == _generation) {
          profile = null;
          onChanged?.call();
        }
      }
    });
  }
  final CloudGateway gateway;
  late final StreamSubscription<String?> _subscription;
  int _generation = 0;
  CloudProfile? profile;
  void Function()? onChanged;

  void dispose() {
    ++_generation;
    _subscription.cancel();
  }
}