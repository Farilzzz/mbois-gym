import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_database.dart';
import '../widgets/initial_avatar.dart';
import '../app.dart' show databaseProvider;

/// Model for client attendance record in Manager read-only view.
class ManagerClientAttendanceRecord {
  const ManagerClientAttendanceRecord({
    required this.sessionNumber,
    required this.scheduledTime,
    required this.status, // 'completed', 'scheduled', 'cancelled'
  });

  final int sessionNumber;
  final DateTime scheduledTime;
  final String status;

  String get statusLabel => switch (status.toLowerCase()) {
    'completed' => 'Hadir',
    'cancelled' => 'Dibatalkan',
    _ => 'Direncanakan',
  };

  Color get statusColor => switch (status.toLowerCase()) {
    'completed' => const Color(0xFF10B981),
    'cancelled' => const Color(0xFFEF4444),
    _ => const Color(0xFF0088FF),
  };
}

/// Model for client item in Manager PT Detail view.
class ManagerClientItem {
  const ManagerClientItem({
    required this.id,
    required this.name,
    required this.packageName,
    required this.totalSessions,
    required this.attendedSessions,
    required this.remainingSessions,
    this.attendanceRecords = const [],
    this.status = 'unknown',
  });

  final String status;
  final String id;
  final String name;
  final String packageName;
  final int totalSessions;
  final int attendedSessions;
  final int remainingSessions;
  final List<ManagerClientAttendanceRecord> attendanceRecords;

  // Legacy projections without lifecycle are deliberately not called active.
  bool get isActive => status == 'active' && remainingSessions > 0;
  String get statusLabel => switch (status) {
    'active' when remainingSessions > 0 => 'Aktif',
    'completed' => 'Selesai',
    'cancelled' => 'Dibatalkan',
    'discontinued' => 'Dihentikan',
    _ => 'Status belum tersedia',
  };
}

/// Projection-only client roster; historical service is never an active total.
class ManagerClientHistoryScreen extends StatefulWidget {
  const ManagerClientHistoryScreen({
    super.key,
    required this.trainer,
    required this.onAttendance,
  });
  final TrainerPerformance trainer;
  final void Function(BuildContext, ManagerClientItem) onAttendance;
  @override
  State<ManagerClientHistoryScreen> createState() =>
      _ManagerClientHistoryScreenState();
}

class _ManagerClientHistoryScreenState
    extends State<ManagerClientHistoryScreen> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final clients = widget.trainer.clients
        .where(
          (c) => switch (filter) {
            'active' => c.isActive,
            'history' => !c.isActive,
            _ => true,
          },
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('Klien • ${widget.trainer.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Status layanan bukan bukti pembayaran atau pengembalian dana.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const {
                'all': 'Semua',
                'active': 'Aktif',
                'history': 'Riwayat',
              }.entries)
                ChoiceChip(
                  label: Text(item.value),
                  selected: filter == item.key,
                  onSelected: (_) => setState(() => filter = item.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (clients.isEmpty) const Text('Tidak ada klien pada filter ini.'),
          for (final client in clients)
            Card(
              child: ListTile(
                title: Text(client.name),
                subtitle: Text(
                  '${client.statusLabel} • ${client.packageName}\n${client.attendedSessions} dari ${client.totalSessions} sesi dihadiri • Sisa ${client.remainingSessions}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onAttendance(context, client),
              ),
            ),
        ],
      ),
    );
  }
}

/// Model for individual Trainer Performance in Manager Dashboard.
class TrainerPerformance {
  const TrainerPerformance({
    required this.id,
    required this.name,
    required this.specialization,
    required this.activeClients,
    required this.packagesSold,
    required this.totalSales,
    this.photoUrl,
    this.status = 'active',
    this.quarterlyTarget = 5000000.0,
    this.monthlySales = const [0.0, 0.0, 0.0],
    this.clients = const [],
  });

  final String id;
  final String name;
  final String specialization;
  final int activeClients;
  final int packagesSold;
  final double totalSales;
  final String? photoUrl;
  final String status;
  final double quarterlyTarget;
  final List<double> monthlySales;
  final List<ManagerClientItem> clients;

