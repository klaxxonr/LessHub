-- Illegal Soccer Assist (Rayfield Premium Hub) v4.0
-- Log-analiz doğrulanmış fixler: goal finding, spam koruması, movement non-interference.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local LP = Players.LocalPlayer

-- ============================================================
-- 1. RAYFIELD
-- ============================================================
local Rayfield = nil
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not Rayfield then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "IS Assist",
            Text = "Rayfield failed to load.",
            Duration = 6
        })
    end)
    return
end

local Window = Rayfield:CreateWindow({
    Name = "IS Assist",
    Icon = 4483362458,
    LoadingTitle = "IS Assist",
    LoadingSubtitle = "Loading modules...",
    Theme = "Default",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local function notify(title, content, dur)
    pcall(function()
        Rayfield:Notify({ Title = title, Content = content, Duration = dur or 3 })
    end)
end

notify("IS Assist", "Hub loaded.", 4)

-- ============================================================
-- 2. MODULES
-- ============================================================
local M = {}
local loadStatus = {}

local function safeRequire(path)
    local ok, result = pcall(function()
        local obj = ReplicatedStorage
        for _, part in ipairs(path) do
            obj = obj:FindFirstChild(part) or obj:WaitForChild(part, 3)
            if not obj then return nil end
        end
        return require(obj)
    end)
    if ok and result then
        loadStatus[table.concat(path, ".")] = "OK"
        return result
    end
    loadStatus[table.concat(path, ".")] = "FAIL"
    return nil
end

M.Sprint = safeRequire({"Modules", "Actions", "Sprint"})
M.Movement = safeRequire({"Client", "Gameplay", "Player", "Movement"})
M.Renderer = safeRequire({"Client", "Gameplay", "Ball", "Renderer"})
M.MatchSettings = safeRequire({"Modules", "Gameplay", "MatchSettings"})
M.ActorTeams = safeRequire({"Client", "Gameplay", "ActorTeams"})
M.PracticeSession = safeRequire({"Client", "Gameplay", "PracticeSession"})
M.Actors = safeRequire({"Modules", "Characters", "Actors"})
M.ActionChargeState = safeRequire({"Modules", "Actions", "ActionChargeState"})
M.GoalkeeperDive = safeRequire({"Modules", "Actions", "GoalkeeperDive"})
M.GoalkeeperRole = safeRequire({"Client", "Gameplay", "Player", "GoalkeeperRole"})
M.BicycleKick = safeRequire({"Modules", "Actions", "BicycleKick"})
M.RainbowFlick = safeRequire({"Modules", "Actions", "RainbowFlick"})

-- ============================================================
-- 3. REMOTES
-- ============================================================
local Remotes = {}
pcall(function()
    local root = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
    if root then
        local ball = root:FindFirstChild("Ball") or root:WaitForChild("Ball", 3)
        if ball then
            Remotes.Tackle = ball:FindFirstChild("Tackle") or ball:WaitForChild("Tackle", 3)
            Remotes.Kick = ball:FindFirstChild("Kick") or ball:WaitForChild("Kick", 3)
        end
        local chars = root:FindFirstChild("Characters")
        if chars then
            Remotes.MovementBoost = chars:FindFirstChild("MovementBoost")
        end
    end
end)

if not Remotes.Tackle then
    notify("IS Assist", "Tackle remote not found. Shot features will fail.", 6)
end

-- ============================================================
-- 4. STATE (all defaults neutral)
-- ============================================================
local featureState = {
    infStamina = false,
    speedMult = 1.0,
    jumpPower = 50,
    perfectShot = false,
    shotCooldown = 2.0,
    dwellTime = 1.0,
    curveMode = "AUTO",
    chargeSeconds = 0.4,
    autoDodge = false,
    dodgeRange = 8,
    autoTackle = false,
    tackleRange = 8,
    tackleCooldown = 1.5,
    autoGK = false,
    diveDir = "SMART",
    diveRange = 40,
    esp = false,
    ballTracker = false,
    teleportToBall = false,
}

-- ============================================================
-- 5. HELPERS
-- ============================================================
-- Monotonic sessionId, base from current time at each call to avoid staleness
local sessionCounter = 0
local sessionInitTime = 0
local function newSessionId()
    local now = workspace:GetServerTimeNow()
    if sessionInitTime == 0 or (now - sessionInitTime) > 30 then
        sessionInitTime = now
        sessionCounter = math.floor(now * 2e6)
    end
    sessionCounter = sessionCounter + 2
    return sessionCounter
end

local function getRoot()
    local c = LP.Character
    if c then return c:FindFirstChild("HumanoidRootPart") end
end

local function getHum()
    local c = LP.Character
    if c then return c:FindFirstChildOfClass("Humanoid") end
end

local function getCam() return workspace.CurrentCamera end
local function unit(v)
    if v and v.Magnitude > 0.001 then return v.Unit end
    return Vector3.new(0, 0, 1)
end

local function getBallPos()
    local p = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then p = M.Renderer.GetPosition() end
    end)
    return p
end

local function getBallOwnerId()
    local id = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetOwnedUserId then id = M.Renderer.GetOwnedUserId() end
    end)
    return id
