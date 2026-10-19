local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

local FontRegular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)
local FontMedium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FontSemi = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold)
local FontBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

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
	return create("UICorner", { CornerRadius = r or UDim.new(0, 12), Parent = p })
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
	local t = TweenService:Create(obj, TweenInfo.new(dur or 0.22, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function getMouse()
	local inset = GuiService:GetGuiInset()
	local loc = UserInputService:GetMouseLocation()
	return Vector2.new(loc.X - inset.X, loc.Y - inset.Y)
end

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

local Theme = {
	Accent = Color3.fromRGB(168, 85, 247),
	Background = Color3.fromRGB(8, 8, 11),
	Surface = Color3.fromRGB(14, 14, 19),
	Surface2 = Color3.fromRGB(20, 20, 27),
	Surface3 = Color3.fromRGB(28, 28, 38),
	Text = Color3.fromRGB(245, 245, 252),
	Muted = Color3.fromRGB(150, 150, 170),
	Stroke = Color3.fromRGB(255, 255, 255),
	Error = Color3.fromRGB(248, 113, 113),
}

local GLOW = "rbxassetid://8992230677"
local SHADOW = "rbxassetid://6014261993"
local CONFIG_PATH = "ecstasy_config.json"

local SoundFolder = Instance.new("Folder")
SoundFolder.Name = "EcstasySounds"
SoundFolder.Parent = SoundService

local function mkSound(id, vol)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.22
	s.Parent = SoundFolder
	return s
end

local ClickSnd = mkSound("rbxassetid://6895079853", 0.2)
local NotifySnd = mkSound("rbxassetid://9117411570", 0.16)

local Ecstasy = {
	Windows = {},
	Maid = Maid.new(),
	SoundEnabled = true,
	ClickSounds = true,
	NotifySounds = true,
	SoundVolume = 0.22,
	GlassTransparency = 0.12,
	Keybind = Enum.KeyCode.RightControl,
	_glassObjects = {},
}

local function getParent()
	local p
	pcall(function() if typeof(gethui) == "function" then p = gethui() end end)
	if p then return p end
	pcall(function()
		local c = game:GetService("CoreGui")
		local t = Instance.new("Folder")
		t.Parent = c
		t:Destroy()
		p = c
	end)
	return p or LocalPlayer:WaitForChild("PlayerGui")
end

local function canFile()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function saveConfig()
	if not canFile() then return end
	local data = {
		SoundEnabled = Ecstasy.SoundEnabled,
		ClickSounds = Ecstasy.ClickSounds,
		NotifySounds = Ecstasy.NotifySounds,
		SoundVolume = Ecstasy.SoundVolume,
		GlassTransparency = Ecstasy.GlassTransparency,
		Keybind = Ecstasy.Keybind and Ecstasy.Keybind.Name or "RightControl",
	}
	pcall(function()
		writefile(CONFIG_PATH, HttpService:JSONEncode(data))
	end)
end

local function loadConfig()
	if not canFile() or not isfile(CONFIG_PATH) then return end
	local ok, raw = pcall(readfile, CONFIG_PATH)
	if not ok or not raw then return end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 or type(data) ~= "table" then return end
	if data.SoundEnabled ~= nil then Ecstasy.SoundEnabled = data.SoundEnabled end
	if data.ClickSounds ~= nil then Ecstasy.ClickSounds = data.ClickSounds end
	if data.NotifySounds ~= nil then Ecstasy.NotifySounds = data.NotifySounds end
	if data.SoundVolume ~= nil then Ecstasy.SoundVolume = data.SoundVolume end
	if data.GlassTransparency ~= nil then Ecstasy.GlassTransparency = data.GlassTransparency end
	if data.Keybind then
		local k = Enum.KeyCode[data.Keybind]
		if k then Ecstasy.Keybind = k end
	end
end

loadConfig()

function Ecstasy:PlayClick()
	if self.SoundEnabled and self.ClickSounds then
		ClickSnd.Volume = self.SoundVolume
		ClickSnd:Play()
	end
end

function Ecstasy:PlayNotify()
	if self.SoundEnabled and self.NotifySounds then
		NotifySnd.Volume = self.SoundVolume * 0.85
		NotifySnd:Play()
	end
end

function Ecstasy:RegisterGlass(obj, baseTrans)
	table.insert(self._glassObjects, { obj = obj, base = baseTrans or 0.1 })
	obj.BackgroundTransparency = math.clamp((baseTrans or 0.1) + self.GlassTransparency, 0, 0.95)
end

function Ecstasy:ApplyGlass()
	local g = self.GlassTransparency
	for _, entry in ipairs(self._glassObjects) do
		if entry.obj and entry.obj.Parent then
			entry.obj.BackgroundTransparency = math.clamp(entry.base + g, 0, 0.95)
		end
	end
	for _, win in ipairs(self.Windows) do
		if win.Main and win.Main.Parent and win.Visible then
			win.Main.BackgroundTransparency = math.clamp(0.04 + g, 0, 0.9)
		end
	end
end

local function addHover(frame, scaleTarget)
	local shine = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = frame
	})
	corner(shine, UDim.new(0, 10))
	local grad = create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.88),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(0.65, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine
	})
	local scale = create("UIScale", { Scale = 1, Parent = scaleTarget or frame })
	local hovering = false
	frame.MouseEnter:Connect(function()
		hovering = true
		tween(shine, { BackgroundTransparency = 0.72 }, 0.18)
		tween(scale, { Scale = 1.035 }, 0.2, Enum.EasingStyle.Quint)
	end)
	frame.MouseLeave:Connect(function()
		hovering = false
		tween(shine, { BackgroundTransparency = 1 }, 0.22)
		tween(scale, { Scale = 1 }, 0.22, Enum.EasingStyle.Quint)
	end)
	frame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = 0.97 }, 0.08)
		end
	end)
	frame.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = hovering and 1.035 or 1 }, 0.18)
		end
	end)
	local conn = RunService.RenderStepped:Connect(function()
		if not hovering or not frame.Parent then return end
		local mouse = getMouse()
		local pos = frame.AbsolutePosition
		local size = frame.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		local rx = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
		local ry = math.clamp((mouse.Y - pos.Y) / size.Y, 0, 1)
		grad.Offset = Vector2.new((rx - 0.5) * 1.5, (ry - 0.5) * 1.5)
		grad.Rotation = (rx - 0.5) * 45
	end)
	frame.Destroying:Connect(function() conn:Disconnect() end)
