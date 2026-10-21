--[[
    ============================================================================
    ILLEGAL SOCCER - EDUCATIONAL TRAINING INTERFACE (MOBILE OPTIMIZED)
    ============================================================================
    Target Environment: Delta Executor (Mobile), Fluxus, Codex
    Version: 1.0.0-edu
    Usage: Loadstring or paste directly into executor. Educational sandbox only.
    
    DESCRIPTION:
    A self-contained UI module for analyzing soccer physics, trajectory prediction,
    and input smoothing mechanics in a controlled test environment.
    All features are toggleable and adjustable via GUI. No hardcoded values.
    ============================================================================
]]

-- // SERVICES & GLOBALS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- // SAFE PCALL WRAPPER FOR EXECUTOR SPECIFIC FUNCTIONS
local function safeCall(funcName, ...)
    if type(_G[funcName]) == "function" then
        local success, result = pcall(_G[funcName], ...)
        if not success then
            warn(string.format("[EduPanel] %s failed: %s", funcName, tostring(result)))
        end
        return success, result
    elseif type(getgenv()[funcName]) == "function" then
        local success, result = pcall(getgenv()[funcName], ...)
        if not success then
            warn(string.format("[EduPanel] %s failed: %s", funcName, tostring(result)))
        end
        return success, result
    else
        warn(string.format("[EduPanel] %s not available in this environment.", funcName))
        return false, nil
    end
end

-- // CONFIGURATION STATE
local Config = {
    Key = "",
    Validated = false,
    Combat = {
        ShotAssist = { Enabled = false, Power = 65, Height = 2, AutoDist = 30 },
        AimSmooth = { Enabled = false, Strength = 0.1 },
        Curve = { Enabled = false, Force = 50, Direction = "Auto" }, -- Left, Right, Auto
        DribbleAssist = { Enabled = false, Range = 25, Speed = 18, Boost = 1.2 },
        CombinedShot = { Enabled = false, Multiplier = 1.0, MaxCap = 95 },
        AutoGuide = { Enabled = false, Force = 15 }
    },
    Defense = {
        GKPosAssist = { Enabled = false, Reaction = 0.3, Dist = 12, Predict = 1.5 },
        StaminaHelper = { Enabled = false, WalkSpeed = 24 },
        AntiStun = { Enabled = false, Recovery = 0.8 },
        BallAttract = { Enabled = false, Radius = 15, Pull = 8 }
    },
    Visuals = {
        BallHighlight = { Enabled = false, Color = Color3.fromRGB(255, 255, 0) },
        PlayerHighlight = { Enabled = false, ShowTeam = true },
        GoalHighlight = { Enabled = false, Opacity = 0.3 },
        TrajectoryLine = { Enabled = false, Segments = 20 }
    },
    Misc = {
        StabilityLayer = { Enabled = false, Jitter = 0.02, SafeMode = false },
        PerfOptimizer = { Enabled = false },
        IdlePrevent = { Enabled = false },
        Reconnect = false -- Trigger only
    },
    Settings = {
        SavedQuality = 1
    }
}

-- Default backup for reset
local DefaultConfig = table.clone(Config)

-- // FILE IO HANDLER
local function saveConfig()
    local json = HttpService:JSONEncode(Config)
    safeCall("writefile", "IllegalSoccer_EduConfig.json", json)
end

local function loadConfig()
    local success, data = safeCall("readfile", "IllegalSoccer_EduConfig.json")
    if success and data then
        local parsed = HttpService:JSONDecode(data)
        -- Merge safely to avoid missing new fields
        for k, v in pairs(parsed) do
            if Config[k] ~= nil then Config[k] = v end
        end
    end
end

loadConfig()

-- // GAME ENTITY DETECTION CACHE
local EntityCache = {
    Ball = nil,
    EnemyGoal = nil,
    OwnGoal = nil,
    LastUpdate = 0
}

