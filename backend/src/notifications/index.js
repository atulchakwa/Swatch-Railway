import { Resend } from 'resend';
import sgMail from '@sendgrid/mail';
import axios from 'axios';
import config from '../config/index.js';
import logger from '../logger/index.js';

class NotificationService {
  constructor() {
    this.resend = config.resend.apiKey ? new Resend(config.resend.apiKey) : null;

    if (config.sendgrid.apiKey) {
      sgMail.setApiKey(config.sendgrid.apiKey);
    }
    this.sgMail = sgMail;
  }

  async sendEmailViaResend({ to, subject, html, from = config.reporting.fromEmail, attachments = [] }) {
    if (!this.resend) {
      logger.warn('NotificationService', 'Resend not configured, skipping email');
      return null;
    }

    try {
      const { data, error } = await this.resend.emails.send({
        from, to: Array.isArray(to) ? to : [to], subject, html,
        attachments: attachments.map(a => ({
          filename: a.filename,
          content: a.content.toString('base64')
        }))
      });

      if (error) {
        logger.error('NotificationService', 'Resend email failed', error);
        throw error;
      }

      logger.info('NotificationService', `Email sent via Resend to ${to}`);
      return data;
    } catch (error) {
      logger.error('NotificationService', 'Resend email error', error);
      throw error;
    }
  }

  async sendEmailViaSendgrid({ to, subject, html, from = 'noreply@swachhrailways.com', attachments = [] }) {
    try {
      const msg = {
        to: Array.isArray(to) ? to : [to],
        from,
        subject,
        html,
        attachments: attachments.map(a => ({
          filename: a.filename,
          content: a.content.toString('base64')
        }))
      };

      await this.sgMail.send(msg);
      logger.info('NotificationService', `Email sent via SendGrid to ${to}`);
      return true;
    } catch (error) {
      logger.error('NotificationService', 'SendGrid email error', error);
      throw error;
    }
  }

  async sendVoiceVia2Factor(phone, otp) {
    const apiKey = config.sms.twoFactorApiKey || process.env.TWOF_API_KEY || process.env.TWO_FACTOR_API_KEY || process.env.TWOFACTOR_API_KEY || process.env['2FACTOR_API_KEY'];
    if (!apiKey) {
      logger.warn('NotificationService', '2Factor API key not configured');
      return null;
    }

    try {
      const url = `https://2factor.in/API/V1/${apiKey}/VOICE/${phone}/${otp}`;
      logger.info('NotificationService', `Calling 2Factor VOICE OTP URL for ${phone}...`);
      const response = await axios.get(url, { timeout: 5000 });

      if (response.data && (response.data.Status === 'Success' || response.data.status === 'Success')) {
        logger.info('NotificationService', `Voice OTP call successfully initiated via 2Factor to ${phone}`);
        return response.data;
      }
      throw new Error(response.data?.Details || '2Factor voice OTP failed');
    } catch (error) {
      logger.error('NotificationService', '2Factor Voice OTP error:', error?.response?.data || error.message);
      throw error;
    }
  }

  async sendSmsVia2Factor(phone, otp) {
    const apiKey = config.sms.twoFactorApiKey || process.env.TWOF_API_KEY || process.env.TWO_FACTOR_API_KEY || process.env.TWOFACTOR_API_KEY || process.env['2FACTOR_API_KEY'];
    if (!apiKey) {
      logger.warn('NotificationService', '2Factor API key not configured');
      return null;
    }

    try {
      const url = `https://2factor.in/API/V1/${apiKey}/SMS/${phone}/${otp}`;
      const response = await axios.get(url, { timeout: 5000 });

      if (response.data && (response.data.Status === 'Success' || response.data.status === 'Success')) {
        logger.info('NotificationService', `SMS sent via 2Factor to ${phone}`);
        return response.data;
      }
      throw new Error(response.data?.Details || '2Factor SMS failed');
    } catch (error) {
      logger.error('NotificationService', '2Factor SMS error:', error?.response?.data || error.message);
      throw error;
    }
  }

