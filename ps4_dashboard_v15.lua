local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("PS4Dashboard")
if old then old:Destroy() end

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

local SOUND_IDS = {
    Select = "rbxassetid://124400323975890",
    Login = "rbxassetid://123072435492721",
    Open = "rbxassetid://134203002406032",
    Close = "rbxassetid://88440088035194",
    Notify = "rbxassetid://84711905220990",
    Home = "rbxassetid://126928354906604",
}

-- Key that hides / shows the whole dashboard (change it here)
local TOGGLE_KEY = Enum.KeyCode.RightShift

local settings = { sound = true, volume = 0.6, toasts = true, theme = 1, images = true }
local earned = {}
local pageGradients, waves = {}, {}

local function playSound(name)
    local id = SOUND_IDS[name]
    if not id or not settings.sound then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.Name = "PS4_" .. name
        s.SoundId = id
        s.Volume = settings.volume
        s.Parent = SoundService
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

local function colorFor(text)
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
local IMG_PREFIX = "ps4_img_"
local assetFn = getcustomasset or getsynasset
local imgCache = {}
local imgFailed = {}

local function imageUrl(path)
    if type(path) ~= "string" or path == "" then return nil end
    if path:lower():find("%.webp") then return nil end
    if path:sub(1, 4) == "http" then return path end
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    return SB_ROOT .. path
end

local function pickImage(sc)
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
    if not url or imgFailed[url] or not settings.images then fail() return end
    if type(assetFn) ~= "function" or type(writefile) ~= "function" or type(isfile) ~= "function" then fail() return end
    if imgCache[url] then callback(imgCache[url]) return end
    task.spawn(function()
        local h = 5381
        for i = 1, #url do h = (h * 33 + url:byte(i)) % 4294967296 end
        local file = IMG_PREFIX .. h .. ".png"
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
            imgFailed[url] = true
            fail()
        end
    end)
end

local function loadGameIcon(placeId, callback)
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
    loadImage(path, show, function() loadGameIcon(gameId, show) end)
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
local checkForUpdate
local openEditor

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

local function formatBytes(n)
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
    return string.format("Downloading %d%%  (%s / %s)", pct, formatBytes(size * st.progress), formatBytes(size))
end

local MAX_STORAGE = 10
local LIB_FILE = "ps4_library.json"

local function canWrite()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

-- Short "loader" scripts just call loadstring(game:HttpGet(url))().
-- If that url is dead the script itself throws "HTTP 404" and then
-- "attempt to call a nil value". We check the link first so a dead
-- script never gets started.
local function findLoaderUrls(code)
    local urls = {}
    if #code > 1500 then return urls end
    for url in code:gmatch("HttpGet%(%s*[\"']([^\"']+)[\"']") do table.insert(urls, url) end
    for url in code:gmatch("HttpGetAsync%(%s*[\"']([^\"']+)[\"']") do table.insert(urls, url) end
    return urls
end

local DEAD_LINK_MSG = "This script's link is dead (404) - it was probably removed"

local function execScript(code)
    if not code or code == "" then notify("No code in this script") return end
    if type(loadstring) ~= "function" then notify("loadstring not available") return end

    task.spawn(function()
        for _, url in ipairs(findLoaderUrls(code)) do
            local ok, res = pcall(httpGet, url)
            if not ok then
                if tostring(res):find("404") then
                    notify(DEAD_LINK_MSG)
                    return
                end
            elseif type(res) ~= "string" or res == "" or res:match("^%s*404") or res:sub(1, 1) == "<" then
                notify(DEAD_LINK_MSG)
                return
            end
        end

        local fn, err = loadstring(code)
        if not fn then notify("Load error: " .. tostring(err):sub(1, 80)) return end

        local ok, err2 = xpcall(fn, function(e) return tostring(e) end)
        if ok then
            notify("Script started")
            if unlockTrophy then unlockTrophy("runner") end
        else
            local msg = tostring(err2)
            if msg:find("404") then
                notify(DEAD_LINK_MSG)
            elseif msg:find("attempt to call a nil value") and msg:find(":1:") then
                notify("The script could not load its own code (dead or blocked link)")
            else
                notify("Error: " .. msg:sub(1, 80))
            end
        end
    end)
end

local library = {}

local function libraryCount()
    local n = 0
    for _ in pairs(library) do n += 1 end
    return n
end

local function loadLibrary()
    if not canWrite() then return end
    if isfile(LIB_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(LIB_FILE))
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
    if ok then writefile(LIB_FILE, encoded) end
end

local function sortedLibrary()
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

local function deleteFromLibrary(id)
    if not library[id] then return false end
    library[id] = nil
    saveLibrary()
    notify("Deleted")
    refreshLocal()
    if unlockTrophy then unlockTrophy("tidy") end
    return true
end

loadLibrary()

local SETTINGS_FILE = "ps4_settings.json"

local function saveSettings()
    if not canWrite() then return end
    pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode({ settings = settings, earned = earned }))
    end)
end

local function loadSettings()
    if not canWrite() then return end
    if not isfile(SETTINGS_FILE) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data.settings or {}) do settings[k] = v end
        if type(data.earned) == "table" then earned = data.earned end
    end
end

loadSettings()

local W, H = 800, 450

local gui = make("ScreenGui", {
    Name = "PS4Dashboard",
    ResetOnSpawn = false,
    DisplayOrder = 999,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

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

local uiScale = make("UIScale", { Scale = 1 }, main)
local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local v = cam.ViewportSize
    uiScale.Scale = math.clamp(math.min((v.X - 16) / W, (v.Y - 32) / H), 0.45, 1.4)
end
updateScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local bg = make("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0, ZIndex = 0,
}, main)
local bgGradient = make("UIGradient", {
    Rotation = 35,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 22, 60)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(14, 68, 142)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 30, 82)),
    }),
}, bg)

for i = 1, 4 do
    local wave = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1.7, 0, 0, 90 + i * 24),
        Position = UDim2.new(0.5, 0, 0.5 + i * 0.1, 0),
        Rotation = -10 + i * 2,
        BackgroundColor3 = Color3.fromRGB(90, 165, 240),
        BackgroundTransparency = 0.7 + i * 0.04,
        BorderSizePixel = 0, ZIndex = 0,
    }, bg)
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

