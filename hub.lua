-- Illegal Soccer Assist (Rayfield Premium Hub) v3.0
-- Mobile compatible. All features pcall-protected.
-- SessionId base fixed to 2e6, AimDirection/KickDirection split per log analysis.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

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
            Text = "Rayfield failed to load. Check internet.",
            Duration = 6
        })
    end)
    return
end

local Window = Rayfield:CreateWindow({
    Name = "IS Assist",
    Icon = 4483362458,
    LoadingTitle = "IS Assist",
    LoadingSubtitle = "Loading...",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

pcall(function()
    Rayfield:Notify({
        Title = "IS Assist",
        Content = "Hub loaded. UI opened.",
        Duration = 4,
        Image = 4483362458,
    })
end)

-- ============================================================
-- 2. MODULES
-- ============================================================
local M = {}
local function safeRequire(path)
    local ok, result = pcall(function()
        local obj = ReplicatedStorage
        for _, part in ipairs(path) do
            obj = obj:FindFirstChild(part) or obj:WaitForChild(part, 2)
            if not obj then return nil end
        end
        return require(obj)
    end)
    return ok and result or nil
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
M.BicycleKick = safeRequire({"Modules", "Actions", "BicycleKick"})
M.RainbowFlick = safeRequire({"Modules", "Actions", "RainbowFlick"})
M.Physics = safeRequire({"Modules", "Ball", "Physics"})

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
            Remotes.RainbowFlick = ball:FindFirstChild("RainbowFlick")
        end
        local chars = root:FindFirstChild("Characters")
        if chars then
            Remotes.MovementBoost = chars:FindFirstChild("MovementBoost")
            Remotes.Ragdoll = chars:FindFirstChild("Ragdoll")
        end
    end
end)

-- ============================================================
-- 4. STATE
-- ============================================================
local featureState = {
    -- Movement
    infStamina = false,
    speedMult = 1.0,
    jumpPower = 50,
    sprintBoost = false,
    -- Shot
    perfectShot = false,
    shotCooldown = 1.5,
    curveMode = "OFF",
    chargeSeconds = 0.4,
    -- Dribble
    autoDodge = false,
    dodgeRange = 8,
    dodgeCooldown = 1.0,
    autoRainbow = false,
    -- Goalkeeper
    autoGK = false,
    diveDir = "SMART",
    highBall = false,
    diveRange = 40,
    -- Defense
    autoTackle = false,
    tackleRange = 8,
    tackleCooldown = 1.5,
    -- Misc
    esp = false,
    ballTracker = false,
    teleportToBall = false,
    antiRagdoll = false,
}

-- ============================================================
-- 5. HELPERS
-- ============================================================
-- CRITICAL FIX: SessionId base is *2e6 per log analysis, not 1e6
local sessionCounter = math.floor(workspace:GetServerTimeNow() * 2e6)
local function newSessionId()
    sessionCounter = sessionCounter + 2
    return sessionCounter
end

local function getRoot()
    local char = LP.Character
    if char then return char:FindFirstChild("HumanoidRootPart") end
    return nil
end

local function getHum()
    local char = LP.Character
    if char then return char:FindFirstChildOfClass("Humanoid") end
    return nil
end

local function getCam()
    return workspace.CurrentCamera
end

local function unit(v)
    if v and v.Magnitude > 0.001 then return v.Unit end
    return Vector3.new(0, 0, 1)
end

local function getBallPos()
    local pos = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetPosition then
            pos = M.Renderer.GetPosition()
        end
    end)
    return pos
end

local function getBallOwnerUserId()
    local uid = nil
    pcall(function()
        if M.Renderer and M.Renderer.GetOwnedUserId then
            uid = M.Renderer.GetOwnedUserId()
        end
    end)
    return uid
end

local function getMyTeam()
    local team = nil
    pcall(function()
        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
            team = M.ActorTeams.GetCharacterTeamName(LP.Character)
        end
    end)
    return team
end

