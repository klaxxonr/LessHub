--[[
    LessHub - Illegal Soccer
    Rayfield UI | Delta + Mobile
    Remotes: Ball.Kick / Tackle / RainbowFlick (spy log)
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "LessHub | Illegal Soccer",
    LoadingTitle = "LessHub",
    LoadingSubtitle = "Illegal Soccer",
    Theme = "Default",
    ToggleUIKeybind = "K",
    ConfigurationSaving = { Enabled = false },
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local BallRemotes = Remotes and Remotes:FindFirstChild("Ball")
local CharRemotes = Remotes and Remotes:FindFirstChild("Characters")
local ItemRemotes = Remotes and Remotes:FindFirstChild("Items")

local KickRemote = BallRemotes and BallRemotes:FindFirstChild("Kick")
local TackleRemote = BallRemotes and BallRemotes:FindFirstChild("Tackle")
local FlickRemote = BallRemotes and BallRemotes:FindFirstChild("RainbowFlick")
local CallPassRemote = BallRemotes and BallRemotes:FindFirstChild("CallForPass")
local GKClearRemote = BallRemotes and BallRemotes:FindFirstChild("ForcedGoalkeeperClear")
local GKClearRelease = BallRemotes and BallRemotes:FindFirstChild("ForcedGoalkeeperClearRelease")
local BoostRemote = CharRemotes and CharRemotes:FindFirstChild("MovementBoost")
local RagdollRemote = CharRemotes and CharRemotes:FindFirstChild("Ragdoll")
local ItemRequest = ItemRemotes and ItemRemotes:FindFirstChild("Request")

-- Settings
local S = {
    AutoDodge = false,
    DodgeDistance = 10,
    AutoSlide = false,
    SlideDistance = 12,
    AutoFlick = false,
    AutoPass = false,
    PerfectShot = false,
    AutoVolley = false,
    CurveShot = false,
    FakeShot = false,
    CallForPass = false,
    AutoItem = false,
    GKClear = false,
    KickPower = false,
    AntiRagdoll = false,
    AntiStun = false,
    InfiniteStamina = false,
    Speed = false,
    SpeedValue = 1.3,
    Fly = false,
    FlySpeed = 50,
    BallESP = false,
    PlayerESP = false,
    Fullbright = false,
    FPSBoost = false,
}

local idCounter = 0
local function nextId()
    idCounter += 1
    return (math.floor(tick() * 1e6) % 1e12) * 1000 + idCounter
end

local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function getBall()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name == "Ball" or v.Name:lower():find("ball")) and v.Size.Magnitude < 12 then
            return v
        end
    end
end

local function aimDir()
    local look = Camera.CFrame.LookVector
    return Vector3.new(look.X, 0, look.Z).Unit
end

local function playerVel(root)
    return root and root.AssemblyLinearVelocity or Vector3.zero
end

local function fireTackle(cmd)
    if not TackleRemote then return end
    pcall(function()
        TackleRemote:FireServer({
            Protocol = "ActionCommand",
            Command = cmd,
        })
    end)
end

local function fireKickSession(phase, cmd)
    if not KickRemote then return end
    pcall(function()
        KickRemote:FireServer({
            Phase = phase,
            Protocol = "ActionSession",
            Command = cmd,
        })
    end)
end

local function fireFlick(cmd)
    if not FlickRemote then return end
    pcall(function()
        FlickRemote:FireServer({
            Protocol = "ActionCommand",
            Command = cmd,
        })
    end)
end

-- ========== TABS ==========
local TabAuto = Window:CreateTab("Auto", "zap")
local TabShot = Window:CreateTab("Shooting", "target")
local TabMove = Window:CreateTab("Movement", "person-standing")
local TabVis = Window:CreateTab("Visuals", "eye")
local TabMisc = Window:CreateTab("Misc", "settings")

-- AUTO
TabAuto:CreateToggle({
    Name = "Auto Dodge",
    CurrentValue = false,
    Flag = "AutoDodge",
    Callback = function(v) S.AutoDodge = v end,
})
TabAuto:CreateSlider({
    Name = "Dodge Distance",
    Range = {6, 16},
    Increment = 0.5,
    CurrentValue = 10,
    Flag = "DodgeDist",
    Callback = function(v) S.DodgeDistance = v end,
})
TabAuto:CreateToggle({
    Name = "Auto Slide Tackle",
    CurrentValue = false,
    Flag = "AutoSlide",
    Callback = function(v) S.AutoSlide = v end,
})
TabAuto:CreateSlider({
    Name = "Slide Distance",
    Range = {8, 20},
    Increment = 0.5,
    CurrentValue = 12,
    Flag = "SlideDist",
    Callback = function(v) S.SlideDistance = v end,
})
TabAuto:CreateToggle({
    Name = "Auto Rainbow Flick",
    CurrentValue = false,
    Flag = "AutoFlick",
    Callback = function(v) S.AutoFlick = v end,
})
TabAuto:CreateToggle({
    Name = "Auto Pass (Assisted)",
    CurrentValue = false,
    Flag = "AutoPass",
    Callback = function(v) S.AutoPass = v end,
})
TabAuto:CreateToggle({
    Name = "Call For Pass",
    CurrentValue = false,
    Flag = "CallPass",
    Callback = function(v) S.CallForPass = v end,
})
TabAuto:CreateToggle({
    Name = "Auto Use Item",
    CurrentValue = false,
    Flag = "AutoItem",
    Callback = function(v) S.AutoItem = v end,
})
TabAuto:CreateToggle({
    Name = "GK Forced Clear",
    CurrentValue = false,
    Flag = "GKClear",
    Callback = function(v) S.GKClear = v end,
})

-- SHOOTING
TabShot:CreateToggle({
    Name = "Perfect Shot (Aim to Goal)",
    CurrentValue = false,
    Flag = "PerfectShot",
    Callback = function(v) S.PerfectShot = v end,
})
TabShot:CreateToggle({
    Name = "Auto Volley",
    CurrentValue = false,
    Flag = "AutoVolley",
    Callback = function(v) S.AutoVolley = v end,
})
TabShot:CreateToggle({
    Name = "Curve Shot",
    CurrentValue = false,
    Flag = "CurveShot",
    Callback = function(v) S.CurveShot = v end,
})
TabShot:CreateToggle({
    Name = "Fake Shot",
    CurrentValue = false,
    Flag = "FakeShot",
    Callback = function(v) S.FakeShot = v end,
})
TabShot:CreateButton({
    Name = "Manual Rainbow Flick",
    Callback = function()
        local root = getRoot()
        if not root then return end
        local id = nextId()
        fireFlick({
            PlayerVelocity = playerVel(root),
            Kind = "RainbowFlick",
            ShotTime = tick(),
            ActionId = id,
        })
        task.delay(0.35, function()
            local r2 = getRoot()
            fireFlick({
                Mode = "RainbowFlickDetach",
                ActionId = nextId(),
                PlayerVelocity = r2 and playerVel(r2) or Vector3.zero,
                Kind = "RainbowFlick",
                ShotTime = tick(),
                AimDirection = aimDir(),
            })
        end)
    end,
})
TabShot:CreateButton({
    Name = "Manual Slide",
    Callback = function()
        local root = getRoot()
        if not root then return end
        fireTackle({
            Mode = "Slide",
            ActionId = nextId(),
            PlayerVelocity = playerVel(root),
            Kind = "Tackle",
            ShotTime = tick(),
            AimDirection = aimDir(),
        })
    end,
})
TabShot:CreateButton({
    Name = "Manual Dodge",
    Callback = function()
        local root = getRoot()
        if not root then return end
        local id = nextId()
        fireTackle({
            Mode = "Dodge",
            ActionId = id,
            PlayerVelocity = playerVel(root),
            Kind = "Tackle",
            ShotTime = tick(),
            AimDirection = aimDir(),
        })
        task.delay(0.25, function()
            local r2 = getRoot()
            fireTackle({
                Mode = "DodgeEnd",
                ActionId = nextId(),
                PlayerVelocity = r2 and playerVel(r2) or Vector3.zero,
                Kind = "Tackle",
                ShotTime = tick(),
            })
        end)
    end,
})

-- MOVEMENT
TabMove:CreateToggle({
    Name = "Request Kick Power",
    CurrentValue = false,
    Flag = "KickPower",
    Callback = function(v) S.KickPower = v end,
})
TabMove:CreateToggle({
    Name = "Anti Ragdoll",
    CurrentValue = false,
    Flag = "AntiRagdoll",
    Callback = function(v) S.AntiRagdoll = v end,
})
TabMove:CreateToggle({
    Name = "Infinite Stamina (client)",
    CurrentValue = false,
    Flag = "InfStamina",
    Callback = function(v) S.InfiniteStamina = v end,
})
TabMove:CreateToggle({
    Name = "Speed Boost",
    CurrentValue = false,
    Flag = "Speed",
    Callback = function(v) S.Speed = v end,
})
TabMove:CreateSlider({
    Name = "Speed Multiplier",
    Range = {1, 2.5},
    Increment = 0.1,
    CurrentValue = 1.3,
    Flag = "SpeedVal",
    Callback = function(v) S.SpeedValue = v end,
})
TabMove:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "Fly",
    Callback = function(v) S.Fly = v end,
})
TabMove:CreateSlider({
    Name = "Fly Speed",
    Range = {20, 120},
    Increment = 5,
    CurrentValue = 50,
    Flag = "FlySpd",
    Callback = function(v) S.FlySpeed = v end,
})

