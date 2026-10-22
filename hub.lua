l-- Football Assist v6 FINAL
-- Based on real FireServer log capture

task.wait(0.5)
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Football Assist v6",
        Text = "Loaded. Notification = script works.",
        Duration = 4,
    })
end)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui", 5)

local RemotesFolder = RS:FindFirstChild("Remotes")
local BallFolder = RemotesFolder and RemotesFolder:FindFirstChild("Ball")
local TackleRemote = BallFolder and BallFolder:FindFirstChild("Tackle")
local KickRemote = BallFolder and BallFolder:FindFirstChild("Kick")
local StateRemote = BallFolder and BallFolder:FindFirstChild("State")
if not TackleRemote or not KickRemote then
    warn("[v6] remotes missing"); return
end

-- SETTINGS
local S = {
    infiniteStamina = false,
    speedMultiplier = 1.0,
    jumpBoost = false,
    perfectShot = false,
    perfectShotRange = 55,
    curveMode = "off",      -- off / left / right / auto
    autoDribble = false,
    autoGK = false,
}

-- MODULES
local M = {}
local function loadMod(name, path)
    local ok, r = pcall(function()
        local o = RS
        for n in string.gmatch(path, "[^.]+") do
            o = o:FindFirstChild(n); if not o then return nil end
        end
        return require(o)
    end)
    if ok and r then M[name] = r; return r end
end
loadMod("Sprint","Modules.Actions.Sprint")
loadMod("Movement","Client.Gameplay.Player.Movement")
loadMod("Dodge","Modules.Actions.Dodge")
loadMod("Dive","Modules.Actions.GoalkeeperDive")
loadMod("GKActions","Modules.Actions.GoalkeeperActions")
loadMod("GKPrediction","Modules.Gameplay.GoalkeeperPrediction")
loadMod("Renderer","Client.Gameplay.Ball.Renderer")
loadMod("Match","Modules.Gameplay.MatchSettings")
loadMod("Teams","Client.Gameplay.ActorTeams")
loadMod("Practice","Client.Gameplay.PracticeSession")
loadMod("Actors","Modules.Characters.Actors")
loadMod("ActionCommands","Modules.Actions.ActionCommands")
loadMod("Hitboxes","Modules.Gameplay.HitboxSettings")

-- HELPERS
local function getChar() return LP.Character end
local function getRoot()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function getCam() return workspace.CurrentCamera end
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function unit(v, fb) v = flat(v); return v.Magnitude > 1e-4 and v.Unit or (fb or Vector3.new(0,0,-1)) end
local function v3(v) return typeof(v) == "Vector3" end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end

-- SESSION ID
local sessionCounter = math.floor(workspace:GetServerTimeNow() * 1e6)
local function newId() sessionCounter = sessionCounter + 2; return sessionCounter end

-- BALL POSITION
local function getBallPos()
    if M.Renderer and M.Renderer.GetPosition then
        local ok, p = pcall(M.Renderer.GetPosition)
        if ok and v3(p) then return p end
    end
    local map = workspace:FindFirstChild("Map")
    local data = map and map:FindFirstChild("Data")
    local ball = data and data:FindFirstChild("Ball")
    if ball and ball:IsA("BasePart") then return ball.Position end
    return nil
end

local function ballOwnedByMe()
    if M.Renderer and M.Renderer.GetOwnedUserId then
        local ok, id = pcall(M.Renderer.GetOwnedUserId)
        if ok then return id == LP.UserId end
    end
    return false
end

-- GOAL
local function getGoalCtx()
    if M.Practice and M.Practice.IsActive then
        local ok, a = pcall(M.Practice.IsActive)
        if ok and a then
            local ok2, g = pcall(M.Practice.GetDefendedGoalPart)
            if ok2 and g and g:IsA("BasePart") then return { goal = g, mode = "PRACTICE" } end
        end
    end
    if M.Teams and M.Match then
        local okT, team = pcall(M.Teams.GetActorTeamName, LP)
        if okT and team then
            local okO, opp = pcall(M.Match.GetOpposingTeamName, team)
            if okO and opp then
                local map = workspace:FindFirstChild("Map")
                local data = map and map:FindFirstChild("Data")
                local oppSide = data and data:FindFirstChild(opp)
                local g = oppSide and oppSide:FindFirstChild("Goal")
                if g and g:IsA("BasePart") then
                    return { goal = g, team = team, mode = "MATCH" }
                end
            end
        end
    end
    return nil
