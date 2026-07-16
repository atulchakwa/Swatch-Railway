/*
 * Required Firestore composite indexes:
 *  1. `station_billing_packs` – `contractId` ASC, `stationId` ASC, `month` ASC, `year` ASC
 *  2. `station_billing_packs` – `stationId` ASC, `createdAt` DESC
 *  3. `machine_downtime` – `stationId` ASC, `startTime` ASC
 *  4. `inspections` – `stationId` ASC, `createdAt` ASC
 */

import { db, admin } from '../database/index.js';
import { NotFoundError, ValidationError } from '../errors/index.js';
import logger from '../logger/index.js';
import { auditService } from './auditService.js';

class StationBillingService {
  async generateBillingSupportPack(user, data) {
    const { contractId, stationId, month, year } = data;
    if (!contractId || !stationId || !month || !year) throw new ValidationError('contractId, stationId, month, and year are required');

    const contractDoc = await db.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) throw new NotFoundError('Contract not found');
    const contractData = contractDoc.data();
    const stationDoc = await db.collection('stations').doc(stationId).get();
    if (!stationDoc.exists) throw new NotFoundError('Station not found');
    const stationName = stationDoc.data().stationName || '';

    const monthPad = String(month).padStart(2, '0');
    const startDate = `${year}-${monthPad}-01`;
    const lastDay = new Date(parseInt(year), parseInt(month), 0).getDate();
    const endDate = `${year}-${monthPad}-${String(lastDay).padStart(2, '0')}`;

    const [attendanceSnap, activitySnap, scorecardSnap, complaintSnap, feedbackSnap, inspectionSnap, machineSnap, downtimeSnap] = await Promise.all([
      db.collection('station_attendance').where('stationId', '==', stationId).where('date', '>=', startDate).where('date', '<=', endDate).get(),
      db.collection('station_daily_activities').where('stationId', '==', stationId).where('date', '>=', startDate).where('date', '<=', endDate).get(),
      db.collection('daily_scorecards').where('stationId', '==', stationId).where('date', '>=', startDate).where('date', '<=', endDate).get(),
      db.collection('complaints').where('stationId', '==', stationId).where('createdAt', '>=', startDate).where('createdAt', '<=', endDate + 'T23:59:59').get(),
      db.collection('station_feedback').where('stationId', '==', stationId).where('createdAt', '>=', startDate).where('createdAt', '<=', endDate + 'T23:59:59').get(),
      db.collection('inspections').where('stationId', '==', stationId).where('createdAt', '>=', startDate).where('createdAt', '<=', endDate + 'T23:59:59').get(),
      db.collection('machines').where('stationId', '==', stationId).get(),
      db.collection('machine_downtime').where('stationId', '==', stationId).where('startTime', '>=', startDate).where('startTime', '<=', endDate + 'T23:59:59').get(),
    ]);

    const attendanceRecords = []; attendanceSnap.forEach(d => attendanceRecords.push(d.data()));
    const presentCount = attendanceRecords.filter(r => ['present', 'late'].includes(r.status)).length;
    const uniqueDates = [...new Set(attendanceRecords.map(r => r.date))].length;
    const attendanceSummary = { totalDaysRecorded: uniqueDates, totalAttendanceEntries: attendanceRecords.length, totalPresent: presentCount, totalAbsent: attendanceRecords.filter(r => r.status === 'absent').length, averageDailyManpower: uniqueDates > 0 ? Math.round(presentCount / uniqueDates) : 0, attendancePercentage: attendanceRecords.length > 0 ? Math.round(presentCount / attendanceRecords.length * 100) : 0 };

    const activities = []; activitySnap.forEach(d => activities.push(d.data()));
    const actSummary = { total: activities.length, APPROVED: 0, COMPLETED: 0, REJECTED: 0, PENDING: 0, IN_PROGRESS: 0, PARTIALLY_COMPLETED: 0, RESUBMITTED: 0 };
    activities.forEach(a => { if (actSummary[a.status] !== undefined) actSummary[a.status]++; });
    const activityCompletionRate = actSummary.total > 0 ? Math.round((actSummary.APPROVED + actSummary.COMPLETED) / actSummary.total * 100) : 0;

    const scorecards = []; scorecardSnap.forEach(d => scorecards.push(d.data()));
    const totalScore = scorecards.reduce((s, c) => s + (c.overallStationScore || 0), 0);
    const avgScore = scorecards.length > 0 ? Math.round(totalScore / scorecards.length * 10) / 10 : 0;
    const gradeMap = {}; scorecards.forEach(c => { const g = c.grade || 'N/A'; gradeMap[g] = (gradeMap[g] || 0) + 1; });
    const scorecardSummary = { daysWithScorecard: scorecards.length, averageScore: avgScore, gradeDistribution: gradeMap, certified: scorecards.every(c => c.certified) };