-- Find target goal (opposite of our team, using camera direction heuristic)
local function findTargetGoal()
    local root = getRoot()
    if not root then return nil end
    local cam = getCam()
    if not cam then return nil end
    local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
    if flatLook.Magnitude < 0.001 then return nil end
    flatLook = flatLook.Unit

    local best = nil
    local bestScore = -math.huge
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:lower():find("goal") then
            local toGoal = Vector3.new(part.Position.X - root.Position.X, 0, part.Position.Z - root.Position.Z)
            local dist = toGoal.Magnitude
            if dist > 10 and dist < 500 then
                local score = toGoal.Unit:Dot(flatLook) * dist
                if score > bestScore then
                    bestScore = score
                    best = part.Position
                end
            end
        end
    end
    return best
end

-- Find opponent goalkeeper
local function getOpponentKeeperPos()
    local myTeam = getMyTeam()
    if not myTeam then return nil end
    local gkPos = nil
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
                            if hrp then gkPos = hrp.Position; break end
                        end
                    end
                end
            end
        end
    end)
    return gkPos
end

-- Find teammate user id
local function findTeammateUserId()
    local myTeam = getMyTeam()
    if not myTeam then return nil end
    local ballPos = getBallPos()
    if not ballPos then return nil end
    local bestId, bestDist = nil, math.huge
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local sameTeam = false
                    pcall(function()
                        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
                            sameTeam = (M.ActorTeams.GetCharacterTeamName(model) == myTeam)
                        end
                    end)
                    if sameTeam then
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

-- Find nearest opponent within range
local function findNearestOpponent(maxRange)
    local myTeam = getMyTeam()
    if not myTeam then return nil end
    local myRoot = getRoot()
    if not myRoot then return nil end
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
                            if d < bestDist then
                                bestDist = d
                                best = hrp
                            end
                        end
                    end
                end
            end
        end
    end)
    return best, bestDist
end

-- ============================================================
-- 6. COMMAND BUILDERS (with log-verified fixes)
-- ============================================================
local function buildShotStart(targetPos)
    local root = getRoot()
    local ballPos = getBallPos() or Vector3.new(0, 0, 0)
    local cam = getCam()
    local direction = unit(targetPos - ballPos)
    -- CRITICAL FIX: KickDirection is horizontal projection of Direction
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
                Direction = direction,           -- 3D, includes Y
                Origin = ballPos,
                CameraCFrame = cam.CFrame,
                IsAirborne = false,
            },
            PassType = "Shot",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Kind = "Tackle",
            Mode = "Kick",
            KickDirection = flat,                -- horizontal, Y = 0
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
            ChargeStartedAt = startTime,      -- client start time (log shows ~52ms jitter OK)
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
-- 7. FEATURE FUNCTIONS
-- ============================================================
local lastShotTime = 0
local lastDodgeTime = 0
local lastTackleTime = 0
local lastDiveTime = 0
local lastRainbowTime = 0

local function fireAtTarget(targetPos, overrideCurve)
    if not Remotes.Tackle then return false end
    local ballPos = getBallPos()
    if not ballPos then return false end

    local curve = 0
    if overrideCurve then
        curve = overrideCurve
    else
        local gk = getOpponentKeeperPos()
        if gk then
            local goalPos = findTargetGoal()
            if goalPos then
                local lateral = Vector3.new(gk.X - goalPos.X, 0, gk.Z - goalPos.Z)
                if lateral.Magnitude > 0.1 then
                    curve = lateral.Unit:Dot(unit(goalPos - ballPos)) > 0 and -1 or 1
                end
            end
        end
    end

    local startCmd, sid, startTime = buildShotStart(targetPos)
    local ok = pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    if not ok then return false end

    task.wait(featureState.chargeSeconds + 0.02)

    -- Recalculate target direction at release time (log-verified best practice)
    local newBallPos = getBallPos() or ballPos
    local newDir = unit(targetPos - newBallPos)
    local releaseCmd = buildShotRelease(targetPos, sid, startTime, curve)
    pcall(function() Remotes.Tackle:FireServer(releaseCmd) end)
    return true
end

