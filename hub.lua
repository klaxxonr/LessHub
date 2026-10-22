-- Illegal Soccer Assist (Rayfield Edition) v2.0
-- Mobile / Delta / Xeno compatible

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local LP = Players.LocalPlayer

-- ============================================================
-- 1. RAYFIELD LOAD (mobile-first)
-- ============================================================
local Rayfield
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not Rayfield then
    pcall(function()
        Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
    end)
end

if not Rayfield then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "IS Assist",
            Text = "Rayfield could not be loaded. Check internet.",
            Duration = 5
        })
    end)
    return
end

-- Use CreateMobile if available (best for touch), else CreateWindow
local Window
if Rayfield.CreateMobile then
    pcall(function()
        Window = Rayfield:CreateMobile({
            Name = "IS Assist",
            LoadingTitle = "Loading...",
            LoadingSubtitle = "Mobile Edition",
        })
    end)
end
if not Window then
    Window = Rayfield:CreateWindow({
        Name = "IS Assist",
        LoadingTitle = "Loading...",
        LoadingSubtitle = "Mobile Edition",
        ConfigurationSaving = { Enabled = false },
        KeySystem = false,
    })
end

-- Notification
task.spawn(function()
    pcall(function()
        Rayfield:Notify({
            Title = "IS Assist",
            Content = "Script loaded successfully.",
            Duration = 4,
        })
    end)
end)

-- ============================================================
-- 2. MODULES (pcall)
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
    end
end)

-- ============================================================
-- 4. HELPERS
-- ============================================================
local sessionCounter = math.floor(workspace:GetServerTimeNow() * 1e6)
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
    if v and v.Magnitude > 0 then return v.Unit end
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

local function getGoalPos()
    if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
        local ok, goal = pcall(function() return M.PracticeSession.GetDefendedGoalPart() end)
        if ok and goal and goal.Position then return goal.Position end
    end
    local g = workspace:FindFirstChild("Goal", true)
    if g and g:IsA("BasePart") then return g.Position end
    return nil
end

-- ============================================================
-- 5. COMMAND BUILDERS
-- ============================================================
local function buildShotStart(aimDir)
    local root = getRoot()
    local ballPos = getBallPos() or Vector3.new(0, 0, 0)
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
                Direction = aimDir,
                Origin = ballPos,
                CameraCFrame = getCam().CFrame,
                IsAirborne = false,
            },
            PassType = "Shot",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Kind = "Tackle",
            Mode = "Kick",
            KickDirection = aimDir,
        }
    }, sid, now
end

local function buildShotRelease(aimDir, sid, startTime, curve)
    local root = getRoot()
    local ballPos = getBallPos() or Vector3.new(0, 0, 0)
    local cmd = {
        Phase = "Release",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = 0.4,
            ChargeStartedAt = startTime,
            SessionId = sid,
            ShotTime = workspace:GetServerTimeNow(),
            AimDirection = {
                Direction = aimDir,
                Origin = ballPos,
                CameraCFrame = getCam().CFrame,
                IsAirborne = false,
            },
            PassType = "Shot",
            KickDirection = aimDir,
            Kind = "Tackle",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Mode = "Kick",
            ChargeSeconds = 0.4,
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

-- ============================================================
-- 6. FEATURES (same as before, Rayfield-independent)
-- ============================================================
local featureState = {
    infiniteStamina = false,
    speedMult = 1.0,
    jumpBoost = false,
    perfectShot = false,
    curveMode = "OFF",
    autoDribble = false,
    autoGK = false,
    diveDir = "SMART",
    highBall = false,
    esp = false,
    teleport = false,
}

local function applyInfiniteStamina(enable)
    if not M.Sprint then return end
    if enable then
        pcall(function() M.Sprint.SetUnlimitedStamina("v6") end)
    else
        pcall(function()
            if M.Sprint.ClearUnlimitedStaminaSource then
                M.Sprint.ClearUnlimitedStaminaSource("v6")
            end
        end)
    end
end

local function applySpeed(mult)
    if not M.Movement then return end
    local char = LP.Character
    if char then pcall(function() M.Movement.SetMultiplier(char, mult) end) end
end

local function applyJump(enable)
    local hum = getHum()
    if hum then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = enable and 120 or 50
        end)
    end
end

