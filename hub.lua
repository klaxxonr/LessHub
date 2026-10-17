--[[
    LessHub - Illegal Soccer
    Mobil Uyumlu • Siyah-Mavi Tema • TR/EN Dil Desteği
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Dil Sistemi
local Lang = "tr"
local L = {}

local function SetLang(lang)
    Lang = lang
    if lang == "tr" then
        L = {
            Title = "LessHub",
            Movement = "Hareket",
            Auto = "Otomatik",
            Visuals = "Görsel",
            Misc = "Diğer",
            InfiniteStamina = "Sınırsız Dayanıklılık",
            AutoSprint = "Otomatik Sprint",
            NoBallSlowdown = "Top Yavaşlatma Yok",
            InfiniteJump = "Sınırsız Zıplama",
            Fly = "Uçuş",
            SpeedMultiplier = "Hız Çarpanı",
            FlySpeed = "Uçuş Hızı",
            AutoGoalkeeper = "Güçlü Otomatik Kaleci",
            AutoDive = "Otomatik Dive",
            AutoDribble = "Gelişmiş Otomatik Dribble",
            AutoTackle = "Otomatik Tackle",
            PerfectShot = "Perfect Shot",
            GoalSilentAim = "Goal Silent Aim",
            AutoVolley = "Otomatik Volley",
            BallTrajectory = "Top Yörüngesi",
            SmartAutoItem = "Akıllı Otomatik Item",
            AutoPass = "Otomatik Pas",
            CurveShot = "Curve Shot Assist",
            AutoSombrero = "Otomatik Sombrero",
            TackleAimbot = "Tackle Aimbot",
            AutoClear = "Otomatik Clear",
            PositioningAssist = "Pozisyon Asistanı",
            BallESP = "Top ESP",
            PlayerESP = "Oyuncu ESP",
            Fullbright = "Fullbright",
            Radar = "Radar",
            FPSBooster = "FPS Booster",
            AntiRagdoll = "Anti Ragdoll",
            AntiKnockback = "Anti Knockback",
            AntiAFK = "Anti-AFK",
            BanProtection = "Ban Koruması",
            Loaded = "LessHub yüklendi"
        }
    else
        L = {
            Title = "LessHub",
            Movement = "Movement",
            Auto = "Auto",
            Visuals = "Visuals",
            Misc = "Misc",
            InfiniteStamina = "Infinite Stamina",
            AutoSprint = "Auto Sprint",
            NoBallSlowdown = "No Ball Slowdown",
            InfiniteJump = "Infinite Jump",
            Fly = "Fly",
            SpeedMultiplier = "Speed Multiplier",
            FlySpeed = "Fly Speed",
            AutoGoalkeeper = "Strong Auto Goalkeeper",
            AutoDive = "Auto Dive",
            AutoDribble = "Advanced Auto Dribble",
            AutoTackle = "Auto Tackle",
            PerfectShot = "Perfect Shot",
            GoalSilentAim = "Goal Silent Aim",
            AutoVolley = "Auto Volley",
            BallTrajectory = "Ball Trajectory",
            SmartAutoItem = "Smart Auto Item",
            AutoPass = "Auto Pass",
            CurveShot = "Curve Shot Assist",
            AutoSombrero = "Auto Sombrero",
            TackleAimbot = "Tackle Aimbot",
            AutoClear = "Auto Clear",
            PositioningAssist = "Positioning Assist",
            BallESP = "Ball ESP",
            PlayerESP = "Player ESP",
            Fullbright = "Fullbright",
            Radar = "Radar",
            FPSBooster = "FPS Booster",
            AntiRagdoll = "Anti Ragdoll",
            AntiKnockback = "Anti Knockback",
            AntiAFK = "Anti-AFK",
            BanProtection = "Ban Protection",
            Loaded = "LessHub loaded"
        }
    end
end

SetLang("tr")

-- Ayarlar
local Settings = {
    InfiniteStamina = false,
    SpeedMultiplier = 1,
    AutoSprint = false,
    NoBallSlowdown = false,
    InfiniteJump = false,
    Fly = false,
    FlySpeed = 55,
    AutoGoalkeeper = false,
    AutoDive = true,
    GKPrediction = 1.25,
    GKDiveDistance = 29,
    AutoDribble = false,
    DribbleDistance = 9.8,
    DribbleSensitivity = 0.72,
    AutoTackle = false,
    TackleDistance = 11.5,
    PerfectShot = false,
    GoalSilentAim = false,
    AutoVolley = false,
    BallTrajectory = false,
    SmartAutoItem = false,
    AutoPass = false,
    CurveShot = false,
    AutoSombrero = false,
    TackleAimbot = false,
    AutoClear = false,
    PositioningAssist = false,
    BallESP = false,
    PlayerESP = false,
    Fullbright = false,
    Radar = false,
    FPSBooster = false,
    AntiRagdoll = false,
    AntiKnockback = false,
    AntiAFK = true,
    BanProtection = true,
}

-- Eski GUI temizle
if CoreGui:FindFirstChild("LessHub") then
    CoreGui.LessHub:Destroy()
end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LessHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

-- Floating Button
local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 58, 0, 58)
OpenBtn.Position = UDim2.new(0, 15, 0.45, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 255)
OpenBtn.Text = "L"
OpenBtn.TextSize = 26
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextColor3 = Color3.new(1,1,1)
OpenBtn.Parent = ScreenGui
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(1,0)
local openStroke = Instance.new("UIStroke", OpenBtn)
openStroke.Color = Color3.fromRGB(100, 200, 255)
openStroke.Thickness = 2.5

-- Ana Frame
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 360, 0, 520)
Main.Position = UDim2.new(0.5, -180, 0.5, -260)
Main.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Visible = false
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Color3.fromRGB(0, 140, 255)
mainStroke.Thickness = 2.5

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "LessHub"
Title.TextColor3 = Color3.fromRGB(0, 190, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 34, 0, 34)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -17)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 55)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.TextSize = 20
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    OpenBtn.Visible = true
end)

OpenBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    OpenBtn.Visible = false
end)

-- Tablar
local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(1, -16, 0, 34)
TabFrame.Position = UDim2.new(0, 8, 0, 50)
TabFrame.BackgroundTransparency = 1
TabFrame.Parent = Main

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.Padding = UDim.new(0, 6)
TabList.Parent = TabFrame

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -95)
Content.Position = UDim2.new(0, 8, 0, 90)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.CanvasSize = UDim2.new(0, 0, 0, 1100)
Content.Parent = Main

local ContentList = Instance.new("UIListLayout")
ContentList.Padding = UDim.new(0, 6)
ContentList.Parent = Content

local Tabs = {}
local CurrentTab = "Movement"

local function CreateTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 34, 45)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = TabFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    Tabs[name] = btn

    btn.MouseButton1Click:Connect(function()
        CurrentTab = name
        for n, b in pairs(Tabs) do
            b.BackgroundColor3 = (n == name) and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(30, 34, 45)
            b.TextColor3 = (n == name) and Color3.new(1,1,1) or Color3.fromRGB(180, 180, 180)
        end
        for _, child in pairs(Content:GetChildren()) do
            if child:IsA("Frame") then
                child.Visible = child:GetAttribute("Tab") == name
            end
        end
    end)
end

CreateTab("Hareket")
CreateTab("Otomatik")
CreateTab("Görsel")
CreateTab("Diğer")
Tabs["Hareket"].BackgroundColor3 = Color3.fromRGB(0, 140, 255)
Tabs["Hareket"].TextColor3 = Color3.new(1,1,1)

-- Toggle Oluşturucu
local function CreateToggle(tabName, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
    frame.BorderSizePixel = 0
    frame:SetAttribute("Tab", tabName)
    frame.Visible = (tabName == "Hareket")
    frame.Parent = Content
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 54, 0, 26)
    btn.Position = UDim2.new(1, -66, 0.5, -13)
    btn.BackgroundColor3 = default and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(55, 60, 75)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(55, 60, 75)
        callback(state)
    end)
end

-- Slider Oluşturucu
local function CreateSlider(tabName, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 56)
    frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
    frame.BorderSizePixel = 0
    frame:SetAttribute("Tab", tabName)
    frame.Visible = (tabName == "Hareket")
    frame.Parent = Content
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 0, 22)
    label.Position = UDim2.new(0, 12, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. string.format("%.2f", default)
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 10)
    bar.Position = UDim2.new(0, 12, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            local value = min + (max - min) * pos
            label.Text = text .. ": " .. string.format("%.2f", value)
            callback(value)
        end
    end)
end

-- ==================== ÖZELLİKLERİ OLUŞTUR ====================

