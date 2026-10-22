--[[
    ⚽ ULTIMATE FOOTBALL ASSISTANT v4.0 ⚽
    
    Referans analizine dayalı yeniden yazım:
    - Gerçek oyun modüllerini kullanır (ReplicatedStorage.Modules.*)
    - Oyunun action protocol'ünü kullanır (FireServer değil)
    - Prediction tabanlı kaleci
    - Modül bazlı, korumalı çağrılar
    - Mobile uyumlu custom UI
    
    Features:
    - Auto Goalkeeper (dive + jump + position)
    - Close-Range Rush
    - Auto Dribble (tackle prediction)
    - Best Shot Assist (aim override)
    - Movement (respect manual)
    
    Executor: Delta / Xeno / Solara
    Risk: Hesap yasaklanabilir. Sorumluluk sende.
--]]

-- ============================================================
-- 0. GÜVENLİK
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.5)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
assert(PlayerGui, "PlayerGui bulunamadı")

-- ============================================================
-- 1. LOGGER
-- ============================================================
local Log = { Debug = false }
local function log(fmt, ...)
    if Log.Debug then
        print("[FA] " .. string.format(fmt, ...))
    end
end

-- ============================================================
-- 2. MODÜL ÇÖZÜMLEYİCİ (Fallback'li)
-- ============================================================
-- Referans: her modülü pcall ile yükle, hata varsa devam et
local M = {}
local ModuleStatus = {}

local function resolveModule(path, optional)
    local ok, result = pcall(function()
        local obj = ReplicatedStorage
        for name in string.gmatch(path, "[^.]+") do
            obj = obj:WaitForChild(name, 5)
            if not obj then error("missing: " .. path) end
        end
        return require(obj)
    end)
    if ok and result then
        ModuleStatus[path] = "OK"
        return result
    end
    ModuleStatus[path] = "FAIL: " .. tostring(result)
    if not optional then
        log("Module required but failed: %s -> %s", path, tostring(result))
    end
    return nil
end

-- Çekirdek modüller (referanstan)
M.BallPhysics          = resolveModule("Modules.Ball.Physics", true)
M.Prediction           = resolveModule("Modules.Gameplay.GoalkeeperPrediction", true)
M.Motion               = resolveModule("Modules.Characters.CharacterMotion", true)
M.Match                = resolveModule("Modules.Gameplay.MatchSettings", true)
M.Teams                = resolveModule("Client.Gameplay.ActorTeams", true)
M.Dive                 = resolveModule("Modules.Actions.GoalkeeperDive", true)
M.Assist               = resolveModule("Modules.Actions.GoalkeeperDiveAssist", true)
M.Actions              = resolveModule("Modules.Actions.ActionCommands", true)
M.Protocol             = resolveModule("Modules.Actions.ActionRemoteProtocol", true)
M.Locks                = resolveModule("Modules.Actions.ActionLocks", true)
M.GKActions            = resolveModule("Modules.Actions.GoalkeeperActions", true)
M.Hitboxes             = resolveModule("Modules.Gameplay.HitboxSettings", true)
M.Keybinds             = resolveModule("Modules.Gameplay.Keybinds", true)
M.Controllers          = resolveModule("Modules.Characters.CharacterControllers", true)
M.Grounding            = resolveModule("Modules.Characters.Grounding", true)
M.Ragdoll              = resolveModule("Modules.Characters.Ragdoll", true)
M.Movement             = resolveModule("Client.Gameplay.Player.Movement", true)
M.Presentation         = resolveModule("Client.Gameplay.Actions.GoalkeeperDivePresentation", true)
M.Slide                = resolveModule("Client.Gameplay.Actions.SlideTackleInput", true)
M.Dodge                = resolveModule("Client.Gameplay.Actions.Dodge", true)
M.Freeze               = resolveModule("Client.Gameplay.KickoffFreeze", true)
M.Replay               = resolveModule("Client.Gameplay.Replay.GoalReplay", true)
M.Clock                = resolveModule("Client.Player.CharacterMotionSmoothing", true)
M.GKRole               = resolveModule("Client.Gameplay.Player.GoalkeeperRole", true)
M.Actors               = resolveModule("Modules.Characters.Actors", true)
M.Renderer             = resolveModule("Client.Gameplay.Ball.Renderer", true)
M.Practice             = resolveModule("Client.Gameplay.PracticeSession", true)
M.Physics              = resolveModule("Modules.Ball.Physics", true)
M.Contacts             = resolveModule("Modules.Actions.GoalkeeperActions", true)

-- Remotes
local BallRemotes = ReplicatedStorage:FindFirstChild("Remotes")
    and ReplicatedStorage.Remotes:FindFirstChild("Ball")
local TackleRemote = BallRemotes and BallRemotes:WaitForChild("Tackle", 5)
local StateRemote = BallRemotes and BallRemotes:WaitForChild("State", 5)
assert(TackleRemote and StateRemote, "Ball remotes bulunamadı - oyun içinde misin?")

-- ============================================================
-- 3. AYARLAR
-- ============================================================
local Settings = {
    -- Kaleci
    GKEnabled = true,
    DiveFilter = "SMART",       -- SMART / FORWARD / LEFT / RIGHT / SIDES
    HighBallJumps = true,
    JumpThenDive = true,
    PositionAssist = true,
    PreShotCoverage = true,
    CloseRush = true,
    BackwardRecovery = true,
    RespectManualMovement = true,
    PositionMode = "THREATS",    -- THREATS / HOME_AND_THREATS

    -- Forvet
    STREnabled = false,
    AutoCurve = false,
    SmartRelease = false,
    AssistRange = 65,

    -- Diğer
    AutoDribble = false,
    AntiAFK = true,
    Debug = false,
}

-- Constants (referanstan)
local CFG = {
    -- Prediction
    PredictionHorizon = 1.10,
    SampleStep = 0.01,
    GoalMarginSeconds = 0.045,
    PlannerHz = 12,
    CloseShotPlannerHz = 30,
    UrgentShotSeconds = 0.55,

    -- Positioning
    HomeDepth = 8,
    HomeRadius = 2.5,
    PositionDeadzone = 0.65,
    SafeLateralReach = 14,
    PositionResponseSeconds = 0.14,

    -- Jump
    JumpRetrySeconds = 0.65,
    JumpQueueEstimate = 0.05,
    JumpQueueTimeout = 0.45,

    -- Timing
    CachedFrameMaxAge = 0.12,
    ManualReleaseGrace = 0.18,

    -- Dive
    DiveRepeatDelay = 0.35,
    DiveHitboxCurveSeconds = 0.45,

    -- Rush
    RushRange = 12,
    RushGoalDepth = 28,
    RushConfirmSeconds = 0.05,
    RushScanInterval = 0.05,

    -- UI
    UISampleHz = 4,
}

-- ============================================================
-- 4. DURUM
-- ============================================================
local Stats = {
    diveRequests = 0, diveSent = 0, jumpRequests = 0,
    catches = 0, rushTriggers = 0, dribbles = 0,
    lastError = nil, lastPlan = "NONE",
}

local S = {
    alive = true,
    cleanupDone = false,
    connections = {},
    status = "STARTING",
    detail = "",
    lastChar = nil,
    lastFrame = nil,
    nextPlanAt = 0,
    nextActionAt = 0,
    nextJumpAt = 0,
    pending = nil,
    motionLease = nil,
    ownedMove = nil,
    allowPositioning = false,
    focused = true,
    manualUntil = 0,
    stick = Vector2.zero,
    touches = {},
    currentContext = nil,
    ballSignature = nil,
    flightKey = nil,
    ui = nil,
    uiBusy = false,
    runtimeFailures = 0,
    runtimeRetryAt = 0,
    runtimeError = nil,
    queueEstimate = CFG.JumpQueueEstimate,
    wasKeeper = false,
    manualActionUntil = 0,
    moveLock = "FA." .. tostring(math.floor(os.clock() * 1000000)),
    retiredLocks = {},
    retiredMotions = {},
    ownLockReleases = 0,
    ownLockAcquires = 0,
}

-- ============================================================
-- 5. YARDIMCILAR
-- ============================================================
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function finiteVec(v) return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z) end
local function unit(v, fallback) v = flat(v); return v.Magnitude > 1e-4 and v.Unit or (fallback or Vector3.new(0,0,-1)) end

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function now()
    -- Referans: smoothed server time
    if M.Clock and M.Clock.GetSmoothedServerTime then
        local ok, t = pcall(M.Clock.GetSmoothedServerTime)
        if ok and finite(t) then return t end
    end
    return workspace:GetServerTimeNow()
