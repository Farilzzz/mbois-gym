#!/usr/bin/env node
'use strict';

/**
 * Mbois Gym Firebase Admin SDK CLI
 * Administrative provisioning for Trainers and Managers.
 * Uses Application Default Credentials (ADC), enforces explicit project 'mbois-gym',
 * preserves existing claims & profile fields, uses atomic consistency, and never accepts or logs secrets.
 */

const { AdminService } = require('./lib/admin_service.cjs');

const VALID_ROLES = ['trainer', 'manager'];
const ALLOWED_PROJECT = 'mbois-gym';

function parseArgs(args) {
  if (!args || args.length === 0) {
    return { command: 'help' };
  }

  let command = null;
  const options = {
    project: null,
    dryRun: false,
  };

  const PROHIBITED_OPTIONS = ['--password', '-p', '--secret', '--token'];

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    for (const prohibited of PROHIBITED_OPTIONS) {
      if (arg === prohibited || arg.startsWith(prohibited + '=')) {
        throw new Error(`Opsi '${prohibited}' dilarang. CLI ini tidak menerima password atau secret langsung.`);
      }
    }

    if (!command && !arg.startsWith('-')) {
      command = arg;
      continue;
    }

    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--apply') {
      options.apply = true;
      options.dryRun = false;
    } else if (arg === '--project') {
      options.project = args[++i];
    } else if (arg.startsWith('--project=')) {
      options.project = arg.split('=')[1];
    } else if (arg === '--year') {
      options.year = parseInt(args[++i], 10);
    } else if (arg.startsWith('--year=')) {
      options.year = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--quarter' || arg === '-q') {
      options.quarter = parseInt(args[++i], 10);
    } else if (arg.startsWith('--quarter=')) {
      options.quarter = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--timezone' || arg === '--tz') {
      options.timezone = args[++i];
    } else if (arg.startsWith('--timezone=') || arg.startsWith('--tz=')) {
      options.timezone = arg.split('=')[1];
    } else if (arg === '--json') {
      options.json = true;
    } else if (arg === '--role') {
      options.role = args[++i];
    } else if (arg.startsWith('--role=')) {
      options.role = arg.split('=')[1];
    } else if (arg === '--uid') {
      options.uid = args[++i];
    } else if (arg.startsWith('--uid=')) {
      options.uid = arg.split('=')[1];
    } else if (arg === '--email') {
      options.email = args[++i];
    } else if (arg.startsWith('--email=')) {
      options.email = arg.split('=')[1];
    } else if (arg === '--name' || arg === '--display-name') {
      options.name = args[++i];
    } else if (arg.startsWith('--name=') || arg.startsWith('--display-name=')) {
      options.name = arg.split('=')[1];
    } else if (arg === '--phone') {
      options.phone = args[++i];
    } else if (arg.startsWith('--phone=')) {
      options.phone = arg.split('=')[1];
    } else if (arg === '--status') {
      options.status = args[++i];
    } else if (arg.startsWith('--status=')) {
      options.status = arg.split('=')[1];
    } else {
      throw new Error(`Argumen tidak dikenal: ${arg}`);
    }
  }

  if (options.help) {
    return { command: 'help', ...options };
  }

  if (!command) {
    throw new Error('Perintah harus ditentukan.');
  }

  // Normalize command aliases
  if (command === 'create-trainer') {
    command = 'create';
    options.role = 'trainer';
  } else if (command === 'create-manager') {
    command = 'create';
    options.role = 'manager';
  } else if (command === 'sync-projection' || command === 'projection-sync') {
    command = 'sync-projections';
  }

  const VALID_COMMANDS = ['create', 'provision-existing', 'status', 'disable', 'reset-link', 'sync-projections', 'help'];
  if (!VALID_COMMANDS.includes(command)) {
    throw new Error(`Perintah tidak valid: '${command}'. Pilih salah satu: ${VALID_COMMANDS.join(', ')}`);
  }

  // Validate explicit project
  if (!options.project) {
    throw new Error(`Harus menyertakan flag eksplisit --project ${ALLOWED_PROJECT}`);
  }
  if (options.project !== ALLOWED_PROJECT) {
    throw new Error(`Project '${options.project}' tidak diizinkan. CLI ini dibatasi secara eksplisit untuk project '${ALLOWED_PROJECT}'.`);
  }

  if (command === 'sync-projections') {
    if (options.quarter !== undefined && (!Number.isInteger(options.quarter) || options.quarter < 1 || options.quarter > 4)) {
      throw new Error(`Kuartal tidak valid: ${options.quarter}. Harus bernilai 1-4.`);
    }
  }

  // Validate UID if present (alphanumeric, no path traversal)
  if (options.uid !== undefined) {
    if (!options.uid || typeof options.uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(options.uid)) {
      throw new Error(`Format UID tidak valid: '${options.uid}'`);
    }
  }

  // Validate role if required or provided
  if (command === 'create' || command === 'provision-existing') {
    if (!options.role) {
      throw new Error(`Flag --role <trainer|manager> wajib diisi untuk perintah '${command}'.`);
    }
    if (!VALID_ROLES.includes(options.role)) {
      throw new Error(`Role '${options.role}' tidak valid. Role yang diizinkan hanya: ${VALID_ROLES.join(', ')}`);
    }
  }

  if (command === 'create' && !options.email) {
    throw new Error("Flag --email <email> wajib diisi untuk perintah 'create'.");
  }

  if ((command === 'status' || command === 'disable') && !options.uid && !options.email) {
    throw new Error(`Harus menyertakan flag --uid <uid> atau --email <email> untuk perintah '${command}'.`);
  }

  if (command === 'provision-existing' && !options.uid && !options.email) {
    throw new Error("Harus menyertakan flag --uid <uid> (atau --email <email>) untuk 'provision-existing'.");
  }

  if (command === 'reset-link' && !options.email && !options.uid) {
    throw new Error("Harus menyertakan flag --email <email> (atau --uid <uid>) untuk 'reset-link'.");
  }

  return { command, ...options };
}

