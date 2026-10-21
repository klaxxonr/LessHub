--[[
  Illegal Soccer | Auto Dribble + Auto Curve (v3 - Kontrol Sende)
  Delta Executor (Mobil)
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CFG = {
    ApproachRange  = 14,      -- bu mesafeden uzaksa script topa koşar
    ChaseSpeed     = 32,      -- sadece chase sırasında
    VelocityAssist = true,
    VA_PullPower   = 5,
    VA_Range       = 5,
    ShootRange     = 30,
    ShotCooldown   = 1.4,
    ShotPower      = 105,
    CurvePower     = 60,
    PredictTime    = 0.12,
}

local DribbleOn = true
local CurveOn   = true

-- === TOP BULMA ===
local ballCache
local function isBallPart(o)
    if not o:IsA("BasePart") then return false end
    local n = o.Name:lower()
    return n:find("ball") or n:find("soccer") or n:find("football") or n:find("top")
end
local function findBall()
    if ballCache and ballCache.Parent and isBallPart(ballCache) then return ballCache end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if isBallPart(o) then ballCache = o return o end
    end
    return nil
end

local function getAttackDir()
    local look = Camera.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then return Vector3.new(0, 0, -1) end
    return flat.Unit
end

local function curveShot(ball, dir, curve)
    if not ball then return end
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.01 then return end
    dir = dir.Unit
    local side = dir:Cross(Vector3.new(0, 1, 0))
    if side.Magnitude < 0.01 then side = Vector3.new(1, 0, 0) end
    side = side.Unit
    local v = dir * CFG.ShotPower + side * curve
    v = Vector3.new(v.X, math.min(v.Y, 25), v.Z)
    ball.AssemblyLinearVelocity = v
end

-- === ANA DÖNGÜ ===
local lastShoot = 0
local baseSpeed = nil   -- orijinal WalkSpeed'i hatırla
local isChasing = false

RunService.Heartbeat:Connect(function(dt)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then
        baseSpeed = nil
        isChasing = false
        return
    end

    -- Base speed'i yakala (oyun set ettikten sonra)
    if not baseSpeed or baseSpeed <= 0 then
        baseSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or 16
    end

    local ball = findBall()
    if not ball then return end

    local attack   = getAttackDir()
    local ballPred = ball.Position + ball.AssemblyLinearVelocity * CFG.PredictTime
    local ballFlat = Vector3.new(ballPred.X, root.Position.Y, ballPred.Z)
    local toBall   = ballFlat - root.Position
    local dist     = toBall.Magnitude

    -- === AUTO DRIBBLE (sadece top UZAKKEN) ===
    if DribbleOn and dist > CFG.ApproachRange then
        isChasing = true
        if hum.WalkSpeed ~= CFG.ChaseSpeed then hum.WalkSpeed = CFG.ChaseSpeed end
        local dir = Vector3.new(toBall.X, 0, toBall.Z)
        if dir.Magnitude > 0.1 then
            hum:Move(dir.Unit, false)
        end
    else
        -- Yakınız veya dribble kapalı → KONTROL SENDE
        -- Move() ÇAĞIRMIYORUZ, sadece WalkSpeed'i eski değerine döndür
        if isChasing then
            isChasing = false
            if baseSpeed and hum.WalkSpeed ~= baseSpeed then
                hum.WalkSpeed = baseSpeed
            end
        end
    end

    -- === VELOCITY ASSIST (top ayağında kalsın) ===
    if CFG.VelocityAssist and DribbleOn and dist < CFG.VA_Range then
        local pull = root.Position + attack * 1.5 - ball.Position
        pull = Vector3.new(pull.X, 0, pull.Z)
        ball.AssemblyLinearVelocity = ball.AssemblyLinearVelocity + pull * CFG.VA_PullPower * dt
    end

    -- === AUTO CURVE SHOT ===
    if CurveOn then
        local facing = dist > 0.1 and toBall.Unit:Dot(attack) or 0
        if dist < CFG.ShootRange and facing > 0.35 and (tick() - lastShoot) > CFG.ShotCooldown then
            curveShot(ball, attack, CFG.CurvePower)
            lastShoot = tick()
        end
    end
end)

-- Karakter değişince baseSpeed sıfırla
LP.CharacterAdded:Connect(function() baseSpeed = nil; isChasing = false end)

-- === GUI ===
local gui = Instance.new("ScreenGui")
gui.Name = "SoccerHelperV3"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local function makeToggle(label, default, y, setter)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 190, 0, 42)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = default and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(70, 70, 70)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextScaled = true
    b.Text = label .. (default and " [ON]" or " [OFF]")
    b.Parent = gui
    local s = default
    b.MouseButton1Click:Connect(function()
        s = not s
        b.BackgroundColor3 = s and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(70, 70, 70)
        b.Text = label .. (s and " [ON]" or " [OFF]")
        setter(s)
    end)
end

makeToggle("Auto Dribble (Chase)", true, 10, function(s) DribbleOn = s end)
makeToggle("Auto Curve Shot", true, 57, function(s) CurveOn = s end)
makeToggle("Velocity Assist", true, 104, function(s) CFG.VelocityAssist = s end)

-- Debug HUD
local dbg = Instance.new("TextLabel")
dbg.Size = UDim2.new(0, 190, 0, 30)
dbg.Position = UDim2.new(0, 10, 0, 151)
dbg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
dbg.TextColor3 = Color3.fromRGB(0, 255, 120)
dbg.Font = Enum.Font.Code
dbg.TextScaled = true
dbg.Text = "..."
dbg.Parent = gui

task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        local ball = findBall()
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if ball and root then
            local d = (ball.Position - root.Position).Magnitude
            local mode = isChasing and "CHASE" or "SEN"
            dbg.Text = string.format("[%s] %.1f st", mode, d)
        elseif ball then
            dbg.Text = "Ball: " .. ball.Name
        else
            dbg.Text = "Top bulunamadi!"
        end
    end
end)