--[[
    ecstasy v1.6.0
    Cooler dark cyber-glass UI
    - No version shown
    - Better fonts
    - Larger size
    - Cursor-following shine
    - Redesigned title + loading
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local SoundService     = game:GetService("SoundService")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------
-- Fonts (much cleaner)
--------------------------------------------------------------------
local FontRegular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)
local FontMedium  = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FontBold    = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local FontSemi    = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold)

--------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------
local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[ecstasy]", err) end
end

local function create(class, props)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then i[k] = v end
    end
    if props and props.Parent then i.Parent = props.Parent end
    return i
end

local function corner(p, r)
    return create("UICorner", { CornerRadius = r or UDim.new(0, 10), Parent = p })
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
    local t = TweenService:Create(obj, TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function getMouse()
    local inset = GuiService:GetGuiInset()
    local loc = UserInputService:GetMouseLocation()
    return Vector2.new(loc.X - inset.X, loc.Y - inset.Y)
end

--------------------------------------------------------------------
-- Maid
--------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({ t = {} }, Maid) end
function Maid:Give(x) table.insert(self.t, x) return x end
function Maid:Conn(c) return self:Give(function() if c and c.Connected then c:Disconnect() end end) end
function Maid:Inst(i) return self:Give(function() if i and i.Parent then i:Destroy() end end) end
function Maid:Clean()
    for _, v in ipairs(self.t) do
        local ty = typeof(v)
        if ty == "RBXScriptConnection" then if v.Connected then v:Disconnect() end
        elseif ty == "Instance" then if v.Parent then v:Destroy() end
        elseif ty == "function" then pcall(v) end
    end
    table.clear(self.t)
end

--------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------
local Theme = {
    Accent     = Color3.fromRGB(175, 55, 255),
    Background = Color3.fromRGB(10, 10, 14),
    Surface    = Color3.fromRGB(16, 16, 22),
    Surface2   = Color3.fromRGB(22, 22, 30),
    Surface3   = Color3.fromRGB(30, 30, 40),
    Text       = Color3.fromRGB(242, 242, 250),
    Muted      = Color3.fromRGB(150, 150, 170),
    Stroke     = Color3.fromRGB(255, 255, 255),
    Error      = Color3.fromRGB(255, 90, 110),
}

local GLOW = "rbxassetid://8992230677"
local SHADOW = "rbxassetid://6014261993"

--------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------
local SoundFolder = Instance.new("Folder")
SoundFolder.Name = "EcstasySounds"
SoundFolder.Parent = SoundService

local function mkSound(id, vol)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = vol or 0.28
    s.Parent = SoundFolder
    return s
end

local ClickSnd  = mkSound("rbxassetid://15675032796", 0.26)
local NotifySnd = mkSound("rbxassetid://7383525713", 0.24)

--------------------------------------------------------------------
-- Library
--------------------------------------------------------------------
local Ecstasy = {
    Version = "1.6.0",
    Windows = {},
    Maid = Maid.new(),
    SoundEnabled = true,
    ClickSounds = true,
    NotifySounds = true,
    SoundVolume = 0.3,
}

local function getParent()
    local p
    pcall(function() if typeof(gethui) == "function" then p = gethui() end end)
    if p then return p end
    pcall(function()
        local c = game:GetService("CoreGui")
        local t = Instance.new("Folder") t.Parent = c t:Destroy()
        p = c
    end)
    return p or LocalPlayer:WaitForChild("PlayerGui")
end

function Ecstasy:PlayClick()
    if self.SoundEnabled and self.ClickSounds then
        ClickSnd.Volume = self.SoundVolume
        ClickSnd:Play()
    end
end

function Ecstasy:PlayNotify()
    if self.SoundEnabled and self.NotifySounds then
        NotifySnd.Volume = self.SoundVolume
        NotifySnd:Play()
    end
end

--------------------------------------------------------------------
-- Cursor-following shine (the important part)
--------------------------------------------------------------------
local function addCursorShine(frame)
    local shine = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        ZIndex = 8,
        Parent = frame
    })
    corner(shine, UDim.new(0, 9))

    local grad = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.35, 0.92),
            NumberSequenceKeypoint.new(0.5, 0.78),
            NumberSequenceKeypoint.new(0.65, 0.92),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Offset = Vector2.new(0, 0),
        Rotation = 0,
        Parent = shine
    })

    local hovering = false

    frame.MouseEnter:Connect(function()
        hovering = true
        tween(shine, { BackgroundTransparency = 0.82 }, 0.2)
    end)

    frame.MouseLeave:Connect(function()
        hovering = false
        tween(shine, { BackgroundTransparency = 1 }, 0.25)
    end)

    -- Follow cursor
    local conn = RunService.RenderStepped:Connect(function()
        if not hovering or not frame.Parent then return end
        local mouse = getMouse()
        local pos = frame.AbsolutePosition
        local size = frame.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end

        local relX = (mouse.X - pos.X) / size.X
        local relY = (mouse.Y - pos.Y) / size.Y
        relX = math.clamp(relX, 0, 1)
        relY = math.clamp(relY, 0, 1)

        -- Move the light toward the cursor
        grad.Offset = Vector2.new((relX - 0.5) * 1.4, (relY - 0.5) * 1.4)
        grad.Rotation = (relX - 0.5) * 40
    end)

    frame.Destroying:Connect(function()
        conn:Disconnect()
    end)

    return shine
