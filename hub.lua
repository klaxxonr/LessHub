--==============================================================================--
--  LessHub - Illegal Soccer (Personal Research & Optimization Suite)
--  Target Executor: Delta (Mobile First / Android/iOS), Synapse, Wave, KRNL, Solara
--  Version: 1.0.0
--  Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/..."))()
--==============================================================================--

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--------------------------------------------------------------------------------
-- CONFIGURATION & STATE SYSTEM
--------------------------------------------------------------------------------
local Config = {
    -- Key System
    KeyValidated = false,
    
    -- Combat Settings
    ShotAssist = false,
    ShotPower = 80,
    ShotHeight = "Middle", -- Ground, Middle, TopCorner
    AutoShotDistance = 15,
    
    AimSmoothing = false,
    AimPower = 5,
    
    CurveEnabled = false,
    CurvePower = 50,
    CurveDirection = "Auto", -- Left, Right, Auto
    
    DribbleAssist = false,
    DribbleDistance = 12,
    DribbleSpeed = 20,
    
    CombinedShot = false,
    CombinedMultiplier = 1.2,
    
    AutoScoreGuidance = false,
    GuidancePower = 15,
    
    -- Defense Settings
    GKAssist = false,
    GKReactionTime = 0.2,
    GKWalkDistance = 25,
    GKPredictionTime = 1.5,
    
    StaminaHelper = false,
    WalkSpeedBoost = 20,
    
    AntiStun = false,
    AntiStunPower = 10,
    
    BallAttraction = false,
    AttractionRadius = 15,
    AttractionForce = 30,
    
    -- Visuals
    BallHighlight = false,
    PlayerHighlight = false,
    GoalHighlight = false,
    TrajectoryLine = false,
    
    -- Misc
    StabilityLayer = false,
    SafeMode = false,
    PerformanceOptimizer = false,
    IdlePrevent = false,
    
    -- Hidden runtime states
    OriginalWalkSpeed = 16,
    IsSafeModeActive = false
}

local SafeConfig = {}
local HiddenVisualObjects = {}
local OriginalLightingSettings = {
    GlobalShadows = Lighting.GlobalShadows,
    ShadowSoftness = Lighting.ShadowSoftness
}

--------------------------------------------------------------------------------
-- UTILITY & CACHING SYSTEM
--------------------------------------------------------------------------------
local Cache = {
    Ball = nil,
    EnemyGoal = nil,
    OwnGoal = nil,
    LastBallScan = 0,
    LastGoalScan = 0,
    AlreadyDoingAction = false
}

local function SafePcall(fn, ...)
    local success, err = pcall(fn, ...)
    if not success then
        warn("[LessHub SafePcall Warning]: " .. tostring(err))
    end
    return success, err
end

-- Detection: Ball
local function GetBall()
    if Cache.Ball and Cache.Ball.Parent and tick() - Cache.LastBallScan < 2 then
        return Cache.Ball
    end
    
    Cache.LastBallScan = tick()
    local bestBall = nil
    local highestVelocity = -1
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if string.find(name, "ball") or string.find(name, "soccer") or string.find(name, "football") or string.find(name, "top") then
                Cache.Ball = obj
                return obj
            end
            
            -- Fallback heuristic: High speed physics part near center
            if obj.Velocity.Magnitude > highestVelocity and obj.Velocity.Magnitude > 5 then
                highestVelocity = obj.Velocity.Magnitude
                bestBall = obj
            end
        end
    end
    
    Cache.Ball = bestBall
    return bestBall
end

-- Detection: Goals & Teams
local function GetGoals()
    if Cache.EnemyGoal and Cache.OwnGoal and tick() - Cache.LastGoalScan < 10 then
        return Cache.EnemyGoal, Cache.OwnGoal
    end
    
    Cache.LastGoalScan = tick()
    local goals = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if string.find(name, "goal") or string.find(name, "net") or string.find(name, "score") then
                table.insert(goals, obj)
            end
        end
    end
    
    if #goals >= 2 then
        -- Assign based on position relative to local player spawn or Z axis
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pPos = char.HumanoidRootPart.Position
            table.sort(goals, function(a, b)
                local posA = a:IsA("Model") and a:GetPivot().Position or a.Position
                local posB = b:IsA("Model") and b:GetPivot().Position or b.Position
                return (posA - pPos).Magnitude > (posB - pPos).Magnitude
            end)
            Cache.EnemyGoal = goals[1]
            Cache.OwnGoal = goals[2]
        end
    end
    
    return Cache.EnemyGoal, Cache.OwnGoal
