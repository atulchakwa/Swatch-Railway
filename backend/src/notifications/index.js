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

  async sendSmsVia2Factor(phone, message) {
    if (!config.sms.twoFactorApiKey) {
      logger.warn('NotificationService', '2Factor API key not configured');
      return null;
    }

    try {
      const url = `https://2factor.in/API/V1/${config.sms.twoFactorApiKey}/VOICE/${phone}/${message}`;
      const response = await axios.get(url);

      if (response.data.Status === 'Success') {
        logger.info('NotificationService', `Voice OTP sent via 2Factor to ${phone}`);
        return response.data;
      }
      throw new Error(response.data.Details || '2Factor voice OTP failed');
    } catch (error) {
      logger.error('NotificationService', '2Factor SMS error', error);
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
    return this.sendSmsVia2Factor(phone, otp);
  }

  async sendPasswordResetOtpSms(phone, otp) {
    const message = `Your Password Reset OTP is: ${otp}. Do not share this with anyone.`;
    return this.sendSmsViaTwilio(phone, message);
  }
}

export const notificationService = new NotificationService();
export default notificationService;
