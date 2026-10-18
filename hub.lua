--[[
    Illegal Soccer | Premium Script (Delta Executor / Mobile)
    Özellikler:
    - Auto Goal (otomatik gol)
    - Auto Dribble (otomatik top sürme)
    - Infinite Stamina (sınırsız dayanıklılık)
    - Godmode (ölümsüzlük)
    - Speed Hack / Jump Power
    - Teleport to Ball / Goal
    - ESP (oyuncu ve top görselleştirme)
    - Auto Shoot
    - Rejoin Server
    - ve daha fazlası...
--]]

-- ============================================================
-- 1. UI KÜTÜPHANESİ (Rayfield)
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Illegal Soccer | Premium",
   LoadingTitle = "Illegal Soccer Premium",
   LoadingSubtitle = "by AI",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "IllegalSoccer",
      FileName = "PremiumConfig"
   },
   KeySystem = false
})

-- ============================================================
-- 2. YARDIMCI FONKSİYONLAR
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getChar()
    return char:FindFirstChildOfClass("Humanoid")
end

-- Topu bulma fonksiyonu (oyuna göre isim değişebilir)
local function getBall()
    return Workspace:FindFirstChild("Ball") 
        or Workspace:FindFirstChild("SoccerBall") 
        or Workspace:FindFirstChild("Football")
end

-- Kaleyi bulma fonksiyonu (oyuna göre isim değişebilir)
local function getGoal()
    return Workspace:FindFirstChild("Goal") 
        or Workspace:FindFirstChild("GoalPost") 
        or Workspace:FindFirstChild("Net")
end

-- ============================================================
-- 3. DEĞİŞKENLER
-- ============================================================
local settings = {
    autoGoal = false,
    autoDribble = false,
    infiniteStamina = false,
    godmode = false,
    speedHack = false,
    speedValue = 50,
    jumpPower = false,
    jumpValue = 100,
    espPlayers = false,
    espBall = false,
    autoShoot = false
}

-- ============================================================
-- 4. ANA SEKMELER
-- ============================================================
local MainTab = Window:CreateTab("Ana", 4483362458)
local PlayerTab = Window:CreateTab("Oyuncu", 4483362458)
local BallTab = Window:CreateTab("Top", 4483362458)
local VisualTab = Window:CreateTab("Görsel", 4483362458)
local MiscTab = Window:CreateTab("Diğer", 4483362458)

-- ============================================================
-- 5. ANA SEKME (Auto Goal, Auto Dribble, Infinite Stamina)
-- ============================================================
MainTab:CreateSection("Otomasyon")

MainTab:CreateToggle({
    Name = "Auto Goal",
    CurrentValue = false,
    Flag = "AutoGoal",
    Callback = function(value)
        settings.autoGoal = value
    end
})

MainTab:CreateToggle({
    Name = "Auto Dribble",
    CurrentValue = false,
    Flag = "AutoDribble",
    Callback = function(value)
        settings.autoDribble = value
    end
})

MainTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Flag = "InfStamina",
    Callback = function(value)
        settings.infiniteStamina = value
    end
})

-- ============================================================
-- 6. OYUNCU SEKME (Godmode, Speed, Jump)
-- ============================================================
PlayerTab:CreateSection("Hayatta Kalma")

PlayerTab:CreateToggle({
    Name = "Godmode (Ölümsüzlük)",
    CurrentValue = false,
    Flag = "Godmode",
    Callback = function(value)
        settings.godmode = value
        if value then
            local hum = getHumanoid()
            if hum then hum.Health = math.huge end
        end
    end
})

PlayerTab:CreateSection("Hareket")

PlayerTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Flag = "SpeedHack",
    Callback = function(value)
        settings.speedHack = value
        if not value then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = 16 end
        end
    end
})

PlayerTab:CreateSlider({
    Name = "Hız Değeri",
    Range = {16, 200},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 50,
    Flag = "SpeedValue",
    Callback = function(value)
        settings.speedValue = value
        if settings.speedHack then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = value end
        end
    end
})

PlayerTab:CreateToggle({
    Name = "Jump Power Hack",
    CurrentValue = false,
    Flag = "JumpHack",
    Callback = function(value)
        settings.jumpPower = value
        if not value then
            local hum = getHumanoid()
            if hum then hum.JumpPower = 50 end
        end
    end
})

PlayerTab:CreateSlider({
    Name = "Zıplama Gücü",
    Range = {50, 500},
    Increment = 10,
    Suffix = "Power",
    CurrentValue = 100,
    Flag = "JumpValue",
    Callback = function(value)
        settings.jumpValue = value
        if settings.jumpPower then
            local hum = getHumanoid()
            if hum then hum.JumpPower = value end
        end
    end
})

-- ============================================================
-- 7. TOP SEKMESİ (Teleport, Auto Shoot)
-- ============================================================
BallTab:CreateSection("Top Kontrolü")

BallTab:CreateButton({
    Name = "Topa Işınlan",
    Callback = function()
        local ball = getBall()
        local char = getChar()
        if ball and char and char.PrimaryPart then
            char:SetPrimaryPartCFrame(ball.CFrame + Vector3.new(0, 5, 0))
        end
    end
})

BallTab:CreateToggle({
    Name = "Auto Shoot (Otomatik Şut)",
    CurrentValue = false,
    Flag = "AutoShoot",
    Callback = function(value)
        settings.autoShoot = value
    end
})

-- ============================================================
-- 8. GÖRSEL SEKME (ESP)
-- ============================================================
VisualTab:CreateSection("ESP")