end

local function isBallOwnedByMe()
    return getBallOwnerId() == LP.UserId
end

local function isCharging()
    local charging = false
    pcall(function()
        if M.ActionChargeState and M.ActionChargeState.IsCharging then
            charging = M.ActionChargeState.IsCharging() and true or false
        end
    end)
    if not charging then
        pcall(function()
            if M.ActionChargeState and M.ActionChargeState.IsCharging then
                charging = M.ActionChargeState.IsCharging(LP.Character) and true or false
            end
        end)
    end
    return charging
end

local function getMyTeam()
    local t = nil
    pcall(function()
        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
            t = M.ActorTeams.GetCharacterTeamName(LP.Character)
        end
    end)
    return t
end

-- ============================================================
-- GOAL FINDING (CRITICAL FIX)
-- ============================================================
local goalCache = { parts = {}, lastRefresh = 0 }
local function refreshGoalCache()
    if tick() - goalCache.lastRefresh < 5 and #goalCache.parts > 0 then return end
    goalCache.lastRefresh = tick()
    goalCache.parts = {}

    -- Method 1: PracticeSession.GetGoalParts
    pcall(function()
        if M.PracticeSession and M.PracticeSession.GetGoalParts then
            local parts = M.PracticeSession.GetGoalParts()
            if parts then
                for _, p in pairs(parts) do
                    if typeof(p) == "Instance" and p:IsA("BasePart") then
                        table.insert(goalCache.parts, p)
                    end
                end
            end
        end
    end)
    if #goalCache.parts >= 2 then return end

    -- Method 2: CollectionService "Goal" tag
    pcall(function()
        local tagged = CollectionService:GetTagged("Goal")
        for _, p in ipairs(tagged) do
            if p:IsA("BasePart") then table.insert(goalCache.parts, p) end
        end
    end)
    if #goalCache.parts >= 2 then return end

    -- Method 3: Map.Data.Goals folder
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        if map then
            local data = map:FindFirstChild("Data")
            if data then
                local goals = data:FindFirstChild("Goals")
                if goals then
                    for _, child in ipairs(goals:GetChildren()) do
                        if child:IsA("BasePart") then table.insert(goalCache.parts, child) end
                    end
                end
            end
        end
    end)
    if #goalCache.parts >= 2 then return end

    -- Method 4: strict name match (Goal, Goal1, Goal2, Goal_A, Goal_B, Team1Goal, Team2Goal)
    if #goalCache.parts < 2 then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and #goalCache.parts < 4 then
                local n = d.Name:lower()
                if n == "goal" or n:match("^goal%d+$") or n:match("^goal_") or n:match("team%dgoal") then
                    table.insert(goalCache.parts, d)
                end
            end
        end
    end
end

-- Returns position of the ENEMY goal (furthest from our own defended goal)
local function getEnemyGoalPosition()
    refreshGoalCache()
    if #goalCache.parts == 0 then return nil end
    if #goalCache.parts == 1 then return goalCache.parts[1].Position end

    local myGoalPart = nil
    pcall(function()
        if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
            myGoalPart = M.PracticeSession.GetDefendedGoalPart()
        end
    end)

    if myGoalPart and myGoalPart.Position then
        local best, bestDist = nil, 0
        for _, p in ipairs(goalCache.parts) do
            local d = (p.Position - myGoalPart.Position).Magnitude
            if d > bestDist then bestDist = d; best = p end
        end
        if best then return best.Position end
    end

    -- Fallback: pick goal most in front of camera
    local cam = getCam()
    if not cam then return goalCache.parts[1].Position end
    local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
    if flatLook.Magnitude > 0.01 then flatLook = flatLook.Unit else flatLook = Vector3.new(0, 0, -1) end
    local best, bestDot = nil, -math.huge
    for _, p in ipairs(goalCache.parts) do
        local dir = Vector3.new(p.Position.X, 0, p.Position.Z)
        local root = getRoot()
        if root then
            local toGoal = Vector3.new(p.Position.X - root.Position.X, 0, p.Position.Z - root.Position.Z)
            if toGoal.Magnitude > 10 then
                local d = toGoal.Unit:Dot(flatLook)
                if d > bestDot then bestDot = d; best = p end
            end
        end
    end
    if best then return best.Position end
    return goalCache.parts[1].Position
