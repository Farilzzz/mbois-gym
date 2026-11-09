const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc, deleteDoc, serverTimestamp, writeBatch} = require('firebase/firestore');
module.exports = ({dbFor, getEnv}) => describe('Operational payload compatibility and integrity', () => {
  const workout = () => ({id:123,logId:'actual',clientIntId:1,packageIntId:2,sessionIntId:null,performedAt:serverTimestamp(),notes:'Training',totalVolume:120,exercises:[{id:1,name:'Squat',method:'normal',equipment:'barbell',groupKey:null,rpe:7,rir:3,notes:'',sets:[{id:1,setNumber:1,stage:'working',reps:12,weightKg:10}]}]});
  it('repository workout payload supports owner create/edit/exercise-set removal/delete', async () => {
    const ref = doc(dbFor('pt1'),'clients/c1/workouts/actual');
    await assertSucceeds(setDoc(ref,workout()));
    await assertSucceeds(updateDoc(ref,{notes:'Edited',sessionIntId:3,totalVolume:0,exercises:[],updatedAt:serverTimestamp()}));
    await assertFails(updateDoc(doc(dbFor('pt2'),ref.path),{notes:'intruder'}));
    await assertFails(deleteDoc(doc(dbFor('pt2'),ref.path)));
    await assertSucceeds(deleteDoc(ref));
  });
  it('repository evaluation payload supports finalize and edit without identity rewrite', async () => {
    const ref = doc(dbFor('pt1'),'clients/c1/evaluations/actual');
    await assertSucceeds(setDoc(ref,{id:123,evalId:'actual',packageIntId:2,finalWeightKg:70,bodyFatStart:null,bodyFatEnd:null,muscleStart:null,muscleEnd:null,armRight:null,armLeft:null,thighRight:null,thighLeft:null,achievement:'done',evaluation:'improved',recommendation:'continue',conclusion:'good',finalizedAt:serverTimestamp()}));
    await assertSucceeds(updateDoc(ref,{evaluation:'Updated'}));
    await assertFails(updateDoc(ref,{packageIntId:99}));
  });
  it('coupled quota increment cannot alter purchase facts', async () => {
    await getEnv().withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(),'clients/c1/packages/integrity'),{id:1,totalSessions:4,completedCount:0,status:'active',price:500000});
      await setDoc(doc(ctx.firestore(),'clients/c1/sessions/integrity'),{packageIntId:1,packageDocId:'integrity',sessionNumber:1,scheduledTime:new Date(),status:'scheduled'});
    });
    const db = dbFor('pt1');
    const batch = writeBatch(db);
    batch.update(doc(db,'clients/c1/packages/integrity'),{completedCount:1,lastCompletedSessionId:'integrity',price:1});
    batch.update(doc(db,'clients/c1/sessions/integrity'),{status:'completed',completedAt:serverTimestamp(),clientSignatureStatus:'verified',coachSignatureStatus:'verified',clientSignatureStrokes:[{points:[{x:1,y:1},{x:2,y:2}]}],coachSignatureStrokes:[{points:[{x:1,y:1},{x:2,y:2}]}]});
    await assertFails(batch.commit());
  });
});
