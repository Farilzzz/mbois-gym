#!/usr/bin/env node
'use strict';

/**
 * Mbois Gym - Manager Dashboard Projection Builder CLI
 * Trusted Firebase Admin SDK script to materialize manager read models.
 *
 * Paths populated:
 * - manager_dashboard/{year}-Q{quarter}
 * - manager_dashboard/{year}-Q{quarter}/trainers/{trainerId}
 * - manager_dashboard/{year}-Q{quarter}/trainers/{trainerId}/clients/{clientId}
 * - manager_dashboard/{year}-Q{quarter}/trainers/{trainerId}/clients/{clientId}/attendance/{sessionId}
 *
 * Rules:
 * - Dry-run by default; requires explicit --apply to write.
 * - Does not accept or log passwords or secrets.
 * - Strictly allowlists fields: no sensitive information (medical, workouts, notes, signatures).
 */

const {
  parseArgs,
  runProjectionJob,
  ALLOWED_PROJECT,
} = require('./builder.cjs');

function printHelp() {
  console.log(`
===============================================================
 Mbois Gym - Manager Dashboard Projection Builder (Admin SDK)
===============================================================

Deskripsi:
  Membangun dan memperbarui read-model terisolasi untuk dashboard manajer
  di Firestore pada path:
  manager_dashboard/{year}-Q{quarter}/trainers/{trainerId}/clients/{clientId}/attendance/{sessionId}

Penggunaan:
  node tools/projections/cli.cjs --project mbois-gym [opsi]

Opsi:
  --project <id>     ID proyek Firebase (Wajib, harus '${ALLOWED_PROJECT}')
  --year <tahun>     Tahun periode (default: tahun berjalan zona waktu lokal)
  --quarter, -q <1-4> Kuartal periode Q1-Q4 (default: kuartal berjalan)
  --timezone, --tz   Zona waktu perhitungan (default: 'Asia/Jakarta' / WIB)
  --dry-run          Mode simulasi/dry-run tanpa menulis ke Firestore (DEFAULT)
  --apply            Terapkan penulisan riil ke Cloud Firestore
  --json             Cetak hasil proyeksi dalam format JSON
  --help, -h         Tampilkan bantuan ini

Fitur & Keamanan:
  - Dry-run secara default untuk mencegah penulisan data yang tidak disengaja.
  - Memuat semua pelatih (PT), termasuk pelatih dengan 0 penjualan.
  - Target triwulan individual Rp 5.000.000 per pelatih.
  - Deduplikasi transaksi package_sales berbasis ID & filter validitas.
  - Strict allowlist privasi klien: tidak ada catatan medis/latihan, telepon, atau tanda tangan.
`);
}

function formatRupiah(amount) {
  const num = Number(amount) || 0;
  const isNeg = num < 0;
  const abs = Math.abs(Math.round(num)).toString();
  const parts = [];
  for (let i = abs.length; i > 0; i -= 3) {
    parts.unshift(abs.substring(Math.max(0, i - 3), i));
  }
  return `${isNeg ? '-' : ''}Rp ${parts.join('.')}`;
}

async function main() {
  const rawArgs = process.argv.slice(2);

  if (rawArgs.includes('--help') || rawArgs.includes('-h')) {
    printHelp();
    process.exit(0);
  }

  let options;
  try {
    options = parseArgs(rawArgs);
  } catch (err) {
    console.error(`\n[ERROR ARGUMEN] ${err.message}\n`);
    console.error(`Gunakan --help untuk melihat panduan penggunaan.\n`);
    process.exit(1);
  }

  if (options.help) {
    printHelp();
    process.exit(0);
  }

  // Lazy-load Firebase Admin SDK
  let admin;
  try {
    admin = require('firebase-admin');
  } catch (err) {
    console.error('\n[ERROR] Modul firebase-admin tidak ditemukan.');
    console.error('Jalankan npm install di dalam tools/projections/\n');
    process.exit(1);
  }

  // Initialize Firebase Admin with ADC if not already initialized
  if (admin.apps.length === 0) {
    try {
      admin.initializeApp({
        projectId: options.project,
      });
    } catch (initErr) {
      console.error(`\n[ERROR INISIALISASI] Gagal menginisialisasi Firebase Admin SDK: ${initErr.message}\n`);
      process.exit(1);
    }
  }

  const db = admin.firestore();

  console.log(`\n===============================================================`);
  console.log(` Membangun Proyeksi Dashboard Manajer: ${options.project}`);
  console.log(` Periode: ${options.year}-Q${options.quarter} | Zona Waktu: ${options.timezone}`);
  console.log(` Mode: ${options.apply ? 'PENULISAN RIIL (--apply)' : 'SIMULASI / DRY RUN (default)'}`);
  console.log(`===============================================================\n`);

  try {
    const result = await runProjectionJob(db, options);

    if (options.json) {
      console.log(JSON.stringify(result, null, 2));
      return;
    }

    console.log(`Ringkasan Hasil Perhitungan Proyeksi:`);
    console.log(`- Periode ID               : ${result.periodId}`);
    console.log(`- Total PT Aktif           : ${result.dashboard.totalActivePt} PT`);
    console.log(`- Total PT Terdaftar       : ${result.trainers.length} PT (termasuk 0 penjualan)`);
    console.log(`- Total Klien Aktif        : ${result.dashboard.totalActiveClients} klien`);
    console.log(`- Paket Terjual Periode Ini: ${result.dashboard.totalPackagesSold} paket`);
    console.log(`- Total Penjualan Triwulan : ${formatRupiah(result.dashboard.totalSales)}`);
    console.log(`- Rincian Bulanan [M1,M2,M3]: [${result.dashboard.monthlySales.map(formatRupiah).join(', ')}]`);
    console.log(`- Total Dokumen Proyeksi   : ${result.writes ? result.writes.length : result.writesCount} dokumen\n`);

    console.log(`Performa Individual per Pelatih (Target: Rp 5.000.000):`);
    for (const t of result.trainers) {
      const target = t.doc.quarterlyTarget || 5000000;
      const sales = t.doc.totalSales || 0;
      const pct = target > 0 ? ((sales / target) * 100).toFixed(1) : '0.0';
      const statusAchieved = sales >= target ? 'TERCAPAI' : 'BELUM';
      console.log(`  * ${t.doc.name.padEnd(20)}: ${formatRupiah(sales).padStart(14)} (${pct.padStart(5)}% - ${statusAchieved}) | ${t.doc.activeClients} klien | ${t.clients.length} terproyeksi`);
    }
    console.log(``);

    if (result.dryRun) {
      console.log(`---------------------------------------------------------------`);
      console.log(`[DRY RUN] Mode simulasi selesai.`);
      console.log(`TIDAK ADA data yang ditulis ke Firestore.`);
      console.log(`Untuk menerapkan perubahan ke Cloud Firestore, jalankan kembali dengan flag:`);
      console.log(`  node tools/projections/cli.cjs --project ${options.project} --year ${options.year} --quarter ${options.quarter} --apply`);
      console.log(`---------------------------------------------------------------\n`);
    } else {
      console.log(`---------------------------------------------------------------`);
      console.log(`[SUKSES] Berhasil memperbarui proyeksi dashboard manajer.`);
      console.log(`Total dokumen ditulis : ${result.commitResult.committedCount}`);
      console.log(`Jumlah commit batch   : ${result.commitResult.batchCount}`);
      console.log(`---------------------------------------------------------------\n`);
    }
  } catch (err) {
    console.error(`\n[ERROR EKSEKUSI] ${err.message}\n`);
    if (err.stack) {
      console.error(err.stack);
    }
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  main,
};
