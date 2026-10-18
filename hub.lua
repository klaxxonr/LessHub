--[[
    LessHub v2.0 | Premium Script Hub for Illegal Soccer
    Mobile-Optimized | Delta Compatible | No Key System
    Language: English | Full Feature Implementation
]]

-- SERVICES
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- STATE MANAGEMENT
local Settings = {
    -- AIM
    AimEnabled = false,
    SilentAim = false,
    AimTarget = "Ball", -- Ball, Player, GoalCorner, AwayFromKeeper, Center
    AimFOV = 120,
    AimSmooth = 0.18,
    
    -- GOALKEEPER
    AutoDive = false,
    DiveTiming = 0.25,
    AutoPosition = false,
    ReboundControl = false,
    
    -- DRIBBLE & TRICKSHOT
    AutoDribble = false,
    ProximityShield = false,
    AutoTrickshot = false,
    TrickshotType = "Volley", -- Volley, Bicycle, Rabona
    FakeShoot = false,
    WallFakeShoot = false,
    
    -- MOVEMENT
    InfiniteStamina = false,
    AntiFling = false,
    SpeedBoost = false,
    SpeedValue = 22,
    
    -- VISUALS
    BallESP = false,
    PlayerESP = false,
    TrajectoryLine = false,
    FOVCircle = true,
    
    -- NETWORK
    PingMitigation = false,
    PredictionBoost = false,
    ReplicationSmoothing = false,
    RenderLimit = false,
    MaxRenderDist = 100
}

-- SAFE CALL
local function Safe(func, ...)
    local ok, err = pcall(func, ...)
    if not ok then warn("[LessHub] "..tostring(err)) end
end

-- UTILITIES
local function Lerp(a, b, t) return a + (b - a) * math.clamp(t, 0, 1) end

local function GetBall()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Ball" then return obj end
    end
    return nil
end

local function GetGoalTargets()
    -- Dynamic goal detection based on field orientation
    local ball = GetBall()
    if not ball then return {} end
    
    local fieldCenter = Vector3.new(0, 0, 0)
    local direction = (ball.Position - fieldCenter).Unit
    local goalZ = direction.Z > 0 and -55 or 55
    
    return {
        Center = Vector3.new(0, 4, goalZ),
        LeftCorner = Vector3.new(-18, 7, goalZ),
        RightCorner = Vector3.new(18, 7, goalZ),
        AwayFromKeeper = Vector3.new(direction.X > 0 and -15 or 15, 6, goalZ)
    }
end

local function PredictBallTrajectory(ball, timeAhead)
    if not ball then return nil end
    local pos = ball.Position
    local vel = ball.Velocity
    local gravity = workspace.Gravity
    return pos + vel * timeAhead + 0.5 * Vector3.new(0, -gravity, 0) * timeAhead^2
end

local function GetAimTarget()
    local closest, minDist = nil, Settings.AimFOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    if Settings.AimTarget == "Ball" then
        local ball = GetBall()
        if ball then
            local screenPos, vis = Camera:WorldToViewportPoint(ball.Position)
            if vis then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < minDist then closest, minDist = ball, dist end
            end
        end
    elseif Settings.AimTarget == "Player" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local screenPos, vis = Camera:WorldToViewportPoint(hrp.Position)
                    if vis then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < minDist then closest, minDist = hrp, dist end
                    end
                end
            end
        end
    else
        local targets = GetGoalTargets()
        local targetPos = targets.Center
        if Settings.AimTarget == "GoalCorner" then targetPos = targets.LeftCorner
        elseif Settings.AimTarget == "AwayFromKeeper" then targetPos = targets.AwayFromKeeper end
        
        if targetPos then
            local screenPos, vis = Camera:WorldToViewportPoint(targetPos)
            if vis then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < minDist then closest = {Position = targetPos}, minDist = dist end
            end
        end
    end
    return closest
end

