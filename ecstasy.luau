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

local ACCENT_PRESETS = {
	Purple = Color3.fromRGB(168, 85, 247),
	Red = Color3.fromRGB(255, 55, 55),
	White = Color3.fromRGB(255, 255, 255),
}

local function colorClose(a, b)
	if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then return false end
	return math.abs(a.R - b.R) < 0.04 and math.abs(a.G - b.G) < 0.04 and math.abs(a.B - b.B) < 0.04
end

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

local ClickSnd = mkSound("rbxassetid://6895079853", 0.35)
ClickSnd.PlaybackSpeed = 1.2
local NotifySnd = mkSound("rbxassetid://4590662766", 0.28)
NotifySnd.PlaybackSpeed = 1.05
local OpenSnd = mkSound("rbxassetid://9117422732", 0.22)
OpenSnd.PlaybackSpeed = 1.25
local CloseSnd = mkSound("rbxassetid://9117422732", 0.18)
CloseSnd.PlaybackSpeed = 0.85
local TabSnd = mkSound("rbxassetid://6895079853", 0.28)
TabSnd.PlaybackSpeed = 1.4
local SliderSnd = mkSound("rbxassetid://6895079853", 0.2)
SliderSnd.PlaybackSpeed = 1.5

local Ecstasy = {
	Windows = {},
	Maid = Maid.new(),
	SoundEnabled = true,
	ClickSounds = true,
	NotifySounds = true,
	SoundVolume = 0.22,
	GlassTransparency = 0.12,
	Keybind = Enum.KeyCode.RightControl,
	AccentName = "Purple",
	_glassObjects = {},
	_accentObjects = {},
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
		AccentName = Ecstasy.AccentName or "Purple",
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
	if data.AccentName and ACCENT_PRESETS[data.AccentName] then
		Ecstasy.AccentName = data.AccentName
		Theme.Accent = ACCENT_PRESETS[data.AccentName]
	end
end

loadConfig()

function Ecstasy:PlayClick()
	if self.SoundEnabled and self.ClickSounds then
		ClickSnd.Volume = math.clamp(self.SoundVolume, 0, 1)
		ClickSnd.TimePosition = 0
		ClickSnd:Play()
	end
end

function Ecstasy:PlayNotify()
	if self.SoundEnabled and self.NotifySounds then
		NotifySnd.Volume = math.clamp(self.SoundVolume * 0.9, 0, 1)
		NotifySnd.TimePosition = 0
		NotifySnd:Play()
	end
end

function Ecstasy:PlayOpen()
	if self.SoundEnabled and self.ClickSounds then
		OpenSnd.Volume = math.clamp(self.SoundVolume * 0.7, 0, 1)
		OpenSnd.TimePosition = 0
		OpenSnd:Play()
	end
end

function Ecstasy:PlayClose()
	if self.SoundEnabled and self.ClickSounds then
		CloseSnd.Volume = math.clamp(self.SoundVolume * 0.55, 0, 1)
		CloseSnd.TimePosition = 0
		CloseSnd:Play()
	end
end

function Ecstasy:PlayTab()
	if self.SoundEnabled and self.ClickSounds then
		TabSnd.Volume = math.clamp(self.SoundVolume * 0.75, 0, 1)
		TabSnd.TimePosition = 0
		TabSnd:Play()
	end
end

function Ecstasy:PlaySlider()
	if self.SoundEnabled and self.ClickSounds then
		SliderSnd.Volume = math.clamp(self.SoundVolume * 0.45, 0, 1)
		SliderSnd.TimePosition = 0
		SliderSnd:Play()
	end
end

function Ecstasy:RegisterAccent(obj, prop)
	if not obj then return end
	prop = prop or "BackgroundColor3"
	pcall(function()
		obj:SetAttribute("EcstasyAccent", true)
		obj:SetAttribute("EcstasyAccentProp", prop)
		obj[prop] = Theme.Accent
	end)
	table.insert(self._accentObjects, { obj = obj, prop = prop })
end

function Ecstasy:TagAccent(obj, prop)
	self:RegisterAccent(obj, prop)
end

local function applyAccentToTree(root, col)
	if not root then return end
	local list = { root }
	pcall(function()
		for _, d in ipairs(root:GetDescendants()) do
			table.insert(list, d)
		end
	end)
	for _, d in ipairs(list) do
		if d:GetAttribute("EcstasyAccent") then
			local prop = d:GetAttribute("EcstasyAccentProp") or "BackgroundColor3"
			pcall(function() d[prop] = col end)
		end
	end
end

function Ecstasy:SetAccent(name)
	local col = ACCENT_PRESETS[name]
	if not col then return end
	local old = Theme.Accent
	self.AccentName = name
	Theme.Accent = col

	local function recolorRoot(root)
		if not root then return end
		local nodes = { root }
		pcall(function()
			for _, d in ipairs(root:GetDescendants()) do
				table.insert(nodes, d)
			end
		end)
		for _, d in ipairs(nodes) do
			if d:GetAttribute("EcstasyAccent") then
				local prop = d:GetAttribute("EcstasyAccentProp") or "BackgroundColor3"
				pcall(function() d[prop] = col end)
			else
				pcall(function()
					if d:IsA("GuiObject") then
						if colorClose(d.BackgroundColor3, old) then
							d.BackgroundColor3 = col
						end
						if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
							if colorClose(d.TextColor3, old) then
								d.TextColor3 = col
							end
						end
						if d:IsA("ImageLabel") or d:IsA("ImageButton") then
							if colorClose(d.ImageColor3, old) then
								d.ImageColor3 = col
							end
						end
						if d:IsA("ScrollingFrame") then
							if colorClose(d.ScrollBarImageColor3, old) then
								d.ScrollBarImageColor3 = col
							end
						end
					elseif d:IsA("UIStroke") then
						if colorClose(d.Color, old) then
							d.Color = col
						end
					elseif d:IsA("UIGradient") then
						local seq = d.Color.Keypoints
						local changed = false
						local keys = {}
						for _, kp in ipairs(seq) do
							local c = kp.Value
							if colorClose(c, old) then
								c = col
								changed = true
							end
							table.insert(keys, ColorSequenceKeypoint.new(kp.Time, c))
						end
						if changed then
							d.Color = ColorSequence.new(keys)
						end
					end
				end)
			end
		end
	end

	for _, win in ipairs(self.Windows) do
		if win.Theme then win.Theme.Accent = col end
		if win._glowLayers then
			for _, g in ipairs(win._glowLayers) do
				if g and g.Parent then g.ImageColor3 = col end
			end
		end
		if win._titleLine and win._titleLine.Parent then
			win._titleLine.BackgroundColor3 = col
		end
		recolorRoot(win.Gui)
		recolorRoot(win.GlowHost)
		recolorRoot(win.MainShell)
	end
	recolorRoot(NGui)
	for _, entry in ipairs(self._accentObjects) do
		if entry.obj and entry.obj.Parent and not entry.locked then
			pcall(function() entry.obj[entry.prop] = col end)
		end
	end
	saveConfig()
end

function Ecstasy:ResolveColor(opts, fallback)
	opts = opts or {}
	if opts.Color then
		if typeof(opts.Color) == "Color3" then return opts.Color, true end
		if type(opts.Color) == "string" and ACCENT_PRESETS[opts.Color] then
			return ACCENT_PRESETS[opts.Color], true
		end
	end
	return fallback or Theme.Accent, false
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
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Theme.Accent),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.85),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.7, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine
	})
	local scale = create("UIScale", { Scale = 1, Parent = scaleTarget or frame })
	local hovering = false
	frame.MouseEnter:Connect(function()
		hovering = true
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Theme.Accent),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		})
		tween(shine, { BackgroundTransparency = 0.62 }, 0.16)
		tween(scale, { Scale = 1.045 }, 0.18, Enum.EasingStyle.Quint)
	end)
	frame.MouseLeave:Connect(function()
		hovering = false
		tween(shine, { BackgroundTransparency = 1 }, 0.2)
		tween(scale, { Scale = 1 }, 0.2, Enum.EasingStyle.Quint)
	end)
	frame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = 0.94 }, 0.06, Enum.EasingStyle.Quad)
		end
	end)
	frame.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = hovering and 1.045 or 1 }, 0.16, Enum.EasingStyle.Back)
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
		grad.Offset = Vector2.new((rx - 0.5) * 1.7, (ry - 0.5) * 1.7)
		grad.Rotation = (rx - 0.5) * 55
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
	local closed = false

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
		BackgroundTransparency = 0.06 + Ecstasy.GlassTransparency * 0.25,
		BorderSizePixel = 0,
		Parent = wrapper
	})
	corner(card, UDim.new(0, 14))
	stroke(card, Theme.Stroke, 0.92, 1)

	local glow = create("ImageLabel", {
		Size = UDim2.new(1, 50, 1, 50),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = GLOW,
		ImageColor3 = Theme.Accent,
		ImageTransparency = 0.86,
		ZIndex = 0,
		Parent = card
	})
	Ecstasy:RegisterAccent(glow, "ImageColor3")

	local inner = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card
	})
	pad(inner, 16, 16, 14, 16)

	local accent = create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = inner
	})
	corner(accent, UDim.new(0, 2))
	Ecstasy:RegisterAccent(accent)

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
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = card
	})
	local prog = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = progTrack
	})
	Ecstasy:RegisterAccent(prog)

	local scale = create("UIScale", { Scale = 0.88, Parent = card })
	wrapper.Position = UDim2.new(1, 40, 0, 0)
	card.GroupTransparency = 1

	local function dismiss()
		if closed or not wrapper.Parent then return end
		closed = true
		tween(wrapper, { Position = UDim2.new(1, 48, 0, 0) }, 0.22, Enum.EasingStyle.Quint)
		tween(card, { GroupTransparency = 1 }, 0.2)
		tween(scale, { Scale = 0.9 }, 0.2)
		task.delay(0.24, function() if wrapper.Parent then wrapper:Destroy() end end)
	end

	local hit = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = card
	})
	hit.MouseEnter:Connect(function()
		if closed then return end
		tween(scale, { Scale = 1.04 }, 0.16, Enum.EasingStyle.Quint)
		tween(card, { BackgroundTransparency = 0.02 }, 0.16)
		tween(glow, { ImageTransparency = 0.78 }, 0.16)
	end)
	hit.MouseLeave:Connect(function()
		if closed then return end
		tween(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Quint)
		tween(card, { BackgroundTransparency = 0.06 + Ecstasy.GlassTransparency * 0.25 }, 0.18)
		tween(glow, { ImageTransparency = 0.86 }, 0.18)
	end)
	hit.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		dismiss()
	end)

	tween(wrapper, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Quint)
	tween(card, { GroupTransparency = 0 }, 0.26, Enum.EasingStyle.Quint)
	tween(scale, { Scale = 1 }, 0.32, Enum.EasingStyle.Back)
	tween(prog, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		dismiss()
	end)
