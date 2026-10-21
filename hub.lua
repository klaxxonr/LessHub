--===================================================================================--
--  ILLEGAL SOCCER ULTIMATE MOBILE HUB (v2.5)
--  Target Game: Illegal Soccer / Illegal Soccer Tournament (Roblox)
--  Supported Executors: Delta (Android/iOS), Solara, Xeno, Wave, Hydroxide
--  Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/.../main.lua"))()
--===================================================================================--

-- Guard against double execution
if getgenv().IllegalSoccerHubLoaded then
    if getgenv().ToggleIllegalHubUI then
        getgenv().ToggleIllegalHubUI()
    end
    return
end
getgenv().IllegalSoccerHubLoaded = true

--===================================================================================--
-- SERVICES & SAFE EXECUTOR ENVIRONMENT WRAPPERS
--===================================================================================--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Executor function wrappers with safe fallbacks
local safeWriteFile = function(file, contents)
    pcall(function()
        if writefile then writefile(file, contents) end
    end)
end

local safeReadFile = function(file)
    local success, result = pcall(function()
        if readfile and isfile and isfile(file) then return readfile(file) end
    end)
    if success then return result end
    return nil
end

--===================================================================================--
-- CONFIGURATION & STATE SYSTEM
--===================================================================================--
local CONFIG_FILE = "IllegalSoccerHub_Config.json"

local Config = {
    -- Combat
    PerfectShot = false,
    ShotPower = 80,
    AimHeight = "Mid", -- "Ground", "Mid", "Top Corner"
    AutoShootRange = 45,
    
    SilentAim = false,
    SilentAimStrength = 75, -- Lerp percentage
    
    CurveEnabled = false,
    CurvePower = 45,
    CurveDirection = "Auto", -- "Auto", "Left", "Right"
    
    AutoDribble = false,
    ApproachRange = 8,
    ChaseSpeed = 22,
    
    Unstoppable = false,
    PowerBoost = 1.3,
    
    AutoScore = false,
    GuidanceStrength = 35,

    -- Defense
    AutoKeeper = false,
    ReactionTime = 0.1,
    PredictionTime = 1.2,
    MaxWalkDistance = 35,
    
    InfiniteStamina = false,
    SpeedBoost = 22,
    
    AntiTackle = false,
    AntiTackleForce = 50,
    
    BallMagnet = false,
    MagnetRadius = 15,
    MagnetForce = 30,

    -- Visuals
    BallESP = true,
    PlayerESP = true,
    GoalESP = true,
    TrajectoryLine = true,

    -- Misc
    AntiBanJitter = true,
    SafeMode = false,
    FPSBoost = false,
    
    -- UI Settings
    KeyValidated = false
}

local OriginalWalkSpeed = 16
local FPSBoostCache = {}