-- VISUALS
TabVis:CreateToggle({
    Name = "Ball ESP",
    CurrentValue = false,
    Flag = "BallESP",
    Callback = function(v) S.BallESP = v end,
})
TabVis:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "PlayerESP",
    Callback = function(v) S.PlayerESP = v end,
})
TabVis:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "Fullbright",
    Callback = function(v)
        S.Fullbright = v
        if v then
            Lighting.Brightness = 2.2
            Lighting.FogEnd = 1e5
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1
            Lighting.FogEnd = 1000
            Lighting.GlobalShadows = true
        end
    end,
})
TabVis:CreateToggle({
    Name = "FPS Boost",
    CurrentValue = false,
    Flag = "FPS",
    Callback = function(v)
        S.FPSBoost = v
        pcall(function()
            settings().Rendering.QualityLevel = v and 1 or 5
        end)
    end,
})

-- MISC
TabMisc:CreateLabel("Delta + Mobile compatible")
TabMisc:CreateLabel("SessionId may be server-checked")
TabMisc:CreateButton({
    Name = "Destroy Hub",
    Callback = function()
        Rayfield:Destroy()
    end,
})

-- ========== LOOPS ==========
local lastDodge, lastSlide, lastFlick, lastPass, lastBoost = 0, 0, 0, 0, 0
local bodyVel, bodyGyro

