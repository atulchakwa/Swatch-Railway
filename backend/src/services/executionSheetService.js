/*
 * Work Execution Sheet (Annexure-AB) service.
 * Tracks daily execution of the 25 weighted items and computes the monthly
 * execution score used for the 50% billing component of station cleaning
 * contracts.
 *
 * Required Firestore composite indexes:
 *  1. `execution_sheet_daily_logs` – `contractId` ASC, `stationId` ASC, `date` ASC
 */

import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import { auditService } from './auditService.js';

const STATUS_SET = new Set(['EXECUTED', 'PARTIAL', 'NOT_EXECUTED', 'N/A']);

function daysInMonth(month, year) {
  return new Date(parseInt(year), parseInt(month), 0).getDate();
}

class ExecutionSheetService {
  /* ---------- Template items ---------- */

  async getItems({ contractId, stationId, status = 'active' } = {}) {
    let query = db.collection('execution_sheet_items');
    if (status) query = query.where('status', '==', status);
    if (stationId) query = query.where('stationId', '==', stationId);
    const snapshot = await query.get();
    let items = [];
    snapshot.forEach((doc) => {
      const d = doc.data();
      if (contractId && d.contractId && d.contractId !== contractId) return;
      items.push({ id: doc.id, ...d });
    });
    items.sort((a, b) => (a.itemNo || 0) - (b.itemNo || 0));
    return { count: items.length, items };
  }

  async getItemById(uid) {
    const doc = await db.collection('execution_sheet_items').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Execution sheet item not found');
    return { id: doc.id, ...doc.data() };
  }

