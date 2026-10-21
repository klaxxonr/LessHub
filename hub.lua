--[[
  Illegal Soccer | Advanced Auto Dribble + Auto Curve
  Delta Executor (Mobil)
  Ayarları CFG tablosundan değiştir.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CFG = {
    -- Dribbling
    DribbleOffset  = 2.8,     -- topun kaç stud arkasında durulacak
    ApproachRange  = 12,      -- bu mesafeden itibaren topa yönel
    WalkSpeed      = 34,      -- top sürerken hız
    SmoothLerp     = 0.55,    -- 0-1 arası; düşük = yumuşak dönüş

    -- Velocity Assist (top ayağında kalsın)
    VelocityAssist = true,
    VA_PullPower   = 5,
    VA_Range       = 5,

    -- Shot / Curve
    ShootRange     = 30,
    ShotCooldown   = 1.4,
    ShotPower      = 105,
    CurvePower     = 60,      -- falso şiddeti (artır = daha kavisli)

    PredictTime    = 0.12,
}

-- ====== TOP BULMA ======
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

-- ====== HÜCUM YÖNÜ ======
local function getAttackDir()
    local look = Camera.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then return Vector3.new(0, 0, -1) end
    return flat.Unit
end

-- ====== FALSOLU ŞUT ======
local function curveShot(ball, dir, curve)
    if not ball then return end
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.01 then return end
    dir = dir.Unit
    local side = dir:Cross(Vector3.new(0, 1, 0))
    if side.Magnitude < 0.01 then side = Vector3.new(1, 0, 0) end
    side = side.Unit
    local v = dir * CFG.ShotPower + side * curve
    v = Vector3.new(v.X, math.min(v.Y, 25), v.Z) -- çok yükselmesin
    ball.AssemblyLinearVelocity = v
end

-- ====== ANA DÖNGÜ ======
local lastDir   = Vector3.zero
local lastShoot = 0

RunService.Heartbeat:Connect(function(dt)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then return end

    local ball = findBall()
    if not ball then return end

    if hum.WalkSpeed ~= CFG.WalkSpeed then hum.WalkSpeed = CFG.WalkSpeed end

    local attack   = getAttackDir()
    local ballPred = ball.Position + ball.AssemblyLinearVelocity * CFG.PredictTime
    local ballFlat = Vector3.new(ballPred.X, root.Position.Y, ballPred.Z)
    local toBall   = ballFlat - root.Position
    local dist     = toBall.Magnitude

    -- Hedef: topun arkası
    local targetPos = ballFlat - attack * CFG.DribbleOffset
    local toTarget  = targetPos - root.Position
    toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)

    local desired
    if dist > CFG.ApproachRange then
        desired = toBall.Unit          -- çok uzak, direkt topa
    elseif toTarget.Magnitude > 0.5 then
        desired = toTarget.Unit        -- arkasına geç
    else
        desired = attack                -- arkadayız, topu it
    end

    lastDir = lastDir:Lerp(desired, CFG.SmoothLerp)
    if lastDir.Magnitude > 0.05 then
        hum:Move(lastDir.Unit, false)
    end

    -- Velocity Assist: top ayağında kalsın
    if CFG.VelocityAssist and dist < CFG.VA_Range then
        local pull = root.Position + attack * 1.5 - ball.Position
        pull = Vector3.new(pull.X, 0, pull.Z)
        ball.AssemblyLinearVelocity = ball.AssemblyLinearVelocity + pull * CFG.VA_PullPower * dt
    end

    -- Auto-Curve Şut
    local facing = dist > 0.1 and toBall.Unit:Dot(attack) or 0
    if dist < CFG.ShootRange and facing > 0.35 and (tick() - lastShoot) > CFG.ShotCooldown then
        curveShot(ball, attack, CFG.CurvePower)
        lastShoot = tick()
    end
end)

-- ====== TOGGLE GUI (Delta Mobile) ======
local gui = Instance.new("ScreenGui")
gui.Name = "SoccerHelper"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local function toggle(label, default, setter, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 150, 0, 40)
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

toggle("Velocity Assist", true, function(s) CFG.VelocityAssist = s end, 10)
toggle("Auto Curve Shot", true, function(s) CFG.ShotPower = s and 105 or 0; CFG.CurvePower = s and 60 or 0 end, 55)