end

local function getOpponentKeeperPos()
    local myTeam = getMyTeam()
    if not myTeam then return nil end
    local gk = nil
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local theirTeam = nil
                    pcall(function()
                        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
                            theirTeam = M.ActorTeams.GetCharacterTeamName(model)
                        end
                    end)
                    if theirTeam and theirTeam ~= myTeam then
                        local isGK = false
                        pcall(function()
                            if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter then
                                isGK = M.MatchSettings.IsGoalkeeperCharacter(model)
                            end
                        end)
                        if isGK then
                            local hrp = model:FindFirstChild("HumanoidRootPart")
                            if hrp then gk = hrp.Position; break end
                        end
                    end
                end
            end
        end
    end)
    return gk
end

local function findTeammateId()
    local myTeam = getMyTeam()
    if not myTeam then return nil end
    local ballPos = getBallPos(); if not ballPos then return nil end
    local bestId, bestDist = nil, math.huge
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local same = false
                    pcall(function()
                        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
                            same = (M.ActorTeams.GetCharacterTeamName(model) == myTeam)
                        end
                    end)
                    if same then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (hrp.Position - ballPos).Magnitude
                            if d < bestDist then bestDist = d; bestId = plr.UserId end
                        end
                    end
                end
            end
        end
    end)
    return bestId
end

local function findNearestOpponent(maxRange)
    local myTeam = getMyTeam(); if not myTeam then return nil end
    local myRoot = getRoot(); if not myRoot then return nil end
    local best, bestDist = nil, maxRange
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local theirTeam = nil
                    pcall(function()
                        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
                            theirTeam = M.ActorTeams.GetCharacterTeamName(model)
                        end
                    end)
                    if theirTeam and theirTeam ~= myTeam then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (hrp.Position - myRoot.Position).Magnitude
                            if d < bestDist then bestDist = d; best = hrp end
                        end
                    end
                end
            end
        end
    end)
    return best, bestDist
end

local function isLocalPlayerGK()
    local isGK = false
    -- Method 1: GoalkeeperRole (property or function)
    pcall(function()
        if M.GoalkeeperRole then
            local v = M.GoalkeeperRole.IsGoalkeeper
            if type(v) == "boolean" then isGK = v
            elseif type(v) == "function" then isGK = v() and true or false end
        end
    end)
    if isGK then return true end
    -- Method 2: MatchSettings
    pcall(function()
        if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter and LP.Character then
            isGK = M.MatchSettings.IsGoalkeeperCharacter(LP.Character) and true or false
        end
    end)
    return isGK
end

-- ============================================================
-- 6. COMMAND BUILDERS (log-verified)
-- ============================================================
local function buildShotStart(targetPos)
    local root = getRoot()
    local ballPos = getBallPos() or Vector3.new(0, 0, 0)
    local cam = getCam()
    local direction = unit(targetPos - ballPos)
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude > 0.001 then flat = flat.Unit end
    local sid = newSessionId()
    local now = workspace:GetServerTimeNow()
    return {
        Phase = "Start",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = 0.4,
            SessionId = sid,
            ShotTime = now,
            AimDirection = {
                Direction = direction,
                Origin = ballPos,
                CameraCFrame = cam.CFrame,
                IsAirborne = false,
            },
            PassType = "Shot",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Kind = "Tackle",
            Mode = "Kick",
            KickDirection = flat,
        }
    }, sid, now
end

local function buildShotRelease(targetPos, sid, startTime, curve)
    local root = getRoot()
    local ballPos = getBallPos() or Vector3.new(0, 0, 0)
    local cam = getCam()
    local direction = unit(targetPos - ballPos)
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude > 0.001 then flat = flat.Unit end
    local cmd = {
        Phase = "Release",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = 0.4,
            ChargeStartedAt = startTime,
            SessionId = sid,
            ShotTime = workspace:GetServerTimeNow(),
            AimDirection = {
                Direction = direction,
                Origin = ballPos,
                CameraCFrame = cam.CFrame,
                IsAirborne = false,
            },
            PassType = "Shot",
            KickDirection = flat,
            Kind = "Tackle",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Mode = "Kick",
            ChargeSeconds = featureState.chargeSeconds,
        }
    }
    if curve and curve ~= 0 then cmd.Command.Curve = curve end
    return cmd
