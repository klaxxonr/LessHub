-- Illegal Soccer Assist v1.1 (Mobile / Delta / Xeno)
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
screenGui.Name = "IS_Assist_" .. tostring(math.random(100000, 999999))
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() screenGui.DisplayOrder = 999999 end)
pcall(function() screenGui.Enabled = true end)

-- Robust UI parent: gethui -> PlayerGui -> CoreGui
local function getBestUIParent()
    local gethuiFn = rawget(_G, "gethui")
    if type(gethuiFn) == "function" then
        local ok, hui = pcall(gethuiFn)
        if ok and hui then return hui, "gethui" end
    end
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then pcall(function() pg = LP:WaitForChild("PlayerGui", 3) end) end
    if pg then return pg, "PlayerGui" end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg, "CoreGui" end
    return nil, nil
end

local uiParent, parentName = getBestUIParent()
local parentOk = false
if uiParent then
    parentOk = pcall(function() screenGui.Parent = uiParent end) and screenGui.Parent ~= nil
end
if not parentOk then
    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
end

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 320, 0, 520)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = true
mainFrame.ZIndex = 10
pcall(function() mainFrame.Draggable = true end)
mainFrame.Parent = screenGui
pcall(function()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = mainFrame
end)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 11
titleBar.Parent = mainFrame
pcall(function()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = titleBar
end)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 12, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "IS ASSIST"
titleText.TextColor3 = Color3.fromRGB(220, 220, 230)
titleText.TextSize = 16
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.ZIndex = 12
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
closeBtn.ZIndex = 12
closeBtn.Parent = titleBar
pcall(function()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = closeBtn
end)

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -8, 0, 34)
tabBar.Position = UDim2.new(0, 4, 0, 40)
tabBar.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 11
tabBar.Parent = mainFrame
pcall(function()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = tabBar
end)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 2)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -8, 1, -84)
contentFrame.Position = UDim2.new(0, 4, 0, 78)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 10
contentFrame.Parent = mainFrame

local tabNames = {"MOVEMENT", "SHOT", "DRIBBLE", "GK", "MISC"}
local tabButtons = {}

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 58, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 190)
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.LayoutOrder = i
    btn.ZIndex = 12
    btn.Parent = tabBar
    pcall(function()
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = btn
    end)
    tabButtons[name] = btn
end

-- Tab content frames (created upfront, visible=false)
local tabContents = {}
for _, name in ipairs(tabNames) do
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.ZIndex = 10
    frame.Parent = contentFrame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 14
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ZIndex = 11
    pcall(function() scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    scroll.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    -- CanvasSize fallback if AutomaticCanvasSize is unsupported
    pcall(function()
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            pcall(function()
                scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(layout.AbsoluteContentSize.Y + 20, 100))
            end)
        end)
    end)

    tabContents[name] = scroll
end

local function switchTab(tabName)
    for n, btn in pairs(tabButtons) do
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        btn.TextColor3 = Color3.fromRGB(180, 180, 190)
    end
    if tabButtons[tabName] then
        tabButtons[tabName].BackgroundColor3 = Color3.fromRGB(70, 120, 200)
        tabButtons[tabName].TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    for n, child in pairs(tabContents) do
        local tabFrame = child.Parent
        if tabFrame then
            tabFrame.Visible = (n == tabName)
        end
    end
end

for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        pcall(switchTab, name)
    end)
end

-- Helper widgets
local function createToggle(parent, text, default)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -8, 0, 44)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    container.BorderSizePixel = 0
    container.Parent = parent
    pcall(function()
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = container
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
    toggleBtn.Position = UDim2.new(1, -68, 0, 7)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(70, 70, 80)
    toggleBtn.Text = default and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 11
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = container
    pcall(function()
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = toggleBtn
    end)

    local state = default
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(70, 70, 80)
        toggleBtn.Text = state and "ON" or "OFF"
    end)
    return container, function() return state end
end

local function createButton(parent, text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 44)
    btn.BackgroundColor3 = color or Color3.fromRGB(60, 120, 200)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = parent
    pcall(function()
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)
    return btn
end