end

--------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------
local NGui, NHolder
local function ensureNotif()
    if NGui and NGui.Parent then return end
    NGui = create("ScreenGui", {
        Name = "EcstasyNotifs", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 9999,
        Parent = getParent()
    })
    Ecstasy.Maid:Inst(NGui)
    NHolder = create("Frame", {
        AnchorPoint = Vector2.new(1,1), Position = UDim2.new(1,-20,1,-20),
        Size = UDim2.new(0, 320, 1, -40), BackgroundTransparency = 1, Parent = NGui
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 11), Parent = NHolder
    })
end

function Ecstasy:Notify(o)
    o = o or {}
    ensureNotif()
    self:PlayNotify()

    local card = create("Frame", {
        Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0.06,
        BorderSizePixel = 0, Parent = NHolder
    })
    corner(card, UDim.new(0, 12))
    stroke(card, Theme.Stroke, 0.86)
    pad(card, 15, 15, 13, 13)

    create("Frame", {
        Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0, Parent = card
    })

    create("TextLabel", {
        Size = UDim2.new(1, -12, 0, 17), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = o.Title or "Notification",
        TextColor3 = Theme.Text, TextSize = 14, FontFace = FontMedium,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card
    })
    create("TextLabel", {
        Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(12, 20), BackgroundTransparency = 1,
        Text = o.Content or "", TextColor3 = Theme.Muted, TextSize = 12,
        FontFace = FontRegular, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card
    })

    local bar = create("Frame", {
        Size = UDim2.new(1,0,0,2), Position = UDim2.new(0,0,1,-2),
        BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0, Parent = card
    })
    local fill = create("Frame", {
        Size = UDim2.fromScale(1,1), BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0, Parent = bar
    })

    card.Position = UDim2.new(1, 40, 0, 0)
    card.BackgroundTransparency = 1
    tween(card, {Position = UDim2.new(0,0,0,0), BackgroundTransparency = 0.06}, 0.35, Enum.EasingStyle.Back)
    tween(fill, {Size = UDim2.fromScale(0,1)}, o.Duration or 3.5, Enum.EasingStyle.Linear)

    task.delay(o.Duration or 3.5, function()
        if not card.Parent then return end
        tween(card, {Position = UDim2.new(1,50,0,0), BackgroundTransparency = 1}, 0.28)
        task.wait(0.3)
        if card.Parent then card:Destroy() end
    end)
end

