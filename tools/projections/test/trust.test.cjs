const {test} = require('node:test');
const assert = require('node:assert/strict');
const {buildManagerDashboardProjection: build, parseDateInTimezone, fetchSourceDataFromFirestore} = require('../builder.cjs');
const options = {year:2026, quarter:1};
const sale = {id:'sale', clientId:'client', trainerId:'uid', price:100, status:'valid', timestamp:'2026-01-01T00:00:00Z'};
const source = () => ({users:[{id:'uid',role:'trainer',status:'active'}],clients:[{id:'client',assignedTrainerIds:['uid'],packages:[{status:'active',totalSessions:4,completedCount:0}],sessions:[]}],packageSales:[{...sale}]});
test('sales fail closed on status, amount, date and ownership', () => {
  for (const bad of [{status:undefined},{status:'pending'},{price:-1},{price:Infinity},{price:'100'},{price:NaN},{timestamp:null},{timestamp:{}},{timestamp:'2026-02-30T00:00:00Z'},{trainerId:'unknown'},{clientId:'missing'}]) {
    const data=source(); data.packageSales=[{...sale,...bad}];
    assert.equal(build(data,options).dashboard.totalPackagesSold,0,JSON.stringify(bad));
  }
  assert.equal(build(source(),options).dashboard.totalSales,100);
});
test('ambiguous assignments and conflicting duplicate sales are refused', () => {
  const data=source(); data.clients[0].assignedTrainerIds=['uid','other'];
  assert.equal(build(data,options).dashboard.totalPackagesSold,0);
  assert.equal(build(data,options).trainers[0].clients.length,0);
  const dup=source(); dup.packageSales.push({...sale,price:200});
  assert.equal(build(dup,options).dashboard.totalPackagesSold,0);
});
test('missing dates never mean now', () => {
  for (const value of [null,undefined,{},'', '2026-01-01']) assert.throws(()=>parseDateInTimezone(value));
});
test('Firestore document identity wins over embedded legacy numeric IDs; read errors propagate', async () => {
  const db={collection(name){return {get:async()=>({docs:name==='users'?[{id:'uid',data:()=>({id:42,role:'trainer'})}]:[]})};}};
  assert.equal((await fetchSourceDataFromFirestore(db)).users[0].id,'uid');
  const fail={collection(name){return {get:async()=>({docs:name==='clients'?[{id:'c',data:()=>({}),ref:{collection(){return {get:async()=>{throw Error('read failed');}};}}}]:[]})};}};
  await assert.rejects(fetchSourceDataFromFirestore(fail),/read failed/);
});
