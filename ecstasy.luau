--[[
    ecstasy · v1.3.0
    High-quality dark cyber-glass UI
    Inspired by Airflow layout & polish, original visual identity
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local SoundService     = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

--// Utility
local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[ecstasy]", err) end
end

local function create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = radius or UDim.new(0, 10),
        Parent = parent
    })
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or Color3.fromRGB(255, 255, 255),
        Transparency = transparency or 0.9,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent
    })
end

local function tween(obj, props, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

--// Maid
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
    table.insert(self._tasks, task)
    return task
end

function Maid:AddConnection(conn)
    return self:Give(function()
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end)
end

function Maid:AddInstance(inst)
    return self:Give(function()
        if inst and inst.Parent then
            inst:Destroy()
        end
    end)
end

function Maid:DoCleaning()
    for _, task in ipairs(self._tasks) do
        local t = typeof(task)
        if t == "RBXScriptConnection" then
            if task.Connected then task:Disconnect() end
        elseif t == "Instance" then
            if task.Parent then task:Destroy() end
        elseif t == "function" then
            pcall(task)
        end
    end
    table.clear(self._tasks)
end

--// Theme
local Theme = {
    Accent      = Color3.fromRGB(180, 50, 255),
    Background  = Color3.fromRGB(12, 12, 16),
    Surface     = Color3.fromRGB(18, 18, 24),
    Surface2    = Color3.fromRGB(24, 24, 32),
    Surface3    = Color3.fromRGB(30, 30, 40),
    Text        = Color3.fromRGB(240, 240, 250),
    Muted       = Color3.fromRGB(140, 140, 160),
    Stroke      = Color3.fromRGB(255, 255, 255),
    Error       = Color3.fromRGB(255, 90, 110),
}

--// Sound System
local SoundFolder = Instance.new("Folder")
SoundFolder.Name = "EcstasySounds"
SoundFolder.Parent = SoundService

local function makeSound(id, volume)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume or 0.3
    s.Parent = SoundFolder
    return s
end

local ClickSound  = makeSound("rbxassetid://15675032796", 0.28)
local NotifySound = makeSound("rbxassetid://7383525713", 0.25)

--// Library
local Ecstasy = {
    Version = "1.3.0",
    Windows = {},
    Maid = Maid.new(),

    SoundEnabled  = true,
    ClickSounds   = true,
    NotifySounds  = true,
    SoundVolume   = 0.3,
}

local function getGuiParent()
    local parent
    pcall(function()
        if typeof(gethui) == "function" then
            parent = gethui()
        end
    end)
    if parent then return parent end

    pcall(function()
        local core = game:GetService("CoreGui")
        local test = Instance.new("Folder")
        test.Parent = core
        test:Destroy()
        parent = core
    end)
    if parent then return parent end

    return LocalPlayer:WaitForChild("PlayerGui")
end

function Ecstasy:PlayClick()
    if not self.SoundEnabled or not self.ClickSounds then return end
    ClickSound.Volume = self.SoundVolume
    ClickSound:Play()
end

function Ecstasy:PlayNotify()
    if not self.SoundEnabled or not self.NotifySounds then return end
    NotifySound.Volume = self.SoundVolume
    NotifySound:Play()
end

--// Notifications
local NotificationGui
local NotificationHolder

local function ensureNotifications()
    if NotificationGui and NotificationGui.Parent then return end

    NotificationGui = create("ScreenGui", {
        Name = "EcstasyNotifications",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        Parent = getGuiParent()
    })
    Ecstasy.Maid:AddInstance(NotificationGui)

    NotificationHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.new(0, 320, 1, -40),
        BackgroundTransparency = 1,
        Parent = NotificationGui
    })

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 12),
        Parent = NotificationHolder
    })
end

