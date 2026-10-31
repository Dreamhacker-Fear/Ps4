// Orbis Auth v2 - Cloudflare Worker + Durable Object (ES modules)
//
//   GET  /                     -> "Orbis Auth is online."
//   POST /setup                -> registers /psn. OFF by default (SETUP_ENABLED). Needs
//                                 "Authorization: Bearer <SIGNING_SECRET>" - never put the secret in a URL.
//   POST / or /interactions    -> Discord interactions (/psn)
//   POST /verify  {uid, code}  -> exchanges a passcode for a session token   (POST only)
//   POST /session {uid, token} -> re-checks a session token                  (POST only)
//
// Needs: Durable Object binding AUTH (class AuthState), secrets DISCORD_PUBLIC_KEY,
// DISCORD_BOT_TOKEN, SIGNING_SECRET.  All state lives in the Durable Object, so every
// read-modify-write is atomic. KV (PSN_USERS) is no longer used.

const APP_ID = "1565803212982845521";
const GUILD_ID = "1565451165213401149";

const CODE_LEN = 4;                 // fixed at 4 digits (PSN login design)
const CODE_TTL = 86400;             // an unused passcode lives 24 hours
const SESSION_TTL = 86400;          // free session token lives 24 hours
const PREMIUM_SESSION_TTL = 30 * 86400; // Premium trusted-device session: 30 days
const OWNER_UID = "8407673016";
const FREE_ACCOUNT_LIMIT = 3;
const REQUIRE_PROFILE_PROOF = true; // prove the Roblox account is yours (see isOwner below)
const SIG_MAX_AGE = 300;            // Discord requests older/newer than 5 min are rejected
const SETUP_ENABLED = false;        // /setup is disabled (404). Set true only while re-registering /psn.

