import cron from 'node-cron';
import { Resend } from 'resend';
import ExcelJS from 'exceljs';
import { db, admin } from './database/index.js';
import * as evidence from '../evidence_manager.js';
import logger from './logger/index.js';
import { taskManagementService } from './services/taskManagementService.js';

let resend = null;
try {
  if (process.env.RESEND_API_KEY) resend = new Resend(process.env.RESEND_API_KEY);
} catch (e) {
  logger.warn('Resend not configured — email features disabled');
}

async function generateCoachExcelBuffer(data) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Coach Cleaning Report');
  const headerStyle = {
    font: { bold: true, color: { argb: 'FFFFFF' } },
    fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: '1F4E78' } },
    alignment: { vertical: 'middle', horizontal: 'center', wrapText: true },
    border: { outline: { style: 'thin' } }
  };
  sheet.columns = [
    { header: 'Date', key: 'date', width: 15 },
    { header: 'Train Details', key: 'train', width: 30 },
    { header: 'Work Type', key: 'workType', width: 20 },
    { header: 'ACWP Status', key: 'acwp', width: 15 },
    { header: 'Total Penalty', key: 'penalty', width: 15 },
    { header: 'Internal (A)', key: 'intA', width: 12 },
    { header: 'Intensive (NA)', key: 'intNA', width: 12 },
    { header: 'Status', key: 'status', width: 15 }
  ];
  sheet.getRow(1).eachCell((cell) => { cell.style = headerStyle; });
  data.forEach(item => {
    sheet.addRow({
      date: item.formDateTime ? item.formDateTime.split('T')[0] : 'N/A',
      train: `${item.submittedTo?.trainNumber || ''} - ${item.submittedTo?.trainName || ''}`,
      workType: item.ratingDetails?.workType || 'N/A',
      acwp: item.ratingDetails?.acwpStatus || 'N/A',
      penalty: item.summary?.totalPenalty || 0,
      intA: item.summary?.internal?.A || 0,
      intNA: item.summary?.intensive?.NA || 0,
      status: item.status || 'LOCKED'
    });
  });
  return await workbook.xlsx.writeBuffer();
}

async function generatePremisesExcelBuffer(data) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Premises Report');
  const headerStyle = {
    font: { bold: true, color: { argb: 'FFFFFF' } },
    fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: '4472C4' } },
    alignment: { vertical: 'middle', horizontal: 'center' }
  };
  sheet.columns = [
    { header: 'Date', key: 'date', width: 15 },
    { header: 'Location', key: 'location', width: 20 },
    { header: 'Area (Sq Mtrs)', key: 'area', width: 15 },
    { header: 'Housekeeping Score', key: 'hkScore', width: 20 },
    { header: 'Pit-Line Score', key: 'pitScore', width: 15 },
    { header: 'Garbage Score', key: 'gbScore', width: 15 },
    { header: 'Overall Score', key: 'overall', width: 15 },
    { header: 'Status', key: 'status', width: 15 }
  ];
  sheet.getRow(1).eachCell((cell) => { cell.style = headerStyle; });
  data.forEach(item => {
    sheet.addRow({
      date: item.formDateTime ? item.formDateTime.split('T')[0] : 'N/A',
      location: item.location || 'N/A',
      area: item.area || 0,
      hkScore: item.summary?.housekeepingScore || '0',
      pitScore: item.summary?.pitLineScore || '0',
      gbScore: item.summary?.garbageDisposalScore || '0',
      overall: item.summary?.overallScore || '0',
      status: item.status || 'N/A'
    });
  });
  return await workbook.xlsx.writeBuffer();
}