end

local function GetEffectiveValue(val, isPower)
    if Config.SafeMode then
        return val * 0.6
    end
    return val
end

--------------------------------------------------------------------------------
-- FILE SYSTEM (SAVE/LOAD CONFIG)
--------------------------------------------------------------------------------
local ConfigFileName = "LessHub_IllegalSoccer_Config.json"

local function SaveConfig()
    SafePcall(function()
        if writefile then
            local data = HttpService:JSONEncode(Config)
            writefile(ConfigFileName, data)
        end
    end)
end

local function LoadConfig()
    SafePcall(function()
        if readfile and isfile and isfile(ConfigFileName) then
            local data = readfile(ConfigFileName)
            local decoded = HttpService:JSONDecode(data)
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then
                    Config[k] = v
                end
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- UI CONSTRUCTION (MOBILE / DELTA OPTIMIZED)
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LessHub_UI"
ScreenGui.ResetOnSpawn = false

-- Executor check to attach to CoreGui safely
SafePcall(function()
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game:GetService("CoreGui")
    else
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end)

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 260)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(35, 85, 185)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- Top Bar
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 35)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0.6, 0, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "LessHub | Illegal Soccer"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.Parent = TopBar

-- Close & Minimize Buttons
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -35, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(220, 60, 60)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 35, 0, 35)
MinBtn.Position = UDim2.new(1, -70, 0, 0)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.Parent = TopBar

-- Dragging Functionality for Touch & Mouse
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Floating Toggle Hub Button (For Mobile Accessibility)
local ToggleHubBtn = Instance.new("TextButton")
ToggleHubBtn.Name = "ToggleHubBtn"
ToggleHubBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleHubBtn.Position = UDim2.new(0, 10, 0.3, 0)
ToggleHubBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
ToggleHubBtn.Text = "HUB"
ToggleHubBtn.TextColor3 = Color3.fromRGB(0, 170, 255)
ToggleHubBtn.Font = Enum.Font.GothamBold
ToggleHubBtn.TextSize = 12
ToggleHubBtn.Parent = ScreenGui

local HubCorner = Instance.new("UICorner")
HubCorner.CornerRadius = UDim.new(0, 22)
HubCorner.Parent = ToggleHubBtn

local HubStroke = Instance.new("UIStroke")
HubStroke.Color = Color3.fromRGB(0, 170, 255)
HubStroke.Thickness = 1.5
HubStroke.Parent = ToggleHubBtn

ToggleHubBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

--------------------------------------------------------------------------------
-- KEY SYSTEM CONTAINER
--------------------------------------------------------------------------------
local KeyFrame = Instance.new("Frame")
KeyFrame.Size = UDim2.new(1, 0, 1, -35)
KeyFrame.Position = UDim2.new(0, 0, 0, 35)
KeyFrame.BackgroundTransparency = 1
KeyFrame.Parent = MainFrame

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(0.7, 0, 0, 40)
KeyInput.Position = UDim2.new(0.15, 0, 0.25, 0)
KeyInput.BackgroundColor3 = Color3.fromRGB(30, 34, 45)
KeyInput.PlaceholderText = "Enter Key Here..."
KeyInput.Text = ""
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.Font = Enum.Font.Gotham
KeyInput.TextSize = 13
KeyInput.Parent = KeyFrame

local KeyInputCorner = Instance.new("UICorner")
KeyInputCorner.CornerRadius = UDim.new(0, 6)
KeyInputCorner.Parent = KeyInput

local ValidateBtn = Instance.new("TextButton")
ValidateBtn.Size = UDim2.new(0.5, 0, 0, 40)
ValidateBtn.Position = UDim2.new(0.25, 0, 0.55, 0)
ValidateBtn.BackgroundColor3 = Color3.fromRGB(35, 115, 225)
ValidateBtn.Text = "Validate"
ValidateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ValidateBtn.Font = Enum.Font.GothamBold
ValidateBtn.TextSize = 14
ValidateBtn.Parent = KeyFrame