-- Hareket Sekmesi
CreateToggle("Hareket", L.InfiniteStamina, false, function(v) Settings.InfiniteStamina = v end)
CreateToggle("Hareket", L.AutoSprint, false, function(v) Settings.AutoSprint = v end)
CreateToggle("Hareket", L.NoBallSlowdown, false, function(v) Settings.NoBallSlowdown = v end)
CreateToggle("Hareket", L.InfiniteJump, false, function(v) Settings.InfiniteJump = v end)
CreateToggle("Hareket", L.Fly, false, function(v) Settings.Fly = v end)
CreateSlider("Hareket", L.SpeedMultiplier, 1, 2.8, 1, function(v) Settings.SpeedMultiplier = v end)
CreateSlider("Hareket", L.FlySpeed, 25, 140, 55, function(v) Settings.FlySpeed = v end)

-- Otomatik Sekmesi
CreateToggle("Otomatik", L.AutoGoalkeeper, false, function(v) Settings.AutoGoalkeeper = v end)
CreateToggle("Otomatik", L.AutoDive, true, function(v) Settings.AutoDive = v end)
CreateToggle("Otomatik", L.AutoDribble, false, function(v) Settings.AutoDribble = v end)
CreateToggle("Otomatik", L.AutoTackle, false, function(v) Settings.AutoTackle = v end)
CreateToggle("Otomatik", L.PerfectShot, false, function(v) Settings.PerfectShot = v end)
CreateToggle("Otomatik", L.GoalSilentAim, false, function(v) Settings.GoalSilentAim = v end)
CreateToggle("Otomatik", L.AutoVolley, false, function(v) Settings.AutoVolley = v end)
CreateToggle("Otomatik", L.AutoPass, false, function(v) Settings.AutoPass = v end)
CreateToggle("Otomatik", L.CurveShot, false, function(v) Settings.CurveShot = v end)
CreateToggle("Otomatik", L.AutoSombrero, false, function(v) Settings.AutoSombrero = v end)
CreateToggle("Otomatik", L.TackleAimbot, false, function(v) Settings.TackleAimbot = v end)
CreateToggle("Otomatik", L.AutoClear, false, function(v) Settings.AutoClear = v end)
CreateToggle("Otomatik", L.PositioningAssist, false, function(v) Settings.PositioningAssist = v end)
CreateToggle("Otomatik", L.SmartAutoItem, false, function(v) Settings.SmartAutoItem = v end)

-- Görsel Sekmesi
CreateToggle("Görsel", L.BallESP, false, function(v) Settings.BallESP = v end)
CreateToggle("Görsel", L.PlayerESP, false, function(v) Settings.PlayerESP = v end)
CreateToggle("Görsel", L.Fullbright, false, function(v)
    Settings.Fullbright = v
    if v then
        Lighting.Brightness = 2.2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = 1
        Lighting.FogEnd = 1000
        Lighting.GlobalShadows = true
    end
end)
CreateToggle("Görsel", L.BallTrajectory, false, function(v) Settings.BallTrajectory = v end)
CreateToggle("Görsel", L.Radar, false, function(v) Settings.Radar = v end)
CreateToggle("Görsel", L.FPSBooster, false, function(v)
    Settings.FPSBooster = v
    if v then
        settings().Rendering.QualityLevel = 1
    end
end)

-- Diğer Sekmesi
CreateToggle("Diğer", L.AntiRagdoll, false, function(v) Settings.AntiRagdoll = v end)
CreateToggle("Diğer", L.AntiKnockback, false, function(v) Settings.AntiKnockback = v end)
CreateToggle("Diğer", L.AntiAFK, true, function(v) Settings.AntiAFK = v end)
CreateToggle("Diğer", L.BanProtection, true, function(v) Settings.BanProtection = v end)

-- Karakter
local Character, Humanoid, RootPart
local function UpdateChar()
    Character = LocalPlayer.Character
    if Character then
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        RootPart = Character:FindFirstChild("HumanoidRootPart")
    end
end
UpdateChar()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    UpdateChar()
end)

-- Basit özellik loop'u (temel olanlar)
RunService.Heartbeat:Connect(function()
    if not Humanoid or not RootPart then return end

    if Settings.SpeedMultiplier > 1 or Settings.AutoSprint then
        Humanoid.WalkSpeed = 16 * math.max(Settings.SpeedMultiplier, Settings.AutoSprint and 1.35 or 1)
    end

    if Settings.InfiniteStamina then
        pcall(function()
            for _, v in pairs(Character:GetDescendants()) do
                if v:IsA("NumberValue") and v.Name:lower():find("stamina") then
                    v.Value = 100
                end
            end
        end)
    end

    if Settings.AntiRagdoll then
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end
end)

print("LessHub başarıyla yüklendi!")