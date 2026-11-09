'use strict';
const nonempty=x=>typeof x==='string'&&x.trim().length>0;
function sessionPackage(s,packages){
 const explicit=s.packageDocId??(typeof s.packageId==='string'?s.packageId:null);
 if(explicit!=null)return packages.some(p=>p.id===explicit)?explicit:null;
 const legacy=s.packageIntId??(Number.isInteger(s.packageId)?s.packageId:null);
 if(!Number.isInteger(legacy))return null;
 const matches=packages.filter(p=>p.legacyId===legacy);
 return matches.length===1?matches[0].id:null;
}
function date(x){const d=x?.toDate?x.toDate():new Date(x);return x&&Number.isFinite(d.getTime())?d:null;}
function periodOf(x){const d=date(x);if(!d)return null;const p=Object.fromEntries(new Intl.DateTimeFormat('en-US',{timeZone:'Asia/Jakarta',year:'numeric',month:'numeric'}).formatToParts(d).map(x=>[x.type,x.value]));return {id:`${p.year}-Q${Math.ceil(+p.month/3)}`,month:(+p.month-1)%3};}
function trustedSale(s){return ['paid','valid','refunded'].includes(s.status)&&s.paymentStatus==='paid'&&['paymentEvidenceId','verifiedBy','transactionId','packageId','clientId','trainerId'].every(k=>typeof s[k]==='string'&&s[k].length>0)&&date(s.verifiedAt)&&periodOf(s.timestamp)&&Number.isSafeInteger(s.totalSessions)&&s.totalSessions>0&&Number.isSafeInteger(s.price)&&s.price>0&&Number.isInteger(s.refundAmount??0)&&(s.refundAmount??0)>=0&&(s.refundAmount??0)<=s.price&&(!(s.refundAmount>0||s.status==='refunded')||(['refundEvidenceId','refundVerifiedBy'].every(k=>nonempty(s[k]))&&date(s.refundVerifiedAt)&&s.refundAmount>0))&&(s.status!=='refunded'||s.refundAmount===s.price);}
function lifecycle(p,done){const status=String(p.status||'').toLowerCase();const total=Number(p.totalSessions)||0;if(total>0&&done>=total)return 'completed';if(['cancelled','canceled','void','discontinued'].includes(status))return 'cancelled';if(status==='closed')return 'unknown';return status==='active'&&total>done?'active':'unknown';}
function build(source,periods){
 const trainers=(source.users||[]).filter(x=>x.role==='trainer'),clients=source.clients||[],sales=source.packageSales||[],audit={unresolved:[],excluded:[]},valid=[];
 const counts=new Map();for(const s of sales)if(s.transactionId)counts.set(s.transactionId,(counts.get(s.transactionId)||0)+1);
 for(const s of sales){
  const c=clients.find(c=>c.id===s.clientId);
  const reason=counts.get(s.transactionId)>1?'duplicate_transaction':!trustedSale(s)?'missing_or_invalid_payment_link_or_snapshot':!c?.packages?.some(p=>p.id===s.packageId)||!trainers.some(t=>t.id===s.trainerId)?'unresolved_reference':null;
  if(reason)audit.unresolved.push({id:s.id,reason});else valid.push(s);
 }
 const writes=[];
 for(const pid of [...new Set(periods)].sort()){
  const root=`manager_dashboard/${pid}`,rootDoc={year:+pid.slice(0,4),quarter:+pid.slice(-1),timezone:'Asia/Jakarta',totalSales:0,totalPackagesSold:0,monthlySales:[0,0,0],totalActivePt:trainers.filter(t=>(t.status||'active')==='active').length,totalActiveClients:0};const active=new Set();writes.push({path:root,data:rootDoc});
  for(const t of trainers){
   const tr={name:t.displayName||t.name||'Coach Mbois',specialization:t.specialization||'Personal Trainer',status:t.status||'active',activeClients:0,packagesSold:0,totalSales:0,monthlySales:[0,0,0],quarterlyTarget:5000000,photoUrl:t.photoUrl||null};const tp=`${root}/trainers/${t.id}`;writes.push({path:tp,data:tr});
   for(const s of valid.filter(s=>s.trainerId===t.id&&periodOf(s.timestamp).id===pid)){const net=s.price-(s.refundAmount??0),m=periodOf(s.timestamp).month;tr.totalSales+=net;tr.packagesSold++;tr.monthlySales[m]+=net;rootDoc.totalSales+=net;rootDoc.totalPackagesSold++;rootDoc.monthlySales[m]+=net;}
   for(const c of clients.filter(c=>c.assignedTrainerIds?.length===1&&c.assignedTrainerIds[0]===t.id)){
    const sessions=(c.sessions||[]).map(s=>({...s,packageId:sessionPackage(s,c.packages||[])}));const packages=(c.packages||[]).map(p=>{const n=sessions.filter(s=>s.packageId===p.id&&s.status==='completed').length,total=Number.isInteger(p.totalSessions)&&p.totalSessions>0?p.totalSessions:0;return {id:p.id,packageName:p.packageName||p.tierName||`Paket ${total} Sesi`,status:lifecycle(p,n),totalSessions:total,attendedSessions:n,remainingSessions:Math.max(0,total-n)};});
    const primary=packages.find(p=>p.id===c.activePackageId)||packages.find(p=>p.status==='active')||packages.at(-1);const status=primary?.status||'no_package';if(status==='active'){tr.activeClients++;active.add(c.id);}
    const cp=`${tp}/clients/${c.id}`;writes.push({path:cp,data:{name:c.name||'Klien',packageName:primary?.packageName||'Paket PT',totalSessions:primary?.totalSessions||0,attendedSessions:primary?.attendedSessions||0,remainingSessions:primary?.remainingSessions||0,status,selectedPackageId:primary?.id||null,packages,unresolvedSessionCount:sessions.filter(s=>!packages.some(p=>p.id===s.packageId)).length}});
    for(const s of sessions.filter(s=>packages.some(p=>p.id===s.packageId)))writes.push({path:`${cp}/attendance/${s.id}`,data:{packageId:s.packageId,sessionNumber:Number(s.sessionNumber)||1,scheduledTime:date(s.scheduledTime||s.scheduledAt)||null,status:['scheduled','completed','cancelled'].includes(s.status)?s.status:'scheduled'}});
   }
  }rootDoc.totalActiveClients=active.size;
 }return {writes,audit};
}
module.exports={build,trustedSale,periodOf};
