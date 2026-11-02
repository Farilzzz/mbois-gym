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
    final role = data['role'] as String? ?? 'trainer';
    final status = data['status'] as String? ?? 'inactive';
    final rawDisplayName = (data['displayName'] as String?)?.trim();
    final rawName = (data['name'] as String?)?.trim();
    final authDisplayName = auth.currentUser?.displayName?.trim();

    final displayName =
        (rawDisplayName != null && rawDisplayName.isNotEmpty && rawDisplayName != 'PT')
            ? rawDisplayName
            : (rawName != null && rawName.isNotEmpty && rawName != 'PT')
                ? rawName
                : (authDisplayName != null && authDisplayName.isNotEmpty && authDisplayName != 'PT')
                    ? authDisplayName
                    : (role == 'manager' ? 'Gym Manager' : 'Coach Mbois');
    final email = (data['email'] as String?)?.trim().isNotEmpty == true
        ? (data['email'] as String).trim()
        : (auth.currentUser?.email ?? '');
    final phone = (data['phone'] as String?)?.trim() ?? '';
    final heightCm = (data['heightCm'] as num?)?.toDouble();
    final weightKg = (data['weightKg'] as num?)?.toDouble();
    final specialization = data['specialization'] as String? ?? '';
    final experienceYears = (data['experienceYears'] as num?)?.toInt();
    final certifications = data['certifications'] as String? ?? '';
    final bio = data['bio'] as String? ?? '';
    final photoUrl = data['photoUrl'] as String?;

    return CloudProfile(
      uid,
      displayName,
      status == 'active',
      email: email,
      phone: phone,
      role: role,
      heightCm: heightCm,
      weightKg: weightKg,
      specialization: specialization,
      experienceYears: experienceYears,
      certifications: certifications,
      bio: bio,
      photoUrl: photoUrl,
      status: status,
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
    final cleanName = displayName.trim();
    await firestore.collection('users').doc(uid).update({
      'displayName': cleanName,
      'name': cleanName,
      'phone': phone.trim(),
      'heightCm': ?heightCm,
      'weightKg': ?weightKg,
      'specialization': ?specialization,
      'experienceYears': ?experienceYears,
      'certifications': ?certifications,
      'bio': ?bio,
      'photoUrl': ?photoUrl,
    });
    try {
      if (auth.currentUser != null && auth.currentUser!.uid == uid) {
        await auth.currentUser!.updateDisplayName(cleanName);
      }
    } catch (_) {}
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