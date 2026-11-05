'use strict';

/**
 * Trusted Firebase Admin SDK Manager Dashboard Projection Builder
 * Computes isolated, read-only manager dashboard projections at:
 * manager_dashboard/{year}-Q{quarter}/trainers/{trainerId}/clients/{clientId}/attendance/{sessionId}
 *
 * Enforces:
 * - Deterministic quarter calculation with explicit timezone (default Asia/Jakarta)
 * - Individual Rp 5.000.000 quarterly target for every trainer
 * - Deduplication of package_sales by ID and validity checking
 * - Inclusion of all trainers even with 0 sales
 * - Strict allowlist: NO sensitive information (no medical/assessments, notes, signatures, phones)
 * - Dry-run default, --apply explicit
 */

const ALLOWED_PROJECT = 'mbois-gym';
const DEFAULT_TIMEZONE = 'Asia/Jakarta';
const DEFAULT_QUARTERLY_TARGET = 5000000.0;

/**
 * Parse CLI arguments
 */
function parseArgs(args = []) {
  const options = {
    project: null,
    year: null,
    quarter: null,
    timezone: DEFAULT_TIMEZONE,
    apply: false,
    dryRun: true,
    json: false,
    help: false,
  };

  const PROHIBITED_OPTIONS = ['--password', '-p', '--secret', '--token'];

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    for (const prohibited of PROHIBITED_OPTIONS) {
      if (arg === prohibited || arg.startsWith(prohibited + '=')) {
        throw new Error(`Opsi '${prohibited}' dilarang. CLI ini tidak menerima credentials rahasia.`);
      }
    }

    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--apply') {
      options.apply = true;
      options.dryRun = false;
    } else if (arg === '--dry-run') {
      options.dryRun = true;
      options.apply = false;
    } else if (arg === '--json') {
      options.json = true;
    } else if (arg === '--project') {
      options.project = args[++i];
    } else if (arg.startsWith('--project=')) {
      options.project = arg.split('=')[1];
    } else if (arg === '--year') {
      options.year = parseInt(args[++i], 10);
    } else if (arg.startsWith('--year=')) {
      options.year = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--quarter' || arg === '-q') {
      options.quarter = parseInt(args[++i], 10);
    } else if (arg.startsWith('--quarter=') || arg.startsWith('-q=')) {
      options.quarter = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--timezone' || arg === '--tz') {
      options.timezone = args[++i];
    } else if (arg.startsWith('--timezone=') || arg.startsWith('--tz=')) {
      options.timezone = arg.split('=')[1];
    } else {
      throw new Error(`Argumen tidak dikenal: ${arg}`);
    }
  }

  if (options.help) {
    return options;
  }

  if (!options.project) {
    throw new Error(`Flag --project wajib diisi (contoh: --project ${ALLOWED_PROJECT})`);
  }

  if (options.project !== ALLOWED_PROJECT) {
    throw new Error(`Project '${options.project}' tidak diizinkan. CLI ini dibatasi secara eksplisit untuk '${ALLOWED_PROJECT}'.`);
  }

  // Determine current year and quarter in target timezone if not specified
  const nowParsed = parseDateInTimezone(new Date(), options.timezone);
  if (options.year === null || isNaN(options.year)) {
    options.year = nowParsed.year;
  }
  if (options.quarter === null || isNaN(options.quarter)) {
    options.quarter = nowParsed.quarter;
  }

  if (options.quarter < 1 || options.quarter > 4) {
    throw new Error(`Kuartal harus bernilai 1-4 (diterima: ${options.quarter})`);
  }

  return options;
}

/**
 * Parse a date/timestamp input in a given timezone and extract calendar components
 */
