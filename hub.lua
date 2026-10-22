--[[
    Illegal Soccer Assist - Pure Native Executor Engine
    Mobile Compatible (Delta Android v2.743+)
    Zero Module Dependency / Direct Remote Protocol Execution
]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- ==========================================
-- 1. UI CREATION (UI ALWAYS FIRST)
-- ==========================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IllegalSoccerNativeGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = PlayerGui end)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 520)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.BorderSizePixel = 0
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 16
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.Text = "ILLEGAL SOCCER NATIVE V7"
TitleBar.Parent = MainFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 45, 0, 45)
ToggleButton.Position = UDim2.new(1, -45, 0, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
ToggleButton.BorderSizePixel = 0
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "-"
ToggleButton.Parent = TitleBar

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -45)
ContentFrame.Position = UDim2.new(0, 0, 0, 45)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local TabBar = Instance.new("Frame")
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
    page.Size = UDim2.new(1, 0, 1, -40)
    page.Position = UDim2.new(0, 0, 0, 40)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.CanvasSize = UDim2.new(0, 0, 0, 500)
    page.ScrollBarThickness = 10
    page.Visible = (i == 1)
    page.Parent = ContentFrame
    tabPages[tabName] = page
end

local guiVisible = true
ToggleButton.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    for _, child in ipairs(ContentFrame:GetChildren()) do
        if child ~= TabBar then child.Visible = false end
    end
    TabBar.Visible = guiVisible
    if guiVisible then
        for k, btn in pairs(tabButtons) do
            if btn.BackgroundColor3 == Color3.fromRGB(45, 45, 60) then tabPages[k].Visible = true end
        end
        ToggleButton.Text = "-"
        MainFrame.Size = UDim2.new(0, 320, 0, 520)
    else
        ToggleButton.Text = "+"
        MainFrame.Size = UDim2.new(0, 320, 0, 45)
    end
end)

for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        for tName, tPage in pairs(tabPages) do
            tPage.Visible = (tName == name)
            tabButtons[tName].BackgroundColor3 = (tName == name) and Color3.fromRGB(45, 45, 60) or Color3.fromRGB(25, 25, 35)
        end
    end)
end

local function createButton(parent, text, posY)
    local btn = Instance.new("TextButton")
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

-- Notification
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Native Assist V7",
        Text = "Loaded for Delta Android!",
        Duration = 4
    })
end)

-- ==========================================
-- 2. DIRECT REMOTE BINDINGS
-- ==========================================

local TackleRemote, KickRemote, MovementBoostRemote
pcall(function()
    TackleRemote = ReplicatedStorage.Remotes.Ball.Tackle
    KickRemote = ReplicatedStorage.Remotes.Ball.Kick
    MovementBoostRemote = ReplicatedStorage.Remotes.Characters.MovementBoost
end)

local sessionCounter = math.floor(workspace:GetServerTimeNow() * 1e6)
local function getNextSessionId()
    sessionCounter = sessionCounter + 2
    return sessionCounter
end

local function getRoot()
    local char = LP.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getHum()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getBall()
    return Workspace:FindFirstChild("Ball") or Workspace:FindFirstChild("Football") or (Workspace:FindFirstChild("Balls") and Workspace.Balls:FindFirstChildOfClass("Part"))
end

-- ==========================================
-- 3. CORE LOGIC ENGINE
-- ==========================================

-- TAB 1: MOVEMENT
local pMove = tabPages["MOVE"]
createLabel(pMove, "Native Speed & Stamina Engine", 10)

