--[[ STEAL A BOX - UI kit (shared by every part of the client UI)
     One look everywhere: the round Fredoka One font, thick dark outlines, soft top-lit
     gradients and chunky "3D" buttons that squish when you press them - the style of the
     big Roblox simulators.

     The whole UI is designed for a 1280 x 720 screen and scaled to fit any screen with ONE
     UIScale on the root frame, so nothing is ever positioned in a way that can overlap on
     small screens: every region is a list layout that stacks its children. ]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("StealABoxConfig"))

local UI = {}
UI.Font = Config.Font
do
	local UIS = game:GetService("UserInputService")
	UI.isTouch = UIS.TouchEnabled and not UIS.KeyboardEnabled
end
-- the size the UI is designed for. Phones use a smaller one, so everything is a bit bigger there.
UI.REF_W, UI.REF_H = 1280, 720
if UI.isTouch then UI.REF_W, UI.REF_H = 960, 540 end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
UI.rgb = rgb
UI.C = {
	ink = rgb(20, 16, 32),          -- outlines
	panel = rgb(38, 34, 60),        -- window body
	panelDark = rgb(25, 22, 42),    -- page background
	card = rgb(52, 46, 82),         -- cards inside windows
	cardLight = rgb(68, 61, 104),
	hud = rgb(22, 19, 38),          -- HUD pills
	white = Color3.new(1, 1, 1),
	black = Color3.new(0, 0, 0),
	sub = rgb(205, 200, 230),       -- secondary text
	muted = rgb(140, 134, 172),
	green = rgb(70, 215, 85),
	blue = rgb(60, 155, 255),
	yellow = rgb(255, 200, 45),
	gold = rgb(255, 205, 50),
	red = rgb(255, 72, 88),
	purple = rgb(165, 100, 255),
	orange = rgb(255, 150, 45),
	pink = rgb(255, 95, 170),
	cyan = rgb(40, 205, 240),
	money = rgb(125, 255, 80),
	grey = rgb(96, 92, 120),
}
local C = UI.C

------------------------------------------------------------------
-- PRIMITIVES
------------------------------------------------------------------
function UI.new(class, props, parent)
	local o = Instance.new(class)
	if props then
		for k, v in pairs(props) do o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end
local new = UI.new

function UI.corner(obj, px)
	return new("UICorner", {CornerRadius = (px == true) and UDim.new(1, 0) or UDim.new(0, px or 12)}, obj)
end

function UI.stroke(obj, thickness, color, transparency)
	return new("UIStroke", {Thickness = thickness or 2.5, Color = color or C.ink, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round}, obj)
end

-- soft top-lit look: lighter at the top, darker at the bottom
function UI.shade(obj, top, bottom, rotation)
	return new("UIGradient", {Rotation = rotation or 90, Color = ColorSequence.new(top or C.white, bottom or rgb(200, 200, 210))}, obj)
end

-- a bright candy gradient in one colour: light at the top, deep at the bottom
function UI.vivid(obj, color, rotation)
	obj.BackgroundColor3 = C.white
	for _, g in ipairs(obj:GetChildren()) do
		if g:IsA("UIGradient") then g:Destroy() end
	end
	return new("UIGradient", {Rotation = rotation or 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(C.white, 0.35)),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, color:Lerp(C.black, 0.22)),
	})}, obj)
end

function UI.padding(obj, all, top, bottom, left, right)
	return new("UIPadding", {PaddingTop = UDim.new(0, top or all or 0), PaddingBottom = UDim.new(0, bottom or all or 0),
		PaddingLeft = UDim.new(0, left or all or 0), PaddingRight = UDim.new(0, right or all or 0)}, obj)
end

function UI.list(obj, padding, dir, hAlign, vAlign)
	return new("UIListLayout", {Padding = UDim.new(0, padding or 6), FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left, VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder}, obj)
end

function UI.tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- an invisible frame (for layout)
function UI.box(parent, props)
	local f = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1)}, parent)
	if props then
		for k, v in pairs(props) do f[k] = v end
	end
	return f
end

-- text with the dark outline every label has. Text always FITS its box: it is drawn at `Max`
-- (in UI units, so it grows with the screen like everything else) and shrinks only when the
-- words don't fit, so long words can never spill over other text.
--   props: normal TextLabel props + Max (biggest text size), Min (smallest), Stroke (outline px, 0 = none)
local TextService = game:GetService("TextService")
local FIT_FONT = Enum.Font.FredokaOne
local function fits(text, size, w, h, wrapped)
	local ok, b = pcall(TextService.GetTextSize, TextService, text, size, FIT_FONT, Vector2.new(wrapped and w or 100000, 100000))
	if not ok then return true end
	return b.X <= w + 1 and b.Y <= h + 1
end
function UI.fitText(l, maxSize, minSize)
	local abs = l.AbsoluteSize
	if l.Text == "" or abs.X < 2 or abs.Y < 2 then
		l.TextSize = maxSize
		return
	end
	-- the box in UI units (the root's UIScale also scales the text)
	local s = (UI.root and l:IsDescendantOf(UI.root)) and UI.scale or 1
	local w, h = abs.X / s, abs.Y / s
	if fits(l.Text, maxSize, w, h, l.TextWrapped) then
		l.TextSize = maxSize
		return
	end
	local lo, hi = minSize, maxSize - 1 -- biggest size that fits (binary search)
	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		if fits(l.Text, mid, w, h, l.TextWrapped) then lo = mid else hi = mid - 1 end
	end
	l.TextSize = lo
end
function UI.label(parent, text, props)
	props = props or {}
	local l = new("TextLabel", {
		BackgroundTransparency = 1, FontFace = UI.Font, TextColor3 = C.white, Size = UDim2.fromScale(1, 1),
		TextScaled = false, Text = Config.StripEmoji(tostring(text or "")), TextWrapped = true,
	}, parent)
	for k, v in pairs(props) do
		if k ~= "Max" and k ~= "Min" and k ~= "Stroke" then l[k] = v end
	end
	local maxSize = math.floor(props.Max or 28)
	local minSize = math.min(maxSize, math.floor(props.Min or 9))
	l.TextSize = maxSize
	local function refit() UI.fitText(l, maxSize, minSize) end
	l:GetPropertyChangedSignal("Text"):Connect(refit)
	l:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()
	local strokePx = props.Stroke or 2
	if strokePx > 0 then
		new("UIStroke", {Thickness = strokePx, Color = C.ink, LineJoinMode = Enum.LineJoinMode.Round}, l)
	end
	return l
end

function UI.setText(label, text)
	label.Text = Config.StripEmoji(tostring(text or ""))
end

------------------------------------------------------------------
-- SOUNDS (built-in Roblox sounds, pitched for a soft "tick", a "pop" and a "ding")
------------------------------------------------------------------
local SFX = {enabled = true}
UI.SFX = SFX
do
	local function snd(id, vol, pitch)
		return new("Sound", {SoundId = id, Volume = vol, PlaybackSpeed = pitch}, SoundService)
	end
	SFX.click = snd("rbxasset://sounds/electronicpingshort.wav", 0.22, 2.4)
	SFX.open = snd("rbxasset://sounds/swoosh.wav", 0.25, 1.5)
	SFX.close = snd("rbxasset://sounds/swoosh.wav", 0.18, 1.9)
	SFX.ding = snd("rbxasset://sounds/electronicpingshort.wav", 0.5, 1)
	SFX.error = snd("rbxasset://sounds/electronicpingshort.wav", 0.3, 0.55)
	-- play a short copy (so fast repeats overlap instead of cutting off)
	function SFX.play(name, pitch, vol)
		if not SFX.enabled then return end
		local base = SFX[name]
		if typeof(base) ~= "Instance" then return end
		local s = base:Clone()
		if pitch then s.PlaybackSpeed = pitch end
		if vol then s.Volume = vol end
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 3)
	end