end

local function buildDodge(direction)
    local root = getRoot()
    return {
        Protocol = "ActionCommand",
        Command = {
            Mode = "Dodge",
            Kind = "Tackle",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            AimDirection = direction or Vector3.new(0, 0, 1),
        }
    }
end

local function buildSlide(direction)
    local root = getRoot()
    return {
        Protocol = "ActionCommand",
        Command = {
            Mode = "Slide",
            Kind = "Tackle",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            AimDirection = direction or Vector3.new(0, 0, 1),
        }
    }
end

-- ============================================================
-- 7. FEATURES
-- ============================================================
local function fireAt(targetPos, overrideCurve)
    if not Remotes.Tackle then
        notify("Shot", "Tackle remote missing", 3)
        return false
    end
    local startCmd, sid, startTime = buildShotStart(targetPos)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(featureState.chargeSeconds + 0.02)
    local curve = overrideCurve or 0
    pcall(function()
        Remotes.Tackle:FireServer(buildShotRelease(targetPos, sid, startTime, curve))
    end)
    return true
end

local function pickCurve(goalPos, ballPos)
    local gk = getOpponentKeeperPos()
    if not gk then return 0 end
    local lat = Vector3.new(gk.X - goalPos.X, 0, gk.Z - goalPos.Z)
    if lat.Magnitude < 0.1 then return 0 end
    return lat.Unit:Dot(unit(goalPos - ballPos)) > 0 and -1 or 1
end

local function firePerfectShot()
    if not Remotes.Tackle then return false end
    local ballPos = getBallPos(); if not ballPos then return false end
    local goalPos = getEnemyGoalPosition()
    if not goalPos then
        notify("Shot", "Enemy goal not found", 3)
        return false
    end
    -- Aim at open corner
    local gk = getOpponentKeeperPos()
    local target = goalPos
    if gk then
        local lat = Vector3.new(gk.X - goalPos.X, 0, gk.Z - goalPos.Z)
        if lat.Magnitude > 0.1 then
            target = goalPos - lat.Unit * 8 + Vector3.new(0, 2, 0)
        else
            target = goalPos + Vector3.new(0, 2, 0)
        end
    else
        target = goalPos + Vector3.new(0, 2, 0)
    end

    -- Skip if user is aiming away from goal (probably passing)
    local cam = getCam()
    if cam then
        local targetDir = unit(target - ballPos)
        local camDir = unit(cam.CFrame.LookVector)
        if targetDir:Dot(camDir) < 0.3 then return false end
    end

    local curve
    if featureState.curveMode == "LEFT" then curve = -1
    elseif featureState.curveMode == "RIGHT" then curve = 1
    elseif featureState.curveMode == "OFF" then curve = 0
    else curve = pickCurve(goalPos, ballPos) end

    return fireAt(target, curve)
end

local function fireFakeShot()
    if not Remotes.Tackle then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local goalPos = getEnemyGoalPosition() or (ballPos + Vector3.new(0, 0, 20))
    local startCmd = buildShotStart(goalPos)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(0.15)
    pcall(function() Remotes.Tackle:FireServer(buildDodge(unit(goalPos - ballPos))) end)
end

local function fireWallShot()
    if not Remotes.Tackle then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local walls = nil
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        if map then
            local data = map:FindFirstChild("Data")
            if data then walls = data:FindFirstChild("Walls") end
        end
    end)
    local wallPos = nil
    if walls then
        local best = math.huge
        for _, w in ipairs(walls:GetChildren()) do
            if w:IsA("BasePart") then
                local d = (w.Position - ballPos).Magnitude
                if d < best then best = d; wallPos = w.Position end
            end
        end
    end
    if not wallPos then
        local cam = getCam()
        wallPos = ballPos - unit(cam.CFrame.LookVector) * 25
    end
    fireAt(wallPos, 0)
end

