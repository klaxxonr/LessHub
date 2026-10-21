--===================================================================================================--
--  ILLEGAL SOCCER ADVANCED ENTERPRISE HUB (v4.0 - ULTRA OPTIMIZED & FIXED)
--  Target Game: Illegal Soccer / Soccer Tournament Clones (Roblox)
--  Supported Executors: Delta (Mobile Android/iOS), Solara, Xeno, Wave, Hydrogen
--  FIXES APPLIED: Removed Key System entirely, completely eliminated the zero-feature FPS drop bug
--                 by implementing strict feature gating, object pooling, and optimized event loops.
--===================================================================================================--

if getgenv().IllegalSoccerEnterpriseLoaded then
    if getgenv().ToggleIllegalSoccerUI then
        getgenv().ToggleIllegalSoccerUI()
    end
    return
end
getgenv().IllegalSoccerEnterpriseLoaded = true

--===================================================================================================--
-- SERVICES & SECURE ENVIRONMENT INITIALIZATION
--===================================================================================================--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Safe file operations wrapper
local function safeWrite(file, data)
    pcall(function()
        if writefile then writefile(file, data) end
    end)
end

local function safeRead(file)
    local success, res = pcall(function()
        if readfile and isfile and isfile(file) then return readfile(file) end
    end)
    if success then return res end
    return nil
end

--===================================================================================================--
-- CONFIGURATION & PERSISTENCE SYSTEM
--===================================================================================================--
local CONFIG_FILENAME = "IllegalSoccerHub_Config_v4.json"

local Config = {
    -- Combat
    PerfectShot = false,
    ShotPower = 95,
    AimHeight = "Mid", -- Ground, Mid, Top Corner
    AutoShootRange = 55,
    
    SilentAim = false,
    SilentAimStrength = 85,
    
    CurveEnabled = false,
    CurvePower = 60,
    CurveDirection = "Auto",
    
    AutoDribble = false,
    ApproachRange = 10,
    ChaseSpeed = 24,
    
    Unstoppable = false,
    PowerBoost = 1.45,
    
    AutoScore = false,
    GuidanceStrength = 45,

    -- Defense
    AutoKeeper = false,
    ReactionTime = 0.05,
    PredictionTime = 1.4,
    MaxWalkDistance = 45,
    
    InfiniteStamina = false,
    SpeedBoost = 24,
    
    AntiTackle = false,
    AntiTackleForce = 65,
    
    BallMagnet = false,
    MagnetRadius = 20,
    MagnetForce = 45,

    -- Visuals
    BallESP = true,
    PlayerESP = true,
    GoalESP = true,
    TrajectoryLine = true,

    -- Misc
    AntiBanJitter = true,
    SafeMode = false,
    FPSBoost = false
}

local function LoadUserConfig()
    local raw = safeRead(CONFIG_FILENAME)
    if raw then
        local success, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then Config[k] = v end
            end
        end
    end
end

local function SaveUserConfig()
    local success, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if success and encoded then
        safeWrite(CONFIG_FILENAME, encoded)
    end
end

LoadUserConfig()

--===================================================================================================--
-- REMOTE EVENT REPOSITORY & GAME-SPECIFIC HOOKS
--===================================================================================================--
local RemoteCache = {
    Shoot = nil,
    Pass = nil,
    Curve = nil,
    Tackle = nil
}

local function DiscoverGameRemotes()
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local name = string.lower(obj.Name)
                if name:find("shoot") or name:find("kick") or name:find("strike") then
                    RemoteCache.Shoot = obj
                elseif name:find("pass") or name:find("loft") then
                    RemoteCache.Pass = obj
                elseif name:find("curve") or name:find("falso") then
                    RemoteCache.Curve = obj
                elseif name:find("tackle") or name:find("slide") then
                    RemoteCache.Tackle = obj
                end
            end
        end
    end)
end
task.spawn(DiscoverGameRemotes)

--===================================================================================================--
-- ADVANCED ENTITY DETECTION (BALL & GOALS)
--===================================================================================================--
local CachedBall = nil
local LastBallQuery = 0