function parseDateInTimezone(dateInput, timezone = DEFAULT_TIMEZONE) {
  let jsDate;

  if (dateInput === undefined || dateInput === null || dateInput === '') {
    throw new Error(`Tanggal tidak valid: ${dateInput}`);
  }
  if (dateInput instanceof Date) {
    jsDate = dateInput;
  } else if (typeof dateInput.toDate === 'function') {
    jsDate = dateInput.toDate();
  } else if (typeof dateInput === 'object' && typeof dateInput.seconds === 'number') {
    jsDate = new Date(dateInput.seconds * 1000 + (dateInput.nanoseconds || 0) / 1000000);
  } else if (typeof dateInput === 'string') {
      const match = /^(\d{4})-(\d{2})-(\d{2})T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.exec(dateInput);
      if (!match || Number(match[2]) < 1 || Number(match[2]) > 12 || Number(match[3]) < 1 || Number(match[3]) > new Date(Date.UTC(Number(match[1]),Number(match[2]),0)).getUTCDate()) throw new Error('Invalid timestamp');
      jsDate = new Date(dateInput);
    } else {
      throw new Error('Invalid timestamp');
    }

  if (isNaN(jsDate.getTime())) {
    throw new Error(`Tanggal tidak valid: ${dateInput}`);
  }

  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    hour12: false,
  });

  const parts = formatter.formatToParts(jsDate);
  const partMap = {};
  for (const p of parts) {
    partMap[p.type] = p.value;
  }

  const year = parseInt(partMap.year, 10);
  const month = parseInt(partMap.month, 10); // 1-12
  const day = parseInt(partMap.day, 10);
  const quarter = Math.floor((month - 1) / 3) + 1; // 1-4

  return {
    year,
    month,
    day,
    quarter,
    jsDate,
  };
}

/**
 * Returns period metadata for a given year and quarter
 */
function getQuarterInfo(year, quarter, timezone = DEFAULT_TIMEZONE) {
  if (quarter < 1 || quarter > 4) {
    throw new Error(`Kuartal harus bernilai 1-4: ${quarter}`);
  }

  const startMonth = (quarter - 1) * 3 + 1;
  const months = [startMonth, startMonth + 1, startMonth + 2];
  const periodId = `${year}-Q${quarter}`;

  return {
    year,
    quarter,
    periodId,
    months,
    timezone,
  };
}

/**
 * Calculate client lifecycle status deterministically
 */
function getClientLifecycle(client) {
  if (!client) return 'unknown';
  const docStatus = String(client.status || '').toLowerCase().trim();
  if (docStatus === 'cancelled') return 'cancelled';
  if (docStatus === 'inactive') return 'inactive';

  const packages = Array.isArray(client.packages) ? client.packages : [];
  if (packages.length === 0) return 'no_package';

  const activePkg = packages.find(p => p.status === 'active');
  if (activePkg) {
    const total = Number(activePkg.totalSessions) || 0;
    const completed = Number(activePkg.completedCount) || 0;
    if (completed >= total && total > 0) {
      return 'completed';
    }
    return 'active';
  }

  const closedPkgs = packages.filter(p => p.status === 'closed');
  if (closedPkgs.length > 0) {
    const lastClosed = closedPkgs[closedPkgs.length - 1];
    const total = Number(lastClosed.totalSessions) || 0;
    const completed = Number(lastClosed.completedCount) || 0;
    if (completed >= total && total > 0) {
      return 'completed';
    }
    return 'discontinued';
  }

  return 'cancelled';
}

/**
 * Check if a package sale is valid (not cancelled/refunded/void)
 * Also excludes sales whose client/package registration was cancelled without completed sessions.
 */