function Ecstasy:Notify(options)
    options = options or {}
    ensureNotifications()
    self:PlayNotify()

    local title = options.Title or "Notification"
    local content = options.Content or ""
    local duration = options.Duration or 4

    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Parent = NotificationHolder
    })
    corner(card, UDim.new(0, 12))
    stroke(card, Theme.Stroke, 0.88)
    padding(card, 16, 16, 14, 14)

    -- Accent bar
    local accent = create("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = card
    })
    corner(accent, UDim.new(0, 2))

    create("TextLabel", {
        Size = UDim2.new(1, -12, 0, 18),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    create("TextLabel", {
        Size = UDim2.new(1, -12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(12, 22),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = Theme.Muted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    -- Progress bar
    local progressBg = create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = card
    })
    local progress = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = progressBg
    })

    card.Position = UDim2.new(1, 30, 0, 0)
    card.BackgroundTransparency = 1

    tween(card, {
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0.1
    }, 0.35, Enum.EasingStyle.Back)

    tween(progress, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        if not card.Parent then return end
        tween(card, {
            Position = UDim2.new(1, 40, 0, 0),
            BackgroundTransparency = 1
        }, 0.3)
        task.wait(0.32)
        if card.Parent then card:Destroy() end
    end)
end

--// Window
local Window = {}
Window.__index = Window

function Ecstasy:CreateWindow(options)
    options = options or {}

    local theme = options.Theme or {}
    for k, v in pairs(Theme) do
        if theme[k] == nil then
            theme[k] = v
        end
    end

    local window = setmetatable({
        Name = options.Name or "ecstasy",
        SubTitle = options.SubTitle or ("v" .. self.Version),
        Size = options.Size or UDim2.fromOffset(720, 480),
        Keybind = options.Keybind or Enum.KeyCode.RightControl,
        Blur = options.Blur ~= false,
        Theme = theme,
        Tabs = {},
        Maid = Maid.new(),
        Visible = true,
    }, Window)

    -- ScreenGui
    local gui = create("ScreenGui", {
        Name = "Ecstasy_" .. HttpService:GenerateGUID(false):sub(1, 8),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
        IgnoreGuiInset = true,
        Parent = getGuiParent()
    })
    window.Gui = gui
    window.Maid:AddInstance(gui)
    Ecstasy.Maid:AddInstance(gui)

    -- Main Frame
    local main = create("Frame", {
        Name = "Main",
        Size = window.Size,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui
    })
    window.Main = main
    corner(main, UDim.new(0, 14))
    stroke(main, theme.Stroke, 0.85)

    -- Top Bar
    local topBar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = main
    })
    corner(topBar, UDim.new(0, 14))

    -- Mask bottom of topbar
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 1, -16),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = topBar
    })

    create("TextLabel", {
        Size = UDim2.new(1, -120, 0, 22),
        Position = UDim2.fromOffset(20, 10),
        BackgroundTransparency = 1,
        Text = window.Name,
        TextColor3 = theme.Text,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topBar
    })

    create("TextLabel", {
        Size = UDim2.new(1, -120, 0, 16),
        Position = UDim2.fromOffset(20, 32),
        BackgroundTransparency = 1,
        Text = window.SubTitle,
        TextColor3 = theme.Muted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topBar
    })

    -- Close Button
    local closeBtn = create("TextButton", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, -44, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.Surface2,
        BackgroundTransparency = 0.4,
        Text = "×",
        TextColor3 = theme.Muted,
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Parent = topBar
    })
    corner(closeBtn, UDim.new(0, 8))

    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, { BackgroundTransparency = 0.1, TextColor3 = theme.Error }, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, { BackgroundTransparency = 0.4, TextColor3 = theme.Muted }, 0.2)
    end)
    closeBtn.MouseButton1Click:Connect(function()
        window:Destroy()
    end)

    -- Sidebar
    local sidebar = create("Frame", {
        Size = UDim2.new(0, 180, 1, -56),
        Position = UDim2.fromOffset(0, 56),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = main
    })
    window.Sidebar = sidebar

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = sidebar
    })
    padding(sidebar, 12, 12, 14, 14)

    -- Content Area
    local content = create("Frame", {
        Size = UDim2.new(1, -180, 1, -56),
        Position = UDim2.fromOffset(180, 56),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = main
    })
    window.Content = content

    --// Dragging (Fixed + Smooth)
    local dragging = false
    local dragStart = Vector2.zero
    local startPos = main.Position
    local targetPos = main.Position
    local currentPos = main.Position

    window.Maid:AddConnection(topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos = main.Position
            currentPos = main.Position
            targetPos = main.Position
        end
    end))

    window.Maid:AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
        targetPos = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end))

    window.Maid:AddConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    window.Maid:AddConnection(RunService.RenderStepped:Connect(function(dt)
        if not main.Parent then return end
        local alpha = math.clamp(dt * 16, 0, 1)
        local x = currentPos.X.Offset + (targetPos.X.Offset - currentPos.X.Offset) * alpha
        local y = currentPos.Y.Offset + (targetPos.Y.Offset - currentPos.Y.Offset) * alpha
        currentPos = UDim2.new(targetPos.X.Scale, x, targetPos.Y.Scale, y)
        main.Position = currentPos
    end))

    -- Keybind
    window.Maid:AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == window.Keybind then
            window:Toggle()
        end
    end))

    -- Blur
    if window.Blur then
        local blur = Instance.new("BlurEffect")
        blur.Name = "EcstasyBlur"
        blur.Size = 0
        blur.Parent = Lighting
        window.Maid:AddInstance(blur)
        tween(blur, { Size = 14 }, 0.4)
        window._blur = blur
    end

    -- Entrance
    main.Size = UDim2.fromOffset(0, 0)
    main.BackgroundTransparency = 1
    tween(main, {
        Size = window.Size,
        BackgroundTransparency = 0.15
    }, 0.45, Enum.EasingStyle.Back)

    table.insert(Ecstasy.Windows, window)
    return window
