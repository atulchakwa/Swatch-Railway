import { db, admin } from '../database/index.js';
import { stationReportService } from './stationReportService.js';
import logger from '../logger/index.js';
import config from '../config/index.js';

/* Recipient role mappings per report type (Section 10.1, 10.2) */
const DAILY_RECIPIENT_MAP = {
  daily_attendance: ['CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'DIVISION_ADMIN'],
  daily_activity: ['RAILWAY_SUPERVISOR', 'CONTRACTOR_ADMIN'],
  daily_scorecard: ['RAILWAY_SUPERVISOR', 'DIVISION_ADMIN'],
  daily_complaint: ['RAILWAY_SUPERVISOR', 'CONTRACTOR_ADMIN'],
  daily_feedback: ['RAILWAY_SUPERVISOR', 'DIVISION_ADMIN'],
  daily_inspection: ['RAILWAY_SUPERVISOR', 'DIVISION_ADMIN', 'SR_DCM'],
  daily_supervisor_log: ['RAILWAY_SUPERVISOR'],
  missed_activity: ['CONTRACTOR_SUPERVISOR', 'RAILWAY_SUPERVISOR'],
};

const MONTHLY_RECIPIENT_MAP = {
  monthly_attendance: ['DIVISION_ADMIN', 'BILLING_USER', 'COMMERCIAL_USER'],
  monthly_cleaning: ['DIVISION_ADMIN', 'SR_DCM'],
  monthly_scorecard: ['DIVISION_ADMIN', 'SR_DCM'],
  monthly_complaint: ['DIVISION_ADMIN'],
  monthly_feedback: ['DIVISION_ADMIN'],
  monthly_billing: ['DIVISION_ADMIN', 'COMMERCIAL_USER', 'BILLING_USER'],
  monthly_penalty: ['DIVISION_ADMIN', 'COMMERCIAL_USER'],
  monthly_performance: ['DIVISION_ADMIN', 'SR_DCM'],
};

const REPORT_TYPE_TITLES = {
  daily_attendance: 'Daily Attendance Report',
  daily_activity: 'Daily Cleaning Activity Report',
  daily_scorecard: 'Daily Cleanliness Scorecard',
  daily_complaint: 'Daily Complaint Report',
  daily_feedback: 'Daily Passenger Feedback Report',
  daily_inspection: 'Daily Inspection Report',
  daily_supervisor_log: 'Daily Supervisor Log',
  missed_activity: 'Missed Activity / Exception Report',
  monthly_attendance: 'Monthly Attendance Summary',
  monthly_cleaning: 'Monthly Cleaning Summary',
  monthly_scorecard: 'Monthly Cleanliness Scorecard',
  monthly_complaint: 'Monthly Complaint Summary',
  monthly_feedback: 'Monthly Passenger Feedback Summary',
  monthly_billing: 'Monthly Billing Support Pack',
  monthly_penalty: 'Monthly Penalty / Deduction Report',
  monthly_performance: 'Monthly Performance Summary',
};

class AutoEmailService {
  /* ---------------------------------------------------------------
     Low-level send
     --------------------------------------------------------------- */

  async _sendEmail({ to, subject, html, attachments = [] }) {
    let sgMail;
    try {
      sgMail = (await import('@sendgrid/mail')).default;
      if (config.sendgrid?.apiKey) sgMail.setApiKey(config.sendgrid.apiKey);
    } catch { /* sendgrid not available */ }

    const msg = {
      to: Array.isArray(to) ? to : [to],
      from: config.reporting?.fromEmail || 'noreply@swachhrailways.com',
      subject,
      html: html || `<p>${subject}</p>`,
      attachments: attachments.map(a => ({
        content: Buffer.isBuffer(a.content) ? a.content.toString('base64') : a.content,
        filename: a.filename,
        type: a.type || 'application/pdf',
        disposition: 'attachment',
      })),
    };

    if (sgMail && config.sendgrid?.apiKey) {
      try { return await sgMail.send(msg); } catch (e) { logger.warn('AutoEmail', 'SendGrid failed', e.message); }
    }
    
    // Fallback to Resend if available
    if (config.resend?.apiKey) {
      try {
        const { Resend } = await import('resend');
        const resend = new Resend(config.resend.apiKey);
        const resendData = await resend.emails.send({
          from: msg.from,
          to: msg.to,
          subject: msg.subject,
          html: msg.html,
          attachments: msg.attachments
        });
        if (resendData.error) throw resendData.error;
        return resendData.data;
      } catch (e) {
        logger.warn('AutoEmail', 'Resend failed', e.message);
      }
    }
    /* fallback: log instead of send */
    logger.info('AutoEmail', `[SIMULATED] Email to ${msg.to.join(',')} subject="${subject}"`);
    return { messageId: 'simulated' };
  }

  /* ---------------------------------------------------------------
     Recipient resolution
     --------------------------------------------------------------- */

  async resolveRecipients(roleNames, stationId, division) {
    const emails = new Set();
    for (const roleName of roleNames) {
      let q = db.collection('users').where('role', '==', roleName).where('active', '==', true).limit(200);
      if (stationId) {
        q = q.where('stationId', '==', stationId);
      } else if (division) {
        q = q.where('division', '==', division);
      }
      const snap = await q.get();
      snap.forEach(d => {
        const u = d.data();
        if (u.email) emails.add(u.email);
      });
    }
    return [...emails];
  }

  async resolveRecipientsByStation(roleNames, stationId) {
    return this.resolveRecipients(roleNames, stationId, null);
  }

  async resolveRecipientsByDivision(roleNames, division) {
    return this.resolveRecipients(roleNames, null, division);
  }

  /* ---------------------------------------------------------------
     Dispatch helpers
     --------------------------------------------------------------- */

  async dispatchDailyReport(reportType, stationId, date) {
    const roles = DAILY_RECIPIENT_MAP[reportType];
    if (!roles) throw new Error(`Unknown daily report type: ${reportType}`);
    const title = REPORT_TYPE_TITLES[reportType] || reportType;
    const stationDoc = await db.collection('stations').doc(stationId).get();
    const stationName = stationDoc.exists ? stationDoc.data().stationName || stationId : stationId;
    const division = stationDoc.exists ? stationDoc.data().division : null;

    const recipients = await this.resolveRecipients(roles, stationId, division);
    if (recipients.length === 0) {
      logger.warn('AutoEmail', `No recipients for ${reportType} at station ${stationId}`);
      return { sent: 0, recipients: [] };
    }

    const user = { uid: 'system', fullName: 'System', role: 'SUPER_ADMIN' };
    const fnMap = {
      daily_attendance: 'generateDailyAttendanceReport', daily_activity: 'generateDailyActivityReport',
      daily_scorecard: 'generateDailyScorecardReport', daily_complaint: 'generateDailyComplaintReport',
      daily_feedback: 'generateDailyFeedbackReport', daily_inspection: 'generateDailyInspectionReport',
      daily_supervisor_log: 'generateDailySupervisorLog',
      missed_activity: 'generateMissedActivityReport',
    };
    let reportData;
    try {
      reportData = await stationReportService[fnMap[reportType]](stationId, date, user);
    } catch (e) {
      logger.error('AutoEmail', `Failed to generate ${reportType}: ${e.message}`);
      return { sent: 0, error: e.message };
    }

    const summaryHtml = Object.entries(reportData.summary || {})
      .filter(([k]) => !['records', 'missedActivities', 'overdueActivities', 'delayedActivities', 'inspections', 'areaCompletion', 'scores'].includes(k))
      .map(([k, v]) => `<tr><td>${k.replace(/([A-Z])/g, ' $1').replace(/^./, s => s.toUpperCase())}</td><td>${JSON.stringify(v)}</td></tr>`)
      .join('');

    await this._sendEmail({
      to: recipients,
      subject: `${title} — ${stationName} — ${date}`,
      html: `<h2>${title}</h2><p><b>Station:</b> ${stationName}<br><b>Date:</b> ${date}</p><table border="1" cellpadding="4" cellspacing="0">${summaryHtml}</table><p><i>Auto-generated by Swachh Railways System</i></p>`,
    });

    const logRef = db.collection('email_history').doc();
    await logRef.set({
      emailId: logRef.id, reportType, stationId, date,
      to: recipients, sentBy: 'system', sentByName: 'System',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('AutoEmail', `Dispatched ${reportType} to ${recipients.length} recipients for ${stationId}`);
    return { sent: recipients.length, recipients };
  }

  async dispatchDailyReports(stationId, date) {
    const types = Object.keys(DAILY_RECIPIENT_MAP);
    const results = [];
    for (const t of types) {
      results.push({ type: t, result: await this.dispatchDailyReport(t, stationId, date) });
    }
    return results;
  }

  async dispatchMonthlyReport(reportType, stationId, month, year) {
    const roles = MONTHLY_RECIPIENT_MAP[reportType];
    if (!roles) throw new Error(`Unknown monthly report type: ${reportType}`);
    const title = REPORT_TYPE_TITLES[reportType] || reportType;
    const stationDoc = await db.collection('stations').doc(stationId).get();
    const stationName = stationDoc.exists ? stationDoc.data().stationName || stationId : stationId;
    const division = stationDoc.exists ? stationDoc.data().division : null;

    const recipients = await this.resolveRecipients(roles, stationId, division);
    if (recipients.length === 0) {
      logger.warn('AutoEmail', `No recipients for ${reportType} station ${stationId}`);
      return { sent: 0, recipients: [] };
    }

    const user = { uid: 'system', fullName: 'System', role: 'SUPER_ADMIN' };
    const fnMap = {
      monthly_attendance: 'generateMonthlyAttendanceSummary', monthly_cleaning: 'generateMonthlyCleaningSummary',
      monthly_scorecard: 'generateMonthlyScorecardReport', monthly_complaint: 'generateMonthlyComplaintSummary',
      monthly_feedback: 'generateMonthlyFeedbackSummary', monthly_billing: 'generateMonthlyBillingReport',
      monthly_penalty: 'generateMonthlyPenaltyReport',
      monthly_performance: 'generateMonthlyPerformanceReport',
    };
    let reportData;
    try {
      reportData = await stationReportService[fnMap[reportType]](stationId, month, year, user);
    } catch (e) {
      logger.error('AutoEmail', `Failed to generate ${reportType}: ${e.message}`);
      return { sent: 0, error: e.message };
    }

    const summaryHtml = Object.entries(reportData.summary || {})
      .filter(([k]) => !['records', 'inspections', 'missedActivities', 'overdueActivities', 'delayedActivities', 'modifications'].includes(k))
      .map(([k, v]) => `<tr><td>${k.replace(/([A-Z])/g, ' $1').replace(/^./, s => s.toUpperCase())}</td><td>${JSON.stringify(v)}</td></tr>`)
      .join('');

    await this._sendEmail({
      to: recipients,
      subject: `${title} — ${stationName} — ${month}/${year}`,
      html: `<h2>${title}</h2><p><b>Station:</b> ${stationName}<br><b>Period:</b> ${month}/${year}</p><table border="1" cellpadding="4" cellspacing="0">${summaryHtml}</table><p><i>Auto-generated by Swachh Railways System</i></p>`,
    });

    const logRef = db.collection('email_history').doc();
    await logRef.set({
      emailId: logRef.id, reportType, stationId, month, year,
      to: recipients, sentBy: 'system', sentByName: 'System',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('AutoEmail', `Dispatched ${reportType} to ${recipients.length} recipients for ${stationId}`);
    return { sent: recipients.length, recipients };
  }

  async dispatchMonthlyReports(stationId, month, year) {
    const types = Object.keys(MONTHLY_RECIPIENT_MAP);
    const results = [];
    for (const t of types) {
      results.push({ type: t, result: await this.dispatchMonthlyReport(t, stationId, month, year) });
    }
    return results;
  }

  /* ---------------------------------------------------------------
     Missed-activity alert (only to contractor-supervisor, railway-supervisor)
     --------------------------------------------------------------- */

  async dispatchMissedActivityAlert(stationId, date) {
    const result = await this.dispatchDailyReport('missed_activity', stationId, date);
    if (result.sent > 0) {
      logger.info('AutoEmail', `Missed activity alert sent for ${stationId} on ${date}`);
    }
    return result;
  }

  /* ---------------------------------------------------------------
     Rejected-form notification
     --------------------------------------------------------------- */

  async dispatchRejectedFormNotification(stationId, formType, formId, reason) {
    const stationDoc = await db.collection('stations').doc(stationId).get();
    const division = stationDoc.exists ? stationDoc.data().division : null;
    const recipients = await this.resolveRecipients(['CONTRACTOR_SUPERVISOR', 'RAILWAY_SUPERVISOR'], stationId, division);
    if (recipients.length === 0) return { sent: 0 };

    await this._sendEmail({
      to: recipients,
      subject: `Form Rejected — ${formType} — ${stationId}`,
      html: `<h2>Form Rejected</h2><p><b>Station:</b> ${stationId}<br><b>Form Type:</b> ${formType}<br><b>Form ID:</b> ${formId}<br><b>Reason:</b> ${reason || 'N/A'}</p><p><i>Please review and resubmit.</i></p>`,
    });

    await db.collection('email_history').doc().set({
      emailId: db.collection('email_history').doc().id, reportType: 'rejected_form',
      stationId, formType, formId, to: recipients, sentBy: 'system', sentByName: 'System',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { sent: recipients.length, recipients };
  }

  /* ---------------------------------------------------------------
     Complaint escalation notification
     --------------------------------------------------------------- */

  async dispatchComplaintEscalation(complaintId, stationId, category, description) {
    const stationDoc = await db.collection('stations').doc(stationId).get();
    const division = stationDoc.exists ? stationDoc.data().division : null;
    const recipients = await this.resolveRecipients(['DIVISION_ADMIN', 'RAILWAY_ADMIN', 'RAILWAY_MASTER'], stationId, division);
    if (recipients.length === 0) return { sent: 0 };

    await this._sendEmail({
      to: recipients,
      subject: `Complaint Escalated — ${category} — ${stationId}`,
      html: `<h2>Complaint Escalated</h2><p><b>Complaint ID:</b> ${complaintId}<br><b>Station:</b> ${stationId}<br><b>Category:</b> ${category}<br><b>Description:</b> ${description || 'N/A'}</p><p><i>Immediate attention required.</i></p>`,
    });

    await db.collection('email_history').doc().set({
      emailId: db.collection('email_history').doc().id, reportType: 'complaint_escalation',
      complaintId, stationId, category, to: recipients, sentBy: 'system', sentByName: 'System',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { sent: recipients.length, recipients };
  }

  /* ---------------------------------------------------------------
     End-of-day batch dispatch
     --------------------------------------------------------------- */

  async dispatchEndOfDayReports(stationId, date) {
    const results = await this.dispatchDailyReports(stationId, date);
    await this.dispatchMissedActivityAlert(stationId, date);
    return { stationId, date, daily: results };
  }

  /* ---------------------------------------------------------------
     Monthly batch dispatch
     --------------------------------------------------------------- */

  async dispatchEndOfMonthReports(stationId, month, year) {
    return this.dispatchMonthlyReports(stationId, month, year);
  }
}

export const autoEmailService = new AutoEmailService();
