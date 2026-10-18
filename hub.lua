--[[
    LessHub for Illegal Soccer
    Mobile Friendly | Floating Toggle | Categorized | No Key
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    Colors = {
        Background = Color3.fromRGB(10, 12, 18),
        Surface = Color3.fromRGB(18, 22, 32),
        Primary = Color3.fromRGB(0, 120, 255),
        Text = Color3.fromRGB(230, 235, 245),
        TextDim = Color3.fromRGB(140, 150, 170),
        Danger = Color3.fromRGB(220, 60, 60),
        Success = Color3.fromRGB(0, 200, 120),
    },
    Fonts = {
        Title = Enum.Font.GothamBold,
        Body = Enum.Font.Gotham,
        Mono = Enum.Font.Code,
    },
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Open = false,
    -- Movement
    WalkSpeedEnabled = false,
    WalkSpeedValue = 16,
    JumpPowerEnabled = false,
    JumpPowerValue = 50,
    InfiniteJump = false,
    -- Striker
    AutoGoal = false,
    AutoDribble = false,
    PerfectShot = false,
    CurveShot = false,
    ShotRange = 60,       -- studs
    -- Goalkeeper
    AutoGK = false,
    AutoDive = false,
    GKRange = 25,         -- studs
    DiveDelay = 100,      -- ms
    -- Combat
    SilentAim = false,
    AimRange = 80,        -- studs
    AimDelay = 50,        -- ms
    -- Utility
    ItemESP = false,
    PlayerESP = false,
    -- Connections
    Connections = {},
}

-- ============================================================
-- MODULE CACHE (oyunun kendi modülleri)
-- ============================================================
local Modules = {}
local function LoadModule(path)
    if Modules[path] then return Modules[path] end
    local obj = ReplicatedStorage
    for name in string.gmatch(path, "[^.]+") do
        obj = obj:WaitForChild(name, 5)
        if not obj then return nil end
    end
    local ok, mod = pcall(require, obj)
    if ok and type(mod) == "table" then
        Modules[path] = mod
        return mod
    end
    return nil
end

-- ============================================================
-- UTILITY
-- ============================================================
local function GetChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char, hum
end

local function GetBall()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("ball") then
            return obj
        end
    end
    return nil
end

local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(State.Connections, c)
    return c
end

-- ============================================================
-- UI
-- ============================================================
local function CreateUI()
    -- ScreenGui (PlayerGui'ye ekle, CoreGui değil)
    local gui = Instance.new("ScreenGui")
    gui.Name = "LessHub"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui

    -- ========================================================
    -- FLOATING BUTTON (manuel sürükleme)
    -- ========================================================
    local float = Instance.new("TextButton")
    float.Name = "Float"
    float.Size = UDim2.new(0, 58, 0, 58)
    float.Position = UDim2.new(0, 20, 0.5, -29)
    float.BackgroundColor3 = CONFIG.Colors.Primary
    float.Text = "LH"
    float.TextColor3 = CONFIG.Colors.Text
    float.Font = CONFIG.Fonts.Title
    float.TextSize = 20
    float.AutoButtonColor = false
    float.Active = true
    float.Parent = gui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 16)
    floatCorner.Parent = float

    -- Floating button sürükleme (mobil + PC)
    local dragStart = nil
    local dragStartPos = nil
    float.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            dragStartPos = float.Position
        end
    end)
    float.InputChanged:Connect(function(input)
        if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            float.Position = UDim2.new(
                dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X,
                dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y
            )
        end
    end)
    float.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            if dragStart then
                local delta = (input.Position - dragStart).Magnitude
                if delta < 8 then
                    -- Tıklama: paneli aç/kapat
                    State.Open = not State.Open
                    if State.Open then
                        -- Panel açılırken butonu gizleme, sadece paneli göster
                    end
                end
            end
            dragStart = nil
            dragStartPos = nil
        end
    end)

    -- ========================================================
    -- MAIN PANEL
    -- ========================================================
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 360, 0, 520)
    panel.Position = UDim2.new(0.5, -180, 0.5, -260)
    panel.BackgroundColor3 = CONFIG.Colors.Background
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Parent = gui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 14)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = CONFIG.Colors.Primary
    panelStroke.Thickness = 1.5
    panelStroke.Transparency = 0.5
    panelStroke.Parent = panel

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 52)
    header.BackgroundColor3 = CONFIG.Colors.Surface
    header.BorderSizePixel = 0
    header.Parent = panel

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 14)
    headerCorner.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 30)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "LessHub"
    title.TextColor3 = CONFIG.Colors.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = CONFIG.Fonts.Title
    title.TextSize = 22
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 34, 0, 34)
    closeBtn.Position = UDim2.new(1, -44, 0, 9)
    closeBtn.BackgroundColor3 = CONFIG.Colors.Danger
    closeBtn.BackgroundTransparency = 0.7
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = CONFIG.Colors.Text
    closeBtn.Font = CONFIG.Fonts.Body
    closeBtn.TextSize = 16
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    -- Scrolling area
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -72)
    scroll.Position = UDim2.new(0, 10, 0, 62)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = CONFIG.Colors.Primary
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = panel

    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Padding = UDim.new(0, 8)
    scrollLayout.Parent = scroll

    local scrollPad = Instance.new("UIPadding")
    scrollPad.PaddingTop = UDim.new(0, 4)
    scrollPad.PaddingBottom = UDim.new(0, 12)
    scrollPad.Parent = scroll

    -- ========================================================
    -- UI HELPERS
    -- ========================================================
    local function Section(name)
        local sec = Instance.new("Frame")
        sec.Size = UDim2.new(1, 0, 0, 0)
        sec.BackgroundTransparency = 1
        sec.AutomaticSize = Enum.AutomaticSize.Y
        sec.Parent = scroll

        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 6)
        lay.Parent = sec

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 24)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = CONFIG.Colors.Primary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = CONFIG.Fonts.Title
        lbl.TextSize = 14
        lbl.Parent = sec
        return sec
    end

    local function Toggle(parent, text, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BackgroundColor3 = CONFIG.Colors.Surface
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local cor = Instance.new("UICorner")
        cor.CornerRadius = UDim.new(0, 8)
        cor.Parent = frame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = CONFIG.Colors.Text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = CONFIG.Fonts.Body
        lbl.TextSize = 13
        lbl.Parent = frame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 46, 0, 24)
        btn.Position = UDim2.new(1, -58, 0.5, -12)
        btn.BackgroundColor3 = default and CONFIG.Colors.Primary or CONFIG.Colors.TextDim
        btn.BackgroundTransparency = default and 0.3 or 0.7
        btn.Text = default and "ON" or "OFF"
        btn.TextColor3 = CONFIG.Colors.Text
        btn.Font = CONFIG.Fonts.Title
        btn.TextSize = 10
        btn.Parent = frame

        local btnCor = Instance.new("UICorner")
        btnCor.CornerRadius = UDim.new(0, 6)
        btnCor.Parent = btn

        local on = default
        btn.MouseButton1Click:Connect(function()
            on = not on
            btn.Text = on and "ON" or "OFF"
            btn.BackgroundColor3 = on and CONFIG.Colors.Primary or CONFIG.Colors.TextDim
            btn.BackgroundTransparency = on and 0.3 or 0.7
            if callback then callback(on) end
        end)
        return frame
    end

    local function Slider(parent, text, min, max, default, suffix, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 56)
        frame.BackgroundColor3 = CONFIG.Colors.Surface
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local cor = Instance.new("UICorner")
        cor.CornerRadius = UDim.new(0, 8)
        cor.Parent = frame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -80, 0, 20)
        lbl.Position = UDim2.new(0, 12, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = CONFIG.Colors.Text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = CONFIG.Fonts.Body
        lbl.TextSize = 13
        lbl.Parent = frame

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0, 70, 0, 20)
        valLbl.Position = UDim2.new(1, -82, 0, 6)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(default) .. suffix
        valLbl.TextColor3 = CONFIG.Colors.Primary
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Font = CONFIG.Fonts.Mono
        valLbl.TextSize = 12
        valLbl.Parent = frame

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -24, 0, 6)
        track.Position = UDim2.new(0, 12, 0, 34)
        track.BackgroundColor3 = CONFIG.Colors.TextDim
        track.BackgroundTransparency = 0.7
        track.BorderSizePixel = 0
        track.Parent = frame

        local trackCor = Instance.new("UICorner")
        trackCor.CornerRadius = UDim.new(0, 3)
        trackCor.Parent = track

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = CONFIG.Colors.Primary
        fill.BorderSizePixel = 0
        fill.Parent = track

        local fillCor = Instance.new("UICorner")
        fillCor.CornerRadius = UDim.new(0, 3)
        fillCor.Parent = fill

        local dragging = false
        local function update(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel + 0.5)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            valLbl.Text = tostring(val) .. suffix
            if callback then callback(val) end
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
               or input.UserInputType == Enum.UserInputType.Touch) then
                update(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        return frame
    end

    -- ========================================================
    -- SECTIONS
    -- ========================================================

    -- ----- MOVEMENT -----
    local move = Section("MOVEMENT")
    Toggle(move, "WalkSpeed", false, function(on)
        State.WalkSpeedEnabled = on
        local _, hum = GetChar()
        if hum then hum.WalkSpeed = on and State.WalkSpeedValue or 16 end
    end)
    Slider(move, "WalkSpeed Value", 16, 120, 16, "", function(v)
        State.WalkSpeedValue = v
        if State.WalkSpeedEnabled then
            local _, hum = GetChar()
            if hum then hum.WalkSpeed = v end
        end
    end)
    Toggle(move, "JumpPower", false, function(on)
        State.JumpPowerEnabled = on
        local _, hum = GetChar()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = on and State.JumpPowerValue or 50
        end
    end)
    Slider(move, "JumpPower Value", 50, 200, 50, "", function(v)
        State.JumpPowerValue = v
        if State.JumpPowerEnabled then
            local _, hum = GetChar()
            if hum then hum.JumpPower = v end
        end
    end)
    Toggle(move, "Infinite Jump", false, function(on)
        State.InfiniteJump = on
    end)
    Connect(UserInputService.JumpRequest, function()
        if State.InfiniteJump then
            local _, hum = GetChar()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)

    -- ----- STRIKER -----
    local striker = Section("STRIKER")
    Toggle(striker, "Auto Goal", false, function(on) State.AutoGoal = on end)
    Slider(striker, "Shot Range (studs)", 20, 120, 60, "", function(v) State.ShotRange = v end)
    Toggle(striker, "Auto Dribble", false, function(on) State.AutoDribble = on end)
    Toggle(striker, "Perfect Shot", false, function(on) State.PerfectShot = on end)
    Toggle(striker, "Curve Shot", false, function(on) State.CurveShot = on end)

    -- ----- GOALKEEPER -----
    local gk = Section("GOALKEEPER")
    Toggle(gk, "Auto GK", false, function(on) State.AutoGK = on end)
    Slider(gk, "GK Range (studs)", 5, 50, 25, "", function(v) State.GKRange = v end)
    Toggle(gk, "Auto Dive", false, function(on) State.AutoDive = on end)
    Slider(gk, "Dive Delay (ms)", 0, 500, 100, "ms", function(v) State.DiveDelay = v end)

    -- ----- COMBAT -----
    local combat = Section("COMBAT")
    Toggle(combat, "Silent Aim", false, function(on) State.SilentAim = on end)
    Slider(combat, "Aim Range (studs)", 20, 200, 80, "", function(v) State.AimRange = v end)
    Slider(combat, "Aim Delay (ms)", 0, 300, 50, "ms", function(v) State.AimDelay = v end)

    -- ----- UTILITY -----
    local util = Section("UTILITY")
    Toggle(util, "Item ESP", false, function(on) State.ItemESP = on end)
    Toggle(util, "Player ESP", false, function(on) State.PlayerESP = on end)

    -- ========================================================
    -- PANEL TOGGLE
    -- ========================================================
    local function SetPanel(open)
        State.Open = open
        panel.Visible = open
        if open then
            panel.Size = UDim2.new(0, 320, 0, 440)
            panel.BackgroundTransparency = 1
            TweenService:Create(panel, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 360, 0, 520),
                BackgroundTransparency = 0,
            }):Play()
        end
    end

    float.MouseButton1Click:Connect(function()
        SetPanel(not State.Open)
    end)
    closeBtn.MouseButton1Click:Connect(function()
        SetPanel(false)
    end)

    return gui
