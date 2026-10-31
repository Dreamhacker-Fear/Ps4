// Orbis Auth v2 - Cloudflare Worker + Durable Object (ES modules)
//
//   GET  /                     -> "Orbis Auth is online."
//   POST /setup                -> registers /psn. OFF by default (SETUP_ENABLED). Needs
//                                 "Authorization: Bearer <SIGNING_SECRET>" - never put the secret in a URL.
//   POST / or /interactions    -> Discord interactions (/psn)
//   POST /verify  {uid, code}  -> exchanges a passcode for a session token   (POST only)
//   POST /session {uid, token} -> re-checks a session token                  (POST only)
//   POST /presence, /friends/search, /friends/request, /friends/respond, /friends/remove,
//   POST /admin/users          -> script friends + owner list. All need a valid session token.
//
// Needs: Durable Object binding AUTH (class AuthState), secrets DISCORD_PUBLIC_KEY,
// DISCORD_BOT_TOKEN, SIGNING_SECRET.  All state lives in the Durable Object, so every
// read-modify-write is atomic. KV (PSN_USERS) is no longer used.

const APP_ID = "1565803212982845521";
const GUILD_ID = "1565451165213401149";

const CODE_LEN = 4;                 // fixed at 4 digits (PSN login design)
const CODE_TTL = 86400;             // an unused passcode lives 24 hours
const SESSION_TTL = 86400;          // a session token lives 24 hours
const REQUIRE_PROFILE_PROOF = true; // prove the Roblox account is yours (see isOwner below)
const SIG_MAX_AGE = 300;            // Discord requests older/newer than 5 min are rejected
const OWNER_UID = "8407673016";    // the Roblox account that gets the owner panel (enforced HERE, on the server)
const ONLINE_WINDOW = 150;          // seen in the last 150 s = online (the dashboard pings every 60 s)
const MAX_FRIENDS = 100;
const MAX_PENDING = 30;
const SETUP_ENABLED = false;        // /setup is disabled (404). Set true only while re-registering /psn.

const LIMITS = {
  ipReqPerMin: 30,   // verify requests per IP per minute
  ipFail: 12,        // failed attempts per IP per 10 minutes
  uidFail: 10,       // failed attempts per Roblox user id per 10 minutes
  globalFail: 150,   // failed attempts from everybody per minute (emergency brake)
  sessionPerMin: 60, // session checks per IP per minute
  psnPerMin: 10,     // /psn uses per Discord user per minute
  presencePerMin: 12,
  friendOpsPerMin: 30,
  searchPerMin: 10,
  adminPerMin: 20,
};

const nowSec = () => Math.floor(Date.now() / 1000);
const isUid = (s) => /^\d{1,20}$/.test(String(s));
const isCode = (s) => new RegExp(`^\\d{${CODE_LEN}}$`).test(String(s));
const isToken = (s) => /^[0-9a-f]{64}$/.test(String(s));

function randomHex(bytes) {
  const b = new Uint8Array(bytes);
  crypto.getRandomValues(b);
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}
function randomCode() {
  const max = 10 ** CODE_LEN;
  const limit = Math.floor(2 ** 32 / max) * max; // rejection sampling, no modulo bias
  const buf = new Uint32Array(1);
  let x;
  do { crypto.getRandomValues(buf); x = buf[0]; } while (x >= limit);
  return String(x % max).padStart(CODE_LEN, "0");
}
async function sha256Hex(s) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const MSG = {
  invalid: "Wrong, expired or already used passcode. Run /psn in Discord for a fresh one.",
  proof_missing: "Add the phrase from your /psn message to the About section of your Roblox profile, then try again.",
  ownership_unavailable: "Could not check your Roblox profile right now. Try again in a moment.",
  session_invalid: "Your session expired. Run /psn in Discord for a new passcode.",
  bad_request: "That request was not valid.",
  server_error: "The login server had a problem. Try again in a moment.",
  forbidden: "This is only available to the owner.",
  not_found: "That user was not found.",
  limit_reached: "That list is full.",
};
const STATUS = { invalid: 401, proof_missing: 403, ownership_unavailable: 503, session_invalid: 401,
  rate_limited: 429, bad_request: 400, server_error: 503, forbidden: 403, not_found: 404, limit_reached: 409 };

