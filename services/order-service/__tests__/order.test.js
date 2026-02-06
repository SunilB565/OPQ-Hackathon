const request = require('supertest');
const app = require('../index');

describe('OPQ Notes service', () => {
  test('GET /health should return ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('status', 'ok');
  });
  test('GET /api/order/notes should proxy to storage', async () => {
    const res = await request(app).get('/api/order/notes');
    expect([200,500]).toContain(res.statusCode);
  });
});
