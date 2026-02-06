const express = require('express');
const client = require('prom-client');

const app = express();
app.use(express.json());

const register = new client.Registry();
client.collectDefaultMetrics({ register });
const savedCounter = new client.Counter({ name: 'notes_saved_total', help: 'Total notes saved or requests processed' });
register.registerMetric(savedCounter);

// Sample data: predefined notes and students
let notes = [
  { id: 1, title: 'AWS Questions', description: 'Collection of AWS interview questions', owner: 'admin' },
  { id: 2, title: 'Node.js Notes', description: 'Useful Node.js patterns', owner: 'admin' }
];

let students = [
  { id: 1, name: 'alice' },
  { id: 2, name: 'bob' },
  { id: 3, name: 'charlie' }
];

let requests = []; // { id, student, noteId, status: 'pending'|'approved' }

// Routes mounted under /api/storage
const router = express.Router();

// List notes (public metadata)
router.get('/notes', (req, res) => {
  res.json({ notes });
});

// List students
router.get('/students', (req, res) => {
  res.json({ students });
});

// Student requests access to a note
router.post('/requests', (req, res) => {
  const { student, noteId } = req.body || {};
  if (!student || !noteId) return res.status(400).json({ error: 'student and noteId required' });
  const studentExists = students.find(s => s.name === student || s.id === student);
  const noteExists = notes.find(n => n.id === Number(noteId));
  if (!studentExists) return res.status(400).json({ error: 'student not found' });
  if (!noteExists) return res.status(400).json({ error: 'note not found' });
  const reqId = requests.length + 1;
  const r = { id: reqId, student: studentExists.name, noteId: Number(noteId), status: 'pending' };
  requests.push(r);
  savedCounter.inc();
  res.json(r);
});

// Admin approves a request: POST /approve { requestId }
router.post('/approve', (req, res) => {
  const token = req.headers['x-admin-token'] || req.headers['x-admin-Token'];
  if (process.env.ADMIN_TOKEN && process.env.ADMIN_TOKEN !== '') {
    if (!token || token !== process.env.ADMIN_TOKEN) {
      return res.status(403).json({ error: 'unauthorized' });
    }
  }
  const { requestId } = req.body || {};
  if (!requestId) return res.status(400).json({ error: 'requestId required' });
  const r = requests.find(x => x.id === Number(requestId));
  if (!r) return res.status(404).json({ error: 'request not found' });
  r.status = 'approved';
  savedCounter.inc();
  res.json(r);
});
// List requests
router.get('/requests', (req, res) => {
  res.json({ requests });
});

// Returns content of a note to an approved student: GET /notes/:id/content?student=alice
router.get('/notes/:id/content', (req, res) => {
  const noteId = Number(req.params.id);
  const student = req.query.student;
  const note = notes.find(n => n.id === noteId);
  if (!note) return res.status(404).json({ error: 'note not found' });
  const approved = requests.find(r => r.noteId === noteId && r.student === student && r.status === 'approved');
  if (!approved) return res.status(403).json({ error: 'access not granted' });
  // Sample content
  const content = note.title === 'AWS Questions' ? [ 'What is IAM?', 'Explain EBS vs EFS' ] : [ 'Event loop', 'Streams' ];
  res.json({ id: note.id, title: note.title, content });
});

app.use('/api/storage', router);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const PORT = process.env.PORT || 4000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`OPQ Storage service listening on ${PORT}`));
}

module.exports = app;
