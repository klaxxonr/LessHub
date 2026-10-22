--[[
    ⚽ FOOTBALL ULTIMATE ASSIST v5.0 ⚽
    Introspect API'sine göre yeniden yazım.
    - Gerçek modül API'leri (introspect'ten)
    - Her özellik izole
    - Mobile uyumlu
--]]

-- ============================================================
-- 1. SERVİSLER & GÜVENLİK
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui", 10)
assert(PG, "PlayerGui yok")

-- ============================================================
-- 2. MODÜL ÇÖZÜMLEYİCİ
-- ============================================================
local ModuleStatus = {}
local function requireMod(path)
    local obj = RS
    for name in string.gmatch(path, "[^.]+") do
        obj = obj:FindFirstChild(name)
        if not obj then
            ModuleStatus[path] = "MISSING"
            return nil
        end
    end
    local ok, result = pcall(require, obj)
    if ok and type(result) == "table" then
        ModuleStatus[path] = "OK"
        return result
    end
    ModuleStatus[path] = "ERR:" .. tostring(result):sub(1, 40)
    return nil
end

local M = {
    -- Movement & Stamina
    Sprint        = requireMod("Modules.Actions.Sprint"),
    ClientSprint  = requireMod("Client.Gameplay.Player.Sprint"),
    Movement      = requireMod("Client.Gameplay.Player.Movement"),
    Controllers   = requireMod("Modules.Characters.CharacterControllers"),
    Motion        = requireMod("Modules.Characters.CharacterMotion"),
    Grounding     = requireMod("Modules.Characters.Grounding"),
    -- Aim & Shoot
    Reticle       = requireMod("Client.Interface.Reticle"),
    Shoot         = requireMod("Modules.Actions.Shoot"),
    ClientShoot   = requireMod("Client.Gameplay.Actions.Shoot"),
    AimSolver     = requireMod("Modules.Actions.AimSolver"),
    EndpointAim   = requireMod("Modules.Actions.EndpointAim"),
    ShotAimAssist = requireMod("Modules.Actions.ShotAimAssist"),
    KickCore      = requireMod("Modules.Actions.KickCore"),
    -- Goalkeeper
    Dive          = requireMod("Modules.Actions.GoalkeeperDive"),
    DiveAssist    = requireMod("Modules.Actions.GoalkeeperDiveAssist"),
    GKActions     = requireMod("Modules.Actions.GoalkeeperActions"),
    GKPrediction  = requireMod("Modules.Gameplay.GoalkeeperPrediction"),
    GKPositioning = requireMod("Modules.Gameplay.GoalkeeperPositioning"),
    GKRole        = requireMod("Client.Gameplay.Player.GoalkeeperRole"),
    -- Ball
    Physics       = requireMod("Modules.Ball.Physics"),
    Carry         = requireMod("Modules.Ball.Carry"),
    Receiving     = requireMod("Modules.Ball.Receiving"),
    Renderer      = requireMod("Client.Gameplay.Ball.Renderer"),
    -- Dodge / Tackle
    Dodge         = requireMod("Modules.Actions.Dodge"),
    ClientDodge   = requireMod("Client.Gameplay.Actions.Dodge"),
    SlideTackle   = requireMod("Modules.Actions.SlideTackle"),
    SlideInput    = requireMod("Client.Gameplay.Actions.SlideTackleInput"),
    -- Action core
    ActionCmds    = requireMod("Modules.Actions.ActionCommands"),
    Protocol      = requireMod("Modules.Actions.ActionRemoteProtocol"),
    Locks         = requireMod("Modules.Actions.ActionLocks"),
    ChargeState   = requireMod("Modules.Actions.ActionChargeState"),
    RainbowFlick  = requireMod("Modules.Actions.RainbowFlick"),
    BicycleKick   = requireMod("Modules.Actions.BicycleKick"),
    -- Helpers
    Teams         = requireMod("Client.Gameplay.ActorTeams"),
    Match         = requireMod("Modules.Gameplay.MatchSettings"),
    Practice      = requireMod("Client.Gameplay.PracticeSession"),
    Actors        = requireMod("Modules.Characters.Actors"),
    Hitboxes      = requireMod("Modules.Gameplay.HitboxSettings"),
    Keybinds      = requireMod("Modules.Gameplay.Keybinds"),
    Controls      = requireMod("Modules.Gameplay.Controls"),
    LibInput      = requireMod("Libraries.Input"),
}

-- Ball remotes
local RemotesFolder = RS:FindFirstChild("Remotes")
local BallRemotes = RemotesFolder and RemotesFolder:FindFirstChild("Ball")
local TackleRemote = BallRemotes and BallRemotes:FindFirstChild("Tackle")
local StateRemote = BallRemotes and BallRemotes:FindFirstChild("State")

-- ============================================================
-- 3. AYARLAR & DURUM
-- ============================================================
local Settings = {
    -- Movement
    infiniteStamina = false,
    speedMultiplier = 1.0,
    jumpBoost = false,
    -- Aim
    aimAssist = false,
    aimStrength = 1.0,  -- 0..1 (weak..strong)
    -- Auto
    autoShoot = false,
    autoShootRange = 30,
    -- GK
    gkEnabled = false,
    gkDiveDir = "SMART",
    gkHighJumps = true,
    gkPositioning = true,
    -- Tricks
    autoDribble = false,
    -- Debug
    debug = false,
}

local S = {
    alive = true,
    connections = {},
    ui = nil,
    -- Stamina
    staminaApplied = false,
    -- Speed
    speedApplied = false,
    originalSpeedMult = 1,
    -- Aim hook
    originalAimRay = nil,
    aimHookActive = false,
    -- Auto GK
    lastGKPlan = "NONE",
    nextGKPlanAt = 0,
    lastDiveAt = 0,
    lastJumpAt = 0,
    -- Dribble
    tacklePackets = {},
    lastDribbleAt = 0,
    -- Wall fake shot
    wallAimActive = false,
    wallAimDir = nil,
    -- Fake shot
    fakeShotActive = false,
    -- Stats
    stats = {
        dives = 0, jumps = 0, dribbles = 0,
        fakeShots = 0, wallShots = 0, autoShots = 0,
        savedShots = 0,
    },
    lastError = "none",
}

