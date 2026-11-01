import 'dart:math' as math;

import 'package:mbois_gym_pt/data/pt_packages.dart';

/// Target penjualan triwulan untuk dashboard manajer.
class QuarterlyTarget {
  final int year;
  final int quarter;
  final int targetAmount;

  const QuarterlyTarget({
    required this.year,
    required this.quarter,
    this.targetAmount = 5000000,
  }) : assert(quarter >= 1 && quarter <= 4, 'Quarter must be between 1 and 4');

  List<int> get months => switch (quarter) {
    1 => const [1, 2, 3],
    2 => const [4, 5, 6],
    3 => const [7, 8, 9],
    4 => const [10, 11, 12],
    _ => const [],
  };

  String get label => 'Q$quarter $year';

  bool contains(DateTime date) =>
      date.year == year && ((date.month - 1) ~/ 3) + 1 == quarter;
}

int getQuarterFromMonth(int month) => ((month - 1) ~/ 3) + 1;

int getQuarter(DateTime date) => getQuarterFromMonth(date.month);

/// Filter transaksi berdasarkan periode triwulan dan tahun.
List<PackageSaleRecord> filterSalesByQuarter(
  List<PackageSaleRecord> sales, {
  required int year,
  required int quarter,
}) {
  assert(quarter >= 1 && quarter <= 4, 'Quarter must be between 1 and 4');
  return sales
      .where(
        (s) => s.timestamp.year == year && getQuarter(s.timestamp) == quarter,
      )
      .toList();
}

/// Data titik bulanan untuk visualisasi fl_chart.
class MonthlySalesPoint {
  final int month;
  final String monthName;
  final String shortMonthName;
  final int totalSales;
  final int salesCount;
  final double x;
  final double y;

  const MonthlySalesPoint({
    required this.month,
    required this.monthName,
    required this.shortMonthName,
    required this.totalSales,
    required this.salesCount,
    required this.x,
    required this.y,
  });
}

/// Performa agregat per Personal Trainer dalam triwulan.
class PtPerformance {
  final String trainerId;
  final String trainerName;
  final int totalSales;
  final int packagesSold;
  final int totalSessions;
  final double contributionPercentage;

  const PtPerformance({
    required this.trainerId,
    required this.trainerName,
    required this.totalSales,
    required this.packagesSold,
    required this.totalSessions,
    required this.contributionPercentage,
  });
}

/// Hasil kalkulasi metrik triwulan manajer.
class QuarterlyMetrics {
  final QuarterlyTarget target;
  final int totalSales;
  final int validSalesCount;
  final double achievementPercentage;
  final int remainingTarget;
  final List<MonthlySalesPoint> monthlyBreakdown;
  final List<PtPerformance> ptPerformances;
  final List<PackageSaleRecord> validSales;

  const QuarterlyMetrics({
    required this.target,
    required this.totalSales,
    required this.validSalesCount,
    required this.achievementPercentage,
    required this.remainingTarget,
    required this.monthlyBreakdown,
    required this.ptPerformances,
    required this.validSales,
  });
}

const Map<int, (String, String)> monthLabels = {
  1: ('Januari', 'Jan'),
  2: ('Februari', 'Feb'),
  3: ('Maret', 'Mar'),
  4: ('April', 'Apr'),
  5: ('Mei', 'Mei'),
  6: ('Juni', 'Jun'),
  7: ('Juli', 'Jul'),
  8: ('Agustus', 'Agu'),
  9: ('September', 'Sep'),
  10: ('Oktober', 'Okt'),
  11: ('November', 'Nov'),
  12: ('Desember', 'Des'),
};

/// Fungsi utama kalkulasi metrik triwulan:
/// - Total sales valid dalam periode
/// - Pencapaian % terhadap target
/// - Sisa target (0 jika telah terpenuhi)
/// - Breakdown 3 bulan berurutan untuk fl_chart (x: 0, 1, 2)
/// - Perbandingan performa per PT terurut dari yang tertinggi
QuarterlyMetrics calculateQuarterlyMetrics({
  required List<PackageSaleRecord> sales,
  required QuarterlyTarget target,
}) {
  final quarterSales = filterSalesByQuarter(
    sales,
    year: target.year,
    quarter: target.quarter,
  );

  final validSales = quarterSales.where((s) => s.isValid).toList();

  final totalSales = validSales.fold<int>(0, (sum, s) => sum + s.price);
  final validSalesCount = validSales.length;

  final achievementPercentage = target.targetAmount > 0
      ? (totalSales / target.targetAmount) * 100.0
      : 0.0;

  final remainingTarget = math.max(0, target.targetAmount - totalSales);

  final List<MonthlySalesPoint> monthlyBreakdown = [];
  final targetMonths = target.months;
  for (int i = 0; i < targetMonths.length; i++) {
    final m = targetMonths[i];
    final (mName, shortName) = monthLabels[m] ?? ('Bulan $m', 'M$m');
    final monthSales = validSales.where((s) => s.timestamp.month == m).toList();
    final monthTotal = monthSales.fold<int>(0, (sum, s) => sum + s.price);
    monthlyBreakdown.add(
      MonthlySalesPoint(
        month: m,
        monthName: mName,
        shortMonthName: shortName,
        totalSales: monthTotal,
        salesCount: monthSales.length,
        x: i.toDouble(),
        y: monthTotal.toDouble(),
      ),
    );
  }

  final Map<String, List<PackageSaleRecord>> ptSalesMap = {};
  for (final sale in validSales) {
    ptSalesMap.putIfAbsent(sale.trainerId, () => []).add(sale);
  }

  final List<PtPerformance> ptPerformances = [];
  for (final entry in ptSalesMap.entries) {
    final trainerId = entry.key;
    final records = entry.value;
    final trainerName = records.first.trainerName.isNotEmpty
        ? records.first.trainerName
        : 'PT $trainerId';
    final ptTotal = records.fold<int>(0, (sum, s) => sum + s.price);
    final ptSessions = records.fold<int>(0, (sum, s) => sum + s.sessionsCount);
    final contrib = totalSales > 0 ? (ptTotal / totalSales) * 100.0 : 0.0;

    ptPerformances.add(
      PtPerformance(
        trainerId: trainerId,
        trainerName: trainerName,
        totalSales: ptTotal,
        packagesSold: records.length,
        totalSessions: ptSessions,
        contributionPercentage: contrib,
      ),
    );
  }

  ptPerformances.sort((a, b) {
    final cmp = b.totalSales.compareTo(a.totalSales);
    if (cmp != 0) return cmp;
    return b.packagesSold.compareTo(a.packagesSold);
  });

  return QuarterlyMetrics(
    target: target,
    totalSales: totalSales,
    validSalesCount: validSalesCount,
    achievementPercentage: achievementPercentage,
    remainingTarget: remainingTarget,
    monthlyBreakdown: monthlyBreakdown,
    ptPerformances: ptPerformances,
    validSales: validSales,
  );
}