function isValidSale(sale, clientsMap = new Map(), trainersMap = new Map()) {
  if (!sale || typeof sale !== 'object') return false;
  if (String(sale.status || '').toLowerCase().trim() !== 'valid') return false;
  const price = sale.price;
  if (typeof price !== 'number' || !Number.isFinite(price) || price < 0) return false;
  if (!sale.timestamp) return false;
  try { parseDateInTimezone(sale.timestamp); } catch (_) { return false; }

  if (trainersMap.size > 0 && (!sale.trainerId || !trainersMap.has(String(sale.trainerId)))) {
    return false;
  }
  if (clientsMap.size > 0 && (!sale.clientId || !clientsMap.has(String(sale.clientId)))) {
    return false;
  }

  if (sale.clientId && clientsMap.has(String(sale.clientId))) {
    const client = clientsMap.get(String(sale.clientId));
    const assigned = Array.isArray(client.assignedTrainerIds) ? client.assignedTrainerIds.map(String) : [];
    if (assigned.length !== 1 || (sale.trainerId && assigned[0] !== String(sale.trainerId))) {
      return false;
    }
    const lifecycle = getClientLifecycle(client);
    if (lifecycle === 'cancelled' || lifecycle === 'discontinued') {
      const packages = Array.isArray(client.packages) ? client.packages : [];
      if (!packages.some(p => (Number(p.completedCount) || 0) > 0)) {
        return false;
      }
    }
  }

  return true;
}

/**
 * Deduplicate package sales by ID, retaining only valid records
 */
function deduplicateSales(sales = [], clientsMap = new Map(), trainersMap = new Map()) {
  const seen = new Set();
    const conflicts = new Set();
    const fingerprints = new Map();
    for (const s of sales) {
      if (!s) continue;
      const id = s.id || s.saleId;
      const value = JSON.stringify(s);
      if (fingerprints.has(id) && fingerprints.get(id) !== value) conflicts.add(id);
      fingerprints.set(id,value);
    }
    const validList = [];

  for (const sale of sales) {
    if (!sale) continue;
    const id = sale.id || sale.saleId;
    if (!id) continue;

    if (seen.has(id)) {
      continue;
    }
    seen.add(id);

    if (!conflicts.has(id) && isValidSale(sale, clientsMap, trainersMap)) {
      validList.push(sale);
    }
  }

  return validList;
}

/**
 * Core pure calculation: builds the manager dashboard projection
 */