-- ============================================================
-- 4. YARDIMCILAR
-- ============================================================
local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(S.connections, c)
    return c
end

local function log(fmt, ...)
    if Settings.debug then
        print("[FA] " .. string.format(fmt, ...))
    end
end

local function reportError(ctx, err)
    S.lastError = ctx .. ": " .. tostring(err)
    if Settings.debug then warn("[FA] " .. S.lastError) end
end

local function getChar() return LP.Character end
local function getRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function isGK()
    if M.Match and M.Match.IsGoalkeeperCharacter and LP.Character then
        local ok, r = pcall(M.Match.IsGoalkeeperCharacter, LP.Character)
        if ok then return r == true end
    end
    return false
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function v3(v) return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z) end

-- ============================================================
-- 5. TOP OKUMA
-- ============================================================
local function readBall()
    if not M.Renderer then return { phase = "NO_RENDERER" } end
    local okId, ballId = pcall(M.Renderer.GetMatchBallId)
    local okOwner, owner = pcall(M.Renderer.GetOwnedUserId)
    local okState, state, world = pcall(M.Renderer.GetAuthoritativeMovementState)
    
    if okOwner and owner ~= nil then
        return { phase = "OWNED", ballId = ballId, owner = owner }
    end
    if okState and state and world and v3(state.Position) and v3(state.Velocity) then
        return {
            phase = "MOVEMENT", state = state, world = world, ballId = ballId,
        }
    end
    return { phase = "UNAVAILABLE", ballId = ballId }
end

-- ============================================================
-- 6. KALE / TAKIM TESPİTİ
-- ============================================================
local function findGoalAndContext()
    -- Practice mode öncelik
    if M.Practice and M.Practice.IsActive then
        local ok, active = pcall(M.Practice.IsActive)
        if ok and active then
            local ok2, goal = pcall(M.Practice.GetDefendedGoalPart)
            if ok2 and goal and goal:IsA("BasePart") then
                local root = getRoot()
                local forward = root and (goal.Position - root.Position).Unit or Vector3.new(0,0,1)
                forward = flat(forward)
                if forward.Magnitude > 0.001 then forward = forward.Unit end
                return {
                    goal = goal, team = nil, mode = "PRACTICE",
                    forward = forward,
                    right = Vector3.new(-forward.Z, 0, forward.X),
                }
            end
        end
    end
    -- Match mode
    if M.Teams and M.Match then
        local okTeam, myTeam = pcall(M.Teams.GetActorTeamName, LP)
        if okTeam and myTeam then
            local okOpp, oppTeam = pcall(M.Match.GetOpposingTeamName, myTeam)
            if okOpp and oppTeam then
                local map = workspace:FindFirstChild("Map")
                local data = map and map:FindFirstChild("Data")
                local mySide = data and data:FindFirstChild(myTeam)
                local oppSide = data and data:FindFirstChild(oppTeam)
                local goal = mySide and mySide:FindFirstChild("Goal")
                local attack = oppSide and oppSide:FindFirstChild("Goal")
                if goal and goal:IsA("BasePart") then
                    local fwd
                    if attack and attack:IsA("BasePart") then
                        fwd = attack.Position - goal.Position
                    else
                        local root = getRoot()
                        fwd = root and (root.Position - goal.Position) or Vector3.new(0, 0, 1)
                    end
                    fwd = flat(fwd)
                    if fwd.Magnitude > 0.001 then fwd = fwd.Unit end
                    return {
                        goal = goal, team = myTeam, mode = "MATCH",
                        forward = fwd,
                        right = Vector3.new(-fwd.Z, 0, fwd.X),
                    }
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- 7. ÖZELLİK: INFINITE STAMINA
-- ============================================================
local function setInfiniteStamina(on)
    local applied = false
    -- Önce client-facing (görsel için)
    if M.ClientSprint and M.ClientSprint.SetUnlimitedStamina then
        local ok, result = pcall(M.ClientSprint.SetUnlimitedStamina, on)
        if ok and result ~= false then applied = true end
    end
    -- Sonra core (asıl mantık)
    if M.Sprint then
        if on then
            if M.Sprint.SetUnlimitedStamina then
                -- Muhtemel iki imza: (source), (source, value), (bool)
                local ok1 = pcall(M.Sprint.SetUnlimitedStamina, "UniversalAssist")
                if not ok1 then
                    pcall(M.Sprint.SetUnlimitedStamina, true)
                end
                applied = true
            end
        else
            if M.Sprint.ClearUnlimitedStaminaSource then
                pcall(M.Sprint.ClearUnlimitedStaminaSource, "UniversalAssist")
            end
        end
    end
    S.staminaApplied = applied
    log("Infinite stamina %s (applied=%s)", on and "ON" or "OFF", tostring(applied))
    return applied
end

-- ============================================================
-- 8. ÖZELLİK: SPEED / JUMP BOOST
-- ============================================================
local function applySpeed()
    if not M.Movement or not M.Movement.SetMultiplier then return false end
    local char = getChar()
    if not char then return false end
    if Settings.speedMultiplier == 1.0 then
        pcall(M.Movement.SetMultiplier, char, 1.0)
        S.speedApplied = false
        return true
    end
    local ok, result = pcall(M.Movement.SetMultiplier, char, Settings.speedMultiplier)
    S.speedApplied = ok and result ~= false
    return S.speedApplied
end