    const complaints = []; complaintSnap.forEach(d => complaints.push(d.data()));
    const cmpSummary = { total: complaints.length, closed: complaints.filter(c => c.status === 'CLOSED').length, open: complaints.filter(c => ['REPORTED', 'ASSIGNED', 'IN_PROGRESS'].includes(c.status)).length, rejected: complaints.filter(c => c.status === 'REJECTED').length };

    const feedbackRecords = []; feedbackSnap.forEach(d => feedbackRecords.push(d.data()));
    const totalRating = feedbackRecords.reduce((s, f) => s + (f.rating || 0), 0);
    const feedbackSummary = { totalFeedbacks: feedbackRecords.length, averageRating: feedbackRecords.length > 0 ? Math.round(totalRating / feedbackRecords.length * 10) / 10 : 0, negativeFeedbacks: feedbackRecords.filter(f => f.isNegative).length };

    const inspections = []; inspectionSnap.forEach(d => inspections.push(d.data()));
    const totalDeficiencies = inspections.reduce((s, i) => s + (i.deficiencies || []).length, 0);
    const closedDeficiencies = inspections.reduce((s, i) => s + ((i.deficiencies || []).filter(d => d.status === 'CLOSED' || d.status === 'VERIFIED').length), 0);
    const inspectionSummary = { totalInspections: inspections.length, totalDeficiencies, closedDeficiencies, openDeficiencies: totalDeficiencies - closedDeficiencies, inspectionTypes: [...new Set(inspections.map(i => i.inspectionType || 'standard'))].length };

    const downtimeRecords = []; downtimeSnap.forEach(d => downtimeRecords.push(d.data()));
    const totalDowntimeHours = downtimeRecords.reduce((s, d) => s + (d.totalDowntimeHours || 0), 0);
    const totalMachinePenalty = downtimeRecords.reduce((s, d) => s + (d.penaltyAmount || 0), 0);
    const machineDowntimeSummary = { incidents: downtimeRecords.length, totalHours: totalDowntimeHours, totalPenalty: totalMachinePenalty };

    const billingRuleSnap = await db.collection('billingRules').where('contractId', '==', contractId).limit(1).get();
    let penalties = { totalPenaltyAmount: 0, deductions: [] };
    if (!billingRuleSnap.empty) {
      const rules = billingRuleSnap.docs[0].data();
      const monthlyBase = (contractData.contractValue || 0) / 12;
      if (attendanceSummary.attendancePercentage < 90 && rules.attendancePenaltyRate) {
        const amt = Math.round(((90 - attendanceSummary.attendancePercentage) / 100) * monthlyBase * (rules.attendancePenaltyRate || 0.01));
        penalties.deductions.push({ reason: 'Attendance Shortfall', percentage: 90 - attendanceSummary.attendancePercentage, amount: amt });
        penalties.totalPenaltyAmount += amt;
      }
      if (avgScore < 70 && rules.scorePenaltyRate) {
        const amt = Math.round(((70 - avgScore) / 100) * monthlyBase * (rules.scorePenaltyRate || 0.02));
        penalties.deductions.push({ reason: 'Score Below 70%', percentage: 70 - avgScore, amount: amt });
        penalties.totalPenaltyAmount += amt;
      }
    }
    if (machineDowntimeSummary.totalPenalty > 0) {
      penalties.deductions.push({ reason: 'Machine Downtime Penalty', percentage: 0, amount: machineDowntimeSummary.totalPenalty });
      penalties.totalPenaltyAmount += machineDowntimeSummary.totalPenalty;
    }
    const machines = []; machineSnap.forEach(d => machines.push(d.data()));
    const inMaintenanceCount = machines.filter(m => m.workingStatus === 'under_maintenance' || m.workingStatus === 'broken').length;
    const billableAmount = Math.max(0, (contractData.contractValue / 12) - penalties.totalPenaltyAmount);

