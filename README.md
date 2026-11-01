# Mbois Gym PT Management — 2026

Sistem Manajemen Personal Trainer (PT) resmi untuk operasional **Mbois Gym** (Tahun Pengembangan: **2026**). Proyek ini mendigitalisasi pengelolaan klien, program latihan, asesmen fisik awal, pencatatan jadwal dan absensi sesi, pemotongan kuota dengan tanda tangan digital ganda touchscreen, evaluasi Post PT, katalog 4 paket resmi individu, isolasi privasi absensi klien, tool administratif Firebase Admin SDK untuk provisioning staf internal, serta dashboard manajer untuk memantau target penjualan triwulan Rp 5.000.000 per Personal Trainer.

Aplikasi client dibangun menggunakan **Flutter** dengan **Firebase Authentication** dan **Cloud Firestore** sebagai backend operasional utama yang terpusat, real-time, dan konsisten antarperangkat.

Repository Resmi Revisi: [https://github.com/Farilzzz/mbois-gym](https://github.com/Farilzzz/mbois-gym)

---

## 1. Panduan Memulai Cepat (Quick Start)

### A. Clone Baru (Fresh Clone)
Untuk penguji, evaluator, atau rekan tim yang ingin memasang aplikasi dari awal:
```bash
git clone https://github.com/Farilzzz/mbois-gym.git
cd mbois-gym
flutter pub get
flutter run
```

### B. Memperbarui Clone yang Sudah Ada
Untuk memperbarui repository lokal ke versi final terbaru di branch `main`:
```bash
git status
git switch main
git pull origin main
flutter pub get
flutter run
```

---

## 2. Persyaratan & Setup Lingkungan

### A. Setup Flutter SDK
- **Flutter SDK**: `^3.13.0` atau yang lebih baru (Channel stable disarankan).
- **Dart SDK**: `^3.1.0` ke atas.
- **Android Studio / Android SDK**: Platform API level 33/34, Build-tools 33.0.0+, Android Emulator atau perangkat fisik dengan USB debugging aktif.
- **Node.js**: Versi `18.x` atau `20.x` (dibutuhkan untuk menjalankan tool administratif di `tools/admin` dan pengujian Security Rules di `rules-test`).

### B. Konfigurasi Firebase
Aplikasi telah dikonfigurasi untuk terhubung dengan Firebase Project **`mbois-gym`**:
- Konfigurasi Android berada di `android/app/google-services.json`.
- Konfigurasi Dart options otomatis di `lib/firebase_options.dart`.
- Firebase Authentication: Metode Email/Password aktif.
- Cloud Firestore: Basis data terpusat (mode produksi dengan `firestore.rules`).
- Untuk menjalankan secara lokal atau menghubungkan dengan project pengujian mandiri:
  1. Pastikan Firebase CLI terpasang (`npm install -g firebase-tools`).
  2. Login ke akun Google pengelola (`firebase login`).
  3. Konfigurasi project dengan `flutterfire configure --project=mbois-gym`.

### C. Menjalankan di Emulator / Perangkat HP Fisik
1. Jalankan emulator Android melalui Android Studio Device Manager atau hubungkan ponsel fisik dengan USB Debugging.
2. Pastikan perangkat terdeteksi:
   ```bash
   flutter devices
   ```
3. Jalankan aplikasi:
   ```bash
   flutter run
   ```

---

## 3. Sistem Login Internal & Peran Pengguna

Sistem login didesain khusus untuk staf internal gym (Personal Trainer dan Manager):
- **Tampilan Bersih & Terisolasi**: Halaman login hanya menampilkan Logo Mbois Gym, Input Email, Input Password, Tombol Log In, dan tautan Lupa Password.
- **Tanpa Registrasi Publik**: Tombol "Belum punya akun?", "Informasi Akun", registrasi mandiri, dan navigasi arsip lokal telah dihapus total. Akun operasional sepenuhnya dibuat dan dikelola oleh pihak pengelola.
- **Pemulihan Kata Sandi**: Pengguna yang lupa kata sandi dapat memasukkan email untuk menerima instruksi pemulihan resmi melalui Firebase Auth.

### A. TRAINER (Personal Trainer)
Trainer hanya memiliki akses ke data klien dan sesi yang ditugaskan kepada dirinya (`assignedTrainerIds`).
- **Home & Lifecycle Klien**: Memantau klien aktif yang memiliki sisa kuota sesi. Klien yang selesai atau dibatalkan otomatis dipindahkan dari feed aktif.
- **Penjadwalan Fleksibel**: Menambah jadwal appointment sesi, mengedit tanggal dan jam sesi terencana (*planned*) tanpa menghapus sesi, serta membatalkan sesi (pembatalan langsung mengembalikan slot penjadwalan tanpa memotong kuota paket klien).
- **Absensi & Potong Kuota**: Modal tanda tangan digital fullscreen touchscreen mengumpulkan tanda tangan asli Klien dan Coach secara terpisah, memotong kuota tepat satu kali secara atomik di Firestore.
- **Riwayat Sesi Selesai**: Membuka dialog detail riwayat sesi pada tab "Hadir" untuk melihat tanggal, nama klien, catatan latihan, dan pratinjau kedua tanda tangan asli.
- **Profil Coach**: Meninjau dan memperbarui spesialisasi, TB, BB, nomor WhatsApp, dan bio pelatih.

### B. MANAGER (Manajer Operasional)
Manajer memiliki hak pantau terhadap seluruh Personal Trainer untuk kebutuhan supervisi dan pelaporan target bisnis.
- **Dashboard Manajemen PT**: Menampilkan indikator Total PT Aktif, Klien Aktif, Paket Terjual, serta Nilai Penjualan Triwulan.
- **Target Penjualan Rp 5.000.000 per PT per Triwulan**: Menampilkan perbandingan performa masing-masing PT terhadap target kuartal kalender dengan visualisasi batang fl_chart dan indikator pemenuhan target.
- **Detail PT & Klien**: Manajer dapat memilih PT untuk melihat profil dan daftar klien bimbingannya.
- **Isolasi Privasi Absensi Read-Only**: Ketika membuka detail klien, manajer **hanya disajikan informasi absensi operasional** (nama klien, nama paket, tanggal/jam sesi, status kehadiran, sesi dihadiri vs sisa sesi).
- **Perlindungan Backend**: Asesmen fisik medis, riwayat cedera, program beban/workout log harian, dan tanda tangan digital Klien **diblokir di level Security Rules Firestore** dan tidak diizinkan dibaca oleh role Manager.

---

## 4. Pricelist Resmi Paket PT & Target Triwulan

### A. Tarif Paket Personal Trainer Individu
Mbois Gym memberlakukan 4 pilihan paket PT individu baku:

| Paket | Sesi | Masa Berlaku | Harga Resmi |
|---|---|---|---|
| **Paket 4 Sesi** | 4 sesi | 4 minggu | **Rp 500.000** |
| **Paket 10 Sesi** | 10 sesi | 4 minggu | **Rp 1.000.000** |
| **Paket 16 Sesi** | 16 sesi | 8 minggu | **Rp 1.600.000** |
| **Paket 24 Sesi** | 24 sesi | 8 minggu | **Rp 2.000.000** |

Perhitungan kuota penjadwalan:
$$\\text{Slot Tersedia} = \\text{Total Sesi Paket} - \\text{Sesi Hadir} - \\text{Jadwal Aktif Terencana}$$

### B. Periode Kuartal Kalender Target Rp 5.000.000
Target individual Rp 5.000.000 dihitung per Personal Trainer per kuartal:
- **Q1**: 1 Januari – 31 Maret
- **Q2**: 1 April – 30 Juni
- **Q3**: 1 Juli – 30 September
- **Q4**: 1 Oktober – 31 Desember

---

## 5. Tool Pengelola: Firebase Admin CLI & Projections

Untuk menjaga kepatuhan arsitektur keamanan, seluruh proses pembuatan akun, penetapan role, dan penyusunan proyeksi dashboard dijalankan melalui script CLI administratif di luar aplikasi Flutter (tidak menyimpan Service Account atau secret di dalam source code mobile atau git).

### A. Tool Administrasi Akun (`tools/admin`)
Terletak di direktori `tools/admin`, tool ini memanfaatkan **Firebase Admin SDK** untuk administrasi staf:

1. **Instalasi Dependensi**:
   ```bash
   cd tools/admin
   npm install
   ```

2. **Membuat Akun Trainer Baru**:
   ```bash
   node admin.cjs create-trainer --project mbois-gym --email coach@mboisgym.com --name "Coach Budi" --specialization "Hypertrophy"
   ```

3. **Membuat Akun Manager Baru**:
   ```bash
   node admin.cjs create-manager --project mbois-gym --email manager@mboisgym.com --name "Manager Operasional"
   ```

4. **Memprovisi Akun yang Sudah Ada di Firebase Auth (Target UID)**:
   Contoh untuk UID Manager yang sudah terdaftar (`xtGOiCT0JBhSVorhRkFEbkdSUp63`):
   ```bash
   node admin.cjs provision-existing --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63 --role manager --name "Manager Faril"
   ```

5. **Memeriksa Status Akun**:
   ```bash
   node admin.cjs status --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63
   ```

6. **Menonaktifkan Akun (Disable)**:
   ```bash
   node admin.cjs disable --project mbois-gym --email coach@mboisgym.com
   ```

7. **Menghasilkan Tautan Reset Password**:
   ```bash
   node admin.cjs reset-link --project mbois-gym --email coach@mboisgym.com
   ```

### B. Tool Pembangun Proyeksi Dashboard Manager (`tools/projections`)
Terletak di direktori `tools/projections`, tool ini membaca transaksi penjualan dan absensi, lalu memproyeksikannya ke koleksi `manager_dashboard` yang aman dibaca oleh Manager:

1. **Instalasi Dependensi**:
   ```bash
   cd tools/projections
   npm install
   ```

2. **Simulasi Proyeksi (Dry Run - Tanpa Menulis ke Cloud)**:
   ```bash
   node cli.cjs --project mbois-gym --year 2026 --quarter 1
   ```

3. **Menerapkan Proyeksi ke Cloud Firestore**:
   ```bash
   node cli.cjs --project mbois-gym --year 2026 --quarter 1 --apply
   ```

---

## 6. Kebijakan Kredensial & Akun Demo

Untuk mencegah kebocoran data klien riil dan melindungi integritas database produksi:
- **Tidak Ada Hardcoded Secret**: Repositori git ini bebas dari private keys, service account JSON, maupun password akun staf.
- **Akun Demo Terisolasi**: Kredensial akun pengujian operasional dikelola secara privat pada dokumen `AKUN_DEMO_MBOIS_PRIVATE.txt` di luar repositori Git dan hanya dibagikan langsung kepada evaluator atau penguji resmi.
- **Pendaftaran Akun Tambahan**: Penguji dapat meminta penambahan akun pengujian baru kepada software engineer/pengelola sistem dengan memanfaatkan tool administratif `tools/admin/admin.cjs`.

---

## 7. Rangkuman Pengujian & Verifikasi Kualitas

Seluruh suite pengujian telah divalidasi dan berjalan hijau:

| Komponen Pengujian | Perintah Eksekusi | Status Validasi |
|---|---|---|
| **Firestore Security Rules** | `npm run test:rules` | **59 tests passed** (0 failed) |
| **Flutter Static Analysis** | `flutter analyze --no-fatal-infos` | **0 errors, 0 warnings** (Clean) |
| **Flutter Unit & Widget Tests** | `flutter test` | **130 tests passed** (0 failed) |
| **Admin CLI Suite** | `cd tools/admin && npm test` | **12 tests passed** (0 failed) |
| **Projections Builder Suite** | `cd tools/projections && npm test` | **16 tests passed** (0 failed) |
| **Android APK Debug Build** | `flutter build apk --debug` | **BUILD SUCCESSFUL** (`app-debug.apk`) |

### Cakupan Kasus Uji Kritis:
1. **Sistem Login Internal**: Memvalidasi penghapusan registrasi publik, informasi akun lama, dan navigasi arsip lokal pada `test/cloud_auth_cutover_test.dart`.
2. **Isolasi Privasi Manager**: Memverifikasi alur navigasi dari daftar PT hingga absensi read-only klien tanpa mengekspos data medis, catatan rahasia, maupun tanda tangan pada `test/manager_quarterly_target_and_privacy_test.dart` dan `test/manager_firestore_read_model_test.dart`.
3. **Kalkulasi Kuota & Paket**: Formula pemotongan kuota, deduplikasi pemotongan sesi ganda, dan validasi 4 paket resmi pada `test/regression_lifecycle_quota_signatures_test.dart`.
4. **Rescheduling & Pembatalan Sesi**: Pengembalian kuota dan slot penjadwalan saat sesi dibatalkan pada `test/pt_features_and_signature_flow_test.dart`.
5. **Keamanan Backend Firestore**: Evaluasi 59 skenario akses RBAC (Role-Based Access Control) di `rules-test/firestore.test.cjs`.

---

## 8. Panduan Troubleshooting

1. **Aplikasi Menampilkan "Akun Anda berstatus nonaktif"**:
   - Pastikan akun yang digunakan telah diprovisi dengan status `active` di Firestore `users/{uid}`. Hubungi pengelola untuk mengaktifkan akun via `tools/admin`.
2. **Role Tidak Dikenali / Tampilan Kosong Saat Login**:
   - Pastikan field `role` bernilai tepat `'trainer'` atau `'manager'` (huruf kecil).
3. **Peringatan Dependency di Lingkungan Node.js**:
   - Jalankan `npm install` di masing-masing subdirektori (`tools/admin` dan `tools/projections`) untuk memastikan modul lokal terpasang.
4. **Android Build / Gradle Timeout**:
   - Jika Gradle mengalami kendala koneksi download wrapper pada eksekusi pertama, jalankan perintah dengan flag `--android-skip-build-dependency-validation` atau buka proyek di Android Studio untuk sinkronisasi Gradle.
5. **Foto Profil Default**:
   - Jika foto cloud pelatih belum diunggah atau bucket storage belum diaktifkan, aplikasi secara elegan menampilkan avatar inisial nama pelatih tanpa mengganggu fungsi operasional.