local function LoadConfig()
    local data = safeReadFile(CONFIG_FILE)
    if data then
        local success, decoded = pcall(function() return HttpService:JSONDecode(data) end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then
                    Config[k] = v
                end
            end
        end
    end
end

local function SaveConfig()
    local success, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if success and encoded then
        safeWriteFile(CONFIG_FILE, encoded)
    end
end

LoadConfig()

--===================================================================================--
-- GAME DETECTION ENGINE (BALL, GOALS, TEAM)
--===================================================================================--
local CachedBall = nil
local LastBallScan = 0

local function FindBall()
    if tick() - LastBallScan < 1.5 and CachedBall and CachedBall:IsDescendantOf(Workspace) then
        return CachedBall
    end
    LastBallScan = tick()

    -- Search by common names
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if name:find("ball") or name:find("soccer") or name:find("football") or name == "top" then
                CachedBall = obj
                return obj
            end
        end
    end

    -- Fallback: find highest velocity unanchored small part near workspace ground
    local candidates = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and not obj.Anchored and obj.Size.Magnitude < 10 then
            if obj.AssemblyLinearVelocity.Magnitude > 1 then
                table.insert(candidates, obj)
            end
        end
    end
    
    table.sort(candidates, function(a, b)
        return a.AssemblyLinearVelocity.Magnitude > b.AssemblyLinearVelocity.Magnitude
    end)

    if #candidates > 0 then
        CachedBall = candidates[1]
        return candidates[1]
    end

    return nil
end

local function GetGoals()
    local enemyGoal, ownGoal = nil, nil
    local myTeam = LocalPlayer.Team

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if name:find("goal") or name:find("net") or name:find("score") then
                local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                if part then
                    -- Team heuristic based on naming or positioning
                    if name:find("red") or name:find("away") or name:find("guest") or name:find("2") then
                        if myTeam and (myTeam.Name:lower():find("red") or myTeam.Name:lower():find("2")) then
                            ownGoal = part
                        else
                            enemyGoal = part
                        end
                    elseif name:find("blue") or name:find("home") or name:find("1") then
                        if myTeam and (myTeam.Name:lower():find("blue") or myTeam.Name:lower():find("1")) then
                            ownGoal = part
                        else
                            enemyGoal = part
                        end
                    else
                        -- Distinguish by distance to player starting orientation
                        if not enemyGoal then enemyGoal = part else ownGoal = part end
                    end
                end
            end
        end
    end
    return enemyGoal, ownGoal
end

--===================================================================================--
-- MOBILE-FIRST USER INTERFACE BUILDER
--===================================================================================--
local ParentGui = CoreGui
pcall(function()
    if gethui then ParentGui = gethui() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IllegalSoccerHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

-- Floating Toggle Button (Mobile Friendly)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "HubToggleButton"
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0.02, 0, 0.2, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = "⚽"
ToggleButton.TextSize = 26
ToggleButton.TextColor3 = Color3.fromRGB(0, 210, 255)
ToggleButton.ZIndex = 100
ToggleButton.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0.5, 0)
ToggleCorner.Parent = ToggleButton

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(0, 170, 255)
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleButton

-- Main Window
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 350, 0, 260)
MainWindow.Position = UDim2.new(0.5, -175, 0.5, -130)
MainWindow.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainWindow.BorderSizePixel = 0
MainWindow.ClipsDescendants = true
MainWindow.Visible = false
MainWindow.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainWindow

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(35, 40, 55)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainWindow

-- Title Bar / Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
Header.BorderSizePixel = 0
Header.Parent = MainWindow

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "ILLEGAL SOCCER HUB"
TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -34, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 25)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Dragging Mechanics (Mobile & Touch Compatible)
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    MainWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainWindow.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
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
        update(input)
    end
end)

-- Key System Window
local KeyWindow = Instance.new("Frame")
KeyWindow.Name = "KeyWindow"
KeyWindow.Size = UDim2.new(0, 290, 0, 160)
KeyWindow.Position = UDim2.new(0.5, -145, 0.5, -80)
KeyWindow.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
KeyWindow.BorderSizePixel = 0
KeyWindow.Parent = ScreenGui

local KeyCorner = Instance.new("UICorner")
KeyCorner.CornerRadius = UDim.new(0, 10)
KeyCorner.Parent = KeyWindow

local KeyTitle = Instance.new("TextLabel")
KeyTitle.Size = UDim2.new(1, 0, 0, 35)
KeyTitle.BackgroundTransparency = 1
KeyTitle.Text = "ENTER ACCESS KEY"
KeyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyTitle.Font = Enum.Font.GothamBold
KeyTitle.TextSize = 14
KeyTitle.Parent = KeyWindow

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(0.85, 0, 0, 40)
KeyInput.Position = UDim2.new(0.075, 0, 0.3, 0)
KeyInput.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
KeyInput.TextColor3 = Color3.fromRGB(0, 220, 255)
KeyInput.PlaceholderText = "Enter Key Here..."
KeyInput.PlaceholderColor3 = Color3.fromRGB(100, 110, 130)
KeyInput.Font = Enum.Font.Gotham
KeyInput.TextSize = 14
KeyInput.Text = ""
KeyInput.Parent = KeyWindow