  double get achievementPercentage =>
      quarterlyTarget > 0 ? (totalSales / quarterlyTarget) * 100 : 0.0;
  bool get isTargetAchieved => totalSales >= quarterlyTarget;
  double get remainingAmount =>
      (quarterlyTarget - totalSales).clamp(0.0, double.infinity);
}

/// Aggregated data model for Manager Dashboard in a given quarter and year.
class ManagerDashboardData {
  const ManagerDashboardData({
    required this.totalActivePt,
    required this.totalActiveClients,
    required this.totalPackagesSold,
    required this.totalSales,
    required this.monthlySales,
    required this.trainers,
    this.projectionPending = false,
  });

  final bool projectionPending;

  const ManagerDashboardData.empty()
    : projectionPending = false,
      totalActivePt = 0,
      totalActiveClients = 0,
      totalPackagesSold = 0,
      totalSales = 0.0,
      monthlySales = const [0.0, 0.0, 0.0],
      trainers = const [];

  final int totalActivePt;
  final int totalActiveClients;
  final int totalPackagesSold;
  final double totalSales;
  final List<double>
  monthlySales; // 3 values for the 3 months of the selected quarter
  final List<TrainerPerformance> trainers;

  bool get isEmpty =>
      totalActivePt == 0 &&
      totalActiveClients == 0 &&
      totalPackagesSold == 0 &&
      totalSales == 0 &&
      trainers.isEmpty;
}

/// Period representation (Year + Quarter).
class DashboardPeriod {
  const DashboardPeriod({required this.year, required this.quarter});

  final int year;
  final int quarter; // 1, 2, 3, 4

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardPeriod &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          quarter == other.quarter;

  @override
  int get hashCode => Object.hash(year, quarter);

  List<String> get monthLabels {
    switch (quarter) {
      case 1:
        return const ['Jan', 'Feb', 'Mar'];
      case 2:
        return const ['Apr', 'Mei', 'Jun'];
      case 3:
        return const ['Jul', 'Agu', 'Sep'];
      case 4:
      default:
        return const ['Okt', 'Nov', 'Des'];
    }
  }
}

/// Abstract contract for Manager Dashboard repository.
abstract class ManagerDashboardRepository {
  Future<ManagerDashboardData> fetchDashboardData({
    required int year,
    required int quarter,
  });
}

/// Optional live read-model contract keeps existing repository fakes compatible.
abstract class LiveManagerDashboardRepository {
  Stream<ManagerDashboardData> watchDashboardData({
    required int year,
    required int quarter,
  });
}

/// In-memory / Mock implementation for Manager Dashboard repository.
class InMemoryManagerDashboardRepository implements ManagerDashboardRepository {
  InMemoryManagerDashboardRepository({
    ManagerDashboardData? initialData,
    this.shouldThrow = false,
  }) : _data = initialData ?? const ManagerDashboardData.empty();

  final ManagerDashboardData _data;
  final bool shouldThrow;

  @override
  Future<ManagerDashboardData> fetchDashboardData({
    required int year,
    required int quarter,
  }) async {
    if (shouldThrow) {
      throw Exception('Gagal memuat data dashboard');
    }
    return _data;
  }
}

/// Default SQLite-backed implementation for Manager Dashboard repository.
class SqliteManagerDashboardRepository implements ManagerDashboardRepository {
  SqliteManagerDashboardRepository(this.db);
  final AppDatabase db;

  static double priceForSessions(int totalSessions) {
    switch (totalSessions) {
      case 4:
        return 500000.0;
      case 8:
      case 10:
        return 1000000.0;
      case 12:
        return 1500000.0;
      case 16:
        return 1600000.0;
      case 24:
        return 2000000.0;
      default:
        return (totalSessions * 125000).toDouble();
    }
  }