end

local NGui, NHolder
local function ensureNotif()
	if NGui and NGui.Parent then return end
	NGui = create("ScreenGui", {
		Name = "EcstasyNotifs",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10000,
		Parent = getParent()
	})
	Ecstasy.Maid:Inst(NGui)
	NHolder = create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.new(0, 310, 1, -44),
		BackgroundTransparency = 1,
		Parent = NGui
	})
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 12),
		Parent = NHolder
	})
end

function Ecstasy:Notify(o)
	o = o or {}
	ensureNotif()
	self:PlayNotify()
	local title = o.Title or "Notification"
	local content = o.Content or ""
	local duration = o.Duration or 4

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.15 + self.GlassTransparency * 0.5,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = NHolder
	})
	corner(card, UDim.new(0, 14))
	stroke(card, Theme.Stroke, 0.9)
	pad(card, 16, 16, 14, 16)
	self:RegisterGlass(card, 0.12)

	create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = card
	})

	create("TextLabel", {
		Size = UDim2.new(1, -14, 0, 18),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 14,
		FontFace = FontSemi,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card
	})

	if content ~= "" then
		create("TextLabel", {
			Size = UDim2.new(1, -14, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(14, 22),
			BackgroundTransparency = 1,
			Text = content,
			TextColor3 = Theme.Muted,
			TextSize = 12,
			FontFace = FontRegular,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card
		})
	end

	local progBg = create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Theme.Surface3,
		BorderSizePixel = 0,
		Parent = card
	})
	local prog = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = progBg
	})

	card.Position = UDim2.new(1, 50, 0, 0)
	card.BackgroundTransparency = 1
	tween(card, {
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = math.clamp(0.12 + self.GlassTransparency * 0.5, 0, 0.85)
	}, 0.42, Enum.EasingStyle.Quint)
	tween(prog, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if not card.Parent then return end
		tween(card, {
			Position = UDim2.new(1, 55, 0, 0),
			BackgroundTransparency = 1
		}, 0.32, Enum.EasingStyle.Quint)
		task.wait(0.34)
		if card.Parent then card:Destroy() end
	end)