// ---------------------------------------------------------------------------
// Roblox account ownership.
// A Roblox client can send any user id it likes, so the id alone proves nothing.
// We therefore require a one-time phrase (given only to the Discord owner of the passcode)
// to appear in the "About" section of that Roblox profile. Only the account owner can edit
// that text. Read straight from Roblox's own API by the server, never from the client.
// ---------------------------------------------------------------------------
async function fetchProfileDescription(uid) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 4000);
  try {
    const r = await fetch(`https://users.roblox.com/v1/users/${uid}`, {
      signal: ctrl.signal, headers: { Accept: "application/json" },
    });
    if (!r.ok) return null;
    const j = await r.json();
    return typeof j.description === "string" ? j.description : null;
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// Real Roblox name for a user id (so nobody can register under someone else's name).
async function fetchRobloxName(uid) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 4000);
  try {
    const r = await fetch(`https://users.roblox.com/v1/users/${uid}`, {
      signal: ctrl.signal, headers: { Accept: "application/json" },
    });
    if (!r.ok) return null;
    const j = await r.json();
    if (typeof j.name !== "string") return null;
    return { name: j.name, display: typeof j.displayName === "string" ? j.displayName : j.name };
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// Durable Object: one global instance. Storage reads/writes with no network await in between
// are atomic here, which removes the KV race conditions (claiming, counters, uniqueness).
// ---------------------------------------------------------------------------
export class AuthState {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  // Every multi-step read/write below runs inside ONE storage transaction: it commits as a unit,
  // rolls back completely if anything throws, and nothing else can interleave with it.
  // Rule inside a transaction: only storage calls, never fetch/crypto (those happen outside).
  tx(fn) {
    return this.state.storage.transaction(fn);
  }

  async fetch(request) {
    const path = new URL(request.url).pathname;
    let out;
    try {
      const body = await request.json(); // inside the try: malformed JSON can never escape as an uncaught error
      if (!body || typeof body !== "object" || Array.isArray(body)) out = { ok: false, reason: "bad_request" };
      else if (path === "/issue") out = await this.issue(body);
      else if (path === "/claim") out = await this.claim(body);
      else if (path === "/session") out = await this.session(body);
      else if (path === "/presence") out = await this.presence(body);
      else if (path === "/friends/search") out = await this.friendSearch(body);
      else if (path === "/friends/request") out = await this.friendRequest(body);
      else if (path === "/friends/respond") out = await this.friendRespond(body);
      else if (path === "/friends/remove") out = await this.friendRemove(body);
      else if (path === "/admin/users") out = await this.adminUsers(body);
      else out = { ok: false, reason: "bad_request" };
    } catch (e) {
      out = { ok: false, reason: e instanceof SyntaxError ? "bad_request" : "server_error" };
    }
    if (!out.ok && out.reason && !out.message) out.message = MSG[out.reason];
    if (!out.ok && !out.status) out.status = STATUS[out.reason] || 400;
    return Response.json(out);
  }

  // ----- counters (fixed windows) - always called with a transaction handle -----
  async txBump(txn, name, windowSec) {
    const t = nowSec();
    const w = Math.floor(t / windowSec);
    const key = `rl:${windowSec}:${w}:${name}`;
    const v = ((await txn.get(key)) || 0) + 1;
    await txn.put(key, v);
    return { count: v, retry: (w + 1) * windowSec - t };
  }
  async txPeek(txn, name, windowSec) {
    const t = nowSec();
    const w = Math.floor(t / windowSec);
    const v = (await txn.get(`rl:${windowSec}:${w}:${name}`)) || 0;
    return { count: v, retry: (w + 1) * windowSec - t };
  }
  async txFail(txn, ip, uid) {
    await this.txBump(txn, `ipfail:${ip}`, 600);
    if (isUid(uid)) await this.txBump(txn, `uidfail:${uid}`, 600);
    await this.txBump(txn, "gfail", 60);
  }
  limited(retry, busy) {
    return {
      ok: false, reason: "rate_limited", retry, status: 429,
      message: busy ? `Login is busy right now. Try again in ${retry}s.` : `Too many attempts. Try again in ${retry}s.`,
    };
  }
  async failTx(ip, uid, reason) {
    await this.tx((txn) => this.txFail(txn, ip, uid));
    return { ok: false, reason };
  }
  async ensureAlarm() {
    if ((await this.state.storage.getAlarm()) == null) await this.state.storage.setAlarm(Date.now() + 3600e3);
  }

  // ----- /psn: hand out (or re-show) a passcode. Whole operation = one transaction -----
  async issue(body) {
    const did = String(body.did || "");
    const iid = body.iid ? String(body.iid) : "";
    if (!/^\d{5,25}$/.test(did)) return { ok: false, reason: "bad_request" };

    const out = await this.tx(async (txn) => {
      const t = nowSec();
      if (iid) { // replay guard: an interaction id can be used once
        if (await txn.get(`seen:${iid}`)) return { ok: false, reason: "bad_request" };
        await txn.put(`seen:${iid}`, t + 900);
      }
      const r = await this.txBump(txn, `psn:${did}`, 60);
      if (r.count > LIMITS.psnPerMin) return this.limited(r.retry);

      const cur = await txn.get(`user:${did}`); // { code, exp }
      if (cur) {
        const rec = await txn.get(`code:${cur.code}`);
        if (rec && rec.did === did && rec.exp > t) {
          return { ok: true, code: cur.code, challenge: rec.challenge, exp: rec.exp }; // same code again
        }
        if (rec && rec.did === did) await txn.delete(`code:${cur.code}`); // only ever delete our own stale record
        await txn.delete(`user:${did}`);
      }
      for (let i = 0; i < 60; i++) { // codes stay unique: check + write happen in the same transaction
        const code = randomCode();
        const ex = await txn.get(`code:${code}`);
        if (ex && ex.exp > t) continue; // taken by a live code
        const rec = { did, challenge: "orbis-" + randomHex(5), iat: t, exp: t + CODE_TTL };
        await txn.put(`code:${code}`, rec);
        await txn.put(`user:${did}`, { code, exp: rec.exp });
        return { ok: true, code, challenge: rec.challenge, exp: rec.exp };
      }
      return { ok: false, reason: "server_error", message: "No free passcode right now. Try again later." };
    });
    if (out.ok) await this.ensureAlarm();
    return out;
  }

  // ----- /verify: passcode (+ Roblox profile proof) -> session token. A passcode works ONCE. -----
  async claim(body) {
    const ip = String(body.ip || "unknown");
    const uid = String(body.uid == null ? "" : body.uid);
    const code = String(body.code == null ? "" : body.code);

    // step 1 (one transaction): limits + read the code
    const pre = await this.tx(async (txn) => {
      const q = await this.txBump(txn, `ipreq:${ip}`, 60);
      if (q.count > LIMITS.ipReqPerMin) return { out: this.limited(q.retry) };
      const ipF = await this.txPeek(txn, `ipfail:${ip}`, 600);
      if (ipF.count >= LIMITS.ipFail) return { out: this.limited(ipF.retry) };
      const gF = await this.txPeek(txn, "gfail", 60);
      if (gF.count >= LIMITS.globalFail) return { out: this.limited(gF.retry, true) };
      if (isUid(uid)) {
        const uF = await this.txPeek(txn, `uidfail:${uid}`, 600);
        if (uF.count >= LIMITS.uidFail) return { out: this.limited(uF.retry) };
      }
      if (!isUid(uid) || !isCode(code)) {
        await this.txFail(txn, ip, uid);
        return { out: { ok: false, reason: "invalid" } };
      }
      const rec = await txn.get(`code:${code}`);
      if (!rec || rec.exp <= nowSec()) {
        await this.txFail(txn, ip, uid);
        return { out: { ok: false, reason: "invalid" } };
      }
      return { rec };
    });
    if (pre.out) return pre.out;
    const rec = pre.rec;

    // step 2 (outside any transaction): Roblox profile proof - a network call
    if (REQUIRE_PROFILE_PROOF) {
      const desc = await fetchProfileDescription(uid);
      if (desc === null) return { ok: false, reason: "ownership_unavailable" };
      if (!desc.includes(rec.challenge)) return this.failTx(ip, uid, "proof_missing");
    }

    const token = randomHex(32);
    const tokenHash = await sha256Hex(token); // crypto happens BEFORE the transaction

    // step 3 (one transaction): re-check, consume the code, create the session
    const out = await this.tx(async (txn) => {
      const t = nowSec();
      const rec2 = await txn.get(`code:${code}`);
      if (!rec2 || rec2.exp <= t || rec2.challenge !== rec.challenge) { // someone else used it meanwhile
        await this.txFail(txn, ip, uid);
        return { ok: false, reason: "invalid" };
      }
      await txn.delete(`code:${code}`); // single use
      const u = await txn.get(`user:${rec2.did}`);
      if (u && u.code === code) await txn.delete(`user:${rec2.did}`);
      await txn.put(`sess:${tokenHash}`, { uid, did: rec2.did, exp: t + SESSION_TTL });
      return { ok: true, token, exp: t + SESSION_TTL };
    });
    if (out.ok) await this.ensureAlarm();
    return out;
  }

  // ----- /session: later launches use the token, not the 4-digit code -----
  async session(body) {
    const ip = String(body.ip || "unknown");
    const uid = String(body.uid == null ? "" : body.uid);
    const token = String(body.token == null ? "" : body.token);
    const hash = isToken(token) ? await sha256Hex(token) : null; // crypto before the transaction
    return this.tx(async (txn) => {
      const q = await this.txBump(txn, `sreq:${ip}`, 60);
      if (q.count > LIMITS.sessionPerMin) return this.limited(q.retry);
      const f = await this.txPeek(txn, `sfail:${ip}`, 600);
      if (f.count >= 20) return this.limited(f.retry);
      const s = hash && isUid(uid) ? await txn.get(`sess:${hash}`) : null;
      if (!s || s.uid !== uid || s.exp <= nowSec()) {
        await this.txBump(txn, `sfail:${ip}`, 600);
        return { ok: false, reason: "session_invalid" };
      }
      return { ok: true, exp: s.exp };
    });
  }


  // ===== script users: presence, friends, owner list. Every call needs a valid session token. =====
  // Checks the session first (invalid sessions write nothing), then counts the call per user.
  async authedTx(body, name, perMin, fn) {
    const uid = String(body.uid == null ? "" : body.uid);
    const token = String(body.token == null ? "" : body.token);
    const hash = isToken(token) ? await sha256Hex(token) : null; // crypto before the transaction
    return this.tx(async (txn) => {
      const t = nowSec();
      const s = hash && isUid(uid) ? await txn.get(`sess:${hash}`) : null;
      if (!s || s.uid !== uid || s.exp <= t) return { ok: false, reason: "session_invalid" };
      const q = await this.txBump(txn, `${name}:${uid}`, 60);
      if (q.count > perMin) return this.limited(q.retry);
      return fn(txn, uid, t);
    });
  }
  async frGet(txn, id) {
    const f = await txn.get(`fr:${id}`);
    return { friends: (f && f.friends) || [], incoming: (f && f.incoming) || [], outgoing: (f && f.outgoing) || [] };
  }
  async userView(txn, id, t) {
    const u = await txn.get(`usr:${id}`);
    if (!u || !u.name) return null;
    const ago = Math.max(0, t - (u.last || 0));
    return { uid: id, name: u.name, display: u.display || u.name, online: ago <= ONLINE_WINDOW, ago };
  }
  async views(txn, ids, t) {
    const out = [];
    for (const id of ids) { const v = await this.userView(txn, id, t); if (v) out.push(v); }
    out.sort((a, b) => (a.online !== b.online ? (a.online ? -1 : 1) : a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1));
    return out;
  }

  // heartbeat: "I am online". Also returns my friends, friend requests and whether I am the owner.
  async presence(body) {
    const uid = String(body.uid == null ? "" : body.uid);
    const pre = await this.authedTx(body, "pres", LIMITS.presencePerMin, async (txn, id, t) => {
      const u = await txn.get(`usr:${id}`);
      return { ok: true, fetch: !u || !u.name || t - (u.nameAt || 0) > 86400 };
    });
    if (!pre.ok) return pre;
    const prof = pre.fetch ? await fetchRobloxName(uid) : null; // network call, outside any transaction
    return this.authedTx(body, "presw", LIMITS.presencePerMin * 2, async (txn, id, t) => {
      const u = (await txn.get(`usr:${id}`)) || { uid: id, first: t };
      if (prof) { u.name = prof.name; u.display = prof.display; u.nameAt = t; }
      if (!u.name) { u.name = `user${id.slice(-4)}`; u.display = u.name; }
      u.last = t;
      await txn.put(`usr:${id}`, u);
      const fr = await this.frGet(txn, id);
      return {
        ok: true, owner: id === OWNER_UID,
        friends: await this.views(txn, fr.friends, t),
        incoming: await this.views(txn, fr.incoming, t),
        outgoing: fr.outgoing.length,
      };
    });
  }

  async friendSearch(body) {
    const q = String(body.q == null ? "" : body.q).trim().toLowerCase();
    if (q.length < 2 || q.length > 20) return { ok: false, reason: "bad_request" };
    return this.authedTx(body, "fsearch", LIMITS.searchPerMin, async (txn, id, t) => {
      const fr = await this.frGet(txn, id);
      const all = await txn.list({ prefix: "usr:", limit: 5000 });
      const out = [];
      for (const [k, u] of all) {
        const other = k.slice(4);
        if (other === id || !u.name) continue;
        const n = u.name.toLowerCase();
        const d = (u.display || u.name).toLowerCase();
        if (!n.includes(q) && !d.includes(q)) continue;
        out.push({
          uid: other, name: u.name, display: u.display || u.name,
          online: t - (u.last || 0) <= ONLINE_WINDOW,
          state: fr.friends.includes(other) ? "friend" : fr.outgoing.includes(other) ? "sent" : fr.incoming.includes(other) ? "incoming" : "none",
          s: n.startsWith(q) || d.startsWith(q) ? 0 : 1,
        });
      }
      out.sort((a, b) => a.s - b.s || (a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1));
      return { ok: true, users: out.slice(0, 10).map(({ s, ...rest }) => rest) };
    });
  }

  async friendRequest(body) {
    const to = String(body.to == null ? "" : body.to);
    if (!isUid(to)) return { ok: false, reason: "bad_request" };
    return this.authedTx(body, "fops", LIMITS.friendOpsPerMin, async (txn, id) => {
      if (to === id) return { ok: false, reason: "bad_request" };
      if (!(await txn.get(`usr:${to}`))) return { ok: false, reason: "not_found" };
      const me = await this.frGet(txn, id);
      const them = await this.frGet(txn, to);
      if (me.friends.includes(to)) return { ok: true, state: "friend" };
      if (me.incoming.includes(to)) { // they already asked me: this makes us friends
        if (me.friends.length >= MAX_FRIENDS || them.friends.length >= MAX_FRIENDS) return { ok: false, reason: "limit_reached" };
        me.incoming = me.incoming.filter((x) => x !== to);
        them.outgoing = them.outgoing.filter((x) => x !== id);
        me.friends.push(to); them.friends.push(id);
        await txn.put(`fr:${id}`, me); await txn.put(`fr:${to}`, them);
        return { ok: true, state: "friend" };
      }
      if (me.outgoing.includes(to)) return { ok: true, state: "sent" };
      if (me.outgoing.length >= MAX_PENDING || them.incoming.length >= MAX_PENDING) return { ok: false, reason: "limit_reached" };
      me.outgoing.push(to); them.incoming.push(id);
      await txn.put(`fr:${id}`, me); await txn.put(`fr:${to}`, them);
      return { ok: true, state: "sent" };
    });
  }

  async friendRespond(body) {
    const from = String(body.from == null ? "" : body.from);
    if (!isUid(from)) return { ok: false, reason: "bad_request" };
    const accept = body.accept === true;
    return this.authedTx(body, "fops", LIMITS.friendOpsPerMin, async (txn, id) => {
      const me = await this.frGet(txn, id);
      if (!me.incoming.includes(from)) return { ok: false, reason: "not_found" };
      const them = await this.frGet(txn, from);
      me.incoming = me.incoming.filter((x) => x !== from);
      them.outgoing = them.outgoing.filter((x) => x !== id);
      if (accept) {
        if (me.friends.length >= MAX_FRIENDS || them.friends.length >= MAX_FRIENDS) return { ok: false, reason: "limit_reached" };
        if (!me.friends.includes(from)) me.friends.push(from);
        if (!them.friends.includes(id)) them.friends.push(id);
      }
      await txn.put(`fr:${id}`, me); await txn.put(`fr:${from}`, them);
      return { ok: true, accepted: accept };
    });
  }

  async friendRemove(body) {
    const other = String(body.other == null ? "" : body.other);
    if (!isUid(other)) return { ok: false, reason: "bad_request" };
    return this.authedTx(body, "fops", LIMITS.friendOpsPerMin, async (txn, id) => {
      const me = await this.frGet(txn, id);
      const them = await this.frGet(txn, other);
      me.friends = me.friends.filter((x) => x !== other);
      them.friends = them.friends.filter((x) => x !== id);
      await txn.put(`fr:${id}`, me); await txn.put(`fr:${other}`, them);
      return { ok: true };
    });
  }

  // owner only: everybody who ever used the dashboard. The owner check is HERE on the server.
  async adminUsers(body) {
    return this.authedTx(body, "admin", LIMITS.adminPerMin, async (txn, id, t) => {
      if (id !== OWNER_UID) return { ok: false, reason: "forbidden" };
      const all = await txn.list({ prefix: "usr:", limit: 5000 });
      const users = [];
      let online = 0;
      for (const [k, u] of all) {
        const ago = Math.max(0, t - (u.last || 0));
        const on = ago <= ONLINE_WINDOW;
        if (on) online++;
        users.push({ uid: k.slice(4), name: u.name || "?", display: u.display || u.name || "?", online: on, ago, first: u.first || 0 });
      }
      return { ok: true, total: users.length, online, users };
    });
  }

  // ----- hourly cleanup of expired data -----
  async alarm() {
    const remaining = await this.tx(async (txn) => {
      const t = nowSec();
      const all = await txn.list();
      const del = [];
      for (const [k, v] of all) {
        if (k.startsWith("code:") || k.startsWith("sess:") || k.startsWith("user:")) {
          if (v && v.exp <= t) del.push(k);
        } else if (k.startsWith("seen:")) {
          if (v <= t) del.push(k);
        } else if (k.startsWith("rl:")) {
          const [, win, w] = k.split(":");
          if ((Number(w) + 2) * Number(win) <= t) del.push(k);
        }
      }
      for (let i = 0; i < del.length; i += 100) await txn.delete(del.slice(i, i + 100));
      return all.size - del.length;
    });
    if (remaining > 0) await this.state.storage.setAlarm(Date.now() + 3600e3);
  }
}

// ---------------------------------------------------------------------------
// Worker (front door)
// ---------------------------------------------------------------------------
const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
const discordReply = (content) => json({ type: 4, data: { content, flags: 64 } });

async function callAuth(env, path, payload) {
  const stub = env.AUTH.get(env.AUTH.idFromName("orbis"));
  const res = await stub.fetch("https://auth.internal" + path, { method: "POST", body: JSON.stringify(payload) });
  return res.json();
}

function hexToBytes(h) {
  const a = new Uint8Array(h.length / 2);
  for (let i = 0; i < a.length; i++) a[i] = parseInt(h.substr(i * 2, 2), 16);
  return a;
}
async function verifyDiscord(env, sig, ts, body) {
  try {
    const data = new TextEncoder().encode(ts + body);
    const pub = hexToBytes(env.DISCORD_PUBLIC_KEY);
    try {
      const key = await crypto.subtle.importKey("raw", pub, { name: "Ed25519" }, false, ["verify"]);
      return await crypto.subtle.verify("Ed25519", key, hexToBytes(sig), data);
    } catch (_) {
      const key = await crypto.subtle.importKey(
        "raw", pub, { name: "NODE-ED25519", namedCurve: "NODE-ED25519" }, false, ["verify"]);
      return await crypto.subtle.verify("NODE-ED25519", key, hexToBytes(sig), data);
    }
  } catch (_) {
    return false;
  }
}

async function handleDiscord(request, env) {
  const sig = request.headers.get("x-signature-ed25519");
  const ts = request.headers.get("x-signature-timestamp");
  const body = await request.text();
  if (!sig || !ts || !/^\d{10}$/.test(ts)) return new Response("Bad request", { status: 401 });
  // freshness: a captured request cannot be replayed later
  if (Math.abs(nowSec() - Number(ts)) > SIG_MAX_AGE) return new Response("Stale request", { status: 401 });
  if (!(await verifyDiscord(env, sig, ts, body))) return new Response("Bad request signature", { status: 401 });

  let it;
  try { it = JSON.parse(body); } catch (_) { return new Response("Bad request", { status: 400 }); }
  if (it.type === 1) return json({ type: 1 }); // PING
  if (it.type === 2 && it.data && it.data.name === "psn") {
    if (it.guild_id !== GUILD_ID) return discordReply("This command only works in the Orbis server.");
    const did = it.member && it.member.user && it.member.user.id;
    if (!did) return discordReply("Could not read your Discord account. Try again in the server.");
    let r;
    try { r = await callAuth(env, "/issue", { did, iid: it.id }); } catch (_) { r = null; }
    if (!r || !r.ok) return discordReply(r && r.message ? r.message : "Could not create a code right now. Please try again in a moment.");
    let msg = `Your PS4 passcode: **${r.code}**\nExpires <t:${r.exp}:R>. It works once and links to your Roblox account, so don't share it.`;
    if (REQUIRE_PROFILE_PROOF) {
      msg += `\n\nBefore you log in, add this phrase to the **About** section of your Roblox profile:\n\`${r.challenge}\`\n` +
             `You can remove it again after you are logged in.`;
    }
    return discordReply(msg);
  }
  return discordReply("Unknown command.");
}

async function handleAuthPost(request, env, path) {
  if (request.method !== "POST") return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 405);
  const ip = request.headers.get("CF-Connecting-IP") || "unknown";
  let b;
  try {
    const text = await request.text();
    if (text.length > 512) return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 413);
    b = JSON.parse(text);
  } catch (_) {
    return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 400);
  }
  const payload = path === "/verify"
    ? { ip, uid: String(b.uid == null ? "" : b.uid), code: String(b.code == null ? "" : b.code) }
    : { ip, uid: String(b.uid == null ? "" : b.uid), token: String(b.token == null ? "" : b.token) };
  try {
    const out = await callAuth(env, path === "/verify" ? "/claim" : "/session", payload);
    const status = out.ok ? 200 : (out.status || 400);
    delete out.status;
    return json(out, status);
  } catch (_) {
    return json({ ok: false, reason: "server_error", message: MSG.server_error }, 503); // fail closed
  }
}

