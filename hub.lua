--[[
    ⚽ ILLEGAL SOCCER | ULTIMATE PREMIUM SCRIPT ⚽
    Executor: Delta (Mobile) / Xeno / Solara
    Features: Auto Goal, Auto Dribble, Auto Shoot, Auto Tackle, Auto GK,
              Infinite Stamina, Godmode, Speed/Jump, ESP, Teleport,
              Auto Weapon, Anti-AFK, Server Hop, ve daha fazlası...
    Version: 3.0 (Fixed UI & Dynamic Object Detection)
--]]

-- ============================================================
-- 0. GÜVENLİK VE SERVİSLER
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- 1. YARDIMCI FONKSİYONLAR (Dinamik Nesne Bulma)
-- ============================================================
local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = getChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Gelişmiş top bulucu (isim değişikliklerine karşı dayanıklı)
local function findBall()
    local ballNames = {"ball", "soccerball", "football", "soccer", "top"}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local lowerName = obj.Name:lower()
            for _, pattern in ipairs(ballNames) do
                if lowerName:find(pattern) then
                    return obj
                end
            end
        end
    end
    return nil
end

-- Gelişmiş kale bulucu
local function findGoal()
    local goalNames = {"goal", "net", "goalpost", "kale"}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local lowerName = obj.Name:lower()
            for _, pattern in ipairs(goalNames) do
                if lowerName:find(pattern) then
                    return obj
                end
            end
        end
    end
    return nil
end

-- Stamina değerlerini bulma
local function getStaminaObjects()
    local staminaObjs = {}
    local char = getChar()
    if not char then return staminaObjs end
    for _, obj in ipairs(char:GetDescendants()) do
        if (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
            local name = obj.Name:lower()
            if name:find("stamina") or name:find("energy") or name:find("endurance") then
                table.insert(staminaObjs, obj)
            end
        end
    end
    return staminaObjs
end

-- ============================================================
-- 2. UI KÜTÜPHANESİ (Rayfield - Mobil Görünürlük Düzeltildi)
-- ============================================================
local Rayfield
local success, err = pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    -- Yedek UI (Fluent) yüklemeyi dene
    local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

    local Window = Fluent:CreateWindow({
        Title = "Illegal Soccer | Ultimate",
        SubTitle = "Premium Script (Fallback UI)",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.K
    })

    -- Fluent ile devam etmek için basit bir sarmalayıcı
    -- (Bu kısım, Rayfield başarısız olursa devreye girer)
    Rayfield = {
        CreateWindow = function() return Window end,
        Notify = function(self, args)
            Fluent:Notify({
                Title = args.Title or "Bildirim",
                Content = args.Content or "",
                Duration = args.Duration or 5
            })
        end
    }
end

-- Rayfield penceresini oluştur (ShowText mobilde görünürlüğü sağlar)
local Window
if Rayfield.CreateWindow then
    Window = Rayfield:CreateWindow({
        Name = "⚽ Illegal Soccer | Ultimate Premium",
        LoadingTitle = "Illegal Soccer Ultimate",
        LoadingSubtitle = "Mobil Uyumlu · v3.0",
        ShowText = "Rayfield", -- Mobilde UI'nin görünmesini sağlar
        ToggleUIKeybind = "K", -- K tuşu ile aç/kapat
        ConfigurationSaving = {
            Enabled = false, -- Mobilde çakışmayı önlemek için kapalı
        },
        KeySystem = false
    })
else
    -- Fluent fallback için pencere zaten oluşturuldu
    Window = Rayfield.CreateWindow()
end

-- ============================================================
-- 3. AYARLAR
-- ============================================================
local Settings = {
    -- Otomasyon
    AutoGoal = false,
    AutoDribble = false,
    AutoShoot = false,
    AutoTackle = false,
    AutoGoalkeeper = false,
    AutoWeapon = false,

    -- Hayatta Kalma
    Godmode = false,
    InfiniteStamina = false,
    AntiAFK = true,

    -- Hareket
    SpeedHack = false,
    SpeedValue = 50,
    JumpHack = false,
    JumpValue = 100,

    -- Görsel
    ESPPlayers = false,
    ESPBall = false,
    ESPGoal = false,

    -- Teleport
    TeleportToBall = false,
    TeleportToGoal = false
}

-- ============================================================
-- 4. SEKMELER
-- ============================================================
local Tabs = {
    Main = Window:CreateTab("Ana", 4483362458),
    Player = Window:CreateTab("Oyuncu", 4483362458),
    Ball = Window:CreateTab("Top & Gol", 4483362458),
    Visual = Window:CreateTab("Görsel", 4483362458),
    Misc = Window:CreateTab("Diğer", 4483362458)
}

-- ============================================================
-- 5. ANA SEKME (Otomasyon)
-- ============================================================
Tabs.Main:CreateSection("Otomasyon (Sunucu Tarafı)")

Tabs.Main:CreateToggle({
    Name = "Auto Goal (Otomatik Gol)",
    CurrentValue = false,
    Flag = "AutoGoal",
    Callback = function(value) Settings.AutoGoal = value end
})

Tabs.Main:CreateToggle({
    Name = "Auto Dribble (Otomatik Top Sürme)",
    CurrentValue = false,
    Flag = "AutoDribble",
    Callback = function(value) Settings.AutoDribble = value end
})

Tabs.Main:CreateToggle({
    Name = "Auto Shoot (Otomatik Şut)",
    CurrentValue = false,
    Flag = "AutoShoot",
    Callback = function(value) Settings.AutoShoot = value end
})

Tabs.Main:CreateToggle({
    Name = "Auto Tackle (Otomatik Müdahale)",
    CurrentValue = false,
    Flag = "AutoTackle",
    Callback = function(value) Settings.AutoTackle = value end
})

Tabs.Main:CreateToggle({
    Name = "Auto Goalkeeper (Otomatik Kaleci)",
    CurrentValue = false,
    Flag = "AutoGK",
    Callback = function(value) Settings.AutoGoalkeeper = value end
})

Tabs.Main:CreateToggle({
    Name = "Auto Weapon (Otomatik Silah)",
    CurrentValue = false,
    Flag = "AutoWeapon",
    Callback = function(value) Settings.AutoWeapon = value end
})

-- ============================================================
-- 6. OYUNCU SEKME (Hayatta Kalma & Hareket)
-- ============================================================
Tabs.Player:CreateSection("Hayatta Kalma")

Tabs.Player:CreateToggle({
    Name = "Godmode (Ölümsüzlük)",
    CurrentValue = false,
    Flag = "Godmode",
    Callback = function(value) Settings.Godmode = value end
})

Tabs.Player:CreateToggle({
    Name = "Infinite Stamina (Sonsuz Dayanıklılık)",
    CurrentValue = false,
    Flag = "InfStamina",
    Callback = function(value) Settings.InfiniteStamina = value end
})

Tabs.Player:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Flag = "AntiAFK",
    Callback = function(value) Settings.AntiAFK = value end
})