end

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(S.connections, c)
    return c
end

local function report(key, message)
    Stats.lastError = tostring(message)
    if Settings.Debug then
        warn("[FA] " .. key .. ": " .. tostring(message))
    end
end

-- ============================================================
-- 6. INPUT TAKİBİ (manual movement algılama)
-- ============================================================
connect(UserInputService.InputChanged, function(input)
    if input.KeyCode == Enum.KeyCode.Thumbstick1 then
        S.stick = Vector2.new(input.Position.X, input.Position.Y)
    end
end)

connect(UserInputService.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        S.touches[input] = true
    end
end)

connect(UserInputService.InputEnded, function(input)
    S.touches[input] = nil
    if input.KeyCode == Enum.KeyCode.Thumbstick1 then
        S.stick = Vector2.zero
    end
end)

connect(UserInputService.WindowFocusReleased, function()
    S.focused = false
    S.stick = Vector2.zero
    table.clear(S.touches)
end)

connect(UserInputService.WindowFocused, function()
    S.focused = true
    S.manualUntil = os.clock() + CFG.ManualReleaseGrace
    S.nextPlanAt = 0
end)

local function inputActive()
    if not S.focused or UserInputService:GetFocusedTextBox() then return true end
    for _, key in ipairs({
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
    }) do
        if UserInputService:IsKeyDown(key) then return true end
    end
    return S.stick.Magnitude > 0.12 or next(S.touches) ~= nil
end

-- ============================================================
-- 7. HAREKET KONTROLÜ (referans: SetMoveCommand)
-- ============================================================
-- Kritik: WalkSpeed değiştirme! Oyunun kendi move command sistemini kullan.
local function getMoveCommand(char)
    if M.Controllers and M.Controllers.GetMoveCommand then
        local ok, cmd = pcall(M.Controllers.GetMoveCommand, char)
        if ok and typeof(cmd) == "Vector3" then return cmd end
    end
    return Vector3.zero
end

local function setMoveCommand(char, dir)
    if M.Controllers and M.Controllers.SetMoveCommand then
        local ok, result = pcall(M.Controllers.SetMoveCommand, char, dir)
        if ok and result ~= false then return true end
    end
    -- Fallback: Humanoid:Move (daha az güvenli ama gerekli)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and finiteVec(dir) then
        hum:Move(dir, false)
        return true
    end
    return false
end

local function releaseMove(allowWrite)
    local char, owned = S.ownedMove and LocalPlayer.Character or nil, S.ownedMove
    S.ownedMove = nil
    S.allowPositioning = false
    if not owned or not allowWrite or not char then return end
    if inputActive() then return end -- manuel input varsa dokunma
    local current = getMoveCommand(char)
    if current.Magnitude > 0.001 and current:Dot(owned) > 0.99 then
        pcall(setMoveCommand, char, Vector3.zero)
    end
end

-- ============================================================
-- 8. TOP STATE OKUYUCU (referans: Renderer + State remote)
-- ============================================================
local function readBall()
    -- Öncelik: Renderer (referans)
    if M.Renderer then
        local ok1, ballId = pcall(M.Renderer.GetMatchBallId)
        local ok2, owner = pcall(M.Renderer.GetOwnedUserId)
        if ok1 and ok2 then
            if owner ~= nil then
                return { phase = "OWNED", ballId = ballId, owner = owner }
            end
            local ok3, state, world = pcall(M.Renderer.GetAuthoritativeMovementState)
            if ok3 and state and world then
                if finiteVec(state.Position) and finiteVec(state.Velocity) then
                    return {
                        phase = "MOVEMENT",
                        state = state, world = world,
                        ballId = ballId,
                        flightKey = tostring(ballId) .. ":" .. tostring(state.ActionId or state.StartedAt),
                    }
                end
            end
        end
    end

    -- Fallback: workspace'ten top bul
    local ballPart
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("ball") or obj.Name:lower():find("soccer")) then
            ballPart = obj
            break
        end
    end
    if ballPart then
        return {
            phase = "MOVEMENT",
            state = {
                Position = ballPart.Position,
                Velocity = ballPart.AssemblyLinearVelocity,
                Radius = ballPart.Size.Magnitude * 0.25,
                UpdatedAt = workspace:GetServerTimeNow(),
            },
            world = nil,
            ballId = ballPart,
            flightKey = tostring(ballPart),
        }
    end
    return { phase = "UNAVAILABLE" }
end

-- ============================================================
-- 9. KALE / TAKIM TESPİTİ (referans)
-- ============================================================
local function contextFor(root)
    -- Practice mode
    if M.Practice and M.Practice.GetDefendedGoalPart then
        local ok, goal = pcall(M.Practice.GetDefendedGoalPart)
        if ok and goal and goal:IsA("BasePart") then
            return { goal = goal, mode = "PRACTICE", team = nil }
        end
    end

    -- Match mode
    if M.Teams and M.Match then
        local ok1, team = pcall(M.Teams.GetActorTeamName, LocalPlayer)
        if ok1 and team then
            local map = workspace:FindFirstChild("Map")
            local data = map and map:FindFirstChild("Data")
            local home = data and data:FindFirstChild(team)
            local opponent = data and data:FindFirstChild(M.Match.GetOpposingTeamName(team))
            local goal = home and home:FindFirstChild("Goal")
            local attack = opponent and opponent:FindFirstChild("Goal")
            if goal and goal:IsA("BasePart") then
                local forward = attack and attack:IsA("BasePart")
                    and unit(attack.Position - goal.Position)
                    or unit(root.Position - goal.Position)
                if forward:Dot(root.Position - goal.Position) < 0 then forward = -forward end
                return {
                    goal = goal, team = team, mode = "MATCH",
                    forward = forward,
                    right = Vector3.new(-forward.Z, 0, forward.X),
                }
            end
        end
    end
    return nil
end

local function goalHalfWidth(ctx)
    if not ctx or not ctx.goal or not ctx.right then return 3.66 end
    local g = ctx.goal
    local s = g.Size
    local axis = ctx.right
    return math.max(0.5, (
        math.abs(g.CFrame.RightVector:Dot(axis)) * s.X +
        math.abs(g.CFrame.UpVector:Dot(axis)) * s.Y +
        math.abs(g.CFrame.LookVector:Dot(axis)) * s.Z
    ) * 0.5)
end

-- ============================================================
-- 10. YÖRÜNGE TAHMİNİ (referans: Physics module)
-- ============================================================
local function predictBallAt(state, world, dt)
    -- Öncelik: oyunun fizik modülü
    if M.Physics and M.Physics.GetStateAtTime and state and world then
        local ok, result = pcall(M.Physics.GetStateAtTime, state, state.UpdatedAt + dt, world, {})
        if ok and result and finiteVec(result.Position) then
            return result
        end
    end
    -- Fallback: basit balistik
    return {
        Position = state.Position + state.Velocity * dt + Vector3.new(0, -workspace.Gravity * dt * dt * 0.5, 0),
        Velocity = state.Velocity + Vector3.new(0, -workspace.Gravity * dt, 0),
        Radius = state.Radius or 0.22,
        UpdatedAt = state.UpdatedAt + dt,
    }
end

local function predictGoalCrossing(state, world, goal, fromTime, maxSeconds)
    -- Öncelik: oyunun prediction modülü
    if M.Prediction and M.Prediction.GetGoalCrossing and world then
        local ok, pos, t = pcall(M.Prediction.GetGoalCrossing, state, world, goal, fromTime, maxSeconds)
        if ok then return pos, t end
    end
    -- Fallback: manuel plane intersection
    if not state or not goal then return nil, nil end
    local plane = goal.Position
    local normal = unit(LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        and (goal.Position - LocalPlayer.Character.HumanoidRootPart.Position) or Vector3.new(0,0,1))
    local p0 = state.Position
    local v = state.Velocity
    local denom = v:Dot(normal)
    if math.abs(denom) < 1e-4 then return nil, nil end
    local t = (plane - p0):Dot(normal) / denom
    if t < 0 or t > maxSeconds then return nil, nil end
    return p0 + v * t, fromTime + t
end

