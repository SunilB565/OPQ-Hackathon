const request = require('supertest');
const app = require('../index');

describe('OPQ Storage service', () => {
  test('GET /health should return ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('status', 'ok');
  });
});