    const ref = db.collection('station_billing_packs').doc();
    const now = new Date().toISOString();
    const pack = {
      uid: ref.id, contractId, stationId, stationName,
      month: parseInt(month), year: parseInt(year),
      contractNumber: contractData.contractNumber || '',
      contractorName: contractData.contractorName || contractData.entityName || '',
      monthlyContractValue: Math.round((contractData.contractValue || 0) / 12),
      gstRate: contractData.gstRate || 18,
      gstAmount: Math.round((billableAmount * (contractData.gstRate || 18)) / 100),
      totalPayableWithGst: Math.round(billableAmount * (1 + (contractData.gstRate || 18) / 100)),
      attendanceSummary, activitySummary: { ...actSummary, completionRate: activityCompletionRate },
      scorecardSummary, complaintSummary: cmpSummary, feedbackSummary, inspectionSummary,
      machineSummary: { total: machines.length, inMaintenance: inMaintenanceCount, deployed: machines.length - inMaintenanceCount, downtime: machineDowntimeSummary },
      penalties, billableAmount, status: 'DRAFT',
      paymentStatus: 'unpaid', paymentDate: null, paymentRef: null, paymentAmount: null,
      complianceChecklist: { attendanceSheetAttached: false, wagesheetAttached: false, bankStatementAttached: false, policeVerificationAttached: false, medicalCertificateAttached: false, biometricSheetAttached: false, scorecardAttached: scorecardSummary.daysWithScorecard > 0, gstInvoiceAttached: false },
      generatedBy: user.uid, generatedByName: user.fullName || '', generatedAt: now, createdAt: now, updatedAt: now,
    };
    await ref.set(pack);
    await auditService.logAudit('STATION_BILL_PACK_CREATED', user.uid, user.fullName || 'System', ref.id, 'station_billing_packs', `Billing support pack generated for station ${stationName} period ${month}/${year}`);
    return { message: 'Billing support pack generated', uid: ref.id, pack };
  }

  async getPackById(uid) {
    const doc = await db.collection('station_billing_packs').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Billing pack not found');
    return { id: doc.id, ...doc.data() };
  }

  async listPacks(query = {}) {
    const { contractId, stationId, month, year, status, paymentStatus, limit = 50 } = query;
    let q = db.collection('station_billing_packs');
    if (contractId) q = q.where('contractId', '==', contractId);
    if (stationId) q = q.where('stationId', '==', stationId);
    if (month) q = q.where('month', '==', parseInt(month));
    if (year) q = q.where('year', '==', parseInt(year));
    if (status) q = q.where('status', '==', status);
    if (paymentStatus) q = q.where('paymentStatus', '==', paymentStatus);
    const snapshot = await q.orderBy('createdAt', 'desc').limit(parseInt(limit)).get();
    const packs = []; snapshot.forEach(doc => packs.push({ id: doc.id, ...doc.data() }));
    return { count: packs.length, packs };
  }

  async updateCompliance(uid, checklist, user) {
    const ref = db.collection('station_billing_packs').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Billing pack not found');
    await ref.update({ complianceChecklist: checklist, updatedAt: new Date().toISOString() });
    if (user) {
      await auditService.logAudit('STATION_BILL_PACK_COMPLIANCE_UPDATED', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Compliance checklist updated`);
    }
    return { message: 'Compliance checklist updated', uid };
  }

  async submitPack(uid, user) {
    const ref = db.collection('station_billing_packs').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Billing pack not found');
    if (doc.data().status !== 'DRAFT') throw new ValidationError('Only DRAFT packs can be submitted');

    const pack = doc.data();
    const checklist = pack.complianceChecklist || {};
    const allComplete = Object.values(checklist).every(v => v === true);
    await ref.update({ status: 'SUBMITTED', submittedBy: user.uid, submittedAt: new Date().toISOString(), autoVerified: allComplete, updatedAt: new Date().toISOString() });
    await auditService.logAudit('STATION_BILL_PACK_SUBMITTED', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Billing support pack submitted`);
    return { message: 'Billing pack submitted', uid, autoVerified: allComplete };
  }

  async approvePack(uid, user) {
    const ref = db.collection('station_billing_packs').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Billing pack not found');
    await ref.update({ status: 'APPROVED', approvedBy: user.uid, approvedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    await auditService.logAudit('STATION_BILL_PACK_APPROVED', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Billing support pack approved`);
    return { message: 'Billing pack approved', uid };
  }

  async rejectPack(uid, reason, user) {
    const ref = db.collection('station_billing_packs').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Billing pack not found');
    if (!reason) throw new ValidationError('Rejection reason is required');
    await ref.update({ status: 'REJECTED', rejectionReason: reason, rejectedBy: user.uid, rejectedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    await auditService.logAudit('STATION_BILL_PACK_REJECTED', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Billing support pack rejected. Reason: ${reason}`);
    return { message: 'Billing pack rejected', uid };
  }

  async recordPayment(uid, user, body) {
    const ref = db.collection('station_billing_packs').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Billing pack not found');
    if (doc.data().status !== 'APPROVED') throw new ValidationError('Only APPROVED packs can have payments recorded');
    const { amount, paymentRef, paymentDate } = body;
    if (!amount || !paymentRef) throw new ValidationError('amount and paymentRef are required');
    await ref.update({ paymentStatus: amount >= doc.data().totalPayableWithGst ? 'paid' : 'partial', paymentAmount: amount, paymentRef, paymentDate: paymentDate || new Date().toISOString(), paidAt: new Date().toISOString(), paidBy: user.uid, updatedAt: new Date().toISOString() });
    await auditService.logAudit('STATION_BILL_PACK_PAYMENT_RECORDED', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Payment recorded. Ref: ${paymentRef}`);
    return { message: 'Payment recorded', uid };
  }

  async updatePack(uid, data, user) {
    const ref = db.collection('station_billing_packs').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Billing pack not found');
    if (!['DRAFT', 'REJECTED'].includes(doc.data().status)) throw new ValidationError('Only DRAFT or REJECTED packs can be edited');
    const allowed = ['complianceChecklist', 'attendanceSummary', 'activitySummary', 'scorecardSummary', 'complaintSummary', 'feedbackSummary', 'machineSummary', 'penalties', 'billableAmount'];
    const updates = { updatedAt: new Date().toISOString() };
    for (const key of allowed) { if (data[key] !== undefined) updates[key] = data[key]; }
    await ref.update(updates);
    if (user) {
      await auditService.logAudit('STATION_BILL_PACK_UPDATED', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Billing support pack updated`);
    }
    return { message: 'Billing pack updated', uid };
  }

  async deletePack(uid, user) {
    const ref = db.collection('station_billing_packs').doc(uid);
    if (!(await ref.get()).exists) throw new NotFoundError('Billing pack not found');
    await ref.update({ status: 'DELETED', deletedAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
    if (user) {
      await auditService.logAudit('STATION_BILL_PACK_DELETED', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Billing support pack deleted`);
    }
    return { message: 'Billing pack deleted' };
  }

  async returnToDraft(uid, user) {
    const ref = db.collection('station_billing_packs').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Billing pack not found');
    if (doc.data().status !== 'REJECTED') throw new ValidationError('Only REJECTED packs can be returned to draft');
    await ref.update({ status: 'DRAFT', rejectionReason: null, updatedAt: new Date().toISOString(), returnedToDraftBy: user.uid });
    await auditService.logAudit('STATION_BILL_PACK_RETURNED_TO_DRAFT', user.uid, user.fullName || 'User', uid, 'station_billing_packs', `Billing support pack returned to draft`);
    return { message: 'Billing pack returned to draft', uid };
  }

  /* ---------------------------------------------------------------
     Monthly billing auto-generation (Workflow 15.3)
     --------------------------------------------------------------- */

  async generateMonthlyBillingPacks(month, year, user) {
    if (!month || !year) throw new ValidationError('month and year are required');
    const userObj = user || { uid: 'system', fullName: 'System', role: 'SUPER_ADMIN' };
    const contractsSnap = await db.collection('contracts').where('status', '==', 'ACTIVE').limit(200).get();
    if (contractsSnap.empty) return { generated: 0, message: 'No active contracts found' };

    const generated = [];
    const errors = [];
    const processedStations = new Set();

    for (const contractDoc of contractsSnap.docs) {
      const contract = contractDoc.data();
      const contractId = contractDoc.id;
      let stationsSnap;
      if (contract.stationId) {
        const stationDoc = await db.collection('stations').doc(contract.stationId).get();
        if (stationDoc.exists && stationDoc.data().active !== false) {
          stationsSnap = [stationDoc];
        } else continue;
      } else {
        stationsSnap = await db.collection('stations').where('active', '==', true).limit(200).get();
      }
      const stationList = stationsSnap.docs ? stationsSnap.docs : [stationsSnap];
      for (const stationDoc of stationList) {
        if (stationDoc.id && processedStations.has(stationDoc.id)) continue;
        if (stationDoc.id) processedStations.add(stationDoc.id);
        const stationId = stationDoc.id;
        try {
          const existSnap = await db.collection('station_billing_packs')
            .where('contractId', '==', contractId).where('stationId', '==', stationId)
            .where('month', '==', parseInt(month)).where('year', '==', parseInt(year))
            .where('status', 'in', ['DRAFT', 'SUBMITTED', 'APPROVED']).limit(1).get();
          if (!existSnap.empty) {
            errors.push({ contractId, stationId, error: 'Pack already exists for this period' });
            continue;
          }
          const result = await this.generateBillingSupportPack(userObj, { contractId, stationId, month, year });
          generated.push({ contractId, stationId, packUid: result.uid });
        } catch (err) {
          errors.push({ contractId, stationId, error: err.message });
        }
      }
    }
    return { generated: generated.length, packs: generated, errors };
  }
}

export const stationBillingService = new StationBillingService();