local function firePerfectPass()
    if not Remotes.Kick then
        notify("Pass", "Kick remote missing", 3)
        return
    end
    local root = getRoot(); if not root then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local teammateId = findTeammateId()
    if not teammateId then
        notify("Pass", "No teammate found", 2)
        return
    end
    local cam = getCam()
    pcall(function()
        Remotes.Kick:FireServer({
            Phase = "Release",
            Protocol = "ActionSession",
            Command = {
                MaximumChargeSeconds = 0.4,
                ChargeStartedAt = workspace:GetServerTimeNow(),
                SessionId = newSessionId(),
                ShotTime = workspace:GetServerTimeNow(),
                AimDirection = {
                    Direction = unit(cam.CFrame.LookVector),
                    Origin = ballPos,
                    CameraCFrame = cam.CFrame,
                    IsAirborne = false,
                },
                PassType = "AssistedPass",
                TargetUserId = teammateId,
                KickDirection = unit(Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)),
                Kind = "Tackle",
                PlayerVelocity = root.AssemblyLinearVelocity,
                Mode = "Kick",
                ChargeSeconds = 0.4,
            }
        })
    end)
end

local function fireRainbowFlick()
    if not Remotes.Tackle then return end
    local root = getRoot(); if not root then return end
    local dir = unit(getCam().CFrame.LookVector)
    pcall(function()
        Remotes.Tackle:FireServer({
            Protocol = "ActionCommand",
            Command = {
                Kind = "RainbowFlick",
                ActionId = newSessionId(),
                ShotTime = workspace:GetServerTimeNow(),
                PlayerVelocity = root.AssemblyLinearVelocity,
                AimDirection = dir,
            }
        })
    end)
    task.wait(0.4)
    pcall(function()
        Remotes.Tackle:FireServer({
            Protocol = "ActionCommand",
            Command = {
                Mode = "RainbowFlickDetach",
                Kind = "Tackle",
                ActionId = newSessionId(),
                ShotTime = workspace:GetServerTimeNow(),
                PlayerVelocity = root.AssemblyLinearVelocity,
                AimDirection = dir,
            }
        })
    end)
end

-- ============================================================
-- 8. DEFAULTS TRACKING (only apply on change, never spam)
-- ============================================================
local lastAppliedSpeed = 1.0
local lastAppliedJump = 50
local lastAppliedStamina = false

local function applySpeedIfChanged()
    if math.abs(featureState.speedMult - lastAppliedSpeed) < 0.01 then return end
    lastAppliedSpeed = featureState.speedMult
    if not M.Movement or not M.Movement.SetMultiplier then return end
    local char = LP.Character
    if not char then return end
    pcall(function() M.Movement.SetMultiplier(char, featureState.speedMult) end)
end

local function applyJumpIfChanged()
    if math.abs(featureState.jumpPower - lastAppliedJump) < 1 then return end
    lastAppliedJump = featureState.jumpPower
    local hum = getHum()
    if not hum then return end
    pcall(function()
        hum.UseJumpPower = true
        hum.JumpPower = featureState.jumpPower
    end)
end

local function applyStaminaIfChanged()
    if featureState.infStamina == lastAppliedStamina then return end
    lastAppliedStamina = featureState.infStamina
    if not M.Sprint or not M.Sprint.SetUnlimitedStamina then return end
    if featureState.infStamina then
        pcall(function() M.Sprint.SetUnlimitedStamina("v6") end)
    else
        pcall(function()
            if M.Sprint.ClearUnlimitedStaminaSource then
                M.Sprint.ClearUnlimitedStaminaSource("v6")
            end
        end)
    end
end

-- ============================================================
-- 9. PERFECT SHOT: ONE FIRE PER POSSESSION
-- ============================================================
local possessionStart = 0
local wasOwned = false
local firedThisPossession = false
local lastShotTime = 0

local function perfectShotTick()
    if not featureState.perfectShot then
        wasOwned = false
        firedThisPossession = false
        return
    end
    local owned = isBallOwnedByMe()
    if owned and not wasOwned then
        possessionStart = tick()
        firedThisPossession = false
    end
    wasOwned = owned
    if not owned then return end
    if firedThisPossession then return end
    if isCharging() then
        -- user is manually charging, don't interfere
        firedThisPossession = true
        return
    end
    local dwell = tick() - possessionStart
    if dwell < featureState.dwellTime then return end
    if tick() - lastShotTime < featureState.shotCooldown then return end
    lastShotTime = tick()
    firedThisPossession = true
    task.spawn(function() pcall(firePerfectShot) end)
end

-- ============================================================
-- 10. AUTO DODGE
-- ============================================================
local lastDodgeTime = 0
local function autoDodgeTick()
    if not featureState.autoDodge or not Remotes.Tackle then return end
    if tick() - lastDodgeTime < 1 then return end
    local opp, dist = findNearestOpponent(featureState.dodgeRange)
    if not opp then return end
    lastDodgeTime = tick()
    local myRoot = getRoot(); if not myRoot then return end
    local away = unit(myRoot.Position - opp.Position)
    pcall(function() Remotes.Tackle:FireServer(buildDodge(away)) end)
