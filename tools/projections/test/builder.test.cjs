const { test, describe, it } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

// We will import the builder once created
const {
  parseArgs,
  getQuarterInfo,
  parseDateInTimezone,
  deduplicateSales,
  buildManagerDashboardProjection,
  ALLOWED_PROJECT,
} = require('../builder.cjs');

describe('CLI Argument Parsing & Validation', () => {
  it('defaults to dry-run when --apply is omitted', () => {
    const args = parseArgs(['--project', 'mbois-gym', '--year', '2026', '--quarter', '1']);
    assert.equal(args.dryRun, true);
    assert.equal(args.apply, false);
    assert.equal(args.project, 'mbois-gym');
    assert.equal(args.year, 2026);
    assert.equal(args.quarter, 1);
    assert.equal(args.timezone, 'Asia/Jakarta');
  });

  it('sets apply to true and dryRun to false when --apply is passed', () => {
    const args = parseArgs(['--project', 'mbois-gym', '--year', '2026', '--quarter', '2', '--apply']);
    assert.equal(args.dryRun, false);
    assert.equal(args.apply, true);
    assert.equal(args.quarter, 2);
  });

  it('validates allowed project', () => {
    assert.throws(() => parseArgs(['--project', 'other-gym']), /Project 'other-gym' tidak diizinkan/);
    assert.throws(() => parseArgs([]), /--project/);
  });

  it('validates quarter range 1-4', () => {
    assert.throws(() => parseArgs(['--project', 'mbois-gym', '--quarter', '0']), /Kuartal harus bernilai 1-4/);
    assert.throws(() => parseArgs(['--project', 'mbois-gym', '--quarter', '5']), /Kuartal harus bernilai 1-4/);
  });
});

describe('Timezone & Quarter Boundaries', () => {
  it('correctly maps quarter months for Q1-Q4', () => {
    assert.deepEqual(getQuarterInfo(2026, 1).months, [1, 2, 3]);
    assert.deepEqual(getQuarterInfo(2026, 2).months, [4, 5, 6]);
    assert.deepEqual(getQuarterInfo(2026, 3).months, [7, 8, 9]);
    assert.deepEqual(getQuarterInfo(2026, 4).months, [10, 11, 12]);
  });

  it('handles timezone transition across quarter boundaries correctly in Asia/Jakarta', () => {
    // 2026-03-31 18:30 UTC is 2026-04-01 01:30 in Asia/Jakarta (WIB) -> Q2, month 4
    const dateUtcBoundary = new Date('2026-03-31T18:30:00Z');
    const parsedWib = parseDateInTimezone(dateUtcBoundary, 'Asia/Jakarta');
    assert.equal(parsedWib.year, 2026);
    assert.equal(parsedWib.month, 4); // April -> Q2 in WIB
    assert.equal(parsedWib.quarter, 2);

    // In UTC, it would be March (month 3, Q1)
    const parsedUtc = parseDateInTimezone(dateUtcBoundary, 'UTC');
    assert.equal(parsedUtc.month, 3);
    assert.equal(parsedUtc.quarter, 1);
  });
});

describe('Package Sales Deduplication & Validity Filtering', () => {
  it('deduplicates sales by ID and excludes invalid sales (cancelled/refunded/void)', () => {
    const rawSales = [
      { id: 'sale-1', trainerId: 'pt-1', price: 1000000, timestamp: '2026-01-15T10:00:00Z', status: 'valid' },
      { id: 'sale-1', trainerId: 'pt-1', price: 1000000, timestamp: '2026-01-15T10:00:00Z', status: 'valid' }, // duplicate
      { id: 'sale-2', trainerId: 'pt-1', price: 500000, timestamp: '2026-02-10T10:00:00Z', status: 'refunded' }, // invalid
      { id: 'sale-3', trainerId: 'pt-1', price: 1600000, timestamp: '2026-03-05T10:00:00Z', status: 'cancelled' }, // invalid
      { id: 'sale-4', trainerId: 'pt-1', price: 2000000, timestamp: '2026-03-20T10:00:00Z', status: 'valid' },
    ];

    const deduped = deduplicateSales(rawSales);
    assert.equal(deduped.length, 2);
    assert.deepEqual(deduped.map(s => s.id), ['sale-1', 'sale-4']);
  });
});

