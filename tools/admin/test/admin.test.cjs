const { test } = require('node:test');
const assert = require('node:assert/strict');
const { parseArgs } = require('../admin.cjs');
const { AdminService } = require('../lib/admin_service.cjs');

test('requires explicit exact project and validates command before SDK initialization', async () => {
  assert.throws(() => parseArgs(['status', '--uid', 'u']), /project/);
  assert.throws(() => parseArgs(['status', '--project', 'other', '--uid', 'u']), /project/);
  assert.deepEqual(parseArgs(['status', '--project', 'mbois-gym', '--uid', 'u']), { command: 'status', project: 'mbois-gym', dryRun: false, uid: 'u' });
  assert.throws(() => parseArgs(['create', '--project', 'mbois-gym', '--role', 'admin', '--email', 'a@example.com', '--name', 'A']), /role/i);
  assert.throws(() => parseArgs(['status', '--project', 'mbois-gym', '--uid', '../bad']), /uid/i);
  assert.throws(() => parseArgs(['status', '--project', 'mbois-gym', '--uid', 'u', '--password', 'secret']), /opsi|option/i);
});

// In-Memory Test Double for Firebase Auth & Firestore
function createMockFirebase() {
  const usersAuth = new Map(); // uid -> userRecord
  const usersFirestore = new Map(); // uid -> docData
  let firestoreFailsNext = false;

  const auth = {
    async getUser(uid) {
      const u = usersAuth.get(uid);
      if (!u) {
        const err = new Error(`User not found: ${uid}`);
        err.code = 'auth/user-not-found';
        throw err;
      }
      return JSON.parse(JSON.stringify(u));
    },
    async getUserByEmail(email) {
      for (const u of usersAuth.values()) {
        if (u.email && u.email.toLowerCase() === email.toLowerCase()) {
          return JSON.parse(JSON.stringify(u));
        }
      }
      const err = new Error(`User not found with email: ${email}`);
      err.code = 'auth/user-not-found';
      throw err;
    },
    async createUser(props) {
      for (const u of usersAuth.values()) {
        if (u.email && u.email.toLowerCase() === props.email.toLowerCase()) {
          const err = new Error(`The email address is already in use by another account.`);
          err.code = 'auth/email-already-exists';
          throw err;
        }
      }
      const uid = props.uid || `uid_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const record = {
        uid,
        email: props.email,
        displayName: props.displayName || '',
        phoneNumber: props.phoneNumber || '',
        disabled: false,
        customClaims: {},
      };
      usersAuth.set(uid, record);
      return JSON.parse(JSON.stringify(record));
    },
    async setCustomUserClaims(uid, claims) {
      const u = usersAuth.get(uid);
      if (!u) throw new Error('User not found');
      u.customClaims = { ...claims };
    },
    async updateUser(uid, props) {
      const u = usersAuth.get(uid);
      if (!u) throw new Error('User not found');
      if (props.disabled !== undefined) u.disabled = props.disabled;
      if (props.displayName !== undefined) u.displayName = props.displayName;
      return JSON.parse(JSON.stringify(u));
    },
    async deleteUser(uid) {
      usersAuth.delete(uid);
    },
    async generatePasswordResetLink(email) {
      await this.getUserByEmail(email);
      return `https://mbois-gym.firebaseapp.com/__/auth/action?mode=resetPassword&email=${encodeURIComponent(email)}&apiKey=FAKE_KEY`;
    },
  };

  const firestore = {
    collection(name) {
      if (name !== 'users') throw new Error(`Collection mock only handles 'users', got '${name}'`);
      return {
        doc: (uid) => {
          return {
            id: uid,
            path: `users/${uid}`,
            async get() {
              const data = usersFirestore.get(uid);
              return {
                exists: data !== undefined,
                id: uid,
                data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined),
              };
            },
            async set(data, options = {}) {
              if (firestoreFailsNext) {
                firestoreFailsNext = false;
                throw new Error('Simulated Firestore write failure');
              }
              if (options.merge) {
                const prev = usersFirestore.get(uid) || {};
                usersFirestore.set(uid, { ...prev, ...data });
              } else {
                usersFirestore.set(uid, { ...data });
              }
            },
          };
        },
      };
    },
    async runTransaction(updateFunction) {
      if (firestoreFailsNext) {
        firestoreFailsNext = false;
        throw new Error('Simulated Firestore transaction failure');
      }
      const transaction = {
        async get(docRef) {
          const data = usersFirestore.get(docRef.id);
          return {
            exists: data !== undefined,
            id: docRef.id,
            data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined),
          };
        },
        set(docRef, data, options = {}) {
          if (options.merge) {
            const prev = usersFirestore.get(docRef.id) || {};
            usersFirestore.set(docRef.id, { ...prev, ...data });
          } else {
            usersFirestore.set(docRef.id, { ...data });
          }
        },
      };
      return await updateFunction(transaction);
    },
    _setFailsNext(val) {
      firestoreFailsNext = val;
    },
    _getRawDoc(uid) {
      return usersFirestore.get(uid);
    },
    _setRawDoc(uid, data) {
      usersFirestore.set(uid, data);
    },
  };

  return { auth, firestore, usersAuth, usersFirestore };
}