local function createSlider(parent, text, min, max, default)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -8, 0, 62)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    container.BorderSizePixel = 0
    container.Parent = parent
    pcall(function()
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = container
    end)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. string.format("%.2f", default)
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -20, 0, 10)
    barBg.Position = UDim2.new(0, 10, 0, 34)
    barBg.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    barBg.BorderSizePixel = 0
    barBg.Parent = container
    pcall(function()
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = barBg
    end)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(70, 140, 220)
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    pcall(function()
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = fill
    end)

    local val = default
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local function update(i)
                local pos = i.Position.X - barBg.AbsolutePosition.X
                local pct = math.clamp(pos / math.max(barBg.AbsoluteSize.X, 1), 0, 1)
                val = min + (max - min) * pct
                fill.Size = UDim2.new(pct, 0, 1, 0)
                label.Text = text .. ": " .. string.format("%.2f", val)
            end
            update(input)
            local conn
            conn = UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                    update(i)
                end
            end)
            local endConn
            endConn = UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    if conn then conn:Disconnect() end
                    if endConn then endConn:Disconnect() end
                end
            end)
        end
    end)
    return container, function() return val end
end

-- Populate tabs
local uiRefs = { toggles = {}, sliders = {}, buttons = {} }

do
    local parent = tabContents["MOVEMENT"]
    uiRefs.toggles.infStam = select(2, createToggle(parent, "Infinite Stamina", false))
    uiRefs.sliders.speed = select(2, createSlider(parent, "Speed Multiplier", 1.0, 2.5, 1.0))
    uiRefs.toggles.jumpBoost = select(2, createToggle(parent, "Jump Boost (120)", false))
end

do
    local parent = tabContents["SHOT"]
    uiRefs.toggles.perfectShot = select(2, createToggle(parent, "Perfect Shot (Auto Aim)", false))
    local curveModes = {"OFF", "LEFT", "RIGHT", "AUTO"}
    local curveIdx = 1
    local curveBtn = createButton(parent, "Curve: OFF", Color3.fromRGB(70, 70, 80), function()
        curveIdx = curveIdx % #curveModes + 1
        curveBtn.Text = "Curve: " .. curveModes[curveIdx]
        curveBtn.BackgroundColor3 = curveIdx == 1 and Color3.fromRGB(70, 70, 80) or Color3.fromRGB(60, 120, 200)
    end)
    uiRefs.getCurveMode = function() return curveModes[curveIdx] end
    uiRefs.buttons.fakeShot = createButton(parent, "FAKE SHOT", Color3.fromRGB(60, 120, 200), nil)
    uiRefs.buttons.wallShot = createButton(parent, "WALL SHOT", Color3.fromRGB(60, 120, 200), nil)
    uiRefs.buttons.pass = createButton(parent, "PERFECT PASS", Color3.fromRGB(60, 120, 200), nil)
end

do
    local parent = tabContents["DRIBBLE"]
    uiRefs.toggles.autoDribble = select(2, createToggle(parent, "Auto Dribble (Dodge)", false))
    uiRefs.buttons.rainbowFlick = createButton(parent, "RAINBOW FLICK", Color3.fromRGB(60, 120, 200), nil)
end

do
    local parent = tabContents["GK"]
    uiRefs.toggles.autoGK = select(2, createToggle(parent, "Auto Goalkeeper", false))
    local dirs = {"SMART", "FORWARD", "LEFT", "RIGHT", "SIDES"}
    local dirIdx = 1
    local dirBtn = createButton(parent, "Dive: SMART", Color3.fromRGB(70, 70, 80), function()
        dirIdx = dirIdx % #dirs + 1
        dirBtn.Text = "Dive: " .. dirs[dirIdx]
    end)
    uiRefs.getDiveDir = function() return dirs[dirIdx] end
    uiRefs.toggles.highBall = select(2, createToggle(parent, "High Ball Jumps", false))
end

do
    local parent = tabContents["MISC"]
    uiRefs.toggles.esp = select(2, createToggle(parent, "ESP (Boxes)", false))
    uiRefs.buttons.rejoin = createButton(parent, "REJOIN SERVER", Color3.fromRGB(60, 120, 200), function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    end)
    uiRefs.buttons.unload = createButton(parent, "UNLOAD SCRIPT", Color3.fromRGB(200, 60, 60), function()
        pcall(function() screenGui:Destroy() end)
        _G.FootballAssist = nil
    end)
    uiRefs.toggles.teleport = select(2, createToggle(parent, "Teleport To Ball (RISKY)", false))