end

local function playLoading(parent, theme, done)
	local ov = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(3, 3, 5),
		BackgroundTransparency = 0,
		ZIndex = 600,
		Parent = parent
	})

	for _, L in ipairs({ {240, 0.75}, {400, 0.86}, {580, 0.93} }) do
		create("ImageLabel", {
			Size = UDim2.fromOffset(L[1], L[1]),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = GLOW,
			ImageColor3 = theme.Accent,
			ImageTransparency = L[2],
			ZIndex = 601,
			Parent = ov
		})
	end

	local glass = create("CanvasGroup", {
		Size = UDim2.fromOffset(300, 170),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 602,
		Parent = ov
	})
	corner(glass, UDim.new(0, 18))
	stroke(glass, theme.Stroke, 0.88)
	local glassScale = create("UIScale", { Scale = 0.86, Parent = glass })

	local ring = create("Frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.new(0.5, 0, 0, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = glass
	})
	local ringStroke = create("UIStroke", {
		Color = theme.Accent,
		Thickness = 2.5,
		Transparency = 0.2,
		Parent = ring
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = ringStroke
	})

	local loadingLabel = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0.5, 0, 0, 88),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = "Loading",
		TextColor3 = theme.Text,
		TextSize = 16,
		FontFace = FontSemi,
		TextTransparency = 1,
		Parent = glass
	})
	local dots = create("TextLabel", {
		Size = UDim2.new(0, 32, 0, 22),
		Position = UDim2.new(0.5, 42, 0, 88),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.Accent,
		TextSize = 16,
		FontFace = FontSemi,
		TextTransparency = 1,
		Parent = glass
	})

	local spinConn = RunService.RenderStepped:Connect(function(dt)
		ring.Rotation = (ring.Rotation + dt * 280) % 360
	end)

	tween(glassScale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
	tween(loadingLabel, { TextTransparency = 0 }, 0.2)
	tween(dots, { TextTransparency = 0 }, 0.2)

	local running = true
	local patterns = { ".", "..", "..." }
	local di = 0
	task.spawn(function()
		while running do
			di = (di % 3) + 1
			dots.Text = patterns[di]
			task.wait(0.18)
		end
	end)

	task.wait(0.45)
	running = false
	tween(loadingLabel, { TextTransparency = 1 }, 0.12)
	tween(dots, { TextTransparency = 1 }, 0.12)
	tween(ringStroke, { Transparency = 1 }, 0.12)
	task.wait(0.1)

	local avatar = create("ImageLabel", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.new(0.5, 0, 0.5, -16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Surface2,
		BackgroundTransparency = 0.1,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		Parent = glass
	})
	corner(avatar, UDim.new(1, 0))
	stroke(avatar, theme.Accent, 0.3, 2)

	pcall(function()
		local content, ready = Players:GetUserThumbnailAsync(
			LocalPlayer.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if ready then avatar.Image = content end
	end)

	local welcome = create("TextLabel", {
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.new(0.5, 0, 0.5, 28),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "Welcome, " .. (LocalPlayer.DisplayName or LocalPlayer.Name),
		TextColor3 = theme.Text,
		TextSize = 14,
		FontFace = FontSemi,
		TextTransparency = 1,
		Parent = glass
	})

	tween(avatar, { Size = UDim2.fromOffset(52, 52) }, 0.26, Enum.EasingStyle.Back)
	tween(welcome, { TextTransparency = 0 }, 0.2)
	task.wait(0.48)

	spinConn:Disconnect()
	tween(glassScale, { Scale = 1.08 }, 0.2, Enum.EasingStyle.Quint)
	tween(glass, { GroupTransparency = 1 }, 0.22)
	tween(ov, { BackgroundTransparency = 1 }, 0.25)
	task.wait(0.26)
	ov:Destroy()
	if done then done() end
end

local Window = {}
Window.__index = Window

function Ecstasy:CreateWindow(opts)
	opts = opts or {}
	local theme = opts.Theme or {}
	for k, v in pairs(Theme) do if theme[k] == nil then theme[k] = v end end
	if ACCENT_PRESETS[Ecstasy.AccentName] then
		theme.Accent = ACCENT_PRESETS[Ecstasy.AccentName]
		Theme.Accent = theme.Accent
	end

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

	win._glowLayers = {}
	for _, L in ipairs({ {110, 0.72}, {180, 0.82}, {260, 0.9} }) do
		local gl = create("ImageLabel", {
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
		table.insert(win._glowLayers, gl)
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
	win._titleLine = create("Frame", {
		Size = UDim2.fromOffset(24, 2),
		Position = UDim2.fromOffset(22, 34),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = top
	})
	Ecstasy:RegisterAccent(win._titleLine)
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
	if opts.Settings ~= false then
		task.defer(function()
			win:CreateSettingsTab()
		end)
	end
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
	local pos = shell and shell.Position or m.Position

	if self.Visible then
		Ecstasy:PlayOpen()
		if shell then
			shell.Position = UDim2.new(pos.X.Scale, pos.X.Offset + 100, pos.Y.Scale, pos.Y.Offset)
			shell.Visible = true
		end
		if g then
			g.Position = UDim2.new(pos.X.Scale, pos.X.Offset + 100, pos.Y.Scale, pos.Y.Offset)
			g.Visible = true
		end
		s.Scale = 0.94
		m.BackgroundTransparency = 1
		local target = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset)
		tween(s, { Scale = 1 }, 0.18, Enum.EasingStyle.Quint)
		tween(m, { BackgroundTransparency = math.clamp(0.04 + Ecstasy.GlassTransparency, 0, 0.85) }, 0.18)
		if shell then tween(shell, { Position = target }, 0.18, Enum.EasingStyle.Quint) end
		if g then tween(g, { Position = target }, 0.18, Enum.EasingStyle.Quint) end
		if self._blur and self.Blur then tween(self._blur, { Size = 12 }, 0.18) end
		task.delay(0.2, function() self._toggling = false end)
	else
		Ecstasy:PlayClose()
		local hidePos = UDim2.new(pos.X.Scale, pos.X.Offset + 110, pos.Y.Scale, pos.Y.Offset)
		tween(s, { Scale = 0.94 }, 0.16, Enum.EasingStyle.Quint)
		tween(m, { BackgroundTransparency = 1 }, 0.16)
		if shell then tween(shell, { Position = hidePos }, 0.16, Enum.EasingStyle.Quint) end
		if g then tween(g, { Position = hidePos }, 0.16, Enum.EasingStyle.Quint) end
		if self._blur then tween(self._blur, { Size = 0 }, 0.14) end
		task.delay(0.17, function()
			if not self.Visible then
				if shell then
					shell.Visible = false
					shell.Position = pos
				end
				if g then
					g.Visible = false
					g.Position = pos
				end
				s.Scale = 1
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
	Ecstasy:RegisterAccent(accent)
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
	if tab.Active then return end
	Ecstasy:PlayTab()
	for _, t in ipairs(self.Tabs) do
		t.Active = false
		t.Page.Visible = false
		tween(t.Button, { BackgroundTransparency = 1 }, 0.18)
		tween(t.Label, { TextColor3 = self.Theme.Muted }, 0.18)
		tween(t.Accent, { BackgroundTransparency = 1 }, 0.18)
		if t.Icon then tween(t.Icon, { ImageColor3 = self.Theme.Muted }, 0.18) end
	end
	tab.Active = true
	tab.Page.Visible = true
	tween(tab.Button, { BackgroundTransparency = 0.35 }, 0.2)
	tween(tab.Label, { TextColor3 = self.Theme.Text }, 0.2)
	tween(tab.Accent, { BackgroundTransparency = 0 }, 0.2)
	if tab.Icon then tween(tab.Icon, { ImageColor3 = self.Theme.Accent }, 0.2) end
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

	local secTitle = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Theme.Accent,
		TextSize = 12,
		FontFace = FontSemi,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame
	})
	Ecstasy:RegisterAccent(secTitle, "TextColor3")
	sec.Title = secTitle

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

local function el(sec, h, order)
	local th = sec.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, h or 46),
		BackgroundColor3 = th.Surface2,
		BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3,
		BorderSizePixel = 0,
		LayoutOrder = order or 0,
		Parent = sec.List
	})
	corner(c, UDim.new(0, 10))
	local s = stroke(c, th.Stroke, 0.92)
	addHover(c)
	Ecstasy:RegisterGlass(c, 0.2)

	c.MouseEnter:Connect(function()
		tween(s, { Transparency = 0.65, Color = Theme.Accent }, 0.14)
		tween(c, { BackgroundTransparency = 0.06 }, 0.14)
	end)
	c.MouseLeave:Connect(function()
		tween(s, { Transparency = 0.92, Color = th.Stroke }, 0.18)
		tween(c, { BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3 }, 0.18)
	end)
	return c