--------------------------------------------------------------------
-- Cooler Loading Screen
--------------------------------------------------------------------
local function playLoading(parent, theme, done)
    local ov = create("Frame", {
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = Color3.fromRGB(6, 6, 9),
        BackgroundTransparency = 0,
        ZIndex = 500,
        Parent = parent
    })

    local center = create("Frame", {
        Size = UDim2.fromOffset(300, 210),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = ov
    })

    -- Glow behind logo
    local logoGlow = create("ImageLabel", {
        Size = UDim2.fromOffset(220, 100),
        Position = UDim2.new(0.5, 0, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Image = GLOW,
        ImageColor3 = theme.Accent,
        ImageTransparency = 0.75,
        Parent = center
    })

    -- Main title with gradient feel
    local title = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 28),
        BackgroundTransparency = 1,
        Text = "ecstasy",
        TextColor3 = theme.Text,
        TextSize = 36,
        FontFace = FontBold,
        TextTransparency = 1,
        Parent = center
    })

    -- Accent line under title
    local line = create("Frame", {
        Size = UDim2.fromOffset(0, 2),
        Position = UDim2.new(0.5, 0, 0, 78),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = center
    })
    corner(line, UDim.new(1, 0))

    local status = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.fromOffset(0, 110),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.Muted,
        TextSize = 13,
        FontFace = FontRegular,
        TextTransparency = 1,
        Parent = center
    })

    -- Progress bar
    local progBg = create("Frame", {
        Size = UDim2.fromOffset(160, 3),
        Position = UDim2.new(0.5, 0, 0, 150),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = theme.Surface3,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = center
    })
    corner(progBg, UDim.new(1, 0))
    local prog = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Parent = progBg
    })
    corner(prog, UDim.new(1, 0))

    -- Fade in
    tween(title, { TextTransparency = 0 }, 0.45)
    tween(logoGlow, { ImageTransparency = 0.7 }, 0.5)
    tween(line, { BackgroundTransparency = 0, Size = UDim2.fromOffset(70, 2) }, 0.5, Enum.EasingStyle.Back)
    tween(status, { TextTransparency = 0 }, 0.4)
    tween(progBg, { BackgroundTransparency = 0 }, 0.4)
    task.wait(0.35)

    local steps = {
        { t = "Loading modules", p = 0.25 },
        { t = "Building interface", p = 0.55 },
        { t = "Applying effects", p = 0.8 },
        { t = "Ready", p = 1 },
    }

    for _, s in ipairs(steps) do
        status.Text = s.t
        tween(prog, { Size = UDim2.fromScale(s.p, 1) }, 0.28)
        task.wait(0.32)
    end

    task.wait(0.15)

    -- Exit
    tween(title, { TextTransparency = 1 }, 0.3)
    tween(line, { BackgroundTransparency = 1 }, 0.25)
    tween(status, { TextTransparency = 1 }, 0.25)
    tween(progBg, { BackgroundTransparency = 1 }, 0.25)
    tween(logoGlow, { ImageTransparency = 1 }, 0.3)
    tween(ov, { BackgroundTransparency = 1 }, 0.4)
    task.wait(0.42)
    ov:Destroy()
    if done then done() end
end

--------------------------------------------------------------------
-- Window
--------------------------------------------------------------------
local Window = {}
Window.__index = Window