end

-- ============================================================
-- 11. AUTO TACKLE
-- ============================================================
local lastTackleTime = 0
local function autoTackleTick()
    if not featureState.autoTackle or not Remotes.Tackle then return end
    if tick() - lastTackleTime < featureState.tackleCooldown then return end
    local owner = getBallOwnerId()
    if not owner or owner == LP.UserId or owner <= 0 then return end
    local opp, dist = findNearestOpponent(featureState.tackleRange)
    if not opp then return end
    local myRoot = getRoot(); if not myRoot then return end
    lastTackleTime = tick()
    local slideDir = unit(opp.Position - myRoot.Position)
    pcall(function() Remotes.Tackle:FireServer(buildSlide(slideDir)) end)
end

-- ============================================================
-- 12. AUTO GK
-- ============================================================
local lastDiveTime = 0
local function autoGKTick()
    if not featureState.autoGK then return end
    if not isLocalPlayerGK() then return end
    if tick() - lastDiveTime < 1.2 then return end
    local ballPos = getBallPos()
    local root = getRoot()
    if not ballPos or not root then return end
    local goalPart = nil
    pcall(function()
        if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
            goalPart = M.PracticeSession.GetDefendedGoalPart()
        end
    end)
    if not goalPart then return end
    if (ballPos - goalPart.Position).Magnitude > featureState.diveRange then return end

    local dirName = "F"
    if featureState.diveDir == "SMART" then
        local lat = Vector3.new(ballPos.X - goalPart.Position.X, 0, ballPos.Z - goalPart.Position.Z)
        if lat.Magnitude > 3 then
            local myLat = Vector3.new(root.Position.X - goalPart.Position.X, 0, root.Position.Z - goalPart.Position.Z)
            dirName = myLat:Dot(lat.Unit) > 0 and "R" or "L"
        end
    elseif featureState.diveDir == "LEFT" then dirName = "L"
    elseif featureState.diveDir == "RIGHT" then dirName = "R"
    elseif featureState.diveDir == "SIDES" then
        dirName = (ballPos - goalPart.Position).X > 0 and "R" or "L"
    end

    lastDiveTime = tick()
    local dived = false
    if M.GoalkeeperDive and M.GoalkeeperDive.Run then
        pcall(function()
            local choice = M.GoalkeeperDive.GetDirectionChoiceByName and M.GoalkeeperDive.GetDirectionChoiceByName(dirName)
            if choice then
                local basisFn = function() return CFrame.new(goalPart.Position, goalPart.Position + Vector3.new(0, 0, -1)) end
                M.GoalkeeperDive.Run(root, getHum(), choice, basisFn, {})
                dived = true
            end
        end)
    end
    if not dived and Remotes.Tackle then
        pcall(function()
            Remotes.Tackle:FireServer({
                Protocol = "ActionCommand",
                Command = {
                    Mode = "GoalkeeperDive",
                    Kind = "Tackle",
                    ActionId = newSessionId(),
                    ShotTime = workspace:GetServerTimeNow(),
                    PlayerVelocity = root.AssemblyLinearVelocity,
                    AimDirection = unit(ballPos - root.Position),
                    DirectionName = dirName,
                }
            })
        end)
    end
end

-- ============================================================
-- 13. ESP & TRACKER
-- ============================================================
local espObjects = {}
local function updateESP()
    if not featureState.esp then
        for _, o in pairs(espObjects) do pcall(function() o:Destroy() end) end
        espObjects = {}
        return
    end
    local all = {}
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then all = M.Actors.GetAllCharacterModels() end
    end)
    for _, model in ipairs(all) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp and not espObjects[model] then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 120, 0, 30)
            bb.AlwaysOnTop = true
            bb.Adornee = hrp
            bb.Parent = LP.PlayerGui
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = model.Name
            lbl.TextColor3 = Color3.fromRGB(255, 255, 100)
            lbl.TextSize = 12
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = bb
            espObjects[model] = bb
        end
    end
    for model, o in pairs(espObjects) do
        if not model.Parent or not model:FindFirstChild("HumanoidRootPart") then
            pcall(function() o:Destroy() end)
            espObjects[model] = nil
        end
    end
end

