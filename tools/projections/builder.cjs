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

  if (!dateInput) {
    jsDate = new Date();
  } else if (dateInput instanceof Date) {
    jsDate = dateInput;
  } else if (typeof dateInput.toDate === 'function') {
    jsDate = dateInput.toDate();
  } else if (typeof dateInput === 'object' && typeof dateInput.seconds === 'number') {
    jsDate = new Date(dateInput.seconds * 1000 + (dateInput.nanoseconds || 0) / 1000000);
  } else if (typeof dateInput === 'string' || typeof dateInput === 'number') {
    jsDate = new Date(dateInput);
  } else {
    jsDate = new Date();
  }

  if (isNaN(jsDate.getTime())) {
    throw new FormatException(`Tanggal tidak valid: ${dateInput}`);
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
 * Check if a package sale is valid (not cancelled/refunded/void)
 */
function isValidSale(sale) {
  if (!sale) return false;
  const status = String(sale.status || 'valid').toLowerCase().trim();
  return status !== 'cancelled' && status !== 'refunded' && status !== 'void';
}

/**
 * Deduplicate package sales by ID, retaining only valid records
 */
function deduplicateSales(sales = []) {
  const seen = new Set();
  const validList = [];

  for (const sale of sales) {
    if (!sale) continue;
    const id = sale.id || sale.saleId;
    if (!id) continue;

    if (seen.has(id)) {
      continue;
    }
    seen.add(id);

    if (isValidSale(sale)) {
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

  // 2. Deduplicate and filter package sales for target quarter & year
  const rawSales = sourceData.packageSales || [];
  const dedupedSales = deduplicateSales(rawSales);

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
  const rawClients = sourceData.clients || [];
  const clientsByTrainer = new Map();

  for (const client of rawClients) {
    if (!client || !client.id) continue;
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
      status: client.status || 'active',
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

    // TRAINER ALLOWLIST
    // EXCLUDES: private phone, email, personal address, bank details
    const trainerDoc = {
      name: trainer.displayName || trainer.name || 'PT',
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
    id: d.id,
    ...d.data(),
  }));

  // 2. Fetch Package Sales
  const salesSnap = await db.collection('package_sales').get();
  const packageSales = salesSnap.docs.map(d => ({
    id: d.id,
    ...d.data(),
  }));

  // 3. Fetch Clients and subcollections (packages & sessions)
  const clientsSnap = await db.collection('clients').get();
  const clients = [];

  for (const clientDoc of clientsSnap.docs) {
    const clientData = {
      id: clientDoc.id,
      ...clientDoc.data(),
    };

    // Subcollections reference helper
    const ref = clientDoc.ref || clientDoc.reference || (db.collection('clients').doc(clientDoc.id));

    // Fetch packages subcollection
    try {
      const pkgSnap = await ref.collection('packages').get();
      clientData.packages = pkgSnap.docs.map(p => ({
        id: p.id,
        ...p.data(),
      }));
    } catch (_) {
      clientData.packages = [];
    }

    // Fetch sessions subcollection
    try {
      const sessSnap = await ref.collection('sessions').get();
      clientData.sessions = sessSnap.docs.map(s => ({
        id: s.id,
        ...s.data(),
      }));
    } catch (_) {
      clientData.sessions = [];
    }

    clients.push(clientData);
  }

  return {
    users,
    packageSales,
    clients,
  };
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