Tabs.Player:CreateSection("Hareket")

Tabs.Player:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Flag = "SpeedHack",
    Callback = function(value)
        Settings.SpeedHack = value
        if not value then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = 16 end
        end
    end
})

Tabs.Player:CreateSlider({
    Name = "Hız Değeri",
    Range = {16, 200},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 50,
    Flag = "SpeedValue",
    Callback = function(value)
        Settings.SpeedValue = value
        if Settings.SpeedHack then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = value end
        end
    end
})

Tabs.Player:CreateToggle({
    Name = "Jump Power Hack",
    CurrentValue = false,
    Flag = "JumpHack",
    Callback = function(value)
        Settings.JumpHack = value
        if not value then
            local hum = getHumanoid()
            if hum then hum.JumpPower = 50 end
        end
    end
})

Tabs.Player:CreateSlider({
    Name = "Zıplama Gücü",
    Range = {50, 500},
    Increment = 10,
    Suffix = "Power",
    CurrentValue = 100,
    Flag = "JumpValue",
    Callback = function(value)
        Settings.JumpValue = value
        if Settings.JumpHack then
            local hum = getHumanoid()
            if hum then hum.JumpPower = value end
        end
    end
})

-- ============================================================
-- 7. TOP & GOL SEKME (Teleport)
-- ============================================================
Tabs.Ball:CreateSection("Işınlanma")

Tabs.Ball:CreateButton({
    Name = "Topa Işınlan",
    Callback = function()
        local ball = findBall()
        local root = getRoot()
        if ball and root then
            root.CFrame = ball.CFrame + Vector3.new(0, 5, 0)
        end
    end
})

