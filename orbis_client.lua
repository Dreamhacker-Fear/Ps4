-- Orbis Auth v2 Client
-- Required by ps4.lua
-- 4-digit passcodes + persistent sessions

local HttpService = game:GetService("HttpService")

local API = "https://ps4.lucaebraeuer.workers.dev"

local Client = {}
local cachedTokens = {}

local function getRequest()
    if syn and syn.request then return syn.request end
    if http and http.request then return http.request end
    if http_request then return http_request end
    if request then return request end
    if fluxus and fluxus.request then return fluxus.request end
    return nil
end

local function fileName(uid)
    return "orbis_session_" .. tostring(uid) .. ".json"
end

local function saveToken(uid, token)
    uid = tostring(uid)
    cachedTokens[uid] = token

    if type(writefile) == "function" then
        pcall(function()
            writefile(fileName(uid), HttpService:JSONEncode({
                token = token
            }))
        end)
    end
end

local function readToken(uid)
    uid = tostring(uid)

    if cachedTokens[uid] then
        return cachedTokens[uid]
    end

    if type(isfile) ~= "function"
        or type(readfile) ~= "function" then
        return nil
    end

    local ok, data = pcall(function()
        if not isfile(fileName(uid)) then return nil end
        return HttpService:JSONDecode(readfile(fileName(uid)))
    end)

    if ok and type(data) == "table"
        and type(data.token) == "string"
        and data.token:match("^[0-9a-f]+$")
        and #data.token == 64 then

        cachedTokens[uid] = data.token
        return data.token
    end

    return nil
end

local function clearToken(uid)
    uid = tostring(uid)
    cachedTokens[uid] = nil

    if type(delfile) == "function"
        and type(isfile) == "function" then
        pcall(function()
            if isfile(fileName(uid)) then
                delfile(fileName(uid))
            end
        end)
    end
end

local function post(path, payload)
    local req = getRequest()

    if not req then
        return {
            ok = false,
            reason = "norequest",
            message = "Your executor does not support HTTP requests."
        }
    end

    local ok, response = pcall(function()
        return req({
            Url = API .. path,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if not ok or type(response) ~= "table" then
        return {
            ok = false,
            reason = "net",
            message = "Could not connect to Orbis Auth. Check your connection."
        }
    end

    local status = response.StatusCode
        or response.Status_Code
        or response.status_code

    local body = response.Body or response.body

    if type(body) ~= "string" then
        return {
            ok = false,
            reason = "net",
            message = "The authentication server returned an invalid response."
        }
    end

    local decodedOk, result = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not decodedOk or type(result) ~= "table" then
        return {
            ok = false,
            reason = "net",
            message = "Could not read the authentication server response."
        }
    end

    if type(status) == "number"
        and status >= 500 then
        result.ok = false
        result.reason = result.reason or "server_error"
        result.message = result.message or "Orbis Auth is temporarily unavailable."
    end

    if not result.ok then
        result.message = result.message or "Authentication failed."
    end

    return result
end

-- First login: exchange 4-digit code for session token
function Client.verify(code, uid)
    uid = tostring(uid or "")
    code = tostring(code or "")

    if not uid:match("^%d+$") then
        return {
            ok = false,
            reason = "bad_request",
            message = "Invalid Roblox user ID."
        }
    end

    if not code:match("^%d%d%d%d$") then
        return {
            ok = false,
            reason = "invalid",
            message = "Enter exactly 4 digits."
        }
    end

    local result = post("/verify", {
        uid = uid,
        code = code
    })

    if result.ok then
        local token = result.token

        if type(token) ~= "string"
            or #token ~= 64
            or not token:match("^[0-9a-f]+$") then
            return {
                ok = false,
                reason = "server_error",
                message = "The server returned an invalid session token."
            }
        end

        saveToken(uid, token)
    end

    return result
end

-- Load locally saved session
function Client.load(uid)
    return readToken(uid) ~= nil
end

-- Validate saved session with POST /session
function Client.resume(uid)
    uid = tostring(uid or "")

    local token = readToken(uid)

    if not token then
        return {
            ok = false,
            reason = "none",
            message = ""
        }
    end

    local result = post("/session", {
        uid = uid,
        token = token
    })

    if result.reason == "session_invalid" then
        clearToken(uid)
    end

    return result
end

-- Delete saved session
function Client.clear(uid)
    clearToken(uid)
end


-- Orbis account registry and owner tools. All endpoints authenticate with the
-- saved server-issued session token; client-supplied roles are never trusted.
local function accountRequest(path, uid, payload)
    uid = tostring(uid or "")
    local token = readToken(uid)
    if not token then
        return { ok = false, reason = "session_invalid", message = "Sign in again to continue." }
    end
    payload = payload or {}
    payload.uid = uid
    payload.token = token
    return post(path, payload)
end

function Client.register(username, uid)
    return accountRequest("/orbis/register", uid, { username = tostring(username or "") })
end

function Client.accounts(uid)
    return accountRequest("/orbis/accounts", uid, {})
end

function Client.ownerAccounts(uid, query)
    return accountRequest("/orbis/owner/accounts", uid, { query = tostring(query or "") })
end

function Client.ownerVisit(uid, accountId)
    return accountRequest("/orbis/owner/visit", uid, { accountId = tostring(accountId or "") })
end

-- days=30 grants one month; days=0 revokes Premium.
function Client.ownerPremium(uid, targetUid, days)
    return accountRequest("/orbis/owner/premium", uid, {
        targetUid = tostring(targetUid or ""),
        days = tonumber(days) or 30,
    })
end

return Client
