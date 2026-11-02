const { readFileSync } = require('node:fs');
const assert = require('node:assert/strict');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, collection, collectionGroup, getDoc, getDocs, setDoc, updateDoc, deleteDoc, query, where, runTransaction, serverTimestamp } = require('firebase/firestore');

const projectId = 'demo-mbois-gym';
const descendants = ['packages', 'sessions', 'workouts', 'evaluations', 'assessments', 'progress_measurements', 'assignment_history'];
let env;
const dbFor = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const read = (uid, path) => getDoc(doc(dbFor(uid), path));
async function adminUpdate(path, data) {
  await env.withSecurityRulesDisabled(async ctx => updateDoc(doc(ctx.firestore(), path), data));
}

describe('Mbois Gym read-only pilot rules (emulator only)', function () {
  this.timeout(20000);
  before(async () => {
    // Fail closed: never allow this suite to select a live project or endpoint.
    assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):8085$/);
    env = await initializeTestEnvironment({ projectId, firestore: { host: '127.0.0.1', port: 8085, rules: readFileSync('firestore.rules', 'utf8') } });
  });
  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async ctx => {
      const db = ctx.firestore();
      const entries = [];
      for (let i = 1; i <= 4; i++) {
        entries.push([`users/pt${i}`, { role: 'trainer', status: 'active', displayName: `PT ${i}`, phone: '08000' }]);
        entries.push([`clients/c${i}`, { assignedTrainerIds: [`pt${i}`], name: `Client ${i}` }]);
        for (const sub of descendants) entries.push([`clients/c${i}/${sub}/old`, { trainerId: `pt${i}`, note: 'historical' }]);
      }
      entries.push(['users/inactive', { role: 'trainer', status: 'inactive' }], ['users/pending', { role: 'trainer', status: 'pending' }], ['users/admin', { role: 'admin', status: 'active' }], ['clients/shared', { assignedTrainerIds: ['pt1', 'pt2'] }], ['clients/disabled', { assignedTrainerIds: ['inactive', 'pending', 'unknown', 'admin'] }], ['pt_packages/old', { assignedTrainerId: 'pt1' }], ['workout_logs/old', { trainerId: 'pt1' }]);
      await Promise.all(entries.map(([path, data]) => setDoc(doc(db, path), data)));
    });
  });
  after(async () => { if (env) await env.cleanup(); });

  for (let i = 1; i <= 4; i++) {
    it(`PT ${i} reads own client but not any other PT client`, async () => {
      await assertSucceeds(read(`pt${i}`, `clients/c${i}`));
      for (let j = 1; j <= 4; j++) if (j !== i) await assertFails(read(`pt${i}`, `clients/c${j}`));
    });
    it(`PT ${i} query returns exactly assigned clients`, async () => {
      const db = dbFor(`pt${i}`);
      const result = await assertSucceeds(getDocs(query(collection(db, 'clients'), where('assignedTrainerIds', 'array-contains', `pt${i}`))));
      assert.deepEqual(result.docs.map(d => d.id).sort(), (i <= 2 ? [`c${i}`, 'shared'] : [`c${i}`]).sort());
    });
  }
  for (const uid of [null, 'inactive', 'pending', 'unknown', 'admin']) {
    it(`${uid || 'unauthenticated'} cannot read operational data or query`, async () => {
      await assertFails(read(uid, 'clients/disabled'));
      await assertFails(read(uid, 'clients/c1/sessions/old'));
      await assertFails(getDocs(query(collection(dbFor(uid), 'clients'), where('assignedTrainerIds', 'array-contains', uid || 'pt1'))));
    });
  }
  it('unfiltered and another trainer filtered queries are denied', async () => {
    const db = dbFor('pt1');
    await assertFails(getDocs(collection(db, 'clients')));
    await assertFails(getDocs(query(collection(db, 'clients'), where('assignedTrainerIds', 'array-contains', 'pt2'))));
  });
  for (const sub of descendants) {
    it(`${sub}: authoritative parent allows assigned reads/list and denies outsiders`, async () => {
      await assertSucceeds(read('pt1', `clients/c1/${sub}/old`));
      await assertSucceeds(getDocs(collection(dbFor('pt1'), `clients/c1/${sub}`)));
      await assertFails(read('pt2', `clients/c1/${sub}/old`));
      await assertFails(getDocs(collection(dbFor('pt2'), `clients/c1/${sub}`)));
    });
    it(`${sub}: reassignment revokes former PT despite historical trainerId`, async () => {
      await adminUpdate('clients/c1', { assignedTrainerIds: ['pt2'] });
      await assertFails(read('pt1', 'clients/c1'));
      await assertFails(read('pt1', `clients/c1/${sub}/old`));
      await assertSucceeds(read('pt2', `clients/c1/${sub}/old`));
    });
  }
  it('revoking active status immediately removes access', async () => {
    const db = dbFor('pt1');
    await assertSucceeds(getDoc(doc(db, 'clients/c1')));
    await adminUpdate('users/pt1', { status: 'inactive' });
    await assertFails(getDoc(doc(db, 'clients/c1')));
    await assertFails(getDoc(doc(db, 'clients/c1/sessions/old')));
  });
  it('own profile readable, other profile/list and unauthenticated access denied', async () => {
    await assertSucceeds(read('pt1', 'users/pt1'));
    await assertSucceeds(read('inactive', 'users/inactive'));
    await assertFails(read('pt1', 'users/pt2'));
    await assertFails(read(null, 'users/pt1'));
    await assertFails(getDocs(collection(dbFor('pt1'), 'users')));
  });
  it('self displayName and phone edits allowed without changing authorization', async () => {
    await assertSucceeds(updateDoc(doc(dbFor('pt1'), 'users/pt1'), {
      displayName: 'Edited',
      phone: '08123',
      heightCm: 175,
      weightKg: 70,
      specialization: 'Hypertrophy',
      experienceYears: 5,
      certifications: 'APKI Certified',
      bio: 'Coach fitness',
      photoUrl: 'https://example.com/avatar.jpg',
    }));
  });
  for (const [uid, data] of [['pt1', { role: 'admin' }], ['pending', { status: 'active' }], ['inactive', { status: 'active' }], ['pt1', { assignedTrainerIds: ['pt1'] }]]) {
    it(`${uid} cannot escalate with ${Object.keys(data)[0]}`, async () => {
      await assertFails(updateDoc(doc(dbFor(uid), `users/${uid}`), data));
    });
  }
  it('profiles cannot be self-provisioned, deleted, or modified by another user', async () => {
    await assertFails(setDoc(doc(dbFor('unknown'), 'users/unknown'), { role: 'trainer', status: 'active' }));
    await assertFails(deleteDoc(doc(dbFor('pt1'), 'users/pt1')));
    await assertFails(updateDoc(doc(dbFor('pt1'), 'users/pt2'), { displayName: 'Forged' }));
  });
  it('assignment tampering forbidden', async () => {
    await assertFails(updateDoc(doc(dbFor('pt1'), 'clients/c2'), { assignedTrainerIds: ['pt1'] }));
    await assertFails(updateDoc(doc(dbFor('pt1'), 'clients/c1'), { assignedTrainerIds: ['pt1', 'pt2'] }));
  });
  it('active trainer can create client assigned to self, but not only to others', async () => {
    await assertSucceeds(setDoc(doc(dbFor('pt1'), 'clients/c_new_1'), { name: 'New Client 1', assignedTrainerIds: ['pt1'] }));
    await assertFails(setDoc(doc(dbFor('pt1'), 'clients/c_new_2'), { name: 'Forged Assignment', assignedTrainerIds: ['pt2'] }));
    await assertFails(setDoc(doc(dbFor('inactive'), 'clients/c_new_3'), { name: 'Inactive Creator', assignedTrainerIds: ['inactive'] }));
  });
  it('assigned trainer can update client fields, but outsiders cannot', async () => {
    await assertSucceeds(updateDoc(doc(dbFor('pt1'), 'clients/c1'), { name: 'Updated Client 1', age: 30 }));
    await assertFails(updateDoc(doc(dbFor('pt2'), 'clients/c1'), { name: 'Intruder Update' }));
    await assertFails(deleteDoc(doc(dbFor('pt2'), 'clients/c1')));
  });
  it('assigned trainer can schedule, reschedule, and cancel a session but cannot complete it without trusted authority', async () => {
    const path = 'clients/c1/sessions/new_item';
    await assertSucceeds(setDoc(doc(dbFor('pt1'), path), { packageIntId: 1, sessionNumber: 1, scheduledTime: new Date(), status: 'scheduled' }));
    await assertSucceeds(updateDoc(doc(dbFor('pt1'), path), { scheduledTime: new Date(Date.now() + 86400000), notes: 'Rescheduled session' }));
    await assertSucceeds(updateDoc(doc(dbFor('pt1'), path), { status: 'cancelled' }));
    await assertFails(updateDoc(doc(dbFor('pt1'), path), { status: 'completed' }));
    await assertFails(setDoc(doc(dbFor('pt2'), 'clients/c1/sessions/intruder'), { packageIntId: 1, sessionNumber: 1, scheduledTime: new Date(), status: 'scheduled' }));
  });
  it('trainer can create valid package; completedCount and destructive operations fail closed', async () => {
    const path = 'clients/c1/packages/new_item';
    await assertSucceeds(setDoc(doc(dbFor('pt1'), path), { totalSessions: 12, completedCount: 0, status: 'active' }));
    await assertFails(updateDoc(doc(dbFor('pt1'), path), { completedCount: 1 }));
    await assertFails(deleteDoc(doc(dbFor('pt1'), path)));
  });
  for (const sub of ['workouts', 'evaluations', 'assessments', 'progress_measurements']) {
    it(`${sub}: assigned trainer writes note only; outsider and malformed payload denied`, async () => {
      const path = `clients/c1/${sub}/new_item`;
      await assertSucceeds(setDoc(doc(dbFor('pt1'), path), { note: 'Created by PT1', createdAt: new Date() }));
      await assertSucceeds(updateDoc(doc(dbFor('pt1'), path), { note: 'Edited' }));
      await assertFails(setDoc(doc(dbFor('pt1'), `clients/c1/${sub}/bad`), { role: 'manager' }));
      await assertFails(setDoc(doc(dbFor('pt2'), `clients/c1/${sub}/intruder`), { note: 'Intrusion' }));
    });
  }
  it('assignment history is manager-only and immutable to trainers', async () => {
    await assertFails(setDoc(doc(dbFor('pt1'), 'clients/c1/assignment_history/new'), { fromTrainerId: 'pt1', toTrainerId: 'pt2' }));
  });
  for (const path of ['pt_packages/old', 'workout_logs/old', 'exercise_catalog/old', 'migration_imports/old']) {
    it(`${path}: un-namespaced root operational writes strictly denied`, async () => {
      const db = dbFor('pt1');
      await assertFails(setDoc(doc(db, `${path}-new`), { assignedTrainerId: 'pt1', trainerId: 'pt1' }));
      await assertFails(updateDoc(doc(db, path), { note: 'tampered' }));
      await assertFails(deleteDoc(doc(db, path)));
    });
  }
  it('manager reads trainer profiles and operational clients; trainer cannot read others', async () => {
    await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' }));
    await assertSucceeds(read('manager', 'users/pt1'));
    await assertSucceeds(getDocs(collection(dbFor('manager'), 'users')));
    await assertFails(read('manager', 'clients/c2'));
    await assertFails(read('manager', 'clients/c2/sessions/old'));
    await assertFails(read('pt1', 'users/pt2'));
    await assertFails(read('pt1', 'clients/c2'));
  });
  it('manager edits trainer status but neither role nor trainer authorization fields are self-editable', async () => {
    await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' }));
    await assertFails(updateDoc(doc(dbFor('pt1'), 'users/pt1'), { status: 'inactive' }));
    await assertSucceeds(updateDoc(doc(dbFor('manager'), 'users/pt1'), { status: 'inactive' }));
    await assertFails(updateDoc(doc(dbFor('pt1'), 'users/pt1'), { status: 'active' }));
    await assertFails(updateDoc(doc(dbFor('manager'), 'users/pt1'), { role: 'manager' }));
  });
  it('trainer client creation requires exactly self; manager assigns an active trainer', async () => {
    await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' }));
    await assertFails(setDoc(doc(dbFor('pt1'), 'clients/multi'), { name: 'bad', assignedTrainerIds: ['pt1', 'pt2'] }));
    await assertSucceeds(setDoc(doc(dbFor('manager'), 'clients/managed'), { name: 'managed', assignedTrainerIds: ['pt1'] }));
    await assertFails(setDoc(doc(dbFor('manager'), 'clients/invalid'), { name: 'invalid', assignedTrainerIds: ['inactive'] }));
    await assertSucceeds(setDoc(doc(dbFor('pt1'), 'clients/own_single'), { name: 'self', assignedTrainerIds: ['pt1'] }));
    await assertFails(setDoc(doc(dbFor('pt1'), 'clients/own_plus'), { name: 'selfplus', assignedTrainerIds: ['pt1', 'pt2'] }));
  });
  it('manager cannot get/list sensitive clients or descendants, including collection groups', async () => {
    await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' }));
    await assertFails(getDocs(collection(dbFor('manager'), 'clients')));
    for (const sub of [...descendants, 'signatures']) {
      await assertFails(read('manager', `clients/c2/${sub}/old`));
      await assertFails(getDocs(collection(dbFor('manager'), `clients/c2/${sub}`)));
      await assertFails(getDocs(collectionGroup(dbFor('manager'), sub)));
    }
  });
  it('trusted projection is readable only by active manager and immutable from client SDKs', async () => {
    const paths = [
      'manager_dashboard/2026-Q1',
      'manager_dashboard/2026-Q1/trainers/pt1',
      'manager_dashboard/2026-Q1/trainers/pt1/clients/c1',
      'manager_dashboard/2026-Q1/trainers/pt1/clients/c1/attendance/s1',
    ];
    await env.withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' });
      for (const path of paths) await setDoc(doc(ctx.firestore(), path), { name: 'Operational projection' });
    });
    for (const path of paths) {
      await assertSucceeds(read('manager', path));
      await assertSucceeds(getDocs(collection(dbFor('manager'), path.substring(0, path.lastIndexOf('/')))));
      for (const uid of [null, 'pt1', 'inactive', 'pending', 'unknown']) await assertFails(read(uid, path));
      for (const uid of ['manager', 'pt1']) {
        await assertFails(setDoc(doc(dbFor(uid), path + '-new'), { name: 'Forged' }));
        await assertFails(updateDoc(doc(dbFor(uid), path), { name: 'Forged' }));
        await assertFails(deleteDoc(doc(dbFor(uid), path)));
      }
    }
    await assertFails(read('manager', paths[3] + '/secret/data'));
    await adminUpdate('users/manager', { status: 'inactive' });
    for (const path of paths) await assertFails(read('manager', path));
  });
  it('manager manages catalog and assignment; trainer cannot alter either', async () => {
    await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' }));
    await assertSucceeds(setDoc(doc(dbFor('manager'), 'exercise_catalog/squat'), { name: 'Squat' }));
    await assertFails(setDoc(doc(dbFor('pt1'), 'exercise_catalog/forged'), { name: 'Forged' }));
    await assertSucceeds(updateDoc(doc(dbFor('manager'), 'clients/c1'), { assignedTrainerIds: ['pt2'] }));
    await assertFails(read('pt1', 'clients/c1'));
    await assertFails(updateDoc(doc(dbFor('manager'), 'clients/c1'), { assignedTrainerIds: ['unknown'] }));
    await assertSucceeds(setDoc(doc(dbFor('manager'), 'clients/c1/assignment_history/h1'), { fromTrainerId: 'pt1', toTrainerId: 'pt2' }));
    await assertFails(updateDoc(doc(dbFor('manager'), 'clients/c1/assignment_history/h1'), { toTrainerId: 'pt1' }));
  });
  it('package and session schemas deny quota tampering and client-side completion', async () => {
    await assertFails(setDoc(doc(dbFor('pt1'), 'clients/c1/packages/new'), { totalSessions: 0, completedCount: 0, status: 'active' }));
    await assertFails(updateDoc(doc(dbFor('pt1'), 'clients/c1/packages/old'), { completedCount: 1 }));
    await assertFails(updateDoc(doc(dbFor('pt1'), 'clients/c1/sessions/old'), { status: 'completed' }));
    await assertFails(setDoc(doc(dbFor('pt1'), 'clients/c1/sessions/bad'), { status: 'completed', sessionNumber: 1 }));
  });
  it('package_sales allows active manager read all, trainer read own and create own; denies update/delete and tampering', async () => {
    await env.withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' });
      await setDoc(doc(ctx.firestore(), 'package_sales/s1'), {
        clientId: 'c1',
        clientName: 'Budi',
        trainerId: 'pt1',
        trainerName: 'Coach 1',
        tierName: 'Paket 10 Sesi',
        sessionsCount: 10,
        durationWeeks: 4,
        price: 1000000,
        status: 'valid',
      });
    });
    await assertSucceeds(read('manager', 'package_sales/s1'));
    await assertSucceeds(getDocs(collection(dbFor('manager'), 'package_sales')));
    await assertSucceeds(read('pt1', 'package_sales/s1'));
    await assertFails(read('pt2', 'package_sales/s1'));
    await assertSucceeds(setDoc(doc(dbFor('pt1'), 'package_sales/s2'), {
      clientId: 'c1',
      clientName: 'Budi',
      trainerId: 'pt1',
      trainerName: 'Coach 1',
      tierName: 'Paket 4 Sesi',
      sessionsCount: 4,
      durationWeeks: 4,
      price: 500000,
      status: 'valid',
    }));
    await assertFails(setDoc(doc(dbFor('pt1'), 'package_sales/s3'), {
      clientId: 'c1',
      clientName: 'Budi',
      trainerId: 'pt2',
      trainerName: 'Coach 2',
      tierName: 'Paket 4 Sesi',
      sessionsCount: 4,
      durationWeeks: 4,
      price: 500000,
      status: 'valid',
    }));
    await assertFails(updateDoc(doc(dbFor('manager'), 'package_sales/s1'), { price: 2000000 }));
    await assertFails(deleteDoc(doc(dbFor('pt1'), 'package_sales/s1')));
  });
  it('legacy root resources, unknown paths, deeper nesting and collection groups denied', async () => {
    for (const path of ['pt_packages/old', 'workout_logs/old', 'unknown/doc', 'clients/c1/sessions/old/secret/data']) await assertFails(read('pt1', path));
    await assertFails(getDocs(collectionGroup(dbFor('pt1'), 'sessions')));
  });

  describe('Atomic completion transaction and getAfter coupled rules (real emulator)', () => {
    const validClientStrokes = [
      { points: [{ x: 10.5, y: 20.5 }, { x: 15.0, y: 25.0 }] }
    ];
    const validCoachStrokes = [
      { points: [{ x: 30.0, y: 40.0 }, { x: 35.0, y: 45.0 }] }
    ];

    it('atomic transaction completes scheduled session and increments quota with verified signatures', async () => {
      const db = dbFor('pt1');
      const pkgRef = doc(db, 'clients/c1/packages/pkg_tx_1');
      const sessionRef = doc(db, 'clients/c1/sessions/s_tx_1');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_tx_1'), {
          totalSessions: 4,
          completedCount: 0,
          status: 'active',
        });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_tx_1'), {
          packageIntId: 1,
          packageDocId: 'pkg_tx_1',
          sessionNumber: 1,
          scheduledTime: new Date(),
          status: 'scheduled',
        });
      });

      await assertSucceeds(runTransaction(db, async (tx) => {
        const pSnap = await tx.get(pkgRef);
        const sSnap = await tx.get(sessionRef);
        assert.equal(pSnap.data().completedCount, 0);
        assert.equal(sSnap.data().status, 'scheduled');

        tx.update(pkgRef, {
          completedCount: 1,
          lastCompletedSessionId: 's_tx_1',
          updatedAt: serverTimestamp(),
        });
        tx.update(sessionRef, {
          status: 'completed',
          completedAt: serverTimestamp(),
          packageDocId: 'pkg_tx_1',
          notes: 'Sesi 1 berhasil',
          clientSignatureStatus: 'verified',
          coachSignatureStatus: 'verified',
          clientSignatureStrokes: validClientStrokes,
          coachSignatureStrokes: validCoachStrokes,
          clientName: 'Client 1',
          trainerName: 'PT 1',
        });
      }));

      const pAfter = await read('pt1', 'clients/c1/packages/pkg_tx_1');
      assert.equal(pAfter.data().completedCount, 1);
      assert.equal(pAfter.data().status, 'active');

      const sAfter = await read('pt1', 'clients/c1/sessions/s_tx_1');
      assert.equal(sAfter.data().status, 'completed');
      assert.equal(sAfter.data().clientSignatureStatus, 'verified');
    });

    it('completing final session atomically closes package status to closed', async () => {
      const db = dbFor('pt1');
      const pkgRef = doc(db, 'clients/c1/packages/pkg_last');
      const sessionRef = doc(db, 'clients/c1/sessions/s_last');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_last'), {
          totalSessions: 2,
          completedCount: 1,
          status: 'active',
        });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_last'), {
          packageIntId: 2,
          packageDocId: 'pkg_last',
          sessionNumber: 2,
          scheduledTime: new Date(),
          status: 'scheduled',
        });
      });

      await assertSucceeds(runTransaction(db, async (tx) => {
        tx.update(pkgRef, {
          completedCount: 2,
          status: 'closed',
          lastCompletedSessionId: 's_last',
          closedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        tx.update(sessionRef, {
          status: 'completed',
          completedAt: serverTimestamp(),
          packageDocId: 'pkg_last',
          notes: 'Sesi penutup paket',
          clientSignatureStatus: 'verified',
          coachSignatureStatus: 'verified',
          clientSignatureStrokes: validClientStrokes,
          coachSignatureStrokes: validCoachStrokes,
        });
      }));

      const pAfter = await read('pt1', 'clients/c1/packages/pkg_last');
      assert.equal(pAfter.data().completedCount, 2);
      assert.equal(pAfter.data().status, 'closed');
    });

    it('counter forgery denied: cannot increment package quota without completing session', async () => {
      const db = dbFor('pt1');
      const pkgRef = doc(db, 'clients/c1/packages/pkg_forge');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_forge'), {
          totalSessions: 4,
          completedCount: 0,
          status: 'active',
        });
      });

      // Attempt single update without coupled session
      await assertFails(updateDoc(pkgRef, {
        completedCount: 1,
        lastCompletedSessionId: 'non_existent_session',
      }));
    });

    it('session completion forgery denied: cannot complete session without coupled quota increment', async () => {
      const db = dbFor('pt1');
      const sessionRef = doc(db, 'clients/c1/sessions/s_forge');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_forge_2'), {
          totalSessions: 4,
          completedCount: 0,
          status: 'active',
        });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_forge'), {
          packageIntId: 1,
          packageDocId: 'pkg_forge_2',
          sessionNumber: 1,
          scheduledTime: new Date(),
          status: 'scheduled',
        });
      });

      // Attempt single update without coupled package
      await assertFails(updateDoc(sessionRef, {
        status: 'completed',
        completedAt: new Date(),
        packageDocId: 'pkg_forge_2',
        clientSignatureStatus: 'verified',
        coachSignatureStatus: 'verified',
        clientSignatureStrokes: validClientStrokes,
        coachSignatureStrokes: validCoachStrokes,
      }));
    });

    it('double debit denied: completing an already completed session fails', async () => {
      const db = dbFor('pt1');
      const pkgRef = doc(db, 'clients/c1/packages/pkg_double');
      const sessionRef = doc(db, 'clients/c1/sessions/s_double');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_double'), {
          totalSessions: 4,
          completedCount: 1,
          status: 'active',
        });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_double'), {
          packageIntId: 1,
          packageDocId: 'pkg_double',
          sessionNumber: 1,
          scheduledTime: new Date(),
          status: 'completed',
          completedAt: new Date(),
        });
      });

      await assertFails(runTransaction(db, async (tx) => {
        tx.update(pkgRef, {
          completedCount: 2,
          lastCompletedSessionId: 's_double',
        });
        tx.update(sessionRef, {
          status: 'completed',
          completedAt: serverTimestamp(),
          packageDocId: 'pkg_double',
          clientSignatureStatus: 'verified',
          coachSignatureStatus: 'verified',
          clientSignatureStrokes: validClientStrokes,
          coachSignatureStrokes: validCoachStrokes,
        });
      }));
    });

    it('quota exhaustion protected: cannot complete session if package quota reached', async () => {
      const db = dbFor('pt1');
      const pkgRef = doc(db, 'clients/c1/packages/pkg_exhausted');
      const sessionRef = doc(db, 'clients/c1/sessions/s_extra');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_exhausted'), {
          totalSessions: 4,
          completedCount: 4,
          status: 'closed',
        });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_extra'), {
          packageIntId: 1,
          packageDocId: 'pkg_exhausted',
          sessionNumber: 5,
          scheduledTime: new Date(),
          status: 'scheduled',
        });
      });

      await assertFails(runTransaction(db, async (tx) => {
        tx.update(pkgRef, {
          completedCount: 5,
          lastCompletedSessionId: 's_extra',
        });
        tx.update(sessionRef, {
          status: 'completed',
          completedAt: serverTimestamp(),
          packageDocId: 'pkg_exhausted',
          clientSignatureStatus: 'verified',
          coachSignatureStatus: 'verified',
          clientSignatureStrokes: validClientStrokes,
          coachSignatureStrokes: validCoachStrokes,
        });
      }));
    });

    it('unauthorized PT denied: non-assigned PT cannot complete session', async () => {
      const db = dbFor('pt2'); // PT2 is not assigned to c1
      const pkgRef = doc(db, 'clients/c1/packages/pkg_tx_unauth');
      const sessionRef = doc(db, 'clients/c1/sessions/s_tx_unauth');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_tx_unauth'), {
          totalSessions: 4,
          completedCount: 0,
          status: 'active',
        });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_tx_unauth'), {
          packageIntId: 1,
          packageDocId: 'pkg_tx_unauth',
          sessionNumber: 1,
          scheduledTime: new Date(),
          status: 'scheduled',
        });
      });

      await assertFails(runTransaction(db, async (tx) => {
        tx.update(pkgRef, {
          completedCount: 1,
          lastCompletedSessionId: 's_tx_unauth',
        });
        tx.update(sessionRef, {
          status: 'completed',
          completedAt: serverTimestamp(),
          packageDocId: 'pkg_tx_unauth',
          clientSignatureStatus: 'verified',
          coachSignatureStatus: 'verified',
          clientSignatureStrokes: validClientStrokes,
          coachSignatureStrokes: validCoachStrokes,
        });
      }));
    });

    it('malformed signature rejected: empty strokes or invalid structure denied', async () => {
      const db = dbFor('pt1');
      const pkgRef = doc(db, 'clients/c1/packages/pkg_bad_sig');
      const sessionRef = doc(db, 'clients/c1/sessions/s_bad_sig');

      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'clients/c1/packages/pkg_bad_sig'), {
          totalSessions: 4,
          completedCount: 0,
          status: 'active',
        });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_bad_sig'), {
          packageIntId: 1,
          packageDocId: 'pkg_bad_sig',
          sessionNumber: 1,
          scheduledTime: new Date(),
          status: 'scheduled',
        });
      });

      await assertFails(runTransaction(db, async (tx) => {
        tx.update(pkgRef, {
          completedCount: 1,
          lastCompletedSessionId: 's_bad_sig',
        });
        tx.update(sessionRef, {
          status: 'completed',
          completedAt: serverTimestamp(),
          packageDocId: 'pkg_bad_sig',
          clientSignatureStatus: 'verified',
          coachSignatureStatus: 'verified',
          clientSignatureStrokes: [], // Empty strokes should be rejected!
          coachSignatureStrokes: [],
        });
      }));
    });

    it('privacy retention: active manager cannot read completed session or signature data', async () => {
      await env.withSecurityRulesDisabled(async ctx => {
        await setDoc(doc(ctx.firestore(), 'users/manager'), { role: 'manager', status: 'active' });
        await setDoc(doc(ctx.firestore(), 'clients/c1/sessions/s_priv'), {
          status: 'completed',
          clientSignatureStrokes: validClientStrokes,
        });
      });

      await assertFails(read('manager', 'clients/c1/sessions/s_priv'));
      await assertFails(getDocs(collection(dbFor('manager'), 'clients/c1/sessions')));
    });
  });
});
