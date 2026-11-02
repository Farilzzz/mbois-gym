import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mbois_gym_pt/app.dart';
import 'package:mbois_gym_pt/cloud/cloud_session.dart';
import 'package:mbois_gym_pt/design_system/app_design_system.dart';
import 'package:mbois_gym_pt/features/manager_profile_screen.dart';
import 'package:mbois_gym_pt/widgets/initial_avatar.dart';

const kTestManager = CloudProfile(
  'manager-uid-1',
  'Maya Manager',
  true,
  email: 'maya@example.com',
  phone: '+628123456789',
  role: 'manager',
  heightCm: 170,
  weightKg: 65,
  specialization: 'Private Trainer Data',
  certifications: 'Secret Cert',
  bio: 'Private Bio',
);

const kTestTrainer = CloudProfile(
  'trainer-uid-1',
  'Tommy Trainer',
  true,
  email: 'tommy@example.com',
  phone: '+628987654321',
  role: 'trainer',
);

class MockManagerAuthController extends CloudAuthController {
  CloudProfile? profile;
  Object? buildError;
  String? updatedDisplayName;
  String? updatedPhone;
  String? resetPasswordEmailRequested;
  bool logoutCalled = false;
  String? updateProfileErrorResult;
  bool throwOnUpdate = false;
  bool throwOnReset = false;

  MockManagerAuthController({this.profile = kTestManager, this.buildError});

  @override
  Future<CloudProfile?> build() async {
    if (buildError != null) throw buildError!;
    return profile;
  }

  @override
  Future<String?> updateProfile({
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
    updatedDisplayName = displayName;
    updatedPhone = phone;
    if (throwOnUpdate) throw Exception('Network timeout during update');
    if (updateProfileErrorResult != null) return updateProfileErrorResult;

    if (profile != null) {
      profile = CloudProfile(
        profile!.uid,
        displayName,
        profile!.active,
        email: profile!.email,
        phone: phone,
        role: profile!.role,
        status: profile!.status,
      );
      state = AsyncData(profile);
    }
    return null;
  }

  @override
  Future<String> resetPassword(String email) async {
    resetPasswordEmailRequested = email;
    if (throwOnReset) throw Exception('Auth server unavailable');
    return 'Tautan reset password telah dikirim ke $email.';
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    profile = null;
    state = const AsyncData(null);
  }
}

Future<void> pumpManagerProfile(
  WidgetTester tester, {
  required MockManagerAuthController authController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [cloudAuthProvider.overrideWith(() => authController)],
      child: const MaterialApp(home: ManagerProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ManagerProfileScreen Presentation', () {
    testWidgets(
      'shows manager identity without physical stats or trainer menus or photo upload',
      (tester) async {
        final auth = MockManagerAuthController();
        await pumpManagerProfile(tester, authController: auth);

        expect(find.text('Maya Manager'), findsWidgets);
        expect(find.text('maya@example.com'), findsOneWidget);
        expect(find.text('Manager'), findsWidgets);
        expect(find.byType(InitialAvatar), findsOneWidget);

        // Verify no physical stats
        expect(find.textContaining('Tinggi'), findsNothing);
        expect(find.textContaining('Berat'), findsNothing);
        expect(find.textContaining('BMI'), findsNothing);
        expect(find.textContaining('170'), findsNothing);
        expect(find.textContaining('65'), findsNothing);

        // Verify no trainer menus or private trainer fields
        expect(find.textContaining('Private Trainer Data'), findsNothing);
        expect(find.textContaining('Secret Cert'), findsNothing);
        expect(find.textContaining('Private Bio'), findsNothing);
        expect(find.textContaining('Spesialisasi'), findsNothing);
        expect(find.textContaining('Sertifikasi'), findsNothing);
        expect(find.textContaining('Pengalaman'), findsNothing);
        expect(find.textContaining('Klien'), findsNothing);
        expect(find.textContaining('Jadwal'), findsNothing);

        // Verify no photo upload controls
        expect(find.byIcon(Icons.camera_alt), findsNothing);
        expect(find.byIcon(Icons.photo_camera), findsNothing);
        expect(find.textContaining('Upload Foto'), findsNothing);
        expect(find.textContaining('Foto Profil'), findsNothing);
      },
    );

    testWidgets(
      'safe error UI when provider fails to load (no raw exception UI)',
      (tester) async {
        final auth = MockManagerAuthController(
          buildError: Exception('Fatal db connection failed'),
        );
        await pumpManagerProfile(tester, authController: auth);

        expect(find.textContaining('Fatal db connection failed'), findsNothing);
        expect(
          find.textContaining('Gagal memuat profil manager'),
          findsOneWidget,
        );
      },
    );
  });

  group('Manager Profile Actions', () {
    testWidgets(
      'edit name button opens dialog, updates displayName, and preserves phone',
      (tester) async {
        final auth = MockManagerAuthController();
        await pumpManagerProfile(tester, authController: auth);

        // Tap the Edit Name button
        final editButton = find.widgetWithText(OutlinedButton, 'Edit Nama');
        expect(editButton, findsOneWidget);
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // Dialog is displayed with current name prefilled
        expect(find.text('Edit Nama Manager'), findsOneWidget);
        final textField = find.byType(TextFormField);
        expect(textField, findsOneWidget);

        await tester.enterText(textField, 'Maya Super Manager');
        await tester.pumpAndSettle();

        // Submit dialog
        final saveButton = find.widgetWithText(FilledButton, 'Simpan');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Verify updateProfile was called with new name and PRESERVED phone
        expect(auth.updatedDisplayName, 'Maya Super Manager');
        expect(auth.updatedPhone, '+628123456789');

        // Verify success snackbar appears
        expect(find.text('Nama profil berhasil diperbarui.'), findsOneWidget);
        // Verify updated name displays in UI
        expect(find.text('Maya Super Manager'), findsWidgets);
      },
    );

    testWidgets(
      'reset password button calls resetPassword with email and shows snackbar',
      (tester) async {
        final auth = MockManagerAuthController();
        await pumpManagerProfile(tester, authController: auth);

        final resetButton = find.widgetWithText(FilledButton, 'Reset Password');
        await tester.ensureVisible(resetButton);
        expect(resetButton, findsOneWidget);
        await tester.tap(resetButton);
        await tester.pumpAndSettle();

        // Confirmation dialog opens
        expect(find.text('Konfirmasi Reset Password'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('maya@example.com'),
          ),
          findsOneWidget,
        );

        // Tap Kirim on confirmation dialog
        final sendButton = find.widgetWithText(FilledButton, 'Kirim Tautan');
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        expect(auth.resetPasswordEmailRequested, 'maya@example.com');
        expect(
          find.textContaining('Tautan reset password telah dikirim'),
          findsOneWidget,
        );
      },
    );

    testWidgets('logout button prompts confirmation and invokes logout()', (
      tester,
    ) async {
      final auth = MockManagerAuthController();
      await pumpManagerProfile(tester, authController: auth);

      final logoutButton = find.widgetWithText(
        ElevatedButton,
        'Keluar dari Akun',
      );
      await tester.ensureVisible(logoutButton);
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Logout'), findsOneWidget);
      final confirmLogoutButton = find.widgetWithText(FilledButton, 'Keluar');
      await tester.tap(confirmLogoutButton);
      await tester.pumpAndSettle();

      expect(auth.logoutCalled, isTrue);
    });

    testWidgets(
      'edit name failure displays safe error and leaves dialog open',
      (tester) async {
        final auth = MockManagerAuthController();
        auth.updateProfileErrorResult = 'Sistem sedang sibuk';
        await pumpManagerProfile(tester, authController: auth);

        final editButton = find.widgetWithText(OutlinedButton, 'Edit Nama');
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'New Manager Name');
        await tester.pumpAndSettle();

        final saveButton = find.widgetWithText(FilledButton, 'Simpan');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Dialog is still open with safe error
        expect(find.text('Edit Nama Manager'), findsOneWidget);
        expect(find.textContaining('Gagal memperbarui nama'), findsOneWidget);
        expect(find.textContaining('Exception'), findsNothing);
      },
    );

    testWidgets('reset password failure displays safe error snackbar', (
      tester,
    ) async {
      final auth = MockManagerAuthController();
      auth.throwOnReset = true;
      await pumpManagerProfile(tester, authController: auth);

      final resetButton = find.widgetWithText(FilledButton, 'Reset Password');
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(FilledButton, 'Kirim Tautan');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Safe error snackbar
      expect(
        find.textContaining('Gagal mengirim tautan reset password'),
        findsOneWidget,
      );
      expect(find.textContaining('Auth server unavailable'), findsNothing);
    });
  });

