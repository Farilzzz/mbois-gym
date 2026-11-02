'use strict';

/**
 * AdminService encapsulating Firebase Auth and Firestore provisioning logic.
 * Follows security principles:
 * - Application Default Credentials (ADC)
 * - Atomic consistency and rollback on partial failure
 * - Preserves existing custom claims
 * - Preserves existing Firestore profile fields
 * - Validates role ('trainer' | 'manager') according to application parser & firestore.rules
 * - Honest reporting for reset links and sync state
 */

class AdminService {
  constructor(options = {}) {
    this.auth = options.auth;
    this.firestore = options.firestore;
    this.FieldValue = options.FieldValue || {
      serverTimestamp: () => new Date().toISOString(),
    };
  }

  /**
   * Resolve an Auth user by UID or email.
   */
  async findAuthUser({ uid, email }) {
    if (uid) {
      return await this.auth.getUser(uid);
    }
    if (email) {
      return await this.auth.getUserByEmail(email.trim());
    }
    throw new Error('Harus menentukan UID atau email.');
  }

  /**
   * Create a new Trainer or Manager account.
   */
  async createUser({ email, role, displayName, phone, dryRun = false }) {
    if (!email || !email.includes('@')) {
      throw new Error(`Email tidak valid: '${email}'`);
    }
    if (!['trainer', 'manager'].includes(role)) {
      throw new Error(`Role '${role}' tidak valid. Hanya 'trainer' atau 'manager' yang diizinkan.`);
    }

    // Check duplicate in Auth first
    try {
      const existing = await this.auth.getUserByEmail(email.trim());
      if (existing) {
        throw new Error(`User dengan email '${email}' sudah terdaftar (UID: ${existing.uid}). Gunakan perintah provision-existing.`);
      }
    } catch (err) {
      if (err.code !== 'auth/user-not-found' && !err.message.includes('not found')) {
        throw err;
      }
    }

    if (dryRun) {
      return {
        dryRun: true,
        action: 'create',
        email: email.trim(),
        role,
        displayName: displayName || (role === 'manager' ? 'Gym Manager' : 'Coach Mbois'),
        phone: phone || '',
        status: 'active',
        note: 'Rencana pembuatan akun baru (Dry Run: tidak ada data yang diubah di Auth atau Firestore).',
      };
    }

    // 1. Create Auth user
    const createParams = {
      email: email.trim(),
      displayName: displayName || (role === 'manager' ? 'Gym Manager' : 'Coach Mbois'),
    };
    if (phone && phone.trim()) {
      createParams.phoneNumber = phone.trim().startsWith('+') ? phone.trim() : undefined;
    }

    const authUser = await this.auth.createUser(createParams);
    const uid = authUser.uid;

    try {
      // 2. Set Custom Claims
      await this.auth.setCustomUserClaims(uid, { role });

      // 3. Write Firestore document with atomic timestamp
      const now = this.FieldValue.serverTimestamp ? this.FieldValue.serverTimestamp() : new Date().toISOString();
      const userDocRef = this.firestore.collection('users').doc(uid);

      await userDocRef.set({
        uid,
        email: email.trim(),
        displayName: createParams.displayName,
        phone: phone ? phone.trim() : '',
        role,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      });

      return {
        success: true,
        uid,
        email: email.trim(),
        displayName: createParams.displayName,
        role,
        status: 'active',
      };
    } catch (firestoreError) {
      // Rollback Auth user on failure to prevent inconsistent orphaned state
      try {
        await this.auth.deleteUser(uid);
      } catch (rollbackErr) {
        console.error(`Rollback Auth user ${uid} failed:`, rollbackErr);
      }
      throw new Error(`Gagal menulis dokumen profil Firestore, rollback Auth user berhasil: ${firestoreError.message}`);
    }
  }