end

-- PERFECT AIM
local function computePerfectAim()
    local goalCtx = getGoalCtx()
    local ballPos = getBallPos()
    if not goalCtx or not ballPos then return nil end
    local goal = goalCtx.goal
    local cf = goal.CFrame
    local sz = goal.Size
    local up = Vector3.new(0,1,0)
    
    local forward = (sz.X < sz.Z) and cf.LookVector or cf.RightVector
    if forward:Dot(ballPos - goal.Position) < 0 then forward = -forward end
    local lateral = forward:Cross(up).Unit
    local halfW = (math.abs(lateral:Dot(cf.RightVector)) * sz.X
                 + math.abs(lateral:Dot(cf.LookVector)) * sz.Z) * 0.5
    local halfH = sz.Y * 0.5
    
    -- Keeper detection
    local sideSign = 1
    if M.Actors and M.Actors.GetAllCharacterModels then
        local ok, models = pcall(M.Actors.GetAllCharacterModels)
        if ok and models then
            for _, model in ipairs(models) do
                if model ~= getChar() then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    local r = model:FindFirstChild("HumanoidRootPart")
                    if hum and r and hum.Health > 0 then
                        local toGoal = (goal.Position - r.Position).Magnitude
                        if toGoal < 30 then
                            local kLat = (r.Position - goal.Position):Dot(lateral)
                            sideSign = kLat > 0 and -1 or 1
                        end
                    end
                end
            end
        end
    end
    
    local target = goal.Position + lateral * (halfW * 0.7 * sideSign) + up * (halfH * 0.7)
    target = target - forward * 0.5
    
    local dir = (target - ballPos).Unit
    return dir, sideSign
end

-- BUILD SHOT START
local function buildShotStart(direction)
    local root = getRoot(); if not root then return nil end
    local cam = getCam()
    local ballPos = getBallPos() or root.Position
    local sid = newId(); local now = workspace:GetServerTimeNow()
    return {
        Phase="Start", Protocol="ActionSession",
        Command = {
            MaximumChargeSeconds=0.4, SessionId=sid, ShotTime=now,
            AimDirection = {
                Direction=direction, Origin=ballPos,
                CameraCFrame=cam and cam.CFrame or root.CFrame,
                IsAirborne=false,
            },
            PassType="Shot", PlayerVelocity=root.AssemblyLinearVelocity,
            Kind="Tackle", Mode="Kick", KickDirection=unit(direction),
        }
    }, sid, now
end

local function buildShotRelease(sid, t0, direction, curve)
    local root = getRoot(); if not root then return nil end
    local cam = getCam()
    local ballPos = getBallPos() or root.Position
    local cmd = {
        MaximumChargeSeconds=0.4, ChargeStartedAt=t0, SessionId=sid,
        ShotTime=workspace:GetServerTimeNow(),
        AimDirection = {
            Direction=direction, Origin=ballPos,
            CameraCFrame=cam and cam.CFrame or root.CFrame,
            IsAirborne=false,
        },
        PassType="Shot", KickDirection=unit(direction),
        Kind="Tackle", PlayerVelocity=root.AssemblyLinearVelocity,
        Mode="Kick", ChargeSeconds=0.4,
    }
    if curve and curve ~= 0 then cmd.Curve = curve end
    return { Phase="Release", Protocol="ActionSession", Command=cmd }
end

