import { db, admin } from '../database/index.js';
import PDFDocument from 'pdfkit';
import fs from 'fs';
import path from 'path';
import { NotFoundError, ValidationError, ForbiddenError } from '../errors/index.js';
import { auditService } from './auditService.js';

class BillingService {
  async saveBillingConfig(configData, user) {
    const { uid, fullName } = user;
    const existingQuery = await db.collection('billingRules').where('contractId', '==', configData.contractId).limit(1).get();
    let ref;
    if (!existingQuery.empty) {
      ref = db.collection('billingRules').doc(existingQuery.docs[0].id);
      configData.updatedAt = new Date().toISOString();
      configData.updatedBy = uid;
      delete configData.uid;
      await ref.update(configData);
      await auditService.logAudit('BILLING_CONFIG_UPDATED', uid, fullName || 'User', ref.id, 'billingRules', `Billing rules updated for contract ${configData.contractNumber} by ${fullName || 'User'}`, configData);
    } else {
      ref = db.collection('billingRules').doc();
      configData.uid = ref.id;
      configData.createdAt = new Date().toISOString();
      configData.createdBy = uid;
      configData.status = 'Active';
      await ref.set(configData);
      await auditService.logAudit('BILLING_CONFIG_CREATED', uid, fullName || 'User', ref.id, 'billingRules', `Billing rules configured for contract ${configData.contractNumber} by ${fullName || 'User'}`, configData);
    }
    return { message: 'Billing config saved', uid: ref.id };
  }

  async getBillingConfigByContract(contractId) {
    const snapshot = await db.collection('billingRules').where('contractId', '==', contractId).limit(1).get();
    if (snapshot.empty) throw new NotFoundError('No billing config found');
    return { config: snapshot.docs[0].data() };
  }

  async listBillingConfigs(user) {
    const { role, zone, division, entityId, userType } = user;
    let query = db.collection('billingRules');
    const userRole = (role || '').toLowerCase().replace(/_/g, ' ');
    if (userType === 'contractor') {
      if (!entityId) throw new ForbiddenError('Entity ID missing.');
      query = query.where('entityId', '==', entityId);
    } else if (userRole === 'super admin') {
      // Super admin sees all
    } else if (userRole === 'railway master') {
      query = query.where('zone', '==', zone);
    } else if ((!userRole.includes("super admin") && userRole.includes("admin")) || userRole.includes('supervisor')) {
      query = query.where('division', '==', division);
    }
    const snapshot = await query.limit(200).get();
    const configs = [];
    snapshot.forEach(doc => configs.push(doc.data()));
    return { count: configs.length, configs };
  }

  async createInvoice(creatorData, body) {
    const { contractId, month, year, overallScore, scoreBreakdown, machineShortageCount, manpowerShortageCount, missedObhsCount, otherPenalties } = body;
    const { uid, fullName } = creatorData;

    const ruleSnapshot = await db.collection('billingRules').where('contractId', '==', contractId).limit(1).get();
    if (ruleSnapshot.empty) throw new ValidationError('No billing config found. Configure billing rules first.');

    const rule = ruleSnapshot.docs[0].data();
    rule.uid = ruleSnapshot.docs[0].id;

    const contractDoc = await db.collection('contracts').doc(contractId).get();
    const contract = contractDoc.exists ? contractDoc.data() : {};
    const contractValue = contract.contractValue || 0;
    const deductionRate = rule.deductionRate || 0;
    const totalDeduction = (contractValue * deductionRate / 100) * ((100 - (overallScore || 100)) / 100);
    const finalPayable = contractValue - totalDeduction;

    const ref = db.collection('billingReports').doc();
    const billData = {
      uid: ref.id, contractId, contractNumber: contract.contractNumber || 'N/A',
      entityId: contract.entityId, entityName: contract.entityName || contract.agencyName || '',
      zone: contract.zone, division: contract.division, month, year,
      period: `${month}/${year}`, contractValue, overallScore: overallScore || 100,
      grade: overallScore >= 90 ? 'A' : overallScore >= 80 ? 'B' : overallScore >= 70 ? 'C' : 'D',
      totalDeduction, finalPayable,
      deductions: [{ type: 'Performance', description: 'Score based deduction', count: 1, rate: totalDeduction, amount: totalDeduction }],
      status: 'PENDING', createdBy: uid, createdAt: new Date().toISOString()
    };
    if (scoreBreakdown) billData.scoreBreakdown = scoreBreakdown;
    if (machineShortageCount) billData.machineShortageCount = machineShortageCount;
    if (manpowerShortageCount) billData.manpowerShortageCount = manpowerShortageCount;
    if (missedObhsCount) billData.missedObhsCount = missedObhsCount;
    if (otherPenalties) billData.otherPenalties = otherPenalties;
    await ref.set(billData);
    await auditService.logAudit('BILL_CREATED', uid, fullName || 'User', ref.id, 'billingReports', `Billing report generated for contract ${contract.contractNumber || 'N/A'} period ${month}/${year} by ${fullName || 'User'}`, billData);

    return { message: 'Bill generated', uid: ref.id };
  }