local minimized = false
local currentPage = nil
local panelOpen = false

notify = function(msg)
    table.insert(notifyLog, 1, { text = tostring(msg), time = os.time() })
    if #notifyLog > 40 then table.remove(notifyLog) end
    if not settings.toasts then return end
    playSound("Notify")
    local prev = main:FindFirstChild("PS4Toast")
    if prev then prev:Destroy() end
    local toast = make("Frame", {
        Name = "PS4Toast",
        Size = UDim2.fromOffset(290, 54),
        Position = UDim2.fromOffset(-310, 14),
        BackgroundColor3 = Color3.fromRGB(8, 22, 48),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0, ZIndex = 60,
    }, main)
    round(toast, 8)
    stroke(toast, COLORS.white, 1, 0.8)
    label(toast, "PlayStation", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(12, 6), 10, COLORS.muted)
    local m = label(toast, msg, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(12, 24), 12, COLORS.white)
    m.TextWrapped = false
    m.TextTruncate = Enum.TextTruncate.AtEnd
    tween(toast, 0.3, { Position = UDim2.fromOffset(16, 14) })
    task.delay(3, function()
        if toast.Parent then
            tween(toast, 0.25, { Position = UDim2.fromOffset(-310, 14) },
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

local panel = make("CanvasGroup", {
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

local panelTitle = label(panel, "", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 22), 17, COLORS.white, true)
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

local function openPanel(title, entries)
    panelTitle.Text = title
    for _, c in ipairs(panelList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for index, e in ipairs(entries) do
        local row = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false,
            Text = e[1], TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.Gotham, TextSize = 14,
            TextColor3 = COLORS.white, LayoutOrder = index,
        }, panelList)
        make("UIPadding", { PaddingLeft = UDim.new(0, 14) }, row)
        round(row, 4)
        local o = stroke(row, COLORS.white, 2, 1)
        row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.88; o.Transparency = 0.1 end)
        row.MouseLeave:Connect(function() row.BackgroundTransparency = 1; o.Transparency = 1 end)
        row.Activated:Connect(function()
            playSound("Select")
            closePanel()
            if e[2] then e[2]() end
        end)
    end
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
        Position = UDim2.fromOffset(34, H - 44),
        BackgroundTransparency = 1,
        Text = "○   Back",
        Font = Enum.Font.Gotham, TextSize = 14,
        TextColor3 = COLORS.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, page)
    backBtn.MouseEnter:Connect(function() backBtn.TextColor3 = COLORS.white end)
    backBtn.MouseLeave:Connect(function() backBtn.TextColor3 = COLORS.muted end)
    pages[name] = { frame = page, back = backBtn, title = titleLabel }
    return page
end

local function hidePage(page)
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
            hidePage(d.frame)
        end
    end
    currentPage = name
end

local function goHome()
    closePanel()
    for _, d in pairs(pages) do
        if d.frame.Visible then hidePage(d.frame) end
    end
    currentPage = nil
    playSound("Close")
end

local storePage = makePage("Store", "PlayStation Store")
local libraryPage = makePage("Library", "Library")
local settingsPage = makePage("Settings", "Settings")
local infoPage = makePage("Info", "")
local friendsPage = makePage("Friends", "Friends")
local partyPage = makePage("Party", "Party")
local messagesPage = makePage("Messages", "Messages")
local notifPage = makePage("Notifications", "Notifications")
local trophyPage = makePage("Trophies", "Trophies")
local editorPage = makePage("Editor", "Code Editor")

local infoBody = label(infoPage, "", UDim2.new(1, -80, 0, 260), UDim2.fromOffset(40, 80), 14, COLORS.muted)
infoBody.TextYAlignment = Enum.TextYAlignment.Top

for _, d in pairs(pages) do d.back.Activated:Connect(goHome) end

local function showInfo(title, text)
    pages.Info.title.Text = title
    infoBody.Text = text
    showPage("Info")
end

local function shortText(t, n)
    t = tostring(t)
    if #t > n then return t:sub(1, n - 1) .. "…" end
    return t
end

local function showScriptInfo(id)
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

local function confirmDelete(id)
    local e = library[id]
    if not e then return end
    openPanel("Delete \"" .. shortText(e.title, 16) .. "\"?", {
        { "Delete", function() deleteFromLibrary(id) end },
        { "Cancel" },
    })
end

local function openScriptOptions(id)
    local e = library[id]
    if not e then return end
    local entries = { { "Start", function() execScript(e.code) end } }
    if not e.custom then
        table.insert(entries, { "Check for Update", function() checkForUpdate(id) end })
    end
    table.insert(entries, { "Edit Code", function() openEditor(id) end })
    table.insert(entries, { "Information", function() showScriptInfo(id) end })
    table.insert(entries, { "Copy Script", function() copyText(tostring(e.code or ""), "Script") end })
    table.insert(entries, { "Delete", function() confirmDelete(id) end })
    openPanel(shortText(e.title, 22), entries)
end

local function openPowerPanel()
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

local function openPlayerOptions(userId, username, display)
    openPanel(shortText(display, 22), {
        { "Copy Username", function() copyText(username, "Username") end },
        { "Copy User ID", function() copyText(tostring(userId), "User ID") end },
        { "Copy Profile Link", function() copyText("https://www.roblox.com/users/" .. userId .. "/profile", "Profile link") end },
        { "Cancel" },
    })
end

local function avatarCircle(parent, userId, x, y, size)
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

local friendsScroll = makeListScroll(friendsPage)
local partyScroll = makeListScroll(partyPage)
local notifScroll = makeListScroll(notifPage)
local trophyScroll = makeListScroll(trophyPage)
local msgScroll = makeListScroll(messagesPage, 84, 272)

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
    { id = "platinum", name = "Platinum", desc = "Earn every other trophy", grade = "Platinum" },
}

