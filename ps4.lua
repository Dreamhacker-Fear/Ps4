local S = {} -- shared values live here so the main chunk stays under Luau's 200-local limit
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
S.SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
S.playerGui = player:WaitForChild("PlayerGui")

S.old = S.playerGui:FindFirstChild("PS4Dashboard")
if S.old then S.old:Destroy() end

local COLORS = {
    white = Color3.fromRGB(255, 255, 255),
    muted = Color3.fromRGB(165, 188, 220),
    blue = Color3.fromRGB(0, 112, 209),
    dark = Color3.fromRGB(6, 20, 48),
    card = Color3.fromRGB(12, 34, 72),
    line = Color3.fromRGB(76, 137, 220),
    danger = Color3.fromRGB(140, 40, 40),
    grey = Color3.fromRGB(70, 82, 125),
}

S.SOUND_IDS = {
    Select = "rbxassetid://124400323975890",
    Login = "rbxassetid://123072435492721",
    Open = "rbxassetid://134203002406032",
    Close = "rbxassetid://88440088035194",
    Notify = "rbxassetid://84711905220990",
    Home = "rbxassetid://126928354906604",
}

-- Key that hides / shows the whole dashboard (change it here)
local TOGGLE_KEY = Enum.KeyCode.RightShift

local settings = { sound = true, volume = 0.6, toasts = true, theme = 1, images = true, hideOnStart = true, uiscale = 1 }
local earned = {}
local pageGradients, waves = {}, {}

local function playSound(name)
    local id = S.SOUND_IDS[name]
    if not id or not settings.sound then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.Name = "PS4_" .. name
        s.SoundId = id
        s.Volume = settings.volume
        s.Parent = S.SoundService
        local ok = pcall(function() s:Play() end)
        if not ok then s:Destroy() return end
        s.Ended:Connect(function() s:Destroy() end)
        task.delay(15, function() if s.Parent then s:Destroy() end end)
    end)
end

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end

local function round(obj, r)
    make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, obj)
end

local function circle(obj)
    make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, obj)
end

local function stroke(obj, color, thick, trans)
    return make("UIStroke", {
        Color = color or COLORS.white,
        Thickness = thick or 1,
        Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

local function tween(obj, dur, goal, style, dir)
    local t = TweenService:Create(obj,
        TweenInfo.new(dur, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
    t:Play()
    return t
end

local function label(parent, text, size, pos, ts, color, bold)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Size = size,
        Position = pos,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = ts or 12,
        TextColor3 = color or COLORS.white,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
    }, parent)
end

local function button(parent, text, size, pos, color, ts)
    local o = make("TextButton", {
        Size = size,
        Position = pos,
        BackgroundColor3 = color or COLORS.card,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = COLORS.white,
        TextSize = ts or 12,
        Font = Enum.Font.GothamMedium,
        TextWrapped = true,
        AutoButtonColor = true,
    }, parent)
    round(o, 5)
    return o
end

local function makeCover(parent, class, color, text)
    local c = make(class, { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, parent)
    if class == "TextButton" then c.Text = ""; c.AutoButtonColor = false end
    round(c, 4)
    make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(
            color:Lerp(Color3.new(1, 1, 1), 0.22),
            color:Lerp(Color3.new(0, 0, 0), 0.4)
        ),
    }, c)
    local art = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = text,
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.white,
        TextScaled = true,
        TextWrapped = true,
    }, c)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
    }, art)
    make("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 6 }, art)
    return c
end

-- ===== PlayStation-style icons, drawn from simple shapes (no image files needed) =====
S.iconDraw = {}
local D = S.iconDraw
D.cross = function(px, bar) bar(0.5, 0.5, 0.8, 45); bar(0.5, 0.5, 0.8, -45) end
D.circle = function(px) px(0.5, 0.5, 0.8, 0.8, { r = 0.5 }) end
D.square = function(px) px(0.5, 0.5, 0.7, 0.7, { r = 0.08 }) end
D.triangle = function(px, bar) bar(0.3, 0.5, 0.8, -60); bar(0.7, 0.5, 0.8, 60); bar(0.5, 0.84, 0.8, 0) end
D.options = function(px, bar) bar(0.5, 0.28, 0.7, 0); bar(0.5, 0.5, 0.7, 0); bar(0.5, 0.72, 0.7, 0) end
D.minus = function(px, bar) bar(0.5, 0.5, 0.6, 0) end
D.friends = function(px, bar, dot)
    dot(0.36, 0.3, 0.26); px(0.36, 0.7, 0.46, 0.28, { fill = true, r = 0.5 })
    dot(0.72, 0.38, 0.2); px(0.72, 0.72, 0.3, 0.2, { fill = true, r = 0.5 })
end
D.person = function(px, bar, dot)
    dot(0.5, 0.32, 0.32); px(0.5, 0.74, 0.6, 0.34, { fill = true, r = 0.5 })
end
D.party = function(px, bar, dot)
    px(0.5, 0.42, 0.8, 0.55, { r = 0.3 }); px(0.3, 0.78, 0.14, 0.14, { fill = true, rot = 45 })
    dot(0.32, 0.42, 0.1); dot(0.5, 0.42, 0.1); dot(0.68, 0.42, 0.1)
end
D.messages = function(px, bar)
    px(0.5, 0.5, 0.82, 0.6, { r = 0.1 }); bar(0.3, 0.37, 0.5, 38); bar(0.7, 0.37, 0.5, -38)
end
D.bell = function(px, bar, dot)
    px(0.5, 0.36, 0.5, 0.5, { fill = true, r = 0.5 }); px(0.5, 0.52, 0.5, 0.28, { fill = true })
    px(0.5, 0.66, 0.74, 0.16, { fill = true, r = 0.5 }); dot(0.5, 0.84, 0.14); dot(0.5, 0.1, 0.1)
end
D.trophy = function(px)
    px(0.5, 0.26, 0.44, 0.22, { fill = true }); px(0.5, 0.4, 0.44, 0.3, { fill = true, r = 0.5 })
    px(0.2, 0.32, 0.2, 0.2, { r = 0.5 }); px(0.8, 0.32, 0.2, 0.2, { r = 0.5 })
    px(0.5, 0.62, 0.1, 0.18, { fill = true }); px(0.5, 0.78, 0.4, 0.08, { fill = true, r = 0.4 })
end
D.gear = function(px, bar, dot, ts, th)
    px(0.5, 0.5, 0.52, 0.52, { r = 0.5, th = th * 1.5 })
    for i = 0, 7 do
        local a = math.rad(i * 45)
        px(0.5 + 0.34 * math.cos(a), 0.5 + 0.34 * math.sin(a), 0.15, 0.15, { fill = true, rot = i * 45 })
    end
end
D.power = function(px, bar, dot, ts)
    for k = 0, 27 do
        local a = math.rad(35 + k * (290 / 27))
        dot(0.5 + 0.3 * math.sin(a), 0.56 - 0.3 * math.cos(a), math.max(0.09, ts * 1.1))
    end
    bar(0.5, 0.3, 0.36, 90)
end
D.refresh = function(px, bar, dot, ts)
    for k = 0, 24 do
        local a = math.rad(40 + k * (290 / 24))
        dot(0.5 + 0.3 * math.sin(a), 0.5 - 0.3 * math.cos(a), math.max(0.09, ts * 1.1))
    end
    bar(0.63, 0.18, 0.22, 8); bar(0.74, 0.28, 0.22, 80)
end
D.download = function(px, bar)
    bar(0.5, 0.4, 0.42, 90); bar(0.4, 0.58, 0.28, 45); bar(0.6, 0.58, 0.28, -45); bar(0.5, 0.84, 0.6, 0)
end
D.play = function(px, bar) bar(0.28, 0.5, 0.7, 90); bar(0.54, 0.32, 0.62, 34); bar(0.54, 0.68, 0.62, -34) end
D.pause = function(px, bar) bar(0.36, 0.5, 0.6, 90); bar(0.64, 0.5, 0.6, 90) end
D.trash = function(px, bar)
    bar(0.5, 0.24, 0.62, 0); bar(0.5, 0.15, 0.22, 0); px(0.5, 0.58, 0.5, 0.52, { r = 0.1 })
    bar(0.4, 0.58, 0.3, 90); bar(0.6, 0.58, 0.3, 90)
end
D.edit = function(px, bar) px(0.55, 0.45, 0.18, 0.66, { fill = true, r = 0.3, rot = 45 }); bar(0.4, 0.86, 0.5, 0) end
D.info = function(px, bar, dot)
    px(0.5, 0.5, 0.82, 0.82, { r = 0.5 }); dot(0.5, 0.3, 0.1); bar(0.5, 0.6, 0.3, 90)
end
D.copy = function(px) px(0.38, 0.38, 0.46, 0.46, { r = 0.1 }); px(0.6, 0.6, 0.46, 0.46, { r = 0.1 }) end
D.check = function(px, bar) bar(0.36, 0.62, 0.32, 45); bar(0.6, 0.5, 0.62, -50) end
D.store = function(px) px(0.5, 0.62, 0.66, 0.5, { r = 0.1 }); px(0.5, 0.3, 0.28, 0.28, { r = 0.5 }) end
D.library = function(px)
    px(0.3, 0.3, 0.28, 0.28, { r = 0.1 }); px(0.7, 0.3, 0.28, 0.28, { r = 0.1 })
    px(0.3, 0.7, 0.28, 0.28, { r = 0.1 }); px(0.7, 0.7, 0.28, 0.28, { r = 0.1 })
end
D.sound = function(px, bar)
    px(0.24, 0.5, 0.14, 0.22, { fill = true, r = 0.1 }); px(0.38, 0.5, 0.24, 0.24, { fill = true, rot = 45 })
    bar(0.7, 0.34, 0.2, -40); bar(0.74, 0.5, 0.2, 0); bar(0.7, 0.66, 0.2, 40)
end
D.theme = function(px, bar, dot)
    px(0.5, 0.5, 0.8, 0.8, { r = 0.5 }); dot(0.34, 0.4, 0.12); dot(0.5, 0.3, 0.12); dot(0.66, 0.4, 0.12); dot(0.62, 0.62, 0.12)
end
D.disk = function(px) px(0.5, 0.25, 0.7, 0.2, { r = 0.5 }); px(0.5, 0.5, 0.7, 0.2, { r = 0.5 }); px(0.5, 0.75, 0.7, 0.2, { r = 0.5 }) end
D.image = function(px, bar, dot)
    px(0.5, 0.5, 0.82, 0.62, { r = 0.1 }); dot(0.34, 0.38, 0.14); bar(0.62, 0.62, 0.34, -40)
end
D.network = function(px, bar) px(0.5, 0.5, 0.8, 0.8, { r = 0.5 }); px(0.5, 0.5, 0.36, 0.8, { r = 0.5 }); bar(0.5, 0.5, 0.8, 0) end
D.monitor = function(px, bar)
    px(0.5, 0.42, 0.8, 0.5, { r = 0.1 }); px(0.5, 0.72, 0.1, 0.12, { fill = true }); bar(0.5, 0.86, 0.4, 0)
end

D.key = function(px, bar)
    px(0.26, 0.5, 0.34, 0.34, { r = 0.5 })
    bar(0.6, 0.5, 0.46, 0)
    bar(0.74, 0.64, 0.16, 90)
    bar(0.88, 0.64, 0.16, 90)
end
D.lock = function(px, bar)
    bar(0.5, 0.14, 0.46, 0)
    bar(0.27, 0.28, 0.28, 90)
    bar(0.73, 0.28, 0.28, 90)
    px(0.5, 0.68, 0.74, 0.44, { fill = true, r = 0.12 })
end
D.unlock = function(px, bar)
    bar(0.58, 0.08, 0.46, 0)
    bar(0.81, 0.2, 0.24, 90)
    bar(0.35, 0.14, 0.12, 90)
    px(0.5, 0.68, 0.74, 0.44, { fill = true, r = 0.12 })
end
D.search = function(px, bar)
    px(0.42, 0.42, 0.55, 0.55, { r = 0.5 })
    bar(0.8, 0.8, 0.32, 45)
end
D.keyless = function(px, bar)
    px(0.26, 0.5, 0.34, 0.34, { r = 0.5 })
    bar(0.6, 0.5, 0.46, 0)
    bar(0.74, 0.64, 0.16, 90)
    bar(0.88, 0.64, 0.16, 90)
    bar(0.5, 0.5, 1.0, -45)
end

-- S.icon(name, parent, pixelSize, color, position) draws an icon and returns its holder frame
function S.icon(name, parent, size, color, pos)
    color = color or COLORS.white
    local box = make("Frame", {
        Name = "Icon_" .. tostring(name),
        Size = UDim2.fromOffset(size, size),
        Position = pos or UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = (parent.ZIndex or 1) + 1,
    }, parent)
    local th = math.max(1.5, size * 0.085)
    local function px(cx, cy, w, h, o)
        o = o or {}
        local f = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(cx, cy),
            Size = UDim2.fromScale(w, h),
            Rotation = o.rot or 0,
            BackgroundColor3 = color,
            BackgroundTransparency = o.fill and 0 or 1,
            BorderSizePixel = 0,
            ZIndex = box.ZIndex,
        }, box)
        if o.r then make("UICorner", { CornerRadius = UDim.new(o.r, 0) }, f) end
        if not o.fill then
            make("UIStroke", {
                Color = color, Thickness = o.th or th,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, f)
        end
        return f
    end
    local function bar(cx, cy, len, rot)
        local f = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(cx, cy),
            Size = UDim2.new(len, 0, 0, th),
            Rotation = rot or 0,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            ZIndex = box.ZIndex,
        }, box)
        make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
        return f
    end
    local function dot(cx, cy, d) return px(cx, cy, d, d, { fill = true, r = 0.5 }) end
    local draw = S.iconDraw[name]
    if draw then draw(px, bar, dot, th / size, th) end
    return box
end

-- picks an icon for a menu entry from its text (nil = no icon)
function S.iconForText(t)
    local s = tostring(t):lower()
    local list = {
        { "start", "play" }, { "delete", "trash" }, { "remove", "trash" }, { "clear", "trash" },
        { "edit", "edit" }, { "write", "edit" }, { "information", "info" }, { "copy", "copy" },
        { "in library", "check" }, { "download", "download" }, { "update", "download" },
        { "open store", "store" }, { "get scripts", "store" }, { "open library", "library" },
        { "pause", "pause" }, { "resume", "play" }, { "hide", "minus" }, { "close", "cross" },
        { "storage", "disk" },
    }
    for _, pair in ipairs(list) do
        if s:find(pair[1], 1, true) then return pair[2] end
    end
    if s == "cancel" then return "circle" end
    return nil
end

S.settingIcon = {
    ["Notifications"] = "bell", ["Sound and Screen"] = "sound", ["Themes"] = "theme", ["Storage"] = "disk",
    ["Store Images"] = "image", ["Network"] = "network", ["Account Management"] = "person",
    ["System"] = "monitor", ["Initialization"] = "refresh", ["Power"] = "power",
}

function S.colorFor(text)
    local h = 0
    text = tostring(text)
    for i = 1, #text do h = (h * 31 + text:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.55, 0.55)
end

local httpLog = {}

local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    table.insert(httpLog, 1, { url = url, ok = ok, err = (not ok) and tostring(res) or nil, time = os.time() })
    if #httpLog > 30 then table.remove(httpLog) end
    if not ok then error(res, 0) end
    return res
end

local SB_ROOT = "https://scriptblox.com"
S.IMG_PREFIX = "ps4_img_"
local assetFn = getcustomasset or getsynasset
local imgCache = {}
S.imgFailed = {}

local function imageUrl(path)
    if type(path) ~= "string" or path == "" then return nil end
    if path:lower():find("%.webp") then return nil end
    if path:sub(1, 4) == "http" then return path end
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    return SB_ROOT .. path
end

function S.pickImage(sc)
    local cands = { sc.image, type(sc.game) == "table" and sc.game.imageUrl or nil }
    for _, p in ipairs(cands) do
        if type(p) == "string" and p ~= "" and not p:lower():find("%.webp") then return p end
    end
    return nil
end

local iconCache, iconFailed = {}, {}

local function loadImage(path, callback, onFail)
    local url = imageUrl(path)
    local function fail() if onFail then onFail() end end
    if not url or S.imgFailed[url] or not settings.images then fail() return end
    if type(assetFn) ~= "function" or type(writefile) ~= "function" or type(isfile) ~= "function" then fail() return end
    if imgCache[url] then callback(imgCache[url]) return end
    task.spawn(function()
        local h = 5381
        for i = 1, #url do h = (h * 33 + url:byte(i)) % 4294967296 end
        local file = S.IMG_PREFIX .. h .. ".png"
        local ok, asset = pcall(function()
            if not isfile(file) then
                local data = httpGet(url)
                if type(data) ~= "string" or #data < 100 then error("empty image") end
                writefile(file, data)
            end
            return assetFn(file)
        end)
        if ok and asset then
            imgCache[url] = asset
            callback(asset)
        else
            S.imgFailed[url] = true
            fail()
        end
    end)
end

function S.loadGameIcon(placeId, callback)
    placeId = tonumber(placeId)
    if not placeId or placeId <= 0 or iconFailed[placeId] or not settings.images then return end
    if iconCache[placeId] then loadImage(iconCache[placeId], callback) return end
    task.spawn(function()
        local ok, url = pcall(function()
            local res = httpGet("https://thumbnails.roblox.com/v1/places/gameicons?placeIds=" .. placeId .. "&returnPolicy=PlaceHolder&size=256x256&format=Png&isCircular=false")
            return HttpService:JSONDecode(res).data[1].imageUrl
        end)
        if ok and type(url) == "string" then
            iconCache[placeId] = url
            loadImage(url, callback)
        else
            iconFailed[placeId] = true
        end
    end)
end

local function attachImage(cover, path, gameId)
    local function show(asset)
        if not cover.Parent then return end
        local img = make("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = asset,
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 2,
        }, cover)
        round(img, 4)
    end
    loadImage(path, show, function() S.loadGameIcon(gameId, show) end)
end

local notify
local refreshLocal
local refreshStoreButtons
local openStore
local minimizeDashboard
local downloadScript
local unlockTrophy
local updateProgressViews
local openDownloadOptions

local openEditor

-- Runs a menu action safely: if it errors you get a notification
-- instead of the click silently doing nothing.
function S.run(fn)
    if type(fn) ~= "function" then return end
    local ok, err = xpcall(fn, function(e) return tostring(e) end)
    if not ok then
        warn("[PS4Dashboard] " .. tostring(err))
        notify("Error: " .. tostring(err):sub(1, 70))
    end
end


local dlQueue, dlState, tileProgress = {}, {}, {}
local notifyLog = {}

local function copyText(text, what)
    local fn = setclipboard or toclipboard
    if type(fn) == "function" then
        pcall(fn, text)
        notify((what or "Text") .. " copied")
    else
        notify("Clipboard not supported by your executor")
    end
end

function S.formatBytes(n)
    n = math.floor(n)
    if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
    if n >= 1024 then return string.format("%.1f KB", n / 1024) end
    return string.format("%d B", n)
end

local function dlStatusText(id)
    local st = dlState[id]
    if not st then return "" end
    local size = st.size or #tostring(st.data.code or "")
    local pct = math.floor(st.progress * 100)
    if st.paused then return "Paused at " .. pct .. "%" end
    if st.status == "Waiting" then return "Waiting in queue" end
    if st.status == "Installing" then return "Installing..." end
    if not st.size then return "Downloading " .. pct .. "%" end
    return string.format("Downloading %d%%  (%s / %s)", pct, S.formatBytes(size * st.progress), S.formatBytes(size))
end

local MAX_STORAGE = 10
S.LIB_FILE = "ps4_library.json"

local function canWrite()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

-- Short "loader" scripts just call loadstring(game:HttpGet(url))().
-- If that url is dead the script itself throws "HTTP 404" and then
-- "attempt to call a nil value". We check the link first so a dead
-- script never gets started.
function S.findLoaderUrls(code)
    local urls = {}
    if #code > 1500 then return urls end
    for url in code:gmatch("HttpGet%(%s*[\"']([^\"']+)[\"']") do table.insert(urls, url) end
    for url in code:gmatch("HttpGetAsync%(%s*[\"']([^\"']+)[\"']") do table.insert(urls, url) end
    return urls
end

S.DEAD_LINK_MSG = "This script's link is dead (404) - it was probably removed"

local function execScript(code)
    if not code or code == "" then notify("No code in this script") return end
    if type(loadstring) ~= "function" then notify("loadstring not available") return end

    if S.runBusy then notify("Please wait...") return end
    S.runBusy = true

    task.spawn(function()
      local okRun, errRun = pcall(function()
        -- safety scan + PS4-style loading stages (random length)
        local verdict = S.scanCode(code)
        local loading = S.showLoading("Checking script...")
        for _, st in ipairs(S.randomStages()) do
            loading.setText(st.text)
            task.wait(st.time)
        end
        loading.close()
        if verdict.level == "block" then
            S.showError("blocked", nil, verdict.code, "This script was blocked to protect you.\n" .. verdict.reason)
            return
        elseif verdict.level == "warn" then
            notify("Caution: " .. verdict.reason)
        end

        -- only refuse to start when the loader link is clearly dead
        for _, url in ipairs(S.findLoaderUrls(code)) do
            local ok, res = pcall(httpGet, url)
            if not ok then
                if tostring(res):find("404") then
                    S.showError("dead")
                    return
                end
            elseif type(res) ~= "string" or res == "" or res:match("^%s*404")
                or (res:sub(1, 1) == "<" and (res:find("404", 1, true) or res:lower():find("not found", 1, true))) then
                S.showError("dead")
                return
            end
        end

        local fn, err = loadstring(code)
        if not fn then S.showError("load", err) return end

        -- the script runs in its own thread: many scripts never "finish",
        -- so we must not wait for them before giving feedback
        notify("Script started")
        if unlockTrophy then unlockTrophy("runner") end

        local failed = false
        task.spawn(function()
            local ok, err2 = xpcall(fn, function(e) return tostring(e) end)
            if not ok then
                failed = true
                local msg = tostring(err2)
                if msg:find("404") then
                    S.showError("dead")
                elseif msg:find("attempt to call a nil value") and msg:find(":1:") then
                    S.showError("dead")
                else
                    S.showError("run", msg)
                end
            end
        end)

        -- like a real console: the dashboard steps aside once the "game" runs
        if settings.hideOnStart then
            task.wait(1.2)
            if not failed then minimizeDashboard() end
        end
      end)
      S.runBusy = false
      if not okRun then S.showError("run", errRun) end
    end)
end

local library = {}

local function libraryCount()
    local n = 0
    for _ in pairs(library) do n += 1 end
    return n
end

function S.loadLibrary()
    if not canWrite() then return end
    if isfile(S.LIB_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(S.LIB_FILE))
        end)
        if ok and type(data) == "table" then
            library = data
        end
    end
end

local function saveLibrary()
    if not canWrite() then return end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(library)
    end)
    if ok then writefile(S.LIB_FILE, encoded) end
end

function S.sortedLibrary()
    local list = {}
    for id, e in pairs(library) do table.insert(list, { id = id, entry = e }) end
    table.sort(list, function(a, b)
        local ta, tb = a.entry.downloadedAt or 0, b.entry.downloadedAt or 0
        if ta ~= tb then return ta < tb end
        return a.id < b.id
    end)
    return list
end

local function isDownloaded(id)
    return library[tostring(id)] ~= nil
end

function S.deleteFromLibrary(id)
    if not library[id] then return false end
    library[id] = nil
    saveLibrary()
    notify("Deleted")
    refreshLocal()
    if unlockTrophy then unlockTrophy("tidy") end
    return true
end

S.loadLibrary()

local SETTINGS_FILE = "ps4_settings.json"

local function saveSettings()
    if not canWrite() then return end
    pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode({ settings = settings, earned = earned }))
    end)
end

function S.loadSettings()
    if not canWrite() then return end
    if not isfile(SETTINGS_FILE) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data.settings or {}) do settings[k] = v end
        if type(data.earned) == "table" then earned = data.earned end
    end
end

S.loadSettings()

local W, H = 800, 450

local gui = make("ScreenGui", {
    Name = "PS4Dashboard",
    ResetOnSpawn = false,
    DisplayOrder = 999,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, S.playerGui)

local main = make("CanvasGroup", {
    Name = "Dashboard",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = COLORS.dark,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
round(main, 12)
stroke(main, COLORS.line, 1, 0.3)

-- dark backdrop shown behind the window while it is maximized
S.backdrop = make("Frame", {
    Name = "Backdrop",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = COLORS.dark,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = -1,
}, gui)
S.maximized = false

local uiScale = make("UIScale", { Scale = 1 }, main)
function S.updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local v = cam.ViewportSize
    if S.maximized then
        uiScale.Scale = math.max(0.4, math.min(v.X / W, v.Y / H))
        return
    end
    uiScale.Scale = math.clamp(math.min((v.X - 16) / W, (v.Y - 32) / H) * (settings.uiscale or 1), 0.4, 1.6)
end
S.updateScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(S.updateScale)
end

S.bg = make("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0, ZIndex = 0,
}, main)
S.bgGradient = make("UIGradient", {
    Rotation = 100,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 76, 178)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(6, 62, 160)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 40, 118)),
    }),
}, S.bg)

for i = 1, 4 do
    local wave = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1.7, 0, 0, 90 + i * 24),
        Position = UDim2.new(0.5, 0, 0.5 + i * 0.1, 0),
        Rotation = -10 + i * 2,
        BackgroundColor3 = Color3.fromRGB(80, 150, 235),
        BackgroundTransparency = 0.88 + i * 0.025,
        BorderSizePixel = 0, ZIndex = 0,
    }, S.bg)
    round(wave, 90)
    table.insert(waves, wave)
    make("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, wave)
    TweenService:Create(wave,
        TweenInfo.new(7 + i * 2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.new(0.5, 0, 0.42 + i * 0.1, 0), Rotation = -4 + i * 2 }
    ):Play()
end

-- PS4 notification icon: blue square, full toast height, flush left, white symbols in a 2x2 grid
function S.toastIcon(toast)
    local box = make("Frame", {
        Name = "SymbolBox", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 61,
    }, toast)
    make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(0, 98, 205), Color3.fromRGB(0, 58, 150)),
    }, box)
    local white = Color3.new(1, 1, 1)
    -- 14px symbols, 6px gap -> 34px grid centered in the 56px box (11px margin)
    S.icon("square", box, 14, white, UDim2.fromOffset(11, 11))
    S.icon("triangle", box, 14, white, UDim2.fromOffset(31, 11))
    S.icon("cross", box, 14, white, UDim2.fromOffset(11, 31))
    S.icon("circle", box, 14, white, UDim2.fromOffset(31, 31))
    make("Frame", {
        Size = UDim2.new(1, -56, 0, 2), Position = UDim2.new(0, 56, 1, -2),
        BackgroundColor3 = Color3.fromRGB(0, 112, 209), BorderSizePixel = 0, ZIndex = 61,
    }, toast)
    return box
end

local minimized = false
local currentPage = nil
local panelOpen = false

-- ===== Support link, PS4-style popups (loading + error) and the safety scan =====
S.DISCORD = "https://discord.gg/9aefrXgRjf"

function S.popupBase(w, h)
    local old = main:FindFirstChild("PS4Popup")
    if old then old:Destroy() end
    local scrim = make("TextButton", {
        Name = "PS4Popup", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 90,
    }, main)
    tween(scrim, 0.2, { BackgroundTransparency = 0.35 })
    local box = make("Frame", {
        Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(20, 28, 48), BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 91,
    }, scrim)
    stroke(box, COLORS.white, 1, 0.75)
    return scrim, box
end

function S.popupClose(scrim)
    if not scrim or not scrim.Parent then return end
    tween(scrim, 0.15, { BackgroundTransparency = 1 })
    task.delay(0.16, function() if scrim.Parent then scrim:Destroy() end end)
end

-- Loading popup: ring of dots with a fading tail + a line of text.  ctl.setText(t) / ctl.close()
function S.showLoading(text)
    local scrim, box = S.popupBase(300, 128)
    local ctl = { alive = true }
    local holder = make("Frame", {
        Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(128, 18), BackgroundTransparency = 1, ZIndex = 92,
    }, box)
    local dots = {}
    for i = 1, 12 do
        local a = (i - 1) / 12 * math.pi * 2
        local d = make("Frame", {
            Size = UDim2.fromOffset(5, 5), BackgroundColor3 = COLORS.white, BorderSizePixel = 0, ZIndex = 93,
            Position = UDim2.fromOffset(22 + 17 * math.sin(a) - 2.5, 22 - 17 * math.cos(a) - 2.5),
        }, holder)
        circle(d)
        dots[i] = d
    end
    local lbl = label(box, text, UDim2.fromOffset(280, 36), UDim2.fromOffset(10, 76), 14, COLORS.white)
    lbl.ZIndex = 92
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    task.spawn(function()
        local phase = 0
        while ctl.alive and scrim.Parent do
            phase = (phase + 1) % 12
            for i, d in ipairs(dots) do
                local age = (phase - i) % 12 -- 0 = head of the tail
                d.BackgroundTransparency = math.clamp(age / 11, 0, 0.9)
            end
            task.wait(0.08)
        end
    end)
    function ctl.setText(t) if lbl.Parent then lbl.Text = t end end
    function ctl.close() ctl.alive = false; S.popupClose(scrim) end
    return ctl
end

