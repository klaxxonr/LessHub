--[[\n    Illegal Soccer Premium Assist Script\n    Mobile Compatible (Delta / Xeno)\n    Strictly ASCII, No Emojis, UI First Architecture\n]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- ==========================================
-- 1. UI CREATED AT THE VERY BEGINNING (RULE 1 & 4)
-- ==========================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IllegalSoccerAssistGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    ScreenGui.Parent = PlayerGui
end)

-- Main Frame (Pixel-based, No Scale, No UIScale, No UIStroke)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 520)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Title Bar
local TitleBar = Instance.new("TextLabel")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.BorderSizePixel = 0
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 16
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.Text = "ILLEGAL SOCCER ASSIST V6"
TitleBar.Parent = MainFrame

-- Close / Minimize Toggle Button (Min 40px height)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, 45, 0, 45)
ToggleButton.Position = UDim2.new(1, -45, 0, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
ToggleButton.BorderSizePixel = 0
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "-"
ToggleButton.Parent = TitleBar

-- Content Container
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, 0, 1, -45)
ContentFrame.Position = UDim2.new(0, 0, 0, 45)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- Tab Buttons Bar
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, 40)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
TabBar.BorderSizePixel = 0
TabBar.Parent = ContentFrame

local tabs = {"MOVE", "SHOT", "DRIBB", "GK", "MISC"}
local tabButtons = {}
local tabPages = {}

local tabWidth = 320 / #tabs
for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Name = tabName .. "Btn"
    btn.Size = UDim2.new(0, tabWidth, 1, 0)
    btn.Position = UDim2.new(0, (i - 1) * tabWidth, 0, 0)
    btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(45, 45, 60) or Color3.fromRGB(25, 25, 35)
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.SourceSansBold
    btn.Text = tabName
    btn.Parent = TabBar
    tabButtons[tabName] = btn

    local page = Instance.new("ScrollingFrame")
    page.Name = tabName .. "Page"
    page.Size = UDim2.new(1, 0, 1, -40)
    page.Position = UDim2.new(0, 0, 0, 40)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.CanvasSize = UDim2.new(0, 0, 0, 600)
    page.ScrollBarThickness = 10
    page.Visible = (i == 1)
    page.Parent = ContentFrame
    tabPages[tabName] = page
end

-- Toggle UI visibility
local guiVisible = true
ToggleButton.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    for _, child in ipairs(ContentFrame:GetChildren()) do
        if child ~= TabBar then
            child.Visible = false
        end
    end
    TabBar.Visible = guiVisible
    if guiVisible then
        for k, btn in pairs(tabButtons) do
            if btn.BackgroundColor3 == Color3.fromRGB(45, 45, 60) then
                tabPages[k].Visible = true
            end
        end
        ToggleButton.Text = "-"
        MainFrame.Size = UDim2.new(0, 320, 0, 520)
    else
        ToggleButton.Text = "+"
        MainFrame.Size = UDim2.new(0, 320, 0, 45)
    end
end)

-- Tab Switching Logic
for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        for tName, tPage in pairs(tabPages) do
            tPage.Visible = (tName == name)
            tabButtons[tName].BackgroundColor3 = (tName == name) and Color3.fromRGB(45, 45, 60) or Color3.fromRGB(25, 25, 35)
        end
    end)
end

-- Helper to create buttons/toggles easily with min 40px height
local function createButton(parent, name, text, posY)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, -20, 0, 45)
    btn.Position = UDim2.new(0, 10, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.SourceSansBold
    btn.Text = text
    btn.Parent = parent
    return btn
end

local function createLabel(parent, text, posY)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 30)
    lbl.Position = UDim2.new(0, 10, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.SourceSans
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.Parent = parent
    return lbl
end

-- ==========================================
-- 2. STARTUP NOTIFICATION (RULE 5)
-- ==========================================
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Illegal Soccer Assist",
        Text = "UI Loaded Successfully. Ready.",
        Duration = 5
    })
end)

-- ==========================================
-- 3. SAFE MODULE LOADER (RULE 3 & 4)
-- ==========================================
local M = {}
local function loadModule(key, path)
    pcall(function()
        local current = ReplicatedStorage
        for _, part in ipairs(path) do
            current = current:WaitForChild(part, 2)
            if not current then return end
        end
        if typeof(current) == "Instance" and current:IsA("ModuleScript") then
            M[key] = require(current)
        end
    end)
end