end

-- a button bounces: grows a little on hover, squishes on press, ticks when clicked
function UI.pressable(button, target)
	target = target or button
	local scale = target:FindFirstChild("PressScale") or new("UIScale", {Name = "PressScale"}, target)
	button.MouseEnter:Connect(function() UI.tween(scale, 0.25, {Scale = 1.06}, Enum.EasingStyle.Back) end)
	button.MouseLeave:Connect(function() UI.tween(scale, 0.2, {Scale = 1}) end)
	button.MouseButton1Down:Connect(function() UI.tween(scale, 0.06, {Scale = 0.92}) end)
	button.MouseButton1Up:Connect(function() UI.tween(scale, 0.35, {Scale = 1.06}, Enum.EasingStyle.Back) end)
	button.Activated:Connect(function() SFX.play("click", 2.2 + math.random() * 0.4) end)
	return scale
end

------------------------------------------------------------------
-- ICONS: every icon is drawn with frames (round shapes, a thick dark outline and soft
-- top-lit shading), so the whole UI has one cartoon look instead of emoji.
-- UI.icon(name, parent, size, position, colour, anchor) -> the icon's container frame
------------------------------------------------------------------
local ICON = {}
UI.ICON = ICON
do
	local INK = C.ink
	local WHITE2 = Color3.new(1, 1, 1)
	local GOLD = rgb(255, 205, 50)
	local function P2(x, y) return UDim2.fromScale(x, y) end
	-- one shape. props: normal Frame props + Round (true = circle, number = radius scale),
	-- Stroke (thickness, false = none), Shade (soft gradient), Fade (fades out to the left)
	local function sh(ctx, props)
		ctx.z = ctx.z + 1
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.ZIndex = ctx.z
		for k, v in pairs(props) do
			if k ~= "Round" and k ~= "Stroke" and k ~= "Shade" and k ~= "Fade" and k ~= "StrokeColor" then f[k] = v end
		end
		if props.Round then
			new("UICorner", {CornerRadius = (props.Round == true) and UDim.new(1, 0) or UDim.new(props.Round, 0)}, f)
		end
		if props.Stroke ~= false then
			new("UIStroke", {Thickness = (props.Stroke or 1) * ctx.w, Color = props.StrokeColor or INK, LineJoinMode = Enum.LineJoinMode.Round}, f)
		end
		if props.Shade then
			new("UIGradient", {Rotation = 90, Color = ColorSequence.new(WHITE2, rgb(190, 190, 200))}, f)
		elseif props.Fade then
			new("UIGradient", {Transparency = NumberSequence.new(1, 0)}, f)
		end
		f.Parent = ctx.root
		return f
	end
	-- the same shape twice: a dark one a bit bigger behind it = an outline around compound shapes
	local function outlined(ctx, props)
		local back = {}
		for k, v in pairs(props) do back[k] = v end
		back.BackgroundColor3 = INK
		back.Stroke = false
		back.Shade = nil
		back.Size = props.Size + UDim2.fromOffset(ctx.w * 2.4, ctx.w * 2.4)
		sh(ctx, back)
		return back
	end
	local function textIn(f, str, color)
		new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = UI.Font, TextScaled = true, Text = str,
			TextColor3 = color, ZIndex = f.ZIndex + 1}, f)
	end
	local D = {}
	D.bag = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.22), Size = P2(0.4, 0.3), BackgroundTransparency = 1, Round = true, Stroke = 2.2, StrokeColor = c:Lerp(INK, 0.45)})
		sh(ctx, {Position = P2(0.5, 0.6), Size = P2(0.8, 0.66), BackgroundColor3 = c, Round = 0.3, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.44), Size = P2(0.8, 0.32), BackgroundColor3 = c:Lerp(WHITE2, 0.2), Round = 0.4})
		sh(ctx, {Position = P2(0.5, 0.74), Size = P2(0.46, 0.24), BackgroundColor3 = c:Lerp(INK, 0.2), Round = 0.35})
		sh(ctx, {Position = P2(0.5, 0.56), Size = P2(0.16, 0.16), BackgroundColor3 = GOLD, Round = 0.3})
	end
	D.book = function(ctx, c)
		sh(ctx, {Position = P2(0.56, 0.53), Size = P2(0.64, 0.78), BackgroundColor3 = rgb(250, 244, 225), Round = 0.12})
		sh(ctx, {Position = P2(0.46, 0.5), Size = P2(0.66, 0.8), BackgroundColor3 = c, Round = 0.14, Shade = true})
		sh(ctx, {Position = P2(0.2, 0.5), Size = P2(0.1, 0.78), BackgroundColor3 = c:Lerp(INK, 0.35), Stroke = false})
		sh(ctx, {Position = P2(0.5, 0.36), Size = P2(0.36, 0.14), BackgroundColor3 = WHITE2, Round = 0.4, Stroke = false})
		sh(ctx, {Position = P2(0.5, 0.56), Size = P2(0.26, 0.07), BackgroundColor3 = c:Lerp(WHITE2, 0.45), Round = 0.5, Stroke = false})
		sh(ctx, {Position = P2(0.66, 0.92), Size = P2(0.1, 0.2), BackgroundColor3 = rgb(235, 60, 70), Stroke = false})
	end
	D.gift = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.66), Size = P2(0.72, 0.54), BackgroundColor3 = c, Round = 0.14, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.4), Size = P2(0.86, 0.2), BackgroundColor3 = c:Lerp(WHITE2, 0.2), Round = 0.25})
		sh(ctx, {Position = P2(0.5, 0.62), Size = P2(0.15, 0.66), BackgroundColor3 = GOLD, Stroke = false})
		sh(ctx, {Position = P2(0.36, 0.21), Size = P2(0.28, 0.2), BackgroundColor3 = GOLD, Round = true, Rotation = -28})
		sh(ctx, {Position = P2(0.64, 0.21), Size = P2(0.28, 0.2), BackgroundColor3 = GOLD, Round = true, Rotation = 28})
		sh(ctx, {Position = P2(0.5, 0.27), Size = P2(0.16, 0.16), BackgroundColor3 = GOLD:Lerp(WHITE2, 0.3), Round = true})
	end
	D.home = function(ctx, c)
		sh(ctx, {Position = P2(0.74, 0.3), Size = P2(0.13, 0.24), BackgroundColor3 = rgb(200, 70, 60)})
		sh(ctx, {Position = P2(0.5, 0.44), Size = P2(0.6, 0.6), BackgroundColor3 = rgb(235, 80, 70), Rotation = 45, Round = 0.12})
		sh(ctx, {Position = P2(0.5, 0.7), Size = P2(0.64, 0.44), BackgroundColor3 = c, Round = 0.1, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.79), Size = P2(0.2, 0.26), BackgroundColor3 = rgb(150, 95, 55), Round = 0.3})
		sh(ctx, {Position = P2(0.3, 0.64), Size = P2(0.14, 0.14), BackgroundColor3 = rgb(150, 220, 255), Round = 0.2})
		sh(ctx, {Position = P2(0.7, 0.64), Size = P2(0.14, 0.14), BackgroundColor3 = rgb(150, 220, 255), Round = 0.2})
	end
	D.trail = function(ctx, c)
		for k = 0, 2 do
			sh(ctx, {Position = P2(0.36 + k * 0.03, 0.62 - k * 0.12), Size = P2(0.62 - k * 0.1, 0.13), Rotation = -32, BackgroundColor3 = c:Lerp(WHITE2, k * 0.2), Round = true, Stroke = false, Fade = true})
		end
		sh(ctx, {Position = P2(0.68, 0.33), Size = P2(0.36, 0.36), BackgroundColor3 = c, Round = true, Shade = true})
		sh(ctx, {Position = P2(0.63, 0.28), Size = P2(0.12, 0.12), BackgroundColor3 = WHITE2, Round = true, Stroke = false})
	end
	D.bolt = function(ctx, c)
		local parts = {
			{Position = P2(0.58, 0.28), Size = P2(0.22, 0.48), Rotation = 24},
			{Position = P2(0.5, 0.5), Size = P2(0.5, 0.17), Rotation = -12},
			{Position = P2(0.42, 0.72), Size = P2(0.22, 0.48), Rotation = 24},
		}
		for _, p in ipairs(parts) do outlined(ctx, p) end
		for _, p in ipairs(parts) do
			p.BackgroundColor3 = c
			p.Stroke = false
			sh(ctx, p)
		end
		sh(ctx, {Position = P2(0.6, 0.22), Size = P2(0.07, 0.22), Rotation = 24, BackgroundColor3 = WHITE2, BackgroundTransparency = 0.3, Stroke = false})
	end
	D.boot = function(ctx, c) -- a sporty sneaker, side view, running to the right
		local dark, light = c:Lerp(INK, 0.35), c:Lerp(WHITE2, 0.35)
		-- two little speed lines behind it
		sh(ctx, {Position = P2(0.08, 0.5), Size = P2(0.14, 0.06), BackgroundColor3 = WHITE2, Round = true, Stroke = 0.6})
		sh(ctx, {Position = P2(0.1, 0.64), Size = P2(0.1, 0.06), BackgroundColor3 = WHITE2, Round = true, Stroke = 0.6})
		-- the shoe: heel + toe in one smooth shape, a tongue on top
		sh(ctx, {Position = P2(0.42, 0.33), Size = P2(0.18, 0.22), Rotation = -10, BackgroundColor3 = light, Round = 0.4})
		sh(ctx, {Position = P2(0.35, 0.55), Size = P2(0.36, 0.4), BackgroundColor3 = c, Round = 0.38, Shade = true})
		sh(ctx, {Position = P2(0.62, 0.64), Size = P2(0.6, 0.26), BackgroundColor3 = c, Round = 0.5, Shade = true})
		-- white toe cap, a stripe on the side, laces, a dark heel tab
		sh(ctx, {Position = P2(0.83, 0.67), Size = P2(0.2, 0.18), BackgroundColor3 = WHITE2, Round = 0.5, Stroke = 0.7})
		sh(ctx, {Position = P2(0.5, 0.62), Size = P2(0.34, 0.07), Rotation = -14, BackgroundColor3 = WHITE2, Round = true, Stroke = false})
		for k = 0, 2 do
			sh(ctx, {Position = P2(0.47 + k * 0.08, 0.45 + k * 0.04), Size = P2(0.12, 0.045), Rotation = -30, BackgroundColor3 = WHITE2, Round = true, Stroke = false})
		end
		sh(ctx, {Position = P2(0.18, 0.5), Size = P2(0.06, 0.2), BackgroundColor3 = dark, Round = 0.4, Stroke = false})
		-- thick white sole with a coloured line
		sh(ctx, {Position = P2(0.54, 0.83), Size = P2(0.86, 0.15), BackgroundColor3 = WHITE2, Round = 0.5})
		sh(ctx, {Position = P2(0.54, 0.8), Size = P2(0.8, 0.035), BackgroundColor3 = dark, Round = true, Stroke = false})
	end
	D.cash = function(ctx, c)
		sh(ctx, {Position = P2(0.56, 0.58), Size = P2(0.8, 0.46), Rotation = -10, BackgroundColor3 = c:Lerp(INK, 0.3), Round = 0.14})
		sh(ctx, {Position = P2(0.48, 0.48), Size = P2(0.8, 0.46), BackgroundColor3 = c, Round = 0.14, Shade = true})
		sh(ctx, {Position = P2(0.48, 0.48), Size = P2(0.66, 0.32), BackgroundTransparency = 1, Round = 0.14, Stroke = 0.8, StrokeColor = c:Lerp(WHITE2, 0.45)})
		local coin = sh(ctx, {Position = P2(0.48, 0.48), Size = P2(0.24, 0.24), BackgroundColor3 = c:Lerp(WHITE2, 0.35), Round = true, Stroke = false})
		textIn(coin, "$", c:Lerp(INK, 0.4))
	end
	D.coin = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.52), Size = P2(0.84, 0.84), BackgroundColor3 = c:Lerp(INK, 0.25), Round = true})
		sh(ctx, {Position = P2(0.5, 0.47), Size = P2(0.84, 0.84), BackgroundColor3 = c, Round = true, Shade = true})
		local inner = sh(ctx, {Position = P2(0.5, 0.47), Size = P2(0.58, 0.58), BackgroundColor3 = c:Lerp(WHITE2, 0.25), Round = true, Stroke = 0.7, StrokeColor = c:Lerp(INK, 0.3)})
		textIn(inner, "$", c:Lerp(INK, 0.45))
	end
	D.star = function(ctx, c)
		local a = {Position = P2(0.5, 0.5), Size = P2(0.58, 0.58), Rotation = 45, Round = 0.12}
		local b = {Position = P2(0.5, 0.5), Size = P2(0.58, 0.58), Rotation = 0, Round = 0.12}
		outlined(ctx, a)
		outlined(ctx, b)
		a.BackgroundColor3, a.Stroke = c, false
		b.BackgroundColor3, b.Stroke = c, false
		sh(ctx, a)
		sh(ctx, b)
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.3, 0.3), BackgroundColor3 = c:Lerp(WHITE2, 0.6), Round = true, Stroke = false})
	end
	D.moon = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.78, 0.78), BackgroundColor3 = c, Round = true, Shade = true})
		for _, cr in ipairs({{0.38, 0.38, 0.2}, {0.62, 0.6, 0.16}, {0.4, 0.68, 0.1}}) do
			sh(ctx, {Position = P2(cr[1], cr[2]), Size = P2(cr[3], cr[3]), BackgroundColor3 = c:Lerp(INK, 0.2), Round = true, Stroke = false})
		end
	end
	D.sun = function(ctx, c)
		for k = 0, 7 do
			local a = k * math.pi / 4
			sh(ctx, {Position = P2(0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36), Size = P2(0.2, 0.1), Rotation = math.deg(a), BackgroundColor3 = c, Round = true})
		end
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.5, 0.5), BackgroundColor3 = c, Round = true, Shade = true})
	end
	D.down = function(ctx, c)
		local shaft = {Position = P2(0.5, 0.32), Size = P2(0.26, 0.44), Round = 0.2}
		local head = {Position = P2(0.5, 0.6), Size = P2(0.46, 0.46), Rotation = 45, Round = 0.12}
		outlined(ctx, head)
		outlined(ctx, shaft)
		head.BackgroundColor3, head.Stroke = c, false
		shaft.BackgroundColor3, shaft.Stroke = c, false
		sh(ctx, head)
		sh(ctx, shaft)
	end
	D.arrow = function(ctx, c) -- pointing right
		local shaft = {Position = P2(0.34, 0.5), Size = P2(0.44, 0.26), Round = 0.2}
		local head = {Position = P2(0.6, 0.5), Size = P2(0.46, 0.46), Rotation = 45, Round = 0.12}
		outlined(ctx, head)
		outlined(ctx, shaft)
		head.BackgroundColor3, head.Stroke = c, false
		shaft.BackgroundColor3, shaft.Stroke = c, false
		sh(ctx, head)
		sh(ctx, shaft)
	end
	D.close = function(ctx, c)
		for _, r in ipairs({45, -45}) do sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.74, 0.2), Rotation = r, BackgroundColor3 = c, Round = true}) end
	end
	D.check = function(ctx, c)
		sh(ctx, {Position = P2(0.34, 0.6), Size = P2(0.36, 0.18), Rotation = 45, BackgroundColor3 = c, Round = true})
		sh(ctx, {Position = P2(0.6, 0.48), Size = P2(0.62, 0.18), Rotation = -50, BackgroundColor3 = c, Round = true})
	end
	D.heart = function(ctx, c)
		local l = {Position = P2(0.34, 0.38), Size = P2(0.42, 0.42), Round = true}
		local r = {Position = P2(0.66, 0.38), Size = P2(0.42, 0.42), Round = true}
		local b = {Position = P2(0.5, 0.56), Size = P2(0.44, 0.44), Rotation = 45, Round = 0.1}
		for _, p in ipairs({l, r, b}) do outlined(ctx, p) end
		for _, p in ipairs({l, r, b}) do
			p.BackgroundColor3, p.Stroke = c, false
			sh(ctx, p)
		end
		sh(ctx, {Position = P2(0.32, 0.34), Size = P2(0.12, 0.12), BackgroundColor3 = WHITE2, BackgroundTransparency = 0.2, Round = true, Stroke = false})
	end
	D.box = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.54), Size = P2(0.78, 0.7), BackgroundColor3 = c, Round = 0.1, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.3), Size = P2(0.84, 0.18), BackgroundColor3 = c:Lerp(INK, 0.2), Round = 0.2})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.18, 0.74), BackgroundColor3 = rgb(225, 190, 130), Stroke = false})
		sh(ctx, {Position = P2(0.5, 0.68), Size = P2(0.4, 0.16), BackgroundColor3 = rgb(250, 246, 235), Round = 0.2, Stroke = 0.6})
	end
	D.lock = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.34), Size = P2(0.46, 0.46), BackgroundTransparency = 1, Round = true, Stroke = 2.4, StrokeColor = rgb(170, 175, 190)})
		sh(ctx, {Position = P2(0.5, 0.64), Size = P2(0.7, 0.5), BackgroundColor3 = c, Round = 0.2, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.62), Size = P2(0.12, 0.2), BackgroundColor3 = INK, Round = true, Stroke = false})
	end
	D.skull = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.44), Size = P2(0.74, 0.66), BackgroundColor3 = c, Round = 0.45, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.78), Size = P2(0.44, 0.24), BackgroundColor3 = c, Round = 0.25})
		for _, sx in ipairs({-1, 1}) do sh(ctx, {Position = P2(0.5 + sx * 0.16, 0.46), Size = P2(0.2, 0.22), BackgroundColor3 = INK, Round = true, Stroke = false}) end
		sh(ctx, {Position = P2(0.5, 0.62), Size = P2(0.08, 0.1), BackgroundColor3 = INK, Round = 0.3, Stroke = false})
	end
	-- NEW: crown (VIP), clover (luck), clock (time), gear (settings), calendar (daily),
	-- rebirth (round arrows), ticket (codes), shop (market stall)
	D.crown = function(ctx, c)
		for _, x in ipairs({0.24, 0.5, 0.76}) do
			sh(ctx, {Position = P2(x, (x == 0.5) and 0.36 or 0.42), Size = P2(0.26, 0.26), Rotation = 45, BackgroundColor3 = c, Round = 0.15})
		end
		sh(ctx, {Position = P2(0.5, 0.66), Size = P2(0.78, 0.36), BackgroundColor3 = c, Round = 0.15, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.82), Size = P2(0.8, 0.1), BackgroundColor3 = c:Lerp(INK, 0.25), Round = 0.4, Stroke = false})
		for _, x in ipairs({0.3, 0.5, 0.7}) do
			sh(ctx, {Position = P2(x, 0.64), Size = P2(0.11, 0.11), BackgroundColor3 = (x == 0.5) and rgb(255, 70, 90) or rgb(90, 200, 255), Round = true, Stroke = 0.6})
		end
	end
	D.clover = function(ctx, c)
		sh(ctx, {Position = P2(0.62, 0.8), Size = P2(0.08, 0.34), Rotation = -25, BackgroundColor3 = c:Lerp(INK, 0.25), Round = true})
		for _, o in ipairs({{0.5, 0.27}, {0.27, 0.5}, {0.73, 0.5}, {0.5, 0.73}}) do
			sh(ctx, {Position = P2(o[1], o[2]), Size = P2(0.36, 0.36), BackgroundColor3 = c, Round = true, Shade = true})
		end
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.18, 0.18), BackgroundColor3 = c:Lerp(WHITE2, 0.3), Round = true, Stroke = false})
	end
	D.clock = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.52), Size = P2(0.84, 0.84), BackgroundColor3 = c, Round = true, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.52), Size = P2(0.62, 0.62), BackgroundColor3 = rgb(250, 248, 240), Round = true, Stroke = 0.8})
		sh(ctx, {Position = P2(0.5, 0.42), Size = P2(0.08, 0.24), BackgroundColor3 = INK, Round = true, Stroke = false})
		sh(ctx, {Position = P2(0.59, 0.55), Size = P2(0.2, 0.08), Rotation = 30, BackgroundColor3 = INK, Round = true, Stroke = false})
		sh(ctx, {Position = P2(0.5, 0.52), Size = P2(0.1, 0.1), BackgroundColor3 = rgb(255, 80, 90), Round = true, Stroke = false})
	end
	D.gear = function(ctx, c)
		for k = 0, 7 do
			local a = k * math.pi / 4
			sh(ctx, {Position = P2(0.5 + math.cos(a) * 0.34, 0.5 + math.sin(a) * 0.34), Size = P2(0.2, 0.2), Rotation = math.deg(a), BackgroundColor3 = c, Round = 0.2})
		end
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.66, 0.66), BackgroundColor3 = c, Round = true, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.26, 0.26), BackgroundColor3 = c:Lerp(INK, 0.55), Round = true})
	end
	D.calendar = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.58), Size = P2(0.8, 0.7), BackgroundColor3 = rgb(250, 248, 240), Round = 0.15})
		sh(ctx, {Position = P2(0.5, 0.32), Size = P2(0.8, 0.22), BackgroundColor3 = c, Round = 0.3, Shade = true})
		for _, x in ipairs({0.32, 0.68}) do sh(ctx, {Position = P2(x, 0.2), Size = P2(0.09, 0.2), BackgroundColor3 = INK, Round = true, Stroke = false}) end
		for row = 0, 1 do
			for col = 0, 2 do
				sh(ctx, {Position = P2(0.3 + col * 0.2, 0.58 + row * 0.18), Size = P2(0.12, 0.1), BackgroundColor3 = (row == 1 and col == 2) and c or rgb(190, 186, 210), Round = 0.3, Stroke = false})
			end
		end
	end
	D.rebirth = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.66, 0.66), BackgroundTransparency = 1, Round = true, Stroke = 3.2, StrokeColor = c})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.76, 0.76), BackgroundTransparency = 1, Round = true, Stroke = 1})
		sh(ctx, {Position = P2(0.8, 0.3), Size = P2(0.26, 0.26), Rotation = 45, BackgroundColor3 = c, Round = 0.15})
		sh(ctx, {Position = P2(0.2, 0.7), Size = P2(0.26, 0.26), Rotation = 45, BackgroundColor3 = c, Round = 0.15})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.24, 0.24), BackgroundColor3 = c:Lerp(WHITE2, 0.4), Round = true})
	end
	D.ticket = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.84, 0.52), Rotation = -14, BackgroundColor3 = c, Round = 0.18, Shade = true})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.6, 0.3), Rotation = -14, BackgroundTransparency = 1, Round = 0.2, Stroke = 0.8, StrokeColor = c:Lerp(WHITE2, 0.5)})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.14, 0.14), Rotation = 31, BackgroundColor3 = GOLD, Round = 0.2})
	end
	D.shop = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.66), Size = P2(0.74, 0.48), BackgroundColor3 = rgb(250, 244, 230), Round = 0.1})
		sh(ctx, {Position = P2(0.5, 0.74), Size = P2(0.24, 0.32), BackgroundColor3 = rgb(160, 105, 60), Round = 0.2})
		sh(ctx, {Position = P2(0.5, 0.34), Size = P2(0.9, 0.26), BackgroundColor3 = c, Round = 0.3, Shade = true})
		for k = 0, 2 do sh(ctx, {Position = P2(0.27 + k * 0.23, 0.34), Size = P2(0.1, 0.24), BackgroundColor3 = WHITE2, Stroke = false}) end
	end
	D.plus = function(ctx, c)
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.24, 0.76), BackgroundColor3 = c, Round = 0.3})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.76, 0.24), BackgroundColor3 = c, Round = 0.3})
		sh(ctx, {Position = P2(0.5, 0.5), Size = P2(0.22, 0.22), BackgroundColor3 = c, Round = 0.2, Stroke = false})
	end
	ICON.draw = D
	-- the icon's outline gets thicker on bigger icons
	function ICON.new(name, parent, size, pos, color, anchor)
		local holder = new("Frame", {Name = "Icon_" .. name, BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new(), AnchorPoint = anchor or Vector2.new()}, parent)
		local px = (size.X.Offset > 0) and size.X.Offset or 40
		local ctx = {root = holder, z = (parent and parent:IsA("GuiObject")) and parent.ZIndex or 1, w = math.clamp(px / 18, 1.2, 3.4)}
		holder.ZIndex = ctx.z
		local fn = D[name] or D.star
		fn(ctx, color or GOLD)
		return holder
	end
