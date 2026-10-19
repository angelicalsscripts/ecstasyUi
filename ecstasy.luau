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
		if win.TopBar and win.TopBar.Parent then
			win.TopBar.BackgroundTransparency = math.clamp(0.12 + g * 0.4, 0, 0.9)
		end
		if win.Sidebar and win.Sidebar.Parent then
			win.Sidebar.BackgroundTransparency = math.clamp(0.18 + g * 0.35, 0, 0.9)
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
		Size = UDim2.new(0, 300, 1, -44),
		BackgroundTransparency = 1,
		Parent = NGui
	})
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 10),
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

	local wrapper = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = NHolder
	})

	local card = create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Parent = wrapper
	})
	corner(card, UDim.new(0, 14))
	stroke(card, Theme.Stroke, 0.94, 1)

	local inner = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card
	})
	pad(inner, 16, 16, 14, 16)

	create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = inner
	})

	local textCol = create("Frame", {
		Size = UDim2.new(1, -14, 0, 0),
		Position = UDim2.fromOffset(14, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = inner
	})
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = textCol
	})

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 13,
		FontFace = FontSemi,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = textCol
	})

	if content ~= "" then
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = content,
			TextColor3 = Theme.Muted,
			TextSize = 12,
			FontFace = FontRegular,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = textCol
		})
	end

	local progTrack = create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(35, 35, 48),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = card
	})
	local prog = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = progTrack
	})

	local scale = create("UIScale", { Scale = 0.92, Parent = card })
	wrapper.Position = UDim2.new(1, 30, 0, 0)
	card.GroupTransparency = 1

	tween(wrapper, { Position = UDim2.new(0, 0, 0, 0) }, 0.38, Enum.EasingStyle.Quint)
	tween(card, { GroupTransparency = 0 }, 0.35, Enum.EasingStyle.Quint)
	tween(scale, { Scale = 1 }, 0.38, Enum.EasingStyle.Quint)
	tween(prog, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if not wrapper.Parent then return end
		tween(wrapper, { Position = UDim2.new(1, 40, 0, 0) }, 0.28, Enum.EasingStyle.Quint)
		tween(card, { GroupTransparency = 1 }, 0.26)
		tween(scale, { Scale = 0.94 }, 0.26)
		task.wait(0.3)
		if wrapper.Parent then wrapper:Destroy() end
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
		Size = UDim2.fromOffset(340, 260),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = ov
	})
	local scaleObj = create("UIScale", { Scale = 1, Parent = center })

	local loadingLabel = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0.5, 0, 0.5, -20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "Loading",
		TextColor3 = theme.Text,
		TextSize = 22,
		FontFace = FontSemi,
		TextTransparency = 1,
		Parent = center
	})

	local dots = create("TextLabel", {
		Size = UDim2.new(0, 40, 0, 28),
		Position = UDim2.new(0.5, 55, 0.5, -20),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.Accent,
		TextSize = 22,
		FontFace = FontSemi,
		TextTransparency = 1,
		Parent = center
	})

	tween(loadingLabel, { TextTransparency = 0 }, 0.4)
	tween(dots, { TextTransparency = 0 }, 0.4)

	local dotPatterns = { ".", "..", "..." }
	local dotIdx = 0
	local running = true
	task.spawn(function()
		while running do
			dotIdx = (dotIdx % 3) + 1
			dots.Text = dotPatterns[dotIdx]
			task.wait(0.35)
		end
	end)

	task.wait(1.4)
	running = false
	tween(loadingLabel, { TextTransparency = 1 }, 0.3)
	tween(dots, { TextTransparency = 1 }, 0.3)
	task.wait(0.35)

	local avatar = create("ImageLabel", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.new(0.5, 0, 0.5, -40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Surface2,
		BackgroundTransparency = 0.2,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		Parent = center
	})
	corner(avatar, UDim.new(1, 0))
	stroke(avatar, theme.Accent, 0.4, 2)

	pcall(function()
		local content, ready = Players:GetUserThumbnailAsync(
			LocalPlayer.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if ready then avatar.Image = content end
	end)

	local welcome = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0.5, 0, 0.5, 30),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "Welcome, " .. (LocalPlayer.DisplayName or LocalPlayer.Name),
		TextColor3 = theme.Text,
		TextSize = 18,
		FontFace = FontSemi,
		TextTransparency = 1,
		Parent = center
	})

	local sub = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0.5, 0, 0.5, 52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "ecstasy",
		TextColor3 = theme.Accent,
		TextSize = 13,
		FontFace = FontMedium,
		TextTransparency = 1,
		Parent = center
	})

	tween(avatar, { Size = UDim2.fromOffset(72, 72) }, 0.45, Enum.EasingStyle.Back)
	tween(welcome, { TextTransparency = 0 }, 0.4)
	tween(sub, { TextTransparency = 0 }, 0.45)
	task.wait(1.1)

	tween(scaleObj, { Scale = 1.12 }, 0.35, Enum.EasingStyle.Quint)
	tween(avatar, { ImageTransparency = 1, BackgroundTransparency = 1 }, 0.3)
	tween(welcome, { TextTransparency = 1 }, 0.3)
	tween(sub, { TextTransparency = 1 }, 0.3)
	tween(ov, { BackgroundTransparency = 1 }, 0.4)
	task.wait(0.42)
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
		TabMap = {},
		Maid = Maid.new(),
		Visible = true,
		_toggling = false,
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

	local mainShell = create("Frame", {
		Name = "MainShell",
		Size = win.Size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = gui
	})
	local mainScale = create("UIScale", { Scale = 1, Parent = mainShell })
	win._mainScale = mainScale

	local main = create("CanvasGroup", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 0.04 + Ecstasy.GlassTransparency,
		BorderSizePixel = 0,
		Parent = mainShell
	})
	win.Main = main
	win.MainShell = mainShell
	corner(main, UDim.new(0, 16))
	stroke(main, theme.Stroke, 0.82)
	Ecstasy:RegisterGlass(main, 0.04)

	local top = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.12 + Ecstasy.GlassTransparency * 0.4,
		BorderSizePixel = 0,
		Parent = main
	})
	win.TopBar = top
	Ecstasy:RegisterGlass(top, 0.12)

	create("TextLabel", {
		Size = UDim2.new(0, 240, 0, 22),
		Position = UDim2.fromOffset(22, 10),
		BackgroundTransparency = 1,
		Text = win.Name,
		TextColor3 = theme.Text,
		TextSize = 18,
		FontFace = FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top
	})
	create("Frame", {
		Size = UDim2.fromOffset(24, 2),
		Position = UDim2.fromOffset(22, 34),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = top
	})
	if win.SubTitle ~= "" then
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
	end

	local close = create("TextButton", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -46, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = theme.Surface2,
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Parent = top
	})
	corner(close, UDim.new(1, 0))
	stroke(close, theme.Stroke, 0.85)
	local closeIcon = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "✕",
		TextColor3 = theme.Muted,
		TextSize = 12,
		FontFace = FontBold,
		Parent = close
	})
	addHover(close)
	close.MouseEnter:Connect(function()
		tween(close, { BackgroundColor3 = theme.Error, BackgroundTransparency = 0.15 }, 0.15)
		tween(closeIcon, { TextColor3 = Color3.new(1, 1, 1) }, 0.15)
	end)
	close.MouseLeave:Connect(function()
		tween(close, { BackgroundColor3 = theme.Surface2, BackgroundTransparency = 0.35 }, 0.2)
		tween(closeIcon, { TextColor3 = theme.Muted }, 0.2)
	end)
	close.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		win:Destroy()
	end)

	local side = create("Frame", {
		Size = UDim2.new(0, 200, 1, -58),
		Position = UDim2.fromOffset(0, 58),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.18 + Ecstasy.GlassTransparency * 0.35,
		BorderSizePixel = 0,
		Parent = main
	})
	win.Sidebar = side
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		Parent = side
	})
	pad(side, 12, 12, 14, 14)
	Ecstasy:RegisterGlass(side, 0.18)

	local content = create("Frame", {
		Size = UDim2.new(1, -200, 1, -58),
		Position = UDim2.fromOffset(200, 58),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main
	})
	win.Content = content

	local dragging, dragStart, startPos, targetPos, currentPos =
		false, Vector2.zero, mainShell.Position, mainShell.Position, mainShell.Position

	win.Maid:Conn(top.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
			startPos = mainShell.Position
			currentPos = mainShell.Position
			targetPos = mainShell.Position
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
		if not mainShell.Parent then return end
		local a = math.clamp(dt * 18, 0, 1)
		local x = currentPos.X.Offset + (targetPos.X.Offset - currentPos.X.Offset) * a
		local y = currentPos.Y.Offset + (targetPos.Y.Offset - currentPos.Y.Offset) * a
		currentPos = UDim2.new(targetPos.X.Scale, x, targetPos.Y.Scale, y)
		mainShell.Position = currentPos
		glowHost.Position = currentPos
		glowHost.Size = mainShell.Size
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
	end

	playLoading(gui, theme, function()
		mainShell.Visible = true
		glowHost.Visible = true
		mainScale.Scale = 0.92
		main.BackgroundTransparency = 1
		tween(mainScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Quint)
		tween(main, {
			BackgroundTransparency = math.clamp(0.04 + Ecstasy.GlassTransparency, 0, 0.85)
		}, 0.4, Enum.EasingStyle.Quint)
		if win._blur then tween(win._blur, { Size = 12 }, 0.4) end
	end)

	table.insert(Ecstasy.Windows, win)
	return win
end

function Window:Toggle()
	if self._toggling then return end
	self._toggling = true
	self.Visible = not self.Visible
	local m = self.Main
	local shell = self.MainShell
	local g = self.GlowHost
	local s = self._mainScale

	if self.Visible then
		if shell then shell.Visible = true end
		if g then g.Visible = true end
		s.Scale = 0.94
		m.BackgroundTransparency = 1
		tween(s, { Scale = 1 }, 0.32, Enum.EasingStyle.Quint)
		tween(m, { BackgroundTransparency = math.clamp(0.04 + Ecstasy.GlassTransparency, 0, 0.85) }, 0.32)
		if self._blur then tween(self._blur, { Size = 12 }, 0.3) end
		task.delay(0.35, function() self._toggling = false end)
	else
		tween(s, { Scale = 0.94 }, 0.28, Enum.EasingStyle.Quint)
		tween(m, { BackgroundTransparency = 1 }, 0.28)
		if self._blur then tween(self._blur, { Size = 0 }, 0.25) end
		task.delay(0.3, function()
			if not self.Visible then
				if shell then shell.Visible = false end
				if g then g.Visible = false end
			end
			self._toggling = false
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
	local icon = opts.Icon
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
	addHover(btn)

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

	local iconOffset = 20
	if icon then
		local img = create("ImageLabel", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 18, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = icon,
			ImageColor3 = self.Theme.Muted,
			Parent = btn
		})
		tab.Icon = img
		iconOffset = 40
	end

	local label = create("TextLabel", {
		Size = UDim2.new(1, -iconOffset - 8, 1, 0),
		Position = UDim2.fromOffset(iconOffset, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = self.Theme.Muted,
		TextSize = 13,
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
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12), Parent = left })
	tab.Left = left

	local right = create("Frame", {
		Size = UDim2.new(0.5, -9, 0, 0),
		Position = UDim2.new(0.5, 9, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = page
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12), Parent = right })
	tab.Right = right

	btn.MouseEnter:Connect(function()
		if not tab.Active then
			tween(btn, { BackgroundTransparency = 0.5 }, 0.15)
			tween(label, { TextColor3 = self.Theme.Text }, 0.15)
			if tab.Icon then tween(tab.Icon, { ImageColor3 = self.Theme.Text }, 0.15) end
		end
	end)
	btn.MouseLeave:Connect(function()
		if not tab.Active then
			tween(btn, { BackgroundTransparency = 1 }, 0.2)
			tween(label, { TextColor3 = self.Theme.Muted }, 0.2)
			if tab.Icon then tween(tab.Icon, { ImageColor3 = self.Theme.Muted }, 0.2) end
		end
	end)
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		self:SelectTab(tab)
	end)

	table.insert(self.Tabs, tab)
	self.TabMap[name] = tab
	if #self.Tabs == 1 then self:SelectTab(tab) end
	return tab