local ballBB = nil
local function updateBallTracker()
    if not featureState.ballTracker then
        if ballBB then pcall(function() ballBB:Destroy() end); ballBB = nil end
        return
    end
    if not ballBB then
        local bp = workspace:FindFirstChild("Ball", true)
        if bp and bp:IsA("BasePart") then
            ballBB = Instance.new("BillboardGui")
            ballBB.Size = UDim2.new(0, 100, 0, 24)
            ballBB.AlwaysOnTop = true
            ballBB.Adornee = bp
            ballBB.Parent = LP.PlayerGui
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "BALL"
            lbl.TextColor3 = Color3.fromRGB(255, 120, 120)
            lbl.TextSize = 12
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = ballBB
        end
    end
end

local function teleportTick()
    if not featureState.teleportToBall then return end
    local bp = getBallPos(); if not bp then return end
    local hrp = getRoot(); if not hrp then return end
    pcall(function() hrp.CFrame = CFrame.new(bp + Vector3.new(0, 5, 0)) end)
end

-- ============================================================
-- 14. UI
-- ============================================================
local MovementTab = Window:CreateTab("Movement", 4483362458)
MovementTab:CreateToggle({ Name = "Infinite Stamina", CurrentValue = false, Flag = "InfStam",
    Callback = function(v) featureState.infStamina = v end })
MovementTab:CreateSlider({ Name = "Speed Multiplier", Range = {1.0, 2.5}, Increment = 0.1, Suffix = "x",
    CurrentValue = 1.0, Flag = "SpeedMult", Callback = function(v) featureState.speedMult = v end })
MovementTab:CreateSlider({ Name = "Jump Power", Range = {50, 150}, Increment = 5, Suffix = "",
    CurrentValue = 50, Flag = "JumpPower", Callback = function(v) featureState.jumpPower = v end })

local ShotTab = Window:CreateTab("Shot", 4483362458)
ShotTab:CreateToggle({ Name = "Perfect Shot (once per possession)", CurrentValue = false, Flag = "PerfectShot",
    Callback = function(v) featureState.perfectShot = v end })
ShotTab:CreateSlider({ Name = "Possession Dwell Before Auto-Fire", Range = {0.5, 5.0}, Increment = 0.1,
    Suffix = "s", CurrentValue = 1.0, Flag = "DwellTime", Callback = function(v) featureState.dwellTime = v end })
ShotTab:CreateSlider({ Name = "Shot Cooldown", Range = {1.0, 5.0}, Increment = 0.1, Suffix = "s",
    CurrentValue = 2.0, Flag = "ShotCooldown", Callback = function(v) featureState.shotCooldown = v end })
ShotTab:CreateDropdown({ Name = "Curve Mode", Options = {"OFF", "LEFT", "RIGHT", "AUTO"},
    CurrentOption = {"AUTO"}, MultipleOptions = false, Flag = "CurveMode",
    Callback = function(opt) featureState.curveMode = type(opt) == "table" and opt[1] or opt end })
ShotTab:CreateSlider({ Name = "Charge Seconds", Range = {0.1, 0.4}, Increment = 0.05, Suffix = "s",
    CurrentValue = 0.4, Flag = "ChargeSec", Callback = function(v) featureState.chargeSeconds = v end })
ShotTab:CreateButton({ Name = "FAKE SHOT", Callback = function() pcall(fireFakeShot) end })
ShotTab:CreateButton({ Name = "WALL SHOT", Callback = function() pcall(fireWallShot) end })
ShotTab:CreateButton({ Name = "PERFECT PASS", Callback = function() pcall(firePerfectPass) end })

local DribbleTab = Window:CreateTab("Dribble", 4483362458)
DribbleTab:CreateToggle({ Name = "Auto Dodge (Enemy Near)", CurrentValue = false, Flag = "AutoDodge",
    Callback = function(v) featureState.autoDodge = v end })
DribbleTab:CreateSlider({ Name = "Dodge Range", Range = {3, 15}, Increment = 1, Suffix = " studs",
    CurrentValue = 8, Flag = "DodgeRange", Callback = function(v) featureState.dodgeRange = v end })
DribbleTab:CreateButton({ Name = "MANUAL RAINBOW FLICK", Callback = function() pcall(fireRainbowFlick) end })

local GKTab = Window:CreateTab("Goalkeeper", 4483362458)
GKTab:CreateToggle({ Name = "Auto Goalkeeper", CurrentValue = false, Flag = "AutoGK",
    Callback = function(v) featureState.autoGK = v end })