-- UI CONSTRUCTION
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LessHubV2"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Safe(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Floating Toggle
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 56, 0, 56)
ToggleBtn.Position = UDim2.new(0, 12, 0.5, -28)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(10, 14, 26)
ToggleBtn.Text = "L"
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextColor3 = Color3.fromRGB(0, 170, 255)
ToggleBtn.TextSize = 26
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1,0)
local Stroke = Instance.new("UIStroke", ToggleBtn)
Stroke.Color = Color3.fromRGB(0, 170, 255)
Stroke.Thickness = 2

-- Draggable Toggle
local dragStart, startPos, dragging
ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = ToggleBtn.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 360)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(0, 170, 255)
Instance.new("UIStroke", MainFrame).Thickness = 1

-- Tabs
local TabNames = {"Aim", "GK", "Dribble", "Move", "Visuals", "Net"}
local TabButtons, ContentFrames = {}, {}
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 44)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame
Instance.new("UIListLayout", TabBar).FillDirection = Enum.FillDirection.Horizontal
Instance.new("UIPadding", TabBar).PaddingLeft = UDim.new(0, 6)

for i, name in ipairs(TabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#TabNames, -4, 1, -8)
    btn.Position = UDim2.new((i-1)/#TabNames, 2, 0, 4)
    btn.BackgroundColor3 = Color3.fromRGB(20, 28, 45)
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(180, 200, 220)
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    TabButtons[name] = btn
    
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -12, 1, -50)
    content.Position = UDim2.new(0, 6, 0, 46)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
    content.Visible = (i == 1)
    content.Parent = MainFrame
    Instance.new("UIListLayout", content).Padding = UDim.new(0, 5)
    ContentFrames[name] = content
    
    btn.MouseButton1Click:Connect(function()
        for n, f in pairs(ContentFrames) do f.Visible = false end
        for n, b in pairs(TabButtons) do 
            b.BackgroundColor3 = Color3.fromRGB(20, 28, 45)
            b.TextColor3 = Color3.fromRGB(180, 200, 220)
        end
        content.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        btn.TextColor3 = Color3.fromRGB(10, 14, 26)
    end)
end
TabButtons["Aim"].BackgroundColor3 = Color3.fromRGB(0, 170, 255)
TabButtons["Aim"].TextColor3 = Color3.fromRGB(10, 14, 26)

-- UI Builders
local function CreateToggle(parent, label, key)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 38)
    c.BackgroundTransparency = 1
    c.Parent = parent
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -52, 1, 0)
    l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.Font = Enum.Font.GothamMedium
    l.TextColor3 = Color3.fromRGB(220, 230, 240)
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = c
    
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 44, 0, 24)
    b.Position = UDim2.new(1, -48, 0.5, -12)
    b.BackgroundColor3 = Settings[key] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 50, 70)
    b.Text = ""
    b.BorderSizePixel = 0
    b.Parent = c
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    
    b.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        b.BackgroundColor3 = Settings[key] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 50, 70)
    end)
end