end
function UI.icon(name, parent, size, pos, color, anchor)
	return ICON.new(name, parent, size, pos, color, anchor)
end

------------------------------------------------------------------
-- CHUNKY BUTTON: a coloured face on a darker "shadow" - press it and it sinks down.
-- UI.button(parent, {Text, Color, Size, Position, AnchorPoint, Icon, TextSize, LayoutOrder, ZIndex})
-- -> btn table: {holder, face, label, setText(t), setColor(c), setEnabled(on), Activated}
------------------------------------------------------------------
function UI.button(parent, opt)
	opt = opt or {}
	local color = opt.Color or C.green
	local z = opt.ZIndex or 1
	local holder = new("Frame", {Name = opt.Name or "Button", BackgroundTransparency = 1, Size = opt.Size or UDim2.fromOffset(140, 44),
		Position = opt.Position or UDim2.new(), AnchorPoint = opt.AnchorPoint or Vector2.new(), LayoutOrder = opt.LayoutOrder or 0, ZIndex = z}, parent)
	local DEPTH = opt.Depth or 4
	local shadow = new("Frame", {Name = "Shadow", Position = UDim2.fromOffset(0, DEPTH), Size = UDim2.new(1, 0, 1, -DEPTH),
		BackgroundColor3 = color:Lerp(C.black, 0.45), BorderSizePixel = 0, ZIndex = z}, holder)
	UI.corner(shadow, opt.Radius or 7)
	UI.stroke(shadow, 3.5)
	local face = new("TextButton", {Name = "Face", Size = UDim2.new(1, 0, 1, -DEPTH), BackgroundColor3 = color, Text = "", AutoButtonColor = false,
		BorderSizePixel = 0, ZIndex = z + 1}, holder)
	UI.corner(face, opt.Radius or 7)
	UI.stroke(face, 3.5)
	local rim = new("Frame", {Name = "Rim", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1, ZIndex = z + 1}, face)
	UI.corner(rim, math.max(3, (opt.Radius or 7) - 3))
	UI.stroke(rim, 2, C.white, 0.45)
	UI.shade(face, C.white, rgb(178, 178, 192))
	-- a soft shine on the top half
	local shine = new("Frame", {Name = "Shine", Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0.42, -3), BackgroundColor3 = C.white,
		BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = z + 1}, face)
	UI.corner(shine, opt.Radius and math.max(4, opt.Radius - 3) or 9)
	local textLeft = 8
	local iconFrame
	if opt.Icon then
		local isz = opt.IconSize or 28
		iconFrame = UI.icon(opt.Icon, face, UDim2.fromOffset(isz, isz), UDim2.new(0, 8, 0.5, 0), opt.IconColor or color:Lerp(C.white, 0.25), Vector2.new(0, 0.5))
		iconFrame.ZIndex = z + 2
		textLeft = 8 + isz + 4
	end
	local label = UI.label(face, opt.Text or "", {Position = UDim2.fromOffset(textLeft, 3), Size = UDim2.new(1, -textLeft - 8, 1, -6),
		Max = opt.TextSize or 22, ZIndex = z + 3, Stroke = 2, TextWrapped = false})
	local btn = {holder = holder, face = face, label = label, shadow = shadow, icon = iconFrame, enabled = true, color = color}
	local baseY = 0
	face.MouseButton1Down:Connect(function()
		if btn.enabled then UI.tween(face, 0.05, {Position = UDim2.fromOffset(0, DEPTH - 1)}) end
	end)
	local function up() UI.tween(face, 0.12, {Position = UDim2.fromOffset(0, baseY)}, Enum.EasingStyle.Back) end
	face.MouseButton1Up:Connect(up)
	face.MouseLeave:Connect(up)
	face.MouseEnter:Connect(function()
		if btn.enabled then face.BackgroundColor3 = btn.color:Lerp(C.white, 0.12) end
	end)
	face.MouseLeave:Connect(function() face.BackgroundColor3 = btn.enabled and btn.color or C.grey end)
	face.Activated:Connect(function()
		if btn.enabled then SFX.play("click", 2.2 + math.random() * 0.4) else SFX.play("error") end
	end)
	btn.Activated = face.Activated
	function btn.setText(t) UI.setText(label, t) end
	function btn.setColor(col)
		btn.color = col
		if btn.enabled then face.BackgroundColor3 = col end
		shadow.BackgroundColor3 = (btn.enabled and col or C.grey):Lerp(C.black, 0.45)
	end
	function btn.setEnabled(on)
		btn.enabled = on
		face.BackgroundColor3 = on and btn.color or C.grey
		shadow.BackgroundColor3 = (on and btn.color or C.grey):Lerp(C.black, 0.45)
		label.TextColor3 = on and C.white or rgb(215, 212, 230)
	end
	return btn