async function safeEqual(a, b) { // constant-time: compare SHA-256 digests byte by byte
  const enc = new TextEncoder();
  const ha = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(a)));
  const hb = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(b)));
  let d = 0;
  for (let i = 0; i < ha.length; i++) d |= ha[i] ^ hb[i];
  return d === 0;
}

const SIGNED_PATHS = new Set(["/presence", "/friends/search", "/friends/request", "/friends/respond", "/friends/remove", "/admin/users"]);
async function handleSigned(request, env, path) {
  if (request.method !== "POST") return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 405);
  let b;
  try {
    const text = await request.text();
    if (text.length > 1024) return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 413);
    b = JSON.parse(text);
    if (!b || typeof b !== "object" || Array.isArray(b)) throw new Error("bad");
  } catch (_) {
    return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 400);
  }
  const str = (v) => String(v == null ? "" : v);
  const payload = { uid: str(b.uid), token: str(b.token), q: str(b.q), to: str(b.to), from: str(b.from), other: str(b.other), accept: b.accept === true };
  try {
    const out = await callAuth(env, path, payload);
    const status = out.ok ? 200 : (out.status || 400);
    delete out.status;
    return json(out, status);
  } catch (_) {
    return json({ ok: false, reason: "server_error", message: MSG.server_error }, 503);
  }
}