function buildManagerDashboardProjection(sourceData, options = {}) {
  const year = options.year || 2026;
  const quarter = options.quarter || 1;
  const timezone = options.timezone || DEFAULT_TIMEZONE;
  const quarterlyTarget = typeof options.quarterlyTarget === 'number'
    ? options.quarterlyTarget
    : DEFAULT_QUARTERLY_TARGET;

  const quarterInfo = getQuarterInfo(year, quarter, timezone);
  const targetMonths = quarterInfo.months; // e.g. [1, 2, 3]

  // 1. Filter all trainers from users collection (all trainers even with 0 sales)
  const allUsers = sourceData.users || [];
  const trainerUsers = allUsers.filter(u => u && u.role === 'trainer');

  // Build client map for cross-referencing sales & lifecycle status
  const rawClients = sourceData.clients || [];
  const clientsMap = new Map(rawClients.map(c => [String(c.id), c]));

  // 2. Deduplicate and filter package sales for target quarter & year
  const rawSales = sourceData.packageSales || [];
  const trainersMap = new Map(trainerUsers.map(t => [t.id,t]));
  const dedupedSales = deduplicateSales(rawSales, clientsMap, trainersMap).filter(s =>
    clientsMap.has(String(s.clientId)) && trainersMap.has(String(s.trainerId)));
  // Existing client-authored ledger is not proof of payment. Applying it requires
  // an independent administrative verification/migration, not a client status.

  const quarterSales = [];
  for (const sale of dedupedSales) {
    try {
      const parsed = parseDateInTimezone(sale.timestamp, timezone);
      if (parsed.year === year && parsed.quarter === quarter) {
        quarterSales.push({
          ...sale,
          _parsedMonth: parsed.month,
        });
      }
    } catch (_) {
      // Ignore invalid timestamp
    }
  }

  // Group sales by trainerId
  const salesByTrainer = new Map();
  for (const sale of quarterSales) {
    const trainerId = sale.trainerId;
    if (!trainerId) continue;
    if (!salesByTrainer.has(trainerId)) {
      salesByTrainer.set(trainerId, []);
    }
    salesByTrainer.get(trainerId).push(sale);
  }

  // 3. Process clients and attendance with STRICT ALLOWLIST (NO sensitive info)
  const clientsByTrainer = new Map();

  for (const client of rawClients) {
    if (!client || !client.id) continue;
    if (!Array.isArray(client.assignedTrainerIds) || client.assignedTrainerIds.length !== 1 || !trainersMap.has(client.assignedTrainerIds[0])) continue;
    const clientAssignedTrainers = Array.isArray(client.assignedTrainerIds)
      ? client.assignedTrainerIds
      : [];

    // Find active package or primary package
    const packages = Array.isArray(client.packages) ? client.packages : [];
    const activePkg = packages.find(p => p.status === 'active') || packages[0];

    const rawSessions = Array.isArray(client.sessions) ? client.sessions : [];

    // Calculate completed sessions and total sessions
    let completedSessionsCount = 0;
    const allowlistedAttendance = [];

    // Sort sessions by sessionNumber
    const sortedSessions = [...rawSessions].sort((a, b) => {
      const numA = (a && a.sessionNumber) || 0;
      const numB = (b && b.sessionNumber) || 0;
      return numA - numB;
    });

    for (const sess of sortedSessions) {
      if (!sess) continue;
      const status = String(sess.status || 'scheduled').toLowerCase();
      if (status === 'completed') {
        completedSessionsCount++;
      }

      // Scheduled time
      let scheduledTime = sess.scheduledTime || sess.scheduledAt || sess.completedAt || new Date();
      if (typeof scheduledTime.toDate === 'function') {
        scheduledTime = scheduledTime.toDate();
      }

      // ATTENDANCE ALLOWLIST: Only sessionNumber, scheduledTime, status
      // EXCLUDES: notes, cancelReason, cancelledBy, signatures, workouts
      allowlistedAttendance.push({
        id: sess.id || sess.sessionId || `session-${sess.sessionNumber || 1}`,
        doc: {
          sessionNumber: Number(sess.sessionNumber) || 1,
          scheduledTime: scheduledTime,
          status: status,
        },
      });
    }

    let totalSessions = activePkg
      ? (Number(activePkg.totalSessions) || 0)
      : Math.max(completedSessionsCount, rawSessions.length);
    let attendedSessions = activePkg && typeof activePkg.completedCount === 'number'
      ? activePkg.completedCount
      : completedSessionsCount;
    let remainingSessions = Math.max(0, totalSessions - attendedSessions);
    let packageName = activePkg
      ? (activePkg.tierName || activePkg.packageName || `Paket ${totalSessions} Sesi`)
      : (totalSessions > 0 ? `Paket ${totalSessions} Sesi` : 'Paket PT');

    const lifecycle = getClientLifecycle(client);
    const isOperational = lifecycle === 'active' || lifecycle === 'completed';
    if (!isOperational) {
      // Exclude cancelled/discontinued clients without completed sessions from operational views
      continue;
    }

    // CLIENT ALLOWLIST: Only name, packageName, totalSessions, attendedSessions, remainingSessions
    // EXCLUDES: notes, medical, evaluations, workouts, phone, email, address, assessments
    const clientProjectionItem = {
      id: client.id,
      doc: {
        name: client.name || 'Klien',
        packageName: packageName,
        totalSessions: totalSessions,
        attendedSessions: attendedSessions,
        remainingSessions: remainingSessions,
      },
      status: lifecycle,
      attendance: allowlistedAttendance,
    };

    for (const trainerId of clientAssignedTrainers) {
      if (!clientsByTrainer.has(trainerId)) {
        clientsByTrainer.set(trainerId, []);
      }
      clientsByTrainer.get(trainerId).push(clientProjectionItem);
    }
  }

  // 4. Build Trainer projections
  const trainersProjection = [];
  let totalActiveClientsSet = new Set();
  let totalOverallSales = 0;
  let totalOverallPackagesSold = 0;
  const overallMonthlySales = [0, 0, 0];

  for (const trainer of trainerUsers) {
    const trainerId = trainer.id;
    const trainerSales = salesByTrainer.get(trainerId) || [];
    const trainerClients = clientsByTrainer.get(trainerId) || [];

    // Monthly breakdown for this trainer
    const trainerMonthlySales = [0, 0, 0];
    let trainerTotalSales = 0;

    for (const sale of trainerSales) {
      const price = Number(sale.price) || 0;
      trainerTotalSales += price;

      const saleMonth = sale._parsedMonth;
      const monthIdx = targetMonths.indexOf(saleMonth);
      if (monthIdx >= 0 && monthIdx < 3) {
        trainerMonthlySales[monthIdx] += price;
        overallMonthlySales[monthIdx] += price;
      }
    }

    totalOverallSales += trainerTotalSales;
    totalOverallPackagesSold += trainerSales.length;

    // Active clients for this trainer
    const activeTrainerClients = trainerClients.filter(c => c.status === 'active');
    for (const c of activeTrainerClients) {
      totalActiveClientsSet.add(c.id);
    }

    const rawName = (trainer.displayName && String(trainer.displayName).trim()) || '';
    const altName = (trainer.name && String(trainer.name).trim()) || '';
    const trainerName = (rawName && rawName !== 'PT')
      ? rawName
      : (altName && altName !== 'PT')
        ? altName
        : 'Coach Mbois';

    // TRAINER ALLOWLIST
    // EXCLUDES: private phone, email, personal address, bank details
    const trainerDoc = {
      name: trainerName,
      specialization: trainer.specialization || 'Personal Trainer',
      activeClients: activeTrainerClients.length,
      packagesSold: trainerSales.length,
      totalSales: trainerTotalSales,
      photoUrl: trainer.photoUrl || null,
      status: trainer.status || 'active',
      quarterlyTarget: quarterlyTarget, // Always 5.000.000
      monthlySales: trainerMonthlySales,
    };

    trainersProjection.push({
      id: trainerId,
      doc: trainerDoc,
      clients: trainerClients,
    });
  }

  // Count active trainers
  const totalActivePt = trainerUsers.filter(u => u.status === 'active').length;

  // Root Dashboard Document
  const dashboardDoc = {
    totalActivePt: totalActivePt,
    totalActiveClients: totalActiveClientsSet.size,
    totalPackagesSold: totalOverallPackagesSold,
    totalSales: totalOverallSales,
    monthlySales: overallMonthlySales,
    year: year,
    quarter: quarter,
    timezone: timezone,
  };

  // Compile list of atomic/batch writes with deterministic paths
  const writes = [];
  const rootPath = `manager_dashboard/${quarterInfo.periodId}`;
  writes.push({
    path: rootPath,
    data: dashboardDoc,
  });

  for (const trainer of trainersProjection) {
    const trainerPath = `${rootPath}/trainers/${trainer.id}`;
    writes.push({
      path: trainerPath,
      data: trainer.doc,
    });

    for (const client of trainer.clients) {
      const clientPath = `${trainerPath}/clients/${client.id}`;
      writes.push({
        path: clientPath,
        data: client.doc,
      });

      for (const att of client.attendance) {
        const attendancePath = `${clientPath}/attendance/${att.id}`;
        writes.push({
          path: attendancePath,
          data: att.doc,
        });
      }
    }
  }

  return {
    periodId: quarterInfo.periodId,
    dashboard: dashboardDoc,
    trainers: trainersProjection,
    writes: writes,
  };
}