  async getInvoices(filters) {
    const { status, contractId, entityId: filterEntityId, division, zone, month, year, user } = filters;
    const { role, zone: userZone, division: userDivision, entityId: userEntityId, userType } = user;
    const normalizedRole = (role || '').toLowerCase().replace(/_/g, ' ');
    let query = db.collection('billingReports');
    if (userType === 'contractor') query = query.where('entityId', '==', userEntityId);
    else if (normalizedRole === 'super admin') {
      // Super Admin sees everything
    }
    else if (normalizedRole === 'railway master') query = query.where('zone', '==', userZone);
    else if (normalizedRole.includes('admin') || normalizedRole.includes('supervisor')) query = query.where('division', '==', userDivision);
    if (status) query = query.where('status', '==', status);
    if (contractId) query = query.where('contractId', '==', contractId);
    if (filterEntityId) query = query.where('entityId', '==', filterEntityId);
    if (division) query = query.where('division', '==', division);
    if (zone) query = query.where('zone', '==', zone);
    if (month) query = query.where('month', '==', parseInt(month));
    if (year) query = query.where('year', '==', parseInt(year));
    const snapshot = await query.orderBy('createdAt', 'desc').limit(200).get();
    const reports = [];
    snapshot.forEach(doc => reports.push(doc.data()));
    return { count: reports.length, reports };
  }

  async getInvoiceById(uid) {
    const doc = await db.collection('billingReports').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Report not found');
    return { report: doc.data() };
  }

  async updateInvoice(uid, body) {
    const { action, reason, user } = body;
    if (action === 'approve') {
      return this.approveBill(uid, user);
    } else if (action === 'reject') {
      return this.rejectBill(uid, reason, user);
    }
    throw new ValidationError('Invalid action. Use "approve" or "reject".');
  }

  async approveBill(uid, user) {
    const { uid: approverId, fullName } = user;
    const ref = db.collection('billingReports').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Report not found');
    const report = doc.data();
    if (report.status !== 'PENDING') throw new ValidationError(`Cannot approve bill with status: ${report.status}`);
    const invoiceNumber = `INV-${report.contractNumber}-${report.year}${String(report.month).padStart(2, '0')}-${Date.now().toString().slice(-4)}`;
    await ref.update({
      status: 'APPROVED', approvedBy: approverId, approvedByName: fullName,
      approvedAt: new Date().toISOString(), invoiceNumber,
      invoiceGeneratedAt: new Date().toISOString(),
      auditLog: admin.firestore.FieldValue.arrayUnion({ action: 'APPROVED', performedBy: approverId, performedByName: fullName, timestamp: new Date().toISOString(), details: `Bill approved by ${fullName}` })
    });
    await auditService.logAudit('BILL_APPROVED', approverId, fullName || 'User', ref.id, 'billingReports', `Bill approved by ${fullName || 'User'}. Invoice ${invoiceNumber} generated.`, { status: 'APPROVED', invoiceNumber });
    return { message: 'Bill approved', invoiceNumber };
  }

  async rejectBill(uid, reason, user) {
    const { uid: rejectorId, fullName } = user;
    const ref = db.collection('billingReports').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Report not found');
    const report = doc.data();
    if (report.status !== 'PENDING') throw new ValidationError(`Cannot reject bill with status: ${report.status}`);
    await ref.update({
      status: 'REJECTED', rejectedBy: rejectorId, rejectedByName: fullName,
      rejectedAt: new Date().toISOString(), rejectionReason: reason || 'No reason provided',
      auditLog: admin.firestore.FieldValue.arrayUnion({ action: 'REJECTED', performedBy: rejectorId, performedByName: fullName, timestamp: new Date().toISOString(), details: `Bill rejected by ${fullName}` })
    });
    await auditService.logAudit('BILL_REJECTED', rejectorId, fullName || 'User', ref.id, 'billingReports', `Bill rejected by ${fullName || 'User'}. Reason: ${reason}`, { status: 'REJECTED', rejectionReason: reason });
    return { message: 'Bill rejected' };
  }