-- Message popup: text, (code), small detail line, buttons.  Contact Support copies the Discord link.
function S.showDialog(message, code, detail, buttons)
    local scrim, box = S.popupBase(420, 176)
    local msg = label(box, message, UDim2.fromOffset(372, 56), UDim2.fromOffset(24, 16), 14, COLORS.white)
    msg.ZIndex = 92
    msg.TextYAlignment = Enum.TextYAlignment.Top
    local cd = label(box, code and ("(" .. code .. ")") or "", UDim2.fromOffset(372, 18), UDim2.fromOffset(24, 78), 13, COLORS.muted)
    cd.ZIndex = 92
    local dt = label(box, detail or "", UDim2.fromOffset(372, 16), UDim2.fromOffset(24, 98), 11, COLORS.muted)
    dt.ZIndex = 92
    dt.TextWrapped = false
    dt.TextTruncate = Enum.TextTruncate.AtEnd
    local function btn(text, x, onClick)
        local b = make("TextButton", {
            Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(x, 130),
            BackgroundColor3 = Color3.fromRGB(34, 52, 92), BorderSizePixel = 0, AutoButtonColor = false,
            Text = text, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COLORS.white, ZIndex = 92,
        }, box)
        local st = stroke(b, COLORS.white, 1.5, 0.65)
        b.MouseEnter:Connect(function() st.Transparency = 0 end)
        b.MouseLeave:Connect(function() st.Transparency = 0.65 end)
        b.Activated:Connect(function() playSound("Select"); onClick() end)
        return b
    end
    if buttons then
        local n = #buttons
        local x0 = (420 - (n * 160 + (n - 1) * 10)) / 2
        for i, bt in ipairs(buttons) do
            btn(bt[1], x0 + (i - 1) * 170, function()
                S.popupClose(scrim)
                if bt[2] then bt[2]() end
            end)
        end
    else
        btn("OK", 45, function() S.popupClose(scrim) end)
        btn("Contact Support", 215, function() copyText(S.DISCORD, "Support link") end)
    end
    playSound("Notify")
    return scrim
end

S.ERRORS = {
    net = { "NW-31201-7", "Unable to connect to the server. Check your connection and try again." },
    load = { "CE-30005-8", "Cannot start the script. The file may be damaged or missing." },
    run = { "CE-34878-0", "An error has occurred in the following script." },
    dead = { "SU-41333-4", "This script's link is dead. It was probably removed." },
    dl = { "CE-33992-6", "The download could not be completed." },
    blocked = { "SF-10000-0", "This script was blocked to protect you." },
}
function S.showError(kind, detail, codeOverride, msgOverride)
    local e = S.ERRORS[kind] or S.ERRORS.run
    local code, msg = codeOverride or e[1], msgOverride or e[2]
    table.insert(notifyLog, 1, { text = "Error " .. code .. ": " .. msg:gsub("\n", " "), time = os.time() })
    task.spawn(function()
        if minimized and S.restoreDashboard then S.restoreDashboard() end
        S.showDialog(msg, code, detail and tostring(detail):sub(1, 70) or nil)
    end)
end

-- Safety scan: looks for things stealers and loggers do.  Returns { level = "ok"|"warn"|"block", code, reason }
S.SCAN_HIGH = {
    { "roblosecurity", "SF-10001-0", "It tries to read your account cookie." },
    { "api/webhooks", "SF-10002-0", "It sends data to a Discord webhook." },
    { "grabify", "SF-10003-0", "It contains an IP logger link." },
    { "iplogger", "SF-10003-0", "It contains an IP logger link." },
    { "2no.co", "SF-10003-0", "It contains an IP logger link." },
    { "stopify.co", "SF-10003-0", "It contains an IP logger link." },
    { "blasze", "SF-10003-0", "It contains an IP logger link." },
    { "leancoding.co", "SF-10003-0", "It contains an IP logger link." },
}
function S.scanCode(code)
    code = tostring(code or "")
    local l = code:lower()
    for _, r in ipairs(S.SCAN_HIGH) do
        if l:find(r[1], 1, true) then return { level = "block", code = r[2], reason = r[3] } end
    end
    local hits = {}
    local obf = false
    for _, w in ipairs({ "luraph", "ironbrew", "moonsec", "obfuscated by" }) do
        if l:find(w, 1, true) then obf = true break end
    end
    if not obf then
        for run in code:gmatch("[%w%+/=]+") do
            if #run >= 400 then obf = true break end
        end
    end
    if not obf then
        local _, esc = code:gsub("\\%d%d?%d?", "")
        if esc > 150 then obf = true end
    end
    if obf then table.insert(hits, "The code is heavily obfuscated.") end
    if l:find("postasync", 1, true) or l:find("httppost", 1, true)
        or (l:find("method", 1, true) and l:find('"post"', 1, true)) then
        table.insert(hits, "It sends data to the internet.")
    end
    if l:find(":kick(", 1, true) or l:find("game:shutdown", 1, true) then
        table.insert(hits, "It can kick you or close the game.")
    end
    if l:find("delfile", 1, true) or l:find("deletefile", 1, true) or l:find("delfolder", 1, true) then
        table.insert(hits, "It can delete files from your device.")
    end
    if #hits >= 2 then
        return { level = "block", code = "SF-20001-0", reason = hits[1] .. " " .. hits[2] }
    elseif #hits == 1 then
        return { level = "warn", reason = hits[1] }
    end
    return { level = "ok" }
end

-- random loading stages (sometimes it just takes a while, like the real thing)
function S.randomStages()
    local names = { "Checking script...", "Scanning for threats...", "Verifying content...", "Preparing to start..." }
    local out = {}
    for i, n in ipairs(names) do
        local t = 0.6 + math.random() * 1.8
        if math.random() < 0.15 then t = t + 3 + math.random() * 5 end
        out[i] = { text = n, time = t }
    end
    return out
end


notify = function(msg)
    table.insert(notifyLog, 1, { text = tostring(msg), time = os.time() })
    if #notifyLog > 40 then table.remove(notifyLog) end
    if not settings.toasts then return end
    playSound("Notify")
    local prev = main:FindFirstChild("PS4Toast")
    if prev then prev:Destroy() end
    local toast = make("Frame", {
        Name = "PS4Toast",
        Size = UDim2.fromOffset(300, 56),
        Position = UDim2.fromOffset(-320, 14),
        BackgroundColor3 = Color3.fromRGB(228, 233, 241),
        BackgroundTransparency = 0,
        BorderSizePixel = 0, ZIndex = 60,
    }, main)
    local ink = Color3.fromRGB(44, 56, 84)
    S.toastIcon(toast)
    local m = label(toast, msg, UDim2.new(1, -76, 1, -8), UDim2.fromOffset(68, 4), 14, ink)
    m.ZIndex = 61
    m.TextTruncate = Enum.TextTruncate.AtEnd
    tween(toast, 0.4, { Position = UDim2.fromOffset(16, 14) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    task.delay(3, function()
        if toast.Parent then
            tween(toast, 0.25, { Position = UDim2.fromOffset(-320, 14) },
                Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.3, function() if toast.Parent then toast:Destroy() end end)
        end
    end)
end

local scrim = make("TextButton", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0, Text = "",
    AutoButtonColor = false, Visible = false, ZIndex = 40,
}, main)

local panel = make("Frame", {
    Name = "OptionsPanel",
    Size = UDim2.new(0, 270, 1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0, Visible = false, ZIndex = 45,
}, main)
make("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new(Color3.fromRGB(16, 44, 90), Color3.fromRGB(5, 16, 38)),
}, panel)

S.panelTitle = label(panel, "", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 22), 17, COLORS.white, true)
local panelList = make("Frame", {
    Size = UDim2.new(1, -24, 1, -90),
    Position = UDim2.fromOffset(12, 74),
    BackgroundTransparency = 1,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, panelList)

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    tween(scrim, 0.2, { BackgroundTransparency = 1 })
    local t = tween(panel, 0.22, { Position = UDim2.new(1, 0, 0, 0) },
        Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    t.Completed:Connect(function()
        if not panelOpen then panel.Visible = false; scrim.Visible = false end
    end)
end

S.panelRows = {}
S.panelIndex = 1
S.pageNav = {}
S.backTarget = { SettingsList = "Settings" }

-- turns a key / gamepad button into a simple direction word
function S.dirOf(k)
    if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then return "left" end
    if k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then return "right" end
    if k == Enum.KeyCode.Up or k == Enum.KeyCode.DPadUp then return "up" end
    if k == Enum.KeyCode.Down or k == Enum.KeyCode.DPadDown then return "down" end
    if k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then return "ok" end
    return nil
end

function S.focusPanelRow(i)
    local n = #S.panelRows
    if n == 0 then return end
    i = math.clamp(i, 1, n)
    S.panelIndex = i
    for idx, r in ipairs(S.panelRows) do
        local on = idx == i
        r.row.BackgroundTransparency = on and 0.88 or 1
        r.ring.Transparency = on and 0.1 or 1
    end
end

function S.selectPanelRow(i)
    local r = S.panelRows[i]
    if not r then return end
    playSound("Select")
    closePanel()
    S.run(r.fn)
end

function S.panelKey(k)
    local d = S.dirOf(k)
    if d == "up" then S.focusPanelRow(S.panelIndex - 1)
    elseif d == "down" then S.focusPanelRow(S.panelIndex + 1)
    elseif d == "ok" then S.selectPanelRow(S.panelIndex) end
end

local function openPanel(title, entries)
    S.panelTitle.Text = title
    for _, c in ipairs(panelList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    S.panelRows = {}
    for index, e in ipairs(entries) do
        local row = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false,
            Text = "", TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.Gotham, TextSize = 14,
            TextColor3 = COLORS.white, LayoutOrder = index,
        }, panelList)
        round(row, 4)
        local rowIcon = S.iconForText(e[1])
        if rowIcon then S.icon(rowIcon, row, 20, COLORS.white, UDim2.fromOffset(12, 10)) end
        local rowLbl = label(row, e[1], UDim2.new(1, -50, 1, 0), UDim2.fromOffset(rowIcon and 42 or 14, 0), 14, COLORS.white)
        rowLbl.TextWrapped = false
        rowLbl.TextTruncate = Enum.TextTruncate.AtEnd
        local o = stroke(row, COLORS.white, 2, 1)
        S.panelRows[index] = { row = row, ring = o, fn = e[2] }
        row.MouseEnter:Connect(function() S.focusPanelRow(index) end)
        row.Activated:Connect(function() S.selectPanelRow(index) end)
    end
    S.focusPanelRow(1)
    playSound("Open")
    panelOpen = true
    scrim.Visible = true
    panel.Visible = true
    panel.Position = UDim2.new(1, 0, 0, 0)
    tween(scrim, 0.25, { BackgroundTransparency = 0.5 })
    tween(panel, 0.25, { Position = UDim2.new(1, -270, 0, 0) })
end

scrim.Activated:Connect(closePanel)

local pages = {}

local function makePage(name, title)
    local page = make("CanvasGroup", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false, ZIndex = 20,
    }, main)
    local back = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
    }, page)
    local pg = make("UIGradient", {
        Rotation = 35,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 20, 54)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(12, 58, 122)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 24, 66)),
        }),
    }, back)
    table.insert(pageGradients, pg)
    local titleLabel = label(page, title, UDim2.new(1, -80, 0, 36), UDim2.fromOffset(40, 22), 24, COLORS.white)
    make("Frame", {
        Size = UDim2.new(1, -80, 0, 1),
        Position = UDim2.fromOffset(40, 66),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
    }, page)
    local backBtn = make("TextButton", {
        Name = "Back",
        Size = UDim2.fromOffset(120, 30),
        Position = UDim2.fromOffset(112, H - 44),
        BackgroundTransparency = 1,
        Text = "",
    }, page)
    S.icon("circle", backBtn, 18, COLORS.muted, UDim2.fromOffset(0, 6))
    local backLbl = label(backBtn, "Back", UDim2.fromOffset(80, 30), UDim2.fromOffset(26, 0), 14, COLORS.muted)
    backBtn.MouseEnter:Connect(function() backLbl.TextColor3 = COLORS.white end)
    backBtn.MouseLeave:Connect(function() backLbl.TextColor3 = COLORS.muted end)
    S.icon("cross", page, 16, COLORS.muted, UDim2.fromOffset(44, H - 37))
    label(page, "Enter", UDim2.fromOffset(70, 30), UDim2.fromOffset(66, H - 44), 14, COLORS.muted)
    pages[name] = { frame = page, back = backBtn, title = titleLabel }
    return page
end

function S.hidePage(page)
    local t = tween(page, 0.18, { GroupTransparency = 1 })
    t.Completed:Connect(function()
        if page.GroupTransparency > 0.95 then page.Visible = false end
    end)
end

local function showPage(name)
    local target = pages[name]
    if not target then return end
    playSound("Select")
    closePanel()
    for n, d in pairs(pages) do
        if n == name then
            d.frame.Visible = true
            d.frame.GroupTransparency = 1
            tween(d.frame, 0.22, { GroupTransparency = 0 })
        elseif d.frame.Visible then
            S.hidePage(d.frame)
        end
    end
    currentPage = name
end

function S.goHome()
    closePanel()
    for _, d in pairs(pages) do
        if d.frame.Visible then S.hidePage(d.frame) end
    end
    currentPage = nil
    playSound("Close")
end

function S.goBack()
    local cur = currentPage
    if not cur then return end
    local target = S.backTarget[cur]
    if cur == "Info" then target = S.infoFrom end
    if target and pages[target] then
        showPage(target)
    else
        S.goHome()
    end
end

local storePage = makePage("Store", "PlayStation Store")
local libraryPage = makePage("Library", "Library")
S.settingsPage = makePage("Settings", "Settings")
S.infoPage = makePage("Info", "")
S.friendsPage = makePage("Friends", "Friends")
S.partyPage = makePage("Party", "Party")
local messagesPage = makePage("Messages", "Messages")
S.notifPage = makePage("Notifications", "Notifications")
S.trophyPage = makePage("Trophies", "Trophies")
local editorPage = makePage("Editor", "Code Editor")
local ownerPage = makePage("Owner", "Owner Panel")
S.slPage = makePage("SettingsList", "")
S.browserPage = makePage("Browser", "Internet Browser")

local infoBody = label(S.infoPage, "", UDim2.new(1, -80, 0, 260), UDim2.fromOffset(40, 80), 14, COLORS.muted)
infoBody.TextYAlignment = Enum.TextYAlignment.Top

for _, d in pairs(pages) do d.back.Activated:Connect(function() S.goBack() end) end

local function showInfo(title, text)
    if currentPage ~= "Info" then S.infoFrom = currentPage end
    pages.Info.title.Text = title
    infoBody.Text = text
    showPage("Info")
end

local function shortText(t, n)
    t = tostring(t)
    if #t > n then return t:sub(1, n - 1) .. "…" end
    return t
end

function S.showScriptInfo(id)
    local e = library[id]
    if not e then return end
    local keyText = e.key and "Key required" or "Keyless"
    local when = os.date("%Y-%m-%d %H:%M", e.downloadedAt or 0)
    local code = tostring(e.code or "")
    showInfo(shortText(e.title, 40), string.format(
        "Game: %s\nKey: %s\nViews: %s\nDownloaded: %s\nSize: %d characters\n\nCode preview:\n%s",
        tostring(e.game or "Universal"), keyText, tostring(e.views or 0), when, #code,
        code:sub(1, 220)))
end

function S.confirmDelete(id)
    local e = library[id]
    if not e then return end
    openPanel("Delete \"" .. shortText(e.title, 16) .. "\"?", {
        { "Delete", function() S.deleteFromLibrary(id) end },
        { "Cancel" },
    })
end

function S.openScriptOptions(id)
    local e = library[id]
    if not e then return end
    local entries = { { "Start", function() execScript(e.code) end } }
    if not e.custom then
        table.insert(entries, { "Check for Update", function() S.checkForUpdate(id) end })
    end
    table.insert(entries, { "Edit Code", function() openEditor(id) end })
    table.insert(entries, { "Information", function() S.showScriptInfo(id) end })
    table.insert(entries, { "Copy Script", function() copyText(tostring(e.code or ""), "Script") end })
    table.insert(entries, { "Delete", function() S.confirmDelete(id) end })
    openPanel(shortText(e.title, 22), entries)
end

function S.openPowerPanel()
    openPanel("Power", {
        { "Hide Dashboard  (" .. TOGGLE_KEY.Name .. ")", function() minimizeDashboard() end },
        { "Close Dashboard", function() playSound("Close"); gui:Destroy() end },
        { "Cancel" },
    })
end

local function makeListScroll(page, y, h)
    local sc = make("ScrollingFrame", {
        Size = UDim2.fromOffset(W - 80, h or (H - 150)),
        Position = UDim2.fromOffset(40, y or 84),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = COLORS.muted,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, page)
    make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sc)
    return sc
end

local function clearList(sc)
    for _, c in ipairs(sc:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function listRow(sc, order, height)
    local row = make("Frame", {
        Size = UDim2.new(1, -12, 0, height or 54),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 0.94,
        BorderSizePixel = 0,
        LayoutOrder = order,
    }, sc)
    round(row, 4)
    return row
end

local function rowText(row, text, pos, size, ts, color, bold)
    local l = label(row, text, size, pos, ts, color, bold)
    l.TextWrapped = false
    l.TextTruncate = Enum.TextTruncate.AtEnd
    return l
end

local function rowButton(row, fn)
    local b = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "", ZIndex = 5,
    }, row)
    b.Activated:Connect(function() playSound("Select"); fn() end)
    return b
end

function S.refreshOwnerAccounts()
    clearList(ownerScroll)
    local query = tostring(ownerSearch.Text or ""):lower():gsub("^@", "")
    local shown = 0
    for i, account in ipairs(ownerAccountsCache) do
        local uid = tostring(account.uid or "")
        local username = account.username or uid
        if query == "" or username:lower():find(query, 1, true) or uid:find(query, 1, true) then
            shown += 1
            local row = listRow(ownerScroll, shown, 58)
            rowButton(row, function()
                local action = account.premium and "Revoke Premium" or "Grant Premium"
                openPanel(action .. "?", {
                    { action, function()
                        task.spawn(function()
                            local result = S.orbis.setPremium(player.UserId, uid, not account.premium)
                            if result and result.ok then
                                notify((result.premium and "Premium granted to " or "Premium revoked for ") .. username)
                                S.openOwnerPanel()
                            else
                                S.showDialog(result and result.message or "Could not update Premium.")
                            end
                        end)
                    end },
                    { "Cancel" },
                })
            end)
            rowText(row, username .. "  (@" .. username .. ")", UDim2.fromOffset(14, 6), UDim2.new(1, -170, 0, 22), 13, COLORS.white, true)
            rowText(row, "User ID: " .. uid .. "  •  " .. (account.premium and "PREMIUM" or "Standard"), UDim2.fromOffset(14, 30), UDim2.new(1, -170, 0, 18), 11, account.premium and Color3.fromRGB(255, 205, 80) or COLORS.muted)
            label(row, account.premium and "REVOKE" or "GRANT", UDim2.new(0, 90, 1, 0), UDim2.new(1, -100, 0, 0), 11, account.premium and Color3.fromRGB(255, 150, 150) or Color3.fromRGB(120, 220, 160), true)
        end
    end
    if shown == 0 then
        local empty = label(ownerScroll, "No matching accounts found.", UDim2.new(1, -12, 0, 30), UDim2.new(), 13, COLORS.muted)
        empty.LayoutOrder = 1
    end
end

function S.openOwnerPanel()
    if not S.isOwner then notify("Owner access required"); return end
    unlockTrophy("owner_visit")
    notify("Owner access verified")
    showPage("Owner")
    clearList(ownerScroll)
    local loading = label(ownerScroll, "Loading registered accounts...", UDim2.new(1, -12, 0, 30), UDim2.new(), 13, COLORS.muted)
    loading.LayoutOrder = 1
    task.spawn(function()
        if S.orbis and S.orbis.ownerVisit then S.orbis.ownerVisit(player.UserId) end
        local result = S.orbis and S.orbis.ownerAccounts(player.UserId)
        if not ownerPage.Visible then return end
        if not result or not result.ok then
            loading.Text = result and result.message or "Could not load Owner accounts."
            return
        end
        ownerAccountsCache = result.accounts or {}
        for _, account in ipairs(ownerAccountsCache) do
            local ok, username = pcall(function() return Players:GetNameFromUserIdAsync(tonumber(account.uid)) end)
            account.username = ok and username or ("User " .. tostring(account.uid))
        end
        if loading.Parent then loading:Destroy() end
        S.refreshOwnerAccounts()
    end)
end

ownerSearch.FocusLost:Connect(function() S.refreshOwnerAccounts() end)

function S.openPlayerOptions(userId, username, display)
    openPanel(shortText(display, 22), {
        { "Copy Username", function() copyText(username, "Username") end },
        { "Copy User ID", function() copyText(tostring(userId), "User ID") end },
        { "Copy Profile Link", function() copyText("https://www.roblox.com/users/" .. userId .. "/profile", "Profile link") end },
        { "Cancel" },
    })
end

function S.avatarCircle(parent, userId, x, y, size)
    local img = make("ImageLabel", {
        Size = UDim2.fromOffset(size, size),
        Position = UDim2.fromOffset(x, y),
        BackgroundColor3 = COLORS.card,
        BorderSizePixel = 0,
        Image = "",
    }, parent)
    circle(img)
    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and url and img.Parent then img.Image = url end
    end)
    return img
end

local friendsScroll = makeListScroll(S.friendsPage)
S.partyScroll = makeListScroll(S.partyPage)
local notifScroll = makeListScroll(S.notifPage)
S.trophyScroll = makeListScroll(S.trophyPage)
local msgScroll = makeListScroll(messagesPage, 84, 272)
local ownerSearch = make("TextBox", {
    Size = UDim2.new(1, -80, 0, 30), Position = UDim2.fromOffset(40, 78),
    BackgroundColor3 = COLORS.card, BackgroundTransparency = 0.25, BorderSizePixel = 0,
    Text = "", PlaceholderText = "Search by Roblox @username or User ID", PlaceholderColor3 = COLORS.muted,
    TextColor3 = COLORS.white, Font = Enum.Font.Gotham, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, ownerPage)
round(ownerSearch, 5)
make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, ownerSearch)
local ownerScroll = makeListScroll(ownerPage, 118, H - 188)
local ownerAccountsCache = {}

local TROPHIES = {
    { id = "first_dl", name = "First Download", desc = "Download your first script", grade = "Bronze" },
    { id = "runner", name = "Player One", desc = "Start a script", grade = "Bronze" },
    { id = "explorer", name = "Window Shopper", desc = "Pick a genre in the Store", grade = "Bronze" },
    { id = "searcher", name = "Seeker", desc = "Search the Store", grade = "Bronze" },
    { id = "social", name = "Social Butterfly", desc = "Open your Friends list", grade = "Bronze" },
    { id = "tidy", name = "Spring Cleaning", desc = "Delete a script", grade = "Bronze" },
    { id = "keyless", name = "No Strings Attached", desc = "Download a keyless script", grade = "Silver" },
    { id = "themer", name = "Interior Designer", desc = "Change the theme", grade = "Silver" },
    { id = "coder", name = "Developer", desc = "Save your own script", grade = "Silver" },
    { id = "full", name = "Collector", desc = "Fill all library slots", grade = "Gold" },
    { id = "owner_visit", name = "Owner Visited", desc = "Open the verified Owner Panel", grade = "Gold" },
    { id = "platinum", name = "Platinum", desc = "Earn every other trophy", grade = "Platinum" },
}

S.GRADE_COLORS = {
    Bronze = Color3.fromRGB(205, 127, 50),
    Silver = Color3.fromRGB(192, 200, 210),
    Gold = Color3.fromRGB(255, 200, 40),
    Platinum = Color3.fromRGB(150, 220, 255),
}

unlockTrophy = function(id)
    if earned[id] then return end
    local def
    for _, t in ipairs(TROPHIES) do
        if t.id == id then def = t break end
    end
    if not def then return end
    earned[id] = os.time()
    saveSettings()
    notify("Trophy earned: " .. def.name .. " (" .. def.grade .. ")")
    if id ~= "platinum" then
        local all = true
        for _, t in ipairs(TROPHIES) do
            if t.id ~= "platinum" and t.id ~= "owner_visit" and not earned[t.id] then all = false break end
        end
        if all then task.delay(3, function() unlockTrophy("platinum") end) end
    end
end

function S.refreshTrophies()
    clearList(S.trophyScroll)
    local got = 0
    for _, t in ipairs(TROPHIES) do
        if earned[t.id] then got += 1 end
    end
    pages.Trophies.title.Text = "Trophies  -  " .. got .. " / " .. #TROPHIES
    for i, t in ipairs(TROPHIES) do
        local has = earned[t.id] ~= nil
        local row = listRow(S.trophyScroll, i, 54)
        rowButton(row, function()
            showInfo(t.name, t.desc .. "\n\nGrade: " .. t.grade .. "\nStatus: " ..
                (has and ("Earned " .. os.date("%Y-%m-%d", earned[t.id])) or "Locked"))
        end)
        make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(40, 40),
            Position = UDim2.fromOffset(10, 7),
            Text = "★",
            Font = Enum.Font.GothamBold,
            TextSize = 28,
            TextColor3 = has and S.GRADE_COLORS[t.grade] or COLORS.grey,
        }, row)
        rowText(row, t.name, UDim2.fromOffset(62, 8), UDim2.new(1, -200, 0, 20), 14, has and COLORS.white or COLORS.muted, true)
        rowText(row, t.desc, UDim2.fromOffset(62, 29), UDim2.new(1, -200, 0, 16), 11, COLORS.muted)
        rowText(row, has and os.date("%Y-%m-%d", earned[t.id]) or "Locked", UDim2.new(1, -120, 0.5, -10), UDim2.fromOffset(108, 20), 11, COLORS.muted)
    end
end

function S.refreshFriends()
    unlockTrophy("social")
    clearList(friendsScroll)
    local status = label(friendsScroll, "Loading friends...", UDim2.new(1, -12, 0, 30), UDim2.new(), 14, COLORS.muted)
    status.LayoutOrder = 0
    task.spawn(function()
        local list = {}
        local ok = pcall(function()
            local pg = Players:GetFriendsAsync(player.UserId)
            for _ = 1, 3 do
                for _, f in ipairs(pg:GetCurrentPage()) do table.insert(list, f) end
                if pg.IsFinished then break end
                pg:AdvanceToNextPageAsync()
            end
        end)
        if not status.Parent then return end
        if #list == 0 then
            status.Text = ok and "No friends found" or "Could not load friends"
            return
        end
        table.sort(list, function(a, b)
            if (a.IsOnline == true) ~= (b.IsOnline == true) then return a.IsOnline == true end
            return tostring(a.Username):lower() < tostring(b.Username):lower()
        end)
        status:Destroy()
        for i = 1, math.min(#list, 60) do
            local f = list[i]
            local row = listRow(friendsScroll, i, 54)
            S.avatarCircle(row, f.Id, 10, 7, 40)
            rowButton(row, function() S.openPlayerOptions(f.Id, tostring(f.Username), tostring(f.DisplayName or f.Username)) end)
            rowText(row, tostring(f.DisplayName or f.Username), UDim2.fromOffset(62, 8), UDim2.new(1, -200, 0, 20), 14, COLORS.white, true)
            rowText(row, "@" .. tostring(f.Username), UDim2.fromOffset(62, 29), UDim2.new(1, -200, 0, 16), 11, COLORS.muted)
            if f.IsOnline ~= nil then
                local on = f.IsOnline == true
                local dot = make("Frame", {
                    Size = UDim2.fromOffset(10, 10),
                    Position = UDim2.new(1, -96, 0.5, -5),
                    BackgroundColor3 = on and Color3.fromRGB(60, 200, 110) or COLORS.grey,
                    BorderSizePixel = 0,
                }, row)
                circle(dot)
                label(row, on and "Online" or "Offline", UDim2.fromOffset(70, 20), UDim2.new(1, -80, 0.5, -10), 12, on and COLORS.white or COLORS.muted)
            end
        end
    end)
end

local function refreshParty()
    clearList(S.partyScroll)
    local plist = Players:GetPlayers()
    pages.Party.title.Text = "Party  -  " .. #plist .. " in this server"
    for i, p in ipairs(plist) do
        local row = listRow(S.partyScroll, i, 54)
        S.avatarCircle(row, p.UserId, 10, 7, 40)
        rowButton(row, function() S.openPlayerOptions(p.UserId, p.Name, p.DisplayName) end)
        rowText(row, p.DisplayName, UDim2.fromOffset(62, 8), UDim2.new(1, -200, 0, 20), 14, COLORS.white, true)
        rowText(row, "@" .. p.Name .. "  |  account age " .. p.AccountAge .. " days", UDim2.fromOffset(62, 29), UDim2.new(1, -200, 0, 16), 11, COLORS.muted)
        if p == player then
            label(row, "YOU", UDim2.fromOffset(60, 20), UDim2.new(1, -70, 0.5, -10), 12, Color3.fromRGB(110, 180, 255), true)
        end
    end
end

Players.PlayerAdded:Connect(function()
    if currentPage == "Party" then task.delay(0.3, refreshParty) end
end)
Players.PlayerRemoving:Connect(function()
    if currentPage == "Party" then task.delay(0.5, refreshParty) end
end)

local chatLog = {}
local TextChatService = game:GetService("TextChatService")

function S.refreshMessages()
    clearList(msgScroll)
    if #chatLog == 0 then
        local l = label(msgScroll, "No messages yet. Chat in the server or send one below.", UDim2.new(1, -12, 0, 30), UDim2.new(), 13, COLORS.muted)
        l.LayoutOrder = 1
        return
    end
    for i, m in ipairs(chatLog) do
        local row = listRow(msgScroll, i, 40)
        rowButton(row, function()
            openPanel(shortText(m.name, 22), {
                { "Copy Message", function() copyText(m.text, "Message") end },
                { "Cancel" },
            })
        end)
        rowText(row, m.name, UDim2.fromOffset(12, 0), UDim2.fromOffset(130, 40), 12, Color3.fromRGB(110, 180, 255), true)
        local t = label(row, m.text, UDim2.new(1, -170, 1, 0), UDim2.fromOffset(156, 0), 12, COLORS.white)
        t.TextTruncate = Enum.TextTruncate.AtEnd
    end
    task.defer(function() msgScroll.CanvasPosition = Vector2.new(0, 99999) end)
end

function S.pushChat(name, text)
    table.insert(chatLog, { name = tostring(name), text = tostring(text) })
    if #chatLog > 60 then table.remove(chatLog, 1) end
    if currentPage == "Messages" then S.refreshMessages() end
end

pcall(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        TextChatService.MessageReceived:Connect(function(msg)
            local src = msg.TextSource and Players:GetPlayerByUserId(msg.TextSource.UserId)
            S.pushChat(src and src.DisplayName or "System", msg.Text)
        end)
    else
        local function hook(p) p.Chatted:Connect(function(text) S.pushChat(p.DisplayName, text) end) end
        for _, p in ipairs(Players:GetPlayers()) do hook(p) end
        Players.PlayerAdded:Connect(hook)
    end
end)

local msgBox = make("TextBox", {
    Size = UDim2.fromOffset(W - 156, 30),
    Position = UDim2.fromOffset(40, H - 82),
    BackgroundColor3 = COLORS.card,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Write a message...",
    PlaceholderColor3 = COLORS.muted,
    TextColor3 = COLORS.white,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
}, messagesPage)
round(msgBox, 6)
stroke(msgBox, COLORS.white, 1, 0.85)
S.sendBtn = button(messagesPage, "Send", UDim2.fromOffset(64, 30), UDim2.fromOffset(W - 104, H - 82), COLORS.blue, 12)

function S.sendChat()
    local text = msgBox.Text
    if text:gsub("%s", "") == "" then return end
    local ok = pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.TextChannels.RBXGeneral:SendAsync(text)
        else
            game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
        end
    end)
    if ok then msgBox.Text = "" else notify("Could not send message") end
