-- Illegal Soccer Assist (Mobile / Delta / Xeno)
-- UI first, everything pcall-protected, ASCII strings only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer

-- ============================================================
-- 1. UI (CREATED FIRST)
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "IS_Assist"
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    screenGui.Parent = LP:WaitForChild("PlayerGui")
end)

-- Main frame (pixel based, mobile safe)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 320, 0, 520)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 12, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "IS ASSIST"
titleText.TextColor3 = Color3.fromRGB(220, 220, 230)
titleText.TextSize = 16
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -36, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
pcall(function()
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = closeBtn
end)
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -8, 0, 34)
tabBar.Position = UDim2.new(0, 4, 0, 40)
tabBar.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 6)
tabCorner.Parent = tabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 2)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local tabs = {}
local tabNames = {"MOVEMENT", "SHOT", "DRIBBLE", "GK", "MISC"}
local tabButtons = {}

local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -8, 1, -84)
contentFrame.Position = UDim2.new(0, 4, 0, 78)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 190)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.LayoutOrder = i
    btn.Parent = tabBar
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = btn
    end)
    tabButtons[name] = btn
end

local function switchTab(tabName)
    for _, btn in pairs(tabButtons) do
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        btn.TextColor3 = Color3.fromRGB(180, 180, 190)
    end
    if tabButtons[tabName] then
        tabButtons[tabName].BackgroundColor3 = Color3.fromRGB(70, 120, 200)
        tabButtons[tabName].TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child.Visible = (child.Name == tabName)
        end
    end
end

-- Create tab content frames
local tabContents = {}
for _, name in ipairs(tabNames) do
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = contentFrame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 12
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    tabContents[name] = scroll
end

-- Helper: create toggle
local function createToggle(parent, text, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -8, 0, 42)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    container.BorderSizePixel = 0
    container.Parent = parent
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = container
    end)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 60, 0, 30)
    toggleBtn.Position = UDim2.new(1, -68, 0, 6)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(70, 70, 80)
    toggleBtn.Text = default and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 11
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = container
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = toggleBtn
    end)

    local state = default
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(70, 70, 80)
        toggleBtn.Text = state and "ON" or "OFF"
        if callback then
            pcall(callback, state)
        end
    end)
    return container, function() return state end
end

-- Helper: create button
local function createButton(parent, text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 42)
    btn.BackgroundColor3 = color or Color3.fromRGB(60, 120, 200)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = parent
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)
    return btn
end

-- Helper: create slider
local function createSlider(parent, text, min, max, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -8, 0, 62)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    container.BorderSizePixel = 0
    container.Parent = parent
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = container
    end)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -20, 0, 8)
    barBg.Position = UDim2.new(0, 10, 0, 32)
    barBg.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    barBg.BorderSizePixel = 0
    barBg.Parent = container
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = barBg
    end)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(70, 140, 220)
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = fill
    end)

    local val = default
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local function update(input)
                local pos = input.Position.X - barBg.AbsolutePosition.X
                local pct = math.clamp(pos / barBg.AbsoluteSize.X, 0, 1)
                val = min + (max - min) * pct
                fill.Size = UDim2.new(pct, 0, 1, 0)
                label.Text = text .. ": " .. string.format("%.2f", val)
                if callback then pcall(callback, val) end
            end
            update(input)
            local conn
            conn = UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                    update(i)
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end)
    return container, function() return val end
end

-- Populate tabs
local uiRefs = { toggles = {}, sliders = {}, buttons = {} }

-- MOVEMENT
do
    local parent = tabContents["MOVEMENT"]
    local _, getInfStam = createToggle(parent, "Infinite Stamina", false, function(v) end)
    uiRefs.toggles.infStam = getInfStam
    local _, getSpeed = createSlider(parent, "Speed Multiplier", 1.0, 2.5, 1.0, function(v) end)
    uiRefs.sliders.speed = getSpeed
    local _, getJump = createToggle(parent, "Jump Boost (120)", false, function(v) end)
    uiRefs.toggles.jumpBoost = getJump
end

