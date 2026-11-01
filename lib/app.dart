import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_database.dart';
import 'data/gym_repository.dart';
import 'cloud/cloud_pilot.dart';
import 'cloud/cloud_session.dart';
import 'cloud/firebase_cloud_gateway.dart';
import 'design_system/app_design_system.dart';
import 'features/screens.dart';
import 'features/manager_dashboard_screen.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(),
);

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  if (Firebase.apps.isNotEmpty) {
    final authProfile = ref.watch(cloudAuthProvider).value;
    if (authProfile != null) {
      try {
        return FirestoreGymRepository(
          firestore: FirebaseFirestore.instance,
          auth: FirebaseAuth.instance,
        );
      } catch (_) {}
    }
  }
  final db = ref.watch(databaseProvider);
  return SqliteGymRepository(db);
});

class _OfflineCloudGateway implements CloudGateway {
  const _OfflineCloudGateway();

  @override
  Stream<String?> get authChanges => const Stream.empty();

  @override
  String? get currentUid => null;

  @override
  Future<CloudProfile?> profile(String uid) async => null;

  @override
  Future<void> signIn(String email, String password) async =>
      throw StateError('Firebase tidak tersedia pada lingkungan ini.');
      

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {}

  @override
  Future<List<CloudClient>> clients(String uid) async => const [];

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

final cloudGatewayProvider = FutureProvider<CloudGateway>((ref) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(milliseconds: 300));
    }
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    return FirebaseCloudGateway(auth, firestore);
  } catch (_) {
    return const _OfflineCloudGateway();
  }
});

class CloudAuthController extends AsyncNotifier<CloudProfile?> {
  @override
  Future<CloudProfile?> build() async {
    try {
      final gateway = await ref.watch(cloudGatewayProvider.future);
      final uid = await gateway.authChanges.first.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => null,
      );
      if (uid == null) return null;
      final profile = await gateway.profile(uid);
      if (profile != null && profile.canAccess) {
        return profile;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> login(String email, String password) async {
    state = const AsyncLoading();
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || password.isEmpty) {
      state = const AsyncData(null);
      return 'Email valid dan password wajib diisi.';
    }
    try {
      final gateway = await ref.read(cloudGatewayProvider.future);
      await gateway.signIn(cleanEmail, password);
      final uid =
          gateway.currentUid ??
          await gateway.authChanges.first.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () => null,
          );
      if (uid == null) {
        state = const AsyncData(null);
        return 'Gagal memverifikasi sesi login Firebase.';
      }
      final profile = await gateway.profile(uid);
      if (profile == null) {
        await gateway.signOut();
        state = const AsyncData(null);
        return 'Profil Coach tidak ditemukan di Firestore users/$uid. Hubungi administrator.';
      }
      if (profile.typedRole == null) {
        await gateway.signOut();
        state = const AsyncData(null);
        return 'Akses ditolak: Peran akun tidak dikenal.';
      }
      if (!profile.active) {
        await gateway.signOut();
        state = const AsyncData(null);
        return 'Akun Coach Anda belum aktif atau dinonaktifkan oleh administrator. Akses cloud ditolak.';
      }
      state = AsyncData(profile);
      return null;
    } catch (e) {
      state = const AsyncData(null);
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid') ||
          msg.contains('wrong') ||
          msg.contains('credential') ||
          msg.contains('user-not-found')) {
        return 'Email atau password salah. Periksa kembali akun Anda.';
      }
      if (msg.contains('network') || msg.contains('unavailable')) {
        return 'Koneksi jaringan gagal. Periksa koneksi internet Anda.';
      }
      return 'Gagal masuk: Periksa kembali email dan password.';
    }
  }

  Future<String> resetPassword(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Masukkan email valid terlebih dahulu.';
    }
    try {
      final gateway = await ref.read(cloudGatewayProvider.future);
      await gateway.resetPassword(cleanEmail);
    } catch (_) {}
    return 'Jika email terdaftar, tautan reset password telah dikirim ke email Anda.';
  }

  Future<void> logout() async {
    try {
      final gateway = await ref.read(cloudGatewayProvider.future);
      await gateway.signOut();
    } catch (_) {}
    state = const AsyncData(null);
  }

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
    final current = state.value;
    if (current == null) return 'Sesi tidak ditemukan.';
    if (displayName.trim().isEmpty) return 'Nama tidak boleh kosong.';
    try {
      final gateway = await ref.read(cloudGatewayProvider.future);
      await gateway.updateProfile(
        uid: current.uid,
        displayName: displayName.trim(),
        phone: phone.trim(),
        heightCm: heightCm,
        weightKg: weightKg,
        specialization: specialization,
        experienceYears: experienceYears,
        certifications: certifications,
        bio: bio,
        photoUrl: photoUrl,
      );
      final updated = CloudProfile(
        current.uid,
        displayName.trim(),
        current.active,
        email: current.email,
        phone: phone.trim(),
        role: current.role,
        status: current.status,
        heightCm: heightCm ?? current.heightCm,
        weightKg: weightKg ?? current.weightKg,
        specialization: specialization ?? current.specialization,
        experienceYears: experienceYears ?? current.experienceYears,
        certifications: certifications ?? current.certifications,
        bio: bio ?? current.bio,
        photoUrl: photoUrl ?? current.photoUrl,
      );
      state = AsyncData(updated);
      return null;
    } catch (e) {
      return 'Gagal memperbarui profil di Firestore: ${e.toString()}';
    }
  }
}