local function setFly(on)
    local root = getRoot()
    if on and root then
        if bodyVel then bodyVel:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bodyVel.Velocity = Vector3.zero
        bodyVel.Parent = root
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        bodyGyro.P = 12000
        bodyGyro.Parent = root
    else
        if bodyVel then bodyVel:Destroy() bodyVel = nil end
        if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    end
end

local function addESP(part, color, text)
    if part:FindFirstChild("LessESP") then return end
    local b = Instance.new("BillboardGui")
    b.Name = "LessESP"
    b.AlwaysOnTop = true
    b.Size = UDim2.new(0, 100, 0, 28)
    b.StudsOffset = Vector3.new(0, 2.4, 0)
    b.Adornee = part
    b.Parent = part
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 1, 0)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = color
    t.TextStrokeTransparency = 0.5
    t.Font = Enum.Font.GothamBold
    t.TextSize = 12
    t.Parent = b
end

RunService.Heartbeat:Connect(function()
    local root, hum = getRoot()
    if not root or not hum or hum.Health <= 0 then return end

    -- Speed
    if S.Speed then
        hum.WalkSpeed = 16 * S.SpeedValue
    end

    -- Stamina client
    if S.InfiniteStamina then
        pcall(function()
            for _, v in ipairs(LocalPlayer.Character:GetDescendants()) do
                if v:IsA("NumberValue") and v.Name:lower():find("stamina") then
                    v.Value = 999
                end
            end
        end)
    end

    -- Anti ragdoll client
    if S.AntiRagdoll then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            if hum:GetState() == Enum.HumanoidStateType.Ragdoll then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end

    -- Fly
    if S.Fly then
        if not bodyVel then setFly(true) end
        local mv = Vector3.zero
        local cam = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv -= Vector3.yAxis end
        if UserInputService.TouchEnabled and mv.Magnitude < 0.1 then
            mv = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
        end
        bodyVel.Velocity = mv.Magnitude > 0 and mv.Unit * S.FlySpeed or Vector3.zero
        bodyGyro.CFrame = cam
    elseif bodyVel then
        setFly(false)
    end

    -- Kick power spam (low rate)
    if S.KickPower and BoostRemote and tick() - lastBoost > 1.5 then
        lastBoost = tick()
        pcall(function() BoostRemote:FireServer("RequestKickPower") end)
    end

    -- Auto Dodge
    if S.AutoDodge and tick() - lastDodge > 0.45 then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr \~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local d = (root.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                if d < S.DodgeDistance then
                    lastDodge = tick()
                    local id = nextId()
                    fireTackle({
                        Mode = "Dodge",
                        ActionId = id,
                        PlayerVelocity = playerVel(root),
                        Kind = "Tackle",
                        ShotTime = tick(),
                        AimDirection = aimDir(),
                    })
                    task.delay(0.28, function()
                        local r2 = getRoot()
                        fireTackle({
                            Mode = "DodgeEnd",
                            ActionId = nextId(),
                            PlayerVelocity = r2 and playerVel(r2) or Vector3.zero,
                            Kind = "Tackle",
                            ShotTime = tick(),
                        })
                    end)
                    break
                end
            end
        end
    end

    -- Auto Slide
    if S.AutoSlide and tick() - lastSlide > 0.7 then
        local ball = getBall()
        if ball then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr \~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local er = plr.Character.HumanoidRootPart
                    if (root.Position - er.Position).Magnitude < S.SlideDistance
                        and (er.Position - ball.Position).Magnitude < 10 then
                        lastSlide = tick()
                        fireTackle({
                            Mode = "Slide",
                            ActionId = nextId(),
                            PlayerVelocity = playerVel(root),
                            Kind = "Tackle",
                            ShotTime = tick(),
                            AimDirection = (ball.Position - root.Position).Unit,
                        })
                        break
                    end
                end
            end
        end
    end

    -- Auto Flick
    if S.AutoFlick and tick() - lastFlick > 2 then
        local ball = getBall()
        if ball and (ball.Position - root.Position).Magnitude < 8 then
            lastFlick = tick()
            fireFlick({
                PlayerVelocity = playerVel(root),
                Kind = "RainbowFlick",
                ShotTime = tick(),
                ActionId = nextId(),
            })
            task.delay(0.35, function()
                local r2 = getRoot()
                fireFlick({
                    Mode = "RainbowFlickDetach",
                    ActionId = nextId(),
                    PlayerVelocity = r2 and playerVel(r2) or Vector3.zero,
                    Kind = "RainbowFlick",
                    ShotTime = tick(),
                    AimDirection = aimDir(),
                })
            end)
        end
    end

    -- Call for pass
    if S.CallForPass and CallPassRemote and tick() - lastPass > 2 then
        lastPass = tick()
        pcall(function() CallPassRemote:FireServer() end)
    end

    -- GK Clear
    if S.GKClear and GKClearRemote then
        local ball = getBall()
        if ball and (ball.Position - root.Position).Magnitude < 25 then
            pcall(function()
                GKClearRemote:FireServer()
                if GKClearRelease then
                    task.delay(0.2, function()
                        pcall(function() GKClearRelease:FireServer() end)
                    end)
                end
            end)
        end
    end
end)

-- Perfect Shot / Fake Shot: soft hook on Kick FireServer
task.spawn(function()
    if not KickRemote then return end
    local old
    if hookfunction then
        old = hookfunction(KickRemote.FireServer, function(self, data, ...)
            if typeof(data) == "table" and data.Protocol == "ActionSession" and data.Command then
                local cmd = data.Command
                if S.PerfectShot and data.Phase == "Release" then
                    -- try aim forward / camera
                    local dir = aimDir()
                    if typeof(cmd.AimDirection) == "Vector3" then
                        cmd.AimDirection = dir
                    elseif typeof(cmd.AimDirection) == "table" then
                        cmd.AimDirection.Direction = dir
                    end
                    if cmd.KickDirection then cmd.KickDirection = dir end
                    if S.CurveShot then cmd.Curve = -1 end
                end
                if S.FakeShot and data.Phase == "Start" then
                    -- cancel-like: very short charge path — user still needs to release; mark pass type
                    cmd.PassType = "FreeLowPass"
                end
                if S.AutoPass and data.Phase == "Release" then
                    cmd.PassType = "AssistedPass"
                end
            end
            return old(self, data, ...)
        end)
    end
end)

-- ESP loop
task.spawn(function()
    while task.wait(0.6) do
        if S.BallESP then
            local b = getBall()
            if b then addESP(b, Color3.fromRGB(255, 220, 0), "BALL") end
        end
        if S.PlayerESP then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr \~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local col = plr.Team and plr.Team.TeamColor.Color or Color3.fromRGB(255, 80, 80)
                    addESP(plr.Character.HumanoidRootPart, col, plr.Name)
                end
            end
        end
    end
end)

Rayfield:Notify({
    Title = "LessHub",
    Content = "Loaded | Test Auto Dodge / Slide / Flick first",
    Duration = 5,
})

print("LessHub loaded")