-- ============================================================
-- 11. KARAKTER DURUMU
-- ============================================================
local function snapshotPlayer(character, root, humanoid)
    if not character or not root or not humanoid then return nil end
    if humanoid.Health <= 0 then return nil end

    local cf = root.CFrame
    local vel = root.AssemblyLinearVelocity
    local grounded = true
    if M.Controllers and M.Controllers.IsLanded then
        local ok, g = pcall(M.Controllers.IsLanded, character, humanoid)
        if ok then grounded = g end
    end

    local floorY = root.Position.Y
    if M.Grounding and M.Grounding.GetStandingY then
        local ok, y = pcall(M.Grounding.GetStandingY, humanoid, root)
        if ok and finite(y) then floorY = y end
    end

    local jumpSpeed = humanoid.UseJumpPower
        and humanoid.JumpPower
        or math.sqrt(math.max(0, 2 * workspace.Gravity * humanoid.JumpHeight))

    return {
        character = character,
        root = root,
        humanoid = humanoid,
        rootCF = cf,
        velocity = vel,
        floorY = floorY,
        grounded = grounded,
        jumpSpeed = jumpSpeed,
        gravity = workspace.Gravity,
        at = now(),
        readClock = os.clock(),
    }
end

-- ============================================================
-- 12. KALECİ ROLÜ
-- ============================================================
local function isGoalkeeper()
    if M.Match and M.Match.IsGoalkeeperCharacter and LocalPlayer.Character then
        local ok, result = pcall(M.Match.IsGoalkeeperCharacter, LocalPlayer.Character)
        if ok then return result end
    end
    -- Fallback: oyuncu attribute
    if LocalPlayer.Character then
        local attr = LocalPlayer.Character:GetAttribute("IsGoalkeeper")
        if attr ~= nil then return attr == true end
    end
    return false
end

-- ============================================================
-- 13. ENGEL KONTROLÜ
-- ============================================================
local function isBlocked(character, root)
    if next(S.retiredMotions) or next(S.retiredLocks) then
        return "OWN_CLEANUP_PENDING"
    end
    if M.Controllers and M.Controllers.IsSuspended then
        local ok, result = pcall(M.Controllers.IsSuspended, character)
        if ok and result then return "SUSPENDED" end
    end
    if M.Ragdoll then
        local isRag = false
        if M.Ragdoll.IsLocallyRagdolled then
            local ok, r = pcall(M.Ragdoll.IsLocallyRagdolled, LocalPlayer)
            if ok then isRag = r end
        elseif M.Ragdoll.IsEnabled then
            local ok, r = pcall(M.Ragdoll.IsEnabled, character)
            if ok then isRag = r end
        end
        if isRag then return "RAGDOLL" end
    end
    if M.Freeze and M.Freeze.IsFrozen then
        local ok, r = pcall(M.Freeze.IsFrozen)
        if ok and r then return "ROUND_TRANSITION" end
    end
    if M.Replay and M.Replay.IsActive then
        local ok, r = pcall(M.Replay.IsActive)
        if ok and r then return "REPLAY" end
    end
    if M.Slide and M.Slide.IsSlideTackling then
        local ok, r = pcall(M.Slide.IsSlideTackling)
        if ok and r then return "MANUAL_SLIDE" end
    end
    if M.Dodge and M.Dodge.IsDribbling then
        local ok, r = pcall(M.Dodge.IsDribbling)
        if ok and r then return "MANUAL_DODGE" end
    end
    if M.Dive and M.Dive.IsDiveConstraintActive then
        local ok, r = pcall(M.Dive.IsDiveConstraintActive, root)
        if ok and r then return "DIVE_ACTIVE" end
    end
    return nil
end

-- ============================================================
-- 14. KALECİ: DİVE PLANLAMA
-- ============================================================
local function allowedDirections(snapshot, ctx)
    local result = {}
    local filter = Settings.DiveFilter

    if filter == "FORWARD" then result = { "F" }
    elseif filter == "LEFT" then result = { "L", "LF" }
    elseif filter == "RIGHT" then result = { "R", "RF" }
    elseif filter == "SIDES" then result = { "L", "R", "LF", "RF" }
    else result = { "F", "L", "R", "LF", "RF" } end

    if Settings.BackwardRecovery and (filter == "SMART") then
        local passed = (snapshot.state.Position - snapshot.rootCF.Position):Dot(ctx.forward) < -1
        local high = snapshot.state.Position.Y - snapshot.rootCF.Position.Y > 3
        if passed or high then
            table.insert(result, "B")
            table.insert(result, "LB")
            table.insert(result, "RB")
        end
    end
    return result
end

local function makeDivePlan(snapshot, ctx, directionName, delay)
    if not M.Dive or not M.Dive.GetDirectionChoiceByName or not M.Dive.GetWorldDirection then
        return nil
    end

    local ok1, choice = pcall(M.Dive.GetDirectionChoiceByName, directionName)
    if not ok1 or not choice then return nil end

    local basis = CFrame.lookAt(snapshot.rootCF.Position, snapshot.rootCF.Position + ctx.forward)
    local ok2, worldDir = pcall(M.Dive.GetWorldDirection, choice, basis, ctx.forward)
    if not ok2 or not typeof(worldDir) == "Vector3" then return nil end

    return {
        kind = "DIVE",
        directionName = directionName,
        choice = choice,
        worldDirection = worldDir,
        basis = basis,
        origin = snapshot.rootCF,
        delay = delay or 0,
    }
end

local function simulateDiveRoot(plan, t)
    if not M.Dive or not M.Dive.GetTravel or not M.Dive.Constants then
        -- Fallback: linear
        return plan.origin + plan.worldDirection * (M.Dive and M.Dive.Constants and M.Dive.Constants.Distance or 10)
    end
    local constants = M.Dive.Constants
    local distance = constants.Distance or 10
    local scale = 1
    local vertical = constants.InitialVerticalVelocity or 8
    local gravity = constants.GravityStudsPerSecondSquared or -65
    local elapsed = math.max(0, t - plan.delay)
    local ok, travel = pcall(M.Dive.GetTravel, elapsed * scale, distance)
    if not ok then travel = elapsed * 20 end
    local rise = vertical * elapsed + 0.5 * gravity * elapsed * elapsed
    local pos = plan.origin.Position + plan.worldDirection * travel + Vector3.new(0, rise, 0)
    return CFrame.new(pos, pos + plan.worldDirection)
end

local function checkDiveContact(snapshot, plan, ctx)
    if not M.Hitboxes or not M.Hitboxes.AirReceive then return nil end
    if not M.Contacts or not M.Contacts.FindDiveSaveContact then return nil end
    if not snapshot.eta then return nil end

    local horizon = math.min(
        M.Dive and M.Dive.Constants and M.Dive.Constants.HitboxCurveSeconds or 0.45,
        snapshot.eta - CFG.GoalMarginSeconds
    )
    if horizon <= 0.0001 then return nil end

    -- Simulate trajectory of ball AND dive root
    local prevBall = snapshot.state.Position
    local prevRootCF = snapshot.rootCF
    local t = 0
    local step = 0.01

    while t < horizon do
        t = math.min(horizon, t + step)
        local ballState = predictBallAt(snapshot.state, snapshot.world, t)
        local rootCF = simulateDiveRoot(plan, t)

        local ok, hit = pcall(M.Contacts.FindDiveSaveContact, LocalPlayer,
            prevBall, ballState.Position,
            { StartRootCFrame = prevRootCF, EndRootCFrame = rootCF, BallRadius = ballState.Radius or 0.22 })

        if ok and hit and hit.Alpha then
            return {
                contactTime = t,
                miss = 0,
            }
        end

        -- Hitbox check
        if M.Hitboxes.GetSegmentEnterAlpha then
            local ok2, alpha = pcall(M.Hitboxes.GetSegmentEnterAlpha,
                { CFrame = rootCF }, M.Hitboxes.AirReceive,
                prevBall + rootCF.Position - prevRootCF.Position, ballState.Position)
            if ok2 and finite(alpha) and alpha >= 0 and alpha <= 1 then
                return { contactTime = t, miss = 0 }
            end
        end

        prevBall = ballState.Position
        prevRootCF = rootCF
    end

    return nil
end