local KeyInputCorner = Instance.new("UICorner")
KeyInputCorner.CornerRadius = UDim.new(0, 6)
KeyInputCorner.Parent = KeyInput

local ValidateBtn = Instance.new("TextButton")
ValidateBtn.Size = UDim2.new(0.85, 0, 0, 40)
ValidateBtn.Position = UDim2.new(0.075, 0, 0.65, 0)
ValidateBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 220)
ValidateBtn.Text = "VALIDATE KEY"
ValidateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ValidateBtn.Font = Enum.Font.GothamBold
ValidateBtn.TextSize = 14
ValidateBtn.Parent = KeyWindow

local ValidateCorner = Instance.new("UICorner")
ValidateCorner.CornerRadius = UDim.new(0, 6)
ValidateCorner.Parent = ValidateBtn

-- Validation Logic
ValidateBtn.MouseButton1Click:Connect(function()
    Config.KeyValidated = true
    KeyWindow.Visible = false
    MainWindow.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainWindow.Visible = false
end)

ToggleButton.MouseButton1Click:Connect(function()
    if Config.KeyValidated then
        MainWindow.Visible = not MainWindow.Visible
    else
        KeyWindow.Visible = not KeyWindow.Visible
    end
end)

getgenv().ToggleIllegalHubUI = function()
    if Config.KeyValidated then
        MainWindow.Visible = not MainWindow.Visible
    else
        KeyWindow.Visible = not KeyWindow.Visible
    end
end

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 85, 1, -38)
Sidebar.Position = UDim2.new(0, 0, 0, 38)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainWindow

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.Parent = Sidebar

local Container = Instance.new("Frame")
Container.Name = "Container"
Container.Size = UDim2.new(1, -90, 1, -44)
Container.Position = UDim2.new(0, 88, 0, 41)
Container.BackgroundTransparency = 1
Container.Parent = MainWindow

local TabFrames = {}
local TabButtons = {}

local function CreateTab(name)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, 0, 0, 38)
    TabBtn.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
    TabBtn.BorderSizePixel = 0
    TabBtn.Text = name
    TabBtn.TextColor3 = Color3.fromRGB(140, 150, 170)
    TabBtn.Font = Enum.Font.GothamBold
    TabBtn.TextSize = 11
    TabBtn.Parent = Sidebar

    local TabFrame = Instance.new("ScrollingFrame")
    TabFrame.Size = UDim2.new(1, 0, 1, 0)
    TabFrame.BackgroundTransparency = 1
    TabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabFrame.ScrollBarThickness = 3
    TabFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
    TabFrame.Visible = false
    TabFrame.Parent = Container

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 6)
    TabLayout.Parent = TabFrame

    TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabFrame.CanvasSize = UDim2.new(0, 0, 0, TabLayout.AbsoluteContentSize.Y + 10)
    end)

    TabButtons[name] = TabBtn
    TabFrames[name] = TabFrame

    TabBtn.MouseButton1Click:Connect(function()
        for tName, btn in pairs(TabButtons) do
            btn.TextColor3 = Color3.fromRGB(140, 150, 170)
            btn.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
        end
        for tName, frame in pairs(TabFrames) do
            frame.Visible = false
        end
        TabBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
        TabBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
        TabFrame.Visible = true
    end)

    return TabFrame
end

local CombatTab = CreateTab("Combat")
local DefenseTab = CreateTab("Defense")
local VisualsTab = CreateTab("Visuals")
local MiscTab = CreateTab("Misc")
local SettingsTab = CreateTab("Settings")

-- Select initial tab
TabButtons["Combat"].TextColor3 = Color3.fromRGB(0, 200, 255)
TabButtons["Combat"].BackgroundColor3 = Color3.fromRGB(28, 32, 45)
TabFrames["Combat"].Visible = true