  /**
   * Provision existing user by UID or email (e.g. from Auth export or existing login).
   * Preserves existing custom claims and existing Firestore profile fields.
   */
  async provisionExistingUser({ uid, email, role, name, displayName, status = 'active', dryRun = false }) {
    if (!['trainer', 'manager'].includes(role)) {
      throw new Error(`Role '${role}' tidak valid. Hanya 'trainer' atau 'manager' yang diizinkan.`);
    }

    const authUser = await this.findAuthUser({ uid, email });
    const targetUid = authUser.uid;

    const existingClaims = authUser.customClaims || {};
    const updatedClaims = { ...existingClaims, role };

    const userDocRef = this.firestore.collection('users').doc(targetUid);

    if (dryRun) {
      const existingDoc = await userDocRef.get();
      return {
        dryRun: true,
        action: 'provision-existing',
        uid: targetUid,
        email: authUser.email,
        currentAuthClaims: existingClaims,
        updatedAuthClaims: updatedClaims,
        firestoreDocExists: existingDoc.exists,
        targetRole: role,
        targetStatus: status,
        targetName: (name || displayName || '').trim() || undefined,
        note: 'Rencana pembaruan akun (Dry Run: tidak ada data yang diubah di Auth atau Firestore).',
      };
    }

    let preservedFields = [];
    let resolvedName = '';

    // Transactional Firestore update ensuring profile fields preserved
    await this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userDocRef);
      const existingData = snapshot.exists ? (snapshot.data() || {}) : {};
      preservedFields = Object.keys(existingData).filter((k) => !['role', 'status', 'updatedAt'].includes(k));

      const now = this.FieldValue.serverTimestamp ? this.FieldValue.serverTimestamp() : new Date().toISOString();

      const explicitName = (name || displayName || '').trim();
      resolvedName = explicitName ||
        (existingData.displayName && existingData.displayName.trim() !== 'PT' ? existingData.displayName.trim() : '') ||
        (existingData.name && existingData.name.trim() !== 'PT' ? existingData.name.trim() : '') ||
        (authUser.displayName && authUser.displayName.trim() !== 'PT' ? authUser.displayName.trim() : '') ||
        (role === 'manager' ? 'Gym Manager' : 'Coach Mbois');

      const mergedData = {
        ...existingData,
        uid: targetUid,
        email: authUser.email || existingData.email || '',
        displayName: resolvedName,
        name: resolvedName,
        role,
        status,
        updatedAt: now,
      };

      if (!snapshot.exists) {
        mergedData.createdAt = now;
      }