function printHelp() {
  console.log(`
================================================================================
 Mbois Gym Firebase Admin SDK CLI (tools/admin)
================================================================================

CLI administratif untuk memprovisi akun Trainer dan Manager pada Firebase Auth & Firestore.
Menggunakan Application Default Credentials (ADC) tanpa secret file dalam git repository.
Dibatasi secara ketat dan eksplisit untuk --project mbois-gym.

PENGGUNAAN:
  node ./admin.cjs <command> --project mbois-gym [opsi...]

PERINTAH YANG TERSEDIA:
  create            Membuat akun Auth baru, custom claims role, dan profil Firestore users/{uid}.
                    Alias: create-trainer, create-manager.
                    Contoh:
                      node ./admin.cjs create --project mbois-gym --role trainer --email coach@mbois.com --name "Coach Budi"
                      node ./admin.cjs create-manager --project mbois-gym --email manager@mbois.com --name "Manager Gym"

  provision-existing
                    Memprovisi akun yang sudah ada (misal dari Auth export atau akun lama)
                    dengan menetapkan role (claims + Firestore) dan status active,
                    sambil MEMPERTAHANKAN custom claims dan field profil yang sudah ada.
                    Contoh:
                      node ./admin.cjs provision-existing --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63 --role trainer
                      node ./admin.cjs provision-existing --project mbois-gym --email user@example.com --role manager

  status            Memeriksa status akun di Firebase Auth dan dokumen Firestore /users/{uid}.
                    Melaporkan status konsistensi dan izin akses aplikasi secara jujur.
                    Contoh:
                      node ./admin.cjs status --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63
                      node ./admin.cjs status --project mbois-gym --email babangfaril5@gmail.com

  disable           Menonaktifkan akun di Firebase Auth (disabled: true) dan menandai status
                    dokumen Firestore menjadi 'inactive' tanpa menghapus data.
                    Contoh:
                      node ./admin.cjs disable --project mbois-gym --uid xtGOiCT0JBhSVorhRkFEbkdSUp63

  reset-link        Membuat link reset password satu kali via Admin SDK.
                    PERHATIAN: Link ini HANYA dibuat secara lokal via Admin SDK;
                    email TIDAK otomatis dikirim oleh Firebase ke pengguna.
                    Contoh:
                      node ./admin.cjs reset-link --project mbois-gym --email babangfaril5@gmail.com

  sync-projections  Membangun atau mensinkronkan read-model dashboard manajer.
                    Alias: sync-projection, projection-sync.
                    Contoh:
                      node ./admin.cjs sync-projections --project mbois-gym --year 2026 --quarter 1
                      node ./admin.cjs sync-projections --project mbois-gym --apply

OPSI GLOBAL:
  --project <id>    Wajib diisi secara eksplisit: 'mbois-gym'.
  --dry-run         Mensimulasikan eksekusi tanpa mengubah data di Auth atau Firestore.
  --help, -h        Menampilkan panduan ini.

PRINSIP KEAMANAN:
  1. ADC (Application Default Credentials): Jalankan 'gcloud auth application-default login'
     sebelum menggunakan tool ini di lingkungan live, atau gunakan Emulator Firebase.
  2. TIDAK MENERIMA PASSWORD/SECRET: Tool ini menolak flag --password atau --secret.
     Pembuatan password dilakukan mandiri oleh pengguna via link reset password.
  3. INTEGRITAS DATA: Mempertahankan field profil spesialisasi, biografi, sertifikasi, dll.
================================================================================
`);
}