end

S.sendBtn.Activated:Connect(function() playSound("Select"); S.sendChat() end)
msgBox.FocusLost:Connect(function(enter) if enter then S.sendChat() end end)

local editingId = nil

local nameBox = make("TextBox", {
    Size = UDim2.fromOffset(300, 28),
    Position = UDim2.fromOffset(40, 76),
    BackgroundColor3 = COLORS.card,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Script name",
    PlaceholderColor3 = COLORS.muted,
    TextColor3 = COLORS.white,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
}, editorPage)
round(nameBox, 6)
make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, nameBox)
stroke(nameBox, COLORS.white, 1, 0.85)

local slotLabel = label(editorPage, "", UDim2.fromOffset(380, 28), UDim2.fromOffset(354, 76), 12, COLORS.muted)

local editorScroll = make("ScrollingFrame", {
    Size = UDim2.fromOffset(W - 80, 252),
    Position = UDim2.fromOffset(40, 114),
    BackgroundColor3 = Color3.fromRGB(6, 14, 34),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = COLORS.muted,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, editorPage)
round(editorScroll, 6)
stroke(editorScroll, COLORS.white, 1, 0.85)

local codeBox = make("TextBox", {
    Size = UDim2.new(1, -12, 0, 240),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Write your Lua code here...",
    PlaceholderColor3 = COLORS.muted,
    TextColor3 = Color3.fromRGB(200, 230, 255),
    Font = Enum.Font.Code,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    MultiLine = true,
    ClearTextOnFocus = false,
}, editorScroll)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
}, codeBox)

S.runBtn = button(editorPage, "Run", UDim2.fromOffset(80, 30), UDim2.fromOffset(W - 370, H - 44), COLORS.blue, 12)
S.clearBtn = button(editorPage, "Clear", UDim2.fromOffset(80, 30), UDim2.fromOffset(W - 280, H - 44), COLORS.card, 12)
S.saveBtn = button(editorPage, "Save", UDim2.fromOffset(150, 30), UDim2.fromOffset(W - 190, H - 44), Color3.fromRGB(20, 120, 70), 12)

openEditor = function(id)
    editingId = (id and library[id]) and id or nil
    local e = editingId and library[editingId]
    nameBox.Text = e and tostring(e.title or "") or ""
    codeBox.Text = e and tostring(e.code or "") or ""
    if e then
        slotLabel.Text = "Editing a saved script"
    elseif libraryCount() + #dlQueue >= MAX_STORAGE then
        slotLabel.Text = "Library full - delete a script to save a new one"
    else
        slotLabel.Text = "New script - will be saved to slot " .. (libraryCount() + #dlQueue + 1)
    end
    editorScroll.CanvasPosition = Vector2.new(0, 0)
    showPage("Editor")
end

function S.saveEditor()
    local name = nameBox.Text:match("^%s*(.-)%s*$")
    local code = codeBox.Text
    if code:gsub("%s", "") == "" then notify("Write some code first") return end
    if name == "" then name = "My Script " .. (libraryCount() + #dlQueue + 1) end
    if editingId and library[editingId] then
        local e = library[editingId]
        e.title = name
        e.code = code
        saveLibrary()
        notify("Saved: " .. name)
        refreshLocal()
        return
    end
    if libraryCount() + #dlQueue >= MAX_STORAGE then
        notify("Library full (" .. MAX_STORAGE .. " slots) - delete one first")
        return
    end
    local id = "custom_" .. os.time() .. "_" .. math.random(1000, 9999)
    library[id] = {
        title = name,
        game = "Custom",
        code = code,
        key = false,
        views = 0,
        custom = true,
        downloadedAt = os.time(),
    }
    saveLibrary()
    editingId = id
    slotLabel.Text = "Editing a saved script"
    notify("Saved to library: " .. name)
    refreshLocal()
    task.delay(2.5, function() unlockTrophy("coder") end)
end

S.runBtn.Activated:Connect(function() playSound("Select"); execScript(codeBox.Text) end)
S.clearBtn.Activated:Connect(function() playSound("Select"); codeBox.Text = "" end)
S.saveBtn.Activated:Connect(function() playSound("Select"); S.saveEditor() end)


-- ===== Internet Browser (text browser) =====
-- Roblox cannot draw real web pages, so this fetches a page with game:HttpGet and shows it as
-- text with tappable links (no images / scripts / videos). Has history, bookmarks and search.
S.br = { hist = {}, idx = 0, token = 0, cur = nil, title = nil }
S.JB_HOSTS = { ["raw13g.github.io"] = true, ["webkitty.arabpixel.net"] = true } -- simulated exploit pages
S.BR_BLOCK = { p = 1, div = 1, br = 1, li = 1, tr = 1, ul = 1, ol = 1, table = 1, hr = 1, section = 1,
    article = 1, header = 1, footer = 1, pre = 1, blockquote = 1, form = 1, nav = 1, main = 1, dd = 1, dt = 1 }

function S.brDecode(t)
    t = t:gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
        :gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&apos;", "'")
    t = t:gsub("&#(%d+);", function(n)
        local ok, c = pcall(utf8.char, tonumber(n))
        return ok and c or ""
    end)
    return t
end

function S.brUrlDecode(t)
    t = t:gsub("%+", " ")
    t = t:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    return t
end

function S.brResolve(base, href)
    href = S.brDecode(href):match("^%s*(.-)%s*$")
    if href == "" or href:sub(1, 1) == "#" then return nil end
    local real = href:match("[?&]uddg=([^&]+)") -- search engine redirect links
    if real then return S.brUrlDecode(real) end
    local clean = href:gsub("#.*$", "")
    if clean:match("^https?://") then return clean end
    if clean:match("^%a[%w+.-]*:") then return nil end
    local scheme, host, path = base:match("^(https?://)([^/?#]+)(.*)$")
    if not scheme then return nil end
    if clean:sub(1, 2) == "//" then return scheme .. clean:sub(3) end
    if clean:sub(1, 1) == "/" then return scheme .. host .. clean end
    if clean:sub(1, 1) == "?" then
        local p = path:gsub("[?#].*$", "")
        if p == "" then p = "/" end
        return scheme .. host .. p .. clean
    end
    local dir = path:match("^([^?#]*/)") or "/"
    return scheme .. host .. dir .. clean
end

function S.brParse(html, base)
    local blocks, title = {}, nil
    html = html:gsub("<!%-%-.-%-%->", "")
    html = html:gsub("<[sS][cC][rR][iI][pP][tT].-</[sS][cC][rR][iI][pP][tT]>", "")
    html = html:gsub("<[sS][tT][yY][lL][eE].-</[sS][tT][yY][lL][eE]>", "")
    title = html:match("<[tT][iI][tT][lL][eE][^>]*>(.-)</[tT][iI][tT][lL][eE]>")
    if title then title = S.brDecode(title):gsub("%s+", " "):match("^%s*(.-)%s*$") end
    html = html:gsub("<[hH][eE][aA][dD].-</[hH][eE][aA][dD]>", "")
    local buf, head = {}, false
    local function flush()
        local t = table.concat(buf):gsub("%s+", " ")
        t = t:match("^%s*(.-)%s*$")
        if t ~= "" then table.insert(blocks, { type = "text", text = S.brDecode(t), head = head }) end
        buf = {}
    end
    local pos = 1
    while pos <= #html and #blocks < 400 do
        local a, b, tag = html:find("<([^>]*)>", pos)
        if not a then
            table.insert(buf, html:sub(pos))
            break
        end
        if a > pos then table.insert(buf, html:sub(pos, a - 1)) end
        local closing = tag:sub(1, 1) == "/"
        local name = (tag:match("^/?%s*([%w]+)") or ""):lower()
        pos = b + 1
        if name == "a" and not closing then
            local href = tag:match('[hH][rR][eE][fF]%s*=%s*"([^"]*)"') or tag:match("[hH][rR][eE][fF]%s*=%s*'([^']*)'")
            local c, d = html:find("</[aA]>", pos)
            local inner = html:sub(pos, (c or (#html + 1)) - 1):gsub("<[^>]*>", "")
            inner = S.brDecode(inner):gsub("%s+", " "):match("^%s*(.-)%s*$")
            local url = href and S.brResolve(base, href)
            if url and inner ~= "" then
                flush()
                table.insert(blocks, { type = "link", text = inner, url = url })
            elseif inner ~= "" then
                table.insert(buf, inner .. " ")
            end
            if d then pos = d + 1 end
        elseif name == "img" then
            local alt = tag:match('[aA][lL][tT]%s*=%s*"([^"]*)"')
            if alt and alt ~= "" then table.insert(buf, "[" .. alt .. "] ") end
        elseif name:match("^h[1-6]$") then
            flush()
            head = not closing
        elseif S.BR_BLOCK[name] then
            flush()
        end
    end
    flush()
    return blocks, title
end

function S.brSetStatus(t)
    t = tostring(t)
    if t:sub(1, 7) == "Loading" then S.brP.title.Text = "Loading..."
    elseif t == "Home" then S.brP.title.Text = "Internet Browser"
    else S.brP.title.Text = shortText(S.br.title or t, 44) end
end

function S.brSetLock(url)
    if S.brLock then S.brLock.Visible = type(url) == "string" and url:sub(1, 8) == "https://" end
end

function S.brSearch(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return end
    S.brGo("https://html.duckduckgo.com/html/?q=" .. HttpService:UrlEncode(text))
end

function S.brCountVisit(url, title)
    settings.brFreq = settings.brFreq or {}
    for _, e in ipairs(settings.brFreq) do
        if e.u == url then e.n += 1; e.t = shortText(title or e.t, 30); saveSettings() return end
    end
    if #settings.brFreq >= 12 then
        table.sort(settings.brFreq, function(a, b) return a.n > b.n end)
        table.remove(settings.brFreq)
    end
    table.insert(settings.brFreq, { u = url, t = shortText(title or url, 30), n = 1 })
    saveSettings()
end

function S.brRender(blocks, keepPos)
    S.br.lastBlocks = blocks
    S.brHome.Visible = false
    S.brBmBtn.Visible = false
    S.brScroll.Visible = true
    local z = S.br.zoom or 1
    local function sz(n) return math.max(8, math.floor(n * z + 0.5)) end
    local pos = S.brScroll.CanvasPosition
    clearList(S.brScroll)
    for i, b in ipairs(blocks) do
        if i > 400 then break end
        if b.type == "link" then
            local safe = tostring(b.text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            local btn = make("TextButton", {
                Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, AutoButtonColor = false, LayoutOrder = i,
                RichText = true, Text = "<u>" .. safe .. "</u>", TextColor3 = Color3.fromRGB(20, 70, 200),
                Font = Enum.Font.Gotham, TextSize = sz(14), TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, S.brScroll)
            btn.Activated:Connect(function() playSound("Select"); S.brGo(b.url) end)
        elseif b.type == "button" then
            local btn = button(S.brScroll, b.text, UDim2.new(1, -12, 0, 36), UDim2.new(), COLORS.blue, sz(14))
            btn.LayoutOrder = i
            btn.Activated:Connect(function() playSound("Select"); b.fn() end)
        else
            make("TextLabel", {
                Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, LayoutOrder = i, Text = b.text, TextWrapped = true,
                Font = b.head and Enum.Font.GothamBold or Enum.Font.Gotham,
                TextSize = sz(b.head and 18 or 14),
                TextColor3 = b.head and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(55, 55, 55),
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            }, S.brScroll)
        end
    end
    S.brScroll.CanvasPosition = keepPos and pos or Vector2.new(0, 0)
end

-- the blank start page: "Frequently Used Pages" + Bookmarks button
function S.brShowHome()
    S.brScroll.Visible = false
    S.brHome.Visible = true
    S.brBmBtn.Visible = true
    S.urlBox.Text = ""
    S.brSetLock(nil)
    local list = {}
    local freq = {}
    for _, e in ipairs(settings.brFreq or {}) do table.insert(freq, e) end
    table.sort(freq, function(a, b) return a.n > b.n end)
    for _, e in ipairs(freq) do table.insert(list, { t = e.t, u = e.u }) end
    for _, d in ipairs({
        { t = "DuckDuckGo", u = "https://html.duckduckgo.com/html/" },
        { t = "Wikipedia", u = "https://en.wikipedia.org/wiki/Special:Random" },
    }) do
        local has = false
        for _, e in ipairs(list) do if e.u == d.u then has = true end end
        if not has then table.insert(list, d) end
    end
    for i, tile in ipairs(S.brTiles) do
        local e = list[i]
        S.brTileUrls[i] = e and e.u or nil
        tile.art.Visible = e ~= nil
        tile.name.Text = e and e.t or ""
        if e then
            tile.art.BackgroundColor3 = S.colorFor(e.t)
            tile.initial.Text = tostring(e.t):sub(1, 1):upper()
        end
    end
end

function S.brToggleFull()
    S.br.full = not S.br.full
    for _, o in ipairs(S.brChrome) do o.Visible = not S.br.full end
    if S.br.full then
        S.brScroll.Position = UDim2.fromOffset(40, 16)
        S.brScroll.Size = UDim2.fromOffset(W - 80, H - 70)
    else
        S.brScroll.Position = UDim2.fromOffset(40, 106)
        S.brScroll.Size = UDim2.fromOffset(W - 80, H - 160)
    end
    notify(S.br.full and "Full screen on" or "Full screen off")
end

function S.brCycleZoom()
    local steps = { 0.85, 1, 1.25, 1.5 }
    local cur = 1
    for i, v in ipairs(steps) do if v == (S.br.zoom or 1) then cur = i end end
    S.br.zoom = steps[cur % #steps + 1]
    notify("Zoom " .. math.floor(S.br.zoom * 100 + 0.5) .. "%")
    if S.br.lastBlocks and S.brScroll.Visible then S.brRender(S.br.lastBlocks, true) end
end

function S.brHomeBlocks()
    local blocks = {
        { type = "text", text = "PS4 Internet Browser", head = true },
        { type = "text", text = "Type an address or a search term in the bar above. This is a simple text browser: no images, scripts or videos." },
        { type = "link", text = "Search the web (DuckDuckGo)", url = "https://html.duckduckgo.com/html/" },
        { type = "link", text = "Wikipedia", url = "https://en.wikipedia.org/wiki/Special:Random" },
    }
    local bms = settings.bookmarks or {}
    if #bms > 0 then table.insert(blocks, { type = "text", text = "Bookmarks", head = true }) end
    for _, bm in ipairs(bms) do table.insert(blocks, { type = "link", text = bm.t, url = bm.u }) end
    return blocks
end

function S.brExploitPage()
    local fw = tonumber(S.jbFw())
    local blocks = {
        { type = "text", text = "PS4 Exploit Host (simulated)", head = true },
        { type = "text", text = "Detected system software: " .. S.jbFw() },
    }
    if fw > S.JB_MAX_FW then
        table.insert(blocks, { type = "text", text = "This firmware is not supported (maximum 13.52). A jailbreak is not possible." })
    else
        table.insert(blocks, { type = "text", text = "Offline cache: 100% installed. Bookmark this page (Menu > Add Bookmark), then select the payload." })
        if settings.jbNoUpdate ~= true then
            table.insert(blocks, { type = "text", text = "Warning: system update files are not blocked (Settings > Jailbreak)." })
        end
        if S.jb.active then
            table.insert(blocks, { type = "text", text = "GoldHEN is already loaded." })
        else
            table.insert(blocks, { type = "button", text = "GoldHEN", fn = function() S.startJailbreak() end })
        end
    end
    table.insert(blocks, { type = "text", text = "This page is part of the dashboard simulation. Nothing real is exploited." })
    return blocks, "Exploit Host"
end

function S.brGo(url, noPush)
    url = (url or ""):match("^%s*(.-)%s*$")
    if url == "" then return end
    S.br.token += 1
    local my = S.br.token
    S.urlBox.Text = url == "about:home" and "" or url
    S.brSetLock(url)
    if not noPush then
        for i = #S.br.hist, S.br.idx + 1, -1 do table.remove(S.br.hist, i) end
        table.insert(S.br.hist, url)
        S.br.idx = #S.br.hist
    end
    if url == "about:home" then
        S.br.cur, S.br.title = url, "Home"
        S.brShowHome()
        S.brSetStatus("Home")
        return
    end
    local host = url:match("^https?://([^/?#]+)")
    if not host then
        S.brRender({ { type = "text", text = "Invalid address", head = true } })
        return
    end
    S.brSetStatus("Loading " .. shortText(url, 70) .. " ...")
    task.spawn(function()
        local blocks, title
        if S.JB_HOSTS[host:lower()] then
            task.wait(0.6)
            blocks, title = S.brExploitPage()
        else
            local ok, res = pcall(httpGet, url)
            if not ok then
                title = "Error"
                blocks = {
                    { type = "text", text = "This page can't be displayed", head = true },
                    { type = "text", text = "Check the address and your connection.\n" .. shortText(tostring(res), 140) },
                }
            else
                local head = res:sub(1, 800):lower()
                if head:find("<html", 1, true) or head:find("<body", 1, true) or head:find("<!doctype", 1, true)
                    or head:find("<div", 1, true) or head:find("<p", 1, true) or head:find("<a ", 1, true) then
                    blocks, title = S.brParse(res, url)
                else
                    blocks, title = {}, host
                    for line in (res:sub(1, 8000) .. "\n"):gmatch("(.-)\n") do
                        if line:match("%S") then table.insert(blocks, { type = "text", text = line }) end
                    end
                end
                if #blocks == 0 then
                    blocks = { { type = "text", text = "This page has no readable text (it probably needs JavaScript)." } }
                end
            end
        end
        if my ~= S.br.token then return end
        S.br.cur, S.br.title = url, title or host
        if not S.JB_HOSTS[host:lower()] and not url:find("duckduckgo.com/html", 1, true) then
            S.brCountVisit(url, title or host)
        end
        S.brRender(blocks)
        S.brSetStatus(shortText(S.br.title, 60) .. "  -  " .. host)
    end)
end

function S.brInput(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return end
    if text:match("^https?://") or text == "about:home" then S.brGo(text)
    elseif text:find("%.") and not text:find("%s") then S.brGo("https://" .. text)
    else S.brGo("https://html.duckduckgo.com/html/?q=" .. HttpService:UrlEncode(text)) end
end

function S.brStep(d)
    local i = S.br.idx + d
    if i < 1 or i > #S.br.hist then return end
    S.br.idx = i
    S.brGo(S.br.hist[i], true)
end

function S.brClearData()
    S.br.hist, S.br.idx = {}, 0
    settings.brFreq = {}
    saveSettings()
    S.jb.cacheClean = true
    notify("Cookies and website data deleted")
end

function S.brAddBookmark()
    local u = S.br.cur
    if not u or u == "about:home" then notify("Open a page first") return end
    settings.bookmarks = settings.bookmarks or {}
    for _, bm in ipairs(settings.bookmarks) do if bm.u == u then notify("Already bookmarked") return end end
    if #settings.bookmarks >= 20 then notify("Bookmark list is full") return end
    table.insert(settings.bookmarks, { t = shortText(S.br.title or u, 40), u = u })
    saveSettings()
    notify("Bookmark added")
end

function S.brBookmarks()
    local e = {}
    for i, bm in ipairs(settings.bookmarks or {}) do
        if i > 6 then break end
        table.insert(e, { shortText(bm.t, 24), function() S.brGo(bm.u) end })
    end
    if #e == 0 then table.insert(e, { "No bookmarks yet" }) end
    table.insert(e, { "Add Bookmark", function() S.brAddBookmark() end })
    if #(settings.bookmarks or {}) > 0 then
        table.insert(e, { "Clear Bookmarks", function() settings.bookmarks = {}; saveSettings(); notify("Bookmarks cleared") end })
    end
    openPanel("Bookmarks", e)
end

function S.brHistoryPanel()
    local e = {}
    for i = #S.br.hist, math.max(1, #S.br.hist - 7), -1 do
        local u = S.br.hist[i]
        table.insert(e, { shortText((u:gsub("^https?://", "")), 26), function() S.brGo(u) end })
    end
    if #e == 0 then e = { { "No history yet" } } end
    openPanel("Browsing History", e)
end

function S.brMore()
    openPanel("More", {
        { "Home", function() S.brGo("about:home") end },
        { "Stop Loading", function() S.br.token += 1; notify("Stopped") end },
        { "Copy Address", function() copyText(S.br.cur or "", "Address") end },
        { "Delete Cookies and Website Data", function() S.brClearData() end },
        { "Cancel" },
    })
end

function S.brOptions()
    openPanel("Options Menu", {
        { "Browsing History", function() S.brHistoryPanel() end },
        { "Bookmarks", function() S.brBookmarks() end },
        { "Back", function() S.brStep(-1) end },
        { "Forward", function() S.brStep(1) end },
        { "Refresh", function() S.brGo(S.br.cur or "about:home", true) end },
        { "Add Bookmark", function() S.brAddBookmark() end },
        { "More...", function() S.brMore() end },
        { "Cancel" },
    })
end

function S.openBrowser(url)
    showPage("Browser")
    if url then S.brGo(url)
    elseif S.br.idx == 0 then S.brGo("about:home") end
end

-- PS4-style browser screen: www + page title, address bar, search box, page area, bottom hints
S.iconDraw.lock = function(px, bar, dot)
    px(0.5, 0.64, 0.62, 0.46, { fill = true, r = 0.12 })
    px(0.5, 0.3, 0.38, 0.4, { r = 0.5 })
end
S.iconDraw.search = function(px, bar, dot)
    px(0.42, 0.42, 0.5, 0.5, { r = 0.5 })
    bar(0.78, 0.8, 0.3, 45)
end
S.iconDraw.heart = function(px, bar, dot)
    px(0.35, 0.36, 0.36, 0.36, { fill = true, r = 0.5 })
    px(0.65, 0.36, 0.36, 0.36, { fill = true, r = 0.5 })
    px(0.5, 0.56, 0.44, 0.44, { fill = true, rot = 45 })
end

function S.brBuildUI()
    local page = S.browserPage
    S.brP = pages.Browser
    S.br.zoom = 1
    S.brChrome = {}
    for _, c in ipairs(page:GetChildren()) do
        if c:IsA("Frame") and c.Size.Y.Scale == 0 and c.Size.Y.Offset == 1 then c:Destroy() end
    end
    S.brP.title.Position = UDim2.fromOffset(80, 16)
    S.brP.title.Size = UDim2.new(1, -140, 0, 36)
    S.brP.title.TextSize = 22
    S.brP.title.TextWrapped = false
    S.brP.title.TextTruncate = Enum.TextTruncate.AtEnd
    local www = label(page, "www", UDim2.fromOffset(36, 36), UDim2.fromOffset(40, 16), 12, COLORS.white, true)
    www.TextWrapped = false
    table.insert(S.brChrome, S.brP.title)
    table.insert(S.brChrome, www)

    local urlW = W - 80 - 200
    local function field(x, w)
        local f = make("Frame", {
            Size = UDim2.fromOffset(w, 34), Position = UDim2.fromOffset(x, 62),
            BackgroundColor3 = Color3.fromRGB(8, 32, 78), BackgroundTransparency = 0.1, BorderSizePixel = 0,
        }, page)
        local st = stroke(f, COLORS.white, 2, 0.55)
        table.insert(S.brChrome, f)
        return f, st
    end

    local urlF, urlS = field(40, urlW)
    S.urlBox = make("TextBox", {
        Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        PlaceholderText = "Enter URL", PlaceholderColor3 = COLORS.muted,
        TextColor3 = COLORS.white, Font = Enum.Font.Gotham, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true,
    }, urlF)
    S.brLock = S.icon("lock", urlF, 16, COLORS.white, UDim2.new(1, -28, 0, 9))
    S.brLock.Visible = false
    S.urlBox.Focused:Connect(function() urlS.Transparency = 0 end)
    S.urlBox.FocusLost:Connect(function(enter)
        urlS.Transparency = 0.55
        if enter then S.brInput(S.urlBox.Text) end
    end)

    local seaF, seaS = field(40 + urlW + 10, 190)
    S.icon("search", seaF, 16, COLORS.white, UDim2.fromOffset(10, 9))
    S.searchBox = make("TextBox", {
        Size = UDim2.new(1, -66, 1, 0), Position = UDim2.fromOffset(34, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        PlaceholderText = "Search", PlaceholderColor3 = COLORS.muted,
        TextColor3 = COLORS.white, Font = Enum.Font.Gotham, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true,
    }, seaF)
    local tri = make("TextButton", {
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -31, 0, 3),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    }, seaF)
    S.icon("triangle", tri, 16, COLORS.muted, UDim2.fromOffset(6, 6))
    tri.Activated:Connect(function() playSound("Select"); S.brSearch(S.searchBox.Text) end)
    S.searchBox.Focused:Connect(function() seaS.Transparency = 0 end)
    S.searchBox.FocusLost:Connect(function(enter)
        seaS.Transparency = 0.55
        if enter then S.brSearch(S.searchBox.Text) end
    end)

    S.brStatus = label(page, "", UDim2.fromOffset(10, 10), UDim2.fromOffset(0, 0), 11, COLORS.muted)
    S.brStatus.Visible = false

    S.brScroll = makeListScroll(page, 106, H - 160)
    S.brScroll.BackgroundTransparency = 0
    S.brScroll.BackgroundColor3 = Color3.fromRGB(234, 234, 234)
    S.brScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
    }, S.brScroll)

    S.brHome = make("Frame", {
        Size = UDim2.fromOffset(W - 80, 240), Position = UDim2.fromOffset(40, 106),
        BackgroundColor3 = Color3.fromRGB(6, 24, 60), BackgroundTransparency = 0.45, BorderSizePixel = 0,
    }, page)
    stroke(S.brHome, COLORS.white, 1, 0.55)
    label(S.brHome, "Frequently Used Pages", UDim2.fromOffset(300, 24), UDim2.fromOffset(12, 6), 13, COLORS.white)
    S.brTiles, S.brTileUrls = {}, {}
    local tw, th, gap = 165, 92, 12
    for i = 1, 8 do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local tile = make("TextButton", {
            Size = UDim2.fromOffset(tw, th),
            Position = UDim2.fromOffset(12 + col * (tw + gap), 34 + row * (th + gap)),
            BackgroundColor3 = Color3.fromRGB(10, 36, 86), BackgroundTransparency = 0.25,
            BorderSizePixel = 0, AutoButtonColor = false, Text = "",
        }, S.brHome)
        local ts = stroke(tile, COLORS.white, 1, 0.75)
        tile.MouseEnter:Connect(function() ts.Transparency = 0.1 end)
        tile.MouseLeave:Connect(function() ts.Transparency = 0.75 end)
        local art = make("Frame", {
            Size = UDim2.new(1, -8, 0, 52), Position = UDim2.fromOffset(4, 4),
            BackgroundColor3 = COLORS.card, BorderSizePixel = 0, Visible = false,
        }, tile)
        local initial = label(art, "", UDim2.fromScale(1, 1), UDim2.new(), 26, COLORS.white, true)
        initial.TextXAlignment = Enum.TextXAlignment.Center
        local nm = label(tile, "", UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 58), 11, COLORS.white)
        nm.TextYAlignment = Enum.TextYAlignment.Top
        tile.Activated:Connect(function()
            local u = S.brTileUrls[i]
            if u then playSound("Select"); S.brGo(u) end
        end)
        S.brTiles[i] = { art = art, initial = initial, name = nm }
    end

    S.brBmBtn = make("TextButton", {
        Size = UDim2.fromOffset(360, 32), Position = UDim2.fromOffset((W - 360) / 2, 356),
        BackgroundColor3 = Color3.fromRGB(6, 24, 60), BackgroundTransparency = 0.3,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "",
    }, page)
    stroke(S.brBmBtn, COLORS.white, 1, 0.7)
    S.icon("heart", S.brBmBtn, 18, COLORS.white, UDim2.fromOffset(120, 7))
    label(S.brBmBtn, "Bookmarks", UDim2.fromOffset(140, 32), UDim2.fromOffset(146, 0), 14, COLORS.white)
    S.brBmBtn.Activated:Connect(function() playSound("Select"); S.brBookmarks() end)

    local function hintBtn(x, w, fn)
        local b = make("TextButton", {
            Size = UDim2.fromOffset(w, 28), Position = UDim2.fromOffset(x, H - 44),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        }, page)
        b.Activated:Connect(function() playSound("Select"); fn() end)
    end
    local function pill(x, w, text)
        local f = make("Frame", {
            Size = UDim2.fromOffset(w, 16), Position = UDim2.fromOffset(x, H - 37),
            BackgroundTransparency = 1, BorderSizePixel = 0,
        }, page)
        round(f, 3)
        stroke(f, COLORS.muted, 1, 0)
        local l = label(f, text, UDim2.fromScale(1, 1), UDim2.new(), 9, COLORS.muted, true)
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextWrapped = false
    end
    S.icon("square", page, 16, COLORS.muted, UDim2.fromOffset(250, H - 37))
    label(page, "Full Screen", UDim2.fromOffset(90, 30), UDim2.fromOffset(272, H - 44), 14, COLORS.muted)
    hintBtn(246, 118, function() S.brToggleFull() end)
    pill(378, 28, "R3")
    label(page, "Zoom", UDim2.fromOffset(60, 30), UDim2.fromOffset(412, H - 44), 14, COLORS.muted)
    hintBtn(374, 90, function() S.brCycleZoom() end)
    pill(476, 62, "OPTIONS")
    label(page, "Options Menu", UDim2.fromOffset(110, 30), UDim2.fromOffset(544, H - 44), 14, COLORS.muted)
    hintBtn(472, 190, function() S.brOptions() end)
end
S.brBuildUI()

local notifDlRefs = {}

local function refreshNotifications()
    clearList(notifScroll)
    notifDlRefs = {}
    local order = 0
    local function header(text)
        order += 1
        local l = label(notifScroll, text, UDim2.new(1, -12, 0, 24), UDim2.new(), 12, COLORS.muted, true)
        l.LayoutOrder = order
    end
    if #dlQueue > 0 then
        header("DOWNLOADS")
        for _, id in ipairs(dlQueue) do
            local st = dlState[id]
            if st then
                order += 1
                local row = listRow(notifScroll, order, 62)
                rowButton(row, function() openDownloadOptions(id) end)
                rowText(row, tostring(st.data.title), UDim2.fromOffset(14, 6), UDim2.new(1, -28, 0, 20), 13, COLORS.white, true)
                local statusLbl = rowText(row, dlStatusText(id), UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 14), 11, COLORS.muted)
                local track = make("Frame", {
                    Size = UDim2.new(1, -28, 0, 6),
                    Position = UDim2.fromOffset(14, 48),
                    BackgroundColor3 = COLORS.white,
                    BackgroundTransparency = 0.8,
                    BorderSizePixel = 0,
                }, row)
                round(track, 3)
                local fill = make("Frame", {
                    Size = UDim2.fromScale(st.progress, 1),
                    BackgroundColor3 = Color3.fromRGB(0, 170, 255),
                    BorderSizePixel = 0,
                }, track)
                round(fill, 3)
                notifDlRefs[id] = { status = statusLbl, fill = fill }
            end
        end
    end
    header("NOTIFICATIONS")
    if #notifyLog == 0 then
        order += 1
        local l = label(notifScroll, "Nothing new.", UDim2.new(1, -12, 0, 30), UDim2.new(), 13, COLORS.muted)
        l.LayoutOrder = order
    end
    for _, n in ipairs(notifyLog) do
        order += 1
        local row = listRow(notifScroll, order, 38)
        rowButton(row, function()
            openPanel("Notification", {
                { "Remove", function()
                    for idx, v in ipairs(notifyLog) do
                        if v == n then table.remove(notifyLog, idx) break end
                    end
                    refreshNotifications()
                end },
                { "Clear All", function()
                    notifyLog = {}
                    refreshNotifications()
                end },
                { "Cancel" },
            })
        end)
        rowText(row, n.text, UDim2.fromOffset(14, 0), UDim2.new(1, -90, 1, 0), 12, COLORS.white)
        label(row, os.date("%H:%M", n.time), UDim2.fromOffset(60, 38), UDim2.new(1, -70, 0, 0), 11, COLORS.muted)
    end
end

S.fb = make("Frame", {
    Size = UDim2.new(1, 0, 0, 90),
    BackgroundTransparency = 1, ZIndex = 5,
}, main)

local hintLabel = label(S.fb, "", UDim2.fromOffset(110, 16), UDim2.fromOffset(0, 62), 11, COLORS.white)
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.Visible = false

S.functionItems = {
    { "♙", "Friends" }, { "◉", "Party" }, { "✉", "Messages" },
    { "♧", "Notifications" }, { "★", "Trophies" }, { "⚙", "Settings" }, { "⏻", "Power" },
}

for index, item in ipairs(S.functionItems) do
    local x = 24 + (index - 1) * 38
    local icon = make("TextButton", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.fromOffset(x, 22),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "", Font = Enum.Font.GothamMedium,
        TextSize = 22, TextColor3 = COLORS.white,
    }, S.fb)
    circle(icon)
    S.icon(({ Friends = "friends", Party = "party", Messages = "messages", Notifications = "bell",
        Trophies = "trophy", Settings = "gear", Power = "power" })[item[2]], icon, 20, COLORS.white, UDim2.fromOffset(6, 6))
    local ring = stroke(icon, COLORS.white, 2, 1)
    local function showHint()
        icon.BackgroundTransparency = 0.88
        ring.Transparency = 0.15
        hintLabel.Text = item[2]
        hintLabel.Position = UDim2.fromOffset(x + 16 - 55, 58)
        hintLabel.Visible = true
    end
    icon.MouseEnter:Connect(showHint)
    icon.MouseLeave:Connect(function()
        icon.BackgroundTransparency = 1
        ring.Transparency = 1
        if hintLabel.Text == item[2] then hintLabel.Visible = false end
    end)
    icon.Activated:Connect(function()
        playSound("Select")
        showHint()
        task.delay(1.5, function() if hintLabel.Text == item[2] then hintLabel.Visible = false end end)
        local name = item[2]
        if name == "Settings" then showPage("Settings")
        elseif name == "Power" then S.openPowerPanel()
        elseif name == "Friends" then S.refreshFriends(); showPage("Friends")
        elseif name == "Party" then refreshParty(); showPage("Party")
        elseif name == "Messages" then S.refreshMessages(); showPage("Messages")
        elseif name == "Notifications" then refreshNotifications(); showPage("Notifications")
        elseif name == "Trophies" then S.refreshTrophies(); showPage("Trophies") end
    end)
end

local clock = label(main, "", UDim2.fromOffset(60, 34), UDim2.new(1, -116, 0, 21), 15, COLORS.white)
clock.TextXAlignment = Enum.TextXAlignment.Right
clock.ZIndex = 5

S.clockBtn = make("TextButton", {
    Size = UDim2.fromOffset(60, 34),
    Position = UDim2.new(1, -116, 0, 21),
    BackgroundTransparency = 1, Text = "", ZIndex = 6,
}, main)
S.clockBtn.Activated:Connect(function()
    playSound("Select")
    notify(os.date("%A, %d %B %Y"))
end)

local avatar = make("ImageButton", {
    Size = UDim2.fromOffset(26, 26),
    Position = UDim2.fromOffset(346, 25),
    BackgroundColor3 = COLORS.card,
    BorderSizePixel = 0, Image = "", ZIndex = 5,
}, main)
circle(avatar)
stroke(avatar, COLORS.white, 1.5, 0.3)

-- Window controls, like a browser window: minimize and maximize
S.winBar = make("Frame", {
    Size = UDim2.fromOffset(84, 30),
    Position = UDim2.new(1, -206, 0, 23),
    BackgroundTransparency = 1,
    ZIndex = 6,
}, main)

function S.winButton(x)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(38, 30),
        Position = UDim2.fromOffset(x, 0),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 6,
    }, S.winBar)
    round(b, 6)
    b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.85 end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    return b
end

S.minBtn = S.winButton(0)
make("Frame", {
    Size = UDim2.fromOffset(12, 2),
    Position = UDim2.fromOffset(13, 17),
    BackgroundColor3 = COLORS.white,
    BorderSizePixel = 0, ZIndex = 7,
}, S.minBtn)

S.maxBtn = S.winButton(46)
S.sqBack = make("Frame", {
    Size = UDim2.fromOffset(9, 9),
    Position = UDim2.fromOffset(18, 8),
    BackgroundTransparency = 1,
    BorderSizePixel = 0, Visible = false, ZIndex = 7,
}, S.maxBtn)
stroke(S.sqBack, COLORS.white, 1.5, 0)
S.sqFront = make("Frame", {
    Size = UDim2.fromOffset(11, 11),
    Position = UDim2.fromOffset(14, 9),
    BackgroundColor3 = Color3.fromRGB(14, 52, 104),
    BackgroundTransparency = 1,
    BorderSizePixel = 0, ZIndex = 8,
}, S.maxBtn)
stroke(S.sqFront, COLORS.white, 1.5, 0)

-- maximize icon = one square, restore-down icon = two overlapping squares
function S.setMaxIcon(isMax)
    S.sqBack.Visible = isMax
    S.sqFront.BackgroundTransparency = isMax and 0 or 1
    S.sqFront.Size = isMax and UDim2.fromOffset(9, 9) or UDim2.fromOffset(11, 11)
    S.sqFront.Position = isMax and UDim2.fromOffset(12, 13) or UDim2.fromOffset(14, 9)
end

S.minBtn.Activated:Connect(function() playSound("Select"); minimizeDashboard() end)
S.maxBtn.Activated:Connect(function() playSound("Select"); S.toggleMaximize() end)

task.spawn(function()
    local ok, url = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if ok and url and avatar.Parent then avatar.Image = url end
end)

-- name + PS Plus icon next to the avatar, trophy level at the right (like the PS4)
S.nameHolder = make("Frame", {
    Size = UDim2.fromOffset(150, 26),
    Position = UDim2.fromOffset(380, 25),
    BackgroundTransparency = 1, ZIndex = 5,
}, main)
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 5),
}, S.nameHolder)
S.userName = make("TextLabel", {
    BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.fromOffset(0, 26), Text = player.DisplayName,
    Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COLORS.white,
    ZIndex = 5, LayoutOrder = 1,
}, S.nameHolder)
make("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 26), Text = "+",
    Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(255, 196, 0),
    ZIndex = 5, LayoutOrder = 2,
}, S.nameHolder)

