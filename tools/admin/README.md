# Firebase Admin CLI — Mbois Gym (`tools/admin`)

Tool baris perintah administratif berbasis Node.js dan Firebase Admin SDK untuk manajemen akun, provisi peran (*role provisioning*), dan sinkronisasi profil Trainer serta Manager di lingkungan Mbois Gym.

---

## 1. Latar Belakang & Arsitektur

### 1.1 Model Hak Akses & Role Parser
Sistem aplikasi Mbois Gym (`mbois-gym-revisi`) menggunakan dual-layer authorization:
1. **Firestore Security Rules (`firestore.rules`)**:
   Fungsi `activeRole(role)` memverifikasi keberadaan dan keaktifan dokumen profil pengguna pada koleksi `/users/{uid}`:
   ```javascript
   function activeRole(role) {
     return signedIn()
       && exists(/databases/$(database)/documents/users/$(request.auth.uid))
       && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == role
       && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.status == 'active';
   }
   ```
   Aturan `/users/{uid}` melarang klien membuat atau menghapus akun (`allow create, delete: if false;`), sehingga pembuatan profil hanya dapat dilakukan secara tepercaya via Admin SDK.
2. **Flutter App Gateway (`lib/cloud/cloud_session.dart` & `lib/cloud/firebase_cloud_gateway.dart`)**:
   `CloudRole.parse(value)` hanya menerima `'trainer'` dan `'manager'`. Profil dinyatakan dapat mengakses aplikasi (`canAccess`) apabila `active == true` (`status == 'active'`) dan `typedRole != null`.
3. **Firebase Auth Custom Claims**:
   Admin CLI menetapkan klaim `{ role: 'trainer' | 'manager' }` pada token Auth pengguna untuk konsistensi token dan backend endpoints di masa depan, sekaligus **mempertahankan custom claims yang sudah ada**.

---

## 2. Prinsip Keamanan & Desain

- **Application Default Credentials (ADC)**:
  Tool tidak memuat file kunci rahasia (*service account JSON*) di dalam repositori git. Autentikasi Admin SDK menggunakan kredensial ADC lingkungan mesin.
- **Eksplisit `--project mbois-gym`**:
  Semua perintah memvalidasi parameter proyek secara ketat guna mencegah salah sasaran ke proyek Firebase lain.
- **Tanpa Penyimpanan / Penerimaan Rahasia**:
  CLI menolak opsi `--password` atau `--secret`. Pembuatan password awal atau pembaruan password dilakukan mandiri oleh pengguna melalui link reset password.
- **Pelaporan Jujur (Honest Reporting)**:
  - Perintah `status` membedakan secara tegas antara eksistensi akun di Auth vs Firestore (misalnya pengguna yang baru ada di Auth export namun belum diprovisi di Firestore seperti UID `xtGOiCT0JBhSVorhRkFEbkdSUp63`).
  - Perintah `reset-link` secara transparan mencantumkan peringatan bahwa email **TIDAK** dikirim otomatis oleh Firebase, melainkan link dibuat secara lokal untuk dikirimkan secara manual.
- **Preservasi Data & Atomisitas**:
  Pembaruan pada akun yang sudah ada (`provision-existing`) menggunakan transaksi Firestore agar field spesialisasi, biografi, sertifikasi, tinggi, dan berat badan tidak tertimpa/hilang.

---

## 3. Instalasi & Prasyarat

Masuk ke direktori `tools/admin`:
```bash
cd tools/admin
npm install
```

### Konfigurasi ADC (Sebelum Menjalankan ke Lingkungan Live)
```bash
gcloud auth application-default login
```
*Catatan: Jika dijalankan dalam emulator lokal Firebase, set env:*
```bash
export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
```

---

## 4. Referensi Perintah CLI

### 4.1 Membuat Akun Baru (`create` / `create-trainer` / `create-manager`)
Membuat akun di Firebase Auth, memberikan klaim peran, dan membuat dokumen `/users/{uid}`.
```bash
# Membuat Trainer baru
node ./admin.cjs create-trainer --project mbois-gym --email coach.budi@mbois.com --name "Coach Budi" --phone "081234567890"

# Membuat Manager baru
node ./admin.cjs create-manager --project mbois-gym --email manager@mbois.com --name "Manager Gym"

# Mode Dry-Run (simulasi tanpa penulisan data)
node ./admin.cjs create-trainer --project mbois-gym --email coach.test@mbois.com --dry-run
```

### 4.2 Provisi Akun Eksisting (`provision-existing`)
Digunakan untuk akun yang sudah ada di Auth (misalnya hasil ekspor Auth seperti `xtGOiCT0JBhSVorhRkFEbkdSUp63` / `babangfaril5@gmail.com`).
Mempertahankan custom claims lama dan seluruh field profil Firestore yang sudah tersimpan.
```bash
# Provisi target UID menjadi trainer aktif
node ./admin.cjs provision-existing --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63 --role trainer

# Provisi via email
node ./admin.cjs provision-existing --project mbois-gym --email babangfaril5@gmail.com --role manager
```

### 4.3 Memeriksa Status Akun (`status`)
Memeriksa status akun di Firebase Auth dan dokumen `/users/{uid}` secara mendalam.
```bash
node ./admin.cjs status --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63
node ./admin.cjs status --project mbois-gym --email babangfaril5@gmail.com
```

### 4.4 Menonaktifkan Akun (`disable`)
Menonaktifkan login pengguna di Firebase Auth (`disabled: true`) dan mengubah status profil Firestore menjadi `'inactive'`. Data latihan, absensi, dan profil tetap utuh.
```bash
node ./admin.cjs disable --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63
```

### 4.5 Membuat Link Reset Password (`reset-link`)
Menghasilkan tautan pemulihan kata sandi satu kali pakai (*action URL*).
```bash
node ./admin.cjs reset-link --project mbois-gym --email babangfaril5@gmail.com
```
*Output memuat peringatan eksplisit:*
> `PERHATIAN: Link reset password berhasil dibuat via Admin SDK. Email TIDAK otomatis dikirim oleh Firebase ke pengguna. Bagikan link ini secara manual dan aman ke pengguna.`

---

## 5. Pengujian Otomatis (TDD)

Jalankan test suite menggunakan Node test runner:
```bash
npm test
# atau
node --test test/*.test.cjs
```
Semua kasus uji mencakup:
- Validasi flag `--project mbois-gym` dan penolakan opsi berbahaya (`--password`, `--secret`).
- Pembuatan akun Auth + Firestore dengan klaim peran.
- Pencegahan duplikasi email akun.
- Rollback Auth user otomatis apabila penulisan profil Firestore gagal.
- Preservasi klaim custom dan data profil Firestore pada `provision-existing`.
- Diagnostik status jujur untuk akun Auth-only tanpa dokumen Firestore.
- Penonaktifan akun secara sinkron di Auth dan Firestore.
- Kejujuran pengiriman email pada `reset-link`.
- Mode `--dry-run` tanpa mutasi data.