end

local function playLoading(parent, theme, done)
	local ov = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(5, 5, 7),
		BackgroundTransparency = 0,
		ZIndex = 600,
		Parent = parent
	})
	local center = create("Frame", {
		Size = UDim2.fromOffset(320, 200),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = ov
	})

	local ringOuter = create("Frame", {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = center
	})
	local ringStroke = create("UIStroke", {
		Color = theme.Accent,
		Thickness = 2.5,
		Transparency = 0.15,
		Parent = ringOuter
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ringOuter })
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0),
			NumberSequenceKeypoint.new(1, 1)
		}),
		Parent = ringStroke
	})

	local ringInner = create("Frame", {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = ringOuter
	})
	local ringStroke2 = create("UIStroke", {
		Color = theme.Accent,
		Thickness = 1.5,
		Transparency = 0.45,
		Parent = ringInner
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ringInner })

	local title = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 100),
		BackgroundTransparency = 1,
		Text = "ecstasy",
		TextColor3 = theme.Text,
		TextSize = 28,
		FontFace = FontBold,
		TextTransparency = 1,
		Parent = center
	})

	local line = create("Frame", {
		Size = UDim2.fromOffset(0, 2),
		Position = UDim2.new(0.5, 0, 0, 140),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = center
	})
	corner(line, UDim.new(1, 0))

	local status = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 158),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.Muted,
		TextSize = 12,
		FontFace = FontRegular,
		TextTransparency = 1,
		Parent = center
	})

	local spinConn = RunService.RenderStepped:Connect(function(dt)
		ringOuter.Rotation = (ringOuter.Rotation + dt * 210) % 360
		ringInner.Rotation = (ringInner.Rotation - dt * 140) % 360
	end)

	tween(title, { TextTransparency = 0 }, 0.5)
	tween(line, { BackgroundTransparency = 0, Size = UDim2.fromOffset(56, 2) }, 0.55, Enum.EasingStyle.Back)
	tween(status, { TextTransparency = 0 }, 0.4)
	task.wait(0.35)

	local steps = {
		{ "Preparing", 0.28 },
		{ "Loading modules", 0.32 },
		{ "Building interface", 0.3 },
		{ "Almost ready", 0.28 },
	}
	for _, s in ipairs(steps) do
		status.Text = s[1]
		task.wait(s[2])
	end
	status.Text = "Ready"
	task.wait(0.2)

	local sc = create("UIScale", { Scale = 1, Parent = center })
	tween(sc, { Scale = 1.08 }, 0.28, Enum.EasingStyle.Back)
	tween(title, { TextTransparency = 1 }, 0.28)
	tween(line, { BackgroundTransparency = 1 }, 0.25)
	tween(status, { TextTransparency = 1 }, 0.25)
	tween(ringStroke, { Transparency = 1 }, 0.3)
	tween(ringStroke2, { Transparency = 1 }, 0.3)
	tween(ov, { BackgroundTransparency = 1 }, 0.4)
	task.wait(0.42)
	spinConn:Disconnect()
	ov:Destroy()
	if done then done() end
end

local Window = {}
Window.__index = Window

