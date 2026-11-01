# Mbois Gym PT Management

Sistem manajemen Personal Trainer (PT) resmi untuk operasional Mbois Gym. Proyek ini mendigitalisasi pengelolaan klien, program latihan, asesmen fisik awal, pencatatan jadwal dan absensi sesi, pemotongan kuota dengan tanda tangan digital adaptif, evaluasi Post PT, katalog 4 paket resmi individu, serta dashboard manajer untuk memantau target penjualan triwulan.

Aplikasi client dibangun menggunakan Flutter dengan Firebase Authentication dan Cloud Firestore sebagai backend operasional utama yang terpusat dan konsisten antarperangkat.

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
- Melihat dan memperbarui data profil profesional pribadi (nama, telepon, tinggi badan, berat badan, spesialisasi, pengalaman, sertifikasi, bio).
- Mengelola data klien yang ditugaskan kepadanya (`assignedTrainerIds`).
- Mengelola jadwal latihan, absensi, program latihan (Workout Log), serta evaluasi Post PT.
- Melakukan pemotongan kuota sesi dengan verifikasi tanda tangan ganda (Klien dan Coach).
- Membatalkan jadwal sesi tanpa merusak kuota paket.
- Mendaftarkan klien baru atau memperpanjang paket berdasarkan 4 pilihan paket resmi PT.

### B. MANAGER (Manajer Operasional)
- Mengakses **Dashboard Manajemen Khusus** (`/manager-dashboard` atau `/dashboard` otomatis).
- Memantau metrik bisnis triwulan (Q1–Q4) dengan target awal **Rp 5.000.000** per triwulan:
  - Total PT aktif & total klien terdaftar.
  - Jumlah paket PT terjual & total nominal omzet paket.
  - Persentase pencapaian target triwulan dan sisa nominal menuju target.
  - Grafik batang fl_chart per bulan dalam triwulan terpilih.
  - Tabel perbandingan performa penjualan dan klien per Personal Trainer.
- Melihat daftar seluruh Personal Trainer Mbois Gym beserta profil profesionalnya.
- Mengelola penugasan klien antar-PT.

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

## 4. Pricelist Resmi Paket Personal Trainer

Berdasarkan tarif resmi Mbois Gym, aplikasi menyediakan 4 pilihan paket PT individu baku:

| Paket | Sesi | Durasi | Harga Resmi |
|---|---|---|---|
| **Paket 4 Sesi** | 4 sesi | 4 minggu | Rp 500.000 |
| **Paket 10 Sesi** | 10 sesi | 4 minggu | Rp 1.000.000 |
| **Paket 16 Sesi** | 16 sesi | 8 minggu | Rp 1.600.000 |
| **Paket 24 Sesi** | 24 sesi | 8 minggu | Rp 2.000.000 |

- Setiap pendaftaran klien baru atau perpanjangan paket PT menyimpan snapshot harga dan data paket ke `package_sales`, sehingga perubahan harga di masa mendatang tidak mengubah riwayat finansial terdahulu.
- Kuota sesi dihitung secara atomik dan tidak dapat bernilai negatif.

---

## 5. Fitur Operasional Utama

### A. CRUD Absensi & Pembatalan Sesi
- **CREATE**: Menjadwalkan appointment sesi latihan berdasarkan kalender dan waktu.
- **READ**: Filter status sesi yang interaktif:
  - `Aktif / Dijadwalkan` (default): Menampilkan sesi mendatang yang siap dijalankan.
  - `Hadir`: Menampilkan riwayat sesi yang telah selesai diverifikasi.
  - `Dibatalkan`: Menampilkan sesi yang dibatalkan beserta alasannya.
  - `Semua`: Menampilkan seluruh catatan sesi.
- **UPDATE / CANCEL**:
  - Tombol **Batalkan Sesi** memunculkan dialog konfirmasi dan input alasan pembatalan. Sesi yang dibatalkan **langsung menghilang dari daftar sesi aktif**, tersimpan permanen di cloud dengan status `cancelled`, dan **kuota paket klien tidak terpotong**.
- **DELETE / RESTORE**: Audit trail tersimpan pada dokumen sesi tanpa penghapusan diam-diam.

### B. Pop-Up Tanda Tangan Khusus Touchscreen
Menjawab kendala gesture dragging pada layar HP fisik:
- **Dedicated Fullscreen Dialog**: Membuka kanvas tanda tangan modal dengan ukuran besar yang terkunci (`PopScope(canPop: false)`), mencegah konflik scrolling halaman latar.
- **RawGestureDetector Independen**: Gesture menggambar menang di arena gesture Flutter, mendukung multi-stroke tanpa terhapus saat jari diangkat.
- **Verifikasi Ganda**: Memeriksa tanda tangan terpisah untuk **Klien** dan **Coach / PT**.
- **Signature Preview Card**: Menampilkan kartu pratinjau tanda tangan, status terverifikasi, dan opsi ubah tanda tangan sebelum konfirmasi akhir.
- **Proteksi Idempotensi**: Mencegah double-tap tombol "Verifikasi & Potong Sesi" dan memproses transaksi atomik Firestore.