-- Helper UI Elements
local function AddToggle(parent, text, configKey, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -8, 0, 40)
    Row.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    Row.BorderSizePixel = 0
    Row.Parent = parent

    local RowCorner = Instance.new("UICorner")
    RowCorner.CornerRadius = UDim.new(0, 6)
    RowCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 8, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(220, 220, 230)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 50, 0, 28)
    ToggleBtn.Position = UDim2.new(1, -56, 0.5, -14)
    ToggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 180, 120) or Color3.fromRGB(50, 55, 70)
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
        ToggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 180, 120) or Color3.fromRGB(50, 55, 70)
        ToggleBtn.Text = Config[configKey] and "ON" or "OFF"
        SaveConfig()
        if callback then callback(Config[configKey]) end
    end)
end

local function AddSlider(parent, text, configKey, min, max, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -8, 0, 44)
    Row.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    Row.BorderSizePixel = 0
    Row.Parent = parent

    local RowCorner = Instance.new("UICorner")
    RowCorner.CornerRadius = UDim.new(0, 6)
    RowCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 0.5, 0)
    Label.Position = UDim2.new(0, 8, 0, 2)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(200, 205, 220)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local ValLabel = Instance.new("TextLabel")
    ValLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
    ValLabel.Position = UDim2.new(0.68, 0, 0, 2)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(Config[configKey])
    ValLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    ValLabel.Font = Enum.Font.GothamBold
    ValLabel.TextSize = 10
    ValLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValLabel.Parent = Row

    local MinusBtn = Instance.new("TextButton")
    MinusBtn.Size = UDim2.new(0, 35, 0, 20)
    MinusBtn.Position = UDim2.new(0, 8, 0.5, 2)
    MinusBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
    MinusBtn.Text = "-"
    MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinusBtn.Font = Enum.Font.GothamBold
    MinusBtn.TextSize = 12
    MinusBtn.Parent = Row

    local PlusBtn = Instance.new("TextButton")
    PlusBtn.Size = UDim2.new(0, 35, 0, 20)
    PlusBtn.Position = UDim2.new(1, -43, 0.5, 2)
    PlusBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
    PlusBtn.Text = "+"
    PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlusBtn.Font = Enum.Font.GothamBold
    PlusBtn.TextSize = 12
    PlusBtn.Parent = Row

    local function updateVal(newVal)
        newVal = math.clamp(newVal, min, max)
        Config[configKey] = newVal
        ValLabel.Text = tostring(newVal)
        SaveConfig()
        if callback then callback(newVal) end
    end

    MinusBtn.MouseButton1Click:Connect(function()
        updateVal(Config[configKey] - (max > 20 and 5 or 1))
    end)

    PlusBtn.MouseButton1Click:Connect(function()
        updateVal(Config[configKey] + (max > 20 and 5 or 1))
    end)
end

--===================================================================================--
-- POPULATE UI TABS
--===================================================================================--

-- Combat
AddToggle(CombatTab, "Perfect Shot", "PerfectShot")
AddSlider(CombatTab, "Shot Power", "ShotPower", 10, 150)
AddSlider(CombatTab, "Auto Shoot Range", "AutoShootRange", 10, 100)

AddToggle(CombatTab, "Goal Silent Aim", "SilentAim")
AddSlider(CombatTab, "Aim Strength %", "SilentAimStrength", 10, 100)

AddToggle(CombatTab, "Curve Shot (Falso)", "CurveEnabled")
AddSlider(CombatTab, "Curve Power", "CurvePower", 0, 150)

AddToggle(CombatTab, "Auto Dribble", "AutoDribble")
AddSlider(CombatTab, "Approach Range", "ApproachRange", 3, 25)
AddSlider(CombatTab, "Chase Speed", "ChaseSpeed", 16, 40)

AddToggle(CombatTab, "Unstoppable Shots", "Unstoppable")
AddToggle(CombatTab, "Auto Score Guidance", "AutoScore")