local speedToggle = createButton(pMove, "Speed Boost: OFF", 50)
local speedActive = false
speedToggle.MouseButton1Click:Connect(function()
    speedActive = not speedActive
    speedToggle.Text = "Speed Boost: " .. (speedActive and "ON (22 WalkSpeed)" or "OFF")
    speedToggle.BackgroundColor3 = speedActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

local jumpToggle = createButton(pMove, "Jump Power: OFF", 110)
local jumpActive = false
jumpToggle.MouseButton1Click:Connect(function()
    jumpActive = not jumpActive
    jumpToggle.Text = "Jump Power: " .. (jumpActive and "ON (100 Power)" or "OFF")
    jumpToggle.BackgroundColor3 = jumpActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

local staminaToggle = createButton(pMove, "Stamina Bypass: OFF", 170)
local staminaActive = false
staminaToggle.MouseButton1Click:Connect(function()
    staminaActive = not staminaActive
    staminaToggle.Text = "Stamina Bypass: " .. (staminaActive and "ON" or "OFF")
    staminaToggle.BackgroundColor3 = staminaActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

-- TAB 2: SHOT
local pShot = tabPages["SHOT"]
createLabel(pShot, "Direct Protocol Shooting", 10)

local autoShotToggle = createButton(pShot, "Auto Shot (Ball Near Goal): OFF", 50)
local autoShotActive = false
autoShotToggle.MouseButton1Click:Connect(function()
    autoShotActive = not autoShotActive
    autoShotToggle.Text = "Auto Shot: " .. (autoShotActive and "ON" or "OFF")
    autoShotToggle.BackgroundColor3 = autoShotActive and Color3.fromRGB(40, 140, 60) or Color3.fromRGB(50, 50, 70)
end)

local forceShotBtn = createButton(pShot, "Force Power Shot (Instant)", 110)
forceShotBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)

local function fireDirectShot(curve)
    pcall(function()
        if not TackleRemote then return end
        local root = getRoot()
        if not root then return end
        
        local pos = root.Position
        local vel = root.AssemblyLinearVelocity
        local look = root.CFrame.LookVector
        local id = getNextSessionId()
        local shotTime = workspace:GetServerTimeNow()

        -- 1. Request Kick Power
        if MovementBoostRemote then
            pcall(function() MovementBoostRemote:FireServer("RequestKickPower") end)
        end

        -- 2. Send Start Packet
        TackleRemote:FireServer({
            Phase = "Start",
            Protocol = "ActionSession",
            Command = {
                MaximumChargeSeconds = 0.4,
                SessionId = id,
                ShotTime = shotTime,
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

        -- 3. Send Release Packet 0.4s later
        task.delay(0.4, function()
            TackleRemote:FireServer({
                Phase = "Release",
                Protocol = "ActionSession",
                Command = {
                    MaximumChargeSeconds = 0.4,
                    ChargeStartedAt = shotTime,
                    SessionId = id,
                    ShotTime = workspace:GetServerTimeNow(),
                    AimDirection = {
                        Direction = look,
                        Origin = pos,
                        CameraCFrame = workspace.CurrentCamera.CFrame,
                        IsAirborne = false,
                    },
                    PassType = "Shot",
                    KickDirection = look,
                    Kind = "Tackle",
                    PlayerVelocity = vel,
                    Mode = "Kick",
                    ChargeSeconds = 0.4,
                    Curve = curve or 0,
                }
            })
        end)
    end)
end
forceShotBtn.MouseButton1Click:Connect(function() fireDirectShot(0) end)

local fakeShotBtn = createButton(pShot, "Force Fake Shot", 170)
fakeShotBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
fakeShotBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if not TackleRemote then return end
        local root = getRoot()
        if not root then return end
        
        local pos = root.Position
        local vel = root.AssemblyLinearVelocity
        local look = root.CFrame.LookVector
        local id = getNextSessionId()

        TackleRemote:FireServer({
            Phase = "Start",
            Protocol = "ActionSession",
            Command = {
                MaximumChargeSeconds = 0.4,
                SessionId = id,
                ShotTime = workspace:GetServerTimeNow(),
                AimDirection = { Direction = look, Origin = pos, CameraCFrame = workspace.CurrentCamera.CFrame, IsAirborne = false },
                PassType = "Shot",
                PlayerVelocity = vel,
                Kind = "Tackle",
                Mode = "Kick",
                KickDirection = look,
            }
        })

        task.delay(0.12, function()
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
end)

-- TAB 3: DRIBBLE
local pDrib = tabPages["DRIBB"]
createLabel(pDrib, "Dribble & Tackle Actions", 10)

local slideBtn = createButton(pDrib, "Force Slide Tackle", 50)
slideBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
slideBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if not TackleRemote then return end
        local root = getRoot()
        if not root then return end
        
        TackleRemote:FireServer({
            Protocol = "ActionCommand",
            Command = {
                Mode = "Slide",
                Kind = "Tackle",
                ActionId = getNextSessionId(),
                ShotTime = workspace:GetServerTimeNow(),
                PlayerVelocity = root.AssemblyLinearVelocity,
                AimDirection = root.CFrame.LookVector,
            }
        })
    end)
end)

local rainbowBtn = createButton(pDrib, "Force Rainbow Flick", 110)
rainbowBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
rainbowBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if not TackleRemote then return end
        local root = getRoot()
        if not root then return end
        
        local id = getNextSessionId()
        local vel = root.AssemblyLinearVelocity
        local look = root.CFrame.LookVector

        TackleRemote:FireServer({
            Protocol = "ActionCommand",
            Command = { Kind = "RainbowFlick", ActionId = id, ShotTime = workspace:GetServerTimeNow(), PlayerVelocity = vel, AimDirection = look }
        })

        task.delay(0.35, function()
            TackleRemote:FireServer({
                Protocol = "ActionCommand",
                Command = { Kind = "RainbowFlick", Mode = "RainbowFlickDetach", ActionId = id, ShotTime = workspace:GetServerTimeNow(), PlayerVelocity = vel, AimDirection = look }
            })
        end)
    end)
end)

-- TAB 4: GOALKEEPER
local pGk = tabPages["GK"]
createLabel(pGk, "Goalkeeper Manual Overrides", 10)

local gkDiveLeft = createButton(pGk, "Force Dive LEFT", 50)
gkDiveLeft.BackgroundColor3 = Color3.fromRGB(40, 90, 160)

local gkDiveRight = createButton(pGk, "Force Dive RIGHT", 110)
gkDiveRight.BackgroundColor3 = Color3.fromRGB(40, 90, 160)

local function fireGkDive(dirName)
    pcall(function()
        if not TackleRemote then return end
        local root = getRoot()
        if not root then return end
        
        local look = root.CFrame.LookVector
        local sideDir = (dirName == "L") and -root.CFrame.RightVector or root.CFrame.RightVector

        TackleRemote:FireServer({
            Protocol = "ActionCommand",
            Command = {
                Kind = "GoalkeeperDive",
                Mode = "Dive",
                ActionId = getNextSessionId(),
                ShotTime = workspace:GetServerTimeNow(),
                PlayerVelocity = root.AssemblyLinearVelocity,
                AimDirection = sideDir,
                DirectionName = dirName
            }
        })
    end)
end

gkDiveLeft.MouseButton1Click:Connect(function() fireGkDive("L") end)
gkDiveRight.MouseButton1Click:Connect(function() fireGkDive("R") end)

-- TAB 5: MISC
local pMisc = tabPages["MISC"]
createLabel(pMisc, "Utility Features", 10)

local tpBallBtn = createButton(pMisc, "Teleport To Ball", 50)
tpBallBtn.BackgroundColor3 = Color3.fromRGB(160, 90, 40)
tpBallBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local ball = getBall()
        local root = getRoot()
        if ball and root then
            root.CFrame = ball.CFrame + Vector3.new(0, 3, 0)
        end
    end)
end)

local rejoinBtn = createButton(pMisc, "Rejoin Server", 110)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
rejoinBtn.MouseButton1Click:Connect(function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end)

-- ==========================================
-- 4. MAIN GAME LOOP
-- ==========================================

RunService.Heartbeat:Connect(function()
    pcall(function()
        local hum = getHum()
        if hum then
            -- Speed Overwrite
            if speedActive then
                hum.WalkSpeed = 22
            end
            -- Jump Overwrite
            if jumpActive then
                hum.JumpPower = 100
            end
        end

        -- Stamina Request Spam Bypass
        if staminaActive and MovementBoostRemote then
            MovementBoostRemote:FireServer("RequestSprintStamina")
        end
    end)
end)