local function firePerfectShot(overrideCurve)
    if not Remotes.Tackle then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local goalPos = getGoalPos(); if not goalPos then return end

    local gkPos = nil
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
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
    end)

    local offset = Vector3.new(0, 2, 0)
    if gkPos then
        local lat = Vector3.new((gkPos - goalPos).X, 0, (gkPos - goalPos).Z)
        if lat.Magnitude > 0.1 then offset = lat.Unit * 8 + Vector3.new(0, 2, 0) end
    end
    local target = goalPos + offset
    local dir = unit(target - ballPos)

    local curve = 0
    if overrideCurve then curve = overrideCurve
    elseif gkPos then
        local lat = Vector3.new((gkPos - goalPos).X, 0, (gkPos - goalPos).Z)
        if lat.Magnitude > 0.1 then
            curve = lat.Unit:Dot(unit(goalPos - ballPos)) > 0 and -1 or 1
        end
    end

    local startCmd, sid, startTime = buildShotStart(dir)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(0.42)
    pcall(function() Remotes.Tackle:FireServer(buildShotRelease(dir, sid, startTime, curve)) end)
end

local function fireFakeShot()
    if not Remotes.Tackle then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local goalPos = getGoalPos() or (ballPos + Vector3.new(0, 0, 20))
    local dir = unit(goalPos - ballPos)
    local startCmd = buildShotStart(dir)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(0.15)
    pcall(function() Remotes.Tackle:FireServer(buildDodge(dir)) end)
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
    if not wallPos then wallPos = ballPos - unit(getCam().CFrame.LookVector) * 20 end
    local dir = unit(wallPos - ballPos)
    local startCmd, sid, startTime = buildShotStart(dir)
    pcall(function() Remotes.Tackle:FireServer(startCmd) end)
    task.wait(0.42)
    pcall(function() Remotes.Tackle:FireServer(buildShotRelease(dir, sid, startTime, 0)) end)
end

local function firePerfectPass()
    if not Remotes.Kick then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local teammateId, bestDist = nil, math.huge
    pcall(function()
        if M.Actors and M.Actors.GetAllCharacterModels then
            for _, model in ipairs(M.Actors.GetAllCharacterModels()) do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    local same = false
                    pcall(function()
                        if M.ActorTeams and M.ActorTeams.GetCharacterTeamName then
                            same = (M.ActorTeams.GetCharacterTeamName(LP.Character) == M.ActorTeams.GetCharacterTeamName(model))
                        end
                    end)
                    if same then
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (hrp.Position - ballPos).Magnitude
                            if d < bestDist then bestDist = d; teammateId = plr.UserId end
                        end
                    end
                end
            end
        end
    end)
    if not teammateId then return end

    local root = getRoot()
    local cmd = {
        Phase = "Release",
        Protocol = "ActionSession",
        Command = {
            MaximumChargeSeconds = 0.4,
            ChargeStartedAt = workspace:GetServerTimeNow(),
            SessionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            AimDirection = {
                Direction = unit(getCam().CFrame.LookVector),
                Origin = ballPos,
                CameraCFrame = getCam().CFrame,
                IsAirborne = false,
            },
            PassType = "AssistedPass",
            TargetUserId = teammateId,
            KickDirection = unit(getCam().CFrame.LookVector),
            Kind = "Tackle",
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            Mode = "Kick",
            ChargeSeconds = 0.4,
        }
    }
    pcall(function() Remotes.Kick:FireServer(cmd) end)
end

local function fireRainbowFlick()
    if not Remotes.Tackle then return end
    local root = getRoot()
    local dir = unit(getCam().CFrame.LookVector)
    local cmd1 = {
        Protocol = "ActionCommand",
        Command = {
            Kind = "RainbowFlick",
            ActionId = newSessionId(),
            ShotTime = workspace:GetServerTimeNow(),
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
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
            PlayerVelocity = root and root.AssemblyLinearVelocity or Vector3.new(0, 0, 0),
            AimDirection = dir,
        }
    }
    pcall(function() Remotes.Tackle:FireServer(cmd2) end)
end

