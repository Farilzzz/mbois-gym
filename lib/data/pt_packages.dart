import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper untuk format mata uang Rupiah dengan pemisah ribuan titik.
/// Contoh: formatRupiah(500000) -> 'Rp 500.000'
String formatRupiah(int amount) {
  final isNegative = amount < 0;
  final absStr = amount.abs().toString();
  final buffer = StringBuffer();
  final len = absStr.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(absStr[i]);
  }
  return '${isNegative ? '-' : ''}Rp $buffer';
}

/// Definisi tier/paket resmi Personal Trainer Mbois Gym.
class PtPackageTier {
  final String id;
  final String name;
  final int sessionsCount;
  final int durationWeeks;
  final int price;

  const PtPackageTier({
    required this.id,
    required this.name,
    required this.sessionsCount,
    required this.durationWeeks,
    required this.price,
  });

  static List<PtPackageTier> get officialTiers => officialPtPackages;

  static const PtPackageTier tier4 = PtPackageTier(
    id: 'pt_pkg_4',
    name: 'Paket 4 Sesi',
    sessionsCount: 4,
    durationWeeks: 4,
    price: 500000,
  );

  static const PtPackageTier tier10 = PtPackageTier(
    id: 'pt_pkg_10',
    name: 'Paket 10 Sesi',
    sessionsCount: 10,
    durationWeeks: 4,
    price: 1000000,
  );

  static const PtPackageTier tier16 = PtPackageTier(
    id: 'pt_pkg_16',
    name: 'Paket 16 Sesi',
    sessionsCount: 16,
    durationWeeks: 8,
    price: 1600000,
  );

  static const PtPackageTier tier24 = PtPackageTier(
    id: 'pt_pkg_24',
    name: 'Paket 24 Sesi',
    sessionsCount: 24,
    durationWeeks: 8,
    price: 2000000,
  );

  String get formattedPrice => formatRupiah(price);
  String get description =>
      '$sessionsCount sesi | $durationWeeks minggu | $formattedPrice';
}

/// 4 Paket resmi individu PT Mbois Gym
const List<PtPackageTier> officialPtPackages = [
  PtPackageTier(
    id: 'pt_pkg_4',
    name: 'Paket 4 Sesi',
    sessionsCount: 4,
    durationWeeks: 4,
    price: 500000,
  ),
  PtPackageTier(
    id: 'pt_pkg_10',
    name: 'Paket 10 Sesi',
    sessionsCount: 10,
    durationWeeks: 4,
    price: 1000000,
  ),
  PtPackageTier(
    id: 'pt_pkg_16',
    name: 'Paket 16 Sesi',
    sessionsCount: 16,
    durationWeeks: 8,
    price: 1600000,
  ),
  PtPackageTier(
    id: 'pt_pkg_24',
    name: 'Paket 24 Sesi',
    sessionsCount: 24,
    durationWeeks: 8,
    price: 2000000,
  ),
];

PtPackageTier? findPackageTier(int sessionsCount) {
  for (final tier in officialPtPackages) {
    if (tier.sessionsCount == sessionsCount) return tier;
  }
  return null;
}

/// Model transaksi/penjualan paket PT.
class PackageSaleRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String trainerId;
  final String trainerName;
  final String tierName;
  final int sessionsCount;
  final int durationWeeks;
  final int price;
  final DateTime timestamp;
  final String status;

  const PackageSaleRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.trainerId,
    required this.trainerName,
    required this.tierName,
    required this.sessionsCount,
    required this.durationWeeks,
    required this.price,
    required this.timestamp,
    this.status = 'valid',
  });

  /// Only independently verified sales count as revenue. A package request
  /// (including a recorded or pending purchase) is not payment evidence.
  bool get isValid =>
      status.trim().toLowerCase() == 'valid' &&
      price > 0 &&
      clientId.isNotEmpty &&
      trainerId.isNotEmpty &&
      timestamp.isAfter(DateTime.fromMillisecondsSinceEpoch(0));

  PackageSaleRecord copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? trainerId,
    String? trainerName,
    String? tierName,
    int? sessionsCount,
    int? durationWeeks,
    int? price,
    DateTime? timestamp,
    String? status,
  }) => PackageSaleRecord(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName,
    trainerId: trainerId ?? this.trainerId,
    trainerName: trainerName ?? this.trainerName,
    tierName: tierName ?? this.tierName,
    sessionsCount: sessionsCount ?? this.sessionsCount,
    durationWeeks: durationWeeks ?? this.durationWeeks,
    price: price ?? this.price,
    timestamp: timestamp ?? this.timestamp,
    status: status ?? this.status,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'trainerId': trainerId,
    'trainerName': trainerName,
    'tierName': tierName,
    'sessionsCount': sessionsCount,
    'durationWeeks': durationWeeks,
    'price': price,
    'timestamp': timestamp,
    'status': status,
  };

  factory PackageSaleRecord.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return PackageSaleRecord(
      id: id ?? map['id']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      trainerId: map['trainerId']?.toString() ?? '',
      trainerName: map['trainerName']?.toString() ?? '',
      tierName: map['tierName']?.toString() ?? '',
      sessionsCount: (map['sessionsCount'] as num?)?.toInt() ?? 0,
      durationWeeks: (map['durationWeeks'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toInt() ?? 0,
      timestamp: parseTime(map['timestamp']),
      status: map['status']?.toString() ?? 'pending',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackageSaleRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
