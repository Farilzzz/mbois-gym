'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
for(const filename of ['verify_and_apply_projection.cjs','audit_and_backup.cjs']){
  test(`${filename} refuses to run against production`,()=>{
    const source=fs.readFileSync(path.join(root,filename),'utf8');
    assert.match(source,/FIRESTORE_EMULATOR_HOST/);
    assert.doesNotMatch(source,/startsWith\('manager_dashboard\/2026-Q4'\)/);
    assert.doesNotMatch(source,/\['485163'/);
  });
}
