--[[
    ecstasy · v1.1.0
    Ultra-smooth dark cyber-glass UI · Airflow-inspired motion
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local GuiService       = game:GetService("GuiService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")

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
-- Library root
--------------------------------------------------------------------
local Ecstasy = {
    Version     = "1.1.0",
    Windows     = {},
    _maid       = Maid.new(),
    _blur       = nil,
    _parent     = nil,
}

local function resolveParent()
    local p
    pcall(function() if typeof(gethui) == "function" then p = gethui() end end)
    if p then return p end
    pcall(function()
        local cg = game:GetService("CoreGui")
        local t = Instance.new("Folder"); t.Parent = cg; t:Destroy()
        p = cg
    end)
    if p then return p end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function Ecstasy:_parent()
    if not self._parent or not self._parent.Parent then
        self._parent = resolveParent()
    end
    return self._parent
end

function Ecstasy:_blurOn(on)
    if not on then
        if self._blur then self._blur:Destroy(); self._blur = nil end
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

--------------------------------------------------------------------
-- Interactive Hover Engine (Shine + Scale + Depress)
--------------------------------------------------------------------
local function makeInteractive(frame, theme)
    -- UIScale for micro-animations
    local scale = create("UIScale", { Scale = 1, Parent = frame })

    -- Shine gradient (hidden by default)
    local shine = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 10,
        Parent = frame
    })
    corner(shine, UDim.new(0, 8))
    local grad = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        }),
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
        -- sweep shine
        grad.Offset = Vector2.new(-1.2, 0)
        tween(grad, { Offset = Vector2.new(1.2, 0) }, 0.55, Enum.EasingStyle.Quad)
    end)

    frame.MouseLeave:Connect(function()
        hovering = false
        tween(scale, { Scale = 1 }, 0.22)
    end)

    frame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            tween(scale, { Scale = 0.98 }, 0.08)
        end
    end)

    frame.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            tween(scale, { Scale = hovering and 1.02 or 1 }, 0.18)
        end
    end)

    return scale
end

--------------------------------------------------------------------
-- Modern Toast Notifications (D)
--------------------------------------------------------------------
local notifGui, notifHolder

