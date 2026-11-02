import 'package:drift/drift.dart' show Value, InsertMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../cloud/cloud_session.dart';
import '../data/exercise_api_service.dart';

import '../app.dart';
import '../data/app_database.dart';
import '../data/pt_packages.dart';
import '../widgets/dedicated_signature_dialog.dart';
import '../widgets/initial_avatar.dart';
import '../design_system/app_design_system.dart';

// Palette definitions matching Mbois Gym Figma
const kMboisDark = Color(0xFF192126);
const kMboisTeal = Color(0xFF0F8780);
const kMboisMint = Color(0xFFE0F4F0);
const kMboisLine = Color(0xFFD6E0DE);
const kMboisMuted = Color(0xFF667578);

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Image.asset(
                AppAssets.logoClean,
                width: 240,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Image.asset(
                  AppAssets.logo,
                  width: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.fitness_center,
                    color: AppColors.primaryRoyalBlue,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'GYM TRACKER APP',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textBlack,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              const CircularProgressIndicator(
                color: AppColors.primaryRoyalBlue,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await ref
        .read(cloudAuthProvider.notifier)
        .login(_email.text, _password.text);
    if (mounted) {
      setState(() {
        _loading = false;
        _error = err;
      });
      if (err == null) {
        context.go('/dashboard');
      }
    }
  }

  void _showResetPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _email.text.trim(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password Coach'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email PT yang terdaftar di Firebase untuk menerima tautan pemulihan kata sandi.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email PT',
                hintText: 'coach@mboisgym.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.vibrantBlue,
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              Navigator.pop(ctx);
              final msg = await ref
                  .read(cloudAuthProvider.notifier)
                  .resetPassword(email);
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            child: const Text('Kirim Link Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    AppAssets.logoClean,
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => Image.asset(
                      AppAssets.logo,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        Icons.fitness_center,
                        size: 56,
                        color: AppColors.primaryRoyalBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'WELCOME BACK,\nCOACH',
                  style: AppTypography.welcomeTitle.copyWith(
                    color: isDark ? Colors.white : AppColors.primaryRoyalBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Aplikasi Manajemen Klien & Latihan Personal Trainer',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: AppRadius.medium,
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                AppCustomTextField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  hintText: 'coach@mboisgym.com',
                  isDarkFill: true,
                ),
                const SizedBox(height: 16),
                AppCustomTextField(
                  label: 'Password',
                  controller: _password,
                  obscureText: true,
                  hintText: '••••••••',
                  isDarkFill: true,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _showResetPasswordDialog,
                    child: const Text(
                      'Lupa Password?',
                      style: TextStyle(
                        color: AppColors.vibrantBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppPillButton(
                  text: 'Log In',
                  isLoading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi, Coach';
    if (hour < 15) return 'Selamat Siang, Coach';
    if (hour < 18) return 'Selamat Sore, Coach';
    return 'Selamat Malam, Coach';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(gymRepositoryProvider);
    final trainerId = ref.watch(authProvider).value ?? 1;
    final cloudProfile = ref.watch(cloudAuthProvider).value;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Image.asset(
          AppAssets.logoClean,
          height: 34,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => const Text(
            'MBOIS GYM',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.primaryRoyalBlue,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifikasi',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada notifikasi baru.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined),
            tooltip: 'Bantuan & Dukungan',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hubungi admin Mbois Gym di info@mboisgym.com'),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () => context.go('/settings'),
              child: InitialAvatar(
                name: (cloudProfile?.name.trim().isNotEmpty == true &&
                        cloudProfile!.name.trim() != 'PT')
                    ? cloudProfile.name
                    : 'Coach Mbois',
                email: cloudProfile?.email,
                radius: 19,
                backgroundColor: AppColors.skyBlueSoft,
                foregroundColor: AppColors.vibrantBlue,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder(
        future: () async {
          final clients = await db.allClients(trainerId);
          final sessions = await db.allSessionsForTrainer(trainerId);
          final packages = await db.allPackagesForTrainer(trainerId);

          final activeList =
              <
                ({
                  Client client,
                  PtPackage pkg,
                  int remaining,
                  int totalSessions,
                })
              >[];
          for (final c in clients) {
            final lifecycle = await db.getClientLifecycleStatus(c.id);
            if (lifecycle == 'active') {
              final pkg = await db.currentPackage(c.id);
              if (pkg != null && pkg.status == 'active') {
                final completed = await db.completedCount(pkg.id);
                final remaining = pkg.totalSessions - completed;
                if (remaining > 0) {
                  activeList.add((
                    client: c,
                    pkg: pkg,
                    remaining: remaining,
                    totalSessions: pkg.totalSessions,
                  ));
                }
              }
            }
          }

          return (
            clients: clients,
            activeClients: activeList,
            sessions: sessions,
            packages: packages,
          );
        }(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final resolved = snapshot.data!;
          final activeClients = resolved.activeClients;
          final sessions = resolved.sessions;
          final packages = resolved.packages;
          final cloudName = cloudProfile?.name.trim();
          final resolvedTrainerName =
              (cloudName != null && cloudName.isNotEmpty && cloudName != 'PT')
                  ? cloudName
                  : 'Coach Mbois';
          final trainer = Trainer(
            id: trainerId,
            name: resolvedTrainerName,
            email: cloudProfile?.email ?? 'coach@mboisgym.com',
            phone: cloudProfile?.phone ?? '',
            passwordSalt: '',
            passwordHash: '',
          );

          final activePackages = activeClients.length;
          final closedPackages = packages
              .where((p) => p.status == 'closed')
              .length;
          final completedSessions = sessions
              .where((s) => s.status == 'completed')
              .length;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Coach Header / Greeting Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.large,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E262B), Color(0xFF13181C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTimeGreeting(),
                            style: const TextStyle(
                              color: AppColors.cyanAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trainer.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            trainer.email,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Metric cards
              Row(
                children: [
                  _MetricCard(
                    label: 'Klien Aktif',
                    value: '$activePackages',
                    color: AppColors.vibrantBlue,
                  ),
                  const SizedBox(width: 10),
                  _MetricCard(
                    label: 'Klien Selesai',
                    value: '$closedPackages',
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 10),
                  _MetricCard(
                    label: 'Sesi Selesai',
                    value: '$completedSessions',
                    color: AppColors.cyanAccent,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Active Clients Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Klien Aktif',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/clients'),
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (activeClients.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 8),
                          const Text('Belum ada klien aktif saat ini.'),
                          const SizedBox(height: 14),
                          AppDarkButton(
                            text: 'TAMBAH CLIENT BARU',
                            onPressed: () => context.push('/clients/new'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                ...activeClients
                    .take(4)
                    .map(
                      (ac) => AppClientCard(
                        name: ac.client.name,
                        sessionsRemaining: ac.remaining,
                        totalSessions: ac.totalSessions,
                        onTapDetail: () =>
                            context.push('/clients/${ac.client.id}'),
                      ),
                    ),
                const SizedBox(height: 12),
                AppDarkButton(
                  text: 'TAMBAH CLIENT BARU',
                  onPressed: () => context.push('/clients/new'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.medium,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});
  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(gymRepositoryProvider);
    final trainerId = ref.watch(authProvider).value ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daftar Klien',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kMboisTeal,
          labelColor: kMboisTeal,
          tabs: const [
            Tab(text: 'AKTIF'),
            Tab(text: 'SELESAI'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari nama klien...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Client>>(
              future: db.allClients(trainerId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!;
                final filtered = _query.isEmpty
                    ? all
                    : all
                          .where((c) => c.name.toLowerCase().contains(_query))
                          .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _ClientCategoryList(clients: filtered, activeOnly: true),
                    _ClientCategoryList(clients: filtered, activeOnly: false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/new'),
        backgroundColor: kMboisTeal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _ClientCategoryList extends ConsumerWidget {
  const _ClientCategoryList({required this.clients, required this.activeOnly});
  final List<Client> clients;
  final bool activeOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(gymRepositoryProvider);

    return FutureBuilder<List<(Client, PtPackage?, int, String)>>(
      future: Future.wait(
        clients.map((c) async {
          final lifecycle = await db.getClientLifecycleStatus(c.id);
          final pkg = await db.latestPackage(c.id);
          final completed = pkg != null ? await db.completedCount(pkg.id) : 0;
          return (c, pkg, completed, lifecycle);
        }),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!.where((item) {
          final lifecycle = item.$4;
          if (activeOnly) {
            return lifecycle == 'active';
          } else {
            // Tab Selesai: strictly completed clients whose full package sessions were finished
            return lifecycle == 'completed';
          }
        }).toList();

        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 56, color: kMboisMuted),
                  const SizedBox(height: 8),
                  Text(
                    activeOnly
                        ? 'Tidak ada klien aktif ditemukan.'
                        : 'Belum ada klien di riwayat/selesai.',
                    style: const TextStyle(color: kMboisMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final (c, pkg, completed, lifecycle) = items[index];
            final total = pkg?.totalSessions ?? 8;
            final isWaitingEvaluation =
                activeOnly && completed >= total;

            final (badgeText, badgeColor, badgeTextColor) = () {
              if (activeOnly) {
                if (isWaitingEvaluation) {
                  return (
                    'Menunggu Post PT',
                    Colors.orange.shade100,
                    Colors.orange.shade900,
                  );
                }
                return ('Aktif', kMboisMint, kMboisTeal);
              }
              // Tab Selesai: strictly completed packages
              return ('Selesai', Colors.grey.shade200, Colors.blueGrey);
            }();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InitialAvatar(
                          name: c.name,
                          radius: 22,
                          backgroundColor: badgeColor == Colors.red.shade100
                              ? Colors.red.shade200
                              : (activeOnly ? kMboisTeal : Colors.blueGrey),
                          foregroundColor: badgeColor == Colors.red.shade100
                              ? Colors.red.shade900
                              : Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Usia: ${c.age} thn • ${c.goal}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kMboisMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (pkg != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sesi: $completed / $total selesai',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${((completed / total) * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kMboisMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: total > 0 ? (completed / total) : 0,
                          minHeight: 8,
                          backgroundColor: kMboisLine,
                          color: activeOnly ? kMboisTeal : Colors.blueGrey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Buka Detail Klien'),
                        onPressed: () => context.push('/clients/${c.id}'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key});
  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _contact = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _goal = TextEditingController(text: 'Strength & Muscle Gain');
  final _medical = TextEditingController(text: 'Tidak ada');
  final _injury = TextEditingController(text: 'Tidak ada');
  final _notes = TextEditingController();
  PtPackageTier _selectedTier = PtPackageTier.tier10;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _contact.dispose();
    _height.dispose();
    _weight.dispose();
    _goal.dispose();
    _medical.dispose();
    _injury.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(gymRepositoryProvider);
    final trainerId = ref.read(authProvider).value ?? 1;

    try {
      final clientId = await db.addClient(
        trainerId: trainerId,
        name: _name.text,
        age: int.parse(_age.text),
        sessionsCount: _selectedTier.sessionsCount,
        contact: _contact.text,
        height: double.tryParse(_height.text),
        weight: double.tryParse(_weight.text),
        goal: _goal.text,
        medical: _medical.text,
        injury: _injury.text,
        notes: _notes.text,
      );

      // Catat transaksi penjualan paket resmi PT
      try {
        final currentCloudUser = ref.read(cloudAuthProvider).value;
        await db.recordPackageSale(
          PackageSaleRecord(
            id: 'sale_${DateTime.now().millisecondsSinceEpoch}_$clientId',
            clientId: clientId.toString(),
            clientName: _name.text.trim(),
            trainerId: currentCloudUser?.uid ?? 'pt_$trainerId',
            trainerName: currentCloudUser?.name ?? 'Coach',
            tierName: _selectedTier.name,
            sessionsCount: _selectedTier.sessionsCount,
            durationWeeks: _selectedTier.durationWeeks,
            price: _selectedTier.price,
            timestamp: DateTime.now(),
            status: 'valid',
          ),
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client dan Paket PT berhasil disimpan!'),
          ),
        );
        context.pushReplacement('/clients/$clientId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tambah Member Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            const Text(
              'Data Diri & Asesmen Awal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AppCustomTextField(
              label: 'Nama Lengkap Klien *',
              controller: _name,
              hintText: 'Masukkan nama klien',
              isDarkFill: true,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppCustomTextField(
                    label: 'Usia (tahun) *',
                    controller: _age,
                    keyboardType: TextInputType.number,
                    hintText: 'Contoh: 25',
                    isDarkFill: true,
                    validator: (v) => v == null || int.tryParse(v) == null
                        ? 'Usia valid wajib'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCustomTextField(
                    label: 'Kontak / No WA',
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    hintText: '08123456789',
                    isDarkFill: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppCustomTextField(
                    label: 'Tinggi (cm)',
                    controller: _height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    hintText: '175',
                    isDarkFill: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCustomTextField(
                    label: 'Berat Badan (kg)',
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    hintText: '70',
                    isDarkFill: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppCustomTextField(
              label: 'Tujuan Latihan',
              controller: _goal,
              hintText: 'Strength & Muscle Gain',
              isDarkFill: true,
            ),
            const SizedBox(height: 14),
            AppCustomTextField(
              label: 'Riwayat Sakit',
              controller: _medical,
              hintText: 'Tidak ada',
              isDarkFill: true,
            ),
            const SizedBox(height: 14),
            AppCustomTextField(
              label: 'Riwayat Cedera',
              controller: _injury,
              hintText: 'Tidak ada',
              isDarkFill: true,
            ),
            const SizedBox(height: 14),
            AppCustomTextField(
              label: 'Catatan Khusus Asesmen PT',
              controller: _notes,
              maxLines: 2,
              hintText: 'Catatan fleksibilitas, postur, dll.',
              isDarkFill: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilihan Paket Resmi Personal Training',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Column(
              children: PtPackageTier.officialTiers.map((tier) {
                final selected = _selectedTier.id == tier.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedTier = tier),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.vibrantBlue
                            : (isDark
                                  ? const Color(0xFF262C30)
                                  : AppColors.inputLightFill),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.vibrantBlue
                              : (isDark ? Colors.white24 : Colors.black12),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? Colors.white
                                : (isDark ? Colors.white54 : Colors.black45),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tier.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white
                                              : AppColors.textBlack),
                                  ),
                                ),
                                Text(
                                  'Durasi: ${tier.durationWeeks} Minggu (${tier.sessionsCount} Sesi)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Colors.white70
                                        : (isDark
                                              ? Colors.white60
                                              : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            tier.formattedPrice,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : AppColors.vibrantBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            AppDarkButton(
              text: 'TAMBAH & SIMPAN MEMBER',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});
  final int clientId;
  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshCount = 0;

  void _refresh() {
    setState(() => _refreshCount++);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(gymRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop(); // Kembali ke halaman sebelumnya jika ada riwayat
            } else {
              context.go(
                '/clients',
              ); // Paksa kembali ke menu Klien jika tidak ada riwayat
            }
          },
        ),

        title: const Text(
          'Detail Client PT',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: kMboisTeal,
          labelColor: kMboisTeal,
          tabs: const [
            Tab(text: 'Absensi'),
            Tab(text: 'List Exercise'),
            Tab(text: 'Log / History'),
            Tab(text: 'Post PT'),
            Tab(text: 'Asesmen'),
          ],
        ),
      ),

      body: FutureBuilder(
        key: ValueKey(_refreshCount),
        future: Future.wait([
          db.getClient(widget.clientId),
          db.currentPackage(widget.clientId),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final client = snapshot.data![0] as Client;
          final pkg = snapshot.data![1] as PtPackage?;

          if (pkg == null) {
            return const Center(
              child: Text('Paket PT belum dibuat untuk klien ini.'),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _AttendanceTab(client: client, package: pkg, onRefresh: _refresh),
              _ExerciseTab(client: client, package: pkg),
              _HistoryTab(client: client, package: pkg),
              _PostPtTab(client: client, package: pkg, onRefresh: _refresh),
              _AssessmentTab(client: client, onRefresh: _refresh),
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceTab extends ConsumerStatefulWidget {
  const _AttendanceTab({
    required this.client,
    required this.package,
    this.onRefresh,
  });
  final Client client;
  final PtPackage package;
  final VoidCallback? onRefresh;

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  String _selectedStatus = 'Aktif';

  Client get client => widget.client;
  PtPackage get package => widget.package;
  VoidCallback? get onRefresh => widget.onRefresh;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(gymRepositoryProvider);

    return FutureBuilder(
      future: Future.wait([
        db.packageSessions(package.id),
        db.completedCount(package.id),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data![0] as List<Session>;
        final completed = snapshot.data![1] as int;

        final completedCount = sessions
            .where((s) => s.status == 'completed')
            .length;
        final activeScheduledCount = sessions
            .where((s) => s.status == 'scheduled')
            .length;
        final availableSlots =
            (package.totalSessions - completedCount - activeScheduledCount)
                .clamp(0, package.totalSessions);
        final canSchedule = package.status == 'active' && availableSlots > 0;

        final List<Session> displayedSessions;
        if (_selectedStatus == 'Aktif') {
          displayedSessions = sessions
              .where((s) => s.status == 'scheduled')
              .toList();
        } else if (_selectedStatus == 'Hadir') {
          displayedSessions = sessions
              .where((s) => s.status == 'completed')
              .toList();
        } else if (_selectedStatus == 'Dibatalkan') {
          displayedSessions = sessions
              .where((s) => s.status == 'cancelled')
              .toList();
        } else {
          displayedSessions = sessions;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: kMboisDark,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Paket: ${package.totalSessions} Sesi • Selesai: $completed • Sisa: ${package.totalSessions - completed} Sesi',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${package.status.toUpperCase()}',
                      style: TextStyle(
                        color: package.status == 'active'
                            ? kMboisMint
                            : Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (package.status == 'active')
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.cancel_outlined,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Batalkan Paket',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Konfirmasi Batalkan Paket'),
                          content: const Text(
                            'Apakah Anda yakin ingin membatalkan paket PT ini? Paket yang dibatalkan tidak dapat digunakan lagi.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Ya, Batalkan Paket'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await db.closePackage(package.id);
                        onRefresh?.call();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Paket PT berhasil ditutup/dibatalkan.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.autorenew, size: 16),
                    label: const Text('Perpanjang Paket PT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMboisTeal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      int selectedSessions = 8;
                      final chosen = await showDialog<int>(
                        context: context,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setDialogState) => AlertDialog(
                            title: const Text('Perpanjang Paket PT'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pilih jumlah sesi untuk paket baru:',
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: selectedSessions,
                                  items: [
                                    ...PtPackageTier.officialTiers.map(
                                      (t) => DropdownMenuItem(
                                        value: t.sessionsCount,
                                        child: Text(
                                          '${t.name} (${t.durationWeeks} Mg) - ${t.formattedPrice}',
                                        ),
                                      ),
                                    ),
                                    if (!PtPackageTier.officialTiers.any(
                                      (t) =>
                                          t.sessionsCount == selectedSessions,
                                    ))
                                      DropdownMenuItem(
                                        value: selectedSessions,
                                        child: Text('$selectedSessions Sesi'),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setDialogState(
                                        () => selectedSessions = v,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kMboisTeal,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () =>
                                    Navigator.pop(ctx, selectedSessions),
                                child: const Text('Perpanjang'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (chosen != null) {
                        try {
                          await db.renewPackage(client.id, chosen);
                          final matchingTier = PtPackageTier.officialTiers
                              .firstWhere(
                                (t) => t.sessionsCount == chosen,
                                orElse: () => PtPackageTier(
                                  id: 'pt_pkg_$chosen',
                                  name: 'Paket $chosen Sesi',
                                  sessionsCount: chosen,
                                  durationWeeks: 4,
                                  price: chosen * 100000,
                                ),
                              );
                          try {
                            final currentCloudUser = ref
                                .read(cloudAuthProvider)
                                .value;
                            await db.recordPackageSale(
                              PackageSaleRecord(
                                id: 'sale_${DateTime.now().millisecondsSinceEpoch}_${client.id}',
                                clientId: client.id.toString(),
                                clientName: client.name,
                                trainerId:
                                    currentCloudUser?.uid ??
                                    'pt_${client.trainerId}',
                                trainerName: currentCloudUser?.name ?? 'Coach',
                                tierName: matchingTier.name,
                                sessionsCount: matchingTier.sessionsCount,
                                durationWeeks: matchingTier.durationWeeks,
                                price: matchingTier.price,
                                timestamp: DateTime.now(),
                                status: 'valid',
                              ),
                            );
                          } catch (_) {}

                          onRefresh?.call();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Paket $chosen sesi berhasil dibuat!',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal perpanjang: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Daftar Sesi (Slot: $availableSlots)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (canSchedule)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Jadwalkan'),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 7),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 16, minute: 0),
                        );
                        if (pickedTime != null) {
                          final dt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                          await db.schedule(package.id, dt);
                          onRefresh?.call();
                        }
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['Aktif', 'Hadir', 'Dibatalkan', 'Semua'].map((st) {
                final isSel = _selectedStatus == st;
                return ChoiceChip(
                  label: Text(st),
                  selected: isSel,
                  selectedColor: kMboisTeal,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedStatus = st);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (displayedSessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _selectedStatus == 'Aktif'
                        ? 'Tidak ada sesi aktif dijadwalkan. Klik "Jadwalkan Sesi" untuk memulai.'
                        : _selectedStatus == 'Dibatalkan'
                        ? 'Tidak ada sesi yang dibatalkan.'
                        : _selectedStatus == 'Hadir'
                        ? 'Belum ada sesi yang hadir/selesai.'
                        : 'Belum ada data sesi.',
                  ),
                ),
              )
            else
              ...displayedSessions.map(
                (s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: s.status == 'completed'
                          ? kMboisTeal.withValues(alpha: 0.4)
                          : s.status == 'cancelled'
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: s.status == 'completed'
                                  ? kMboisTeal
                                  : s.status == 'cancelled'
                                  ? Colors.red.shade100
                                  : Colors.grey.shade200,
                              foregroundColor: s.status == 'completed'
                                  ? Colors.white
                                  : s.status == 'cancelled'
                                  ? Colors.red.shade900
                                  : Colors.black87,
                              child: Text(
                                '${s.sessionNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sesi ${s.sessionNumber} • ${s.scheduledAt.day}/${s.scheduledAt.month}/${s.scheduledAt.year} ${s.scheduledAt.hour.toString().padLeft(2, '0')}:${s.scheduledAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Status: ${s.status == 'completed'
                                        ? 'HADIR'
                                        : s.status == 'cancelled'
                                        ? 'DIBATALKAN'
                                        : 'DIJADWALKAN'}${s.notes.isNotEmpty ? " • ${s.notes}" : ""}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: s.status == 'completed'
                                          ? kMboisTeal
                                          : s.status == 'cancelled'
                                          ? Colors.red
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (s.status == 'completed')
                              const Chip(
                                label: Text(
                                  'Hadir',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                                backgroundColor: kMboisTeal,
                                visualDensity: VisualDensity.compact,
                              )
                            else if (s.status == 'cancelled')
                              Chip(
                                label: const Text(
                                  'Dibatalkan',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                  ),
                                ),
                                backgroundColor: Colors.red.shade50,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        if (s.status == 'scheduled' &&
                            package.status == 'active') ...[
                          const Divider(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kMboisTeal,
                                  side: const BorderSide(color: kMboisTeal),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.edit_calendar, size: 14),
                                label: const Text(
                                  'Edit Jadwal',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _editSession(context, s),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.close, size: 14),
                                label: const Text(
                                  'Batalkan Sesi',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _cancelSession(context, s),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kMboisTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text(
                                  'Potong Sesi',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _confirmDeduction(context, s),
                              ),
                            ],
                          ),
                        ] else if (s.status == 'completed') ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kMboisTeal,
                                  side: const BorderSide(color: kMboisTeal),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.history_edu, size: 14),
                                label: const Text(
                                  'Detail Riwayat & Tanda Tangan',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onPressed: () =>
                                    _showSessionHistoryDetail(context, s),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _cancelSession(BuildContext context, Session s) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batalkan Sesi ${s.sessionNumber}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sesi ini akan dibatalkan dan langsung dipindahkan dari daftar sesi aktif. '
              'Kuota paket klien tidak akan berkurang.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan (Opsional)',
                hintText: 'Contoh: Klien sakit / reschedule',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(gymRepositoryProvider);
      final ok = await db.cancelSession(
        s.id,
        cancelReason: reasonController.text.trim().isEmpty
            ? 'Dibatalkan oleh PT'
            : reasonController.text.trim(),
      );
      if (ok) {
        onRefresh?.call();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sesi ${s.sessionNumber} berhasil dibatalkan.'),
            ),
          );
        }
      }
    }
  }

  void _confirmDeduction(BuildContext context, Session session) {
    final noteController = TextEditingController(
      text: 'Hadir latihan sesuai jadwal',
    );
    DedicatedSignatureResult? clientSig;
    DedicatedSignatureResult? coachSig;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isReady = clientSig != null && coachSig != null;

          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(
                  'Sesi ${session.sessionNumber}: Tanda Tangan & Absensi',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              body: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.viewInsetsOf(dialogCtx).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Klien: ${client.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Jadwal: ${session.scheduledAt.day}/${session.scheduledAt.month}/${session.scheduledAt.year} '
                        '${session.scheduledAt.hour.toString().padLeft(2, '0')}:${session.scheduledAt.minute.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(height: 12),

                      // Klien Signature Section
                      if (clientSig == null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '1. Tanda Tangan Klien (${client.name}) *',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sentuh tombol di bawah untuk membuka kanvas tanda tangan khusus.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.draw, size: 16),
                                label: const Text(
                                  'Buka Pad Tanda Tangan Klien',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kMboisTeal,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final res =
                                      await DedicatedSignatureDialog.show(
                                        dialogCtx,
                                        title: 'Tanda Tangan Klien',
                                        signerLabel: 'Klien: ${client.name}',
                                      );
                                  if (res != null) {
                                    setDialogState(() => clientSig = res);
                                  }
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        SignaturePreviewCard(
                          signature: clientSig,
                          signerLabel: 'Tanda Tangan Klien (${client.name})',
                          onEdit: () async {
                            final res = await DedicatedSignatureDialog.show(
                              dialogCtx,
                              title: 'Tanda Tangan Klien',
                              signerLabel: 'Klien: ${client.name}',
                              initialStrokes: clientSig?.strokes,
                            );
                            if (res != null) {
                              setDialogState(() => clientSig = res);
                            }
                          },
                        ),

                      const SizedBox(height: 14),

                      // Coach Signature Section
                      if (coachSig == null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '2. Tanda Tangan Coach / PT *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sentuh tombol di bawah untuk membubuhkan verifikasi pelatih.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.draw, size: 16),
                                label: const Text(
                                  'Buka Pad Tanda Tangan Coach',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.vibrantBlue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final res =
                                      await DedicatedSignatureDialog.show(
                                        dialogCtx,
                                        title: 'Tanda Tangan Coach / PT',
                                        signerLabel: 'Coach / Personal Trainer',
                                      );
                                  if (res != null) {
                                    setDialogState(() => coachSig = res);
                                  }
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        SignaturePreviewCard(
                          signature: coachSig,
                          signerLabel: 'Tanda Tangan Coach / PT',
                          onEdit: () async {
                            final res = await DedicatedSignatureDialog.show(
                              dialogCtx,
                              title: 'Tanda Tangan Coach / PT',
                              signerLabel: 'Coach / Personal Trainer',
                              initialStrokes: coachSig?.strokes,
                            );
                            if (res != null) {
                              setDialogState(() => coachSig = res);
                            }
                          },
                        ),

                      const SizedBox(height: 14),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Catatan Kehadiran',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogCtx).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isReady ? kMboisTeal : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: (!isReady || isSubmitting)
                            ? null
                            : () async {
                                setDialogState(() => isSubmitting = true);
                                final repo = ref.read(gymRepositoryProvider);
                                try {
                                  final currentCoachName =
                                      ref.read(cloudAuthProvider).value?.name ??
                                      'Coach Mbois';
                                  final saved = await repo.completeSession(
                                    session.id,
                                    noteController.text,
                                    clientStrokes: clientSig?.strokes,
                                    coachStrokes: coachSig?.strokes,
                                    clientName: client.name,
                                    trainerName: currentCoachName,
                                  );
                                  if (!dialogCtx.mounted) return;
                                  if (!saved) {
                                    setDialogState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(dialogCtx)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Status sesi telah berubah atau tidak valid untuk diproses. Periksa riwayat sebelum mencoba lagi.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                    return;
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Sesi berhasil diverifikasi dan kuota dipotong secara aman via Cloud Firestore.',
                                        ),
                                      ),
                                    );
                                    onRefresh?.call();
                                  }
                                } catch (e) {
                                  if (dialogCtx.mounted) {
                                    setDialogState(() => isSubmitting = false);
                                    final errStr = e.toString().toLowerCase();
                                    final String userMsg;
                                    if (errStr.contains('quota') ||
                                        errStr.contains('habis') ||
                                        errStr.contains('remaining') ||
                                        errStr.contains('zero')) {
                                      userMsg = 'Kuota sesi pada paket ini telah habis.';
                                    } else if (errStr.contains('completed') ||
                                        errStr.contains('selesai') ||
                                        errStr.contains('already')) {
                                      userMsg = 'Sesi ini sudah berstatus selesai atau telah diproses sebelumnya.';
                                    } else if (errStr.contains(
                                          'permission-denied',
                                        ) ||
                                        errStr.contains('unauthorized')) {
                                      userMsg = 'Akses ditolak. Pastikan akun coach Anda memiliki hak akses.';
                                    } else if (errStr.contains('network') ||
                                        errStr.contains('unavailable') ||
                                        errStr.contains('timeout')) {
                                      userMsg = 'Koneksi bermasalah. Periksa koneksi internet Anda dan coba lagi.';
                                    } else if (errStr.contains('stateerror') ||
                                        errStr.contains('status')) {
                                      userMsg = 'Status sesi tidak valid untuk pemotongan kuota.';
                                    } else {
                                      userMsg = 'Gagal memproses absensi dan pemotongan sesi. Silakan coba lagi.';
                                    }
                                    ScaffoldMessenger.of(dialogCtx)
                                        .showSnackBar(
                                          SnackBar(
                                            content: Text(userMsg),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Verifikasi & Potong Sesi'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editSession(BuildContext context, Session s) async {
    DateTime selectedDate = s.scheduledAt;
    TimeOfDay selectedTime = TimeOfDay(
      hour: s.scheduledAt.hour,
      minute: s.scheduledAt.minute,
    );
    final noteController = TextEditingController(text: s.notes);

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dateStr =
              '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
          final timeStr =
              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: Text('Edit Jadwal Sesi ${s.sessionNumber}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubah tanggal dan jam pelaksanaan sesi. Kuota sesi dan relasi klien/paket tetap terjaga.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today,
                      color: kMboisTeal,
                    ),
                    title: const Text('Tanggal Sesi'),
                    subtitle: Text(
                      dateStr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time, color: kMboisTeal),
                    title: const Text('Jam Mulai Sesi'),
                    subtitle: Text(
                      timeStr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Jadwal (Opsional)',
                      hintText: 'Contoh: Reschedule atas permintaan klien',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMboisTeal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final newDt = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  final db = ref.read(gymRepositoryProvider);
                  final ok = await db.rescheduleSession(
                    s.id,
                    newDt,
                    notes: noteController.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (ok) {
                    onRefresh?.call();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Jadwal Sesi ${s.sessionNumber} berhasil diperbarui.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Simpan Perubahan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showSessionHistoryDetail(
    BuildContext context,
    Session s,
  ) async {
    final db = ref.read(gymRepositoryProvider);
    final details = await db.getSessionDetails(s.id);
    if (!context.mounted) return;

    List<List<Offset>> parseStrokes(dynamic raw) {
      if (raw == null) return [];
      final List<List<Offset>> result = [];

      Offset? parseOffset(dynamic pt) {
        if (pt == null) return null;
        if (pt is Offset) return pt;
        if (pt is Map && pt.containsKey('x') && pt.containsKey('y')) {
          final x = (pt['x'] as num?)?.toDouble();
          final y = (pt['y'] as num?)?.toDouble();
          if (x != null && y != null) return Offset(x, y);
        }
        return null;
      }

      if (raw is Map && raw.containsKey('points') && raw['points'] is List) {
        final List<Offset> current = [];
        for (final item in raw['points'] as List) {
          final off = parseOffset(item);
          if (off != null) {
            current.add(off);
          } else if (current.isNotEmpty) {
            result.add(List.unmodifiable(current));
            current.clear();
          }
        }
        if (current.isNotEmpty) result.add(List.unmodifiable(current));
        return result;
      }

      if (raw is List) {
        for (final strokeItem in raw) {
          if (strokeItem is List) {
            final List<Offset> stroke = [];
            for (final pt in strokeItem) {
              final off = parseOffset(pt);
              if (off != null) stroke.add(off);
            }
            if (stroke.isNotEmpty) result.add(stroke);
          } else if (strokeItem is Map && strokeItem['points'] is List) {
            final List<Offset> stroke = [];
            for (final pt in (strokeItem['points'] as List)) {
              final off = parseOffset(pt);
              if (off != null) stroke.add(off);
            }
            if (stroke.isNotEmpty) result.add(stroke);
          }
        }
      }
      return result;
    }

    final clientStrokes = parseStrokes(details?['clientSignatureStrokes']);
    final coachStrokes = parseStrokes(details?['coachSignatureStrokes']);
    final notes = (details?['notes'] as String?) ?? s.notes;
    final clientName = (details?['clientName'] as String?) ?? client.name;
    final trainerName =
        (details?['trainerName'] as String?) ?? 'Coach Personal Trainer';
    DateTime? completedAt;
    final rawCompleted = details?['completedAt'];
    if (rawCompleted is DateTime) {
      completedAt = rawCompleted;
    } else if (rawCompleted != null) {
      try {
        completedAt = (rawCompleted as dynamic).toDate() as DateTime?;
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified, color: kMboisTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Riwayat Sesi ${s.sessionNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kMboisMint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: kMboisTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Klien: $clientName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Pelatih / PT: $trainerName'),
                      Text(
                        'Jadwal: ${s.scheduledAt.day}/${s.scheduledAt.month}/${s.scheduledAt.year} ${s.scheduledAt.hour.toString().padLeft(2, '0')}:${s.scheduledAt.minute.toString().padLeft(2, '0')}',
                      ),
                      if (completedAt != null)
                        Text(
                          'Selesai pada: ${completedAt.day}/${completedAt.month}/${completedAt.year} ${completedAt.hour.toString().padLeft(2, '0')}:${completedAt.minute.toString().padLeft(2, '0')}',
                        ),
                      const Text(
                        'Status: HADIR (Sesi Diverifikasi)',
                        style: TextStyle(
                          color: kMboisTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Catatan: $notes',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Bukti Tanda Tangan Digital Asli (Read-Only):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SignaturePreviewCard(
                  strokes: clientStrokes,
                  signerLabel: 'Tanda Tangan Klien ($clientName)',
                  height: 110,
                  timestamp: completedAt,
                ),
                const SizedBox(height: 10),
                SignaturePreviewCard(
                  strokes: coachStrokes,
                  signerLabel: 'Tanda Tangan Coach ($trainerName)',
                  height: 110,
                  timestamp: completedAt,
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMboisTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTab extends ConsumerWidget {
  const _ExerciseTab({required this.client, required this.package});
  final Client client;
  final PtPackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 64, color: kMboisTeal),
            const SizedBox(height: 16),
            Text(
              'Catat Latihan: ${client.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Input nama exercise, set, repetisi, beban, RPE/RIR, serta metode latihan (Straight, Superset, Drop Set, dll).',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMboisMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Buka Editor Sesi Latihan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kMboisTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.push('/clients/${client.id}/workout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab({required this.client, required this.package});
  final Client client;
  final PtPackage package;

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  int _refreshSignal = 0;

  void _reload() {
    setState(() => _refreshSignal++);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(gymRepositoryProvider);

    return FutureBuilder<List<WorkoutLog>>(
      key: ValueKey(_refreshSignal),
      future: db.logsForClient(widget.client.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data!;

        if (logs.isEmpty) {
          return const Center(
            child: Text('Belum ada riwayat latihan tersimpan untuk klien ini.'),
          );
        }

        return FutureBuilder<List<double>>(
          future: Future.wait(
            logs.map((log) async {
              final exercises = await db.exercisesForLog(log.id);
              double logVol = 0;
              for (final ex in exercises) {
                final sets = await db.setsForExercise(ex.id);
                for (final s in sets) {
                  if (s.weightKg != null) {
                    logVol += (s.reps * s.weightKg!);
                  }
                }
              }
              return logVol;
            }),
          ),
          builder: (context, volSnapshot) {
            final volumes = volSnapshot.data ?? [];
            final totalVol = volumes.fold<double>(0, (sum, v) => sum + v);
            final avgVol = volumes.isNotEmpty ? totalVol / volumes.length : 0.0;
            final chartPoints = volumes.reversed
                .toList(); // chronological order

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (chartPoints.length > 1) ...[
                  WorkoutVolumeChart(volumes: chartPoints),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kMboisMint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Total Volume',
                              style: TextStyle(
                                fontSize: 11,
                                color: kMboisTeal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalVol.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kMboisTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Rata-rata/Sesi',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${avgVol.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Riwayat Sesi Latihan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...logs.map(
                  (log) => _LogDetailCard(log: log, onRefresh: _reload),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class WorkoutVolumeChart extends StatelessWidget {
  const WorkoutVolumeChart({super.key, required this.volumes});
  final List<double> volumes;

  @override
  Widget build(BuildContext context) {
    if (volumes.isEmpty) return const SizedBox();
    final spots = volumes
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxVol = volumes.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 10),
      decoration: BoxDecoration(
        color: kMboisDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Perkembangan Volume (kg)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kMboisTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Puncak: ${maxVol.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'S${val.toInt() + 1}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: kMboisTeal,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: kMboisTeal.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogDetailCard extends ConsumerWidget {
  const _LogDetailCard({required this.log, this.onRefresh});
  final WorkoutLog log;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(gymRepositoryProvider);

    return FutureBuilder<List<WorkoutExercise>>(
      future: db.exercisesForLog(log.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final exercises = snapshot.data!;

        return FutureBuilder<List<List<WorkoutSet>>>(
          future: Future.wait(exercises.map((e) => db.setsForExercise(e.id))),
          builder: (context, setSnapshot) {
            if (!setSnapshot.hasData) return const SizedBox();
            final allSets = setSnapshot.data!;

            double totalVol = 0;
            for (final list in allSets) {
              for (final s in list) {
                if (s.weightKg != null) {
                  totalVol += (s.reps * s.weightKg!);
                }
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Text(
                  '${log.performedAt.day}/${log.performedAt.month}/${log.performedAt.year} • Sesi Latihan',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Training Volume: ${totalVol.toStringAsFixed(1)} kg • ${exercises.length} exercise',
                  style: const TextStyle(
                    color: kMboisTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (log.notes.isNotEmpty) ...[
                          Text(
                            'Catatan: ${log.notes}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                          const Divider(),
                        ],
                        ...exercises.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ex = entry.value;
                          final sets = allSets[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${idx + 1}. ${ex.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kMboisMint,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        ex.method,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: kMboisTeal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (ex.groupKey != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${ex.groupKey})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: kMboisTeal,
                                        ),
                                      ),
                                    ],
                                    if (ex.rir != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'RIR: ${ex.rir}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: kMboisMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sets
                                      .map(
                                        (s) => s.weightKg == null
                                            ? '${s.reps}x (BW)'
                                            : '${s.reps}x${s.weightKg}kg',
                                      )
                                      .join(' • '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kMboisMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit Workout'),
                              onPressed: () async {
                                await context.push(
                                  '/clients/${log.clientId}/workout?logId=${log.id}',
                                );
                                onRefresh?.call();
                              },
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Hapus Workout',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Hapus Workout?'),
                                    content: Text(
                                      'Apakah Anda yakin ingin menghapus seluruh log latihan tanggal ${log.performedAt.day}/${log.performedAt.month}/${log.performedAt.year}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Batal'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  await db.deleteWorkout(log.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Log workout berhasil dihapus',
                                        ),
                                      ),
                                    );
                                  }
                                  onRefresh?.call();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PostPtTab extends ConsumerStatefulWidget {
  const _PostPtTab({
    required this.client,
    required this.package,
    this.onRefresh,
  });
  final Client client;
  final PtPackage package;
  final VoidCallback? onRefresh;

  @override
  ConsumerState<_PostPtTab> createState() => _PostPtTabState();
}

class _PostPtTabState extends ConsumerState<_PostPtTab> {
  final _finalWeight = TextEditingController();
  final _bodyFatStart = TextEditingController();
  final _bodyFatEnd = TextEditingController();
  final _muscleStart = TextEditingController();
  final _muscleEnd = TextEditingController();
  final _armRight = TextEditingController();
  final _armLeft = TextEditingController();
  final _thighRight = TextEditingController();
  final _thighLeft = TextEditingController();
  final _achievement = TextEditingController();
  final _evaluation = TextEditingController();
  final _recommendation = TextEditingController();
  final _conclusion = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _finalWeight.dispose();
    _bodyFatStart.dispose();
    _bodyFatEnd.dispose();
    _muscleStart.dispose();
    _muscleEnd.dispose();
    _armRight.dispose();
    _armLeft.dispose();
    _thighRight.dispose();
    _thighLeft.dispose();
    _achievement.dispose();
    _evaluation.dispose();
    _recommendation.dispose();
    _conclusion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(gymRepositoryProvider);

    return FutureBuilder<int>(
      future: db.completedCount(widget.package.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final completed = snapshot.data!;
        final total = widget.package.totalSessions;
        final isCompleted = completed >= total;

        if (widget.package.status == 'closed') {
          return FutureBuilder<PostPtEvaluation?>(
            future: db.getEvaluationForPackage(widget.package.id),
            builder: (context, evalSnap) {
              final eval = evalSnap.data;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Icon(Icons.verified, size: 64, color: kMboisTeal),
                  const SizedBox(height: 12),
                  const Text(
                    'Paket PT Selesai & Terevaluasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Evaluasi Post PT telah tersimpan untuk paket ${widget.package.totalSessions} sesi ini.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMboisMuted),
                  ),
                  const SizedBox(height: 16),
                  if (eval != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hasil Pengukuran Akhir',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Divider(height: 16),
                            _InfoRow(
                              label: 'Berat Badan Akhir',
                              value: eval.finalWeightKg != null
                                  ? '${eval.finalWeightKg} kg'
                                  : '-',
                            ),
                            _InfoRow(
                              label: 'Body Fat',
                              value:
                                  '${eval.bodyFatStart ?? "-"}% → ${eval.bodyFatEnd ?? "-"}%',
                            ),
                            _InfoRow(
                              label: 'Massa Otot',
                              value:
                                  '${eval.muscleStart ?? "-"} kg → ${eval.muscleEnd ?? "-"} kg',
                            ),
                            _InfoRow(
                              label: 'Lingkar Lengan (R / L)',
                              value:
                                  '${eval.armRight ?? "-"} cm / ${eval.armLeft ?? "-"} cm',
                            ),
                            _InfoRow(
                              label: 'Lingkar Paha (R / L)',
                              value:
                                  '${eval.thighRight ?? "-"} cm / ${eval.thighLeft ?? "-"} cm',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Evaluasi & Kesimpulan PT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Divider(height: 16),
                            _InfoRow(
                              label: 'Pencapaian',
                              value: eval.achievement,
                            ),
                            _InfoRow(
                              label: 'Evaluasi Coach',
                              value: eval.evaluation,
                            ),
                            _InfoRow(
                              label: 'Rekomendasi',
                              value: eval.recommendation,
                            ),
                            _InfoRow(
                              label: 'Kesimpulan',
                              value: eval.conclusion,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        }

        if (!isCompleted) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Program Belum Selesai',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sesi selesai: $completed dari $total sesi (${total - completed} sesi tersisa).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completed / total,
                    minHeight: 12,
                    backgroundColor: kMboisLine,
                    color: kMboisTeal,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Form evaluasi akhir Post PT hanya dapat diisi dan difinalisasi setelah seluruh sesi dalam paket diselesaikan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMboisMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: kMboisMint,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evaluasi Akhir Post PT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kMboisTeal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Seluruh sesi telah selesai. Silakan isi form evaluasi progres akhir member.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _finalWeight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Berat Badan Akhir (kg)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bodyFatStart,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Body Fat Awal (%)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bodyFatEnd,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Body Fat Akhir (%)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _muscleStart,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Muscle Mass Awal (kg)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _muscleEnd,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Muscle Mass Akhir (kg)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _armRight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'L. Lengan Kanan (cm)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _armLeft,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'L. Lengan Kiri (cm)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _thighRight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'L. Paha Kanan (cm)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _thighLeft,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'L. Paha Kiri (cm)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _achievement,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Pencapaian Tujuan Klien',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _evaluation,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Evaluasi Coach PT'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recommendation,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Rekomendasi Latihan Selanjutnya',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conclusion,
              decoration: const InputDecoration(
                labelText: 'Kesimpulan Program',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Konfirmasi Finalisasi Post PT'),
                          content: const Text(
                            'Apakah Anda yakin ingin memfinalisasi evaluasi Post PT? Paket ini akan ditutup secara permanen dan tidak dapat diubah lagi.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kMboisTeal,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Ya, Finalisasi'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      setState(() => _saving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await db.finalizePackage(
                          widget.package.id,
                          PostPtEvaluationsCompanion.insert(
                            packageId: widget.package.id,
                            finalWeightKg: Value(
                              double.tryParse(_finalWeight.text),
                            ),
                            bodyFatStart: Value(
                              double.tryParse(_bodyFatStart.text),
                            ),
                            bodyFatEnd: Value(
                              double.tryParse(_bodyFatEnd.text),
                            ),
                            muscleStart: Value(
                              double.tryParse(_muscleStart.text),
                            ),
                            muscleEnd: Value(double.tryParse(_muscleEnd.text)),
                            armRight: Value(double.tryParse(_armRight.text)),
                            armLeft: Value(double.tryParse(_armLeft.text)),
                            thighRight: Value(
                              double.tryParse(_thighRight.text),
                            ),
                            thighLeft: Value(double.tryParse(_thighLeft.text)),
                            achievement: _achievement.text.trim().isEmpty
                                ? 'Target program selesai'
                                : _achievement.text.trim(),
                            evaluation: _evaluation.text.trim().isEmpty
                                ? 'Evaluasi selesai'
                                : _evaluation.text.trim(),
                            recommendation: _recommendation.text.trim().isEmpty
                                ? 'Program lanjutan mandiri / perpanjangan'
                                : _recommendation.text.trim(),
                            conclusion: _conclusion.text.trim().isEmpty
                                ? 'Selesai'
                                : _conclusion.text.trim(),
                          ),
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Evaluasi Post PT berhasil disimpan & paket ditutup!',
                              ),
                            ),
                          );
                          widget.onRefresh?.call();
                          setState(() => _saving = false);
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                          setState(() => _saving = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kMboisTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SIMPAN & TUTUP PAKET',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AssessmentTab extends ConsumerStatefulWidget {
  const _AssessmentTab({required this.client, this.onRefresh});
  final Client client;
  final VoidCallback? onRefresh;
  @override
  ConsumerState<_AssessmentTab> createState() => _AssessmentTabState();
}

class _AssessmentTabState extends ConsumerState<_AssessmentTab> {
  bool _isEditing = false;
  late TextEditingController _name;
  late TextEditingController _age;
  late TextEditingController _contact;
  late TextEditingController _height;
  late TextEditingController _weight;
  late TextEditingController _goal;
  late TextEditingController _medical;
  late TextEditingController _injury;
  late TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.client.name);
    _age = TextEditingController(text: '${widget.client.age}');
    _contact = TextEditingController(text: widget.client.contact);
    _height = TextEditingController(
      text: widget.client.heightCm != null ? '${widget.client.heightCm}' : '',
    );
    _weight = TextEditingController(
      text: widget.client.initialWeightKg != null
          ? '${widget.client.initialWeightKg}'
          : '',
    );
    _goal = TextEditingController(text: widget.client.goal);
    _medical = TextEditingController(text: widget.client.medicalHistory);
    _injury = TextEditingController(text: widget.client.injuryHistory);
    _notes = TextEditingController(text: widget.client.assessmentNotes);
  }

  @override
  void didUpdateWidget(covariant _AssessmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client && !_isEditing) {
      _name.text = widget.client.name;
      _age.text = '${widget.client.age}';
      _contact.text = widget.client.contact;
      _height.text = widget.client.heightCm != null
          ? '${widget.client.heightCm}'
          : '';
      _weight.text = widget.client.initialWeightKg != null
          ? '${widget.client.initialWeightKg}'
          : '';
      _goal.text = widget.client.goal;
      _medical.text = widget.client.medicalHistory;
      _injury.text = widget.client.injuryHistory;
      _notes.text = widget.client.assessmentNotes;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _contact.dispose();
    _height.dispose();
    _weight.dispose();
    _goal.dispose();
    _medical.dispose();
    _injury.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final db = ref.watch(gymRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Data Asesmen & Profil Klien',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow:
                    TextOverflow.ellipsis, // 2. TAMBAHKAN POTONGAN TEKS INI
              ),
            ),
            TextButton.icon(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              label: Text(_isEditing ? 'Batal' : 'Edit Asesmen'),
              onPressed: () => setState(() => _isEditing = !_isEditing),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_isEditing) ...[
          _InfoRow(label: 'Nama Lengkap', value: c.name),
          _InfoRow(label: 'Usia', value: '${c.age} tahun'),
          _InfoRow(
            label: 'Tinggi Badan',
            value: c.heightCm != null ? '${c.heightCm} cm' : '-',
          ),
          _InfoRow(
            label: 'Berat Badan Awal',
            value: c.initialWeightKg != null ? '${c.initialWeightKg} kg' : '-',
          ),
          _InfoRow(
            label: 'Kontak',
            value: c.contact.isNotEmpty ? c.contact : '-',
          ),
          const Divider(height: 24),
          _InfoRow(label: 'Tujuan Latihan', value: c.goal),
          _InfoRow(label: 'Riwayat Sakit', value: c.medicalHistory),
          _InfoRow(label: 'Riwayat Cedera', value: c.injuryHistory),
          _InfoRow(label: 'Catatan PT', value: c.assessmentNotes),
        ] else ...[
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama Lengkap *'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Usia (tahun) *',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _contact,
                  decoration: const InputDecoration(
                    labelText: 'Kontak / No HP',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tinggi Badan (cm)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Berat Badan Awal (kg)',
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          TextField(
            controller: _goal,
            decoration: const InputDecoration(labelText: 'Tujuan Latihan'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medical,
            decoration: const InputDecoration(labelText: 'Riwayat Sakit'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _injury,
            decoration: const InputDecoration(labelText: 'Riwayat Cedera'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Catatan PT'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final name = _name.text.trim();
              final age = int.tryParse(_age.text) ?? 0;
              if (name.isEmpty || age <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nama dan usia valid wajib diisi'),
                  ),
                );
                return;
              }
              final h = double.tryParse(_height.text);
              final w = double.tryParse(_weight.text);
              await db.updateClient(
                c.copyWith(
                  name: name,
                  age: age,
                  contact: _contact.text.trim(),
                  heightCm: Value(h),
                  initialWeightKg: Value(w),
                  goal: _goal.text,
                  medicalHistory: _medical.text,
                  injuryHistory: _injury.text,
                  assessmentNotes: _notes.text,
                ),
              );
              setState(() => _isEditing = false);
              widget.onRefresh?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data profil & asesmen berhasil diperbarui'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kMboisTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan Perubahan Asesmen'),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: kMboisMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutEditorScreen extends ConsumerStatefulWidget {
  const WorkoutEditorScreen({super.key, required this.clientId, this.logId});
  final int clientId;
  final int? logId;
  @override
  ConsumerState<WorkoutEditorScreen> createState() =>
      _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends ConsumerState<WorkoutEditorScreen> {
  final _workoutNotes = TextEditingController();
  final List<ExerciseDraft> _exercises = [];
  int? _selectedSessionId;
  bool _saving = false;
  bool _loadingWorkout = false;

  @override
  void initState() {
    super.initState();
    if (widget.logId != null) {
      _loadExistingWorkout();
    }
  }

  Future<void> _loadExistingWorkout() async {
    setState(() => _loadingWorkout = true);
    final db = ref.read(gymRepositoryProvider);
    final log = await db.getWorkoutLog(widget.logId!);
    if (log != null) {
      _workoutNotes.text = log.notes;
      _selectedSessionId = log.sessionId;
      final exercises = await db.exercisesForLog(log.id);
      _exercises.clear();
      for (final ex in exercises) {
        final sets = await db.setsForExercise(ex.id);
        _exercises.add(
          ExerciseDraft(
            id: ex.id,
            name: ex.name,
            method: ex.method,
            equipment: ex.equipment,
            groupKey: ex.groupKey,
            rpe: ex.rpe,
            rir: ex.rir,
            notes: ex.notes,
            sets: sets
                .map(
                  (s) => SetDraft(s.reps, s.weightKg, stage: s.stage, id: s.id),
                )
                .toList(),
          ),
        );
      }
    }
    if (mounted) setState(() => _loadingWorkout = false);
  }

  bool _hasUnsavedChanges() =>
      _exercises.isNotEmpty || _workoutNotes.text.trim().isNotEmpty;

  void _editSetDialog(ExerciseDraft ex, int sIdx) {
    final s = ex.sets[sIdx];
    final repsController = TextEditingController(text: '${s.reps}');
    final weightController = TextEditingController(
      text: s.weightKg != null ? '${s.weightKg}' : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Set ${sIdx + 1} - ${ex.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Repetisi *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Beban (kg) (kosongkan jika BW)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMboisTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final reps = int.tryParse(repsController.text) ?? 0;
              final weightText = weightController.text.trim();
              final weight = weightText.isEmpty
                  ? null
                  : double.tryParse(weightText);
              if (reps <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Repetisi harus lebih dari 0')),
                );
                return;
              }
              setState(() {
                ex.sets[sIdx] = SetDraft(
                  reps,
                  weight,
                  stage: s.stage,
                  id: s.id,
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Set'),
          ),
        ],
      ),
    );
  }

  void _editExerciseDialog(ExerciseDraft ex, int eIdx) {
    final nameController = TextEditingController(text: ex.name);
    final equipController = TextEditingController(text: ex.equipment);
    final notesController = TextEditingController(text: ex.notes);
    String method = ex.method;
    final rpeController = TextEditingController(
      text: ex.rpe != null ? '${ex.rpe}' : '',
    );
    final rirController = TextEditingController(
      text: ex.rir != null ? '${ex.rir}' : '',
    );
    final groupKeyController = TextEditingController(text: ex.groupKey ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Detail Exercise',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Exercise *',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(
                    labelText: 'Metode Latihan',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Straight Set',
                      child: Text('Straight Set (Standard)'),
                    ),
                    DropdownMenuItem(
                      value: 'Superset',
                      child: Text('Superset (Agonis-Antagonis)'),
                    ),
                    DropdownMenuItem(
                      value: 'Drop Set',
                      child: Text('Drop Set (Penurunan Beban)'),
                    ),
                    DropdownMenuItem(
                      value: 'Giant Set',
                      child: Text('Giant Set (3+ Gerakan)'),
                    ),
                    DropdownMenuItem(
                      value: 'Circuit',
                      child: Text('Circuit Training'),
                    ),
                    DropdownMenuItem(
                      value: 'Rest-Pause',
                      child: Text('Rest-Pause Set'),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => method = v ?? method),
                ),
                const SizedBox(height: 12),
                if (method == 'Superset' ||
                    method == 'Giant Set' ||
                    method == 'Circuit') ...[
                  TextField(
                    controller: groupKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Group / Cluster Key *',
                      hintText: 'Contoh: Super-1, Cluster-A',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rpeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'RPE (1-10)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: rirController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'RIR (0-5)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: equipController,
                  decoration: const InputDecoration(
                    labelText: 'Alat / Mesin (Barbell, Dumbbell, Cable, dll)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Khusus',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMboisTeal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama exercise tidak boleh kosong'),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      ex.name = name;
                      ex.method = method;
                      ex.equipment = equipController.text.trim();
                      ex.notes = notesController.text.trim();
                      ex.groupKey = groupKeyController.text.trim().isEmpty
                          ? null
                          : groupKeyController.text.trim();
                      ex.rpe = double.tryParse(rpeController.text);
                      ex.rir = int.tryParse(rirController.text);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Simpan Detail Exercise'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addExerciseDialog() {
    final nameController = TextEditingController();
    final equipController = TextEditingController();
    final notesController = TextEditingController();
    String method = 'Straight Set';
    final repsController = TextEditingController(text: '10');
    final weightController = TextEditingController();
    final rpeController = TextEditingController(text: '8');
    final rirController = TextEditingController();
    final groupKeyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tambah Exercise Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Exercise *',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu_book, color: kMboisTeal),
                      tooltip: 'Pilih dari Katalog Exercise',
                      onPressed: () async {
                        final picked = await _pickCatalogExercise(context);
                        if (picked != null) {
                          setModalState(() => nameController.text = picked);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Metode Latihan',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Straight Set',
                      child: Text('Straight Set'),
                    ),
                    DropdownMenuItem(
                      value: 'Superset',
                      child: Text('Superset'),
                    ),
                    DropdownMenuItem(
                      value: 'Drop Set',
                      child: Text('Drop Set'),
                    ),
                    DropdownMenuItem(
                      value: 'Giant Set',
                      child: Text('Giant Set'),
                    ),
                    DropdownMenuItem(
                      value: 'Circuit Training',
                      child: Text('Circuit Training'),
                    ),
                    DropdownMenuItem(
                      value: 'Rest-Pause',
                      child: Text('Rest-Pause'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => method = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: repsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Repetisi *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Beban (kg) (kosongkan jika BW)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rpeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'RPE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: rirController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'RIR (Reps in Reserve)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: groupKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Group / Superset Key',
                          hintText: 'Misal: A1',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: equipController,
                  decoration: const InputDecoration(
                    labelText: 'Alat (Barbel/Dumbbell/Mesin)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Catatan PT'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMboisTeal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final reps = int.tryParse(repsController.text) ?? 0;
                    final weightText = weightController.text.trim();
                    final weight = weightText.isEmpty
                        ? null
                        : double.tryParse(weightText);
                    if (name.isEmpty || reps <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Nama exercise dan repetisi valid wajib diisi',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _exercises.add(
                        ExerciseDraft(
                          name: name,
                          method: method,
                          equipment: equipController.text.trim(),
                          groupKey: groupKeyController.text.trim().isEmpty
                              ? null
                              : groupKeyController.text.trim(),
                          rpe: double.tryParse(rpeController.text),
                          rir: int.tryParse(rirController.text),
                          notes: notesController.text.trim(),
                          sets: [SetDraft(reps, weight)],
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Tambahkan ke Daftar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _pickCatalogExercise(BuildContext context) async {
    final db = ref.read(gymRepositoryProvider);
    final localDb = ref.read(databaseProvider);
    String searchQuery = '';
    bool isSyncing = false;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) =>
            FutureBuilder<List<ExerciseCatalogData>>(
              future: db.exerciseCatalog,
              builder: (context, snapshot) {
                final allItems = snapshot.data ?? [];
                final filtered = searchQuery.isEmpty
                    ? allItems
                    : allItems
                          .where(
                            (e) =>
                                e.name.toLowerCase().contains(
                                  searchQuery.toLowerCase(),
                                ) ||
                                e.category.toLowerCase().contains(
                                  searchQuery.toLowerCase(),
                                ),
                          )
                          .toList();

                return AlertDialog(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pilih Exercise'),
                      if (isSyncing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            Icons.cloud_download,
                            color: kMboisTeal,
                          ),
                          tooltip: 'Sinkronisasi dari wger API',
                          onPressed: () async {
                            setDialogState(() => isSyncing = true);
                            final (count, err) =
                                await ExerciseApiService.syncFromWger(localDb);
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSyncing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    err ??
                                        'Berhasil mensinkronkan $count exercise dari wger API!',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 420,
                    child: Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Cari exercise atau kategori...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setDialogState(() => searchQuery = v.trim()),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text('Exercise tidak ditemukan.'),
                                )
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (ctx, i) {
                                    final item = filtered[i];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${item.category} • Sumber: ${item.source}',
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                      ),
                                      onTap: () =>
                                          Navigator.pop(dialogCtx, item.name),
                                    );
                                  },
                                ),
                        ),
                        const Divider(),
                        const Text(
                          'Sumber exercise: Katalog Offline + wger Workout Manager API (CC-BY-SA 4.0)',
                          style: TextStyle(fontSize: 10, color: kMboisMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Tutup'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Custom'),
                      onPressed: () async {
                        final customController = TextEditingController();
                        final customCategory = TextEditingController(
                          text: 'Custom',
                        );
                        final added = await showDialog<String>(
                          context: dialogCtx,
                          builder: (cCtx) => AlertDialog(
                            title: const Text('Tambah Exercise Baru'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: customController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Exercise',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Kategori (Chest, Back, dll)',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(cCtx),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kMboisTeal,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final name = customController.text.trim();
                                  if (name.isNotEmpty) {
                                    await localDb
                                        .into(localDb.exerciseCatalog)
                                        .insert(
                                          ExerciseCatalogCompanion.insert(
                                            name: name,
                                            category:
                                                customCategory.text
                                                    .trim()
                                                    .isEmpty
                                                ? 'Custom'
                                                : customCategory.text.trim(),
                                            source: const Value('custom_pt'),
                                          ),
                                          mode: InsertMode.insertOrIgnore,
                                        );
                                    if (cCtx.mounted) Navigator.pop(cCtx, name);
                                  }
                                },
                                child: const Text('Simpan'),
                              ),
                            ],
                          ),
                        );
                        if (added != null && dialogCtx.mounted) {
                          Navigator.pop(dialogCtx, added);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(gymRepositoryProvider);
    final totalVol = trainingVolume(_exercises);

    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Buang Perubahan?'),
            content: const Text(
              'Latihan yang belum disimpan akan hilang. Apakah Anda yakin ingin keluar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.logId != null ? 'Edit Sesi Latihan' : 'Pencatatan Latihan',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _loadingWorkout
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FutureBuilder<List<Session>>(
                    future: db.currentPackage(widget.clientId).then((pkg) {
                      if (pkg == null) return <Session>[];
                      return db.packageSessions(pkg.id);
                    }),
                    builder: (context, sessSnapshot) {
                      final sessions = sessSnapshot.data ?? [];
                      return DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: _selectedSessionId,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Sesi Appointment (Opsional)',
                          prefixIcon: Icon(Icons.event_note, color: kMboisTeal),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Tanpa Sesi Terjadwal (Latihan Tambahan)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...sessions.map(
                            (s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(
                                'Sesi ${s.sessionNumber} (${s.scheduledAt.day}/${s.scheduledAt.month}/${s.scheduledAt.year})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedSessionId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _workoutNotes,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Sesi Latihan Hari Ini',
                      hintText: 'Contoh: Upper body push, fokus tempo dan aktivasi scapula',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: kMboisMint,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Training Volume:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kMboisTeal,
                            ),
                          ),
                          Text(
                            '${totalVol.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kMboisTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Exercise (${_exercises.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kMboisTeal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _addExerciseDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_exercises.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Belum ada exercise yang ditambahkan.'),
                      ),
                    )
                  else
                    ..._exercises.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ex = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${idx + 1}. ${ex.name} (${ex.method})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (ex.groupKey != null ||
                                            ex.rir != null ||
                                            ex.rpe != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              [
                                                if (ex.groupKey != null)
                                                  'Group: ${ex.groupKey}',
                                                if (ex.rir != null)
                                                  'RIR: ${ex.rir}',
                                                if (ex.rpe != null)
                                                  'RPE: ${ex.rpe}',
                                              ].join(' • '),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: kMboisTeal,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_note,
                                      color: kMboisTeal,
                                    ),
                                    tooltip: 'Edit Detail Exercise',
                                    onPressed: () =>
                                        _editExerciseDialog(ex, idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Hapus Exercise',
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Hapus Exercise?'),
                                          content: Text(
                                            'Apakah Anda yakin ingin menghapus "${ex.name}" dari sesi latihan ini?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Batal'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Hapus'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true && mounted) {
                                        setState(
                                          () => _exercises.removeAt(idx),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              ...ex.sets.asMap().entries.map((sEntry) {
                                final sIdx = sEntry.key;
                                final s = sEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.weightKg == null
                                              ? 'Set ${sIdx + 1}: ${s.reps} rep • Beban Tubuh (BW)'
                                              : 'Set ${sIdx + 1}: ${s.reps} rep x ${s.weightKg} kg = ${(s.volume ?? 0).toStringAsFixed(1)} kg',
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        tooltip: 'Edit Set',
                                        onPressed: () =>
                                            _editSetDialog(ex, sIdx),
                                      ),
                                      if (ex.sets.length > 1)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          tooltip: 'Hapus Set',
                                          onPressed: () => setState(
                                            () => ex.sets.removeAt(sIdx),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Tambah Set / Drop Stage'),
                                  onPressed: () {
                                    setState(() {
                                      final last = ex.sets.last;
                                      ex.sets.add(
                                        SetDraft(
                                          last.reps,
                                          last.weightKg,
                                          stage: ex.sets.length + 1,
                                        ),
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving || _exercises.isEmpty
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);
                            final pkg = await db.currentPackage(
                              widget.clientId,
                            );
                            if (pkg == null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Paket klien tidak ditemukan.'),
                                ),
                              );
                              if (mounted) {
                                setState(() => _saving = false);
                              }
                              return;
                            }
                            try {
                              if (widget.logId != null) {
                                await db.updateWorkout(
                                  logId: widget.logId!,
                                  notes: _workoutNotes.text,
                                  sessionId: _selectedSessionId,
                                  exercises: _exercises,
                                );
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Perubahan latihan berhasil disimpan!',
                                      ),
                                    ),
                                  );
                                  nav.pop();
                                }
                              } else {
                                await db.saveWorkout(
                                  clientId: widget.clientId,
                                  packageId: pkg.id,
                                  sessionId: _selectedSessionId,
                                  notes: _workoutNotes.text,
                                  exercises: _exercises,
                                );
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sesi latihan berhasil disimpan ke riwayat!',
                                      ),
                                    ),
                                  );
                                  nav.pop();
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                                setState(() => _saving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMboisTeal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.logId != null
                                ? 'SIMPAN PERUBAHAN'
                                : 'SIMPAN SESI LATIHAN',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _refreshSignal = 0;

  void _reload() {
    setState(() => _refreshSignal++);
  }

  void _showEditProfileDialog(BuildContext context, Trainer trainer) {
    final nameController = TextEditingController(text: trainer.name);
    final emailController = TextEditingController(text: trainer.email);
    final phoneController = TextEditingController(text: trainer.phone);
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Profil Coach'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorText!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap PT *',
                      prefixIcon: Icon(
                        Icons.person,
                        color: AppColors.vibrantBlue,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Nama lengkap tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email PT *',
                      prefixIcon: Icon(
                        Icons.email,
                        color: AppColors.vibrantBlue,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || !isValidEmail(v)) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp *',
                      hintText: 'Contoh: 08123456789 atau +628****6789',
                      prefixIcon: Icon(
                        Icons.phone,
                        color: AppColors.vibrantBlue,
                      ),
                    ),
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          !isValidPhoneNumber(v)) {
                        return 'Format nomor WhatsApp tidak valid (8-18 digit)';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.vibrantBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      final db = ref.read(databaseProvider);
                      try {
                        await db.updateTrainer(
                          id: trainer.id,
                          name: nameController.text.trim(),
                          email: emailController.text.trim().toLowerCase(),
                          phone: phoneController.text.trim(),
                          avatarUrl: trainer.avatarUrl,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profil berhasil diperbarui'),
                            ),
                          );
                          _reload();
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          errorText = e
                              .toString()
                              .replaceFirst('Exception: ', '')
                              .replaceFirst('StateError: ', '')
                              .replaceFirst('ArgumentError: ', '');
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCloudProfileDialog(BuildContext context, CloudProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final phoneController = TextEditingController(text: profile.phone);
    final heightController = TextEditingController(
      text: profile.heightCm != null ? profile.heightCm.toString() : '',
    );
    final weightController = TextEditingController(
      text: profile.weightKg != null ? profile.weightKg.toString() : '',
    );
    final specController = TextEditingController(text: profile.specialization);
    final expController = TextEditingController(
      text: profile.experienceYears != null
          ? profile.experienceYears.toString()
          : '',
    );
    final certController = TextEditingController(text: profile.certifications);
    final bioController = TextEditingController(text: profile.bio);

    final formKey = GlobalKey<FormState>();
    bool saving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: kMboisTeal),
              SizedBox(width: 8),
              Text(
                'Edit Profil Coach PT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap PT *',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: AppColors.vibrantBlue,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Nama lengkap tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: profile.email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email Akun (Read-Only)',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WhatsApp *',
                        hintText: 'Contoh: 08123456789 atau +628123456789',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: AppColors.vibrantBlue,
                        ),
                      ),
                      validator: (v) {
                        if (v != null &&
                            v.trim().isNotEmpty &&
                            !isValidPhoneNumber(v)) {
                          return 'Format nomor WhatsApp tidak valid (8-18 digit)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Text('Peran Administratif: ${profile.role} (hanya admin)'),
                    Text('Status Akun: ${profile.status} (hanya admin)'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Tinggi Badan (cm)',
                              prefixIcon: Icon(Icons.height, color: kMboisTeal),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = double.tryParse(v);
                              if (n == null || n <= 0 || n > 260) {
                                return 'Angka 30-260 cm';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Berat Badan (kg)',
                              prefixIcon: Icon(
                                Icons.fitness_center,
                                color: kMboisTeal,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = double.tryParse(v);
                              if (n == null || n <= 0 || n > 300) {
                                return 'Angka 20-300 kg';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: specController,
                      decoration: const InputDecoration(
                        labelText: 'Spesialisasi',
                        hintText: 'Contoh: Hypertrophy, Bodybuilding, Fat Loss',
                        prefixIcon: Icon(
                          Icons.stars_outlined,
                          color: kMboisTeal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: expController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Pengalaman',
                              suffixText: 'tahun',
                              prefixIcon: Icon(
                                Icons.work_outline,
                                color: kMboisTeal,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = int.tryParse(v);
                              if (n == null || n < 0 || n > 60) {
                                return '0-60 thn';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: certController,
                            decoration: const InputDecoration(
                              labelText: 'Sertifikasi',
                              hintText: 'APKI / CSCS / NASM',
                              prefixIcon: Icon(
                                Icons.verified_outlined,
                                color: kMboisTeal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: bioController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Bio / Deskripsi Singkat',
                        hintText: 'Deskripsi singkat profil kepelatihan Anda',
                        prefixIcon: Icon(
                          Icons.notes_outlined,
                          color: kMboisTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMboisTeal,
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        final err = await ref
                            .read(cloudAuthProvider.notifier)
                            .updateProfile(
                              displayName: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              heightCm: double.tryParse(
                                heightController.text.trim(),
                              ),
                              weightKg: double.tryParse(
                                weightController.text.trim(),
                              ),
                              experienceYears: int.tryParse(
                                expController.text.trim(),
                              ),
                              specialization: specController.text.trim(),
                              certifications: certController.text.trim(),
                              bio: bioController.text.trim(),
                              photoUrl: profile.photoUrl,
                            );
                        if (err != null) {
                          setDialogState(() {
                            saving = false;
                            errorText = err;
                          });
                          return;
                        }
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Profil Coach PT berhasil diperbarui.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          errorText = e.toString();
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudProfileView(
    BuildContext context,
    CloudProfile cloudUser,
    ThemeMode theme,
    bool isDark,
  ) {
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profil & Pengaturan Coach'),
        backgroundColor: AppColors.vibrantBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: () => ref.refresh(cloudAuthProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.vibrantBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  InitialAvatar(
                    name: cloudUser.name,
                    email: cloudUser.email,
                    radius: 42,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.vibrantBlue,
                    textStyle: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.vibrantBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cloudUser.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cloudUser.role} • ${cloudUser.status}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Akun Coach',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.email_outlined,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Email Akun',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.email,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.chat_outlined,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Nomor WhatsApp',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.phone.isNotEmpty
                                  ? cloudUser.phone
                                  : 'Belum diatur',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontStyle: cloudUser.phone.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.fingerprint,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Firebase UID',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.uid,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          const Text(
                            'Data Profesional PT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.height,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Tinggi Badan',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.heightCm != null
                                  ? '${cloudUser.heightCm!.toStringAsFixed(1)} cm'
                                  : 'Belum diatur',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.fitness_center,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Berat Badan',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.weightKg != null
                                  ? '${cloudUser.weightKg!.toStringAsFixed(1)} kg'
                                  : 'Belum diatur',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.stars_outlined,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Keahlian / Spesialisasi',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.specialization.isNotEmpty
                                  ? cloudUser.specialization
                                  : 'Belum diatur',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.work_outline,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Pengalaman',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.experienceYears != null
                                  ? '${cloudUser.experienceYears} tahun'
                                  : 'Belum diatur',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.verified_outlined,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Sertifikasi',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.certifications.isNotEmpty
                                  ? cloudUser.certifications
                                  : 'Belum diatur',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.notes_outlined,
                              color: AppColors.vibrantBlue,
                            ),
                            title: const Text(
                              'Bio',
                              style: TextStyle(
                                fontSize: 12,
                                color: kMboisMuted,
                              ),
                            ),
                            subtitle: Text(
                              cloudUser.bio.isNotEmpty
                                  ? cloudUser.bio
                                  : 'Belum diatur',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kMboisTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text(
                                'EDIT PROFIL',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _showEditCloudProfileDialog(
                                context,
                                cloudUser,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Pengaturan Tema Aplikasi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Ikuti Sistem (Default)'),
                          value: ThemeMode.system,
                          groupValue: theme,
                          onChanged: (v) => v != null
                              ? ref.read(themeProvider.notifier).setMode(v)
                              : null,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Mode Terang (Light)'),
                          value: ThemeMode.light,
                          groupValue: theme,
                          onChanged: (v) => v != null
                              ? ref.read(themeProvider.notifier).setMode(v)
                              : null,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Mode Gelap (Dark)'),
                          value: ThemeMode.dark,
                          groupValue: theme,
                          onChanged: (v) => v != null
                              ? ref.read(themeProvider.notifier).setMode(v)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('LOGOUT COACH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Konfirmasi Logout'),
                          content: const Text(
                            'Apakah Anda yakin ingin keluar dari sesi Coach Firebase?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.dangerRed,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Keluar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await ref.read(cloudAuthProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      }
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloudAuth = ref.watch(cloudAuthProvider);
    final cloudUser = cloudAuth.value;
    final theme = ref.watch(themeProvider).value ?? ThemeMode.system;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cloudUser != null) {
      return _buildCloudProfileView(context, cloudUser, theme, isDark);
    }

    final authState = ref.watch(authProvider);
    final trainerId = authState.value;
    final db = ref.watch(databaseProvider);

    if (trainerId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profil & Pengaturan Coach'),
        backgroundColor: AppColors.vibrantBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder(
        key: ValueKey(_refreshSignal),
        future: Future.wait([
          db.getTrainerById(trainerId),
          db.allClients(trainerId),
          db.select(db.sessions).get(),
          db.select(db.ptPackages).get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trainer = snapshot.data![0] as Trainer?;
          if (trainer == null) {
            return const Center(child: Text('Akun Coach tidak ditemukan.'));
          }
          final clients = snapshot.data![1] as List<Client>;
          final sessions = snapshot.data![2] as List<Session>;
          final packages = snapshot.data![3] as List<PtPackage>;

          final activePackages = packages
              .where((p) => p.status == 'active')
              .length;
          final completedSessions = sessions
              .where((s) => s.status == 'completed')
              .length;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Top Vibrant Blue Header Banner with Avatar
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.vibrantBlue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 8, bottom: 28),
                  child: Column(
                    children: [
                      // Avatar with lime-yellow edit pencil badge
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                AppAssets.coachAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Image.asset(
                                  AppAssets.defaultAvatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: Colors.white,
                                    child: Center(
                                      child: Text(
                                        trainer.name.isNotEmpty
                                            ? trainer.name[0].toUpperCase()
                                            : 'P',
                                        style: const TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.vibrantBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _showEditProfileDialog(context, trainer),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.badgeYellowLime,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        trainer.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: AppRadius.pill,
                        ),
                        child: const Text(
                          'PERSONAL TRAINER • MBOIS GYM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      // Floating Cyan Summary Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent,
                          borderRadius: AppRadius.large,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyanAccent.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Klien', '${clients.length}'),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white30,
                            ),
                            _buildStatItem('Paket Aktif', '$activePackages'),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white30,
                            ),
                            _buildStatItem(
                              'Sesi Selesai',
                              '$completedSessions',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Detail Info Card with Edit Profile Dialog Option
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.large,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.email_outlined,
                                  color: AppColors.vibrantBlue,
                                ),
                                title: const Text(
                                  'Email Akun',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kMboisMuted,
                                  ),
                                ),
                                subtitle: Text(
                                  trainer.email,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.chat_outlined,
                                  color: AppColors.vibrantBlue,
                                ),
                                title: const Text(
                                  'Nomor WhatsApp',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kMboisMuted,
                                  ),
                                ),
                                subtitle: Text(
                                  trainer.phone.trim().isNotEmpty
                                      ? trainer.phone.trim()
                                      : 'Belum diatur',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: trainer.phone.isEmpty
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AppPillButton(
                                text: 'EDIT PROFIL',
                                backgroundColor: AppColors.cyanAccent,
                                onPressed: () =>
                                    _showEditProfileDialog(context, trainer),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Theme Settings
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.medium,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'Pengaturan Tema Aplikasi',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('Ikuti Sistem (Default)'),
                              value: ThemeMode.system,
                              groupValue: theme,
                              onChanged: (v) {
                                if (v != null) {
                                  ref.read(themeProvider.notifier).setMode(v);
                                }
                              },
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('Mode Terang (Light)'),
                              value: ThemeMode.light,
                              groupValue: theme,
                              onChanged: (v) {
                                if (v != null) {
                                  ref.read(themeProvider.notifier).setMode(v);
                                }
                              },
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('Mode Gelap (Dark)'),
                              value: ThemeMode.dark,
                              groupValue: theme,
                              onChanged: (v) {
                                if (v != null) {
                                  ref.read(themeProvider.notifier).setMode(v);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Firebase Pilot Card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.medium,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.cloud_sync_outlined,
                            color: AppColors.vibrantBlue,
                          ),
                          title: const Text('Integrasi Cloud Firebase'),
                          subtitle: const Text(
                            'Status koneksi dan sinkronisasi server',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/cloud-pilot'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Logout Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('LOGOUT COACH'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dangerRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                          ),
                        ),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Konfirmasi Logout'),
                              content: const Text(
                                'Apakah Anda yakin ingin keluar dari sesi Coach?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.dangerRed,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Keluar'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

typedef SettingsScreen = ProfileScreen;