local function buildDodge(direction)
    local root = getRoot(); if not root then return nil end
    return {
        Protocol="ActionCommand",
        Command = {
            Mode="Dodge", Kind="Tackle", ActionId=newId(),
            ShotTime=workspace:GetServerTimeNow(),
            PlayerVelocity=root.AssemblyLinearVelocity,
            AimDirection=unit(direction),
        }
    }
end

-- FIRE HELPERS
local lastShotAt = 0
local function firePerfectShot()
    if os.clock() - lastShotAt < 1.0 then return false end
    if not ballOwnedByMe() then return false end
    local goalCtx = getGoalCtx(); if not goalCtx then return false end
    local ballPos = getBallPos(); if not ballPos then return false end
    if (goalCtx.goal.Position - ballPos).Magnitude > S.perfectShotRange then return false end
    
    local dir, sideSign = computePerfectAim()
    if not dir then return false end
    
    local curve = 0
    if S.curveMode == "left" then curve = -1
    elseif S.curveMode == "right" then curve = 1
    elseif S.curveMode == "auto" then curve = sideSign or 0 end
    
    lastShotAt = os.clock()
    local start, sid, t0 = buildShotStart(dir)
    if not start then return false end
    local ok1 = pcall(function() TackleRemote:FireServer(start) end)
    if not ok1 then return false end
    task.wait(0.42)
    local release = buildShotRelease(sid, t0, dir, curve)
    if not release then return false end
    pcall(function() TackleRemote:FireServer(release) end)
    S.stats_shots = (S.stats_shots or 0) + 1
    return true
end

local function fireFakeShot()
    local cam = getCam()
    local root = getRoot(); if not root then return false end
    local dir = unit(cam and cam.CFrame.LookVector or root.CFrame.LookVector)
    local start = buildShotStart(dir)
    if not start then return false end
    pcall(function() TackleRemote:FireServer(start) end)
    task.wait(0.15)
    local dodge = buildDodge(dir)
    if dodge then pcall(function() TackleRemote:FireServer(dodge) end) end
    return true
end

local function fireDodgeAway(threatPos)
    local root = getRoot(); if not root then return false end
    local away = flat(root.Position - threatPos)
    if away.Magnitude < 0.1 then away = flat(root.CFrame.LookVector) end
    local dodge = buildDodge(away.Unit)
    if dodge then pcall(function() TackleRemote:FireServer(dodge) end) return true end
    return false
end

-- INCOMING TACKLE DETECTION (for auto dribble)
local threats = {}
if TackleRemote and TackleRemote.OnClientEvent then
    TackleRemote.OnClientEvent:Connect(function(packet)
        if type(packet) ~= "table" then return end
        local cmd = packet.Command
        if not cmd then return end
        if cmd.Kind == "Tackle" and (cmd.Mode == "Slide" or cmd.Mode == "Kick" or cmd.Mode == "Volley") then
            local actorId = cmd.ActorUserId or cmd.UserId
            if actorId and actorId ~= LP.UserId then
                threats[actorId] = workspace:GetServerTimeNow()
            end
        end
    end)
end

-- STAMINA / SPEED
local function applyStamina(on)
    if not M.Sprint then return end
    if on then
        pcall(M.Sprint.SetUnlimitedStamina, "v6")
        pcall(M.Sprint.SetUnlimitedStamina, "v6", true)
    else
        pcall(M.Sprint.ClearUnlimitedStaminaSource, "v6")
    end
end
local function applySpeed()
    if not M.Movement or not M.Movement.SetMultiplier then return end
    local char = getChar(); if not char then return end
    pcall(M.Movement.SetMultiplier, char, S.speedMultiplier)
end
local function applyJump()
    local hum = getHum(); if not hum then return end
    hum.JumpPower = S.jumpBoost and 120 or 50
end