S.trophyHolder = make("Frame", {
    Size = UDim2.fromOffset(60, 26),
    Position = UDim2.fromOffset(540, 25),
    BackgroundTransparency = 1, ZIndex = 5,
}, main)
S.icon("trophy", S.trophyHolder, 18, COLORS.white, UDim2.fromOffset(0, 4))
S.trophyCount = label(S.trophyHolder, "0", UDim2.fromOffset(34, 26), UDim2.fromOffset(24, 0), 13, COLORS.white)
S.trophyCount.TextWrapped = false

task.spawn(function()
    while gui.Parent do
        clock.Text = os.date("%H:%M")
        local n = 0
        for _ in pairs(earned) do n += 1 end
        S.trophyCount.Text = tostring(n)
        task.wait(1)
    end
end)

local BASE, FOCUS, GAP = 84, 141, 2
S.BAR = 30 -- arrow strip under the focused tile
local TILE_X, TILE_Y = 117, 83
local items = {}
local tiles = {}
local tileStrokes = {}
local focusIndex = 2 -- start on the first slot so the Store tile sits on its left, like the PS4

S.halo = make("Frame", {
    Size = UDim2.fromOffset(FOCUS + 18, FOCUS + 18),
    Position = UDim2.fromOffset(TILE_X - 9, TILE_Y - 9),
    BackgroundColor3 = COLORS.white,
    BackgroundTransparency = 0.9,
    BorderSizePixel = 0, ZIndex = 3,
}, main)
S.halo.Visible = false
TweenService:Create(S.halo,
    TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { BackgroundTransparency = 0.78 }):Play()

S.focusBar = make("Frame", {
    Size = UDim2.fromOffset(FOCUS, S.BAR + 2),
    Position = UDim2.fromOffset(TILE_X, TILE_Y + FOCUS - 2),
    BackgroundColor3 = Color3.fromRGB(40, 104, 206),
    BackgroundTransparency = 0,
    BorderSizePixel = 0, ZIndex = 4,
}, main)
stroke(S.focusBar, COLORS.white, 2, 0)
S.stripLabel = label(S.focusBar, "\226\134\147", UDim2.new(1, 0, 1, -2), UDim2.fromOffset(0, 2), 14, COLORS.white, true)
S.stripLabel.TextXAlignment = Enum.TextXAlignment.Center
S.stripBtn = make("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6,
}, S.focusBar)
S.stripLock = make("Frame", {
    Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -30, 0, 5),
    BackgroundTransparency = 1, ZIndex = 5, Visible = false,
}, S.focusBar)
S.menuOpen = false

-- games: "Start" bar on the bottom of the tile (with an options button), like the PS4
S.startOverlay = make("Frame", {
    Size = UDim2.fromOffset(FOCUS, 28),
    Position = UDim2.fromOffset(TILE_X, TILE_Y + FOCUS - 28),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0, ZIndex = 5, Visible = false,
}, main)
make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.2) }, S.startOverlay)
S.startLbl = label(S.startOverlay, "Start", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 13, COLORS.white)
S.startLbl.TextXAlignment = Enum.TextXAlignment.Center
S.startLbl.ZIndex = 6
S.startOpt = make("TextButton", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(4, 3),
    BackgroundTransparency = 1, Text = "", ZIndex = 8, Visible = false,
}, S.focusBar)
S.icon("options", S.startOpt, 14, COLORS.white, UDim2.fromOffset(6, 6))

-- games: small menu under the tile (Overview / Recent Activities / Related Items)
S.menuGroup = make("Frame", {
    Size = UDim2.fromOffset(FOCUS, 154),
    Position = UDim2.fromOffset(TILE_X, TILE_Y + FOCUS + S.BAR + 2),
    BackgroundColor3 = Color3.fromRGB(4, 24, 70),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0, ZIndex = 4, Visible = false,
}, main)
S.menuRows = {
    { "Overview", function(it) S.showScriptInfo(it.id) end },
    { "Recent Activities", function() refreshNotifications(); showPage("Notifications") end },
    { "Related Items", function() openStore() end },
    { "Edit Code", function(it) openEditor(it.id) end },
    { "Copy Script", function(it)
        local e = library[it.id]
        if e then copyText(tostring(e.code or ""), "Script") end
    end },
    { "Check for Update", function(it)
        local e = library[it.id]
        if e and not e.custom then S.checkForUpdate(it.id) else notify("No updates for custom scripts") end
    end },
    { "Delete Game", function(it) S.confirmDelete(it.id) end },
}
for i, r in ipairs(S.menuRows) do
    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, (i - 1) * 22),
        BackgroundColor3 = COLORS.white, BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = r[1], Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = COLORS.white, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, S.menuGroup)
    make("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
    if i > 1 then
        make("Frame", {
            Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, (i - 1) * 22),
            BackgroundColor3 = COLORS.white, BackgroundTransparency = 0.82,
            BorderSizePixel = 0, ZIndex = 6,
        }, S.menuGroup)
    end
    if r[1] == "Delete Game" then b.TextColor3 = Color3.fromRGB(255, 130, 130) end
    b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.85 end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    b.Activated:Connect(function()
        playSound("Select")
        local it = items[focusIndex]
        S.menuOpen = false
        if it and it.kind == "script" then
            S.updateFocusUI(it)
            r[2](it)
        end
    end)
end

-- games: big picture of the game + a box that says Keyless / Key required
S.gameGroup = make("Frame", {
    Size = UDim2.fromOffset(480, 170),
    Position = UDim2.fromOffset(TILE_X + FOCUS + 8, TILE_Y + FOCUS + 38),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Visible = false,
}, main)
S.keyBadge = make("Frame", {
    Size = UDim2.fromOffset(200, 42), Position = UDim2.fromOffset(262, 0),
    BackgroundColor3 = Color3.fromRGB(34, 158, 92), BorderSizePixel = 0, ZIndex = 4,
}, S.gameGroup)
S.keyIconHolder = make("Frame", {
    Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(8, 4),
    BackgroundTransparency = 1, ZIndex = 5,
}, S.keyBadge)
S.keyText = label(S.keyBadge, "Keyless", UDim2.new(1, -54, 1, 0), UDim2.fromOffset(46, 0), 14, COLORS.white, true)
S.keyText.ZIndex = 5
S.gameLine = label(S.gameGroup, "", UDim2.fromOffset(210, 36), UDim2.fromOffset(262, 52), 12, COLORS.muted)
S.gameLine.TextYAlignment = Enum.TextYAlignment.Top
S.viewsLine = label(S.gameGroup, "", UDim2.fromOffset(210, 18), UDim2.fromOffset(262, 90), 12, COLORS.muted)
S.gamePic = nil

function S.showGamePanel(item)
    if S.gamePic then S.gamePic:Destroy(); S.gamePic = nil end
    local e = library[item.id]
    if not e then return end
    local gname = tostring(e.game or "Universal")
    local pic = makeCover(S.gameGroup, "Frame", S.colorFor(gname), shortText(gname, 24))
    local cr = pic:FindFirstChildOfClass("UICorner")
    if cr then cr.CornerRadius = UDim.new(0, 0) end
    pic.Size = UDim2.fromOffset(250, 150)
    pic.Position = UDim2.fromOffset(0, 0)
    pic.ZIndex = 4
    if e.img or e.gameId then attachImage(pic, e.img, e.gameId) end
    S.gamePic = pic

    for _, c in ipairs(S.keyIconHolder:GetChildren()) do c:Destroy() end
    for _, c in ipairs(S.stripLock:GetChildren()) do c:Destroy() end
    local lockName = e.key and "lock" or "unlock"
    S.icon(lockName, S.stripLock, 20, COLORS.white, UDim2.fromOffset(1, 1))
    if e.key then
        S.keyBadge.BackgroundColor3 = Color3.fromRGB(214, 128, 24)
        S.keyText.Text = "Key required"
    else
        S.keyBadge.BackgroundColor3 = Color3.fromRGB(34, 158, 92)
        S.keyText.Text = "Keyless"
    end
    S.icon(lockName, S.keyIconHolder, 26, COLORS.white, UDim2.fromOffset(4, 4))
    S.gameLine.Text = "Game: " .. gname
    S.viewsLine.Text = "Views: " .. tostring(e.views or 0)
end

-- store: row of big cards under the tile (like the PS4 Store)
S.storeGroup = make("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    BorderSizePixel = 0, ZIndex = 3, Visible = false,
}, main)
S.storeCards = {
    { "Universal\nScripts", 2, 40, 131 },
    { "Admin\nCommands", 3, 173, 131 },
    { "Combat &\nAimbot", 4, 306, 131 },
    { "All Scripts", 1, 439, 262 },
}
for _, def in ipairs(S.storeCards) do
    local card = makeCover(S.storeGroup, "TextButton", S.colorFor(def[1]), def[1])
    local cr = card:FindFirstChildOfClass("UICorner")
    if cr then cr.CornerRadius = UDim.new(0, 0) end
    card.Position = UDim2.fromOffset(def[3], 283)
    card.Size = UDim2.fromOffset(def[4], 141)
    card.ZIndex = 4
    card.Activated:Connect(function() playSound("Select"); S.openGenre(def[2]) end)
    if def[4] > 200 then
        local bar = make("Frame", {
            Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -28),
            BackgroundColor3 = Color3.fromRGB(4, 20, 54), BackgroundTransparency = 0.1,
            BorderSizePixel = 0, ZIndex = 6,
        }, card)
        make("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 28), Position = UDim2.fromOffset(8, 0),
            Text = "+", Font = Enum.Font.GothamBold, TextSize = 20,
            TextColor3 = Color3.fromRGB(255, 196, 0), ZIndex = 7,
        }, bar)
        local t = label(bar, "FREE SCRIPTS TO PLAY", UDim2.new(1, -40, 1, 0), UDim2.fromOffset(32, 0), 10, COLORS.white, true)
        t.ZIndex = 7
    end
end

local nameLabel = label(main, "", UDim2.fromOffset(420, 28),
    UDim2.fromOffset(TILE_X + FOCUS + 8, TILE_Y + FOCUS), 24, COLORS.white)
nameLabel.ZIndex = 4
nameLabel.TextWrapped = false
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

local optionsButton = make("TextButton", {
    Size = UDim2.fromOffset(110, 26),
    Position = UDim2.fromOffset(TILE_X + FOCUS + 8, TILE_Y + FOCUS + 32),
    BackgroundColor3 = COLORS.white,
    BackgroundTransparency = 0.92,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "Options",
    Font = Enum.Font.GothamMedium, TextSize = 13,
    TextColor3 = COLORS.muted,
    ZIndex = 4,
}, main)
round(optionsButton, 15)
S.icon("options", optionsButton, 16, COLORS.white, UDim2.fromOffset(9, 5))
optionsButton.MouseEnter:Connect(function() optionsButton.TextColor3 = COLORS.white end)
optionsButton.MouseLeave:Connect(function() optionsButton.TextColor3 = COLORS.muted end)

local liveCards = {}
S.cardWidth = 400
S.feedGroup = make("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1,
}, main)

-- left: big feed post (like "Amy Michaels played UNCHARTED 4")
do
    local card = make("Frame", {
        Size = UDim2.fromOffset(S.cardWidth, 160),
        Position = UDim2.fromOffset(81, 293),
        BackgroundColor3 = Color3.fromRGB(18, 84, 184),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0, ZIndex = 3,
    }, S.feedGroup)
    S.feedThumb = make("Frame", {
        Size = UDim2.fromOffset(46, 46),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Color3.fromRGB(10, 90, 180),
        BorderSizePixel = 0, ZIndex = 4,
    }, card)
    local title = label(card, "", UDim2.new(1, -62, 0, 20), UDim2.fromOffset(56, 4), 13, COLORS.white, true)
    local body = label(card, "", UDim2.new(1, -62, 0, 34), UDim2.fromOffset(56, 24), 11, COLORS.muted)
    body.TextYAlignment = Enum.TextYAlignment.Top
    -- large "screenshot" area under the post
    S.feedArt = make("Frame", {
        Size = UDim2.new(1, -184, 0, 100),
        Position = UDim2.fromOffset(92, 58),
        BackgroundColor3 = Color3.fromRGB(6, 30, 70),
        BorderSizePixel = 0, ZIndex = 4,
    }, card)
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 90, 120), Color3.fromRGB(6, 20, 44)) }, S.feedArt)
    liveCards[1] = { title = title, body = body }
end

-- right: plain side column (like "Now Playing" / "Trending")
do
    local card = make("Frame", {
        Size = UDim2.fromOffset(190, 100),
        Position = UDim2.fromOffset(556, 293),
        BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 3,
    }, S.feedGroup)
    local title = label(card, "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 0), 12, COLORS.white)
    local body = label(card, "", UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 22), 11, COLORS.muted)
    body.TextYAlignment = Enum.TextYAlignment.Top
    liveCards[2] = { title = title, body = body }
end

function S.updateLive(item)
    local t1, b1, t2, b2
    local slots = libraryCount() .. "/" .. MAX_STORAGE .. " slots used."
    if not item then
        t1, b1, t2, b2 = "Nothing here yet", "Open the Store", "", ""
    elseif item.kind == "script" then
        local e = library[item.id]
        t1, b1 = "Ready to start", e and ("Game: " .. tostring(e.game or "Universal")) or ""
        t2, b2 = "Options", "Start, view information or delete this script."
    elseif item.kind == "download" then
        t1, b1 = "Download", dlStatusText(item.id)
        t2, b2 = "Options", "Pause or cancel this download."
    elseif item.kind == "empty" then
        t1, b1 = "Empty slot", "Double-press to write your own script, or get one from the Store."
        t2, b2 = "Storage", slots
    elseif item.kind == "whatsnew" then
        t1, b1 = player.DisplayName .. " opened the dashboard", "just now"
        t2, b2 = "Post an update", "Press Enter to share a Release, Showcase or Bug Report."
    elseif item.kind == "store" then
        t1, b1 = "New releases", "Browse ScriptBlox by genre, keyless or with key."
        t2, b2 = "Library", slots
    elseif item.kind == "browser" then
        t1, b1 = "Internet Browser", "Search the web or open a page. Text only."
        t2, b2 = "Storage", slots
    else
        t1, b1 = "Your scripts", "Everything you downloaded."
        t2, b2 = "Storage", slots
    end
    do
        local c = Color3.fromRGB(10, 90, 180)
        if item and (item.kind == "script" or item.kind == "download") then c = S.colorFor(item.name) end
        S.feedThumb.BackgroundColor3 = c
    end
    liveCards[1].title.Text = t1
    liveCards[1].body.Text = b1
    liveCards[2].title.Text = t2
    liveCards[2].body.Text = b2
    liveCards[2].title.Parent.Visible = t2 ~= ""
end

function S.layoutTiles(animate)
    for i, tile in ipairs(tiles) do
        local isFocus = i == focusIndex
        local size = isFocus and FOCUS or BASE
        local x
        if i < focusIndex then x = TILE_X - (focusIndex - i) * (BASE + GAP)
        elseif isFocus then x = TILE_X
        else x = TILE_X + FOCUS + GAP + (i - focusIndex - 1) * (BASE + GAP) end
        tileStrokes[i].Color = COLORS.white
        local gs = UDim2.fromOffset(size, size)
        local gp = UDim2.fromOffset(x, TILE_Y)
        if animate then
            tween(tile, 0.2, { Size = gs, Position = gp })
            tween(tileStrokes[i], 0.2, { Thickness = isFocus and 2 or 0 })
        else
            tile.Size = gs
            tile.Position = gp
            tileStrokes[i].Thickness = isFocus and 2 or 0
        end
    end
end

function S.updateFocusUI(item)
    local k = item.kind
    S.feedGroup.Visible = k ~= "script" and k ~= "store"
    S.storeGroup.Visible = k == "store"
    S.menuGroup.Visible = k == "script" and S.menuOpen == true
    S.gameGroup.Visible = k == "script"
    if k == "script" then S.showGamePanel(item) end
    S.startOverlay.Visible = false
    S.startOpt.Visible = k == "script"
    S.stripLock.Visible = k == "script"
    S.focusBar.Visible = true
    if k == "whatsnew" then
        S.stripLabel.Font = Enum.Font.GothamBold
        S.stripLabel.TextSize = 14
        S.stripLabel.Text = "\226\134\147"
    else
        S.stripLabel.Font = Enum.Font.Gotham
        S.stripLabel.TextSize = 12
        S.stripLabel.Text = ({ store = "Start", library = "Open", download = "Options", empty = "Write", browser = "Open" })[k] or "Start"
    end
end

local function setFocus(index, silent)
    if #items == 0 then return end
    index = math.clamp(index, 1, #items)
    if index ~= focusIndex and not silent then playSound("Select") end
    if index ~= focusIndex then S.menuOpen = false end
    focusIndex = index
    local item = items[focusIndex]
    nameLabel.Text = item.name
    optionsButton.Visible = false
    S.updateLive(item)
    S.updateFocusUI(item)
    S.layoutTiles(not silent)
end

openStore = function() end

local function activateFocus()
    local item = items[focusIndex]
    if not item then return end
    if item.kind == "script" then
        local e = library[item.id]
        if e then execScript(e.code) end
    elseif item.kind == "download" then
        openDownloadOptions(item.id)
    elseif item.kind == "empty" then
        openEditor()
    elseif item.kind == "store" then openStore()
    elseif item.kind == "whatsnew" then S.openNews()
    elseif item.kind == "browser" then S.openBrowser()
    else showPage("Library") end
end

function S.openStoreTileOptions()
    openPanel("PlayStation Store", {
        { "Open Store", function() openStore() end },
        { "View Downloads", function() refreshNotifications(); showPage("Notifications") end },
        { "Cancel" },
    })
end

function S.openLibraryTileOptions()
    openPanel("Library", {
        { "Open Library", function() showPage("Library") end },
        { "Storage Info", function()
            showInfo("Storage", libraryCount() .. " / " .. MAX_STORAGE .. " slots used\n" .. #dlQueue .. " download(s) in queue")
        end },
        { "Delete All Scripts", function()
            openPanel("Delete everything?", {
                { "Delete All", function()
                    for sid in pairs(library) do library[sid] = nil end
                    saveLibrary()
                    notify("Library cleared")
                    refreshLocal()
                end },
                { "Cancel" },
            })
        end },
        { "Cancel" },
    })
end

function S.openEmptyOptions()
    openPanel("Empty Slot", {
        { "Write Own Script", function() openEditor() end },
        { "Get Scripts (Open Store)", function() openStore() end },
        { "Cancel" },
    })
end

local function optionsForFocus()
    local item = items[focusIndex]
    if not item then return end
    if item.kind == "script" then
        S.menuOpen = not S.menuOpen
        S.updateFocusUI(item)
    elseif item.kind == "download" then openDownloadOptions(item.id)
    elseif item.kind == "whatsnew" then S.openNews()
    elseif item.kind == "store" then S.openStoreTileOptions()
    elseif item.kind == "library" then S.openLibraryTileOptions()
    elseif item.kind == "browser" then S.brOptions()
    else S.openEmptyOptions() end
end

optionsButton.Activated:Connect(function() playSound("Select"); optionsForFocus() end)
S.startOpt.Activated:Connect(function() playSound("Select"); optionsForFocus() end)
S.stripBtn.Activated:Connect(function() playSound("Select"); activateFocus() end)

for i, lc in ipairs(liveCards) do
    local overlay = make("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "", ZIndex = 6,
    }, lc.title.Parent)
    overlay.Activated:Connect(function()
        playSound("Select")
        if i == 1 then activateFocus() else optionsForFocus() end
    end)
end

-- "What's New" tile: the four PlayStation shapes
function S.drawNewsTile(tile)
    local hold = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(58, 58), BackgroundTransparency = 1,
    }, tile)
    S.icon("square", hold, 26, COLORS.white, UDim2.fromOffset(0, 0))
    S.icon("triangle", hold, 26, COLORS.white, UDim2.fromOffset(32, 0))
    S.icon("cross", hold, 26, COLORS.white, UDim2.fromOffset(0, 32))
    S.icon("circle", hold, 26, COLORS.white, UDim2.fromOffset(32, 32))
end

-- Store tile: shopping bag with the four shapes on it
function S.drawWebTile(tile)
    for i = 0, 7 do
        local a = math.rad(i * 45)
        local d = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5 + 0.36 * math.cos(a), 0.4 + 0.32 * math.sin(a)),
            Size = UDim2.fromOffset(5, 5), BackgroundColor3 = COLORS.white, BorderSizePixel = 0,
            ZIndex = tile.ZIndex + 1,
        }, tile)
        circle(d)
    end
    local w = make("TextLabel", {
        BackgroundTransparency = 1, Text = "WWW", Font = Enum.Font.GothamBold, TextColor3 = COLORS.white,
        TextScaled = true, Size = UDim2.fromScale(0.6, 0.2), Position = UDim2.fromScale(0.2, 0.3),
        ZIndex = tile.ZIndex + 1,
    }, tile)
end

