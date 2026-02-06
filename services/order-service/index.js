const express = require('express');
const axios = require('axios');
const client = require('prom-client');

const app = express();
app.use(express.json());

const register = new client.Registry();
client.collectDefaultMetrics({ register });
const requestsCounter = new client.Counter({ name: 'access_requests_total', help: 'Total access requests' });
register.registerMetric(requestsCounter);

const STORAGE_URL = process.env.STORAGE_URL || 'http://storage-service:4000';

// Routes mounted under /api/order
const router = express.Router();

// List notes (proxied to storage service)
router.get('/notes', async (req, res) => {
  try {
    const resp = await axios.get(`${STORAGE_URL}/api/storage/notes`, { timeout: 5000 });
    return res.json(resp.data);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// Request access to a note: body { student: 'name', noteId: 1 }
router.post('/request-access', async (req, res) => {
  const body = req.body;
  if (!body || !body.student || !body.noteId) {
    return res.status(400).json({ error: 'student and noteId required' });
  }
  try {
    const resp = await axios.post(`${STORAGE_URL}/api/storage/requests`, body, { timeout: 5000 });
    requestsCounter.inc();
    return res.json({ status: 'requested', request: resp.data });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.use('/api/order', router);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`OPQ Notes service listening on ${PORT}`));
}

module.exports = app;