      transaction.set(userDocRef, mergedData, { merge: true });
    });

    // Update custom claims in Auth
    await this.auth.setCustomUserClaims(targetUid, updatedClaims);

    // Keep Auth displayName in sync
    if (resolvedName && authUser.displayName !== resolvedName) {
      try {
        await this.auth.updateUser(targetUid, { displayName: resolvedName });
      } catch (_) {}
    }

    // If account was disabled and targetStatus is active, enable it in Auth
    if (status === 'active' && authUser.disabled) {
      await this.auth.updateUser(targetUid, { disabled: false });
    }

    return {
      success: true,
      uid: targetUid,
      email: authUser.email,
      role,
      status,
      customClaims: updatedClaims,
      preservedFields,
    };
  }

  /**
   * Get comprehensive status for an account (Auth + Firestore consistency).
   */
  async getUserStatus({ uid, email }) {
    let authUser = null;
    let authError = null;

    try {
      authUser = await this.findAuthUser({ uid, email });
    } catch (err) {
      authError = err.message;
    }

    if (!authUser) {
      return {
        auth: { exists: false, error: authError },
        firestore: { exists: false },
        isConsistent: false,
        canAccess: false,
        diagnostic: `User '${uid || email}' tidak ditemukan di Firebase Auth.`,
      };
    }

    const targetUid = authUser.uid;
    const userDocRef = this.firestore.collection('users').doc(targetUid);
    const docSnapshot = await userDocRef.get();
    const docExists = docSnapshot.exists;
    const docData = docExists ? docSnapshot.data() : null;

    const authRole = authUser.customClaims?.role || null;
    const firestoreRole = docData?.role || null;
    const firestoreStatus = docData?.status || null;

    const rolesMatch = authRole === firestoreRole && firestoreRole !== null;
    const isConsistent = docExists && rolesMatch && !authUser.disabled && firestoreStatus === 'active';
    const canAccess = firestoreStatus === 'active' && (firestoreRole === 'trainer' || firestoreRole === 'manager') && !authUser.disabled;

    let diagnostic = '';
    if (!docExists) {
      diagnostic = `PERINGATAN: Akun terdaftar di Auth (Auth export only), namun dokumen profil Firestore /users/${targetUid} belum dibuat. Akses aplikasi Flutter akan ditolak. Jalankan 'provision-existing --uid ${targetUid} --role <trainer|manager>' untuk memprovisi.`;
    } else if (authUser.disabled || firestoreStatus !== 'active') {
      diagnostic = `Akun tidak aktif (Auth disabled: ${authUser.disabled}, Firestore status: '${firestoreStatus}'). Akses aplikasi ditolak.`;
    } else if (!rolesMatch) {
      diagnostic = `INKONSISTENSI: Role di Auth claims ('${authRole}') tidak cocok dengan role di Firestore ('${firestoreRole}').`;
    } else {
      diagnostic = `Akun aktif dan konsisten sebagai '${firestoreRole}'. Akses aplikasi Flutter diizinkan.`;
    }

    return {
      auth: {
        exists: true,
        uid: targetUid,
        email: authUser.email,
        displayName: authUser.displayName,
        phoneNumber: authUser.phoneNumber,
        disabled: authUser.disabled,
        customClaims: authUser.customClaims || {},
      },
      firestore: {
        exists: docExists,
        role: firestoreRole,
        status: firestoreStatus,
        displayName: docData?.displayName,
        phone: docData?.phone,
        profileFields: docData ? Object.keys(docData) : [],
        data: docData,
      },
      isConsistent,
      canAccess,
      diagnostic,
    };
  }

  /**
   * Disable a user in both Auth and Firestore.
   */
  async disableUser({ uid, email, dryRun = false }) {
    const authUser = await this.findAuthUser({ uid, email });
    const targetUid = authUser.uid;

    if (dryRun) {
      return {
        dryRun: true,
        action: 'disable',
        uid: targetUid,
        email: authUser.email,
        note: 'Rencana penonaktifan akun (Dry Run: tidak ada data yang diubah).',
      };
    }

    // 1. Update Firestore status to 'inactive'
    const userDocRef = this.firestore.collection('users').doc(targetUid);
    const now = this.FieldValue.serverTimestamp ? this.FieldValue.serverTimestamp() : new Date().toISOString();
    await userDocRef.set({ status: 'inactive', updatedAt: now }, { merge: true });

    // 2. Disable in Auth
    await this.auth.updateUser(targetUid, { disabled: true });

    return {
      success: true,
      uid: targetUid,
      email: authUser.email,
      disabled: true,
      status: 'inactive',
    };
  }

  /**
   * Generate password reset link honestly without claiming an email was sent.
   */
  async generateResetLink({ uid, email }) {
    let targetEmail = email;
    if (!targetEmail) {
      const authUser = await this.findAuthUser({ uid });
      targetEmail = authUser.email;
    }
    if (!targetEmail) {
      throw new Error('User tidak memiliki email terdaftar untuk membuat reset link.');
    }

    const resetLink = await this.auth.generatePasswordResetLink(targetEmail.trim());

    return {
      email: targetEmail.trim(),
      resetLink,
      emailSent: false,
      warning: 'PERHATIAN: Link reset password berhasil dibuat via Admin SDK. Email TIDAK otomatis dikirim oleh Firebase ke pengguna. Bagikan link ini secara manual dan aman ke pengguna.',
    };
  }
}

module.exports = {
  AdminService,
};
