--[[
    ecstasy · v1.2.1
    Fixed: Window dragging + separate toggleable notification sound
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local SoundService     = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------
local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[ecstasy]", err) end
end

local function create(class, props, children)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then i[k] = v end
    end
    if children then for _, c in ipairs(children) do c.Parent = i end end
    if props and props.Parent then i.Parent = props.Parent end
    return i
end

local function corner(p, r)
    return create("UICorner", { CornerRadius = r or UDim.new(0, 8), Parent = p })
end

local function stroke(p, col, trans, thick)
    return create("UIStroke", {
        Color = col or Color3.fromRGB(255, 255, 255),
        Transparency = trans or 0.88,
        Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = p
    })
end

local function pad(p, l, r, t, b)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = p
    })
end

local function tween(obj, props, dur, style, dir)
    dur = dur or 0.18
    style = style or Enum.EasingStyle.Quart
    dir = dir or Enum.EasingDirection.Out
    local t = TweenService:Create(obj, TweenInfo.new(dur, style, dir), props)
    t:Play()
    return t
end

--------------------------------------------------------------------
-- Maid
--------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({ _t = {} }, Maid) end
function Maid:Give(task) table.insert(self._t, task) return task end
function Maid:Conn(c) return self:Give(function() if c and c.Connected then c:Disconnect() end end) end
function Maid:Inst(i) return self:Give(function() if i and i.Parent then i:Destroy() end end) end
function Maid:Clean()
    for _, t in ipairs(self._t) do
        local ty = typeof(t)
        if ty == "RBXScriptConnection" then if t.Connected then t:Disconnect() end
        elseif ty == "Instance" then if t.Parent then t:Destroy() end
        elseif ty == "function" then pcall(t)
        elseif ty == "table" and t.Destroy then pcall(function() t:Destroy() end) end
    end
    table.clear(self._t)
end
function Maid:Destroy() self:Clean() end

--------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------
local DEFAULT = {
    Accent     = Color3.fromRGB(180, 50, 255),
    Background = Color3.fromRGB(13, 13, 18),
    Surface    = Color3.fromRGB(18, 18, 24),
    Surface2   = Color3.fromRGB(24, 24, 32),
    Text       = Color3.fromRGB(235, 235, 245),
    Muted      = Color3.fromRGB(140, 140, 160),
    Stroke     = Color3.fromRGB(255, 255, 255),
    Error      = Color3.fromRGB(255, 90, 110),
}

--------------------------------------------------------------------
-- Sound System
--------------------------------------------------------------------
local SoundFolder = Instance.new("Folder")
SoundFolder.Name = "EcstasySounds"
SoundFolder.Parent = SoundService

local function makeSound(id, vol)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = vol or 0.35
    s.Parent = SoundFolder
    return s
end

local clickSound  = makeSound("rbxassetid://15675032796", 0.32) -- soft click
local notifySound = makeSound("rbxassetid://7383525713", 0.28)  -- soft notify

--------------------------------------------------------------------
-- Library
--------------------------------------------------------------------
local Ecstasy = {
    Version          = "1.2.1",
    Windows          = {},
    _maid            = Maid.new(),
    _blur            = nil,
    _guiParent       = nil,

    -- Sound controls
    SoundEnabled     = true,   -- master switch
    ClickSounds      = true,   -- buttons, toggles, tabs
    NotifySounds     = true,   -- notifications only
    SoundVolume      = 0.35,
}

local function resolveParent()
    local p
    pcall(function() if typeof(gethui) == "function" then p = gethui() end end)
    if p then return p end
    pcall(function()
        local cg = game:GetService("CoreGui")
        local t = Instance.new("Folder")
        t.Parent = cg
        t:Destroy()
        p = cg
    end)
    if p then return p end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function Ecstasy:_getParent()
    if not self._guiParent or not self._guiParent.Parent then
        self._guiParent = resolveParent()
    end
    return self._guiParent
end

function Ecstasy:_blurOn(on)
    if not on then
        if self._blur then self._blur:Destroy() self._blur = nil end
        return
    end
    if self._blur and self._blur.Parent then return end
    local b = Instance.new("BlurEffect")
    b.Name = "EcstasyBlur"
    b.Size = 0
    b.Parent = Lighting
    self._blur = b
    self._maid:Inst(b)
    tween(b, { Size = 16 }, 0.4, Enum.EasingStyle.Quad)
end

function Ecstasy:PlayClick()
    if not self.SoundEnabled or not self.ClickSounds then return end
    clickSound.Volume = self.SoundVolume
    clickSound:Play()
