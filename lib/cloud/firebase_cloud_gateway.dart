import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloud_session.dart';

class FirebaseCloudGateway implements CloudGateway {
  FirebaseCloudGateway(this.auth, this.firestore);
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  @override
  Stream<String?> get authChanges =>
      auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUid => auth.currentUser?.uid;

  @override
  Future<CloudProfile?> profile(String uid) async {
    final snapshot = await firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null || CloudRole.parse(data['role']) == null) {
      return null;
    }
    final displayName =
        (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? (data['displayName'] as String).trim()
        : (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : (auth.currentUser?.displayName?.isNotEmpty == true
              ? auth.currentUser!.displayName!
              : 'PT');
    final email = (data['email'] as String?)?.trim().isNotEmpty == true
        ? (data['email'] as String).trim()
        : (auth.currentUser?.email ?? '');
    final phone = (data['phone'] as String?)?.trim() ?? '';
    final role = data['role'] as String? ?? 'trainer';
    final status = data['status'] as String? ?? 'inactive';

    return CloudProfile(
      uid,
      displayName,
      status == 'active',
      email: email,
      phone: phone,
      role: role,
    );
  }

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
  }) async {
    await firestore.collection('users').doc(uid).update({
      'displayName': displayName.trim(),
      'phone': phone.trim(),
      'heightCm': ?heightCm,
      'weightKg': ?weightKg,
      'specialization': ?specialization,
      'experienceYears': ?experienceYears,
      'certifications': ?certifications,
      'bio': ?bio,
      'photoUrl': ?photoUrl,
    });
  }

  @override
  Future<void> signIn(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email.trim(), password: password);


  @override
  Future<void> signOut() => auth.signOut();

  @override
  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw StateError('Sesi tidak valid');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: oldPassword),
    );
    await user.updatePassword(newPassword);
  }

  @override
  Future<List<CloudClient>> clients(String uid) async {
    final query = await firestore
        .collection('clients')
        .where('assignedTrainerIds', arrayContains: uid)
        .get();
    return query.docs
        .map(
          (doc) =>
              CloudClient(doc.id, doc.data()['name'] as String? ?? 'Klien'),
        )
        .toList(growable: false);
  }
}