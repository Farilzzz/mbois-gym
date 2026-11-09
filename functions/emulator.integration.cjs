'use strict';
const {test}=require('node:test');const a=require('node:assert/strict');
// Fail closed before initializing an Admin client (including when run accidentally).
const project=process.env.GCLOUD_PROJECT;
if(!project?.startsWith('demo-')||!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||'')||!process.env.FIREBASE_EMULATOR_HUB)throw Error('Requires demo project and local Firestore + Functions emulators');
const {initializeApp}=require('firebase-admin/app');const {getFirestore}=require('firebase-admin/firestore');
initializeApp({projectId:project});const db=getFirestore();const {reconcile,fetch}=require('./store-v2.cjs');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function eventually(check){let error;for(let n=0;n<120;n++){try{await check();return;}catch(e){error=e;}await sleep(500);}throw error;}
const data=async p=>(await db.doc(p).get()).data();
const root='manager_dashboard/2026-Q1';
test('real automatic trigger delivery, replay, concurrency and cleanup',{timeout:240000},async()=>{
 const b=db.batch();
 b.set(db.doc('users/t'),{role:'trainer',name:'Trainer'});b.set(db.doc('users/t2'),{role:'trainer'});
 b.set(db.doc('clients/c'),{assignedTrainerIds:['t']});
 b.set(db.doc('clients/c/packages/p'),{id:7,totalSessions:4,status:'active'});
 b.set(db.doc('clients/c/sessions/s'),{id:123,packageDocId:'p',packageIntId:7,status:'completed',scheduledAt:'2026-01-02'});
 b.set(db.doc('package_sales/sale'),{id:44,clientId:'c',trainerId:'t',packageId:'p',transactionId:'tx',paymentEvidenceId:'receipt',verifiedBy:'admin',verifiedAt:'2026-01-01',timestamp:'2026-01-01',status:'paid',paymentStatus:'paid',price:450000,totalSessions:4});
 await b.commit();
 // No reconcile call here: proves Functions actually delivered source triggers.
 await eventually(async()=>{a.equal((await data(root))?.totalSales,450000);a.equal((await data(root+'/trainers/t/clients/c'))?.attendedSessions,1);});
 const src=await fetch(db);a.equal(src.clients[0].packages[0].id,'p');a.equal(src.clients[0].packages[0].legacyId,7);
 await Promise.all([reconcile(db),reconcile(db),reconcile(db)]);
 a.equal((await data(root)).totalSales,450000);
 await Promise.all([db.doc('clients/c').update({assignedTrainerIds:['t2']}),db.doc('package_sales/sale').update({timestamp:'2026-04-01'})]);
 await eventually(async()=>{a.equal((await data(root)).totalSales,0);a.equal((await data('manager_dashboard/2026-Q2')).totalSales,450000);a.equal(await data(root+'/trainers/t/clients/c'),undefined);a.equal((await data(root+'/trainers/t2/clients/c'))?.attendedSessions,1);});
 // Discover stale nested outputs even with a missing root and missing manifest.
 await db.doc('manager_dashboard/2020-Q1/trainers/ghost/clients/stale/attendance/old').set({private:'must disappear'});
 await db.doc('projection_control/manager').delete();
 await db.doc('users/t').update({name:'Changed'});
 await eventually(async()=>a.equal(await data('manager_dashboard/2020-Q1/trainers/ghost/clients/stale/attendance/old'),undefined));
 a.ok((await db.doc('clients/c/packages/p').get()).exists);
 // Source removal must clear historical aggregate without deleting other sources.
 await db.doc('package_sales/sale').delete();
 await eventually(async()=>a.equal((await data('manager_dashboard/2026-Q2')).totalSales,0));
 a.ok((await db.doc('clients/c/sessions/s').get()).exists);
 // Hostile manifest cannot authorize deleting source data.
 await db.doc('projection_control/manager').set({manifest:['clients/c']});
 await a.rejects(reconcile(db),/manifest/i);
 a.ok((await db.doc('clients/c').get()).exists);
 await db.doc('projection_control/manager').delete();
});