async function sendEmailWithAttachments(email, division, coachBuffer, premisesBuffer, stats = { coachCount: 0, premisesCount: 0 }) {
  const todayDate = new Date().toISOString().split('T')[0];
  try {
    const hasData = stats.coachCount > 0 || stats.premisesCount > 0;
    if (!resend) { logger.warn('Resend not configured, skipping email'); return; }
    await resend.emails.send({
      from: 'Swachh Railways <reports@swachhrailways.com>',
      to: [email],
      subject: `Daily Cleaning Report | ${division} | ${todayDate}`,
      html: `
        <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; border: 1px solid #eee; padding: 20px; border-radius: 8px;">
          <h2 style="color: #1F4E78; border-bottom: 2px solid #1F4E78; padding-bottom: 10px;">Daily Summary Report</h2>
          <p>Dear Admin,</p>
          <p>Please find the automated cleaning performance reports for the <b>${division}</b> division.</p>
          <div style="background-color: #f9f9f9; padding: 15px; border-left: 4px solid #1F4E78; margin: 20px 0;">
            <p style="margin: 0; font-weight: bold;">Summary for ${todayDate}:</p>
            <ul style="margin: 10px 0 0 0;">
              <li>Coach Forms: ${stats.coachCount}</li>
              <li>Premises Forms: ${stats.premisesCount}</li>
            </ul>
          </div>
          ${hasData ? `
            <div style="background-color: #f9f9f9; padding: 15px; border-left: 4px solid #1F4E78; margin: 20px 0;">
              <p style="margin: 0; font-weight: bold;">Attached Files:</p>
              <ul style="margin: 10px 0 0 0;">
                ${stats.coachCount > 0 ? '<li>Coach Cleaning Detailed Report (.xlsx)</li>' : ''}
                ${stats.premisesCount > 0 ? '<li>Premises Cleaning Detailed Report (.xlsx)</li>' : ''}
              </ul>
            </div>
          ` : `
            <div style="background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0;">
              <p style="margin: 0; color: #856404;">
                ⚠️ No forms were submitted today. Please check if forms are being created properly.
              </p>
            </div>
          `}
          <p style="margin-top: 30px; font-size: 0.85em; color: #888; border-top: 1px solid #eee; padding-top: 15px;">
            <i>This is an automated message generated by the Swachh Railways System. Please do not reply to this email.</i>
          </p>
          <p style="font-weight: bold; color: #1F4E78; margin-bottom: 0;">Swachh Railways Management System</p>
          <p style="font-size: 0.8em; color: #666; margin-top: 4px;">Powered by Backend Automation</p>
        </div>
      `,
      attachments: [
        ...(coachBuffer ? [{ filename: `Coach_Report_${division}_${todayDate}.xlsx`, content: coachBuffer.toString('base64') }] : []),
        ...(premisesBuffer ? [{ filename: `Premises_Report_${division}_${todayDate}.xlsx`, content: premisesBuffer.toString('base64') }] : [])
      ],
    });
    logger.info('Cron', `Report successfully emailed to Admin: ${email} (${division})`);
  } catch (error) {
    logger.error('Cron', `Error sending email to ${email}:`, error);
  }
}

async function getDailyReportData() {
  const today = new Date();
  const startOfDay = new Date(today.setHours(0, 0, 0, 0));
  const endOfDay = new Date(today.setHours(23, 59, 59, 999));
  try {
    const adminSnapshot = await admin.firestore().collection('users').where('role', '==', 'admin').get();
    if (adminSnapshot.empty) { logger.info('Cron', "No admins found in the database."); return; }
    for (const doc of adminSnapshot.docs) {
      const adminInfo = doc.data();
      const adminDivision = adminInfo.division;
      const adminEmail = adminInfo.email;
      if (!adminDivision) { logger.info('Cron', `Skipping admin ${adminEmail} because division is not set.`); continue; }
      const coachSnapshot = await admin.firestore().collection('coachForms').where('submittedByDivision', '==', adminDivision).where('createdAt', '>=', startOfDay).where('createdAt', '<=', endOfDay).get();
      const coachData = coachSnapshot.docs.map(d => d.data());
      const premisesSnapshot = await admin.firestore().collection('premisesForms').where('submittedByDivision', '==', adminDivision).where('createdAt', '>=', startOfDay).where('createdAt', '<=', endOfDay).get();
      const premisesData = premisesSnapshot.docs.map(d => d.data());
      const coachBuffer = coachData.length > 0 ? await generateCoachExcelBuffer(coachData) : null;
      const premisesBuffer = premisesData.length > 0 ? await generatePremisesExcelBuffer(premisesData) : null;
      await sendEmailWithAttachments(adminEmail, adminDivision, coachBuffer, premisesBuffer, { coachCount: coachData.length, premisesCount: premisesData.length });
    }
  } catch (error) { logger.error('Cron', "Error in Automated Reporting Loop:", error); }
}