function Ecstasy:CreateWindow(opts)
    opts = opts or {}
    local theme = opts.Theme or {}
    for k, v in pairs(Theme) do if theme[k] == nil then theme[k] = v end end

    local win = setmetatable({
        Name = opts.Name or "ecstasy",
        SubTitle = opts.SubTitle or "Glass Engine",
        Size = opts.Size or UDim2.fromOffset(820, 560), -- larger
        Keybind = opts.Keybind or Enum.KeyCode.RightControl,
        Blur = opts.Blur ~= false,
        Theme = theme,
        Tabs = {},
        Maid = Maid.new(),
        Visible = true,
    }, Window)

    local gui = create("ScreenGui", {
        Name = "Ecstasy_" .. HttpService:GenerateGUID(false):sub(1, 6),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
        IgnoreGuiInset = true,
        Parent = getParent()
    })
    win.Gui = gui
    win.Maid:Inst(gui)
    Ecstasy.Maid:Inst(gui)

    -- Purple glow falloff
    local glowHost = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Parent = gui
    })
    win.GlowHost = glowHost

    for _, L in ipairs({
        { s = 100, t = 0.8 },
        { s = 160, t = 0.87 },
        { s = 230, t = 0.93 },
    }) do
        create("ImageLabel", {
            Size = UDim2.new(1, L.s, 1, L.s),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = GLOW,
            ImageColor3 = theme.Accent,
            ImageTransparency = L.t,
            ZIndex = 0,
            Parent = glowHost
        })
    end

    create("ImageLabel", {
        Size = UDim2.new(1, 50, 1, 50),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = SHADOW,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.5,
        ZIndex = 0,
        Parent = glowHost
    })

    -- Main
    local main = create("Frame", {
        Name = "Main",
        Size = win.Size,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 2,
        Parent = gui
    })
    win.Main = main
    corner(main, UDim.new(0, 14))
    stroke(main, theme.Stroke, 0.8)

    -- Top bar
    local top = create("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Parent = main
    })
    corner(top, UDim.new(0, 14))
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Parent = top
    })

    -- Cooler title treatment
    local titleLabel = create("TextLabel", {
        Size = UDim2.new(0, 200, 0, 22),
        Position = UDim2.fromOffset(22, 10),
        BackgroundTransparency = 1,
        Text = win.Name,
        TextColor3 = theme.Text,
        TextSize = 18,
        FontFace = FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = top
    })

    -- Small accent underline under title
    create("Frame", {
        Size = UDim2.fromOffset(28, 2),
        Position = UDim2.fromOffset(22, 34),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Parent = top
    })

    create("TextLabel", {
        Size = UDim2.new(1, -140, 0, 14),
        Position = UDim2.fromOffset(22, 38),
        BackgroundTransparency = 1,
        Text = win.SubTitle,
        TextColor3 = theme.Muted,
        TextSize = 11,
        FontFace = FontRegular,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = top
    })

    local close = create("TextButton", {
        Size = UDim2.fromOffset(34, 34),
        Position = UDim2.new(1, -46, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.Surface2,
        BackgroundTransparency = 0.25,
        Text = "×",
        TextColor3 = theme.Muted,
        TextSize = 18,
        FontFace = FontBold,
        AutoButtonColor = false,
        Parent = top
    })
    corner(close, UDim.new(0, 9))
    addCursorShine(close)
    close.MouseEnter:Connect(function()
        tween(close, { BackgroundTransparency = 0.05, TextColor3 = theme.Error }, 0.15)
    end)
    close.MouseLeave:Connect(function()
        tween(close, { BackgroundTransparency = 0.25, TextColor3 = theme.Muted }, 0.2)
    end)
    close.MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        win:Destroy()
    end)

    -- Sidebar
    local side = create("Frame", {
        Size = UDim2.new(0, 190, 1, -58),
        Position = UDim2.fromOffset(0, 58),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Parent = main
    })
    win.Sidebar = side
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = side
    })
    pad(side, 12, 12, 14, 14)

    -- Content
    local content = create("Frame", {
        Size = UDim2.new(1, -190, 1, -58),
        Position = UDim2.fromOffset(190, 58),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = main
    })
    win.Content = content

    -- Dragging
    local dragging, dragStart, startPos, targetPos, currentPos =
        false, Vector2.zero, main.Position, main.Position, main.Position

    win.Maid:Conn(top.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            startPos = main.Position
            currentPos = main.Position
            targetPos = main.Position
        end
    end))
    win.Maid:Conn(UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
        targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end))
    win.Maid:Conn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    win.Maid:Conn(RunService.RenderStepped:Connect(function(dt)
        if not main.Parent then return end
        local a = math.clamp(dt * 16, 0, 1)
        local x = currentPos.X.Offset + (targetPos.X.Offset - currentPos.X.Offset) * a
        local y = currentPos.Y.Offset + (targetPos.Y.Offset - currentPos.Y.Offset) * a
        currentPos = UDim2.new(targetPos.X.Scale, x, targetPos.Y.Scale, y)
        main.Position = currentPos
        glowHost.Position = currentPos
        glowHost.Size = main.Size
    end))

    win.Maid:Conn(UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == win.Keybind then win:Toggle() end
    end))

    if win.Blur then
        local b = Instance.new("BlurEffect")
        b.Size = 0
        b.Parent = Lighting
        win.Maid:Inst(b)
        tween(b, { Size = 12 }, 0.4)
    end

    playLoading(gui, theme, function()
        main.Visible = true
        main.Size = UDim2.fromOffset(0, 0)
        main.BackgroundTransparency = 1
        tween(main, {
            Size = win.Size,
            BackgroundTransparency = 0.08
        }, 0.45, Enum.EasingStyle.Back)
    end)

    table.insert(Ecstasy.Windows, win)
    return win