-- SHOT
do
    local parent = tabContents["SHOT"]
    local _, getPerfect = createToggle(parent, "Perfect Shot (Auto Aim)", false, function(v) end)
    uiRefs.toggles.perfectShot = getPerfect
    -- Curve mode dropdown simplified as cycle button
    local curveModes = {"OFF", "LEFT", "RIGHT", "AUTO"}
    local curveIdx = 1
    local curveBtn = createButton(parent, "Curve: OFF", Color3.fromRGB(70, 70, 80), function()
        curveIdx = curveIdx % #curveModes + 1
        curveBtn.Text = "Curve: " .. curveModes[curveIdx]
        curveBtn.BackgroundColor3 = curveIdx == 1 and Color3.fromRGB(70, 70, 80) or Color3.fromRGB(60, 120, 200)
    end)
    uiRefs.buttons.curve = curveBtn
    uiRefs.getCurveMode = function() return curveModes[curveIdx] end

    uiRefs.buttons.fakeShot = createButton(parent, "FAKE SHOT", Color3.fromRGB(60, 120, 200), function() end)
    uiRefs.buttons.wallShot = createButton(parent, "WALL SHOT", Color3.fromRGB(60, 120, 200), function() end)
    uiRefs.buttons.pass = createButton(parent, "PERFECT PASS", Color3.fromRGB(60, 120, 200), function() end)
end

-- DRIBBLE
do
    local parent = tabContents["DRIBBLE"]
    local _, getAutoDribble = createToggle(parent, "Auto Dribble (Dodge)", false, function(v) end)
    uiRefs.toggles.autoDribble = getAutoDribble
    uiRefs.buttons.rainbowFlick = createButton(parent, "RAINBOW FLICK", Color3.fromRGB(60, 120, 200), function() end)
end

-- GOALKEEPER
do
    local parent = tabContents["GOALKEEPER"]
    local _, getAutoGK = createToggle(parent, "Auto Goalkeeper", false, function(v) end)
    uiRefs.toggles.autoGK = getAutoGK
    -- Dive direction cycle
    local dirs = {"SMART", "FORWARD", "LEFT", "RIGHT", "SIDES"}
    local dirIdx = 1
    local dirBtn = createButton(parent, "Dive: SMART", Color3.fromRGB(70, 70, 80), function()
        dirIdx = dirIdx % #dirs + 1
        dirBtn.Text = "Dive: " .. dirs[dirIdx]
    end)
    uiRefs.buttons.diveDir = dirBtn
    uiRefs.getDiveDir = function() return dirs[dirIdx] end

    local _, getHighBall = createToggle(parent, "High Ball Jumps", false, function(v) end)
    uiRefs.toggles.highBall = getHighBall
end

-- MISC
do
    local parent = tabContents["MISC"]
    local _, getESP = createToggle(parent, "ESP (Boxes)", false, function(v) end)
    uiRefs.toggles.esp = getESP
    uiRefs.buttons.rejoin = createButton(parent, "REJOIN SERVER", Color3.fromRGB(60, 120, 200), function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LP)
        end)
    end)
    uiRefs.buttons.unload = createButton(parent, "UNLOAD SCRIPT", Color3.fromRGB(200, 60, 60), function()
        pcall(function()
            screenGui:Destroy()
        end)
        _G.FootballAssist = nil
    end)
    local _, getTP = createToggle(parent, "Teleport To Ball (RISKY)", false, function(v) end)
    uiRefs.toggles.teleport = getTP
end

switchTab("MOVEMENT")

-- Reopen button (small floating button)
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 50, 0, 50)
openBtn.Position = UDim2.new(0, 10, 0, 10)
openBtn.BackgroundColor3 = Color3.fromRGB(70, 120, 200)
openBtn.Text = "IS"
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.TextSize = 14
openBtn.Font = Enum.Font.GothamBold
openBtn.BorderSizePixel = 0
openBtn.Visible = false
openBtn.Parent = screenGui
pcall(function()
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 25)
    c.Parent = openBtn
end)
openBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = true
    openBtn.Visible = false
end)
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    openBtn.Visible = true
end)

-- ============================================================
-- 2. NOTIFICATION
-- ============================================================
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "IS Assist",
        Text = "Script loaded. UI opened.",
        Duration = 4
    })
end)

-- ============================================================
-- 3. MODULE LOADING (pcall)
-- ============================================================
local M = {}
local function safeRequire(path)
    local ok, result = pcall(function()
        local obj = ReplicatedStorage
        for _, part in ipairs(path) do
            obj = obj:WaitForChild(part, 5)
            if not obj then return nil end
        end
        return require(obj)
    end)
    if ok then return result end
    return nil
end

