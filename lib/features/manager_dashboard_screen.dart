import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_database.dart';
import '../app.dart' show databaseProvider;

/// Model for client attendance record in Manager read-only view.
class ManagerClientAttendanceRecord {
  const ManagerClientAttendanceRecord({
    required this.sessionNumber,
    required this.scheduledTime,
    required this.status, // 'completed', 'scheduled', 'cancelled'
    this.notes = '',
  });

  final int sessionNumber;
  final DateTime scheduledTime;
  final String status;
  final String notes;

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
  });

  final String id;
  final String name;
  final String packageName;
  final int totalSessions;
  final int attendedSessions;
  final int remainingSessions;
  final List<ManagerClientAttendanceRecord> attendanceRecords;
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
  });

  const ManagerDashboardData.empty()
      : totalActivePt = 0,
        totalActiveClients = 0,
        totalPackagesSold = 0,
        totalSales = 0.0,
        monthlySales = const [0.0, 0.0, 0.0],
        trainers = const [];

  final int totalActivePt;
  final int totalActiveClients;
  final int totalPackagesSold;
  final double totalSales;
  final List<double> monthlySales; // 3 values for the 3 months of the selected quarter
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
      final trainerClients =
          allClients.where((c) => c.trainerId == trainer.id).toList();
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
        final clientPkgs = allPackages.where((p) => p.clientId == c.id).toList();
        final clientPkgIds = clientPkgs.map((p) => p.id).toSet();
        final activePkg = clientPkgs.where((p) => p.status == 'active').firstOrNull ?? clientPkgs.firstOrNull;
        final totalSessions = activePkg?.totalSessions ?? 4;
        final packageName = 'Paket $totalSessions Sesi';
        final cSessions = allSessions.where((s) => clientPkgIds.contains(s.packageId)).toList();
        final attended = cSessions.where((s) => s.status == 'completed').length;
        final remaining = (totalSessions - attended).clamp(0, totalSessions);

        final records = cSessions.map((s) {
          return ManagerClientAttendanceRecord(
            sessionNumber: s.sessionNumber,
            scheduledTime: s.scheduledAt,
            status: s.status,
            notes: s.notes,
          );
        }).toList();

        clientItems.add(ManagerClientItem(
          id: c.id.toString(),
          name: c.name,
          packageName: packageName,
          totalSessions: totalSessions,
          attendedSessions: attended,
          remainingSessions: remaining,
          attendanceRecords: records,
        ));
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

    final activePtCount = trainers.where((t) {
      final tClients = allClients.where((c) => c.trainerId == t.id);
      return tClients.isNotEmpty;
    }).length;

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