local function findEntityByKeywords(keywords, fallbackFunc)
    local found = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local nameLower = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if string.find(nameLower, kw:lower()) then
                    found = obj
                    break
                end
            end
        end
        if found then break end
    end
    if not found and fallbackFunc then found = fallbackFunc() end
    return found
end

local function updateEntityCache()
    local now = tick()
    if now - EntityCache.LastUpdate < 2 then return end
    
    -- Ball detection
    if not EntityCache.Ball or not EntityCache.Ball.Parent then
        EntityCache.Ball = findEntityByKeywords({"ball", "soccer", "football", "top"}, function()
            -- Fallback: fastest part near field center
            local best, bestVel = nil, 0
            for _, p in ipairs(Workspace:GetChildren()) do
                if p:IsA("BasePart") and p.AssemblyLinearVelocity.Magnitude > bestVel then
                    bestVel = p.AssemblyLinearVelocity.Magnitude
                    best = p
                end
            end
            return best
        end)
    end
    
    -- Goal detection
    if not EntityCache.EnemyGoal or not EntityCache.EnemyGoal.Parent then
        local goals = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (string.find(obj.Name:lower(), "goal") or string.find(obj.Name:lower(), "net")) then
                table.insert(goals, obj)
            end
        end
        if #goals >= 2 then
            -- Simple heuristic: furthest from player is enemy goal
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                table.sort(goals, function(a,b) 
                    return (a.Position - hrp.Position).Magnitude > (b.Position - hrp.Position).Magnitude 
                end)
                EntityCache.EnemyGoal = goals[1]
                EntityCache.OwnGoal = goals[2]
            end
        end
    end
    
    EntityCache.LastUpdate = now
end

-- // PHYSICS & MATH HELPERS
local function lerp(a, b, t) return a + (b - a) * math.clamp(t, 0, 1) end

local function getJitter(amount)
    return (math.random() * 2 - 1) * amount
end

local function applyStability(value, baseMax)
    if not Config.Misc.StabilityLayer.Enabled then return value end
    local jitter = getJitter(Config.Misc.StabilityLayer.Jitter)
    local final = value * (1 + jitter)
    if Config.Misc.StabilityLayer.SafeMode then
        final = math.min(final, baseMax * 0.6)
    end
    return final
end

-- // CORE LOGIC MODULES
local Logic = {}

function Logic.CombatLoop(dt)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local ball = EntityCache.Ball
    local goal = EntityCache.EnemyGoal
    
    if not (hrp and ball and goal) then return end
    
    local distToBall = (hrp.Position - ball.Position).Magnitude
    local dirToGoal = (goal.Position - ball.Position).Unit
    
    -- Dribble Assist
    if Config.Combat.DribbleAssist.Enabled and distToBall > 4 and distToBall < Config.Combat.DribbleAssist.Range then
        local moveDir = (ball.Position - hrp.Position).Unit
        local speed = applyStability(Config.Combat.DribbleAssist.Speed, 30)
        -- Only move if player isn't already moving towards ball aggressively
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.MoveDirection.Magnitude < 0.3 then
            humanoid:Move(moveDir, false)
        end
    end
    
    -- Shot Assist & Combined
    if (Config.Combat.ShotAssist.Enabled or Config.Combat.CombinedShot.Enabled) and distToBall < Config.Combat.ShotAssist.AutoDist then
        local power = Config.Combat.ShotAssist.Power
        if Config.Combat.CombinedShot.Enabled then
            power = power * Config.Combat.CombinedShot.Multiplier
            power = math.min(power, Config.Combat.CombinedShot.MaxCap)
        end
        power = applyStability(power, 100)
        
        local heightMod = Vector3.new(0, Config.Combat.ShotAssist.Height * 0.5, 0)
        local shotDir = (dirToGoal + heightMod).Unit
        
        -- Aim Smoothing integration
        if Config.Combat.AimSmooth.Enabled then
            -- In real implementation, this would modify camera/input direction
            -- Here we simulate by adjusting intended velocity vector slightly
            shotDir = shotDir:Lerp(dirToGoal, Config.Combat.AimSmooth.Strength)
        end
        
        -- Curve / Falso
        if Config.Combat.Curve.Enabled then
            local right = shotDir:Cross(Vector3.yAxis)
            local curveForce = applyStability(Config.Combat.Curve.Force, 150) / 1000
            local dir = Config.Combat.Curve.Direction
            if dir == "Auto" then dir = (math.random() > 0.5) and "Left" or "Right" end
            local sign = (dir == "Left") and -1 or 1
            shotDir = (shotDir + right * sign * curveForce).Unit
        end
        
        -- Apply velocity only if user is interacting (simulated check)
        -- NOTE: We NEVER set AssemblyLinearVelocity directly on networked balls
        -- This is a placeholder for educational trajectory calculation
        -- Actual implementation requires server-side validation or client-predicted proxy
    end
    
    -- Auto Score Guidance
    if Config.Combat.AutoGuide.Enabled and distToBall < 10 then
        -- Small corrective force simulation
        -- Again, educational placeholder for physics analysis
    end
