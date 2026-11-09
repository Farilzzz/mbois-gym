'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {fetch,periods}=require('./store-v2.cjs');
const {owned}=require('./owned-paths.cjs');
const {fixture}=require('./safety.test.cjs');
const {build}=require('./projection.cjs');
test('owned output allowlist excludes all source namespaces',()=>{for(const p of ['clients/c','users/u','package_sales/s','projection_control/manager'])assert.equal(owned(p),false);for(const p of ['manager_dashboard/2026-Q1','manager_dashboard/2026-Q1/trainers/t/clients/c/attendance/s'])assert.equal(owned(p),true);});
test('full recompute is idempotent and emits unique paths',()=>{const first=build(fixture(),['2026-Q1']),second=build(fixture(),['2026-Q1']);assert.deepEqual(second,first);assert.equal(new Set(first.writes.map(w=>w.path)).size,first.writes.length);});
function snap(id,data,ref){return {id,data:()=>data,ref};}
test('source Firestore document identity overrides embedded legacy IDs while preserving legacy numeric link',async()=>{
 const pkgRef={collection:()=>({})};
 const db={collection(name){return {get:async()=>({docs:name==='users'?[snap('t',{id:8,role:'trainer'})]:name==='package_sales'?[snap('sale',{id:44,trainerId:'t'})]:[snap('c',{id:3},pkgRef)]})};}};
 const tx={get:async ref=>({docs:ref===pkgRef.collection('packages')?[snap('p',{id:7})]:[]})};
 // Use a direct deterministic fake for nested collection reads.
 pkgRef.collection=name=>({get:async()=>({docs:name==='packages'?[snap('p',{id:7})]:[snap('s',{id:10})]})});
 const result=await fetch(db);
 assert.equal(result.users[0].id,'t');assert.equal(result.users[0].legacyId,8);
 assert.equal(result.clients[0].id,'c');assert.equal(result.clients[0].packages[0].id,'p');assert.equal(result.clients[0].packages[0].legacyId,7);
 assert.equal(result.clients[0].sessions[0].id,'s');assert.equal(result.packageSales[0].id,'sale');
});
test('recompute retains old periods after the last historical sale is deleted',()=>{
 const now=periods({packageSales:[]});
 const result=periods({packageSales:[]},['2020-Q1']);
 assert.ok(result.includes('2020-Q1'));assert.ok(now.every(p=>result.includes(p)));
});