-- Defense
AddToggle(DefenseTab, "Auto Goalkeeper", "AutoKeeper")
AddSlider(DefenseTab, "Max Keeper Walk Dist", "MaxWalkDistance", 10, 80)

AddToggle(DefenseTab, "Infinite Stamina", "InfiniteStamina")
AddSlider(DefenseTab, "Speed Boost", "SpeedBoost", 16, 60)

AddToggle(DefenseTab, "Anti-Tackle Stun", "AntiTackle")
AddToggle(DefenseTab, "Ball Magnet", "BallMagnet")
AddSlider(DefenseTab, "Magnet Radius", "MagnetRadius", 5, 40)

-- Visuals
AddToggle(VisualsTab, "Ball ESP", "BallESP")
AddToggle(VisualsTab, "Player ESP", "PlayerESP")
AddToggle(VisualsTab, "Goal ESP", "GoalESP")
AddToggle(VisualsTab, "Trajectory Line", "TrajectoryLine")

-- Misc
AddToggle(MiscTab, "Anti-Ban Jitter", "AntiBanJitter")
AddToggle(MiscTab, "Safe Mode (Cap Power)", "SafeMode")
AddToggle(MiscTab, "FPS Boost", "FPSBoost", function(val)
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
                if item.obj and item.parent then
                    item.obj.Parent = item.parent
                end
            end
            FPSBoostCache = {}
            Lighting.GlobalShadows = true
        end
    end)
end)

-- Server Hop Button
local HopRow = Instance.new("Frame")
HopRow.Size = UDim2.new(1, -8, 0, 36)
HopRow.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
HopRow.Parent = MiscTab
local HopBtn = Instance.new("TextButton")
HopBtn.Size = UDim2.new(1, 0, 1, 0)
HopBtn.BackgroundTransparency = 1
HopBtn.Text = "Server Hop"
HopBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
HopBtn.Font = Enum.Font.GothamBold
HopBtn.TextSize = 11
HopBtn.Parent = HopRow

HopBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local Api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local Http = HttpService:JSONDecode(game:HttpGet(Api))
        if Http and Http.data then
            for _, server in ipairs(Http.data) do
                if server.playing ~= server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id)
                    break
                end
            end
        end
    end)
end)

-- Settings Tab Reset Button
local ResetRow = Instance.new("Frame")
ResetRow.Size = UDim2.new(1, -8, 0, 36)
ResetRow.BackgroundColor3 = Color3.fromRGB(35, 20, 25)
ResetRow.Parent = SettingsTab
local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(1, 0, 1, 0)
ResetBtn.BackgroundTransparency = 1
ResetBtn.Text = "Reset Config Defaults"
ResetBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.TextSize = 11
ResetBtn.Parent = ResetRow

ResetBtn.MouseButton1Click:Connect(function()
    if isfile and safeWriteFile then
        pcall(function() delfile(CONFIG_FILE) end)
    end
    LocalPlayer:Kick("Config Reset. Please Rejoin!")
end)

--===================================================================================--
-- CORE GAMEPLAY LOOPS & COMBAT LOGIC
--===================================================================================--

-- Jitter / Anti-Ban Guard Helper
local function applySafeJitter(vec)
    if not Config.AntiBanJitter then return vec end
    local jitterX = (math.random() - 0.5) * 0.04
    local jitterZ = (math.random() - 0.5) * 0.04
    return vec + Vector3.new(jitterX, 0, jitterZ)
end

-- WalkSpeed Management Engine
RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hum then return end

        local effectiveSpeed = OriginalWalkSpeed

        if Config.InfiniteStamina then
            effectiveSpeed = Config.SpeedBoost
            -- Attempt to keep stamina attribute maximized
            if char:GetAttribute("Stamina") then
                char:SetAttribute("Stamina", 100)
            end
        end

        if Config.SafeMode and effectiveSpeed > 24 then
            effectiveSpeed = 24
        end

        -- Only boost WalkSpeed when needed to avoid overriding standard control state
        if hum.WalkSpeed ~= effectiveSpeed then
            hum.WalkSpeed = effectiveSpeed
        end
    end)