function S.drawStoreTile(tile)
    local hold = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0),
        Size = UDim2.fromOffset(52, 58), BackgroundTransparency = 1,
    }, tile)
    local handle = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(26, 0),
        Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, ZIndex = 1,
    }, hold)
    circle(handle)
    stroke(handle, COLORS.white, 3, 0)
    local body = make("Frame", {
        Position = UDim2.fromOffset(0, 16), Size = UDim2.fromOffset(52, 42),
        BackgroundColor3 = Color3.fromRGB(70, 150, 235), BorderSizePixel = 0, ZIndex = 2,
    }, hold)
    round(body, 3)
    local c = COLORS.white
    S.icon("square", body, 12, c, UDim2.fromOffset(11, 8))
    S.icon("triangle", body, 12, c, UDim2.fromOffset(29, 8))
    S.icon("cross", body, 12, c, UDim2.fromOffset(11, 24))
    S.icon("circle", body, 12, c, UDim2.fromOffset(29, 24))
    local cap = label(tile, "PlayStation Store", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -18), 9, COLORS.white)
    cap.TextXAlignment = Enum.TextXAlignment.Center
    cap.TextWrapped = false
end

local lastEmptyTap = 0

function S.rebuildHome()
    for _, t in ipairs(tiles) do t:Destroy() end
    tiles = {}
    tileStrokes = {}
    items = {}
    tileProgress = {}

    table.insert(items, { kind = "store", name = "PlayStation\194\174Store" })
    table.insert(items, { kind = "whatsnew", name = "What's New" })
    local used = 0
    for _, row in ipairs(S.sortedLibrary()) do
        used += 1
        table.insert(items, { kind = "script", id = row.id, name = tostring(row.entry.title or "Script") })
    end
    for _, id in ipairs(dlQueue) do
        local st = dlState[id]
        if st then
            used += 1
            table.insert(items, { kind = "download", id = id, name = tostring(st.data.title) })
        end
    end
    for slot = used + 1, MAX_STORAGE do
        table.insert(items, { kind = "empty", name = "Empty Slot " .. slot })
    end
    table.insert(items, { kind = "browser", name = "Internet Browser" })
    table.insert(items, { kind = "library", name = "Library" })

    for i, item in ipairs(items) do
        local color, text
        if item.kind == "script" or item.kind == "download" then color, text = S.colorFor(item.name), shortText(item.name, 18)
        elseif item.kind == "store" then color, text = Color3.fromRGB(12, 46, 120), ""
        elseif item.kind == "whatsnew" then color, text = Color3.fromRGB(30, 100, 200), ""
        elseif item.kind == "browser" then color, text = Color3.fromRGB(10, 70, 175), ""
        elseif item.kind == "empty" then color, text = Color3.fromRGB(16, 34, 70), ""
        else color, text = COLORS.grey, "Library" end
        local tile = makeCover(main, "TextButton", color, text)
        local corner = tile:FindFirstChildOfClass("UICorner")
        if corner then corner.CornerRadius = UDim.new(0, 0) end
        tile.Name = "Tile" .. i
        tile.ZIndex = 4
        local imgPath, gid
        if item.kind == "script" and library[item.id] then
            imgPath, gid = library[item.id].img, library[item.id].gameId
        elseif item.kind == "download" and dlState[item.id] then
            imgPath, gid = dlState[item.id].data.img, dlState[item.id].data.gameId
        end
        if imgPath or gid then attachImage(tile, imgPath, gid) end
        if item.kind == "store" then S.drawStoreTile(tile) elseif item.kind == "whatsnew" then S.drawNewsTile(tile) elseif item.kind == "browser" then S.drawWebTile(tile) end
        if item.kind == "download" then
            local dim = make("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.45,
                BorderSizePixel = 0, ZIndex = 3,
            }, tile)
            round(dim, 4)
            local track = make("Frame", {
                Size = UDim2.new(1, -16, 0, 6),
                Position = UDim2.new(0, 8, 1, -16),
                BackgroundColor3 = COLORS.white,
                BackgroundTransparency = 0.7,
                BorderSizePixel = 0, ZIndex = 4,
            }, tile)
            round(track, 3)
            local fill = make("Frame", {
                Size = UDim2.fromScale(0, 1),
                BackgroundColor3 = Color3.fromRGB(0, 170, 255),
                BorderSizePixel = 0, ZIndex = 5,
            }, track)
            round(fill, 3)
            local pctLabel = make("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 22),
                Position = UDim2.new(0, 0, 0.5, -14),
                Text = "",
                Font = Enum.Font.GothamBold, TextSize = 16,
                TextColor3 = COLORS.white, ZIndex = 4,
            }, tile)
            tileProgress[item.id] = { fill = fill, pct = pctLabel }
            updateProgressViews(item.id)
        end
        tileStrokes[i] = stroke(tile, COLORS.white, 0, 0)
        tile.Activated:Connect(function()
            if S.longFired then S.longFired = false return end
            if i ~= focusIndex then
                setFocus(i)
                if item.kind == "empty" then lastEmptyTap = tick() end
            elseif item.kind == "empty" then
                local now = tick()
                if now - lastEmptyTap < 0.6 then
                    lastEmptyTap = 0
                    playSound("Select")
                    openEditor()
                else
                    lastEmptyTap = now
                    notify("Press again to write your own script")
                end
            elseif item.kind == "script" or item.kind == "whatsnew" then
                -- tapping the tile itself does nothing: press "Start" (the bar under it) to start
                playSound("Select")
            else
                playSound("Select")
                activateFocus()
            end
        end)
        tile.MouseButton2Click:Connect(function()
            if i ~= focusIndex then setFocus(i) end
            optionsForFocus()
        end)
        tile.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            S.longFired = false
            S.pressId = (S.pressId or 0) + 1
            local mine = S.pressId
            task.delay(0.55, function()
                if S.pressId == mine and input.UserInputState ~= Enum.UserInputState.End then
                    S.longFired = true
                    if i ~= focusIndex then setFocus(i) end
                    optionsForFocus()
                end
            end)
        end)
        tiles[i] = tile
    end

    focusIndex = math.clamp(focusIndex, 1, #items)
    setFocus(focusIndex, true)
end

-- ===== PS4 on-screen keyboard (used by Library search and Store search) =====
S.kbLayers = {
    normal = { "1234567890", "qwertyuiop", "asdfghjkl'", "zxcvbnm,.?" },
    sym = { "!@#$%^&*()", "-_=+[]{};:", "<>/\\|~`\"@#", "!?.,:;()$%" },
}
S.kbDigits = { Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
    Six = "6", Seven = "7", Eight = "8", Nine = "9", Period = ".", Comma = ",", Minus = "-" }
S.KB_KEY = Color3.fromRGB(0, 70, 170)

function S.kbKey(parent, w, text, order, color)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(w, 36), BackgroundColor3 = color or S.KB_KEY,
        BackgroundTransparency = 0.12, BorderSizePixel = 0, AutoButtonColor = false,
        Text = text, Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = COLORS.white,
        LayoutOrder = order,
    }, parent)
    local st = stroke(b, COLORS.white, 2, 1)
    b.MouseEnter:Connect(function() st.Transparency = 0 end)
    b.MouseLeave:Connect(function() st.Transparency = 1 end)
    return b
end

function S.buildKeyboard()
    if S.kb then return S.kb end
    local kb = { value = "", shift = false, sym = false, open = false, blink = true, token = 0 }
    S.kb = kb
    kb.root = make("CanvasGroup", {
        Name = "PS4Keyboard", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 53,
    }, main)
    local back = make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Active = true,
    }, kb.root)
    make("UIGradient", {
        Rotation = 35,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 52, 150)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(0, 90, 196)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 46, 128)),
        }),
    }, back)
    -- soft PS4 bokeh dots
    for i = 1, 8 do
        local d = 8 + (i * 7) % 22
        local dotF = make("Frame", {
            Size = UDim2.fromOffset(d, d), BorderSizePixel = 0,
            Position = UDim2.fromOffset(120 + (i * 97) % 640, 20 + (i * 61) % 400),
            BackgroundColor3 = COLORS.white, BackgroundTransparency = 0.86,
        }, kb.root)
        circle(dotF)
    end

    -- search field
    local field = make("Frame", {
        Size = UDim2.fromOffset(427, 36), Position = UDim2.fromOffset(40, 34),
        BackgroundColor3 = Color3.fromRGB(0, 40, 120), BackgroundTransparency = 0.35, BorderSizePixel = 0,
    }, kb.root)
    stroke(field, COLORS.white, 2, 0)
    S.icon("search", field, 18, COLORS.white, UDim2.fromOffset(10, 9))
    kb.text = make("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -48, 1, 0), Position = UDim2.fromOffset(38, 0),
        Font = Enum.Font.Gotham, TextSize = 16, TextColor3 = COLORS.white, Text = "",
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, field)
    kb.title = label(kb.root, "", UDim2.fromOffset(300, 22), UDim2.fromOffset(40, 8), 12, COLORS.muted)
    make("Frame", {
        Size = UDim2.fromOffset(427, 20), Position = UDim2.fromOffset(40, 76),
        BackgroundColor3 = Color3.fromRGB(0, 40, 120), BackgroundTransparency = 0.55, BorderSizePixel = 0,
    }, kb.root)

    -- character rows
    kb.keys = {}
    for r = 1, 4 do
        local row = make("Frame", {
            Size = UDim2.fromOffset(427, 36), Position = UDim2.fromOffset(40, 104 + (r - 1) * 39),
            BackgroundTransparency = 1,
        }, kb.root)
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, row)
        kb.keys[r] = {}
        for c = 1, 10 do
            local b = S.kbKey(row, 40, "", c)
            kb.keys[r][c] = b
            b.Activated:Connect(function()
                playSound("Select")
                kb.insert(b.Text)
                if kb.shift then kb.shift = false; kb.layout() end
            end)
        end
    end
    -- function row
    local row5 = make("Frame", {
        Size = UDim2.fromOffset(427, 36), Position = UDim2.fromOffset(40, 260), BackgroundTransparency = 1,
    }, kb.root)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
    }, row5)
    kb.shiftBtn = S.kbKey(row5, 40, "Aa", 1)
    kb.symBtn = S.kbKey(row5, 40, "@#:", 2)
    local clr = S.kbKey(row5, 40, "Clr", 3)
    local space = S.kbKey(row5, 192, "Space", 4)
    local dotK = S.kbKey(row5, 40, ".", 5)
    local del = S.kbKey(row5, 60, "Del", 6)
    kb.shiftBtn.Activated:Connect(function() playSound("Select"); kb.shift = not kb.shift; kb.layout() end)
    kb.symBtn.Activated:Connect(function() playSound("Select"); kb.sym = not kb.sym; kb.layout() end)
    clr.Activated:Connect(function() playSound("Select"); kb.value = ""; kb.changed() end)
    space.Activated:Connect(function() playSound("Select"); kb.insert(" ") end)
    dotK.Activated:Connect(function() playSound("Select"); kb.insert(".") end)
    del.Activated:Connect(function() playSound("Select"); kb.backspace() end)
    -- cancel / done
    local row6 = make("Frame", {
        Size = UDim2.fromOffset(427, 36), Position = UDim2.fromOffset(40, 299), BackgroundTransparency = 1,
    }, kb.root)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
    }, row6)
    local cancel = S.kbKey(row6, 210, "Cancel", 1)
    S.icon("circle", cancel, 16, COLORS.muted, UDim2.fromOffset(14, 10))
    local done = S.kbKey(row6, 214, "Done", 2, Color3.fromRGB(0, 112, 209))
    S.icon("cross", done, 16, COLORS.white, UDim2.fromOffset(14, 10))
    cancel.Activated:Connect(function() kb.close(false) end)
    done.Activated:Connect(function() kb.close(true) end)

    -- results panel (right)
    kb.resHead = label(kb.root, "Results", UDim2.fromOffset(240, 24), UDim2.fromOffset(510, 34), 14, COLORS.white, true)
    kb.resList = make("Frame", {
        Size = UDim2.fromOffset(260, 300), Position = UDim2.fromOffset(510, 74), BackgroundTransparency = 1,
    }, kb.root)
    make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, kb.resList)
    kb.hint = label(kb.root, "", UDim2.fromOffset(250, 60), UDim2.fromOffset(510, 74), 13, COLORS.muted)
    kb.hint.TextYAlignment = Enum.TextYAlignment.Top

    function kb.render()
        kb.text.Text = kb.value .. (kb.blink and "|" or "")
    end
    function kb.refreshResults()
        for _, c in ipairs(kb.resList:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        if not kb.resultsFn then
            kb.resHead.Text = "Results"
            kb.hint.Text = kb.hintText or ""
            return
        end
        kb.hint.Text = ""
        local list, total = kb.resultsFn(kb.value)
        kb.resHead.Text = "Results  " .. tostring(total or #list)
        if #list == 0 then
            kb.hint.Text = kb.value == "" and "Start typing to filter your library." or "No matches."
        end
        for i, t in ipairs(list) do
            if i > 5 then break end
            local r = make("Frame", { Size = UDim2.fromOffset(260, 46), BackgroundTransparency = 1, LayoutOrder = i }, kb.resList)
            local th = makeCover(r, "Frame", S.colorFor(t), "")
            th.Size = UDim2.fromOffset(46, 46)
            local cr = th:FindFirstChildOfClass("UICorner")
            if cr then cr.CornerRadius = UDim.new(0, 0) end
            local l = label(r, t, UDim2.fromOffset(204, 46), UDim2.fromOffset(54, 0), 12, COLORS.white)
            l.TextTruncate = Enum.TextTruncate.AtEnd
        end
    end
    function kb.changed()
        kb.render()
        kb.refreshResults()
    end
    function kb.insert(ch)
        if #kb.value >= 60 then return end
        kb.value = kb.value .. ch
        kb.changed()
    end
    function kb.backspace()
        kb.value = kb.value:sub(1, math.max(0, #kb.value - 1))
        kb.changed()
    end
    function kb.layout()
        local layer = kb.sym and S.kbLayers.sym or S.kbLayers.normal
        for r = 1, 4 do
            for c = 1, 10 do
                local ch = layer[r]:sub(c, c)
                if kb.shift and not kb.sym then ch = ch:upper() end
                kb.keys[r][c].Text = ch
            end
        end
        kb.symBtn.Text = kb.sym and "abc" or "@#:"
        kb.shiftBtn.BackgroundColor3 = kb.shift and Color3.fromRGB(40, 130, 230) or S.KB_KEY
    end
    function kb.close(accept)
        if not kb.open then return end
        kb.open = false
        S.kbOpen = false
        if kb.conn then kb.conn:Disconnect(); kb.conn = nil end
        tween(kb.root, 0.15, { GroupTransparency = 1 })
        task.delay(0.17, function()
            if not kb.open then kb.root.Visible = false end
        end)
        playSound("Close")
        if accept and kb.onDone then kb.onDone(kb.value) end
    end
    return kb
end

-- S.openKeyboard(title, initialText, { onDone = fn(text), results = fn(text) -> list, total, hint = "..." })
function S.openKeyboard(title, initial, opts)
    opts = opts or {}
    local kb = S.buildKeyboard()
    if kb.open then return end
    kb.value = initial or ""
    kb.onDone = opts.onDone
    kb.resultsFn = opts.results
    kb.hintText = opts.hint
    kb.title.Text = title or ""
    kb.shift, kb.sym = false, false
    kb.layout()
    kb.changed()
    kb.open = true
    S.kbOpen = true
    kb.root.Visible = true
    kb.root.GroupTransparency = 1
    tween(kb.root, 0.18, { GroupTransparency = 0 })
    playSound("Open")
    -- a real keyboard works too
    kb.conn = UserInputService.InputBegan:Connect(function(input)
        if not kb.open or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local name = input.KeyCode.Name
        if name == "Backspace" then kb.backspace()
        elseif name == "Return" or name == "KeypadEnter" then kb.close(true)
        elseif name == "Escape" then kb.close(false)
        elseif name == "Space" then kb.insert(" ")
        elseif #name == 1 and name:match("%a") then
            local up = kb.shift or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            kb.insert(up and name or name:lower())
        elseif S.kbDigits[name] then kb.insert(S.kbDigits[name]) end
    end)
    kb.token += 1
    local mine = kb.token
    task.spawn(function()
        while kb.open and kb.token == mine and kb.root.Parent do
            kb.blink = not kb.blink
            kb.render()
            task.wait(0.5)
        end
    end)
end

-- ===== Library: PS4 style (list on the left, tile grid on the right) =====
local libFilter = "all"
S.libCats = {
    { id = "all", name = "All" },
    { id = "keyless", name = "Keyless" },
    { id = "key", name = "Key Required" },
}
S.libSel = {}
S.libQuery = ""
S.libSort = 1
S.libSorts = { "Name: A-Z", "Name: Z-A", "Newest first", "Oldest first" }
local refreshLibrary

-- PS4 library blue (not affected by the theme switcher)
do
    local libBack = libraryPage:FindFirstChildOfClass("Frame")
    local g = libBack and libBack:FindFirstChildOfClass("UIGradient")
    if g then
        for i = #pageGradients, 1, -1 do
            if pageGradients[i] == g then table.remove(pageGradients, i) end
        end
        g.Rotation = 40
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 58, 160)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 86, 192)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 50, 140)),
        })
    end
end

-- selected items: count + thumbnails (top right)
S.libCount = make("TextLabel", {
    Size = UDim2.fromOffset(34, 28), Position = UDim2.fromOffset(470, 26),
    BackgroundTransparency = 1, Text = "0",
    Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = COLORS.white,
}, libraryPage)
stroke(S.libCount, COLORS.white, 1, 0.6)
S.libThumbs = make("Frame", {
    Size = UDim2.fromOffset(250, 28), Position = UDim2.fromOffset(512, 26), BackgroundTransparency = 1,
}, libraryPage)
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, S.libThumbs)
make("Frame", {
    Size = UDim2.new(1, -80, 0, 1), Position = UDim2.fromOffset(40, H - 57),
    BackgroundColor3 = COLORS.white, BackgroundTransparency = 0.85, BorderSizePixel = 0,
}, libraryPage)

-- left list: Search / All / Keyless / Key Required
S.libSide = {}
S.sideDefs = {
    { id = "search", name = "Search", icon = "search" },
    { id = "all", name = "All", icon = "library" },
    { id = "keyless", name = "Keyless", icon = "check" },
    { id = "key", name = "Key Required", icon = "options" },
}
for i, d in ipairs(S.sideDefs) do
    local b = make("TextButton", {
        Size = UDim2.fromOffset(166, 36), Position = UDim2.fromOffset(40, 84 + (i - 1) * 42),
        BackgroundTransparency = 1, BackgroundColor3 = COLORS.white, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "",
    }, libraryPage)
    local st = stroke(b, COLORS.white, 2, 1)
    S.icon(d.icon, b, 18, COLORS.white, UDim2.fromOffset(10, 9))
    local nm = label(b, d.name, UDim2.fromOffset(104, 36), UDim2.fromOffset(38, 0), 13, COLORS.white)
    nm.TextWrapped = false
    nm.TextTruncate = Enum.TextTruncate.AtEnd
    local cnt
    if d.id == "search" then
        S.libSearchLbl = nm
    else
        cnt = label(b, "0", UDim2.fromOffset(30, 36), UDim2.new(1, -36, 0, 0), 11, COLORS.white, true)
        cnt.TextXAlignment = Enum.TextXAlignment.Right
    end
    S.libSide[d.id] = { stroke = st, count = cnt }
    b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.88 end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    b.Activated:Connect(function()
        playSound("Select")
        if d.id == "search" then
            S.openKeyboard("Search Library", S.libQuery, {
                onDone = function(text) S.libQuery = text; refreshLibrary() end,
                results = function(text)
                    local out, total, q = {}, 0, text:lower()
                    for _, row in ipairs(S.sortedLibrary()) do
                        local t = tostring(row.entry.title or "")
                        if q == "" or t:lower():find(q, 1, true) then
                            total += 1
                            if #out < 5 then table.insert(out, t) end
                        end
                    end
                    return out, total
                end,
            })
        else
            libFilter = d.id
            refreshLibrary()
        end
    end)
end

S.storageLabel = label(libraryPage, "", UDim2.fromOffset(166, 36), UDim2.fromOffset(40, 84 + 4 * 42 + 6), 11, COLORS.muted)
S.storageLabel.TextYAlignment = Enum.TextYAlignment.Top

-- sort dropdown (top right of the grid)
S.sortBtn = make("TextButton", {
    Size = UDim2.fromOffset(340, 26), Position = UDim2.fromOffset(444, 78),
    BackgroundColor3 = Color3.fromRGB(0, 40, 120), BackgroundTransparency = 0.45,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "",
}, libraryPage)
stroke(S.sortBtn, COLORS.white, 1.5, 0.15)
S.sortLbl = label(S.sortBtn, "Name: A-Z", UDim2.new(1, -40, 1, 0), UDim2.fromOffset(10, 0), 12, COLORS.white)
S.sortChev = label(S.sortBtn, ">", UDim2.fromOffset(20, 26), UDim2.new(1, -28, 0, 0), 12, COLORS.white, true)
S.sortChev.TextXAlignment = Enum.TextXAlignment.Center
S.sortChev.Rotation = 90
S.sortBtn.Activated:Connect(function()
    playSound("Select")
    S.libSort = S.libSort % #S.libSorts + 1
    refreshLibrary()
end)

-- tile grid
S.libGrid = make("ScrollingFrame", {
    Size = UDim2.fromOffset(566, 280), Position = UDim2.fromOffset(222, 112),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = COLORS.muted,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, libraryPage)
make("UIGridLayout", {
    CellSize = UDim2.fromOffset(180, 64), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder,
}, S.libGrid)
make("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingRight = UDim.new(0, 6) }, S.libGrid)

-- bottom buttons
function S.libButton(text, x, y)
    local btn = make("TextButton", {
        Size = UDim2.fromOffset(104, 28), Position = UDim2.fromOffset(x, y),
        BackgroundColor3 = COLORS.white, BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = text,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.white,
    }, libraryPage)
    stroke(btn, COLORS.white, 1.2, 0.15)
    btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.85 end)
    btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
    return btn
end
S.selAllBtn = S.libButton("Select All", 240, H - 44)
S.deselBtn = S.libButton("Deselect All", 352, H - 44)
S.confirmBtn = S.libButton("Confirm", 464, H - 44)

S.libEmpty = label(libraryPage, "Nothing here yet. Download scripts from the PlayStation Store.",
    UDim2.fromOffset(400, 30), UDim2.fromOffset(250, 200), 14, COLORS.white)

-- user name bottom right
S.avatarCircle(libraryPage, player.UserId, W - 218, H - 42, 18)
S.libUser = make("Frame", {
    Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(W - 194, H - 48), BackgroundTransparency = 1,
}, libraryPage)
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5),
}, S.libUser)
S.libUserName = make("TextLabel", {
    BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30),
    Text = player.DisplayName, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COLORS.white, LayoutOrder = 1,
}, S.libUser)
make("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 30), Text = "+",
    Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(255, 196, 0), LayoutOrder = 2,
}, S.libUser)

function S.libMatches(e)
    local okFilter = libFilter == "all"
        or (libFilter == "keyless" and not e.key)
        or (libFilter == "key" and e.key and true or false)
    if not okFilter then return false end
    if S.libQuery == "" then return true end
    return tostring(e.title or ""):lower():find(S.libQuery:lower(), 1, true) ~= nil
end

function S.libRefreshSel()
    for _, c in ipairs(S.libThumbs:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local n = 0
    for _, row in ipairs(S.sortedLibrary()) do
        if S.libSel[row.id] then
            n += 1
            if n <= 8 then
                local th = makeCover(S.libThumbs, "Frame", S.colorFor(row.entry.title), "")
                th.Size = UDim2.fromOffset(28, 28)
                th.LayoutOrder = n
                local cr = th:FindFirstChildOfClass("UICorner")
                if cr then cr.CornerRadius = UDim.new(0, 0) end
                if row.entry.img or row.entry.gameId then attachImage(th, row.entry.img, row.entry.gameId) end
            end
        end
    end
    S.libCount.Text = tostring(n)
end

S.selAllBtn.Activated:Connect(function()
    playSound("Select")
    for _, row in ipairs(S.sortedLibrary()) do
        if S.libMatches(row.entry) then S.libSel[row.id] = true end
    end
    refreshLibrary()
end)
S.deselBtn.Activated:Connect(function()
    playSound("Select")
    S.libSel = {}
    refreshLibrary()
end)
S.confirmBtn.Activated:Connect(function()
    playSound("Select")
    local ids = {}
    for _, row in ipairs(S.sortedLibrary()) do
        if S.libSel[row.id] then table.insert(ids, row.id) end
    end
    if #ids == 0 then notify("Select content first") return end
    openPanel(#ids .. " selected", {
        { "Start", function()
            for _, id in ipairs(ids) do
                if library[id] then execScript(library[id].code) end
            end
        end },
        { "Delete", function()
            openPanel("Delete " .. #ids .. " script(s)?", {
                { "Delete", function()
                    for _, id in ipairs(ids) do S.libSel[id] = nil; S.deleteFromLibrary(id) end
                end },
                { "Cancel" },
            })
        end },
        { "Cancel" },
    })
end)