-- Load all necessary modules safely
pcall(function()
    loadModule("Sprint", {"Modules", "Actions", "Sprint"})
    loadModule("ClientSprint", {"Client", "Gameplay", "Player", "Sprint"})
    loadModule("Movement", {"Client", "Gameplay", "Player", "Movement"})
    loadModule("Shoot", {"Modules", "Actions", "Shoot"})
    loadModule("KickCore", {"Modules", "Actions", "KickCore"})
    loadModule("KickPowerups", {"Modules", "Actions", "KickPowerups"})
    loadModule("ActionCommands", {"Modules", "Actions", "ActionCommands"})
    loadModule("GoalkeeperDive", {"Modules", "Actions", "GoalkeeperDive"})
    loadModule("GoalkeeperDiveAssist", {"Modules", "Actions", "GoalkeeperDiveAssist"})
    loadModule("GoalkeeperActions", {"Modules", "Actions", "GoalkeeperActions"})
    loadModule("GoalkeeperPrediction", {"Modules", "Gameplay", "GoalkeeperPrediction"})
    loadModule("GoalkeeperPositioning", {"Modules", "Gameplay", "GoalkeeperPositioning"})
    loadModule("GoalkeeperRole", {"Client", "Gameplay", "Player", "GoalkeeperRole"})
    loadModule("BallPhysics", {"Modules", "Ball", "Physics"})
    loadModule("BallCarry", {"Modules", "Ball", "Carry"})
    loadModule("BallRenderer", {"Client", "Gameplay", "Ball", "Renderer"})
    loadModule("CharacterControllers", {"Modules", "Characters", "CharacterControllers"})
    loadModule("CharacterMotion", {"Modules", "Characters", "CharacterMotion"})
    loadModule("HitboxSettings", {"Modules", "Gameplay", "HitboxSettings"})
    loadModule("MatchSettings", {"Modules", "Gameplay", "MatchSettings"})
    loadModule("ActorTeams", {"Client", "Gameplay", "ActorTeams"})
    loadModule("PracticeSession", {"Client", "Gameplay", "PracticeSession"})
    loadModule("Actors", {"Modules", "Characters", "Actors"})
    loadModule("ActionLocks", {"Modules", "Actions", "ActionLocks"})
    loadModule("ActionChargeState", {"Modules", "Actions", "ActionChargeState"})
    loadModule("Dodge", {"Modules", "Actions", "Dodge"})
    loadModule("ClientDodge", {"Client", "Gameplay", "Actions", "Dodge"})
    loadModule("RainbowFlick", {"Modules", "Actions", "RainbowFlick"})
    loadModule("BicycleKick", {"Modules", "Actions", "BicycleKick"})
    loadModule("SlideTackle", {"Modules", "Actions", "SlideTackle"})
    loadModule("Controls", {"Modules", "Gameplay", "Controls"})
    loadModule("Keybinds", {"Modules", "Gameplay", "Keybinds"})
    loadModule("Reticle", {"Client", "Interface", "Reticle"})
    loadModule("AimSolver", {"Modules", "Actions", "AimSolver"})
    loadModule("ShotAimAssist", {"Modules", "Actions", "ShotAimAssist"})
    loadModule("EndpointAim", {"Modules", "EndpointAim"})
end)

-- Remotes setup
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
local TackleRemote, KickRemote, StateRemote, RainbowRemote
pcall(function()
    TackleRemote = Remotes.Ball.Tackle
    KickRemote = Remotes.Ball.Kick
    StateRemote = Remotes.Ball.State
    RainbowRemote = Remotes.Ball.RainbowFlick
end)

-- Session ID Generator
local sessionCounter = math.floor(workspace:GetServerTimeNow() * 1e6)
local function newId()
    sessionCounter = sessionCounter + 2
    return sessionCounter
end

local function getRoot()
    local char = LP.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    end
    return nil
end

local function getHum()
    local char = LP.Character
    if char then
        return char:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

-- ==========================================
-- 4. BUILD UI CONTROLS IN TABS
-- ==========================================

-- PAGE 1: MOVEMENT
local pMove = tabPages["MOVE"]
createLabel(pMove, "Movement & Stamina Enhancements", 10)