local function firePerfectShot()
    if not Remotes.Tackle then
        pcall(function()
            Rayfield:Notify({Title = "Error", Content = "Tackle remote not found", Duration = 3})
        end)
        return
    end
    local goalPos = findTargetGoal()
    if not goalPos then
        -- fallback: use camera direction 50 studs away
        local cam = getCam()
        local ballPos = getBallPos()
        if not cam or not ballPos then return end
        goalPos = ballPos + cam.CFrame.LookVector * 50
    end
    -- aim at open corner
    local gk = getOpponentKeeperPos()
    local target = goalPos
    if gk then
        local lateral = Vector3.new(gk.X - goalPos.X, 0, gk.Z - goalPos.Z)
        if lateral.Magnitude > 0.1 then
            target = goalPos - lateral.Unit * 8 + Vector3.new(0, 2, 0)
        else
            target = goalPos + Vector3.new(0, 2, 0)
        end
    else
        target = goalPos + Vector3.new(0, 2, 0)
    end

    local curve = nil
    if featureState.curveMode == "LEFT" then curve = -1
    elseif featureState.curveMode == "RIGHT" then curve = 1
    elseif featureState.curveMode == "OFF" then curve = 0 end

    fireAtTarget(target, curve)
end

local function fireFakeShot()
    if not Remotes.Tackle then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local goalPos = findTargetGoal() or (ballPos + Vector3.new(0, 0, 20))
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
    fireAtTarget(wallPos, 0)
end

local function firePerfectPass()
    if not Remotes.Kick then
        pcall(function()
            Rayfield:Notify({Title = "Error", Content = "Kick remote not found", Duration = 3})
        end)
        return
    end
    local root = getRoot(); if not root then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local teammateId = findTeammateUserId()
    if not teammateId then
        pcall(function()
            Rayfield:Notify({Title = "Pass", Content = "No teammate found", Duration = 2})
        end)
        return
    end
    local cam = getCam()
    local cmd = {
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
    }
    pcall(function() Remotes.Kick:FireServer(cmd) end)
end

local function fireRainbowFlick()
    if not Remotes.Tackle then return end
    if tick() - lastRainbowTime < 2 then return end
    lastRainbowTime = tick()
    local root = getRoot(); if not root then return end
    local cam = getCam()
    local dir = unit(cam.CFrame.LookVector)
    local cmd1 = {
        Protocol = "ActionCommand",
        Command = {
            Kind = "RainbowFlick",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root.AssemblyLinearVelocity,
            AimDirection = dir,
        }
    }
    pcall(function() Remotes.Tackle:FireServer(cmd1) end)
    task.wait(0.4)
    local cmd2 = {
        Protocol = "ActionCommand",
        Command = {
            Mode = "RainbowFlickDetach",
            Kind = "Tackle",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root.AssemblyLinearVelocity,
            AimDirection = dir,
        }
    }
    pcall(function() Remotes.Tackle:FireServer(cmd2) end)
end

local function fireBicycleKick()
    if not Remotes.Tackle then return end
    if not (M.BicycleKick and M.BicycleKick.CanBicycleKick) then return end
    local can = false
    pcall(function() can = M.BicycleKick.CanBicycleKick() end)
    if not can then
        pcall(function()
            Rayfield:Notify({Title = "Bicycle", Content = "Cannot bicycle kick right now", Duration = 2})
        end)
        return
    end
    pcall(function() if M.BicycleKick.StartHover then M.BicycleKick.StartHover() end end)
    task.wait(0.1)
    local ballPos = getBallPos(); if not ballPos then return end
    local goalPos = findTargetGoal() or (ballPos + Vector3.new(0, 0, 20))
    fireAtTarget(goalPos, 0)
end