local GRADE_COLORS = {
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
            if t.id ~= "platinum" and not earned[t.id] then all = false break end
        end
        if all then task.delay(3, function() unlockTrophy("platinum") end) end
    end
end

local function refreshTrophies()
    clearList(trophyScroll)
    local got = 0
    for _, t in ipairs(TROPHIES) do
        if earned[t.id] then got += 1 end
    end
    pages.Trophies.title.Text = "Trophies  -  " .. got .. " / " .. #TROPHIES
    for i, t in ipairs(TROPHIES) do
        local has = earned[t.id] ~= nil
        local row = listRow(trophyScroll, i, 54)
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
            TextColor3 = has and GRADE_COLORS[t.grade] or COLORS.grey,
        }, row)
        rowText(row, t.name, UDim2.fromOffset(62, 8), UDim2.new(1, -200, 0, 20), 14, has and COLORS.white or COLORS.muted, true)
        rowText(row, t.desc, UDim2.fromOffset(62, 29), UDim2.new(1, -200, 0, 16), 11, COLORS.muted)
        rowText(row, has and os.date("%Y-%m-%d", earned[t.id]) or "Locked", UDim2.new(1, -120, 0.5, -10), UDim2.fromOffset(108, 20), 11, COLORS.muted)
    end
end

local function refreshFriends()
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
            avatarCircle(row, f.Id, 10, 7, 40)
            rowButton(row, function() openPlayerOptions(f.Id, tostring(f.Username), tostring(f.DisplayName or f.Username)) end)
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
    clearList(partyScroll)
    local plist = Players:GetPlayers()
    pages.Party.title.Text = "Party  -  " .. #plist .. " in this server"
    for i, p in ipairs(plist) do
        local row = listRow(partyScroll, i, 54)
        avatarCircle(row, p.UserId, 10, 7, 40)
        rowButton(row, function() openPlayerOptions(p.UserId, p.Name, p.DisplayName) end)
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

local function refreshMessages()
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

local function pushChat(name, text)
    table.insert(chatLog, { name = tostring(name), text = tostring(text) })
    if #chatLog > 60 then table.remove(chatLog, 1) end
    if currentPage == "Messages" then refreshMessages() end
end

pcall(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        TextChatService.MessageReceived:Connect(function(msg)
            local src = msg.TextSource and Players:GetPlayerByUserId(msg.TextSource.UserId)
            pushChat(src and src.DisplayName or "System", msg.Text)
        end)
    else
        local function hook(p) p.Chatted:Connect(function(text) pushChat(p.DisplayName, text) end) end
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
local sendBtn = button(messagesPage, "Send", UDim2.fromOffset(64, 30), UDim2.fromOffset(W - 104, H - 82), COLORS.blue, 12)

local function sendChat()
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

sendBtn.Activated:Connect(function() playSound("Select"); sendChat() end)
msgBox.FocusLost:Connect(function(enter) if enter then sendChat() end end)

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

local runBtn = button(editorPage, "Run", UDim2.fromOffset(80, 30), UDim2.fromOffset(W - 370, H - 44), COLORS.blue, 12)
local clearBtn = button(editorPage, "Clear", UDim2.fromOffset(80, 30), UDim2.fromOffset(W - 280, H - 44), COLORS.card, 12)
local saveBtn = button(editorPage, "Save", UDim2.fromOffset(150, 30), UDim2.fromOffset(W - 190, H - 44), Color3.fromRGB(20, 120, 70), 12)

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

local function saveEditor()
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

runBtn.Activated:Connect(function() playSound("Select"); execScript(codeBox.Text) end)
clearBtn.Activated:Connect(function() playSound("Select"); codeBox.Text = "" end)
saveBtn.Activated:Connect(function() playSound("Select"); saveEditor() end)

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

local fb = make("Frame", {
    Size = UDim2.new(1, 0, 0, 90),
    BackgroundTransparency = 1, ZIndex = 5,
}, main)

local hintLabel = label(fb, "", UDim2.fromOffset(110, 16), UDim2.fromOffset(0, 62), 11, COLORS.white)
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.Visible = false

local functionItems = {
    { "♙", "Friends" }, { "◉", "Party" }, { "✉", "Messages" },
    { "♧", "Notifications" }, { "★", "Trophies" }, { "⚙", "Settings" }, { "⏻", "Power" },
}

for index, item in ipairs(functionItems) do
    local x = 40 + (index - 1) * 56
    local icon = make("TextButton", {
        Size = UDim2.fromOffset(40, 40),
        Position = UDim2.fromOffset(x, 18),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = item[1], Font = Enum.Font.GothamMedium,
        TextSize = 22, TextColor3 = COLORS.white,
    }, fb)
    circle(icon)
    local ring = stroke(icon, COLORS.white, 2, 1)
    local function showHint()
        icon.BackgroundTransparency = 0.88
        ring.Transparency = 0.15
        hintLabel.Text = item[2]
        hintLabel.Position = UDim2.fromOffset(x + 20 - 55, 62)
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
        elseif name == "Power" then openPowerPanel()
        elseif name == "Friends" then refreshFriends(); showPage("Friends")
        elseif name == "Party" then refreshParty(); showPage("Party")
        elseif name == "Messages" then refreshMessages(); showPage("Messages")
        elseif name == "Notifications" then refreshNotifications(); showPage("Notifications")
        elseif name == "Trophies" then refreshTrophies(); showPage("Trophies") end
    end)
end

local clock = label(main, "", UDim2.fromOffset(110, 34), UDim2.new(1, -176, 0, 17), 15, COLORS.white)
clock.TextXAlignment = Enum.TextXAlignment.Right
clock.ZIndex = 5

local clockBtn = make("TextButton", {
    Size = UDim2.fromOffset(110, 34),
    Position = UDim2.new(1, -176, 0, 17),
    BackgroundTransparency = 1, Text = "", ZIndex = 6,
}, main)
clockBtn.Activated:Connect(function()
    playSound("Select")
    notify(os.date("%A, %d %B %Y"))
end)

local avatar = make("ImageButton", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(1, -52, 0, 17),
    BackgroundColor3 = COLORS.card,
    BorderSizePixel = 0, Image = "", ZIndex = 5,
}, main)
circle(avatar)
stroke(avatar, COLORS.white, 1.5, 0.3)

task.spawn(function()
    local ok, url = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if ok and url and avatar.Parent then avatar.Image = url end
end)

task.spawn(function()
    while gui.Parent do
        clock.Text = (os.date("%I:%M %p"):gsub("^0", ""))
        task.wait(1)
    end
end)

local BASE, FOCUS, GAP = 92, 138, 12
local TILE_X, TILE_Y = 56, 112
local items = {}
local tiles = {}
local tileStrokes = {}
local focusIndex = 1