VisualTab:CreateToggle({
    Name = "Oyuncuları Göster (ESP)",
    CurrentValue = false,
    Flag = "ESPPlayers",
    Callback = function(value)
        settings.espPlayers = value
    end
})

VisualTab:CreateToggle({
    Name = "Topu Göster (ESP)",
    CurrentValue = false,
    Flag = "ESPBall",
    Callback = function(value)
        settings.espBall = value
    end
})

-- ============================================================
-- 9. DİĞER SEKME (Teleport, Rejoin)
-- ============================================================
MiscTab:CreateSection("Işınlanma")

MiscTab:CreateButton({
    Name = "Kaleye Işınlan",
    Callback = function()
        local goal = getGoal()
        local char = getChar()
        if goal and char and char.PrimaryPart then
            char:SetPrimaryPartCFrame(goal.CFrame + Vector3.new(0, 5, 0))
        end
    end
})

MiscTab:CreateSection("Sunucu")

MiscTab:CreateButton({
    Name = "Sunucudan Ayrıl",
    Callback = function()
        LocalPlayer:Kick("Script aracılığıyla ayrıldınız.")
    end
})

-- ============================================================
-- 10. DÖNGÜLER (Ana mantık)
-- ============================================================

-- Godmode döngüsü
RunService.Heartbeat:Connect(function()
    if settings.godmode then
        local hum = getHumanoid()
        if hum then
            hum.Health = math.huge
        end
    end
end)

-- Speed Hack döngüsü
RunService.Heartbeat:Connect(function()
    if settings.speedHack then
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = settings.speedValue
        end
    end
end)

-- Jump Power döngüsü
RunService.Heartbeat:Connect(function()
    if settings.jumpPower then
        local hum = getHumanoid()
        if hum then
            hum.JumpPower = settings.jumpValue
        end
    end
end)

-- Infinite Stamina döngüsü (oyuna özgü)
RunService.Heartbeat:Connect(function()
    if settings.infiniteStamina then
        local char = getChar()
        if char then
            -- Yaygın stamina isimleri: "Stamina", "Energy", "StaminaValue"
            for _, obj in ipairs(char:GetDescendants()) do
                if obj.Name:lower():find("stamina") or obj.Name:lower():find("energy") then
                    if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                        obj.Value = 9999
                    end
                end
            end
            -- Oyuncu özelliklerinde de olabilir
            for _, obj in ipairs(LocalPlayer:GetDescendants()) do
                if obj.Name:lower():find("stamina") or obj.Name:lower():find("energy") then
                    if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                        obj.Value = 9999
                    end
                end
            end
        end
    end
end)

-- Auto Goal döngüsü (basit yaklaşım)
RunService.Heartbeat:Connect(function()
    if settings.autoGoal then
        local ball = getBall()
        local goal = getGoal()
        local char = getChar()
        if ball and goal and char and char.PrimaryPart then
            -- Topu kaleye doğru yönlendir
            local direction = (goal.Position - ball.Position).Unit
            ball.AssemblyLinearVelocity = direction * 150
        end
    end
end)

-- Auto Dribble döngüsü (topu oyuncunun önünde tutma)
RunService.Heartbeat:Connect(function()
    if settings.autoDribble then
        local ball = getBall()
        local char = getChar()
        if ball and char and char.PrimaryPart then
            local hrp = char.PrimaryPart
            local targetPos = hrp.CFrame * CFrame.new(0, 0, -3) -- karakterin 3 birim önü
            ball.CFrame = CFrame.new(targetPos.Position)
        end
    end
end)

-- Auto Shoot (topa yakınken otomatik şut)
RunService.Heartbeat:Connect(function()
    if settings.autoShoot then
        local ball = getBall()
        local char = getChar()
        local goal = getGoal()
        if ball and char and char.PrimaryPart and goal then
            local dist = (ball.Position - char.PrimaryPart.Position).Magnitude
            if dist < 10 then
                local direction = (goal.Position - ball.Position).Unit
                ball.AssemblyLinearVelocity = direction * 200
            end
        end
    end
end)

-- ============================================================
-- 11. ESP (Görselleştirme)
-- ============================================================
local espObjects = {}

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
    label.Parent = billboard

    espObjects[object] = billboard
end

local function removeAllESP()
    for obj, gui in pairs(espObjects) do
        if gui then gui:Destroy() end
    end
    espObjects = {}
end

-- Oyuncu ESP döngüsü
RunService.Heartbeat:Connect(function()
    if settings.espPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root and not espObjects[root] then
                    createESP(root, Color3.new(1, 0, 0), player.Name)
                end
            end
        end
    else
        -- Sadece oyuncu ESP'lerini kaldır (top ESP'sini koru)
        for obj, gui in pairs(espObjects) do
            if obj.Parent and obj.Parent:IsA("Model") and obj.Parent:FindFirstChildOfClass("Humanoid") then
                gui:Destroy()
                espObjects[obj] = nil
            end
        end
    end
end)

-- Top ESP döngüsü
RunService.Heartbeat:Connect(function()
    local ball = getBall()
    if settings.espBall and ball then
        if not espObjects[ball] then
            createESP(ball, Color3.new(0, 1, 0), "TOP")
        end
    elseif not settings.espBall then
        if ball and espObjects[ball] then
            espObjects[ball]:Destroy()
            espObjects[ball] = nil
        end
    end
end)

-- ============================================================
-- 12. TEMİZLİK (Script durdurulursa)
-- ============================================================
LocalPlayer.CharacterRemoving:Connect(function()
    removeAllESP()
end)

-- UI kapanınca temizlik
Rayfield:Notify({
    Title = "Script Yüklendi",
    Content = "Illegal Soccer Premium aktif!",
    Duration = 5,
    Image = 4483362458
})