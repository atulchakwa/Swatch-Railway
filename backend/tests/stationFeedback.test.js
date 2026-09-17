import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app.js';
import { db } from '../src/database/index.js';

describe('Station Feedback API', () => {
  const testPhone = '9876543210';
  const testStationId = 'NDLS';

  it('GET /api/station-feedback/version should return service version info', async () => {
    const res = await request(app).get('/api/station-feedback/version');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('service');
    expect(res.body).toHaveProperty('build');
  });

  it('GET /api/station-feedback/station/:stationId should return station brief', async () => {
    const res = await request(app).get(`/api/station-feedback/station/${testStationId}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('stationId');
    expect(res.body).toHaveProperty('stationName');
  });

  it('POST /api/station-feedback/send-otp should initiate OTP generation', async () => {
    const res = await request(app)
      .post('/api/station-feedback/send-otp')
      .send({ phone: testPhone, stationId: testStationId });
    
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body).toHaveProperty('message');
  });

  it('POST /api/station-feedback/verify-otp with fallback OTP 123456 should return JWT token', async () => {
    // First trigger send-otp to create doc
    await request(app)
      .post('/api/station-feedback/send-otp')
      .send({ phone: testPhone, stationId: testStationId });

    const res = await request(app)
      .post('/api/station-feedback/verify-otp')
      .send({ phone: testPhone, otp: '123456' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body).toHaveProperty('token');
  });

  it('POST /api/station-feedback/submit should record feedback with category, rating, comments, and imageUrl', async () => {
    // First get verification token
    await request(app)
      .post('/api/station-feedback/send-otp')
      .send({ phone: testPhone, stationId: testStationId });

    const verifyRes = await request(app)
      .post('/api/station-feedback/verify-otp')
      .send({ phone: testPhone, otp: '123456' });

    const token = verifyRes.body.token;

    const submitRes = await request(app)
      .post('/api/station-feedback/submit')
      .set('Authorization', `Bearer ${token}`)
      .send({
        stationId: testStationId,
        areaId: 'platform_1',
        category: 'platform_cleanliness',
        rating: 4,
        comments: 'Platform 1 was very clean and well maintained.',
        phone: testPhone,
        imageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
      });

    expect(submitRes.status).toBe(201);
    expect(submitRes.body).toHaveProperty('uid');
    expect(submitRes.body.feedback.category).toBe('platform_cleanliness');
    expect(submitRes.body.feedback.rating).toBe(4);
    expect(submitRes.body.feedback.areaId).toBe('platform_1');
  });
});