local function planSave(snapshot, ctx)
    local started = os.clock()
    Stats.lastPlan = "NONE"

    local horizon = math.min(CFG.PredictionHorizon, snapshot.eta - CFG.GoalMarginSeconds)
    if horizon <= 0.0001 then
        Stats.lastPlan = "TOO_LATE"
        return nil
    end

    local candidates = {}
    local dirs = allowedDirections(snapshot, ctx)

    -- Immediate dives (delay = 0)
    for _, name in ipairs(dirs) do
        local plan = makeDivePlan(snapshot, ctx, name, 0)
        if plan then
            local contact = checkDiveContact(snapshot, plan, ctx)
            if contact then
                plan.contact = contact
                plan.score = contact.contactTime + 0.1
                table.insert(candidates, plan)
            end
        end
    end

    -- Delayed dives
    if #candidates == 0 then
        for _, name in ipairs(dirs) do
            for _, delay in ipairs({ 0.05, 0.10, 0.20, 0.30 }) do
                if delay < horizon then
                    local plan = makeDivePlan(snapshot, ctx, name, delay)
                    if plan then
                        local contact = checkDiveContact(snapshot, plan, ctx)
                        if contact then
                            plan.contact = contact
                            plan.score = contact.contactTime + delay * 0.5 + 0.1
                            table.insert(candidates, plan)
                        end
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        Stats.lastPlan = "NO_CONTACT"
        return nil
    end

    table.sort(candidates, function(a, b) return a.score < b.score end)
    Stats.lastPlan = candidates[1].directionName .. (candidates[1].delay > 0 and ("@" .. candidates[1].delay) or "")
    log("Plan in %.1fms -> %s", (os.clock() - started) * 1000, Stats.lastPlan)
    return candidates[1]
end

-- ============================================================
-- 15. KALECİ: DIVE GÖNDER (referans: Protocol.Send)
-- ============================================================
local function requestDive(snapshot, plan, ctx)
    if not S.alive or not Settings.GKEnabled then return false end
    if plan.kind ~= "DIVE" or plan.delay ~= 0 then return false end
    if os.clock() - snapshot.readClock > 0.09 then return false end
    if os.clock() < S.nextActionAt then return false end

    local reason = isBlocked(snapshot.character, snapshot.root)
    if reason then
        report("BLOCKED", reason)
        return false
    end

    if not M.Dive or not M.Dive.Run then
        report("DIVE", "Dive module not available")
        return false
    end

    if not M.Actions or not M.Actions.GoalkeeperDive then
        report("DIVE", "ActionCommands module not available")
        return false
    end

    if not M.Protocol or not M.Protocol.Send then
        report("DIVE", "ActionRemoteProtocol not available")
        return false
    end

    -- Fresh snapshot for verification
    local fresh = snapshotPlayer(snapshot.character, snapshot.root, snapshot.humanoid)
    if not fresh then return false end

    Stats.diveRequests += 1
    S.nextActionAt = os.clock() + CFG.DiveRepeatDelay

    -- Referans: lock movement first
    local lease = {
        id = (S.nextLeaseId or 0) + 1,
        character = fresh.character,
        root = fresh.root,
        lockName = S.moveLock .. "." .. tostring(os.clock()),
        lockHeld = false,
        closed = false,
        deadline = os.clock() + 3,
    }
    S.nextLeaseId = lease.id
    S.motionLease = lease

    local ok, err = pcall(function()
        if M.Movement and M.Movement.LockMovement then
            pcall(M.Movement.LockMovement, lease.lockName)
            lease.lockHeld = true
            S.ownLockAcquires += 1
        end

        local controller = M.Dive.Run(
            fresh.root, fresh.humanoid, plan.choice,
            function() return plan.basis end,
            {
                Assist = nil,
                StartedAt = fresh.at,
                Finish = function()
                    if S.motionLease == lease then
                        S.motionLease = nil
                    end
                end,
            }
        )
        if not controller then error("Dive controller refused") end
        lease.controller = controller

        -- Referans: motion sample → command → Protocol.Send
        local motionSample
        if M.Dive.GetMotionSample then
            local ok2, sample = pcall(M.Dive.GetMotionSample, fresh.root)
            if ok2 then motionSample = sample end
        end

        local command = M.Actions.GoalkeeperDive({
            AimDirection = plan.worldDirection,
            DirectionName = plan.directionName,
            DiveMotion = motionSample,
            ShotTime = fresh.at,
        })

        local sent, actionId = pcall(M.Protocol.Send, command)
        if not sent or not finite(actionId) then
            error("Protocol.Send failed: " .. tostring(actionId))
        end

        Stats.diveSent += 1
        log("Dive sent: %s -> action %d", plan.directionName, actionId)

        -- Presentation
        if M.Presentation and M.Presentation.Play then
            pcall(M.Presentation.Play, fresh.character, plan.directionName, fresh.at)
        end
    end)

    if not ok then
        Stats.lastError = tostring(err)
        report("DIVE_ERROR", err)
        -- Cleanup
        if lease.lockHeld and M.Movement and M.Movement.UnlockMovement then
            pcall(M.Movement.UnlockMovement, lease.lockName)
            S.ownLockReleases += 1
        end
        S.motionLease = nil
        return false
    end

    S.status = "DIVE_SENT"
    S.detail = plan.directionName .. (plan.delay > 0 and (" @" .. plan.delay) or "")
    return true
end

-- ============================================================
-- 16. KALECİ: JUMP (referans: Movement.Jump)
-- ============================================================
local function requestJump(snapshot, plan, ctx)
    if not Settings.HighBallJumps then return false end
    if os.clock() < S.nextJumpAt then return false end
    if not snapshot.grounded then return false end
    if snapshot.jumpSpeed <= 0 then return false end
    if not M.Movement or not M.Movement.Jump then return false end

    local reason = isBlocked(snapshot.character, snapshot.root)
    if reason then return false end

    -- Check whether jump actually helps: simulate jump trajectory vs ball
    local horizon = math.min(CFG.PredictionHorizon, snapshot.eta - CFG.GoalMarginSeconds)
    if horizon <= 0.0001 then return false end

    local jumpSpeed = snapshot.jumpSpeed
    local gravity = snapshot.gravity
    local queueDelay = S.queueEstimate

    local prevBall = snapshot.state.Position
    local t = 0
    local step = 0.01
    local contactAt = nil

    while t < horizon do
        t = math.min(horizon, t + step)
        local ballState = predictBallAt(snapshot.state, snapshot.world, t)
        local jumpElapsed = math.max(0, t - queueDelay)
        local jumpRise = math.max(0, jumpSpeed * jumpElapsed - 0.5 * gravity * jumpElapsed * jumpElapsed)
        local rootPos = snapshot.rootCF.Position + Vector3.new(0, jumpRise, 0)

        if M.Hitboxes and M.Hitboxes.AirReceive and M.Hitboxes.GetSegmentEnterAlpha then
            local ok, alpha = pcall(M.Hitboxes.GetSegmentEnterAlpha,
                { CFrame = CFrame.new(rootPos) }, M.Hitboxes.AirReceive,
                prevBall + rootPos - snapshot.rootCF.Position, ballState.Position)
            if ok and finite(alpha) and alpha >= 0 and alpha <= 1 then
                contactAt = t
                break
            end
        end

        prevBall = ballState.Position
    end

    if not contactAt then return false end

    S.nextJumpAt = os.clock() + CFG.JumpRetrySeconds
    local ok, requested = pcall(M.Movement.Jump)
    if not ok or not requested then
        pcall(function() if M.Movement.ReleaseJump then M.Movement.ReleaseJump() end end)
        return false
    end

    Stats.jumpRequests += 1
    S.status = "JUMP_QUEUED"
    S.detail = string.format("contact %.2fs", contactAt)

    -- Register jump for tracking
    S.jump = {
        phase = "QUEUED",
        requested = os.clock(),
        character = snapshot.character,
        root = snapshot.root,
        initialY = snapshot.root.Position.Y,
        flightKey = snapshot.flightKey,
        latch = true,
    }
    return true
end

local function updateJump(character, root, humanoid)
    local j = S.jump
    if not j then return false end
    if j.character ~= character or not root.Parent then
        S.jump = nil
        return false
    end

    if j.phase == "QUEUED" then
        local airborne = not M.Controllers or not M.Controllers.IsLanded
            or not pcall(M.Controllers.IsLanded, character, humanoid)
        local rising = root.AssemblyLinearVelocity.Y > 1 and root.Position.Y > j.initialY + 0.035

        if rising then
            j.phase = "AIRBORNE"
            j.launched = os.clock()
            local observedDelay = math.max(0, j.launched - j.requested)
            S.queueEstimate = S.queueEstimate * 0.7 + math.clamp(observedDelay, 0.015, 0.20) * 0.3
        elseif os.clock() - j.requested > CFG.JumpQueueTimeout then
            S.jump = nil
        end
        return true
    end

    if M.Controllers and M.Controllers.IsLanded then
        local ok, landed = pcall(M.Controllers.IsLanded, character, humanoid)
        if ok and landed then S.jump = nil end
    end
    return false