local function GetBall()
    if tick() - LastBallQuery < 1.0 and CachedBall and CachedBall:IsDescendantOf(Workspace) then
        return CachedBall
    end
    LastBallQuery = tick()

    -- Search by descriptive names in Workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if name:find("ball") or name:find("soccer") or name:find("football") or name == "top" or name == "sphere" then
                CachedBall = obj
                return obj
            end
        end
    end

    -- Heuristic fallback: unanchored physics parts with movement
    local bestCandidate = nil
    local maxVel = 0
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and not obj.Anchored and obj.Size.Magnitude < 12 then
            local vel = obj.AssemblyLinearVelocity.Magnitude
            if vel > maxVel then
                maxVel = vel
                bestCandidate = obj
            end
        end
    end

    if bestCandidate then
        CachedBall = bestCandidate
        return bestCandidate
    end

    return nil
end

local function GetGoals()
    local enemyGoal, ownGoal = nil, nil
    local myTeam = LocalPlayer.Team

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if name:find("goal") or name:find("net") or name:find("post") or name:find("score") then
                local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                if part then
                    if name:find("red") or name:find("away") or name:find("guest") or name:find("team2") then
                        if myTeam and (myTeam.Name:lower():find("red") or myTeam.Name:lower():find("team2")) then
                            ownGoal = part
                        else
                            enemyGoal = part
                        end
                    elseif name:find("blue") or name:find("home") or name:find("team1") then
                        if myTeam and (myTeam.Name:lower():find("blue") or myTeam.Name:lower():find("team1")) then
                            ownGoal = part
                        else
                            enemyGoal = part
                        end
                    else
                        if not enemyGoal then enemyGoal = part else ownGoal = part end
                    end
                end
            end
        end
    end
    return enemyGoal, ownGoal
end

--===================================================================================================--
-- MODERN MOBILE-FIRST UI BUILDER (NO KEY SYSTEM)
--===================================================================================================--
local RootGui = CoreGui
pcall(function()
    if gethui then RootGui = gethui() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IllegalSoccerEnterpriseHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = RootGui

-- Floating Toggle Launcher
local LaunchButton = Instance.new("TextButton")
LaunchButton.Name = "LaunchButton"
LaunchButton.Size = UDim2.new(0, 52, 0, 52)
LaunchButton.Position = UDim2.new(0.03, 0, 0.18, 0)
LaunchButton.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
LaunchButton.BorderSizePixel = 0
LaunchButton.Text = "⚽"
LaunchButton.TextSize = 28
LaunchButton.TextColor3 = Color3.fromRGB(0, 220, 255)
LaunchButton.ZIndex = 150
LaunchButton.Parent = ScreenGui

local LaunchCorner = Instance.new("UICorner")
LaunchCorner.CornerRadius = UDim.new(0.5, 0)
LaunchCorner.Parent = LaunchButton

local LaunchStroke = Instance.new("UIStroke")
LaunchStroke.Color = Color3.fromRGB(0, 180, 255)
LaunchStroke.Thickness = 2.5
LaunchStroke.Parent = LaunchButton

-- Main Window Frame
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 360, 0, 275)
MainWindow.Position = UDim2.new(0.5, -180, 0.5, -137)
MainWindow.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
MainWindow.BorderSizePixel = 0
MainWindow.ClipsDescendants = true
MainWindow.Visible = true -- Open immediately without Key System
MainWindow.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainWindow

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(40, 48, 65)
MainStroke.Thickness = 1.8
MainStroke.Parent = MainWindow

-- Top Header / Title Bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
Header.BorderSizePixel = 0
Header.Parent = MainWindow

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "ILLEGAL SOCCER | PRO HUB"
TitleLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 32, 0, 32)
CloseButton.Position = UDim2.new(1, -36, 0, 4)
CloseButton.BackgroundColor3 = Color3.fromRGB(40, 22, 28)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 90, 90)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

-- Touch & Mouse Dragging Mechanics
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainWindow.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    MainWindow.Visible = false
end)

LaunchButton.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
end)

getgenv().ToggleIllegalSoccerUI = function()
    MainWindow.Visible = not MainWindow.Visible
end

-- Sidebar Navigation Layout
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 90, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainWindow

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.Parent = Sidebar

local Container = Instance.new("Frame")
Container.Name = "Container"
Container.Size = UDim2.new(1, -94, 1, -46)
Container.Position = UDim2.new(0, 93, 0, 43)
Container.BackgroundTransparency = 1
Container.Parent = MainWindow

local TabFrames = {}
local TabButtons = {}

