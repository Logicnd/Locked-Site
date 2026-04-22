try {
  require('dotenv').config();
} catch (e) {
  // dotenv is optional; environment variables may be provided externally
}

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');

const app = express();
const PORT = process.env.PORT || 3000;
const PASSWORD = process.env.LOCKED_SITE_PASSWORD || 'secret123';
const LOG_SALT = process.env.LOG_SALT || process.env.SESSION_SECRET || 'dev-salt-change';

const LOG_PATH = path.join(__dirname, 'access_log.json');

function loadLog() {
  try {
    if (!fs.existsSync(LOG_PATH)) return [];
    const data = fs.readFileSync(LOG_PATH, 'utf8');
    return JSON.parse(data || '[]');
  } catch (e) {
    console.error('Failed to load access log:', e);
    return [];
  }
}

function saveLog(entries) {
  try {
    fs.writeFileSync(LOG_PATH, JSON.stringify(entries, null, 2), 'utf8');
  } catch (e) {
    console.error('Failed to save access log:', e);
  }
}

function anonymizeIp(ip) {
  try {
    return crypto.createHash('sha256').update(String(ip || '') + LOG_SALT).digest('hex').slice(0, 12);
  } catch (e) {
    return 'anon';
  }
}

function logAccess(req, success) {
  const rawIp = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || req.ip || '').toString();
  const entry = { id: anonymizeIp(rawIp), time: new Date().toISOString(), success: !!success };
  const entries = loadLog();
  entries.push(entry);
  // keep log short
  const trimmed = entries.slice(-200);
  saveLog(trimmed);
}

app.use(express.static(path.join(__dirname, 'public')));
app.use(bodyParser.urlencoded({ extended: false }));
app.use(session({
  secret: process.env.SESSION_SECRET || 'dev-secret-change-this',
  resave: false,
  saveUninitialized: false,
  cookie: { httpOnly: true, sameSite: 'lax', maxAge: 24 * 60 * 60 * 1000 }
}));

app.get('/', (req, res) => {
  if (req.session && req.session.authorized) {
    const entries = loadLog().slice(-100).reverse();
    const listHtml = entries.map(e => `<tr><td>${escapeHtml(e.id)}</td><td>${escapeHtml(e.time)}</td><td>${e.success? 'Success' : 'Fail'}</td></tr>`).join('\n');
    res.send(`<!doctype html><html><head><meta charset="utf-8"><title>Locked Site</title></head><body><h1>Welcome to the locked site</h1><p><a href="/logout">Logout</a></p><h2>Access log (anonymized)</h2><table border="1" cellpadding="6"><thead><tr><th>Anon ID</th><th>Time</th><th>Result</th></tr></thead><tbody>${listHtml}</tbody></table></body></html>`);
  } else {
    res.sendFile(path.join(__dirname, 'public', 'login.html'));
  }
});

app.post('/login', (req, res) => {
  const password = (req.body.password || '').toString();
  if (password === PASSWORD) {
    req.session.authorized = true;
    logAccess(req, true);
    res.redirect('/');
  } else {
    logAccess(req, false);
    res.redirect('/?error=1');
  }
});

app.get('/logout', (req, res) => {
  req.session.destroy(() => {
    res.redirect('/');
  });
});

function escapeHtml(str) {
  return String(str || '').replace(/&/g, '&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

app.listen(PORT, () => {
  console.log(`Locked site running on http://localhost:${PORT}`);
});