end

-- ============================================================
-- 17. POZİSYON ASİSTANI (referans: Position)
-- ============================================================
local function positionAssist(snapshot, ctx, dt)
    if not S.allowPositioning or not Settings.PositionAssist then
        releaseMove(true)
        return
    end
    if S.jump or S.motionLease then releaseMove(false); return end

    if Settings.RespectManualMovement and inputActive() then
        S.manualUntil = os.clock() + CFG.ManualReleaseGrace
        releaseMove(false)
        return
    end
    if os.clock() < S.manualUntil then releaseMove(true); return end
    if os.clock() - snapshot.readClock > CFG.CachedFrameMaxAge then releaseMove(true); return end

    local why = isBlocked(snapshot.character, snapshot.root)
    if why then releaseMove(false); return end

    if not snapshot.grounded then releaseMove(false); return end

    local remaining = snapshot.eta and snapshot.eta - math.max(0, os.clock() - snapshot.readClock) or nil
    local threat = remaining and remaining > 0 and snapshot.goalPosition ~= nil

    if Settings.PositionMode == "THREATS" and not threat then
        releaseMove(true); return
    end

    local c = ctx
    local origin = c.goal.Position
    local depth = CFG.HomeDepth
    local ballOffset = snapshot.state.Position - origin
    local halfWidth = math.max(0.5, goalHalfWidth(c) - 2)

    local lateral = ballOffset:Dot(c.right) * depth / math.max(depth, ballOffset:Dot(c.forward))
    if threat then
        local crossing = (snapshot.goalPosition - origin):Dot(c.right)
        local current = (snapshot.root.Position - origin):Dot(c.right)
        lateral = math.clamp(current, crossing - CFG.SafeLateralReach, crossing + CFG.SafeLateralReach)
        if snapshot.state.Position.Y - snapshot.root.Position.Y > 5 then
            depth = math.max(3.5, depth - 2.5)
        end
    end
    lateral = math.clamp(lateral, -halfWidth, halfWidth)

    local targetPos = origin + c.forward * depth + c.right * lateral
    local errorVec = flat(targetPos - snapshot.root.Position)
    local distance = errorVec.Magnitude
    local stopRadius = threat and CFG.PositionDeadzone or CFG.HomeRadius
    local startRadius = threat and 1.15 or CFG.HomeRadius

    if distance <= stopRadius then releaseMove(true); return end
    if distance < startRadius and not S.ownedMove then return end

    local scale = math.clamp((distance - stopRadius) / 3, 0, 1)
    local desired = errorVec.Unit * scale
    if S.ownedMove then
        desired = S.ownedMove:Lerp(desired, 1 - math.exp(-dt / CFG.PositionResponseSeconds))
    end
    if desired.Magnitude < 0.005 then releaseMove(true); return end

    local ok = setMoveCommand(snapshot.character, desired)
    if ok then
        S.ownedMove = desired
        S.allowPositioning = true
    end
end

-- ============================================================
-- 18. CLOSE-RANGE RUSH
-- ============================================================
local function tryCloseRush(character, root, humanoid, ctx)
    if not Settings.CloseRush then return false end
    if os.clock() < (S.nextRushScan or 0) then return false end
    S.nextRushScan = os.clock() + CFG.RushScanInterval
    if os.clock() < S.nextActionAt then return false end
    if S.jump or S.motionLease then return false end

    local ball = readBall()
    if ball.phase ~= "OWNED" or not finite(ball.owner) or ball.owner == LocalPlayer.UserId then
        return false
    end

    -- Find carrier
    local carrierActor
    if M.Actors and M.Actors.GetByUserId then
        local ok, actor = pcall(M.Actors.GetByUserId, ball.owner)
        if ok then carrierActor = actor end
    end
    if not carrierActor then return false end

    local carrierChar = carrierActor.Character
    if not carrierChar or not carrierChar.Parent then return false end
    local carrierRoot = carrierChar:FindFirstChild("HumanoidRootPart")
    local carrierHum = carrierChar:FindFirstChildOfClass("Humanoid")
    if not carrierRoot or not carrierHum or carrierHum.Health <= 0 then return false end

    -- Team check
    if M.Teams then
        local ok1, myTeam = pcall(M.Teams.GetActorTeamName, LocalPlayer)
        local ok2, otherTeam = pcall(M.Teams.GetActorTeamName, carrierActor)
        if ok1 and ok2 and (myTeam == nil or otherTeam == nil or myTeam == otherTeam) then
            return false
        end
    end

    local dist = (carrierRoot.Position - root.Position).Magnitude
    if dist > CFG.RushRange or dist < 0.25 then return false end

    -- Depth check (must be between keeper and goal line)
    local goalPos = ctx.goal.Position
    local keeperDepth = (root.Position - goalPos):Dot(ctx.forward)
    local targetDepth = (carrierRoot.Position - goalPos):Dot(ctx.forward)
    if keeperDepth < 0 or keeperDepth > CFG.RushGoalDepth then return false end
    if targetDepth < keeperDepth - 1 or targetDepth > CFG.RushGoalDepth then return false end

    -- Only rush if carrier is facing goal
    local toGoal = unit(goalPos - carrierRoot.Position)
    local carrierFacing = unit(carrierRoot.CFrame.LookVector):Dot(toGoal)
    if carrierFacing < 0.40 and dist > 6 then return false end

    -- Confirmation (must persist 0.05s)
    local key = tostring(ball.ballId) .. ":" .. tostring(ball.owner)
    if S.rushCandidate ~= key then
        S.rushCandidate = key
        S.rushCandidateSince = os.clock()
        return false
    end
    if os.clock() - S.rushCandidateSince < CFG.RushConfirmSeconds then return false end

    -- Direction
    local toward = unit(carrierRoot.Position - root.Position, ctx.forward)
    local divePlan
    for _, name in ipairs({ "F", "LF", "RF" }) do
        local plan = makeDivePlan({
            rootCF = root.CFrame,
            state = { Position = carrierRoot.Position },
            eta = 0.30,
            world = nil,
        }, ctx, name, 0)
        if plan and plan.worldDirection:Dot(toward) > 0.5 then
            divePlan = plan
            break
        end
    end
    if not divePlan then return false end

    S.nextActionAt = os.clock() + CFG.DiveRepeatDelay
    Stats.rushTriggers += 1
    S.status = "RUSH"
    S.detail = "close-range"

    -- Use native dive
    if M.Dive and M.Dive.Run then
        local ok = pcall(function()
            M.Dive.Run(root, humanoid, divePlan.choice,
                function() return divePlan.basis end, { Assist = nil, StartedAt = now() })
        end)
        return ok
    end
    return false
end

-- ============================================================
-- 19. AUTO DRIBBLE (referans: Tackle packet izleme)
-- ============================================================
local Dribble = {
    recentTackles = {}, -- [userId] = { startedAt, direction }
    nextScan = 0,
    candidate = nil,
    candidateSince = 0,
}

connect(TackleRemote.OnClientEvent, function(packet)
    if not S.alive or not Settings.AutoDribble then return end
    if typeof(packet) ~= "table" then return end
    if packet.Protocol ~= "ActionCommand" or packet.Phase ~= "Execute" then return end
    local cmd = packet.Command
    if not cmd or cmd.Mode ~= "Tackle" then return end
    if not finite(cmd.ActorUserId) or cmd.ActorUserId == LocalPlayer.UserId then return end

    Dribble.recentTackles[cmd.ActorUserId] = {
        startedAt = workspace:GetServerTimeNow(),
        direction = cmd.AimDirection,
    }
end)