const checkAndApprove = async (collectionName) => {
  try {
    const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
    const snapshot = await db.collection(collectionName).where('status', '==', 'SCORED').get();
    if (snapshot.empty) return;
    const batch = db.batch();
    let approvedCount = 0;
    snapshot.forEach(doc => {
      const data = doc.data();
      let shouldApprove = false;
      if (data.ratedAt) {
        let ratedDate;
        if (typeof data.ratedAt.toDate === 'function') { ratedDate = data.ratedAt.toDate(); }
        else { ratedDate = new Date(data.ratedAt); }
        if (!isNaN(ratedDate.getTime()) && ratedDate < thirtyMinAgo) { shouldApprove = true; }
      }
      if (shouldApprove) {
        batch.update(doc.ref, { status: 'AUTO-APPROVED', completedAt: admin.firestore.FieldValue.serverTimestamp(), autoApprovedAt: admin.firestore.FieldValue.serverTimestamp() });
        approvedCount++;
      }
    });
    if (approvedCount > 0) { await batch.commit(); logger.info('Cron', `[Cron] Auto-approved ${approvedCount} forms in ${collectionName}`); }
  } catch (e) {
    if (e.code !== 'FAILED_PRECONDITION') logger.error('Cron', `[Cron Error] Form Approval:`, e.message);
  }
};

const checkContractExpiry = async () => {
  try {
    logger.info('Cron', ' Checking for expired contracts...');
    const now = new Date();
    const snapshot = await db.collection('contracts').where('status', '==', 'Active').get();
    if (snapshot.empty) { logger.info('Cron', ' No active contracts found to check.'); return; }
    const batch = db.batch();
    let expiredCount = 0;
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.endDate) {
        const endDate = new Date(data.endDate);
        endDate.setHours(23, 59, 59, 999);
        if (now > endDate) {
          batch.update(db.collection('contracts').doc(doc.id), { status: 'Expired', updatedAt: new Date().toISOString() });
          expiredCount++;
        }
      }
    });
    if (expiredCount > 0) { await batch.commit(); logger.info('Cron', ` Successfully Expired ${expiredCount} contracts.`); }
    else { logger.info('Cron', 'All active contracts are still valid.'); }
  } catch (e) { logger.error('Cron', ' [Cron Error] Contract Expiry:', e.message); }
};

// ─── Daily midnight: Check contract expiry & generate daily cleaning tasks ───
cron.schedule('0 0 * * *', async () => {
  logger.info('Cron', ' Running Midnight Cron Job...');
  try {
    await checkContractExpiry();
    const today = new Date().toISOString().split('T')[0];
    const taskResult = await taskManagementService.generateFrequencyBasedTasks(today);
    logger.info('Cron', ` [TaskGen] ${taskResult.message}`);
  } catch (e) { logger.error('Cron', ' [Cron Error] Midnight tasks:', e.message); }
});

// ─── Daily 6 AM & 6 PM: Regenerate tasks for current day if needed ───
cron.schedule('0 6,18 * * *', async () => {
  try {
    const today = new Date().toISOString().split('T')[0];
    const existingSnap = await db.collection('cleaningTasks').where('scheduledDate', '==', today).limit(1).get();
    if (existingSnap.empty) {
      const result = await taskManagementService.generateFrequencyBasedTasks(today);
      logger.info('Cron', ` [TaskGen-Refresh] ${result.message}`);
    } else {
      logger.info('Cron', ' [TaskGen-Refresh] Tasks already exist for today, skipping');
    }
  } catch (e) { logger.error('Cron', ' [Cron Error] Task refresh:', e.message); }
});

