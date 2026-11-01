import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/app.dart';
import 'package:mbois_gym_pt/cloud/cloud_session.dart';
import 'package:mbois_gym_pt/design_system/app_design_system.dart';
import 'package:mbois_gym_pt/features/screens.dart';

class MockCloudGateway implements CloudGateway {
  final _authController = StreamController<String?>.broadcast();
  final Map<String, CloudProfile> userProfiles = {};
  final Set<String> registeredEmails = {};
  final Map<String, String> credentials = {}; // email -> password
  @override
  String? currentUid;
  String? lastResetEmail;
  bool updateProfileCalled = false;
  @override
  Stream<String?> get authChanges => _authController.stream;

  @override
  Future<CloudProfile?> profile(String uid) async => userProfiles[uid];

  @override
  Future<void> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (credentials[cleanEmail] != password) {
      throw Exception('INVALID_LOGIN_CREDENTIALS');
    }
    // find uid
    for (final entry in userProfiles.entries) {
      if (entry.value.email.toLowerCase() == cleanEmail) {
        currentUid = entry.key;
        _authController.add(currentUid);
        return;
      }
    }
    throw Exception('USER_NOT_FOUND');
  }

  @override
  Future<void> signOut() async {
    currentUid = null;
    _authController.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    lastResetEmail = email.trim();
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {}

  @override
  Future<List<CloudClient>> clients(String uid) async {
    if (uid == 'pt_active') {
      return [
        const CloudClient('c1', 'Client Alpha'),
        const CloudClient('c2', 'Client Beta'),
      ];
    }
    return [];
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
    final existing = userProfiles[uid];
    if (existing == null) throw Exception('Profile not found');
    updateProfileCalled = true;
    userProfiles[uid] = CloudProfile(
      uid,
      displayName,
      existing.active,
      email: existing.email,
      phone: phone,
      role: existing.role,
      status: existing.status,
      heightCm: heightCm ?? existing.heightCm,
      weightKg: weightKg ?? existing.weightKg,
      specialization: specialization ?? existing.specialization,
      experienceYears: experienceYears ?? existing.experienceYears,
      certifications: certifications ?? existing.certifications,
      bio: bio ?? existing.bio,
      photoUrl: photoUrl ?? existing.photoUrl,
    );
  }

  void dispose() {
    _authController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCloudGateway gateway;

  setUp(() {
    gateway = MockCloudGateway();
    gateway.credentials['pt.active@mboisgym.com'] = 'Password123!';
    gateway.credentials['pt.inactive@mboisgym.com'] = 'Password123!';
    gateway.userProfiles['pt_active'] = const CloudProfile(
      'pt_active',
      'Coach Ahmad Faril',
      true,
      email: 'pt.active@mboisgym.com',
      phone: '08123456789',
      role: 'trainer',
    );
    gateway.userProfiles['pt_inactive'] = const CloudProfile(
      'pt_inactive',
      'Coach Inactive',
      false,
      email: 'pt.inactive@mboisgym.com',
      phone: '08987654321',
      role: 'trainer',
    );
  });

  tearDown(() {
    gateway.dispose();
  });

  group('CloudAuthNotifier Unit Tests', () {
    test('active manager can login without trainer-only rejection', () async {
      gateway.credentials['manager@mboisgym.com'] = 'Password123!';
      gateway.userProfiles['manager'] = const CloudProfile(
        'manager', 'Manager', true,
        email: 'manager@mboisgym.com', role: 'manager',
      );
      final container = ProviderContainer(overrides: [
        cloudGatewayProvider.overrideWith((ref) => gateway),
      ]);
      addTearDown(container.dispose);
      final error = await container.read(cloudAuthProvider.notifier)
          .login('manager@mboisgym.com', 'Password123!');
      expect(error, isNull);
      expect(container.read(cloudAuthProvider).value?.role, 'manager');
    });

    test('unknown active role cannot authenticate', () async {
      gateway.credentials['other@mboisgym.com'] = 'Password123!';
      gateway.userProfiles['other'] = const CloudProfile(
        'other', 'Other', true, email: 'other@mboisgym.com', role: 'owner',
      );
      final container = ProviderContainer(overrides: [
        cloudGatewayProvider.overrideWith((ref) => gateway),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(cloudAuthProvider.notifier)
          .login('other@mboisgym.com', 'Password123!'), isNotNull);
      expect(gateway.currentUid, isNull);
    });

    test('active PT login succeeds and sets CloudProfile state', () async {
      final container = ProviderContainer(
        overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudAuthProvider.notifier);
      final error = await notifier.login(
        'pt.active@mboisgym.com',
        'Password123!',
      );

      expect(error, isNull);
      final state = container.read(cloudAuthProvider).value;
      expect(state, isNotNull);
      expect(state?.uid, 'pt_active');
      expect(state?.name, 'Coach Ahmad Faril');
      expect(state?.active, isTrue);
    });

    test(
      'inactive PT login triggers inactive denial and rejects access',
      () async {
        final container = ProviderContainer(
          overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(cloudAuthProvider.notifier);
        final error = await notifier.login(
          'pt.inactive@mboisgym.com',
          'Password123!',
        );

        expect(error, isNotNull);
        expect(error, contains('belum aktif'));
        final state = container.read(cloudAuthProvider).value;
        expect(state, isNull);
        expect(gateway.currentUid, isNull); // Ensures signed out immediately
      },
    );

    test(
      'wrong password returns error message and leaves session null',
      () async {
        final container = ProviderContainer(
          overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(cloudAuthProvider.notifier);
        final error = await notifier.login(
          'pt.active@mboisgym.com',
          'WrongPass!',
        );

        expect(error, isNotNull);
        expect(error, contains('Email atau password salah'));
        expect(container.read(cloudAuthProvider).value, isNull);
      },
    );

    test('resetPassword sends request via gateway', () async {
      final container = ProviderContainer(
        overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudAuthProvider.notifier);
      final msg = await notifier.resetPassword('pt.active@mboisgym.com');

      expect(msg, contains('reset'));
      expect(gateway.lastResetEmail, 'pt.active@mboisgym.com');
    });

    test('logout clears cloud authentication state', () async {
      final container = ProviderContainer(
        overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudAuthProvider.notifier);
      await notifier.login('pt.active@mboisgym.com', 'Password123!');
      expect(container.read(cloudAuthProvider).value, isNotNull);

      await notifier.logout();
      expect(container.read(cloudAuthProvider).value, isNull);
      expect(gateway.currentUid, isNull);
    });

    test('profile supports optional professional fields without losing admin fields', () {
      const legacy = CloudProfile('legacy', 'Coach', true);
      expect(legacy.heightCm, isNull);
      expect(legacy.specialization, isEmpty);
      const rich = CloudProfile('rich', 'Coach', true,
        heightCm: 178, weightKg: 72.5, specialization: 'Strength',
        experienceYears: 5, certifications: 'NASM', bio: 'Coach',
        photoUrl: 'https://example.org/photo.jpg', status: 'active',
        role: 'manager');
      expect(rich.weightKg, 72.5);
      expect(rich.typedRole, CloudRole.manager);
      expect(rich.status, 'active');
    });

    test('updateProfile allows editing personal professional fields but keeps administrative status and role unchanged', () async {
      final container = ProviderContainer(
        overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudAuthProvider.notifier);
      await notifier.login('pt.active@mboisgym.com', 'Password123!');

      final err = await notifier.updateProfile(
        displayName: 'Coach Ahmad Faril Pro',
        phone: '08555123456',
        heightCm: 180,
        weightKg: 75,
        specialization: 'Hypertrophy & Fat Loss',
        experienceYears: 6,
        certifications: 'APKI Certified',
        bio: 'Dedicated personal trainer.',
      );
      expect(err, isNull);
      final state = container.read(cloudAuthProvider).value;
      expect(state?.name, 'Coach Ahmad Faril Pro');
      expect(state?.heightCm, 180);
      expect(state?.weightKg, 75);
      expect(state?.specialization, 'Hypertrophy & Fat Loss');
      expect(state?.experienceYears, 6);
      expect(state?.certifications, 'APKI Certified');
      expect(state?.bio, 'Dedicated personal trainer.');
      expect(state?.role, 'trainer');
      expect(state?.status, 'active');
    });

    test('updateProfile updates Firestore profile fields', () async {
      final container = ProviderContainer(
        overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudAuthProvider.notifier);
      await notifier.login('pt.active@mboisgym.com', 'Password123!');

      final err = await notifier.updateProfile(
        displayName: 'Coach Ahmad Faril Updated',
        phone: '08555123456',
      );
      expect(err, isNull);
      expect(gateway.updateProfileCalled, isTrue);
      final state = container.read(cloudAuthProvider).value;
      expect(state?.name, 'Coach Ahmad Faril Updated');
      expect(state?.phone, '08555123456');
    });
  });

  group('Widget Tests with True Firebase Auth', () {
    testWidgets(
      'LoginScreen shows brand UI, handles reset password, and blocks inactive PT',
      (tester) async {
        final container = ProviderContainer(
          overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verify brand UI
        expect(find.text('WELCOME BACK,\nCOACH'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Log In'), findsOneWidget);
        expect(find.text('Lupa Password?'), findsOneWidget);
        expect(find.textContaining('Arsip'), findsOneWidget);

        // Attempt inactive login
        await tester.enterText(
          find.widgetWithText(AppCustomTextField, 'Email'),
          'pt.inactive@mboisgym.com',
        );
        await tester.enterText(
          find.widgetWithText(AppCustomTextField, 'Password'),
          'Password123!',
        );
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        // Check inactive denial message displayed
        expect(find.textContaining('belum aktif'), findsOneWidget);
      },
    );

    testWidgets(
      'ProfileScreen displays Cloud PT details, edit profile, and logout',
      (tester) async {
        final container = ProviderContainer(
          overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
        );
        addTearDown(container.dispose);

        // Log in active PT first
        await container
            .read(cloudAuthProvider.notifier)
            .login('pt.active@mboisgym.com', 'Password123!');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profil & Pengaturan Coach'), findsOneWidget);
        expect(find.text('Coach Ahmad Faril'), findsOneWidget);
        expect(find.text('pt.active@mboisgym.com'), findsOneWidget);
        expect(find.text('08123456789'), findsOneWidget);
        expect(find.text('EDIT PROFIL'), findsOneWidget);
        expect(find.textContaining('Arsip'), findsOneWidget);

        // Scroll to logout
        await tester.scrollUntilVisible(find.text('LOGOUT COACH'), 300);
        expect(find.text('LOGOUT COACH'), findsOneWidget);
      },
    );

    testWidgets(
      'ProfileScreen displays professional fields and keeps role/status read-only in edit dialog',
      (tester) async {
        gateway.credentials['pt.pro@mboisgym.com'] = 'Password123!';
        gateway.userProfiles['pt_pro'] = const CloudProfile(
          'pt_pro',
          'Coach Professional',
          true,
          email: 'pt.pro@mboisgym.com',
          phone: '08111222333',
          role: 'trainer',
          status: 'active',
          heightCm: 175,
          weightKg: 70,
          specialization: 'Bodybuilding',
          experienceYears: 4,
          certifications: 'CSCS',
          bio: 'Passionate about strength.',
        );

        final container = ProviderContainer(
          overrides: [cloudGatewayProvider.overrideWith((ref) => gateway)],
        );
        addTearDown(container.dispose);

        await container
            .read(cloudAuthProvider.notifier)
            .login('pt.pro@mboisgym.com', 'Password123!');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verify professional fields displayed
        expect(find.textContaining('Bodybuilding'), findsOneWidget);
        expect(find.textContaining('175'), findsOneWidget);
        expect(find.textContaining('70'), findsOneWidget);
        expect(find.textContaining('CSCS'), findsOneWidget);

        // Tap EDIT PROFIL
        await tester.ensureVisible(find.text('EDIT PROFIL'));
        await tester.tap(find.text('EDIT PROFIL'));
        await tester.pumpAndSettle();

        // Check dialog contains editable personal fields and read-only administrative indicators
        expect(find.text('Spesialisasi'), findsOneWidget);
        expect(find.text('Tinggi Badan (cm)'), findsOneWidget);
        expect(find.text('Berat Badan (kg)'), findsOneWidget);
        expect(find.textContaining('Peran Administratif'), findsOneWidget);
        expect(find.textContaining('Status Akun'), findsOneWidget);

        // Enter new specialization and bio
        final specFinder = find.widgetWithText(TextFormField, 'Spesialisasi');
        await tester.enterText(specFinder, 'Powerlifting & Mobility');

        await tester.tap(find.text('Simpan Perubahan'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Powerlifting & Mobility'), findsOneWidget);
      },
    );
  });
}