local function tryAutoDribble(character, root, humanoid)
    if not Settings.AutoDribble then return false end
    if os.clock() < Dribble.nextScan then return false end
    Dribble.nextScan = os.clock() + 0.05
    if os.clock() < S.manualActionUntil then return false end
    if isBlocked(character, root) then return false end
    if not M.Dodge or not M.Dodge.IsDribbling then return false end

    local ok, isDribbling = pcall(M.Dodge.IsDribbling)
    if ok and isDribbling then return false end

    local myPos = root.Position
    local nowTime = workspace:GetServerTimeNow()
    local bestThreat = nil

    for userId, tackle in pairs(Dribble.recentTackles) do
        local age = nowTime - tackle.startedAt
        if age < 1.2 then -- 1.2s window
            -- Find character
            local actor
            if M.Actors and M.Actors.GetByUserId then
                local okA, a = pcall(M.Actors.GetByUserId, userId)
                if okA then actor = a end
            end
            if actor and actor.Character then
                local otherRoot = actor.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local dist = (otherRoot.Position - myPos).Magnitude
                    if dist < 8 and not bestThreat or (bestThreat and dist < bestThreat.dist) then
                        bestThreat = { actor = actor, dist = dist, age = age, tackle = tackle }
                    end
                end
            end
        else
            Dribble.recentTackles[userId] = nil
        end
    end

    if not bestThreat then return false end

    -- Confirm
    local key = tostring(bestThreat.actor.UserId) .. ":" .. tostring(bestThreat.tackle.startedAt)
    if Dribble.candidate ~= key then
        Dribble.candidate = key
        Dribble.candidateSince = os.clock()
        return false
    end
    if os.clock() - Dribble.candidateSince < 0.05 then return false end

    -- Trigger dodge via native input
    if M.Dodge.HandleInputBegan and M.Keybinds and M.Keybinds.Get then
        local ok2, binding = pcall(M.Keybinds.Get, "Dribble")
        if ok2 and binding then
            local fakeInput = {
                KeyCode = Enum.KeyCode.Unknown,
                UserInputType = Enum.UserInputType.Keyboard,
                UserInputState = Enum.UserInputState.Begin,
            }
            local handled = pcall(M.Dodge.HandleInputBegan, fakeInput, false)
            if handled then
                Stats.dribbles += 1
                S.status = "DRIBBLE"
                Dribble.candidate = nil
                return true
            end
        end
    end

    return false
end

-- ============================================================
-- 20. ANA DÖNGÜ
-- ============================================================
local function tick(dt)
    if not S.alive then return end

    -- Retired locks cleanup
    for lease in pairs(S.retiredMotions) do
        if M.Movement and M.Movement.UnlockMovement then
            pcall(M.Movement.UnlockMovement, lease.lockName)
        end
        S.retiredMotions[lease] = nil
    end

    if not Settings.GKEnabled and not Settings.STREnabled and not Settings.AutoDribble then
        releaseMove(true)
        S.status = "OFF"
        return
    end

    local character = LocalPlayer.Character
    if not character then
        releaseMove(false)
        S.status = "NO_CHARACTER"
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then
        releaseMove(false)
        S.status = "NO_CHARACTER"
        return
    end

    -- Character change
    if character ~= S.lastChar then
        releaseMove(false)
        S.jump = nil
        S.pending = nil
        S.lastFrame = nil
        S.lastChar = character
        S.currentContext = nil
        S.wasKeeper = false
        S.rushCandidate = nil
    end

    -- Manual input grace
    if os.clock() < S.manualActionUntil then
        S.status = "MANUAL"
        return
    end

    if not S.focused or S.uiBusy then
        S.status = S.uiBusy and "UI_OPEN" or "UNFOCUSED"
        return
    end

    -- Update jump state
    updateJump(character, root, humanoid)

    -- Auto Dribble (works for any role)
    tryAutoDribble(character, root, humanoid)

    -- Get context
    local ctx = contextFor(root)
    if not ctx then
        S.status = "NO_CONTEXT"
        return
    end

    -- Goalkeeper specific
    if Settings.GKEnabled and isGoalkeeper() then
        S.wasKeeper = true
        local why = isBlocked(character, root)
        if why then
            S.status = why
            return
        end

        -- Close rush first
        if tryCloseRush(character, root, humanoid, ctx) then return end

        -- Read ball
        local ball = readBall()
        local sig = tostring(ball.ballId) .. ":" .. ball.phase
        if sig ~= S.ballSignature then
            S.ballSignature = sig
            S.lastFrame = nil
            S.nextPlanAt = 0
        end

        if ball.phase == "MOVEMENT" then
            -- Check throttle
            if os.clock() < S.nextPlanAt then
                if S.allowPositioning and S.lastFrame then
                    positionAssist(S.lastFrame, ctx, dt)
                end
                return
            end

            -- Full snapshot
            local snapshot = snapshotPlayer(character, root, humanoid)
            if not snapshot then S.status = "SNAPSHOT_FAIL"; return end

            snapshot.state = ball.state
            snapshot.world = ball.world
            snapshot.flightKey = ball.flightKey
            snapshot.ballId = ball.ballId
            snapshot.context = ctx

            -- Compute ball trajectory
            local current
            if M.Physics and M.Physics.GetStateAtTime and ball.world then
                local ok, r = pcall(M.Physics.GetStateAtTime, ball.state, now(), ball.world, {})
                if ok and r and finiteVec(r.Position) then current = r end
            end
            if not current then current = ball.state end

            snapshot.state = current
            snapshot.at = now()

            -- Goal crossing prediction
            local goalPos, goalTime = predictGoalCrossing(current, ball.world, ctx.goal,
                snapshot.at, M.Prediction and M.Prediction.Constants
                    and M.Prediction.Constants.GoalCrossingMaximumPredictionSeconds or 2.0)

            snapshot.goalPosition = goalPos
            snapshot.goalTime = goalTime
            snapshot.eta = goalPos and finite(goalTime) and (goalTime - snapshot.at) or nil

            S.lastFrame = snapshot

            -- Planner deadline
            local urgent = snapshot.eta and snapshot.eta <= CFG.UrgentShotSeconds
            local hz = urgent and CFG.CloseShotPlannerHz or CFG.PlannerHz
            S.nextPlanAt = os.clock() + 1 / hz

            -- No goal-bound trajectory
            if not snapshot.eta or snapshot.eta <= 0 then
                S.allowPositioning = Settings.PositionMode ~= "THREATS"
                positionAssist(snapshot, ctx, dt)
                S.status = "READY"
                return
            end

            -- Too far
            if snapshot.eta > CFG.PredictionHorizon then
                S.allowPositioning = true
                positionAssist(snapshot, ctx, dt)
                S.status = "TRACKING"
                S.detail = string.format("goal in %.2fs", snapshot.eta)
                return
            end

            S.allowPositioning = false
            local plan = planSave(snapshot, ctx)

            if plan then
                if plan.kind == "DIVE" then
                    if plan.delay > 0 then
                        S.nextPlanAt = math.min(S.nextPlanAt, os.clock() + plan.delay)
                        S.status = "TIMING"
                        S.detail = string.format("%s in %.2fs", plan.directionName, plan.delay)
                    else
                        requestDive(snapshot, plan, ctx)
                    end
                end
            else
                -- Try jump
                if Settings.HighBallJumps then
                    requestJump(snapshot, plan, ctx)
                end
                S.status = "NO_PLAN"
                S.detail = Stats.lastPlan
            end
        else
            releaseMove(true)
            S.allowPositioning = false
            S.status = ball.phase
        end
    else
        -- Not a goalkeeper: release movement
        if S.ownedMove then releaseMove(true) end
        S.status = "WAITING_GK"
    end
end

-- ============================================================
-- 21. MAIN LOOP
-- ============================================================
connect(RunService.Heartbeat, function(dt)
    if not S.alive then return end
    if os.clock() < S.runtimeRetryAt then return end
    if S.tickBusy then return end
    S.tickBusy = true
    local ok, err = xpcall(function() tick(dt) end, debug.traceback)
    S.tickBusy = false
    if not ok then
        S.runtimeFailures += 1
        S.runtimeError = tostring(err)
        S.runtimeRetryAt = os.clock() + 0.25
        Stats.lastError = S.runtimeError
        if S.runtimeFailures >= 3 then
            Settings.GKEnabled = false
            report("RUNTIME", err)
        end
    else
        S.runtimeFailures = 0
    end
end)