end

-- a toggle switch (Settings window). Returns {holder, set(on), Changed (BindableEvent.Event)}
function UI.switch(parent, on, opt)
	opt = opt or {}
	local z = opt.ZIndex or 1
	local holder = new("TextButton", {Size = UDim2.fromOffset(74, 36), BackgroundColor3 = C.grey, Text = "", AutoButtonColor = false,
		Position = opt.Position or UDim2.new(), AnchorPoint = opt.AnchorPoint or Vector2.new(), ZIndex = z}, parent)
	UI.corner(holder, true)
	UI.stroke(holder, 2.5)
	local knob = new("Frame", {Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.white, ZIndex = z + 1}, holder)
	UI.corner(knob, true)
	UI.stroke(knob, 2)
	local changed = Instance.new("BindableEvent")
	local sw = {holder = holder, on = on, Changed = changed.Event}
	function sw.set(v, silent)
		sw.on = v
		UI.tween(knob, 0.15, {Position = v and UDim2.fromOffset(42, 4) or UDim2.fromOffset(4, 4)}, Enum.EasingStyle.Back)
		holder.BackgroundColor3 = v and C.green or C.grey
		if not silent then changed:Fire(v) end
	end
	holder.Activated:Connect(function()
		SFX.play("click", 2.4)
		sw.set(not sw.on)
	end)
	sw.set(on, true)
	return sw