end

function Window:Toggle()
    self.Visible = not self.Visible
    local m = self.Main
    if self.Visible then
        m.Visible = true
        tween(m, { BackgroundTransparency = 0.08 }, 0.25)
    else
        tween(m, { BackgroundTransparency = 1 }, 0.2)
        task.delay(0.22, function()
            if not self.Visible then m.Visible = false end
        end)
    end
end

function Window:Destroy()
    if self._dead then return end
    self._dead = true
    self.Maid:Clean()
    for i, w in ipairs(Ecstasy.Windows) do
        if w == self then table.remove(Ecstasy.Windows, i) break end
    end
end

--------------------------------------------------------------------
-- Tab / Section / Components (with cursor shine)
--------------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

function Window:CreateTab(opts)
    opts = opts or {}
    local name = opts.Name or "Tab"
    local tab = setmetatable({
        Name = name, Window = self, Sections = {}, Maid = Maid.new(), Active = false
    }, Tab)

    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = self.Theme.Surface2,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = self.Sidebar
    })
    corner(btn, UDim.new(0, 10))
    tab.Button = btn
    addCursorShine(btn)

    local accent = create("Frame", {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 7, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = btn
    })
    corner(accent, UDim.new(0, 2))
    tab.Accent = accent

    local label = create("TextLabel", {
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.fromOffset(20, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = self.Theme.Muted,
        TextSize = 14,
        FontFace = FontMedium,
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
    pad(page, 18, 18, 16, 18)

    local left = create("Frame", {
        Size = UDim2.new(0.5, -9, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = page
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 13), Parent = left })
    tab.Left = left

    local right = create("Frame", {
        Size = UDim2.new(0.5, -9, 0, 0),
        Position = UDim2.new(0.5, 9, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = page
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 13), Parent = right })
    tab.Right = right

    btn.MouseEnter:Connect(function()
        if not tab.Active then
            tween(btn, { BackgroundTransparency = 0.6 }, 0.15)
            tween(label, { TextColor3 = self.Theme.Text }, 0.15)
        end
    end)
    btn.MouseLeave:Connect(function()
        if not tab.Active then
            tween(btn, { BackgroundTransparency = 1 }, 0.2)
            tween(label, { TextColor3 = self.Theme.Muted }, 0.2)
        end
    end)
    btn.MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then self:SelectTab(tab) end
    return tab
end

function Window:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        t.Active = false
        t.Page.Visible = false
        tween(t.Button, { BackgroundTransparency = 1 }, 0.2)
        tween(t.Label, { TextColor3 = self.Theme.Muted }, 0.2)
        tween(t.Accent, { BackgroundTransparency = 1 }, 0.2)
    end
    tab.Active = true
    tab.Page.Visible = true
    tween(tab.Button, { BackgroundTransparency = 0.45 }, 0.22)
    tween(tab.Label, { TextColor3 = self.Theme.Text }, 0.22)
    tween(tab.Accent, { BackgroundTransparency = 0 }, 0.22)
end

local Section = {}
Section.__index = Section

function Tab:CreateSection(opts)
    opts = opts or {}
    local name = opts.Name or "Section"
    local side = string.lower(opts.Side or "Left")
    local parent = side == "right" and self.Right or self.Left

    local sec = setmetatable({
        Name = name, Tab = self, Window = self.Window,
        Theme = self.Window.Theme, Maid = Maid.new()
    }, Section)

    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = self.Window.Theme.Surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Parent = parent
    })
    corner(frame, UDim.new(0, 12))
    stroke(frame, self.Window.Theme.Stroke, 0.86)
    pad(frame, 15, 15, 13, 15)
    sec.Frame = frame

    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = self.Window.Theme.Accent,
        TextSize = 12,
        FontFace = FontSemi,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })

    local list = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = frame
    })
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 9), Parent = list })
    sec.List = list

    table.insert(self.Sections, sec)
    return sec