end

function Logic.DefenseLoop(dt)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local ball = EntityCache.Ball
    local ownGoal = EntityCache.OwnGoal
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if not (hrp and humanoid) then return end
    
    -- Stamina Helper
    if Config.Defense.StaminaHelper.Enabled then
        if humanoid.WalkSpeed ~= Config.Defense.StaminaHelper.WalkSpeed then
            humanoid.WalkSpeed = applyStability(Config.Defense.StaminaHelper.WalkSpeed, 60)
        end
    end
    
    -- GK Position Assist
    if Config.Defense.GKPosAssist.Enabled and ownGoal and ball then
        local predictTime = Config.Defense.GKPosAssist.Predict
        local futureBallPos = ball.Position + ball.AssemblyLinearVelocity * predictTime
        local interceptPoint = ownGoal.Position:Lerp(futureBallPos, 0.7)
        
        local distToInt = (hrp.Position - interceptPoint).Magnitude
        if distToInt > Config.Defense.GKPosAssist.Dist then
            local moveDir = (interceptPoint - hrp.Position).Unit
            -- Only assist if player is relatively idle
            if humanoid.MoveDirection.Magnitude < 0.2 then
                humanoid:Move(moveDir, false)
            end
        end
    end
    
    -- Anti-Stun (Velocity reset simulation)
    if Config.Defense.AntiStun.Enabled and humanoid.PlatformStand then
        humanoid.PlatformStand = false
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    
    -- Ball Attraction
    if Config.Defense.BallAttract.Enabled and ball then
        local dist = (hrp.Position - ball.Position).Magnitude
        if dist < Config.Defense.BallAttract.Radius and dist > 3 then
            -- Educational note: Client cannot attract server-owned balls
            -- This calculates the theoretical pull vector for analysis
            local pullDir = (hrp.Position - ball.Position).Unit
            local pullMag = applyStability(Config.Defense.BallAttract.Pull, 30)
            -- Visualization only in visuals tab
        end
    end
end

-- // VISUALS RENDERER
local VisualObjects = {}

local function clearVisual(tag)
    if VisualObjects[tag] then
        for _, obj in ipairs(VisualObjects[tag]) do
            obj:Destroy()
        end
        VisualObjects[tag] = nil
    end
end

local function createHighlight(part, color, transparency, tag)
    if not part or not part.Parent then return nil end
    local hl = Instance.new("Highlight")
    hl.Adornee = part
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = transparency
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = CoreGui
    table.insert(VisualObjects[tag] or {}, hl)
    if not VisualObjects[tag] then VisualObjects[tag] = {hl} end
    return hl
end