describe('Manager Dashboard Projection Computation', () => {
  it('computes exact individual 5M target, monthly sales distribution, includes all trainers even with 0 sales', () => {
    const sourceData = {
      users: [
        {
          id: 'pt-active-1',
          role: 'trainer',
          status: 'active',
          displayName: 'Coach Budi',
          specialization: 'Hypertrophy',
          photoUrl: 'https://example.com/budi.jpg',
        },
        {
          id: 'pt-zero-sales',
          role: 'trainer',
          status: 'active',
          displayName: 'Coach Baru',
          specialization: 'Fat Loss',
        },
        {
          id: 'pt-inactive',
          role: 'trainer',
          status: 'inactive',
          displayName: 'Coach Nonaktif',
          specialization: 'Yoga',
        },
        {
          id: 'mgr-1',
          role: 'manager',
          status: 'active',
          displayName: 'Manager Rudi',
        },
      ],
      packageSales: [
        // Budi sales in Q1 2026: Jan (1M), Feb (2M), Mar (2.1M) -> Total 5.1M (Target 5M achieved)
        { id: 's1', trainerId: 'pt-active-1', clientId: 'c1', price: 1000000, timestamp: '2026-01-10T10:00:00Z', status: 'valid' },
        { id: 's2', trainerId: 'pt-active-1', clientId: 'c1', price: 2000000, timestamp: '2026-02-14T10:00:00Z', status: 'valid' },
        { id: 's3', trainerId: 'pt-active-1', clientId: 'c2', price: 2100000, timestamp: '2026-03-20T10:00:00Z', status: 'valid' },
        // Sale outside Q1 (in Q2): should not count towards Q1
        { id: 's4', trainerId: 'pt-active-1', clientId: 'c1', price: 1000000, timestamp: '2026-04-05T10:00:00Z', status: 'valid' },
      ],
      clients: [
        {
          id: 'c1',
          name: 'Klien Satu',
          assignedTrainerIds: ['pt-active-1'],
          status: 'active',
          packages: [
            { id: 'pkg-1', tierName: 'Paket 10 Sesi', totalSessions: 10, completedCount: 1, status: 'active' },
          ],
          sessions: [
            {
              id: 'sess-1',
              sessionNumber: 1,
              scheduledTime: '2026-01-12T10:00:00Z',
              status: 'completed',
              notes: 'SECRET MEDICAL INFO: Asthma and knee injury', // Sensitive!
              cancelReason: null,
            },
            {
              id: 'sess-2',
              sessionNumber: 2,
              scheduledTime: '2026-01-15T10:00:00Z',
              status: 'scheduled',
              notes: 'Private diet notes', // Sensitive!
            },
          ],
        },
        {
          id: 'c2',
          name: 'Klien Dua',
          assignedTrainerIds: ['pt-active-1'],
          status: 'active',
          packages: [
            { id: 'pkg-2', tierName: 'Paket 4 Sesi', totalSessions: 4, completedCount: 0, status: 'active' },
          ],
          sessions: [],
        },
        {
          id: 'c-unassigned',
          name: 'Klien Bebas',
          assignedTrainerIds: [],
          status: 'active',
        },
      ],
    };

    const projection = buildManagerDashboardProjection(sourceData, {
      year: 2026,
      quarter: 1,
      timezone: 'Asia/Jakarta',
    });

    // 1. Root Document verification
    assert.equal(projection.periodId, '2026-Q1');
    assert.equal(projection.dashboard.totalActivePt, 2); // pt-active-1 and pt-zero-sales (pt-inactive is inactive, mgr-1 is manager)
    assert.equal(projection.dashboard.totalActiveClients, 2); // c1 and c2
    assert.equal(projection.dashboard.totalPackagesSold, 3);
    assert.equal(projection.dashboard.totalSales, 5100000);
    assert.deepEqual(projection.dashboard.monthlySales, [1000000, 2000000, 2100000]);

    // 2. All trainers included (3 trainers total, manager excluded)
    assert.equal(projection.trainers.length, 3);

    const pt1 = projection.trainers.find(t => t.id === 'pt-active-1');
    assert.ok(pt1);
    assert.equal(pt1.doc.name, 'Coach Budi');
    assert.equal(pt1.doc.specialization, 'Hypertrophy');
    assert.equal(pt1.doc.photoUrl, 'https://example.com/budi.jpg');
    assert.equal(pt1.doc.status, 'active');
    assert.equal(pt1.doc.quarterlyTarget, 5000000); // Individual 5M target
    assert.equal(pt1.doc.totalSales, 5100000);
    assert.equal(pt1.doc.packagesSold, 3);
    assert.equal(pt1.doc.activeClients, 2);
    assert.deepEqual(pt1.doc.monthlySales, [1000000, 2000000, 2100000]);

    // Check trainer with 0 sales
    const ptZero = projection.trainers.find(t => t.id === 'pt-zero-sales');
    assert.ok(ptZero);
    assert.equal(ptZero.doc.name, 'Coach Baru');
    assert.equal(ptZero.doc.quarterlyTarget, 5000000);
    assert.equal(ptZero.doc.totalSales, 0);
    assert.equal(ptZero.doc.packagesSold, 0);
    assert.equal(ptZero.doc.activeClients, 0);
    assert.deepEqual(ptZero.doc.monthlySales, [0, 0, 0]);

    // Check inactive trainer
    const ptInactive = projection.trainers.find(t => t.id === 'pt-inactive');
    assert.ok(ptInactive);
    assert.equal(ptInactive.doc.status, 'inactive');
    assert.equal(ptInactive.doc.totalSales, 0);

    // 3. Strict Allowlist & Privacy: No sensitive info in clients and attendance
    assert.equal(pt1.clients.length, 2);
    const client1 = pt1.clients.find(c => c.id === 'c1');
    assert.ok(client1);
    assert.equal(client1.doc.name, 'Klien Satu');
    assert.equal(client1.doc.packageName, 'Paket 10 Sesi');
    assert.equal(client1.doc.totalSessions, 10);
    assert.equal(client1.doc.attendedSessions, 1);
    assert.equal(client1.doc.remainingSessions, 9);

    // Verify client doc has NO sensitive fields
    const clientKeys = Object.keys(client1.doc);
    assert.ok(!clientKeys.includes('notes'));
    assert.ok(!clientKeys.includes('medicalHistory'));
    assert.ok(!clientKeys.includes('evaluations'));
    assert.ok(!clientKeys.includes('workouts'));
    assert.ok(!clientKeys.includes('phone'));
    assert.ok(!clientKeys.includes('assessments'));

    // Verify attendance records in projection
    assert.equal(client1.attendance.length, 2);
    const sess1 = client1.attendance.find(a => a.id === 'sess-1');
    assert.ok(sess1);
    assert.equal(sess1.doc.sessionNumber, 1);
    assert.equal(sess1.doc.status, 'completed');

    // Attendance record MUST NOT leak notes or reasons
    const attendanceKeys = Object.keys(sess1.doc);
    assert.ok(!attendanceKeys.includes('notes'));
    assert.ok(!attendanceKeys.includes('cancelReason'));
    assert.ok(!attendanceKeys.includes('signature'));

    // 4. Stable document paths for batch writes
    const expectedPaths = [
      'manager_dashboard/2026-Q1',
      'manager_dashboard/2026-Q1/trainers/pt-active-1',
      'manager_dashboard/2026-Q1/trainers/pt-active-1/clients/c1',
      'manager_dashboard/2026-Q1/trainers/pt-active-1/clients/c1/attendance/sess-1',
      'manager_dashboard/2026-Q1/trainers/pt-active-1/clients/c1/attendance/sess-2',
      'manager_dashboard/2026-Q1/trainers/pt-active-1/clients/c2',
      'manager_dashboard/2026-Q1/trainers/pt-zero-sales',
      'manager_dashboard/2026-Q1/trainers/pt-inactive',
    ];

    for (const expectedPath of expectedPaths) {
      assert.ok(
        projection.writes.some(w => w.path === expectedPath),
        `Path ${expectedPath} should be included in projection writes`
      );
    }
  });

  test('excludes cancelled client registrations and their sales from operational metrics', () => {
    const sourceData = {
      users: [
        { id: 'pt-1', displayName: 'Coach Faril', role: 'trainer', status: 'active' },
        { id: 'pt-2', displayName: 'PT', name: 'Coach Akbar', role: 'trainer', status: 'active' },
      ],
      packageSales: [
        { id: 'sale-valid', trainerId: 'pt-1', clientId: 'c-active', price: 1000000, timestamp: '2026-10-15T10:00:00Z', status: 'valid' },
        { id: 'sale-cancelled-client', trainerId: 'pt-1', clientId: 'c-cancelled', price: 500000, timestamp: '2026-10-16T10:00:00Z', status: 'valid' },
        { id: 'sale-voided', trainerId: 'pt-2', clientId: 'c-active', price: 500000, timestamp: '2026-10-17T10:00:00Z', status: 'cancelled' },
      ],
      clients: [
        {
          id: 'c-active',
          name: 'Rian Pratama',
          assignedTrainerIds: ['pt-1'],
          status: 'active',
          packages: [
            { id: 'pkg-active', tierName: 'Paket 10 Sesi', totalSessions: 10, completedCount: 2, status: 'active' },
          ],
          sessions: [],
        },
        {
          id: 'c-cancelled',
          name: 'Dimas Test',
          assignedTrainerIds: ['pt-1'],
          packages: [
            { id: 'pkg-closed', tierName: 'Paket 4 Sesi', totalSessions: 4, completedCount: 0, status: 'closed' },
          ],
          sessions: [],
        },
      ],
    };

    const projection = buildManagerDashboardProjection(sourceData, {
      year: 2026,
      quarter: 4,
    });

    assert.equal(projection.dashboard.totalActivePt, 2);
    assert.equal(projection.dashboard.totalActiveClients, 1, 'Only active client c-active should be counted');
    assert.equal(projection.dashboard.totalPackagesSold, 1, 'Only sale-valid should be counted');
    assert.equal(projection.dashboard.totalSales, 1000000, 'Only sale-valid price should be counted');

    const pt1 = projection.trainers.find(t => t.id === 'pt-1');
    assert.equal(pt1.doc.name, 'Coach Faril');
    assert.equal(pt1.doc.activeClients, 1);
    assert.equal(pt1.doc.totalSales, 1000000);
    assert.equal(pt1.clients.length, 1);
    assert.equal(pt1.clients[0].id, 'c-active');

    const pt2 = projection.trainers.find(t => t.id === 'pt-2');
    assert.equal(pt2.doc.name, 'Coach Akbar', 'PT name should resolve to Coach Akbar, never literal PT');
    assert.equal(pt2.doc.totalSales, 0);
  });
});