-- Auto Dribble listener
local lastDodge = 0
if Remotes.Tackle then
    Remotes.Tackle.OnClientEvent:Connect(function(...)
        pcall(function()
            if not featureState.autoDribble then return end
            local cmd = select(1, ...)
            if type(cmd) ~= "table" then return end
            local c = cmd.Command or cmd
            if not c or c.Kind ~= "Tackle" then return end
            if c.Mode ~= "Slide" and c.Mode ~= "Kick" and c.Mode ~= "Volley" then return end
            if c.ActorUserId == LP.UserId then return end
            local oppRoot = nil
            pcall(function()
                if M.Actors and M.Actors.GetByUserId then
                    local actor = M.Actors.GetByUserId(c.ActorUserId)
                    if actor then
                        local model = M.Actors.GetCharacter(actor)
                        if model then oppRoot = model:FindFirstChild("HumanoidRootPart") end
                    end
                end
            end)
            if not oppRoot then return end
            local myRoot = getRoot(); if not myRoot then return end
            if (oppRoot.Position - myRoot.Position).Magnitude < 8 then
                if tick() - lastDodge < 1 then return end
                lastDodge = tick()
                local away = unit(myRoot.Position - oppRoot.Position)
                pcall(function() Remotes.Tackle:FireServer(buildDodge(away)) end)
            end
        end)
    end)
end

-- Auto GK
local lastDive = 0
local function autoGKTick()
    if not featureState.autoGK then return end
    local char = LP.Character; if not char then return end
    local isGK = false
    pcall(function()
        if M.MatchSettings and M.MatchSettings.IsGoalkeeperCharacter then
            isGK = M.MatchSettings.IsGoalkeeperCharacter(char)
        end
    end)
    if not isGK then return end
    if tick() - lastDive < 1.2 then return end

    local ballPos = getBallPos(); if not ballPos then return end
    local goal = nil
    pcall(function()
        if M.PracticeSession and M.PracticeSession.GetDefendedGoalPart then
            goal = M.PracticeSession.GetDefendedGoalPart()
        end
    end)
    if not goal then return end
    if (ballPos - goal.Position).Magnitude > 40 then return end

    local root = getRoot(); if not root then return end
    local d = featureState.diveDir
    local dirName = "F"
    if d == "SMART" then
        local lat = Vector3.new((ballPos - goal.Position).X, 0, (ballPos - goal.Position).Z)
        if lat.Magnitude > 3 then
            local myLat = Vector3.new((root.Position - goal.Position).X, 0, (root.Position - goal.Position).Z)
            dirName = myLat:Dot(lat.Unit) > 0 and "R" or "L"
        end
    elseif d == "LEFT" then dirName = "L"
    elseif d == "RIGHT" then dirName = "R"
    elseif d == "SIDES" then dirName = (ballPos - goal.Position).X > 0 and "R" or "L"
    end

    local dived = false
    if M.GoalkeeperDive and M.GoalkeeperDive.Run then
        pcall(function()
            local choice = M.GoalkeeperDive.GetDirectionChoiceByName and M.GoalkeeperDive.GetDirectionChoiceByName(dirName)
            if choice then
                local basisFn = function() return CFrame.new(goal.Position, goal.Position + Vector3.new(0, 0, -1)) end
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
    lastDive = tick()
end

-- ESP
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
            bb.Size = UDim2.new(0, 40, 0, 20)
            bb.AlwaysOnTop = true
            bb.Adornee = hrp
            bb.Parent = LP.PlayerGui
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = model.Name
            lbl.TextColor3 = Color3.fromRGB(255, 255, 100)
            lbl.TextSize = 10
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

-- Teleport
local function teleportTick()
    if not featureState.teleport then return end
    local ballPos = getBallPos(); if not ballPos then return end
    local hrp = getRoot(); if not hrp then return end
    pcall(function() hrp.CFrame = CFrame.new(ballPos + Vector3.new(0, 5, 0)) end)
end

-- ============================================================
-- 7. RAYFIELD UI (Tabs & Elements)
-- ============================================================
local Tabs = {}

-- MOVEMENT
Tabs.Movement = Window:CreateTab("MOVEMENT")
Tabs.Movement:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Flag = "InfStam",
    Callback = function(v)
        featureState.infiniteStamina = v
        applyInfiniteStamina(v)
    end,
})
Tabs.Movement:CreateSlider({
    Name = "Speed Multiplier",
    Range = {1.0, 2.5},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1.0,
    Flag = "SpeedMult",
    Callback = function(v)
        featureState.speedMult = v
        applySpeed(v)
    end,
})
Tabs.Movement:CreateToggle({
    Name = "Jump Boost (120)",
    CurrentValue = false,
    Flag = "JumpBoost",
    Callback = function(v)
        featureState.jumpBoost = v
        applyJump(v)
    end,
})