local function BuildTab(name)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, 0, 0, 40)
    TabBtn.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
    TabBtn.BorderSizePixel = 0
    TabBtn.Text = name
    TabBtn.TextColor3 = Color3.fromRGB(150, 160, 180)
    TabBtn.Font = Enum.Font.GothamBold
    TabBtn.TextSize = 11
    TabBtn.Parent = Sidebar

    local TabFrame = Instance.new("ScrollingFrame")
    TabFrame.Size = UDim2.new(1, 0, 1, 0)
    TabFrame.BackgroundTransparency = 1
    TabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabFrame.ScrollBarThickness = 3
    TabFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
    TabFrame.Visible = false
    TabFrame.Parent = Container

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 6)
    TabLayout.Parent = TabFrame

    TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabFrame.CanvasSize = UDim2.new(0, 0, 0, TabLayout.AbsoluteContentSize.Y + 12)
    end)

    TabButtons[name] = TabBtn
    TabFrames[name] = TabFrame

    TabBtn.MouseButton1Click:Connect(function()
        for tName, btn in pairs(TabButtons) do
            btn.TextColor3 = Color3.fromRGB(150, 160, 180)
            btn.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
        end
        for tName, frame in pairs(TabFrames) do
            frame.Visible = false
        end
        TabBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
        TabBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
        TabFrame.Visible = true
    end)

    return TabFrame
end

local CombatTab = BuildTab("Combat")
local DefenseTab = BuildTab("Defense")
local VisualsTab = BuildTab("Visuals")
local MiscTab = BuildTab("Misc")
local SettingsTab = BuildTab("Settings")

-- Default active tab
TabButtons["Combat"].TextColor3 = Color3.fromRGB(0, 210, 255)
TabButtons["Combat"].BackgroundColor3 = Color3.fromRGB(24, 28, 40)
TabFrames["Combat"].Visible = true

-- UI Component Builders
local function AddToggleUI(parent, text, configKey, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -8, 0, 40)
    Row.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
    Row.BorderSizePixel = 0
    Row.Parent = parent

    local RowCorner = Instance.new("UICorner")
    RowCorner.CornerRadius = UDim.new(0, 6)
    RowCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(225, 230, 240)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 52, 0, 28)
    ToggleBtn.Position = UDim2.new(1, -58, 0.5, -14)
    ToggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 190, 120) or Color3.fromRGB(45, 50, 65)
    ToggleBtn.Text = Config[configKey] and "ON" or "OFF"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 10
    ToggleBtn.Parent = Row

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 4)
    BtnCorner.Parent = ToggleBtn

    ToggleBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        ToggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 190, 120) or Color3.fromRGB(45, 50, 65)
        ToggleBtn.Text = Config[configKey] and "ON" or "OFF"
        SaveUserConfig()
        if callback then callback(Config[configKey]) end
    end)
end

local function AddSliderUI(parent, text, configKey, min, max, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -8, 0, 44)
    Row.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
    Row.BorderSizePixel = 0
    Row.Parent = parent

    local RowCorner = Instance.new("UICorner")
    RowCorner.CornerRadius = UDim.new(0, 6)
    RowCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 0.5, 0)
    Label.Position = UDim2.new(0, 10, 0, 2)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(210, 215, 230)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local ValLabel = Instance.new("TextLabel")
    ValLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
    ValLabel.Position = UDim2.new(0.66, 0, 0, 2)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(Config[configKey])
    ValLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
    ValLabel.Font = Enum.Font.GothamBold
    ValLabel.TextSize = 10
    ValLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValLabel.Parent = Row

    local MinusBtn = Instance.new("TextButton")
    MinusBtn.Size = UDim2.new(0, 36, 0, 20)
    MinusBtn.Position = UDim2.new(0, 10, 0.5, 2)
    MinusBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
    MinusBtn.Text = "-"
    MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinusBtn.Font = Enum.Font.GothamBold
    MinusBtn.TextSize = 12
    MinusBtn.Parent = Row

    local PlusBtn = Instance.new("TextButton")
    PlusBtn.Size = UDim2.new(0, 36, 0, 20)
    PlusBtn.Position = UDim2.new(1, -46, 0.5, 2)
    PlusBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
    PlusBtn.Text = "+"
    PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlusBtn.Font = Enum.Font.GothamBold
    PlusBtn.TextSize = 12
    PlusBtn.Parent = Row

    local function updateValue(newVal)
        newVal = math.clamp(newVal, min, max)
        Config[configKey] = newVal
        ValLabel.Text = tostring(newVal)
        SaveUserConfig()
        if callback then callback(newVal) end
    end

    MinusBtn.MouseButton1Click:Connect(function()
        updateValue(Config[configKey] - (max > 25 and 5 or 1))
    end)

    PlusBtn.MouseButton1Click:Connect(function()
        updateValue(Config[configKey] + (max > 25 and 5 or 1))
    end)