end)

-- Main Physics and Combat Engine
RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum then return end

        local ball = FindBall()
        local enemyGoal, ownGoal = GetGoals()

        if not ball then return end

        local ballDist = (ball.Position - hrp.Position).Magnitude

        -- 1. BALL MAGNET
        if Config.BallMagnet and ballDist <= Config.MagnetRadius and not ball.Anchored then
            local pullDir = (hrp.Position - ball.Position).Unit
            ball.AssemblyLinearVelocity = applySafeJitter(pullDir * Config.MagnetForce)
        end

        -- 2. AUTO DRIBBLE (Smart approach: only control character when far)
        if Config.AutoDribble and ballDist > Config.ApproachRange and ballDist < 60 then
            local dir = (ball.Position - hrp.Position).Unit
            hum:Move(applySafeJitter(dir), false)
        end

        -- 3. PERFECT SHOT & SILENT AIM & CURVE & UNSTOPPABLE COMBINATION
        if (Config.PerfectShot or Config.SilentAim or Config.Unstoppable) and enemyGoal then
            if ballDist <= Config.AutoShootRange and ball.AssemblyLinearVelocity.Magnitude > 2 then
                local goalPos = enemyGoal.Position

                -- Apply Aim Height Adjustment
                if Config.AimHeight == "Ground" then
                    goalPos = Vector3.new(goalPos.X, goalPos.Y + 1.5, goalPos.Z)
                elseif Config.AimHeight == "Top Corner" then
                    goalPos = Vector3.new(goalPos.X, goalPos.Y + 6.5, goalPos.Z)
                else
                    goalPos = Vector3.new(goalPos.X, goalPos.Y + 4.0, goalPos.Z)
                end

                local targetDir = (goalPos - ball.Position).Unit
                local targetPower = Config.ShotPower

                if Config.Unstoppable then
                    targetPower = targetPower * Config.PowerBoost
                end

                if Config.SafeMode then
                    targetPower = math.min(targetPower, 65)
                end

                -- Compute Curve Offset
                if Config.CurveEnabled and Config.CurvePower > 0 then
                    local sideVector = Vector3.new(-targetDir.Z, 0, targetDir.X)
                    local curveMult = (Config.CurveDirection == "Left") and -1 or 1
                    targetDir = (targetDir + (sideVector * (Config.CurvePower / 100) * curveMult)).Unit
                end

                -- Apply Silent Aim Lerp
                local currentVel = ball.AssemblyLinearVelocity
                local targetVel = targetDir * targetPower
                local lerpRatio = (Config.SilentAim and (Config.SilentAimStrength / 100)) or 0.85

                local finalVel = currentVel:Lerp(targetVel, lerpRatio)
                
                -- Clamp velocity for physics sanity
                if finalVel.Magnitude > 180 then
                    finalVel = finalVel.Unit * 180
                end

                ball.AssemblyLinearVelocity = applySafeJitter(finalVel)
            end
        end

        -- 4. AUTO GOALKEEPER (Trajectory Intercept Prediction)
        if Config.AutoKeeper and ownGoal and ball then
            local ballVel = ball.AssemblyLinearVelocity
            local predictedBallPos = ball.Position + (ballVel * Config.PredictionTime)
            
            -- Intercept point on the line between own goal and predicted ball
            local goalToBall = (predictedBallPos - ownGoal.Position)
            local targetPosition = ownGoal.Position + goalToBall.Unit * math.clamp(goalToBall.Magnitude * 0.3, 4, Config.MaxWalkDistance)
            
            local keeperDist = (targetPosition - hrp.Position).Magnitude
            if keeperDist > 3 then
                local moveDir = (targetPosition - hrp.Position).Unit
                hum:Move(applySafeJitter(moveDir), false)
            end
        end

        -- 5. ANTI-TACKLE STUN RECOVERY
        if Config.AntiTackle then
            if hum:GetState() == Enum.HumanoidStateType.PlatformStanding or hum:GetState() == Enum.HumanoidStateType.Physics then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hrp.AssemblyLinearVelocity = Vector3.new(0, Config.AntiTackleForce, 0)
            end
        end
    end)