end

-- CRITICAL: actually show the first tab
switchTab("MOVEMENT")

-- Floating reopen button
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
openBtn.ZIndex = 999
openBtn.Parent = screenGui
pcall(function()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 25); c.Parent = openBtn
end)
openBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = true
    openBtn.Visible = false
end)

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    openBtn.Visible = true
end)

-- Failsafe: ensure UI is visible after 2 seconds
task.delay(2, function()
    pcall(function()
        if not screenGui.Parent then
            screenGui.Parent = game:GetService("CoreGui")
        end
        screenGui.Enabled = true
        mainFrame.Visible = true
    end)
end)

-- ============================================================
-- 2. NOTIFICATION (non-blocking)
-- ============================================================
task.spawn(function()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "IS Assist",
            Text = "Loaded. UI opened. Parent: " .. tostring(parentName),
            Duration = 4
        })
    end)
end)

-- ============================================================
-- 3. MODULE LOADING (pcall, short timeout)
-- ============================================================
local M = {}
local function safeRequire(path)
    local ok, result = pcall(function()
        local obj = ReplicatedStorage
        for _, part in ipairs(path) do
            obj = obj:FindFirstChild(part) or obj:WaitForChild(part, 2)
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
M.ActionCommands = safeRequire({"Modules", "Actions", "ActionCommands"})
M.GoalkeeperDive = safeRequire({"Modules", "Actions", "GoalkeeperDive"})
M.GoalkeeperPrediction = safeRequire({"Modules", "Gameplay", "GoalkeeperPrediction"})
M.Renderer = safeRequire({"Client", "Gameplay", "Ball", "Renderer"})
M.MatchSettings = safeRequire({"Modules", "Gameplay", "MatchSettings"})
M.ActorTeams = safeRequire({"Client", "Gameplay", "ActorTeams"})
M.PracticeSession = safeRequire({"Client", "Gameplay", "PracticeSession"})
M.Actors = safeRequire({"Modules", "Characters", "Actors"})
M.ActionChargeState = safeRequire({"Modules", "Actions", "ActionChargeState"})
M.RainbowFlick = safeRequire({"Modules", "Actions", "RainbowFlick"})
M.BicycleKick = safeRequire({"Modules", "Actions", "BicycleKick"})

-- ============================================================
-- 4. REMOTES (pcall)
-- ============================================================
local Remotes = {}
pcall(function()
    local remotesRoot = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
    if remotesRoot then
        local ball = remotesRoot:FindFirstChild("Ball") or remotesRoot:WaitForChild("Ball", 3)
        if ball then
            Remotes.Tackle = ball:FindFirstChild("Tackle") or ball:WaitForChild("Tackle", 3)
            Remotes.Kick = ball:FindFirstChild("Kick") or ball:WaitForChild("Kick", 3)
            Remotes.RainbowFlick = ball:FindFirstChild("RainbowFlick")
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

local function getRoot()
    local char = LP.Character
    if char then return char:FindFirstChild("HumanoidRootPart") end
    return nil
end

local function getHum()
    local char = LP.Character
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
local function buildShotStart(aimDir)
    local root = getRoot()
    local ballPos = Vector3.new(0, 0, 0)
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end
    end)
    local sid = newSessionId()
    local now = workspace:GetServerTimeNow()
    return {
        Phase = "Start",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = 0.4,
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
    }, sid, now
end

local function buildShotRelease(aimDir, sid, startTime, curve)
    local root = getRoot()
    local ballPos = Vector3.new(0, 0, 0)
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end
    end)
    local cmd = {
        Phase = "Release",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = 0.4,
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
            ChargeSeconds = 0.4,
        }
    }
    if curve and curve ~= 0 then cmd.Command.Curve = curve end
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

-- ============================================================
-- 7. FEATURES
-- ============================================================
local function applyInfiniteStamina(enable)
    if not M.Sprint then return false end
    local ok = pcall(function() M.Sprint.SetUnlimitedStamina("v6") end)
    if not ok then ok = pcall(function() M.Sprint.SetUnlimitedStamina(true) end) end
    if not ok then ok = pcall(function() M.Sprint.SetUnlimitedStamina("v6", true) end) end
    if not enable and ok then
        pcall(function()
            if M.Sprint.ClearUnlimitedStaminaSource then M.Sprint.ClearUnlimitedStaminaSource("v6") end
        end)
    end
    return ok
