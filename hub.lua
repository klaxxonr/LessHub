--[[
    LessHub for Illegal Soccer
    Black-Blue Theme | Mobile Friendly | Floating Toggle | No Key
    Features: Aimbot, Silent Aim, Auto Goal, Auto Goalkeeper, Auto Dribble,
              Fake Shoot, Perfect Shot, Infinite Stamina, ESP, Speed, Fly, Noclip, vb.
    Adjustable: Delay (ms), Range (studs)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    Colors = {
        Background = Color3.fromRGB(10, 12, 18),
        Surface = Color3.fromRGB(18, 22, 32),
        Primary = Color3.fromRGB(0, 120, 255),
        PrimaryDim = Color3.fromRGB(0, 70, 160),
        Text = Color3.fromRGB(230, 235, 245),
        TextDim = Color3.fromRGB(140, 150, 170),
        Success = Color3.fromRGB(0, 200, 120),
        Danger = Color3.fromRGB(220, 60, 60),
        Warning = Color3.fromRGB(255, 180, 0),
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
    InfiniteJumpEnabled = false,
    FlyEnabled = false,
    NoclipEnabled = false,
    -- Combat / Aimbot
    AimbotEnabled = false,
    AimbotDelay = 100,      -- ms
    AimbotRange = 50,       -- studs
    SilentAimEnabled = false,
    SilentAimDelay = 50,
    SilentAimRange = 100,
    -- Auto Goal / Dribble
    AutoGoalEnabled = false,
    AutoGoalDelay = 200,
    AutoDribbleEnabled = false,
    AutoDribbleRange = 30,
    AutoGoalkeeperEnabled = false,
    AutoGoalkeeperRange = 20,
    AutoDiveEnabled = false,
    AutoDiveDelay = 150,
    -- Fake / Perfect Shot
    FakeShootEnabled = false,
    FakeShootDelay = 150,
    PerfectShootEnabled = false,
    PerfectCurveEnabled = false,
    AutoWallFakeShootEnabled = false,
    -- Resources
    InfiniteStaminaEnabled = false,
    GodmodeEnabled = false,
    -- Utility
    ItemESPEnabled = false,
    PlayerESPEnabled = false,
    AutoItemUseEnabled = false,
    ItemAimbotEnabled = false,
    ItemAimbotRange = 40,
    AutoplayEnabled = false,
    AntiBanEnabled = false,
    ServerHopEnabled = false,
    -- Connections
    Connections = {},
}

-- ============================================================
-- UTILITY
-- ============================================================
local function GetCharacter()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char, hum
end

local function GetBall()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower():find("ball") and obj:IsA("BasePart") then
            return obj
        end
    end
    return nil
end

local function AddConnection(conn)
    table.insert(State.Connections, conn)
    return conn
end

-- ============================================================
-- UI CREATION (Mobile Friendly)
-- ============================================================
local function CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LessHub_UI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui

    -- Floating Button
    local floatBtn = Instance.new("TextButton")
    floatBtn.Name = "FloatButton"
    floatBtn.Size = UDim2.new(0, 60, 0, 60)
    floatBtn.Position = UDim2.new(0, 20, 0.5, -30)
    floatBtn.BackgroundColor3 = CONFIG.Colors.Primary
    floatBtn.BackgroundTransparency = 0.1
    floatBtn.BorderSizePixel = 0
    floatBtn.Text = "LH"
    floatBtn.TextColor3 = CONFIG.Colors.Text
    floatBtn.Font = CONFIG.Fonts.Title
    floatBtn.TextSize = 22
    floatBtn.AutoButtonColor = false
    floatBtn.Active = true
    floatBtn.Draggable = true
    floatBtn.Parent = screenGui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 16)
    floatCorner.Parent = floatBtn

    local floatStroke = Instance.new("UIStroke")
    floatStroke.Color = CONFIG.Colors.Primary
    floatStroke.Thickness = 2
    floatStroke.Transparency = 0.5
    floatStroke.Parent = floatBtn

    -- Main Panel
    local mainPanel = Instance.new("Frame")
    mainPanel.Name = "MainPanel"
    mainPanel.Size = UDim2.new(0, 360, 0, 520)
    mainPanel.Position = UDim2.new(0.5, -180, 0.5, -260)
    mainPanel.BackgroundColor3 = CONFIG.Colors.Background
    mainPanel.BackgroundTransparency = 0.05
    mainPanel.BorderSizePixel = 0
    mainPanel.Visible = false
    mainPanel.Active = true
    mainPanel.Draggable = true
    mainPanel.Parent = screenGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 14)
    panelCorner.Parent = mainPanel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = CONFIG.Colors.Primary
    panelStroke.Thickness = 1.5
    panelStroke.Transparency = 0.6
    panelStroke.Parent = mainPanel

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 52)
    header.BackgroundColor3 = CONFIG.Colors.Surface
    header.BackgroundTransparency = 0.3
    header.BorderSizePixel = 0
    header.Parent = mainPanel

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 14)
    headerCorner.Parent = header

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 14)
    headerFix.Position = UDim2.new(0, 0, 1, -14)
    headerFix.BackgroundColor3 = CONFIG.Colors.Surface
    headerFix.BackgroundTransparency = 0.3
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 32)
    title.Position = UDim2.new(0, 18, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "LessHub"
    title.TextColor3 = CONFIG.Colors.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = CONFIG.Fonts.Title
    title.TextSize = 22
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -60, 0, 16)
    subtitle.Position = UDim2.new(0, 18, 0, 34)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Illegal Soccer"
    subtitle.TextColor3 = CONFIG.Colors.TextDim
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Font = CONFIG.Fonts.Body
    subtitle.TextSize = 12
    subtitle.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -46, 0, 8)
    closeBtn.BackgroundColor3 = CONFIG.Colors.Danger
    closeBtn.BackgroundTransparency = 0.8
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = CONFIG.Colors.Text
    closeBtn.Font = CONFIG.Fonts.Body
    closeBtn.TextSize = 18
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    -- Scrolling Content
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -24, 1, -72)
    scrollFrame.Position = UDim2.new(0, 12, 0, 60)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = CONFIG.Colors.Primary
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = mainPanel

    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Padding = UDim.new(0, 8)
    scrollLayout.Parent = scrollFrame

    local scrollPadding = Instance.new("UIPadding")
    scrollPadding.PaddingTop = UDim.new(0, 4)
    scrollPadding.PaddingBottom = UDim.new(0, 12)
    scrollPadding.Parent = scrollFrame

    -- ========================================================
    -- UI HELPERS
    -- ========================================================
    local function CreateSection(name)
        local section = Instance.new("Frame")
        section.Size = UDim2.new(1, 0, 0, 0)
        section.BackgroundTransparency = 1
        section.AutomaticSize = Enum.AutomaticSize.Y
        section.Parent = scrollFrame

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.Parent = section

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 24)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = CONFIG.Colors.Primary
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = CONFIG.Fonts.Title
        label.TextSize = 14
        label.Parent = section
        return section
    end

    local function CreateToggle(parent, name, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BackgroundColor3 = CONFIG.Colors.Surface
        frame.BackgroundTransparency = 0.4
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -70, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = CONFIG.Colors.Text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = CONFIG.Fonts.Body
        label.TextSize = 13
        label.Parent = frame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 48, 0, 26)
        btn.Position = UDim2.new(1, -60, 0.5, -13)
        btn.BackgroundColor3 = default and CONFIG.Colors.Primary or CONFIG.Colors.TextDim
        btn.BackgroundTransparency = default and 0.2 or 0.6
        btn.BorderSizePixel = 0
        btn.Text = default and "ON" or "OFF"
        btn.TextColor3 = CONFIG.Colors.Text
        btn.Font = CONFIG.Fonts.Title
        btn.TextSize = 10
        btn.Parent = frame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        local isOn = default
        btn.MouseButton1Click:Connect(function()
            isOn = not isOn
            btn.Text = isOn and "ON" or "OFF"
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = isOn and CONFIG.Colors.Primary or CONFIG.Colors.TextDim,
                BackgroundTransparency = isOn and 0.2 or 0.6,
            }):Play()
            if callback then callback(isOn) end
        end)
        return frame
    end

    local function CreateSlider(parent, name, min, max, default, suffix, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 56)
        frame.BackgroundColor3 = CONFIG.Colors.Surface
        frame.BackgroundTransparency = 0.4
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -80, 0, 20)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = CONFIG.Colors.Text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = CONFIG.Fonts.Body
        label.TextSize = 13
        label.Parent = frame

        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(0, 70, 0, 20)
        valLabel.Position = UDim2.new(1, -82, 0, 6)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(default) .. suffix
        valLabel.TextColor3 = CONFIG.Colors.Primary
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Font = CONFIG.Fonts.Mono
        valLabel.TextSize = 12
        valLabel.Parent = frame

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -24, 0, 6)
        track.Position = UDim2.new(0, 12, 0, 34)
        track.BackgroundColor3 = CONFIG.Colors.TextDim
        track.BackgroundTransparency = 0.7
        track.BorderSizePixel = 0
        track.Parent = frame

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(0, 3)
        trackCorner.Parent = track

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = CONFIG.Colors.Primary
        fill.BorderSizePixel = 0
        fill.Parent = track

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 3)
        fillCorner.Parent = fill

        local current = default
        local dragging = false

        local function updateFromX(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel + 0.5)
            current = val
            fill.Size = UDim2.new(rel, 0, 1, 0)
            valLabel.Text = tostring(val) .. suffix
            if callback then callback(val) end
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        return frame
    end

    local function CreateButton(parent, name, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.BackgroundColor3 = color or CONFIG.Colors.Primary
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = CONFIG.Colors.Text
        btn.Font = CONFIG.Fonts.Title
        btn.TextSize = 13
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
        return btn
    end

    -- ========================================================
    -- SECTIONS
    -- ========================================================

    -- MOVEMENT
    local movement = CreateSection("MOVEMENT")
    CreateToggle(movement, "Enable WalkSpeed", false, function(on)
        State.WalkSpeedEnabled = on
        local _, hum = GetCharacter()
        if hum then hum.WalkSpeed = on and State.WalkSpeedValue or 16 end
    end)
    CreateSlider(movement, "WalkSpeed", 16, 150, 16, "", function(v)
        State.WalkSpeedValue = v
        if State.WalkSpeedEnabled then
            local _, hum = GetCharacter()
            if hum then hum.WalkSpeed = v end
        end
    end)
    CreateToggle(movement, "Enable JumpPower", false, function(on)
        State.JumpPowerEnabled = on
        local _, hum = GetCharacter()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = on and State.JumpPowerValue or 50
        end
    end)
    CreateSlider(movement, "JumpPower", 50, 250, 50, "", function(v)
        State.JumpPowerValue = v
        if State.JumpPowerEnabled then
            local _, hum = GetCharacter()
            if hum then hum.JumpPower = v end
        end
    end)
    CreateToggle(movement, "Infinite Jump", false, function(on)
        State.InfiniteJumpEnabled = on
    end)
    -- Infinite Jump handler
    AddConnection(UserInputService.JumpRequest:Connect(function()
        if State.InfiniteJumpEnabled then
            local _, hum = GetCharacter()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))
    CreateToggle(movement, "Fly (Experimental)", false, function(on)
        State.FlyEnabled = on
        -- Fly implementation (basit)
        local char, hum = GetCharacter()
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if on then
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.zero
            bv.Parent = root
            AddConnection(RunService.Heartbeat:Connect(function()
                if not State.FlyEnabled then bv:Destroy() return end
                bv.Velocity = Vector3.new(0, 50, 0) -- basit yukarı uçuş
            end))
        end
    end)
    CreateToggle(movement, "Noclip", false, function(on)
        State.NoclipEnabled = on
        AddConnection(RunService.Stepped:Connect(function()
            if not State.NoclipEnabled then return end
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end))
    end)

    -- COMBAT / AIMBOT
    local combat = CreateSection("COMBAT / AIMBOT")
    CreateToggle(combat, "Aimbot (Goal)", false, function(on) State.AimbotEnabled = on end)
    CreateSlider(combat, "Aimbot Delay (ms)", 0, 500, 100, "ms", function(v) State.AimbotDelay = v end)
    CreateSlider(combat, "Aimbot Range (studs)", 10, 200, 50, "", function(v) State.AimbotRange = v end)
    CreateToggle(combat, "Silent Aim", false, function(on) State.SilentAimEnabled = on end)
    CreateSlider(combat, "Silent Aim Delay (ms)", 0, 300, 50, "ms", function(v) State.SilentAimDelay = v end)
    CreateSlider(combat, "Silent Aim Range (studs)", 10, 300, 100, "", function(v) State.SilentAimRange = v end)

    -- AUTO / GOAL
    local auto = CreateSection("AUTO / GOAL")
    CreateToggle(auto, "Auto Goal", false, function(on) State.AutoGoalEnabled = on end)
    CreateSlider(auto, "Auto Goal Delay (ms)", 50, 1000, 200, "ms", function(v) State.AutoGoalDelay = v end)
    CreateToggle(auto, "Auto Dribble", false, function(on) State.AutoDribbleEnabled = on end)
    CreateSlider(auto, "Auto Dribble Range (studs)", 5, 100, 30, "", function(v) State.AutoDribbleRange = v end)
    CreateToggle(auto, "Auto Goalkeeper", false, function(on) State.AutoGoalkeeperEnabled = on end)
    CreateSlider(auto, "Goalkeeper Range (studs)", 5, 50, 20, "", function(v) State.AutoGoalkeeperRange = v end)
    CreateToggle(auto, "Auto Dive", false, function(on) State.AutoDiveEnabled = on end)
    CreateSlider(a