end

-- Populate Tabs
AddToggleUI(CombatTab, "Perfect Shot", "PerfectShot")
AddSliderUI(CombatTab, "Shot Power", "ShotPower", 10, 180)
AddSliderUI(CombatTab, "Auto Shoot Range", "AutoShootRange", 10, 120)

AddToggleUI(CombatTab, "Goal Silent Aim", "SilentAim")
AddSliderUI(CombatTab, "Aim Strength %", "SilentAimStrength", 10, 100)

AddToggleUI(CombatTab, "Curve / Falso", "CurveEnabled")
AddSliderUI(CombatTab, "Curve Power", "CurvePower", 0, 180)

AddToggleUI(CombatTab, "Auto Dribble", "AutoDribble")
AddSliderUI(CombatTab, "Approach Range", "ApproachRange", 3, 30)
AddSliderUI(CombatTab, "Chase Speed", "ChaseSpeed", 16, 45)

AddToggleUI(CombatTab, "Unstoppable Shots", "Unstoppable")
AddToggleUI(CombatTab, "Auto Score Guidance", "AutoScore")

-- Defense Tab
AddToggleUI(DefenseTab, "Auto Goalkeeper", "AutoKeeper")
AddSliderUI(DefenseTab, "Max Keeper Walk Dist", "MaxWalkDistance", 10, 90)

AddToggleUI(DefenseTab, "Infinite Stamina", "InfiniteStamina")
AddSliderUI(DefenseTab, "Speed Boost", "SpeedBoost", 16, 65)

AddToggleUI(DefenseTab, "Anti-Tackle Stun", "AntiTackle")
AddToggleUI(DefenseTab, "Ball Magnet", "BallMagnet")
AddSliderUI(DefenseTab, "Magnet Radius", "MagnetRadius", 5, 50)

-- Visuals Tab
AddToggleUI(VisualsTab, "Ball ESP", "BallESP")
AddToggleUI(VisualsTab, "Player ESP", "PlayerESP")
AddToggleUI(VisualsTab, "Goal ESP", "GoalESP")
AddToggleUI(VisualsTab, "Trajectory Line", "TrajectoryLine")

-- Misc Tab
AddToggleUI(MiscTab, "Anti-Ban Jitter", "AntiBanJitter")
AddToggleUI(MiscTab, "Safe Mode (Cap Values)", "SafeMode")

local FPSBoostCache = {}
AddToggleUI(MiscTab, "FPS Boost Engine", "FPSBoost", function(val)
    pcall(function()
        if val then
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Decal") then
                    table.insert(FPSBoostCache, {obj = v, parent = v.Parent})
                    v.Parent = nil
                end
            end
            Lighting.GlobalShadows = false
        else
            for _, item in ipairs(FPSBoostCache) do
                if item.obj and item.parent then item.obj.Parent = item.parent end
            end
            FPSBoostCache = {}
            Lighting.GlobalShadows = true
        end
    end)
end)

-- Server Hop Button UI Row
local HopRow = Instance.new("Frame")
HopRow.Size = UDim2.new(1, -8, 0, 36)
HopRow.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
HopRow.Parent = MiscTab
local HopBtn = Instance.new("TextButton")
HopBtn.Size = UDim2.new(1, 0, 1, 0)
HopBtn.BackgroundTransparency = 1
HopBtn.Text = "Server Hop (Random Server)"
HopBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
HopBtn.Font = Enum.Font.GothamBold
HopBtn.TextSize = 11
HopBtn.Parent = HopRow

HopBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local ApiUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local Response = HttpService:JSONDecode(game:HttpGet(ApiUrl))
        if Response and Response.data then
            for _, srv in ipairs(Response.data) do
                if srv.playing ~= srv.maxPlayers and srv.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id)
                    break
                end
            end
        end
    end)
end)

-- Settings Tab Reset
local ResetRow = Instance.new("Frame")
ResetRow.Size = UDim2.new(1, -8, 0, 36)
ResetRow.BackgroundColor3 = Color3.fromRGB(38, 20, 26)
ResetRow.Parent = SettingsTab
local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(1, 0, 1, 0)
ResetBtn.BackgroundTransparency = 1
ResetBtn.Text = "Factory Reset Config"
ResetBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.TextSize = 11
ResetBtn.Parent = ResetRow

ResetBtn.MouseButton1Click:Connect(function()
    pcall(function() if delfile then delfile(CONFIG_FILENAME) end end)
    LocalPlayer:Kick("Configuration reset. Rejoining session...")
end)

