const {test}=require('node:test');
const assert=require('node:assert/strict');
const {reconcile}=require('../reconcile.cjs');
function fake() {
 const store=new Map([['manager_dashboard/2026-Q1',{old:true}],['manager_dashboard/2026-Q1/trainers/stale',{name:'old',secret:'remove'}]]);
 return {store,collection:()=>({get:async()=>({docs:[]})}),doc(p){return {get:async()=>({exists:store.has(p),data:()=>store.get(p)}),collection(c){return {get:async()=>({docs:[...store.keys()].filter(k=>k.startsWith(p+'/'+c+'/')&&k.split('/').length===p.split('/').length+2).map(k=>({id:k.split('/').at(-1)}))})};},set:async d=>store.set(p,d),delete:async()=>store.delete(p)};}};
}
test('dry run enumerates stale documents without writing',async()=>{const db=fake();const before=JSON.stringify([...db.store]);const r=await reconcile(db,{year:2026,quarter:1});assert.equal(r.deleteCount,1);assert.equal(r.setCount,1);assert.equal(JSON.stringify([...db.store]),before);});
test('apply fails closed outside emulator',async()=>{const host=process.env.FIRESTORE_EMULATOR_HOST;delete process.env.FIRESTORE_EMULATOR_HOST;try{await assert.rejects(reconcile(fake(),{year:2026,quarter:1,apply:true}),/emulator|EMULATOR/);}finally{if(host)process.env.FIRESTORE_EMULATOR_HOST=host;}});