end

local function applySpeed(mult)
    if not M.Movement then return false end
    local char = LP.Character
    if not char then return false end
    return pcall(function() M.Movement.SetMultiplier(char, mult) end)
end

local function applyJumpBoost(enable)
    local hum = getHum()
    if not hum then return false end
    return pcall(function()
        hum.UseJumpPower = true
        hum.JumpPower = enable and 120 or 50
    end)
end

local function getGoalPosition()
    if M.PracticeSession then
        local ok, goalPart = pcall(function() return M.PracticeSession.GetDefendedGoalPart() end)
        if ok and goalPart and goalPart.Position then return goalPart.Position end
    end
    local goal = workspace:FindFirstChild("Goal", true)
    if goal and goal:IsA("BasePart") then return goal.Position end
    return nil
end

local function getOpponentGoalkeeperPos()
    local gkPos = nil
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local isGK = false
                    pcall(function()
                        if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter then
                            isGK = M.MatchSettings.IsGoalkeeperCharacter(model)
                        end
                    end)
                    if isGK then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then gkPos = hrp.Position; break end
                    end
                end
            end
        end
    end)
    return gkPos
end

local function firePerfectShot(overrideCurve)
    if not Remotes.Tackle then return false end
    local root = getRoot(); if not root then return false end
    local ballPos = nil
    pcall(function() if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end end)
    if not ballPos then return false end
    local goalPos = getGoalPosition(); if not goalPos then return false end
    local gkPos = getOpponentGoalkeeperPos()
    local goalOffset = Vector3.new(0, 2, 0)
    if gkPos then
        local lateral = Vector3.new((gkPos - goalPos).X, 0, (gkPos - goalPos).Z)
        if lateral.Magnitude > 0.1 then
            goalOffset = lateral.Unit * 8 + Vector3.new(0, 2, 0)
        end
    end
    local target = goalPos + goalOffset
    local direction = unit(target - ballPos)
    local curve = 0
    if overrideCurve then curve = overrideCurve
    elseif gkPos then
        local lateral = Vector3.new((gkPos - goalPos).X, 0, (gkPos - goalPos).Z)
        if lateral.Magnitude > 0.1 then
            local dot = lateral.Unit:Dot(unit(goalPos - ballPos))
            curve = dot > 0 and -1 or 1
        end
    end
    local startCmd, sid, startTime = buildShotStart(direction)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(0.42)
    pcall(function() Remotes.Tackle:FireServer(buildShotRelease(direction, sid, startTime, curve)) end)
    return true
end

local function fireFakeShot()
    if not Remotes.Tackle then return false end
    local ballPos = nil
    pcall(function() if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end end)
    if not ballPos then return false end
    local goalPos = getGoalPosition() or (ballPos + Vector3.new(0, 0, 20))
    local direction = unit(goalPos - ballPos)
    local startCmd = buildShotStart(direction)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(0.15)
    pcall(function() Remotes.Tackle:FireServer(buildDodge(direction)) end)
    return true
end

local function fireWallShot()
    if not Remotes.Tackle then return false end
    local ballPos = nil
    pcall(function() if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end end)
    if not ballPos then return false end
    local walls = nil
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        if map then
            local data = map:FindFirstChild("Data")
            if data then walls = data:FindFirstChild("Walls") end
        end
    end)
    local wallPos = nil
    if walls then
        local best = math.huge
        for _, w in ipairs(walls:GetChildren()) do
            if w:IsA("BasePart") then
                local d = (w.Position - ballPos).Magnitude
                if d < best then best = d; wallPos = w.Position end
            end
        end
    end
    if not wallPos then wallPos = ballPos - unit(getCam().CFrame.LookVector) * 20 end
    local direction = unit(wallPos - ballPos)
    local startCmd, sid, startTime = buildShotStart(direction)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(0.42)
    pcall(function() Remotes.Tackle:FireServer(buildShotRelease(direction, sid, startTime, 0)) end)
    return true
end