end

function Window:SelectTab(tabOrName)
	local tab = type(tabOrName) == "string" and self.TabMap[tabOrName] or tabOrName
	if not tab then return end
	for _, t in ipairs(self.Tabs) do
		t.Active = false
		t.Page.Visible = false
		tween(t.Button, { BackgroundTransparency = 1 }, 0.2)
		tween(t.Label, { TextColor3 = self.Theme.Muted }, 0.2)
		tween(t.Accent, { BackgroundTransparency = 1 }, 0.2)
		if t.Icon then tween(t.Icon, { ImageColor3 = self.Theme.Muted }, 0.2) end
	end
	tab.Active = true
	tab.Page.Visible = true
	tween(tab.Button, { BackgroundTransparency = 0.38 }, 0.22)
	tween(tab.Label, { TextColor3 = self.Theme.Text }, 0.22)
	tween(tab.Accent, { BackgroundTransparency = 0 }, 0.22)
	if tab.Icon then tween(tab.Icon, { ImageColor3 = self.Theme.Accent }, 0.22) end
end

function Window:GetTab(name)
	return self.TabMap[name]
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
		BackgroundTransparency = 0.12 + Ecstasy.GlassTransparency * 0.4,
		BorderSizePixel = 0,
		Parent = parent
	})
	corner(frame, UDim.new(0, 12))
	stroke(frame, self.Window.Theme.Stroke, 0.9)
	pad(frame, 14, 14, 12, 14)
	sec.Frame = frame
	Ecstasy:RegisterGlass(frame, 0.12)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
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
		Position = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = frame
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = list })
	sec.List = list

	table.insert(self.Sections, sec)
	return sec