  @override
  Future<ManagerDashboardData> fetchDashboardData({
    required int year,
    required int quarter,
  }) async {
    final trainers = await db.select(db.trainers).get();
    final allClients = await db.select(db.clients).get();
    final allPackages = await db.select(db.ptPackages).get();
    final allSessions = await db.select(db.sessions).get();

    final startMonth = (quarter - 1) * 3 + 1;
    final endMonth = startMonth + 2;

    final quarterPackages = allPackages.where((p) {
      return p.createdAt.year == year &&
          p.createdAt.month >= startMonth &&
          p.createdAt.month <= endMonth;
    }).toList();

    final monthlySales = [0.0, 0.0, 0.0];
    for (final pkg in quarterPackages) {
      final monthIndex = pkg.createdAt.month - startMonth;
      if (monthIndex >= 0 && monthIndex < 3) {
        monthlySales[monthIndex] += priceForSessions(pkg.totalSessions);
      }
    }

    final totalSales = monthlySales.reduce((a, b) => a + b);
    final activeClientsList = allClients.where((c) {
      final clientPkgs = allPackages.where((p) => p.clientId == c.id);
      return clientPkgs.any((p) => p.status == 'active');
    }).toList();

    final trainerPerformances = <TrainerPerformance>[];
    for (final trainer in trainers) {
      final trainerClients = allClients
          .where((c) => c.trainerId == trainer.id)
          .toList();
      final trainerClientIds = trainerClients.map((c) => c.id).toSet();

      final activeTrainerClients = trainerClients.where((c) {
        final clientPkgs = allPackages.where((p) => p.clientId == c.id);
        return clientPkgs.any((p) => p.status == 'active');
      }).length;

      final trainerQuarterPkgs = quarterPackages
          .where((p) => trainerClientIds.contains(p.clientId))
          .toList();

      final trainerMonthlySales = [0.0, 0.0, 0.0];
      for (final p in trainerQuarterPkgs) {
        final mIdx = p.createdAt.month - startMonth;
        if (mIdx >= 0 && mIdx < 3) {
          trainerMonthlySales[mIdx] += priceForSessions(p.totalSessions);
        }
      }

      final trainerSales = trainerQuarterPkgs.fold<double>(
        0.0,
        (acc, p) => acc + priceForSessions(p.totalSessions),
      );

      final clientItems = <ManagerClientItem>[];
      for (final c in trainerClients) {
        final clientPkgs = allPackages
            .where((p) => p.clientId == c.id)
            .toList();
        final clientPkgIds = clientPkgs.map((p) => p.id).toSet();
        final activePkg =
            clientPkgs.where((p) => p.status == 'active').firstOrNull ??
            clientPkgs.firstOrNull;
        final totalSessions = activePkg?.totalSessions ?? 4;
        final packageName = 'Paket $totalSessions Sesi';
        final cSessions = allSessions
            .where((s) => clientPkgIds.contains(s.packageId))
            .toList();
        final attended = cSessions.where((s) => s.status == 'completed').length;
        final remaining = (totalSessions - attended).clamp(0, totalSessions);

        final records = cSessions.map((s) {
          return ManagerClientAttendanceRecord(
            sessionNumber: s.sessionNumber,
            scheduledTime: s.scheduledAt,
            status: s.status,
          );
        }).toList();

        clientItems.add(
          ManagerClientItem(
            id: c.id.toString(),
            name: c.name,
            packageName: packageName,
            totalSessions: totalSessions,
            attendedSessions: attended,
            remainingSessions: remaining,
            attendanceRecords: records,
          ),
        );
      }

      trainerPerformances.add(
        TrainerPerformance(
          id: trainer.id.toString(),
          name: trainer.name,
          specialization: 'Fitness & Conditioning',
          activeClients: activeTrainerClients,
          packagesSold: trainerQuarterPkgs.length,
          totalSales: trainerSales,
          quarterlyTarget: 5000000.0,
          monthlySales: trainerMonthlySales,
          clients: clientItems,
        ),
      );
    }

    final activePtCount = trainers.length;

    return ManagerDashboardData(
      totalActivePt: activePtCount,
      totalActiveClients: activeClientsList.length,
      totalPackagesSold: quarterPackages.length,
      totalSales: totalSales,
      monthlySales: monthlySales,
      trainers: trainerPerformances,
    );
  }
}

