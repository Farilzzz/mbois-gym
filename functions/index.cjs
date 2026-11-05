'use strict';
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {buildManagerDashboardProjection,fetchSourceDataFromFirestore,parseDateInTimezone}=require('../tools/projections/builder.cjs');
initializeApp();
exports.auditManagerProjection = onDocumentWritten({document:'{sourceCollection}/{sourceId}',region:'asia-southeast1'},async event=>{
  if(!['users','clients','package_sales'].includes(event.params.sourceCollection)) return;
  const source=await fetchSourceDataFromFirestore(getFirestore());
  const {year,quarter}=parseDateInTimezone(new Date(),'Asia/Jakarta');
  const result=buildManagerDashboardProjection(source,{year,quarter,timezone:'Asia/Jakarta'});
  // Deliberately read-only. Legacy client-authored sales are not proof of payment;
  // no financial projection may be published until a trusted sales ledger exists.
  console.info('Manager projection audit', {periodId:result.periodId,documents:result.writes.length});
});
