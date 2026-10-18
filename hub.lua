--[[
    LESSHUB - KEYLESS PREMIUM UI TEMPLATE
    Game: Illegal Soccer (Educational / UI Demo)
    Theme: Deep Black & Electric Blue
    Mobile Optimized: Touch-friendly toggles, draggable
    Key System: NONE
    
    ⚠️ DISCLAIMER: This script is a UI/UX architecture template.
    It contains NO game exploitation, memory injection, or remote event tampering.
    Actual feature callbacks are placeholder functions for demonstration.
]]

-- // CONFIGURATION
local Config = {
    HubName = "LessHub",
    AccentColor = Color3.fromRGB(0, 128, 255),
    BackgroundColor = Color3.fromRGB(12, 12, 15),
    SectionColor = Color3.fromRGB(22, 22, 28),
    TextColor = Color3.fromRGB(235, 235, 240),
    SubTextColor = Color3.fromRGB(160, 160, 170),
    ToggleOnColor = Color3.fromRGB(0, 128, 255),
    ToggleOffColor = Color3.fromRGB(60, 60, 70),
    CornerRadius = UDim.new(0, 10),
    DragSpeed = 0.06,
    MobileToggleSize = UDim2.new(0, 44, 0, 44) -- Büyük dokunma alanı
}

-- // SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- // UTILITY FUNCTIONS
local function Create(instanceType, properties, parent)
    local obj = Instance.new(instanceType)
    for k, v in pairs(properties) do
        obj[k] = v
    end
    if parent then obj.Parent = parent end
    return obj
end

local function Tween(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

-- // SCREEN GUI SETUP
local ScreenGui = Create("ScreenGui", {
    Name = "LessHub_UI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true
}, LocalPlayer:WaitForChild("PlayerGui"))

-- // MAIN WINDOW
local MainFrame = Create("Frame", {
    Name = "MainWindow",
    Size = UDim2.new(0, 380, 0, 520),
    Position = UDim2.new(0.5, -190, 0.5, -260),
    BackgroundColor3 = Config.BackgroundColor,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true
}, ScreenGui)

Create("UICorner", { CornerRadius = Config.CornerRadius }, MainFrame)

-- Header / Drag Bar
local Header = Create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
    Active = true
}, MainFrame)

local TitleLabel = Create("TextLabel", {
    Text = "⚽ " .. Config.HubName,
    Size = UDim2.new(1, -50, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    TextColor3 = Config.AccentColor,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

-- Close / Minimize Button (Mobile Friendly)
local CloseBtn = Create("TextButton", {
    Text = "✕",
    Size = Config.MobileToggleSize,
    Position = UDim2.new(1, -50, 0, 2),
    BackgroundTransparency = 1,
    TextColor3 = Config.SubTextColor,
    Font = Enum.Font.GothamBold,
    TextSize = 18
}, Header)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- // TAB SYSTEM
local TabContainer = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 40),
    Position = UDim2.new(0, 0, 0, 48),
    BackgroundTransparency = 1
}, MainFrame)

local TabListLayout = Create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4)
}, TabContainer)

local ContentContainer = Create("Frame", {
    Size = UDim2.new(1, -16, 1, -104),
    Position = UDim2.new(0, 8, 0, 96),
    BackgroundTransparency = 1,
    ClipsDescendants = true
}, MainFrame)

-- // FEATURE MODULE BUILDER
local LessHub = {}
LessHub.Tabs = {}