-- ============================================================
-- 9. ÖZELLİK: AIM ASSIST (Reticle hook)
-- ============================================================
local function installAimHook()
    if not M.Reticle or not M.Reticle.GetCameraAimRayWithoutHit then
        log("Aim hook: Reticle missing")
        return false
    end
    if S.aimHookActive then return true end
    
    local orig = M.Reticle.GetCameraAimRayWithoutHit
    S.originalAimRay = orig
    
    local function hooked(...)
        local sample = orig(...)
        if not S.alive then return sample end
        
        -- Wall fake shot için özel aim
        if S.wallAimActive and S.wallAimDir then
            return {
                Origin = sample.Origin,
                Direction = S.wallAimDir,
                CameraCFrame = sample.CameraCFrame or CFrame.new(sample.Origin),
            }
        end
        
        -- Normal aim assist
        if not Settings.aimAssist then return sample end
        if not M.ShotAimAssist or not M.ShotAimAssist.GetAssistedDirection then return sample end
        
        -- Sadece top bize aitken veya yakınken
        local ball = readBall()
        if ball.phase ~= "OWNED" or ball.owner ~= LP.UserId then
            -- Volley veya pas için de çalış
            local char = getChar()
            if not char then return sample end
        end
        
        -- ShotAimAssist kullan (oyunun kendi fizik-temelli aim assist'i)
        local goalCtx = findGoalAndContext()
        if not goalCtx then return sample end
        
        local ok, assisted = pcall(function()
            return M.ShotAimAssist.GetAssistedDirection(
                LP, sample, goalCtx.goal, Settings.aimStrength
            )
        end)
        if ok and assisted then return assisted end
        
        return sample
    end
    
    local ok = pcall(function() M.Reticle.GetCameraAimRayWithoutHit = hooked end)
    S.aimHookActive = ok
    log("Aim hook: %s", ok and "installed" or "failed")
    return ok
end

local function uninstallAimHook()
    if not S.aimHookActive or not M.Reticle or not S.originalAimRay then return end
    pcall(function() M.Reticle.GetCameraAimRayWithoutHit = S.originalAimRay end)
    S.aimHookActive = false
    S.originalAimRay = nil
end

-- ============================================================
-- 10. ÖZELLİK: AUTO GK
-- ============================================================
local GK = {
    constants = (M.Dive and M.Dive.Constants) or {
        Distance = 20, InitialVerticalVelocity = 15,
        GravityStudsPerSecondSquared = -65, HitboxCurveSeconds = 0.6,
        MaximumSaveHeight = 7.75, RepeatDelaySeconds = 1.875,
    },
    predictionHorizon = 1.1,
    goalMargin = 0.05,
}

local function buildFrame()
    local char = getChar()
    local root = getRoot()
    local hum = getHum()
    if not char or not root or not hum or hum.Health <= 0 then return nil end
    
    local ball = readBall()
    if ball.phase ~= "MOVEMENT" then return nil end
    
    local ctx = findGoalAndContext()
    if not ctx then return nil end
    
    -- Predict at current time
    local at = workspace:GetServerTimeNow()
    local current = ball.state
    if M.Physics and M.Physics.GetStateAtTime and ball.world then
        local ok, s = pcall(M.Physics.GetStateAtTime, ball.state, at, ball.world, {})
        if ok and s and v3(s.Position) then current = s end
    end
    
    -- Goal crossing prediction
    local goalPos, goalTime
    if M.GKPrediction and M.GKPrediction.GetGoalCrossing then
        local ok, pos, t = pcall(M.GKPrediction.GetGoalCrossing,
            current, ball.world, ctx.goal, at,
            M.GKPrediction.Constants and M.GKPrediction.Constants.GoalCrossingMaximumPredictionSeconds or 5)
        if ok then goalPos, goalTime = pos, t end
    end
    
    local eta = goalPos and finite(goalTime) and (goalTime - at) or nil
    
    return {
        char = char, root = root, hum = hum,
        rootCF = root.CFrame, velocity = root.AssemblyLinearVelocity,
        at = at, state = current, world = ball.world,
        context = ctx, ballId = ball.ballId,
        goalPos = goalPos, goalTime = goalTime, eta = eta,
        radius = current.Radius or 1,
    }
end

local function getDiveDirections()
    local filter = Settings.gkDiveDir
    if filter == "FORWARD" then return { "F" } end
    if filter == "LEFT" then return { "L", "LF" } end
    if filter == "RIGHT" then return { "R", "RF" } end
    if filter == "SIDES" then return { "L", "R", "LF", "RF" } end
    return { "F", "L", "R", "LF", "RF" }
end

local function tryDivePlan(frame, dirName, delay)
    if not M.Dive or not M.Dive.GetDirectionChoiceByName then return nil end
    local ok, choice = pcall(M.Dive.GetDirectionChoiceByName, dirName)
    if not ok or not choice then return nil end
    
    local basis = CFrame.lookAt(frame.rootCF.Position, frame.rootCF.Position + frame.context.forward)
    local ok2, worldDir = pcall(M.Dive.GetWorldDirection, choice, basis, frame.context.forward)
    if not ok2 or not v3(worldDir) then return nil end
    
    -- Simulate trajectory and check contact
    local horizon = math.min(frame.eta - GK.goalMargin, GK.constants.HitboxCurveSeconds + delay + 0.2)
    if horizon <= 0.001 then return nil end
    
    local c = GK.constants
    local prevBall = frame.state.Position
    local prevRoot = frame.rootCF
    local t = 0
    local step = 0.02
    
    while t < horizon do
        t = t + step
        local elapsed = math.max(0, t - delay)
        
        -- Ball position
        local ballAt
        if M.Physics.GetStateAtTime and frame.world then
            local okB, s = pcall(M.Physics.GetStateAtTime, frame.state, frame.at + t, frame.world, {})
            if okB and s and v3(s.Position) then ballAt = s end
        end
        if not ballAt then
            ballAt = { Position = frame.state.Position + frame.state.Velocity * t, Radius = frame.radius }
        end
        
        -- Root position (dive motion)
        local travel = math.min(elapsed * c.Distance / 0.6, c.Distance)
        local rise = c.InitialVerticalVelocity * elapsed + 0.5 * c.GravityStudsPerSecondSquared * elapsed * elapsed
        rise = math.max(0, rise)
        local rootPos = frame.rootCF.Position + worldDir * travel + Vector3.new(0, rise, 0)
        local rootCF = CFrame.lookAt(rootPos, rootPos + worldDir)
        
        -- Contact check via GoalkeeperActions
        if M.GKActions and M.GKActions.FindDiveSaveContact then
            local ok3, hit = pcall(M.GKActions.FindDiveSaveContact, LP,
                prevBall, ballAt.Position,
                { StartRootCFrame = prevRoot, EndRootCFrame = rootCF, BallRadius = frame.radius })
            if ok3 and hit then
                return {
                    kind = "DIVE", dirName = dirName, choice = choice,
                    basis = basis, worldDir = worldDir, delay = delay,
                    contactTime = t,
                    score = t + delay * 0.4,
                }
            end
        end
        
        -- Fallback: hitbox check
        if M.Hitboxes and M.Hitboxes.GetSegmentEnterAlpha and M.Hitboxes.GoalkeeperAirReceive then
            local ok4, alpha = pcall(M.Hitboxes.GetSegmentEnterAlpha,
                { CFrame = rootCF }, M.Hitboxes.GoalkeeperAirReceive,
                prevBall, ballAt.Position)
            if ok4 and type(alpha) == "number" and alpha >= 0 and alpha <= 1 then
                return {
                    kind = "DIVE", dirName = dirName, choice = choice,
                    basis = basis, worldDir = worldDir, delay = delay,
                    contactTime = t,
                    score = t + delay * 0.4,
                }
            end
        end
        
        prevBall = ballAt.Position
        prevRoot = rootCF
    end
    return nil
end

local function planGK(frame)
    if not frame or not frame.eta then return nil end
    if frame.eta > GK.predictionHorizon then return nil end
    
    local candidates = {}
    for _, dirName in ipairs(getDiveDirections()) do
        local p = tryDivePlan(frame, dirName, 0)
        if p then table.insert(candidates, p) end
    end
    if #candidates == 0 then
        for _, delay in ipairs({ 0.08, 0.15, 0.25 }) do
            for _, dirName in ipairs(getDiveDirections()) do
                local p = tryDivePlan(frame, dirName, delay)
                if p then table.insert(candidates, p) end
            end
        end
    end
    if #candidates == 0 then return nil end
    table.sort(candidates, function(a, b) return a.score < b.score end)
    return candidates[1]
end

local function executeDive(frame, plan)
    if not M.Dive or not M.Dive.Run then
        reportError("DIVE", "Dive.Run missing")
        return false
    end
    
    local now = os.clock()
    if now - S.lastDiveAt < (GK.constants.RepeatDelaySeconds or 1.875) then return false end
    if plan.delay > 0.05 then return false end  -- Only execute immediate plans
    
    S.lastDiveAt = now
    
    -- Start dive
    local ok, err = pcall(function()
        local controller = M.Dive.Run(frame.root, frame.hum, plan.choice,
            function() return plan.basis end,
            { Assist = nil, StartedAt = frame.at })
        if not controller then error("Dive controller nil") end
    end)
    if not ok then
        reportError("DIVE_RUN", err)
        return false
    end
    
    -- Send command via protocol
    if M.ActionCmds and M.ActionCmds.GoalkeeperDive and M.Protocol and M.Protocol.Send then
        local ok2, err2 = pcall(function()
            local motion
            if M.Dive.GetMotionSample then
                local okM, m = pcall(M.Dive.GetMotionSample, frame.root)
                if okM then motion = m end
            end
            local cmd = M.ActionCmds.GoalkeeperDive({
                AimDirection = plan.worldDir,
                DirectionName = plan.dirName,
                DiveMotion = motion,
                ShotTime = frame.at,
            })
            M.Protocol.Send(cmd)
        end)
        if not ok2 then reportError("DIVE_SEND", err2) end
    end
    
    -- Presentation
    if M.GKRole and M.GKRole.Dive then
        pcall(M.GKRole.Dive)
    end
    
    S.stats.dives = S.stats.dives + 1
    S.lastGKPlan = plan.dirName .. (plan.delay > 0 and ("@" .. plan.delay) or "")
    return true
end

local function isBlocked()
    if not M.Controllers then return false end
    local char = getChar()
    if not char then return true end
    local ok, susp = pcall(M.Controllers.IsSuspended, char)
    if ok and susp then return true end
    if M.Locks and M.Locks.HasGoalkeeperDiveBlock then
        local ok2, blocked = pcall(M.Locks.HasGoalkeeperDiveBlock, LP, nil)
        if ok2 and blocked then return true end
    end
    return false
end

-- Position assist (basit)
local function gkPositioning(frame, dt)
    if not Settings.gkPositioning then return end
    if not frame or not frame.context then return end
    
    local c = frame.context
    local origin = c.goal.Position
    local halfWidth = (M.GKPositioning and M.GKPositioning.Constants and M.GKPositioning.Constants.GoalHalfWidth) or 21
    
    -- Kalenin merkezine doğru pozisyon al, topa göre lateral ayarla
    local ballOffset = flat(frame.state.Position - origin)
    local lateral = ballOffset:Dot(c.right)
    lateral = math.clamp(lateral * 0.3, -halfWidth + 3, halfWidth - 3)
    
    local depth = (M.GKPositioning and M.GKPositioning.Constants and M.GKPositioning.Constants.GoalDepth) or 8
    local targetPos = origin + c.forward * depth + c.right * lateral
    
    local root = frame.root
    local delta = flat(targetPos - root.Position)
    if delta.Magnitude < 1 then return end
    
    -- SetMoveCommand kullan (WalkSpeed değil)
    if M.Controllers and M.Controllers.SetMoveCommand then
        local desired = delta.Unit * math.min(1, delta.Magnitude / 4)
        pcall(M.Controllers.SetMoveCommand, frame.char, desired)
    end
end

-- ============================================================
-- 11. ÖZELLİK: AUTO DRIBBLE
-- ============================================================
-- Tackle paketlerini dinle
if TackleRemote then
    connect(TackleRemote.OnClientEvent, function(packet)
        if not S.alive then return end
        if typeof(packet) ~= "table" then return end
        -- Farklı formatları tolere et
        local actorId = packet.ActorUserId
            or (packet.Command and packet.Command.ActorUserId)
            or (packet.Command and packet.Command.UserId)
        local mode = packet.Mode or (packet.Command and packet.Command.Mode)
        if not actorId or actorId == LP.UserId then return end
        if mode ~= "Tackle" and mode ~= "SlideTackle" then return end
        
        S.tacklePackets[actorId] = {
            at = workspace:GetServerTimeNow(),
            direction = packet.AimDirection or (packet.Command and packet.Command.AimDirection),
        }
    end)
end

local function tryAutoDribble()
    if not Settings.autoDribble then return end
    if not M.ClientDodge or not M.ClientDodge.HandleInputBegan then return end
    
    local now = workspace:GetServerTimeNow()
    local nowClock = os.clock()
    if nowClock - S.lastDribbleAt < 1.0 then return end
    
    -- Ball bizde mi?
    local ball = readBall()
    if ball.phase ~= "OWNED" or ball.owner ~= LP.UserId then return end
    
    -- Dribbling zaten aktif mi?
    if M.Dodge and M.Dodge.IsDribbling then
        local ok, isD = pcall(M.Dodge.IsDribbling)
        if ok and isD then return end
    end
    
    local char = getChar()
    local root = getRoot()
    if not char or not root then return end
    
    -- Yakında tehdit var mı?
    local myPos = root.Position
    for actorId, info in pairs(S.tacklePackets) do
        local age = now - info.at
        if age > 1.2 then
            S.tacklePackets[actorId] = nil
        else
            local actor = M.Actors and M.Actors.GetByUserId and M.Actors.GetByUserId(actorId)
            local otherChar = actor and actor.Character
            local otherRoot = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
            if otherRoot and (otherRoot.Position - myPos).Magnitude < 8 then
                -- Dribble!
                local fakeInput = Instance.new("InputObject")
                fakeInput.UserInputType = Enum.UserInputType.MouseButton1
                fakeInput.UserInputState = Enum.UserInputState.Begin
                fakeInput.KeyCode = Enum.KeyCode.Unknown
                
                local ok = pcall(M.ClientDodge.HandleInputBegan, fakeInput, false)
                if ok then
                    S.stats.dribbles = S.stats.dribbles + 1
                    S.lastDribbleAt = nowClock
                    return
                end
            end
        end
    end
end

-- ============================================================
-- 12. ÖZELLİK: FAKE SHOT
-- ============================================================
local function triggerFakeShot()
    if not M.ClientShoot or not M.ClientShoot.HandleInputBegan then
        return false, "Shoot module yok"
    end
    
    if M.ClientShoot.IsCharging then
        local ok, charging = pcall(M.ClientShoot.IsCharging)
        if ok and charging then return false, "Zaten şarj" end
    end
    
    task.spawn(function()
        local fakeInput = Instance.new("InputObject")
        fakeInput.UserInputType = Enum.UserInputType.MouseButton1
        fakeInput.UserInputState = Enum.UserInputState.Begin
        fakeInput.KeyCode = Enum.KeyCode.Unknown
        
        local ok1 = pcall(M.ClientShoot.HandleInputBegan, fakeInput, false, nil)
        if not ok1 then
            reportError("FAKESHOT_START", "HandleInputBegan failed")
            return
        end
        
        -- Kısa şarj (gerçek gibi görünsün)
        task.wait(0.18)
        
        -- İptal
        if M.ClientShoot.CancelCharge then
            local ok2 = pcall(M.ClientShoot.CancelCharge)
            if not ok2 then
                reportError("FAKESHOT_CANCEL", "CancelCharge failed")
            end
        elseif M.ClientShoot.HandleInputEnded then
            -- Fallback: bırak
            pcall(M.ClientShoot.HandleInputEnded, fakeInput)
        end
        
        S.stats.fakeShots = S.stats.fakeShots + 1
    end)
    return true
end

-- ============================================================
-- 13. ÖZELLİK: WALL FAKE SHOT
-- ============================================================
local function findNearestWall(maxDist)
    maxDist = maxDist or 60
    local map = workspace:FindFirstChild("Map")
    local data = map and map:FindFirstChild("Data")
    local walls = data and data:FindFirstChild("Walls")
    if not walls then return nil end
    
    local root = getRoot()
    if not root then return nil end
    
    local nearest, nearestDist = nil, maxDist
    for _, part in ipairs(walls:GetDescendants()) do
        if part:IsA("BasePart") then
            local d = (part.Position - root.Position).Magnitude
            if d < nearestDist then
                nearest, nearestDist = part, d
            end
        end
    end
    return nearest
end

local function triggerWallFakeShot()
    if not M.ClientShoot or not M.ClientShoot.HandleInputBegan then
        return false, "Shoot module yok"
    end
    
    local wall = findNearestWall()
    if not wall then return false, "Yakında duvar yok" end
    
    local root = getRoot()
    if not root then return false, "Karakter yok" end
    
    -- Aim direction hesapla
    local aimDir = (wall.Position - root.Position).Unit
    S.wallAimDir = aimDir
    S.wallAimActive = true
    
    task.spawn(function()
        local fakeInput = Instance.new("InputObject")
        fakeInput.UserInputType = Enum.UserInputType.MouseButton1
        fakeInput.UserInputState = Enum.UserInputState.Begin
        fakeInput.KeyCode = Enum.KeyCode.Unknown
        
        local ok1 = pcall(M.ClientShoot.HandleInputBegan, fakeInput, false, nil)
        if not ok1 then
            S.wallAimActive = false
            S.wallAimDir = nil
            reportError("WALL_START", "HandleInputBegan failed")
            return
        end
        
        -- Tam şarj bekle (duvar sekmesi için güçlü şut)
        task.wait(0.45)
        
        -- Bırak (şut ateşle)
        if M.ClientShoot.HandleInputEnded then
            pcall(M.ClientShoot.HandleInputEnded, fakeInput)
        elseif M.ClientShoot.CancelCharge then
            pcall(M.ClientShoot.CancelCharge)
        end
        
        -- Aim'i sıfırla
        task.wait(0.25)
        S.wallAimActive = false
        S.wallAimDir = nil
        S.stats.wallShots = S.stats.wallShots + 1
    end)
    return true
end

-- Safety timeout
task.delay(3, function()
    S.wallAimActive = false
    S.wallAimDir = nil
end)

-- ============================================================
-- 14. ÖZELLİK: AUTO SHOOT (basit)
-- ============================================================
local function tryAutoShoot()
    if not Settings.autoShoot then return end
    if not M.ClientShoot or not M.ClientShoot.HandleInputBegan then return end
    
    local ball = readBall()
    if ball.phase ~= "OWNED" or ball.owner ~= LP.UserId then return end
    
    if M.ClientShoot.IsCharging then
        local ok, c = pcall(M.ClientShoot.IsCharging)
        if ok and c then return end
    end
    
    local root = getRoot()
    local ctx = findGoalAndContext()
    if not root or not ctx then return end
    
    local dist = (ctx.goal.Position - root.Position).Magnitude
    if dist > Settings.autoShootRange then return end
    
    -- Full charge + release
    task.spawn(function()
        local fakeInput = Instance.new("InputObject")
        fakeInput.UserInputType = Enum.UserInputType.MouseButton1
        fakeInput.UserInputState = Enum.UserInputState.Begin
        
        pcall(M.ClientShoot.HandleInputBegan, fakeInput, false, nil)
        task.wait(0.42)  -- full charge
        if M.ClientShoot.HandleInputEnded then
            pcall(M.ClientShoot.HandleInputEnded, fakeInput)
        end
        S.stats.autoShots = S.stats.autoShots + 1
    end)
end

-- ============================================================
-- 15. ANA DÖNGÜ
-- ============================================================
local gkBusy = false
connect(RunService.Heartbeat, function(dt)
    if not S.alive then return end
    
    -- Infinite stamina uygula (bir kez)
    if Settings.infiniteStamina and not S.staminaApplied then
        setInfiniteStamina(true)
    elseif not Settings.infiniteStamina and S.staminaApplied then
        setInfiniteStamina(false)
    end
    
    -- Speed
    if S.speedApplied or Settings.speedMultiplier ~= 1.0 then
        applySpeed()
    end
    
    -- Auto dribble
    pcall(tryAutoDribble)
    
    -- Auto shoot
    if Settings.autoShoot then
        pcall(tryAutoShoot)
    end
    
    -- Auto GK
    if Settings.gkEnabled and not gkBusy then
        gkBusy = true
        local ok, err = xpcall(function()
            if not isGK() then return end
            if isBlocked() then return end
            
            local frame = buildFrame()
            if not frame then return end
            
            -- Too far?
            if not frame.eta or frame.eta <= 0 then
                gkPositioning(frame, dt)
                return
            end
            if frame.eta > GK.predictionHorizon then
                gkPositioning(frame, dt)
                return
            end
            
            -- Plan save
            local now = os.clock()
            if now < S.nextGKPlanAt then return end
            S.nextGKPlanAt = now + 1 / 15  -- 15 Hz planning
            
            local plan = planGK(frame)
            if plan then
                executeDive(frame, plan)
            else
                S.lastGKPlan = "NO_PLAN"
                gkPositioning(frame, dt)
            end
        end, debug.traceback)
        gkBusy = false
        if not ok then reportError("GK_TICK", err) end
    end
end)

-- ============================================================
-- 16. UI
-- ============================================================
local C = {
    bg = Color3.fromRGB(16, 16, 15),
    surface = Color3.fromRGB(24, 24, 22),
    control = Color3.fromRGB(32, 32, 29),
    hover = Color3.fromRGB(42, 40, 32),
    text = Color3.fromRGB(242, 243, 240),
    muted = Color3.fromRGB(160, 160, 155),
    accent = Color3.fromRGB(222, 193, 115),
    accentDim = Color3.fromRGB(131, 111, 61),
    active = Color3.fromRGB(50, 45, 30),
    danger = Color3.fromRGB(200, 70, 70),
    success = Color3.fromRGB(90, 180, 90),
}

local function new(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

local function round(obj, r)
    new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, obj)
    return obj
end

local function addStroke(obj, color, thickness)
    new("UIStroke", {
        Color = color or C.accentDim, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

local function makeFrame(parent, props)
    local p = { BackgroundColor3 = C.surface, BorderSizePixel = 0 }
    for k, v in pairs(props) do p[k] = v end
    return new("Frame", p, parent)
end

local function makeText(parent, text, size, props)
    local p = {
        Text = text, TextSize = size or 12,
        Font = Enum.Font.GothamMedium, TextColor3 = C.text,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
    }
    for k, v in pairs(props or {}) do p[k] = v end
    return new("TextLabel", p, parent)
end

local function makeButton(parent, props)
    local p = {
        Text = "", TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.text, BackgroundColor3 = C.control,
        BorderSizePixel = 0, AutoButtonColor = false,
    }
    for k, v in pairs(props) do p[k] = v end
    return round(new("TextButton", p, parent), 5)
end

-- Global refs for refresh
local UI = { toggles = {}, labels = {}, tabs = {}, activeTab = "Movement" }

local function buildUI()
    local gui = new("ScreenGui", {
        Name = "FootballAssistUI", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PG)
    S.ui = gui
    
    local host = new("Frame", {
        Name = "Host", Position = UDim2.fromOffset(15, 80),
        Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1,
    }, gui)
    
    local panel = round(makeFrame(host, {
        Size = UDim2.fromOffset(340, 520),
        BackgroundColor3 = C.bg,
    }), 10)
    addStroke(panel, C.accentDim)
    panel.Active = true
    
    local uiScale = new("UIScale", { Scale = 1 }, panel)
    
    -- Header
    local header = makeFrame(panel, {
        Size = UDim2.fromOffset(340, 46),
        BackgroundColor3 = C.surface,
    })
    round(header, 10)
    
    makeText(header, "⚽ Football Assist v5.0", 14, {
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.fromOffset(240, 20),
        Font = Enum.Font.GothamBold, TextColor3 = C.accent,
    })
    
    local minimize = makeButton(header, {
        Text = "−", TextSize = 18,
        Position = UDim2.new(1, -76, 0, 10),
        Size = UDim2.fromOffset(28, 26),
    })
    local close = makeButton(header, {
        Text = "×", TextSize = 16,
        Position = UDim2.new(1, -42, 0, 10),
        Size = UDim2.fromOffset(28, 26),
        BackgroundColor3 = Color3.fromRGB(60, 30, 30),
    })
    
    -- Tabs
    local tabBar = makeFrame(panel, {
        Position = UDim2.fromOffset(10, 54),
        Size = UDim2.fromOffset(320, 30),
        BackgroundTransparency = 1,
    })
    
    local tabList = { "Movement", "Aim", "Tricks", "GK", "Debug" }
    local tabPanels = {}
    local tabButtons = {}
    local tabWidth = 320 / #tabList - 4
    
    local function selectTab(name)
        UI.activeTab = name
        for n, p in pairs(tabPanels) do p.Visible = (n == name) end
        for n, b in pairs(tabButtons) do
            local lb = b:FindFirstChild("L")
            if lb then lb.TextColor3 = (n == name) and C.accent or C.muted end
            b.BackgroundColor3 = (n == name) and C.active or C.control
        end
    end
    
    for i, name in ipairs(tabList) do
        local btn = makeButton(tabBar, {
            Position = UDim2.fromOffset((i-1)*(tabWidth+4), 0),
            Size = UDim2.fromOffset(tabWidth, 30),
        })
        makeText(btn, name, 10, {
            Name = "L", Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
        })
        tabButtons[name] = btn
        btn.Activated:Connect(function() selectTab(name) end)
    end
    
    -- Content host
    local contentHost = makeFrame(panel, {
        Position = UDim2.fromOffset(10, 92),
        Size = UDim2.fromOffset(320, 380),
        BackgroundTransparency = 1,
    })
    
    for _, name in ipairs(tabList) do
        local sf = new("ScrollingFrame", {
            Name = name,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.accentDim,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = (name == "Movement"),
        }, contentHost)
        new("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, sf)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
        }, sf)
        tabPanels[name] = sf
    end
    
    local order = { Movement = 0, Aim = 0, Tricks = 0, GK = 0, Debug = 0 }
    
    local function sectionTitle(tab, title)
        order[tab] = order[tab] + 1
        makeText(tabPanels[tab], title, 10, {
            Size = UDim2.new(1, 0, 0, 20),
            LayoutOrder = order[tab],
            Font = Enum.Font.GothamBold,
            TextColor3 = C.muted,
        })
    end
    
    local function addToggle(tab, label, getter, setter)
        order[tab] = order[tab] + 1
        local row = makeButton(tabPanels[tab], {
            Size = UDim2.new(1, 0, 0, 34),
            LayoutOrder = order[tab],
        })
        makeText(row, label, 11, {
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -60, 1, 0),
        })
        local box = makeFrame(row, {
            Position = UDim2.new(1, -30, 0, 8),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = getter() and C.accent or C.control,
        })
        round(box, 4)
        addStroke(box, C.accentDim)
        
        local function refresh()
            box.BackgroundColor3 = getter() and C.accent or C.control
        end
        
        row.Activated:Connect(function()
            local ok, err = pcall(setter, not getter())
            if not ok then reportError("TOGGLE", err) end
            refresh()
        end)
        row.MouseEnter:Connect(function() row.BackgroundColor3 = C.hover end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = C.control end)
        
        table.insert(UI.toggles, refresh)
        return refresh
    end
    
    local function addSlider(tab, label, min, max, getter, setter)
        order[tab] = order[tab] + 1
        local row = makeFrame(tabPanels[tab], {
            Size = UDim2.new(1, 0, 0, 52),
            LayoutOrder = order[tab],
            BackgroundColor3 = C.control,
        })
        round(row, 5)
        local lbl = makeText(row, label .. ": " .. tostring(getter()), 10, {
            Position = UDim2.fromOffset(12, 4),
            Size = UDim2.new(1, -24, 0, 18),
        })
        local track = makeFrame(row, {
            Position = UDim2.fromOffset(12, 28),
            Size = UDim2.new(1, -24, 0, 8),
            BackgroundColor3 = C.accentDim,
        })
        round(track, 4)
        local fill = makeFrame(track, {
            Size = UDim2.new((getter()-min)/(max-min), 0, 1, 0),
            BackgroundColor3 = C.accent,
        })
        round(fill, 4)
        
        local dragging = false
        local function setFromX(x)
            local w = track.AbsoluteSize.X
            if w <= 0 then return end
            local rel = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
            local val = min + rel * (max - min)
            setter(val)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = label .. ": " .. string.format("%.2f", val)
        end
        
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                setFromX(input.Position.X)
            end
        end)
        connect(UIS.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                setFromX(input.Position.X)
            end
        end)
        connect(UIS.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end
    
    local function addActionButton(tab, label, callback, danger)
        order[tab] = order[tab] + 1
        local btn = makeButton(tabPanels[tab], {
            Text = label, TextSize = 11,
            Size = UDim2.new(1, 0, 0, 34),
            LayoutOrder = order[tab],
            BackgroundColor3 = danger and C.danger or C.control,
        })
        btn.Activated:Connect(function()
            local ok, err = pcall(callback)
            if not ok then reportError("ACTION", err) end
        end)
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = C.hover end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = danger and C.danger or C.control
        end)
    end
    
    -- === MOVEMENT TAB ===
    sectionTitle("Movement", "MOVEMENT")
    addToggle("Movement", "Infinite Stamina", function() return Settings.infiniteStamina end, function(v)
        Settings.infiniteStamina = v
        setInfiniteStamina(v)
    end)
    addSlider("Movement", "Speed Multiplier", 1, 3, function() return Settings.speedMultiplier end, function(v)
        Settings.speedMultiplier = v
        applySpeed()
    end)
    addToggle("Movement", "Jump Boost", function() return Settings.jumpBoost end, function(v)
        Settings.jumpBoost = v
        local char = getChar()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v and 100 or 50 end
    end)
    
    -- === AIM TAB ===
    sectionTitle("Aim", "AIM")
    addToggle("Aim", "Aim Assist", function() return Settings.aimAssist end, function(v)
        Settings.aimAssist = v
        if v then installAimHook() else uninstallAimHook() end
    end)
    addSlider("Aim", "Aim Strength", 0.2, 1.0, function() return Settings.aimStrength end, function(v)
        Settings.aimStrength = v
    end)
    sectionTitle("Aim", "AUTO SHOOT")
    addToggle("Aim", "Auto Shoot", function() return Settings.autoShoot end, function(v)
        Settings.autoShoot = v
    end)
    addSlider("Aim", "Shoot Range", 10, 60, function() return Settings.autoShootRange end, function(v)
        Settings.autoShootRange = v
    end)
    
    -- === TRICKS TAB ===
    sectionTitle("Tricks", "ACTIONS")
    addActionButton("Tricks", "🎭 Fake Shot", function()
        local ok, msg = triggerFakeShot()
        if not ok then warn("[FA] Fake shot: " .. tostring(msg)) end
    end)
    addActionButton("Tricks", "🧱 Wall Fake Shot", function()
        local ok, msg = triggerWallFakeShot()
        if not ok then warn("[FA] Wall shot: " .. tostring(msg)) end
    end)
    sectionTitle("Tricks", "AUTO")
    addToggle("Tricks", "Auto Dribble", function() return Settings.autoDribble end, function(v)
        Settings.autoDribble = v
    end)
    
    -- === GK TAB ===
    sectionTitle("GK", "GOALKEEPER")
    addToggle("GK", "Auto Goalkeeper", function() return Settings.gkEnabled end, function(v)
        Settings.gkEnabled = v
        if v then installAimHook() end
    end)
    addToggle("GK", "Position Assist", function() return Settings.gkPositioning end, function(v)
        Settings.gkPositioning = v
    end)
    addToggle("GK", "High Ball Jumps", function() return Settings.gkHighJumps end, function(v)
        Settings.gkHighJumps = v
    end)
    
    -- === DEBUG TAB ===
    sectionTitle("Debug", "MODULE STATUS")
    local debugList = makeFrame(tabPanels["Debug"], {
        Size = UDim2.new(1, 0, 0, 300),
        BackgroundColor3 = C.control,
        LayoutOrder = 1,
    })
    round(debugList, 5)
    local debugText = makeText(debugList, "", 9, {
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 1, -20),
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Code, TextColor3 = C.muted,
    })
    
    local function refreshDebug()
        local lines = {}
        for path, status in pairs(ModuleStatus) do
            local icon = status == "OK" and "✓" or "✗"
            lines[#lines+1] = icon .. " " .. path:sub(-35) .. " [" .. status .. "]"
        end
        table.sort(lines)
        lines[#lines+1] = ""
        lines[#lines+1] = "── STATE ──"
        lines[#lines+1] = "GK: " .. (Settings.gkEnabled and "ON" or "OFF")
        lines[#lines+1] = "Last GK Plan: " .. S.lastGKPlan
        lines[#lines+1] = "Stamina: " .. (Settings.infiniteStamina and "INF" or "OFF")
        lines[#lines+1] = "Aim Hook: " .. (S.aimHookActive and "ON" or "OFF")
        lines[#lines+1] = ""
        lines[#lines+1] = "── STATS ──"
        lines[#lines+1] = "Dives: " .. S.stats.dives .. " | Jumps: " .. S.stats.jumps
        lines[#lines+1] = "Dribbles: " .. S.stats.dribbles
        lines[#lines+1] = "Fake Shots: " .. S.stats.fakeShots .. " | Wall: " .. S.stats.wallShots
        lines[#lines+1] = "Auto Shots: " .. S.stats.autoShots
        lines[#lines+1] = ""
        lines[#lines+1] = "── ERR ──"
        lines[#lines+1] = S.lastError
        debugText.Text = table.concat(lines, "\n")
    end
    refreshDebug()
    addActionButton("Debug", "Refresh", refreshDebug)
    
    -- Status bar
    local statusBar = makeFrame(panel, {
        Position = UDim2.fromOffset(10, 480),
        Size = UDim2.fromOffset(320, 30),
        BackgroundColor3 = C.surface,
    })
    round(statusBar, 5)
    local statusDot = makeFrame(statusBar, {
        Position = UDim2.fromOffset(10, 11),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = C.muted,
    })
    round(statusDot, 4)
    local statusLabel = makeText(statusBar, "READY", 10, {
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Font = Enum.Font.GothamBold,
    })
    
    -- Minimize/close
    minimize.Activated:Connect(function()
        if panel.Size.Y.Offset > 100 then
            panel.Size = UDim2.fromOffset(340, 46)
            contentHost.Visible = false
            statusBar.Visible = false
            minimize.Text = "+"
        else
            panel.Size = UDim2.fromOffset(340, 520)
            contentHost.Visible = true
            statusBar.Visible = true
            minimize.Text = "−"
        end
    end)
    close.Activated:Connect(function()
        if S.alive then
            S.alive = false
            for _, c in ipairs(S.connections) do pcall(function() c:Disconnect() end) end
            uninstallAimHook()
            if S.ui then S.ui:Destroy() end
        end
    end)
    
    -- Drag
    local dragging, dragStart, hostStart
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            hostStart = host.Position
        end
    end)
    connect(UIS.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            host.Position = UDim2.fromOffset(
                hostStart.X.Offset + d.X,
                hostStart.Y.Offset + d.Y
            )
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- Refresh loop
    connect(RunService.Heartbeat, function()
        if not S.alive or not gui.Parent then return end
        local now = os.clock()
        if now < (UI.nextRefresh or 0) then return end
        UI.nextRefresh = now + 0.3
        for _, fn in ipairs(UI.toggles) do pcall(fn) end
        statusLabel.Text = S.lastGKPlan ~= "NONE"
            and (Settings.gkEnabled and ("GK: " .. S.lastGKPlan) or "READY")
            or "READY"
        statusDot.BackgroundColor3 = Settings.gkEnabled and C.accent or C.muted
        if UI.activeTab == "Debug" then pcall(refreshDebug) end
    end)
    
    -- Keybind
    connect(UIS.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            gui.Enabled = not gui.Enabled
        elseif input.KeyCode == Enum.KeyCode.F then
            triggerFakeShot()
        elseif input.KeyCode == Enum.KeyCode.G then
            triggerWallFakeShot()
        end
    end)
    
    selectTab("Movement")
end

-- ============================================================
-- 17. BAŞLAT
-- ============================================================
print("[FA] Module status:")
for path, status in pairs(ModuleStatus) do
    print("  " .. path .. ": " .. status)
end

buildUI()
print("[FA] Football Assist v5.0 loaded. RightShift = toggle UI, F = fake shot, G = wall fake shot.")

-- Public API
_G.FA = {
    Settings = Settings,
    State = S,
    Modules = M,
    ModuleStatus = ModuleStatus,
    Stats = S.stats,
    FakeShot = triggerFakeShot,
    WallFakeShot = triggerWallFakeShot,
    ToggleUI = function()
        if S.ui then S.ui.Enabled = not S.ui.Enabled end
    end,
}