end

local function el(sec, h)
    local th = sec.Theme
    local c = create("Frame", {
        Size = UDim2.new(1, 0, 0, h or 44),
        BackgroundColor3 = th.Surface2,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = sec.List
    })
    corner(c, UDim.new(0, 9))
    local s = stroke(c, th.Stroke, 0.88)
    addCursorShine(c)

    c.MouseEnter:Connect(function()
        tween(s, { Transparency = 0.68 }, 0.15)
        tween(c, { BackgroundTransparency = 0.15 }, 0.15)
    end)
    c.MouseLeave:Connect(function()
        tween(s, { Transparency = 0.88 }, 0.2)
        tween(c, { BackgroundTransparency = 0.3 }, 0.2)
    end)
    return c
end

function Section:CreateToggle(opts)
    opts = opts or {}
    local name, def, cb = opts.Name or "Toggle", opts.Default == true, opts.Callback
    local th = self.Theme
    local c = el(self, 44)

    create("TextLabel", {
        Size = UDim2.new(1, -68, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
        TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local track = create("Frame", {
        Size = UDim2.fromOffset(42, 24), Position = UDim2.new(1, -56, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
        BorderSizePixel = 0, Parent = c
    })
    corner(track, UDim.new(1, 0))
    local knob = create("Frame", {
        Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = th.Muted, BorderSizePixel = 0, Parent = track
    })
    corner(knob, UDim.new(1, 0))

    local state = def
    local function set(v, fire)
        state = v
        if state then
            tween(track, { BackgroundColor3 = th.Accent }, 0.2)
            tween(knob, { Position = UDim2.fromOffset(21, 3), BackgroundColor3 = Color3.new(1,1,1) }, 0.2)
        else
            tween(track, { BackgroundColor3 = th.Surface3 }, 0.2)
            tween(knob, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = th.Muted }, 0.2)
        end
        if fire ~= false then safe(cb, state) end
    end
    set(def, false)

    create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c
    }).MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        set(not state)
    end)

    return { Set = function(_, v) set(v == true) end, Get = function() return state end }
end

function Section:CreateButton(opts)
    opts = opts or {}
    local name, cb = opts.Name or "Button", opts.Callback
    local th = self.Theme
    local c = el(self, 44)

    local btn = create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = name,
        TextColor3 = th.Text, TextSize = 14, FontFace = FontMedium,
        AutoButtonColor = false, Parent = c
    })
    btn.MouseEnter:Connect(function() tween(btn, { TextColor3 = th.Accent }, 0.15) end)
    btn.MouseLeave:Connect(function() tween(btn, { TextColor3 = th.Text }, 0.2) end)
    btn.MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        tween(c, { BackgroundTransparency = 0.08 }, 0.08)
        task.delay(0.1, function() tween(c, { BackgroundTransparency = 0.3 }, 0.25) end)
        safe(cb)
    end)
    return {}
end