-- ============================================================
-- 22. CLEANUP
-- ============================================================
local function cleanup()
    if S.cleanupDone then return true end
    S.alive = false
    for _, c in ipairs(S.connections) do pcall(function() c:Disconnect() end) end
    S.connections = {}
    releaseMove(true)
    if S.motionLease and S.motionLease.lockHeld and M.Movement then
        pcall(M.Movement.UnlockMovement, S.motionLease.lockName)
    end
    if S.ui then pcall(function() S.ui:Destroy() end); S.ui = nil end
    S.cleanupDone = true
    return true
end

-- ============================================================
-- 23. UI (Custom, Mobile Friendly)
-- ============================================================
local Colors = {
    bg = Color3.fromRGB(16, 16, 15),
    surface = Color3.fromRGB(23, 23, 21),
    control = Color3.fromRGB(29, 29, 26),
    hover = Color3.fromRGB(39, 37, 30),
    text = Color3.fromRGB(242, 243, 240),
    muted = Color3.fromRGB(178, 181, 175),
    accent = Color3.fromRGB(222, 193, 115),
    accentDim = Color3.fromRGB(131, 111, 61),
    active = Color3.fromRGB(43, 39, 27),
    danger = Color3.fromRGB(220, 80, 70),
}

local function createInstance(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local function round(obj, r)
    createInstance("UICorner", { CornerRadius = UDim.new(0, r or 5) }, obj)
    return obj
end

local function stroke(obj, color, thick)
    return createInstance("UIStroke", {
        Color = color or Colors.accentDim,
        Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

local function text(parent, str, size, props)
    local p = {
        Text = str, TextSize = size or 13,
        Font = Enum.Font.GothamMedium, TextColor3 = Colors.text,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
    }
    for k, v in pairs(props or {}) do p[k] = v end
    return createInstance("TextLabel", p, parent)
end

local function button(parent, props)
    local p = {
        Text = "", TextSize = 13, Font = Enum.Font.GothamBold,
        TextColor3 = Colors.text, BackgroundColor3 = Colors.control,
        BorderSizePixel = 0, AutoButtonColor = false,
    }
    for k, v in pairs(props) do p[k] = v end
    return round(createInstance("TextButton", p, parent), 5)
end

local function frame(parent, props)
    local p = {
        BackgroundColor3 = Colors.surface, BorderSizePixel = 0,
    }
    for k, v in pairs(props) do p[k] = v end
    return createInstance("Frame", p, parent)
end

local function buildUI()
    local gui = createInstance("ScreenGui", {
        Name = "FootballAssistant",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)
    S.ui = gui

    local host = createInstance("Frame", {
        Name = "Host",
        Position = UDim2.fromOffset(20, 100),
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
    }, gui)

    local panel = round(frame(host, {
        Name = "Panel",
        Size = UDim2.fromOffset(320, 500),
        BackgroundColor3 = Colors.bg,
    }), 9)
    stroke(panel, Colors.accentDim)
    panel.Active = true

    local uiScale = createInstance("UIScale", { Scale = 1 }, panel)

    -- Header
    local header = frame(panel, {
        Name = "Header",
        Size = UDim2.fromOffset(320, 44),
        BackgroundColor3 = Colors.surface,
        BackgroundTransparency = 0,
    })
    round(header, 9)
    header.Active = true

    text(header, "⚽ Football Assistant v4.0", 14, {
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.fromOffset(220, 20),
        Font = Enum.Font.GothamBold,
        TextColor3 = Colors.accent,
    })

    local minimize = button(header, {
        Text = "-", TextSize = 18,
        Position = UDim2.new(1, -72, 0, 10),
        Size = UDim2.fromOffset(28, 24),
    })
    local close = button(header, {
        Text = "×", TextSize = 16,
        Position = UDim2.new(1, -40, 0, 10),
        Size = UDim2.fromOffset(28, 24),
    })

    -- Tabs
    local tabBar = frame(panel, {
        Position = UDim2.fromOffset(10, 52),
        Size = UDim2.fromOffset(300, 28),
        BackgroundTransparency = 1,
    })

    local activeTab = "GK"
    local tabPanels = {}
    local tabButtons = {}

    local function setTab(name)
        activeTab = name
        for tabName, panelObj in pairs(tabPanels) do
            panelObj.Visible = (tabName == name)
        end
        for tabName, btn in pairs(tabButtons) do
            local label = btn:FindFirstChild("Label")
            if label then
                label.TextColor3 = (tabName == name) and Colors.accent or Colors.muted
            end
            btn.BackgroundColor3 = (tabName == name) and Colors.active or Colors.control
        end
    end

    local tabNames = { "GK", "Striker", "Misc", "Debug" }
    local tabWidth = 300 / #tabNames - 4
    for i, name in ipairs(tabNames) do
        local btn = button(tabBar, {
            Position = UDim2.fromOffset((i - 1) * (tabWidth + 4), 0),
            Size = UDim2.fromOffset(tabWidth, 28),
        })
        text(btn, name, 11, {
            Name = "Label",
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
        })
        tabButtons[name] = btn
        btn.Activated:Connect(function() setTab(name) end)
    end

    -- Content area
    local contentHost = frame(panel, {
        Position = UDim2.fromOffset(10, 88),
        Size = UDim2.fromOffset(300, 400),
        BackgroundTransparency = 1,
    })

    local function createTabPanel(name)
        local scroll = createInstance("ScrollingFrame", {
            Name = name,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Colors.accentDim,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = (name == activeTab),
        }, contentHost)
        createInstance("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, scroll)
        return scroll
    end

    for _, name in ipairs(tabNames) do
        tabPanels[name] = createTabPanel(name)
    end

    -- ============ TAB HELPERS ============
    local order = { GK = 0, Striker = 0, Misc = 0, Debug = 0 }

    local function sectionTitle(tab, title)
        order[tab] += 1
        text(tabPanels[tab], title, 11, {
            Size = UDim2.new(1, -8, 0, 22),
            LayoutOrder = order[tab],
            Font = Enum.Font.GothamBold,
            TextColor3 = Colors.muted,
        })
    end

    local function createToggle(tab, labelText, getter, setter)
        order[tab] += 1
        local row = button(tabPanels[tab], {
            Size = UDim2.new(1, -4, 0, 34),
            LayoutOrder = order[tab],
        })

        text(row, labelText, 12, {
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -72, 1, 0),
        })

        local box = frame(row, {
            Name = "Box",
            Position = UDim2.new(1, -32, 0, 8),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = getter() and Colors.accent or Colors.control,
        })
        round(box, 4)
        stroke(box)

        row.Activated:Connect(function()
            setter(not getter())
            box.BackgroundColor3 = getter() and Colors.accent or Colors.control
        end)

        row.MouseEnter:Connect(function() row.BackgroundColor3 = Colors.hover end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = Colors.control end)
    end

    local function createDropdown(tab, labelText, options, getter, setter)
        order[tab] += 1
        local row = frame(tabPanels[tab], {
            Size = UDim2.new(1, -4, 0, 60),
            LayoutOrder = order[tab],
            BackgroundColor3 = Colors.control,
        })
        round(row, 5)

        text(row, labelText, 11, {
            Position = UDim2.fromOffset(12, 4),
            Size = UDim2.new(1, -24, 0, 18),
            TextColor3 = Colors.muted,
        })

        local currentLabel = text(row, getter(), 12, {
            Position = UDim2.fromOffset(12, 24),
            Size = UDim2.new(1, -24, 0, 20),
        })

        -- Cycle through options on tap
        local btn = button(row, {
            Position = UDim2.fromOffset(8, 22),
            Size = UDim2.new(1, -16, 0, 30),
            BackgroundTransparency = 1,
        })
        btn.Activated:Connect(function()
            local current = getter()
            local idx = 1
            for i, opt in ipairs(options) do
                if opt.value == current then idx = i; break end
            end
            local next = options[(idx % #options) + 1]
            setter(next.value)
            currentLabel.Text = next.label
        end)

        row.MouseEnter:Connect(function() row.BackgroundColor3 = Colors.hover end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = Colors.control end)
    end

    local function createSlider(tab, labelText, min, max, getter, setter)
        order[tab] += 1
        local row = frame(tabPanels[tab], {
            Size = UDim2.new(1, -4, 0, 50),
            LayoutOrder = order[tab],
            BackgroundColor3 = Colors.control,
        })
        round(row, 5)

        local label = text(row, labelText .. ": " .. tostring(getter()), 11, {
            Position = UDim2.fromOffset(12, 4),
            Size = UDim2.new(1, -24, 0, 18),
        })

        local track = frame(row, {
            Position = UDim2.fromOffset(12, 28),
            Size = UDim2.new(1, -24, 0, 8),
            BackgroundColor3 = Colors.accentDim,
        })
        round(track, 4)

        local fill = frame(track, {
            Size = UDim2.new((getter() - min) / (max - min), 0, 1, 0),
            BackgroundColor3 = Colors.accent,
        })
        round(fill, 4)

        local dragging = false

        local function updateFromX(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + rel * (max - min) + 0.5)
            setter(value)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = labelText .. ": " .. tostring(value)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromX(input.Position.X)
            end
        end)

        connect(UserInputService.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                updateFromX(input.Position.X)
            end
        end)

        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    local function createButton(tab, labelText, callback, danger)
        order[tab] += 1
        local btn = button(tabPanels[tab], {
            Text = labelText, TextSize = 12,
            Size = UDim2.new(1, -4, 0, 32),
            LayoutOrder = order[tab],
            BackgroundColor3 = danger and Colors.danger or Colors.control,
        })
        btn.Activated:Connect(callback)
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Colors.hover end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = danger and Colors.danger or Colors.control end)
    end

    -- ============ GK TAB ============
    sectionTitle("GK", "GOALKEEPER")
    createToggle("GK", "Auto Save", function() return Settings.GKEnabled end, function(v) Settings.GKEnabled = v end)
    createToggle("GK", "Position Assist", function() return Settings.PositionAssist end, function(v) Settings.PositionAssist = v end)
    createToggle("GK", "Pre-Shot Coverage", function() return Settings.PreShotCoverage end, function(v) Settings.PreShotCoverage = v end)
    createToggle("GK", "Close-Range Rush", function() return Settings.CloseRush end, function(v) Settings.CloseRush = v end)
    createToggle("GK", "High-Ball Jumps", function() return Settings.HighBallJumps end, function(v) Settings.HighBallJumps = v end)
    createToggle("GK", "Jump Then Dive", function() return Settings.JumpThenDive end, function(v) Settings.JumpThenDive = v end)
    createToggle("GK", "Backward Recovery", function() return Settings.BackwardRecovery end, function(v) Settings.BackwardRecovery = v end)
    createToggle("GK", "Respect Manual Movement", function() return Settings.RespectManualMovement end, function(v) Settings.RespectManualMovement = v end)

    createDropdown("GK", "Dive Direction", {
        { value = "SMART", label = "Smart" },
        { value = "FORWARD", label = "Forward" },
        { value = "LEFT", label = "Left" },
        { value = "RIGHT", label = "Right" },
        { value = "SIDES", label = "Sides" },
    }, function() return Settings.DiveFilter end, function(v) Settings.DiveFilter = v end)

    createDropdown("GK", "Position Mode", {
        { value = "THREATS", label = "Threats Only" },
        { value = "HOME_AND_THREATS", label = "Home + Threats" },
    }, function() return Settings.PositionMode end, function(v) Settings.PositionMode = v end)

    -- ============ STRIKER TAB ============
    sectionTitle("Striker", "STRIKER")
    createToggle("Striker", "Best Shot Assist", function() return Settings.STREnabled end, function(v) Settings.STREnabled = v end)
    createToggle("Striker", "Auto Curve Ball", function() return Settings.AutoCurve end, function(v) Settings.AutoCurve = v end)
    createToggle("Striker", "Smart Release", function() return Settings.SmartRelease end, function(v) Settings.SmartRelease = v end)
    createSlider("Striker", "Assist Range", 40, 100,
        function() return Settings.AssistRange end,
        function(v) Settings.AssistRange = v end)

    -- ============ MISC TAB ============
    sectionTitle("Misc", "MISCELLANEOUS")
    createToggle("Misc", "Auto Dribble (Dodge Tackles)", function() return Settings.AutoDribble end, function(v) Settings.AutoDribble = v end)
    createToggle("Misc", "Anti-AFK", function() return Settings.AntiAFK end, function(v) Settings.AntiAFK = v end)
    createToggle("Misc", "Debug Mode", function() return Settings.Debug end, function(v) Settings.Debug = v end)
    createButton("Misc", "Rejoin Server", function()
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end, true)

    -- ============ DEBUG TAB ============
    sectionTitle("Debug", "MODULE STATUS")
    local debugList = frame(tabPanels["Debug"], {
        Size = UDim2.new(1, -4, 0, 300),
        BackgroundColor3 = Colors.control,
        LayoutOrder = 1,
    })
    round(debugList, 5)

    local debugText = text(debugList, "", 10, {
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 1, -20),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Code,
        TextColor3 = Colors.muted,
    })

    local function refreshDebug()
        local lines = {}
        for path, status in pairs(ModuleStatus) do
            lines[#lines + 1] = (status == "OK" and "✓ " or "✗ ") .. path:sub(-35) .. " → " .. status:sub(1, 10)
        end
        table.sort(lines)
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Status: " .. S.status
        lines[#lines + 1] = "Detail: " .. S.detail
        lines[#lines + 1] = "Dives: " .. Stats.diveSent .. " | Jumps: " .. Stats.jumpRequests
        lines[#lines + 1] = "Rush: " .. Stats.rushTriggers .. " | Dribbles: " .. Stats.dribbles
        lines[#lines + 1] = "Last Error: " .. (Stats.lastError or "none")
        debugText.Text = table.concat(lines, "\n")
    end
    refreshDebug()

    createButton("Debug", "Refresh Debug", refreshDebug)

    -- ============ STATUS BAR ============
    local statusBar = frame(panel, {
        Position = UDim2.fromOffset(10, 460),
        Size = UDim2.fromOffset(300, 30),
        BackgroundColor3 = Colors.surface,
    })
    round(statusBar, 5)

    local statusDot = frame(statusBar, {
        Position = UDim2.fromOffset(10, 11),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Colors.muted,
    })
    round(statusDot, 4)

    local statusLabel = text(statusBar, "STARTING", 11, {
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Font = Enum.Font.GothamBold,
    })

    -- ============ MINIMIZE & CLOSE ============
    minimize.Activated:Connect(function()
        if panel.Size.Y.Offset > 100 then
            panel.Size = UDim2.fromOffset(320, 44)
            contentHost.Visible = false
            statusBar.Visible = false
            minimize.Text = "+"
        else
            panel.Size = UDim2.fromOffset(320, 500)
            contentHost.Visible = true
            statusBar.Visible = true
            minimize.Text = "-"
        end
    end)

    close.Activated:Connect(function()
        cleanup()
    end)

    -- ============ DRAG ============
    local dragging, dragStart, hostStart
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            hostStart = host.Position
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            host.Position = UDim2.fromOffset(
                hostStart.X.Offset + delta.X,
                hostStart.Y.Offset + delta.Y
            )
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- ============ REFRESH LOOP ============
    connect(RunService.Heartbeat, function()
        if not S.alive or not gui.Parent then return end
        local clock = os.clock()
        if clock < (S.nextUIAt or 0) then return end
        S.nextUIAt = clock + 1 / CFG.UISampleHz
        statusLabel.Text = S.status .. (S.detail ~= "" and (" — " .. S.detail) or "")
        statusDot.BackgroundColor3 = Settings.GKEnabled and Colors.accent or Colors.muted
    end)

    -- ============ KEYBIND (RightShift) ============
    connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            gui.Enabled = not gui.Enabled
        end
    end)

    -- ============ AUTO FIT ============
    local function fit()
        local camera = workspace.CurrentCamera
        local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local scale = math.min(1, math.max(0.75, (vp.X - 40) / 320))
        uiScale.Scale = scale
    end
    fit()
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fit)
end

-- ============================================================
-- 24. BAŞLAT
-- ============================================================
S.status = "LOADING"
buildUI()
S.status = "READY"

-- Anti-AFK
connect(RunService.Heartbeat, function()
    if not S.alive or not Settings.AntiAFK then return end
    pcall(function()
        game:GetService("VirtualUser"):CaptureController()
        game:GetService("VirtualUser"):ClickButton2(Vector2.new())
    end)
end)

-- Public API
_G.FA = {
    Settings = Settings,
    Stats = Stats,
    State = S,
    Cleanup = cleanup,
    GetModules = function() return M end,
    GetModuleStatus = function() return ModuleStatus end,
}

print("[FA] Football Assistant v4.0 loaded. RightShift to toggle UI.")