final cloudAuthProvider =
    AsyncNotifierProvider<CloudAuthController, CloudProfile?>(
      CloudAuthController.new,
    );

final authProvider = AsyncNotifierProvider<AuthController, int?>(
  AuthController.new,
);
final themeProvider = AsyncNotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RiverpodRefresh(ref);
  final router = _createRouter(ref, refresh);
  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });
  return router;
});

GoRouter _createRouter(Ref ref, Listenable refresh) => GoRouter(
  initialLocation: '/splash',
  refreshListenable: refresh,
  redirect: (context, state) {
    final cloudAuth = ref.read(cloudAuthProvider);
    final auth = ref.read(authProvider);
    if (cloudAuth.isLoading || auth.isLoading) {
      return state.matchedLocation == '/splash' ? null : '/splash';
    }
    final loggedIn = cloudAuth.value != null || auth.value != null;
    final isAllowedSignedOut = {
      '/login',
      '/setup',
      '/legacy-archive',
      '/cloud-pilot',
    }.contains(state.matchedLocation);
    if (!loggedIn && !isAllowedSignedOut) {
      return '/login';
    }
    if (loggedIn &&
        {'/login', '/setup', '/splash'}.contains(state.matchedLocation)) {
      return '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
    GoRoute(
      path: '/legacy-archive',
      builder: (context, state) => const LegacyArchiveScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              final cloudProfile = ref.watch(cloudAuthProvider).value;
              if (cloudProfile != null && cloudProfile.isManager) {
                return const ManagerDashboardScreen();
              }
              return const DashboardScreen();
            },
          ),
        ),
        GoRoute(
          path: '/manager-dashboard',
          builder: (context, state) => const ManagerDashboardScreen(),
        ),
        GoRoute(
          path: '/clients',
          builder: (context, state) => const ClientListScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/cloud-pilot',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final gateway = ref.watch(cloudGatewayProvider);
          return gateway.when(
            data: (value) => CloudPilot(gateway: value),
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text(
                  'Firebase tidak tersedia pada perangkat ini. Data lokal tetap aman.',
                ),
              ),
            ),
          );
        },
      ),
    ),
    GoRoute(
      path: '/clients/new',
      builder: (context, state) => const ClientFormScreen(),
    ),
    GoRoute(
      path: '/clients/:id',
      builder: (context, state) =>
          ClientDetailScreen(clientId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/clients/:id/workout',
      builder: (context, state) {
        final clientId = int.parse(state.pathParameters['id']!);
        final logIdStr = state.uri.queryParameters['logId'];
        final logId = logIdStr != null ? int.tryParse(logIdStr) : null;
        return WorkoutEditorScreen(clientId: clientId, logId: logId);
      },
    ),
  ],
);

abstract interface class AuthStorage {
  Future<String?> readTrainerId();
  Future<void> writeTrainerId(String value);
  Future<void> deleteTrainerId();
}

class SecureAuthStorage implements AuthStorage {
  const SecureAuthStorage();
  static const storage = FlutterSecureStorage();
  @override
  Future<String?> readTrainerId() => storage.read(key: 'trainer_id');
  @override
  Future<void> writeTrainerId(String value) =>
      storage.write(key: 'trainer_id', value: value);
  @override
  Future<void> deleteTrainerId() => storage.delete(key: 'trainer_id');
}