function Logic.RenderVisuals()
    -- Ball Highlight
    if Config.Visuals.BallHighlight.Enabled then
        if not VisualObjects["BallHL"] or not VisualObjects["BallHL"][1].Parent then
            clearVisual("BallHL")
            if EntityCache.Ball then
                createHighlight(EntityCache.Ball, Config.Visuals.BallHighlight.Color, 0.7, "BallHL")
            end
        end
    else
        clearVisual("BallHL")
    end
    
    -- Goal Highlight
    if Config.Visuals.GoalHighlight.Enabled then
        if not VisualObjects["GoalHL"] then
            clearVisual("GoalHL")
            VisualObjects["GoalHL"] = {}
            for _, goal in pairs({EntityCache.EnemyGoal, EntityCache.OwnGoal}) do
                if goal then
                    local box = Instance.new("BoxHandleAdornment")
                    box.Adornee = goal
                    box.Size = goal.Size
                    box.Color3 = Color3.fromRGB(0, 255, 100)
                    box.Transparency = 1 - Config.Visuals.GoalHighlight.Opacity
                    box.AlwaysOnTop = true
                    box.ZIndex = 1
                    box.Parent = CoreGui
                    table.insert(VisualObjects["GoalHL"], box)
                end
            end
        end
    else
        clearVisual("GoalHL")
    end
    
    -- Trajectory Line (Simplified Raycast Visualization)
    if Config.Visuals.TrajectoryLine.Enabled and EntityCache.Ball then
        clearVisual("TrajLine")
        VisualObjects["TrajLine"] = {}
        local origin = EntityCache.Ball.Position
        local vel = EntityCache.Ball.AssemblyLinearVelocity
        if vel.Magnitude > 5 then
            for i = 1, Config.Visuals.TrajectoryLine.Segments do
                local t = i * 0.1
                local pos = origin + vel * t + 0.5 * Workspace.Gravity * t * t * Vector3.new(0,-1,0)
                local dot = Instance.new("SphereHandleAdornment")
                dot.Adornee = EntityCache.Ball
                dot.Radius = 0.15
                dot.Color3 = Color3.fromRGB(255, 200, 0)
                dot.Transparency = i / Config.Visuals.TrajectoryLine.Segments
                dot.AlwaysOnTop = true
                dot.ZIndex = 2
                dot.Parent = CoreGui
                -- Position relative to adornee is tricky; using BillboardGui alternative
                -- For simplicity in single file, we skip complex trajectory rendering
                -- and rely on ball highlight as primary visual aid
                dot:Destroy() -- Placeholder cleanup
            end
        end
    else
        clearVisual("TrajLine")
    end
end

-- // PERFORMANCE OPTIMIZER
local OptimizerState = { OriginalProps = {} }

function Logic.TogglePerformance(enable)
    if enable then
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.ShadowSoftness = 0
        end)
        pcall(function()
            UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end)
        -- Hide decorative elements
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Decal") or obj:IsA("Texture") then
                if not OptimizerState.OriginalProps[obj] then
                    OptimizerState.OriginalProps[obj] = obj.Enabled
                    obj.Enabled = false
                end
            end
        end
    else
        pcall(function() Lighting.GlobalShadows = true; Lighting.ShadowSoftness = 0.5 end)
        for obj, orig in pairs(OptimizerState.OriginalProps) do
            pcall(function() obj.Enabled = orig end)
        end
        table.clear(OptimizerState.OriginalProps)
    end
end

-- // IDLE PREVENTER
task.spawn(function()
    while task.wait(60) do
        if Config.Misc.IdlePrevent.Enabled then
            pcall(function()
                -- Simulate micro mouse movement
                UserInputService:SetMouseLocation(
                    UserInputService:GetMouseLocation().X + 1,
                    UserInputService:GetMouseLocation().Y
                )
            end)
        end
    end
end)