test('CLI: parses aliases create-trainer and create-manager with explicit project', async () => {
  const parsedTrainer = parseArgs(['create-trainer', '--project', 'mbois-gym', '--email', 'coach@mbois.com', '--name', 'Coach B']);
  assert.equal(parsedTrainer.command, 'create');
  assert.equal(parsedTrainer.role, 'trainer');
  assert.equal(parsedTrainer.email, 'coach@mbois.com');
  assert.equal(parsedTrainer.name, 'Coach B');

  const parsedManager = parseArgs(['create-manager', '--project', 'mbois-gym', '--email', 'mgr@mbois.com', '--name', 'Manager M']);
  assert.equal(parsedManager.command, 'create');
  assert.equal(parsedManager.role, 'manager');
  assert.equal(parsedManager.email, 'mgr@mbois.com');
});

test('AdminService: createUser creates Auth user, sets role claim, and creates Firestore profile', async () => {
  const mock = createMockFirebase();
  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  const result = await service.createUser({
    email: 'trainer1@mbois.com',
    role: 'trainer',
    displayName: 'Trainer One',
    phone: '081234567890',
  });

  assert.equal(result.success, true);
  assert.ok(result.uid);
  assert.equal(result.role, 'trainer');
  assert.equal(result.status, 'active');

  // Verify Auth
  const authUser = await mock.auth.getUser(result.uid);
  assert.equal(authUser.email, 'trainer1@mbois.com');
  assert.equal(authUser.displayName, 'Trainer One');
  assert.deepEqual(authUser.customClaims, { role: 'trainer' });
  assert.equal(authUser.disabled, false);

  // Verify Firestore document at /users/{uid}
  const docSnapshot = await mock.firestore.collection('users').doc(result.uid).get();
  assert.equal(docSnapshot.exists, true);
  const data = docSnapshot.data();
  assert.equal(data.email, 'trainer1@mbois.com');
  assert.equal(data.displayName, 'Trainer One');
  assert.equal(data.phone, '081234567890');
  assert.equal(data.role, 'trainer');
  assert.equal(data.status, 'active');
  assert.ok(data.createdAt);
});

test('AdminService: createUser rejects duplicate email without partial state', async () => {
  const mock = createMockFirebase();
  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  await service.createUser({
    email: 'duplicate@mbois.com',
    role: 'manager',
    displayName: 'Boss 1',
  });

  await assert.rejects(
    () => service.createUser({
      email: 'duplicate@mbois.com',
      role: 'trainer',
      displayName: 'Boss 2',
    }),
    /already in use|sudah terdaftar/i
  );
});

test('AdminService: createUser rolls back Auth user if Firestore write fails', async () => {
  const mock = createMockFirebase();
  mock.firestore._setFailsNext(true);
  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  await assert.rejects(
    () => service.createUser({
      email: 'fail_fs@mbois.com',
      role: 'trainer',
      displayName: 'Will Fail',
    }),
    /Firestore/i
  );

  // Auth user must have been rolled back / cleaned up
  await assert.rejects(
    () => mock.auth.getUserByEmail('fail_fs@mbois.com'),
    /not found/i
  );
});