end

function Section:CreateToggle(opts)
	opts = opts or {}
	local name, def, cb = opts.Name or "Toggle", opts.Default == true, opts.Callback
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

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
	if not locked then Ecstasy:RegisterAccent(track) end
	local knob = create("Frame", {
		Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = th.Muted, BorderSizePixel = 0, Parent = track
	})
	corner(knob, UDim.new(1, 0))

	local state = def
	local function set(v, fire)
		state = v
		local col = locked and accentCol or Theme.Accent
		if state then
			tween(track, { BackgroundColor3 = col }, 0.2)
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
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = name,
		TextColor3 = th.Text, TextSize = 13, FontFace = FontMedium,
		AutoButtonColor = false, Parent = c
	})
	if not locked then Ecstasy:RegisterAccent(btn, "TextColor3") end
	btn.MouseEnter:Connect(function()
		local col = locked and accentCol or Theme.Accent
		tween(btn, { TextColor3 = col }, 0.15)
	end)
	btn.MouseLeave:Connect(function() tween(btn, { TextColor3 = th.Text }, 0.2) end)
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		tween(c, { BackgroundTransparency = 0.05 }, 0.08)
		task.delay(0.1, function() tween(c, { BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3 }, 0.25) end)
		safe(cb)
	end)
	return {}
end

