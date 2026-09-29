// api/_lib/canvasApi.js
// Minimal Canvas LMS REST client: domain validation (SSRF guard), Link-header
// pagination and the handful of endpoints the sync needs.

const { HttpError } = require('./http');

const HOST_RE = /^(?=.{4,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$/;

/**
 * Accepts "swinburne.instructure.com", "https://swinburne.instructure.com/"
 * etc. and returns a bare hostname. Only *.instructure.com plus hosts listed
 * in CANVAS_ALLOWED_DOMAINS (comma separated suffixes, for self-hosted
 * Canvas) are accepted — the server will send the user's token there, so an
 * open allow-list would be a server-side request forgery hole.
 */
function normalizeDomain(input) {
  const host = String(input || '')
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, '')
    .split('/')[0];

  if (!HOST_RE.test(host)) throw new HttpError(400, 'Invalid Canvas domain');

  const extra = (process.env.CANVAS_ALLOWED_DOMAINS || '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  const allowed = ['instructure.com', ...extra];
  if (!allowed.some((suffix) => host === suffix || host.endsWith(`.${suffix}`))) {
    throw new HttpError(
      400,
      'Canvas domain not allowed. Use your *.instructure.com address.'
    );
  }
  return host;
}

function nextLink(header) {
  if (!header) return null;
  for (const part of header.split(',')) {
    if (part.includes('rel="next"')) {
      const m = part.match(/<([^>]+)>/);
      if (m) return m[1];
    }
  }
  return null;
}

class CanvasClient {
  constructor(domain, token) {
    this.domain = normalizeDomain(domain);
    this.token = token;
  }

  async _get(url) {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${this.token}` } });
    if (res.status === 401) throw new HttpError(401, 'Canvas token is invalid or expired');
    if (!res.ok) throw new HttpError(502, `Canvas responded ${res.status}`, url);
    return res;
  }

  /** Follows pagination and only ever follows links on the same host. */
  async list(path) {
    const out = [];
    let url = `https://${this.domain}/api/v1${path}`;
    while (url) {
      if (new URL(url).hostname !== this.domain) break;
      const res = await this._get(url);
      const page = await res.json();
      if (Array.isArray(page)) out.push(...page);
      url = nextLink(res.headers.get('link'));
    }
    return out;
  }

  async self() {
    const res = await this._get(`https://${this.domain}/api/v1/users/self`);
    return res.json();
  }

  courses() {
    return this.list('/courses?enrollment_state=active&include[]=term&per_page=50');
  }

  assignments(courseId) {
    return this.list(
      `/courses/${courseId}/assignments?include[]=submission&order_by=due_at&per_page=50`
    );
  }

  modules(courseId) {
    return this.list(`/courses/${courseId}/modules?per_page=50`);
  }
}

module.exports = { CanvasClient, normalizeDomain, nextLink };