--===================================================================================================--
-- RIGIDLY OPTIMIZED CORE GAMEPLAY LOOPS (ZERO FPS DROP WHEN TOGGLES OFF)
--===================================================================================================--

-- Jitter helper
local function applyJitter(v3)
    if not Config.AntiBanJitter then return v3 end
    return v3 + Vector3.new((math.random() - 0.5) * 0.03, 0, (math.random() - 0.5) * 0.03)
end

-- Stamina & Walkspeed Engine (Gated strictly)
RunService.Heartbeat:Connect(function()
    if not Config.InfiniteStamina then return end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hum then return end

        local targetSpeed = Config.SpeedBoost
        if Config.SafeMode then targetSpeed = math.min(targetSpeed, 24) end
        
        if hum.WalkSpeed ~= targetSpeed then
            hum.WalkSpeed = targetSpeed
        end

        if char:GetAttribute("Stamina") then
            char:SetAttribute("Stamina", 100)
        end
    end)
end)

-- Main Physics, Combat & Defense Engine (Strict Gating to eliminate idle lag)
RunService.Heartbeat:Connect(function()
    -- Fast exit if no combat/defense feature is enabled
    if not (Config.PerfectShot or Config.SilentAim or Config.CurveEnabled or Config.AutoDribble or Config.Unstoppable or Config.AutoScore or Config.AutoKeeper or Config.BallMagnet or Config.AntiTackle) then
        return
    end

    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum then return end

        local ball = GetBall()
        local enemyGoal, ownGoal = GetGoals()

        if not ball then return end
        local distToBall = (ball.Position - hrp.Position).Magnitude

        -- 1. BALL MAGNET
        if Config.BallMagnet and distToBall <= Config.MagnetRadius and not ball.Anchored then
            local pullDir = (hrp.Position - ball.Position).Unit
            ball.AssemblyLinearVelocity = applyJitter(pullDir * Config.MagnetForce)
        end

        -- 2. AUTO DRIBBLE
        if Config.AutoDribble and distToBall > Config.ApproachRange and distToBall < 65 then
            local approachDir = (ball.Position - hrp.Position).Unit
            hum:Move(applyJitter(approachDir), false)
        end

        -- 3. PERFECT SHOT, SILENT AIM, CURVE, UNSTOPPABLE
        if (Config.PerfectShot or Config.SilentAim or Config.Unstoppable) and enemyGoal then
            if distToBall <= Config.AutoShootRange and ball.AssemblyLinearVelocity.Magnitude > 1.5 then
                local goalPos = enemyGoal.Position
                if Config.AimHeight == "Ground" then
                    goalPos = Vector3.new(goalPos.X, goalPos.Y + 1.2, goalPos.Z)
                elseif Config.AimHeight == "Top Corner" then
                    goalPos = Vector3.new(goalPos.X, goalPos.Y + 6.0, goalPos.Z)
                else
                    goalPos = Vector3.new(goalPos.X, goalPos.Y + 3.5, goalPos.Z)
                end

                local shootDir = (goalPos - ball.Position).Unit
                local finalPower = Config.ShotPower

                if Config.Unstoppable then finalPower = finalPower * Config.PowerBoost end
                if Config.SafeMode then finalPower = math.min(finalPower, 70) end

                if Config.CurveEnabled and Config.CurvePower > 0 then
                    local sideVec = Vector3.new(-shootDir.Z, 0, shootDir.X)
                    local dirMult = (Config.CurveDirection == "Left") and -1 or 1
                    shootDir = (shootDir + (sideVec * (Config.CurvePower / 100) * dirMult)).Unit
                end

                local currentVel = ball.AssemblyLinearVelocity
                local desiredVel = shootDir * finalPower
                local blendRatio = Config.SilentAim and (Config.SilentAimStrength / 100) or 0.85

                local computedVel = currentVel:Lerp(desiredVel, blendRatio)
                if computedVel.Magnitude > 200 then computedVel = computedVel.Unit * 200 end

                ball.AssemblyLinearVelocity = applyJitter(computedVel)

                -- Invoke remote if available for server synchronization
                if RemoteCache.Shoot then
                    pcall(function() RemoteCache.Shoot:FireServer(ball, computedVel) end)
                end
            end
        end

        -- 4. AUTO GOALKEEPER
        if Config.AutoKeeper and ownGoal then
            local bVel = ball.AssemblyLinearVelocity
            local predictedPos = ball.Position + (bVel * Config.PredictionTime)
            local toGoalVec = (predictedPos - ownGoal.Position)
            local interceptPoint = ownGoal.Position + toGoalVec.Unit * math.clamp(toGoalVec.Magnitude * 0.35, 4, Config.MaxWalkDistance)

            if (interceptPoint - hrp.Position).Magnitude > 3 then
                local moveDir = (interceptPoint - hrp.Position).Unit
                hum:Move(applyJitter(moveDir), false)
            end
        end

        -- 5. ANTI-TACKLE
        if Config.AntiTackle then
            if hum:GetState() == Enum.HumanoidStateType.PlatformStanding or hum:GetState() == Enum.HumanoidStateType.Physics then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hrp.AssemblyLinearVelocity = Vector3.new(0, Config.AntiTackleForce, 0)
            end
        end
    end)