async function handleSetup(request, env) {
  if (!SETUP_ENABLED) return new Response("Not found", { status: 404 });
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const m = (request.headers.get("Authorization") || "").match(/^Bearer (.+)$/);
  if (!env.SIGNING_SECRET || !m || !(await safeEqual(m[1], env.SIGNING_SECRET))) {
    return new Response("Forbidden", { status: 403 });
  }
  const res = await fetch(`https://discord.com/api/v10/applications/${APP_ID}/guilds/${GUILD_ID}/commands`, {
    method: "PUT",
    headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, "Content-Type": "application/json" },
    body: JSON.stringify([{ name: "psn", description: "Get your PS4 Dashboard passcode", type: 1, dm_permission: false }]),
  });
  return new Response(res.ok ? "Command registered." : `Discord said ${res.status}`, { status: res.ok ? 200 : 502 });
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (request.method === "GET" && pathname === "/") return new Response("Orbis Auth is online.");
    if (pathname === "/setup") return handleSetup(request, env);
    if (pathname === "/verify" || pathname === "/session") return handleAuthPost(request, env, pathname);
    if (SIGNED_PATHS.has(pathname)) return handleSigned(request, env, pathname);
    if (request.method === "POST" && (pathname === "/" || pathname === "/interactions")) return handleDiscord(request, env);
    return new Response("Not found", { status: 404 });
  },
};
t