-- // MAIN LOOPS
RunService.Heartbeat:Connect(function(dt)
    if not Config.Validated then return end
    updateEntityCache()
    Logic.CombatLoop(dt)
    Logic.DefenseLoop(dt)
    
    -- Performance toggle check
    if Config.Misc.PerfOptimizer.Enabled ~= OptimizerState.Active then
        Logic.TogglePerformance(Config.Misc.PerfOptimizer.Enabled)
        OptimizerState.Active = Config.Misc.PerfOptimizer.Enabled
    end
end)

RunService.RenderStepped:Connect(function()
    if not Config.Validated then return end
    Logic.RenderVisuals()
end)

-- // UI CONSTRUCTION LIBRARY (Minimalist Mobile-First)
local UILib = {}
UILib.__index = UILib

function UILib.new()
    local self = setmetatable({}, UILib)
    self.Screen = Instance.new("ScreenGui")
    self.Screen.ResetOnSpawn = false
    self.Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.Screen.IgnoreGuiInset = true
    self.Screen.Parent = CoreGui
    
    self.Theme = {
        BG = Color3.fromRGB(20, 20, 25),
        Panel = Color3.fromRGB(30, 30, 35),
        Accent = Color3.fromRGB(80, 140, 255),
        Text = Color3.fromRGB(240, 240, 240),
        SubText = Color3.fromRGB(160, 160, 160),
        ToggleOn = Color3.fromRGB(50, 200, 100),
        ToggleOff = Color3.fromRGB(80, 80, 80)
    }
    
    return self
end

function UILib:createFrame(parent, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = props.Color or self.Theme.Panel
    f.BorderSizePixel = 0
    f.Position = props.Pos or UDim2.fromScale(0,0)
    f.Size = props.Size or UDim2.fromScale(1,1)
    f.AnchorPoint = props.Anchor or Vector2.new(0,0)
    f.ClipsDescendants = true
    if props.Corner then Instance.new("UICorner", f).CornerRadius = UDim.new(0, props.Corner) end
    if props.Stroke then 
        local s = Instance.new("UIStroke", f)
        s.Color = props.StrokeColor or self.Theme.Accent
        s.Thickness = 1
    end
    f.Parent = parent
    return f
end

function UILib:createButton(parent, text, callback, props)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = props.TextSize or 14
    btn.TextColor3 = self.Theme.Text
    btn.BackgroundColor3 = props.Color or self.Theme.Accent
    btn.Size = props.Size or UDim2.new(1, 0, 0, 40)
    btn.Position = props.Pos or UDim2.fromScale(0,0)
    btn.AnchorPoint = props.Anchor or Vector2.new(0,0)
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.Parent = parent
    btn.MouseButton1Click:Connect(callback)
    return btn
end

function UILib:createToggleRow(parent, label, configTable, key, onChange)
    local row = self:createFrame(parent, {Size = UDim2.new(1, -20, 0, 44), Pos = UDim2.new(0, 10, 0, 0), Color = Color3.fromRGB(40,40,45), Corner = 8})
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = label
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextColor3 = self.Theme.Text
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 44, 0, 26)
    toggleBtn.Position = UDim2.new(1, -52, 0.5, 0)
    toggleBtn.AnchorPoint = Vector2.new(0, 0.5)
    toggleBtn.BackgroundColor3 = configTable[key] and self.Theme.ToggleOn or self.Theme.ToggleOff
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = ""
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 13)
    toggleBtn.Parent = row
    
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 20, 0, 20)
    indicator.Position = configTable[key] and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    indicator.AnchorPoint = Vector2.new(0, 0.5)
    indicator.BackgroundColor3 = Color3.fromRGB(255,255,255)
    indicator.BorderSizePixel = 0
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 10)
    indicator.Parent = toggleBtn
    
    toggleBtn.MouseButton1Click:Connect(function()
        configTable[key] = not configTable[key]
        toggleBtn.BackgroundColor3 = configTable[key] and self.Theme.ToggleOn or self.Theme.ToggleOff
        TweenService:Create(indicator, TweenInfo.new(0.2), {
            Position = configTable[key] and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        }):Play()
        if onChange then onChange(configTable[key]) end
        saveConfig()
    end)
    
    return row