M.Sprint = safeRequire({"Modules", "Actions", "Sprint"})
M.ClientSprint = safeRequire({"Client", "Gameplay", "Player", "Sprint"})
M.Movement = safeRequire({"Client", "Gameplay", "Player", "Movement"})
M.Shoot = safeRequire({"Modules", "Actions", "Shoot"})
M.KickCore = safeRequire({"Modules", "Actions", "KickCore"})
M.KickPowerups = safeRequire({"Modules", "Actions", "KickPowerups"})
M.ActionCommands = safeRequire({"Modules", "Actions", "ActionCommands"})
M.ActionRemoteProtocol = safeRequire({"Modules", "Actions", "ActionRemoteProtocol"})
M.GoalkeeperDive = safeRequire({"Modules", "Actions", "GoalkeeperDive"})
M.GoalkeeperDiveAssist = safeRequire({"Modules", "Actions", "GoalkeeperDiveAssist"})
M.GoalkeeperActions = safeRequire({"Modules", "Actions", "GoalkeeperActions"})
M.GoalkeeperPrediction = safeRequire({"Modules", "Gameplay", "GoalkeeperPrediction"})
M.GoalkeeperPositioning = safeRequire({"Modules", "Gameplay", "GoalkeeperPositioning"})
M.GoalkeeperRole = safeRequire({"Client", "Gameplay", "Player", "GoalkeeperRole"})
M.Physics = safeRequire({"Modules", "Ball", "Physics"})
M.Carry = safeRequire({"Modules", "Ball", "Carry"})
M.Renderer = safeRequire({"Client", "Gameplay", "Ball", "Renderer"})
M.CharacterControllers = safeRequire({"Modules", "Characters", "CharacterControllers"})
M.CharacterMotion = safeRequire({"Modules", "Characters", "CharacterMotion"})
M.HitboxSettings = safeRequire({"Modules", "Gameplay", "HitboxSettings"})
M.MatchSettings = safeRequire({"Modules", "Gameplay", "MatchSettings"})
M.ActorTeams = safeRequire({"Client", "Gameplay", "ActorTeams"})
M.PracticeSession = safeRequire({"Client", "Gameplay", "PracticeSession"})
M.Actors = safeRequire({"Modules", "Characters", "Actors"})
M.ActionLocks = safeRequire({"Modules", "Actions", "ActionLocks"})
M.ActionChargeState = safeRequire({"Modules", "Actions", "ActionChargeState"})
M.Dodge = safeRequire({"Modules", "Actions", "Dodge"})
M.ClientDodge = safeRequire({"Client", "Gameplay", "Actions", "Dodge"})
M.RainbowFlick = safeRequire({"Modules", "Actions", "RainbowFlick"})
M.BicycleKick = safeRequire({"Modules", "Actions", "BicycleKick"})
M.SlideTackle = safeRequire({"Modules", "Actions", "SlideTackle"})
M.Controls = safeRequire({"Modules", "Gameplay", "Controls"})
M.Keybinds = safeRequire({"Modules", "Gameplay", "Keybinds"})
M.Reticle = safeRequire({"Client", "Interface", "Reticle"})
M.AimSolver = safeRequire({"Modules", "Actions", "AimSolver"})
M.ShotAimAssist = safeRequire({"Modules", "Actions", "ShotAimAssist"})
M.EndpointAim = safeRequire({"Modules", "Actions", "EndpointAim"})

-- ============================================================
-- 4. REMOTES (pcall)
-- ============================================================
local Remotes = {}
pcall(function()
    local remotesRoot = ReplicatedStorage:WaitForChild("Remotes", 5)
    if remotesRoot then
        local ball = remotesRoot:WaitForChild("Ball", 5)
        if ball then
            Remotes.Tackle = ball:WaitForChild("Tackle", 3)
            Remotes.Kick = ball:WaitForChild("Kick", 3)
            Remotes.State = ball:WaitForChild("State", 3)
            Remotes.RainbowFlick = ball:WaitForChild("RainbowFlick", 3)
        end
        local chars = remotesRoot:WaitForChild("Characters", 5)
        if chars then
            Remotes.MovementBoost = chars:WaitForChild("MovementBoost", 3)
            Remotes.Ragdoll = chars:WaitForChild("Ragdoll", 3)
        end
    end
end)

-- ============================================================
-- 5. HELPERS
-- ============================================================
local sessionCounter = math.floor(workspace:GetServerTimeNow() * 1e6)
local function newSessionId()
    sessionCounter = sessionCounter + 2
    return sessionCounter