-- ============================================================
-- 8. MAIN LOOP
-- ============================================================
local function mainTick()
    -- Movement
    if featureState.infStamina and M.Sprint and M.Sprint.SetUnlimitedStamina then
        pcall(function() M.Sprint.SetUnlimitedStamina("v6") end)
    end
    if M.Movement and M.Movement.SetMultiplier and LP.Character then
        pcall(function() M.Movement.SetMultiplier(LP.Character, featureState.speedMult) end)
    end
    local hum = getHum()
    if hum then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = featureState.jumpPower
        end)
    end

    -- Perfect Shot Auto
    if featureState.perfectShot and Remotes.Tackle then
        if tick() - lastShotTime >= featureState.shotCooldown then
            local owned = false
            pcall(function()
                if M.Renderer and M.Renderer.GetOwnedUserId then
                    owned = (M.Renderer.GetOwnedUserId() == LP.UserId)
                end
            end)
            if owned then
                local charging = false
                pcall(function()
                    if M.ActionChargeState and M.ActionChargeState.IsCharging then
                        charging = M.ActionChargeState.IsCharging()
                    end
                end)
                if not charging then
                    lastShotTime = tick()
                    task.spawn(function() pcall(firePerfectShot) end)
                end
            end
        end
    end

    -- Auto Dodge
    if featureState.autoDodge and Remotes.Tackle then
        if tick() - lastDodgeTime >= featureState.dodgeCooldown then
            local opp, dist = findNearestOpponent(featureState.dodgeRange)
            if opp then
                local myRoot = getRoot()
                if myRoot then
                    lastDodgeTime = tick()
                    local awayDir = unit(myRoot.Position - opp.Position)
                    pcall(function() Remotes.Tackle:FireServer(buildDodge(awayDir)) end)
                end
            end
        end
    end

    -- Auto Tackle
    if featureState.autoTackle and Remotes.Tackle then
        if tick() - lastTackleTime >= featureState.tackleCooldown then
            local owner = getBallOwnerUserId()
            if owner and owner > 0 and owner ~= LP.UserId then
                local opp, dist = findNearestOpponent(featureState.tackleRange)
                if opp then
                    lastTackleTime = tick()
                    local myRoot = getRoot()
                    if myRoot then
                        local slideDir = unit(opp.Position - myRoot.Position)
                        pcall(function() Remotes.Tackle:FireServer(buildSlide(slideDir)) end)
                    end
                end
            end
        end
    end

    -- Auto Rainbow Flick when we have ball
    if featureState.autoRainbow and Remotes.Tackle then
        if tick() - lastRainbowTime >= 3 then
            local owned = false
            pcall(function()
                if M.Renderer and M.Renderer.GetOwnedUserId then
                    owned = (M.Renderer.GetOwnedUserId() == LP.UserId)
                end
            end)
            if owned then
                task.spawn(function() pcall(fireRainbowFlick) end)
            end
        end
    end

    -- Auto Goalkeeper
    if featureState.autoGK and Remotes.Tackle then
        if tick() - lastDiveTime >= 1.2 then
            local char = LP.Character
            if char then
                local isGK = false
                pcall(function()
                    if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter then
                        isGK = M.MatchSettings.IsGoalkeeperCharacter(char)
                    end
                end)
                if isGK then
                    local ballPos = getBallPos()
                    local root = getRoot()
                    local goalPart = nil
                    pcall(function()
                        if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
                            goalPart = M.PracticeSession.GetDefendedGoalPart()
                        end
                    end)
                    if ballPos and root and goalPart then
                        if (ballPos - goalPart.Position).Magnitude <= featureState.diveRange then
                            local directionName = "F"
                            if featureState.diveDir == "SMART" then
                                local lat = Vector3.new(ballPos.X - goalPart.Position.X, 0, ballPos.Z - goalPart.Position.Z)
                                if lat.Magnitude > 3 then
                                    local myLat = Vector3.new(root.Position.X - goalPart.Position.X, 0, root.Position.Z - goalPart.Position.Z)
                                    directionName = myLat:Dot(lat.Unit) > 0 and "R" or "L"
                                end
                            elseif featureState.diveDir == "LEFT" then directionName = "L"
                            elseif featureState.diveDir == "RIGHT" then directionName = "R"
                            elseif featureState.diveDir == "SIDES" then
                                directionName = (ballPos - goalPart.Position).X > 0 and "R" or "L"
                            end

                            lastDiveTime = tick()
                            local dived = false
                            if M.GoalkeeperDive and M.GoalkeeperDive.Run then
                                pcall(function()
                                    local choice = M.GoalkeeperDive.GetDirectionChoiceByName and M.GoalkeeperDive.GetDirectionChoiceByName(directionName)
                                    if choice then
                                        local basisFn = function() return CFrame.new(goalPart.Position, goalPart.Position + Vector3.new(0, 0, -1)) end
                                        M.GoalkeeperDive.Run(root, getHum(), choice, basisFn, {})
                                        dived = true
                                    end
                                end)
                            end
                            if not dived then
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
                                            DirectionName = directionName,
                                        }
                                    })
                                end)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Anti-Ragdoll (client-side visual reset)
    if featureState.antiRagdoll then
        local char = LP.Character
        if char then
            pcall(function()
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.FallingDown then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end)
        end
    end

    -- Teleport to ball
    if featureState.teleportToBall then
        local ballPos = getBallPos()
        local hrp = getRoot()
        if ballPos and hrp then
            pcall(function() hrp.CFrame = CFrame.new(ballPos + Vector3.new(0, 5, 0)) end)
        end
    end