function Ecstasy:CreateWindow(opts)
	opts = opts or {}
	local theme = opts.Theme or {}
	for k, v in pairs(Theme) do if theme[k] == nil then theme[k] = v end end

	local win = setmetatable({
		Name = opts.Name or "ecstasy",
		SubTitle = opts.SubTitle or "",
		Size = opts.Size or UDim2.fromOffset(880, 600),
		Keybind = opts.Keybind or Ecstasy.Keybind,
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

	local glowHost = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = false,
		Parent = gui
	})
	win.GlowHost = glowHost

	for _, L in ipairs({ {110, 0.72}, {180, 0.82}, {260, 0.9} }) do
		create("ImageLabel", {
			Size = UDim2.new(1, L[1], 1, L[1]),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = GLOW,
			ImageColor3 = theme.Accent,
			ImageTransparency = L[2],
			ZIndex = 0,
			Parent = glowHost
		})
	end
	create("ImageLabel", {
		Size = UDim2.new(1, 60, 1, 60),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = SHADOW,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.48,
		ZIndex = 0,
		Parent = glowHost
	})

	local main = create("Frame", {
		Name = "Main",
		Size = win.Size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 0.04 + Ecstasy.GlassTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 2,
		Parent = gui
	})
	win.Main = main
	corner(main, UDim.new(0, 16))
	stroke(main, theme.Stroke, 0.82)
	Ecstasy:RegisterGlass(main, 0.04)

	local top = create("Frame", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.15 + Ecstasy.GlassTransparency * 0.4,
		BorderSizePixel = 0,
		Parent = main
	})
	corner(top, UDim.new(0, 16))
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.15 + Ecstasy.GlassTransparency * 0.4,
		BorderSizePixel = 0,
		Parent = top
	})
	Ecstasy:RegisterGlass(top, 0.12)

	create("TextLabel", {
		Size = UDim2.new(0, 240, 0, 24),
		Position = UDim2.fromOffset(24, 12),
		BackgroundTransparency = 1,
		Text = win.Name,
		TextColor3 = theme.Text,
		TextSize = 20,
		FontFace = FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top
	})
	create("Frame", {
		Size = UDim2.fromOffset(26, 2),
		Position = UDim2.fromOffset(24, 38),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = top
	})
	if win.SubTitle ~= "" then
		create("TextLabel", {
			Size = UDim2.new(1, -160, 0, 14),
			Position = UDim2.fromOffset(24, 42),
			BackgroundTransparency = 1,
			Text = win.SubTitle,
			TextColor3 = theme.Muted,
			TextSize = 11,
			FontFace = FontRegular,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = top
		})
	end

	local close = create("TextButton", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -50, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.Surface2,
		BackgroundTransparency = 0.25,
		Text = "×",
		TextColor3 = theme.Muted,
		TextSize = 20,
		FontFace = FontBold,
		AutoButtonColor = false,
		Parent = top
	})
	corner(close, UDim.new(0, 10))
	addHover(close)
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

	local side = create("Frame", {
		Size = UDim2.new(0, 210, 1, -62),
		Position = UDim2.fromOffset(0, 62),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.35,
		BorderSizePixel = 0,
		Parent = main
	})
	win.Sidebar = side
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = side
	})
	pad(side, 14, 14, 16, 16)
	Ecstasy:RegisterGlass(side, 0.18)

	local content = create("Frame", {
		Size = UDim2.new(1, -210, 1, -62),
		Position = UDim2.fromOffset(210, 62),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main
	})
	win.Content = content

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
		if inp.KeyCode == win.Keybind or inp.KeyCode == Ecstasy.Keybind then
			win:Toggle()
		end
	end))

	if win.Blur then
		local b = Instance.new("BlurEffect")
		b.Size = 0
		b.Parent = Lighting
		win.Maid:Inst(b)
		win._blur = b
		tween(b, { Size = 12 }, 0.45)
	end

	playLoading(gui, theme, function()
		main.Visible = true
		glowHost.Visible = true
		main.Size = UDim2.fromOffset(0, 0)
		main.BackgroundTransparency = 1
		tween(main, {
			Size = win.Size,
			BackgroundTransparency = math.clamp(0.04 + Ecstasy.GlassTransparency, 0, 0.85)
		}, 0.5, Enum.EasingStyle.Quint)
	end)

	table.insert(Ecstasy.Windows, win)
	return win
end