function Ecstasy:Confirm(opts)
	opts = opts or {}
	local title = opts.Title or "Warning"
	local content = opts.Content or "Are you sure you want to continue?"
	local confirmText = opts.ConfirmText or "Confirm"
	local cancelText = opts.CancelText or "Cancel"
	local onConfirm = opts.Callback or opts.OnConfirm
	local onCancel = opts.OnCancel
	local parentGui = opts.Parent
	if not parentGui then
		for _, w in ipairs(self.Windows) do
			if w.Gui and w.Gui.Parent then parentGui = w.Gui break end
		end
	end
	if not parentGui then parentGui = getParent() end

	local warnColor = Color3.fromRGB(251, 191, 36)

	local overlay = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 500,
		Parent = parentGui
	})
	local card = create("CanvasGroup", {
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.04 + Ecstasy.GlassTransparency * 0.2,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 501,
		Parent = overlay
	})
	corner(card, UDim.new(0, 16))
	stroke(card, Theme.Stroke, 0.88)
	local scale = create("UIScale", { Scale = 0.88, Parent = card })
	pad(card, 22, 22, 20, 20)
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = card
	})

	local glow = create("ImageLabel", {
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = GLOW,
		ImageColor3 = warnColor,
		ImageTransparency = 0.82,
		ZIndex = 501,
		Parent = card
	})

	local iconWrap = create("Frame", {
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = warnColor,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 502,
		Parent = card
	})
	corner(iconWrap, UDim.new(1, 0))
	stroke(iconWrap, warnColor, 0.35, 1.5)
	local iconScale = create("UIScale", { Scale = 0.6, Parent = iconWrap })
	create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "!",
		TextColor3 = warnColor,
		TextSize = 24,
		FontFace = FontSemi,
		ZIndex = 503,
		Parent = iconWrap
	})

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 16,
		FontFace = FontSemi,
		LayoutOrder = 2,
		ZIndex = 502,
		Parent = card
	})

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = content,
		TextColor3 = Theme.Muted,
		TextSize = 13,
		FontFace = FontRegular,
		TextWrapped = true,
		LayoutOrder = 3,
		ZIndex = 502,
		Parent = card
	})

	local btnRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		ZIndex = 502,
		Parent = card
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = btnRow
	})

	local function closeModal(confirmed)
		tween(scale, { Scale = 0.9 }, 0.14)
		tween(card, { GroupTransparency = 1 }, 0.14)
		tween(overlay, { BackgroundTransparency = 1 }, 0.14)
		task.delay(0.16, function()
			if overlay.Parent then overlay:Destroy() end
		end)
		if confirmed then safe(onConfirm) else safe(onCancel) end
	end

	local function styleBtn(btn, hoverBg)
		local s = create("UIScale", { Scale = 1, Parent = btn })
		btn.MouseEnter:Connect(function()
			tween(s, { Scale = 1.05 }, 0.14, Enum.EasingStyle.Quint)
			if hoverBg then tween(btn, hoverBg, 0.14) end
		end)
		btn.MouseLeave:Connect(function()
			tween(s, { Scale = 1 }, 0.16)
			if hoverBg then
				tween(btn, {
					BackgroundTransparency = btn:GetAttribute("BaseTrans") or 0.2
				}, 0.16)
			end
		end)
	end

	local cancelBtn = create("TextButton", {
		Size = UDim2.fromOffset(110, 36),
		BackgroundColor3 = Theme.Surface3,
		BackgroundTransparency = 0.2,
		Text = cancelText,
		TextColor3 = Theme.Text,
		TextSize = 13,
		FontFace = FontMedium,
		AutoButtonColor = false,
		ZIndex = 503,
		Parent = btnRow
	})
	cancelBtn:SetAttribute("BaseTrans", 0.2)
	corner(cancelBtn, UDim.new(0, 10))
	stroke(cancelBtn, Theme.Stroke, 0.88)
	styleBtn(cancelBtn, { BackgroundTransparency = 0.05 })

	local confirmBtn = create("TextButton", {
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = warnColor,
		BackgroundTransparency = 0.08,
		Text = confirmText,
		TextColor3 = Color3.fromRGB(20, 16, 8),
		TextSize = 13,
		FontFace = FontSemi,
		AutoButtonColor = false,
		ZIndex = 503,
		Parent = btnRow
	})
	confirmBtn:SetAttribute("BaseTrans", 0.08)
	corner(confirmBtn, UDim.new(0, 10))
	styleBtn(confirmBtn, { BackgroundTransparency = 0 })

	cancelBtn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		closeModal(false)
	end)
	confirmBtn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		closeModal(true)
	end)

	tween(overlay, { BackgroundTransparency = 0.5 }, 0.2)
	tween(card, { GroupTransparency = 0 }, 0.22, Enum.EasingStyle.Quint)
	tween(scale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
	tween(iconScale, { Scale = 1 }, 0.32, Enum.EasingStyle.Back)

	return { Close = function() closeModal(false) end }
end

function Section:CreateWarningButton(opts)
	opts = opts or {}
	local name = opts.Name or "Warning"
	local cb = opts.Callback
	local title = opts.Title or "Warning"
	local content = opts.Content or "Are you sure you want to continue?"
	local confirmText = opts.ConfirmText or "Confirm"
	local cancelText = opts.CancelText or "Cancel"
	local th = self.Theme
	local warnColor = Color3.fromRGB(251, 191, 36)
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

	local icon = create("TextLabel", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = warnColor,
		BackgroundTransparency = 0.8,
		Text = "!",
		TextColor3 = warnColor,
		TextSize = 15,
		FontFace = FontSemi,
		Parent = c
	})
	corner(icon, UDim.new(1, 0))
	stroke(icon, warnColor, 0.4, 1)

	local btn = create("TextButton", {
		Size = UDim2.new(1, -44, 1, 0),
		Position = UDim2.fromOffset(40, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = th.Text,
		TextSize = 13,
		FontFace = FontMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Parent = c
	})
	btn.MouseEnter:Connect(function()
		tween(btn, { TextColor3 = warnColor }, 0.15)
		tween(icon, { BackgroundTransparency = 0.65 }, 0.15)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { TextColor3 = th.Text }, 0.2)
		tween(icon, { BackgroundTransparency = 0.8 }, 0.2)
	end)
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		tween(c, { BackgroundTransparency = 0.05 }, 0.08)
		task.delay(0.1, function() tween(c, { BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3 }, 0.25) end)
		Ecstasy:Confirm({
			Title = title,
			Content = content,
			ConfirmText = confirmText,
			CancelText = cancelText,
			Parent = self.Window and self.Window.Gui,
			Callback = cb
		})
	end)
	return {}
end