final authStorageProvider = Provider<AuthStorage>(
  (ref) => const SecureAuthStorage(),
);

class AuthController extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    try {
      final id = int.tryParse(
        await ref.read(authStorageProvider).readTrainerId() ?? '',
      );
      if (id == null) return null;
      final db = ref.read(databaseProvider);
      final trainer = await (db.select(
        db.trainers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (trainer != null) return id;
      await ref.read(authStorageProvider).deleteTrainerId();
    } catch (_) {}
    return null;
  }

  Future<String?> login(String email, String password) async {
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    final trainer =
        await (db.select(db.trainers)
              ..where((u) => u.email.equals(email.trim().toLowerCase())))
            .getSingleOrNull();
    if (trainer == null ||
        !await verifyPassword(
          password,
          trainer.passwordSalt,
          trainer.passwordHash,
        )) {
      state = const AsyncData(null);
      return 'Email atau password salah';
    }
    try {
      await ref.read(authStorageProvider).writeTrainerId('${trainer.id}');
      state = AsyncData(trainer.id);
      return null;
    } catch (_) {
      state = const AsyncData(null);
      return 'Sesi tidak dapat disimpan dengan aman';
    }
  }

  Future<String?> setup(String name, String email, String password) async {
    if (name.trim().isEmpty || !email.contains('@') || password.length < 8) {
      return 'Nama, email valid, dan password minimal 8 karakter wajib diisi';
    }
    final db = ref.read(databaseProvider);
    if (await db.select(db.trainers).get().then((v) => v.isNotEmpty)) {
      return 'Akun PT lokal sudah tersedia';
    }
    final secured = await hashPassword(password);
    final id = await db
        .into(db.trainers)
        .insert(
          TrainersCompanion.insert(
            name: name.trim(),
            email: email.trim().toLowerCase(),
            passwordSalt: secured.$1,
            passwordHash: secured.$2,
          ),
        );
    try {
      await ref.read(authStorageProvider).writeTrainerId('$id');
      state = AsyncData(id);
      return null;
    } catch (_) {
      state = const AsyncData(null);
      return 'Akun tersimpan, tetapi sesi aman gagal disimpan';
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(authStorageProvider).deleteTrainerId();
    } catch (_) {}
    state = const AsyncData(null);
  }
}

class ThemeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final value =
        (await SharedPreferences.getInstance()).getString('theme_mode') ??
        'system';
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString('theme_mode', mode.name);
    if (!ok) throw StateError('Gagal menyimpan preferensi tema');
    state = AsyncData(mode);
  }
}

Future<(String, String)> hashPassword(
  String password, [
  String? encodedSalt,
]) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );
  final salt = encodedSalt == null
      ? SecretKey(List<int>.generate(16, (_) => Random.secure().nextInt(256)))
      : SecretKey(base64Decode(encodedSalt));
  final saltBytes = await salt.extractBytes();
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: saltBytes,
  );
  return (base64Encode(saltBytes), base64Encode(await key.extractBytes()));
}

Future<bool> verifyPassword(
  String password,
  String salt,
  String expected,
) async => (await hashPassword(password, salt)).$2 == expected;

class MboisApp extends ConsumerWidget {
  const MboisApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider).value ?? ThemeMode.system;
    final router = ref.watch(routerProvider);
    const seed = Color(0xFF192126);
    return MaterialApp.router(
      title: 'Mbois Gym PT',
      debugShowCheckedModeBanner: false,
      themeMode: theme,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF73D8CF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _RiverpodRefresh extends ChangeNotifier {
  _RiverpodRefresh(Ref ref) {
    _sub1 = ref.listen<AsyncValue<int?>>(
      authProvider,
      (_, _) => notifyListeners(),
    );
    _sub2 = ref.listen<AsyncValue<CloudProfile?>>(
      cloudAuthProvider,
      (_, _) => notifyListeners(),
    );
  }
  late final ProviderSubscription<AsyncValue<int?>> _sub1;
  late final ProviderSubscription<AsyncValue<CloudProfile?>> _sub2;

  @override
  void dispose() {
    _sub1.close();
    _sub2.close();
    super.dispose();
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = path.startsWith('/clients')
        ? 1
        : path.startsWith('/settings')
        ? 2
        : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: index,
        onTap: (i) => context.go(['/dashboard', '/clients', '/settings'][i]),
      ),
    );
  }
}