  group('Navigation & AppShell Integration', () {
    testWidgets(
      '/settings route renders ManagerProfileScreen when authenticated user is manager',
      (tester) async {
        final auth = MockManagerAuthController(profile: kTestManager);
        final router = GoRouter(
          initialLocation: '/settings',
          routes: [
            ShellRoute(
              builder: (context, state, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => Consumer(
                    builder: (context, ref, _) {
                      final profile = ref.watch(cloudAuthProvider).value;
                      if (profile != null && profile.isManager) {
                        return const ManagerProfileScreen();
                      }
                      return const Scaffold(body: Text('Fallback Screen'));
                    },
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [cloudAuthProvider.overrideWith(() => auth)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManagerProfileScreen), findsOneWidget);
        expect(find.text('Fallback Screen'), findsNothing);
        expect(find.byType(AppBottomNavigation), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Profil'), findsOneWidget);
        expect(find.text('client'), findsNothing);
      },
    );

    testWidgets(
      'AppShell shows two persistent tabs and routes between them for manager',
      (tester) async {
        final auth = MockManagerAuthController(profile: kTestManager);
        final router = GoRouter(
          initialLocation: '/settings',
          routes: [
            ShellRoute(
              builder: (context, state, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (_, _) => const ManagerProfileScreen(),
                ),
                GoRoute(
                  path: '/dashboard',
                  builder: (_, _) => const Scaffold(body: Text('Manager Home')),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [cloudAuthProvider.overrideWith(() => auth)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManagerProfileScreen), findsOneWidget);
        expect(find.byType(AppBottomNavigation), findsOneWidget);
        expect(find.text('client'), findsNothing);
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
        expect(find.text('Manager Home'), findsOneWidget);
        expect(find.text('Profil'), findsOneWidget);
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        expect(find.byType(ManagerProfileScreen), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets('AppShell displays bottom navbar for trainer', (tester) async {
      final auth = MockManagerAuthController(profile: kTestTrainer);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) =>
                    const Scaffold(body: Text('Trainer Settings')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cloudAuthProvider.overrideWith(() => auth)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNavigation), findsOneWidget);
    });
  });
}