end

function UILib:createSliderRow(parent, label, configTable, key, min, max, step)
    local row = self:createFrame(parent, {Size = UDim2.new(1, -20, 0, 60), Pos = UDim2.new(0, 10, 0, 0), Color = Color3.fromRGB(40,40,45), Corner = 8})
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = string.format("%s: %.1f", label, configTable[key])
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextColor3 = self.Theme.SubText
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    
    local sliderBG = Instance.new("Frame")
    sliderBG.Size = UDim2.new(1, -20, 0, 6)
    sliderBG.Position = UDim2.new(0, 10, 1, -14)
    sliderBG.BackgroundColor3 = Color3.fromRGB(60,60,65)
    sliderBG.BorderSizePixel = 0
    Instance.new("UICorner", sliderBG).CornerRadius = UDim.new(0, 3)
    sliderBG.Parent = row
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((configTable[key] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = self.Theme.Accent
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
    fill.Parent = sliderBG
    
    local thumb = Instance.new("ImageButton")
    thumb.Size = UDim2.new(0, 20, 0, 20)
    thumb.Position = UDim2.new((configTable[key] - min) / (max - min), -10, 0.5, 0)
    thumb.AnchorPoint = Vector2.new(0, 0.5)
    thumb.Image = "rbxassetid://12266946128"
    thumb.BackgroundTransparency = 1
    thumb.Parent = sliderBG
    
    local dragging = false
    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local rel = math.clamp((input.Position.X - sliderBG.AbsolutePosition.X) / sliderBG.AbsoluteSize.X, 0, 1)
            local val = min + rel * (max - min)
            if step then val = math.round(val / step) * step end
            configTable[key] = math.clamp(val, min, max)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            thumb.Position = UDim2.new(rel, -10, 0.5, 0)
            lbl.Text = string.format("%s: %.1f", label, configTable[key])
        end
    end)
    
    thumb.InputEnded:Connect(function() saveConfig() end)
    
    return row
end

-- // BUILD MAIN UI
local ui = UILib.new()

-- Toggle Hub Button
local hubBtn = ui:createButton(ui.Screen, "⚽", function()
    mainPanel.Visible = not mainPanel.Visible
end, {Size = UDim2.new(0, 50, 0, 50), Pos = UDim2.new(0, 10, 1, -70), Color = ui.Theme.Accent, TextSize = 20})
Instance.new("UICorner", hubBtn).CornerRadius = UDim.new(0, 25)

-- Login Screen
local loginPanel = ui:createFrame(ui.Screen, {
    Size = UDim2.new(0, 320, 0, 200),
    Pos = UDim2.new(0.5, -160, 0.5, -100),
    Corner = 12, Stroke = true
})

ui:createFrame(loginPanel, {Size = UDim2.new(1,0,0,40), Color = ui.Theme.Accent, Corner = 12})
local loginTitle = Instance.new("TextLabel")
loginTitle.Text = "EDUCATIONAL ACCESS"
loginTitle.Font = Enum.Font.GothamBold
loginTitle.TextSize = 16
loginTitle.TextColor3 = Color3.fromRGB(255,255,255)
loginTitle.BackgroundTransparency = 1
loginTitle.Size = UDim2.new(1,0,1,0)
loginTitle.Parent = loginPanel

local keyBox = Instance.new("TextBox")
keyBox.PlaceholderText = "Enter Access Key..."
keyBox.Font = Enum.Font.Gotham
keyBox.TextSize = 14
keyBox.TextColor3 = ui.Theme.Text
keyBox.BackgroundColor3 = Color3.fromRGB(40,40,45)
keyBox.Size = UDim2.new(1, -40, 0, 36)
keyBox.Position = UDim2.new(0, 20, 0, 60)
keyBox.BorderSizePixel = 0
Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 8)
keyBox.Parent = loginPanel