  async getDashboard(user) {
    const { role, zone, division, entityId, userType } = user;
    const normalizedRole = (role || '').toLowerCase().replace(/_/g, ' ');
    let query = db.collection('billingReports');
    if (userType === 'contractor') query = query.where('entityId', '==', entityId);
    else if (normalizedRole === 'super admin') {
      // Super Admin sees everything
    }
    else if (normalizedRole === 'railway master') query = query.where('zone', '==', zone);
    else if (normalizedRole.includes('admin') || normalizedRole.includes('supervisor')) query = query.where('division', '==', division);
    const snapshot = await query.limit(200).get();
    const summary = { pendingBills: 0, approvedBills: 0, rejectedBills: 0, totalContractValue: 0, totalDeductions: 0, totalPayable: 0, activeContracts: 0 };
    const contractIds = new Set();
    snapshot.forEach(doc => {
      const d = doc.data();
      if (d.status === 'PENDING') summary.pendingBills++;
      else if (d.status === 'APPROVED') summary.approvedBills++;
      else if (d.status === 'REJECTED') summary.rejectedBills++;
      summary.totalContractValue += d.contractValue || 0;
      summary.totalDeductions += d.totalDeduction || 0;
      summary.totalPayable += d.finalPayable || 0;
      if (d.contractId) contractIds.add(d.contractId);
    });
    summary.activeContracts = contractIds.size;
    return summary;
  }