local ValCorner = Instance.new("UICorner")
ValCorner.CornerRadius = UDim.new(0, 6)
ValCorner.Parent = ValidateBtn

--------------------------------------------------------------------------------
-- MAIN APP CONTAINER (POST-VALIDATION)
--------------------------------------------------------------------------------
local AppFrame = Instance.new("Frame")
AppFrame.Size = UDim2.new(1, 0, 1, -35)
AppFrame.Position = UDim2.new(0, 0, 0, 35)
AppFrame.BackgroundTransparency = 1
AppFrame.Visible = false
AppFrame.Parent = MainFrame

-- Left Navigation Bar
local NavFrame = Instance.new("Frame")
NavFrame.Size = UDim2.new(0, 90, 1, 0)
NavFrame.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
NavFrame.BorderSizePixel = 0
NavFrame.Parent = AppFrame

local NavLayout = Instance.new("UIListLayout")
NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
NavLayout.Padding = UDim.new(0, 2)
NavLayout.Parent = NavFrame

-- Content Frame
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -95, 1, -10)
ContentFrame.Position = UDim2.new(0, 95, 0, 5)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = AppFrame

local Tabs = {}
local TabButtons = {}

local function CreateTab(name, order)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, 0, 0, 40)
    TabBtn.BackgroundTransparency = 1
    TabBtn.Text = name
    TabBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 11
    TabBtn.LayoutOrder = order
    TabBtn.Parent = NavFrame
    
    local TabScroll = Instance.new("ScrollingFrame")
    TabScroll.Size = UDim2.new(1, 0, 1, 0)
    TabScroll.BackgroundTransparency = 1
    TabScroll.BorderSizePixel = 0
    TabScroll.ScrollBarThickness = 3
    TabScroll.ScrollBarImageColor3 = Color3.fromRGB(50, 100, 200)
    TabScroll.Visible = false
    TabScroll.Parent = ContentFrame
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Padding = UDim.new(0, 6)
    ListLayout.Parent = TabScroll
    
    TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabScroll.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 10)
    end)
    
    TabBtn.MouseButton1Click:Connect(function()
        for _, btn in pairs(TabButtons) do
            btn.TextColor3 = Color3.fromRGB(150, 150, 160)
        end
        for _, sc in pairs(Tabs) do
            sc.Visible = false
        end
        TabBtn.TextColor3 = Color3.fromRGB(0, 170, 255)
        TabScroll.Visible = true
    end)
    
    Tabs[name] = TabScroll
    TabButtons[name] = TabBtn
    return TabScroll
end

local CombatTab  = CreateTab("Combat", 1)
local DefenseTab = CreateTab("Defense", 2)
local VisualsTab = CreateTab("Visuals", 3)
local MiscTab    = CreateTab("Misc", 4)
local SettingsTab= CreateTab("Settings", 5)

-- Default Open Combat Tab
TabButtons["Combat"].TextColor3 = Color3.fromRGB(0, 170, 255)
Tabs["Combat"].Visible = true

--------------------------------------------------------------------------------
-- UI COMPONENT BUILDERS (Row format: [Toggle] [Label] [Value] [Slider/+/-])
--------------------------------------------------------------------------------
local function AddRowToggle(parent, labelText, configKey, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -5, 0, 38)
    Row.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
    Row.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Row
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 8, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row
    
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 50, 0, 26)
    ToggleBtn.Position = UDim2.new(1, -55, 0.5, -13)
    ToggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(35, 135, 225) or Color3.fromRGB(45, 48, 60)
    ToggleBtn.Text = Config[configKey] and "ON" or "OFF"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 10
    ToggleBtn.Parent = Row
    
    local TCorner = Instance.new("UICorner")
    TCorner.CornerRadius = UDim.new(0, 4)
    TCorner.Parent = ToggleBtn
    
    ToggleBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        ToggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(35, 135, 225) or Color3.fromRGB(45, 48, 60)
        ToggleBtn.Text = Config[configKey] and "ON" or "OFF"
        if callback then callback(Config[configKey]) end
    end)
    return Row
end