end

function Ecstasy:PlayNotify()
    if not self.SoundEnabled or not self.NotifySounds then return end
    notifySound.Volume = self.SoundVolume
    notifySound:Play()
end

--------------------------------------------------------------------
-- Interactive
--------------------------------------------------------------------
local function makeInteractive(frame, theme, doClickSound)
    local scale = create("UIScale", { Scale = 1, Parent = frame })

    local shine = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 10,
        Parent = frame
    })
    corner(shine, UDim.new(0, 8))
    local grad = create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.4, 0.85),
            NumberSequenceKeypoint.new(0.6, 0.85),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Offset = Vector2.new(-1, 0),
        Rotation = 15,
        Parent = shine
    })

    local hovering = false

    frame.MouseEnter:Connect(function()
        hovering = true
        tween(scale, { Scale = 1.02 }, 0.18)
        grad.Offset = Vector2.new(-1.2, 0)
        tween(grad, { Offset = Vector2.new(1.2, 0) }, 0.55, Enum.EasingStyle.Quad)
    end)

    frame.MouseLeave:Connect(function()
        hovering = false
        tween(scale, { Scale = 1 }, 0.22)
    end)

    frame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            tween(scale, { Scale = 0.98 }, 0.08)
            if doClickSound then
                Ecstasy:PlayClick()
            end
        end
    end)

    frame.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            tween(scale, { Scale = hovering and 1.02 or 1 }, 0.18)
        end
    end)
end

--------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------
local notifGui, notifHolder

local function ensureNotifs()
    if notifGui and notifGui.Parent then return end
    notifGui = create("ScreenGui", {
        Name = "EcstasyToasts",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 10000,
        Parent = Ecstasy:_getParent()
    })
    Ecstasy._maid:Inst(notifGui)

    notifHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 310, 1, -32),
        BackgroundTransparency = 1,
        Parent = notifGui
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 10),
        Parent = notifHolder
    })
end

function Ecstasy:Notify(opts)
    opts = opts or {}
    ensureNotifs()

    -- Separate notification sound toggle
    self:PlayNotify()

    local title    = opts.Title or "Notification"
    local content  = opts.Content or ""
    local duration = opts.Duration or 3.5
    local image    = opts.Image

    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(16, 16, 22),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = notifHolder
    })
    corner(card, UDim.new(0, 10))
    stroke(card, Color3.fromRGB(255, 255, 255), 0.9, 1)
    pad(card, 14, 14, 12, 14)

    create("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = DEFAULT.Accent,
        BorderSizePixel = 0,
        Parent = card
    })

    local left = image and 42 or 14
    if image then
        create("ImageLabel", {
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset(14, 12),
            BackgroundTransparency = 1,
            Image = image,
            ImageColor3 = DEFAULT.Accent,
            Parent = card
        })
    end

    create("TextLabel", {
        Size = UDim2.new(1, -left - 8, 0, 18),
        Position = UDim2.fromOffset(left, 10),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = DEFAULT.Text,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })
    create("TextLabel", {
        Size = UDim2.new(1, -left - 8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(left, 30),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = DEFAULT.Muted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    local progBg = create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Color3.fromRGB(40, 40, 50),
        BorderSizePixel = 0,
        Parent = card
    })
    local prog = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = DEFAULT.Accent,
        BorderSizePixel = 0,
        Parent = progBg
    })

    card.Position = UDim2.new(1, 40, 0, 0)
    card.BackgroundTransparency = 1

    tween(card, {
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0.08
    }, 0.35, Enum.EasingStyle.Back)

    tween(prog, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        if not card.Parent then return end
        tween(card, {
            Position = UDim2.new(1, 50, 0, 0),
            BackgroundTransparency = 1
        }, 0.3, Enum.EasingStyle.Quad)
        task.wait(0.32)
        if card.Parent then card:Destroy() end
    end)
end