end

function Window:Toggle()
    self.Visible = not self.Visible
    local main = self.Main
    if self.Visible then
        main.Visible = true
        tween(main, { BackgroundTransparency = 0.15 }, 0.25)
    else
        tween(main, { BackgroundTransparency = 1 }, 0.2)
        task.delay(0.22, function()
            if not self.Visible then
                main.Visible = false
            end
        end)
    end
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self.Maid:DoCleaning()
    for i, win in ipairs(Ecstasy.Windows) do
        if win == self then
            table.remove(Ecstasy.Windows, i)
            break
        end
    end
end

--// Tab
local Tab = {}
Tab.__index = Tab

function Window:CreateTab(options)
    options = options or {}
    local name = options.Name or "Tab"

    local tab = setmetatable({
        Name = name,
        Window = self,
        Sections = {},
        Maid = Maid.new(),
        Active = false,
    }, Tab)

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = self.Theme.Surface2,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = self.Sidebar
    })
    corner(button, UDim.new(0, 10))
    tab.Button = button

    local accentBar = create("Frame", {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 6, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = button
    })
    corner(accentBar, UDim.new(0, 2))
    tab.AccentBar = accentBar

    local label = create("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.fromOffset(18, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = self.Theme.Muted,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = button
    })
    tab.Label = label

    local page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = self.Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = self.Content
    })
    tab.Page = page
    padding(page, 18, 18, 16, 18)

    local left = create("Frame", {
        Size = UDim2.new(0.5, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = page
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 14),
        Parent = left
    })
    tab.Left = left

    local right = create("Frame", {
        Size = UDim2.new(0.5, -8, 0, 0),
        Position = UDim2.new(0.5, 8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = page
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 14),
        Parent = right
    })
    tab.Right = right

    button.MouseEnter:Connect(function()
        if not tab.Active then
            tween(button, { BackgroundTransparency = 0.7 }, 0.15)
            tween(label, { TextColor3 = self.Theme.Text }, 0.15)
        end
    end)

    button.MouseLeave:Connect(function()
        if not tab.Active then
            tween(button, { BackgroundTransparency = 1 }, 0.2)
            tween(label, { TextColor3 = self.Theme.Muted }, 0.2)
        end
    end)

    button.MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        self:SelectTab(tab)
    end

    return tab
end

function Window:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        t.Active = false
        t.Page.Visible = false
        tween(t.Button, { BackgroundTransparency = 1 }, 0.2)
        tween(t.Label, { TextColor3 = self.Theme.Muted }, 0.2)
        tween(t.AccentBar, { BackgroundTransparency = 1 }, 0.2)
    end

    tab.Active = true
    tab.Page.Visible = true
    tween(tab.Button, { BackgroundTransparency = 0.55 }, 0.22)
    tween(tab.Label, { TextColor3 = self.Theme.Text }, 0.22)
    tween(tab.AccentBar, { BackgroundTransparency = 0 }, 0.22)
end

--// Section
local Section = {}
Section.__index = Section

function Tab:CreateSection(options)
    options = options or {}
    local name = options.Name or "Section"
    local side = string.lower(options.Side or "Left")
    local parent = (side == "right") and self.Right or self.Left

    local section = setmetatable({
        Name = name,
        Tab = self,
        Window = self.Window,
        Theme = self.Window.Theme,
        Maid = Maid.new(),
    }, Section)

    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = self.Window.Theme.Surface,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Parent = parent
    })
    corner(frame, UDim.new(0, 12))
    stroke(frame, self.Window.Theme.Stroke, 0.88)
    padding(frame, 16, 16, 14, 16)
    section.Frame = frame

    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = self.Window.Theme.Accent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })

    local list = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = frame
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = list
    })
    section.List = list

    table.insert(self.Sections, section)
    return section
end

--// Element helpers
local function createElementContainer(section, height)
    local theme = section.Theme
    local container = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 42),
        BackgroundColor3 = theme.Surface2,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = section.List
    })
    corner(container, UDim.new(0, 9))
    local s = stroke(container, theme.Stroke, 0.9)

    container.MouseEnter:Connect(function()
        tween(s, { Transparency = 0.7 }, 0.15)
        tween(container, { BackgroundTransparency = 0.3 }, 0.15)
    end)
    container.MouseLeave:Connect(function()
        tween(s, { Transparency = 0.9 }, 0.2)
        tween(container, { BackgroundTransparency = 0.45 }, 0.2)
    end)

    return container