/// Cloud Firestore implementation for Manager Dashboard repository.
class FirestoreManagerDashboardRepository
    implements ManagerDashboardRepository {
  FirestoreManagerDashboardRepository(this.firestore);
  final FirebaseFirestore firestore;

  @override
  Future<ManagerDashboardData> fetchDashboardData({
    required int year,
    required int quarter,
  }) async {
    final startMonth = (quarter - 1) * 3 + 1;
    final endMonth = startMonth + 2;

    // 1. Fetch trainers
    final usersSnap = await firestore
        .collection('users')
        .where('role', isEqualTo: 'trainer')
        .get();

    // 2. Fetch sales
    final salesSnap = await firestore.collection('package_sales').get();
    final allSales = salesSnap.docs.map((d) => d.data()).toList();

    final quarterSales = allSales.where((s) {
      final ts = s['timestamp'];
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is String) {
        dt = DateTime.tryParse(ts) ?? DateTime.now();
      } else {
        return false;
      }
      final isValid = s['status'] == null || s['status'] == 'valid';
      return dt.year == year &&
          dt.month >= startMonth &&
          dt.month <= endMonth &&
          isValid;
    }).toList();

    // 3. Fetch clients
    final clientsSnap = await firestore.collection('clients').get();
    final allClientDocs = clientsSnap.docs;

    final gymMonthlySales = [0.0, 0.0, 0.0];
    for (final s in quarterSales) {
      final ts = s['timestamp'];
      final dt = ts is Timestamp
          ? ts.toDate()
          : (DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now());
      final mIdx = dt.month - startMonth;
      if (mIdx >= 0 && mIdx < 3) {
        final price = (s['price'] as num?)?.toDouble() ?? 0.0;
        gymMonthlySales[mIdx] += price;
      }
    }
    final totalGymSales = gymMonthlySales.reduce((a, b) => a + b);

    final trainers = <TrainerPerformance>[];
    int totalActiveClients = 0;

    for (final userDoc in usersSnap.docs) {
      final uData = userDoc.data();
      final trainerId = userDoc.id;
      final trainerName = (uData['displayName'] as String?)?.trim().isNotEmpty == true
          ? (uData['displayName'] as String).trim()
          : (uData['name'] as String?)?.trim().isNotEmpty == true
              ? (uData['name'] as String).trim()
              : 'PT';
      final specialization =
          uData['specialization'] as String? ?? 'Personal Trainer';
      final photoUrl = uData['photoUrl'] as String?;
      final status = uData['status'] as String? ?? 'active';

      // Trainer's sales
      final trainerSales =
          quarterSales.where((s) => s['trainerId'] == trainerId).toList();
      final trainerMonthlySales = [0.0, 0.0, 0.0];
      for (final s in trainerSales) {
        final ts = s['timestamp'];
        final dt = ts is Timestamp
            ? ts.toDate()
            : (DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now());
        final mIdx = dt.month - startMonth;
        if (mIdx >= 0 && mIdx < 3) {
          final price = (s['price'] as num?)?.toDouble() ?? 0.0;
          trainerMonthlySales[mIdx] += price;
        }
      }
      final trainerTotalSales = trainerMonthlySales.reduce((a, b) => a + b);

      // Trainer's clients
      final trainerClientDocs = allClientDocs.where((c) {
        final assigned = c.data()['assignedTrainerIds'];
        if (assigned is List) return assigned.contains(trainerId);
        return false;
      }).toList();

      final clientItems = <ManagerClientItem>[];
      for (final cDoc in trainerClientDocs) {
        final cData = cDoc.data();
        final cName = cData['name'] as String? ?? 'Klien';

        // Read packages
        final pkgsSnap = await cDoc.reference.collection('packages').get();
        final activePkg = pkgsSnap.docs
            .where((p) => p.data()['status'] == 'active')
            .firstOrNull;
        final totalSessions =
            (activePkg?.data()['totalSessions'] as num?)?.toInt() ?? 4;
        final packageName = activePkg != null
            ? 'Paket $totalSessions Sesi'
            : 'Paket Selesai';

        // Read sessions
        final sessSnap = await cDoc.reference
            .collection('sessions')
            .orderBy('sessionNumber')
            .get();
        final records = <ManagerClientAttendanceRecord>[];
        int completedCount = 0;

        for (final sDoc in sessSnap.docs) {
          final sData = sDoc.data();
          final sNum = (sData['sessionNumber'] as num?)?.toInt() ?? 1;
          final sStatus = sData['status'] as String? ?? 'scheduled';
          final sTime = sData['scheduledTime'] is Timestamp
              ? (sData['scheduledTime'] as Timestamp).toDate()
              : (DateTime.tryParse(sData['scheduledTime']?.toString() ?? '') ??
                  DateTime.now());
          final sNotes = sData['notes'] as String? ?? '';

          if (sStatus == 'completed') completedCount++;
          records.add(ManagerClientAttendanceRecord(
            sessionNumber: sNum,
            scheduledTime: sTime,
            status: sStatus,
            notes: sNotes,
          ));
        }

        final remaining =
            (totalSessions - completedCount).clamp(0, totalSessions);
        clientItems.add(ManagerClientItem(
          id: cDoc.id,
          name: cName,
          packageName: packageName,
          totalSessions: totalSessions,
          attendedSessions: completedCount,
          remainingSessions: remaining,
          attendanceRecords: records,
        ));
      }

      totalActiveClients += trainerClientDocs.length;
      trainers.add(TrainerPerformance(
        id: trainerId,
        name: trainerName,
        specialization: specialization,
        activeClients: trainerClientDocs.length,
        packagesSold: trainerSales.length,
        totalSales: trainerTotalSales,
        photoUrl: photoUrl,
        status: status,
        quarterlyTarget: 5000000.0,
        monthlySales: trainerMonthlySales,
        clients: clientItems,
      ));
    }

    return ManagerDashboardData(
      totalActivePt: trainers.where((t) => t.status == 'active').length,
      totalActiveClients: totalActiveClients,
      totalPackagesSold: quarterSales.length,
      totalSales: totalGymSales,
      monthlySales: gymMonthlySales,
      trainers: trainers,
    );
  }
}