test('AdminService: provisionExistingUser preserves existing claims and Firestore profile fields', async () => {
  const mock = createMockFirebase();
  const targetUid = 'xtGOiCT0JBhSVorhRkFEbkdSUp63';

  // Seed existing Auth user with existing custom claim
  mock.usersAuth.set(targetUid, {
    uid: targetUid,
    email: 'babangfaril5@gmail.com',
    displayName: 'Babang Faril',
    phoneNumber: '+628111111111',
    disabled: false,
    customClaims: { existing_app_grant: true },
  });

  // Seed existing Firestore user with existing profile fields
  mock.usersFirestore.set(targetUid, {
    displayName: 'Babang Faril',
    email: 'babangfaril5@gmail.com',
    phone: '+628111111111',
    heightCm: 175.5,
    weightKg: 72.0,
    specialization: 'Hypertrophy & Strength',
    experienceYears: 4,
    certifications: 'APKI Certified Personal Trainer',
    bio: 'Dedicated fitness coach with 4 years experience.',
    photoUrl: 'https://cdn.example.com/photo.jpg',
    status: 'inactive', // initially inactive
  });

  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  const result = await service.provisionExistingUser({
    uid: targetUid,
    role: 'trainer',
  });

  assert.equal(result.success, true);
  assert.equal(result.uid, targetUid);
  assert.equal(result.role, 'trainer');
  assert.equal(result.status, 'active');

  // Verify Auth: role is set AND existing claims preserved
  const updatedAuth = await mock.auth.getUser(targetUid);
  assert.equal(updatedAuth.customClaims.role, 'trainer');
  assert.equal(updatedAuth.customClaims.existing_app_grant, true);
  assert.equal(updatedAuth.disabled, false);

  // Verify Firestore: role and status active, but existing profile fields intact!
  const updatedDoc = await mock.firestore.collection('users').doc(targetUid).get();
  const data = updatedDoc.data();
  assert.equal(data.role, 'trainer');
  assert.equal(data.status, 'active');
  assert.equal(data.heightCm, 175.5);
  assert.equal(data.weightKg, 72.0);
  assert.equal(data.specialization, 'Hypertrophy & Strength');
  assert.equal(data.experienceYears, 4);
  assert.equal(data.certifications, 'APKI Certified Personal Trainer');
  assert.equal(data.bio, 'Dedicated fitness coach with 4 years experience.');
  assert.equal(data.photoUrl, 'https://cdn.example.com/photo.jpg');
});

test('AdminService: provisionExistingUser provisions Firestore document if user existed in Auth export only', async () => {
  const mock = createMockFirebase();
  const targetUid = 'xtGOiCT0JBhSVorhRkFEbkdSUp63';

  // Seed Auth only (as noted in context: live Firestore unknown)
  mock.usersAuth.set(targetUid, {
    uid: targetUid,
    email: 'babangfaril5@gmail.com',
    displayName: 'Faril',
    phoneNumber: '',
    disabled: false,
    customClaims: {},
  });

  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  const result = await service.provisionExistingUser({
    uid: targetUid,
    role: 'manager',
  });

  assert.equal(result.success, true);
  assert.equal(result.role, 'manager');

  const doc = await mock.firestore.collection('users').doc(targetUid).get();
  assert.equal(doc.exists, true);
  const data = doc.data();
  assert.equal(data.role, 'manager');
  assert.equal(data.status, 'active');
  assert.equal(data.email, 'babangfaril5@gmail.com');
  assert.equal(data.displayName, 'Faril');
});

test('AdminService: getUserStatus honestly differentiates Auth existence from Firestore existence', async () => {
  const mock = createMockFirebase();
  const unprovisionedUid = 'xtGOiCT0JBhSVorhRkFEbkdSUp63';

  // Only Auth has user, Firestore does not
  mock.usersAuth.set(unprovisionedUid, {
    uid: unprovisionedUid,
    email: 'babangfaril5@gmail.com',
    displayName: 'Faril',
    phoneNumber: '',
    disabled: false,
    customClaims: {},
  });

  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  const status = await service.getUserStatus({ uid: unprovisionedUid });

  assert.equal(status.auth.exists, true);
  assert.equal(status.auth.uid, unprovisionedUid);
  assert.equal(status.firestore.exists, false);
  assert.equal(status.isConsistent, false);
  assert.equal(status.canAccess, false);
  assert.match(status.diagnostic, /Firestore profile belum dibuat|Auth export only/i);
});