Tabs.Ball:CreateButton({
    Name = "Kaleye Işınlan",
    Callback = function()
        local goal = findGoal()
        local root = getRoot()
        if goal and root then
            root.CFrame = goal.CFrame + Vector3.new(0, 5, 0)
        end
    end
})

Tabs.Ball:CreateButton({
    Name = "Topu Kaleye Fırlat",
    Callback = function()
        local ball = findBall()
        local goal = findGoal()
        if ball and goal then
            local direction = (goal.Position - ball.Position).Unit
            ball.AssemblyLinearVelocity = direction * 250
        end
    end
})

-- ============================================================
-- 8. GÖRSEL SEKME (ESP)
-- ============================================================
Tabs.Visual:CreateSection("ESP (Görselleştirme)")

Tabs.Visual:CreateToggle({
    Name = "Oyuncuları Göster (ESP)",
    CurrentValue = false,
    Flag = "ESPPlayers",
    Callback = function(value) Settings.ESPPlayers = value end
})

Tabs.Visual:CreateToggle({
    Name = "Topu Göster (ESP)",
    CurrentValue = false,
    Flag = "ESPBall",
    Callback = function(value) Settings.ESPBall = value end
})

Tabs.Visual:CreateToggle({
    Name = "Kaleyi Göster (ESP)",
    CurrentValue = false,
    Flag = "ESPGoal",
    Callback = function(value) Settings.ESPGoal = value end
})

-- ============================================================
-- 9. DİĞER SEKME (Sunucu İşlemleri)
-- ============================================================
Tabs.Misc:CreateSection("Sunucu")

Tabs.Misc:CreateButton({
    Name = "Sunucudan Ayrıl",
    Callback = function()
        LocalPlayer:Kick("Script aracılığıyla ayrıldınız.")
    end
})

Tabs.Misc:CreateButton({
    Name = "Yeniden Bağlan (Rejoin)",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
})

-- ============================================================
-- 10. ESP SİSTEMİ
-- ============================================================
local ESPObjects = {}

local function createESP(object, color, text)
    if not object or not object:IsA("BasePart") then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. object.Name
    billboard.Adornee = object
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = object

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text or object.Name
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.TextScaled = true
    label.Parent = billboard

    ESPObjects[object] = billboard
end

local function removeESP(object)
    if ESPObjects[object] then
        ESPObjects[object]:Destroy()
        ESPObjects[object] = nil
    end
end

local function clearAllESP()
    for obj, gui in pairs(ESPObjects) do
        if gui then gui:Destroy() end
    end
    ESPObjects = {}
end

-- ============================================================
-- 11. ANA DÖNGÜLER (Heartbeat)
-- ============================================================

-- Godmode Döngüsü
RunService.Heartbeat:Connect(function()
    if Settings.Godmode then
        local hum = getHumanoid()
        if hum then
            hum.Health = math.huge
            hum.MaxHealth = math.huge
        end
    end
end)

-- Speed Hack Döngüsü
RunService.Heartbeat:Connect(function()
    if Settings.SpeedHack then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = Settings.SpeedValue end
    end
end)

-- Jump Hack Döngüsü
RunService.Heartbeat:Connect(function()
    if Settings.JumpHack then
        local hum = getHumanoid()
        if hum then hum.JumpPower = Settings.JumpValue end
    end
end)

-- Infinite Stamina Döngüsü
RunService.Heartbeat:Connect(function()
    if Settings.InfiniteStamina then
        local staminaObjs = getStaminaObjects()
        for _, obj in ipairs(staminaObjs) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                obj.Value = 9999
            end
        end
    end
end)

-- Auto Goal Döngüsü (Topu kaleye yönlendir)
RunService.Heartbeat:Connect(function()
    if Settings.AutoGoal then
        local ball = findBall()
        local goal = findGoal()
        if ball and goal then
            local direction = (goal.Position - ball.Position).Unit
            ball.AssemblyLinearVelocity = direction * 200
        end
    end
end)

-- Auto Dribble Döngüsü (Topu karakterin önünde tut)
RunService.Heartbeat:Connect(function()
    if Settings.AutoDribble then
        local ball = findBall()
        local root = getRoot()
        if ball and root then
            local targetPos = root.CFrame * CFrame.new(0, 0, -3)
            ball.CFrame = CFrame.new(targetPos.Position)
        end
    end
end)