end

-- ============================================================
-- 9. ESP
-- ============================================================
local espObjects = {}
local function updateESP()
    if not featureState.esp then
        for _, obj in pairs(espObjects) do pcall(function() obj:Destroy() end) end
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
            bb.Size = UDim2.new(0, 120, 0, 40)
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
    for model, obj in pairs(espObjects) do
        if not model.Parent or not model:FindFirstChild("HumanoidRootPart") then
            pcall(function() obj:Destroy() end)
            espObjects[model] = nil
        end
    end
end

-- Ball tracker
local ballBillboard = nil
local function updateBallTracker()
    if not featureState.ballTracker then
        if ballBillboard then
            pcall(function() ballBillboard:Destroy() end)
            ballBillboard = nil
        end
        return
    end
    if not ballBillboard then
        local ballPart = workspace:FindFirstChild("Ball", true)
        if ballPart and ballPart:IsA("BasePart") then
            ballBillboard = Instance.new("BillboardGui")
            ballBillboard.Size = UDim2.new(0, 100, 0, 30)
            ballBillboard.AlwaysOnTop = true
            ballBillboard.Adornee = ballPart
            ballBillboard.Parent = LP.PlayerGui
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "BALL"
            lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
            lbl.TextSize = 14
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = ballBillboard
        end
    end
end

-- ============================================================
-- 10. UI TABS
-- ============================================================
local MovementTab = Window:CreateTab("Movement", 4483362458)
MovementTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Flag = "InfStam",
    Callback = function(v) featureState.infStamina = v end,
})
MovementTab:CreateSlider({
    Name = "Speed Multiplier",
    Range = {1.0, 3.0},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1.0,
    Flag = "SpeedMult",
    Callback = function(v) featureState.speedMult = v end,
})
MovementTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 200},
    Increment = 5,
    Suffix = "",
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(v) featureState.jumpPower = v end,
})

local ShotTab = Window:CreateTab("Shot", 4483362458)
ShotTab:CreateToggle({
    Name = "Perfect Shot (Auto Aim + Fire)",
    CurrentValue = false,
    Flag = "PerfectShot",
    Callback = function(v) featureState.perfectShot = v end,
})
ShotTab:CreateSlider({
    Name = "Shot Cooldown",
    Range = {0.5, 5.0},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "ShotCooldown",
    Callback = function(v) featureState.shotCooldown = v end,
})
ShotTab:CreateDropdown({
    Name = "Curve Mode",
    Options = {"OFF", "LEFT", "RIGHT", "AUTO"},
    CurrentOption = "OFF",
    MultipleOptions = false,
    Flag = "CurveMode",
    Callback = function(opt) featureState.curveMode = opt end,
})
ShotTab:CreateSlider({
    Name = "Charge Seconds",
    Range = {0.1, 0.4},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.4,
    Flag = "ChargeSec",
    Callback = function(v) featureState.chargeSeconds = v end,
})
ShotTab:CreateButton({
    Name = "FAKE SHOT",
    Callback = function() pcall(fireFakeShot) end,
})
ShotTab:CreateButton({
    Name = "WALL SHOT",
    Callback = function() pcall(fireWallShot) end,
})
ShotTab:CreateButton({
    Name = "PERFECT PASS",
    Callback = function() pcall(firePerfectPass) end,
})
ShotTab:CreateButton({
    Name = "BICYCLE KICK",
    Callback = function() pcall(fireBicycleKick) end,
})