local stamBtn = createButton(pMove, "StamBtn", "Infinite Stamina: OFF", 50)
local stamActive = false
stamBtn.MouseButton1Click:Connect(function()
    stamActive = not stamActive
    stamBtn.Text = "Infinite Stamina: " .. (stamActive and "ON" or "OFF")
    stamBtn.BackgroundColor3 = stamActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
    pcall(function()
        if M.Sprint and M.Sprint.SetUnlimitedStamina then
            pcall(M.Sprint.SetUnlimitedStamina, "v6")
            pcall(M.Sprint.SetUnlimitedStamina, true)
            pcall(M.Sprint.SetUnlimitedStamina, "v6", true)
        end
    end)
end)

createLabel(pMove, "Speed Multiplier (1.0 - 2.5)", 110)
local speedBtn = createButton(pMove, "SpeedBtn", "Speed Boost: OFF (1.0x)", 145)
local speedActive = false
speedBtn.MouseButton1Click:Connect(function()
    speedActive = not speedActive
    speedBtn.Text = speedActive and "Speed Boost: ON (1.8x)" or "Speed Boost: OFF (1.0x)"
    speedBtn.BackgroundColor3 = speedActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

createLabel(pMove, "Jump Boost", 210)
local jumpBtn = createButton(pMove, "JumpBtn", "Jump Boost: OFF", 245)
local jumpActive = false
jumpBtn.MouseButton1Click:Connect(function()
    jumpActive = not jumpActive
    jumpBtn.Text = "Jump Boost: " .. (jumpActive and "ON" or "OFF")
    jumpBtn.BackgroundColor3 = jumpActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
    local hum = getHum()
    if hum then
        hum.JumpPower = jumpActive and 120 or 50
    end
end)

-- PAGE 2: SHOT
local pShot = tabPages["SHOT"]
createLabel(pShot, "Shooting & Aim Assists", 10)

local perfectShotBtn = createButton(pShot, "PerfShotBtn", "Perfect Shot (Auto Aim+Fire): OFF", 50)
local perfectShotActive = false
perfectShotBtn.MouseButton1Click:Connect(function()
    perfectShotActive = not perfectShotActive
    perfectShotBtn.Text = "Perfect Shot: " .. (perfectShotActive and "ON" or "OFF")
    perfectShotBtn.BackgroundColor3 = perfectShotActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

local curveMode = "AUTO" -- OFF, LEFT, RIGHT, AUTO
local curveBtn = createButton(pShot, "CurveBtn", "Curve Mode: AUTO", 110)
curveBtn.MouseButton1Click:Connect(function()
    if curveMode == "AUTO" then curveMode = "LEFT"
    elseif curveMode == "LEFT" then curveMode = "RIGHT"
    elseif curveMode == "RIGHT" then curveMode = "OFF"
    else curveMode = "AUTO" end
    curveBtn.Text = "Curve Mode: " .. curveMode
end)

local fakeShotBtn = createButton(pShot, "FakeShotBtn", "Trigger Fake Shot", 170)
fakeShotBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
local function fireFakeShot()
    pcall(function()
        if not TackleRemote then return end
        local root = getRoot()
        if not root then return end
        local id = newId()
        local pos = root.Position
        local vel = root.AssemblyLinearVelocity
        local look = root.CFrame.LookVector

        -- Start packet
        TackleRemote:FireServer({
            Phase = "Start",
            Protocol = "ActionSession",
            Command = {
                MaximumChargeSeconds = 0.4,
                SessionId = id,
                ShotTime = workspace:GetServerTimeNow(),
                AimDirection = {
                    Direction = look,
                    Origin = pos,
                    CameraCFrame = workspace.CurrentCamera.CFrame,
                    IsAirborne = false,
                },
                PassType = "Shot",
                PlayerVelocity = vel,
                Kind = "Tackle",
                Mode = "Kick",
                KickDirection = look,
            }
        })

        task.delay(0.15, function()
            TackleRemote:FireServer({
                Protocol = "ActionCommand",
                Command = {
                    Mode = "Dodge",
                    Kind = "Tackle",
                    ActionId = id,
                    ShotTime = workspace:GetServerTimeNow(),
                    PlayerVelocity = vel,
                    AimDirection = look,
                }
            })
        end)
    end)
end
fakeShotBtn.MouseButton1Click:Connect(fireFakeShot)

local wallShotBtn = createButton(pShot, "WallShotBtn", "Trigger Wall Fake Shot", 230)
wallShotBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
wallShotBtn.MouseButton1Click:Connect(function()
    pcall(function()
        -- Fire towards nearest wall or front wall
        local root = getRoot()
        if not root or not TackleRemote then return end
        local id = newId()
        local pos = root.Position
        local vel = root.AssemblyLinearVelocity
        local wallDir = root.CFrame.LookVector
        
        pcall(function()
            local walls = Workspace.Map.Data.Walls
            if walls and walls:FindFirstChild("Front") then
                wallDir = (walls.Front.Position - pos).Unit
            end
        end)

        TackleRemote:FireServer({
            Phase = "Start",
            Protocol = "ActionSession",
            Command = {
                MaximumChargeSeconds = 0.4,
                SessionId = id,
                ShotTime = workspace:GetServerTimeNow(),
                AimDirection = { Direction = wallDir, Origin = pos, CameraCFrame = workspace.CurrentCamera.CFrame, IsAirborne = false },
                PassType = "Shot",
                PlayerVelocity = vel,
                Kind = "Tackle",
                Mode = "Kick",
                KickDirection = wallDir,
            }
        })

        task.delay(0.3, function()
            TackleRemote:FireServer({
                Phase = "Release",
                Protocol = "ActionSession",
                Command = {
                    MaximumChargeSeconds = 0.4,
                    ChargeStartedAt = workspace:GetServerTimeNow() - 0.3,
                    SessionId = id,
                    ShotTime = workspace:GetServerTimeNow(),
                    AimDirection = { Direction = wallDir, Origin = pos, CameraCFrame = workspace.CurrentCamera.CFrame, IsAirborne = false },
                    PassType = "Shot",
                    KickDirection = wallDir,
                    Kind = "Tackle",
                    PlayerVelocity = vel,
                    Mode = "Kick",
                    ChargeSeconds = 0.4,
                    Curve = 1,
                }
            })
        end)
    end)
end)

-- PAGE 3: DRIBBLE
local pDrib = tabPages["DRIBB"]
createLabel(pDrib, "Dribbling & Skill Automation", 10)

local autoDribBtn = createButton(pDrib, "AutoDribBtn", "Auto Dribble / Tackle Dodge: OFF", 50)
local autoDribActive = false
autoDribBtn.MouseButton1Click:Connect(function()
    autoDribActive = not autoDribActive
    autoDribBtn.Text = "Auto Dribble: " .. (autoDribActive and "ON" or "OFF")
    autoDribBtn.BackgroundColor3 = autoDribActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

local rainbowBtn = createButton(pDrib, "RainbowBtn", "Trigger Rainbow Flick", 110)
rainbowBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
rainbowBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if not TackleRemote then return end
        local root = getRoot()
        if not root then return end
        local id = newId()
        local vel = root.AssemblyLinearVelocity
        local aim = root.CFrame.LookVector

        TackleRemote:FireServer({
            Protocol = "ActionCommand",
            Command = {
                Kind = "RainbowFlick",
                ActionId = id,
                ShotTime = workspace:GetServerTimeNow(),
                PlayerVelocity = vel,
                AimDirection = aim,
            }
        })

        task.delay(0.4, function()
            TackleRemote:FireServer({
                Protocol = "ActionCommand",
                Command = {
                    Kind = "RainbowFlick",
                    Mode = "RainbowFlickDetach",
                    ActionId = id,
                    ShotTime = workspace:GetServerTimeNow(),
                    PlayerVelocity = vel,
                    AimDirection = aim,
                }
            })
        end)
    end)
end)

local bicycleBtn = createButton(pDrib, "BicycleBtn", "Trigger Bicycle Kick Hover", 170)
bicycleBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
bicycleBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if M.BicycleKick and M.BicycleKick.StartHover then
            M.BicycleKick.StartHover()
        end
    end)
