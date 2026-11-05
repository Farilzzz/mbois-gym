const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  fetchSourceDataFromFirestore,
  commitProjectionToFirestore,
  runProjectionJob,
} = require('../builder.cjs');

// Mock Firestore implementation for testing fetch and commit behavior
function createMockFirestore(initialCollections = {}) {
  const store = new Map();
  const commitLog = [];

  for (const [colPath, docs] of Object.entries(initialCollections)) {
    for (const doc of docs) {
      store.set(`${colPath}/${doc.id}`, { ...doc });
    }
  }

  return {
    store,
    commitLog,
    collection(colName) {
      return {
        get: async () => {
          const docs = [];
          for (const [key, val] of store.entries()) {
            // Check if key is directly under colName (or subcollection)
            const parts = key.split('/');
            if (parts.length === 2 && parts[0] === colName) {
              docs.push({
                id: parts[1],
                data: () => val,
                ref: {
                  collection: (subName) => ({
                    get: async () => {
                      const subDocs = [];
                      const prefix = `${key}/${subName}/`;
                      for (const [subKey, subVal] of store.entries()) {
                        if (subKey.startsWith(prefix) && subKey.split('/').length === 4) {
                          subDocs.push({
                            id: subKey.split('/')[3],
                            data: () => subVal,
                          });
                        }
                      }
                      return { docs: subDocs };
                    },
                  }),
                },
              });
            }
          }
          return { docs };
        },
      };
    },
    doc(docPath) {
      return { path: docPath };
    },
    batch() {
      const operations = [];
      return {
        set(docRef, data, options) {
          operations.push({ op: 'set', path: docRef.path, data, options });
        },
        commit: async () => {
          commitLog.push([...operations]);
          for (const op of operations) {
            store.set(op.path, op.data);
          }
        },
      };
    },
  };
}

describe('Firestore Source Fetching & Projection Sync', () => {
  it('fetches users, package_sales, clients with packages and sessions', async () => {
    const mockDb = createMockFirestore({
      users: [
        { id: 'pt1', role: 'trainer', status: 'active', displayName: 'Coach 1' },
      ],
      package_sales: [
        { id: 'sale1', trainerId: 'pt1', clientId: 'c1', price: 1000000, status: 'valid', timestamp: '2026-01-10T00:00:00Z' },
      ],
      clients: [
        { id: 'c1', name: 'Client 1', assignedTrainerIds: ['pt1'], status: 'active' },
      ],
      'clients/c1/packages': [
        { id: 'p1', tierName: 'Paket 10 Sesi', totalSessions: 10, completedCount: 2, status: 'active' },
      ],
      'clients/c1/sessions': [
        { id: 's1', sessionNumber: 1, scheduledTime: '2026-01-05T10:00:00Z', status: 'completed' },
        { id: 's2', sessionNumber: 2, scheduledTime: '2026-01-08T10:00:00Z', status: 'completed' },
      ],
    });

    const sourceData = await fetchSourceDataFromFirestore(mockDb);
    assert.equal(sourceData.users.length, 1);
    assert.equal(sourceData.packageSales.length, 1);
    assert.equal(sourceData.clients.length, 1);
    assert.equal(sourceData.clients[0].packages.length, 1);
    assert.equal(sourceData.clients[0].sessions.length, 2);
  });

  it('commits writes in batches without exceeding 500 ops limit', async () => {
    const mockDb = createMockFirestore();

    // Create 550 dummy writes to test chunking
    const dummyWrites = [];
    for (let i = 0; i < 550; i++) {
      dummyWrites.push({
        path: `test_collection/doc_${i}`,
        data: { index: i },
      });
    }

    const result = await commitProjectionToFirestore(mockDb, dummyWrites);
    assert.equal(result.committedCount, 550);
    assert.equal(result.batchCount, 2); // 500 in batch 1, 50 in batch 2
    assert.equal(mockDb.commitLog.length, 2);
    assert.equal(mockDb.commitLog[0].length, 500);
    assert.equal(mockDb.commitLog[1].length, 50);
  });

  it('runProjectionJob respects dryRun flag and does NOT write when dryRun is true', async () => {
    const mockDb = createMockFirestore({
      users: [
        { id: 'pt1', role: 'trainer', status: 'active', displayName: 'Coach 1' },
      ],
      package_sales: [],
      clients: [],
    });

    // DRY RUN: should NOT touch commitLog or write to Firestore
    const dryResult = await runProjectionJob(mockDb, {
      project: 'mbois-gym',
      year: 2026,
      quarter: 1,
      dryRun: true,
      apply: false,
    });

    assert.equal(dryResult.dryRun, true);
    assert.equal(dryResult.writesCount > 0, true);
    assert.equal(mockDb.commitLog.length, 0); // NO WRITES!

    // APPLY: should commit writes
    await assert.rejects(runProjectionJob(mockDb, {
      project: 'mbois-gym',
      year: 2026,
      quarter: 1,
      dryRun: false,
      apply: true,
    }), /Legacy apply disabled/);

    assert.equal(mockDb.commitLog.length, 0); // production writer is deliberately gated.
  });
});
