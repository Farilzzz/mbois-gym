'use strict';
const {onDocumentWritten}=require('firebase-functions/v2/firestore');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {reconcile}=require('./store-v2.cjs');
initializeApp();
for(const [name,document] of Object.entries({users:'users/{id}',clients:'clients/{id}',packages:'clients/{clientId}/packages/{id}',sessions:'clients/{clientId}/sessions/{id}',sales:'package_sales/{id}'})){
 exports['project_'+name]=onDocumentWritten({document,region:'asia-southeast1',retry:true},()=>reconcile(getFirestore()));
}