end

--// Toggle
function Section:CreateToggle(options)
    options = options or {}
    local name = options.Name or "Toggle"
    local default = options.Default == true
    local callback = options.Callback
    local theme = self.Theme

    local container = createElementContainer(self, 42)

    create("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = theme.Text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    local track = create("Frame", {
        Size = UDim2.fromOffset(40, 22),
        Position = UDim2.new(1, -54, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.Surface3,
        BorderSizePixel = 0,
        Parent = container
    })
    corner(track, UDim.new(1, 0))

    local knob = create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = theme.Muted,
        BorderSizePixel = 0,
        Parent = track
    })
    corner(knob, UDim.new(1, 0))

    local state = default

    local function set(value, fire)
        state = value
        if state then
            tween(track, { BackgroundColor3 = theme.Accent }, 0.2)
            tween(knob, {
                Position = UDim2.fromOffset(21, 3),
                BackgroundColor3 = Color3.new(1, 1, 1)
            }, 0.2)
        else
            tween(track, { BackgroundColor3 = theme.Surface3 }, 0.2)
            tween(knob, {
                Position = UDim2.fromOffset(3, 3),
                BackgroundColor3 = theme.Muted
            }, 0.2)
        end
        if fire ~= false then
            safe(callback, state)
        end
    end

    set(default, false)

    local btn = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        Parent = container
    })
    btn.MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        set(not state)
    end)

    return {
        Set = function(_, value) set(value == true) end,
        Get = function() return state end
    }
end

--// Button
function Section:CreateButton(options)
    options = options or {}
    local name = options.Name or "Button"
    local callback = options.Callback
    local theme = self.Theme

    local container = createElementContainer(self, 42)

    local button = create("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        Parent = container
    })

    button.MouseEnter:Connect(function()
        tween(button, { TextColor3 = theme.Accent }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        tween(button, { TextColor3 = theme.Text }, 0.2)
    end)
    button.MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        tween(container, { BackgroundTransparency = 0.15 }, 0.08)
        task.delay(0.1, function()
            tween(container, { BackgroundTransparency = 0.45 }, 0.25)
        end)
        safe(callback)
    end)

    return {}
end

--// Slider
function Section:CreateSlider(options)
    options = options or {}
    local name = options.Name or "Slider"
    local min = options.Min or 0
    local max = options.Max or 100
    local default = options.Default or min
    local decimals = options.Decimals or 0
    local callback = options.Callback
    local theme = self.Theme

    local container = createElementContainer(self, 58)

    create("TextLabel", {
        Size = UDim2.new(1, -80, 0, 18),
        Position = UDim2.fromOffset(14, 8),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = theme.Text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    local valueLabel = create("TextLabel", {
        Size = UDim2.new(0, 70, 0, 18),
        Position = UDim2.new(1, -80, 0, 8),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.Accent,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = container
    })

    local barBg = create("Frame", {
        Size = UDim2.new(1, -28, 0, 6),
        Position = UDim2.fromOffset(14, 38),
        BackgroundColor3 = theme.Surface3,
        BorderSizePixel = 0,
        Parent = container
    })
    corner(barBg, UDim.new(1, 0))

    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Parent = barBg
    })
    corner(fill, UDim.new(1, 0))

    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = barBg
    })
    corner(knob, UDim.new(1, 0))

    local value = default

    local function set(v, fire)
        v = math.clamp(v, min, max)
        if decimals > 0 then
            local mult = 10 ^ decimals
            v = math.floor(v * mult + 0.5) / mult
        else
            v = math.floor(v + 0.5)
        end
        value = v
        local percent = (v - min) / (max - min)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        knob.Position = UDim2.new(percent, 0, 0.5, 0)
        valueLabel.Text = tostring(v)
        if fire ~= false then
            safe(callback, v)
        end
    end

    set(default, false)

    local sliding = false

    local function update(input)
        local relative = (input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X
        set(min + math.clamp(relative, 0, 1) * (max - min))
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            update(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    return {
        Set = function(_, v) set(v) end,
        Get = function() return value end
    }
end

--// Destroy
function Ecstasy:Destroy()
    for _, window in ipairs(self.Windows) do
        pcall(function() window:Destroy() end)
    end
    table.clear(self.Windows)
    self.Maid:DoCleaning()
    if SoundFolder then
        SoundFolder:Destroy()
    end
end

return Ecstasy