// ─── Daily 23:55: Automated daily reports ───
cron.schedule('55 23 * * *', async () => {
  logger.info('Cron', '--- Starting Automated Daily Reports ---');
  try {
    await getDailyReportData();
    logger.info('Cron', '--- Finished Automated Daily Reports Successfully ---');
  } catch (error) { logger.error('Cron', '--- Automated Daily Reports Failed ---', error); }
});

// ─── Daily 2 AM: Evidence archive ───
cron.schedule('0 2 * * *', async () => {
  logger.info('Cron', '--- Running Evidence Archive Cron ---');
  try {
    const result = await evidence.archiveOldRecords(db, db.getBucket(), 7);
    logger.info('Cron', `Archived ${result.archived} records older than ${result.daysOld} days`);
    const longResult = await evidence.moveToLongTerm(db, 30);
    logger.info('Cron', `Moved ${longResult.moved} records to long-term storage`);
  } catch (error) { logger.error('Cron', 'Evidence archive cron failed:', error); }
});

// ─── Every 10 minutes: Check forms and contracts as fallback ───
setInterval(() => {
  checkAndApprove('coachForms');
  checkAndApprove('premisesForms');
  checkAndApprove('ctsForms');
  checkContractExpiry();
}, 600000);

// ─── Every 15 minutes: Update task statuses based on time ───
cron.schedule('*/15 * * * *', async () => {
  try {
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    const activeRunsSnap = await db.collection('RunInstance').where('status', '==', 'Active').select('runInstanceId').get();
    const activeRunIds = new Set();
    activeRunsSnap.forEach(doc => activeRunIds.add(doc.id));
    const headerSnapshot = await db.collection('task_headers').where('status', 'in', ['PLANNED']).where('scheduledDate', '==', today).get();
    const headerBatch = db.batch();
    let updateCount = 0;
    headerSnapshot.forEach(doc => {
      const data = doc.data();
      if (!activeRunIds.has(data.runInstanceId)) return;
      const [h, m] = (data.scheduledTime || '00:00').split(':').map(Number);
      const scheduledDate = new Date(`${today}T${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:00`);
      if (now > scheduledDate) {
        headerBatch.update(doc.ref, { status: 'OVERDUE', updatedAt: now.toISOString() });
        updateCount++;
      }
    });
    if (updateCount > 0) { await headerBatch.commit(); logger.info('Cron', `[Cron] Updated ${updateCount} task headers to OVERDUE`); }
    const complaintSnapshot = await db.collection('obhs_complaints').where('status', '==', 'OPEN').get();
    const complaintBatch = db.batch();
    let escalatedCount = 0;
    complaintSnapshot.forEach(doc => {
      const data = doc.data();
      const createdAt = new Date(data.createdAt);
      const elapsedMinutes = (now - createdAt) / (1000 * 60);
      const slaMap = { 'Cleaning': 30, 'Garbage': 20, 'Water': 30, 'Petty Repair': 60, 'Toilet': 30, 'Electrical': 60 };
      const slaMinutes = slaMap[data.category] || 60;
      if (elapsedMinutes > slaMinutes && !data.slaEscalated) {
        complaintBatch.update(doc.ref, { slaEscalated: true, slaEscalatedAt: now.toISOString(), slaBreach: true, escalationLevel: 1, status: 'ESCALATED', updatedAt: now.toISOString() });
        escalatedCount++;
      }
    });
    if (escalatedCount > 0) { await complaintBatch.commit(); logger.info('Cron', `[Cron] Auto-escalated ${escalatedCount} SLA-breached complaints`); }
  } catch (error) { logger.error('Cron', '[Cron] Task status update error:', error); }
});