refreshLibrary = function()
    for _, c in ipairs(S.libGrid:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local list = S.sortedLibrary()
    local present = {}
    local counts = { all = 0, keyless = 0, key = 0 }
    for _, row in ipairs(list) do
        present[row.id] = true
        counts.all += 1
        if row.entry.key then counts.key += 1 else counts.keyless += 1 end
    end
    for id in pairs(S.libSel) do
        if not present[id] then S.libSel[id] = nil end
    end
    for id, side in pairs(S.libSide) do
        if side.count then side.count.Text = tostring(counts[id] or 0) end
        if id == "search" then
            side.stroke.Transparency = S.libQuery ~= "" and 0.4 or 1
        else
            side.stroke.Transparency = (libFilter == id) and 0 or 1
        end
    end
    S.libSearchLbl.Text = S.libQuery ~= "" and ("Search: " .. S.libQuery) or "Search"
    S.sortLbl.Text = S.libSorts[S.libSort]
    S.storageLabel.Text = "Storage: " .. libraryCount() .. " / " .. MAX_STORAGE .. " slots used"

    local mode = S.libSort
    table.sort(list, function(a, b)
        local ta, tb = tostring(a.entry.title or ""):lower(), tostring(b.entry.title or ""):lower()
        local da, db = a.entry.downloadedAt or 0, b.entry.downloadedAt or 0
        if mode == 1 and ta ~= tb then return ta < tb end
        if mode == 2 and ta ~= tb then return ta > tb end
        if mode == 3 and da ~= db then return da > db end
        if mode == 4 and da ~= db then return da < db end
        return a.id < b.id
    end)

    local shown = 0
    for _, row in ipairs(list) do
        local id, e = row.id, row.entry
        if S.libMatches(e) then
            shown += 1
            local cell = make("TextButton", {
                BackgroundColor3 = Color3.fromRGB(28, 112, 218), BackgroundTransparency = 0.05,
                BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = shown,
            }, S.libGrid)
            local thumb = makeCover(cell, "Frame", S.colorFor(e.title), shortText(e.title, 14))
            thumb.Size = UDim2.fromOffset(64, 64)
            local cr = thumb:FindFirstChildOfClass("UICorner")
            if cr then cr.CornerRadius = UDim.new(0, 0) end
            if e.img or e.gameId then attachImage(thumb, e.img, e.gameId) end
            local nameLbl = label(cell, tostring(e.title or "Script"), UDim2.fromOffset(94, 46), UDim2.fromOffset(72, 4), 11, COLORS.white)
            nameLbl.TextYAlignment = Enum.TextYAlignment.Top
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            if e.key then
                local k = label(cell, "Key required", UDim2.fromOffset(100, 12), UDim2.fromOffset(72, 49), 9, COLORS.muted)
                k.TextWrapped = false
            end
            local box = make("Frame", {
                Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(160, 6),
                BackgroundColor3 = COLORS.white, BackgroundTransparency = 1, BorderSizePixel = 0,
            }, cell)
            stroke(box, COLORS.white, 1.2, 0.1)
            local mark = S.icon("check", box, 14, Color3.fromRGB(14, 74, 168), UDim2.fromOffset(0, 0))
            local ring = stroke(cell, COLORS.white, 0, 0)
            local function paint()
                local on = S.libSel[id] == true
                ring.Thickness = on and 2 or 0
                box.BackgroundTransparency = on and 0 or 1
                mark.Visible = on
            end
            paint()
            cell.MouseEnter:Connect(function() if not S.libSel[id] then ring.Thickness = 1 end end)
            cell.MouseLeave:Connect(paint)
            cell.Activated:Connect(function()
                playSound("Select")
                S.libSel[id] = (not S.libSel[id]) or nil
                paint()
                S.libRefreshSel()
            end)
            cell.MouseButton2Click:Connect(function() playSound("Select"); S.openScriptOptions(id) end)
        end
    end

    S.libEmpty.Visible = shown == 0
    S.libEmpty.Text = (S.libQuery ~= "" and counts.all > 0) and "No matches for your search." or "Nothing here yet. Download scripts from the PlayStation Store."
    S.libRefreshSel()
end

local SB_FETCH = "https://scriptblox.com/api/script/fetch"
S.SB_SEARCH = "https://scriptblox.com/api/script/search"

S.GENRES = {
    { name = "All", keyword = "" },
    { name = "Universal", keyword = "", universal = true },
    { name = "Admin", keyword = "admin" },
    { name = "Combat", keyword = "aimbot" },
    { name = "ESP", keyword = "esp" },
    { name = "Auto Farm", keyword = "auto farm" },
    { name = "Troll", keyword = "troll" },
    { name = "Hub", keyword = "hub" },
    { name = "Fly", keyword = "fly" },
}

S.KEY_STATES = { "any", "keyless", "key" }
S.KEY_LABELS = { any = "Key: Any", keyless = "Keyless", key = "Key Required" }

local sbMode = "recent"
local sbKey = "any"
local sbVerified = false
local sbGenre = 1
local sbQuery = ""
local sbPage = 1
local sbToken = 0
S.storeLoaded = false
local storeCardRefs = {}

local sbScroll = make("ScrollingFrame", {
    Size = UDim2.fromOffset(520, 328),
    Position = UDim2.fromOffset(179, 67),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = COLORS.muted,
    CanvasSize = UDim2.new(),
}, storePage)

local statusLabel = label(storePage, "", UDim2.fromOffset(300, 30), UDim2.fromOffset(290, 220), 14, COLORS.muted)
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Visible = false

label(storePage, "Powered by ScriptBlox.com", UDim2.fromOffset(190, 20), UDim2.fromOffset(180, H - 38), 10, COLORS.muted)

S.pageLabel = label(storePage, "Page 1", UDim2.fromOffset(60, 24), UDim2.fromOffset(W - 170, H - 42), 11, COLORS.white)
S.pageLabel.TextXAlignment = Enum.TextXAlignment.Center

function S.buildUrl()
    local q = sbQuery ~= "" and sbQuery or S.GENRES[sbGenre].keyword
    local params = "max=20&page=" .. sbPage .. "&mode=free"
    if sbMode == "most-viewed" then params ..= "&sortBy=views&order=desc"
    elseif sbMode == "most-liked" then params ..= "&sortBy=likeCount&order=desc" end
    if sbVerified then params ..= "&verified=1" end
    if q ~= "" then
        return S.SB_SEARCH .. "?q=" .. HttpService:UrlEncode(q) .. "&" .. params
    end
    return SB_FETCH .. "?" .. params
end

function S.passes(s)
    if sbKey == "keyless" and s.key == true then return false end
    if sbKey == "key" and s.key ~= true then return false end
    if sbVerified and s.verified ~= true then return false end
    if S.GENRES[sbGenre].universal then
        local gname = (type(s.game) == "table" and s.game.name) and tostring(s.game.name):lower() or "universal"
        if not (s.isUniversal == true or gname:find("universal")) then return false end
    end
    return true
end

S.storeSlots = {
    { 0, 0, 405, 217 }, { 413, 0, 104, 104 }, { 413, 113, 104, 104 },
    { 0, 226, 104, 102 }, { 113, 226, 104, 102 }, { 225, 226, 290, 102 },
}
function S.storeSlot(index)
    local sl = S.storeSlots[index]
    if sl then return sl[1], sl[2], sl[3], sl[4] end
    local k = index - #S.storeSlots - 1
    return (k % 4) * 131, 336 + math.floor(k / 4) * 131, 123, 123
end

function S.clearStoreCards()
    storeCardRefs = {}
    sbScroll.CanvasPosition = Vector2.new(0, 0)
    for _, c in ipairs(sbScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
end

local function setStatus(text)
    statusLabel.Text = text or ""
    statusLabel.Visible = text ~= nil and text ~= ""
end

local function fetchStore()
    sbToken += 1
    local token = sbToken
    S.clearStoreCards()
    setStatus("Loading ScriptBlox...")
    S.pageLabel.Text = "Page " .. sbPage

    task.spawn(function()
        local url = S.buildUrl()

        local ok, res = pcall(function() return httpGet(url) end)
        if token ~= sbToken then return end

        if not ok and url:find("/search") then
            url = (url:gsub("/search", "/fetch"))
            ok, res = pcall(function() return httpGet(url) end)
            if token ~= sbToken then return end
        end

        if not ok or not res or res == "" then
            local why = shortText(tostring(res), 70)
            setStatus("ScriptBlox unreachable: " .. why)
            S.showError("net", why)
            return
        end

        local decOk, data = pcall(function() return HttpService:JSONDecode(res) end)
        if token ~= sbToken then return end
        if not decOk or type(data) ~= "table" then
            setStatus("Could not read ScriptBlox answer")
            return
        end

        local all = (data.result and data.result.scripts) or {}
        local list = {}
        for _, s in ipairs(all) do
            if S.passes(s) then table.insert(list, s) end
        end
        if sbMode == "most-viewed" then
            table.sort(list, function(a, b) return (a.views or 0) > (b.views or 0) end)
        elseif sbMode == "most-liked" then
            table.sort(list, function(a, b) return (a.likeCount or 0) > (b.likeCount or 0) end)
        end

        if #list == 0 then
            setStatus("No scripts found")
            return
        end
        setStatus(nil)

        -- scripts that have a picture go first (they fill the big spots)
        local withImg, noImg = {}, {}
        for _, sc in ipairs(list) do
            local hasPic = S.pickImage(sc) or (type(sc.game) == "table" and sc.game.gameId)
            table.insert(hasPic and withImg or noImg, sc)
        end
        list = {}
        for _, sc in ipairs(withImg) do table.insert(list, sc) end
        for _, sc in ipairs(noImg) do table.insert(list, sc) end

        local bottom = 0
        for index, s in ipairs(list) do
            local title = tostring(s.title or "Untitled")
            local gameName = "Universal"
            if type(s.game) == "table" and s.game.name then gameName = tostring(s.game.name) end
            local code = tostring(s.script or s.rawScript or "")
            local views = tonumber(s.views) or 0
            local verified = s.verified == true
            local needsKey = s.key == true
            local sid = tostring(s._id or s.slug or ("t_" .. title))
            local imgPath = S.pickImage(s)
            local gameId = type(s.game) == "table" and s.game.gameId or nil
            local dlData = { title = title, game = gameName, code = code, key = needsKey, views = views, img = imgPath, gameId = gameId, slug = s.slug }

            local cx, cy, cw, ch = S.storeSlot(index)
            bottom = math.max(bottom, cy + ch)
            local big = cw >= 200
            local card = make("Frame", {
                Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(cw, ch),
                BackgroundTransparency = 1, BorderSizePixel = 0,
            }, sbScroll)

            local coverColor = verified and Color3.fromRGB(20, 100, 60) or Color3.fromRGB(30, 60, 110)
            local cover = makeCover(card, "TextButton", coverColor, "")
            local cr = cover:FindFirstChildOfClass("UICorner")
            if cr then cr.CornerRadius = UDim.new(0, 0) end
            cover.Size = UDim2.fromScale(1, 1)
            cover.Position = UDim2.fromOffset(0, 0)
            attachImage(cover, imgPath, gameId)
            cover.Activated:Connect(function()
                playSound("Select")
                openPanel(shortText(title, 22), {
                    { isDownloaded(sid) and "In Library" or "Download", function() downloadScript(sid, dlData) end },
                    { "Copy Script", function() copyText(code, "Script") end },
                    { "Information", function()
                        showInfo(shortText(title, 40), string.format(
                            "Game: %s\nViews: %s\nKey: %s\nVerified: %s\n\nCode preview:\n%s",
                            gameName, tostring(views), needsKey and "Key required" or "Keyless",
                            verified and "yes" or "no", code:sub(1, 220)))
                    end },
                    { "Cancel" },
                })
            end)

            local shade = make("Frame", {
                AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
                Size = UDim2.new(1, 0, 0, big and 80 or 58),
                BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3,
            }, card)
            make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1) }, shade)

            local tl = label(card, title, UDim2.new(1, -14, 0, big and 24 or 26),
                UDim2.new(0, 7, 1, big and -48 or -42), big and 16 or 10, COLORS.white, true)
            tl.ZIndex = 4
            tl.TextWrapped = not big
            tl.TextTruncate = Enum.TextTruncate.AtEnd
            tl.TextYAlignment = Enum.TextYAlignment.Bottom
            local gl = label(card, gameName .. (big and ("  |  " .. views .. " views") or ""),
                UDim2.new(1, -14, 0, 14), UDim2.new(0, 7, 1, big and -22 or -16), big and 11 or 8, COLORS.muted)
            gl.ZIndex = 4
            gl.TextWrapped = false
            gl.TextTruncate = Enum.TextTruncate.AtEnd

            -- padlock: closed = needs a key, open = keyless
            local lockBox = make("Frame", {
                Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -28, 0, 6),
                BackgroundColor3 = needsKey and Color3.fromRGB(214, 128, 24) or Color3.fromRGB(34, 158, 92),
                BorderSizePixel = 0, ZIndex = 5,
            }, card)
            S.icon(needsKey and "lock" or "unlock", lockBox, 16, COLORS.white, UDim2.fromOffset(3, 3))

            local has = isDownloaded(sid)
            local dl = button(card, has and "In Library" or "Download", UDim2.fromOffset(big and 80 or 62, 20),
                UDim2.fromOffset(6, 6), has and COLORS.grey or COLORS.blue, 10)
            dl.ZIndex = 5
            storeCardRefs[sid] = dl
            refreshStoreButtons()
            dl.Activated:Connect(function()
                playSound("Select")
                if isDownloaded(sid) then notify("Already in library") return end
                downloadScript(sid, dlData)
            end)
        end
        sbScroll.CanvasSize = UDim2.fromOffset(0, bottom + 8)
    end)
end

refreshStoreButtons = function()
    for sid, btn in pairs(storeCardRefs) do
        if btn.Parent then
            local st = dlState[sid]
            if library[sid] then
                btn.Text = "In Library"
                btn.BackgroundColor3 = COLORS.grey
            elseif st then
                btn.Text = st.status == "Waiting" and "Queued" or (st.paused and "Paused" or (math.floor(st.progress * 100) .. "%"))
                btn.BackgroundColor3 = Color3.fromRGB(30, 110, 170)
            else
                btn.Text = "Download"
                btn.BackgroundColor3 = COLORS.blue
            end
        end
    end
end

openStore = function()
    showPage("Store")
    if not S.storeLoaded then
        S.storeLoaded = true
        fetchStore()
    end
end

local function styleTab(btn, active)
    btn.BackgroundColor3 = active and Color3.fromRGB(52, 128, 232) or Color3.fromRGB(26, 82, 176)
    btn.BackgroundTransparency = 0
end

-- left menu button of the PS Store (text on the left, ">" on the right)
function S.psMenuBtn(b, slot)
    b.Position = UDim2.fromOffset(65, 179 + (slot - 1) * 37)
    b.Size = UDim2.fromOffset(108, 29)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextSize = 11
    b.Font = Enum.Font.Gotham
    make("UIPadding", { PaddingLeft = UDim.new(0, 9) }, b)
    local cr = b:FindFirstChildOfClass("UICorner")
    if cr then cr.CornerRadius = UDim.new(0, 0) end
    local chev = label(b, ">", UDim2.fromOffset(16, 29), UDim2.new(1, -24, 0, 0), 11, COLORS.white)
    chev.TextXAlignment = Enum.TextXAlignment.Center
    return b
end

local function makeSmallButton(text, x, w)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(w, 28),
        Position = UDim2.fromOffset(x, 78),
        BackgroundColor3 = COLORS.card,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = COLORS.white,
        AutoButtonColor = false,
    }, storePage)
    round(b, 6)
    return b
end

S.tabDefs = {
    { id = "recent", label = "New" },
    { id = "most-viewed", label = "Trending" },
    { id = "most-liked", label = "Popular" },
}
S.tabButtons = {}
for i, tab in ipairs(S.tabDefs) do
    local b = S.psMenuBtn(makeSmallButton(tab.label, 0, 100), i)
    styleTab(b, i == 1)
    S.tabButtons[tab.id] = b
    b.Activated:Connect(function()
        playSound("Select")
        sbMode = tab.id
        sbPage = 1
        for tid, btn in pairs(S.tabButtons) do styleTab(btn, tid == sbMode) end
        fetchStore()
    end)
end

local keyBtn = S.psMenuBtn(makeSmallButton(S.KEY_LABELS[sbKey], 0, 100), 4)
keyBtn.Activated:Connect(function()
    playSound("Select")
    local idx = table.find(S.KEY_STATES, sbKey) or 1
    sbKey = S.KEY_STATES[idx % #S.KEY_STATES + 1]
    keyBtn.Text = S.KEY_LABELS[sbKey]
    styleTab(keyBtn, sbKey ~= "any")
    sbPage = 1
    fetchStore()
end)

local verBtn = S.psMenuBtn(makeSmallButton("Verified: Off", 0, 100), 5)
verBtn.Activated:Connect(function()
    playSound("Select")
    sbVerified = not sbVerified
    verBtn.Text = sbVerified and "Verified: On" or "Verified: Off"
    styleTab(verBtn, sbVerified)
    sbPage = 1
    fetchStore()
end)

local searchBox = make("TextBox", {
    Size = UDim2.fromOffset(110, 28),
    Position = UDim2.fromOffset(236, 20),
    BackgroundColor3 = COLORS.card,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Search",
    PlaceholderColor3 = COLORS.muted,
    TextColor3 = COLORS.white,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
    TextEditable = false,
    Active = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, storePage)
S.icon("search", storePage, 18, COLORS.white, UDim2.fromOffset(212, 25))
-- PS4-style search bar: outlined, opens the on-screen keyboard when clicked
do
    local bar = make("Frame", {
        Size = UDim2.fromOffset(142, 28), Position = UDim2.fromOffset(206, 20),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, storePage)
    stroke(bar, COLORS.white, 1.5, 0.2)
    S.searchHit = make("TextButton", {
        Size = UDim2.fromOffset(142, 28), Position = UDim2.fromOffset(206, 20),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 22,
    }, storePage)
    S.searchHit.MouseEnter:Connect(function() bar.BackgroundTransparency = 0.88; bar.BackgroundColor3 = COLORS.white end)
    S.searchHit.MouseLeave:Connect(function() bar.BackgroundTransparency = 1 end)
    S.searchHit.Activated:Connect(function()
        playSound("Select")
        S.openKeyboard("Search the PlayStation Store", searchBox.Text, {
            hint = "Press Done to search the PlayStation Store.",
            onDone = function(text)
                searchBox.Text = text
                sbQuery = text
                sbPage = 1
                unlockTrophy("searcher")
                fetchStore()
            end,
        })
    end)
end

-- "Cart" = your download queue
S.cartBtn = make("TextButton", {
    Size = UDim2.fromOffset(70, 28), Position = UDim2.fromOffset(350, 20),
    BackgroundTransparency = 1, Text = "", ZIndex = 21,
}, storePage)
S.icon("download", S.cartBtn, 18, COLORS.white, UDim2.fromOffset(0, 5))
label(S.cartBtn, "Cart", UDim2.fromOffset(44, 28), UDim2.fromOffset(26, 0), 14, COLORS.white)
S.cartBtn.Activated:Connect(function()
    playSound("Select")
    refreshNotifications()
    showPage("Notifications")
end)

searchBox.FocusLost:Connect(function(enter)
    if enter then
        sbQuery = searchBox.Text
        sbPage = 1
        unlockTrophy("searcher")
        fetchStore()
    end
end)

S.chipRow = make("ScrollingFrame", {
    Size = UDim2.fromOffset(94, 300),
    Position = UDim2.fromOffset(702, 98),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, storePage)
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, S.chipRow)

S.chips = {}
for i, g in ipairs(S.GENRES) do
    local chip = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = i == 1 and Color3.fromRGB(52, 128, 232) or Color3.fromRGB(26, 82, 176),
        BackgroundTransparency = 0,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        Text = g.name,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = COLORS.white,
        AutoButtonColor = false,
        LayoutOrder = i,
    }, S.chipRow)
    make("UIPadding", { PaddingLeft = UDim.new(0, 9) }, chip)
    S.chips[i] = chip
    chip.Activated:Connect(function()
        playSound("Select")
        sbGenre = i
        unlockTrophy("explorer")
        sbQuery = ""
        searchBox.Text = ""
        sbPage = 1
        for j, c in ipairs(S.chips) do styleTab(c, j == sbGenre) end
        fetchStore()
    end)
end

-- PS Store look: header, big "PlayStation Store" tile on the left, "Quick Menu" on the right
do
    local t = pages.Store.title
    t.Text = "PlayStation\194\174Store"
    t.TextSize = 16
    t.Position = UDim2.fromOffset(62, 20)
    t.Size = UDim2.fromOffset(150, 28)
    S.icon("store", storePage, 20, COLORS.white, UDim2.fromOffset(38, 24))
    for _, c in ipairs(storePage:GetChildren()) do
        if c:IsA("Frame") and c.Size.Y.Offset == 1 then c.Visible = false end
    end
    local spot = label(storePage, "PS Store Spotlight", UDim2.fromOffset(190, 28), UDim2.fromOffset(520, 20), 14, COLORS.muted)
    spot.TextXAlignment = Enum.TextXAlignment.Right
    local qm = label(storePage, "Quick Menu", UDim2.fromOffset(94, 22), UDim2.fromOffset(702, 70), 12, COLORS.white)
    qm.TextWrapped = false
    local tile = make("TextButton", {
        Size = UDim2.fromOffset(108, 108), Position = UDim2.fromOffset(65, 67),
        BackgroundColor3 = Color3.fromRGB(6, 26, 74), BackgroundTransparency = 0.1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 21,
    }, storePage)
    stroke(tile, COLORS.white, 2, 0)
    local tt = label(tile, "PlayStation\194\174\nStore", UDim2.new(1, -14, 0, 56), UDim2.new(0, 8, 1, -64), 16, COLORS.white, true)
    tt.TextYAlignment = Enum.TextYAlignment.Bottom
    tt.ZIndex = 22
    tile.Activated:Connect(function()
        playSound("Select")
        sbPage = 1
        fetchStore()
    end)
end

function S.openGenre(i)
    sbGenre = i
    sbQuery = ""
    searchBox.Text = ""
    sbPage = 1
    for j, c in ipairs(S.chips) do styleTab(c, j == sbGenre) end
    S.storeLoaded = true
    showPage("Store")
    fetchStore()
end

S.prevBtn = button(storePage, "‹ Prev", UDim2.fromOffset(56, 24), UDim2.fromOffset(W - 232, H - 42), COLORS.card, 11)
S.nextBtn = button(storePage, "Next ›", UDim2.fromOffset(56, 24), UDim2.fromOffset(W - 104, H - 42), COLORS.card, 11)
S.prevBtn.Activated:Connect(function()
    if sbPage > 1 then sbPage -= 1; fetchStore() else notify("First page") end
end)
S.nextBtn.Activated:Connect(function()
    sbPage += 1
    fetchStore()
end)

function S.resolveScriptCode(data)
    local code = tostring(data.code or "")
    if #code > 600 or not code:find("scriptblox%.com/raw/") then return code end
    local slug = data.slug or code:match("scriptblox%.com/raw/([^\"'%)]+)")
    if not slug then return nil, "could not find the script link" end
    local enc = HttpService:UrlEncode(slug)
    local urls = {
        SB_ROOT .. "/raw/" .. slug,
        SB_ROOT .. "/raw/" .. enc,
        SB_ROOT .. "/api/script/raw/" .. enc,
    }
    local lastErr = "script not found (404)"
    for _, u in ipairs(urls) do
        local ok, res = pcall(function() return httpGet(u) end)
        if ok and type(res) == "string" and #res > 0 then
            local first = res:sub(1, 1)
            if first == "{" then
                local dec, d = pcall(function() return HttpService:JSONDecode(res) end)
                if dec and type(d) == "table" then
                    if type(d.script) == "string" and d.script ~= "" then return d.script end
                    if d.message then lastErr = tostring(d.message) end
                end
            elseif first ~= "<" then
                return res
            end
        elseif not ok then
            lastErr = shortText(tostring(res), 60)
        end
    end
    return nil, lastErr
end

local function removeFromQueue(id)
    for i, q in ipairs(dlQueue) do
        if q == id then table.remove(dlQueue, i) break end
    end
end

local dlRunning = false

updateProgressViews = function(id)
    local st = dlState[id]
    if not st then return end
    local pct = math.floor(st.progress * 100)
    local tp = tileProgress[id]
    if tp and tp.fill.Parent then
        tp.fill.Size = UDim2.fromScale(st.progress, 1)
        tp.pct.Text = st.status == "Waiting" and "Queued" or (st.paused and "Paused" or (pct .. "%"))
    end
    local nr = notifDlRefs[id]
    if nr and nr.fill.Parent then
        nr.fill.Size = UDim2.fromScale(st.progress, 1)
        nr.status.Text = dlStatusText(id)
    end
    local item = items[focusIndex]
    if item and item.kind == "download" and item.id == id then
        liveCards[1].body.Text = dlStatusText(id)
    end
    refreshStoreButtons()
end

function S.runDownloads()
    if dlRunning then return end
    dlRunning = true
    task.spawn(function()
        while gui.Parent do
            local id = dlQueue[1]
            if not id then break end
            local st = dlState[id]
            if not st then
                table.remove(dlQueue, 1)
            else
                st.status = "Downloading"
                st.fetchDone = false
                task.spawn(function()
                    local fetched, err = S.resolveScriptCode(st.data)
                    st.resolved = fetched
                    st.err = err
                    st.size = #tostring(fetched or "")
                    st.fetchDone = true
                end)
                local duration = 4
                while dlState[id] == st and st.progress < 1 do
                    if st.fetchDone and st.err then break end
                    local dt = task.wait(0.1)
                    if not st.paused then
                        local cap = st.fetchDone and 1 or 0.92
                        local speed = st.fetchDone and 3 or 1
                        st.progress = math.min(cap, st.progress + dt / duration * speed * (0.6 + math.random() * 0.8))
                    end
                    updateProgressViews(id)
                end
                if dlState[id] == st and st.err then
                    S.showError("dl", st.err)
                    dlState[id] = nil
                    removeFromQueue(id)
                    refreshLocal()
                elseif dlState[id] == st then
                    st.status = "Installing"
                    updateProgressViews(id)
                    task.wait(1)
                    if dlState[id] == st then
                        library[id] = {
                            title = st.data.title,
                            game = st.data.game,
                            code = st.resolved or st.data.code,
                            slug = st.data.slug,
                            key = st.data.key,
                            views = st.data.views,
                            img = st.data.img,
                            gameId = st.data.gameId,
                            downloadedAt = os.time(),
                        }
                        saveLibrary()
                        dlState[id] = nil
                        removeFromQueue(id)
                        notify("Download complete: " .. st.data.title)
                        refreshLocal()
                        task.delay(2.5, function() unlockTrophy("first_dl") end)
                        if not st.data.key then task.delay(6, function() unlockTrophy("keyless") end) end
                        if libraryCount() >= MAX_STORAGE then task.delay(9.5, function() unlockTrophy("full") end) end
                    end
                end
            end
        end
        dlRunning = false
    end)
end

downloadScript = function(id, data)
    id = tostring(id)
    if library[id] then notify("Already in library") return false end
    if dlState[id] then notify("Already in the download queue") return false end
    if libraryCount() + #dlQueue >= MAX_STORAGE then
        notify("Library full (" .. MAX_STORAGE .. " slots) - delete one first")
        return false
    end
    dlState[id] = { data = data, progress = 0, status = "Waiting", paused = false }
    table.insert(dlQueue, id)
    if data.img then loadImage(data.img, function() end) end
    notify("Added to download queue: " .. data.title)
    refreshLocal()
    S.runDownloads()
    return true
end

openDownloadOptions = function(id)
    local st = dlState[id]
    if not st then return end
    openPanel(shortText(st.data.title, 22), {
        { st.paused and "Resume" or "Pause", function()
            st.paused = not st.paused
            updateProgressViews(id)
        end },
        { "Cancel and Delete", function()
            dlState[id] = nil
            removeFromQueue(id)
            notify("Download cancelled")
            refreshLocal()
        end },
        { "Cancel" },
    })
end

local THEMES = {
    { name = "Blue Wave", a = Color3.fromRGB(10, 76, 178), b = Color3.fromRGB(6, 62, 160), c = Color3.fromRGB(3, 40, 118), wave = Color3.fromRGB(80, 150, 235) },
    { name = "Midnight", a = Color3.fromRGB(3, 6, 18), b = Color3.fromRGB(18, 28, 70), c = Color3.fromRGB(2, 8, 26), wave = Color3.fromRGB(70, 110, 190) },
    { name = "Crimson", a = Color3.fromRGB(40, 6, 12), b = Color3.fromRGB(120, 24, 40), c = Color3.fromRGB(30, 4, 12), wave = Color3.fromRGB(230, 100, 120) },
    { name = "Forest", a = Color3.fromRGB(4, 28, 20), b = Color3.fromRGB(14, 100, 72), c = Color3.fromRGB(4, 34, 26), wave = Color3.fromRGB(90, 220, 170) },
    { name = "Violet", a = Color3.fromRGB(24, 8, 56), b = Color3.fromRGB(80, 40, 150), c = Color3.fromRGB(18, 6, 46), wave = Color3.fromRGB(170, 130, 240) },
}

function S.applyTheme(idx)
    local t = THEMES[idx] or THEMES[1]
    local seq = ColorSequence.new({
        ColorSequenceKeypoint.new(0, t.a),
        ColorSequenceKeypoint.new(0.55, t.b),
        ColorSequenceKeypoint.new(1, t.c),
    })
    S.bgGradient.Color = seq
    for _, g in ipairs(pageGradients) do g.Color = seq end
    for _, w in ipairs(waves) do w.BackgroundColor3 = t.wave end
end

S.checkForUpdate = function(id)
    local e = library[id]
    if not e then return end
    notify("Checking for update...")
    task.spawn(function()
        local found
        -- 1) ask ScriptBlox for this exact script by its slug
        if e.slug and e.slug ~= "" then
            local ok, res = pcall(httpGet, SB_ROOT .. "/api/script/" .. HttpService:UrlEncode(tostring(e.slug)))
            if ok then
                local dec, data = pcall(function() return HttpService:JSONDecode(res) end)
                if dec and type(data) == "table" then
                    if type(data.script) == "table" then
                        found = data.script
                    elseif type(data.result) == "table" and type(data.result.script) == "table" then
                        found = data.result.script
                    end
                end
            end
        end
        -- 2) fall back to searching by title
        if not found then
            local q = HttpService:UrlEncode(tostring(e.title))
            for _, base in ipairs({ S.SB_SEARCH, SB_FETCH }) do
                local ok, res = pcall(function() return httpGet(base .. "?q=" .. q .. "&max=20") end)
                if ok then
                    local dec, data = pcall(function() return HttpService:JSONDecode(res) end)
                    if dec and type(data) == "table" then
                        for _, sc in ipairs((data.result and data.result.scripts) or {}) do
                            if tostring(sc._id or sc.slug or "") == id then found = sc break end
                        end
                        if found then break end
                    end
                end
            end
        end
        if not library[id] then return end
        if not found then notify("No update information found") return end
        local newCode, err = S.resolveScriptCode({
            code = tostring(found.script or found.rawScript or ""),
            slug = found.slug or e.slug,
        })
        if not newCode or newCode == "" then
            notify("Update check failed: " .. shortText(tostring(err or "empty script"), 50))
            return
        end
        if newCode ~= e.code then
            e.code = newCode
            saveLibrary()
            notify("Updated: " .. tostring(e.title))
        else
            notify("No update available")
        end
    end)
end