/// Firestore implementation backed only by trusted manager read models.
///
/// The app never follows a `clients/*` reference for a manager. A privileged
/// projection job materialises only operational attendance fields below:
/// `manager_dashboard/{year}-Q{quarter}/trainers/{trainerId}/clients/{clientId}`.
class FirestoreManagerDashboardRepository
    implements ManagerDashboardRepository, LiveManagerDashboardRepository {
  FirestoreManagerDashboardRepository(this.firestore);
  final FirebaseFirestore firestore;

  static String periodId(int year, int quarter) => '$year-Q$quarter';

  // Trusted source reconciliation publishes the period marker after its children.
  // Never subscribe to sensitive source collections from a manager client.
  @override
  Stream<ManagerDashboardData> watchDashboardData({
    required int year,
    required int quarter,
  }) => firestore
      .collection('manager_dashboard')
      .doc(periodId(year, quarter))
      .snapshots()
      .asyncMap((_) => fetchDashboardData(year: year, quarter: quarter));

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const FormatException('Tanggal absensi pada read model tidak valid.');
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;
  static double _double(Object? value) => (value as num?)?.toDouble() ?? 0;
  static List<double> _monthlySales(Object? value) {
    final values = value is List
        ? value.map(_double).take(3).toList()
        : <double>[];
    return [...values, ...List<double>.filled(3 - values.length, 0)];
  }

  @override
  Future<ManagerDashboardData> fetchDashboardData({
    required int year,
    required int quarter,
  }) async {
    final period = firestore
        .collection('manager_dashboard')
        .doc(periodId(year, quarter));
    final summary = await period.get();
    if (!summary.exists) {
      return const ManagerDashboardData(
        totalActivePt: 0,
        totalActiveClients: 0,
        totalPackagesSold: 0,
        totalSales: 0,
        monthlySales: [0, 0, 0],
        trainers: [],
        projectionPending: true,
      );
    }
    final dashboard = summary.data()!;
    final trainerSnapshots = await period.collection('trainers').get();
    final trainers = <TrainerPerformance>[];

    for (final trainerSnapshot in trainerSnapshots.docs) {
      final trainer = trainerSnapshot.data();
      final clientSnapshots = await trainerSnapshot.reference
          .collection('clients')
          .get();
      final clients = <ManagerClientItem>[];
      for (final clientSnapshot in clientSnapshots.docs) {
        final client = clientSnapshot.data();
        final attendanceSnapshots = await clientSnapshot.reference
            .collection('attendance')
            .orderBy('sessionNumber')
            .get();
        final attendance = attendanceSnapshots.docs
            .map((recordSnapshot) {
              final record = recordSnapshot.data();
              return ManagerClientAttendanceRecord(
                sessionNumber: _int(record['sessionNumber']),
                scheduledTime: _date(record['scheduledTime']),
                status: record['status'] as String? ?? 'scheduled',
              );
            })
            .toList(growable: false);
        clients.add(
          ManagerClientItem(
            id: clientSnapshot.id,
            status: client['status'] as String? ?? 'unknown',
            name: client['name'] as String? ?? 'Klien',
            packageName: client['packageName'] as String? ?? 'Paket PT',
            totalSessions: _int(client['totalSessions']),
            attendedSessions: _int(client['attendedSessions']),
            remainingSessions: _int(client['remainingSessions']),
            attendanceRecords: attendance,
          ),
        );
      }
      final rawName = (trainer['displayName'] as String?)?.trim();
      final altName = (trainer['name'] as String?)?.trim();
      final resolvedName =
          (rawName != null && rawName.isNotEmpty && rawName != 'PT')
          ? rawName
          : (altName != null && altName.isNotEmpty && altName != 'PT')
          ? altName
          : 'Coach Mbois';
      trainers.add(
        TrainerPerformance(
          id: trainerSnapshot.id,
          name: resolvedName,
          specialization:
              trainer['specialization'] as String? ?? 'Personal Trainer',
          activeClients: clients.where((c) => c.isActive).length,
          packagesSold: _int(trainer['packagesSold']),
          totalSales: _double(trainer['totalSales']),
          photoUrl: trainer['photoUrl'] as String?,
          status: trainer['status'] as String? ?? 'active',
          quarterlyTarget: _double(trainer['quarterlyTarget']) == 0
              ? 5000000.0
              : _double(trainer['quarterlyTarget']),
          monthlySales: _monthlySales(trainer['monthlySales']),
          clients: clients,
        ),
      );
    }

    int activePtCount = _int(dashboard['totalActivePt']);
    if (activePtCount == 0 && trainers.isNotEmpty) {
      activePtCount = trainers.where((t) => t.status == 'active').length;
    }

    return ManagerDashboardData(
      totalActivePt: activePtCount,
      totalActiveClients: trainers
          .expand((t) => t.clients)
          .where((c) => c.isActive)
          .map((c) => c.id)
          .toSet()
          .length,
      totalPackagesSold: _int(dashboard['totalPackagesSold']),
      totalSales: _double(dashboard['totalSales']),
      monthlySales: _monthlySales(dashboard['monthlySales']),
      trainers: trainers,
    );
  }
}