const LIMITS = {
  ipReqPerMin: 30,   // verify requests per IP per minute
  ipFail: 12,        // failed attempts per IP per 10 minutes
  uidFail: 10,       // failed attempts per Roblox user id per 10 minutes
  globalFail: 150,   // failed attempts from everybody per minute (emergency brake)
  sessionPerMin: 60, // session checks per IP per minute
  psnPerMin: 10,     // /psn uses per Discord user per minute
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
};
const STATUS = { invalid: 401, proof_missing: 403, ownership_unavailable: 503, session_invalid: 401,
  rate_limited: 429, bad_request: 400, server_error: 503 };

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
      else if (path === "/register") out = await this.registerAccount(body);
      else if (path === "/accounts") out = await this.getAccounts(body);
      else if (path === "/owner/accounts") out = await this.ownerAccounts(body);
      else if (path === "/owner/visit") out = await this.ownerVisit(body);
      else if (path === "/owner/premium") out = await this.ownerPremium(body);
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
      const premiumUntil = Number(await txn.get("premium:" + uid)) || 0;
      const premium = premiumUntil > t;
      const exp = t + (premium ? PREMIUM_SESSION_TTL : SESSION_TTL);
      await txn.put("sess:" + tokenHash, { uid, did: rec2.did, exp });
      return { ok: true, token, exp, premium };
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
      const premiumUntil = Number(await txn.get("premium:" + uid)) || 0;
      return { ok: true, exp: s.exp, premium: premiumUntil > nowSec(), premiumUntil: premiumUntil || null };
    });
  }


  // ----- Authenticated Orbis account APIs -----
  async authenticatedSession(body) {
    const uid = String(body.uid == null ? "" : body.uid);
    const token = String(body.token == null ? "" : body.token);
    if (!isUid(uid) || !isToken(token)) return null;
    const hash = await sha256Hex(token);
    const s = await this.state.storage.get("sess:" + hash);
    return s && s.uid === uid && s.exp > nowSec() ? s : null;
  }

  async registerAccount(body) {
    const session = await this.authenticatedSession(body);
    if (!session) return { ok: false, reason: "session_invalid" };
    const username = String(body.username || "").trim();
    if (!/^[A-Za-z0-9_]{3,20}$/.test(username)) {
      return { ok: false, reason: "bad_request", message: "Orbis usernames must be 3-20 letters, numbers or underscores." };
    }
    const usernameKey = username.toLowerCase();
    const id = randomHex(12);
    const t = nowSec();
    return this.tx(async (txn) => {
      const taken = await txn.get("name:" + usernameKey);
      if (taken) return { ok: false, reason: "bad_request", message: "That Orbis username is already taken." };
      const existing = await txn.list({ prefix: "acct:" });
      const owned = [...existing.values()].filter((a) => a && a.uid === session.uid);
      const premiumUntil = Number(await txn.get("premium:" + session.uid)) || 0;
      if (premiumUntil <= t && owned.length >= FREE_ACCOUNT_LIMIT) {
        return { ok: false, reason: "account_limit", message: "Free accounts are limited to 3. Orbis Premium unlocks more accounts." };
      }
      const account = {
        id, username, usernameKey, uid: session.uid, did: session.did || null,
        createdAt: t, premiumUntil: premiumUntil > t ? premiumUntil : 0,
        notifications: [], trophies: [],
      };
      await txn.put("acct:" + id, account);
      await txn.put("name:" + usernameKey, id);
      return { ok: true, account: { id, username, createdAt: t }, premium: premiumUntil > t };
    });
  }

  async getAccounts(body) {
    const session = await this.authenticatedSession(body);
    if (!session) return { ok: false, reason: "session_invalid" };
    const all = await this.state.storage.list({ prefix: "acct:" });
    const accounts = [...all.values()]
      .filter((a) => a && a.uid === session.uid)
      .map((a) => ({ id: a.id, username: a.username, createdAt: a.createdAt }));
    const premiumUntil = Number(await this.state.storage.get("premium:" + session.uid)) || 0;
    return { ok: true, accounts, premium: premiumUntil > nowSec(), premiumUntil: premiumUntil || null,
      accountLimit: premiumUntil > nowSec() ? null : FREE_ACCOUNT_LIMIT };
  }

  async ownerAccounts(body) {
    const session = await this.authenticatedSession(body);
    if (!session || session.uid !== OWNER_UID) return { ok: false, reason: "forbidden", status: 403, message: "Owner access required." };
    const query = String(body.query || "").trim().toLowerCase().replace(/^@/, "").slice(0, 32);
    const all = await this.state.storage.list({ prefix: "acct:" });
    const accounts = [...all.values()]
      .filter((a) => a && (!query || a.usernameKey.includes(query) || a.uid.includes(query)))
      .slice(0, 100)
      .map((a) => ({ id: a.id, username: a.username, uid: a.uid, createdAt: a.createdAt,
        premiumUntil: a.premiumUntil || 0 }));
    return { ok: true, accounts };
  }

  async ownerVisit(body) {
    const session = await this.authenticatedSession(body);
    if (!session || session.uid !== OWNER_UID) return { ok: false, reason: "forbidden", status: 403, message: "Owner access required." };
    const id = String(body.accountId || "");
    if (!/^[0-9a-f]{24}$/.test(id)) return { ok: false, reason: "bad_request" };
    const t = nowSec();
    return this.tx(async (txn) => {
      const account = await txn.get("acct:" + id);
      if (!account) return { ok: false, reason: "bad_request", message: "Orbis account not found." };
      account.notifications = Array.isArray(account.notifications) ? account.notifications : [];
      account.trophies = Array.isArray(account.trophies) ? account.trophies : [];
      account.notifications.unshift({ type: "owner_visit", text: "The Orbis owner visited your profile.", at: t });
      account.notifications = account.notifications.slice(0, 50);
      if (!account.trophies.includes("owner_visited")) account.trophies.push("owner_visited");
      account.lastOwnerVisit = t;
      await txn.put("acct:" + id, account);
      await txn.put("audit:owner_visit:" + t + ":" + id, { accountId: id, uid: account.uid, at: t, actor: OWNER_UID });
      return { ok: true, notified: true, trophyAwarded: true };
    });
  }

  async ownerPremium(body) {
    const session = await this.authenticatedSession(body);
    if (!session || session.uid !== OWNER_UID) return { ok: false, reason: "forbidden", status: 403, message: "Owner access required." };
    const uid = String(body.targetUid || "");
    if (!isUid(uid)) return { ok: false, reason: "bad_request" };
    const days = Math.max(0, Math.min(3650, Number(body.days == null ? 30 : body.days) || 0));
    const until = days === 0 ? 0 : nowSec() + Math.floor(days * 86400);
    await this.tx(async (txn) => {
      if (until) await txn.put("premium:" + uid, until);
      else await txn.delete("premium:" + uid);
      const all = await txn.list({ prefix: "acct:" });
      for (const [key, account] of all) {
        if (account && account.uid === uid) {
          account.premiumUntil = until;
          await txn.put(key, account);
        }
      }
      await txn.put("audit:premium:" + nowSec() + ":" + uid, { uid, until, actor: OWNER_UID });
    });
    return { ok: true, premium: until > nowSec(), premiumUntil: until || null };
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


async function handleOrbisPost(request, env, path) {
  if (request.method !== "POST") return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 405);
  let body;
  try {
    const raw = await request.text();
    if (raw.length > 8192) return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 413);
    body = JSON.parse(raw);
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("bad body");
  } catch (_) {
    return json({ ok: false, reason: "bad_request", message: MSG.bad_request }, 400);
  }
  try {
    const out = await callAuth(env, path, body);
    const status = out.ok ? 200 : (out.status || (out.reason === "forbidden" ? 403 : 400));
    delete out.status;
    return json(out, status);
  } catch (_) {
    return json({ ok: false, reason: "server_error", message: MSG.server_error }, 503);
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
    if (pathname === "/orbis/register") return handleOrbisPost(request, env, "/register");
    if (pathname === "/orbis/accounts") return handleOrbisPost(request, env, "/accounts");
    if (pathname === "/orbis/owner/accounts") return handleOrbisPost(request, env, "/owner/accounts");
    if (pathname === "/orbis/owner/visit") return handleOrbisPost(request, env, "/owner/visit");
    if (pathname === "/orbis/owner/premium") return handleOrbisPost(request, env, "/owner/premium");
    if (request.method === "POST" && (pathname === "/" || pathname === "/interactions")) return handleDiscord(request, env);
    return new Response("Not found", { status: 404 });
  },
};