function S.showNetwork()
    local ping = "n/a"
    pcall(function()
        ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms"
    end)
    local function build(status)
        local lines = {}
        for i = 1, math.min(#httpLog, 6) do
            local r = httpLog[i]
            table.insert(lines, shortText((r.url:gsub("https://", "")), 46) .. "  ->  " .. (r.ok and "OK" or shortText(r.err or "failed", 22)))
        end
        if #lines == 0 then table.insert(lines, "no requests yet") end
        return "Ping: " .. ping .. "\nPlayers in server: " .. #Players:GetPlayers() .. "\nScriptBlox: " .. status
            .. "\n\nLast web requests:\n" .. table.concat(lines, "\n")
    end
    showInfo("Network", build("checking..."))
    task.spawn(function()
        local ok = pcall(function() return httpGet(SB_FETCH .. "?max=1") end)
        if pages.Info.title.Text == "Network" then
            infoBody.Text = build(ok and "reachable" or "unreachable")
        end
    end)
end

function S.showAccount()
    showInfo("Account Management", string.format(
        "Display name: %s\nUsername: @%s\nUser ID: %d\nAccount age: %d days\nMembership: %s",
        player.DisplayName, player.Name, player.UserId, player.AccountAge, player.MembershipType.Name))
end

avatar.Activated:Connect(function()
    playSound("Select")
    S.showAccount()
end)

function S.showSystem()
    local exec, gname, rver = "unknown", "unknown", "unknown"
    pcall(function() if identifyexecutor then exec = tostring((identifyexecutor())) end end)
    pcall(function() gname = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
    pcall(function() rver = version() end)
    showInfo("System", string.format(
        "Executor: %s\nRoblox: %s\nExperience: %s\nPlace ID: %d\nFile API: %s\nScriptBlox images: %s\nLibrary: %d / %d",
        exec, rver, gname, game.PlaceId,
        canWrite() and "yes" or "no",
        (type(assetFn) == "function" and canWrite()) and "supported" or "not supported",
        libraryCount(), MAX_STORAGE))
end

-- ===== PS4 style Settings =====
-- A grid of big icons (like the PS4 settings screen). Opening an icon shows a
-- full page list with check boxes / sliders instead of a side panel.
-- Icons are text glyphs; to use a picture put "rbxassetid://123" as icon.

function S.deleteAll()
    for id in pairs(library) do library[id] = nil end
    saveLibrary()
    notify("Library cleared")
    refreshLocal()
end

function S.restoreDefaults()
    local d = { sound = true, volume = 0.6, toasts = true, theme = 1, images = true, hideOnStart = true, uiscale = 1 }
    for k, v in pairs(d) do settings[k] = v end
    S.applyTheme(1)
    S.updateScale()
    saveSettings()
    notify("Default settings restored")
end


-- ===== Jailbreak (simulated, PS4 style) =====
-- Purely a simulation inside this dashboard: nothing real is exploited.
-- Follows the usual flow: firmware check (max 13.52) -> clear browser cache ->
-- run exploit (may need retries) -> "GoldHEN loaded" -> GoldHEN entry on top of Settings.
-- Tethered like the real one: it is session-only, closing the dashboard = full restart.
S.jb = { active = false, busy = false, cacheClean = false, fails = 0 }
S.FW_LIST = { "9.00", "11.00", "12.02", "13.02", "13.52", "13.53" }
S.JB_MAX_FW = 13.52

function S.jbFw() return settings.fw or "11.00" end

function S.jbCycleFw()
    local cur = 1
    for i, v in ipairs(S.FW_LIST) do if v == S.jbFw() then cur = i end end
    settings.fw = S.FW_LIST[cur % #S.FW_LIST + 1]
    saveSettings()
    if S.jb.active and tonumber(settings.fw) > S.JB_MAX_FW then
        S.jb.active = false
        S.syncGoldHEN()
        notify("Firmware updated - jailbreak lost")
    end
    S.renderSettingsList(true)
end

function S.startJailbreak()
    if S.jb.active then notify("Already jailbroken (GoldHEN is loaded)") return end
    if S.jb.busy then return end
    if tonumber(S.jbFw()) > S.JB_MAX_FW then
        showInfo("Jailbreak not possible",
            "System software " .. S.jbFw() .. " is newer than 13.52.\nA jailbreak is not possible on this firmware.")
        return
    end
    S.jb.busy = true
    task.spawn(function()
        notify("Opening browser...")
        task.wait(1.2)
        notify("Loading exploit page... 50%")
        task.wait(1.2)
        notify("Offline cache installed (100%)")
        task.wait(1.2)
        -- a dirty browser cache makes the exploit fail with the memory error (retry like on a real console)
        local needFails = S.jb.cacheClean and 0 or 2
        if S.jb.fails < needFails then
            S.jb.fails = S.jb.fails + 1
            S.jb.busy = false
            playSound("Notify")
            showInfo("Error", "Not enough free system memory.\nPress OK and run the exploit again.")
            return
        end
        notify("Sending GoldHEN payload...")
        task.wait(1.5)
        S.jb.active, S.jb.busy, S.jb.fails = true, false, 0
        playSound("Notify")
        notify("GoldHEN loaded")
        S.settingIndex = 1
        S.syncGoldHEN()
        if currentPage == "SettingsList" then S.renderSettingsList(true) end
    end)
end


function S.dnsText()
    if settings.dns == nil or settings.dns == "auto" then return "Automatic" end
    return tostring(settings.dns)
end

-- like the real test: with the update-blocking DNS the PlayStation Network step fails (that is normal)
function S.testConnection()
    notify("Testing connection...")
    task.spawn(function()
        task.wait(1.4)
        if settings.dns == "62.210.38.117" then
            notify("Internet: OK  -  PlayStation Network: failed (updates blocked)")
        else
            notify("Internet: OK  -  PlayStation Network: OK")
        end
    end)
end

S.JAILBREAK_DEF = { id = "Jailbreak", icon = "✧", build = function()
    return {
        { type = "info", text = "System Software", value = S.jbFw() },
        { type = "info", text = "Jailbreak Status", value = S.jb.active and "Active (GoldHEN)" or "Not active" },
        { type = "info", text = "DNS Server", value = S.dnsText() },
        { type = "action", text = "Change Firmware (simulated)", onclick = function() S.jbCycleFw() end },
        { type = "toggle", text = "Block System Update Files",
            get = function() return settings.jbNoUpdate == true end,
            set = function(v) settings.jbNoUpdate = v; saveSettings() end },
        { type = "action", text = "Clear Browser Cache", onclick = function() S.brClearData() end },
        { type = "action", text = "Open Internet Browser", onclick = function() S.openBrowser() end },
        { type = "info", text = "Exploit page", value = "raw13g.github.io" },
        { type = "info", text = "Note", value = "Resets when the dashboard closes" },
    }
end }

S.GOLDHEN_DEF = { id = "GoldHEN", icon = "G", build = function()
    return {
        { type = "info", text = "Status", value = "Loaded" },
        { type = "action", text = "Install Package (.pkg) from USB", onclick = function()
            showInfo("Install Package", "Insert a FAT32 or exFAT USB drive that contains .pkg files.\n\nNo USB storage device found.")
        end },
        { type = "action", text = "About GoldHEN", onclick = function()
            showInfo("GoldHEN", "GoldHEN is active for this session.\nKeep the dashboard on Hide (Rest Mode) to keep it active.")
        end },
    }
end }

function S.syncGoldHEN()
    local has = S.SETTINGS[1] == S.GOLDHEN_DEF
    if S.jb.active and not has then
        table.insert(S.SETTINGS, 1, S.GOLDHEN_DEF)
    elseif not S.jb.active and has then
        table.remove(S.SETTINGS, 1)
    end
    S.buildSettingsGrid()
end

S.slScroll = makeListScroll(S.slPage)
S.slRows, S.slIndex = {}, 1
S.currentSetting = nil

function S.rowInteractive(r)
    return r.type ~= "info" and r.type ~= "bar"
end

function S.stepSlider(r, dir)
    local v = r.get() + dir * r.step
    v = math.clamp(math.floor(v / r.step + 0.5) * r.step, r.min, r.max)
    r.set(math.floor(v * 100 + 0.5) / 100)
end

function S.cycleChoice(r, dir)
    local cur, idx = r.get(), 1
    for i, v in ipairs(r.values) do
        if v == cur then
            idx = i
            break
        end
    end
    idx = (idx - 1 + dir) % #r.values + 1
    r.set(r.values[idx])
end

function S.buildRowWidget(row, r)
    local t = r.type
    if t == "toggle" then
        local on = r.get() == true
        local box = make("Frame", {
            Size = UDim2.fromOffset(24, 24),
            Position = UDim2.new(1, -46, 0.5, -12),
            BackgroundColor3 = COLORS.dark,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
        }, row)
        round(box, 4)
        stroke(box, COLORS.white, 2, on and 0 or 0.45)
        if on then
            local mark = make("Frame", {
                Size = UDim2.fromOffset(12, 12),
                Position = UDim2.fromOffset(6, 6),
                BackgroundColor3 = COLORS.white,
                BorderSizePixel = 0,
            }, box)
            round(mark, 2)
        end
    elseif t == "choice" then
        local v = label(row, "‹   " .. r.fmt(r.get()) .. "   ›", UDim2.fromOffset(190, 50), UDim2.new(1, -208, 0, 0), 14, COLORS.white)
        v.TextXAlignment = Enum.TextXAlignment.Right
        v.TextWrapped = false
    elseif t == "slider" then
        local val = r.get()
        local frac = math.clamp((val - r.min) / (r.max - r.min), 0, 1)
        local function mini(txt, x, dir)
            local b = button(row, txt, UDim2.fromOffset(28, 28), UDim2.new(1, x, 0.5, -14), COLORS.card, 16)
            b.Activated:Connect(function()
                playSound("Select")
                S.stepSlider(r, dir)
                S.renderSettingsList(true)
            end)
        end
        mini("-", -346, -1)
        mini("+", -150, 1)
        local track = make("Frame", {
            Size = UDim2.fromOffset(150, 6),
            Position = UDim2.new(1, -310, 0.5, -3),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 0.8,
            BorderSizePixel = 0,
        }, row)
        round(track, 3)
        local fill = make("Frame", {
            Size = UDim2.fromScale(frac, 1),
            BackgroundColor3 = COLORS.white,
            BorderSizePixel = 0,
        }, track)
        round(fill, 3)
        local pct = label(row, r.fmt(val), UDim2.fromOffset(94, 50), UDim2.new(1, -112, 0, 0), 13, COLORS.white)
        pct.TextXAlignment = Enum.TextXAlignment.Right
    elseif t == "radio" then
        local picked = r.selected and r.selected() or false
        local sw = make("Frame", {
            Size = UDim2.fromOffset(96, 28),
            Position = UDim2.new(1, -114, 0.5, -14),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, row)
        round(sw, 6)
        make("UIGradient", { Rotation = 0, Color = r.swatch() }, sw)
        stroke(sw, COLORS.white, 2, picked and 0 or 0.8)
    elseif t == "action" then
        local ch = label(row, "›", UDim2.fromOffset(30, 50), UDim2.new(1, -44, 0, 0), 22, COLORS.muted)
        ch.TextXAlignment = Enum.TextXAlignment.Center
    elseif t == "info" then
        local v = label(row, tostring(r.value or ""), UDim2.new(0.5, -18, 1, 0), UDim2.new(0.5, 0, 0, 0), 14, COLORS.muted)
        v.TextXAlignment = Enum.TextXAlignment.Right
        v.TextWrapped = false
        v.TextTruncate = Enum.TextTruncate.AtEnd
    elseif t == "bar" then
        local total = math.max(r.total or 1, 1)
        local used = r.used or 0
        local txt = label(row, used .. " / " .. total .. " slots used", UDim2.fromOffset(260, 36), UDim2.new(1, -278, 0, 0), 13, COLORS.muted)
        txt.TextXAlignment = Enum.TextXAlignment.Right
        local track = make("Frame", {
            Size = UDim2.new(1, -36, 0, 8),
            Position = UDim2.fromOffset(18, 46),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 0.8,
            BorderSizePixel = 0,
        }, row)
        round(track, 4)
        local fill = make("Frame", {
            Size = UDim2.fromScale(math.clamp(used / total, 0, 1), 1),
            BackgroundColor3 = Color3.fromRGB(0, 170, 255),
            BorderSizePixel = 0,
        }, track)
        round(fill, 4)
    end
end

function S.focusSettingsRow(i)
    S.slIndex = i
    for idx, rr in ipairs(S.slRows) do
        local on = idx == i and S.rowInteractive(rr.data)
        rr.row.BackgroundTransparency = on and 0.95 or 1
        rr.ring.Transparency = on and 0 or 1
    end
end

function S.moveSettingsFocus(step)
    local n = #S.slRows
    local i = S.slIndex
    for _ = 1, n do
        i = i + step
        if i < 1 or i > n then return end
        if S.rowInteractive(S.slRows[i].data) then
            S.focusSettingsRow(i)
            playSound("Select")
            return
        end
    end
end

function S.activateSettingsRow(i)
    local rr = S.slRows[i]
    if not rr then return end
    local r = rr.data
    local t = r.type
    if t == "toggle" then
        r.set(not r.get())
        S.renderSettingsList(true)
    elseif t == "choice" then
        S.cycleChoice(r, 1)
        S.renderSettingsList(true)
    elseif t == "action" or t == "radio" then
        S.run(r.onclick)
        if currentPage == "SettingsList" then S.renderSettingsList(true) end
    end
end

function S.adjustSettingsRow(i, dir)
    local rr = S.slRows[i]
    if not rr then return end
    local r = rr.data
    if r.type == "slider" then
        S.stepSlider(r, dir)
        S.renderSettingsList(true)
    elseif r.type == "choice" then
        S.cycleChoice(r, dir)
        S.renderSettingsList(true)
    elseif r.type == "toggle" then
        r.set(dir > 0)
        S.renderSettingsList(true)
    end
end

function S.renderSettingsList(keep)
    local def = S.currentSetting
    if not def then return end
    local oldPos = S.slScroll.CanvasPosition
    clearList(S.slScroll)
    S.slRows = {}
    local rows = def.build()
    local firstInteractive = 1
    for i, r in ipairs(rows) do
        if S.rowInteractive(r) then
            firstInteractive = i
            break
        end
    end
    for i, r in ipairs(rows) do
        local isBar = r.type == "bar"
        local row = make("TextButton", {
            Size = UDim2.new(1, -12, 0, isBar and 70 or 50),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = i,
        }, S.slScroll)
        local ring = stroke(row, Color3.fromRGB(70, 175, 255), 2, 1)
        local text = r.text
        if r.type == "radio" and r.selected and r.selected() then text = text .. "   (in use)" end
        local lbl = label(row, text, UDim2.new(0.5, -18, 0, isBar and 36 or 50), UDim2.fromOffset(18, 0), 15, COLORS.white)
        lbl.TextWrapped = false
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        S.buildRowWidget(row, r)
        S.slRows[i] = { row = row, ring = ring, data = r }
        if S.rowInteractive(r) then
            row.MouseEnter:Connect(function() S.focusSettingsRow(i) end)
            row.Activated:Connect(function()
                playSound("Select")
                S.focusSettingsRow(i)
                S.activateSettingsRow(i)
            end)
        end
    end
    if not keep then S.slIndex = firstInteractive end
    S.focusSettingsRow(math.clamp(S.slIndex, 1, math.max(#S.slRows, 1)))
    if keep then S.slScroll.CanvasPosition = oldPos end
end

S.SETTINGS = {
    { id = "Notifications", icon = "♧", build = function()
        return {
            { type = "toggle", text = "Pop-up Notifications",
                get = function() return settings.toasts end,
                set = function(v) settings.toasts = v; saveSettings() end },
            { type = "info", text = "Saved Notifications", value = #notifyLog },
            { type = "action", text = "Clear Notification List", onclick = function()
                notifyLog = {}
                notify("Notification list cleared")
            end },
        }
    end },
    { id = "Sound and Screen", icon = "♪", build = function()
        return {
            { type = "toggle", text = "Sound Effects",
                get = function() return settings.sound end,
                set = function(v) settings.sound = v; saveSettings() end },
            { type = "slider", text = "Volume", min = 0, max = 1, step = 0.1,
                fmt = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
                get = function() return settings.volume end,
                set = function(v) settings.volume = v; saveSettings() end },
            { type = "choice", text = "Dashboard Size", values = { 0.75, 0.9, 1, 1.15, 1.3 },
                fmt = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
                get = function() return settings.uiscale end,
                set = function(v) settings.uiscale = v; S.updateScale(); saveSettings() end },
            { type = "toggle", text = "Hide Dashboard When a Script Starts",
                get = function() return settings.hideOnStart end,
                set = function(v) settings.hideOnStart = v; saveSettings() end },
        }
    end },
    { id = "Themes", icon = "◐", build = function()
        local rows = {}
        for i, t in ipairs(THEMES) do
            table.insert(rows, {
                type = "radio", text = t.name,
                selected = function() return settings.theme == i end,
                swatch = function()
                    return ColorSequence.new({
                        ColorSequenceKeypoint.new(0, t.a),
                        ColorSequenceKeypoint.new(0.55, t.b),
                        ColorSequenceKeypoint.new(1, t.c),
                    })
                end,
                onclick = function()
                    settings.theme = i
                    S.applyTheme(i)
                    saveSettings()
                    notify("Theme: " .. t.name)
                    unlockTrophy("themer")
                end,
            })
        end
        return rows
    end },
    { id = "Storage", icon = "▤", build = function()
        return {
            { type = "bar", text = "Script Storage", used = libraryCount(), total = MAX_STORAGE },
            { type = "info", text = "Downloads in Queue", value = #dlQueue },
            { type = "action", text = "Open Library", onclick = function() showPage("Library") end },
            { type = "action", text = "Delete All Scripts", onclick = function()
                openPanel("Delete everything?", {
                    { "Delete All", function()
                        S.deleteAll()
                        if currentPage == "SettingsList" then S.renderSettingsList(true) end
                    end },
                    { "Cancel" },
                })
            end },
        }
    end },
    { id = "Store Images", icon = "▣", build = function()
        return {
            { type = "toggle", text = "ScriptBlox Images",
                get = function() return settings.images end,
                set = function(v) settings.images = v; saveSettings() end },
            { type = "info", text = "Executor Support",
                value = (type(assetFn) == "function" and canWrite()) and "Supported" or "Not supported" },
        }
    end },
    { id = "Network", icon = "☁", build = function()
        return {
            { type = "action", text = "View Connection Status", onclick = function() S.showNetwork() end },
            { type = "info", text = "DNS Server (simulated)", value = S.dnsText() },
            { type = "action", text = "Set DNS Server (simulated)", onclick = function()
                local function setDns(v) settings.dns = v; saveSettings(); S.renderSettingsList(true) end
                openPanel("DNS Settings", {
                    { "Automatic", function() setDns("auto") end },
                    { "Manual: 62.210.38.117", function() setDns("62.210.38.117") end },
                    { "Manual: 8.8.8.8", function() setDns("8.8.8.8") end },
                    { "Cancel" },
                })
            end },
            { type = "action", text = "Test Internet Connection (simulated)", onclick = function() S.testConnection() end },
            { type = "action", text = "Test ScriptBlox Connection", onclick = function()
                notify("Testing connection...")
                task.spawn(function()
                    local ok, err = pcall(httpGet, SB_FETCH .. "?max=1")
                    notify(ok and "ScriptBlox is reachable" or ("ScriptBlox unreachable: " .. shortText(tostring(err), 50)))
                end)
            end },
        }
    end },
    { id = "Owner", icon = "👑", build = function()
        return {
            { type = "info", text = "Owner User ID", value = "8407673016" },
            { type = "info", text = "Access", value = S.isOwner and "Verified Owner" or "Owner only" },
            { type = "action", text = "Open Owner Panel", onclick = function() S.openOwnerPanel() end },
        }
    end },
    { id = "Account Management", icon = "♙", build = function()
        return {
            { type = "info", text = "Display Name", value = player.DisplayName },
            { type = "info", text = "Username", value = "@" .. player.Name },
            { type = "info", text = "Account Age", value = player.AccountAge .. " days" },
            { type = "info", text = "Membership", value = player.MembershipType.Name },
            { type = "action", text = "View Account Details", onclick = function() S.showAccount() end },
        }
    end },
    { id = "System", icon = "⚙", build = function()
        return {
            { type = "info", text = "Hide / Show Key", value = TOGGLE_KEY.Name },
            { type = "info", text = "File API", value = canWrite() and "Available" or "Not available" },
            { type = "info", text = "Library", value = libraryCount() .. " / " .. MAX_STORAGE },
            { type = "action", text = "View System Information", onclick = function() S.showSystem() end },
        }
    end },
    S.JAILBREAK_DEF,
    { id = "Initialization", icon = "↺", build = function()
        return {
            { type = "action", text = "Restore Default Settings", onclick = function()
                openPanel("Restore defaults?", {
                    { "Restore", function() S.restoreDefaults() end },
                    { "Cancel" },
                })
            end },
            { type = "action", text = "Reset Trophies", onclick = function()
                openPanel("Reset trophies?", {
                    { "Reset", function()
                        earned = {}
                        saveSettings()
                        notify("Trophies reset")
                    end },
                    { "Cancel" },
                })
            end },
        }
    end },
    { id = "Power", icon = "⏻", open = function() S.openPowerPanel() end },
}

function S.openSetting(def)
    if not def then return end
    if def.id == "Owner" and not S.isOwner then notify("Owner access required"); return end
    if def.open then
        S.run(def.open)
        return
    end
    S.currentSetting = def
    pages.SettingsList.title.Text = def.id
    S.renderSettingsList(false)
    showPage("SettingsList")
end

S.settingsGrid = make("ScrollingFrame", {
    Size = UDim2.fromOffset(580, 318),
    Position = UDim2.fromOffset(110, 74),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, S.settingsPage)
make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, S.settingsGrid)

S.settingCells = {}
S.settingIndex = 1
S.SET_ROW, S.SET_PITCH, S.SET_VIEW = 32, 35, 318

function S.focusSetting(i)
    local n = #S.settingCells
    if n == 0 then return end
    i = math.clamp(i, 1, n)
    S.settingIndex = i
    for idx, c in ipairs(S.settingCells) do
        local on = idx == i
        c.ring.Transparency = on and 0 or 1
        c.sep.Visible = not on
    end
    local top = (i - 1) * S.SET_PITCH
    local cp = S.settingsGrid.CanvasPosition.Y
    if top < cp then
        S.settingsGrid.CanvasPosition = Vector2.new(0, top)
    elseif top + S.SET_ROW + 8 > cp + S.SET_VIEW then
        S.settingsGrid.CanvasPosition = Vector2.new(0, top + S.SET_ROW + 8 - S.SET_VIEW)
    end
end

function S.buildSettingsGrid()
for _, c in ipairs(S.settingsGrid:GetChildren()) do
    if c:IsA("TextButton") then c:Destroy() end
end
S.settingCells = {}
for i, def in ipairs(S.SETTINGS) do
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, S.SET_ROW),
        Position = UDim2.fromOffset(0, (i - 1) * S.SET_PITCH),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "",
    }, S.settingsGrid)
    local ring = stroke(btn, Color3.fromRGB(70, 175, 255), 2, 1)
    if type(def.icon) == "string" and def.icon:find("^rbxassetid://") then
        make("ImageLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset(12, 5), Image = def.icon,
        }, btn)
    elseif S.settingIcon[def.id] then
        S.icon(S.settingIcon[def.id], btn, 22, COLORS.white, UDim2.fromOffset(12, 5))
    else
        make("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(12, 5),
            Text = tostring(def.icon), Font = Enum.Font.GothamMedium, TextSize = 18, TextColor3 = COLORS.white,
        }, btn)
    end
    local lbl = label(btn, def.id, UDim2.new(1, -60, 1, 0), UDim2.fromOffset(46, 0), 14, COLORS.white)
    lbl.TextWrapped = false
    local sep = make("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 1),
        BackgroundColor3 = COLORS.white, BackgroundTransparency = 0.8, BorderSizePixel = 0,
    }, btn)
    S.settingCells[i] = { btn = btn, ring = ring, label = lbl, sep = sep }
    btn.MouseEnter:Connect(function() S.focusSetting(i) end)
    btn.Activated:Connect(function()
        playSound("Select")
        S.focusSetting(i)
        S.openSetting(def)
    end)
end
S.focusSetting(math.clamp(S.settingIndex or 1, 1, math.max(#S.settingCells, 1)))
end
S.buildSettingsGrid()

S.pageNav.Settings = function(k)
    local d = S.dirOf(k)
    local i = S.settingIndex
    if d == "up" or d == "left" then S.focusSetting(i - 1)
    elseif d == "down" or d == "right" then S.focusSetting(i + 1)
    elseif d == "ok" then
        playSound("Select")
        S.openSetting(S.SETTINGS[i])
    end
end

S.pageNav.SettingsList = function(k)
    local d = S.dirOf(k)
    if d == "up" then S.moveSettingsFocus(-1)
    elseif d == "down" then S.moveSettingsFocus(1)
    elseif d == "left" then S.adjustSettingsRow(S.slIndex, -1)
    elseif d == "right" then S.adjustSettingsRow(S.slIndex, 1)
    elseif d == "ok" then
        playSound("Select")
        S.activateSettingsRow(S.slIndex)
    end
end

-- swipe through the tiles with your finger (or drag with the mouse)
S.swipe = nil
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if minimized or currentPage or panelOpen or S.loginOpen or not gui.Parent then return end
    local ap, as = main.AbsolutePosition, main.AbsoluteSize
    if as.X <= 0 or as.Y <= 0 then return end
    local rx = (input.Position.X - ap.X) / as.X * W
    local ry = (input.Position.Y - ap.Y) / as.Y * H
    if rx < 0 or rx > W or ry < 70 or ry > H then return end
    S.swipe = { x0 = input.Position.X, startIndex = focusIndex, moved = false, scale = as.X / W }
end)
UserInputService.InputChanged:Connect(function(input)
    local sw = S.swipe
    if not sw then return end
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local dx = input.Position.X - sw.x0
    if not sw.moved and math.abs(dx) > 14 * sw.scale then
        sw.moved = true
        S.pressId = (S.pressId or 0) + 1 -- cancels a pending long-press
    end
    if sw.moved then
        S.longFired = true -- the finger lift must not count as a tap
        local steps = math.floor(math.abs(dx) / (50 * sw.scale))
        if dx > 0 then steps = -steps end -- finger moves right = previous tile
        local target = math.clamp(sw.startIndex + steps, 1, #items)
        if target ~= focusIndex then setFocus(target) end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        S.swipe = nil
    end
end)

refreshLocal = function()
    S.rebuildHome()
    refreshLibrary()
    if refreshStoreButtons then refreshStoreButtons() end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or minimized or S.kbOpen or S.loginOpen or not gui.Parent then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.Backspace or k == Enum.KeyCode.ButtonB then
        if panelOpen then closePanel()
        elseif currentPage then S.goBack() end
        return
    end
    if panelOpen then
        S.panelKey(k)
        return
    end
    if currentPage then
        local nav = S.pageNav[currentPage]
        if nav then nav(k) end
        return
    end
    if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then setFocus(focusIndex - 1)
    elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then setFocus(focusIndex + 1)
    elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then activateFocus()
    elseif k == Enum.KeyCode.O or k == Enum.KeyCode.ButtonX then optionsForFocus() end
end)

S.grip = make("TextButton", {
    Size = UDim2.fromOffset(140, 18),
    Position = UDim2.new(0.5, -70, 0, 0),
    BackgroundTransparency = 1, Text = "", ZIndex = 55,
}, main)

S.gripPill = make("Frame", {
    Size = UDim2.fromOffset(46, 4),
    Position = UDim2.new(0.5, -23, 0, 6),
    BackgroundColor3 = COLORS.white,
    BackgroundTransparency = 0.7,
    BorderSizePixel = 0, ZIndex = 56,
}, main)
round(S.gripPill, 2)

local dragging, dragStart, startPosition = false, nil, nil

S.grip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- double-tap maximizes, but only two real taps (a drag never counts)
        local now = tick()
        if now - (S.lastGripTap or 0) < 0.35 then
            S.lastGripTap = 0
            S.toggleMaximize()
            return
        end
        S.gripMoved = false
        if S.maximized then S.lastGripTap = now return end
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        if d.Magnitude > 4 then S.gripMoved = true end
        main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + d.X,
            startPosition.Y.Scale, startPosition.Y.Offset + d.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            -- only a tap that did not move can become half of a double-tap
            S.lastGripTap = S.gripMoved and 0 or tick()
        end
        dragging = false
    end
end)

-- PS button (shown while the dashboard is hidden): PS4 face buttons, draggable
S.PS_SIZE = 60
S.UI_FILE = "ps4_ui.json"
local restoreButton = make("TextButton", {
    Name = "PSButton",
    Size = UDim2.fromOffset(S.PS_SIZE, S.PS_SIZE),
    Position = UDim2.new(1, -86, 1, -102),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 50,
}, gui)
circle(restoreButton)
make("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new(Color3.fromRGB(34, 86, 176), Color3.fromRGB(4, 18, 52)),
}, restoreButton)
S.psRing = stroke(restoreButton, COLORS.white, 2, 0.25)
TweenService:Create(S.psRing,
    TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Transparency = 0.85 }):Play()
pcall(function()
    if isfile and isfile(S.UI_FILE) then
        local d = HttpService:JSONDecode(readfile(S.UI_FILE))
        if type(d) == "table" and tonumber(d.psx) and tonumber(d.psy) then
            local v = gui.AbsoluteSize
            local x, y = tonumber(d.psx), tonumber(d.psy)
            if v.X > 0 and v.Y > 0 then
                x = math.clamp(x, 0, math.max(0, v.X - S.PS_SIZE))
                y = math.clamp(y, 0, math.max(0, v.Y - S.PS_SIZE - 20))
            end
            restoreButton.Position = UDim2.fromOffset(x, y)
        end
    end
end)
-- thin inner plate, like the face-button cluster of a controller
do
    local plate = make("Frame", {
        Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(7, 7),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 51,
    }, restoreButton)
    circle(plate)
    stroke(plate, COLORS.white, 1, 0.78)
    local faces = {
        { "triangle", 23, 8, Color3.fromRGB(72, 226, 160) },
        { "circle", 38, 23, Color3.fromRGB(255, 84, 84) },
        { "cross", 23, 38, Color3.fromRGB(88, 148, 255) },
        { "square", 8, 23, Color3.fromRGB(255, 140, 205) },
    }
    for _, f in ipairs(faces) do
        S.icon(f[1], restoreButton, 14, f[4], UDim2.fromOffset(f[2], f[3]))
    end
end

S.psHint = label(restoreButton, "Drag to move  |  " .. TOGGLE_KEY.Name,
    UDim2.fromOffset(150, 14), UDim2.new(0.5, -75, 1, 6), 10, COLORS.muted)
S.psHint.TextXAlignment = Enum.TextXAlignment.Center

function S.psCenter()
    local p = restoreButton.Position
    return UDim2.new(p.X.Scale, p.X.Offset + S.PS_SIZE / 2, p.Y.Scale, p.Y.Offset + S.PS_SIZE / 2)
end

-- drag the button anywhere on screen (a short tap still restores the dashboard)
restoreButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        S.psMoved = false
        S.psDrag = { start = input.Position, pos = restoreButton.Position, moved = false }
    end
end)
UserInputService.InputChanged:Connect(function(input)
    local d = S.psDrag
    if not d then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - d.start
    if not d.moved and delta.Magnitude < 6 then return end
    d.moved = true
    S.psMoved = true
    local v = gui.AbsoluteSize
    local x = d.pos.X.Scale * v.X + d.pos.X.Offset + delta.X
    local y = d.pos.Y.Scale * v.Y + d.pos.Y.Offset + delta.Y
    x = math.clamp(x, 0, math.max(0, v.X - S.PS_SIZE))
    y = math.clamp(y, 0, math.max(0, v.Y - S.PS_SIZE - 20))
    restoreButton.Position = UDim2.fromOffset(x, y)
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local d = S.psDrag
        S.psDrag = nil
        if d and d.moved then
            pcall(function()
                if writefile then
                    local pos = restoreButton.Position
                    writefile(S.UI_FILE, HttpService:JSONEncode({ psx = pos.X.Offset, psy = pos.Y.Offset }))
                end
            end)
        end
    end
end)

local animationBusy = false

function S.baseScale()
    local cam = workspace.CurrentCamera
    if not cam then return 1 end
    local v = cam.ViewportSize
    if S.maximized then return math.max(0.4, math.min(v.X / W, v.Y / H)) end
    return math.clamp(math.min((v.X - 16) / W, (v.Y - 32) / H) * (settings.uiscale or 1), 0.4, 1.6)
end

-- Minimize (like a browser window): it shrinks down into the PS button
minimizeDashboard = function()
    if minimized or animationBusy then return end
    animationBusy = true
    minimized = true
    closePanel()
    playSound("Close")
    S.savedPos = main.Position
    local base = S.baseScale()
    local info = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    TweenService:Create(main, info, { Position = S.psCenter() }):Play()
    TweenService:Create(uiScale, info, { Scale = 0.03 }):Play()
    local fade = TweenService:Create(main, info, { GroupTransparency = 1 })
    fade:Play()
    fade.Completed:Wait()
    if not gui.Parent then return end
    main.Visible = false
    main.Position = S.savedPos
    uiScale.Scale = base
    S.backdrop.Visible = false
    restoreButton.Visible = true
    animationBusy = false
end

-- Restore: it grows back out of the PS button
function S.restoreDashboard()
    if not minimized or animationBusy then return end
    animationBusy = true
    restoreButton.Visible = false
    local base = S.baseScale()
    local home = S.savedPos or UDim2.fromScale(0.5, 0.5)
    main.Position = S.psCenter()
    uiScale.Scale = 0.03
    main.GroupTransparency = 1
    main.Visible = true
    if S.maximized then
        S.backdrop.Visible = true
        S.backdrop.BackgroundTransparency = 0
    end
    playSound("Open")
    playSound("Home")
    local info = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(main, info, { Position = home }):Play()
    TweenService:Create(uiScale, info, { Scale = base }):Play()
    local fade = TweenService:Create(main, info, { GroupTransparency = 0 })
    fade:Play()
    fade.Completed:Wait()
    if not gui.Parent then return end
    minimized = false
    animationBusy = false
end

-- Maximize / restore down: the window fills the whole screen and back
function S.toggleMaximize()
    if minimized or animationBusy then return end
    animationBusy = true
    local cam = workspace.CurrentCamera
    local v = cam and cam.ViewportSize or Vector2.new(W, H)
    local corner = main:FindFirstChildOfClass("UICorner")
    local rim = main:FindFirstChildOfClass("UIStroke")
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    closePanel()
    if not S.maximized then
        S.maximized = true
        S.preMaxPos = main.Position
        S.backdrop.Visible = true
        TweenService:Create(S.backdrop, info, { BackgroundTransparency = 0 }):Play()
        TweenService:Create(main, info, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
        TweenService:Create(uiScale, info, { Scale = math.max(0.4, math.min(v.X / W, v.Y / H)) }):Play()
        if corner then TweenService:Create(corner, info, { CornerRadius = UDim.new(0, 0) }):Play() end
        if rim then TweenService:Create(rim, info, { Transparency = 1 }):Play() end
    else
        S.maximized = false
        TweenService:Create(S.backdrop, info, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(main, info, { Position = S.preMaxPos or UDim2.fromScale(0.5, 0.5) }):Play()
        TweenService:Create(uiScale, info, { Scale = S.baseScale() }):Play()
        if corner then TweenService:Create(corner, info, { CornerRadius = UDim.new(0, 12) }):Play() end
        if rim then TweenService:Create(rim, info, { Transparency = 0.3 }):Play() end
        task.delay(0.36, function()
            if not S.maximized then S.backdrop.Visible = false end
        end)
    end
    S.setMaxIcon(S.maximized)
    playSound(S.maximized and "Open" or "Close")
    task.delay(0.36, function() animationBusy = false end)
end

function S.toggleDashboard()
    if minimized then S.restoreDashboard() else minimizeDashboard() end
end

restoreButton.Activated:Connect(function()
    if S.psMoved then S.psMoved = false return end
    S.restoreDashboard()
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not gui.Parent then return end
    if input.KeyCode == TOGGLE_KEY or input.KeyCode == Enum.KeyCode.ButtonSelect then
        S.toggleDashboard()
    end
end)

S.applyTheme(settings.theme)
refreshLocal()

-- Loading-style toast: "Checking game." -> ".." -> "..." -> result
function S.loadingToast(baseText)
    local ctl = { alive = true }
    if not settings.toasts then
        function ctl.finish(msg) table.insert(notifyLog, 1, { text = msg, time = os.time() }) end
        return ctl
    end
    playSound("Notify")
    local prev = main:FindFirstChild("PS4Toast")
    if prev then prev:Destroy() end
    local toast = make("Frame", {
        Name = "PS4Toast", Size = UDim2.fromOffset(300, 56), Position = UDim2.fromOffset(-320, 14),
        BackgroundColor3 = Color3.fromRGB(228, 233, 241), BorderSizePixel = 0, ZIndex = 60,
    }, main)
    local ink = Color3.fromRGB(44, 56, 84)
    S.toastIcon(toast)
    local m = label(toast, baseText .. ".", UDim2.new(1, -76, 1, -8), UDim2.fromOffset(68, 4), 14, ink)
    m.ZIndex = 61
    m.TextWrapped = false
    m.TextTruncate = Enum.TextTruncate.AtEnd
    tween(toast, 0.4, { Position = UDim2.fromOffset(16, 14) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local dots = { ".", "..", "..." }
    task.spawn(function()
        local i = 1
        while ctl.alive and toast.Parent do
            m.Text = baseText .. dots[i]
            i = i % 3 + 1
            task.wait(0.4)
        end
    end)
    function ctl.finish(msg)
        ctl.alive = false
        table.insert(notifyLog, 1, { text = msg, time = os.time() })
        if not toast.Parent then return end
        m.Text = msg
        task.delay(3, function()
            if toast.Parent then
                tween(toast, 0.25, { Position = UDim2.fromOffset(-320, 14) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.delay(0.3, function() if toast.Parent then toast:Destroy() end end)
            end
        end)
    end
    return ctl
end

-- ===== PS4 login: "Welcome back" profile picker + passcode (key system) =====
S.KEY = {
    enabled = true,
    len = 4,               -- passcode length (the Orbis Worker uses exactly 4 digits)
}
-- Orbis Auth client (remote module). Host orbis_client.lua in your repo; later login updates only need an edit there.
-- Tip: use a commit or tag instead of "main" so an accidental edit can't change everyone's login.
S.ORBIS_URL = "https://raw.githubusercontent.com/Dreamhacker-Fear/Ps4/main/orbis_client.lua"
S.LOGIN_FILE = "ps4_login.json"
S.login = { profiles = {} }

function S.loadLogin()
    if not canWrite() then return end
    if isfile(S.LOGIN_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(S.LOGIN_FILE)) end)
        if ok and type(data) == "table" and type(data.profiles) == "table" then S.login = data end
    end
end
function S.saveLogin()
    if not canWrite() then return end
    local ok, enc = pcall(function() return HttpService:JSONEncode(S.login) end)
    if ok then writefile(S.LOGIN_FILE, enc) end
end

-- loads the Orbis client once. Returns the module, or nil + reason (the login then stays closed: fail closed)
function S.loadOrbis()
    if S.orbis then return S.orbis end
    local ok, mod = pcall(function() return loadstring(httpGet(S.ORBIS_URL))() end)
    if ok and type(mod) == "table" and type(mod.verify) == "function" and type(mod.resume) == "function" then
        S.orbis = mod
        return mod
    end
    return nil, ok and "The login module is invalid." or tostring(mod)
end

function S.applyProfile(p)
    S.profile = p
    if not p then return end
    if S.userName then S.userName.Text = p.name end
    if S.libUserName then S.libUserName.Text = p.name end
end

function S.loginGate(onDone)
    if not S.KEY.enabled then onDone() return end
    S.loadLogin()
    for _, pr in ipairs(S.login.profiles) do pr.code = nil end -- old local passcodes are no longer used
    S.loginOpen = true
    local alive = true
    local root = make("CanvasGroup", {
        Name = "PS4Login", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 50,
    }, main)
    local back = make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Active = true,
    }, root)
    make("UIGradient", {
        Rotation = 40,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 62, 165)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 92, 200)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 50, 140)),
        }),
    }, back)
    for i = 1, 8 do
        local d = 8 + (i * 7) % 20
        local dotF = make("Frame", {
            Size = UDim2.fromOffset(d, d), BorderSizePixel = 0, BackgroundColor3 = COLORS.white, BackgroundTransparency = 0.88,
            Position = UDim2.fromOffset(60 + (i * 113) % 700, 20 + (i * 67) % 400),
        }, root)
        circle(dotF)
    end
    local logo = label(root, "PS4", UDim2.fromOffset(160, 48), UDim2.fromOffset(28, 14), 38, COLORS.white, true)
    logo.TextWrapped = false
    local holder = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, root)
    tween(root, 0.35, { GroupTransparency = 0 })

    local conn
    local function clear()
        if conn then conn:Disconnect(); conn = nil end
        for _, c in ipairs(holder:GetChildren()) do c:Destroy() end
    end
    local function loadBust(img, userId)
        task.spawn(function()
            local ok, url = pcall(function()
                return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
            end)
            if ok and url and img.Parent then img.Image = url end
        end)
    end
    local function centered(text, y, size, color, bold)
        local l = label(holder, text, UDim2.fromOffset(W, size + 10), UDim2.fromOffset(0, y), size, color or COLORS.white, bold)
        l.TextXAlignment = Enum.TextXAlignment.Center
        return l
    end
    local function hint(icon, text, x)
        S.icon(icon, holder, 16, COLORS.white, UDim2.fromOffset(x, H - 40))
        local l = label(holder, text, UDim2.fromOffset(120, 22), UDim2.fromOffset(x + 22, H - 43), 13, COLORS.white)
        l.TextWrapped = false
    end

    local function finish(p, authResult)
        if not alive then return end
        S.isOwner = authResult and authResult.isOwner == true or false
        S.isPremium = authResult and authResult.premium == true or S.isOwner
        if S.buildSettingsGrid then S.buildSettingsGrid() end
        alive = false
        S.saveLogin()
        S.applyProfile(p)
        S.loginOpen = false
        playSound("Login")
        tween(root, 0.4, { GroupTransparency = 1 })
        task.delay(0.45, function() root:Destroy() end)
        onDone(p)
    end

    local showPicker, showPasscode

    local editMode = false

    local function confirmDelete(p)
        S.showDialog('Delete the profile "' .. p.name .. '"?', nil, "Its saved login is removed too.", {
            { "Delete", function()
                for idx, q in ipairs(S.login.profiles) do
                    if q == p then table.remove(S.login.profiles, idx) break end
                end
                if S.orbis then S.orbis.clear(p.userId) end
                S.saveLogin()
                notify("Profile removed")
                if alive then showPicker() end
            end },
            { "Cancel" },
        })
    end

    local function pickProfile(p)
        if not S.orbis.load(p.userId) then showPasscode(p) return end
        -- saved session: quietly check it with the server (POST /session)
        task.spawn(function()
            local ld = S.showLoading("Signing in...")
            local r = S.orbis.resume(p.userId)
            task.wait(0.8 + math.random() * 1.2)
            ld.close()
            if not alive then return end
            if r.ok then
                finish(p, r)
            elseif r.reason == "session_invalid" or r.reason == "none" then
                showPasscode(p, r.message ~= "" and r.message or nil) -- expired: ask for a new passcode
            else
                S.showDialog(r.message) -- network / server / rate limit: the session is kept, just retry
            end
        end)
    end

    showPicker = function()
        clear()
        if #S.login.profiles == 0 then editMode = false end
        centered("Welcome Back to PlayStation\194\174", 84, 20)
        centered("Who is playing?", 118, 13, COLORS.white)
        local entries = {}
        if #S.login.profiles < 4 then table.insert(entries, { new = true }) end
        for _, p in ipairs(S.login.profiles) do table.insert(entries, { profile = p }) end
        local tw, gap = 114, 14
        local x0 = (W - (#entries * tw + (#entries - 1) * gap)) / 2
        for i, en in ipairs(entries) do
            local tile = make("TextButton", {
                Size = UDim2.fromOffset(tw, 168), Position = UDim2.fromOffset(x0 + (i - 1) * (tw + gap), 170),
                BackgroundColor3 = Color3.fromRGB(28, 112, 218), BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            }, holder)
            local st = stroke(tile, COLORS.white, 3, 1)
            tile.MouseEnter:Connect(function() st.Transparency = 0 end)
            tile.MouseLeave:Connect(function() st.Transparency = 1 end)
            if en.new then
                local plus = label(tile, "+", UDim2.fromOffset(tw, 90), UDim2.fromOffset(0, 18), 64, COLORS.white, true)
                plus.TextXAlignment = Enum.TextXAlignment.Center
                local nm = label(tile, "New User", UDim2.fromOffset(tw, 40), UDim2.fromOffset(0, 128), 12, COLORS.white, true)
                nm.TextXAlignment = Enum.TextXAlignment.Center
                tile.Activated:Connect(function()
                    playSound("Select")
                    S.openKeyboard("Choose your name", player.DisplayName, {
                        hint = "Pick the name shown on your profile.",
                        onDone = function(text)
                            text = text:gsub("^%s+", ""):gsub("%s+$", "")
                            if text == "" then text = player.DisplayName end
                            text = text:sub(1, 16)
                            local prof
                            for _, p in ipairs(S.login.profiles) do
                                if p.userId == player.UserId then prof = p end
                            end
                            if prof then prof.name = text
                            else
                                prof = { name = text, userId = player.UserId }
                                table.insert(S.login.profiles, prof)
                            end
                            S.saveLogin()
                            pickProfile(prof)
                        end,
                    })
                end)
            else
                local p = en.profile
                local holdTok, held, didLong = 0, false, false
                local img = make("ImageLabel", {
                    Size = UDim2.fromOffset(tw, 114), BackgroundColor3 = COLORS.card, BorderSizePixel = 0, Image = "",
                }, tile)
                loadBust(img, p.userId)
                local nm = label(tile, p.name, UDim2.fromOffset(tw - 22, 54), UDim2.fromOffset(8, 114), 12, COLORS.white, true)
                nm.TextTruncate = Enum.TextTruncate.AtEnd
                nm.TextWrapped = false
                if S.orbis.load(p.userId) then
                    local plus = label(tile, "+", UDim2.fromOffset(14, 54), UDim2.fromOffset(tw - 20, 114), 16, Color3.fromRGB(255, 196, 0), true)
                    plus.TextXAlignment = Enum.TextXAlignment.Center
                end
                if editMode then
                    local badge = make("Frame", {
                        Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(tw - 32, 6),
                        BackgroundColor3 = Color3.fromRGB(214, 48, 58), BorderSizePixel = 0,
                    }, tile)
                    circle(badge)
                    S.icon("cross", badge, 14, COLORS.white, UDim2.fromOffset(6, 6))
                end
                -- hold a profile for 0.7s (phone) to delete it
                tile.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        held, didLong = true, false
                        holdTok += 1
                        local mine = holdTok
                        task.delay(0.7, function()
                            if held and holdTok == mine and alive then
                                held, didLong = false, true
                                playSound("Select")
                                confirmDelete(p)
                            end
                        end)
                    end
                end)
                tile.InputEnded:Connect(function() held = false end)
                tile.Activated:Connect(function()
                    if didLong then didLong = false return end
                    playSound("Select")
                    if editMode then confirmDelete(p) else pickProfile(p) end
                end)
                tile.MouseButton2Click:Connect(function() playSound("Select"); confirmDelete(p) end)
            end
        end
        hint("cross", "Enter", 40)
        centered(editMode and "Tap a profile to delete it" or "Need a passcode? Join our Discord to get one.", 346, 12, COLORS.white)
        local dc = make("TextButton", {
            Size = UDim2.fromOffset(230, 28), Position = UDim2.fromOffset((W - 230) / 2, 372),
            BackgroundColor3 = Color3.fromRGB(88, 101, 242), BorderSizePixel = 0, AutoButtonColor = true,
            Text = "Copy Discord link", TextColor3 = COLORS.white, Font = Enum.Font.GothamMedium, TextSize = 13,
        }, holder)
        round(dc, 14)
        dc.Activated:Connect(function() playSound("Select"); copyText(S.DISCORD, "Discord invite") end)
        if #S.login.profiles > 0 then
            local ob = make("TextButton", {
                Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(W - 190, H - 44),
                BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
            }, holder)
            S.icon("options", ob, 18, COLORS.white, UDim2.fromOffset(0, 6))
            local ol = label(ob, editMode and "Done" or "Options Menu", UDim2.fromOffset(120, 30), UDim2.fromOffset(26, 0), 13, COLORS.white)
            ol.TextWrapped = false
            ob.Activated:Connect(function() playSound("Select"); editMode = not editMode; showPicker() end)
        end
    end

    showPasscode = function(p, notice)
        clear()
        centered("Enter the passcode to sign in.", 52, 16)
        centered("Run /psn in our Discord, add the phrase to your Roblox profile About, then enter the 4-digit passcode.", 80, 12, COLORS.muted)

        -- profile card (left)
        local card = make("Frame", {
            Size = UDim2.fromOffset(104, 138), Position = UDim2.fromOffset(150, 120),
            BackgroundColor3 = Color3.fromRGB(28, 112, 218), BorderSizePixel = 0,
        }, holder)
        local img = make("ImageLabel", { Size = UDim2.fromOffset(104, 104), BackgroundColor3 = COLORS.card, BorderSizePixel = 0, Image = "" }, card)
        loadBust(img, p.userId)
        local nm = label(card, p.name, UDim2.fromOffset(96, 34), UDim2.fromOffset(6, 104), 12, COLORS.white, true)
        nm.TextTruncate = Enum.TextTruncate.AtEnd
        nm.TextWrapped = false

        local len = S.KEY.len
        local boxW, boxGap = 44, 8
        local boxes = {}
        local bx = 290
        for i = 1, len do
            local b = make("Frame", {
                Size = UDim2.fromOffset(boxW, boxW), Position = UDim2.fromOffset(bx + (i - 1) * (boxW + boxGap), 120),
                BackgroundColor3 = Color3.fromRGB(0, 40, 120), BackgroundTransparency = 0.45, BorderSizePixel = 0,
            }, holder)
            local st = stroke(b, COLORS.white, 2, 0.75)
            local dot = label(b, "", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 26, COLORS.white, true)
            dot.TextXAlignment = Enum.TextXAlignment.Center
            boxes[i] = { frame = b, stroke = st, dot = dot }
        end
        local status = label(holder, "", UDim2.fromOffset(340, 32), UDim2.fromOffset(290, 166), 11, COLORS.muted)
        status.TextYAlignment = Enum.TextYAlignment.Top
        if notice then
            status.TextColor3 = Color3.fromRGB(255, 150, 150)
            status.Text = notice
        end

        local code, busy, tries = "", false, 0
        local function refreshBoxes()
            for i, b in ipairs(boxes) do
                b.dot.Text = i <= #code and "\226\128\162" or ""
                local active = (i == #code + 1)
                b.stroke.Color = active and Color3.fromRGB(110, 200, 255) or COLORS.white
                b.stroke.Transparency = active and 0 or 0.75
                b.stroke.Thickness = active and 2.5 or 2
            end
        end
        local function shake()
            for _, b in ipairs(boxes) do
                local x = b.frame.Position.X.Offset
                task.spawn(function()
                    for _, dx in ipairs({ 6, -6, 4, -4, 0 }) do
                        b.frame.Position = UDim2.fromOffset(x + dx, 120)
                        task.wait(0.04)
                    end
                end)
            end
        end
        local function submit()
            busy = true
            status.TextColor3 = COLORS.muted
            status.Text = "Checking..."
            task.spawn(function()
                task.wait(0.6 + math.random() * 1.4)
                local r = S.orbis.verify(code, p.userId) -- POST /verify, saves the session token on success
                if not alive then return end
                if r.ok then
                    finish(p, r)
                    return
                end
                code = ""
                refreshBoxes()
                status.TextColor3 = Color3.fromRGB(255, 150, 150)
                status.Text = r.message
                if r.reason == "rate_limited" then
                    S.loginLockUntil = tick() + (r.retry or 60)
                elseif r.reason == "net" or r.reason == "norequest" or r.reason == "server_error" then
                    S.showDialog(r.message) -- OK + Contact Support
                else
                    shake()
                end
                busy = false
            end)
        end
        local function press(d)
            if busy or not alive then return end
            local wait = (S.loginLockUntil or 0) - tick()
            if wait > 0 then
                status.TextColor3 = Color3.fromRGB(255, 150, 150)
                status.Text = "Locked. Try again in " .. math.ceil(wait) .. "s."
                return
            end
            if #code < len then
                code = code .. d
                refreshBoxes()
                if #code == len then submit() end
            end
        end
        local function backspace()
            if busy then return end
            code = code:sub(1, math.max(0, #code - 1))
            refreshBoxes()
        end

        -- number pad (1-5 / 6-0), like the real passcode screen
        local pad = make("Frame", {
            Size = UDim2.fromOffset(5 * 62 + 4 * 4 + 16, 2 * 40 + 4 + 16), Position = UDim2.fromOffset(290, 200),
            BackgroundColor3 = Color3.fromRGB(0, 40, 120), BackgroundTransparency = 0.5, BorderSizePixel = 0,
        }, holder)
        local digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
        for i, d in ipairs(digits) do
            local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
            local k = make("TextButton", {
                Size = UDim2.fromOffset(62, 40), Position = UDim2.fromOffset(8 + col * 66, 8 + row * 44),
                BackgroundColor3 = Color3.fromRGB(0, 70, 170), BackgroundTransparency = 0.3, BorderSizePixel = 0,
                AutoButtonColor = false, Text = d, Font = Enum.Font.Gotham, TextSize = 17, TextColor3 = COLORS.white,
            }, pad)
            local kst = stroke(k, COLORS.white, 2, 1)
            k.MouseEnter:Connect(function() kst.Transparency = 0 end)
            k.MouseLeave:Connect(function() kst.Transparency = 1 end)
            k.Activated:Connect(function() playSound("Select"); press(d) end)
        end
        local function smallBtn(text, x, w, fn)
            local b = make("TextButton", {
                Size = UDim2.fromOffset(w, 30), Position = UDim2.fromOffset(x, 312),
                BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = text,
                Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.white,
            }, holder)
            local bst = stroke(b, COLORS.white, 1.2, 0.3)
            b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.85 end)
            b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
            b.Activated:Connect(function() playSound("Select"); fn() end)
        end
        smallBtn("Get Passcode (Discord)", 290, 190, function() copyText(S.DISCORD, "Discord invite") end)
        smallBtn("Delete", 490, 100, backspace)

        -- back + real keyboard
        local backBtn = make("TextButton", {
            Size = UDim2.fromOffset(120, 30), Position = UDim2.fromOffset(40, H - 44), BackgroundTransparency = 1, Text = "",
        }, holder)
        S.icon("circle", backBtn, 18, COLORS.white, UDim2.fromOffset(0, 6))
        label(backBtn, "Back", UDim2.fromOffset(80, 30), UDim2.fromOffset(26, 0), 14, COLORS.white)
        backBtn.Activated:Connect(function() playSound("Close"); if not busy then showPicker() end end)
        local names = { Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9" }
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local n = input.KeyCode.Name:gsub("^Keypad", "")
            if names[n] then press(names[n])
            elseif input.KeyCode == Enum.KeyCode.Backspace then backspace() end
        end)
        refreshBoxes()
    end

    local function showUnavailable(why)
        clear()
        centered("Login is not available right now.", 130, 18)
        local l = centered("The login module could not be loaded. Check your connection and try again.", 164, 12, COLORS.muted)
        local d = centered(tostring(why or ""):sub(1, 90), 188, 11, COLORS.muted)
        local function bigBtn(text, x, fn)
            local b = make("TextButton", {
                Size = UDim2.fromOffset(180, 34), Position = UDim2.fromOffset(x, 240), BackgroundColor3 = Color3.fromRGB(34, 52, 92),
                BorderSizePixel = 0, AutoButtonColor = true, Text = text, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COLORS.white,
            }, holder)
            stroke(b, COLORS.white, 1.5, 0.5)
            b.Activated:Connect(function() playSound("Select"); fn() end)
        end
        bigBtn("Try again", W / 2 - 190, function() S.startGate() end)
        bigBtn("Copy Discord link", W / 2 + 10, function() copyText(S.DISCORD, "Discord invite") end)
    end

    function S.startGate()
        task.spawn(function()
            clear()
            local ld = S.showLoading("Loading login...")
            local mod, why = S.loadOrbis()
            ld.close()
            if not alive then return end
            if mod then showPicker() else showUnavailable(why) end
        end)
    end
    S.startGate()
end


-- ===== What's New: post to Discord (Release / Showcase / Bug Report) =====
-- Each category sends to its own Discord channel through a webhook.
-- NOTE: webhook URLs inside a client script can be read by anyone who has the script.
S.NEWS = {
    cooldown = 30, -- seconds between posts
    cats = {
        { name = "Release",    color = Color3.fromRGB(46, 160, 90),  embed = 0x2EA05A,
          hook = "https://discord.com/api/webhooks/1565736121827336382/FbSiBz9Nh3NvaU9x--04V6Li2GJ7lSSXUrXkZFB4Q76vF4NAnC_8g1fjoh7IjdLue9Mz" },
        { name = "Showcase",   color = Color3.fromRGB(150, 80, 210), embed = 0x9650D2,
          hook = "https://discord.com/api/webhooks/1565736272738263111/8Zs_hJe0Z_zVxXCbGgzfs7uyNwntDqNC0MuxADR4EovVMaTbI3_zIzxCIk_R1XlBKmZK" },
        { name = "Bug Report", color = Color3.fromRGB(200, 70, 70),  embed = 0xC84646,
          hook = "https://discord.com/api/webhooks/1565737750697869462/6RFwKz_FAEoWL9uwQEuK1X5z55TPd5EZ5hNbW0kxHFLccgmTDvDd14ZigksVT-7-bDt7" },
    },
}
S.newsSel, S.newsNext, S.newsBusy = 1, 0, false

function S.httpRequest()
    return (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)
end

S.newsPage = makePage("News", "What's New")
pages.News.back.Activated:Connect(function() S.goBack() end)

S.newsCatBtns = {}
for i, cat in ipairs(S.NEWS.cats) do
    local b = button(S.newsPage, cat.name, UDim2.fromOffset(150, 30), UDim2.fromOffset(40 + (i - 1) * 158, 78), COLORS.card, 13)
    S.newsCatBtns[i] = b
    b.Activated:Connect(function() playSound("Select"); S.newsSelect(i) end)
end

S.newsTitle = make("TextBox", {
    Size = UDim2.fromOffset(W - 80, 28), Position = UDim2.fromOffset(40, 118),
    BackgroundColor3 = COLORS.card, BackgroundTransparency = 0.3, BorderSizePixel = 0,
    Text = "", PlaceholderText = "Title", PlaceholderColor3 = COLORS.muted, TextColor3 = COLORS.white,
    Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, S.newsPage)
round(S.newsTitle, 6)
make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, S.newsTitle)
stroke(S.newsTitle, COLORS.white, 1, 0.85)

S.newsScroll = make("ScrollingFrame", {
    Size = UDim2.fromOffset(W - 80, 200), Position = UDim2.fromOffset(40, 154),
    BackgroundColor3 = Color3.fromRGB(6, 14, 34), BackgroundTransparency = 0.2, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = COLORS.muted,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, S.newsPage)
round(S.newsScroll, 6)
stroke(S.newsScroll, COLORS.white, 1, 0.85)

S.newsBody = make("TextBox", {
    Size = UDim2.new(1, -12, 0, 190), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
    PlaceholderText = "Write your post here...", PlaceholderColor3 = COLORS.muted, TextColor3 = COLORS.white,
    Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, MultiLine = true, ClearTextOnFocus = false,
}, S.newsScroll)
make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, S.newsBody)

S.newsStatus = label(S.newsPage, "", UDim2.fromOffset(330, 30), UDim2.fromOffset(250, H - 44), 12, COLORS.muted)
S.newsStatus.TextXAlignment = Enum.TextXAlignment.Right
S.newsSend = button(S.newsPage, "Send", UDim2.fromOffset(150, 30), UDim2.fromOffset(W - 190, H - 44), Color3.fromRGB(20, 120, 70), 12)

function S.newsSelect(i)
    S.newsSel = i
    for k, b in ipairs(S.newsCatBtns) do
        b.BackgroundColor3 = (k == i) and S.NEWS.cats[k].color or COLORS.card
    end
    S.newsTitle.PlaceholderText = (i == 3) and "What went wrong?" or "Title"
    S.newsBody.PlaceholderText = (i == 3) and "How can we reproduce it? Which script / game?" or "Write your post here..."
end

function S.openNews()
    S.newsSelect(S.newsSel)
    S.newsStatus.Text = ""
    showPage("News")
end

function S.sendNews()
    if S.newsBusy then return end
    local cat = S.NEWS.cats[S.newsSel]
    local title = S.newsTitle.Text:match("^%s*(.-)%s*$")
    local body = S.newsBody.Text:match("^%s*(.-)%s*$")
    if title == "" then notify("Add a title first") return end
    if body == "" then notify("Write something first") return end
    local wait = S.newsNext - tick()
    if wait > 0 then
        S.newsStatus.TextColor3 = Color3.fromRGB(255, 150, 150)
        S.newsStatus.Text = "Please wait " .. math.ceil(wait) .. "s before posting again."
        return
    end
    local req = S.httpRequest()
    if not req then notify("Your executor can't send web requests") return end

    local gname = "Unknown game"
    pcall(function() gname = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
    local who = S.profile and S.profile.name or player.Name
    local payload = {
        username = "PS4 Dashboard",
        allowed_mentions = { parse = {} }, -- never ping @everyone / roles
        embeds = { {
            title = "[" .. cat.name .. "] " .. title:sub(1, 240),
            description = body:sub(1, 4000),
            color = cat.embed,
            author = { name = player.DisplayName .. " (@" .. player.Name .. ")" },
            footer = { text = who .. " | " .. gname .. " | " .. tostring(game.PlaceId) },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        } },
    }

    S.newsBusy = true
    S.newsSend.Text = "Sending..."
    S.newsStatus.TextColor3 = COLORS.muted
    S.newsStatus.Text = ""
    task.spawn(function()
        local ok, res = pcall(function()
            return req({
                Url = cat.hook, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload),
            })
        end)
        local code = ok and type(res) == "table" and (res.StatusCode or res.Status_Code) or nil
        local sent = ok and type(code) == "number" and code >= 200 and code < 300
        S.newsBusy = false
        S.newsSend.Text = "Send"
        if sent then
            S.newsNext = tick() + S.NEWS.cooldown
            S.newsTitle.Text, S.newsBody.Text = "", ""
            S.newsStatus.Text = cat.name .. " posted!"
            playSound("Notify")
            notify(cat.name .. " posted to Discord")
        else
            S.newsStatus.TextColor3 = Color3.fromRGB(255, 150, 150)
            S.newsStatus.Text = "Could not send" .. (code and (" (HTTP " .. code .. ")") or "") .. "."
        end
    end)
end
S.newsSend.Activated:Connect(function() playSound("Select"); S.sendNews() end)

-- automatic check when the dashboard starts (runs after login)
function S.startup()
  playSound("Home")
  task.spawn(function()
    local t = S.loadingToast("Checking game")
    local started = tick()
    local gname = "Unknown game"
    pcall(function()
        gname = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    local left = 2.4 - (tick() - started) -- let the dots cycle at least twice
    if left > 0 then task.wait(left) end
    if canWrite() then
        t.finish(gname .. " - ready (" .. libraryCount() .. "/" .. MAX_STORAGE .. ")")
    else
        t.finish(gname .. " - no file API, downloads won't persist")
    end
end)
end

S.loginGate(S.startup)
