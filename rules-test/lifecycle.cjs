const assert = require('node:assert/strict');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } = require('firebase/firestore');
module.exports = ({ dbFor, read, getEnv }) => describe('Lifecycle retention regressions', () => {
  const pkg = 'clients/c1/packages/lifecycle';
  const session = 'clients/c1/sessions/lifecycle';
  const signatures = { clientSignatureStatus: 'verified', coachSignatureStatus: 'verified', clientSignatureStrokes: [{points:[{x:1,y:1},{x:2,y:2}]}], coachSignatureStrokes: [{points:[{x:1,y:1},{x:2,y:2}]}] };
  async function seed(status = 'active', sessionStatus = 'scheduled') {
    await getEnv().withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(), pkg), {id:1,totalSessions:4,completedCount:1,status,price:500000});
      await setDoc(doc(ctx.firestore(), session), {packageIntId:1,packageDocId:'lifecycle',sessionNumber:2,scheduledTime:new Date(),status:sessionStatus,...(sessionStatus === 'completed' ? signatures : {})});
    });
  }
  it('package cancellation cannot rewrite purchase facts', async () => {
    await seed();
    await assertFails(updateDoc(doc(dbFor('pt1'), pkg), {status:'cancelled',price:1}));
  });
  it('terminal package records are immutable', async () => {
    for (const status of ['closed','cancelled']) {
      await seed(status);
      await assertFails(updateDoc(doc(dbFor('pt1'), pkg), {price:1}));
      await assertFails(updateDoc(doc(dbFor('pt1'), pkg), {status:'active'}));
    }
  });
  it('session cancellation cannot relink package or inject signatures', async () => {
    await seed();
    await assertFails(updateDoc(doc(dbFor('pt1'), session), {status:'cancelled',packageDocId:'other'}));
    await assertFails(updateDoc(doc(dbFor('pt1'), session), {status:'cancelled',...signatures}));
  });
  it('scheduled session edit cannot inject signatures', async () => {
    await seed();
    await assertFails(updateDoc(doc(dbFor('pt1'), session), signatures));
  });
  it('completed sessions and signatures remain immutable and undeletable', async () => {
    await seed('active','completed');
    for (const data of [{status:'cancelled'},{status:'scheduled'},{notes:'rewrite'},{clientSignatureStrokes:[]},{coachSignatureStatus:'pending'}]) {
      await assertFails(updateDoc(doc(dbFor('pt1'), session), data));
    }
    await assertFails(deleteDoc(doc(dbFor('pt1'), session)));
  });
  it('cancellation preserves quota, completed signatures and other active package', async () => {
    await seed();
    const db = dbFor('pt1');
    await assertSucceeds(setDoc(doc(db, pkg+'-other'), {totalSessions:4,completedCount:0,status:'active'}));
    await assertSucceeds(updateDoc(doc(db, session), {status:'cancelled',cancelledAt:serverTimestamp(),cancelledBy:'pt1',cancelReason:'Appointment only'}));
    assert.equal((await read('pt1',pkg)).data().completedCount,1);
    assert.equal((await read('pt1',pkg)).data().status,'active');
    await assertSucceeds(updateDoc(doc(db,pkg), {status:'cancelled',cancelledAt:serverTimestamp(),cancelledBy:'pt1',cancelReason:'Service discontinued'}));
    assert.equal((await read('pt1',pkg+'-other')).data().status,'active');
    await assertFails(updateDoc(doc(db,session), {status:'scheduled'}));
  });
  it('cancelled package cannot consume quota', async () => {
    await seed('cancelled');
    const db = dbFor('pt1'); const batch = writeBatch(db);
    batch.update(doc(db,pkg), {status:'active',completedCount:2,lastCompletedSessionId:'lifecycle'});
    batch.update(doc(db,session), {status:'completed',completedAt:serverTimestamp(),...signatures});
    await assertFails(batch.commit());
  });
  it('trainer cannot update existing ledger payment or refund facts', async () => {
    await getEnv().withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(),'package_sales/locked'), {trainerId:'pt1',status:'paid',price:500000}));
    await assertFails(updateDoc(doc(dbFor('pt1'),'package_sales/locked'), {status:'refunded',price:0}));
  });
});