end

-- ============================================================
-- LOGIC LOOPS
-- ============================================================
local function StartLoops()
    -- Auto GK / Auto Dive (basit: topa doğru hareket)
    Connect(RunService.Heartbeat, function()
        if not State.AutoGK and not State.AutoDive then return end
        local char, hum = GetChar()
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local ball = GetBall()
        if ball then
            local dist = (ball.Position - root.Position).Magnitude
            if dist <= State.GKRange then
                hum:MoveTo(ball.Position)
                if State.AutoDive and dist < 5 then
                    task.wait(State.DiveDelay / 1000)
                    -- Oyunun Dive modülünü kullanmayı dene
                    local diveMod = LoadModule("Modules.Actions.GoalkeeperDive")
                    if diveMod and type(diveMod.Dive) == "function" then
                        pcall(diveMod.Dive)
                    end
                end
            end
        end
    end)

    -- Auto Goal (basit: topa doğru hareket et ve şut çek)
    Connect(RunService.Heartbeat, function()
        if not State.AutoGoal then return end
        local char, hum = GetChar()
        if not char then return end
        local ball = GetBall()
        if ball then
            local dist = (ball.Position - char.HumanoidRootPart.Position).Magnitude
            if dist <= State.ShotRange then
                hum:MoveTo(ball.Position)
                -- Şut çekme girişimi (oyunun kendi remote'u)
                local ballRemotes = ReplicatedStorage:FindFirstChild("Remotes")
                if ballRemotes then
                    local ballRemote = ballRemotes:FindFirstChild("Ball")
                    if ballRemote then
                        local shoot = ballRemote:FindFirstChild("Shoot")
                        if shoot then
                            pcall(function()
                                shoot:FireServer(ball)
                            end)
                        end
                    end
                end
            end
        end
    end)

    -- Item ESP (basit)
    Connect(RunService.Heartbeat, function()
        if not State.ItemESP then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name:lower():find("item") or obj.Name:lower():find("gun")) then
                if not obj:FindFirstChild("LessESP") then
                    local bill = Instance.new("BillboardGui")
                    bill.Name = "LessESP"
                    bill.Size = UDim2.new(0, 80, 0, 30)
                    bill.AlwaysOnTop = true
                    bill.Parent = obj
                    local txt = Instance.new("TextLabel")
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.Text = obj.Name
                    txt.TextColor3 = Color3.new(1, 1, 0)
                    txt.Parent = bill
                end
            end
        end
    end)

    -- Player ESP (basit)
    Connect(RunService.Heartbeat, function()
        if not State.PlayerESP then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                if root and not root:FindFirstChild("LessPlayerESP") then
                    local bill = Instance.new("BillboardGui")
                    bill.Name = "LessPlayerESP"
                    bill.Size = UDim2.new(0, 100, 0, 40)
                    bill.AlwaysOnTop = true
                    bill.Parent = root
                    local txt = Instance.new("TextLabel")
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.Text = plr.Name
                    txt.TextColor3 = Color3.new(1, 0, 0)
                    txt.Parent = bill
                end
            end
        end
    end)
end

-- ============================================================
-- INIT
-- ============================================================
local ok, err = pcall(function()
    CreateUI()
    StartLoops()
end)

if not ok then
    warn("[LessHub] Error: " .. tostring(err))
end