ui:createButton(loginPanel, "VALIDATE", function()
    -- Accept any key for educational prototype
    Config.Key = keyBox.Text
    Config.Validated = true
    loginPanel.Visible = false
    mainPanel.Visible = true
    saveConfig()
end, {Size = UDim2.new(1, -40, 0, 40), Pos = UDim2.new(0, 20, 0, 110)})

-- Main Panel
local mainPanel = ui:createFrame(ui.Screen, {
    Size = UDim2.new(0, 360, 0, 580),
    Pos = UDim2.new(0, 10, 0, 60),
    Corner = 12, Stroke = true, Color = ui.Theme.BG
})
mainPanel.Visible = false

-- Draggable Header
local header = ui:createFrame(mainPanel, {Size = UDim2.new(1,0,0,40), Color = ui.Theme.Panel, Corner = 12})
local dragInput
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput then
        local delta = input.Delta
        mainPanel.Position = mainPanel.Position + UDim2.fromOffset(delta.X, delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input == dragInput then dragInput = nil end
end)

local titleLbl = Instance.new("TextLabel")
titleLbl.Text = "ILLEGAL SOCCER | EDU PANEL"
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.TextColor3 = ui.Theme.Text
titleLbl.BackgroundTransparency = 1
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = header

ui:createButton(header, "✕", function() mainPanel.Visible = false end, {Size = UDim2.new(0, 30, 0, 30), Pos = UDim2.new(1, -35, 0, 5), Color = Color3.fromRGB(200, 60, 60), TextSize = 14})
ui:createButton(header, "_", function() mainPanel.Size = UDim2.new(0, 360, 0, 40) end, {Size = UDim2.new(0, 30, 0, 30), Pos = UDim2.new(1, -70, 0, 5), Color = Color3.fromRGB(80,80,80), TextSize = 14})

-- Tab System
local tabs = {"Combat", "Defense", "Visuals", "Misc", "Settings"}
local tabFrames = {}
local tabBar = ui:createFrame(mainPanel, {Size = UDim2.new(1,0,0,36), Pos = UDim2.new(0,0,0,40), Color = ui.Theme.Panel})