local function ensureNotifs()
    if notifGui and notifGui.Parent then return end
    notifGui = create("ScreenGui", {
        Name = "EcstasyToasts",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 10000,
        Parent = Ecstasy:_parent()
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

    -- accent bar
    create("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = DEFAULT.Accent,
        BorderSizePixel = 0,
        Parent = card
    }).UICorner = corner(card:FindFirstChildWhichIsA("Frame") or card, UDim.new(0, 2))

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

    -- progress bar
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

    -- start off-screen (right)
    card.Position = UDim2.new(1, 40, 0, 0)
    card.BackgroundTransparency = 1

    -- slide in
    tween(card, {
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0.08
    }, 0.35, Enum.EasingStyle.Back)

    -- progress deplete
    tween(prog, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

    -- exit
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
-- Loading Screen (C)
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

    -- logo text
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

    -- spinning ring
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
    -- partial arc illusion via gradient
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.7, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 0,
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

    -- spin
    local spinConn = RunService.RenderStepped:Connect(function(dt)
        ring.Rotation = (ring.Rotation + dt * 220) % 360
    end)

    -- Phase 1: fade in
    tween(logo, { TextTransparency = 0 }, 0.3)
    tween(status, { TextTransparency = 0 }, 0.3)
    task.wait(0.35)

    -- Phase 2: status updates
    local steps = {
        { t = "Loading modules...", d = 0.25 },
        { t = "Initializing Glass Engine...", d = 0.3 },
        { t = "Ready!", d = 0.25 },
    }
    for _, s in ipairs(steps) do
        status.Text = s.t
        task.wait(s.d)
    end

    -- Phase 3: elastic scale + dissolve
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
-- Window
--------------------------------------------------------------------
local Window = {}
Window.__index = Window

function Ecstasy:CreateWindow(opts)
    opts = opts or {}
    local theme = opts.Theme or {}
    for k, v in pairs(DEFAULT) do if theme[k] == nil then theme[k] = v end end

    local win = setmetatable({
        Name     = opts.Name or "ecstasy",
        SubTitle = opts.SubTitle or ("v" .. Ecstasy.Version .. " • Glass Engine"),
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
        Parent = Ecstasy:_parent()
    })
    win.Gui = gui
    win.Maid:Inst(gui)
    Ecstasy._maid:Inst(gui)

    -- DeepGlow layers (B)
    local glowHolder = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = gui
    })

    for i, sz in ipairs({ 40, 70, 110 }) do
        local g = create("ImageLabel", {
            Size = UDim2.new(1, sz, 1, sz),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://8992230677", -- soft glow
            ImageColor3 = theme.Accent,
            ImageTransparency = 0.75 + i * 0.07,
            ZIndex = 0,
            Parent = glowHolder
        })
    end

    -- Main glass panel
    local main = create("Frame", {
        Name = "Main",
        Size = win.Size,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false, -- shown after loading
        Parent = gui
    })
    win.Main = main
    corner(main, UDim.new(0, 12))
    stroke(main, theme.Stroke, 0.88, 1)

    -- top highlight stroke (frosted edge)
    local topHighlight = create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.7,
        Thickness = 1,
        Parent = main
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.3, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 90,
        Parent = topHighlight
    })

    -- Top bar
    local top = create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = main
    })
    corner(top, UDim.new(0, 12))
    create("Frame", { -- mask bottom corners
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
    makeInteractive(close, theme)
    close.MouseEnter:Connect(function()
        tween(close, { TextColor3 = theme.Error }, 0.15)
    end)
    close.MouseLeave:Connect(function()
        tween(close, { TextColor3 = theme.Muted }, 0.2)
    end)
    close.MouseButton1Click:Connect(function() win:Destroy() end)

    -- Sidebar
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

    -- Content
    local content = create("Frame", {
        Size = UDim2.new(1, -148, 1, -48),
        Position = UDim2.fromOffset(148, 48),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = main
    })
    win.Content = content

    -- Smooth drag (RenderStepped lerp)
    local dragging, dragStart, startPos, targetPos, currentPos
    dragging = false
    targetPos = main.Position
    currentPos = main.Position

    win.Maid:Conn(top.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            startPos = main.Position
            currentPos = main.Position
            targetPos = main.Position
        end
    end))

    win.Maid:Conn(UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
        targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                              startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end))

    win.Maid:Conn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    win.Maid:Conn(RunService.RenderStepped:Connect(function(dt)
        if not main.Parent then return end
        local a = math.clamp(dt * 18, 0, 1)
        local cx = currentPos.X.Offset + (targetPos.X.Offset - currentPos.X.Offset) * a
        local cy = currentPos.Y.Offset + (targetPos.Y.Offset - currentPos.Y.Offset) * a
        currentPos = UDim2.new(targetPos.X.Scale, cx, targetPos.Y.Scale, cy)
        main.Position = currentPos
        -- keep glow centered
        glowHolder.Position = main.Position
        glowHolder.Size = main.Size
        glowHolder.AnchorPoint = main.AnchorPoint
    end))

    -- Keybind toggle
    win.Maid:Conn(UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == win.Keybind then win:Toggle() end
    end))

    if win.Blur then Ecstasy:_blurOn(true) end

    -- Loading sequence then show window
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
        task.delay(0.22, function() if not self.Visible then m.Visible = false end end)
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
-- Tab
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
    makeInteractive(btn, self.Theme)

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

--------------------------------------------------------------------
-- Section
--------------------------------------------------------------------
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

--------------------------------------------------------------------
-- Element container helper
--------------------------------------------------------------------
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
    makeInteractive(c, theme)
    c.MouseEnter:Connect(function() tween(s, { Transparency = 0.7 }, 0.15) end)
    c.MouseLeave:Connect(function() tween(s, { Transparency = 0.92 }, 0.2) end)
    return c
end

--------------------------------------------------------------------
-- Toggle / Slider / Dropdown / Keybind / ColorPicker / Button / TextBox
--------------------------------------------------------------------
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