-- Auto Shoot Döngüsü (Topa yakınken otomatik şut)
RunService.Heartbeat:Connect(function()
    if Settings.AutoShoot then
        local ball = findBall()
        local root = getRoot()
        local goal = findGoal()
        if ball and root and goal then
            local dist = (ball.Position - root.Position).Magnitude
            if dist < 12 then
                local direction = (goal.Position - ball.Position).Unit
                ball.AssemblyLinearVelocity = direction * 250
            end
        end
    end
end)

-- Auto Tackle Döngüsü (Yakındaki rakiplere müdahale)
RunService.Heartbeat:Connect(function()
    if Settings.AutoTackle then
        local root = getRoot()
        if not root then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
                if enemyRoot and (enemyRoot.Position - root.Position).Magnitude < 8 then
                    -- Tackle animasyonunu tetikle (varsa)
                    local tackleEvent = game:GetService("ReplicatedStorage"):FindFirstChild("TackleEvent")
                    if tackleEvent and tackleEvent:IsA("RemoteEvent") then
                        tackleEvent:FireServer(enemyRoot)
                    end
                end
            end
        end
    end
end)

-- Auto Goalkeeper Döngüsü (Kaleyi koru)
RunService.Heartbeat:Connect(function()
    if Settings.AutoGoalkeeper then
        local ball = findBall()
        local goal = findGoal()
        local root = getRoot()
        if ball and goal and root then
            -- Kalenin önünde pozisyon al
            local goalPos = goal.Position
            local ballPos = ball.Position
            local targetPos = goalPos + (goalPos - ballPos).Unit * 5
            targetPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
            root.CFrame = CFrame.new(targetPos, ballPos)
        end
    end
end)

-- Auto Weapon Döngüsü (Silah varsa otomatik ateş et)
RunService.Heartbeat:Connect(function()
    if Settings.AutoWeapon then
        local char = getChar()
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            -- Silahın ateş etme özelliği varsa aktive et
            local fireEvent = tool:FindFirstChild("Fire")
            if fireEvent and fireEvent:IsA("RemoteEvent") then
                -- Yakındaki düşmana doğru ateş et
                local root = getRoot()
                if root then
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character then
                            local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
                            if enemyRoot and (enemyRoot.Position - root.Position).Magnitude < 100 then
                                fireEvent:FireServer(enemyRoot.Position)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Anti-AFK Döngüsü
RunService.Heartbeat:Connect(function()
    if Settings.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- ============================================================
-- 12. ESP DÖNGÜLERİ
-- ============================================================

-- Oyuncu ESP
RunService.Heartbeat:Connect(function()
    if Settings.ESPPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root and not ESPObjects[root] then
                    createESP(root, Color3.new(1, 0, 0), player.Name)
                end
            end
        end
    else
        -- Sadece oyuncu ESP'lerini kaldır
        for obj, gui in pairs(ESPObjects) do
            if obj and obj.Parent and obj.Parent:FindFirstChildOfClass("Humanoid") then
                gui:Destroy()
                ESPObjects[obj] = nil
            end
        end
    end
end)

-- Top ESP
RunService.Heartbeat:Connect(function()
    local ball = findBall()
    if Settings.ESPBall and ball then
        if not ESPObjects[ball] then
            createESP(ball, Color3.new(0, 1, 0), "⚽ TOP")
        end
    elseif ball and ESPObjects[ball] then
        removeESP(ball)
    end
end)

-- Kale ESP
RunService.Heartbeat:Connect(function()
    local goal = findGoal()
    if Settings.ESPGoal and goal then
        if not ESPObjects[goal] then
            createESP(goal, Color3.new(0, 0, 1), "🥅 KALE")
        end
    elseif goal and ESPObjects[goal] then
        removeESP(goal)
    end
end)

-- ============================================================
-- 13. TEMİZLİK VE BİLDİRİMLER
-- ============================================================
LocalPlayer.CharacterRemoving:Connect(function()
    clearAllESP()
end)

Rayfield:Notify({
    Title = "⚽ Illegal Soccer Ultimate",
    Content = "Script başarıyla yüklendi! UI'yi K tuşuyla açıp kapatabilirsin.",
    Duration = 8,
    Image = 4483362458
})