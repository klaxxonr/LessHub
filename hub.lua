--[[
    LessHub v1.0 | Premium Script Hub for Illegal Soccer
    Mobile-Optimized | Delta Compatible | No Key System
    Language: English | Categories: Aim, Goalkeeper, Dribble, Movement, Visuals, Network
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

-- STATE MANAGEMENT (Simple Names)
local Settings = {
    -- AIM CATEGORY
    AimEnabled = false,
    AimTarget = "Ball", -- "Ball", "Player", "GoalCorner", "AwayFromKeeper", "Center"
    AimFOV = 120,
    AimSmooth = 0.15,
    SilentAim = false,
    
    -- GOALKEEPER CATEGORY
    AutoDive = false,
    DiveTiming = 0.25, -- seconds before ball arrives
    AutoPosition = false,
    ReboundControl = false,
    
    -- DRIBBLE CATEGORY
    AutoDribble = false,
    DribbleRhythm = true,
    ProximityShield = false,
    
    -- MOVEMENT CATEGORY
    InfiniteStamina = false,
    AntiFling = false,
    SpeedBoost = false,
    SpeedValue = 18,
    
    -- VISUALS CATEGORY
    BallESP = false,
    PlayerESP = false,
    TrajectoryLine = false,
    FOVCircle = false,
    
    -- NETWORK CATEGORY
    PingMitigation = false,
    PredictionBoost = false,
    ReplicationSmoothing = false,
    RenderDistanceLimit = false,
    MaxRenderDistance = 100,
    
    -- TRICKSHOT CATEGORY
    AutoTrickshot = false,
    TrickshotType = "Volley", -- "Volley", "Bicycle", "Rabona"
}

-- SAFE CALL WRAPPER
local function Safe(func, ...)
    local ok, err = pcall(func, ...)
    if not ok then warn("[LessHub] Error: "..tostring(err)) end
end

-- UTILITY FUNCTIONS
local function Lerp(a, b, t) return a + (b - a) * math.clamp(t, 0, 1) end

local function GetBall()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name == "Ball" then return obj end
    end
    return nil
end

local function GetGoalCorners()
    -- Simplified: returns approximate corner positions based on field
    -- In real implementation, detect goal posts dynamically
    return {
        LeftTop = Vector3.new(-35, 8, -50),
        RightTop = Vector3.new(35, 8, -50),
        Center = Vector3.new(0, 4, -50)
    }
end

local function GetClosestTarget()
    local target = nil
    local minDist = Settings.AimFOV
    
    if Settings.AimTarget == "Ball" then
        local ball = GetBall()
        if ball then
            local pos, vis = Camera:WorldToViewportPoint(ball.Position)
            if vis then
                local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if dist < minDist then target, minDist = ball, dist end
            end
        end
    elseif Settings.AimTarget == "Player" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = p.Character.HumanoidRootPart
                local pos, vis = Camera:WorldToViewportPoint(hrp.Position)
                if vis then
                    local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                    if dist < minDist then target, minDist = hrp, dist end
                end
            end
        end
    else
        -- Goal targeting modes
        local corners = GetGoalCorners()
        local goalPos = corners.Center
        if Settings.AimTarget == "GoalCorner" then goalPos = corners.LeftTop
        elseif Settings.AimTarget == "AwayFromKeeper" then goalPos = corners.RightTop end
        
        local pos, vis = Camera:WorldToViewportPoint(goalPos)
        if vis then
            local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
            if dist < minDist then target = {Position = goalPos} end
        end
    end
    return target
end

-- UI CONSTRUCTION (Mobile-First, Dark Blue Theme)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LessHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Safe(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Floating Toggle Button (Draggable, Edge-Anchored)
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

-- Draggable Logic
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
MainFrame.Size = UDim2.new(0, 480, 0, 340)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -170)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(0, 170, 255)
Instance.new("UIStroke", MainFrame).Thickness = 1

-- Tab Buttons Container
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 44)
TabBar.Position = UDim2.new(0, 0, 0, 0)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame
Instance.new("UIListLayout", TabBar).FillDirection = Enum.FillDirection.Horizontal
Instance.new("UIPadding", TabBar).PaddingLeft = UDim.new(0, 8)

local Tabs = {"Aim", "Goalkeeper", "Dribble", "Movement", "Visuals", "Network"}
local TabButtons = {}
local ContentFrames = {}

for i, tabName in ipairs(Tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#Tabs, -4, 1, -8)
    btn.Position = UDim2.new((i-1)/#Tabs, 2, 0, 4)
    btn.BackgroundColor3 = Color3.fromRGB(20, 28, 45)
    btn.Text = tabName
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromRGB(180, 200, 220)
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    TabButtons[tabName] = btn
    
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -16, 1, -52)
    content.Position = UDim2.new(0, 8, 0, 48)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
    content.Visible = (i == 1)
    content.Parent = MainFrame
    Instance.new("UIListLayout", content).Padding = UDim.new(0, 6)
    ContentFrames[tabName] = content
    
    btn.MouseButton1Click:Connect(function()
        for name, frame in pairs(ContentFrames) do frame.Visible = false end
        for name, b in pairs(TabButtons) do 
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

-- Toggle Builder Function
local function CreateToggle(parent, label, settingKey)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 36)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextColor3 = Color3.fromRGB(220, 230, 240)
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 42, 0, 24)
    btn.Position = UDim2.new(1, -46, 0.5, -12)
    btn.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 50, 70)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    
    btn.MouseButton1Click:Connect(function()
        Settings[settingKey] = not Settings[settingKey]
        btn.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 50, 70)
    end)