### C. Dashboard Manajer & Target Triwulan Rp 5 Juta
- Menggunakan `fl_chart` untuk menampilkan grafik batang real-time penjualan 3 bulan dalam satu triwulan.
- Menghitung persentase pencapaian omzet valid terhadap target Rp 5.000.000.
- Menampilkan perbandingan performa masing-masing PT (klien ditangani, paket terjual, dan total nominal tercatat).
- Filter pemilihan kuartal (Q1 Jan-Mar, Q2 Apr-Jun, Q3 Jul-Sep, Q4 Oct-Dec) dan tahun.

---

## 6. Firestore Security Rules

Keamanan database diatur dalam `firestore.rules` dan diuji secara deterministik dengan Firebase Emulator Suite (57 pengujian):
1. Pengguna tak terotentikasi dan akun berstatus `pending`/`inactive` diblokir total dari seluruh data operasional.
2. Trainer hanya dapat membaca dan menulis data klien yang terdaftar di `assignedTrainerIds`.
3. Trainer dilarang memanipulasi `role`, `status`, atau `assignedTrainerIds` sendiri.
4. Trainer dilarang mengubah status sesi menjadi `completed` atau menaikkan `completedCount` kuota secara langsung dari client tanpa melalui transaksi backend yang sah.
5. Manajer memiliki hak baca seluruh profil PT, data klien, subkoleksi operasional, dan katalog penjualan untuk keperluan pelaporan dashboard.
6. Subkoleksi root tak berpemilik dan koleksi warisan diblokir (`fail closed`).

---

## 7. Pengujian & Hasil Validasi

Validasi dijalankan secara menyeluruh di lingkungan pengujian:

| Pengujian | Perintah | Hasil Aktual |
|---|---|---|
| **Firestore Security Rules** | `npm run test:rules` | **57 tests passed** (0 failed) |
| **Flutter Analyze** | `flutter analyze --no-fatal-infos` | **0 errors, 0 warnings** (Clean) |
| **Flutter Test Suite** | `flutter test --no-pub --platform=tester` | **115 tests passed** (0 failed) |
| **Android APK Debug Build** | `flutter build apk --debug --no-pub` | **SUCCESS** (`app-debug.apk`) |

### Rincian Test Suite Flutter (115 tests):
- `test/auth_test.dart` (11 tests): Otentikasi dan hashing.
- `test/cloud_auth_cutover_test.dart` (17 tests): Firebase Auth, reset password, dan pemblokiran akun inaktif.
- `test/firestore_session_repository_test.dart` (16 tests): Transaksi atomik sesi, idempotensi, dan fallback ID.
- `test/pt_packages_and_manager_metrics_test.dart` (10 tests): Perhitungan metrik triwulan, fl_chart data, dan format Rupiah.
- `test/signature_pad_test.dart` (13 tests): Kanvas tanda tangan dan preview card.
- `test/dedicated_signature_dialog_test.dart` (17 tests): Dialog fullscreen tanda tangan adaptif.
- `test/manager_dashboard_test.dart` (10 tests): UI responsif dashboard manajer dan fl_chart rendering.
- `test/pt_features_and_signature_flow_test.dart` (4 tests): Alur pembatalan sesi, pemotongan kuota, dan form paket resmi.
- `test/ui_flow_test.dart`, `test/revision_ui_test.dart`, `test/workout_ui_test.dart`, `test/exercise_api_test.dart`: Regresi UI dan workout log.

---

## 8. Cara Menjalankan Project

### Prasyarat
- Flutter SDK `^3.13.2`
- Android SDK (API Level 21+)
- Node.js & npm (untuk Firebase Emulator rules tests)
- Java 17 / 21

### Langkah Menjalankan
1. Clone repository:
   ```bash
   git clone https://github.com/YakzIsGood/mbois-gym.git
   cd mbois-gym
   ```
2. Pasang dependency:
   ```bash
   flutter pub get
   ```
3. Jalankan pengujian otomatis:
   ```bash
   flutter test --no-pub --platform=tester
   ```
4. Jalankan emulator Firestore rules:
   ```bash
   npm ci
   npm run test:rules
   ```
5. Jalankan aplikasi pada perangkat Android:
   ```bash
   flutter run
   ```
6. Kompilasi APK debug:
   ```bash
   flutter build apk --debug
   ```
   Artefak APK tersimpan di: `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 9. Batasan & Tindak Lanjut Backend

- **Firebase Storage**: Bukti tanda tangan dan foto profil saat ini diverifikasi integritas titik sentuhannya di perangkat dan status verifikasi dicatat di Cloud Firestore. Integrasi upload blob PNG bytes ke Google Cloud Storage memerlukan aktivasi paket billing Firebase / bucket storage produksi.
- **Multi-Device Live Sync**: Sinkronisasi data operasional berjalan secara real-time via Cloud Firestore. Uji fisik multi-device di lapangan tetap direkomendasikan untuk memvalidasi kenyamanan tanda tangan pada berbagai rasio layar sentuh.