function Window:Toggle()
	self.Visible = not self.Visible
	local m = self.Main
	local g = self.GlowHost
	if self.Visible then
		m.Visible = true
		if g then g.Visible = true end
		tween(m, { BackgroundTransparency = math.clamp(0.04 + Ecstasy.GlassTransparency, 0, 0.85) }, 0.28)
		if self._blur then tween(self._blur, { Size = 12 }, 0.3) end
	else
		tween(m, { BackgroundTransparency = 1 }, 0.22)
		if self._blur then tween(self._blur, { Size = 0 }, 0.22) end
		task.delay(0.24, function()
			if not self.Visible then
				m.Visible = false
				if g then g.Visible = false end
			end
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

local Tab = {}
Tab.__index = Tab

function Window:CreateTab(opts)
	opts = opts or {}
	local name = opts.Name or "Tab"
	local tab = setmetatable({
		Name = name, Window = self, Sections = {}, Maid = Maid.new(), Active = false
	}, Tab)

	local btn = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = self.Theme.Surface2,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = self.Sidebar
	})
	corner(btn, UDim.new(0, 11))
	tab.Button = btn
	addHover(btn)

	local accent = create("Frame", {
		Size = UDim2.new(0, 3, 0, 22),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = btn
	})
	corner(accent, UDim.new(0, 2))
	tab.Accent = accent

	local label = create("TextLabel", {
		Size = UDim2.new(1, -32, 1, 0),
		Position = UDim2.fromOffset(22, 0),
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
	pad(page, 20, 20, 18, 20)

	local left = create("Frame", {
		Size = UDim2.new(0.5, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = page
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14), Parent = left })
	tab.Left = left

	local right = create("Frame", {
		Size = UDim2.new(0.5, -10, 0, 0),
		Position = UDim2.new(0.5, 10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = page
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14), Parent = right })
	tab.Right = right

	btn.MouseEnter:Connect(function()
		if not tab.Active then
			tween(btn, { BackgroundTransparency = 0.5 }, 0.15)
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
	tween(tab.Button, { BackgroundTransparency = 0.38 }, 0.22)
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
		BackgroundTransparency = 0.14 + Ecstasy.GlassTransparency * 0.4,
		BorderSizePixel = 0,
		Parent = parent
	})
	corner(frame, UDim.new(0, 14))
	stroke(frame, self.Window.Theme.Stroke, 0.88)
	pad(frame, 16, 16, 14, 16)
	sec.Frame = frame
	Ecstasy:RegisterGlass(frame, 0.12)

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
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = list })
	sec.List = list

	table.insert(self.Sections, sec)
	return sec
end

local function el(sec, h)
	local th = sec.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, h or 48),
		BackgroundColor3 = th.Surface2,
		BackgroundTransparency = 0.22 + Ecstasy.GlassTransparency * 0.3,
		BorderSizePixel = 0,
		Parent = sec.List
	})
	corner(c, UDim.new(0, 11))
	local s = stroke(c, th.Stroke, 0.9)
	addHover(c)
	Ecstasy:RegisterGlass(c, 0.2)

	c.MouseEnter:Connect(function()
		tween(s, { Transparency = 0.7 }, 0.15)
		tween(c, { BackgroundTransparency = 0.1 }, 0.15)
	end)
	c.MouseLeave:Connect(function()
		tween(s, { Transparency = 0.9 }, 0.2)
		tween(c, { BackgroundTransparency = 0.22 + Ecstasy.GlassTransparency * 0.3 }, 0.2)
	end)
	return c
end

