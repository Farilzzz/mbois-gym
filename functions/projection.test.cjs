'use strict';
const {test}=require('node:test'); const assert=require('node:assert/strict');
const {build}=require('./projection.cjs');
const fixture=()=>({users:[{id:'t',role:'trainer',name:'Coach'}],clients:[{id:'c',name:'Client',assignedTrainerIds:['t'],packages:[{id:'p',status:'cancelled',totalSessions:4}],sessions:[]}],packageSales:[{id:'s',clientId:'c',trainerId:'t',packageId:'p',transactionId:'txn',status:'paid',paymentStatus:'paid',paymentEvidenceId:'receipt',verifiedBy:'admin',verifiedAt:'2026-01-01T00:00:00Z',timestamp:'2026-01-01T00:00:00Z',totalSessions:4,price:500000}]});
test('paid cancelled package remains revenue; no payment evidence is unresolved',()=>{const s=fixture(); const r=build(s,['2026-Q1']);assert.equal(r.writes.find(w=>w.path==='manager_dashboard/2026-Q1').data.totalSales,500000); delete s.packageSales[0].transactionId;assert.equal(build(s,['2026-Q1']).writes[0].data.totalSales,0);assert.equal(build(s,['2026-Q1']).audit.unresolved.length,1);});
module.exports={fixture};