function Section:CreateSlider(opts)
    opts = opts or {}
    local name = opts.Name or "Slider"
    local min, max, def = opts.Min or 0, opts.Max or 100, opts.Default or opts.Min or 0
    local dec, cb = opts.Decimals or 0, opts.Callback
    local th = self.Theme
    local c = el(self, 58)

    create("TextLabel", {
        Size = UDim2.new(1, -75, 0, 17), Position = UDim2.fromOffset(14, 8),
        BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
        TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })
    local val = create("TextLabel", {
        Size = UDim2.new(0, 65, 0, 17), Position = UDim2.new(1, -75, 0, 8),
        BackgroundTransparency = 1, Text = "", TextColor3 = th.Accent,
        TextSize = 13, FontFace = FontMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = c
    })

    local bar = create("Frame", {
        Size = UDim2.new(1, -28, 0, 5), Position = UDim2.fromOffset(14, 38),
        BackgroundColor3 = th.Surface3, BorderSizePixel = 0, Parent = c
    })
    corner(bar, UDim.new(1, 0))
    local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = th.Accent, BorderSizePixel = 0, Parent = bar })
    corner(fill, UDim.new(1, 0))
    local knob = create("Frame", {
        Size = UDim2.fromOffset(13, 13), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0, Parent = bar
    })
    corner(knob, UDim.new(1, 0))

    local value = def
    local function set(v, fire)
        v = math.clamp(v, min, max)
        if dec > 0 then local m = 10^dec v = math.floor(v*m+0.5)/m else v = math.floor(v+0.5) end
        value = v
        local p = (v - min) / (max - min)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, 0, 0.5, 0)
        val.Text = tostring(v)
        if fire ~= false then safe(cb, v) end
    end
    set(def, false)

    local sliding = false
    local function upd(inp)
        local r = (inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
        set(min + math.clamp(r, 0, 1) * (max - min))
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliding = true upd(i)
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
    local name = opts.Name or "Dropdown"
    local options = opts.Options or { "One", "Two", "Three" }
    local def = opts.Default or options[1]
    local cb = opts.Callback
    local th = self.Theme
    local c = el(self, 44)

    create("TextLabel", {
        Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
        TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local selected = def
    local disp = create("TextLabel", {
        Size = UDim2.new(0.5, -16, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1, Text = tostring(selected), TextColor3 = th.Muted,
        TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = c
    })

    local open, drop = false, nil
    local function close()
        if drop then drop:Destroy() drop = nil end
        open = false
    end

    create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c
    }).MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        if open then close() return end
        open = true
        drop = create("Frame", {
            Size = UDim2.new(1, 0, 0, math.min(#options * 32 + 10, 160)),
            Position = UDim2.new(0, 0, 1, 6),
            BackgroundColor3 = th.Surface,
            BackgroundTransparency = 0.04,
            BorderSizePixel = 0, ZIndex = 60, Parent = c
        })
        corner(drop, UDim.new(0, 10))
        stroke(drop, th.Stroke, 0.84)
        local sc = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, #options * 32), Parent = drop
        })
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = sc })
        pad(sc, 6, 6, 6, 6)
        for _, opt in ipairs(options) do
            local b = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = th.Surface2,
                BackgroundTransparency = 1, Text = "  " .. tostring(opt), TextColor3 = th.Text,
                TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false, Parent = sc
            })
            corner(b, UDim.new(0, 6))
            b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.5 }, 0.12) end)
            b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, 0.15) end)
            b.MouseButton1Click:Connect(function()
                selected = opt
                disp.Text = tostring(opt)
                safe(cb, opt)
                close()
            end)
        end
    end)

    return { Set = function(_, v) selected = v disp.Text = tostring(v) end, Get = function() return selected end }
end