function Section:CreateToggle(opts)
	opts = opts or {}
	local name, def, cb = opts.Name or "Toggle", opts.Default == true, opts.Callback
	local th = self.Theme
	local c = el(self, 48)

	create("TextLabel", {
		Size = UDim2.new(1, -72, 1, 0), Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local track = create("Frame", {
		Size = UDim2.fromOffset(46, 26), Position = UDim2.new(1, -62, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
		BorderSizePixel = 0, Parent = c
	})
	corner(track, UDim.new(1, 0))
	local knob = create("Frame", {
		Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = th.Muted, BorderSizePixel = 0, Parent = track
	})
	corner(knob, UDim.new(1, 0))

	local state = def
	local function set(v, fire)
		state = v
		if state then
			tween(track, { BackgroundColor3 = th.Accent }, 0.22)
			tween(knob, { Position = UDim2.fromOffset(23, 3), BackgroundColor3 = Color3.new(1, 1, 1) }, 0.22)
		else
			tween(track, { BackgroundColor3 = th.Surface3 }, 0.22)
			tween(knob, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = th.Muted }, 0.22)
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
	local c = el(self, 48)

	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = name,
		TextColor3 = th.Text, TextSize = 14, FontFace = FontMedium,
		AutoButtonColor = false, Parent = c
	})
	btn.MouseEnter:Connect(function() tween(btn, { TextColor3 = th.Accent }, 0.15) end)
	btn.MouseLeave:Connect(function() tween(btn, { TextColor3 = th.Text }, 0.2) end)
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		tween(c, { BackgroundTransparency = 0.05 }, 0.08)
		task.delay(0.1, function() tween(c, { BackgroundTransparency = 0.22 + Ecstasy.GlassTransparency * 0.3 }, 0.25) end)
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
	local c = el(self, 64)

	create("TextLabel", {
		Size = UDim2.new(1, -80, 0, 18), Position = UDim2.fromOffset(16, 10),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})
	local val = create("TextLabel", {
		Size = UDim2.new(0, 70, 0, 18), Position = UDim2.new(1, -80, 0, 10),
		BackgroundTransparency = 1, Text = "", TextColor3 = th.Accent,
		TextSize = 13, FontFace = FontMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = c
	})

	local bar = create("Frame", {
		Size = UDim2.new(1, -32, 0, 6), Position = UDim2.fromOffset(16, 42),
		BackgroundColor3 = th.Surface3, BorderSizePixel = 0, Parent = c
	})
	corner(bar, UDim.new(1, 0))
	local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = th.Accent, BorderSizePixel = 0, Parent = bar })
	corner(fill, UDim.new(1, 0))
	local knob = create("Frame", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = bar
	})
	corner(knob, UDim.new(1, 0))

	local value = def
	local function set(v, fire)
		v = math.clamp(v, min, max)
		if dec > 0 then local m = 10 ^ dec v = math.floor(v * m + 0.5) / m else v = math.floor(v + 0.5) end
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
	local c = el(self, 48)

	create("TextLabel", {
		Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local selected = def
	local disp = create("TextLabel", {
		Size = UDim2.new(0.5, -18, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
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
			Size = UDim2.new(1, 0, 0, math.min(#options * 34 + 12, 180)),
			Position = UDim2.new(0, 0, 1, 8),
			BackgroundColor3 = th.Surface,
			BackgroundTransparency = 0.06 + Ecstasy.GlassTransparency * 0.3,
			BorderSizePixel = 0, ZIndex = 80, Parent = c
		})
		corner(drop, UDim.new(0, 12))
		stroke(drop, th.Stroke, 0.85)
		local sc = create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, #options * 34), Parent = drop
		})
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = sc })
		pad(sc, 6, 6, 6, 6)
		for _, opt in ipairs(options) do
			local b = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = th.Surface2,
				BackgroundTransparency = 1, Text = "  " .. tostring(opt), TextColor3 = th.Text,
				TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false, Parent = sc
			})
			corner(b, UDim.new(0, 8))
			b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.45 }, 0.12) end)
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
	local c = el(self, 48)

	create("TextLabel", {
		Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local key, listening = def, false
	local kb = create("TextButton", {
		Size = UDim2.fromOffset(86, 30), Position = UDim2.new(1, -102, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
		BackgroundTransparency = 0.15, Text = key.Name, TextColor3 = th.Accent,
		TextSize = 12, FontFace = FontMedium, AutoButtonColor = false, Parent = c
	})
	corner(kb, UDim.new(0, 8))
	stroke(kb, th.Stroke, 0.88)

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
	local c = el(self, 48)

	create("TextLabel", {
		Size = UDim2.new(1, -62, 1, 0), Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local color = def
	local sw = create("TextButton", {
		Size = UDim2.fromOffset(36, 24), Position = UDim2.new(1, -52, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, Text = "",
		AutoButtonColor = false, Parent = c
	})
	corner(sw, UDim.new(0, 7))
	stroke(sw, th.Stroke, 0.72)

	local palette = {
		Color3.fromRGB(168, 85, 247), Color3.fromRGB(255, 70, 120),
		Color3.fromRGB(56, 189, 248), Color3.fromRGB(52, 211, 153),
		Color3.fromRGB(251, 191, 36), Color3.fromRGB(248, 113, 113),
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
	local c = el(self, 48)

	create("TextLabel", {
		Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 14, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local box = create("TextBox", {
		Size = UDim2.new(0.55, -12, 0, 30), Position = UDim2.new(0.42, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
		BackgroundTransparency = 0.15, Text = "", PlaceholderText = ph,
		PlaceholderColor3 = th.Muted, TextColor3 = th.Text, TextSize = 13,
		FontFace = FontRegular, ClearTextOnFocus = false, Parent = c
	})
	corner(box, UDim.new(0, 8))
	stroke(box, th.Stroke, 0.88)
	pad(box, 10, 10, 0, 0)

	box.FocusLost:Connect(function(enter)
		if enter or box.Text ~= "" then safe(cb, box.Text) end
	end)

	return { Set = function(_, t) box.Text = tostring(t) end, Get = function() return box.Text end }
end

function Window:CreateSettingsTab()
	local tab = self:CreateTab({ Name = "Settings" })
	local left = tab:CreateSection({ Name = "Interface", Side = "Left" })
	local right = tab:CreateSection({ Name = "Audio", Side = "Right" })

	left:CreateKeybind({
		Name = "Toggle UI",
		Default = Ecstasy.Keybind,
		Callback = function(key)
			Ecstasy.Keybind = key
			self.Keybind = key
			saveConfig()
		end
	})

	left:CreateSlider({
		Name = "Glass Transparency",
		Min = 0,
		Max = 0.6,
		Default = Ecstasy.GlassTransparency,
		Decimals = 2,
		Callback = function(v)
			Ecstasy.GlassTransparency = v
			Ecstasy:ApplyGlass()
			saveConfig()
		end
	})

	right:CreateToggle({
		Name = "Enable Sounds",
		Default = Ecstasy.SoundEnabled,
		Callback = function(v)
			Ecstasy.SoundEnabled = v
			saveConfig()
		end
	})

	right:CreateToggle({
		Name = "Click Sounds",
		Default = Ecstasy.ClickSounds,
		Callback = function(v)
			Ecstasy.ClickSounds = v
			saveConfig()
		end
	})

	right:CreateToggle({
		Name = "Notification Sounds",
		Default = Ecstasy.NotifySounds,
		Callback = function(v)
			Ecstasy.NotifySounds = v
			saveConfig()
		end
	})

	right:CreateSlider({
		Name = "Volume",
		Min = 0,
		Max = 1,
		Default = Ecstasy.SoundVolume,
		Decimals = 2,
		Callback = function(v)
			Ecstasy.SoundVolume = v
			saveConfig()
		end
	})

	return tab
end

function Window:CreatePremadeTab(opts)
	opts = opts or {}
	local tab = self:CreateTab({ Name = opts.Name or "Demo" })
	local L = tab:CreateSection({ Name = "Controls", Side = "Left" })
	local R = tab:CreateSection({ Name = "Extra", Side = "Right" })

	L:CreateToggle({ Name = "Feature", Default = false, Callback = print })
	L:CreateSlider({ Name = "Value", Min = 0, Max = 100, Default = 50, Callback = print })
	L:CreateButton({ Name = "Action", Callback = function()
		Ecstasy:Notify({ Title = "Done", Content = "Action completed.", Duration = 3 })
	end })
	L:CreateDropdown({ Name = "Mode", Options = { "Normal", "Fast", "Silent" }, Default = "Normal", Callback = print })

	R:CreateKeybind({ Name = "Key", Default = Enum.KeyCode.E, Callback = function(k) print(k.Name) end })
	R:CreateColorPicker({ Name = "Color", Default = Theme.Accent, Callback = print })
	R:CreateTextBox({ Name = "Name", Placeholder = "Type...", Callback = print })
	R:CreateButton({ Name = "Notify", Callback = function()
		Ecstasy:Notify({ Title = "ecstasy", Content = "Looking clean.", Duration = 3 })
	end })

	return tab
end

function Ecstasy:Destroy()
	for _, w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
	table.clear(self.Windows)
	self.Maid:Clean()
	if SoundFolder then SoundFolder:Destroy() end
	if NGui then NGui:Destroy() end
end

return Ecstasy