function initFirebaseAdmin(projectId) {
  const admin = require('firebase-admin');
  if (admin.apps.length === 0) {
    admin.initializeApp({
      projectId,
      credential: admin.credential.applicationDefault(),
    });
  }
  return {
    auth: admin.auth(),
    firestore: admin.firestore(),
    FieldValue: admin.firestore.FieldValue,
  };
}

async function runCli(args, serviceOverride = null) {
  const parsed = parseArgs(args);

  if (parsed.command === 'help') {
    printHelp();
    return { command: 'help' };
  }

  let service = serviceOverride;
  let adminInstances = null;
  if (!service) {
    adminInstances = initFirebaseAdmin(parsed.project);
    service = new AdminService(adminInstances);
  }

  let result;
  switch (parsed.command) {
    case 'create':
      result = await service.createUser({
        email: parsed.email,
        role: parsed.role,
        displayName: parsed.name,
        phone: parsed.phone,
        dryRun: parsed.dryRun,
      });
      break;

    case 'provision-existing':
      result = await service.provisionExistingUser({
        uid: parsed.uid,
        email: parsed.email,
        role: parsed.role,
        name: parsed.name,
        displayName: parsed.name,
        status: parsed.status || 'active',
        dryRun: parsed.dryRun,
      });
      break;

    case 'status':
      result = await service.getUserStatus({
        uid: parsed.uid,
        email: parsed.email,
      });
      break;

    case 'disable':
      result = await service.disableUser({
        uid: parsed.uid,
        email: parsed.email,
        dryRun: parsed.dryRun,
      });
      break;

    case 'reset-link':
      result = await service.generateResetLink({
        uid: parsed.uid,
        email: parsed.email,
      });
      break;

    case 'sync-projections': {
      if (service && typeof service.syncProjections === 'function') {
        result = await service.syncProjections(parsed);
      } else {
        const { runProjectionJob } = require('../projections/builder.cjs');
        const db = (service && service.firestore)
          ? service.firestore
          : (adminInstances ? adminInstances.firestore : initFirebaseAdmin(parsed.project).firestore);
        result = await runProjectionJob(db, {
          project: parsed.project,
          year: parsed.year,
          quarter: parsed.quarter,
          timezone: parsed.timezone,
          apply: parsed.apply === true,
          dryRun: parsed.apply ? false : (parsed.dryRun !== undefined ? parsed.dryRun : true),
          json: parsed.json || false,
        });
      }
      break;
    }

    default:
      throw new Error(`Perintah tidak didukung: ${parsed.command}`);
  }

  return result;
}

if (require.main === module) {
  runCli(process.argv.slice(2))
    .then((res) => {
      console.log(JSON.stringify(res, null, 2));
      process.exit(0);
    })
    .catch((err) => {
      console.error(`\x1b[31m[ERROR]\x1b[0m ${err.message}`);
      process.exit(1);
    });
}

module.exports = {
  VALID_ROLES,
  ALLOWED_PROJECT,
  parseArgs,
  printHelp,
  initFirebaseAdmin,
  runCli,
};