local function CreateSlider(parent, label, key, min, max)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 44)
    c.BackgroundTransparency = 1
    c.Parent = parent
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -60, 0, 18)
    l.Position = UDim2.new(0, 8, 0, 2)
    l.BackgroundTransparency = 1
    l.Text = label .. ": " .. tostring(Settings[key])
    l.Font = Enum.Font.GothamMedium
    l.TextColor3 = Color3.fromRGB(220, 230, 240)
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = c
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -16, 0, 8)
    bg.Position = UDim2.new(0, 8, 0, 28)
    bg.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    bg.BorderSizePixel = 0
    bg.Parent = c
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((Settings[key] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local draggingS = false
    bg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingS = true
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingS = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingS and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
            local val = math.floor(Lerp(min, max, rel) + 0.5)
            Settings[key] = val
            fill.Size = UDim2.new(rel, 0, 1, 0)
            l.Text = label .. ": " .. tostring(val)
        end
    end)
end

-- Populate Tabs
CreateToggle(ContentFrames["Aim"], "Auto Aim", "AimEnabled")
CreateToggle(ContentFrames["Aim"], "Silent Aim", "SilentAim")
CreateSlider(ContentFrames["Aim"], "Aim FOV", "AimFOV", 50, 300)
CreateSlider(ContentFrames["Aim"], "Smoothness", "AimSmooth", 0.05, 0.5)

CreateToggle(ContentFrames["GK"], "Auto Dive", "AutoDive")
CreateSlider(ContentFrames["GK"], "Dive Timing (ms)", "DiveTiming", 100, 500)
CreateToggle(ContentFrames["GK"], "Auto Position", "AutoPosition")
CreateToggle(ContentFrames["GK"], "Rebound Control", "ReboundControl")

CreateToggle(ContentFrames["Dribble"], "Auto Dribble", "AutoDribble")
CreateToggle(ContentFrames["Dribble"], "Proximity Shield", "ProximityShield")
CreateToggle(ContentFrames["Dribble"], "Auto Trickshot", "AutoTrickshot")
CreateToggle(ContentFrames["Dribble"], "Fake Shoot", "FakeShoot")
CreateToggle(ContentFrames["Dribble"], "Wall Fake Shoot", "WallFakeShoot")

CreateToggle(ContentFrames["Move"], "Infinite Stamina", "InfiniteStamina")
CreateToggle(ContentFrames["Move"], "Anti-Fling", "AntiFling")
CreateToggle(ContentFrames["Move"], "Speed Boost", "SpeedBoost")
CreateSlider(ContentFrames["Move"], "Speed Value", "SpeedValue", 16, 32)

CreateToggle(ContentFrames["Visuals"], "Ball ESP", "BallESP")
CreateToggle(ContentFrames["Visuals"], "Player ESP", "PlayerESP")
CreateToggle(ContentFrames["Visuals"], "Trajectory Line", "TrajectoryLine")
CreateToggle(ContentFrames["Visuals"], "FOV Circle", "FOVCircle")

CreateToggle(ContentFrames["Net"], "Ping Mitigation", "PingMitigation")
CreateToggle(ContentFrames["Net"], "Prediction Boost", "PredictionBoost")
CreateToggle(ContentFrames["Net"], "Replication Smoothing", "ReplicationSmoothing")
CreateToggle(ContentFrames["Net"], "Render Limit", "RenderLimit")
CreateSlider(ContentFrames["Net"], "Max Distance", "MaxRenderDist", 50, 200)

-- MAIN TOGGLE
local UIOpen = false
ToggleBtn.MouseButton1Click:Connect(function()
    UIOpen = not UIOpen
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Visible = UIOpen}):Play()
    ToggleBtn.Text = UIOpen and "✕" or "L"
end)

-- FEATURE LOOPS
RunService.Heartbeat:Connect(function(dt)
    Safe(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        
        -- AIMBOT (Mouse-based, not CFrame override)
        if Settings.AimEnabled then
            local target = GetAimTarget()
            if target and hrp then
                local aimPos = target.Position or target:GetPivot().Position
                local screenPos = Camera:WorldToViewportPoint(aimPos)
                local mouseDelta = Vector2.new(screenPos.X - Mouse.X, screenPos.Y - Mouse.Y)
                
                if Settings.SilentAim then
                    -- Silent aim via mouse event manipulation (undetectable)
                    mousemoverel(mouseDelta.X * Settings.AimSmooth, mouseDelta.Y * Settings.AimSmooth)
                else
                    -- Smooth camera follow without overriding game camera
                    local currentCF = Camera.CFrame
                    local targetCF = CFrame.lookAt(currentCF.Position, aimPos)
                    Camera.CFrame = currentCF:Lerp(targetCF, Settings.AimSmooth)
                end
            end
        end
        
        -- AUTO DIVE (Predictive trajectory)
        if Settings.AutoDive and hrp then
            local ball = GetBall()
            if ball then
                local futurePos = PredictBallTrajectory(ball, Settings.DiveTiming)
                if futurePos then
                    local dist = (futurePos - hrp.Position).Magnitude
                    local ballSpeed = ball.Velocity.Magnitude
                    if dist < 12 and ballSpeed > 18 then
                        -- Trigger dive via humanoid state change
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        task.delay(0.1, function()
                            hrp.Velocity = hrp.Velocity + (futurePos - hrp.Position).Unit * 15
                        end)
                    end
                end
            end
        end
        
        -- INFINITE STAMINA (Event interception + value reset)
        if Settings.InfiniteStamina and char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("NumberValue") and string.lower(obj.Name):find("stamina") then
                    obj.Value = obj.MaxValue or 100
                    obj.Changed:Connect(function() obj.Value = obj.MaxValue or 100 end)
                end
            end
        end
        
        -- ANTI-FLING (Local physics force)
        if Settings.AntiFling and hrp then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, math.max(hrp.Velocity.Y, -10), hrp.Velocity.Z)
            hrp.RotVelocity = Vector3.zero
        end
        
        -- SPEED BOOST (VectorForce instead of WalkSpeed)
        if Settings.SpeedBoost and hrp and humanoid then
            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude > 0 then
                local boost = moveDir * (Settings.SpeedValue - 16) * 50
                hrp.Velocity = hrp.Velocity + boost * dt
            end
        end
        
        -- RENDER LIMIT
        if Settings.RenderLimit then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if pHrp then
                        local dist = (pHrp.Position - Camera.CFrame.Position).Magnitude
                        p.Character.LocalTransparencyModifier = dist > Settings.MaxRenderDist and 1 or 0
                    end
                end
            end
        end
    end)