GKTab:CreateDropdown({ Name = "Dive Direction", Options = {"SMART", "FORWARD", "LEFT", "RIGHT", "SIDES"},
    CurrentOption = {"SMART"}, MultipleOptions = false, Flag = "DiveDir",
    Callback = function(opt) featureState.diveDir = type(opt) == "table" and opt[1] or opt end })
GKTab:CreateSlider({ Name = "Dive Trigger Range", Range = {10, 80}, Increment = 5, Suffix = " studs",
    CurrentValue = 40, Flag = "DiveRange", Callback = function(v) featureState.diveRange = v end })

local DefTab = Window:CreateTab("Defense", 4483362458)
DefTab:CreateToggle({ Name = "Auto Slide Tackle", CurrentValue = false, Flag = "AutoTackle",
    Callback = function(v) featureState.autoTackle = v end })
DefTab:CreateSlider({ Name = "Tackle Range", Range = {3, 20}, Increment = 1, Suffix = " studs",
    CurrentValue = 8, Flag = "TackleRange", Callback = function(v) featureState.tackleRange = v end })
DefTab:CreateSlider({ Name = "Tackle Cooldown", Range = {0.5, 5.0}, Increment = 0.1, Suffix = "s",
    CurrentValue = 1.5, Flag = "TackleCooldown", Callback = function(v) featureState.tackleCooldown = v end })

local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateToggle({ Name = "ESP (Player Labels)", CurrentValue = false, Flag = "ESP",
    Callback = function(v) featureState.esp = v end })
MiscTab:CreateToggle({ Name = "Ball Tracker", CurrentValue = false, Flag = "BallTracker",
    Callback = function(v) featureState.ballTracker = v end })
MiscTab:CreateToggle({ Name = "Teleport to Ball (RISKY)", CurrentValue = false, Flag = "TPBall",
    Callback = function(v) featureState.teleportToBall = v end })
MiscTab:CreateButton({ Name = "TEST FIRE SHOT", Callback = function()
    if not Remotes.Tackle then notify("Test", "Tackle remote missing", 3); return end
    local g = getEnemyGoalPosition()
    if not g then notify("Test", "Goal not found", 3); return end
    notify("Test", "Firing at goal: " .. tostring(math.floor(g.X)) .. "," .. tostring(math.floor(g.Z)), 3)
    pcall(firePerfectShot)
end })
MiscTab:CreateButton({ Name = "DEBUG STATUS", Callback = function()
    local msg = ""
    msg = msg .. "Tackle:" .. tostring(Remotes.Tackle ~= nil) .. " "
    msg = msg .. "Kick:" .. tostring(Remotes.Kick ~= nil) .. " "
    msg = msg .. "GK:" .. tostring(isLocalPlayerGK()) .. " "
    local g = getEnemyGoalPosition()
    msg = msg .. "Goal:" .. tostring(g ~= nil) .. " "
    msg = msg .. "Owner:" .. tostring(getBallOwnerId())
    notify("Debug", msg, 8)
end })
MiscTab:CreateButton({ Name = "REJOIN", Callback = function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end })
MiscTab:CreateButton({ Name = "UNLOAD", Callback = function()
    pcall(function() Window:Destroy() end)
    _G.FootballAssist = nil
end })

-- ============================================================
-- 15. LOOPS
-- ============================================================
-- Fast tick (60Hz) - only cheap operations
RunService.Heartbeat:Connect(function()
    xpcall(function()
        perfectShotTick()
        autoDodgeTick()
        autoTackleTick()
        applyStaminaIfChanged()
    end, function() end)
end)

-- Slow tick (5Hz) - heavy operations
task.spawn(function()
    while true do
        task.wait(0.2)
        xpcall(function()
            applySpeedIfChanged()
            applyJumpIfChanged()
            autoGKTick()
            updateESP()
            updateBallTracker()
            teleportTick()
        end, function() end)
    end
end)

-- ============================================================
-- 16. API
-- ============================================================
_G.FootballAssist = {
    Window = Window,
    Modules = M,
    Remotes = Remotes,
    State = featureState,
    FirePerfectShot = firePerfectShot,
    FireFakeShot = fireFakeShot,
    FireWallShot = fireWallShot,
    FirePerfectPass = firePerfectPass,
    FireRainbowFlick = fireRainbowFlick,
    GetEnemyGoal = getEnemyGoalPosition,
    IsLocalGK = isLocalPlayerGK,
    LoadStatus = loadStatus,
    Version = "4.0",
}

print("[IS Assist v4] Loaded.")