  async generateInvoiceNumber(uid, user) {
    const ref = db.collection('billingReports').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) throw new NotFoundError('Report not found');
    const report = doc.data();
    if (report.status !== 'APPROVED') throw new ValidationError('Invoice can only be generated for approved bills');
    const invoiceNumber = report.invoiceNumber || `INV-${report.contractNumber}-${report.year}${String(report.month).padStart(2, '0')}-${Date.now().toString().slice(-4)}`;
    await ref.update({ invoiceNumber, invoiceGeneratedAt: new Date().toISOString() });
    if (user) {
      await auditService.logAudit('INVOICE_GENERATED', user.uid, user.fullName || 'User', ref.id, 'billingReports', `Invoice generated: ${invoiceNumber} by ${user.fullName || 'User'}`, { invoiceNumber });
    } else {
      await auditService.logAudit('INVOICE_GENERATED', 'system', 'System', ref.id, 'billingReports', `Invoice generated: ${invoiceNumber}`, { invoiceNumber });
    }
    return { message: 'Invoice generated', invoiceNumber };
  }

  async getContractorDashboard(user) {
    const { entityId } = user;
    if (!entityId) throw new ForbiddenError('Entity ID missing.');
    const [ruleSnapshot, reportSnapshot] = await Promise.all([
      db.collection('billingRules').where('entityId', '==', entityId).limit(200).get(),
      db.collection('billingReports').where('entityId', '==', entityId).limit(200).get()
    ]);
    const configs = [];
    ruleSnapshot.forEach(doc => configs.push(doc.data()));
    const reports = [];
    reportSnapshot.forEach(doc => reports.push(doc.data()));
    reports.sort((a, b) => ((b.createdAt || '') > (a.createdAt || '') ? 1 : -1));
    let pendingAmount = 0, approvedAmount = 0, totalDeductions = 0;
    reports.forEach(r => {
      totalDeductions += r.totalDeduction || 0;
      if (r.status === 'PENDING') pendingAmount += r.finalPayable || 0;
      if (r.status === 'APPROVED') approvedAmount += r.finalPayable || 0;
    });
    return { configs: configs.length, totalBills: reports.length, pendingAmount, approvedAmount, totalDeductions, recentBills: reports.slice(0, 5), configList: configs };
  }

  async getSupervisorDashboard(user) {
    const { division } = user;
    const [contractsSnapshot, reportSnapshot] = await Promise.all([
      db.collection('contracts').where('division', '==', division).where('status', '==', 'Active').limit(200).get(),
      db.collection('billingReports').where('division', '==', division).limit(200).get()
    ]);
    const reports = [];
    reportSnapshot.forEach(doc => reports.push(doc.data()));
    let totalPenalties = 0, pendingCount = 0, approvedCount = 0;
    reports.forEach(r => {
      totalPenalties += r.totalDeduction || 0;
      if (r.status === 'PENDING') pendingCount++;
      if (r.status === 'APPROVED') approvedCount++;
    });
    return { activeContracts: contractsSnapshot.size, totalBills: reports.length, pendingCount, approvedCount, totalPenalties };
  }

  async getInvoicePdf(uid) {
    const doc = await db.collection('billingReports').doc(uid).get();
    if (!doc.exists) throw new NotFoundError('Billing report not found');
    const bill = doc.data();
    if (bill.status !== 'APPROVED' && !bill.invoiceNumber) {
      throw new ValidationError('Invoice not yet generated. Please generate invoice first.');
    }
    const invoiceNumber = bill.invoiceNumber || `INV-${uid.substring(0, 8)}`;
    const docPdf = new PDFDocument({ margin: 50 });
    const fileName = `invoice_${invoiceNumber}.pdf`;
    const tmpDir = path.join(process.cwd(), 'tmp');
    if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });
    const filePath = path.join(tmpDir, fileName);
    const stream = fs.createWriteStream(filePath);
    docPdf.pipe(stream);

    docPdf.fontSize(22).fillColor('#1f4e78').text('SWACHH RAILWAYS', { align: 'center' });
    docPdf.fontSize(10).fillColor('#666').text('Indian Railways – OBHS Billing System', { align: 'center' });
    docPdf.moveDown();
    docPdf.fontSize(16).fillColor('#1f4e78').text('INVOICE', { align: 'center' });
    docPdf.moveDown();
    docPdf.fontSize(10).fillColor('#333');
    docPdf.text(`Invoice Number: ${invoiceNumber}`);
    docPdf.text(`Date: ${new Date(bill.invoiceGeneratedAt || new Date()).toLocaleDateString('en-IN')}`);
    docPdf.text(`Period: ${bill.period || 'N/A'}`);
    docPdf.moveDown();
    docPdf.moveTo(50, docPdf.y).lineTo(545, docPdf.y).strokeColor('#ddd').stroke();
    docPdf.moveDown();
    docPdf.fontSize(12).fillColor('#1f4e78').text('Bill Details', { underline: true });
    docPdf.moveDown(0.5);
    docPdf.fontSize(10).fillColor('#333');
    const details = [
      ['Contract', bill.contractNumber || 'N/A'], ['Entity', bill.entityName || 'N/A'],
      ['Zone', bill.zone || 'N/A'], ['Division', bill.division || 'N/A'],
      ['Contract Value', `₹${(bill.contractValue || 0).toLocaleString('en-IN')}`],
      ['Overall Score', `${bill.overallScore || 0}%`], ['Grade', bill.grade || 'N/A'],
    ];
    details.forEach(([label, value]) => { docPdf.text(`${label}: ${value}`, { continued: false }); });
    docPdf.moveDown();
    if (bill.deductions && bill.deductions.length > 0) {
      docPdf.fontSize(12).fillColor('#1f4e78').text('Deductions', { underline: true });
      docPdf.moveDown(0.5);
      docPdf.fontSize(9).fillColor('#333');
      const tableTop = docPdf.y;
      const col1 = 50, col2 = 200, col3 = 320, col4 = 420, col5 = 500;
      docPdf.font('Helvetica-Bold');
      docPdf.text('Type', col1, tableTop); docPdf.text('Description', col2, tableTop);
      docPdf.text('Count', col3, tableTop); docPdf.text('Rate', col4, tableTop);
      docPdf.text('Amount', col5, tableTop);
      docPdf.font('Helvetica');
      let y = tableTop + 15;
      bill.deductions.forEach(d => {
        docPdf.text(d.type || 'N/A', col1, y); docPdf.text(d.description || 'N/A', col2, y);
        docPdf.text(`${d.count || 0}`, col3, y); docPdf.text(`₹${(d.rate || 0).toLocaleString('en-IN')}`, col4, y);
        docPdf.text(`₹${(d.amount || 0).toLocaleString('en-IN')}`, col5, y);
        y += 15;
      });
      docPdf.y = y;
    }
    docPdf.moveDown();
    docPdf.moveTo(50, docPdf.y).lineTo(545, docPdf.y).strokeColor('#ddd').stroke();
    docPdf.moveDown();
    docPdf.fontSize(14).fillColor('#28a745').text(`FINAL PAYABLE: ₹${(bill.finalPayable || 0).toLocaleString('en-IN')}`, { align: 'center' });
    docPdf.moveDown(2);
    docPdf.fontSize(8).fillColor('#999').text('Swachh Railways – Contractor Employee Portal | Indian Railways', { align: 'center' });
    docPdf.text(`Generated on ${new Date().toLocaleString('en-IN')}`, { align: 'center' });
    docPdf.end();

    return new Promise((resolve, reject) => {
      stream.on('finish', () => resolve({ filePath, fileName }));
      stream.on('error', reject);
    });
  }
}

export const billingService = new BillingService();
