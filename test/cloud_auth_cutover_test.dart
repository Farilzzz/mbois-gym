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
  Future<void> signUp(String email, String password, String name) async {
    // Implementasi dummy untuk melewati error testing
  }
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
  });
}