end

-- a red notification bubble on the corner of a button
function UI.badge(parent, z)
	local b = new("Frame", {Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = C.red, Visible = false, ZIndex = (z or 1) + 5}, parent)
	UI.corner(b, true)
	UI.stroke(b, 2, C.white)
	local t = UI.label(b, "!", {Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Max = 16, Stroke = 1.5, ZIndex = (z or 1) + 6})
	local s = new("UIScale", {}, b)
	return {frame = b, label = t, scale = s, set = function(n)
		local show = (n == true) or (type(n) == "number" and n > 0)
		b.Visible = show
		if show then UI.setText(t, (type(n) == "number") and tostring(math.min(n, 99)) or "!") end
	end}
end

-- a card: rounded, outlined, soft gradient
function UI.card(parent, color, props)
	local f = new("Frame", {BackgroundColor3 = color or C.card, BorderSizePixel = 0}, parent)
	if props then
		for k, v in pairs(props) do f[k] = v end
	end
	UI.corner(f, 6)
	UI.stroke(f, 3)
	UI.shade(f, C.white, rgb(185, 182, 200))
	return f
end

-- a progress bar. Returns {frame, fill, label, set(fraction, text)}
function UI.bar(parent, props, color)
	local back = new("Frame", {BackgroundColor3 = C.panelDark, BorderSizePixel = 0}, parent)
	for k, v in pairs(props or {}) do back[k] = v end
	UI.corner(back, true)
	UI.stroke(back, 2)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or C.green, BorderSizePixel = 0, ZIndex = back.ZIndex}, back)
	UI.corner(fill, true)
	UI.shade(fill, C.white, rgb(190, 190, 200))
	local label = UI.label(back, "", {Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Max = 16, Stroke = 1.5, ZIndex = back.ZIndex + 1})
	return {frame = back, fill = fill, label = label, set = function(frac, text)
		fill.Size = UDim2.fromScale(math.clamp(frac or 0, 0, 1), 1)
		fill.Visible = (frac or 0) > 0.005
		if text then UI.setText(label, text) end
	end}
