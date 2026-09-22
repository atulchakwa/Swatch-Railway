/**
 * ═════════════════════════════════════════════════════════════════════════════
 * SWACHH RAILWAYS — ANNEXURE-4B BILLING RULE ENGINE
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * Firestore Collections (created on first write):
 *   • annexureContractItems   – 40 contractual items per contract
 *   • annexureAreaComponents  – operational area breakdown under each item
 *   • annexureExecutions      – per-occurrence execution records
 *   • annexureBillingDeductions – immutable billing snapshots
 *   • annexureWeightageTransfers – audit trail for weightage moves
 *   • audit_logs              – shared audit collection (existing)
 */

import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError, ForbiddenError } from '../errors/index.js';
import { auditService } from './auditService.js';
import logger from '../logger/index.js';
import {
  VALID_EXEC_STATUSES,
  VALID_UNITS,
  dailyMoneyValue,
  missedDeduction,
  areaAllocationCheck,
  areaWeightageChangeCheck,
  partialDeductionNote,
  transferUnavailableWeightage,
  addNewItemWeightage,
  contractTotalWarning,
  round2,
} from './annexureRules.js';

// ─── 40 Master Contractual Items (Annexure-4B) ─────────────────────────────
const MASTER_ITEMS = [
  { itemNumber: 1, description: 'Scrubbing, wet cleaning of floor, Concourse, Platform, passages, staircase and different types of floor area provided in station building including waiting rooms, all railway/other offices, retiring rooms', contractualWeightage: 40.00, frequency: 'Twice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 2, description: 'Cleaning and washing of Track plinth', contractualWeightage: 20.00, frequency: 'Twice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 3, description: 'Cleaning of passages & different types of floor area provided in all operation and utility rooms', contractualWeightage: 8.00, frequency: 'Twice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 4, description: 'Cleaning of different types of finishing works in wall cladding', contractualWeightage: 4.00, frequency: 'Twice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 5, description: 'Cleaning of different types of doors/windows frames and shutters/louvers', contractualWeightage: 1.50, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 6, description: 'Cleaning of glasses fixed to doors/windows/ticket counters and elsewhere in station area', contractualWeightage: 3.50, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 7, description: 'Cleaning of rolling shutters', contractualWeightage: 0.50, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 8, description: 'Cleaning of stainless steel/PVC/MS/wooden hand railing', contractualWeightage: 1.75, frequency: 'Thrice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 9, description: 'Cleaning of suspended ceiling', contractualWeightage: 1.00, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 10, description: 'Cleaning of roof ceiling etc.', contractualWeightage: 3.00, frequency: 'Once in a fortnight', quantityMode: 'As available' },
  { itemNumber: 11, description: 'Cleaning & sanitation of toilets & bath rooms (only staff toilets)', contractualWeightage: 2.00, frequency: 'Thrice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 12, description: 'Cleaning and attention of all drains at all levels', contractualWeightage: 0.75, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 13, description: 'Cleaning of portable fire extinguishers/smoke detectors/fire detectors', contractualWeightage: 0.20, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 14, description: 'Cleaning of fire pump panel', contractualWeightage: 0.10, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 15, description: 'Cleaning of butterfly valves/landing valves/internal hydrants/piping/fire hydrant panels', contractualWeightage: 0.20, frequency: 'Once in a fortnight', quantityMode: 'As available' },
  { itemNumber: 16, description: 'Cleaning of indoor light fittings & accessories', contractualWeightage: 0.20, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 17, description: 'Cleaning of switch boards/panels/distribution boards', contractualWeightage: 0.20, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 18, description: 'Cleaning of fans/exhaust fans & accessories', contractualWeightage: 0.10, frequency: 'Once in a fortnight', quantityMode: 'As available' },
  { itemNumber: 19, description: 'Cleaning of external lighting fittings & accessories', contractualWeightage: 0.20, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 20, description: 'Cleaning of escalators', contractualWeightage: 1.00, frequency: 'Thrice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 21, description: 'Cleaning of lifts', contractualWeightage: 1.00, frequency: 'Thrice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 22, description: 'Cleaning of computers/accessories/telephone sets/miscellaneous items', contractualWeightage: 0.30, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 23, description: 'Cleaning of furniture/office equipment etc.', contractualWeightage: 0.30, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 24, description: 'Cleaning of DG room with DG set & connected equipment', contractualWeightage: 0.20, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 25, description: 'Cleaning of HT & LT equipment available in ASS Room', contractualWeightage: 0.75, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 26, description: 'Cleaning of LT equipment available in LT Switch Room', contractualWeightage: 0.30, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 27, description: 'Cleaning of equipment available in UPS Room', contractualWeightage: 0.30, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 28, description: 'Cleaning of Pump Room with equipment', contractualWeightage: 0.30, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 29, description: 'Cleaning of equipment in Signaling Room other than separately covered items', contractualWeightage: 0.30, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 30, description: 'Cleaning of equipment in Station Control Room, Booking Offices and Excess Fare Office', contractualWeightage: 0.30, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 31, description: 'Cleaning of cable trays, cable trench covers, Undercroft area etc.', contractualWeightage: 0.40, frequency: 'Once in a fortnight', quantityMode: 'As available' },
  { itemNumber: 32, description: 'Cleaning of air conditioners', contractualWeightage: 0.20, frequency: 'Once in a fortnight', quantityMode: 'As available' },
  { itemNumber: 33, description: 'Cleaning of equipment available in Telecom Room', contractualWeightage: 0.25, frequency: 'Once in a week', quantityMode: 'As available' },
  { itemNumber: 34, description: 'Cleaning of automatic fare collection system, TVM and security equipment', contractualWeightage: 0.60, frequency: 'Thrice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 35, description: 'Cleaning of underground/overhead water tank', contractualWeightage: 0.30, frequency: 'Once in a month', quantityMode: 'As available' },
  { itemNumber: 36, description: 'Cleaning of pavement/circulating area near station entry/exit, Subway and FOB', contractualWeightage: 4.00, frequency: 'Twice in each shift and as and when required', quantityMode: 'As available' },
  { itemNumber: 37, description: 'Cleaning of Sign Boards/Name Boards/Notice Boards/Advertisement Boards', contractualWeightage: 0.50, frequency: 'Once in a day', quantityMode: 'As available' },
  { itemNumber: 38, description: 'Supply of dust bins/biodegradable garbage bags and disposal of waste etc.', contractualWeightage: 0.20, frequency: 'Once in each shift and as and when required', quantityMode: 'As required' },
  { itemNumber: 39, description: 'Disposal of waste/garbage/dust/rubbish and cleaning of dust bins', contractualWeightage: 0.20, frequency: 'Once in each shift and as and when required', quantityMode: 'As required' },
  { itemNumber: 40, description: 'Light Pest Control', contractualWeightage: 0.50, frequency: 'Once in a month', quantityMode: 'As required' }
];

class AnnexureBillingService {

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — CONTRACT ITEMS (LEVEL 1)
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Seed the 40 contractual items for a given contract.
   * Idempotent — skips if items already exist.
   */
  async seedContractItems(contractId, user) {
    if (!contractId) throw new ValidationError('contractId is required');

    // Verify contract exists
    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new NotFoundError('Contract not found');

    // Check if already seeded
    const existingSnap = await db.collection('annexureContractItems')
      .where('contractId', '==', contractId)
      .limit(1).get();
    if (!existingSnap.empty) {
      return { message: 'Contract items already seeded', count: 0, alreadySeeded: true };
    }

    const batch = db.batch();
    const itemIds = [];

    for (const master of MASTER_ITEMS) {
      const ref = db.collection('annexureContractItems').doc();
      const doc = {
        uid: ref.id,
        contractId,
        itemNumber: master.itemNumber,
        contractualDescription: master.description,
        contractualWeightage: master.contractualWeightage,
        effectiveWeightage: master.contractualWeightage, // may differ after transfers
        frequency: master.frequency,
        quantityMode: master.quantityMode,
        status: 'ACTIVE', // ACTIVE | NOT_AVAILABLE
        weightageTransferred: false,
        transferredTo: null,
        transferredWeightage: 0,
        receivedWeightage: 0,
        remarks: null,
        partialDeductionAllowed: false, // must be explicitly enabled per contract
        createdAt: new Date().toISOString(),
        createdBy: user?.uid || 'system'
      };
      batch.set(ref, doc);
      itemIds.push(ref.id);
    }

    await batch.commit();

    if (user?.uid) {
      await auditService.logAudit(
        'ANNEXURE_ITEMS_SEEDED', user.uid, user.fullName || 'System',
        contractId, 'annexureContractItems',
        `40 Annexure-4B items seeded for contract ${contractId}`,
        { count: 40 }
      );
    }

    // Validate total
    const total = MASTER_ITEMS.reduce((sum, m) => sum + m.contractualWeightage, 0);
    const warnings = [];
    const warning = contractTotalWarning(total);
    if (warning) warnings.push(warning);

    return { message: 'Contract items seeded successfully', count: 40, itemIds, totalWeightage: total, warnings };
  }

  /**
   * Get all contract items for a contract with area summaries.
   */
  async getContractItems(contractId, user) {
    if (!contractId) throw new ValidationError('contractId is required');

    const snapshot = await db.collection('annexureContractItems')
      .where('contractId', '==', contractId)
      .get();

    if (snapshot.empty) return { count: 0, items: [], totalWeightage: 0, warnings: [] };

    const items = [];
    snapshot.forEach(doc => items.push({ id: doc.id, ...doc.data() }));
    items.sort((a, b) => a.itemNumber - b.itemNumber);

    // Enrich with area allocation summary
    for (const item of items) {
      const areasSnap = await db.collection('annexureAreaComponents')
        .where('contractItemId', '==', item.uid)
        .where('status', '==', 'ACTIVE')
        .get();
      let allocatedWeightage = 0;
      const areas = [];
      areasSnap.forEach(d => {
        const areaData = d.data();
        allocatedWeightage += areaData.allocatedWeightage || 0;
        areas.push({ id: d.id, ...areaData });
      });
      item.allocatedWeightage = parseFloat(allocatedWeightage.toFixed(4));
      item.remainingWeightage = parseFloat((item.effectiveWeightage - allocatedWeightage).toFixed(4));
      item.areaCount = areas.length;
      item.areas = areas;
    }

    const totalWeightage = items.reduce((s, i) => s + i.effectiveWeightage, 0);
    const warnings = [];
    const warning = contractTotalWarning(totalWeightage);
    if (warning) warnings.push(warning);

    return { count: items.length, items, totalWeightage: parseFloat(totalWeightage.toFixed(2)), warnings };
  }

  /**
   * Get a single contract item by ID.
   */
  async getContractItemById(itemId) {
    const doc = await db.collection('annexureContractItems').doc(itemId).get();
    if (!doc.exists) throw new NotFoundError('Contract item not found');
    const item = { id: doc.id, ...doc.data() };

    // Fetch areas
    const areasSnap = await db.collection('annexureAreaComponents')
      .where('contractItemId', '==', item.uid)
      .get();
    let allocatedWeightage = 0;
    const areas = [];
    areasSnap.forEach(d => {
      const areaData = d.data();
      if (areaData.status === 'ACTIVE') allocatedWeightage += areaData.allocatedWeightage || 0;
      areas.push({ id: d.id, ...areaData });
    });
    item.allocatedWeightage = parseFloat(allocatedWeightage.toFixed(4));
    item.remainingWeightage = parseFloat((item.effectiveWeightage - allocatedWeightage).toFixed(4));
    item.areas = areas;

    return item;
  }

  /**
   * Update a contract item (remarks, partialDeductionAllowed, frequency override).
   * Cannot change contractualWeightage directly.
   */
  async updateContractItem(itemId, updates, user) {
    const ref = db.collection('annexureContractItems').doc(itemId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Contract item not found');
    const oldData = doc.data();

    const allowed = ['remarks', 'partialDeductionAllowed', 'frequency'];
    const safeUpdates = {};
    for (const key of allowed) {
      if (updates[key] !== undefined) safeUpdates[key] = updates[key];
    }
    safeUpdates.updatedAt = new Date().toISOString();
    safeUpdates.updatedBy = user.uid;

    await ref.update(safeUpdates);

    await auditService.logAudit(
      'ANNEXURE_ITEM_UPDATED', user.uid, user.fullName || 'User',
      itemId, 'annexureContractItems',
      `Contract item ${oldData.itemNumber} updated`,
      { oldValues: { remarks: oldData.remarks, partialDeductionAllowed: oldData.partialDeductionAllowed, frequency: oldData.frequency }, newValues: safeUpdates }
    );

    return { message: 'Contract item updated', uid: itemId };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — ITEM AVAILABILITY & WEIGHTAGE TRANSFER
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Mark an item as NOT_AVAILABLE and transfer its weightage to Item 1.
   */
  async markItemUnavailable(itemId, user, reason) {
    const itemRef = db.collection('annexureContractItems').doc(itemId);
    const itemDoc = await itemRef.get();
    if (!itemDoc.exists) throw new NotFoundError('Contract item not found');
    const itemData = itemDoc.data();

    if (itemData.status === 'NOT_AVAILABLE') {
      throw new ValidationError('Item is already marked as NOT_AVAILABLE');
    }
    if (itemData.itemNumber === 1) {
      throw new ValidationError('Item 1 cannot be marked as unavailable');
    }

    // Find Item 1 for this contract
    const item1Snap = await db.collection('annexureContractItems')
      .where('contractId', '==', itemData.contractId)
      .where('itemNumber', '==', 1)
      .limit(1).get();
    if (item1Snap.empty) throw new NotFoundError('Item 1 not found for this contract');
    const item1Doc = item1Snap.docs[0];
    const item1Data = item1Doc.data();

    const { transferredWeightage, item1After } = transferUnavailableWeightage(
      itemData.effectiveWeightage, item1Data.effectiveWeightage
    );
    const transferAmount = transferredWeightage;

    const batch = db.batch();

    // Update the unavailable item
    batch.update(itemRef, {
      status: 'NOT_AVAILABLE',
      weightageTransferred: true,
      transferredTo: 1,
      transferredWeightage: transferAmount,
      effectiveWeightage: 0,
      updatedAt: new Date().toISOString(),
      updatedBy: user.uid
    });

    // Add weightage to Item 1
    batch.update(item1Doc.ref, {
      effectiveWeightage: item1After,
      receivedWeightage: parseFloat(((item1Data.receivedWeightage || 0) + transferAmount).toFixed(4)),
      updatedAt: new Date().toISOString(),
      updatedBy: user.uid
    });

    // Create transfer record
    const transferRef = db.collection('annexureWeightageTransfers').doc();
    batch.set(transferRef, {
      uid: transferRef.id,
      contractId: itemData.contractId,
      type: 'ITEM_UNAVAILABLE',
      fromItemNumber: itemData.itemNumber,
      fromItemId: itemId,
      toItemNumber: 1,
      toItemId: item1Doc.id,
      weightage: transferAmount,
      reason: reason || `Item ${itemData.itemNumber} not available at station`,
      performedBy: user.uid,
      performedByName: user.fullName || 'User',
      createdAt: new Date().toISOString()
    });

    await batch.commit();

    await auditService.logAudit(
      'ANNEXURE_WEIGHTAGE_TRANSFER', user.uid, user.fullName || 'User',
      itemId, 'annexureContractItems',
      `Item ${itemData.itemNumber} marked NOT_AVAILABLE. ${transferAmount}% transferred to Item 1.`,
      { fromItem: itemData.itemNumber, toItem: 1, weightage: transferAmount, reason }
    );

    return {
      message: `Item ${itemData.itemNumber} marked as unavailable. ${transferAmount}% transferred to Item 1.`,
      transfer: { from: itemData.itemNumber, to: 1, weightage: transferAmount }
    };
  }

  /**
   * Add a new contractual work item (reduces Item 1 weightage).
   */
  async addNewContractItem(contractId, body, user) {
    const { description, weightage, frequency, quantityMode, remarks } = body;
    if (!description || weightage === undefined) {
      throw new ValidationError('description and weightage are required');
    }
    if (weightage <= 0) throw new ValidationError('Weightage must be positive');

    // Find Item 1
    const item1Snap = await db.collection('annexureContractItems')
      .where('contractId', '==', contractId)
      .where('itemNumber', '==', 1)
      .limit(1).get();
    if (item1Snap.empty) throw new NotFoundError('Item 1 not found. Seed items first.');
    const item1Doc = item1Snap.docs[0];
    const item1Data = item1Doc.data();

    const resolved = addNewItemWeightage(item1Data.effectiveWeightage, weightage);
    if (!resolved) {
      throw new ValidationError(`Item 1 only has ${item1Data.effectiveWeightage}% available. Cannot reduce by ${weightage}%.`);
    }
    const newItemWeightage = resolved.newItemWeightage;
    const item1After = resolved.item1After;

    // Find next item number
    const allItemsSnap = await db.collection('annexureContractItems')
      .where('contractId', '==', contractId)
      .get();
    let maxItemNumber = 0;
    allItemsSnap.forEach(d => {
      const n = d.data().itemNumber || 0;
      if (n > maxItemNumber) maxItemNumber = n;
    });
    const newItemNumber = maxItemNumber + 1;

    const batch = db.batch();

    // Create new item
    const newRef = db.collection('annexureContractItems').doc();
    batch.set(newRef, {
      uid: newRef.id,
      contractId,
      itemNumber: newItemNumber,
      contractualDescription: description,
      contractualWeightage: newItemWeightage,
      effectiveWeightage: newItemWeightage,
      frequency: frequency || 'As per contract',
      quantityMode: quantityMode || 'As available',
      status: 'ACTIVE',
      weightageTransferred: false,
      transferredTo: null,
      transferredWeightage: 0,
      receivedWeightage: 0,
      remarks: remarks || null,
      partialDeductionAllowed: false,
      isAdditional: true,
      createdAt: new Date().toISOString(),
      createdBy: user.uid
    });

    // Reduce Item 1
    batch.update(item1Doc.ref, {
      effectiveWeightage: item1After,
      updatedAt: new Date().toISOString(),
      updatedBy: user.uid
    });

    // Transfer record
    const transferRef = db.collection('annexureWeightageTransfers').doc();
    batch.set(transferRef, {
      uid: transferRef.id,
      contractId,
      type: 'NEW_ITEM_ADDED',
      fromItemNumber: 1,
      fromItemId: item1Doc.id,
      toItemNumber: newItemNumber,
      toItemId: newRef.id,
      weightage,
      reason: `New contractual item added: ${description}`,
      performedBy: user.uid,
      performedByName: user.fullName || 'User',
      createdAt: new Date().toISOString()
    });

    await batch.commit();

    await auditService.logAudit(
      'ANNEXURE_NEW_ITEM', user.uid, user.fullName || 'User',
      newRef.id, 'annexureContractItems',
      `New item ${newItemNumber} added (${weightage}%). Item 1 reduced from ${item1Data.effectiveWeightage}% to ${(item1Data.effectiveWeightage - weightage).toFixed(2)}%.`,
      { newItemNumber, description, weightage, item1Before: item1Data.effectiveWeightage, item1After: item1Data.effectiveWeightage - weightage }
    );

    return {
      message: `New item ${newItemNumber} created. Item 1 reduced by ${weightage}%.`,
      uid: newRef.id,
      itemNumber: newItemNumber
    };
  }

  /**
   * Get weightage transfer history for a contract.
   */
  async getWeightageTransfers(contractId) {
    const snap = await db.collection('annexureWeightageTransfers')
      .where('contractId', '==', contractId)
      .get();
    const transfers = [];
    snap.forEach(d => transfers.push({ id: d.id, ...d.data() }));
    transfers.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    return { count: transfers.length, transfers };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — AREA COMPONENTS (LEVEL 2)
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Add an area component under a contract item.
   */
  async addAreaComponent(contractItemId, body, user) {
    const { areaName, areaCode, unit, quantity, rate, allocatedWeightage, frequencyOverride, remarks } = body;
    if (!areaName) throw new ValidationError('areaName is required');
    if (allocatedWeightage === undefined || allocatedWeightage === null) throw new ValidationError('allocatedWeightage is required');
    if (allocatedWeightage < 0) throw new ValidationError('allocatedWeightage cannot be negative');

    if (unit && !VALID_UNITS.includes(unit)) {
      throw new ValidationError(`Invalid unit: ${unit}. Must be one of: ${VALID_UNITS.join(', ')}`);
    }

    // Validate parent item
    const itemDoc = await db.collection('annexureContractItems').doc(contractItemId).get();
    if (!itemDoc.exists) throw new NotFoundError('Contract item not found');
    const itemData = itemDoc.data();

    // Sum existing area allocations
    const existingSnap = await db.collection('annexureAreaComponents')
      .where('contractItemId', '==', contractItemId)
      .where('status', '==', 'ACTIVE')
      .get();
    let currentTotal = 0;
    existingSnap.forEach(d => { currentTotal += d.data().allocatedWeightage || 0; });

    const check = areaAllocationCheck(currentTotal, allocatedWeightage, itemData.effectiveWeightage);
    if (!check.valid) {
      throw new ValidationError(check.error);
    }

    const ref = db.collection('annexureAreaComponents').doc();
    const areaDoc = {
      uid: ref.id,
      contractItemId,
      contractId: itemData.contractId,
      itemNumber: itemData.itemNumber,
      areaName,
      areaCode: areaCode || null,
      unit: unit || null,
      quantity: quantity !== undefined ? parseFloat(quantity) : null,
      rate: rate !== undefined ? parseFloat(rate) : null,
      allocatedWeightage: parseFloat(allocatedWeightage),
      frequencyOverride: frequencyOverride || null,
      status: 'ACTIVE',
      remarks: remarks || null,
      createdAt: new Date().toISOString(),
      createdBy: user.uid
    };

    await ref.set(areaDoc);

    await auditService.logAudit(
      'ANNEXURE_AREA_CREATED', user.uid, user.fullName || 'User',
      ref.id, 'annexureAreaComponents',
      `Area "${areaName}" added under Item ${itemData.itemNumber} with ${allocatedWeightage}% weightage`,
      areaDoc
    );

    return {
      message: `Area "${areaName}" added successfully`,
      uid: ref.id,
      allocatedTotal: check.newTotal,
      remaining: check.remaining
    };
  }

  /**
   * Update an area component.
   */
  async updateAreaComponent(areaId, updates, user) {
    const ref = db.collection('annexureAreaComponents').doc(areaId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Area component not found');
    const oldData = doc.data();

    const allowed = ['areaName', 'areaCode', 'unit', 'quantity', 'rate', 'allocatedWeightage', 'frequencyOverride', 'remarks', 'status'];
    const safeUpdates = {};
    for (const key of allowed) {
      if (updates[key] !== undefined) {
        if (key === 'quantity' || key === 'rate' || key === 'allocatedWeightage') {
          safeUpdates[key] = updates[key] !== null ? parseFloat(updates[key]) : null;
        } else {
          safeUpdates[key] = updates[key];
        }
      }
    }

    // If weightage is changing, validate
    if (safeUpdates.allocatedWeightage !== undefined && safeUpdates.allocatedWeightage !== oldData.allocatedWeightage) {
      if (safeUpdates.allocatedWeightage < 0) throw new ValidationError('allocatedWeightage cannot be negative');

      const itemDoc = await db.collection('annexureContractItems').doc(oldData.contractItemId).get();
      const itemData = itemDoc.data();

      const siblingsSnap = await db.collection('annexureAreaComponents')
        .where('contractItemId', '==', oldData.contractItemId)
        .where('status', '==', 'ACTIVE')
        .get();
      let othersTotal = 0;
      siblingsSnap.forEach(d => {
        if (d.id !== areaId) othersTotal += d.data().allocatedWeightage || 0;
      });

      const changeCheck = areaWeightageChangeCheck(othersTotal, safeUpdates.allocatedWeightage, itemData.effectiveWeightage);
      if (!changeCheck.valid) {
        throw new ValidationError(
          `Area-wise weightage cannot exceed the contractual weightage of this item. ` +
          `Other areas: ${othersTotal.toFixed(2)}%, New value: ${safeUpdates.allocatedWeightage}%, ` +
          `Item limit: ${itemData.effectiveWeightage}%`
        );
      }
    }

    if (safeUpdates.unit && !VALID_UNITS.includes(safeUpdates.unit)) {
      throw new ValidationError(`Invalid unit: ${safeUpdates.unit}. Must be one of: ${VALID_UNITS.join(', ')}`);
    }

    safeUpdates.updatedAt = new Date().toISOString();
    safeUpdates.updatedBy = user.uid;

    await ref.update(safeUpdates);

    await auditService.logAudit(
      'ANNEXURE_AREA_UPDATED', user.uid, user.fullName || 'User',
      areaId, 'annexureAreaComponents',
      `Area "${oldData.areaName}" updated`,
      { oldValues: oldData, newValues: safeUpdates }
    );

    return { message: 'Area component updated', uid: areaId };
  }

  /**
   * Delete (deactivate) an area component.
   */
  async deleteAreaComponent(areaId, user) {
    const ref = db.collection('annexureAreaComponents').doc(areaId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Area component not found');
    const oldData = doc.data();

    await ref.update({
      status: 'INACTIVE',
      updatedAt: new Date().toISOString(),
      updatedBy: user.uid
    });

    await auditService.logAudit(
      'ANNEXURE_AREA_DELETED', user.uid, user.fullName || 'User',
      areaId, 'annexureAreaComponents',
      `Area "${oldData.areaName}" deactivated from Item ${oldData.itemNumber}`,
      { areaName: oldData.areaName, allocatedWeightage: oldData.allocatedWeightage }
    );

    return { message: 'Area component deactivated' };
  }

  /**
   * Get all areas for a specific contract item.
   */
  async getAreasForItem(contractItemId) {
    const snap = await db.collection('annexureAreaComponents')
      .where('contractItemId', '==', contractItemId)
      .get();
    const areas = [];
    snap.forEach(d => areas.push({ id: d.id, ...d.data() }));
    areas.sort((a, b) => (a.areaName || '').localeCompare(b.areaName || ''));

    const activeAreas = areas.filter(a => a.status === 'ACTIVE');
    const allocatedWeightage = activeAreas.reduce((s, a) => s + (a.allocatedWeightage || 0), 0);

    return { count: areas.length, areas, allocatedWeightage: parseFloat(allocatedWeightage.toFixed(2)) };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4 — EXECUTION TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Record an execution.
   */
  async recordExecution(body, user) {
    const { contractItemId, areaComponentId, scheduledDate, occurrenceNumber, status,
            completedQuantity, evidenceUrl, remarks } = body;

    if (!contractItemId || !scheduledDate || !status) {
      throw new ValidationError('contractItemId, scheduledDate, and status are required');
    }
    if (!VALID_EXEC_STATUSES.includes(status)) {
      throw new ValidationError(`Invalid status: ${status}. Must be one of: ${VALID_EXEC_STATUSES.join(', ')}`);
    }

    // Verify item exists
    const itemDoc = await db.collection('annexureContractItems').doc(contractItemId).get();
    if (!itemDoc.exists) throw new NotFoundError('Contract item not found');

    // Verify area if provided
    if (areaComponentId) {
      const areaDoc = await db.collection('annexureAreaComponents').doc(areaComponentId).get();
      if (!areaDoc.exists) throw new NotFoundError('Area component not found');
    }

    const ref = db.collection('annexureExecutions').doc();
    const execDoc = {
      uid: ref.id,
      contractId: itemDoc.data().contractId,
      contractItemId,
      itemNumber: itemDoc.data().itemNumber,
      areaComponentId: areaComponentId || null,
      scheduledDate,
      occurrenceNumber: occurrenceNumber || 1,
      status,
      completedQuantity: completedQuantity !== undefined ? parseFloat(completedQuantity) : null,
      evidenceUrl: evidenceUrl || null,
      remarks: remarks || null,
      executedBy: user.uid,
      executedByName: user.fullName || 'User',
      verifiedBy: null,
      verifiedByName: null,
      createdAt: new Date().toISOString()
    };

    await ref.set(execDoc);

    return { message: 'Execution recorded', uid: ref.id, execution: execDoc };
  }

  /**
   * Update execution status (e.g. verify).
   */
  async updateExecution(executionId, updates, user) {
    const ref = db.collection('annexureExecutions').doc(executionId);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Execution not found');
    const oldData = doc.data();

    const allowed = ['status', 'completedQuantity', 'evidenceUrl', 'remarks', 'verifiedBy', 'verifiedByName'];
    const safeUpdates = {};
    for (const key of allowed) {
      if (updates[key] !== undefined) safeUpdates[key] = updates[key];
    }

    if (updates.verify) {
      safeUpdates.verifiedBy = user.uid;
      safeUpdates.verifiedByName = user.fullName || 'User';
    }

    safeUpdates.updatedAt = new Date().toISOString();
    await ref.update(safeUpdates);

    await auditService.logAudit(
      'ANNEXURE_EXECUTION_UPDATED', user.uid, user.fullName || 'User',
      executionId, 'annexureExecutions',
      `Execution updated for Item ${oldData.itemNumber}`,
      { old: { status: oldData.status }, new: safeUpdates }
    );

    return { message: 'Execution updated', uid: executionId };
  }

  /**
   * Get executions for a contract item or area within a date range.
   */
  async getExecutions(filters) {
    const { contractId, contractItemId, areaComponentId, startDate, endDate, status, limit: lim } = filters;
    let query = db.collection('annexureExecutions');

    if (contractId) query = query.where('contractId', '==', contractId);
    if (contractItemId) query = query.where('contractItemId', '==', contractItemId);
    if (areaComponentId) query = query.where('areaComponentId', '==', areaComponentId);
    if (status) query = query.where('status', '==', status);

    const maxLimit = Math.min(parseInt(lim) || 200, 500);
    const snapshot = await query.limit(maxLimit).get();
    let executions = [];
    snapshot.forEach(d => executions.push({ id: d.id, ...d.data() }));

    // Date filter (in-memory since Firestore string comparison is limited)
    if (startDate) executions = executions.filter(e => e.scheduledDate >= startDate);
    if (endDate) executions = executions.filter(e => e.scheduledDate <= endDate);

    executions.sort((a, b) => (a.scheduledDate || '').localeCompare(b.scheduledDate || '') || (a.occurrenceNumber || 1) - (b.occurrenceNumber || 1));

    return { count: executions.length, executions };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5 — BILLING / DEDUCTION CALCULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Daily Money Value — contractual deduction formula.
   * Formula: Annual Contract Value × Weightage ÷ 365
   * Delegates to the pure rule module (single source of truth).
   */
  calculateDailyMoneyValue(annualContractValue, weightagePercent) {
    return dailyMoneyValue(annualContractValue, weightagePercent);
  }

  /**
   * Calculate deductions for a billing period.
   * This creates IMMUTABLE billing deduction records.
   */
  async calculateBillingDeductions(contractId, billingStart, billingEnd, user) {
    if (!contractId || !billingStart || !billingEnd) {
      throw new ValidationError('contractId, billingStart, and billingEnd are required');
    }

    // Get contract
    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new NotFoundError('Contract not found');
    const contract = contractDoc.data();
    const annualContractValue = contract.contractValue || 0;

    if (!annualContractValue) {
      throw new ValidationError('Contract annual value is not configured');
    }

    // Check for existing finalized bills in this period
    const existingSnap = await db.collection('annexureBillingDeductions')
      .where('contractId', '==', contractId)
      .where('billingStart', '==', billingStart)
      .where('billingEnd', '==', billingEnd)
      .where('status', '==', 'FINALIZED')
      .limit(1).get();
    if (!existingSnap.empty) {
      throw new ValidationError('A finalized bill already exists for this period. Historical bills are immutable.');
    }

    // Get all contract items
    const itemsSnap = await db.collection('annexureContractItems')
      .where('contractId', '==', contractId)
      .get();
    const items = [];
    itemsSnap.forEach(d => items.push({ id: d.id, ...d.data() }));

    // Get all executions for this period
    const execSnap = await db.collection('annexureExecutions')
      .where('contractId', '==', contractId)
      .get();
    let allExecutions = [];
    execSnap.forEach(d => allExecutions.push({ id: d.id, ...d.data() }));
    allExecutions = allExecutions.filter(e => e.scheduledDate >= billingStart && e.scheduledDate <= billingEnd);

    const deductions = [];
    let totalDeduction = 0;

    for (const item of items) {
      if (item.status === 'NOT_AVAILABLE') continue;

      // Get areas for this item
      const areasSnap = await db.collection('annexureAreaComponents')
        .where('contractItemId', '==', item.uid)
        .where('status', '==', 'ACTIVE')
        .get();
      const areas = [];
      areasSnap.forEach(d => areas.push({ id: d.id, ...d.data() }));

      if (areas.length > 0) {
        // Area-level deductions
        for (const area of areas) {
          const areaExecs = allExecutions.filter(e => e.areaComponentId === area.uid);
          const missedCount = areaExecs.filter(e => e.status === 'NOT_COMPLETED').length;
          const partialCount = areaExecs.filter(e => e.status === 'PARTIALLY_COMPLETED').length;

          const dailyVal = this.calculateDailyMoneyValue(annualContractValue, area.allocatedWeightage);
          const deductionAmount = missedDeduction(dailyVal, missedCount);

          if (missedCount > 0 || partialCount > 0) {
            deductions.push({
              contractId,
              billingStart,
              billingEnd,
              itemId: item.uid,
              itemNumber: item.itemNumber,
              areaId: area.uid,
              areaName: area.areaName,
              weightageUsed: area.allocatedWeightage,
              annualContractValue,
              dailyMoneyValue: parseFloat(dailyVal.toFixed(4)),
              missedOccurrences: missedCount,
              partialOccurrences: partialCount,
              deductionAmount: parseFloat(deductionAmount.toFixed(2)),
              partialDeductionNote: partialDeductionNote(partialCount, item.partialDeductionAllowed),
              reason: `${missedCount} missed execution(s) for area "${area.areaName}" under Item ${item.itemNumber}`,
              status: 'DRAFT'
            });
            totalDeduction += deductionAmount;
          }
        }
      } else {
        // Item-level (no areas configured)
        const itemExecs = allExecutions.filter(e => e.contractItemId === item.uid && !e.areaComponentId);
        const missedCount = itemExecs.filter(e => e.status === 'NOT_COMPLETED').length;
        const partialCount = itemExecs.filter(e => e.status === 'PARTIALLY_COMPLETED').length;

        if (missedCount > 0 || partialCount > 0) {
          const dailyVal = this.calculateDailyMoneyValue(annualContractValue, item.effectiveWeightage);
          const deductionAmount = missedDeduction(dailyVal, missedCount);

          deductions.push({
            contractId,
            billingStart,
            billingEnd,
            itemId: item.uid,
            itemNumber: item.itemNumber,
            areaId: null,
            areaName: null,
            weightageUsed: item.effectiveWeightage,
            annualContractValue,
            dailyMoneyValue: parseFloat(dailyVal.toFixed(4)),
            missedOccurrences: missedCount,
            partialOccurrences: partialCount,
            deductionAmount: parseFloat(deductionAmount.toFixed(2)),
            partialDeductionNote: partialDeductionNote(partialCount, item.partialDeductionAllowed),
            reason: `${missedCount} missed execution(s) for Item ${item.itemNumber}`,
            status: 'DRAFT'
          });
          totalDeduction += deductionAmount;
        }
      }
    }

    // Save deductions (batch)
    const batch = db.batch();
    const savedIds = [];
    for (const ded of deductions) {
      const ref = db.collection('annexureBillingDeductions').doc();
      ded.uid = ref.id;
      ded.createdAt = new Date().toISOString();
      ded.createdBy = user.uid;
      ded.createdByName = user.fullName || 'User';
      batch.set(ref, ded);
      savedIds.push(ref.id);
    }
    await batch.commit();

    await auditService.logAudit(
      'ANNEXURE_BILLING_CALCULATED', user.uid, user.fullName || 'User',
      contractId, 'annexureBillingDeductions',
      `Billing deductions calculated for period ${billingStart} to ${billingEnd}. Total: ₹${totalDeduction.toFixed(2)}`,
      { billingStart, billingEnd, deductionCount: deductions.length, totalDeduction }
    );

    return {
      message: 'Billing deductions calculated',
      contractId,
      period: { start: billingStart, end: billingEnd },
      deductionCount: deductions.length,
      totalDeduction: parseFloat(totalDeduction.toFixed(2)),
      deductions,
      savedIds
    };
  }

  /**
   * Finalize billing deductions (make immutable).
   */
  async finalizeBillingDeductions(contractId, billingStart, billingEnd, user) {
    const snap = await db.collection('annexureBillingDeductions')
      .where('contractId', '==', contractId)
      .where('billingStart', '==', billingStart)
      .where('billingEnd', '==', billingEnd)
      .where('status', '==', 'DRAFT')
      .get();

    if (snap.empty) throw new NotFoundError('No draft deductions found for this period');

    const batch = db.batch();
    snap.forEach(doc => {
      batch.update(doc.ref, {
        status: 'FINALIZED',
        finalizedAt: new Date().toISOString(),
        finalizedBy: user.uid,
        finalizedByName: user.fullName || 'User'
      });
    });
    await batch.commit();

    await auditService.logAudit(
      'ANNEXURE_BILLING_FINALIZED', user.uid, user.fullName || 'User',
      contractId, 'annexureBillingDeductions',
      `${snap.size} billing deductions finalized for period ${billingStart} to ${billingEnd}`,
      { billingStart, billingEnd, count: snap.size }
    );

    return { message: `${snap.size} deductions finalized`, count: snap.size };
  }

  /**
   * Get billing deductions for a contract.
   */
  async getBillingDeductions(filters) {
    const { contractId, billingStart, billingEnd, status, itemNumber } = filters;
    let query = db.collection('annexureBillingDeductions');

    if (contractId) query = query.where('contractId', '==', contractId);
    if (status) query = query.where('status', '==', status);
    if (billingStart) query = query.where('billingStart', '==', billingStart);
    if (billingEnd) query = query.where('billingEnd', '==', billingEnd);

    const snap = await query.limit(500).get();
    let deductions = [];
    snap.forEach(d => deductions.push({ id: d.id, ...d.data() }));

    if (itemNumber) deductions = deductions.filter(d => d.itemNumber === parseInt(itemNumber));

    deductions.sort((a, b) => (a.itemNumber || 0) - (b.itemNumber || 0));

    const totalDeduction = deductions.reduce((s, d) => s + (d.deductionAmount || 0), 0);

    return {
      count: deductions.length,
      deductions,
      totalDeduction: parseFloat(totalDeduction.toFixed(2))
    };
  }

  /**
   * Get a billing summary for a contract period.
   */
  async getBillingSummary(contractId, billingStart, billingEnd) {
    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new NotFoundError('Contract not found');
    const contract = contractDoc.data();

    const { deductions, totalDeduction, count } = await this.getBillingDeductions({
      contractId, billingStart, billingEnd
    });

    // Get items for the summary
    const { items, totalWeightage, warnings } = await this.getContractItems(contractId);

    // Count executions in period
    const execSnap = await db.collection('annexureExecutions')
      .where('contractId', '==', contractId)
      .get();
    let allExecs = [];
    execSnap.forEach(d => allExecs.push(d.data()));
    if (billingStart) allExecs = allExecs.filter(e => e.scheduledDate >= billingStart);
    if (billingEnd) allExecs = allExecs.filter(e => e.scheduledDate <= billingEnd);

    const executionSummary = {
      total: allExecs.length,
      completed: allExecs.filter(e => e.status === 'COMPLETED').length,
      partiallyCompleted: allExecs.filter(e => e.status === 'PARTIALLY_COMPLETED').length,
      notCompleted: allExecs.filter(e => e.status === 'NOT_COMPLETED').length,
      waived: allExecs.filter(e => e.status === 'WAIVED').length,
      notApplicable: allExecs.filter(e => e.status === 'NOT_APPLICABLE').length
    };

    return {
      contract: {
        uid: contractId,
        contractNumber: contract.contractNumber,
        contractName: contract.contractName,
        annualContractValue: contract.contractValue || 0,
        entityName: contract.entityName
      },
      period: { start: billingStart, end: billingEnd },
      totalWeightage,
      warnings,
      executionSummary,
      deductionSummary: {
        count,
        totalDeduction,
        deductions
      },
      items: items.map(i => ({
        itemNumber: i.itemNumber,
        description: i.contractualDescription?.substring(0, 80),
        effectiveWeightage: i.effectiveWeightage,
        allocatedWeightage: i.allocatedWeightage,
        remainingWeightage: i.remainingWeightage,
        areaCount: i.areaCount,
        status: i.status
      }))
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6 — UTILITY / VALIDATION
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Validate total weightage for a contract.
   */
  async validateContractWeightage(contractId) {
    const snap = await db.collection('annexureContractItems')
      .where('contractId', '==', contractId)
      .get();
    if (snap.empty) return { valid: false, message: 'No items found', total: 0 };

    let total = 0;
    const items = [];
    snap.forEach(d => {
      const data = d.data();
      total += data.effectiveWeightage || 0;
      items.push({ itemNumber: data.itemNumber, weightage: data.effectiveWeightage, status: data.status });
    });

    const warnings = [];
    const warning = contractTotalWarning(total);
    if (warning) warnings.push(warning);

    return {
      valid: warnings.length === 0,
      total: parseFloat(total.toFixed(2)),
      warnings,
      itemCount: items.length,
      items: items.sort((a, b) => a.itemNumber - b.itemNumber)
    };
  }

  /**
   * Get master item list (no DB needed — returns the Annexure-4B master data).
   */
  getMasterItems() {
    const total = MASTER_ITEMS.reduce((s, m) => s + m.contractualWeightage, 0);
    return {
      count: MASTER_ITEMS.length,
      items: MASTER_ITEMS,
      totalWeightage: round2(total),
      warning: contractTotalWarning(total)
    };
  }
}

export const annexureBillingService = new AnnexureBillingService();
