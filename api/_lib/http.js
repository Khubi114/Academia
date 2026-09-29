// api/_lib/http.js
// Tiny wrapper that gives every endpoint the same behaviour:
//   * CORS preflight handling
//   * HTTP method allow-list
//   * Supabase JWT verification (the caller's identity comes from the token,
//     never from a client-supplied user id)
//   * uniform JSON error responses

const { supabaseAdmin } = require('./supabase');

class HttpError extends Error {
  constructor(status, message, detail) {
    super(message);
    this.status = status;
    this.detail = detail;
  }
}

/** Extracts and verifies the Supabase access token; returns the user id. */
async function requireUser(req) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new HttpError(401, 'Missing Authorization bearer token');

  const { data, error } = await supabaseAdmin.auth.getUser(match[1]);
  if (error || !data?.user) throw new HttpError(401, 'Invalid or expired session');
  return data.user.id;
}

/**
 * Wraps an endpoint.
 * @param {string[]} methods allowed HTTP methods
 * @param {(ctx: {req, res, userId: string, body: object, query: object}) => Promise<object>} fn
 *        returns the JSON body of a 200 response
 */
function endpoint(methods, fn) {
  return async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') return res.status(204).end();
    if (!methods.includes(req.method)) {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
      const userId = await requireUser(req);
      const result = await fn({
        req,
        res,
        userId,
        body: req.body || {},
        query: req.query || {},
      });
      return res.status(200).json(result);
    } catch (err) {
      if (err instanceof HttpError) {
        return res.status(err.status).json({ error: err.message, detail: err.detail });
      }
      console.error(`[${req.url}]`, err);
      return res.status(500).json({ error: 'Internal error', detail: err.message });
    }
  };
}

module.exports = { endpoint, HttpError };