local function AddRowSlider(parent, labelText, configKey, min, max, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -5, 0, 42)
    Row.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
    Row.Parent = parent
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Row
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.5, 0, 0.5, 0)
    Label.Position = UDim2.new(0, 8, 0, 2)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row
    
    local ValLabel = Instance.new("TextLabel")
    ValLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
    ValLabel.Position = UDim2.new(0.55, 0, 0, 2)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(Config[configKey])
    ValLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    ValLabel.Font = Enum.Font.GothamBold
    ValLabel.TextSize = 11
    ValLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValLabel.Parent = Row
    
    -- +/- Control Buttons for Precise Touch Adjustment
    local MinusBtn = Instance.new("TextButton")
    MinusBtn.Size = UDim2.new(0, 24, 0, 18)
    MinusBtn.Position = UDim2.new(0, 8, 0.55, 0)
    MinusBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
    MinusBtn.Text = "-"
    MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinusBtn.Font = Enum.Font.GothamBold
    MinusBtn.TextSize = 12
    MinusBtn.Parent = Row
    
    local PlusBtn = Instance.new("TextButton")
    PlusBtn.Size = UDim2.new(0, 24, 0, 18)
    PlusBtn.Position = UDim2.new(1, -30, 0.55, 0)
    PlusBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
    PlusBtn.Text = "+"
    PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlusBtn.Font = Enum.Font.GothamBold
    PlusBtn.TextSize = 12
    PlusBtn.Parent = Row
    
    local SliderBar = Instance.new("Frame")
    SliderBar.Size = UDim2.new(1, -70, 0, 6)
    SliderBar.Position = UDim2.new(0, 38, 0.7, 0)
    SliderBar.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
    SliderBar.BorderSizePixel = 0
    SliderBar.Parent = Row
    
    local SliderFill = Instance.new("Frame")
    local pct = math.clamp((Config[configKey] - min) / (max - min), 0, 1)
    SliderFill.Size = UDim2.new(pct, 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderBar
    
    local function UpdateVal(newVal)
        newVal = math.clamp(math.floor(newVal), min, max)
        Config[configKey] = newVal
        ValLabel.Text = tostring(newVal)
        local fillPct = math.clamp((newVal - min) / (max - min), 0, 1)
        SliderFill.Size = UDim2.new(fillPct, 0, 1, 0)
        if callback then callback(newVal) end
    end
    
    MinusBtn.MouseButton1Click:Connect(function() UpdateVal(Config[configKey] - 1) end)
    PlusBtn.MouseButton1Click:Connect(function() UpdateVal(Config[configKey] + 1) end)
    
    return Row
end

--------------------------------------------------------------------------------
-- POPULATING INTERFACE TABS
--------------------------------------------------------------------------------
-- COMBAT
AddRowToggle(CombatTab, "Shot Assist", "ShotAssist")
AddRowSlider(CombatTab, "Shot Power", "ShotPower", 10, 150)
AddRowSlider(CombatTab, "Auto Shot Dist", "AutoShotDistance", 5, 50)
AddRowToggle(CombatTab, "Aim Smoothing", "AimSmoothing")
AddRowSlider(CombatTab, "Aim Power", "AimPower", 1, 20)
AddRowToggle(CombatTab, "Curve Ball", "CurveEnabled")
AddRowSlider(CombatTab, "Curve Power", "CurvePower", 0, 150)
AddRowToggle(CombatTab, "Dribble Assist", "DribbleAssist")
AddRowSlider(CombatTab, "Dribble Dist", "DribbleDistance", 5, 30)
AddRowToggle(CombatTab, "Combined Shot", "CombinedShot")
AddRowToggle(CombatTab, "Auto Score Guidance", "AutoScoreGuidance")

-- DEFENSE
AddRowToggle(DefenseTab, "GK Pos Assist", "GKAssist")
AddRowSlider(DefenseTab, "GK Coverage", "GKWalkDistance", 5, 50)
AddRowToggle(DefenseTab, "Stamina Helper", "StaminaHelper")
AddRowSlider(DefenseTab, "WalkSpeed Boost", "WalkSpeedBoost", 16, 60)
AddRowToggle(DefenseTab, "Anti-Stun Assist", "AntiStun")
AddRowToggle(DefenseTab, "Ball Attraction", "BallAttraction")
AddRowSlider(DefenseTab, "Attract Radius", "AttractionRadius", 5, 40)

-- VISUALS
AddRowToggle(VisualsTab, "Ball Highlight", "BallHighlight")
AddRowToggle(VisualsTab, "Player Highlight", "PlayerHighlight")
AddRowToggle(VisualsTab, "Goal Highlight", "GoalHighlight")
AddRowToggle(VisualsTab, "Trajectory Line", "TrajectoryLine")

-- MISC
AddRowToggle(MiscTab, "Stability Layer", "StabilityLayer")
AddRowToggle(MiscTab, "Safe Mode", "SafeMode")
AddRowToggle(MiscTab, "Performance Opt", "PerformanceOptimizer", function(state)
    if state then
        SafePcall(function()
            Lighting.GlobalShadows = false
            Lighting.ShadowSoftness = 0
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Light") or v:IsA("Decal") or v:IsA("Texture") or v:IsA("Trail") then
                    if v.Enabled ~= nil then
                        table.insert(HiddenVisualObjects, {obj = v, prop = "Enabled", val = v.Enabled})
                        v.Enabled = false
                    elseif v.Transparency ~= nil then
                        table.insert(HiddenVisualObjects, {obj = v, prop = "Transparency", val = v.Transparency})
                        v.Transparency = 1
                    end
                end
            end
        end)
    else
        SafePcall(function()
            Lighting.GlobalShadows = OriginalLightingSettings.GlobalShadows
            Lighting.ShadowSoftness = OriginalLightingSettings.ShadowSoftness
            for _, item in ipairs(HiddenVisualObjects) do
                if item.obj and item.obj.Parent then
                    item.obj[item.prop] = item.val
                end
            end
            table.clear(HiddenVisualObjects)
        end)
    end
end)
AddRowToggle(MiscTab, "Anti-Idle Prevent", "IdlePrevent")

-- SETTINGS
local ResetRow = Instance.new("Frame")
ResetRow.Size = UDim2.new(1, -5, 0, 35)
ResetRow.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
ResetRow.Parent = SettingsTab

local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(0.9, 0, 0.8, 0)
ResetBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
ResetBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ResetBtn.Text = "Reset All Defaults"
ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.TextSize = 11
ResetBtn.Parent = ResetRow

local ConfigRow = Instance.new("Frame")
ConfigRow.Size = UDim2.new(1, -5, 0, 35)
ConfigRow.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
ConfigRow.Parent = SettingsTab

local SaveBtn = Instance.new("TextButton")
SaveBtn.Size = UDim2.new(0.42, 0, 0.8, 0)
SaveBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
SaveBtn.BackgroundColor3 = Color3.fromRGB(35, 115, 225)
SaveBtn.Text = "Save Config"
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 11
SaveBtn.Parent = ConfigRow

local LoadBtn = Instance.new("TextButton")
LoadBtn.Size = UDim2.new(0.42, 0, 0.8, 0)
LoadBtn.Position = UDim2.new(0.53, 0, 0.1, 0)
LoadBtn.BackgroundColor3 = Color3.fromRGB(35, 135, 80)
LoadBtn.Text = "Load Config"
LoadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadBtn.Font = Enum.Font.GothamBold
LoadBtn.TextSize = 11
LoadBtn.Parent = ConfigRow

SaveBtn.MouseButton1Click:Connect(SaveConfig)
LoadBtn.MouseButton1Click:Connect(LoadConfig)

-- Executor Info Label
local ExecInfo = Instance.new("TextLabel")
ExecInfo.Size = UDim2.new(1, -5, 0, 30)
ExecInfo.BackgroundTransparency = 1
ExecInfo.Text = "Env: " .. (identifyexecutor and identifyexecutor() or "Delta Mobile / Standard")
ExecInfo.TextColor3 = Color3.fromRGB(120, 120, 140)
ExecInfo.Font = Enum.Font.Gotham
ExecInfo.TextSize = 10
ExecInfo.Parent = SettingsTab

--------------------------------------------------------------------------------
-- KEY VALIDATION & INTERFACE CONTROL
--------------------------------------------------------------------------------
ValidateBtn.MouseButton1Click:Connect(function()
    Config.KeyValidated = true
    KeyFrame.Visible = false
    AppFrame.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

MinBtn.MouseButton1Click:Connect(function()
    AppFrame.Visible = not AppFrame.Visible
end)

--------------------------------------------------------------------------------
-- CORE MODULE LOGIC & FEATURE RUNNERS
--------------------------------------------------------------------------------

-- 1. Anti-Idle System (60s simulation)
task.spawn(function()
    while true do
        task.wait(60)
        if Config.IdlePrevent then
            SafePcall(function()
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end
end)

-- 2. Heartbeat Logic (Combat & Physics Engine Adjustments)
RunService.Heartbeat:Connect(function(dt)
    if not Config.KeyValidated then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    local ball = GetBall()
    local enemyGoal, ownGoal = GetGoals()

    -- Stability Layer Jitter Generation
    local jitter = Vector3.new(0, 0, 0)
    if Config.StabilityLayer then
        jitter = Vector3.new((math.random() - 0.5) * 0.02, 0, (math.random() - 0.5) * 0.02)
    end

    -- Stamina / WalkSpeed Handler
    if Config.StaminaHelper then
        local targetSpeed = GetEffectiveValue(Config.WalkSpeedBoost)
        if hum.WalkSpeed ~= targetSpeed then
            hum.WalkSpeed = targetSpeed
        end
        -- Hardcode-safe stamina attribute attempt
        if char:FindFirstChild("Stamina") and char.Stamina:IsA("NumberValue") then
            char.Stamina.Value = 100
        end
    end

    -- Anti-Stun Assist
    if Config.AntiStun then
        if hum:GetState() == Enum.HumanoidStateType.PlatformStanding or hum.PlatformStand then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end

    -- Dribble Assist (Movement triggered ONLY when ball is distant)
    if Config.DribbleAssist and ball then
        local dist = (ball.Position - hrp.Position).Magnitude
        if dist > Config.DribbleDistance and dist < 60 then
            local moveDir = (ball.Position - hrp.Position).Unit + jitter
            hum:Move(moveDir, false)
        end
    end

    -- Goalkeeper Positioning Assist
    if Config.GKAssist and ball and ownGoal then
        local goalPos = ownGoal:IsA("Model") and ownGoal:GetPivot().Position or ownGoal.Position
        local ballVel = ball.Velocity
        local predictedBallPos = ball.Position + (ballVel * Config.GKPredictionTime)
        
        local goalToBall = (predictedBallPos - goalPos)
        if goalToBall.Magnitude > 0 then
            local targetPos = goalPos + (goalToBall.Unit * math.min(goalToBall.Magnitude, Config.GKWalkDistance))
            local distToTarget = (targetPos - hrp.Position).Magnitude
            
            if distToTarget > 3 then
                hum:Move((targetPos - hrp.Position).Unit + jitter, false)
            end
        end
    end

    -- Ball Attraction
    if Config.BallAttraction and ball then
        local dist = (ball.Position - hrp.Position).Magnitude
        if dist <= Config.AttractionRadius and dist > 3 then
            local pullForce = (hrp.Position - ball.Position).Unit * GetEffectiveValue(Config.AttractionForce)
            ball.Velocity = ball.Velocity + (pullForce * dt)
        end
    end

    -- Shot Assist & Curve Physics Calculation
    if ball and enemyGoal then
        local enemyPos = enemyGoal:IsA("Model") and enemyGoal:GetPivot().Position or enemyGoal.Position
        local distToBall = (ball.Position - hrp.Position).Magnitude

        if Config.ShotAssist or Config.CombinedShot then
            if distToBall <= Config.AutoShotDistance and not Cache.AlreadyDoingAction then
                Cache.AlreadyDoingAction = true
                
                local basePower = GetEffectiveValue(Config.ShotPower)
                if Config.CombinedShot then
                    basePower = math.min(basePower * Config.CombinedMultiplier, 160) -- Dynamic upper cap
                end

                local targetDir = (enemyPos - ball.Position).Unit
                local finalVelocity = targetDir * basePower
                
                -- Curve Application (Perpendicular force vector)
                if Config.CurveEnabled then
                    local curvePower = GetEffectiveValue(Config.CurvePower)
                    local perpVector = Vector3.new(-targetDir.Z, 0, targetDir.X)
                    finalVelocity = finalVelocity + (perpVector * (curvePower * 0.3))
                end

                -- Apply calculated velocity smoothly
                ball.Velocity = finalVelocity
                
                task.delay(0.1, function()
                    Cache.AlreadyDoingAction = false
                end)
            end
        end

        -- Auto Score Guidance
        if Config.AutoScoreGuidance and ball.Velocity.Magnitude > 10 then
            local dirToGoal = (enemyPos - ball.Position).Unit
            ball.Velocity = ball.Velocity:Lerp(dirToGoal * ball.Velocity.Magnitude, dt * (Config.GuidancePower / 10))
        end
    end
end)

--------------------------------------------------------------------------------
-- 3. RenderStepped Logic (Visual Overlays & Smooth Aiming)
--------------------------------------------------------------------------------
local VisualFolder = Instance.new("Folder")
VisualFolder.Name = "LessHub_Visuals"
VisualFolder.Parent = Workspace

local TrajectoryBeam = Instance.new("Beam")
TrajectoryBeam.Width0 = 0.4
TrajectoryBeam.Width1 = 0.4
TrajectoryBeam.Color = ColorSequence.new(Color3.fromRGB(0, 170, 255))
TrajectoryBeam.Transparency = NumberSequence.new(0.2)

local Att0 = Instance.new("Attachment")
local Att1 = Instance.new("Attachment")
Att0.Parent = VisualFolder
Att1.Parent = VisualFolder
TrajectoryBeam.Attachment0 = Att0
TrajectoryBeam.Attachment1 = Att1
TrajectoryBeam.Parent = VisualFolder

RunService.RenderStepped:Connect(function(dt)
    if not Config.KeyValidated then return end
    
    local ball = GetBall()
    local enemyGoal, ownGoal = GetGoals()
    
    -- Visual: Trajectory Line Preview
    if Config.TrajectoryLine and ball and enemyGoal then
        local enemyPos = enemyGoal:IsA("Model") and enemyGoal:GetPivot().Position or enemyGoal.Position
        Att0.WorldPosition = ball.Position
        Att1.WorldPosition = enemyPos
        TrajectoryBeam.Enabled = true
    else
        TrajectoryBeam.Enabled = false
    end

    -- Visual: Ball Highlight
    if Config.BallHighlight and ball then
        local hl = ball:FindFirstChild("LessHub_BallHL")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "LessHub_BallHL"
            hl.FillColor = Color3.fromRGB(0, 255, 120)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.4
            hl.Parent = ball
        end
        hl.Enabled = true
    elseif ball and ball:FindFirstChild("LessHub_BallHL") then
        ball.LessHub_BallHL.Enabled = false
    end

    -- Visual: Player Highlight
    if Config.PlayerHighlight then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hl = plr.Character:FindFirstChild("LessHub_PlrHL")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "LessHub_PlrHL"
                    hl.FillColor = Color3.fromRGB(255, 60, 60)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.5
                    hl.Parent = plr.Character
                end
                hl.Enabled = true
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and plr.Character:FindFirstChild("LessHub_PlrHL") then
                plr.Character.LessHub_PlrHL.Enabled = false
            end
        end
    end

    -- Visual: Goal Highlight
    if Config.GoalHighlight then
        if enemyGoal then
            local hl = enemyGoal:FindFirstChild("LessHub_GoalHL")
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name = "LessHub_GoalHL"
                hl.FillColor = Color3.fromRGB(0, 170, 255)
                hl.FillTransparency = 0.6
                hl.Parent = enemyGoal
            end
            hl.Enabled = true
        end
    elseif enemyGoal and enemyGoal:FindFirstChild("LessHub_GoalHL") then
        enemyGoal.LessHub_GoalHL.Enabled = false
    end

    -- Aim Smoothing Camera Alignment
    if Config.AimSmoothing and ball then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local dist = (ball.Position - char.HumanoidRootPart.Position).Magnitude
            if dist < 20 then
                local targetCFrame = CFrame.new(Camera.CFrame.Position, ball.Position)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, dt * (Config.AimPower / 2))
            end
        end
    end
end)

print("[LessHub]: Module successfully initialized.")