// ─── Every 5 minutes: Check task status transitions near scheduled times ───
cron.schedule('*/5 * * * *', async () => {
  try {
    const now = new Date();
    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    const activeRunsSnap = await db.collection('RunInstance').where('status', '==', 'Active').select('runInstanceId').get();
    const activeRunIds = new Set();
    activeRunsSnap.forEach(doc => activeRunIds.add(doc.id));
    const detailSnapshot = await db.collection('task_details').where('status', '==', 'PLANNED').get();
    const detailBatch = db.batch();
    let openCount = 0, dueSoonCount = 0, skippedCount = 0;
    detailSnapshot.forEach(doc => {
      const data = doc.data();
      if (!activeRunIds.has(data.runInstanceId)) { skippedCount++; return; }
      const [h, m] = (data.scheduledTime || '00:00').split(':').map(Number);
      const taskMinutes = h * 60 + m;
      const diff = taskMinutes - nowMinutes;
      if (diff <= 0 && diff > -120) {
        detailBatch.update(doc.ref, { status: 'OPEN', updatedAt: now.toISOString() });
        openCount++;
      } else if (diff > 0 && diff <= 15) {
        detailBatch.update(doc.ref, { status: 'DUE_SOON', updatedAt: now.toISOString() });
        dueSoonCount++;
      }
    });
    if (openCount + dueSoonCount > 0) { await detailBatch.commit(); logger.info('Cron', `[Cron] Task status updated: ${openCount} OPEN, ${dueSoonCount} DUE_SOON (${skippedCount} skipped - not active)`); }
  } catch (error) { logger.error('Cron', '[Cron] Task detail status error:', error); }
});

// ─── Every 5 minutes: Auto-escalate overdue tasks by time threshold ───
cron.schedule('*/5 * * * *', async () => {
  try {
    const now = new Date();
    const overdueTasksSnap = await db.collection('task_details').where('status', '==', 'OVERDUE').get();
    if (overdueTasksSnap.empty) return;
    const escalationChain = [
      { minutes: 90, escalateTo: 'CM', label: 'CM Alert' },
      { minutes: 60, escalateTo: 'CA', label: 'CA Alert' },
      { minutes: 45, escalateTo: 'CTS', label: 'CTS Alert' },
      { minutes: 30, escalateTo: 'CS', label: 'CS Alert' }
    ];
    const batch = db.batch();
    let escalationCount = 0;
    for (const doc of overdueTasksSnap.docs) {
      const task = doc.data();
      const updatedAt = task.updatedAt ? new Date(task.updatedAt) : null;
      if (!updatedAt) continue;
      const elapsedMinutes = (now - updatedAt) / (1000 * 60);
      const lastEscalation = task.lastEscalationAt || 0;
      for (const level of escalationChain) {
        if (elapsedMinutes >= level.minutes && lastEscalation < level.minutes) {
          const escRef = db.collection('escalations').doc();
          batch.set(escRef, {
            escalationId: escRef.id, sourceEntity: 'task_detail', sourceId: task.detailId || doc.id,
            reason: `${level.label}: Task overdue for ${Math.round(elapsedMinutes)} minutes`,
            details: `${task.taskType} on Coach ${task.coachNo} overdue since ${updatedAt.toISOString()}`,
            escalatedBy: 'system', escalatedByName: 'System', escalatedByRole: 'system',
            escalatedToRole: level.escalateTo, status: 'OPEN', createdAt: now.toISOString(), updatedAt: now.toISOString()
          });
          batch.update(doc.ref, { lastEscalationAt: level.minutes, escalationLevel: level.label, updatedAt: now.toISOString() });
          escalationCount++;
          break;
        }
      }
    }
    if (escalationCount > 0) { await batch.commit(); logger.info('Cron', `[Cron] Auto-escalated ${escalationCount} overdue tasks`); }
  } catch (error) { logger.error('Cron', '[Cron] Escalation error:', error); }
});

logger.info('Cron', 'Cron jobs initialized');