end

local function getChar()
    return LP.Character
end

local function getRoot()
    local char = getChar()
    if char then return char:FindFirstChild("HumanoidRootPart") end
    return nil
end

local function getHum()
    local char = getChar()
    if char then return char:FindFirstChildOfClass("Humanoid") end
    return nil
end

local function getCam()
    return workspace.CurrentCamera
end

local function unit(v)
    if v and v.Magnitude > 0 then return v.Unit end
    return Vector3.new(0, 0, 1)
end

-- ============================================================
-- 6. COMMAND BUILDERS
-- ============================================================
local function buildShotStart(aimDir, chargeSec, curve)
    local root = getRoot()
    local ballPos = Vector3.new(0, 0, 0)
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    local sid = newSessionId()
    local now = workspace:GetServerTimeNow()
    local cmd = {
        Phase = "Start",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = chargeSec or 0.4,
            SessionId = sid,
            ShotTime = now,
            AimDirection = {
                Direction = aimDir,
                Origin = ballPos,
                CameraCFrame = getCam().CFrame,
                IsAirborne = false,
            },
            PassType = "Shot",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Kind = "Tackle",
            Mode = "Kick",
            KickDirection = aimDir,
        }
    }
    return cmd, sid, now
end

local function buildShotRelease(aimDir, sid, startTime, chargeSec, curve)
    local root = getRoot()
    local ballPos = Vector3.new(0, 0, 0)
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    local cmd = {
        Phase = "Release",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = chargeSec or 0.4,
            ChargeStartedAt = startTime,
            SessionId = sid,
            ShotTime = workspace:GetServerTimeNow(),
            AimDirection = {
                Direction = aimDir,
                Origin = ballPos,
                CameraCFrame = getCam().CFrame,
                IsAirborne = false,
            },
            PassType = "Shot",
            KickDirection = aimDir,
            Kind = "Tackle",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Mode = "Kick",
            ChargeSeconds = chargeSec or 0.4,
        }
    }
    if curve and curve ~= 0 then
        cmd.Command.Curve = curve
    end
    return cmd
end

local function buildDodge(direction)
    local root = getRoot()
    return {
        Protocol = "ActionCommand",
        Command = {
            Mode = "Dodge",
            Kind = "Tackle",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            AimDirection = direction or Vector3.new(0, 0, 1),
        }
    }
end

local function buildSlide(direction)
    local root = getRoot()
    return {
        Protocol = "ActionCommand",
        Command = {
            Mode = "Slide",
            Kind = "Tackle",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            AimDirection = direction or Vector3.new(0, 0, 1),
        }
    }
end

-- ============================================================
-- 7. FEATURE FUNCTIONS
-- ============================================================

-- 7.1 Infinite Stamina
local function applyInfiniteStamina(enable)
    if not M.Sprint then return false end
    local ok = pcall(function()
        M.Sprint.SetUnlimitedStamina("v6")
    end)
    if not ok then
        ok = pcall(function() M.Sprint.SetUnlimitedStamina(true) end)
    end
    if not ok then
        ok = pcall(function() M.Sprint.SetUnlimitedStamina("v6", true) end)
    end
    if not enable and ok then
        pcall(function()
            if M.Sprint.ClearUnlimitedStaminaSource then
                M.Sprint.ClearUnlimitedStaminaSource("v6")
            end
        end)
    end
    return ok
end

-- 7.2 Speed
local function applySpeed(mult)
    if not M.Movement then return false end
    local char = getChar()
    if not char then return false end
    return pcall(function()
        M.Movement.SetMultiplier(char, mult)
    end)
end

-- 7.3 Jump
local function applyJumpBoost(enable)
    local hum = getHum()
    if not hum then return false end
    return pcall(function()
        hum.JumpPower = enable and 120 or 50
        hum.UseJumpPower = true
    end)
end

-- 7.4 Get goal position
local function getGoalPosition()
    local root = getRoot()
    if not root then return nil end
    -- Try PracticeSession
    if M.PracticeSession then
        local ok, goalPart = pcall(function()
            return M.PracticeSession.GetDefendedGoalPart()
        end)
        if ok and goalPart and goalPart.Position then
            return goalPart.Position
        end
    end
    -- Fallback: search workspace for goal
    local goal = workspace:FindFirstChild("Goal", true)
    if goal and goal:IsA("BasePart") then
        return goal.Position
    end
    return nil
end

