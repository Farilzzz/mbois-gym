'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {buildManagerDashboardProjection, fetchSourceDataFromFirestore} = require('./builder.cjs');

async function listExisting(db, periodId) {
  const root = `manager_dashboard/${periodId}`;
  const found = [];
  async function walk(docPath) {
    const ref = db.doc(docPath);
    const snap = await ref.get();
    if (snap.exists) found.push({path:docPath, data:snap.data()});
    for (const collectionName of ['trainers','clients','attendance']) {
      const depth = docPath.split('/').length;
      if ((depth === 2 && collectionName !== 'trainers') || (depth === 4 && collectionName !== 'clients') || (depth === 6 && collectionName !== 'attendance') || depth > 6) continue;
      const children = await ref.collection(collectionName).get();
      for (const child of children.docs) await walk(`${docPath}/${collectionName}/${child.id}`);
    }
  }
  await walk(root);
  return found;
}

async function reconcile(db, options = {}) {
  if (!Number.isInteger(options.year) || ![1,2,3,4].includes(options.quarter)) throw Error('Explicit valid year and quarter required');
  const projection = buildManagerDashboardProjection(await fetchSourceDataFromFirestore(db),options);
  const existing = await listExisting(db,projection.periodId);
  const expected = new Set(projection.writes.map(w => w.path));
  const deletes = existing.filter(x=>!expected.has(x.path)).map(x=>x.path).sort((a,b)=>b.split('/').length-a.split('/').length);
  const changes = projection.writes.filter(w=>JSON.stringify(existing.find(x=>x.path===w.path)?.data) !== JSON.stringify(w.data));
  const summary = {periodId:projection.periodId, existingCount:existing.length, setCount:changes.length, deleteCount:deletes.length, dryRun:true};
  if (!options.apply) return summary;
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Apply requires FIRESTORE_EMULATOR_HOST; no production writes from this tool');
  if (!options.backupFile || !path.isAbsolute(options.backupFile)) throw Error('Absolute --backup-file required');
  // Exclusive creation prevents overwriting an earlier backup. Backup includes only the projection subtree.
  const handle = fs.openSync(options.backupFile,'wx',0o600);
  try { fs.writeFileSync(handle,JSON.stringify({periodId:projection.periodId,existing},null,2)); fs.fsyncSync(handle); }
  finally { fs.closeSync(handle); }
  for (const w of changes) await db.doc(w.path).set(w.data); // replace: remove stale fields
  for (const p of deletes) await db.doc(p).delete(); // deepest first
  return {...summary,dryRun:false,backupFile:options.backupFile};
}
module.exports = {reconcile, listExisting};