test('AdminService: disableUser disables Auth and marks Firestore profile inactive', async () => {
  const mock = createMockFirebase();
  const uid = 'trainer_active_1';

  mock.usersAuth.set(uid, {
    uid,
    email: 't1@mbois.com',
    displayName: 'T1',
    disabled: false,
    customClaims: { role: 'trainer' },
  });
  mock.usersFirestore.set(uid, {
    displayName: 'T1',
    email: 't1@mbois.com',
    role: 'trainer',
    status: 'active',
  });

  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });
  const result = await service.disableUser({ uid });

  assert.equal(result.success, true);
  const authUser = await mock.auth.getUser(uid);
  assert.equal(authUser.disabled, true);

  const doc = await mock.firestore.collection('users').doc(uid).get();
  assert.equal(doc.data().status, 'inactive');
});

test('AdminService: generateResetLink returns honest link and explicitly confirms email NOT sent', async () => {
  const mock = createMockFirebase();
  const email = 'babangfaril5@gmail.com';
  mock.usersAuth.set('u1', {
    uid: 'u1',
    email,
    displayName: 'Faril',
    disabled: false,
    customClaims: {},
  });

  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });
  const result = await service.generateResetLink({ email });

  assert.ok(result.resetLink);
  assert.equal(result.emailSent, false); // Honest: not email sent!
  assert.match(result.warning, /email TIDAK otomatis dikirim/i);
});

test('AdminService: dryRun mode plans execution without mutating state', async () => {
  const mock = createMockFirebase();
  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  const plan = await service.createUser({
    email: 'dryrun@mbois.com',
    role: 'trainer',
    displayName: 'Dry Run Trainer',
    dryRun: true,
  });

  assert.equal(plan.dryRun, true);
  assert.equal(plan.action, 'create');
  assert.equal(mock.usersAuth.size, 0);
  assert.equal(mock.usersFirestore.size, 0);
});

test('runCli: executes end-to-end CLI commands with injected service double', async () => {
  const { runCli } = require('../admin.cjs');
  const mock = createMockFirebase();
  const service = new AdminService({ auth: mock.auth, firestore: mock.firestore });

  // 1. Help
  const helpResult = await runCli(['--help'], service);
  assert.equal(helpResult.command, 'help');

  // 2. Create trainer
  const createResult = await runCli([
    'create-trainer',
    '--project', 'mbois-gym',
    '--email', 'cli_trainer@mbois.com',
    '--name', 'CLI Trainer',
  ], service);
  assert.equal(createResult.success, true);
  assert.equal(createResult.role, 'trainer');

  // 3. Status
  const statusResult = await runCli([
    'status',
    '--project', 'mbois-gym',
    '--uid', createResult.uid,
  ], service);
  assert.equal(statusResult.auth.exists, true);
  assert.equal(statusResult.firestore.exists, true);
  assert.equal(statusResult.isConsistent, true);
  assert.equal(statusResult.canAccess, true);

  // 4. Reset link (honest, emailSent: false)
  const resetResult = await runCli([
    'reset-link',
    '--project', 'mbois-gym',
    '--email', 'cli_trainer@mbois.com',
  ], service);
  assert.ok(resetResult.resetLink);
  assert.equal(resetResult.emailSent, false);

  // 5. Disable
  const disableResult = await runCli([
    'disable',
    '--project', 'mbois-gym',
    '--uid', createResult.uid,
  ], service);
  assert.equal(disableResult.success, true);
  assert.equal(disableResult.disabled, true);
  assert.equal(disableResult.status, 'inactive');

  // 6. Verify disabled status reflection
  const postDisableStatus = await runCli([
    'status',
    '--project', 'mbois-gym',
    '--uid', createResult.uid,
  ], service);
  assert.equal(postDisableStatus.canAccess, false);
});