-- 7.5 Get goalkeeper position (opponent)
local function getOpponentGoalkeeperPos()
    local myTeam = nil
    pcall(function()
        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
            myTeam = M.ActorTeams.GetCharacterTeamName(LP.Character)
        end
    end)
    local gkPos = nil
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local player = Players:GetPlayerFromCharacter(model)
                if player and player ~= LP then
                    local isGK = false
                    pcall(function()
                        if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter then
                            isGK = M.MatchSettings.IsGoalkeeperCharacter(model)
                        end
                    end)
                    if isGK then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            gkPos = hrp.Position
                            break
                        end
                    end
                end
            end
        end
    end)
    return gkPos
end

-- 7.6 Perfect Shot
local function firePerfectShot(overrideCurve)
    if not Remotes.Tackle then return false end
    local root = getRoot()
    if not root then return false end
    local ballPos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    if not ballPos then return false end

    local goalPos = getGoalPosition()
    if not goalPos then return false end

    local gkPos = getOpponentGoalkeeperPos()

    -- Determine target corner
    local goalOffset = Vector3.new(0, 0, 0)
    local goalWidth = 12
    if gkPos then
        local lateral = gkPos - goalPos
        lateral = Vector3.new(lateral.X, 0, lateral.Z)
        if lateral.Magnitude > 0.1 then
            -- Shoot to opposite side
            local side = lateral.Unit
            goalOffset = side * (goalWidth * 0.5 + 2) + Vector3.new(0, 2, 0)
        else
            goalOffset = Vector3.new(0, 2, 0)
        end
    else
        goalOffset = Vector3.new(0, 2, 0)
    end

    local target = goalPos + goalOffset
    local direction = unit(target - ballPos)

    -- Curve
    local curve = 0
    if overrideCurve then
        curve = overrideCurve
    elseif gkPos then
        local lateral = gkPos - goalPos
        lateral = Vector3.new(lateral.X, 0, lateral.Z)
        if lateral.Magnitude > 0.1 then
            local dot = lateral.Unit:Dot(unit(goalPos - ballPos))
            curve = dot > 0 and -1 or 1
        end
    end

    local cmdStart, sid, startTime = buildShotStart(direction, 0.4, curve)
    pcall(function()
        Remotes.Tackle:FireServer(cmdStart)
    end)
    task.wait(0.42)
    local cmdRelease = buildShotRelease(direction, sid, startTime, 0.4, curve)
    pcall(function()
        Remotes.Tackle:FireServer(cmdRelease)
    end)
    return true
end

-- 7.7 Fake Shot
local function fireFakeShot()
    if not Remotes.Tackle then return false end
    local root = getRoot()
    if not root then return false end
    local ballPos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    if not ballPos then return false end
    local goalPos = getGoalPosition() or (ballPos + Vector3.new(0, 0, 20))
    local direction = unit(goalPos - ballPos)
    local cmdStart, sid, startTime = buildShotStart(direction, 0.4, 0)
    pcall(function()
        Remotes.Tackle:FireServer(cmdStart)
    end)
    task.wait(0.15)
    local dodgeCmd = buildDodge(direction)
    pcall(function()
        Remotes.Tackle:FireServer(dodgeCmd)
    end)
    return true
end