-- SHOT
Tabs.Shot = Window:CreateTab("SHOT")
Tabs.Shot:CreateToggle({
    Name = "Perfect Shot (Auto Aim)",
    CurrentValue = false,
    Flag = "PerfectShot",
    Callback = function(v) featureState.perfectShot = v end,
})
Tabs.Shot:CreateDropdown({
    Name = "Curve Mode",
    Options = {"OFF", "LEFT", "RIGHT", "AUTO"},
    CurrentOption = {"OFF"},
    MultipleOptions = false,
    Flag = "CurveMode",
    Callback = function(v)
        featureState.curveMode = v[1] or "OFF"
    end,
})
Tabs.Shot:CreateButton({
    Name = "FAKE SHOT",
    Callback = function() pcall(fireFakeShot) end,
})
Tabs.Shot:CreateButton({
    Name = "WALL SHOT",
    Callback = function() pcall(fireWallShot) end,
})
Tabs.Shot:CreateButton({
    Name = "PERFECT PASS",
    Callback = function() pcall(firePerfectPass) end,
})

-- DRIBBLE
Tabs.Dribble = Window:CreateTab("DRIBBLE")
Tabs.Dribble:CreateToggle({
    Name = "Auto Dribble (Dodge)",
    CurrentValue = false,
    Flag = "AutoDribble",
    Callback = function(v) featureState.autoDribble = v end,
})
Tabs.Dribble:CreateButton({
    Name = "RAINBOW FLICK",
    Callback = function() pcall(fireRainbowFlick) end,
})

-- GOALKEEPER
Tabs.GK = Window:CreateTab("GOALKEEPER")
Tabs.GK:CreateToggle({
    Name = "Auto Goalkeeper",
    CurrentValue = false,
    Flag = "AutoGK",
    Callback = function(v) featureState.autoGK = v end,
})
Tabs.GK:CreateDropdown({
    Name = "Dive Direction",
    Options = {"SMART", "FORWARD", "LEFT", "RIGHT", "SIDES"},
    CurrentOption = {"SMART"},
    MultipleOptions = false,
    Flag = "DiveDir",
    Callback = function(v) featureState.diveDir = v[1] or "SMART" end,
})
Tabs.GK:CreateToggle({
    Name = "High Ball Jumps",
    CurrentValue = false,
    Flag = "HighBall",
    Callback = function(v) featureState.highBall = v end,
})

-- MISC
Tabs.Misc = Window:CreateTab("MISC")
Tabs.Misc:CreateToggle({
    Name = "ESP (Boxes)",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(v) featureState.esp = v end,
})
Tabs.Misc:CreateButton({
    Name = "REJOIN SERVER",
    Callback = function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    end,
})
Tabs.Misc:CreateToggle({
    Name = "Teleport To Ball (RISKY)",
    CurrentValue = false,
    Flag = "Teleport",
    Callback = function(v) featureState.teleport = v end,
})
Tabs.Misc:CreateButton({
    Name = "UNLOAD SCRIPT",
    Callback = function()
        pcall(function()
            if Window and Window.Destroy then Window:Destroy() end
        end)
        _G.FootballAssist = nil
    end,
})

-- ============================================================
-- 8. MAIN LOOP (Heartbeat)
-- ============================================================
RunService.Heartbeat:Connect(function()
    xpcall(function()
        -- Perfect shot auto-fire
        if featureState.perfectShot and Remotes.Tackle then
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
                    local curve = nil
                    if featureState.curveMode == "LEFT" then curve = -1
                    elseif featureState.curveMode == "RIGHT" then curve = 1
                    elseif featureState.curveMode == "OFF" then curve = 0 end
                    firePerfectShot(curve)
                end
            end
        end
        autoGKTick()
        updateESP()
        teleportTick()
    end, function() end)
end)

-- ============================================================
-- 9. PUBLIC API
-- ============================================================
_G.FootballAssist = {
    Window = Window,
    Modules = M,
    Remotes = Remotes,
    Features = featureState,
    FirePerfectShot = firePerfectShot,
    FireFakeShot = fireFakeShot,
    FireWallShot = fireWallShot,
    FirePerfectPass = firePerfectPass,
    FireRainbowFlick = fireRainbowFlick,
    Version = "2.0-Rayfield",
}

print("[IS Assist] Rayfield edition loaded.") 