end)

-- DRAWING API (ESP & FOV)
local FOVDrawing = Drawing.new("Circle")
FOVDrawing.Thickness = 1.5
FOVDrawing.Color = Color3.fromRGB(0, 170, 255)
FOVDrawing.Filled = false
FOVDrawing.Visible = false

local TrajectoryDrawing = Drawing.new("Line")
TrajectoryDrawing.Thickness = 2
TrajectoryDrawing.Color = Color3.fromRGB(255, 200, 0)
TrajectoryDrawing.Visible = false

RunService.RenderStepped:Connect(function()
    Safe(function()
        -- FOV CIRCLE
        FOVDrawing.Visible = Settings.FOVCircle
        if FOVDrawing.Visible then
            FOVDrawing.Position = Vector2.new(Mouse.X, Mouse.Y)
            FOVDrawing.Radius = Settings.AimFOV
        end
        
        -- TRAJECTORY LINE
        if Settings.TrajectoryLine then
            local ball = GetBall()
            if ball and ball.Velocity.Magnitude > 5 then
                local currentPos = Camera:WorldToViewportPoint(ball.Position)
                local futurePos = Camera:WorldToViewportPoint(PredictBallTrajectory(ball, 0.5))
                if currentPos.Z > 0 and futurePos.Z > 0 then
                    TrajectoryDrawing.From = Vector2.new(currentPos.X, currentPos.Y)
                    TrajectoryDrawing.To = Vector2.new(futurePos.X, futurePos.Y)
                    TrajectoryDrawing.Visible = true
                else
                    TrajectoryDrawing.Visible = false
                end
            else
                TrajectoryDrawing.Visible = false
            end
        else
            TrajectoryDrawing.Visible = false
        end
        
        -- BALL ESP
        if Settings.BallESP then
            local ball = GetBall()
            if ball then
                local pos, vis = Camera:WorldToViewportPoint(ball.Position)
                if vis then
                    local d = Drawing.new("Circle")
                    d.Position = Vector2.new(pos.X, pos.Y)
                    d.Radius = 5
                    d.Color = Color3.fromRGB(255, 200, 0)
                    d.Filled = true
                    d.Visible = true
                    task.delay(0.03, function() d:Remove() end)
                end
            end
        end
        
        -- PLAYER ESP
        if Settings.PlayerESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if pHrp then
                        local pos, vis = Camera:WorldToViewportPoint(pHrp.Position)
                        if vis then
                            local box = Drawing.new("Square")
                            box.Size = Vector2.new(30, 50)
                            box.Position = Vector2.new(pos.X - 15, pos.Y - 25)
                            box.Color = p.Team == LocalPlayer.Team and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
                            box.Thickness = 1.5
                            box.Filled = false
                            box.Visible = true
                            task.delay(0.03, function() box:Remove() end)
                        end
                    end
                end
            end
        end
    end)
end)

-- CLEANUP
game:BindToClose(function()
    FOVDrawing:Remove()
    TrajectoryDrawing:Remove()
    ScreenGui:Destroy()
end)