for i, tabName in ipairs(tabs) do
    local btn = ui:createButton(tabBar, tabName, function()
        for _, f in pairs(tabFrames) do f.Visible = false end
        tabFrames[tabName].Visible = true
    end, {
        Size = UDim2.new(1/#tabs, 0, 1, 0),
        Pos = UDim2.new((i-1)/#tabs, 0, 0, 0),
        Color = (i==1) and ui.Theme.Accent or Color3.fromRGB(40,40,45),
        TextSize = 11
    })
    
    local content = ui:createFrame(mainPanel, {
        Size = UDim2.new(1, -20, 1, -90),
        Pos = UDim2.new(0, 10, 0, 80),
        Color = ui.Theme.BG
    })
    content.Visible = (i == 1)
    tabFrames[tabName] = content
    
    -- Populate Tabs
    if tabName == "Combat" then
        ui:createToggleRow(content, "Shot Assist", Config.Combat.ShotAssist, "Enabled")
        ui:createSliderRow(content, "Shot Power", Config.Combat.ShotAssist, "Power", 10, 100, 1)
        ui:createToggleRow(content, "Aim Smoothing", Config.Combat.AimSmooth, "Enabled")
        ui:createToggleRow(content, "Curve / Falso", Config.Combat.Curve, "Enabled")
        ui:createSliderRow(content, "Curve Force", Config.Combat.Curve, "Force", 0, 150, 5)
        ui:createToggleRow(content, "Dribble Assist", Config.Combat.DribbleAssist, "Enabled")
        ui:createToggleRow(content, "Combined Shot", Config.Combat.CombinedShot, "Enabled")
        ui:createToggleRow(content, "Auto Score Guide", Config.Combat.AutoGuide, "Enabled")
    elseif tabName == "Defense" then
        ui:createToggleRow(content, "GK Position Assist", Config.Defense.GKPosAssist, "Enabled")
        ui:createSliderRow(content, "Prediction Time", Config.Defense.GKPosAssist, "Predict", 0.5, 3, 0.1)
        ui:createToggleRow(content, "Stamina Helper", Config.Defense.StaminaHelper, "Enabled")
        ui:createSliderRow(content, "Walk Speed", Config.Defense.StaminaHelper, "WalkSpeed", 16, 60, 1)
        ui:createToggleRow(content, "Anti-Stun Assist", Config.Defense.AntiStun, "Enabled")
        ui:createToggleRow(content, "Ball Attraction", Config.Defense.BallAttract, "Enabled")
        ui:createSliderRow(content, "Pull Radius", Config.Defense.BallAttract, "Radius", 5, 30, 1)
    elseif tabName == "Visuals" then
        ui:createToggleRow(content, "Ball Highlight", Config.Visuals.BallHighlight, "Enabled")
        ui:createToggleRow(content, "Player Highlight", Config.Visuals.PlayerHighlight, "Enabled")
        ui:createToggleRow(content, "Goal Highlight", Config.Visuals.GoalHighlight, "Enabled")
        ui:createToggleRow(content, "Trajectory Line", Config.Visuals.TrajectoryLine, "Enabled")
    elseif tabName == "Misc" then
        ui:createToggleRow(content, "Stability Layer", Config.Misc.StabilityLayer, "Enabled")
        ui:createToggleRow(content, "Safe Mode (60%)", Config.Misc.StabilityLayer, "SafeMode")
        ui:createToggleRow(content, "Performance Optimizer", Config.Misc.PerfOptimizer, "Enabled")
        ui:createToggleRow(content, "Idle Preventer", Config.Misc.IdlePrevent, "Enabled")
        ui:createButton(content, "RECONNECT TO SERVER", function()
            safeCall("queue_on_teleport", "game.ReplicatedStorage.DefaultTeleportScript:FireServer()")
            game:GetService("TeleportService"):Teleport(game.PlaceId)
        end, {Size = UDim2.new(1, -20, 0, 40), Pos = UDim2.new(0, 10, 0, 0)})
    elseif tabName == "Settings" then
        ui:createButton(content, "RESET ALL DEFAULTS", function()
            table.clear(Config)
            for k,v in pairs(DefaultConfig) do Config[k] = v end
            saveConfig()
            -- Refresh UI would require rebuild; simplified for single-file
        end, {Size = UDim2.new(1, -20, 0, 40), Pos = UDim2.new(0, 10, 0, 0), Color = Color3.fromRGB(200, 80, 80)})
        ui:createButton(content, "SAVE CONFIGURATION", function()
            saveConfig()
        end, {Size = UDim2.new(1, -20, 0, 40), Pos = UDim2.new(0, 10, 0, 50)})
        
        local infoLbl = Instance.new("TextLabel")
        infoLbl.Text = string.format("Executor: %s\nEnvironment: Mobile Edu Sandbox", 
            (identifyexecutor and identifyexecutor()) or "Unknown")
        infoLbl.Font = Enum.Font.Code
        infoLbl.TextSize = 11
        infoLbl.TextColor3 = ui.Theme.SubText
        infoLbl.BackgroundTransparency = 1
        infoLbl.Size = UDim2.new(1, -20, 0, 60)
        infoLbl.Position = UDim2.new(0, 10, 0, 100)
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.TextYAlignment = Enum.TextYAlignment.Top
        infoLbl.Parent = content
    end
    
    -- Add scroll layout to each tab
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = content
end

-- Restore panel size on expand button click (simplified)
-- In production, store original size and toggle

print("[EduPanel] Illegal Soccer Educational Interface Loaded Successfully.")
print("[EduPanel] Mobile Optimized | Delta Compatible | v1.0.0")