  async createItem(userData, body) {
    const { contractId, stationId, itemNo, weightage } = body;
    if (!contractId || !stationId || !itemNo) {
      throw new ValidationError('contractId, stationId, and itemNo are required');
    }
    if (weightage === undefined || weightage === null || isNaN(weightage)) {
      throw new ValidationError('weightage is required');
    }
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');

    const existing = await db.collection('execution_sheet_items')
      .where('stationId', '==', stationId).where('itemNo', '==', parseInt(itemNo)).get();
    if (!existing.empty) throw new ValidationError(`Item ${itemNo} already exists for this station`);

    const ref = db.collection('execution_sheet_items').doc();
    const data = {
      uid: ref.id,
      contractId,
      stationId,
      stationName: stationDoc.data().stationName || '',
      itemNo: parseInt(itemNo),
      description: body.description || body.areaDetails || `Item ${itemNo}`,
      areaDetails: body.areaDetails || [],
      shiftMonitoring: body.shiftMonitoring || '',
      weightage: parseFloat(weightage),
      requiredFrequencyPerMonth: parseInt(body.requiredFrequencyPerMonth) || 0,
      status: 'active',
      createdBy: userData.uid,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    await ref.set(data);
    await auditService.logAudit('EXECUTION_SHEET_ITEM_CREATED', userData.uid, userData.fullName || 'User', ref.id, 'execution_sheet_items', `Execution sheet item ${itemNo} created`);
    return { message: 'Execution sheet item created', uid: ref.id, item: data };
  }

  async updateItem(uid, userData, body) {
    const ref = db.collection('execution_sheet_items').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Execution sheet item not found');
    const allowed = ['description', 'areaDetails', 'shiftMonitoring', 'weightage', 'requiredFrequencyPerMonth', 'mappedAreas', 'status'];
    const updates = { updatedAt: new Date().toISOString() };
    for (const key of allowed) {
      if (body[key] !== undefined) {
        if (key === 'weightage') updates[key] = parseFloat(body[key]);
        else if (key === 'requiredFrequencyPerMonth') updates[key] = parseInt(body[key]);
        else updates[key] = body[key];
      }
    }
    await ref.update(updates);
    await auditService.logAudit('EXECUTION_SHEET_ITEM_UPDATED', userData.uid, userData.fullName || 'User', uid, 'execution_sheet_items', `Execution sheet item ${doc.data().itemNo} updated`);
    return { message: 'Execution sheet item updated', uid };
  }

  async deleteItem(uid, userData) {
    const ref = db.collection('execution_sheet_items').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Execution sheet item not found');
    await ref.update({ status: 'deleted', updatedAt: new Date().toISOString(), deletedBy: userData.uid });
    await auditService.logAudit('EXECUTION_SHEET_ITEM_DELETED', userData.uid, userData.fullName || 'User', uid, 'execution_sheet_items', `Execution sheet item ${doc.data().itemNo} deleted`);
    return { message: 'Execution sheet item deleted', uid };
  }

  /* ---------- Daily execution logs ---------- */

  _normalizeEntries(entries) {
    if (!Array.isArray(entries)) throw new ValidationError('entries array is required');
    const byItem = {};
    for (const e of entries) {
      const itemNo = parseInt(e.itemNo);
      const status = (e.status || 'EXECUTED').toUpperCase();
      if (!itemNo) throw new ValidationError('Each entry needs a valid itemNo');
      if (!STATUS_SET.has(status)) throw new ValidationError(`Invalid status "${status}" for item ${itemNo}`);
      byItem[itemNo] = {
        itemNo,
        status,
        count: parseInt(e.count || (status === 'EXECUTED' ? 1 : 0)),
        remarks: e.remarks || '',
      };
    }
    return byItem;
  }

  async saveDailySheet(userData, body) {
    const { contractId, stationId, date, shift } = body;
    if (!contractId || !stationId || !date) {
      throw new ValidationError('contractId, stationId, and date are required');
    }
    const entries = this._normalizeEntries(body.entries || []);

    // Upsert the daily log document for the given (station, date, shift).
    let query = db.collection('execution_sheet_daily_logs')
      .where('stationId', '==', stationId).where('date', '==', date);
    if (shift) query = query.where('shift', '==', shift);
    const existing = await query.get();

    const entriesArray = Object.values(entries).sort((a, b) => a.itemNo - b.itemNo);
    const now = new Date().toISOString();
    const payload = {
      contractId,
      stationId,
      date,
      shift: shift || 'full_day',
      entries: entriesArray,
      status: body.submit === true ? 'SUBMITTED' : 'DRAFT',
      submittedBy: body.submit === true ? userData.uid : null,
      submittedAt: body.submit === true ? now : null,
      updatedAt: now,
    };

    if (existing.empty) {
      const ref = db.collection('execution_sheet_daily_logs').doc();
      payload.uid = ref.id;
      payload.createdBy = userData.uid;
      payload.createdAt = now;
      await ref.set(payload);
      await auditService.logAudit('EXECUTION_SHEET_DAILY_SAVED', userData.uid, userData.fullName || 'User', ref.id, 'execution_sheet_daily_logs', `Daily execution sheet saved for ${date}${shift ? ' (' + shift + ')' : ''}`);
      return { message: 'Daily execution sheet saved', uid: ref.id, log: payload };
    }

    const ref = existing.docs[0].ref;
    const current = existing.docs[0].data();
    const mergeStatus = (current.status === 'SUBMITTED' && body.submit !== true) ? 'SUBMITTED' : payload.status;
    payload.uid = current.uid || existing.docs[0].id;
    payload.status = mergeStatus;
    await ref.update(payload);
    await auditService.logAudit('EXECUTION_SHEET_DAILY_UPDATED', userData.uid, userData.fullName || 'User', ref.id, 'execution_sheet_daily_logs', `Daily execution sheet updated for ${date}${shift ? ' (' + shift + ')' : ''}`);
    return { message: 'Daily execution sheet saved', uid: ref.id, log: payload };
  }

  async submitDailySheet(uid, userData) {
    const ref = db.collection('execution_sheet_daily_logs').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Daily execution sheet not found');
    await ref.update({ status: 'SUBMITTED', submittedBy: userData.uid, submittedAt: new Date().toISOString() });
    await auditService.logAudit('EXECUTION_SHEET_DAILY_SUBMITTED', userData.uid, userData.fullName || 'User', uid, 'execution_sheet_daily_logs', `Daily execution sheet submitted for ${doc.data().date}`);
    return { message: 'Daily execution sheet submitted', uid };
  }

  async getDailySheet({ contractId, stationId, date, shift } = {}) {
    const itemsResult = await this.getItems({ contractId, stationId });
    const items = itemsResult.items;

    let query = db.collection('execution_sheet_daily_logs');
    if (stationId) query = query.where('stationId', '==', stationId);
    if (date) query = query.where('date', '==', date);
    const snapshot = await query.get();
    let logs = [];
    snapshot.forEach((doc) => logs.push({ id: doc.id, ...doc.data() }));
    if (shift) logs = logs.filter((l) => l.shift === shift);
    logs.sort((a, b) => (a.shift || '').localeCompare(b.shift || ''));

    // Merge entries with item metadata for the UI.
    const entryMap = {};
    for (const log of logs) {
      for (const e of log.entries || []) {
        entryMap[`${log.shift || 'full_day'}_${e.itemNo}`] = { ...e, logUid: log.id, logStatus: log.status, shift: log.shift || 'full_day' };
      }
    }
    const merged = items.map((item) => ({
      ...item,
      entries: entriesForShifts(entryMap, item.itemNo),
    }));

    return { date, shift: shift || null, items: merged, logs };
  }

  async listDailyLogs({ contractId, stationId, month, year, status, limit = 200 } = {}) {
    let query = db.collection('execution_sheet_daily_logs');
    if (stationId) query = query.where('stationId', '==', stationId);
    const snapshot = await query.limit(parseInt(limit) * 2).get();
    let logs = [];
    snapshot.forEach((doc) => {
      const d = doc.data();
      if (month && year) {
        const prefix = `${year}-${String(month).padStart(2, '0')}`;
        if (!(d.date || '').startsWith(prefix)) return;
      }
      if (status && d.status !== status) return;
      if (contractId && d.contractId !== contractId) return;
      logs.push({ id: doc.id, ...d });
    });
    logs.sort((a, b) => ((b.date || '') + (b.shift || '')).localeCompare((a.date || '') + (a.shift || '')));
    return { count: logs.length, logs };
  }

  /* ---------- Monthly score computation (50% billing component) ---------- */

  _matchesMappedArea(mapped, mainArea, subArea) {
    if (!mapped || !mapped.mainArea || !mainArea) return false;
    if (String(mapped.mainArea).trim().toLowerCase() !== String(mainArea).trim().toLowerCase()) return false;
    if (!mapped.subAreas || mapped.subAreas.length === 0) return true;
    if (!subArea) return false;
    const sub = String(subArea).trim().toLowerCase();
    return mapped.subAreas.some((s) => String(s).trim().toLowerCase() === sub);
  }

  async _fetchAreaExecution(stationId, month, year) {
    // Real area execution: submitted/approved supervisor shift summaries.
    const prefix = `${year}-${String(month).padStart(2, '0')}`;
    let snapshot;
    try {
      snapshot = await db.collection('stationShiftSummaries')
        .where('stationId', '==', stationId)
        .where('date', '>=', `${prefix}-01`)
        .where('date', '<=', `${prefix}-31`)
        .get();
    } catch {
      snapshot = await db.collection('stationShiftSummaries').where('stationId', '==', stationId).get();
    }
    const records = [];
    snapshot.forEach((doc) => {
      const d = doc.data();
      if (!(d.date || '').startsWith(prefix)) return;
      if (!['submitted', 'approved'].includes(d.status)) return;
      records.push(d);
    });
    return records;
  }

  async getMonthlySummary({ contractId, stationId, month, year } = {}) {
    if (!stationId || !month || !year) {
      throw new ValidationError('stationId, month, and year are required');
    }
    const itemsResult = await this.getItems({ contractId, stationId });
    const items = itemsResult.items;
    const prefix = `${year}-${String(month).padStart(2, '0')}`;

    const snapshot = await db.collection('execution_sheet_daily_logs')
      .where('stationId', '==', stationId)
      .get();
    const logs = [];
    snapshot.forEach((doc) => {
      const d = doc.data();
      if (d.date && d.date.startsWith(prefix) && d.status === 'SUBMITTED') logs.push(d);
    });

    const shiftSummaries = await this._fetchAreaExecution(stationId, month, year);
    const monthDays = daysInMonth(month, year);
    const itemScores = [];
    let executionScore = 0;

    for (const item of items) {
      const required = item.requiredFrequencyPerMonth || 0;
      const mappedAreas = item.mappedAreas || [];
      let manualActual = 0;
      let naCount = 0;
      for (const log of logs) {
        for (const e of log.entries || []) {
          if (parseInt(e.itemNo) !== item.itemNo) continue;
          if (e.status === 'N/A') { naCount++; continue; }
          if (e.status === 'EXECUTED') manualActual += e.count || 1;
          else if (e.status === 'PARTIAL') manualActual += (e.count || 0) * 0.5;
        }
      }

      // Area-based execution: count matched area records in submitted shift summaries.
      let areaActual = 0;
      const daysExecuted = new Set();
      if (mappedAreas.length > 0) {
        for (const summary of shiftSummaries) {
          for (const a of summary.areas || []) {
            if (mappedAreas.some((m) => this._matchesMappedArea(m, a.mainArea, a.areaName))) {
              areaActual += 1;
              daysExecuted.add(summary.date);
            }
          }
        }
      }

      const actual = areaActual + manualActual;
      const notApplicable = naCount > 0;
      const achievedRatio = notApplicable || required <= 0
        ? 1
        : Math.min(actual / required, 1);
      const achievedWeight = Math.round(item.weightage * achievedRatio * 100) / 100;
      executionScore += achievedWeight;
      itemScores.push({
        itemNo: item.itemNo,
        description: item.description,
        areaDetails: item.areaDetails || [],
        mappedAreas,
        weightage: item.weightage,
        requiredFrequencyPerMonth: required,
        actualFrequency: Math.round(actual * 10) / 10,
        areaExecution: areaActual,
        manualExecution: Math.round(manualActual * 10) / 10,
        daysExecuted: daysExecuted.size,
        notApplicable,
        source: mappedAreas.length > 0 ? 'areas' : 'manual',
        achievedRatio: Math.round(achievedRatio * 1000) / 10,
        weightageAchieved: achievedWeight,
      });
    }

    executionScore = Math.round(Math.min(executionScore, 100) * 100) / 100;
    let contractValue = 0;
    if (contractId) {
      const contractDoc = await db.collection('contracts').doc(contractId).get();
      if (contractDoc.exists) contractValue = contractDoc.data().contractValue || 0;
    }
    const monthlyBase = Math.round(contractValue / 12);
    // 50% of billing depends on this execution score.
    const executionComponent = Math.round(monthlyBase * 0.50);
    const achievedAmount = Math.round(executionComponent * (executionScore / 100));
    const shortfallDeduction = executionComponent - achievedAmount;

    return {
      contractId, stationId, month: parseInt(month), year: parseInt(year),
      monthDays, daysLogged: new Set(logs.map((l) => l.date)).size,
      daysAreaExecuted: dayCount(shiftSummaries),
      logsCount: logs.length,
      shiftSummaryCount: shiftSummaries.length,
      itemScores,
      executionScore,
      monthlyBase,
      executionComponentNetBase: executionComponent,
      shortfallDeduction,
      achievedAmount,
    };
  }
}

function dayCount(summaries) {
  return new Set(summaries.map((s) => s.date)).size;
}

function entriesForShifts(entryMap, itemNo) {
  const result = [];
  for (const key of Object.keys(entryMap)) {
    if (key.endsWith(`_${itemNo}`)) result.push(entryMap[key]);
  }
  return result;
}

export const executionSheetService = new ExecutionSheetService();