-- 7.8 Wall Shot
local function fireWallShot()
    if not Remotes.Tackle then return false end
    local root = getRoot()
    if not root then return false end
    local ballPos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    if not ballPos then return false end

    -- Find nearest wall
    local walls = nil
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        if map then
            local data = map:FindFirstChild("Data")
            if data then
                walls = data:FindFirstChild("Walls")
            end
        end
    end)
    local wallPos = nil
    if walls then
        local bestDist = math.huge
        for _, wall in ipairs(walls:GetChildren()) do
            if wall:IsA("BasePart") then
                local d = (wall.Position - ballPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    wallPos = wall.Position
                end
            end
        end
    end
    if not wallPos then
        -- Fallback: shoot backward
        wallPos = ballPos - unit(getCam().CFrame.LookVector) * 20
    end
    local direction = unit(wallPos - ballPos)
    local cmdStart, sid, startTime = buildShotStart(direction, 0.4, 0)
    pcall(function()
        Remotes.Tackle:FireServer(cmdStart)
    end)
    task.wait(0.42)
    local cmdRelease = buildShotRelease(direction, sid, startTime, 0.4, 0)
    pcall(function()
        Remotes.Tackle:FireServer(cmdRelease)
    end)
    return true
end

-- 7.9 Perfect Pass
local function firePerfectPass()
    if not Remotes.Kick then return false end
    local root = getRoot()
    if not root then return false end
    local ballPos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    if not ballPos then return false end

    -- Find teammate
    local teammateId = nil
    local bestDist = math.huge
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local sameTeam = false
                    pcall(function()
                        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
                            local myTeam = M.ActorTeams.GetCharacterTeamName(LP.Character)
                            local theirTeam = M.ActorTeams.GetCharacterTeamName(model)
                            sameTeam = (myTeam == theirTeam)
                        end
                    end)
                    if sameTeam then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (hrp.Position - ballPos).Magnitude
                            if d < bestDist then
                                bestDist = d
                                teammateId = plr.UserId
                            end
                        end
                    end
                end
            end
        end
    end)
    if not teammateId then return false end

    local cmd = {
        Phase = "Release",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = 0.4,
            ChargeStartedAt = workspace:GetServerTimeNow(),
            SessionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            AimDirection = {
                Direction = unit(getCam().CFrame.LookVector),
                Origin = ballPos,
                CameraCFrame = getCam().CFrame,
                IsAirborne = false,
            },
            PassType = "AssistedPass",
            TargetUserId = teammateId,
            KickDirection = unit(getCam().CFrame.LookVector),
            Kind = "Tackle",
            PlayerVelocity = root.AssemblyLinearVelocity,
            Mode = "Kick",
            ChargeSeconds = 0.4,
        }
    }
    pcall(function()
        Remotes.Kick:FireServer(cmd)
    end)
    return true
end

-- 7.10 Rainbow Flick
local function fireRainbowFlick()
    if not Remotes.Tackle then return false end
    local root = getRoot()
    if not root then return false end
    local ballPos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    if not ballPos then return false end
    local direction = unit(getCam().CFrame.LookVector)
    local cmd1 = {
        Protocol = "ActionCommand",
        Command = {
            Kind = "RainbowFlick",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root.AssemblyLinearVelocity,
            AimDirection = direction,
        }
    }
    pcall(function()
        Remotes.Tackle:FireServer(cmd1)
    end)
    task.wait(0.4)
    local cmd2 = {
        Protocol = "ActionCommand",
        Command = {
            Mode = "RainbowFlickDetach",
            Kind = "Tackle",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root.AssemblyLinearVelocity,
            AimDirection = direction,
        }
    }
    pcall(function()
        Remotes.Tackle:FireServer(cmd2)
    end)
    return true
end

-- 7.11 Auto Dribble (listen to Tackle remote)
local lastDodgeTime = 0
local function setupAutoDribble()
    if not Remotes.Tackle then return end
    Remotes.Tackle.OnClientEvent:Connect(function(...)
        pcall(function()
            if not uiRefs.toggles.autoDribble or not uiRefs.toggles.autoDribble() then return end
            local args = {...}
            local cmd = args[1]
            if type(cmd) ~= "table" then return end
            local c = cmd.Command or cmd
            if not c or c.Kind ~= "Tackle" then return end
            if c.Mode ~= "Slide" and c.Mode ~= "Kick" and c.Mode ~= "Volley" then return end
            if c.ActorUserId == LP.UserId then return end
            -- Find opponent
            local opponentRoot = nil
            local opponentPlayer = nil
            pcall(function()
                if M.Actors and M.Actors.GetByUserId and c.ActorUserId then
                    local actor = M.Actors.GetByUserId(c.ActorUserId)
                    if actor then
                        local model = M.Actors.GetCharacter(actor)
                        if model then
                            opponentRoot = model:FindFirstChild("HumanoidRootPart")
                            opponentPlayer = Players:GetPlayerByUserId(c.ActorUserId)
                        end
                    end
                end
            end)
            if not opponentRoot then return end
            local myRoot = getRoot()
            if not myRoot then return end
            local dist = (opponentRoot.Position - myRoot.Position).Magnitude
            if dist < 8 then
                local now = tick()
                if now - lastDodgeTime < 1 then return end
                lastDodgeTime = now
                local awayDir = unit(myRoot.Position - opponentRoot.Position)
                local dodgeCmd = buildDodge(awayDir)
                pcall(function()
                    Remotes.Tackle:FireServer(dodgeCmd)
                end)
            end
        end)
    end)
end
setupAutoDribble()