function Section:CreateSlider(opts)
	opts = opts or {}
	local name = opts.Name or "Slider"
	local min, max, def = opts.Min or 0, opts.Max or 100, opts.Default or opts.Min or 0
	local dec, cb = opts.Decimals or 0, opts.Callback
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = el(self, 60, opts.Order or opts.LayoutOrder)

	create("TextLabel", {
		Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(14, 8),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})
	local val = create("TextLabel", {
		Size = UDim2.new(0, 60, 0, 16), Position = UDim2.new(1, -70, 0, 8),
		BackgroundTransparency = 1, Text = "", TextColor3 = accentCol,
		TextSize = 12, FontFace = FontMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = c
	})
	if not locked then Ecstasy:RegisterAccent(val, "TextColor3") end

	local bar = create("Frame", {
		Size = UDim2.new(1, -28, 0, 5), Position = UDim2.fromOffset(14, 38),
		BackgroundColor3 = th.Surface3, BorderSizePixel = 0, Parent = c
	})
	corner(bar, UDim.new(1, 0))
	local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = accentCol, BorderSizePixel = 0, Parent = bar })
	corner(fill, UDim.new(1, 0))
	if not locked then Ecstasy:RegisterAccent(fill) end
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
			sliding = true
			Ecstasy:PlaySlider()
			upd(i)
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
	local win = self.Window
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

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
		TextColor3 = accentCol,
		TextSize = 12,
		FontFace = FontMedium,
		Parent = chip
	})
	if not locked then Ecstasy:RegisterAccent(disp, "TextColor3") end

	local open, drop, dropScale, outsideConn = false, nil, nil, nil

	local function close()
		if outsideConn then outsideConn:Disconnect() outsideConn = nil end
		if not drop then open = false return end
		local d, s = drop, dropScale
		drop, dropScale, open = nil, nil, false
		if s then tween(s, { Scale = 0.96 }, 0.12) end
		if d:IsA("CanvasGroup") then
			tween(d, { GroupTransparency = 1 }, 0.12)
		end
		task.delay(0.14, function() if d and d.Parent then d:Destroy() end end)
	end

	local function openMenu()
		if open then close() return end
		open = true
		Ecstasy:PlayClick()
		local host = win.Gui
		local absPos = c.AbsolutePosition
		local absSize = c.AbsoluteSize
		local inset = GuiService:GetGuiInset()
		local h = math.min(#options * 34 + 14, 200)

		drop = create("CanvasGroup", {
			Size = UDim2.fromOffset(math.max(absSize.X, 170), h),
			Position = UDim2.fromOffset(absPos.X - inset.X, absPos.Y - inset.Y + absSize.Y + 6),
			BackgroundColor3 = th.Surface,
			BackgroundTransparency = 0.08 + Ecstasy.GlassTransparency * 0.35,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			ZIndex = 200,
			Parent = host
		})
		corner(drop, UDim.new(0, 12))
		stroke(drop, th.Stroke, 0.88)
		dropScale = create("UIScale", { Scale = 0.96, Parent = drop })

		local sc = create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = locked and accentCol or Theme.Accent,
			CanvasSize = UDim2.new(0, 0, 0, #options * 34),
			ZIndex = 201,
			Parent = drop
		})
		if not locked then Ecstasy:RegisterAccent(sc, "ScrollBarImageColor3") end
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = sc })
		pad(sc, 6, 6, 6, 6)

		for _, opt in ipairs(options) do
			local isSel = tostring(opt) == tostring(selected)
			local b = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = th.Surface2,
				BackgroundTransparency = isSel and 0.45 or 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 202,
				Parent = sc
			})
			corner(b, UDim.new(0, 8))
			local t = create("TextLabel", {
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				BackgroundTransparency = 1,
				Text = tostring(opt),
				TextColor3 = isSel and (locked and accentCol or Theme.Accent) or th.Text,
				TextSize = 12,
				FontFace = isSel and FontMedium or FontRegular,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 203,
				Parent = b
			})
			local bScale = create("UIScale", { Scale = 1, Parent = b })
			b.MouseEnter:Connect(function()
				local col = locked and accentCol or Theme.Accent
				tween(b, { BackgroundTransparency = 0.4 }, 0.12)
				tween(t, { TextColor3 = col }, 0.12)
				tween(bScale, { Scale = 1.02 }, 0.12)
			end)
			b.MouseLeave:Connect(function()
				local sel = tostring(opt) == tostring(selected)
				local col = locked and accentCol or Theme.Accent
				tween(b, { BackgroundTransparency = sel and 0.45 or 1 }, 0.15)
				tween(t, { TextColor3 = sel and col or th.Text }, 0.15)
				tween(bScale, { Scale = 1 }, 0.15)
			end)
			b.MouseButton1Click:Connect(function()
				selected = opt
				disp.Text = tostring(opt)
				Ecstasy:PlayClick()
				safe(cb, opt)
				close()
			end)
		end

		tween(drop, { GroupTransparency = 0 }, 0.18, Enum.EasingStyle.Quint)
		tween(dropScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Quint)

		task.defer(function()
			outsideConn = UserInputService.InputBegan:Connect(function(inp)
				if not open then return end
				if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
					local pos = inp.Position
					local dp, ds = drop.AbsolutePosition, drop.AbsoluteSize
					local insideDrop = pos.X >= dp.X and pos.X <= dp.X + ds.X and pos.Y >= dp.Y and pos.Y <= dp.Y + ds.Y
					local cp, cs = c.AbsolutePosition, c.AbsoluteSize
					local insideChip = pos.X >= cp.X and pos.X <= cp.X + cs.X and pos.Y >= cp.Y and pos.Y <= cp.Y + cs.Y
					if not insideDrop and not insideChip then close() end
				end
			end)
		end)
	end

	create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c
	}).MouseButton1Click:Connect(function()
		openMenu()
	end)

	return {
		Set = function(_, v) selected = v disp.Text = tostring(v) end,
		Get = function() return selected end,
		SetOptions = function(_, list) options = list or options end
	}
end

function Section:CreateKeybind(opts)
	opts = opts or {}
	local name, def, cb = opts.Name or "Keybind", opts.Default or Enum.KeyCode.E, opts.Callback
	local th = self.Theme
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

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
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

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
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

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

function Section:CreateImageButton(opts)
	opts = opts or {}
	local image = opts.Image or opts.Icon or "rbxassetid://6031094678"
	local h = opts.Height or 48
	local cb = opts.Callback
	local th = self.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = th.Surface2,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = self.List
	})
	corner(c, UDim.new(0, 10))
	stroke(c, th.Stroke, 0.92)
	addHover(c)
	Ecstasy:RegisterGlass(c, 0.2)
	local img = create("ImageLabel", {
		Size = UDim2.fromOffset(h - 16, h - 16),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		Parent = c
	})
	local label = create("TextLabel", {
		Size = UDim2.new(1, -(h + 8), 1, 0),
		Position = UDim2.fromOffset(h, 0),
		BackgroundTransparency = 1,
		Text = opts.Name or opts.Text or "Image Button",
		TextColor3 = th.Text,
		TextSize = 13,
		FontFace = FontMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = c
	})
	create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c
	}).MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		safe(cb)
	end)
	return {
		SetImage = function(_, id) img.Image = tostring(id) end,
		SetText = function(_, t) label.Text = tostring(t) end
	}
end

function Section:CreateCheckbox(opts)
	return self:CreateToggle(opts)
end

function Section:CreateProgressBar(opts)
	opts = opts or {}
	local name = opts.Name or "Progress"
	local value = math.clamp(opts.Value or 0, 0, 1)
	local th = self.Theme
	local c = el(self, 56, opts.Order or opts.LayoutOrder)
	create("TextLabel", {
		Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(14, 8),
		BackgroundTransparency = 1, Text = name, TextColor3 = th.Text,
		TextSize = 13, FontFace = FontRegular, TextXAlignment = Enum.TextXAlignment.Left, Parent = c
	})
	local pct = create("TextLabel", {
		Size = UDim2.new(0, 50, 0, 16), Position = UDim2.new(1, -60, 0, 8),
		BackgroundTransparency = 1, Text = math.floor(value * 100) .. "%", TextColor3 = th.Accent,
		TextSize = 12, FontFace = FontMedium, TextXAlignment = Enum.TextXAlignment.Right, Parent = c
	})
	Ecstasy:RegisterAccent(pct, "TextColor3")
	local bar = create("Frame", {
		Size = UDim2.new(1, -28, 0, 6), Position = UDim2.fromOffset(14, 36),
		BackgroundColor3 = th.Surface3, BorderSizePixel = 0, Parent = c
	})
	corner(bar, UDim.new(1, 0))
	local fill = create("Frame", {
		Size = UDim2.new(value, 0, 1, 0), BackgroundColor3 = th.Accent, BorderSizePixel = 0, Parent = bar
	})
	corner(fill, UDim.new(1, 0))
	Ecstasy:RegisterAccent(fill)
	return {
		Set = function(_, v)
			v = math.clamp(v, 0, 1)
			value = v
			tween(fill, { Size = UDim2.new(v, 0, 1, 0) }, 0.2)
			pct.Text = math.floor(v * 100) .. "%"
		end,
		Get = function() return value end
	}
