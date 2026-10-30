return function(S, ctx)
    local TweenService = game:GetService("TweenService")

    function S.makePage(name, title)
        local page = Instance.new("CanvasGroup")
        page.Name = name
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.GroupTransparency = 1
        page.Visible = false
        page.ZIndex = 20
        page.Parent = S.main

        local back = Instance.new("Frame")
        back.Size = UDim2.fromScale(1, 1)
        back.BackgroundColor3 = Color3.new(1, 1, 1)
        back.BackgroundTransparency = 0.03
        back.BorderSizePixel = 0
        back.Parent = page

        local pg = Instance.new("UIGradient")
        pg.Rotation = 35
        pg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 20, 54)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(12, 58, 122)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 24, 66)),
        })
        pg.Parent = back
        table.insert(S.pageGradients, pg)

        local titleLabel = S.label(page, title, UDim2.new(1, -80, 0, 36), UDim2.fromOffset(40, 22), 24, S.COLORS.white)
        local underline = Instance.new("Frame")
        underline.Size = UDim2.new(1, -80, 0, 1)
        underline.Position = UDim2.fromOffset(40, 66)
        underline.BackgroundColor3 = S.COLORS.white
        underline.BackgroundTransparency = 0.85
        underline.BorderSizePixel = 0
        underline.Parent = page

        local backBtn = Instance.new("TextButton")
        backBtn.Name = "Back"
        backBtn.Size = UDim2.fromOffset(120, 30)
        backBtn.Position = UDim2.fromOffset(112, S.H - 44)
        backBtn.BackgroundTransparency = 1
        backBtn.Text = ""
        backBtn.Parent = page
        S.icon("circle", backBtn, 18, S.COLORS.muted, UDim2.fromOffset(0, 6))
        local backLbl = S.label(backBtn, "Back", UDim2.fromOffset(80, 30), UDim2.fromOffset(26, 0), 14, S.COLORS.muted)
        backBtn.MouseEnter:Connect(function() backLbl.TextColor3 = S.COLORS.white end)
        backBtn.MouseLeave:Connect(function() backLbl.TextColor3 = S.COLORS.muted end)
        S.icon("cross", page, 16, S.COLORS.muted, UDim2.fromOffset(44, S.H - 37))
        S.label(page, "Enter", UDim2.fromOffset(70, 30), UDim2.fromOffset(66, S.H - 44), 14, S.COLORS.muted)
        S.pages[name] = { frame = page, back = backBtn, title = titleLabel }
        return page
    end

    function S.hidePage(page)
        local t = S.tween(page, 0.18, { GroupTransparency = 1 })
        t.Completed:Connect(function()
            if page.GroupTransparency > 0.95 then page.Visible = false end
        end)
    end

    function S.showPage(name)
        local target = S.pages[name]
        if not target then return end
        S.playSound("Select")
        if S.closePanel then S.closePanel() end
        for n, d in pairs(S.pages) do
            if n == name then
                d.frame.Visible = true
                d.frame.GroupTransparency = 1
                S.tween(d.frame, 0.22, { GroupTransparency = 0 })
            elseif d.frame.Visible then
                S.hidePage(d.frame)
            end
        end
        S.currentPage = name
    end

    function S.goHome()
        if S.closePanel then S.closePanel() end
        for _, d in pairs(S.pages) do
            if d.frame.Visible then S.hidePage(d.frame) end
        end
        S.currentPage = nil
        S.playSound("Close")
    end

    function S.goBack()
        local cur = S.currentPage
        if not cur then return end
        local target = S.backTarget[cur]
        if cur == "Info" then target = S.infoFrom end
        if target and S.pages[target] then
            S.showPage(target)
        else
            S.goHome()
        end
    end

    S.scrim = Instance.new("TextButton")
    S.scrim.Size = UDim2.fromScale(1, 1)
    S.scrim.BackgroundColor3 = Color3.new(0, 0, 0)
    S.scrim.BackgroundTransparency = 1
    S.scrim.BorderSizePixel = 0
    S.scrim.Text = ""
    S.scrim.AutoButtonColor = false
    S.scrim.Visible = false
    S.scrim.ZIndex = 40
    S.scrim.Parent = S.main

    S.panel = Instance.new("Frame")
    S.panel.Name = "OptionsPanel"
    S.panel.Size = UDim2.new(0, 270, 1, 0)
    S.panel.Position = UDim2.new(1, 0, 0, 0)
    S.panel.BackgroundColor3 = Color3.new(1, 1, 1)
    S.panel.BorderSizePixel = 0
    S.panel.Visible = false
    S.panel.ZIndex = 45
    S.panel.Parent = S.main
    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color = ColorSequence.new(Color3.fromRGB(16, 44, 90), Color3.fromRGB(5, 16, 38))
    grad.Parent = S.panel

    S.panelTitle = S.label(S.panel, "", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 22), 17, S.COLORS.white, true)
    S.panelList = Instance.new("Frame")
    S.panelList.Size = UDim2.new(1, -24, 1, -90)
    S.panelList.Position = UDim2.fromOffset(12, 74)
    S.panelList.BackgroundTransparency = 1
    S.panelList.Parent = S.panel
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = S.panelList

    function S.closePanel()
        if not S.panelOpen then return end
        S.panelOpen = false
        S.tween(S.scrim, 0.2, { BackgroundTransparency = 1 })
        local t = S.tween(S.panel, 0.22, { Position = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            if not S.panelOpen then S.panel.Visible = false; S.scrim.Visible = false end
        end)
    end

    S.panelRows = {}
    S.panelIndex = 1

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
        for idx, row in ipairs(S.panelRows) do
            local on = idx == i
            row.row.BackgroundTransparency = on and 0.88 or 1
            row.ring.Transparency = on and 0.1 or 1
        end
    end

    function S.selectPanelRow(i)
        local r = S.panelRows[i]
        if not r then return end
        S.playSound("Select")
        S.closePanel()
        if type(r.fn) == "function" then r.fn() end
    end

    function S.panelKey(k)
        local d = S.dirOf(k)
        if d == "up" then S.focusPanelRow(S.panelIndex - 1)
        elseif d == "down" then S.focusPanelRow(S.panelIndex + 1)
        elseif d == "ok" then S.selectPanelRow(S.panelIndex) end
    end

    function S.openPanel(title, entries)
        S.panelTitle.Text = title
        for _, child in ipairs(S.panelList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        S.panelRows = {}
        for index, entry in ipairs(entries) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, 0, 0, 40)
            row.BackgroundColor3 = S.COLORS.white
            row.BackgroundTransparency = 1
            row.BorderSizePixel = 0
            row.AutoButtonColor = false
            row.Text = ""
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Font = Enum.Font.Gotham
            row.TextSize = 14
            row.TextColor3 = S.COLORS.white
            row.LayoutOrder = index
            row.Parent = S.panelList
            S.round(row, 4)
            local rowIcon = S.iconForText(entry[1])
            if rowIcon then S.icon(rowIcon, row, 20, S.COLORS.white, UDim2.fromOffset(12, 10)) end
            local rowLbl = S.label(row, entry[1], UDim2.new(1, -50, 1, 0), UDim2.fromOffset(rowIcon and 42 or 14, 0), 14, S.COLORS.white)
            rowLbl.TextWrapped = false
            rowLbl.TextTruncate = Enum.TextTruncate.AtEnd
            local ring = S.stroke(row, S.COLORS.white, 2, 1)
            S.panelRows[index] = { row = row, ring = ring, fn = entry[2] }
            row.MouseEnter:Connect(function() S.focusPanelRow(index) end)
            row.Activated:Connect(function() S.selectPanelRow(index) end)
        end
        S.focusPanelRow(1)
        S.playSound("Open")
        S.panelOpen = true
        S.scrim.Visible = true
        S.panel.Visible = true
        S.panel.Position = UDim2.new(1, 0, 0, 0)
        S.tween(S.scrim, 0.25, { BackgroundTransparency = 0.5 })
        S.tween(S.panel, 0.25, { Position = UDim2.new(1, -270, 0, 0) })
    end

    S.scrim.Activated:Connect(function() S.closePanel() end)

    function S.loadingToast(baseText)
        local ctl = { alive = true }
        if not S.settings.toasts then
            function ctl.finish(msg)
                table.insert(S.notifyLog, 1, { text = msg, time = os.time() })
            end
            return ctl
        end
        S.playSound("Notify")
        local prev = S.main:FindFirstChild("PS4Toast")
        if prev then prev:Destroy() end
        local toast = Instance.new("Frame")
        toast.Name = "PS4Toast"
        toast.Size = UDim2.fromOffset(300, 56)
        toast.Position = UDim2.fromOffset(-320, 14)
        toast.BackgroundColor3 = Color3.fromRGB(228, 233, 241)
        toast.BorderSizePixel = 0
        toast.ZIndex = 60
        toast.Parent = S.main
        local ink = Color3.fromRGB(44, 56, 84)
        local hold = Instance.new("Frame")
        hold.Size = UDim2.fromOffset(30, 30)
        hold.Position = UDim2.fromOffset(14, 13)
        hold.BackgroundTransparency = 1
        hold.ZIndex = 61
        hold.Parent = toast
        S.icon("square", hold, 13, ink, UDim2.fromOffset(0, 0))
        S.icon("triangle", hold, 13, ink, UDim2.fromOffset(17, 0))
        S.icon("cross", hold, 13, ink, UDim2.fromOffset(0, 17))
        S.icon("circle", hold, 13, ink, UDim2.fromOffset(17, 17))
        local m = S.label(toast, baseText .. ".", UDim2.new(1, -66, 1, -8), UDim2.fromOffset(56, 4), 14, ink)
        m.ZIndex = 61
        m.TextWrapped = false
        m.TextTruncate = Enum.TextTruncate.AtEnd
        S.tween(toast, 0.3, { Position = UDim2.fromOffset(16, 14) })
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
            table.insert(S.notifyLog, 1, { text = msg, time = os.time() })
            if not toast.Parent then return end
            m.Text = msg
            task.delay(3, function()
                if toast.Parent then
                    S.tween(toast, 0.25, { Position = UDim2.fromOffset(-320, 14) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                    task.delay(0.3, function() if toast.Parent then toast:Destroy() end end)
                end
            end)
        end
        return ctl
    end

    return S
end