function Section:CreateKeybind(opts)
    opts = opts or {}
    local name, def, cb = opts.Name or "Keybind", opts.Default or Enum.KeyCode.E, opts.Callback
    local th = self.Theme
    local c = el(self, 44)

    create("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
        TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local key, listening = def, false
    local kb = create("TextButton", {
        Size = UDim2.fromOffset(78, 28), Position = UDim2.new(1, -92, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
        BackgroundTransparency = 0.2, Text = key.Name, TextColor3 = th.Accent,
        TextSize = 12, FontFace = FontMedium, AutoButtonColor = false, Parent = c
    })
    corner(kb, UDim.new(0, 7))
    stroke(kb, th.Stroke, 0.85)

    kb.MouseButton1Click:Connect(function()
        listening = true
        kb.Text = "..."
        tween(kb, { BackgroundColor3 = th.Accent }, 0.15)
    end)

    self.Maid:Conn(UserInputService.InputBegan:Connect(function(inp)
        if not listening then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            key = inp.KeyCode
            kb.Text = key.Name
            listening = false
            tween(kb, { BackgroundColor3 = th.Surface3 }, 0.2)
            safe(cb, key)
        end
    end))

    return { Set = function(_, k) key = k kb.Text = k.Name end, Get = function() return key end }
end

function Section:CreateColorPicker(opts)
    opts = opts or {}
    local name, def, cb = opts.Name or "Color", opts.Default or Theme.Accent, opts.Callback
    local th = self.Theme
    local c = el(self, 44)

    create("TextLabel", {
        Size = UDim2.new(1, -58, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
        TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local color = def
    local sw = create("TextButton", {
        Size = UDim2.fromOffset(32, 22), Position = UDim2.new(1, -46, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, Text = "",
        AutoButtonColor = false, Parent = c
    })
    corner(sw, UDim.new(0, 6))
    stroke(sw, th.Stroke, 0.7)

    local palette = {
        Color3.fromRGB(175, 55, 255), Color3.fromRGB(255, 70, 120),
        Color3.fromRGB(50, 150, 255), Color3.fromRGB(50, 220, 150),
        Color3.fromRGB(255, 190, 50), Color3.fromRGB(255, 90, 90),
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 40, 50)
    }
    local idx = 1
    sw.MouseButton1Click:Connect(function()
        Ecstasy:PlayClick()
        idx = (idx % #palette) + 1
        color = palette[idx]
        tween(sw, { BackgroundColor3 = color }, 0.15)
        safe(cb, color)
    end)

    return { Set = function(_, col) color = col sw.BackgroundColor3 = col end, Get = function() return color end }
end

function Section:CreateTextBox(opts)
    opts = opts or {}
    local name = opts.Name or "Input"
    local ph = opts.Placeholder or "..."
    local cb = opts.Callback
    local th = self.Theme
    local c = el(self, 44)

    create("TextLabel", {
        Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
        TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
    })

    local box = create("TextBox", {
        Size = UDim2.new(0.55, -10, 0, 28), Position = UDim2.new(0.42, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
        BackgroundTransparency = 0.2, Text = "", PlaceholderText = ph,
        PlaceholderColor3 = th.Muted, TextColor3 = th.Text, TextSize = 13,
        FontFace = FontRegular, ClearTextOnFocus = false, Parent = c
    })
    corner(box, UDim.new(0, 7))
    stroke(box, th.Stroke, 0.86)
    pad(box, 10, 10, 0, 0)

    box.FocusLost:Connect(function(enter)
        if enter or box.Text ~= "" then safe(cb, box.Text) end
    end)

    return { Set = function(_, t) box.Text = tostring(t) end, Get = function() return box.Text end }
end

function Window:CreatePremadeTab(opts)
    opts = opts or {}
    local tab = self:CreateTab({ Name = opts.Name or "Demo" })
    local L = tab:CreateSection({ Name = "Controls", Side = "Left" })
    local R = tab:CreateSection({ Name = "More", Side = "Right" })

    L:CreateToggle({ Name = "Enable Feature", Default = false, Callback = print })
    L:CreateSlider({ Name = "Value", Min = 0, Max = 100, Default = 50, Callback = print })
    L:CreateButton({ Name = "Test Action", Callback = function()
        Ecstasy:Notify({ Title = "Success", Content = "Action completed.", Duration = 3 })
    end })
    L:CreateDropdown({ Name = "Mode", Options = { "Normal", "Fast", "Silent" }, Default = "Normal", Callback = print })

    R:CreateKeybind({ Name = "Key", Default = Enum.KeyCode.E, Callback = function(k) print(k.Name) end })
    R:CreateColorPicker({ Name = "Color", Default = Theme.Accent, Callback = print })
    R:CreateTextBox({ Name = "Name", Placeholder = "Type...", Callback = print })
    R:CreateButton({ Name = "Notify", Callback = function()
        Ecstasy:Notify({ Title = "ecstasy", Content = "Looking much better now.", Duration = 3 })
    end })

    return tab
end

function Ecstasy:Destroy()
    for _, w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
    table.clear(self.Windows)
    self.Maid:Clean()
    if SoundFolder then SoundFolder:Destroy() end
end

return Ecstasy