local function firePerfectPass()
    if not Remotes.Kick then return false end
    local root = getRoot(); if not root then return false end
    local ballPos = nil
    pcall(function() if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end end)
    if not ballPos then return false end
    local teammateId, bestDist = nil, math.huge
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local same = false
                    pcall(function()
                        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
                            local my = M.ActorTeams.GetCharacterTeamName(LP.Character)
                            local th = M.ActorTeams.GetCharacterTeamName(model)
                            same = (my == th)
                        end
                    end)
                    if same then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (hrp.Position - ballPos).Magnitude
                            if d < bestDist then bestDist = d; teammateId = plr.UserId end
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
    pcall(function() Remotes.Kick:FireServer(cmd) end)
    return true
end

local function fireRainbowFlick()
    if not Remotes.Tackle then return false end
    local root = getRoot(); if not root then return false end
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
    pcall(function() Remotes.Tackle:FireServer(cmd1) end)
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
    pcall(function() Remotes.Tackle:FireServer(cmd2) end)
    return true
end

-- Auto Dribble
local lastDodgeTime = 0
if Remotes.Tackle then
    Remotes.Tackle.OnClientEvent:Connect(function(...)
        pcall(function()
            if not uiRefs.toggles.autoDribble or not uiRefs.toggles.autoDribble() then return end
            local cmd = select(1, ...)
            if type(cmd) ~= "table" then return end
            local c = cmd.Command or cmd
            if not c or c.Kind ~= "Tackle" then return end
            if c.Mode ~= "Slide" and c.Mode ~= "Kick" and c.Mode ~= "Volley" then return end
            if c.ActorUserId == LP.UserId then return end
            local opponentRoot = nil
            pcall(function()
                if M.Actors and M.Actors.GetByUserId and c.ActorUserId then
                    local actor = M.Actors.GetByUserId(c.ActorUserId)
                    if actor then
                        local model = M.Actors.GetCharacter(actor)
                        if model then opponentRoot = model:FindFirstChild("HumanoidRootPart") end
                    end
                end
            end)
            if not opponentRoot then return end
            local myRoot = getRoot(); if not myRoot then return end
            if (opponentRoot.Position - myRoot.Position).Magnitude < 8 then
                local now = tick()
                if now - lastDodgeTime < 1 then return end
                lastDodgeTime = now
                local awayDir = unit(myRoot.Position - opponentRoot.Position)
                pcall(function() Remotes.Tackle:FireServer(buildDodge(awayDir)) end)
            end
        end)
    end)
end

-- Auto GK
local lastDiveTime = 0
local function autoGoalkeeperTick()
    if not uiRefs.toggles.autoGK or not uiRefs.toggles.autoGK() then return end
    local char = LP.Character; if not char then return end
    local isGK = false
    pcall(function()
        if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter then
            isGK = M.MatchSettings.IsGoalkeeperCharacter(char)
        end
    end)
    if not isGK then return end
    if tick() - lastDiveTime < 1.2 then return end
    local ballPos = nil
    pcall(function() if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end end)
    if not ballPos then return end
    local goalPart = nil
    pcall(function()
        if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
            goalPart = M.PracticeSession.GetDefendedGoalPart()
        end
    end)
    if not goalPart then return end
    if (ballPos - goalPart.Position).Magnitude > 40 then return end
    local root = getRoot(); if not root then return end
    local diveDir = uiRefs.getDiveDir and uiRefs.getDiveDir() or "SMART"
    local directionName = "F"
    if diveDir == "SMART" then
        local lateral = Vector3.new((ballPos - goalPart.Position).X, 0, (ballPos - goalPart.Position).Z)
        if lateral.Magnitude > 3 then
            local myLat = Vector3.new((root.Position - goalPart.Position).X, 0, (root.Position - goalPart.Position).Z)
            directionName = myLat:Dot(lateral.Unit) > 0 and "R" or "L"
        end
    elseif diveDir == "LEFT" then directionName = "L"
    elseif diveDir == "RIGHT" then directionName = "R"
    elseif diveDir == "SIDES" then
        directionName = (ballPos - goalPart.Position).X > 0 and "R" or "L"
    end
    local hum = getHum()
    local dived = false
    if M.GoalkeeperDive and M.GoalkeeperDive.Run then
        pcall(function()
            local choice = M.GoalkeeperDive.GetDirectionChoiceByName and M.GoalkeeperDive.GetDirectionChoiceByName(directionName)
            if choice then
                local basisFn = function() return CFrame.new(goalPart.Position, goalPart.Position + Vector3.new(0, 0, -1)) end
                M.GoalkeeperDive.Run(root, hum, choice, basisFn, {})
                dived = true
            end
        end)
    end
    if not dived and Remotes.Tackle then
        local cmd = {
            Protocol = "ActionCommand",
            Command = {
                Mode = "GoalkeeperDive",
                Kind = "Tackle",
                ActionId = newSessionId(),
                ShotTime = workspace:GetServerTimeNow(),
                PlayerVelocity = root.AssemblyLinearVelocity,
                AimDirection = unit(ballPos - root.Position),
                DirectionName = directionName,
            }
        }
        pcall(function() Remotes.Tackle:FireServer(cmd) end)
    end
    lastDiveTime = tick()