-- 7.12 Auto Goalkeeper (simplified robust)
local lastDiveTime = 0
local function autoGoalkeeperTick()
    if not uiRefs.toggles.autoGK or not uiRefs.toggles.autoGK() then return end
    local char = getChar()
    if not char then return end
    local isGK = false
    pcall(function()
        if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter then
            isGK = M.MatchSettings.IsGoalkeeperCharacter(char)
        end
    end)
    if not isGK then return end

    local now = tick()
    if now - lastDiveTime < 1.2 then return end

    local ballState = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetAuthoritativeMovementState then
            ballState = M.Renderer.GetAuthoritativeMovementState()
        end
    end)
    if not ballState then return end

    local goalPart = nil
    pcall(function()
        if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
            goalPart = M.PracticeSession.GetDefendedGoalPart()
        end
    end)
    if not goalPart then return end

    -- Simple prediction
    local root = getRoot()
    if not root then return end
    local ballPos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    if not ballPos then return end

    -- If ball is close to goal and moving towards it
    local goalPos = goalPart.Position
    local distToGoal = (ballPos - goalPos).Magnitude
    if distToGoal > 40 then return end

    -- Determine dive direction
    local diveDir = uiRefs.getDiveDir and uiRefs.getDiveDir() or "SMART"
    local directionName = "F"
    local aimDir = unit(ballPos - root.Position)

    if diveDir == "SMART" then
        local lateral = ballPos - goalPos
        lateral = Vector3.new(lateral.X, 0, lateral.Z)
        if lateral.Magnitude > 3 then
            local side = lateral.Unit
            local myLateral = root.Position - goalPos
            myLateral = Vector3.new(myLateral.X, 0, myLateral.Z)
            if myLateral:Dot(side) > 0 then
                directionName = "R"
            else
                directionName = "L"
            end
        end
    elseif diveDir == "LEFT" then
        directionName = "L"
    elseif diveDir == "RIGHT" then
        directionName = "R"
    elseif diveDir == "SIDES" then
        local lateral = ballPos - goalPos
        lateral = Vector3.new(lateral.X, 0, lateral.Z)
        directionName = lateral.X > 0 and "R" or "L"
    end

    -- Try GoalkeeperDive.Run
    local hum = getHum()
    local dived = false
    if M.GoalkeeperDive and M.GoalkeeperDive.Run then
        pcall(function()
            local choice = nil
            if M.GoalkeeperDive.GetDirectionChoiceByName then
                choice = M.GoalkeeperDive.GetDirectionChoiceByName(directionName)
            end
            if choice then
                local basisFn = function() return CFrame.new(goalPos, goalPos + Vector3.new(0, 0, -1)) end
                M.GoalkeeperDive.Run(root, hum, choice, basisFn, {})
                dived = true
            end
        end)
    end

    -- Fallback: Fire command directly
    if not dived and Remotes.Tackle then
        local cmd = {
            Protocol = "ActionCommand",
            Command = {
                Mode = "GoalkeeperDive",
                Kind = "Tackle",
                ActionId = newSessionId(),
                ShotTime = workspace:GetServerTimeNow(),
                PlayerVelocity = root.AssemblyLinearVelocity,
                AimDirection = aimDir,
                DirectionName = directionName,
            }
        }
        pcall(function()
            Remotes.Tackle:FireServer(cmd)
        end)
    end
    lastDiveTime = now
end

-- 7.13 Bicycle Kick (auto when airborne)
local function autoBicycleTick()
    -- Only if perfect shot is on or user wants? Not exposed as toggle, skip for now
end

-- 7.14 ESP
local espObjects = {}
local function updateESP()
    local enable = uiRefs.toggles.esp and uiRefs.toggles.esp()
    if not enable then
        for _, obj in pairs(espObjects) do
            pcall(function() obj:Destroy() end)
        end
        espObjects = {}
        return
    end
    -- Create for all players
    local allChars = {}
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            allChars = M.Actors.GetAllCharacterModels()
        end
    end)
    for _, model in ipairs(allChars) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp and not espObjects[model] then
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 40, 0, 20)
            billboard.AlwaysOnTop = true
            billboard.Adornee = hrp
            billboard.Parent = screenGui
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = model.Name
            label.TextColor3 = Color3.fromRGB(255, 255, 100)
            label.TextSize = 10
            label.Parent = billboard
            espObjects[model] = billboard
        end
    end
    -- Cleanup destroyed
    for model, obj in pairs(espObjects) do
        if not model.Parent or not model:FindFirstChild("HumanoidRootPart") then
            pcall(function() obj:Destroy() end)
            espObjects[model] = nil
        end
    end
