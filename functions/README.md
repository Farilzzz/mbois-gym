# Cloud Functions - Manager Dashboard Projection Automation

This directory contains prepared 2nd generation Cloud Functions to automatically synchronize manager projections whenever source documents (`users`, `clients`, `package_sales`) change.

## Architecture

- **Trigger**: `onDocumentWritten('{sourceCollection}/{sourceId}')` (Firestore event triggers).
- **Region**: `asia-southeast1` (Jakarta/Singapore nearest region).
- **Runtime**: Node.js 22.
- **Handler**: `index.cjs` imports the verified builder logic from `tools/projections/builder.cjs` and recalculates the active period's projection incrementally.

## Deployment & Billing Safety Note

- Per project instructions, this function is **prepared only**.
- **DO NOT DEPLOY** (`firebase deploy --only functions`) without explicit authorization and verified Google Cloud billing activation.
- Untrusted client SDK writes to `package_sales` should be prohibited in security rules (`allow write: if false;`), routing sales recording exclusively through trusted Cloud Functions or Admin SDK scripts to prevent fabricated sales records.