end)

-- PAGE 4: GOALKEEPER
local pGk = tabPages["GK"]
createLabel(pGk, "Automated Goalkeeper Defenses", 10)

local autoGkBtn = createButton(pGk, "AutoGkBtn", "Auto Goalkeeper Dive: OFF", 50)
local autoGkActive = false
autoGkBtn.MouseButton1Click:Connect(function()
    autoGkActive = not autoGkActive
    autoGkBtn.Text = "Auto GK: " .. (autoGkActive and "ON" or "OFF")
    autoGkBtn.BackgroundColor3 = autoGkActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

local gkDirMode = "SMART" -- SMART, FORWARD, LEFT, RIGHT
local gkDirBtn = createButton(pGk, "GkDirBtn", "Dive Direction: SMART", 110)
gkDirBtn.MouseButton1Click:Connect(function()
    if gkDirMode == "SMART" then gkDirMode = "FORWARD"
    elseif gkDirMode == "FORWARD" then gkDirMode = "LEFT"
    elseif gkDirMode == "LEFT" then gkDirMode = "RIGHT"
    else gkDirMode = "SMART" end
    gkDirBtn.Text = "Dive Direction: " .. gkDirMode
end)

-- PAGE 5: MISC
pMisc = tabPages["MISC"]
createLabel(pMisc, "Utilities & Visuals", 10)

local espBtn = createButton(pMisc, "EspBtn", "ESP Boxes (Players & Ball): OFF", 50)
local espActive = false
espBtn.MouseButton1Click:Connect(function()
    espActive = not espActive
    espBtn.Text = "ESP Boxes: " .. (espActive and "ON" or "OFF")
    espBtn.BackgroundColor3 = espActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

local tpBallBtn = createButton(pMisc, "TpBallBtn", "Teleport to Ball (Risky)", 110)
tpBallBtn.BackgroundColor3 = Color3.fromRGB(160, 90, 40)
tpBallBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local root = getRoot()
        local ballPos = nil
        if M.BallRenderer and M.BallRenderer.GetPosition then
            ballPos = M.BallRenderer.GetPosition()
        end
        if root and ballPos then
            root.CFrame = CFrame.new(ballPos + Vector3.new(0, 4, 0))
        end
    end)
end)