  async sendVoiceViaTwilio(phone, otp) {
    const { twilio } = config.sms;
    if (!twilio || !twilio.accountSid || !twilio.authToken || !twilio.phoneNumber) {
      logger.warn('NotificationService', 'Twilio Voice not configured');
      return null;
    }

    try {
      const twilioClient = (await import('twilio')).default(twilio.accountSid, twilio.authToken);
      const digits = String(otp).split('').join(' ');
      const result = await twilioClient.calls.create({
        twiml: `<Response><Say voice="alice" language="en-IN">Greetings from Swachh Railways. Your verification code is ${digits}. I repeat, your verification code is ${digits}. Thank you.</Say></Response>`,
        from: twilio.phoneNumber,
        to: `+91${phone}`
      });
      logger.info('NotificationService', `Voice call initiated via Twilio to ${phone}`);
      return result;
    } catch (error) {
      logger.error('NotificationService', 'Twilio Voice call error:', error.message);
      throw error;
    }
  }

  async sendSmsViaTwilio(phone, message) {
    const { twilio } = config.sms;
    if (!twilio.accountSid || !twilio.authToken) {
      logger.warn('NotificationService', 'Twilio not configured');
      return null;
    }

    try {
      const twilioClient = (await import('twilio')).default(twilio.accountSid, twilio.authToken);
      const result = await twilioClient.messages.create({
        body: message,
        from: twilio.phoneNumber,
        to: `+91${phone}`
      });
      logger.info('NotificationService', `SMS sent via Twilio to ${phone}`);
      return result;
    } catch (error) {
      logger.error('NotificationService', 'Twilio SMS error', error);
      throw error;
    }
  }

  async sendOtpEmail(email, otp, purpose = 'login') {
    const subject = purpose === 'login'
      ? 'Login OTP - Swachh Railways'
      : 'Password Reset OTP - Swachh Railways';

    const html = `
      <div style="font-family: Arial, sans-serif; border: 1px solid #ddd; padding: 20px; border-radius: 10px;">
        <h2 style="color: #2c3e50;">${purpose === 'login' ? 'Verify Your Login' : 'Password Reset Request'}</h2>
        <p>Your One-Time Password (OTP) is:</p>
        <h1 style="color: #e67e22; letter-spacing: 5px;">${otp}</h1>
        <p>This code is valid for <b>5 minutes</b>. Please do not share this with anyone.</p>
        <hr style="border: 0; border-top: 1px solid #eee;" />
        <p style="font-size: 12px; color: #7f8c8d;">If you didn't request this, please ignore this email.</p>
      </div>`;

    return this.sendEmailViaResend({ to: email, subject, html, from: config.reporting.authEmail });
  }

  async sendOtpSms(phone, otp) {
    // Attempt voice call primary, then SMS fallback
    try {
      const voiceRes = await this.sendVoiceVia2Factor(phone, otp);
      if (voiceRes) return voiceRes;
    } catch (e) {}
    return this.sendSmsVia2Factor(phone, otp);
  }

  async sendPasswordResetOtp(phone, otp) {
    // Voice call first, then SMS fallbacks — for forgot-password OTP.
    try {
      const voiceRes = await this.sendVoiceVia2Factor(phone, otp);
      if (voiceRes) return voiceRes;
    } catch (e) {
      logger.warn('NotificationService', `2Factor voice failed, trying SMS fallback: ${e?.message}`);
    }
    try {
      const smsRes = await this.sendSmsVia2Factor(phone, otp);
      if (smsRes) return smsRes;
    } catch (e) {}
    return this.sendPasswordResetOtpSms(phone, otp);
  }

  async sendPasswordResetOtpSms(phone, otp) {
    const message = `Your Password Reset OTP is: ${otp}. Do not share this with anyone.`;
    return this.sendSmsViaTwilio(phone, message);
  }
}

export const notificationService = new NotificationService();
export default notificationService;
