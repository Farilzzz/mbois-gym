'use strict';
const owned=p=>typeof p==='string'&&/^manager_dashboard\/\d{4}-Q[1-4](?:\/trainers\/[^/]+(?:\/clients\/[^/]+(?:\/attendance\/[^/]+)?)?)?$/.test(p);
async function discover(db,tx){
 const snaps=await Promise.all([db.collection('manager_dashboard'),...['trainers','clients','attendance'].map(c=>db.collectionGroup(c))].map(q=>tx.get(q)));
 return new Map(snaps.flatMap(s=>s.docs).filter(d=>owned(d.ref.path)).map(d=>[d.ref.path,d]));
}
module.exports={owned,discover};