/// Provider for Manager Dashboard Repository.
final managerDashboardRepositoryProvider = Provider<ManagerDashboardRepository>(
  (ref) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirestoreManagerDashboardRepository(FirebaseFirestore.instance);
      } catch (_) {
        // Fallback if firestore instance unavailable
      }
    }
    try {
      final db = ref.watch(databaseProvider);
      return SqliteManagerDashboardRepository(db);
    } catch (_) {
      return InMemoryManagerDashboardRepository();
    }
  },
);

/// Currency formatter helper for Rupiah.
String formatRupiah(num amount) {
  final isNegative = amount < 0;
  final absAmount = amount.abs().round();
  final digits = absAmount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final sign = isNegative ? '-' : '';
  return '${sign}Rp ${buffer.toString()}';
}

/// ManagerDashboardScreen widget implementation.
class ManagerDashboardScreen extends ConsumerStatefulWidget {
  const ManagerDashboardScreen({
    super.key,
    this.repository,
    this.initialYear,
    this.initialQuarter,
    this.initialTarget = 5000000.0,
  });

  final ManagerDashboardRepository? repository;
  final int? initialYear;
  final int? initialQuarter;
  final double initialTarget;

  @override
  ConsumerState<ManagerDashboardScreen> createState() =>
      _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState
    extends ConsumerState<ManagerDashboardScreen> {
  late int _selectedYear;
  late int _selectedQuarter;
  late double _quarterlyTarget;

  bool _isLoading = true;
  String? _errorMessage;
  ManagerDashboardData? _dashboardData;
  StreamSubscription<ManagerDashboardData>? _subscription;
  int _generation = 0;
  final ValueNotifier<ManagerDashboardData?> _liveData = ValueNotifier(null);

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _liveData.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = widget.initialYear ?? now.year;
    _selectedQuarter = widget.initialQuarter ?? (((now.month - 1) ~/ 3) + 1);
    _quarterlyTarget = widget.initialTarget;
    _loadData();
  }

  Future<void> _loadData() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (!mounted || generation != _generation) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    void accept(ManagerDashboardData data) {
      if (!mounted || generation != _generation) return;
      _liveData.value = data;
      setState(() {
        _dashboardData = data;
        _isLoading = false;
        _errorMessage = null;
      });
    }

    void fail(Object error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }

    final ManagerDashboardRepository repo =
        widget.repository ?? ref.read(managerDashboardRepositoryProvider);
    if (repo is LiveManagerDashboardRepository) {
      _subscription = (repo as LiveManagerDashboardRepository)
          .watchDashboardData(year: _selectedYear, quarter: _selectedQuarter)
          .listen(accept, onError: fail);
    } else {
      try {
        accept(
          await repo.fetchDashboardData(
            year: _selectedYear,
            quarter: _selectedQuarter,
          ),
        );
      } catch (e) {
        fail(e);
      }
    }
  }

  void _showEditTargetDialog() {
    final controller = TextEditingController(
      text: _quarterlyTarget.toInt().toString(),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: const Text('Ubah Target Triwulan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Penjualan (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final newTarget = double.tryParse(controller.text.trim());
                if (newTarget != null && newTarget > 0) {
                  setState(() {
                    _quarterlyTarget = newTarget;
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _textPrimary => _colors.onSurface;
  Color get _textSecondary => _colors.onSurfaceVariant;
  Color get _textMuted => _colors.onSurfaceVariant;
  Color get _containerBg => _colors.surfaceContainerLow;
  Color get _containerBorder => _colors.outlineVariant;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Konfirmasi Keluar'),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari aplikasi?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).scaffoldBackgroundColor
            : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Dashboard Manajemen PT',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF0F172A),
          elevation: 0.5,
          actions: [
            IconButton(
              tooltip: 'Profil & Pengaturan',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.go('/settings'),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderFilters(),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorState()
                  else ...[
                    if (_dashboardData!.projectionPending)
                      _buildProjectionPending(_dashboardData!.totalActivePt),
                    _buildKpiCards(_dashboardData!),
                    const SizedBox(height: 16),
                    if (!_dashboardData!.projectionPending) ...[
                      _buildTargetCard(_dashboardData!),
                      const SizedBox(height: 16),
                      _buildChartCard(_dashboardData!),
                      const SizedBox(height: 16),
                      _buildTrainerPerformanceSection(_dashboardData!),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderFilters() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 20, color: _colors.primary),
                SizedBox(width: 8),
                Text(
                  'Periode:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Triwulan Selector
                DropdownButton<int>(
                  value: _selectedQuarter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Q1')),
                    DropdownMenuItem(value: 2, child: Text('Q2')),
                    DropdownMenuItem(value: 3, child: Text('Q3')),
                    DropdownMenuItem(value: 4, child: Text('Q4')),
                  ],
                  onChanged: (val) {
                    if (val != null && val != _selectedQuarter) {
                      setState(() {
                        _selectedQuarter = val;
                      });
                      _loadData();
                    }
                  },
                ),
                // Year Selector
                DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  items: [2024, 2025, 2026, 2027].map((y) {
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedYear) {
                      setState(() {
                        _selectedYear = val;
                      });
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: _colors.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionPending(int activePt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.tertiary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: _colors.onTertiaryContainer,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Proyeksi Dashboard Belum Tersedia',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _colors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tercatat $activePt Personal Trainer aktif di sistem. Data agregat penjualan, capaian target, dan rincian klien untuk periode Q$_selectedQuarter $_selectedYear belum disinkronkan oleh Admin ke read-model terisolasi.',
            style: TextStyle(
              fontSize: 13,
              color: _colors.onTertiaryContainer,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Peringatan: Nilai di bawah menunjukkan status pending sinkronisasi dan bukan nol penjualan riil. Tidak ada data dummy yang digunakan.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: _colors.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Periksa Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _colors.onTertiaryContainer,
                side: BorderSide(color: _colors.onTertiaryContainer),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards(ManagerDashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Total PT Aktif',
              value: '${data.totalActivePt}',
              icon: Icons.fitness_center,
              iconColor: _colors.primary,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Total Klien Aktif',
              value: data.projectionPending
                  ? 'Menunggu sinkronisasi'
                  : '${data.totalActiveClients}',
              icon: Icons.people_alt_outlined,
              iconColor: _colors.secondary,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Paket PT Terjual',
              value: data.projectionPending
                  ? 'Menunggu sinkronisasi'
                  : '${data.totalPackagesSold}',
              icon: Icons.inventory_2_outlined,
              iconColor: _colors.tertiary,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Total Penjualan',
              subtitle: 'Nilai Paket Terjual',
              value: data.projectionPending
                  ? 'Menunggu sinkronisasi'
                  : formatRupiah(data.totalSales),
              icon: Icons.payments_outlined,
              iconColor: _colors.secondary,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    String? subtitle,
    required String value,
    required IconData icon,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _containerBorder),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black26
                : const Color(0x08000000),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: _textMuted)),
          ],
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(ManagerDashboardData data) {
    final achievementPercentage = _quarterlyTarget > 0
        ? (data.totalSales / _quarterlyTarget) * 100
        : 0.0;
    final remainingAmount = (_quarterlyTarget - data.totalSales).clamp(
      0.0,
      double.infinity,
    );
    final progress = _quarterlyTarget > 0
        ? (data.totalSales / _quarterlyTarget).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Target Triwulan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showEditTargetDialog,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Ubah Target'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Target: ${formatRupiah(_quarterlyTarget)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
                Text(
                  'Pencapaian: ${achievementPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: achievementPercentage >= 100
                        ? _colors.secondary
                        : _colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: _containerBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  achievementPercentage >= 100
                      ? _colors.secondary
                      : _colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sisa Menuju Target: ${formatRupiah(remainingAmount)}',
              style: TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(ManagerDashboardData data) {
    final period = DashboardPeriod(
      year: _selectedYear,
      quarter: _selectedQuarter,
    );
    final monthLabels = period.monthLabels;
    final maxSales = data.monthlySales.isEmpty
        ? 1.0
        : data.monthlySales.reduce((a, b) => a > b ? a : b);
    final maxY = maxSales == 0 ? 1000000.0 : maxSales * 1.25;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Grafik Penjualan Bulanan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  'Q$_selectedQuarter $_selectedYear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${monthLabels[group.x.toInt()]}\n${formatRupiah(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (val, meta) {
                          if (val == 0) return const SizedBox();
                          final juta = val / 1000000;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${juta.toStringAsFixed(1)}jt',
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 9, color: _textMuted),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < monthLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                monthLabels[idx],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: _isDark ? Colors.white12 : _containerBorder,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(3, (idx) {
                    final amount = idx < data.monthlySales.length
                        ? data.monthlySales[idx]
                        : 0.0;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: amount,
                          color: _colors.primary,
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerPerformanceSection(ManagerDashboardData data) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daftar Perbandingan Kinerja PT',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (data.trainers.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.trainers.length,
                separatorBuilder: (context, index) => const Divider(height: 20),
                itemBuilder: (ctx, idx) {
                  final pt = data.trainers[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InitialAvatar(
                              name: pt.name,
                              radius: 20,
                              backgroundColor: _colors.primaryContainer,
                              foregroundColor: _colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pt.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pt.status == 'active'
                                              ? _colors.secondaryContainer
                                              : _containerBg,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          pt.status == 'active'
                                              ? 'Aktif'
                                              : 'Nonaktif',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: pt.status == 'active'
                                                ? _colors.onSecondaryContainer
                                                : _textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pt.specialization,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatRupiah(pt.totalSales),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _colors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _containerBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Klien Aktif: ${pt.activeClients}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _containerBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Paket Terjual: ${pt.packagesSold}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pt.isTargetAchieved
                                    ? _colors.secondaryContainer
                                    : _colors.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pt.isTargetAchieved
                                    ? 'Target Tercapai ✓ (${pt.achievementPercentage.toStringAsFixed(1)}%)'
                                    : 'Belum Tercapai (${pt.achievementPercentage.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: pt.isTargetAchieved
                                      ? _colors.onSecondaryContainer
                                      : _colors.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (pt.totalSales / pt.quarterlyTarget).clamp(
                              0.0,
                              1.0,
                            ),
                            minHeight: 6,
                            backgroundColor: _containerBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pt.isTargetAchieved
                                  ? _colors.secondary
                                  : _colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Target: ${formatRupiah(pt.quarterlyTarget)}',
                              style: TextStyle(fontSize: 11, color: _textMuted),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                foregroundColor: _colors.primary,
                              ),
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: const Text(
                                'Detail PT & Klien',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => _showTrainerDetail(context, pt),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showTrainerDetail(BuildContext context, TrainerPerformance originalPt) {
    final ptId = originalPt.id;
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (ctx) => ValueListenableBuilder<ManagerDashboardData?>(
          valueListenable: _liveData,
          builder: (ctx, data, _) {
            final pt =
                data?.trainers.where((t) => t.id == ptId).firstOrNull ??
                originalPt;
            return Scaffold(
              appBar: AppBar(title: Text(pt.name)),
              body: DraggableScrollableSheet(
                initialChildSize: 1,
                minChildSize: 1,
                maxChildSize: 1,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _containerBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              InitialAvatar(
                                name: pt.name,
                                radius: 24,
                                backgroundColor: _colors.primaryContainer,
                                foregroundColor: _colors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pt.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pt.specialization,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Target Achievement Card
                              Card(
                                elevation: 0,
                                color: _containerBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: _containerBorder),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Target Penjualan Triwulan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: _textPrimary,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: pt.isTargetAchieved
                                                  ? _colors.secondaryContainer
                                                  : _colors.tertiaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              pt.isTargetAchieved
                                                  ? 'Target Tercapai ✓'
                                                  : 'Belum Tercapai',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: pt.isTargetAchieved
                                                    ? _colors
                                                          .onSecondaryContainer
                                                    : _colors
                                                          .onTertiaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Nilai Paket Terjual Tercatat: ${formatRupiah(pt.totalSales)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Target: ${formatRupiah(pt.quarterlyTarget)} (${pt.achievementPercentage.toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                        ),
                                      ),
                                      if (!pt.isTargetAchieved) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Sisa Target: ${formatRupiah(pt.remainingAmount)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _colors.tertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        'Rincian Bulanan Triwulan Ini:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: List.generate(3, (i) {
                                          final labels = DashboardPeriod(
                                            year: _selectedYear,
                                            quarter: _selectedQuarter,
                                          ).monthLabels;
                                          final amt = i < pt.monthlySales.length
                                              ? pt.monthlySales[i]
                                              : 0.0;
                                          return Column(
                                            children: [
                                              Text(
                                                labels[i],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                formatRupiah(amt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _textPrimary,
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.people_outline),
                                label: const Text(
                                  'Daftar Klien yang Ditangani',
                                ),
                                onPressed: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ValueListenableBuilder<
                                          ManagerDashboardData?
                                        >(
                                          valueListenable: _liveData,
                                          builder: (_, data, _) =>
                                              ManagerClientHistoryScreen(
                                                trainer:
                                                    data?.trainers
                                                        .where(
                                                          (t) => t.id == pt.id,
                                                        )
                                                        .firstOrNull ??
                                                    pt,
                                                onAttendance: (context, client) =>
                                                    _showClientAttendanceDetail(
                                                      context,
                                                      client,
                                                    ),
                                              ),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showClientAttendanceDetail(
    BuildContext context,
    ManagerClientItem client,
  ) {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Detail Absensi Klien')),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.event_available, color: _colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Read-Only • ${client.name} • ${client.statusLabel}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textMuted,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Info Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _containerBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _containerBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Paket yang Diikuti:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textMuted,
                                  ),
                                ),
                                Text(
                                  client.packageName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sesi Dihadiri:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textMuted,
                                  ),
                                ),
                                Text(
                                  '${client.attendedSessions} Sesi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _colors.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sesi Belum Dijalani:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textMuted,
                                  ),
                                ),
                                Text(
                                  '${client.remainingSessions} Sesi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Riwayat Jadwal & Kehadiran Sesi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (client.attendanceRecords.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: Text(
                            'Belum ada jadwal sesi tercatat.',
                            style: TextStyle(fontSize: 12, color: _textMuted),
                          ),
                        )
                      else
                        ...client.attendanceRecords.map((rec) {
                          final dtStr =
                              '${rec.scheduledTime.day.toString().padLeft(2, '0')}/${rec.scheduledTime.month.toString().padLeft(2, '0')}/${rec.scheduledTime.year} • ${rec.scheduledTime.hour.toString().padLeft(2, '0')}:${rec.scheduledTime.minute.toString().padLeft(2, '0')}';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _containerBorder),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: _containerBg,
                                  child: Text(
                                    '${rec.sessionNumber}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sesi ${rec.sessionNumber}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        dtStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: rec.statusColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    rec.statusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: rec.statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 10),
                      Text(
                        'Catatan Privasi: Asesmen kesehatan, catatan latihan rahasia, dan tanda tangan klien tidak ditampilkan.',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: _containerBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_outlined, size: 48, color: _textMuted),
          const SizedBox(height: 8),
          Text(
            'Belum ada data kinerja PT pada periode ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textMuted),
          ),
        ],
      ),
    );
  }
}