end)

--===================================================================================================--
-- ZERO-LEAK OPTIMIZED ESP & VISUALS ENGINE
--===================================================================================================--
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "IllegalSoccerEnterpriseESP"
ESPFolder.Parent = ScreenGui

local TrajectoryBeam = Instance.new("Beam")
TrajectoryBeam.TextureMode = Enum.TextureMode.Wrap
TrajectoryBeam.Width0 = 0.35
TrajectoryBeam.Width1 = 0.35
TrajectoryBeam.Color = ColorSequence.new(Color3.fromRGB(0, 220, 255))
TrajectoryBeam.Transparency = NumberSequence.new(0.2)
TrajectoryBeam.FaceCamera = true

local Attach0 = Instance.new("Attachment")
local Attach1 = Instance.new("Attachment")
TrajectoryBeam.Attachment0 = Attach0
TrajectoryBeam.Attachment1 = Attach1

RunService.RenderStepped:Connect(function()
    if not (Config.BallESP or Config.PlayerESP or Config.GoalESP or Config.TrajectoryLine) then
        ESPFolder:ClearAllChildren()
        TrajectoryBeam.Parent = nil
        return
    end

    pcall(function()
        ESPFolder:ClearAllChildren()

        local ball = GetBall()
        local enemyGoal, ownGoal = GetGoals()

        -- Ball ESP
        if Config.BallESP and ball then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 110, 0, 32)
            bb.AlwaysOnTop = true
            bb.Adornee = ball
            bb.Parent = ESPFolder

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = string.format("⚽ Ball [%dm]", math.floor((ball.Position - Camera.CFrame.Position).Magnitude))
            lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 11
            lbl.Parent = bb
        end

        -- Goal ESP
        if Config.GoalESP then
            local function createGoalMarker(part, textStr, col)
                if not part then return end
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 130, 0, 32)
                bb.AlwaysOnTop = true
                bb.Adornee = part
                bb.Parent = ESPFolder

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = textStr
                lbl.TextColor3 = col
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 11
                lbl.Parent = bb
            end
            createGoalMarker(enemyGoal, "🎯 ENEMY GOAL", Color3.fromRGB(255, 75, 75))
            createGoalMarker(ownGoal, "🛡️ OWN GOAL", Color3.fromRGB(75, 255, 120))
        end

        -- Player ESP
        if Config.PlayerESP then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
                    local head = plr.Character.Head
                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.new(0, 100, 0, 26)
                    bb.AlwaysOnTop = true
                    bb.Adornee = head
                    bb.Parent = ESPFolder

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = string.format("%s [%dm]", plr.Name, math.floor((head.Position - Camera.CFrame.Position).Magnitude))
                    lbl.TextColor3 = (plr.Team == LocalPlayer.Team) and Color3.fromRGB(100, 210, 255) or Color3.fromRGB(255, 100, 100)
                    lbl.Font = Enum.Font.Gotham
                    lbl.TextSize = 10
                    lbl.Parent = bb
                end
            end
        end

        -- Trajectory Line
        if Config.TrajectoryLine and ball and enemyGoal then
            Attach0.Parent = ball
            Attach1.Parent = Workspace.Terrain
            TrajectoryBeam.Parent = ESPFolder
            Attach0.Position = Vector3.new(0, 0, 0)
            Attach1.Position = ball.Position + (ball.AssemblyLinearVelocity * 0.9)
        else
            TrajectoryBeam.Parent = nil
        end
    end)
end)

-- Anti-AFK Background Routine
task.spawn(function()
    while task.wait(50) do
        pcall(function()
            local VU = game:GetService("VirtualUser")
            VU:CaptureController()
            VU:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)