end

-- a grid that grows with its content (inside scrolling pages)
function UI.grid(parent, cell, gap, order)
	local f = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0}, parent)
	new("UIGridLayout", {CellSize = cell, CellPadding = UDim2.fromOffset(gap or 10, gap or 10), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder}, f)
	return f
end

-- a section title: label between two fading lines
function UI.section(parent, text, color, order)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order or 0}, parent)
	for _, sx in ipairs({0, 1}) do
		local line = new("Frame", {AnchorPoint = Vector2.new(sx, 0.5), Position = UDim2.new(sx, 0, 0.5, 0), Size = UDim2.new(0.2, 0, 0, 3),
			BackgroundColor3 = color or C.yellow, BorderSizePixel = 0}, row)
		UI.corner(line, true)
		new("UIGradient", {Transparency = NumberSequence.new((sx == 0) and 1 or 0, (sx == 0) and 0 or 1)}, line)
	end
	local l = UI.label(row, text, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.56, 0, 1, 0), Max = 22, TextColor3 = color or C.yellow})
	return l, row
end

------------------------------------------------------------------
-- ROOT: one ScreenGui for the HUD + windows, scaled with ONE UIScale.
-- The root frame is made 1/scale big, so after scaling it fills the screen exactly and
-- everything inside can be laid out in "1280 x 720" coordinates.
------------------------------------------------------------------
function UI.initRoot(playerGui)
	local gui = new("ScreenGui", {Name = "StealABoxUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false, DisplayOrder = 5}, playerGui)
	local root = new("Frame", {Name = "Root", BackgroundTransparency = 1, BorderSizePixel = 0}, gui)
	local scale = new("UIScale", {}, root)
	-- full-screen layers that ignore the top bar: under the HUD (screen edges) and over it (flashes, confetti)
	local under = new("ScreenGui", {Name = "StealABoxUnder", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
	local over = new("ScreenGui", {Name = "StealABoxOver", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
	UI.gui, UI.root, UI.under, UI.over, UI.rootScale = gui, root, under, over, scale
	UI.scale = 1
	UI.vw, UI.vh = UI.REF_W, UI.REF_H -- the root's size in UI units
	local function rescale()
		local size = gui.AbsoluteSize
		if size.X < 2 or size.Y < 2 then return end
		local s = math.clamp(math.min(size.X / UI.REF_W, size.Y / UI.REF_H), 0.5, 1.5)
		UI.scale = s
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		UI.vw, UI.vh = size.X / s, size.Y / s
		if UI.refitWindows then UI.refitWindows() end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	rescale()
	task.defer(rescale)

	-- the dark layer behind an open window (click it to close the window)
	UI.dim = new("TextButton", {Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(8, 6, 18), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, Visible = false, ZIndex = 50}, root)
	UI.blur = new("BlurEffect", {Name = "StealABoxBlur", Size = 0}, game:GetService("Lighting"))
	UI.dim.Activated:Connect(function() UI.close() end)
	return gui, root
end

------------------------------------------------------------------
-- WINDOWS: one at a time, centred, springy. A coloured title bar with an icon, a red close
-- button, optional tabs, and scrolling pages that grow with their content.
--   UI.window({Name, Title, Icon, Color, Size = Vector2, Tabs = {{Key, Label, Icon}}})
--   win.pages[key] (or win.page) = the ScrollingFrame to fill
--   win.onOpen = function() ... end  (refresh when it opens)
------------------------------------------------------------------
local windows = {}
local openWin = nil
-- the area windows use: below one row of notifications, above the bottom edge
local WIN_TOP, WIN_BOTTOM = 84, 10
UI.winLeft = 12 -- windows stay right of this x (the HUD menu sets it, so windows never cover the menu)
local function fitWindow(win)
	local vw = UI.vw or 1280
	local availH = math.max(200, (UI.vh or 720) - WIN_TOP - WIN_BOTTOM)
	local left = UI.winLeft or 12
	local w = math.min(win.size.X, math.max(320, vw - left - 12))
	local h = math.min(win.size.Y, availH)
	if win.docked then
		h = math.min(win.size.Y, availH - 90) -- room for the big button under it
		win.frame.Size = UDim2.fromOffset(w, h)
		win.centerX = vw - (UI.dockRight or 240) - w / 2
		win.centerY = WIN_TOP + (availH - 80) / 2
		UI.dockLeft = win.centerX - w / 2 - 60 -- (the red ">" tab sticks out on the left)
		return win.centerY
	end
	win.frame.Size = UDim2.fromOffset(w, h)
	win.centerY = WIN_TOP + availH / 2
	-- centred on the screen when it fits, otherwise pushed right of the menu
	win.centerX = math.max(vw / 2, left + w / 2)
	return win.centerY
end
function UI.refitWindows()
	for _, win in pairs(windows) do
		fitWindow(win)
		if win.frame.Visible then win.frame.Position = UDim2.fromOffset(win.centerX, win.centerY) end
	end
end
local windowChanged = Instance.new("BindableEvent")
UI.WindowChanged = windowChanged.Event -- fires (name or nil)

local function makePage(parent, z)
	local page = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 7,
		ScrollBarImageColor3 = rgb(150, 145, 185), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ZIndex = z}, parent)
	UI.padding(page, 10, 10, 14, 10, 10)
	UI.list(page, 10, nil, Enum.HorizontalAlignment.Center)
	return page
end

function UI.window(opt)
	local docked = opt.Docked == true
	local color = rgb(255, 150, 30) -- every window has the same orange header (like the screenshots)
	local size = opt.Size or Vector2.new(760, 470)
	local frame = new("Frame", {Name = opt.Name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color:Lerp(C.panel, 0.45), Visible = false, ZIndex = 60}, UI.root)
	UI.corner(frame, 8)
	UI.stroke(frame, 4)
	UI.shade(frame, C.white, rgb(175, 172, 192))
	frame.BackgroundColor3 = rgb(44, 44, 48)
	local scale = new("UIScale", {}, frame)
	-- title bar
	local header = new("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = color, BorderSizePixel = 0}, frame)
	UI.corner(header, 22)
	UI.shade(header, color:Lerp(C.white, 0.35), color:Lerp(C.black, 0.12))
	new("Frame", {Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = color:Lerp(C.black, 0.1), BorderSizePixel = 0}, header)
	local sheen = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0}, header)
	UI.corner(sheen, 22)
	local sheenGrad = new("UIGradient", {Rotation = 20, Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1)})}, sheen)
	local titleX = 18
	if opt.Icon then
		UI.icon(opt.Icon, header, UDim2.fromOffset(46, 46), UDim2.fromOffset(14, 6), color:Lerp(C.white, 0.15))
		titleX = 70
	end
	local title = UI.label(header, opt.Title or opt.Name, {Position = UDim2.fromOffset(titleX, 9), Size = UDim2.new(1, -titleX - 70, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left, Max = 32, Stroke = 3, TextWrapped = false})
	local close
	if docked then
		-- side panel: a red square ">" tab on its left edge closes it
		header.Size = UDim2.new(1, 0, 0, 54)
		close = new("TextButton", {Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -8, 0.5, 0), Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = rgb(230, 30, 40), Text = "", AutoButtonColor = false}, frame)
		UI.corner(close, 6)
		UI.stroke(close, 3.5)
		UI.shade(close, C.white, rgb(190, 190, 190))
		UI.label(close, ">", {Size = UDim2.fromScale(1, 1), Max = 36, Stroke = 3})
		title.Size = UDim2.new(1, -titleX - 200, 0, 40)
		if opt.HeaderButton then
			opt.HeaderButton.Size = UDim2.fromOffset(180, 40)
			opt.HeaderButton.AnchorPoint = Vector2.new(1, 0.5)
			opt.HeaderButton.Position = UDim2.new(1, -10, 0.5, 0)
			opt.HeaderButton.Depth = 3
			opt.HeaderButton.ZIndex = 3
			opt.HeaderButton.TextSize = opt.HeaderButton.TextSize or 18
		end
	else
		close = new("TextButton", {Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0, 29), Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = rgb(230, 30, 40), Text = "", AutoButtonColor = false}, frame)
		UI.corner(close, 6)
		UI.stroke(close, 3.5)
		UI.shade(close, C.white, rgb(190, 190, 190))
		UI.icon("close", close, UDim2.fromOffset(26, 26), UDim2.fromScale(0.5, 0.5), C.white, Vector2.new(0.5, 0.5))
	end
	UI.pressable(close)
	-- body
	local body = new("Frame", {Name = "Body", Position = UDim2.fromOffset(8, 64), Size = UDim2.new(1, -16, 1, -72), BackgroundColor3 = color:Lerp(C.panelDark, 0.9), BorderSizePixel = 0}, frame)
	UI.corner(body, 16)
	UI.stroke(body, 2.5, color:Lerp(C.ink, 0.5))
	local headerBtn, footerBtn
	-- dark charcoal body with a faint grid (two striped gradients, no hundreds of frames)
	body.Position, body.Size = UDim2.fromOffset(6, 60), UDim2.new(1, -12, 1, -66)
	body.BackgroundColor3 = rgb(50, 50, 55)
	UI.corner(body, 4)
	for _, rot in ipairs({0, 90}) do
		local keys = {}
		for k = 0, 18 do
			table.insert(keys, NumberSequenceKeypoint.new(k / 18, (k % 2 == 0) and 0.93 or 1))
		end
		local grid = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, BackgroundTransparency = 0}, body)
		UI.corner(grid, 4)
		new("UIGradient", {Rotation = rot, Transparency = NumberSequence.new(keys)}, grid)
	end
	if docked then
		if opt.HeaderButton then headerBtn = UI.button(header, opt.HeaderButton) end
		if opt.Footer then
			opt.Footer.Size = UDim2.new(1, -40, 0, 62)
			opt.Footer.AnchorPoint = Vector2.new(0.5, 0)
			opt.Footer.Position = UDim2.new(0.5, 0, 1, 12)
			opt.Footer.TextSize = opt.Footer.TextSize or 30
			opt.Footer.Depth = 6
			footerBtn = UI.button(frame, opt.Footer)
		end
	end
	local win = {name = opt.Name, frame = frame, body = body, header = header, title = title, scale = scale, sheen = sheenGrad,
		color = color, pages = {}, tabs = {}, tab = nil, size = size, docked = docked, headerBtn = headerBtn, footerBtn = footerBtn}
	if opt.Tabs then
		local tabRow = new("Frame", {Name = "Tabs", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 44), BackgroundTransparency = 1}, body)
		UI.list(tabRow, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		local pageHolder = new("Frame", {Name = "Pages", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), BackgroundTransparency = 1, ClipsDescendants = true}, body)
		local tabW = math.min(170, math.floor((size.X - 40 - (#opt.Tabs - 1) * 8) / #opt.Tabs))
		for i, t in ipairs(opt.Tabs) do
			local b = UI.button(tabRow, {Text = t.Label, Color = C.cardLight, Size = UDim2.fromOffset(tabW, 42), LayoutOrder = i, Icon = t.Icon, IconSize = 26, TextSize = 20, Depth = 3})
			b.setColor(rgb(110, 110, 122))
			local page = makePage(pageHolder)
			page.Visible = false
			win.pages[t.Key] = page
			win.tabs[t.Key] = b
			b.Activated:Connect(function() win.setTab(t.Key) end)
		end
		function win.setTab(key)
			win.tab = key
			for k, page in pairs(win.pages) do
				page.Visible = (k == key)
				win.tabs[k].setColor((k == key) and color or rgb(110, 110, 122))
			end
			if win.onTab then win.onTab(key) end
		end
		win.setTab(opt.Tabs[1].Key)
	else
		local page = makePage(body)
		win.pages.main = page
		win.page = page
	end
	close.Activated:Connect(function() if openWin == win then UI.close() end end)
	windows[opt.Name] = win
	return win
end

local function hideWin(win, instant)
	win.token = (win.token or 0) + 1
	if instant then
		win.frame.Visible = false
		return
	end
	local token = win.token
	SFX.play("close")
	UI.tween(win.scale, 0.16, {Scale = 0.75}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.16, function()
		if win.token == token then win.frame.Visible = false end
	end)
end

local function setDim(on)
	if on then
		UI.dim.Visible = true
		UI.tween(UI.dim, 0.25, {BackgroundTransparency = 0.45})
		UI.tween(UI.blur, 0.3, {Size = 14})
	else
		UI.tween(UI.dim, 0.2, {BackgroundTransparency = 1})
		UI.tween(UI.blur, 0.25, {Size = 0})
		task.delay(0.22, function() if not openWin or openWin.docked then UI.dim.Visible = false end end)
	end
end

function UI.open(name, tab)
	local win = windows[name]
	if not win then return end
	if openWin and openWin ~= win then hideWin(openWin, true) end
	if tab and win.setTab then win.setTab(tab) end
	if win.onOpen then
		local ok, err = pcall(win.onOpen)
		if not ok then warn("[Steal a Box] " .. name .. " window: " .. tostring(err)) end
	end
	local wasOpen = openWin == win
	openWin = win
	win.token = (win.token or 0) + 1
	win.frame.Visible = true
	setDim(not win.docked)
	local cy = fitWindow(win)
	if not wasOpen then
		SFX.play("open")
		win.scale.Scale = 0.6
		win.frame.Position = UDim2.fromOffset(win.centerX + (win.docked and 300 or 0), cy + (win.docked and 0 or 30))
		UI.tween(win.scale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
		UI.tween(win.frame, 0.35, {Position = UDim2.fromOffset(win.centerX, cy)}, Enum.EasingStyle.Quint)
		win.sheen.Offset = Vector2.new(-1, 0)
		UI.tween(win.sheen, 0.8, {Offset = Vector2.new(1, 0)})
	end
	windowChanged:Fire(name)
end

function UI.close()
	if not openWin then return end
	local win = openWin
	openWin = nil
	hideWin(win)
	setDim(false)
	if win.onClose then pcall(win.onClose) end
	windowChanged:Fire(nil)
end

function UI.toggle(name, tab)
	if openWin and openWin.name == name then UI.close() else UI.open(name, tab) end
end

function UI.isOpen(name)
	if name then return openWin ~= nil and openWin.name == name end
	return openWin ~= nil
end

function UI.getWindow(name) return windows[name] end
-- a normal window (dims the screen) is open - not just a side panel
function UI.isModalOpen() return openWin ~= nil and not openWin.docked end

-- a little turning 3D item in a ViewportFrame. Returns vp, list (pose it with Config.PoseItemModel)
function UI.itemView(parent, item, props)
	local vp = new("ViewportFrame", {BackgroundTransparency = 1, LightColor = C.white, Ambient = rgb(175, 175, 175), LightDirection = Vector3.new(-1, -1, -1)}, parent)
	for k, v in pairs(props or {}) do vp[k] = v end
	local model, list = Config.BuildItemModel(item, 1, CFrame.new())
	model.Parent = vp
	vp.CurrentCamera = new("Camera", {FieldOfView = 34, CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -5), Vector3.new(0, 0, 0))}, vp)
	return vp, list, model
end

return UI