local halo = make("Frame", {
    Size = UDim2.fromOffset(FOCUS + 18, FOCUS + 18),
    Position = UDim2.fromOffset(TILE_X - 9, TILE_Y - 9),
    BackgroundColor3 = COLORS.white,
    BackgroundTransparency = 0.9,
    BorderSizePixel = 0, ZIndex = 3,
}, main)
round(halo, 8)

local nameLabel = label(main, "", UDim2.fromOffset(420, 26),
    UDim2.fromOffset(TILE_X, TILE_Y + FOCUS + 10), 17, COLORS.white)
nameLabel.ZIndex = 4
nameLabel.TextWrapped = false
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

local optionsButton = make("TextButton", {
    Size = UDim2.fromOffset(100, 22),
    Position = UDim2.fromOffset(TILE_X, TILE_Y + FOCUS + 38),
    BackgroundTransparency = 1,
    Text = "≡   Options",
    Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = COLORS.muted,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, main)
optionsButton.MouseEnter:Connect(function() optionsButton.TextColor3 = COLORS.white end)
optionsButton.MouseLeave:Connect(function() optionsButton.TextColor3 = COLORS.muted end)

local liveCards = {}
local cardWidth = (W - TILE_X * 2 - 12) / 2

for i = 1, 2 do
    local card = make("Frame", {
        Size = UDim2.fromOffset(cardWidth, 100),
        Position = UDim2.fromOffset(TILE_X + (i - 1) * (cardWidth + 12), 328),
        BackgroundColor3 = Color3.fromRGB(4, 14, 34),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0, ZIndex = 3,
    }, main)
    round(card, 6)
    stroke(card, COLORS.white, 1, 0.9)
    local title = label(card, "", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 10), 13, COLORS.white, true)
    local body = label(card, "", UDim2.new(1, -28, 0, 52), UDim2.fromOffset(14, 36), 12, COLORS.muted)
    body.TextYAlignment = Enum.TextYAlignment.Top
    liveCards[i] = { title = title, body = body }
end

local function updateLive(item)
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
    elseif item.kind == "store" then
        t1, b1 = "New releases", "Browse ScriptBlox by genre, keyless or with key."
        t2, b2 = "Library", slots
    else
        t1, b1 = "Your scripts", "Everything you downloaded."
        t2, b2 = "Storage", slots
    end
    liveCards[1].title.Text = t1
    liveCards[1].body.Text = b1
    liveCards[2].title.Text = t2
    liveCards[2].body.Text = b2
    liveCards[2].title.Parent.Visible = t2 ~= ""
end

local function layoutTiles(animate)
    for i, tile in ipairs(tiles) do
        local isFocus = i == focusIndex
        local size = isFocus and FOCUS or BASE
        local x
        if i < focusIndex then x = TILE_X - (focusIndex - i) * (BASE + GAP)
        elseif isFocus then x = TILE_X
        else x = TILE_X + FOCUS + GAP + (i - focusIndex - 1) * (BASE + GAP) end
        local gs = UDim2.fromOffset(size, size)
        local gp = UDim2.fromOffset(x, TILE_Y)
        if animate then
            tween(tile, 0.2, { Size = gs, Position = gp })
            tween(tileStrokes[i], 0.2, { Thickness = isFocus and 3 or 0 })
        else
            tile.Size = gs
            tile.Position = gp
            tileStrokes[i].Thickness = isFocus and 3 or 0
        end
    end
end

local function setFocus(index, silent)
    if #items == 0 then return end
    index = math.clamp(index, 1, #items)
    if index ~= focusIndex and not silent then playSound("Select") end
    focusIndex = index
    local item = items[focusIndex]
    nameLabel.Text = item.name
    optionsButton.Visible = true
    updateLive(item)
    layoutTiles(not silent)
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
    else showPage("Library") end
end

local function openStoreTileOptions()
    openPanel("PlayStation Store", {
        { "Open Store", function() openStore() end },
        { "View Downloads", function() refreshNotifications(); showPage("Notifications") end },
        { "Cancel" },
    })
end

local function openLibraryTileOptions()
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

local function openEmptyOptions()
    openPanel("Empty Slot", {
        { "Write Own Script", function() openEditor() end },
        { "Get Scripts (Open Store)", function() openStore() end },
        { "Cancel" },
    })
end

local function optionsForFocus()
    local item = items[focusIndex]
    if not item then return end
    if item.kind == "script" then openScriptOptions(item.id)
    elseif item.kind == "download" then openDownloadOptions(item.id)
    elseif item.kind == "store" then openStoreTileOptions()
    elseif item.kind == "library" then openLibraryTileOptions()
    else openEmptyOptions() end
end

optionsButton.Activated:Connect(function() playSound("Select"); optionsForFocus() end)

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

local lastEmptyTap = 0

local function rebuildHome()
    for _, t in ipairs(tiles) do t:Destroy() end
    tiles = {}
    tileStrokes = {}
    items = {}
    tileProgress = {}

    table.insert(items, { kind = "store", name = "PlayStation Store" })
    local used = 0
    for _, row in ipairs(sortedLibrary()) do
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
    table.insert(items, { kind = "library", name = "Library" })

    for i, item in ipairs(items) do
        local color, text
        if item.kind == "script" or item.kind == "download" then color, text = colorFor(item.name), shortText(item.name, 18)
        elseif item.kind == "store" then color, text = Color3.fromRGB(10, 90, 180), "PlayStation\nStore"
        elseif item.kind == "empty" then color, text = Color3.fromRGB(16, 34, 70), ""
        else color, text = COLORS.grey, "Library" end
        local tile = makeCover(main, "TextButton", color, text)
        tile.Name = "Tile" .. i
        tile.ZIndex = 4
        local imgPath, gid
        if item.kind == "script" and library[item.id] then
            imgPath, gid = library[item.id].img, library[item.id].gameId
        elseif item.kind == "download" and dlState[item.id] then
            imgPath, gid = dlState[item.id].data.img, dlState[item.id].data.gameId
        end
        if imgPath or gid then attachImage(tile, imgPath, gid) end
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
            else
                playSound("Select")
                activateFocus()
            end
        end)
        tiles[i] = tile
    end

    focusIndex = math.clamp(focusIndex, 1, #items)
    setFocus(focusIndex, true)
end

local libFilter = "all"
local libCats = {
    { id = "all", name = "All" },
    { id = "keyless", name = "Keyless" },
    { id = "key", name = "Key Required" },
}
local catButtons = {}
local refreshLibrary

local sidebar = make("Frame", {
    Size = UDim2.fromOffset(170, 200),
    Position = UDim2.fromOffset(40, 84),
    BackgroundTransparency = 1,
}, libraryPage)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)