end

-- ESP
local espObjects = {}
local function updateESP()
    local enable = uiRefs.toggles.esp and uiRefs.toggles.esp()
    if not enable then
        for _, obj in pairs(espObjects) do pcall(function() obj:Destroy() end) end
        espObjects = {}
        return
    end
    local all = {}
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then all = M.Actors.GetAllCharacterModels() end
    end)
    for _, model in ipairs(all) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp and not espObjects[model] then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 40, 0, 20)
            bb.AlwaysOnTop = true
            bb.Adornee = hrp
            bb.Parent = screenGui
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = model.Name
            lbl.TextColor3 = Color3.fromRGB(255, 255, 100)
            lbl.TextSize = 10
            lbl.Parent = bb
            espObjects[model] = bb
        end
    end
    for model, obj in pairs(espObjects) do
        if not model.Parent or not model:FindFirstChild("HumanoidRootPart") then
            pcall(function() obj:Destroy() end)
            espObjects[model] = nil
        end
    end
end

-- Teleport
local function teleportTick()
    if not uiRefs.toggles.teleport or not uiRefs.toggles.teleport() then return end
    local ballPos = nil
    pcall(function() if M.Renderer and M.Renderer.GetPosition then ballPos = M.Renderer.GetPosition() end end)
    if not ballPos then return end
    local hrp = getRoot(); if not hrp then return end
    pcall(function() hrp.CFrame = CFrame.new(ballPos + Vector3.new(0, 5, 0)) end)
end

-- One-shot buttons
uiRefs.buttons.fakeShot.MouseButton1Click:Connect(function() pcall(fireFakeShot) end)
uiRefs.buttons.wallShot.MouseButton1Click:Connect(function() pcall(fireWallShot) end)
uiRefs.buttons.pass.MouseButton1Click:Connect(function() pcall(firePerfectPass) end)
uiRefs.buttons.rainbowFlick.MouseButton1Click:Connect(function() pcall(fireRainbowFlick) end)

-- ============================================================
-- 8. MAIN LOOP
-- ============================================================
local infStamActive = false
RunService.Heartbeat:Connect(function()
    xpcall(function()
        if uiRefs.toggles.infStam then
            local on = uiRefs.toggles.infStam()
            if on ~= infStamActive then
                infStamActive = on
                applyInfiniteStamina(on)
            end
        end
        if uiRefs.sliders.speed then applySpeed(uiRefs.sliders.speed()) end
        if uiRefs.toggles.jumpBoost then applyJumpBoost(uiRefs.toggles.jumpBoost()) end
        if uiRefs.toggles.perfectShot and uiRefs.toggles.perfectShot() then
            local owned = false
            pcall(function()
                if M.Renderer and M.Renderer.GetOwnedUserId then
                    owned = (M.Renderer.GetOwnedUserId() == LP.UserId)
                end
            end)
            if owned then
                local charging = false
                pcall(function()
                    if M.ActionChargeState and M.ActionChargeState.IsCharging then
                        charging = M.ActionChargeState.IsCharging()
                    end
                end)
                if not charging then
                    local mode = uiRefs.getCurveMode and uiRefs.getCurveMode() or "OFF"
                    local curve = (mode == "LEFT") and -1 or (mode == "RIGHT") and 1 or (mode == "AUTO") and nil or 0
                    firePerfectShot(curve)
                end
            end
        end
        autoGoalkeeperTick()
        updateESP()
        teleportTick()
    end, function() end)
end)

-- ============================================================
-- 9. PUBLIC API
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
    Version = "1.1",
}

print("[IS Assist] Loaded. UI parent: " .. tostring(parentName))