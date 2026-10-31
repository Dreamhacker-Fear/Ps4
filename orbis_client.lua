-- Orbis Auth client (remote module, no UI). Host this file in your GitHub repo and load it from the dashboard:
--   local Orbis = loadstring(game:HttpGet("https://raw.githubusercontent.com/Dreamhacker-Fear/Ps4/main/orbis_client.lua"))()
-- Updating this file updates the login logic for everyone without a new dashboard download.
--
--   Orbis.verify(code, userId)  -> first login:  POST /verify  {uid, code}   (code = exactly 4 digits)
--   Orbis.resume(userId)        -> later launches: POST /session {uid, token}
--   Orbis.clear(userId)         -> forget the saved session (log out)
-- Every call returns a table: { ok = true }  or  { ok = false, reason = "...", message = "text for the GUI", retry = seconds|nil }
--   Orbis.api(userId, path, extra) -> signed-in call (/presence, /friends/..., /admin/users)
-- reason is one of: forbidden, not_found, limit_reached, invalid, proof_missing, ownership_unavailable, rate_limited, session_invalid,
--                   bad_request, server_error, net, norequest, none

local HttpService = game:GetService("HttpService")

local M = {}
M.WORKER = "https://ps4.lucaebraeuer.workers.dev"
M.DISCORD = "https://discord.gg/9aefrXgRjf"
M.CODE_LEN = 4
M.FILE = "ps4_orbis_session.json"

local TEXT = {
    invalid = "Wrong, expired or already used passcode. Run /psn in Discord for a fresh one.",
    proof_missing = "Add the phrase from your /psn message to the About section of your Roblox profile, then try again.",
    ownership_unavailable = "Could not check your Roblox profile right now. Try again in a moment.",
    rate_limited = "Too many attempts. Please wait a moment.",
    session_invalid = "Your session expired. Run /psn in Discord for a new passcode.",
    bad_request = "That request was not valid.",
    server_error = "The login server had a problem. Try again in a moment.",
    net = "Cannot reach the login server. Check your connection and try again.",
    norequest = "Your executor cannot send secure login requests (it needs request / http_request).",
    forbidden = "This is only available to the owner.",
    not_found = "That user was not found.",
    limit_reached = "That list is full.",
}

-- ---------- saved sessions (one per Roblox user id) ----------
local mem = {}
local function canFile()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end
local function readAll()
    if not canFile() or not isfile(M.FILE) then return {} end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(M.FILE)) end)
    if ok and type(data) == "table" and type(data.sessions) == "table" then return data.sessions end
    return {}
end
local function writeAll(sessions)
    if not canFile() then return end
    pcall(function() writefile(M.FILE, HttpService:JSONEncode({ sessions = sessions })) end)
end

function M.load(uid)
    uid = tostring(uid)
    local s = mem[uid] or readAll()[uid]
    if type(s) == "table" and type(s.token) == "string" then return s end

    -- Migrate sessions saved by the previous Orbis client (one file per Roblox user).
    if canFile() then
        local legacy = "orbis_session_" .. uid .. ".json"
        if isfile(legacy) then
            local ok, data = pcall(function() return HttpService:JSONDecode(readfile(legacy)) end)
            if ok and type(data) == "table" and type(data.token) == "string"
                and #data.token == 64 and data.token:match("^[0-9a-f]+$") then
                s = { token = data.token, exp = tonumber(data.exp) }
                M.save(uid, s.token, s.exp)
                return s
            end
        end
    end
    return nil
end
function M.save(uid, token, exp)
    uid = tostring(uid)
    local rec = { token = token, exp = tonumber(exp) }
    mem[uid] = rec
    local all = readAll()
    all[uid] = rec
    writeAll(all)
end
function M.clear(uid)
    uid = tostring(uid)
    mem[uid] = nil
    local all = readAll()
    all[uid] = nil
    writeAll(all)
end

-- ---------- HTTP (POST only: the Worker no longer accepts GET) ----------
local function requestFn()
    return (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)
end

-- returns the decoded JSON table, or nil + "net" / "norequest"
local function post(path, payload)
    local fn = requestFn()
    if type(fn) ~= "function" then return nil, "norequest" end
    local ok, res = pcall(fn, {
        Url = M.WORKER .. path,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(payload),
    })
    if not ok or type(res) ~= "table" then return nil, "net" end
    local body = res.Body or res.body
    local okj, data = pcall(function() return HttpService:JSONDecode(tostring(body or "")) end)
    if not okj or type(data) ~= "table" then return nil, "net" end -- e.g. an HTML error page
    return data
end

local function failure(data)
    local reason = tostring(data.reason or "server_error")
    return {
        ok = false,
        reason = reason,
        message = tostring(data.message or TEXT[reason] or TEXT.server_error),
        retry = tonumber(data.retry),
    }
end
local function netFailure(kind)
    return { ok = false, reason = kind, message = TEXT[kind] or TEXT.net }
end

-- ---------- first login ----------
function M.verify(code, uid)
    code = tostring(code or "")
    if #code ~= M.CODE_LEN or not code:match("^%d+$") then
        return { ok = false, reason = "invalid", message = "Enter the " .. M.CODE_LEN .. "-digit passcode." }
    end
    local data, kind = post("/verify", { uid = tostring(uid), code = code })
    if not data then return netFailure(kind) end
    if data.ok == true and type(data.token) == "string" then
        M.save(uid, data.token, data.exp)
        return { ok = true, exp = tonumber(data.exp) }
    end
    return failure(data)
end

-- ---------- later launches ----------
function M.resume(uid)
    local s = M.load(uid)
    if not s then return { ok = false, reason = "none", message = "" } end
    local data, kind = post("/session", { uid = tostring(uid), token = s.token })
    if not data then return netFailure(kind) end -- network trouble: keep the session, let the user retry
    if data.ok == true then
        if data.exp then M.save(uid, s.token, data.exp) end
        return { ok = true, exp = tonumber(data.exp) }
    end
    if tostring(data.reason) == "session_invalid" then M.clear(uid) end -- expired: forget it, ask for a new passcode
    return failure(data)
end

-- ---------- signed-in calls (presence, friends, owner list) ----------
-- Sends {uid, token, ...extra} to `path`. Returns the server's JSON table on success (ok = true plus its fields),
-- or { ok = false, reason, message, retry } on failure. An expired session is forgotten automatically.
function M.api(uid, path, extra)
    local s = M.load(uid)
    if not s then return { ok = false, reason = "session_invalid", message = TEXT.session_invalid } end
    local body = { uid = tostring(uid), token = s.token }
    for k, v in pairs(extra or {}) do body[k] = v end
    local data, kind = post(path, body)
    if not data then return netFailure(kind) end
    if data.ok == true then return data end
    if tostring(data.reason) == "session_invalid" then M.clear(uid) end
    return failure(data)
end

return M