--------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------
local function playLoading(parent, theme, onDone)
    local overlay = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(8, 8, 12),
        BackgroundTransparency = 0,
        ZIndex = 200,
        Parent = parent
    })

    local center = create("Frame", {
        Size = UDim2.fromOffset(220, 160),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = overlay
    })

    local logo = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.fromOffset(0, 20),
        BackgroundTransparency = 1,
        Text = "ecstasy",
        TextColor3 = theme.Text,
        TextSize = 28,
        Font = Enum.Font.GothamBold,
        TextTransparency = 1,
        Parent = center
    })

    local ring = create("Frame", {
        Size = UDim2.fromOffset(48, 48),
        Position = UDim2.new(0.5, 0, 0, 70),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Parent = center
    })
    local ringStroke = create("UIStroke", {
        Color = theme.Accent,
        Thickness = 2.5,
        Transparency = 0.3,
        Parent = ring
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.7, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = ringStroke
    })

    local status = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.fromOffset(0, 130),
        BackgroundTransparency = 1,
        Text = "Loading modules...",
        TextColor3 = theme.Muted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextTransparency = 1,
        Parent = center
    })

    local spinConn = RunService.RenderStepped:Connect(function(dt)
        ring.Rotation = (ring.Rotation + dt * 220) % 360
    end)

    tween(logo, { TextTransparency = 0 }, 0.3)
    tween(status, { TextTransparency = 0 }, 0.3)
    task.wait(0.35)

    local steps = {
        { t = "Loading modules...", d = 0.25 },
        { t = "Initializing Glass Engine...", d = 0.3 },
        { t = "Ready!", d = 0.25 },
    }
    for _, s in ipairs(steps) do
        status.Text = s.t
        task.wait(s.d)
    end

    local scale = create("UIScale", { Scale = 1, Parent = center })
    tween(scale, { Scale = 1.15 }, 0.25, Enum.EasingStyle.Back)
    tween(overlay, { BackgroundTransparency = 1 }, 0.35)
    tween(logo, { TextTransparency = 1 }, 0.25)
    tween(status, { TextTransparency = 1 }, 0.25)
    task.wait(0.38)

    spinConn:Disconnect()
    overlay:Destroy()
    if onDone then onDone() end
end

--------------------------------------------------------------------
-- Window (Dragging Fixed)
--------------------------------------------------------------------
local Window = {}
Window.__index = Window

