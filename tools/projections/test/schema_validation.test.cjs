const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  buildManagerDashboardProjection,
} = require('../builder.cjs');

describe('Schema Real & FirestoreManagerDashboardRepository Exact Match', () => {
  it('produces documents matching the exact read model expected by FirestoreManagerDashboardRepository', () => {
    const sampleInput = {
      users: [
        {
          id: 'pt-101',
          role: 'trainer',
          status: 'active',
          displayName: 'Coach John',
          specialization: 'Strength & Conditioning',
          photoUrl: 'https://img.example.com/john.jpg',
        },
      ],
      packageSales: [
        {
          id: 'ps-1',
          trainerId: 'pt-101',
          clientId: 'client-501',
          price: 2500000,
          timestamp: '2026-02-15T09:00:00Z',
          status: 'valid',
        },
      ],
      clients: [
        {
          id: 'client-501',
          name: 'Jane Doe',
          assignedTrainerIds: ['pt-101'],
          status: 'active',
          packages: [
            {
              id: 'pkg-1',
              tierName: 'Paket 16 Sesi',
              totalSessions: 16,
              completedCount: 5,
              status: 'active',
            },
          ],
          sessions: [
            {
              id: 'session-1',
              sessionNumber: 1,
              scheduledTime: '2026-02-01T10:00:00Z',
              status: 'completed',
              notes: 'DO NOT LEAK SENSITIVE DIET OR MEDICAL NOTES',
              cancelReason: null,
            },
            {
              id: 'session-2',
              sessionNumber: 2,
              scheduledTime: '2026-02-03T10:00:00Z',
              status: 'completed',
            },
          ],
        },
      ],
    };

    const projection = buildManagerDashboardProjection(sampleInput, {
      year: 2026,
      quarter: 1,
      timezone: 'Asia/Jakarta',
    });

    const writeMap = new Map();
    for (const w of projection.writes) {
      writeMap.set(w.path, w.data);
    }

    // 1. Root Document: manager_dashboard/2026-Q1
    const rootDoc = writeMap.get('manager_dashboard/2026-Q1');
    assert.ok(rootDoc, 'Root document must exist in writes');
    assert.equal(typeof rootDoc.totalActivePt, 'number');
    assert.equal(typeof rootDoc.totalActiveClients, 'number');
    assert.equal(typeof rootDoc.totalPackagesSold, 'number');
    assert.equal(typeof rootDoc.totalSales, 'number');
    assert.ok(Array.isArray(rootDoc.monthlySales));
    assert.equal(rootDoc.monthlySales.length, 3);
    assert.equal(rootDoc.year, 2026);
    assert.equal(rootDoc.quarter, 1);
    assert.equal(rootDoc.timezone, 'Asia/Jakarta');

    // 2. Trainer Document: manager_dashboard/2026-Q1/trainers/pt-101
    const trainerDoc = writeMap.get('manager_dashboard/2026-Q1/trainers/pt-101');
    assert.ok(trainerDoc, 'Trainer document must exist in writes');
    assert.equal(typeof trainerDoc.name, 'string');
    assert.equal(typeof trainerDoc.specialization, 'string');
    assert.equal(typeof trainerDoc.activeClients, 'number');
    assert.equal(typeof trainerDoc.packagesSold, 'number');
    assert.equal(typeof trainerDoc.totalSales, 'number');
    assert.equal(typeof trainerDoc.status, 'string');
    assert.equal(trainerDoc.quarterlyTarget, 5000000.0);
    assert.ok(Array.isArray(trainerDoc.monthlySales));
    assert.equal(trainerDoc.monthlySales.length, 3);
    // In Q1: month 1 (Jan)=0, month 2 (Feb)=2500000, month 3 (Mar)=0
    assert.deepEqual(trainerDoc.monthlySales, [0, 2500000, 0]);

    // 3. Client Document: manager_dashboard/2026-Q1/trainers/pt-101/clients/client-501
    const clientDoc = writeMap.get('manager_dashboard/2026-Q1/trainers/pt-101/clients/client-501');
    assert.ok(clientDoc, 'Client document must exist in writes');
    assert.equal(typeof clientDoc.name, 'string');
    assert.equal(typeof clientDoc.packageName, 'string');
    assert.equal(typeof clientDoc.totalSessions, 'number');
    assert.equal(typeof clientDoc.attendedSessions, 'number');
    assert.equal(typeof clientDoc.remainingSessions, 'number');
    assert.equal(clientDoc.totalSessions, 16);
    assert.equal(clientDoc.attendedSessions, 5);
    assert.equal(clientDoc.remainingSessions, 11);

    // CRITICAL PRIVACY: Client document must NOT contain any disallowed fields
    const clientKeys = Object.keys(clientDoc);
    const forbiddenClientFields = [
      'notes', 'medical', 'evaluations', 'workouts', 'phone',
      'email', 'address', 'assessments', 'signatures', 'diagnostics'
    ];
    for (const forbidden of forbiddenClientFields) {
      assert.ok(!clientKeys.includes(forbidden), `Forbidden field '${forbidden}' found in client projection`);
    }

    // 4. Attendance Documents: manager_dashboard/2026-Q1/trainers/pt-101/clients/client-501/attendance/session-1
    const attDoc1 = writeMap.get('manager_dashboard/2026-Q1/trainers/pt-101/clients/client-501/attendance/session-1');
    assert.ok(attDoc1, 'Attendance document session-1 must exist');
    assert.equal(typeof attDoc1.sessionNumber, 'number');
    assert.equal(attDoc1.sessionNumber, 1);
    assert.ok(attDoc1.scheduledTime instanceof Date || typeof attDoc1.scheduledTime === 'string' || typeof attDoc1.scheduledTime.toDate === 'function');
    assert.equal(typeof attDoc1.status, 'string');
    assert.equal(attDoc1.status, 'completed');

    // CRITICAL PRIVACY: Attendance must NOT leak notes or reasons
    const attKeys = Object.keys(attDoc1);
    const forbiddenAttFields = ['notes', 'cancelReason', 'cancelledBy', 'signature', 'exercises', 'sets'];
    for (const forbidden of forbiddenAttFields) {
      assert.ok(!attKeys.includes(forbidden), `Forbidden field '${forbidden}' found in attendance projection`);
    }
  });
});
