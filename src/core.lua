return function(S, ctx)
    local game = game
    local task = task
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local SoundService = game:GetService("SoundService")
    local player = Players.LocalPlayer

    S.COLORS = {
        white = Color3.fromRGB(255, 255, 255),
        muted = Color3.fromRGB(165, 188, 220),
        blue = Color3.fromRGB(0, 112, 209),
        dark = Color3.fromRGB(6, 20, 48),
        card = Color3.fromRGB(12, 34, 72),
        line = Color3.fromRGB(76, 137, 220),
        danger = Color3.fromRGB(140, 40, 40),
        grey = Color3.fromRGB(70, 82, 125),
    }

    S.settings = {
        sound = true,
        volume = 0.6,
        toasts = true,
        theme = 1,
        images = true,
        hideOnStart = true,
        uiscale = 1,
    }
    S.earned = {}
    S.SOUND_IDS = {
        Select = "rbxassetid://124400323975890",
        Login = "rbxassetid://123072435492721",
        Open = "rbxassetid://134203002406032",
        Close = "rbxassetid://88440088035194",
        Notify = "rbxassetid://84711905220990",
        Home = "rbxassetid://126928354906604",
    }
    S.httpLog = {}
    S.IMG_PREFIX = "ps4_img_"
    S.imgFailed = {}
    S.iconCache, S.iconFailed = {}, {}
    S.pageGradients = {}
    S.waves = {}
    S.pages = {}
    S.backTarget = { SettingsList = "Settings" }
    S.currentPage = nil
    S.panelOpen = false
    S.notifyLog = {}
    S.menuOpen = false

    local function make(className, props, parent)
        local obj = Instance.new(className)
        for key, value in pairs(props or {}) do
            obj[key] = value
        end
        obj.Parent = parent
        return obj
    end

    local function round(obj, radius)
        make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, obj)
    end

    local function circle(obj)
        make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, obj)
    end

    local function stroke(obj, color, thickness, transparency)
        return make("UIStroke", {
            Color = color or S.COLORS.white,
            Thickness = thickness or 1,
            Transparency = transparency or 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, obj)
    end

    local function tween(obj, duration, goal, style, direction)
        local t = TweenService:Create(
            obj,
            TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
            goal
        )
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
            TextColor3 = color or S.COLORS.white,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true,
        }, parent)
    end

    local function button(parent, text, size, pos, color, ts)
        local obj = make("TextButton", {
            Size = size,
            Position = pos,
            BackgroundColor3 = color or S.COLORS.card,
            BorderSizePixel = 0,
            Text = text,
            TextColor3 = S.COLORS.white,
            TextSize = ts or 12,
            Font = Enum.Font.GothamMedium,
            TextWrapped = true,
            AutoButtonColor = true,
        }, parent)
        round(obj, 5)
        return obj
    end

    local function playSound(name)
        local id = S.SOUND_IDS[name]
        if not id or not S.settings.sound then return end
        task.spawn(function()
            local s = Instance.new("Sound")
            s.Name = "PS4_" .. name
            s.SoundId = id
            s.Volume = S.settings.volume
            s.Parent = SoundService
            local ok = pcall(function() s:Play() end)
            if not ok then s:Destroy(); return end
            s.Ended:Connect(function() s:Destroy() end)
            task.delay(15, function() if s.Parent then s:Destroy() end end)
        end)
    end

    local function httpGet(url)
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        table.insert(S.httpLog, 1, { url = url, ok = ok, err = not ok and tostring(res) or nil, time = os.time() })
        if #S.httpLog > 30 then table.remove(S.httpLog) end
        if not ok then error(res, 0) end
        return res
    end

    local function notify(msg)
        table.insert(S.notifyLog, 1, { text = tostring(msg), time = os.time() })
        if #S.notifyLog > 40 then table.remove(S.notifyLog) end
        if not S.settings.toasts then return end
        playSound("Notify")
        local main = S.main
        if not main then return end
        local prev = main:FindFirstChild("PS4Toast")
        if prev then prev:Destroy() end
        local toast = make("Frame", {
            Name = "PS4Toast",
            Size = UDim2.fromOffset(300, 56),
            Position = UDim2.fromOffset(-320, 14),
            BackgroundColor3 = Color3.fromRGB(228, 233, 241),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 60,
        }, main)
        local ink = Color3.fromRGB(44, 56, 84)
        local hold = make("Frame", {
            Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(14, 13),
            BackgroundTransparency = 1, ZIndex = 61,
        }, toast)
        S.icon("square", hold, 13, ink, UDim2.fromOffset(0, 0))
        S.icon("triangle", hold, 13, ink, UDim2.fromOffset(17, 0))
        S.icon("cross", hold, 13, ink, UDim2.fromOffset(0, 17))
        S.icon("circle", hold, 13, ink, UDim2.fromOffset(17, 17))
        local m = label(toast, tostring(msg), UDim2.new(1, -66, 1, -8), UDim2.fromOffset(56, 4), 14, ink)
        m.ZIndex = 61
        m.TextTruncate = Enum.TextTruncate.AtEnd
        tween(toast, 0.3, { Position = UDim2.fromOffset(16, 14) })
        task.delay(3, function()
            if toast.Parent then
                tween(toast, 0.25, { Position = UDim2.fromOffset(-320, 14) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.delay(0.3, function() if toast.Parent then toast:Destroy() end end)
            end
        end)
    end

    S.make, S.round, S.circle, S.stroke, S.tween, S.label, S.button, S.playSound, S.notify =
        make, round, circle, stroke, tween, label, button, playSound, notify
    S.httpGet = httpGet
    S.UserInputService = UserInputService
    S.TweenService = TweenService
    S.HttpService = HttpService
    S.Players = Players
    S.SoundService = SoundService
    S.Player = player
    S.W, S.H = 800, 450
    ctx.make, ctx.round, ctx.circle, ctx.stroke, ctx.tween, ctx.label, ctx.button =
        make, round, circle, stroke, tween, label, button
    ctx.playSound = playSound
    ctx.notify = notify
    ctx.COLORS = S.COLORS
    ctx.settings = S.settings
    ctx.W, ctx.H = S.W, S.H
    ctx.main = nil
    ctx.gui = nil
    ctx.Player = player
    ctx.Players = Players
    ctx.TweenService = TweenService
    ctx.UserInputService = UserInputService
    ctx.HttpService = HttpService
    return S
end
