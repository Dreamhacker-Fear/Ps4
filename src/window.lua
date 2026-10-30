return function(S, ctx)
    local TweenService = game:GetService("TweenService")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local W, H = S.W, S.H

    S.playerGui = player:WaitForChild("PlayerGui")
    S.gui = Instance.new("ScreenGui")
    S.gui.Name = "PS4Dashboard"
    S.gui.ResetOnSpawn = false
    S.gui.DisplayOrder = 999
    S.gui.IgnoreGuiInset = true
    S.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    S.gui.Parent = S.playerGui

    S.main = Instance.new("CanvasGroup")
    S.main.Name = "Dashboard"
    S.main.AnchorPoint = Vector2.new(0.5, 0.5)
    S.main.Size = UDim2.fromOffset(W, H)
    S.main.Position = UDim2.fromScale(0.5, 0.5)
    S.main.BackgroundColor3 = S.COLORS.dark
    S.main.BorderSizePixel = 0
    S.main.ClipsDescendants = true
    S.main.Parent = S.gui
    S.round(S.main, 12)
    S.stroke(S.main, S.COLORS.line, 1, 0.3)

    S.bg = Instance.new("Frame")
    S.bg.Size = UDim2.fromScale(1, 1)
    S.bg.BackgroundColor3 = Color3.new(1, 1, 1)
    S.bg.BorderSizePixel = 0
    S.bg.ZIndex = 0
    S.bg.Parent = S.main
    S.bgGradient = Instance.new("UIGradient")
    S.bgGradient.Rotation = 100
    S.bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 76, 178)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(6, 62, 160)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 40, 118)),
    })
    S.bgGradient.Parent = S.bg

    S.backdrop = Instance.new("Frame")
    S.backdrop.Name = "Backdrop"
    S.backdrop.Size = UDim2.fromScale(1, 1)
    S.backdrop.BackgroundColor3 = S.COLORS.dark
    S.backdrop.BackgroundTransparency = 1
    S.backdrop.BorderSizePixel = 0
    S.backdrop.Visible = false
    S.backdrop.ZIndex = -1
    S.backdrop.Parent = S.gui

    S.maximized = false
    S.minimized = false
    S.savedPos = UDim2.fromScale(0.5, 0.5)
    S.uiScale = Instance.new("UIScale")
    S.uiScale.Scale = 1
    S.uiScale.Parent = S.main

    function S.updateScale()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local v = cam.ViewportSize
        if S.maximized then
            S.uiScale.Scale = math.max(0.4, math.min(v.X / W, v.Y / H))
            return
        end
        S.uiScale.Scale = math.clamp(math.min((v.X - 16) / W, (v.Y - 32) / H) * (S.settings.uiscale or 1), 0.4, 1.6)
    end

    function S.baseScale()
        local cam = workspace.CurrentCamera
        if not cam then return 1 end
        local v = cam.ViewportSize
        if S.maximized then return math.max(0.4, math.min(v.X / W, v.Y / H)) end
        return math.clamp(math.min((v.X - 16) / W, (v.Y - 32) / H) * (S.settings.uiscale or 1), 0.4, 1.6)
    end

    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            S.updateScale()
        end)
    end

    S.grip = Instance.new("TextButton")
    S.grip.Size = UDim2.fromOffset(140, 18)
    S.grip.Position = UDim2.new(0.5, -70, 0, 0)
    S.grip.BackgroundTransparency = 1
    S.grip.Text = ""
    S.grip.ZIndex = 55
    S.grip.Parent = S.main

    S.gripPill = Instance.new("Frame")
    S.gripPill.Size = UDim2.fromOffset(46, 4)
    S.gripPill.Position = UDim2.new(0.5, -23, 0, 6)
    S.gripPill.BackgroundColor3 = S.COLORS.white
    S.gripPill.BackgroundTransparency = 0.7
    S.gripPill.BorderSizePixel = 0
    S.gripPill.ZIndex = 56
    S.gripPill.Parent = S.main
    S.round(S.gripPill, 2)

    local dragging, dragStart, startPosition = false, nil, nil

    S.grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
            startPosition = S.main.Position
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            if d.Magnitude > 4 then S.gripMoved = true end
            S.main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + d.X, startPosition.Y.Scale, startPosition.Y.Offset + d.Y)
        end
    end)

    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                S.lastGripTap = S.gripMoved and 0 or tick()
            end
            dragging = false
        end
    end)

    S.PS_SIZE = 60
    S.restoreButton = Instance.new("TextButton")
    S.restoreButton.Name = "PSButton"
    S.restoreButton.Size = UDim2.fromOffset(S.PS_SIZE, S.PS_SIZE)
    S.restoreButton.Position = UDim2.new(1, -86, 1, -102)
    S.restoreButton.BackgroundColor3 = Color3.new(1, 1, 1)
    S.restoreButton.BorderSizePixel = 0
    S.restoreButton.Text = ""
    S.restoreButton.AutoButtonColor = false
    S.restoreButton.Visible = false
    S.restoreButton.ZIndex = 50
    S.restoreButton.Parent = S.gui
    S.circle(S.restoreButton)
    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color = ColorSequence.new(Color3.fromRGB(34, 86, 176), Color3.fromRGB(4, 18, 52))
    grad.Parent = S.restoreButton
    S.psRing = S.stroke(S.restoreButton, S.COLORS.white, 2, 0.25)
    TweenService:Create(S.psRing, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.85 }):Play()

    do
        local plate = Instance.new("Frame")
        plate.Size = UDim2.fromOffset(46, 46)
        plate.Position = UDim2.fromOffset(7, 7)
        plate.BackgroundTransparency = 1
        plate.BorderSizePixel = 0
        plate.ZIndex = 51
        plate.Parent = S.restoreButton
        S.circle(plate)
        S.stroke(plate, S.COLORS.white, 1, 0.78)
        local faces = {
            { "triangle", 23, 8, Color3.fromRGB(72, 226, 160) },
            { "circle", 38, 23, Color3.fromRGB(255, 84, 84) },
            { "cross", 23, 38, Color3.fromRGB(88, 148, 255) },
            { "square", 8, 23, Color3.fromRGB(255, 140, 205) },
        }
        for _, f in ipairs(faces) do
            S.icon(f[1], S.restoreButton, 14, f[4], UDim2.fromOffset(f[2], f[3]))
        end
    end

    S.psHint = S.label(S.restoreButton, "Drag to move  |  " .. (Enum.KeyCode.RightShift.Name or "Shift"),
        UDim2.fromOffset(150, 14), UDim2.new(0.5, -75, 1, 6), 10, S.COLORS.muted)
    S.psHint.TextXAlignment = Enum.TextXAlignment.Center

    local animationBusy = false

    function S.psCenter()
        local p = S.restoreButton.Position
        return UDim2.new(p.X.Scale, p.X.Offset + S.PS_SIZE / 2, p.Y.Scale, p.Y.Offset + S.PS_SIZE / 2)
    end

    function S.minimizeDashboard()
        if S.minimized or animationBusy then return end
        animationBusy = true
        S.minimized = true
        if S.closePanel then S.closePanel() end
        S.playSound("Close")
        S.savedPos = S.main.Position
        local base = S.baseScale()
        local info = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        TweenService:Create(S.main, info, { Position = S.psCenter() }):Play()
        TweenService:Create(S.uiScale, info, { Scale = 0.03 }):Play()
        local fade = TweenService:Create(S.main, info, { GroupTransparency = 1 })
        fade:Play()
        fade.Completed:Wait()
        if not S.gui.Parent then return end
        S.main.Visible = false
        S.main.Position = S.savedPos
        S.uiScale.Scale = base
        S.backdrop.Visible = false
        S.restoreButton.Visible = true
        animationBusy = false
    end

    function S.restoreDashboard()
        if not S.minimized or animationBusy then return end
        animationBusy = true
        S.restoreButton.Visible = false
        local base = S.baseScale()
        local home = S.savedPos or UDim2.fromScale(0.5, 0.5)
        S.main.Position = S.psCenter()
        S.uiScale.Scale = 0.03
        S.main.GroupTransparency = 1
        S.main.Visible = true
        if S.maximized then
            S.backdrop.Visible = true
            S.backdrop.BackgroundTransparency = 0
        end
        S.playSound("Open")
        S.playSound("Home")
        local info = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        TweenService:Create(S.main, info, { Position = home }):Play()
        TweenService:Create(S.uiScale, info, { Scale = base }):Play()
        local fade = TweenService:Create(S.main, info, { GroupTransparency = 0 })
        fade:Play()
        fade.Completed:Wait()
        if not S.gui.Parent then return end
        S.minimized = false
        animationBusy = false
    end

    function S.toggleMaximize()
        if S.minimized or animationBusy then return end
        animationBusy = true
        local cam = workspace.CurrentCamera
        local v = cam and cam.ViewportSize or Vector2.new(W, H)
        local corner = S.main:FindFirstChildOfClass("UICorner")
        local rim = S.main:FindFirstChildOfClass("UIStroke")
        local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if S.closePanel then S.closePanel() end
        if not S.maximized then
            S.maximized = true
            S.preMaxPos = S.main.Position
            S.backdrop.Visible = true
            TweenService:Create(S.backdrop, info, { BackgroundTransparency = 0 }):Play()
            TweenService:Create(S.main, info, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
            TweenService:Create(S.uiScale, info, { Scale = math.max(0.4, math.min(v.X / W, v.Y / H)) }):Play()
            if corner then TweenService:Create(corner, info, { CornerRadius = UDim.new(0, 0) }):Play() end
            if rim then TweenService:Create(rim, info, { Transparency = 1 }):Play() end
        else
            S.maximized = false
            TweenService:Create(S.backdrop, info, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(S.main, info, { Position = S.preMaxPos or UDim2.fromScale(0.5, 0.5) }):Play()
            TweenService:Create(S.uiScale, info, { Scale = S.baseScale() }):Play()
            if corner then TweenService:Create(corner, info, { CornerRadius = UDim.new(0, 12) }):Play() end
            if rim then TweenService:Create(rim, info, { Transparency = 0.3 }):Play() end
            task.delay(0.36, function()
                if not S.maximized then S.backdrop.Visible = false end
            end)
        end
        if S.setMaxIcon then S.setMaxIcon(S.maximized) end
        S.playSound(S.maximized and "Open" or "Close")
        task.delay(0.36, function() animationBusy = false end)
    end

    function S.toggleDashboard()
        if S.minimized then S.restoreDashboard() else S.minimizeDashboard() end
    end

    S.restoreButton.Activated:Connect(function()
        if S.psMoved then S.psMoved = false return end
        S.restoreDashboard()
    end)

    ctx.main = S.main
    ctx.gui = S.gui
    return S
end