-- AUTO DRIBBLE / GK LOOPS
local lastDribble = 0
local function tickAutoDribble()
    if not S.autoDribble then return end
    if os.clock() - lastDribble < 1.0 then return end
    if not ballOwnedByMe() then return end
    if M.Dodge and M.Dodge.IsDribbling then
        local ok, d = pcall(M.Dodge.IsDribbling)
        if ok and d then return end
    end
    local now = workspace:GetServerTimeNow()
    for actorId, t in pairs(threats) do
        if now - t < 1.0 then
            local actor = M.Actors and M.Actors.GetByUserId and M.Actors.GetByUserId(actorId)
            local r = actor and actor.Character and actor.Character:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - (getRoot() and getRoot().Position or Vector3.zero)).Magnitude < 8 then
                if fireDodgeAway(r.Position) then
                    lastDribble = os.clock()
                    return
                end
            end
        else
            threats[actorId] = nil
        end
    end
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "FootballAssistV6"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 999999
gui.Parent = PG

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 320, 0, 520)
panel.Position = UDim2.new(0.5, -160, 0, 30)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
panel.BorderSizePixel = 4
panel.BorderColor3 = Color3.fromRGB(200, 170, 90)
panel.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
title.BorderSizePixel = 0
title.Text = "FOOTBALL ASSIST v6"
title.TextColor3 = Color3.fromRGB(220, 190, 110)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -40, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = panel
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -60)
scroll.Position = UDim2.new(0, 10, 0, 50)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(200, 170, 90)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = scroll

local y_auto = 0
local function addBtn(text, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 38)
    b.LayoutOrder = y_auto; y_auto = y_auto + 1
    b.BackgroundColor3 = color or Color3.fromRGB(40, 40, 40)
    b.BorderSizePixel = 2
    b.BorderColor3 = Color3.fromRGB(80, 80, 80)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = scroll
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(cb)
        if not ok then warn("[v6] " .. tostring(err)) end
    end)
    return b
end

-- BUTTONS
addBtn("[STAMINA] ON", Color3.fromRGB(30,100,50), function()
    S.infiniteStamina = true
    applyStamina(true)
end)
addBtn("[STAMINA] OFF", Color3.fromRGB(100,30,30), function()
    S.infiniteStamina = false
    applyStamina(false)
end)
addBtn("[SPEED] 2x ON", Color3.fromRGB(30,100,50), function()
    S.speedMultiplier = 2.0; applySpeed()
end)
addBtn("[SPEED] OFF", Color3.fromRGB(100,30,30), function()
    S.speedMultiplier = 1.0; applySpeed()
end)
addBtn("[JUMP] BOOST", Color3.fromRGB(30,100,50), function()
    S.jumpBoost = not S.jumpBoost
    applyJump()
end)
addBtn("[SHOT] PERFECT (auto fire)", Color3.fromRGB(120,90,20), function()
    S.perfectShot = not S.perfectShot
end)
addBtn("[SHOT] FIRE NOW", Color3.fromRGB(120,90,20), function()
    firePerfectShot()
end)
addBtn("[SHOT] FAKE", Color3.fromRGB(120,60,20), function()
    fireFakeShot()
end)
addBtn("[CURVE] off", Color3.fromRGB(50,50,80), function()
    local modes = {"off", "left", "right", "auto"}
    local i = 1
    for j, m in ipairs(modes) do if m == S.curveMode then i = j; break end end
    S.curveMode = modes[(i % #modes) + 1]
end)
addBtn("[DRIBBLE] AUTO ON/OFF", Color3.fromRGB(30,100,50), function()
    S.autoDribble = not S.autoDribble
end)

-- MAIN LOOP
local staminaApplied = false
RunService.Heartbeat:Connect(function()
    if not gui.Parent then return end
    -- Stamina re-apply
    if S.infiniteStamina and not staminaApplied then
        applyStamina(true); staminaApplied = true
    elseif not S.infiniteStamina and staminaApplied then
        applyStamina(false); staminaApplied = false
    end
    -- Speed
    if S.speedMultiplier ~= 1.0 then
        applySpeed()
    end
    -- Jump
    if S.jumpBoost then
        applyJump()
    end
    -- Auto shot
    if S.perfectShot then
        firePerfectShot()
    end
    -- Auto dribble
    tickAutoDribble()
end)

print("[v6] Football Assist loaded. Notification = working.")