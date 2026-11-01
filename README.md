# Mbois Gym PT Management

Sistem Manajemen Personal Trainer (PT) resmi untuk operasional **Mbois Gym** (Tahun Pengembangan: **2026**). Proyek ini mendigitalisasi pengelolaan klien, program latihan, asesmen fisik awal, pencatatan jadwal dan absensi sesi, pemotongan kuota dengan tanda tangan digital ganda touchscreen, evaluasi Post PT, katalog 4 paket resmi individu, isolasi privasi absensi klien, serta dashboard manajer untuk memantau target penjualan triwulan Rp 5.000.000 per Personal Trainer.

Aplikasi client dibangun menggunakan **Flutter** dengan **Firebase Authentication** dan **Cloud Firestore** sebagai backend operasional utama yang terpusat, real-time, dan konsisten antarperangkat.

Repository Utama: [https://github.com/YakzIsGood/mbois-gym](https://github.com/YakzIsGood/mbois-gym)

---

## 1. Arsitektur Sistem

- **Platform Client**: Flutter (Dart SDK `^3.13.2`), kompatibel dengan Android (minSdkVersion 21).
- **Backend Operasional**:
  - **Firebase Authentication**: Autentikasi email/password terverifikasi untuk Personal Trainer dan Manager.
  - **Cloud Firestore**: Single source of truth untuk profil pengguna, data klien, subkoleksi paket/sesi/workout/evaluasi, serta transaksi penjualan paket (`package_sales`).
- **State Management**: `flutter_riverpod` (AsyncNotifier dan AutoDispose providers).
- **Navigasi & Routing**: `go_router` dengan `AppShell` adaptif berbasis peran pengguna (`trainer` vs `manager`).
- **Visualisasi & Grafik**: `fl_chart` untuk grafik batang performa penjualan bulanan triwulan dan perkembangan tonase latihan.
- **Penyimpanan Lokal / Cache**: `shared_preferences` untuk preferensi tema tampilan (Dark/Light). Tampilan UI telah dibersihkan dari label teknis developer seperti "SQLite" atau "Database Lokal" dan digantikan dengan "Riwayat & Arsip Latihan".

---

## 2. Peran & Otorisasi Pengguna

Aplikasi menerapkan dua peran operasional utama berbasis dokumen `users/{uid}` di Cloud Firestore:

### A. TRAINER (Personal Trainer)
Trainer hanya mengelola data sesuai penugasan dirinya (`assignedTrainerIds`).
**Alur Kerja Trainer**:
1. **Login**: Masuk menggunakan email dan password Trainer terverifikasi.
2. **Klien Aktif**: Memantau daftar klien aktif pada Home. Klien yang dibatalkan atau telah menyelesaikan seluruh paket otomatis dipindahkan dari daftar aktif ke daftar selesai.
3. **Pendaftaran Paket**: Mendaftarkan klien baru atau perpanjangan paket dengan memilih salah satu dari 4 paket resmi PT.
4. **Jadwal Sesi**:
   - Menambahkan jadwal sesi appointment sesuai kuota yang tersedia.
   - Mengedit tanggal dan jam sesi terencana (*planned*) tanpa perlu menghapus dan membuat ulang.
   - Membatalkan sesi dengan alasan valid; pembatalan langsung mengembalikan slot penjadwalan tanpa memotong kuota paket.
5. **Absensi & Potong Sesi**:
   - Membuka modal tanda tangan digital fullscreen touchscreen.
   - Mengumpulkan goresan tanda tangan asli dari Klien dan Coach secara terpisah (mendukung multi-stroke tanpa pergeseran gesture).
   - Memvalidasi pemotongan kuota sesi (hanya berkurang tepat satu kali).
6. **Riwayat Sesi**:
   - Melihat riwayat sesi selesai pada tab "Hadir".
   - Membuka dialog detail riwayat untuk meninjau tanggal pelaksanaan, nama PT, nama klien, catatan sesi, dan kedua tanda tangan digital asli.
7. **Profil PT**:
   - Meninjau dan memperbarui spesialisasi, pengalaman, sertifikasi, tinggi badan (TB), berat badan (BB), dan bio pelatih.

### B. MANAGER (Manajer Operasional)
Manajer memiliki hak pantau operasional dan evaluasi performa seluruh Personal Trainer di gym.
**Alur Kerja Manajer**:
1. **Login**: Masuk menggunakan akun Manager terverifikasi. Aplikasi otomatis mengarahkan ke **Dashboard Manajemen PT**.
2. **Dashboard KPI & Target Triwulan**:
   - Memilih filter Tahun dan Triwulan (Q1, Q2, Q3, Q4).
   - Memantau 4 kartu ringkasan: Total PT Aktif, Klien Aktif, Paket Terjual, dan Nilai Paket Terjual Tercatat.
   - Memeriksa grafik perbandingan capaian penjualan terhadap target **Rp 5.000.000** per PT.
3. **Daftar Kinerja Seluruh PT**:
   - Memeriksa nama, foto/avatar, spesialisasi, status aktif/nonaktif, jumlah klien aktif, nilai paket terjual, progress bar, dan label status pencapaian target ("Target Tercapai ✓" vs "Belum Tercapai").
4. **Pilih PT & Daftar Klien**:
   - Menekan tombol **Detail PT & Klien** untuk melihat rincian penjualan bulanan dalam triwulan dan daftar seluruh klien yang ditangani oleh PT tersebut.
5. **Detail Absensi Klien (Read-Only)**:
   - Menekan salah satu nama klien untuk membuka dialog rekam kehadiran.
   - **Prinsip Perlindungan Privasi Klien**: Manajer hanya disajikan data operasional absensi:
     * Nama klien.
     * Paket yang diikuti.
     * Tanggal dan jam sesi.
     * Status kehadiran (Hadir, Dijadwalkan, Dibatalkan).
     * Jumlah sesi yang dihadiri dan jumlah sesi yang belum dijalani.
     * *Catatan privasi: Asesmen kesehatan medis, catatan rahasia latihan, program beban, dan tanda tangan klien tidak ditampilkan kepada manajer.*

> **PENTING — Keamanan Pemberian Peran**:
> Pendaftaran mandiri publik (self-signup) sebagai Manager maupun Trainer aktif **ditiadakan secara ketat**. Seluruh akun PT dan Manajer harus diprovisikan oleh pihak berwenang melalui Firebase Console atau proses administratif tepercaya. Field `role`, `status`, dan `assignedTrainerIds` dilindungi oleh Firestore Security Rules dan tidak dapat diubah oleh trainer sendiri.

---

## 3. Struktur Koleksi Cloud Firestore

```text
users/{uid}                           -> Dokumen profil PT / Manager
  ├── uid: string
  ├── name: string
  ├── email: string
  ├── phone: string
  ├── role: 'trainer' | 'manager'
  ├── status: 'active' | 'inactive'
  ├── heightCm: number (opsional)
  ├── weightKg: number (opsional)
  ├── specialization: string (opsional)
  ├── experienceYears: number (opsional)
  ├── certifications: string (opsional)
  └── bio: string (opsional)

clients/{clientId}                    -> Dokumen klien Mbois Gym
  ├── id: number | string
  ├── name: string
  ├── age: number
  ├── contact: string
  ├── assignedTrainerIds: array[string]
  ├── heightCm: number
  ├── initialWeightKg: number
  ├── goal: string
  ├── medicalHistory: string
  ├── injuryHistory: string
  ├── assessmentNotes: string
  │
  ├── packages/{packageId}            -> Subkoleksi Paket PT
  │     ├── id: number | string
  │     ├── clientId: string
  │     ├── totalSessions: number (4, 10, 16, 24)
  │     ├── completedCount: number (terkunci server/transaksi)
  │     ├── status: 'active' | 'closed'
  │     └── createdAt: timestamp
  │
  ├── sessions/{sessionId}            -> Subkoleksi Jadwal & Absensi
  │     ├── id: number | string
  │     ├── packageId: string
  │     ├── sessionNumber: number
  │     ├── scheduledAt: timestamp
  │     ├── status: 'scheduled' | 'completed' | 'cancelled'
  │     ├── notes: string
  │     ├── clientSignatureStatus: string ('verified_touchscreen')
  │     ├── coachSignatureStatus: string ('verified_touchscreen')
  │     └── cancelReason: string (jika status == 'cancelled')
  │
  ├── workouts/{workoutId}            -> Catatan Latihan (Exercise, Sets, Reps, Load)
  ├── evaluations/{evaluationId}      -> Evaluasi Post PT & status finalisasi paket
  └── progress_measurements/{progId}  -> Pengukuran progres lingkar & berat badan

package_sales/{saleId}                -> Catatan snapshot transaksi penjualan paket
  ├── id: string
  ├── clientId: string
  ├── clientName: string
  ├── trainerId: string
  ├── trainerName: string
  ├── tierName: string
  ├── sessionsCount: number
  ├── durationWeeks: number
  ├── price: number (snapshot Rupiah)
  ├── timestamp: timestamp
  └── status: 'valid' | 'refunded'
```

---

## 4. Pricelist Resmi Paket PT & Target Triwulan

### A. Tarif Paket Personal Trainer Individu
Berdasarkan ketentuan operasional Mbois Gym, aplikasi menyediakan 4 pilihan paket PT individu baku:

| Paket | Sesi | Durasi | Harga Resmi |
|---|---|---|---|
| **Paket 4 Sesi** | 4 sesi | 4 minggu | **Rp 500.000** |
| **Paket 10 Sesi** | 10 sesi | 4 minggu | **Rp 1.000.000** |
| **Paket 16 Sesi** | 16 sesi | 8 minggu | **Rp 1.600.000** |
| **Paket 24 Sesi** | 24 sesi | 8 minggu | **Rp 2.000.000** |

Setiap pendaftaran klien baru atau perpanjangan paket PT mencatat snapshot harga ke koleksi `package_sales` yang terikat pada `trainerId`. Perhitungan slot penjadwalan mengikuti formula:
$$\text{Slot Penjadwalan Tersedia} = \text{Total Sesi Paket} - \text{Sesi Selesai} - \text{Jadwal Aktif}$$

### B. Target Penjualan Rp 5.000.000 per PT per Triwulan
Target penjualan paket sebesar **Rp 5.000.000** berlaku secara **individual untuk setiap Personal Trainer** selama satu triwulan kalender (bukan target kolektif seluruh gym):
- **Q1**: Januari – Maret
- **Q2**: April – Juni
- **Q3**: Juli – September
- **Q4**: Oktober – Desember

Dashboard menyajikan grafik batang fl_chart bulanan, persentase pencapaian masing-masing PT, sisa nominal target, dan indikator pemenuhan target yang dihitung dari transaksi paket Firestore yang valid.

---

## 5. Fitur Operasional Utama

### A. CRUD Absensi & Manajemen Jadwal Sesi
- **CREATE**: Menjadwalkan appointment sesi latihan berdasarkan kalender dan waktu sesuai kuota yang tersedia.
- **EDIT / RESCHEDULE**: Jadwal terencana (*planned*) dapat diedit tanggal dan jam pertemuannya langsung tanpa perlu menghapus dan membuat ulang jadwal.
- **READ**: Filter status sesi yang interaktif:
  - `Aktif / Dijadwalkan` (default): Menampilkan sesi mendatang yang siap dijalankan.
  - `Hadir`: Menampilkan riwayat sesi yang telah selesai diverifikasi beserta detail kedua tanda tangan.
  - `Dibatalkan`: Menampilkan sesi yang dibatalkan beserta alasannya.
  - `Semua`: Menampilkan seluruh catatan sesi.
- **CANCEL**:
  - Tombol **Batalkan Sesi** memunculkan dialog konfirmasi dan input alasan pembatalan. Sesi yang dibatalkan **langsung menghilang dari daftar sesi aktif**, tersimpan permanen di cloud dengan status `cancelled`, **kuota paket klien tidak terpotong**, dan tombol Tambah Jadwal kembali tersedia untuk membuat sesi pengganti.

### B. Pop-Up Tanda Tangan Khusus Touchscreen
- **Dedicated Fullscreen Dialog**: Membuka kanvas tanda tangan modal dengan ukuran besar yang terkunci (`PopScope(canPop: false)`), mencegah konflik gesture scrolling halaman latar.
- **RawGestureDetector Independen**: Gesture menggambar menang di arena gesture Flutter, mendukung multi-stroke tanpa terhapus saat jari diangkat.
- **Verifikasi Ganda**: Memeriksa tanda tangan terpisah untuk **Klien** dan **Coach / PT**.
- **Signature Preview Card**: Menampilkan kartu pratinjau tanda tangan, status terverifikasi, dan opsi ubah tanda tangan sebelum konfirmasi akhir.
- **Proteksi Idempotensi**: Mencegah double-tap tombol "Verifikasi & Potong Sesi" dan memproses transaksi atomik Firestore.

### C. Dashboard Manajer & Isolasi Privasi Klien
- **Grafik Batang Capaian PT**: Visualisasi pencapaian per PT terhadap target Rp 5.000.000 dengan indikator visual "Target Tercapai ✓" atau "Belum Tercapai".
- **Filter Tahun & Triwulan**: Analisis data historis dan berjalan untuk Q1 hingga Q4.
- **Detail PT & Klien**: Menampilkan profil pelatih, rincian omzet bulanan, dan daftar klien yang dibimbing.
- **Detail Absensi Read-Only**: Tinjauan rekam kehadiran sesi klien (nomor sesi, jadwal, status kehadiran, sesi dihadiri vs sisa sesi) dengan proteksi data rahasia (asesmen fisik, riwayat medis, workout log, dan tanda tangan tidak dibocorkan ke manajer).

---

## 6. Firestore Security Rules

Keamanan database diatur dalam `firestore.rules` dan diuji secara deterministik dengan Firebase Emulator Suite (58 pengujian):
1. Pengguna tak terotentikasi dan akun berstatus `pending`/`inactive` diblokir total dari seluruh data operasional.
2. Trainer hanya dapat membaca dan menulis data klien yang terdaftar di `assignedTrainerIds`.
3. Trainer dilarang memanipulasi `role`, `status`, atau `assignedTrainerIds` sendiri.
4. Trainer dilarang mengubah status sesi menjadi `completed` atau menaikkan `completedCount` kuota secara langsung dari client tanpa melalui transaksi backend yang sah.
5. Manajer memiliki hak baca profil PT dan data operasional yang diizinkan untuk pelaporan dashboard manajerial.
6. Subkoleksi root tak berpemilik dan koleksi warisan diblokir (`fail closed`).

---

## 7. Pengujian & Hasil Validasi

Validasi dijalankan secara menyeluruh di lingkungan pengujian:

| Pengujian | Perintah | Hasil Aktual |
|---|---|---|
| **Firestore Security Rules** | `npm run test:rules` | **58 tests passed** (0 failed) |
| **Flutter Analyze** | `flutter analyze --no-fatal-infos` | **0 errors, 0 warnings** (Clean) |
| **Flutter Test Suite** | `flutter test` | **129 tests passed** (0 failed) |
| **Android APK Debug Build** | `flutter build apk --debug` | **BUILD SUCCESSFUL** (`app-debug.apk`) |
| **Smoke Test Emulator Android** | `adb install` + screencap manual | **Terverifikasi Bebas Bug** |

### Rincian Test Suite Flutter (129 tests):
- `test/regression_lifecycle_quota_signatures_test.dart` (20 tests): Lifecycle klien, filter klien batal di Home, pemulihan kuota pembatalan sesi, rescheduling jadwal, dan riwayat tanda tangan.
- `test/manager_dashboard_test.dart` & `test/manager_quarterly_target_and_privacy_test.dart` (14 tests): UI responsif dashboard manajer, fl_chart rendering, formula harga paket resmi, target kuartal Rp 5M individual, dan isolasi privasi absensi klien.
- `test/cloud_auth_cutover_test.dart` & `test/auth_test.dart` (28 tests): Firebase Auth cutover, reset password, dan pemblokiran akun inaktif.
- `test/firestore_session_repository_test.dart` (16 tests): Transaksi atomik sesi, idempotensi, dan fallback ID.
- `test/pt_packages_and_manager_metrics_test.dart` (10 tests): Perhitungan metrik triwulan, fl_chart data, dan format Rupiah.
- `test/signature_pad_test.dart` & `test/dedicated_signature_dialog_test.dart` (30 tests): Dialog fullscreen tanda tangan adaptif dan gesture touchscreen.
- `test/pt_features_and_signature_flow_test.dart` (4 tests): Alur pembatalan sesi, pemotongan kuota, dan form 4 paket resmi.
- `test/ui_flow_test.dart`, `test/revision_ui_test.dart`, `test/workout_ui_test.dart`, `test/exercise_api_test.dart` (7 tests): Regresi UI dan workout log.

---

## 8. Panduan Provisioning & Akun Demo Pengujian

Untuk menjaga keamanan project Firebase produksi dan mencegah kebocoran kredensial ke publik:
- **Akun Demo Trainer & Manager**: Disediakan secara terpisah dan kredensialnya dikelola secara privat di luar repositori Git (`AKUN_DEMO_MBOIS_PRIVATE.txt`).
- **Pemberian Kredensial**: Pemilik proyek atau penguji dapat membagikan email dan password pengujian secara privat melalui kontak langsung.
- **Prosedur Tambah Akun Demo Baru**:
  1. Tambahkan user di Firebase Authentication Console.
  2. Buat dokumen profil di koleksi Firestore `users/{uid}` dengan `role: "trainer"` atau `role: "manager"` dan `status: "active"`.
  3. Akun langsung dapat digunakan untuk login pada aplikasi.

---

## 9. Cara Menggunakan Versi Terbaru Setelah Merge

### A. Untuk Clone Baru (Fresh Clone)
```bash
git clone https://github.com/YakzIsGood/mbois-gym.git
cd mbois-gym
flutter pub get
flutter run
```

### B. Untuk Pengguna yang Sudah Memiliki Clone Lama
```bash
# 1. Periksa status repository lokal
git status

# 2. Simpan perubahan lokal jika ada
git stash

# 3. Berpindah ke branch main dan perbarui dari upstream
git switch main
git pull origin main

# 4. Unduh dependensi terbaru
flutter pub get

# 5. Jalankan aplikasi
flutter run
```

Source code hasil merge dapat dilihat langsung pada repository utama:
[https://github.com/YakzIsGood/mbois-gym](https://github.com/YakzIsGood/mbois-gym)

---

## 10. Batasan & Status Backend

- **Firebase Storage**: Bucket Firebase Storage produksi (`mbois-gym.firebasestorage.app`) memerlukan konfigurasi bucket aktif untuk upload blob file biner ke cloud. Aplikasi saat ini menggunakan fallback rendering avatar inisial nama pelatih yang elegan dan aman saat URL foto cloud belum tersedia.
- **Integritas Tanda Tangan**: Tanda tangan digital diverifikasi touch screen dan tersimpan aman di Firestore sebagai Base64 terkompresi, dapat ditinjau kembali pada modal riwayat sesi completed.