end

local function el(sec, h)
	local th = sec.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, h or 46),
		BackgroundColor3 = th.Surface2,
		BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3,
		BorderSizePixel = 0,
		Parent = sec.List
	})
	corner(c, UDim.new(0, 10))
	local s = stroke(c, th.Stroke, 0.92)
	addHover(c)
	Ecstasy:RegisterGlass(c, 0.2)

	c.MouseEnter:Connect(function()
		tween(s, { Transparency = 0.72 }, 0.15)
		tween(c, { BackgroundTransparency = 0.08 }, 0.15)
	end)
	c.MouseLeave:Connect(function()
		tween(s, { Transparency = 0.92 }, 0.2)
		tween(c, { BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3 }, 0.2)
	end)
	return c
end

function Section:CreateToggle(opts)
	opts = opts or {}
	local name, def, cb = opts.Name or "Toggle", opts.Default == true, opts.Callback
	local th = self.Theme
	local c = el(self, 46)

	create("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local track = create("Frame", {
		Size = UDim2.fromOffset(44, 24), Position = UDim2.new(1, -58, 0.5, 0),
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
			tween(knob, { Position = UDim2.fromOffset(23, 3), BackgroundColor3 = Color3.new(1, 1, 1) }, 0.2)
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
	local c = el(self, 46)

	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = name,
		TextColor3 = th.Text, TextSize = 13, FontFace = FontMedium,
		AutoButtonColor = false, Parent = c
	})
	btn.MouseEnter:Connect(function() tween(btn, { TextColor3 = th.Accent }, 0.15) end)
	btn.MouseLeave:Connect(function() tween(btn, { TextColor3 = th.Text }, 0.2) end)
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		tween(c, { BackgroundTransparency = 0.05 }, 0.08)
		task.delay(0.1, function() tween(c, { BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3 }, 0.25) end)
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
	local c = el(self, 60)

	create("TextLabel", {
		Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(14, 8),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})
	local val = create("TextLabel", {
		Size = UDim2.new(0, 60, 0, 16), Position = UDim2.new(1, -70, 0, 8),
		BackgroundTransparency = 1, Text = "", TextColor3 = th.Accent,
		TextSize = 12, FontFace = FontMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = c
	})

	local bar = create("Frame", {
		Size = UDim2.new(1, -28, 0, 5), Position = UDim2.fromOffset(14, 38),
		BackgroundColor3 = th.Surface3, BorderSizePixel = 0, Parent = c
	})
	corner(bar, UDim.new(1, 0))
	local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = th.Accent, BorderSizePixel = 0, Parent = bar })
	corner(fill, UDim.new(1, 0))
	local knob = create("Frame", {
		Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
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
	local c = el(self, 46)

	create("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local selected = def
	local chip = create("Frame", {
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = th.Surface3,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = c
	})
	corner(chip, UDim.new(0, 8))
	stroke(chip, th.Stroke, 0.9)
	pad(chip, 10, 10, 0, 0)
	local disp = create("TextLabel", {
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = tostring(selected),
		TextColor3 = th.Accent,
		TextSize = 12,
		FontFace = FontMedium,
		Parent = chip
	})

	local open, drop, dropScale = false, nil, nil
	local function close()
		if not drop then return end
		local d, s = drop, dropScale
		drop, dropScale, open = nil, nil, false
		if s then tween(s, { Scale = 0.94 }, 0.15) end
		tween(d, { GroupTransparency = 1 }, 0.15)
		task.delay(0.16, function() if d and d.Parent then d:Destroy() end end)
	end

	create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c
	}).MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		if open then close() return end
		open = true
		local h = math.min(#options * 34 + 12, 180)
		drop = create("CanvasGroup", {
			Size = UDim2.new(1, 0, 0, h),
			Position = UDim2.new(0, 0, 1, 8),
			BackgroundColor3 = th.Surface,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			ZIndex = 100,
			Parent = c
		})
		corner(drop, UDim.new(0, 12))
		stroke(drop, th.Stroke, 0.9)
		dropScale = create("UIScale", { Scale = 0.94, Parent = drop })

		local sc = create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = th.Accent,
			CanvasSize = UDim2.new(0, 0, 0, #options * 34),
			Parent = drop
		})
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = sc })
		pad(sc, 6, 6, 6, 6)

		for _, opt in ipairs(options) do
			local isSel = tostring(opt) == tostring(selected)
			local b = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = th.Surface2,
				BackgroundTransparency = isSel and 0.55 or 1,
				Text = "",
				AutoButtonColor = false,
				Parent = sc
			})
			corner(b, UDim.new(0, 8))
			local t = create("TextLabel", {
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				BackgroundTransparency = 1,
				Text = tostring(opt),
				TextColor3 = isSel and th.Accent or th.Text,
				TextSize = 12,
				FontFace = isSel and FontMedium or FontRegular,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = b
			})
			b.MouseEnter:Connect(function()
				tween(b, { BackgroundTransparency = 0.5 }, 0.12)
				tween(t, { TextColor3 = th.Accent }, 0.12)
			end)
			b.MouseLeave:Connect(function()
				local sel = tostring(opt) == tostring(selected)
				tween(b, { BackgroundTransparency = sel and 0.55 or 1 }, 0.15)
				tween(t, { TextColor3 = sel and th.Accent or th.Text }, 0.15)
			end)
			b.MouseButton1Click:Connect(function()
				selected = opt
				disp.Text = tostring(opt)
				safe(cb, opt)
				close()
			end)
		end

		tween(drop, { GroupTransparency = 0 }, 0.2, Enum.EasingStyle.Quint)
		tween(dropScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Quint)
	end)

	return { Set = function(_, v) selected = v disp.Text = tostring(v) end, Get = function() return selected end }