local rejoinBtn = createButton(pMisc, "RejoinBtn", "Rejoin Server", 170)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
rejoinBtn.MouseButton1Click:Connect(function()
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
end)

local unloadBtn = createButton(pMisc, "UnloadBtn", "Unload Script", 230)
unloadBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
unloadBtn.MouseButton1Click:Connect(function()
    pcall(function()
        ScreenGui:Destroy()
        _G.IllegalSoccerAssist = nil
    end)
end)

-- ==========================================
-- 5. ESP IMPLEMENTATION (SAFE BILLBOARD GUI)
-- ==========================================
local espContainer = Instance.new("Folder")
espContainer.Name = "AssistESPFolder"
espContainer.Parent = ScreenGui

local function clearESP()
    espContainer:ClearAllChildren()
end

local function updateESP()
    if not espActive then
        clearESP()
        return
    end
    clearESP()

    pcall(function()
        -- Player ESP
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = plr.Character.HumanoidRootPart
                local bill = Instance.new("BillboardGui")
                bill.Size = UDim2.new(0, 50, 0, 50)
                bill.AlwaysOnTop = true
                bill.Adornee = hrp

                local frame = Instance.new("Frame")
                frame.Size = UDim2.new(1, 0, 1, 0)
                frame.BackgroundTransparency = 0.5
                frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                frame.Parent = bill
                bill.Parent = espContainer
            end
        end

        -- Ball ESP
        local ballPos = nil
        if M.BallRenderer and M.BallRenderer.GetPosition then
            ballPos = M.BallRenderer.GetPosition()
        end
        if ballPos then
            local part = Instance.new("Part")
            part.Size = Vector3.new(1, 1, 1)
            part.Position = ballPos
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 1

            local bill = Instance.new("BillboardGui")
            bill.Size = UDim2.new(0, 60, 0, 60)
            bill.AlwaysOnTop = true
            bill.Adornee = part

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundTransparency = 0.3
            frame.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
            frame.Parent = bill
            bill.Parent = espContainer
            part.Parent = espContainer
        end
    end)
end

-- ==========================================
-- 6. BACKGROUND LOOPS (HEARTBEAT)
-- ==========================================

local lastDribbleTime = 0
local lastPerfectShotTime = 0