local DribbleTab = Window:CreateTab("Dribble", 4483362458)
DribbleTab:CreateToggle({
    Name = "Auto Dodge (Enemy Near)",
    CurrentValue = false,
    Flag = "AutoDodge",
    Callback = function(v) featureState.autoDodge = v end,
})
DribbleTab:CreateSlider({
    Name = "Dodge Range",
    Range = {3, 15},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 8,
    Flag = "DodgeRange",
    Callback = function(v) featureState.dodgeRange = v end,
})
DribbleTab:CreateSlider({
    Name = "Dodge Cooldown",
    Range = {0.3, 3.0},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.0,
    Flag = "DodgeCooldown",
    Callback = function(v) featureState.dodgeCooldown = v end,
})
DribbleTab:CreateToggle({
    Name = "Auto Rainbow Flick (On Possession)",
    CurrentValue = false,
    Flag = "AutoRainbow",
    Callback = function(v) featureState.autoRainbow = v end,
})
DribbleTab:CreateButton({
    Name = "MANUAL RAINBOW FLICK",
    Callback = function() pcall(fireRainbowFlick) end,
})

local GKTab = Window:CreateTab("Goalkeeper", 4483362458)
GKTab:CreateToggle({
    Name = "Auto Goalkeeper",
    CurrentValue = false,
    Flag = "AutoGK",
    Callback = function(v) featureState.autoGK = v end,
})
GKTab:CreateDropdown({
    Name = "Dive Direction",
    Options = {"SMART", "FORWARD", "LEFT", "RIGHT", "SIDES"},
    CurrentOption = "SMART",
    MultipleOptions = false,
    Flag = "DiveDir",
    Callback = function(opt) featureState.diveDir = opt end,
})
GKTab:CreateSlider({
    Name = "Dive Trigger Range",
    Range = {10, 80},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 40,
    Flag = "DiveRange",
    Callback = function(v) featureState.diveRange = v end,
})
GKTab:CreateToggle({
    Name = "High Ball Jumps",
    CurrentValue = false,
    Flag = "HighBall",
    Callback = function(v) featureState.highBall = v end,
})

local DefTab = Window:CreateTab("Defense", 4483362458)
DefTab:CreateToggle({
    Name = "Auto Slide Tackle",
    CurrentValue = false,
    Flag = "AutoTackle",
    Callback = function(v) featureState.autoTackle = v end,
})
DefTab:CreateSlider({
    Name = "Tackle Range",
    Range = {3, 20},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 8,
    Flag = "TackleRange",
    Callback = function(v) featureState.tackleRange = v end,
})
DefTab:CreateSlider({
    Name = "Tackle Cooldown",
    Range = {0.5, 5.0},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "TackleCooldown",
    Callback = function(v) featureState.tackleCooldown = v end,
})

local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateToggle({
    Name = "ESP (Player Labels)",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(v) featureState.esp = v end,
})
MiscTab:CreateToggle({
    Name = "Ball Tracker",
    CurrentValue = false,
    Flag = "BallTracker",
    Callback = function(v) featureState.ballTracker = v end,
})
MiscTab:CreateToggle({
    Name = "Anti-Ragdoll (Client)",
    CurrentValue = false,
    Flag = "AntiRagdoll",
    Callback = function(v) featureState.antiRagdoll = v end,
})
MiscTab:CreateToggle({
    Name = "Teleport to Ball (RISKY)",
    CurrentValue = false,
    Flag = "TPBall",
    Callback = function(v) featureState.teleportToBall = v end,
})
MiscTab:CreateButton({
    Name = "REJOIN SERVER",
    Callback = function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    end,
})
MiscTab:CreateButton({
    Name = "UNLOAD SCRIPT",
    Callback = function()
        pcall(function() Window:Destroy() end)
        _G.FootballAssist = nil
    end,
})

-- ============================================================
-- 11. LOOPS
-- ============================================================
RunService.Heartbeat:Connect(function()
    xpcall(mainTick, function() end)
end)

-- ESP / Tracker at lower frequency
task.spawn(function()
    while true do
        task.wait(0.3)
        xpcall(updateESP, function() end)
        xpcall(updateBallTracker, function() end)
    end
end)

-- ============================================================
-- 12. PUBLIC API
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
    FireBicycleKick = fireBicycleKick,
    Version = "3.0-Rayfield",
}

print("[IS Assist v3] Loaded. SessionId base 2e6. Direction=3D, KickDirection=horizontal.")