end

function Section:CreateList(opts)
	opts = opts or {}
	local name = opts.Name or "List"
	local items = opts.Items or opts.Options or {}
	local multi = opts.MultiSelect == true
	local cb = opts.Callback
	local th = self.Theme
	local height = math.min(28 + #items * 30 + 12, 180)
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = th.Surface2,
		BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3,
		BorderSizePixel = 0,
		Parent = self.List
	})
	corner(c, UDim.new(0, 10))
	stroke(c, th.Stroke, 0.92)
	Ecstasy:RegisterGlass(c, 0.2)
	pad(c, 10, 10, 8, 8)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = th.Accent,
		TextSize = 11,
		FontFace = FontSemi,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = c
	})

	local sc = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -20),
		Position = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = th.Accent,
		CanvasSize = UDim2.new(0, 0, 0, #items * 30),
		Parent = c
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = sc })

	local selected = multi and {} or nil
	if multi then
		for _, it in ipairs(items) do selected[it] = false end
	elseif #items > 0 then
		selected = items[1]
	end

	local function refresh()
		for _, child in ipairs(sc:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for _, it in ipairs(items) do
			local isOn = multi and selected[it] or selected == it
			local b = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = th.Surface3,
				BackgroundTransparency = isOn and 0.35 or 1,
				Text = "",
				AutoButtonColor = false,
				Parent = sc
			})
			corner(b, UDim.new(0, 7))
			local t = create("TextLabel", {
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.fromOffset(10, 0),
				BackgroundTransparency = 1,
				Text = tostring(it),
				TextColor3 = isOn and th.Accent or th.Text,
				TextSize = 12,
				FontFace = isOn and FontMedium or FontRegular,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = b
			})
			b.MouseEnter:Connect(function()
				if not isOn then tween(b, { BackgroundTransparency = 0.55 }, 0.12) end
			end)
			b.MouseLeave:Connect(function()
				local on = multi and selected[it] or selected == it
				tween(b, { BackgroundTransparency = on and 0.35 or 1 }, 0.12)
			end)
			b.MouseButton1Click:Connect(function()
				Ecstasy:PlayClick()
				if multi then
					selected[it] = not selected[it]
					local list = {}
					for _, x in ipairs(items) do if selected[x] then table.insert(list, x) end end
					safe(cb, list)
				else
					selected = it
					safe(cb, it)
				end
				refresh()
			end)
		end
	end
	refresh()

	return {
		SetItems = function(_, list)
			items = list or items
			sc.CanvasSize = UDim2.new(0, 0, 0, #items * 30)
			if multi then
				selected = {}
				for _, it in ipairs(items) do selected[it] = false end
			elseif #items > 0 then
				selected = items[1]
			end
			refresh()
		end,
		Get = function()
			if multi then
				local list = {}
				for _, x in ipairs(items) do if selected[x] then table.insert(list, x) end end
				return list
			end
			return selected
		end,
		Set = function(_, v)
			if multi and type(v) == "table" then
				for k in pairs(selected) do selected[k] = false end
				for _, x in ipairs(v) do selected[x] = true end
			else
				selected = v
			end
			refresh()
		end
	}
end

function Section:CreateSearch(opts)
	opts = opts or {}
	local ph = opts.Placeholder or "Search..."
	local cb = opts.Callback
	local th = self.Theme
	local c = el(self, 46, opts.Order or opts.LayoutOrder)
	local box = create("TextBox", {
		Size = UDim2.new(1, -28, 0, 30),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = th.Surface3,
		BackgroundTransparency = 0.2,
		Text = "",
		PlaceholderText = ph,
		PlaceholderColor3 = th.Muted,
		TextColor3 = th.Text,
		TextSize = 12,
		FontFace = FontRegular,
		ClearTextOnFocus = false,
		Parent = c
	})
	corner(box, UDim.new(0, 8))
	stroke(box, th.Stroke, 0.9)
	pad(box, 10, 10, 0, 0)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		safe(cb, box.Text)
	end)
	return { Set = function(_, t) box.Text = tostring(t) end, Get = function() return box.Text end }
end

function Section:CreateDivider(opts)
	opts = opts or {}
	local th = self.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		LayoutOrder = opts.Order or opts.LayoutOrder or 0,
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

function Section:CreateSpacer(opts)
	opts = opts or {}
	local h = opts.Height or 10
	create("Frame", {
		Size = UDim2.new(1, 0, 0, h),
		BackgroundTransparency = 1,
		LayoutOrder = opts.Order or opts.LayoutOrder or 0,
		Parent = self.List
	})
	return {}
end

function Section:CreatePrimaryButton(opts)
	opts = opts or {}
	local name, cb = opts.Name or "Primary", opts.Callback
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = accentCol,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		LayoutOrder = opts.Order or opts.LayoutOrder or 0,
		Parent = self.List
	})
	corner(c, UDim.new(0, 10))
	if not locked then Ecstasy:RegisterAccent(c) end
	addHover(c)
	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
		FontFace = FontSemi,
		AutoButtonColor = false,
		Parent = c
	})
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		tween(c, { BackgroundTransparency = 0.05 }, 0.08)
		task.delay(0.12, function() tween(c, { BackgroundTransparency = 0.15 }, 0.2) end)
		safe(cb)
	end)
	return {}
end

function Section:CreateGhostButton(opts)
	opts = opts or {}
	local name, cb = opts.Name or "Ghost", opts.Callback
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = opts.Order or opts.LayoutOrder or 0,
		Parent = self.List
	})
	corner(c, UDim.new(0, 10))
	local st = stroke(c, accentCol, 0.45, 1.5)
	if not locked then Ecstasy:RegisterAccent(st, "Color") end
	addHover(c)
	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = accentCol,
		TextSize = 13,
		FontFace = FontMedium,
		AutoButtonColor = false,
		Parent = c
	})
	if not locked then Ecstasy:RegisterAccent(btn, "TextColor3") end
	btn.MouseEnter:Connect(function()
		tween(c, { BackgroundTransparency = 0.85 }, 0.15)
		tween(st, { Transparency = 0.2 }, 0.15)
	end)
	btn.MouseLeave:Connect(function()
		tween(c, { BackgroundTransparency = 1 }, 0.2)
		tween(st, { Transparency = 0.45 }, 0.2)
	end)
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		safe(cb)
	end)
	return {}
end