end)

--===================================================================================--
-- VISUALS ENGINE (ESP & TRAJECTORY LINE)
--===================================================================================--
local TrajectoryBeam = Instance.new("Beam")
TrajectoryBeam.TextureMode = Enum.TextureMode.Wrap
TrajectoryBeam.Width0 = 0.4
TrajectoryBeam.Width1 = 0.4
TrajectoryBeam.Color = ColorSequence.new(Color3.fromRGB(0, 220, 255))
TrajectoryBeam.Transparency = NumberSequence.new(0.2)
TrajectoryBeam.FaceCamera = true

local Att0 = Instance.new("Attachment")
local Att1 = Instance.new("Attachment")
TrajectoryBeam.Attachment0 = Att0
TrajectoryBeam.Attachment1 = Att1

local ESPHolder = Instance.new("Folder")
ESPHolder.Name = "IllegalSoccerESP"
ESPHolder.Parent = ScreenGui

RunService.RenderStepped:Connect(function()
    pcall(function()
        ESPHolder:ClearAllChildren()

        local ball = FindBall()
        local enemyGoal, ownGoal = GetGoals()

        -- 1. BALL ESP
        if Config.BallESP and ball then
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.AlwaysOnTop = true
            billboard.Adornee = ball
            billboard.Parent = ESPHolder

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = string.format("⚽ Ball [%dm]", math.floor((ball.Position - Camera.CFrame.Position).Magnitude))
            label.TextColor3 = Color3.fromRGB(255, 220, 0)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 11
            label.Parent = billboard
        end

        -- 2. GOAL ESP
        if Config.GoalESP then
            local function makeGoalHighlight(part, name, col)
                if not part then return end
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 120, 0, 30)
                bb.AlwaysOnTop = true
                bb.Adornee = part
                bb.Parent = ESPHolder

                local txt = Instance.new("TextLabel")
                txt.Size = UDim2.new(1, 0, 1, 0)
                txt.BackgroundTransparency = 1
                txt.Text = name
                txt.TextColor3 = col
                txt.Font = Enum.Font.GothamBold
                txt.TextSize = 12
                txt.Parent = bb
            end
            makeGoalHighlight(enemyGoal, "🎯 ENEMY GOAL", Color3.fromRGB(255, 60, 60))
            makeGoalHighlight(ownGoal, "🛡️ OWN GOAL", Color3.fromRGB(60, 255, 100))
        end

        -- 3. PLAYER ESP
        if Config.PlayerESP then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
                    local head = plr.Character.Head
                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.new(0, 100, 0, 25)
                    bb.AlwaysOnTop = true
                    bb.Adornee = head
                    bb.Parent = ESPHolder

                    local txt = Instance.new("TextLabel")
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.Text = string.format("%s [%dm]", plr.Name, math.floor((head.Position - Camera.CFrame.Position).Magnitude))
                    txt.TextColor3 = (plr.Team == LocalPlayer.Team) and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 100, 100)
                    txt.Font = Enum.Font.Gotham
                    txt.TextSize = 10
                    txt.Parent = bb
                end
            end
        end

        -- 4. TRAJECTORY LINE
        if Config.TrajectoryLine and ball and enemyGoal then
            Att0.Parent = ball
            Att1.Parent = Workspace.Terrain
            TrajectoryBeam.Parent = ESPHolder
            
            Att0.Position = Vector3.new(0, 0, 0)
            Att1.Position = ball.Position + (ball.AssemblyLinearVelocity * 0.8)
        else
            TrajectoryBeam.Parent = nil
        end
    end)
end)

-- Anti-AFK Simulation Loop
task.spawn(function()
    while task.wait(60) do
        pcall(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)