function Section:CreateSlider(opts)
    opts = opts or {}
    local name = opts.Name or "Slider"
    local min, max, def = opts.Min or 0, opts.Max or 100, opts.Default or opts.Min or 0
    local dec, unit, cb = opts.Decimals or 0, opts.ValueUnit or "", opts.Callback
    local theme = self.Theme
    local c = elContainer(self, 52)

    create("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(12, 6),
        BackgroundTransparency = 1, Text = name, TextColor3 = theme.Text,
        TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })
    local valLbl = create("TextLabel", {
        Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -70, 0, 6),
        BackgroundTransparency = 1, Text = "", TextColor3 = theme.Accent,
        TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = c
    })

    local bar = create("Frame", {
        Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(12, 34),
        BackgroundColor3 = theme.Surface, BorderSizePixel = 0, Parent = c
    })
    corner(bar, UDim.new(1, 0))
    local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Parent = bar })
    corner(fill, UDim.new(1, 0))
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Parent = bar
    })
    corner(knob, UDim.new(1, 0))

    local value = def
    local function set(v, fire)
        v = math.clamp(v, min, max)
        if dec > 0 then local m = 10^dec; v = math.floor(v*m+0.5)/m else v = math.floor(v+0.5) end
        value = v
        local pct = (v - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = string.format("%."..dec.."f%s", v, unit)
        if fire ~= false then safe(cb, v) end
    end
    set(def, false)

    local sliding = false
    local function upd(inp)
        local rel = (inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
        set(min + math.clamp(rel, 0, 1) * (max - min))
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliding = true; upd(i)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end)

    return { Set = function(_, v) set(v) end, Get = function() return value end }
end

function Section:CreateDropdown(opts)
    opts = opts or {}
    local name, options, def, multi, cb =
        opts.Name or "Dropdown", opts.Options or {}, opts.Default, opts.MultiSelect == true, opts.Callback
    local theme = self.Theme
    local c = elContainer(self, 36)

    create("TextLabel", {
        Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = theme.Text,
        TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local selected = def or options[1] or "None"
    if multi then selected = type(def) == "table" and def or {} end

    local disp = create("TextLabel", {
        Size = UDim2.new(0.5, -20, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = multi and table.concat(selected, ", ") or tostring(selected),
        TextColor3 = theme.Muted, TextSize = 12, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = c
    })
    local chev = create("TextLabel", {
        Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -22, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1,
        Text = "▾", TextColor3 = theme.Muted, TextSize = 12, Font = Enum.Font.GothamBold, Parent = c
    })

    local open, drop = false, nil
    local function close()
        if drop then tween(drop, { BackgroundTransparency = 1 }, 0.15)
            task.delay(0.16, function() if drop then drop:Destroy() drop = nil end end) end
        open = false; tween(chev, { Rotation = 0 }, 0.2)
    end

    local function openDrop()
        if open then close() return end
        open = true; tween(chev, { Rotation = 180 }, 0.2)
        drop = create("Frame", {
            Size = UDim2.new(1, 0, 0, math.min(#options*28+8, 160)),
            Position = UDim2.new(0, 0, 1, 4),
            BackgroundColor3 = theme.Surface, BackgroundTransparency = 0.15,
            BorderSizePixel = 0, ZIndex = 50, ClipsDescendants = true, Parent = c
        })
        corner(drop, UDim.new(0, 8)); stroke(drop, theme.Stroke, 0.85, 1)
        local sc = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, #options*28), Parent = drop
        })
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = sc })
        pad(sc, 4, 4, 4, 4)
        for _, opt in ipairs(options) do
            local b = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = theme.Surface2,
                BackgroundTransparency = 1, Text = "  "..tostring(opt), TextColor3 = theme.Text,
                TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false, Parent = sc
            })
            corner(b, UDim.new(0, 5))
            b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.6 }, 0.12) end)
            b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, 0.15) end)
            b.MouseButton1Click:Connect(function()
                if multi then
                    local i = table.find(selected, opt)
                    if i then table.remove(selected, i) else table.insert(selected, opt) end
                    disp.Text = #selected > 0 and table.concat(selected, ", ") or "None"
                    safe(cb, selected)
                else
                    selected = opt; disp.Text = tostring(opt); safe(cb, opt); close()
                end
            end)
        end
    end

    create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c })
        .MouseButton1Click:Connect(openDrop)

    return { Set = function(_, v) selected = v; disp.Text = multi and table.concat(v,", ") or tostring(v) end,
             Get = function() return selected end }