function LessHub:CreateTab(name)
    local tabBtn = Create("TextButton", {
        Text = name,
        Size = UDim2.new(0, 90, 1, 0),
        BackgroundColor3 = Config.SectionColor,
        TextColor3 = Config.SubTextColor,
        Font = Enum.Font.GothamSemiBold,
        TextSize = 13,
        AutoButtonColor = false,
        LayoutOrder = #self.Tabs + 1
    }, TabContainer)
    Create("UICorner", { CornerRadius = UDim.new(0, 8) }, tabBtn)

    local contentFrame = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Config.AccentColor,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false
    }, ContentContainer)

    local listLayout = Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, contentFrame)

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
    end)

    local tabIndex = #self.Tabs + 1
    self.Tabs[tabIndex] = { Button = tabBtn, Content = contentFrame }

    tabBtn.MouseButton1Click:Connect(function()
        for i, t in ipairs(self.Tabs) do
            t.Content.Visible = (i == tabIndex)
            Tween(t.Button, TweenInfo.new(0.2), {
                BackgroundColor3 = (i == tabIndex) and Config.AccentColor or Config.SectionColor,
                TextColor3 = (i == tabIndex) and Color3.fromRGB(255,255,255) or Config.SubTextColor
            })
        end
    end)

    -- İlk tab varsayılan aktif
    if tabIndex == 1 then
        contentFrame.Visible = true
        tabBtn.BackgroundColor3 = Config.AccentColor
        tabBtn.TextColor3 = Color3.fromRGB(255,255,255)
    end

    return {
        AddToggle = function(self, label, defaultVal, callback)
            local state = defaultVal or false
            local item = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Config.SectionColor,
                LayoutOrder = #contentFrame:GetChildren()
            }, contentFrame)
            Create("UICorner", { CornerRadius = UDim.new(0, 8) }, item)

            Create("TextLabel", {
                Text = label,
                Size = UDim2.new(1, -60, 1, 0),
                Position = UDim2.new(0, 14, 0, 0),
                BackgroundTransparency = 1,
                TextColor3 = Config.TextColor,
                Font = Enum.Font.GothamMedium,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left
            }, item)

            local toggleBg = Create("Frame", {
                Size = UDim2.new(0, 40, 0, 22),
                Position = UDim2.new(1, -52, 0.5, -11),
                BackgroundColor3 = state and Config.ToggleOnColor or Config.ToggleOffColor
            }, item)
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }, toggleBg)

            local knob = Create("Frame", {
                Size = UDim2.new(0, 18, 0, 18),
                Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
                BackgroundColor3 = Color3.fromRGB(255,255,255)
            }, toggleBg)
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

            local btn = Create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = ""
            }, item)

            btn.MouseButton1Click:Connect(function()
                state = not state
                Tween(toggleBg, TweenInfo.new(0.25), {
                    BackgroundColor3 = state and Config.ToggleOnColor or Config.ToggleOffColor
                })
                Tween(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
                    Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
                })
                if callback then pcall(callback, state) end
            end)
        end,

        AddButton = function(self, label, callback)
            local item = Create("TextButton", {
                Text = label,
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Config.AccentColor,
                TextColor3 = Color3.fromRGB(255,255,255),
                Font = Enum.Font.GothamSemiBold,
                TextSize = 14,
                LayoutOrder = #contentFrame:GetChildren()
            }, contentFrame)
            Create("UICorner", { CornerRadius = UDim.new(0, 8) }, item)

            item.MouseButton1Click:Connect(function()
                if callback then pcall(callback) end
            end)
        end
    }
end

-- // DRAG FUNCTIONALITY (MOBILE + DESKTOP)
do
    local dragging, dragInput, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    Header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                     startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            Tween(MainFrame, TweenInfo.new(Config.DragSpeed, Enum.EasingStyle.Quad), {Position = newPos})
        end
    end)
end

-- // BUILD TABS & FEATURES (PLACEHOLDER CALLBACKS)
local VisualsTab = LessHub:CreateTab("Visuals")
VisualsTab:AddToggle("Ball ESP", false, function(enabled)
    print("[LessHub] Ball ESP:", enabled)
    -- Gerçek implementasyonda: WorldToViewportPoint ile top pozisyonu çizilir
end)
VisualsTab:AddToggle("Player Tracers", false, function(enabled)
    print("[LessHub] Player Tracers:", enabled)
end)
VisualsTab:AddToggle("Goal Highlight", true, function(enabled)
    print("[LessHub] Goal Highlight:", enabled)
end)

local GameplayTab = LessHub:CreateTab("Gameplay")
GameplayTab:AddToggle("Kick Assist", false, function(enabled)
    print("[LessHub] Kick Assist:", enabled)
    -- Gerçek implementasyonda: Vuruş vektörü hesaplaması yapılır
end)
GameplayTab:AddToggle("Stamina Saver", false, function(enabled)
    print("[LessHub] Stamina Saver:", enabled)
end)
GameplayTab:AddButton("Reset Camera", function()
    print("[LessHub] Camera reset requested")
end)

local MiscTab = LessHub:CreateTab("Misc")
MiscTab:AddToggle("Anti-AFK", true, function(enabled)
    print("[LessHub] Anti-AFK:", enabled)
end)
MiscTab:AddButton("Rejoin Server", function()
    print("[LessHub] Rejoin triggered")
end)
MiscTab:AddButton("Copy Server ID", function()
    print("[LessHub] Server ID copied")
end)

print("✅ LessHub loaded successfully | Keyless | Mobile Ready")