/**
 * Fetch required source collections from Firestore
 */
async function fetchSourceDataFromFirestore(db) {
  // 1. Fetch Users
  const usersSnap = await db.collection('users').get();
  const users = usersSnap.docs.map(d => ({
    ...d.data(),
        legacyId: d.data().id ?? null,
        id: d.id,
  }));

  // 2. Fetch Package Sales
  const salesSnap = await db.collection('package_sales').get();
  const packageSales = salesSnap.docs.map(d => ({
    ...d.data(),
        legacyId: d.data().id ?? null,
        id: d.id,
  }));

  // 3. Fetch Clients and subcollections (packages & sessions)
  const clientsSnap = await db.collection('clients').get();
  const clients = [];

  for (const clientDoc of clientsSnap.docs) {
    const clientData = {
      ...clientDoc.data(),
            legacyId: clientDoc.data().id ?? null,
            id: clientDoc.id,
    };

    // Subcollections reference helper
    const ref = clientDoc.ref || clientDoc.reference || (db.collection('clients').doc(clientDoc.id));

    // Fetch packages subcollection
    const pkgSnap = await ref.collection('packages').get();
    clientData.packages = pkgSnap.docs.map(p => ({
      ...p.data(),
      legacyId: p.data().id ?? null,
      id: p.id,
    }));

    // Fetch sessions subcollection
    const sessSnap = await ref.collection('sessions').get();
    clientData.sessions = sessSnap.docs.map(s => ({
      ...s.data(),
      legacyId: s.data().id ?? null,
      id: s.id,
    }));

    clients.push(clientData);
  }

  function legacyIndex(items) {
    const index = new Map();
    for (const item of items) {
      if (item.legacyId === null) continue;
      const key = String(item.legacyId);
      if (index.has(key)) index.set(key, null); // duplicate legacy ID: refuse ambiguity
      else index.set(key, item.id);
    }
    return index;
  }
  const userByLegacy = legacyIndex(users);
  const clientByLegacy = legacyIndex(clients);
  for (const sale of packageSales) {
    const clientKey = String(sale.clientId ?? '');
    const trainerKey = String(sale.trainerId ?? '');
    sale.clientId = clientByLegacy.has(clientKey) ? clientByLegacy.get(clientKey) : clientKey;
    sale.trainerId = userByLegacy.has(trainerKey) ? userByLegacy.get(trainerKey) : trainerKey;
  }
  return { users, packageSales, clients };
}