end

function Section:CreateKeybind(opts)
    opts = opts or {}
    local name, def, cb = opts.Name or "Keybind", opts.Default or Enum.KeyCode.E, opts.Callback
    local theme = self.Theme
    local c = elContainer(self, 36)

    create("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = theme.Text,
        TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local key, listening = def, false
    local kbtn = create("TextButton", {
        Size = UDim2.fromOffset(70, 24), Position = UDim2.new(1, -82, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.3, Text = key.Name, TextColor3 = theme.Accent,
        TextSize = 11, Font = Enum.Font.GothamMedium, AutoButtonColor = false, Parent = c
    })
    corner(kbtn, UDim.new(0, 6)); stroke(kbtn, theme.Stroke, 0.85, 1)
    makeInteractive(kbtn, theme)

    kbtn.MouseButton1Click:Connect(function()
        listening = true; kbtn.Text = "..."
        tween(kbtn, { BackgroundColor3 = theme.Accent }, 0.15)
    end)

    self.Maid:Conn(UserInputService.InputBegan:Connect(function(inp)
        if not listening then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            key = inp.KeyCode; kbtn.Text = key.Name; listening = false
            tween(kbtn, { BackgroundColor3 = theme.Surface }, 0.2)
            safe(cb, key)
        end
    end))

    return { Set = function(_, k) key = k; kbtn.Text = k.Name end, Get = function() return key end }
end

function Section:CreateColorPicker(opts)
    opts = opts or {}
    local name, def, cb = opts.Name or "Color", opts.Default or Color3.fromRGB(255, 0, 100), opts.Callback
    local theme = self.Theme
    local c = elContainer(self, 36)

    create("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = theme.Text,
        TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local color = def
    local sw = create("TextButton", {
        Size = UDim2.fromOffset(28, 20), Position = UDim2.new(1, -40, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, Text = "",
        AutoButtonColor = false, Parent = c
    })
    corner(sw, UDim.new(0, 5)); stroke(sw, theme.Stroke, 0.7, 1)
    makeInteractive(sw, theme)

    local palette = {
        Color3.fromRGB(255,0,100), Color3.fromRGB(180,50,255), Color3.fromRGB(50,150,255),
        Color3.fromRGB(50,220,150), Color3.fromRGB(255,200,50), Color3.fromRGB(255,80,80),
        Color3.fromRGB(255,255,255), Color3.fromRGB(30,30,40)
    }
    local idx = 1
    sw.MouseButton1Click:Connect(function()
        idx = (idx % #palette) + 1
        color = palette[idx]
        tween(sw, { BackgroundColor3 = color }, 0.18)
        safe(cb, color)
    end)

    return { Set = function(_, col) color = col; sw.BackgroundColor3 = col end, Get = function() return color end }
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

function Section:CreateTextBox(opts)
    opts = opts or {}
    local name = opts.Name or "TextBox"
    local ph = opts.Placeholder or "..."
    local clear = opts.ClearOnFocus == true
    local cb = opts.Callback
    local theme = self.Theme
    local c = elContainer(self, 36)

    create("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = theme.Text,
        TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local box = create("TextBox", {
        Size = UDim2.new(0.55, -12, 0, 24), Position = UDim2.new(0.45, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.3, Text = "", PlaceholderText = ph,
        PlaceholderColor3 = theme.Muted, TextColor3 = theme.Text, TextSize = 12,
        Font = Enum.Font.Gotham, ClearTextOnFocus = clear, Parent = c
    })
    corner(box, UDim.new(0, 6)); stroke(box, theme.Stroke, 0.88, 1); pad(box, 8, 8, 0, 0)

    box.FocusLost:Connect(function(enter)
        if enter or box.Text ~= "" then safe(cb, box.Text) end
    end)

    return { Set = function(_, t) box.Text = tostring(t) end, Get = function() return box.Text end }
end

--------------------------------------------------------------------
-- Global destroy
--------------------------------------------------------------------
function Ecstasy:Destroy()
    for _, w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
    table.clear(self.Windows)
    self._maid:Clean()
    if self._blur then self._blur:Destroy(); self._blur = nil end
    if notifGui then notifGui:Destroy(); notifGui = nil end
end

return Ecstasy