/// Provider for Manager Dashboard Repository.
final managerDashboardRepositoryProvider =
    Provider<ManagerDashboardRepository>((ref) {
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
});

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ManagerDashboardRepository repo =
          widget.repository ?? ref.read(managerDashboardRepositoryProvider);
      final data = await repo.fetchDashboardData(
        year: _selectedYear,
        quarter: _selectedQuarter,
      );
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Dashboard Manajemen PT',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
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
                  _buildKpiCards(_dashboardData!),
                  const SizedBox(height: 16),
                  _buildTargetCard(_dashboardData!),
                  const SizedBox(height: 16),
                  _buildChartCard(_dashboardData!),
                  const SizedBox(height: 16),
                  _buildTrainerPerformanceSection(_dashboardData!),
                ],
              ],
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
              children: const [
                Icon(Icons.tune, size: 20, color: Color(0xFF0088FF)),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
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
              iconColor: const Color(0xFF0088FF),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Total Klien Aktif',
              value: '${data.totalActiveClients}',
              icon: Icons.people_alt_outlined,
              iconColor: const Color(0xFF0F8780),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Paket PT Terjual',
              value: '${data.totalPackagesSold}',
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFFF59E0B),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Total Penjualan',
              subtitle: 'Nilai Paket Terjual',
              value: formatRupiah(data.totalSales),
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF10B981),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
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
    final remainingAmount = (_quarterlyTarget - data.totalSales).clamp(0.0, double.infinity);
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
                const Text(
                  'Target Triwulan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  'Pencapaian: ${achievementPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: achievementPercentage >= 100
                        ? Colors.green
                        : const Color(0xFF0088FF),
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
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  achievementPercentage >= 100
                      ? Colors.green
                      : const Color(0xFF0088FF),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sisa Menuju Target: ${formatRupiah(remainingAmount)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
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
                const Text(
                  'Grafik Penjualan Bulanan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Q$_selectedQuarter $_selectedYear',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
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
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
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
                          color: const Color(0xFF0088FF),
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
            const Text(
              'Daftar Perbandingan Kinerja PT',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
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
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFD4ECFF),
                              backgroundImage: pt.photoUrl != null &&
                                      pt.photoUrl!.isNotEmpty
                                  ? NetworkImage(pt.photoUrl!)
                                  : null,
                              child: (pt.photoUrl == null ||
                                      pt.photoUrl!.isEmpty)
                                  ? Text(
                                      pt.name.isNotEmpty
                                          ? pt.name.substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0088FF),
                                      ),
                                    )
                                  : null,
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
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
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          pt.status == 'active'
                                              ? 'Aktif'
                                              : 'Nonaktif',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: pt.status == 'active'
                                                ? const Color(0xFF166534)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pt.specialization,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatRupiah(pt.totalSales),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF10B981),
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
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Klien Aktif: ${pt.activeClients}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Paket Terjual: ${pt.packagesSold}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
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
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
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
                                      ? const Color(0xFF166534)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (pt.totalSales / pt.quarterlyTarget)
                                .clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pt.isTargetAchieved
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF0088FF),
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
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                foregroundColor: const Color(0xFF0088FF),
                              ),
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: const Text(
                                'Detail PT & Klien',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () =>
                                  _showTrainerDetail(context, pt),
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

  void _showTrainerDetail(BuildContext context, TrainerPerformance pt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFD4ECFF),
                          backgroundImage: pt.photoUrl != null &&
                                  pt.photoUrl!.isNotEmpty
                              ? NetworkImage(pt.photoUrl!)
                              : null,
                          child: (pt.photoUrl == null || pt.photoUrl!.isEmpty)
                              ? Text(
                                  pt.name.isNotEmpty
                                      ? pt.name.substring(0, 1).toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF0088FF),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pt.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pt.specialization,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
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
                          color: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Target Penjualan Triwulan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pt.isTargetAchieved
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFFEF3C7),
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
                                              ? const Color(0xFF166534)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Nilai Paket Terjual Tercatat: ${formatRupiah(pt.totalSales)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Target: ${formatRupiah(pt.quarterlyTarget)} (${pt.achievementPercentage.toStringAsFixed(1)}%)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (!pt.isTargetAchieved) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sisa Target: ${formatRupiah(pt.remainingAmount)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                const Text(
                                  'Rincian Bulanan Triwulan Ini:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
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
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formatRupiah(amt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
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
                        const Text(
                          'Daftar Klien yang Ditangani',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (pt.clients.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Belum ada klien yang ditangani oleh PT ini.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pt.clients.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, cIdx) {
                              final client = pt.clients[cIdx];
                              return Card(
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    client.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${client.packageName} • ${client.attendedSessions} dari ${client.totalSessions} sesi dihadiri',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: Color(0xFF0088FF),
                                  ),
                                  onTap: () =>
                                      _showClientAttendanceDetail(context, client),
                                ),
                              );
                            },
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

  void _showClientAttendanceDetail(
      BuildContext context, ManagerClientItem client) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.event_available, color: Color(0xFF0088FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Absensi Klien',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Read-Only • ${client.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Paket yang Diikuti:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            client.packageName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sesi Dihadiri:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${client.attendedSessions} Sesi',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sesi Belum Dijalani:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${client.remainingSessions} Sesi',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0088FF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Riwayat Jadwal & Kehadiran Sesi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                if (client.attendanceRecords.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'Belum ada jadwal sesi tercatat.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFFF1F5F9),
                            child: Text(
                              '${rec.sessionNumber}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
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
                              color: rec.statusColor.withValues(alpha: 0.12),
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
                const Text(
                  'Catatan Privasi: Asesmen kesehatan, catatan latihan rahasia, dan tanda tangan klien tidak ditampilkan.',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Icon(Icons.bar_chart_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text(
            'Belum ada data kinerja PT pada periode ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