function Section:CreateToggleButton(opts)
	opts = opts or {}
	local name = opts.Name or "Toggle Button"
	local state = opts.Default == true
	local cb = opts.Callback
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = state and accentCol or th.Text,
		TextSize = 13,
		FontFace = FontMedium,
		AutoButtonColor = false,
		Parent = c
	})
	local badge = create("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(1, -18, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = state and accentCol or th.Muted,
		BorderSizePixel = 0,
		Parent = c
	})
	corner(badge, UDim.new(1, 0))
	if not locked then
		Ecstasy:RegisterAccent(btn, "TextColor3")
		Ecstasy:RegisterAccent(badge)
	end

	local function set(v, fire)
		state = v == true
		local col = locked and accentCol or Theme.Accent
		tween(btn, { TextColor3 = state and col or th.Text }, 0.15)
		tween(badge, { BackgroundColor3 = state and col or th.Muted }, 0.15)
		if fire ~= false then safe(cb, state) end
	end
	set(state, false)

	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		set(not state)
	end)
	return { Set = function(_, v) set(v == true) end, Get = function() return state end }
end

function Section:CreateStatus(opts)
	opts = opts or {}
	local name = opts.Name or "Status"
	local status = opts.Status or opts.Value or "Idle"
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

	create("TextLabel", {
		Size = UDim2.new(0.45, 0, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = th.Text,
		TextSize = 13,
		FontFace = FontRegular,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = c
	})

	local pill = create("Frame", {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = accentCol,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Parent = c
	})
	corner(pill, UDim.new(1, 0))
	pad(pill, 12, 12, 0, 0)
	if not locked then Ecstasy:RegisterAccent(pill) end

	local dot = create("Frame", {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = accentCol,
		BorderSizePixel = 0,
		Parent = pill
	})
	corner(dot, UDim.new(1, 0))
	if not locked then Ecstasy:RegisterAccent(dot) end

	local label = create("TextLabel", {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = tostring(status),
		TextColor3 = accentCol,
		TextSize = 12,
		FontFace = FontMedium,
		Parent = pill
	})
	if not locked then Ecstasy:RegisterAccent(label, "TextColor3") end

	return {
		Set = function(_, v)
			label.Text = tostring(v)
		end,
		Get = function() return label.Text end,
		SetColor = function(_, col)
			if typeof(col) == "Color3" then
				pill.BackgroundColor3 = col
				dot.BackgroundColor3 = col
				label.TextColor3 = col
			end
		end
	}
end

function Section:CreateNumberBox(opts)
	opts = opts or {}
	local name = opts.Name or "Number"
	local min = opts.Min or 0
	local max = opts.Max or 100
	local value = opts.Default or min
	local step = opts.Step or 1
	local cb = opts.Callback
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

	create("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = th.Text,
		TextSize = 13,
		FontFace = FontRegular,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = c
	})

	local row = create("Frame", {
		Size = UDim2.fromOffset(120, 28),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = c
	})

	local function makeSide(text, x)
		local b = create("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.fromOffset(x, 0),
			BackgroundColor3 = th.Surface3,
			BackgroundTransparency = 0.2,
			Text = text,
			TextColor3 = th.Text,
			TextSize = 16,
			FontFace = FontSemi,
			AutoButtonColor = false,
			Parent = row
		})
		corner(b, UDim.new(0, 8))
		return b
	end

	local minus = makeSide("-", 0)
	local plus = makeSide("+", 92)

	local box = create("TextBox", {
		Size = UDim2.fromOffset(56, 28),
		Position = UDim2.fromOffset(32, 0),
		BackgroundColor3 = th.Surface3,
		BackgroundTransparency = 0.25,
		Text = tostring(value),
		TextColor3 = accentCol,
		TextSize = 13,
		FontFace = FontMedium,
		ClearTextOnFocus = false,
		Parent = row
	})
	corner(box, UDim.new(0, 8))
	if not locked then Ecstasy:RegisterAccent(box, "TextColor3") end

	local function set(v, fire)
		v = math.clamp(tonumber(v) or value, min, max)
		value = v
		box.Text = tostring(v)
		if fire ~= false then safe(cb, v) end
	end
	set(value, false)

	minus.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		set(value - step)
	end)
	plus.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		set(value + step)
	end)
	box.FocusLost:Connect(function()
		set(box.Text)
	end)

	return { Set = function(_, v) set(v) end, Get = function() return value end }
end

function Section:CreateRadio(opts)
	opts = opts or {}
	local name = opts.Name or "Radio"
	local options = opts.Options or { "A", "B", "C" }
	local selected = opts.Default or options[1]
	local cb = opts.Callback
	local th = self.Theme
	local accentCol, locked = Ecstasy:ResolveColor(opts, th.Accent)
	local height = 28 + #options * 30
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = th.Surface2,
		BackgroundTransparency = 0.2 + Ecstasy.GlassTransparency * 0.3,
		BorderSizePixel = 0,
		LayoutOrder = opts.Order or opts.LayoutOrder or 0,
		Parent = self.List
	})
	corner(c, UDim.new(0, 10))
	stroke(c, th.Stroke, 0.92)
	Ecstasy:RegisterGlass(c, 0.2)
	pad(c, 10, 10, 8, 8)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = accentCol,
		TextSize = 11,
		FontFace = FontSemi,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = c
	})
	local title = c:FindFirstChildWhichIsA("TextLabel")
	if title and not locked then Ecstasy:RegisterAccent(title, "TextColor3") end

	local list = create("Frame", {
		Size = UDim2.new(1, 0, 1, -20),
		Position = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 1,
		Parent = c
	})
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = list })

	local dots = {}
	local function refresh()
		for opt, pair in pairs(dots) do
			local on = opt == selected
			local col = locked and accentCol or Theme.Accent
			tween(pair.dot, { BackgroundColor3 = on and col or th.Muted, BackgroundTransparency = on and 0 or 0.4 }, 0.15)
			tween(pair.label, { TextColor3 = on and col or th.Text }, 0.15)
		end
	end

	for _, opt in ipairs(options) do
		local row = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = list
		})
		local dot = create("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 4, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = th.Muted,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Parent = row
		})
		corner(dot, UDim.new(1, 0))
		stroke(dot, th.Stroke, 0.7)
		local label = create("TextLabel", {
			Size = UDim2.new(1, -28, 1, 0),
			Position = UDim2.fromOffset(26, 0),
			BackgroundTransparency = 1,
			Text = tostring(opt),
			TextColor3 = th.Text,
			TextSize = 12,
			FontFace = FontRegular,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row
		})
		dots[opt] = { dot = dot, label = label }
		row.MouseButton1Click:Connect(function()
			Ecstasy:PlayClick()
			selected = opt
			refresh()
			safe(cb, selected)
		end)
	end
	refresh()

	return {
		Set = function(_, v) selected = v refresh() end,
		Get = function() return selected end
	}
end

function Section:CreatePlayerList(opts)
	opts = opts or {}
	local name = opts.Name or "Players"
	local multi = opts.MultiSelect == true
	local cb = opts.Callback
	local items = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		table.insert(items, plr.Name)
	end
	local list = self:CreateList({
		Name = name,
		Items = items,
		MultiSelect = multi,
		Order = opts.Order or opts.LayoutOrder,
		Callback = cb
	})
	local function rebuild()
		local names = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			table.insert(names, plr.Name)
		end
		list:SetItems(names)
	end
	Players.PlayerAdded:Connect(rebuild)
	Players.PlayerRemoving:Connect(rebuild)
	return list