function Ecstasy:CreateWindow(opts)
    opts = opts or {}
    local theme = opts.Theme or {}
    for k, v in pairs(DEFAULT) do if theme[k] == nil then theme[k] = v end end

    local win = setmetatable({
        Name     = opts.Name or "ecstasy",
        SubTitle = opts.SubTitle or ("v" .. Ecstasy.Version),
        Size     = opts.Size or UDim2.fromOffset(580, 380),
        Keybind  = opts.Keybind or Enum.KeyCode.RightControl,
        Blur     = opts.Blur ~= false,
        Theme    = theme,
        Tabs     = {},
        Maid     = Maid.new(),
        Visible  = true,
    }, Window)

    local gui = create("ScreenGui", {
        Name = "Ecstasy_" .. HttpService:GenerateGUID(false):sub(1, 6),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
        IgnoreGuiInset = true,
        Parent = Ecstasy:_getParent()
    })
    win.Gui = gui
    win.Maid:Inst(gui)
    Ecstasy._maid:Inst(gui)

    -- Glow
    local glowHolder = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = gui
    })
    for i, sz in ipairs({40, 70, 110}) do
        create("ImageLabel", {
            Size = UDim2.new(1, sz, 1, sz),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://8992230677",
            ImageColor3 = theme.Accent,
            ImageTransparency = 0.75 + i * 0.07,
            ZIndex = 0,
            Parent = glowHolder
        })
    end

    local main = create("Frame", {
        Name = "Main",
        Size = win.Size,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Parent = gui
    })
    win.Main = main
    corner(main, UDim.new(0, 12))
    stroke(main, theme.Stroke, 0.88, 1)

    local top = create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = main
    })
    corner(top, UDim.new(0, 12))
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = top
    })

    create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 20),
        Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1,
        Text = win.Name,
        TextColor3 = theme.Text,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = top
    })
    create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 16),
        Position = UDim2.fromOffset(16, 26),
        BackgroundTransparency = 1,
        Text = win.SubTitle,
        TextColor3 = theme.Muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = top
    })

    local close = create("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -38, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.Surface2,
        BackgroundTransparency = 0.4,
        Text = "×",
        TextColor3 = theme.Muted,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Parent = top
    })
    corner(close, UDim.new(0, 6))
    makeInteractive(close, theme, true)
    close.MouseEnter:Connect(function()
        tween(close, { TextColor3 = theme.Error }, 0.15)
    end)
    close.MouseLeave:Connect(function()
        tween(close, { TextColor3 = theme.Muted }, 0.2)
    end)
    close.MouseButton1Click:Connect(function() win:Destroy() end)

    local side = create("Frame", {
        Size = UDim2.new(0, 148, 1, -48),
        Position = UDim2.fromOffset(0, 48),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = main
    })
    win.Sidebar = side
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = side
    })
    pad(side, 8, 8, 10, 10)

    local content = create("Frame", {
        Size = UDim2.new(1, -148, 1, -48),
        Position = UDim2.fromOffset(148, 48),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = main
    })
    win.Content = content

    -- ====================== FIXED DRAGGING ======================
    local dragging = false
    local dragStart = Vector2.zero
    local startPos = main.Position
    local targetPos = main.Position
    local currentPos = main.Position

    win.Maid:Conn(top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos = main.Position
            currentPos = main.Position
            targetPos = main.Position
        end
    end))

    win.Maid:Conn(UserInputService.InputChanged:Connect(function(input)
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

    win.Maid:Conn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    -- Smooth lerp
    win.Maid:Conn(RunService.RenderStepped:Connect(function(dt)
        if not main.Parent then return end

        local alpha = math.clamp(dt * 18, 0, 1)
        local newX = currentPos.X.Offset + (targetPos.X.Offset - currentPos.X.Offset) * alpha
        local newY = currentPos.Y.Offset + (targetPos.Y.Offset - currentPos.Y.Offset) * alpha

        currentPos = UDim2.new(targetPos.X.Scale, newX, targetPos.Y.Scale, newY)
        main.Position = currentPos

        -- Keep glow following
        glowHolder.Position = main.Position
        glowHolder.Size = main.Size
        glowHolder.AnchorPoint = main.AnchorPoint
    end))
    -- ====================== END FIXED DRAGGING ======================

    win.Maid:Conn(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == win.Keybind then
            win:Toggle()
        end
    end))

    if win.Blur then Ecstasy:_blurOn(true) end

    playLoading(gui, theme, function()
        main.Visible = true
        main.Size = UDim2.fromOffset(0, 0)
        main.BackgroundTransparency = 1
        tween(main, {
            Size = win.Size,
            BackgroundTransparency = 0.28
        }, 0.4, Enum.EasingStyle.Back)
    end)

    table.insert(Ecstasy.Windows, win)
    return win
end

function Window:Toggle()
    self.Visible = not self.Visible
    local m = self.Main
    if self.Visible then
        m.Visible = true
        tween(m, { BackgroundTransparency = 0.28 }, 0.25)
        if self.Blur then Ecstasy:_blurOn(true) end
    else
        tween(m, { BackgroundTransparency = 1 }, 0.2)
        task.delay(0.22, function()
            if not self.Visible then m.Visible = false end
        end)
        if self.Blur then Ecstasy:_blurOn(false) end
    end
end

function Window:Destroy()
    if self._dead then return end
    self._dead = true
    self.Maid:Clean()
    for i, w in ipairs(Ecstasy.Windows) do
        if w == self then table.remove(Ecstasy.Windows, i) break end
    end
    if #Ecstasy.Windows == 0 then Ecstasy:_blurOn(false) end
end

--------------------------------------------------------------------
-- Tab + Section + basic components (same structure)
--------------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

function Window:CreateTab(opts)
    opts = opts or {}
    local name = opts.Name or "Tab"

    local tab = setmetatable({
        Name = name, Window = self, Sections = {}, Maid = Maid.new(), _on = false
    }, Tab)

    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = self.Theme.Surface2,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = self.Sidebar
    })
    corner(btn, UDim.new(0, 8))
    tab.Button = btn
    makeInteractive(btn, self.Theme, true)

    local accent = create("Frame", {
        Size = UDim2.new(0, 3, 0, 18),
        Position = UDim2.new(0, 4, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = btn
    })
    corner(accent, UDim.new(0, 2))
    tab.Accent = accent

    local label = create("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(16, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = self.Theme.Muted,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn
    })
    tab.Label = label

    local page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = self.Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = self.Content
    })
    tab.Page = page
    pad(page, 12, 12, 10, 12)

    local left = create("Frame", {
        Size = UDim2.new(0.5, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = page
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = left })
    tab.Left = left

    local right = create("Frame", {
        Size = UDim2.new(0.5, -6, 0, 0),
        Position = UDim2.new(0.5, 6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = page
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = right })
    tab.Right = right

    btn.MouseButton1Click:Connect(function() self:_sel(tab) end)

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then self:_sel(tab) end
    return tab
end

function Window:_sel(tab)
    for _, t in ipairs(self.Tabs) do
        t._on = false
        t.Page.Visible = false
        tween(t.Button, { BackgroundTransparency = 1 }, 0.2)
        tween(t.Label, { TextColor3 = self.Theme.Muted }, 0.2)
        tween(t.Accent, { BackgroundTransparency = 1 }, 0.2)
    end
    tab._on = true
    tab.Page.Visible = true
    tween(tab.Button, { BackgroundTransparency = 0.55 }, 0.22)
    tween(tab.Label, { TextColor3 = self.Theme.Text }, 0.22)
    tween(tab.Accent, { BackgroundTransparency = 0 }, 0.22)
end

local Section = {}
Section.__index = Section

function Tab:CreateSection(opts)
    opts = opts or {}
    local name = opts.Name or "Section"
    local side = (opts.Side or "Left"):lower()
    local parent = side == "right" and self.Right or self.Left

    local sec = setmetatable({
        Name = name, Tab = self, Window = self.Window,
        Theme = self.Window.Theme, Maid = Maid.new()
    }, Section)

    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = self.Window.Theme.Surface,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = parent
    })
    corner(frame, UDim.new(0, 10))
    stroke(frame, self.Window.Theme.Stroke, 0.9, 1)
    pad(frame, 12, 12, 10, 12)
    sec.Frame = frame

    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = self.Window.Theme.Accent,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })

    local list = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = frame
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = list })
    sec.List = list

    table.insert(self.Sections, sec)
    return sec