end

-- 7.15 Teleport to Ball (risky, manual only)
local function teleportToBall()
    if not uiRefs.toggles.teleport or not uiRefs.toggles.teleport() then return end
    local ballPos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            ballPos = M.Renderer.GetPosition()
        end
    end)
    if not ballPos then return end
    local char = getChar()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        hrp.CFrame = CFrame.new(ballPos + Vector3.new(0, 5, 0))
    end)
end

-- ============================================================
-- 8. BUTTON CALLBACKS
-- ============================================================
-- Movement
local infStamActive = false
local origSetToggle = uiRefs.toggles.infStam
-- We need to wire the actual callbacks; easier: override after creation
-- Since createToggle already returns getter, we'll just use a separate loop? 
-- Better: re-create toggles with callbacks now. But they already exist.
-- Workaround: attach MouseButton1Click to existing toggle buttons is complex.
-- Instead, we'll poll states in main loop for toggles that need continuous application.
-- For one-shot buttons, wire here.

uiRefs.buttons.fakeShot.MouseButton1Click:Connect(function()
    pcall(fireFakeShot)
end)
uiRefs.buttons.wallShot.MouseButton1Click:Connect(function()
    pcall(fireWallShot)
end)
uiRefs.buttons.pass.MouseButton1Click:Connect(function()
    pcall(firePerfectPass)
end)
uiRefs.buttons.rainbowFlick.MouseButton1Click:Connect(function()
    pcall(fireRainbowFlick)
end)
uiRefs.buttons.rejoin.MouseButton1Click:Connect(function()
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
end)
uiRefs.buttons.unload.MouseButton1Click:Connect(function()
    pcall(function()
        screenGui:Destroy()
    end)
    _G.FootballAssist = nil
end)

-- ============================================================
-- 9. MAIN LOOP (Heartbeat, xpcall protected)
-- ============================================================
local heartbeatConn = RunService.Heartbeat:Connect(function()
    xpcall(function()
        -- Infinite stamina
        if uiRefs.toggles.infStam then
            local on = uiRefs.toggles.infStam()
            if on ~= infStamActive then
                infStamActive = on
                applyInfiniteStamina(on)
            end
        end
        -- Speed
        if uiRefs.sliders.speed then
            local mult = uiRefs.sliders.speed()
            applySpeed(mult)
        end
        -- Jump
        if uiRefs.toggles.jumpBoost then
            local on = uiRefs.toggles.jumpBoost()
            applyJumpBoost(on)
        end
        -- Perfect shot auto fire
        if uiRefs.toggles.perfectShot and uiRefs.toggles.perfectShot() then
            local owned = false
            pcall(function()
                if M.Renderer and M.Renderer.GetOwnedUserId then
                    owned = (M.Renderer.GetOwnedUserId() == LP.UserId)
                end
            end)
            if owned then
                -- Only fire if not charging
                local charging = false
                pcall(function()
                    if M.ActionChargeState and M.ActionChargeState.IsCharging then
                        charging = M.ActionChargeState.IsCharging()
                    end
                end)
                if not charging then
                    local curveMode = uiRefs.getCurveMode and uiRefs.getCurveMode() or "OFF"
                    local curve = nil
                    if curveMode == "LEFT" then curve = -1
                    elseif curveMode == "RIGHT" then curve = 1
                    elseif curveMode == "AUTO" then curve = nil
                    else curve = 0 end
                    firePerfectShot(curve)
                end
            end
        end
        -- Auto goalkeeper
        autoGoalkeeperTick()
        -- ESP
        updateESP()
        -- Teleport
        teleportToBall()
    end, function(err)
        -- silently ignore
    end)
end)

-- ============================================================
-- 10. PUBLIC API
-- ============================================================
_G.FootballAssist = {
    UI = screenGui,
    Modules = M,
    Remotes = Remotes,
    FirePerfectShot = firePerfectShot,
    FireFakeShot = fireFakeShot,
    FireWallShot = fireWallShot,
    FirePerfectPass = firePerfectPass,
    FireRainbowFlick = fireRainbowFlick,
    SetSpeed = applySpeed,
    SetInfiniteStamina = applyInfiniteStamina,
    SetJumpBoost = applyJumpBoost,
    Version = "1.0",
}