end

function Section:CreateKeybind(opts)
	opts = opts or {}
	local name, def, cb = opts.Name or "Keybind", opts.Default or Enum.KeyCode.E, opts.Callback
	local th = self.Theme
	local c = el(self, 46)

	create("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local key, listening = def, false
	local kb = create("TextButton", {
		Size = UDim2.fromOffset(80, 28), Position = UDim2.new(1, -94, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
		BackgroundTransparency = 0.2, Text = key.Name, TextColor3 = th.Accent,
		TextSize = 11, FontFace = FontMedium, AutoButtonColor = false, Parent = c
	})
	corner(kb, UDim.new(0, 7))
	stroke(kb, th.Stroke, 0.9)

	kb.MouseButton1Click:Connect(function()
		listening = true
		kb.Text = "..."
		tween(kb, { BackgroundColor3 = th.Accent, TextColor3 = Color3.new(1, 1, 1) }, 0.15)
	end)

	self.Maid:Conn(UserInputService.InputBegan:Connect(function(inp)
		if not listening then return end
		if inp.UserInputType == Enum.UserInputType.Keyboard then
			key = inp.KeyCode
			kb.Text = key.Name
			listening = false
			tween(kb, { BackgroundColor3 = th.Surface3, TextColor3 = th.Accent }, 0.2)
			safe(cb, key)
		end
	end))

	return { Set = function(_, k) key = k kb.Text = k.Name end, Get = function() return key end }
end

function Section:CreateColorPicker(opts)
	opts = opts or {}
	local name, def, cb = opts.Name or "Color", opts.Default or Theme.Accent, opts.Callback
	local th = self.Theme
	local c = el(self, 46)

	create("TextLabel", {
		Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local color = def
	local sw = create("TextButton", {
		Size = UDim2.fromOffset(32, 22), Position = UDim2.new(1, -46, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, Text = "",
		AutoButtonColor = false, Parent = c
	})
	corner(sw, UDim.new(0, 6))
	stroke(sw, th.Stroke, 0.75)

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
	local c = el(self, 46)

	create("TextLabel", {
		Size = UDim2.new(0.36, 0, 1, 0), Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})

	local box = create("TextBox", {
		Size = UDim2.new(0.56, -10, 0, 28), Position = UDim2.new(0.4, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = th.Surface3,
		BackgroundTransparency = 0.2, Text = "", PlaceholderText = ph,
		PlaceholderColor3 = th.Muted, TextColor3 = th.Text, TextSize = 12,
		FontFace = FontRegular, ClearTextOnFocus = false, Parent = c
	})
	corner(box, UDim.new(0, 7))
	stroke(box, th.Stroke, 0.9)
	pad(box, 8, 8, 0, 0)

	box.FocusLost:Connect(function(enter)
		if enter or box.Text ~= "" then safe(cb, box.Text) end
	end)

	return { Set = function(_, t) box.Text = tostring(t) end, Get = function() return box.Text end }
end

function Section:CreateLabel(opts)
	opts = opts or {}
	local text = opts.Text or opts.Name or "Label"
	local th = self.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.List
	})
	local l = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = th.Muted,
		TextSize = 12,
		FontFace = FontRegular,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = c
	})
	return { Set = function(_, t) l.Text = tostring(t) end }
end

function Section:CreateParagraph(opts)
	return self:CreateLabel(opts)
end

function Section:CreateImage(opts)
	opts = opts or {}
	local image = opts.Image or opts.Icon or ""
	local h = opts.Height or 100
	local th = self.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = th.Surface2,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = self.List
	})
	corner(c, UDim.new(0, 10))
	stroke(c, th.Stroke, 0.92)
	local img = create("ImageLabel", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		Parent = c
	})
	corner(img, UDim.new(0, 8))
	return {
		Set = function(_, id) img.Image = tostring(id) end,
		Get = function() return img.Image end
	}
end

function Section:CreateDivider(opts)
	local th = self.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Parent = self.List
	})
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = th.Stroke,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Parent = c
	})
	return {}
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
	L:CreateDivider()
	L:CreateLabel({ Text = "Use Settings tab for UI options." })

	R:CreateKeybind({ Name = "Key", Default = Enum.KeyCode.E, Callback = function(k) print(k.Name) end })
	R:CreateColorPicker({ Name = "Color", Default = Theme.Accent, Callback = print })
	R:CreateTextBox({ Name = "Name", Placeholder = "Type...", Callback = print })
	R:CreateImage({ Image = "rbxassetid://6031094678", Height = 80 })
	R:CreateButton({ Name = "Notify", Callback = function()
		Ecstasy:Notify({ Title = "ecstasy", Content = "Looking clean.", Duration = 3 })
	end })
	R:CreateButton({ Name = "Open Settings", Callback = function()
		self:SelectTab("Settings")
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