end

local function elContainer(sec, h)
    local theme = sec.Theme
    local c = create("Frame", {
        Size = UDim2.new(1, 0, 0, h or 36),
        BackgroundColor3 = theme.Surface2,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Parent = sec.List
    })
    corner(c, UDim.new(0, 8))
    local s = stroke(c, theme.Stroke, 0.92, 1)
    makeInteractive(c, theme, true)
    c.MouseEnter:Connect(function() tween(s, { Transparency = 0.7 }, 0.15) end)
    c.MouseLeave:Connect(function() tween(s, { Transparency = 0.92 }, 0.2) end)
    return c
end

function Section:CreateToggle(opts)
    opts = opts or {}
    local name, def, cb = opts.Name or "Toggle", opts.Default == true, opts.Callback
    local theme = self.Theme
    local c = elContainer(self, 36)

    create("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = theme.Text,
        TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local track = create("Frame", {
        Size = UDim2.fromOffset(36, 20), Position = UDim2.new(1, -48, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = theme.Surface, BorderSizePixel = 0, Parent = c
    })
    corner(track, UDim.new(1, 0))
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = theme.Muted, BorderSizePixel = 0, Parent = track
    })
    corner(knob, UDim.new(1, 0))

    local state = def
    local function set(v, fire)
        state = v
        if state then
            tween(track, { BackgroundColor3 = theme.Accent }, 0.2)
            tween(knob, { Position = UDim2.fromOffset(19, 3), BackgroundColor3 = Color3.new(1,1,1) }, 0.2)
        else
            tween(track, { BackgroundColor3 = theme.Surface }, 0.2)
            tween(knob, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = theme.Muted }, 0.2)
        end
        if fire ~= false then safe(cb, state) end
    end
    set(def, false)

    create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c })
        .MouseButton1Click:Connect(function() set(not state) end)

    return { Set = function(_, v) set(v == true) end, Get = function() return state end }
end

function Section:CreateButton(opts)
    opts = opts or {}
    local name, cb = opts.Name or "Button", opts.Callback
    local theme = self.Theme
    local c = elContainer(self, 36)

    local btn = create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = name, TextColor3 = theme.Text, TextSize = 13,
        Font = Enum.Font.GothamMedium, AutoButtonColor = false, Parent = c
    })
    btn.MouseEnter:Connect(function() tween(btn, { TextColor3 = theme.Accent }, 0.15) end)
    btn.MouseLeave:Connect(function() tween(btn, { TextColor3 = theme.Text }, 0.2) end)
    btn.MouseButton1Click:Connect(function()
        tween(c, { BackgroundTransparency = 0.15 }, 0.08)
        task.delay(0.1, function() tween(c, { BackgroundTransparency = 0.55 }, 0.25) end)
        safe(cb)
    end)

    return {}
end

function Ecstasy:Destroy()
    for _, w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
    table.clear(self.Windows)
    self._maid:Clean()
    if self._blur then self._blur:Destroy() self._blur = nil end
    if notifGui then notifGui:Destroy() notifGui = nil end
    if SoundFolder then SoundFolder:Destroy() end
end

return Ecstasy