const FIRESTORE_MAX_BATCH_SIZE = 500;

/**
 * Commit writes in Firestore batches (max 500 per batch)
 */
async function commitProjectionToFirestore(db, writes = []) {
  if (writes.length === 0) {
    return { committedCount: 0, batchCount: 0 };
  }

  let batchCount = 0;
  for (let i = 0; i < writes.length; i += FIRESTORE_MAX_BATCH_SIZE) {
    const chunk = writes.slice(i, i + FIRESTORE_MAX_BATCH_SIZE);
    const batch = db.batch();

    for (const item of chunk) {
      const docRef = db.doc(item.path);
      batch.set(docRef, item.data, { merge: true });
    }

    await batch.commit();
    batchCount++;
  }

  return {
    committedCount: writes.length,
    batchCount: batchCount,
  };
}

/**
 * Execute the projection job end-to-end
 */
async function runProjectionJob(db, options = {}) {
  const parsed = options.project ? options : parseArgs(options);

  const sourceData = await fetchSourceDataFromFirestore(db);
  const projection = buildManagerDashboardProjection(sourceData, parsed);

  if (parsed.apply && !parsed.dryRun) {
    throw new Error('Legacy apply disabled: use reconcile.cjs with emulator and exclusive backup. Production financial verification is required.');
    const commitResult = await commitProjectionToFirestore(db, projection.writes);
    return {
      ...projection,
      dryRun: false,
      apply: true,
      commitResult,
    };
  }

  return {
    ...projection,
    dryRun: true,
    apply: false,
    writesCount: projection.writes.length,
  };
}

module.exports = {
  ALLOWED_PROJECT,
  DEFAULT_TIMEZONE,
  DEFAULT_QUARTERLY_TARGET,
  FIRESTORE_MAX_BATCH_SIZE,
  parseArgs,
  parseDateInTimezone,
  getQuarterInfo,
  isValidSale,
  deduplicateSales,
  buildManagerDashboardProjection,
  fetchSourceDataFromFirestore,
  commitProjectionToFirestore,
  runProjectionJob,
};