for i, cat in ipairs(libCats) do
    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = i == 1 and 0.88 or 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = cat.name,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham, TextSize = 14,
        TextColor3 = COLORS.white,
        LayoutOrder = i,
    }, sidebar)
    make("UIPadding", { PaddingLeft = UDim.new(0, 14) }, b)
    round(b, 4)
    catButtons[cat.id] = b
    b.Activated:Connect(function()
        playSound("Select")
        libFilter = cat.id
        refreshLibrary()
    end)
end

local libList = make("ScrollingFrame", {
    Size = UDim2.fromOffset(W - 270, 300),
    Position = UDim2.fromOffset(230, 84),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = COLORS.muted,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, libraryPage)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, libList)

local storageLabel = label(libraryPage, "", UDim2.fromOffset(300, 20), UDim2.fromOffset(230, H - 40), 12, COLORS.muted)
local libEmpty = label(libraryPage, "Nothing here yet. Download scripts from the PlayStation Store.",
    UDim2.fromOffset(400, 30), UDim2.fromOffset(250, 150), 14, COLORS.muted)

refreshLibrary = function()
    for _, c in ipairs(libList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    local counts = { all = 0, keyless = 0, key = 0 }
    local list = sortedLibrary()
    for _, row in ipairs(list) do
        counts.all += 1
        if row.entry.key then counts.key += 1 else counts.keyless += 1 end
    end
    for _, cat in ipairs(libCats) do
        local b = catButtons[cat.id]
        b.Text = cat.name .. "  (" .. counts[cat.id] .. ")"
        b.BackgroundTransparency = cat.id == libFilter and 0.88 or 1
    end
    storageLabel.Text = "Storage: " .. libraryCount() .. " / " .. MAX_STORAGE .. " slots used"

    local shown = 0
    for _, row in ipairs(list) do
        local id, e = row.id, row.entry
        local match = libFilter == "all"
            or (libFilter == "keyless" and not e.key)
            or (libFilter == "key" and e.key)
        if match then
            shown += 1
            local item = make("TextButton", {
                Size = UDim2.new(1, -12, 0, 64),
                BackgroundColor3 = COLORS.white,
                BackgroundTransparency = 0.94,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = shown,
            }, libList)
            round(item, 4)
            local ring = stroke(item, COLORS.white, 2, 1)
            item.MouseEnter:Connect(function() item.BackgroundTransparency = 0.88; ring.Transparency = 0.1 end)
            item.MouseLeave:Connect(function() item.BackgroundTransparency = 0.94; ring.Transparency = 1 end)

            local cover = makeCover(item, "Frame", colorFor(e.title), shortText(e.title, 10))
            cover.Size = UDim2.fromOffset(52, 52)
            cover.Position = UDim2.fromOffset(6, 6)
            if e.img or e.gameId then attachImage(cover, e.img, e.gameId) end

            local t = label(item, tostring(e.title or "Script"), UDim2.new(1, -200, 0, 22), UDim2.fromOffset(70, 10), 14, COLORS.white, true)
            t.TextWrapped = false
            t.TextTruncate = Enum.TextTruncate.AtEnd

            local sub = label(item,
                (e.key and "Key required" or "Keyless") .. "  |  " .. tostring(e.game or "Universal")
                    .. "  |  " .. os.date("%Y-%m-%d", e.downloadedAt or 0),
                UDim2.new(1, -200, 0, 18), UDim2.fromOffset(70, 34), 11, COLORS.muted)
            sub.TextWrapped = false
            sub.TextTruncate = Enum.TextTruncate.AtEnd

            local opt = make("TextButton", {
                Size = UDim2.fromOffset(90, 28),
                Position = UDim2.new(1, -102, 0.5, -14),
                BackgroundColor3 = COLORS.card,
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                Text = "≡  Options",
                Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = COLORS.white,
                AutoButtonColor = true,
            }, item)
            round(opt, 6)

            item.Activated:Connect(function() playSound("Select"); execScript(e.code) end)
            opt.Activated:Connect(function() playSound("Select"); openScriptOptions(id) end)
        end
    end

    libEmpty.Visible = shown == 0
end

local SB_FETCH = "https://scriptblox.com/api/script/fetch"
local SB_SEARCH = "https://scriptblox.com/api/script/search"

local GENRES = {
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

local KEY_STATES = { "any", "keyless", "key" }
local KEY_LABELS = { any = "Key: Any", keyless = "Keyless", key = "Key Required" }

local sbMode = "recent"
local sbKey = "any"
local sbVerified = false
local sbGenre = 1
local sbQuery = ""
local sbPage = 1
local sbToken = 0
local storeLoaded = false
local storeCardRefs = {}

local sbScroll = make("ScrollingFrame", {
    Size = UDim2.fromOffset(W - 60, 244),
    Position = UDim2.fromOffset(30, 150),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = COLORS.muted,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, storePage)

make("UIGridLayout", {
    CellSize = UDim2.fromOffset(150, 184),
    CellPadding = UDim2.fromOffset(14, 14),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sbScroll)

local statusLabel = label(storePage, "", UDim2.fromOffset(300, 30), UDim2.fromOffset(250, 240), 14, COLORS.muted)
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Visible = false

label(storePage, "Powered by ScriptBlox.com", UDim2.fromOffset(190, 20), UDim2.fromOffset(180, H - 38), 10, COLORS.muted)

local pageLabel = label(storePage, "Page 1", UDim2.fromOffset(60, 24), UDim2.fromOffset(W - 170, H - 42), 11, COLORS.white)
pageLabel.TextXAlignment = Enum.TextXAlignment.Center

local function buildUrl()
    local q = sbQuery ~= "" and sbQuery or GENRES[sbGenre].keyword
    local params = "max=20&page=" .. sbPage .. "&mode=free"
    if sbMode == "most-viewed" then params ..= "&sortBy=views&order=desc"
    elseif sbMode == "most-liked" then params ..= "&sortBy=likeCount&order=desc" end
    if sbVerified then params ..= "&verified=1" end
    if q ~= "" then
        return SB_SEARCH .. "?q=" .. HttpService:UrlEncode(q) .. "&" .. params
    end
    return SB_FETCH .. "?" .. params
end

local function passes(s)
    if sbKey == "keyless" and s.key == true then return false end
    if sbKey == "key" and s.key ~= true then return false end
    if sbVerified and s.verified ~= true then return false end
    if GENRES[sbGenre].universal then
        local gname = (type(s.game) == "table" and s.game.name) and tostring(s.game.name):lower() or "universal"
        if not (s.isUniversal == true or gname:find("universal")) then return false end
    end
    return true
end

local function clearStoreCards()
    storeCardRefs = {}
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
    clearStoreCards()
    setStatus("Loading ScriptBlox...")
    pageLabel.Text = "Page " .. sbPage

    task.spawn(function()
        local url = buildUrl()

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
            notify("ScriptBlox unreachable: " .. why)
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
            if passes(s) then table.insert(list, s) end
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

        for index, s in ipairs(list) do
            local title = tostring(s.title or "Untitled")
            local gameName = "Universal"
            if type(s.game) == "table" and s.game.name then gameName = tostring(s.game.name) end
            local code = tostring(s.script or s.rawScript or "")
            local views = tonumber(s.views) or 0
            local verified = s.verified == true
            local needsKey = s.key == true
            local sid = tostring(s._id or s.slug or ("t_" .. title))
            local imgPath = pickImage(s)
            local gameId = type(s.game) == "table" and s.game.gameId or nil
            local dlData = { title = title, game = gameName, code = code, key = needsKey, views = views, img = imgPath, gameId = gameId, slug = s.slug }

            local card = make("Frame", {
                BackgroundColor3 = COLORS.card,
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                LayoutOrder = index,
            }, sbScroll)
            round(card, 6)

            local coverColor = verified and Color3.fromRGB(20, 100, 60) or Color3.fromRGB(30, 60, 110)
            local cover = makeCover(card, "TextButton", coverColor, shortText(title, 20))
            cover.Size = UDim2.new(1, -12, 0, 90)
            cover.Position = UDim2.fromOffset(6, 6)
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

            local badge = make("TextLabel", {
                Size = UDim2.fromOffset(needsKey and 34 or 52, 14),
                Position = UDim2.new(1, -4, 0, 4),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = needsKey and Color3.fromRGB(150, 100, 20) or Color3.fromRGB(20, 120, 70),
                BorderSizePixel = 0,
                Text = needsKey and "KEY" or "KEYLESS",
                Font = Enum.Font.GothamBold, TextSize = 8,
                TextColor3 = COLORS.white, ZIndex = 3,
            }, cover)
            round(badge, 3)

            local tl = label(card, title, UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 100), 10, COLORS.white, true)
            tl.TextWrapped = false
            tl.TextTruncate = Enum.TextTruncate.AtEnd

            local gl = label(card, gameName, UDim2.new(1, -12, 0, 14), UDim2.fromOffset(6, 118), 9, COLORS.muted)
            gl.TextWrapped = false
            gl.TextTruncate = Enum.TextTruncate.AtEnd

            label(card, views .. " views" .. (verified and "  |  verified" or ""),
                UDim2.new(1, -12, 0, 12), UDim2.fromOffset(6, 134), 8, COLORS.muted)

            local has = isDownloaded(sid)
            local dl = button(card, has and "In Library" or "Download", UDim2.new(1, -12, 0, 24),
                UDim2.fromOffset(6, 150), has and COLORS.grey or COLORS.blue, 10)
            storeCardRefs[sid] = dl
            refreshStoreButtons()
            dl.Activated:Connect(function()
                playSound("Select")
                if isDownloaded(sid) then notify("Already in library") return end
                downloadScript(sid, dlData)
            end)
        end
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
    if not storeLoaded then
        storeLoaded = true
        fetchStore()
    end
end

local function styleTab(btn, active)
    btn.BackgroundColor3 = active and COLORS.blue or COLORS.card
    btn.BackgroundTransparency = active and 0 or 0.5
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

local tabDefs = {
    { id = "recent", label = "New" },
    { id = "most-viewed", label = "Trending" },
    { id = "most-liked", label = "Top" },
}
local tabButtons = {}
for i, tab in ipairs(tabDefs) do
    local b = makeSmallButton(tab.label, 40 + (i - 1) * 86, 80)
    styleTab(b, i == 1)
    tabButtons[tab.id] = b
    b.Activated:Connect(function()
        playSound("Select")
        sbMode = tab.id
        sbPage = 1
        for tid, btn in pairs(tabButtons) do styleTab(btn, tid == sbMode) end
        fetchStore()
    end)
end

local keyBtn = makeSmallButton(KEY_LABELS[sbKey], 300, 110)
keyBtn.Activated:Connect(function()
    playSound("Select")
    local idx = table.find(KEY_STATES, sbKey) or 1
    sbKey = KEY_STATES[idx % #KEY_STATES + 1]
    keyBtn.Text = KEY_LABELS[sbKey]
    styleTab(keyBtn, sbKey ~= "any")
    sbPage = 1
    fetchStore()
end)

local verBtn = makeSmallButton("Verified: Off", 416, 100)
verBtn.Activated:Connect(function()
    playSound("Select")
    sbVerified = not sbVerified
    verBtn.Text = sbVerified and "Verified: On" or "Verified: Off"
    styleTab(verBtn, sbVerified)
    sbPage = 1
    fetchStore()
end)

local searchBox = make("TextBox", {
    Size = UDim2.new(0, 220, 0, 28),
    Position = UDim2.new(1, -260, 0, 78),
    BackgroundColor3 = COLORS.card,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Search ScriptBlox...",
    PlaceholderColor3 = COLORS.muted,
    TextColor3 = COLORS.white,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
}, storePage)
round(searchBox, 6)
stroke(searchBox, COLORS.white, 1, 0.85)

searchBox.FocusLost:Connect(function(enter)
    if enter then
        sbQuery = searchBox.Text
        sbPage = 1
        unlockTrophy("searcher")
        fetchStore()
    end
end)

local chipRow = make("ScrollingFrame", {
    Size = UDim2.fromOffset(W - 80, 28),
    Position = UDim2.fromOffset(40, 114),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.X,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.X,
}, storePage)
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, chipRow)

local chips = {}
for i, g in ipairs(GENRES) do
    local chip = make("TextButton", {
        Size = UDim2.fromOffset(math.max(56, #g.name * 8 + 22), 24),
        BackgroundColor3 = i == 1 and COLORS.blue or COLORS.card,
        BackgroundTransparency = i == 1 and 0 or 0.5,
        BorderSizePixel = 0,
        Text = g.name,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = COLORS.white,
        AutoButtonColor = false,
        LayoutOrder = i,
    }, chipRow)
    circle(chip)
    chips[i] = chip
    chip.Activated:Connect(function()
        playSound("Select")
        sbGenre = i
        unlockTrophy("explorer")
        sbQuery = ""
        searchBox.Text = ""
        sbPage = 1
        for j, c in ipairs(chips) do styleTab(c, j == sbGenre) end
        fetchStore()
    end)
end

local prevBtn = button(storePage, "‹ Prev", UDim2.fromOffset(56, 24), UDim2.fromOffset(W - 232, H - 42), COLORS.card, 11)
local nextBtn = button(storePage, "Next ›", UDim2.fromOffset(56, 24), UDim2.fromOffset(W - 104, H - 42), COLORS.card, 11)
prevBtn.Activated:Connect(function()
    if sbPage > 1 then sbPage -= 1; fetchStore() else notify("First page") end
end)
nextBtn.Activated:Connect(function()
    sbPage += 1
    fetchStore()
end)

local function resolveScriptCode(data)
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

local function runDownloads()
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
                    local fetched, err = resolveScriptCode(st.data)
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
                    notify("Download failed: " .. tostring(st.err))
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
    runDownloads()
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
    { name = "Blue Wave", a = Color3.fromRGB(5, 22, 60), b = Color3.fromRGB(14, 68, 142), c = Color3.fromRGB(4, 30, 82), wave = Color3.fromRGB(90, 165, 240) },
    { name = "Midnight", a = Color3.fromRGB(3, 6, 18), b = Color3.fromRGB(18, 28, 70), c = Color3.fromRGB(2, 8, 26), wave = Color3.fromRGB(70, 110, 190) },
    { name = "Crimson", a = Color3.fromRGB(40, 6, 12), b = Color3.fromRGB(120, 24, 40), c = Color3.fromRGB(30, 4, 12), wave = Color3.fromRGB(230, 100, 120) },
    { name = "Forest", a = Color3.fromRGB(4, 28, 20), b = Color3.fromRGB(14, 100, 72), c = Color3.fromRGB(4, 34, 26), wave = Color3.fromRGB(90, 220, 170) },
    { name = "Violet", a = Color3.fromRGB(24, 8, 56), b = Color3.fromRGB(80, 40, 150), c = Color3.fromRGB(18, 6, 46), wave = Color3.fromRGB(170, 130, 240) },
}

local function applyTheme(idx)
    local t = THEMES[idx] or THEMES[1]
    local seq = ColorSequence.new({
        ColorSequenceKeypoint.new(0, t.a),
        ColorSequenceKeypoint.new(0.55, t.b),
        ColorSequenceKeypoint.new(1, t.c),
    })
    bgGradient.Color = seq
    for _, g in ipairs(pageGradients) do g.Color = seq end
    for _, w in ipairs(waves) do w.BackgroundColor3 = t.wave end
end

local function openThemePanel()
    local entries = {}
    for i, t in ipairs(THEMES) do
        table.insert(entries, { (settings.theme == i and "●  " or "○  ") .. t.name, function()
            settings.theme = i
            applyTheme(i)
            saveSettings()
            notify("Theme: " .. t.name)
            unlockTrophy("themer")
        end })
    end
    table.insert(entries, { "Cancel" })
    openPanel("Themes", entries)
end

local function openSoundPanel()
    openPanel("Sound and Screen", {
        { "Sound Effects: " .. (settings.sound and "On" or "Off"), function()
            settings.sound = not settings.sound
            saveSettings()
            notify("Sound effects " .. (settings.sound and "on" or "off"))
        end },
        { "Volume: " .. math.floor(settings.volume * 100 + 0.5) .. "%", function()
            local v = settings.volume + 0.2
            if v > 1.01 then v = 0.2 end
            settings.volume = math.floor(v * 10 + 0.5) / 10
            saveSettings()
            notify("Volume " .. math.floor(settings.volume * 100 + 0.5) .. "%")
        end },
        { "Cancel" },
    })
end

local function openToastPanel()
    openPanel("Notifications", {
        { "Pop-ups: " .. (settings.toasts and "On" or "Off"), function()
            settings.toasts = not settings.toasts
            saveSettings()
            if settings.toasts then notify("Pop-up notifications on") end
        end },
        { "Clear Notification List", function() notifyLog = {} end },
        { "Cancel" },
    })
end

checkForUpdate = function(id)
    local e = library[id]
    if not e then return end
    notify("Checking for update...")
    task.spawn(function()
        local found
        local q = HttpService:UrlEncode(tostring(e.title))
        for _, base in ipairs({ SB_SEARCH, SB_FETCH }) do
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
        if not library[id] then return end
        if not found then notify("No update information found") return end
        local newCode = resolveScriptCode({ code = tostring(found.script or found.rawScript or ""), slug = found.slug }) or ""
        if newCode ~= "" and newCode ~= e.code then
            e.code = newCode
            saveLibrary()
            notify("Updated: " .. tostring(e.title))
        else
            notify("No update available")
        end
    end)
end

local function openImagePanel()
    openPanel("Store Images", {
        { "ScriptBlox Images: " .. (settings.images and "On" or "Off"), function()
            settings.images = not settings.images
            saveSettings()
            notify("Store images " .. (settings.images and "on" or "off"))
        end },
        { "Cancel" },
    })
end

local function showNetwork()
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

local function showAccount()
    showInfo("Account Management", string.format(
        "Display name: %s\nUsername: @%s\nUser ID: %d\nAccount age: %d days\nMembership: %s",
        player.DisplayName, player.Name, player.UserId, player.AccountAge, player.MembershipType.Name))
end

avatar.Activated:Connect(function()
    playSound("Select")
    showAccount()
end)

local function showSystem()
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

local settingNames = {
    "Notifications", "Sound and Screen", "Themes", "Storage",
    "Store Images", "Network", "Account Management", "System", "Power",
}

local settingsScroll = make("ScrollingFrame", {
    Size = UDim2.fromOffset(W - 80, H - 150),
    Position = UDim2.fromOffset(40, 84),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = COLORS.muted,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, settingsPage)

make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, settingsScroll)

local function deleteAll()
    for id in pairs(library) do library[id] = nil end
    saveLibrary()
    notify("Library cleared")
    refreshLocal()
end

for index, name in ipairs(settingNames) do
    local row = make("TextButton", {
        Size = UDim2.new(1, -12, 0, 46),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 0.94,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = index,
    }, settingsScroll)
    round(row, 4)
    local o = stroke(row, COLORS.white, 2, 1)
    label(row, name, UDim2.new(1, -70, 1, 0), UDim2.fromOffset(18, 0), 15, COLORS.white)
    local chev = label(row, "›", UDim2.fromOffset(30, 46), UDim2.new(1, -44, 0, 0), 22, COLORS.muted)
    chev.TextXAlignment = Enum.TextXAlignment.Center
    row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.88; o.Transparency = 0.1 end)
    row.MouseLeave:Connect(function() row.BackgroundTransparency = 0.94; o.Transparency = 1 end)
    row.Activated:Connect(function()
        playSound("Select")
        if name == "Themes" then openThemePanel()
        elseif name == "Storage" then
            openPanel("Storage " .. libraryCount() .. "/" .. MAX_STORAGE, {
                { "Open Library", function() showPage("Library") end },
                { "Delete All Scripts", function()
                    openPanel("Delete everything?", {
                        { "Delete All", deleteAll },
                        { "Cancel" },
                    })
                end },
                { "Cancel" },
            })
        elseif name == "Sound and Screen" then openSoundPanel()
        elseif name == "Power" then openPowerPanel()
        elseif name == "Notifications" then openToastPanel()
        elseif name == "Store Images" then openImagePanel()
        elseif name == "Network" then showNetwork()
        elseif name == "Account Management" then showAccount()
        elseif name == "System" then showSystem() end
    end)
end

refreshLocal = function()
    rebuildHome()
    refreshLibrary()
    if refreshStoreButtons then refreshStoreButtons() end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or minimized or not gui.Parent then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.Backspace or k == Enum.KeyCode.ButtonB then
        if panelOpen then closePanel()
        elseif currentPage then goHome() end
        return
    end
    if panelOpen or currentPage then return end
    if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then setFocus(focusIndex - 1)
    elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then setFocus(focusIndex + 1)
    elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then activateFocus()
    elseif k == Enum.KeyCode.O or k == Enum.KeyCode.ButtonX then optionsForFocus() end
end)

local grip = make("TextButton", {
    Size = UDim2.fromOffset(140, 18),
    Position = UDim2.new(0.5, -70, 0, 0),
    BackgroundTransparency = 1, Text = "", ZIndex = 55,
}, main)

local gripPill = make("Frame", {
    Size = UDim2.fromOffset(46, 4),
    Position = UDim2.new(0.5, -23, 0, 6),
    BackgroundColor3 = COLORS.white,
    BackgroundTransparency = 0.7,
    BorderSizePixel = 0, ZIndex = 56,
}, main)
round(gripPill, 2)

local dragging, dragStart, startPosition = false, nil, nil

grip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + d.X,
            startPosition.Y.Scale, startPosition.Y.Offset + d.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- PS button (shown while the dashboard is hidden)
local restoreButton = button(gui, "PS", UDim2.fromOffset(54, 54), UDim2.new(1, -76, 1, -92), Color3.fromRGB(10, 44, 100), 17)
restoreButton.Font = Enum.Font.GothamBold
restoreButton.Visible = false
restoreButton.AutoButtonColor = false
circle(restoreButton)
local psRing = stroke(restoreButton, COLORS.white, 2, 0.25)
TweenService:Create(psRing,
    TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Transparency = 0.85 }):Play()

local psHint = label(restoreButton, "Press " .. TOGGLE_KEY.Name,
    UDim2.fromOffset(120, 14), UDim2.new(0.5, -60, 1, 6), 10, COLORS.muted)
psHint.TextXAlignment = Enum.TextXAlignment.Center

local animationBusy = false

local function baseScale()
    local cam = workspace.CurrentCamera
    if not cam then return 1 end
    local v = cam.ViewportSize
    return math.clamp(math.min((v.X - 16) / W, (v.Y - 32) / H), 0.45, 1.4)
end

-- Hide: the whole dashboard fades out while zooming out slightly
minimizeDashboard = function()
    if minimized or animationBusy then return end
    animationBusy = true
    minimized = true
    closePanel()
    playSound("Close")
    local base = baseScale()
    tween(uiScale, 0.3, { Scale = base * 0.9 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    local fade = tween(main, 0.3, { GroupTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    fade.Completed:Wait()
    if not gui.Parent then return end
    main.Visible = false
    uiScale.Scale = base
    restoreButton.Visible = true
    animationBusy = false
end

-- Show: fades back in and zooms to full size
local function restoreDashboard()
    if not minimized or animationBusy then return end
    animationBusy = true
    restoreButton.Visible = false
    local base = baseScale()
    uiScale.Scale = base * 0.9
    main.GroupTransparency = 1
    main.Visible = true
    playSound("Open")
    playSound("Home")
    tween(uiScale, 0.35, { Scale = base }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local fade = tween(main, 0.35, { GroupTransparency = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    fade.Completed:Wait()
    if not gui.Parent then return end
    minimized = false
    animationBusy = false
end

local function toggleDashboard()
    if minimized then restoreDashboard() else minimizeDashboard() end
end

restoreButton.Activated:Connect(restoreDashboard)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not gui.Parent then return end
    if input.KeyCode == TOGGLE_KEY or input.KeyCode == Enum.KeyCode.ButtonSelect then
        toggleDashboard()
    end
end)

applyTheme(settings.theme)
refreshLocal()
playSound("Login")
playSound("Home")

if canWrite() then
    notify("Dashboard ready - library " .. libraryCount() .. "/" .. MAX_STORAGE)
else
    notify("Warning: no file API, downloads won't persist")
end