end

function Section:CreateCopyButton(opts)
	opts = opts or {}
	local name = opts.Name or "Copy"
	local text = opts.Text or opts.Value or ""
	local th = self.Theme
	local c = el(self, 46, opts.Order or opts.LayoutOrder)

	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = th.Text,
		TextSize = 13,
		FontFace = FontMedium,
		AutoButtonColor = false,
		Parent = c
	})
	btn.MouseEnter:Connect(function() tween(btn, { TextColor3 = Theme.Accent }, 0.15) end)
	btn.MouseLeave:Connect(function() tween(btn, { TextColor3 = th.Text }, 0.2) end)
	btn.MouseButton1Click:Connect(function()
		Ecstasy:PlayClick()
		local ok = pcall(function()
			if setclipboard then
				setclipboard(tostring(text))
			elseif toclipboard then
				toclipboard(tostring(text))
			end
		end)
		Ecstasy:Notify({
			Title = ok and "Copied" or "Copy failed",
			Content = ok and "Copied to clipboard." or "Clipboard not available.",
			Duration = 2
		})
		safe(opts.Callback, text)
	end)
	return {
		SetText = function(_, t) text = tostring(t) end,
		GetText = function() return text end
	}
end

function Section:CreateButtonRow(opts)
	opts = opts or {}
	local buttons = opts.Buttons or {}
	local th = self.Theme
	local c = create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = opts.Order or opts.LayoutOrder or 0,
		Parent = self.List
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = c
	})
	local count = math.max(#buttons, 1)
	for i, bopts in ipairs(buttons) do
		bopts = bopts or {}
		local accentCol, locked = Ecstasy:ResolveColor(bopts, th.Accent)
		local filled = bopts.Primary == true
		local cell = create("Frame", {
			Size = UDim2.new(1 / count, -math.floor(8 * (count - 1) / count), 1, 0),
			BackgroundColor3 = filled and accentCol or th.Surface2,
			BackgroundTransparency = filled and 0.15 or (0.2 + Ecstasy.GlassTransparency * 0.3),
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = c
		})
		corner(cell, UDim.new(0, 10))
		stroke(cell, th.Stroke, 0.92)
		if filled and not locked then Ecstasy:RegisterAccent(cell) end
		addHover(cell)
		local btn = create("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = bopts.Name or ("Btn " .. i),
			TextColor3 = filled and Color3.new(1, 1, 1) or th.Text,
			TextSize = 12,
			FontFace = FontMedium,
			AutoButtonColor = false,
			Parent = cell
		})
		btn.MouseButton1Click:Connect(function()
			Ecstasy:PlayClick()
			safe(bopts.Callback)
		end)
	end
	return {}
end

function Window:CreateSettingsTab()
	if self._settingsTab then
		return self._settingsTab
	end
	local tab = self:CreateTab({ Name = "Settings" })
	self._settingsTab = tab
	local left = tab:CreateSection({ Name = "Interface", Side = "Left" })
	local right = tab:CreateSection({ Name = "Audio", Side = "Right" })
	local extra = tab:CreateSection({ Name = "Config", Side = "Left" })

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

	left:CreateToggle({
		Name = "Background Blur",
		Default = self.Blur == true,
		Callback = function(v)
			self.Blur = v
			if self._blur then
				tween(self._blur, { Size = v and (self.Visible and 12 or 0) or 0 }, 0.25)
			end
		end
	})

	left:CreateDropdown({
		Name = "Accent Color",
		Options = { "Purple", "Red", "White" },
		Default = Ecstasy.AccentName or "Purple",
		Callback = function(opt)
			Ecstasy:SetAccent(opt)
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

	extra:CreateButton({
		Name = "Reset Config",
		Callback = function()
			Ecstasy.SoundEnabled = true
			Ecstasy.ClickSounds = true
			Ecstasy.NotifySounds = true
			Ecstasy.SoundVolume = 0.22
			Ecstasy.GlassTransparency = 0.12
			Ecstasy.Keybind = Enum.KeyCode.RightControl
			self.Keybind = Ecstasy.Keybind
			Ecstasy:ApplyGlass()
			saveConfig()
			Ecstasy:Notify({ Title = "Settings", Content = "Config reset to defaults.", Duration = 3 })
		end
	})

	extra:CreateButton({
		Name = "Save Config Now",
		Callback = function()
			saveConfig()
			Ecstasy:Notify({ Title = "Settings", Content = "Config saved.", Duration = 2 })
		end
	})

	extra:CreateLabel({ Text = "Settings auto-save when changed." })

	return tab
end

function Window:CreatePremadeTab(opts)
	opts = opts or {}
	local tab = self:CreateTab({ Name = opts.Name or "Demo" })
	local L = tab:CreateSection({ Name = "Controls", Side = "Left" })
	local R = tab:CreateSection({ Name = "Extra", Side = "Right" })

	L:CreateToggle({ Name = "Feature", Default = false, Callback = print })
	L:CreateSlider({ Name = "Value", Min = 0, Max = 100, Default = 50, Callback = print })
	L:CreateProgressBar({ Name = "Load", Value = 0.65 })
	L:CreatePrimaryButton({ Name = "Primary Action", Callback = function()
		Ecstasy:Notify({ Title = "Done", Content = "Primary clicked.", Duration = 3 })
	end })
	L:CreateGhostButton({ Name = "Ghost Action", Callback = print })
	L:CreateToggleButton({ Name = "Armed", Default = false, Callback = print })
	L:CreateButtonRow({
		Buttons = {
			{ Name = "One", Callback = print },
			{ Name = "Two", Primary = true, Callback = print },
			{ Name = "Three", Callback = print },
		}
	})
	L:CreateDropdown({ Name = "Mode", Options = { "Normal", "Fast", "Silent" }, Default = "Normal", Callback = print })
	L:CreateNumberBox({ Name = "Amount", Min = 0, Max = 50, Default = 5, Step = 1, Callback = print })
	L:CreateStatus({ Name = "State", Status = "Ready" })
	L:CreateDivider()
	L:CreateLabel({ Text = "Use Settings for UI options." })

	R:CreateRadio({ Name = "Priority", Options = { "Low", "Medium", "High" }, Default = "Medium", Callback = print })
	R:CreateList({ Name = "Targets", Items = { "Player1", "Player2", "NPC" }, MultiSelect = false, Callback = print })
	R:CreateKeybind({ Name = "Key", Default = Enum.KeyCode.E, Callback = function(k) print(k.Name) end })
	R:CreateTextBox({ Name = "Name", Placeholder = "Type...", Callback = print })
	R:CreateCopyButton({ Name = "Copy Invite", Text = "discord.gg/example" })
	R:CreateWarningButton({
		Name = "Danger Action",
		Title = "Warning",
		Content = "Are you sure you want to run this?",
		ConfirmText = "Yes",
		CancelText = "No",
		Callback = function()
			Ecstasy:Notify({ Title = "Confirmed", Content = "Action ran.", Duration = 3 })
		end
	})
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