RunService.Heartbeat:Connect(function(dt)
    -- Speed Multiplier Loop
    pcall(function()
        if speedActive then
            local char = LP.Character
            if char and M.Movement and M.Movement.SetMultiplier then
                M.Movement.SetMultiplier(char, 1.8)
            end
        end
    end)

    -- Auto Goalkeeper Logic
    pcall(function()
        if autoGkActive and M.GoalkeeperRole and M.GoalkeeperRole.IsGoalkeeper() then
            local root = getRoot()
            local hum = getHum()
            if root and hum and M.BallRenderer and M.BallRenderer.GetPosition then
                local ballPos = M.BallRenderer.GetPosition()
                local dist = (root.Position - ballPos).Magnitude
                if dist < 25 and M.GoalkeeperDive and M.GoalkeeperDive.Run then
                    local choice = "F"
                    if gkDirMode == "LEFT" then choice = "L"
                    elseif gkDirMode == "RIGHT" then choice = "R"
                    elseif gkDirMode == "SMART" then
                        choice = (ballPos.X > root.Position.X) and "R" or "L"
                    end
                    pcall(function()
                        M.GoalkeeperDive.Run(root, hum, choice, function() return root.CFrame end, {})
                    end)
                end
            end
        end
    end)

    -- Auto Dribble Logic
    pcall(function()
        if autoDribActive and tick() - lastDribbleTime > 1.0 then
            local root = getRoot()
            if root and M.Actors and TackleRemote then
                local myPos = root.Position
                for _, otherChar in ipairs(M.Actors.GetAllCharacterModels() or {}) do
                    if otherChar ~= LP.Character then
                        local oRoot = otherChar:FindFirstChild("HumanoidRootPart")
                        if oRoot and (oRoot.Position - myPos).Magnitude < 8 then
                            lastDribbleTime = tick()
                            local id = newId()
                            local dodgeDir = (myPos - oRoot.Position).Unit
                            TackleRemote:FireServer({
                                Protocol = "ActionCommand",
                                Command = {
                                    Mode = "Dodge",
                                    Kind = "Tackle",
                                    ActionId = id,
                                    ShotTime = workspace:GetServerTimeNow(),
                                    PlayerVelocity = root.AssemblyLinearVelocity,
                                    AimDirection = dodgeDir,
                                }
                            })
                            break
                        end
                    end
                end
            end
        end
    end)

    -- Perfect Shot Automation
    pcall(function()
        if perfectShotActive and tick() - lastPerfectShotTime > 0.8 then
            if M.BallRenderer and M.BallRenderer.GetOwnedUserId() == LP.UserId then
                local root = getRoot()
                if root and TackleRemote then
                    lastPerfectShotTime = tick()
                    local id = newId()
                    local pos = root.Position
                    local vel = root.AssemblyLinearVelocity
                    local look = root.CFrame.LookVector

                    -- Find target goal direction
                    local targetPos = pos + look * 50
                    pcall(function()
                        if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
                            local goal = M.PracticeSession.GetDefendedGoalPart()
                            if goal then targetPos = goal.Position end
                        end
                    end)

                    local dir = (targetPos - pos).Unit
                    local curveVal = 0
                    if curveMode == "LEFT" then curveVal = -1
                    elseif curveMode == "RIGHT" then curveVal = 1
                    elseif curveMode == "AUTO" then
                        curveVal = (pos.X > 0) and -1 or 1
                    end

                    -- Start Shot
                    TackleRemote:FireServer({
                        Phase = "Start",
                        Protocol = "ActionSession",
                        Command = {
                            MaximumChargeSeconds = 0.4,
                            SessionId = id,
                            ShotTime = workspace:GetServerTimeNow(),
                            AimDirection = { Direction = dir, Origin = pos, CameraCFrame = workspace.CurrentCamera.CFrame, IsAirborne = false },
                            PassType = "Shot",
                            PlayerVelocity = vel,
                            Kind = "Tackle",
                            Mode = "Kick",
                            KickDirection = dir,
                        }
                    })

                    task.delay(0.42, function()
                        TackleRemote:FireServer({
                            Phase = "Release",
                            Protocol = "ActionSession",
                            Command = {
                                MaximumChargeSeconds = 0.4,
                                ChargeStartedAt = workspace:GetServerTimeNow() - 0.42,
                                SessionId = id,
                                ShotTime = workspace:GetServerTimeNow(),
                                AimDirection = { Direction = dir, Origin = pos, CameraCFrame = workspace.CurrentCamera.CFrame, IsAirborne = false },
                                PassType = "Shot",
                                KickDirection = dir,
                                Kind = "Tackle",
                                PlayerVelocity = vel,
                                Mode = "Kick",
                                ChargeSeconds = 0.4,
                                Curve = curveVal,
                            }
                        })
                    end)
                end
            end
        end
    end)

    -- ESP update ticker
    if espActive and math.random() < 0.2 then
        updateESP()
    end
end)

-- Global exposure for external access
_G.IllegalSoccerAssist = {
    GUI = ScreenGui,
    Modules = M,
    FireFakeShot = fireFakeShot,
}
