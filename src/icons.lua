return function(S, ctx)
    local function make(class, props, parent)
        local obj = Instance.new(class)
        for key, value in pairs(props or {}) do
            obj[key] = value
        end
        obj.Parent = parent
        return obj
    end

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

    function S.icon(name, parent, size, color, pos)
        color = color or S.COLORS.white
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
                    Color = color,
                    Thickness = o.th or th,
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
        local function dot(cx, cy, d)
            return px(cx, cy, d, d, { fill = true, r = 0.5 })
        end
        local draw = S.iconDraw[name]
        if draw then draw(px, bar, dot, th / size, th) end
        return box
    end

    S.iconForText = function(t)
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

    ctx.make = make
    return S
end