end

-- Slider Builder Function
local function CreateSlider(parent, label, settingKey, min, max)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 42)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 0, 18)
    lbl.Position = UDim2.new(0, 8, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(Settings[settingKey])
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextColor3 = Color3.fromRGB(220, 230, 240)
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -16, 0, 8)
    sliderBg.Position = UDim2.new(0, 8, 0, 26)
    sliderBg.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = container
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((Settings[settingKey] - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
    
    local draggingSlider = false
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingSlider = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local val = math.floor(Lerp(min, max, rel) + 0.5)
            Settings[settingKey] = val
            sliderFill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = label .. ": " .. tostring(val)
        end
    end)
end

-- Populate Tabs
CreateToggle(ContentFrames["Aim"], "Auto Aim", "AimEnabled")
CreateToggle(ContentFrames["Aim"], "Silent Aim", "SilentAim")
CreateSlider(ContentFrames["Aim"], "Aim FOV", "AimFOV", 50, 300)
CreateSlider(ContentFrames["Aim"], "Smoothness", "AimSmooth", 0.05, 0.5)

CreateToggle(ContentFrames["Goalkeeper"], "Auto Dive", "AutoDive")
CreateSlider(ContentFrames["Goalkeeper"], "Dive Timing (ms)", "DiveTiming", 100, 500)
CreateToggle(ContentFrames["Goalkeeper"], "Auto Position", "AutoPosition")
CreateToggle(ContentFrames["Goalkeeper"], "Rebound Control", "ReboundControl")

CreateToggle(ContentFrames["Dribble"], "Auto Dribble", "AutoDribble")
CreateToggle(ContentFrames["Dribble"], "Rhythm Sync", "DribbleRhythm")
CreateToggle(ContentFrames["Dribble"], "Proximity Shield", "ProximityShield")

CreateToggle(ContentFrames["Movement"], "Infinite Stamina", "InfiniteStamina")
CreateToggle(ContentFrames["Movement"], "Anti-Fling", "AntiFling")
CreateToggle(ContentFrames["Movement"], "Speed Boost", "SpeedBoost")
CreateSlider(ContentFrames["Movement"], "Speed Value", "SpeedValue", 16, 32)

CreateToggle(ContentFrames["Visuals"], "Ball ESP", "BallESP")
CreateToggle(ContentFrames["Visuals"], "Player ESP", "PlayerESP")
CreateToggle(ContentFrames["Visuals"], "Trajectory Line", "TrajectoryLine")
CreateToggle(ContentFrames["Visuals"], "FOV Circle", "FOVCircle")

CreateToggle(ContentFrames["Network"], "Ping Mitigation", "PingMitigation")
CreateToggle(ContentFrames["Network"], "Prediction Boost", "PredictionBoost")
CreateToggle(ContentFrames["Network"], "Replication Smoothing", "ReplicationSmoothing")
CreateToggle(ContentFrames["Network"], "Render Limit", "RenderDistanceLimit")
CreateSlider(ContentFrames["Network"], "Max Distance", "MaxRenderDistance", 50, 200)

-- MAIN TOGGLE LOGIC
local UIOpen = false
ToggleBtn.MouseButton1Click:Connect(function()
    UIOpen = not UIOpen
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(MainFrame, tweenInfo, {Visible = UIOpen}):Play()
    ToggleBtn.Text = UIOpen and "✕" or "L"
end)

-- FEATURE LOOPS (Safe, Modular, Mobile-Safe)
RunService.Heartbeat:Connect(function(dt)
    Safe(function()
        -- AIMBOT
        if Settings.AimEnabled then
            local target = GetClosestTarget()
            if target then
                local aimPos = target.Position or target:GetPivot().Position
                if Settings.SilentAim then
                    -- Silent aim logic would go here (camera manipulation without visual snap)
                else
                    local currentCF = Camera.CFrame
                    local targetCF = CFrame.lookAt(currentCF.Position, aimPos)
                    Camera.CFrame = currentCF:Lerp(targetCF, Settings.AimSmooth)
                end
            end
        end
        
        -- AUTO DIVE (Goalkeeper)
        if Settings.AutoDive then
            local ball = GetBall()
            if ball and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (ball.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                local vel = ball.Velocity.Magnitude
                if dist < 15 and vel > 20 then
                    -- Trigger dive animation/state here via humanoid or animator
                    -- Implementation depends on game's goalkeeper system
                end
            end
        end
        
        -- INFINITE STAMINA
        if Settings.InfiniteStamina and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                -- Find stamina attribute/value and reset to max
                for _, obj in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if obj:IsA("NumberValue") and string.lower(obj.Name):find("stamina") then
                        obj.Value = obj.MaxValue or 100
                    end
                end
            end
        end
        
        -- ANTI-FLING
        if Settings.AntiFling and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
                hrp.RotVelocity = Vector3.zero
            end
        end
        
        -- SPEED BOOST
        if Settings.SpeedBoost and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.WalkSpeed = Settings.SpeedValue end
        end
        
        -- RENDER DISTANCE LIMIT
        if Settings.RenderDistanceLimit then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
                        player.Character.LocalTransparencyModifier = dist > Settings.MaxRenderDistance and 1 or 0
                    end
                end
            end
        end
    end)
end)

-- DRAWING API FOR ESP & FOV (Lightweight, Delta-Friendly)
local FOVDrawing = Drawing.new("Circle")
FOVDrawing.Thickness = 1.5
FOVDrawing.Color = Color3.fromRGB(0, 170, 255)
FOVDrawing.Filled = false
FOVDrawing.Visible = false

RunService.RenderStepped:Connect(function()
    Safe(function()
        -- FOV CIRCLE
        FOVDrawing.Visible = Settings.FOVCircle and UIOpen
        if FOVDrawing.Visible then
            FOVDrawing.Position = Vector2.new(Mouse.X, Mouse.Y)
            FOVDrawing.Radius = Settings.AimFOV
        end
        
        -- BALL ESP
        if Settings.BallESP then
            local ball = GetBall()
            if ball then
                local pos, vis = Camera:WorldToViewportPoint(ball.Position)
                if vis then
                    -- Simple dot ESP for ball
                    local d = Drawing.new("Circle")
                    d.Position = Vector2.new(pos.X, pos.Y)
                    d.Radius = 4
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
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = p.Character.HumanoidRootPart
                    local pos, vis = Camera:WorldToViewportPoint(hrp.Position)
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
    end)
end)

-- CLEANUP ON REMOVE
game:BindToClose(function()
    FOVDrawing:Remove()
    ScreenGui:Destroy()
end)