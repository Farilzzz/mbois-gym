# Manager Dashboard Projections

This package provides trusted Firebase Admin SDK tools to compute, validate, and backfill isolated read-models for the Manager Dashboard under:
`manager_dashboard/{year}-Q{quarter}/trainers/{trainerId}/clients/{clientId}/attendance/{sessionId}`

## Architecture & Security Model

1. **Read-Only / Isolated Materialization**
   - The Flutter mobile application manager views read exclusively from `manager_dashboard/{periodId}`.
   - Managers never query raw `clients/*`, `users/*`, or `package_sales/*` directly, preventing exposure of sensitive clinical/workout records.
   - Projections enforce a strict allowlist: attendance includes only session numbers, dates, and statuses (excluding private notes, medical logs, workout sets, and signatures).

2. **Canonical UID & Identity Preservation**
   - Documents in Firestore have canonical string IDs (`d.id`). Previous SQLite migrations embedded integer `id` fields in document bodies.
   - In `fetchSourceDataFromFirestore`, canonical Firestore document IDs always take precedence over embedded legacy integer fields (`{ ...d.data(), id: d.id, legacyId: d.data().id }`).
   - Legacy numeric references in `package_sales` (`clientId` or `trainerId` as integer/strings) are cross-referenced and resolved to canonical Firestore UIDs.

3. **Fail-Closed Sales & Ownership Validation**
   - Transactions in `package_sales` must have:
     - Strict `status === 'valid'` (rejects undefined, pending, cancelled, refunded, void).
     - Valid finite price (`>= 0`, not NaN, not Infinity).
     - Valid ISO-8601 or Firestore timestamp within legitimate date bounds.
     - Single, unambiguous trainer ownership: client must have exactly one assigned trainer matching `sale.trainerId`.
     - Non-cancelled client lifecycle: clients cancelled without completed sessions disqualify related sales.
     - Ambiguous or conflicting duplicates (differing prices/fields with the same ID) are disqualified.

4. **Idempotent Backfill & Reconciliation (`reconcile.cjs`)**
   - Supports safe dry-run comparison between live Firestore documents and calculated projection read-models.
   - Tracks stale documents (e.g. deleted clients/trainers or previous un-pruned projection runs) and plans deletions deepest-first.
   - Strict production safety gate: writes (`--apply`) refuse execution unless `FIRESTORE_EMULATOR_HOST` is set, preventing unintended production overwrites from developer workstations.
   - Generates an exclusive backup (`O_EXCL | O_CREAT`) before modifying records.

## Usage

```bash
# Dry run for 2026 Q4 (safe, read-only)
node tools/projections/cli.cjs --project mbois-gym --year 2026 --quarter 4 --dry-run

# Run automated tests
npm test
```
