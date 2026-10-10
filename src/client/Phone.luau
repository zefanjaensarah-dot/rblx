--[[ STEAL A BOX - the big phone on your treadmill: press E (or tap the screen) and play while you run.
     It looks like a real phone: a status bar (time + battery), a wallpaper, app icons that zoom open.
     Snake        swipe on the board, the big D-pad, or WASD / arrow keys. Up to 2 quick turns are queued.
                  Golden apples are worth 5 but vanish. It gets faster and faster.
     Block Blast  DRAG a piece onto the board (it floats above your finger) - or tap a piece, then tap the board.
                  Full rows and columns clear; clear again and again for COMBOS.
     Archery      press anywhere and pull BACK like a slingshot, let go to shoot. Watch the wind!
                  Head = 2, bullseye = 3. Reach the round's goal to go to the next round.
     While the phone is open your character doesn't walk with WASD / arrows / space, and closing the
     phone pauses the game. Only ONE RenderStepped runs, and only while the phone is open. ]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Phone = {}
local bests = {Snake = 0, BlockBlast = 0, Archery = 0}

local UI, C, new -- set in Phone.init
local V2 = Vector2.new
local S2 = UDim2.fromScale
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local function clamp(x, a, b) return (x < a) and a or ((x > b) and b or x) end
local function lerp(a, b, t) return a + (b - a) * t end
local function lerpV(a, b, t) return V2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
local function easeOut(t) t = clamp(t, 0, 1) return 1 - (1 - t) ^ 3 end
local function backOut(t)
	t = clamp(t, 0, 1)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
-- turn `cur` towards `target` (degrees) the short way round
local function turnTo(cur, target, k)
	local d = (target - cur + 540) % 360 - 180
	return cur + d * clamp(k, 0, 1)
end
local function offsetPos(base, dx, dy)
	return UDim2.new(base.X.Scale + dx, base.X.Offset, base.Y.Scale + dy, base.Y.Offset)
end

------------------------------------------------------------------
-- INPUT HELPERS
------------------------------------------------------------------
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end
-- the mouse position in the same space as AbsolutePosition (fallback only)
local function pointer()
	local ok, p = pcall(function() return UserInputService:GetMouseLocation() - GuiService:GetGuiInset() end)
	return ok and p or V2(0, 0)
end
-- where an input is on screen (InputObject.Position is already in AbsolutePosition space)
local function posOf(input)
	local ok, p = pcall(function() return input.Position end)
	if ok and p then return V2(p.X, p.Y) end
	return pointer()
end
-- a screen point as fractions (0..1) of `frame`
local function fracIn(frame, p)
	local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
	if as.X < 1 or as.Y < 1 then return 0.5, 0.5 end
	return (p.X - ap.X) / as.X, (p.Y - ap.Y) / as.Y
end
local function typing()
	local ok, tb = pcall(function() return UserInputService:GetFocusedTextBox() end)
	return ok and tb ~= nil
end
-- (looked up by the key's name)
local DIR_KEYS = {Up = "Up", W = "Up", Down = "Down", S = "Down", Left = "Left", A = "Left", Right = "Right", D = "Right"}
local function dirKey(kc)
	local ok, name = pcall(function() return kc.Name end)
	return ok and DIR_KEYS[name] or nil
end

------------------------------------------------------------------
-- BUILDING BLOCKS (frames, labels, chevrons)
------------------------------------------------------------------
local function frame(parent, props)
	local f = new("Frame", {BorderSizePixel = 0})
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end
-- r: true/nil = circle, < 1 = fraction of the size, >= 1 = pixels
local function round(f, r)
	local cr = (r == nil or r == true) and UDim.new(1, 0) or ((r < 1) and UDim.new(r, 0) or UDim.new(0, r))
	return new("UICorner", {CornerRadius = cr}, f)
end
local function grad(f, c0, c1, rot)
	return new("UIGradient", {Rotation = rot or 90, Color = ColorSequence.new(c0, c1)}, f)
end
local function square(f, ratio)
	return new("UIAspectRatioConstraint", {AspectRatio = ratio or 1, DominantAxis = Enum.DominantAxis.Width}, f)
end
-- a label that scales its text to the box (for numbers that change every frame: no text measuring)
local function text(parent, str, props)
	props = props or {}
	local l = new("TextLabel", {BackgroundTransparency = 1, FontFace = UI.Font, TextScaled = true, TextColor3 = WHITE, Text = str or "",
		Size = S2(1, 1), BorderSizePixel = 0})
	for k, v in pairs(props) do
		if k ~= "Stroke" and k ~= "MaxSize" then l[k] = v end
	end
	if (props.Stroke or 2) > 0 then
		new("UIStroke", {Thickness = props.Stroke or 2, Color = C.ink, LineJoinMode = Enum.LineJoinMode.Round}, l)
	end
	new("UITextSizeConstraint", {MaxTextSize = props.MaxSize or 64, MinTextSize = 1}, l)
	l.Parent = parent
	return l
end
-- a ">" made of two rounded bars; rotate the holder to point it (0 = right, 90 = down)
local function chevron(parent, color, size, z)
	local h = frame(parent, {BackgroundTransparency = 1, AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(size or 0.5, size or 0.5), ZIndex = z or 1})
	square(h)
	for _, s in ipairs({-1, 1}) do
		local b = frame(h, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.47, 0.5 + s * 0.17), Size = S2(0.66, 0.22), Rotation = s * 42,
			BackgroundColor3 = color or WHITE, ZIndex = z or 1})
		round(b, true)
		UI.stroke(b, 2, C.ink)
	end
	return h
end
-- a small round "pill" with a drop shadow look
local function pill(parent, color, props)
	local f = frame(parent, props)
	f.BackgroundColor3 = color
	round(f, true)
	UI.stroke(f, 2.5, C.ink)
	grad(f, WHITE, rgb(200, 200, 212))
	return f
end

------------------------------------------------------------------
-- PARTICLES: a fixed pool of little frames, reused (never created per frame)
-- positions are in "width units": x 0..1 across the parent, y 0..H down it (H = height / width)
------------------------------------------------------------------
local function makeParticles(parent, count, z)
	local P = {H = 1, live = {}}
	local pool, nextI = {}, 1
	for i = 1, count do
		local f = frame(parent, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.02, 0.02), Visible = false, ZIndex = z or 20})
		pool[i] = {f = f, corner = round(f, true)}
	end
	-- opts: g (gravity), drag, spin, rect (confetti), life
	function P.emit(x, y, vx, vy, color, size, opts)
		local p = pool[nextI]
		nextI = nextI % count + 1
		opts = opts or {}
		p.x, p.y, p.vx, p.vy, p.s, p.t = x, y, vx, vy, size, 0
		p.life = opts.life or (0.45 + math.random() * 0.35)
		p.g, p.drag, p.spin = opts.g or 1.4, opts.drag or 2, opts.spin
		p.fade = opts.fade ~= false
		p.f.BackgroundColor3 = color
		p.f.BackgroundTransparency = 0
		p.f.Rotation = opts.rect and math.random(0, 90) or 0
		p.corner.CornerRadius = opts.rect and UDim.new(0.2, 0) or UDim.new(1, 0)
		p.w = opts.rect and 0.6 or 1
		p.f.Visible = true
		P.live[p] = true
	end
	function P.burst(x, y, color, n, speed, size, opts)
		for _ = 1, n do
			local a = math.random() * math.pi * 2
			local sp = speed * (0.35 + math.random() * 0.65)
			local c = color
			if type(color) == "table" then c = color[math.random(1, #color)] end
			P.emit(x, y, math.cos(a) * sp, math.sin(a) * sp - speed * 0.35, c, size * (0.6 + math.random() * 0.7), opts)
		end
	end
	function P.update(dt)
		for p in pairs(P.live) do
			p.t = p.t + dt
			if p.t >= p.life then
				p.f.Visible = false
				P.live[p] = nil
			else
				local d = math.max(0, 1 - p.drag * dt)
				p.vx, p.vy = p.vx * d, p.vy * d + p.g * dt
				p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
				local k = p.t / p.life
				local s = p.s * (1 - k * 0.6)
				p.f.Position = S2(p.x, p.y / P.H)
				p.f.Size = S2(s, s * p.w / P.H)
				if p.fade then p.f.BackgroundTransparency = k * k end
				if p.spin then p.f.Rotation = p.f.Rotation + p.spin * dt end
			end
		end
	end
	function P.clear()
		for p in pairs(P.live) do p.f.Visible = false end
		P.live = {}
	end
	return P
end

------------------------------------------------------------------
-- POPUPS: "+1", "COMBO x3!", "3-2-1-GO"... a pool of labels that pop in, float up and fade
-- x, y are fractions of the parent
------------------------------------------------------------------
local function makePopups(parent, count, z)
	local P = {live = {}}
	local pool, nextI = {}, 1
	for i = 1, count do
		local l = text(parent, "", {AnchorPoint = V2(0.5, 0.5), Size = S2(0.9, 0.1), Visible = false, ZIndex = z or 30, Stroke = 3, MaxSize = 90})
		pool[i] = {l = l, scale = new("UIScale", {}, l), stroke = l:FindFirstChildOfClass("UIStroke")}
	end
	-- opts: h (height fraction), life, rise, w (width fraction), still (no rise)
	function P.pop(str, x, y, color, opts)
		opts = opts or {}
		local p = pool[nextI]
		nextI = nextI % count + 1
		p.x, p.y, p.t = x, y, 0
		p.life, p.rise = opts.life or 0.9, opts.rise or 0.08
		p.l.Text = str
		p.l.TextColor3 = color or WHITE
		p.l.Size = S2(opts.w or 0.9, opts.h or 0.09)
		p.l.TextTransparency = 0
		p.l.Rotation = opts.tilt or 0
		if p.stroke then p.stroke.Transparency = 0 end
		p.scale.Scale = 0.2
		p.l.Position = S2(x, y)
		p.l.Visible = true
		P.live[p] = true
		return p
	end
	function P.update(dt)
		for p in pairs(P.live) do
			p.t = p.t + dt
			local k = p.t / p.life
			if k >= 1 then
				p.l.Visible = false
				P.live[p] = nil
			else
				p.scale.Scale = (p.t < 0.18) and lerp(0.2, 1, backOut(p.t / 0.18)) or 1
				p.l.Position = S2(p.x, p.y - p.rise * easeOut(k))
				local fade = clamp((k - 0.65) / 0.35, 0, 1)
				p.l.TextTransparency = fade
				if p.stroke then p.stroke.Transparency = fade end
			end
		end
	end
	function P.clear()
		for p in pairs(P.live) do p.l.Visible = false end
		P.live = {}
	end
	return P
end

-- shakes a frame around its resting position (screen shake)
local function makeShaker(f)
	local S = {t = 0, dur = 1, mag = 0, base = f.Position}
	function S.kick(mag, dur)
		S.mag, S.t, S.dur = mag, dur, dur
	end
	function S.setBase(p)
		S.base = p
		f.Position = p
	end
	function S.update(dt)
		if S.t <= 0 then return end
		S.t = math.max(0, S.t - dt)
		local m = S.mag * (S.t / S.dur)
		if S.t <= 0 then
			f.Position = S.base
		else
			f.Position = offsetPos(S.base, (math.random() * 2 - 1) * m, (math.random() * 2 - 1) * m)
		end
	end
	return S
end

------------------------------------------------------------------
-- PANEL: the big card for game over / pause / round summary, with a huge Play Again button
------------------------------------------------------------------
local function makePanel(parent, z)
	local P = {}
	-- a see-through button over the game: it catches taps so nothing under it reacts
	local dim = new("TextButton", {Name = "Panel", Text = "", AutoButtonColor = false, BackgroundColor3 = rgb(6, 6, 16), BackgroundTransparency = 0.35,
		Size = S2(1, 1), Visible = false, ZIndex = z or 50, BorderSizePixel = 0}, parent)
	local card = frame(dim, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(0.9, 0.86), BackgroundColor3 = rgb(46, 40, 82)})
	new("UIAspectRatioConstraint", {AspectRatio = 1.12}, card)
	round(card, 20)
	UI.stroke(card, 4, C.ink)
	grad(card, rgb(255, 255, 255), rgb(170, 168, 196))
	local scale = new("UIScale", {}, card)
	-- a glossy band behind the title
	local band = frame(card, {Position = S2(0.04, 0.04), Size = S2(0.92, 0.22), BackgroundColor3 = rgb(90, 70, 170)})
	round(band, 14)
	P.band = band
	P.bandGrad = grad(band, WHITE, rgb(170, 170, 190))
	P.title = UI.label(band, "", {Position = S2(0.04, 0.08), Size = S2(0.92, 0.84), Max = 46, Min = 12, Stroke = 4, TextWrapped = false})
	P.lines = UI.label(card, "", {Position = S2(0.06, 0.28), Size = S2(0.88, 0.3), Max = 26, Min = 10, Stroke = 2.5, TextColor3 = rgb(235, 232, 255)})
	-- "NEW BEST!" ribbon on the corner
	local ribbon = frame(card, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.86, 0.02), Size = S2(0.44, 0.12), Rotation = 12, BackgroundColor3 = C.pink, Visible = false})
	round(ribbon, 8)
	UI.stroke(ribbon, 3, C.ink)
	grad(ribbon, rgb(255, 230, 120), rgb(255, 150, 60))
	UI.label(ribbon, "NEW BEST!", {Size = S2(0.92, 0.84), Position = S2(0.04, 0.08), Max = 26, Min = 8, Stroke = 2.5, TextWrapped = false})
	P.ribbon = ribbon
	P.ribbonScale = new("UIScale", {}, ribbon)
	P.a = UI.button(card, {Text = "PLAY AGAIN", Color = C.green, Size = S2(0.86, 0.21), AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.58), TextSize = 34, Depth = 6, Radius = 12})
	P.b = UI.button(card, {Text = "Home", Color = C.grey, Size = S2(0.46, 0.13), AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.83), TextSize = 20, Depth = 4})
	P.frame, P.card = dim, card
	P.a.Activated:Connect(function()
		if dim.Visible and P.onA then P.onA() end
	end)
	P.b.Activated:Connect(function()
		if dim.Visible and P.onB then P.onB() end
	end)
	-- opt: title, lines, a, aColor, onA, b, onB, best, color
	function P.show(opt)
		UI.setText(P.title, opt.title or "")
		UI.setText(P.lines, opt.lines or "")
		P.title.TextColor3 = opt.titleColor or WHITE
		band.BackgroundColor3 = opt.color or rgb(90, 70, 170)
		P.a.setText(opt.a or "PLAY AGAIN")
		P.a.setColor(opt.aColor or C.green)
		P.onA, P.onB = opt.onA, opt.onB
		P.b.holder.Visible = opt.b ~= nil
		if opt.b then P.b.setText(opt.b) end
		ribbon.Visible = opt.best == true
		dim.Visible = true
		dim.BackgroundTransparency = 1
		UI.tween(dim, 0.25, {BackgroundTransparency = 0.35})
		scale.Scale = 0.4
		UI.tween(scale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
		if opt.best then
			P.ribbonScale.Scale = 3
			UI.tween(P.ribbonScale, 0.5, {Scale = 1}, Enum.EasingStyle.Bounce)
		end
	end
	function P.hide() dim.Visible = false end
	function P.isOpen() return dim.Visible end
	return P
end

-- a big "3-2-1-GO" counter in the middle of a frame
local function makeCountdown(parent, z)
	local l = text(parent, "", {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.45), Size = S2(0.8, 0.34), Visible = false, ZIndex = z or 40, Stroke = 5, MaxSize = 160})
	local sc = new("UIScale", {}, l)
	local st = l:FindFirstChildOfClass("UIStroke")
	local CD = {t = 0, active = false, shown = -1}
	function CD.start(seconds)
		CD.t, CD.active, CD.shown = seconds, true, -1
	end
	-- returns true while still counting
	function CD.update(dt)
		if not CD.active then
			l.Visible = false
			return false
		end
		CD.t = CD.t - dt
		local n = math.ceil(CD.t)
		if CD.t <= -0.45 then
			CD.active = false
			l.Visible = false
			return false
		end
		if n ~= CD.shown then
			CD.shown = n
			l.Visible = true
			l.Text = (n >= 1) and tostring(n) or "GO!"
			l.TextColor3 = (n >= 1) and rgb(255, 235, 90) or C.money
		end
		local frac = (n >= 1) and (1 - (CD.t - (n - 1))) or clamp(-CD.t / 0.45, 0, 1)
		sc.Scale = (frac < 0.25) and lerp(2.2, 1, easeOut(frac / 0.25)) or lerp(1, 0.85, (frac - 0.25) / 0.75)
		l.TextTransparency = clamp((frac - 0.7) / 0.3, 0, 1)
		if st then st.Transparency = l.TextTransparency end
		return CD.t > 0
	end
	function CD.stop()
		CD.active = false
		l.Visible = false
	end
	return CD
end

------------------------------------------------------------------
-- SNAKE: smooth sliding body, a head with eyes + tongue, apples that bob, golden apples
------------------------------------------------------------------
local function buildSnake(env)
	local G = 15
	local CELL = 1 / G
	local pg = env.page("Snake", {title = "Snake", color = rgb(70, 200, 90), bg0 = rgb(30, 70, 45), bg1 = rgb(14, 34, 26)})
	local content = pg.content
	local app = {}

	-- THE BOARD: checkered grass in a wooden frame
	local board = frame(content, {Name = "Board", AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.015), Size = S2(0.98, 0.64), BackgroundColor3 = rgb(96, 178, 64), ZIndex = 2})
	square(board)
	round(board, 10)
	UI.stroke(board, 5, rgb(70, 45, 25))
	grad(board, WHITE, rgb(200, 215, 200))
	for x = 0, G - 1 do
		for y = 0, G - 1 do
			if (x + y) % 2 == 0 then
				frame(board, {Position = S2(x * CELL, y * CELL), Size = S2(CELL, CELL), BackgroundColor3 = rgb(112, 196, 74), ZIndex = 1})
			end
		end
	end
	local shaker = makeShaker(board)
	local parts = makeParticles(board, 48, 9)
	local pops = makePopups(board, 6, 10)
	local cd = makeCountdown(board, 12)
	local panel = makePanel(content, 60)
	local flash = frame(board, {Size = S2(1, 1), BackgroundColor3 = rgb(255, 60, 60), BackgroundTransparency = 1, ZIndex = 11})
	round(flash, 10)

	-- an apple: shadow, round body, shine, stem and leaf (gold = the bonus apple)
	local function makeApple(body, dark, leaf)
		local h = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = S2(CELL * 1.25, CELL * 1.25), BackgroundTransparency = 1, Visible = false, ZIndex = 4})
		local sc = new("UIScale", {}, h)
		local shadow = frame(h, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.9), Size = S2(0.7, 0.2), BackgroundColor3 = BLACK, BackgroundTransparency = 0.7, ZIndex = 1})
		round(shadow, true)
		local b = frame(h, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.55), Size = S2(0.8, 0.76), BackgroundColor3 = body, ZIndex = 2})
		round(b, true)
		UI.stroke(b, 2, dark)
		grad(b, body:Lerp(WHITE, 0.25), dark, 60)
		local shine = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.32, 0.3), Size = S2(0.26, 0.18), Rotation = -30, BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, ZIndex = 3})
		round(shine, true)
		frame(h, {AnchorPoint = V2(0.5, 1), Position = S2(0.5, 0.24), Size = S2(0.08, 0.2), BackgroundColor3 = rgb(110, 70, 30), Rotation = 10, ZIndex = 3})
		local lf = frame(h, {AnchorPoint = V2(0, 0.5), Position = S2(0.52, 0.14), Size = S2(0.3, 0.14), Rotation = -25, BackgroundColor3 = leaf, ZIndex = 3})
		round(lf, true)
		UI.stroke(lf, 1.5, leaf:Lerp(BLACK, 0.4))
		return {h = h, scale = sc, spawnT = 1}
	end
	local apple = makeApple(rgb(240, 50, 60), rgb(150, 20, 35), rgb(90, 200, 60))
	local golden = makeApple(rgb(255, 215, 60), rgb(190, 120, 10), rgb(255, 250, 200))
	local goldBar = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = S2(CELL, CELL * 0.14), BackgroundColor3 = rgb(255, 225, 80), Visible = false, ZIndex = 4})
	round(goldBar, true)
	UI.stroke(goldBar, 1.5, C.ink)

	-- body pieces (pooled): an outline layer under a fill layer = one smooth outlined tube
	local HEAD_C, TAIL_C = rgb(130, 235, 80), rgb(30, 140, 110)
	local segs, mids = {}, {}
	local function piece(list, i, isMid)
		local s = list[i]
		if s then return s end
		local line = frame(board, {AnchorPoint = V2(0.5, 0.5), BackgroundColor3 = rgb(20, 60, 35), ZIndex = 5})
		round(line, true)
		local col = HEAD_C:Lerp(TAIL_C, clamp(i / 28, 0, 1))
		if not isMid and i % 3 == 0 then col = col:Lerp(rgb(250, 230, 90), 0.35) end -- a yellow band every 3rd piece
		local fill = frame(board, {AnchorPoint = V2(0.5, 0.5), BackgroundColor3 = col, ZIndex = 6})
		round(fill, true)
		grad(fill, WHITE, rgb(175, 185, 175), 45)
		s = {line = line, fill = fill}
		list[i] = s
		return s
	end
	-- THE HEAD: rotates to face where it's going; eyes, nostrils and a flicking tongue
	local head = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = S2(CELL * 1.18, CELL * 1.18), BackgroundColor3 = HEAD_C, ZIndex = 8})
	round(head, 0.42)
	UI.stroke(head, 2.5, rgb(20, 60, 35))
	grad(head, WHITE, rgb(185, 195, 185), 45)
	local headScale = new("UIScale", {}, head)
	local tongue = frame(head, {AnchorPoint = V2(0, 0.5), Position = S2(0.86, 0.5), Size = S2(0.5, 0.2), BackgroundTransparency = 1, Visible = false, ZIndex = 1})
	frame(tongue, {AnchorPoint = V2(0, 0.5), Position = S2(0, 0.5), Size = S2(0.75, 0.38), BackgroundColor3 = rgb(230, 40, 70), ZIndex = 1})
	for _, s in ipairs({-1, 1}) do
		frame(tongue, {AnchorPoint = V2(0, 0.5), Position = S2(0.66, 0.5 + s * 0.12), Size = S2(0.36, 0.3), Rotation = s * 35, BackgroundColor3 = rgb(230, 40, 70), ZIndex = 1})
	end
	local eyes = {}
	for k, s in ipairs({-1, 1}) do
		local e = frame(head, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.58, 0.5 + s * 0.25), Size = S2(0.38, 0.38), BackgroundColor3 = WHITE, ZIndex = 3})
		round(e, true)
		UI.stroke(e, 1.5, C.ink)
		local pupil = frame(e, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.64, 0.5), Size = S2(0.52, 0.52), BackgroundColor3 = C.ink, ZIndex = 4})
		round(pupil, true)
		local glint = frame(pupil, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.68, 0.3), Size = S2(0.34, 0.34), BackgroundColor3 = WHITE, ZIndex = 5})
		round(glint, true)
		local x = text(e, "x", {Size = S2(1.1, 1.1), Position = S2(-0.05, -0.12), TextColor3 = C.ink, Stroke = 0, Visible = false, ZIndex = 6})
		eyes[k] = {e = e, pupil = pupil, x = x}
	end
	for _, s in ipairs({-1, 1}) do
		local n = frame(head, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.9, 0.5 + s * 0.1), Size = S2(0.06, 0.06), BackgroundColor3 = rgb(20, 60, 35), ZIndex = 3})
		round(n, true)
	end

	-- THE D-PAD: four big arrow buttons (react the moment you touch them)
	local pad = frame(content, {Name = "DPad", AnchorPoint = V2(0.5, 1), Position = S2(0.5, 0.985), Size = S2(0.94, 0.31), BackgroundTransparency = 1, ZIndex = 4})
	local padRatio = square(pad, 1.75)
	local padBase = frame(pad, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(0.62, 1), BackgroundColor3 = rgb(10, 24, 18), BackgroundTransparency = 0.35, ZIndex = 1})
	round(padBase, true)
	local queueDir -- (set below)
	local lastPress = {}
	local padButtons = {}
	local PAD = {
		Up = {pos = S2(0.5, 0), anchor = V2(0.5, 0), size = S2(0.3, 0.48), rot = -90},
		Down = {pos = S2(0.5, 1), anchor = V2(0.5, 1), size = S2(0.3, 0.48), rot = 90},
		Left = {pos = S2(0.03, 0.5), anchor = V2(0, 0.5), size = S2(0.3, 0.48), rot = 180},
		Right = {pos = S2(0.97, 0.5), anchor = V2(1, 0.5), size = S2(0.3, 0.48), rot = 0},
	}
	local PAD_C = rgb(70, 200, 110)
	for name, spec in pairs(PAD) do
		local b = new("TextButton", {Name = name, Text = "", AutoButtonColor = false, AnchorPoint = spec.anchor, Position = spec.pos, Size = spec.size,
			BackgroundColor3 = PAD_C, BorderSizePixel = 0, ZIndex = 3}, pad)
		round(b, 0.3)
		UI.stroke(b, 3, C.ink)
		grad(b, WHITE, rgb(150, 160, 160))
		chevron(b, WHITE, 0.62, 4).Rotation = spec.rot
		local sc = new("UIScale", {}, b)
		padButtons[name] = b
		local function down()
			if os.clock() - (lastPress[name] or 0) < 0.08 then return end
			lastPress[name] = os.clock()
			sc.Scale = 0.88
			b.BackgroundColor3 = PAD_C:Lerp(WHITE, 0.4)
			queueDir(name)
		end
		local function up()
			sc.Scale = 1
			b.BackgroundColor3 = PAD_C
		end
		b.InputBegan:Connect(function(input) if isPress(input) then down() end end)
		b.InputEnded:Connect(function(input) if isPress(input) then up() end end)
		b.MouseButton1Down:Connect(down)
		b.MouseButton1Up:Connect(up)
		b.MouseLeave:Connect(up)
	end
	local hint = UI.label(content, UI.isTouch and "Swipe on the board or use the arrows" or "WASD / arrow keys, swipe or the arrows.  P = pause",
		{AnchorPoint = V2(0, 0.5), Position = S2(0.015, 0.5), Size = S2(0.17, 0.5), Max = 18, Min = 8, Stroke = 2, TextColor3 = rgb(200, 240, 200), Visible = false})

	-- SWIPES: anywhere on the game (the D-pad buttons sit on top of this)
	local catcher = new("TextButton", {Name = "Swipe", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 1}, content)
	local boardCatcher = new("TextButton", {Name = "SwipeBoard", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 13}, board)
	local swipe = nil

	-- GAME STATE
	local dirs = {Up = V2(0, -1), Down = V2(0, 1), Left = V2(-1, 0), Right = V2(1, 0)}
	local snake, prev, rp = {}, {}, {}
	local dir, queue = dirs.Right, {}
	local tickT, interval, phase = 0, 0.15, "idle"
	local score, eaten, newBest = 0, 0, false
	local food, gold = nil, nil
	local bulges = {}
	local headAngle, tongueT, flickT, blinkT, blinkLeft, deadT = 0, 1, 0, 2, 0, 0
	local shownSegs, shownMids = 0, 0

	queueDir = function(name)
		if phase ~= "play" and phase ~= "count" then return end
		local d = dirs[name]
		local last = queue[#queue] or dir
		if (d - last).Magnitude < 0.01 or (d + last).Magnitude < 0.01 then return end -- same way, or straight back
		if #queue < 2 then table.insert(queue, d) end
	end
	local function same(a, b) return a ~= nil and b ~= nil and (a - b).Magnitude < 0.01 end
	local function free(p)
		for _, s in ipairs(snake) do if same(s, p) then return false end end
		return not same(p, food) and not (gold and same(p, gold.pos))
	end
	local function randomFree()
		for _ = 1, 300 do
			local p = V2(math.random(0, G - 1), math.random(0, G - 1))
			if free(p) then return p end
		end
		for x = 0, G - 1 do for y = 0, G - 1 do if free(V2(x, y)) then return V2(x, y) end end end
		return nil
	end
	local function cellPos(p, dy) return S2((p.X + 0.5) * CELL, (p.Y + 0.5 + (dy or 0)) * CELL) end
	local function placeFood()
		food = randomFree()
		apple.spawnT = 0
	end

	-- draw everything where it is right now (alpha = how far between two steps)
	local function bodySize(i, n)
		local s = 0.86
		local fromTail = n - i
		if fromTail < 4 then s = s * (0.6 + fromTail * 0.1) end
		for _, b in ipairs(bulges) do
			local d = math.abs(b - i)
			if d < 1.5 then s = s * (1.3 - d * 0.18) end
		end
		return s * CELL
	end
	local function render(alpha)
		local n = #snake
		for i = 1, n do rp[i] = lerpV(prev[i] or snake[i], snake[i], alpha) end
		for i = 1, n do
			local s = piece(segs, i, false)
			local sz = bodySize(i, n)
			local pos = S2((rp[i].X + 0.5) * CELL, (rp[i].Y + 0.5) * CELL)
			s.fill.Position, s.line.Position = pos, pos
			s.fill.Size = S2(sz, sz)
			s.line.Size = S2(sz + CELL * 0.16, sz + CELL * 0.16)
			s.fill.Visible, s.line.Visible = true, true
		end
		for i = 1, n - 1 do
			local s = piece(mids, i, true)
			local sz = math.min(bodySize(i, n), bodySize(i + 1, n))
			local m = lerpV(rp[i], rp[i + 1], 0.5)
			local pos = S2((m.X + 0.5) * CELL, (m.Y + 0.5) * CELL)
			s.fill.Position, s.line.Position = pos, pos
			s.fill.Size = S2(sz, sz)
			s.line.Size = S2(sz + CELL * 0.16, sz + CELL * 0.16)
			s.fill.BackgroundColor3 = segs[i].fill.BackgroundColor3:Lerp(segs[i + 1].fill.BackgroundColor3, 0.5)
			s.fill.Visible, s.line.Visible = true, true
		end
		for i = n + 1, shownSegs do segs[i].fill.Visible, segs[i].line.Visible = false, false end
		for i = math.max(1, n), shownMids do mids[i].fill.Visible, mids[i].line.Visible = false, false end
		shownSegs, shownMids = n, math.max(0, n - 1)
		if n > 0 then head.Position = S2((rp[1].X + 0.5) * CELL, (rp[1].Y + 0.5) * CELL) end
		head.Rotation = headAngle
	end

	local function hud()
		pg.setScore(score)
		pg.setBest(bests.Snake)
	end
	local function showOver()
		phase = "over"
		panel.show({title = "GAME OVER", color = rgb(200, 60, 70),
			lines = "Score  " .. score .. "\nBest  " .. bests.Snake .. "\nLength  " .. #snake,
			best = newBest, a = "PLAY AGAIN", onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
	end
	local function die()
		phase = "dead"
		deadT = 0
		prev = table.clone(snake)
		shaker.kick(0.035, 0.5)
		flash.BackgroundTransparency = 0.25
		parts.burst((snake[1].X + 0.5) * CELL, (snake[1].Y + 0.5) * CELL, {HEAD_C, TAIL_C, rgb(250, 230, 90)}, 18, 0.5, 0.035)
		for _, e in ipairs(eyes) do
			e.pupil.Visible = false
			e.x.Visible = true
		end
		tongue.Visible = false
		UI.SFX.play("error")
	end
	local function eat(p, value, color)
		score = score + value
		eaten = eaten + 1
		if score > bests.Snake then
			if bests.Snake > 0 and not newBest then
				pops.pop("NEW BEST!", 0.5, 0.2, rgb(255, 220, 80), {h = 0.12, life = 1.4, rise = 0.05})
			end
			newBest = newBest or bests.Snake > 0
			bests.Snake = score
		end
		hud()
		local x, y = (p.X + 0.5) * CELL, (p.Y + 0.5) * CELL
		parts.burst(x, y, color, value > 1 and 22 or 12, value > 1 and 0.55 or 0.4, 0.03)
		pops.pop("+" .. value, x, y - CELL * 0.6, value > 1 and rgb(255, 220, 60) or C.money, {h = value > 1 and 0.1 or 0.075, w = 0.4, rise = 0.09})
		headScale.Scale = 1.35
		table.insert(bulges, 1)
		interval = math.max(0.065, 0.15 - eaten * 0.0028) -- faster and faster
		UI.SFX.play("click", 2.6, 0.35)
	end
	local function step()
		prev = table.clone(snake)
		if #queue > 0 then
			local d = table.remove(queue, 1)
			if (d + dir).Magnitude > 0.01 then dir = d end -- (never straight back into yourself)
		end
		local h = snake[1] + dir
		local ateApple = same(h, food)
		local ateGold = gold ~= nil and same(h, gold.pos)
		local hit = h.X < 0 or h.Y < 0 or h.X >= G or h.Y >= G
		local check = (ateApple or ateGold) and #snake or #snake - 1 -- the tail moves out of the way
		for i = 1, check do
			if same(snake[i], h) then hit = true break end
		end
		if hit then die() return end
		table.insert(snake, 1, h)
		if ateApple or ateGold then
			prev[#snake] = snake[#snake] -- the new tail piece stays where it is
		else
			table.remove(snake)
		end
		for i = #bulges, 1, -1 do
			bulges[i] = bulges[i] + 1
			if bulges[i] > #snake then table.remove(bulges, i) end
		end
		if ateApple then
			eat(h, 1, {rgb(240, 50, 60), rgb(255, 120, 120), rgb(90, 200, 60)})
			placeFood()
			-- now and then a golden apple shows up for a few seconds
			if not gold and eaten >= 3 and math.random() < 0.3 then
				local p = randomFree()
				if p then
					gold = {pos = p, t = 6, total = 6}
					golden.spawnT = 0
				end
			end
		end
		if ateGold then
			eat(h, 5, {rgb(255, 215, 60), rgb(255, 250, 200), rgb(255, 170, 40)})
			pops.pop("GOLDEN!", 0.5, 0.16, rgb(255, 215, 60), {h = 0.11, life = 1.1, rise = 0.04})
			gold = nil
		end
	end

	function app.start()
		local mid = math.floor(G / 2)
		snake = {V2(5, mid), V2(4, mid), V2(3, mid)}
		prev = table.clone(snake)
		dir, queue, tickT, interval = dirs.Right, {}, 0, 0.15
		score, eaten, newBest, bulges, gold = 0, 0, false, {}, nil
		headAngle, deadT = 0, 0
		flash.BackgroundTransparency = 1
		for _, e in ipairs(eyes) do
			e.pupil.Visible = true
			e.x.Visible = false
		end
		parts.clear()
		pops.clear()
		panel.hide()
		placeFood()
		hud()
		render(1)
		phase = "count"
		cd.start(3)
	end
	local function resume()
		panel.hide()
		phase = "count"
		cd.start(2)
	end
	function app.enter()
		if phase == "paused" then return end
		app.start()
	end
	function app.leave()
		if phase == "play" or phase == "count" then
			phase = "paused"
			cd.stop()
			swipe = nil
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Score  " .. score .. "\nBest  " .. bests.Snake,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		local d = dirKey(kc)
		if d then queueDir(d) return end
		if kc == Enum.KeyCode.P then
			if phase == "paused" then resume() else app.leave() end
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return then
			if phase == "over" then app.start() elseif phase == "paused" then resume() end
		end
	end

	-- swipe: as soon as the finger has moved far enough, turn (by the bigger of the two directions)
	-- and keep going from there, so one long swipe can make several turns
	local function swipeTo(p, final)
		if not swipe then return end
		local d = p - swipe.origin
		local dead = math.max(12, board.AbsoluteSize.X * (final and 0.035 or 0.05))
		if d.Magnitude < dead then return end
		if math.abs(d.X) > math.abs(d.Y) then queueDir(d.X > 0 and "Right" or "Left") else queueDir(d.Y > 0 and "Down" or "Up") end
		swipe.origin = p
	end
	for _, c in ipairs({catcher, boardCatcher}) do
		c.InputBegan:Connect(function(input)
			if not isPress(input) then return end
			swipe = {input = input, origin = posOf(input), mouse = input.UserInputType == Enum.UserInputType.MouseButton1}
		end)
	end
	function app.move(input)
		if not swipe then return end
		if (swipe.mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or input == swipe.input then swipeTo(posOf(input), false) end
	end
	function app.release(input)
		if not swipe then return end
		if (swipe.mouse and input.UserInputType == Enum.UserInputType.MouseButton1) or input == swipe.input then
			swipeTo(posOf(input), true)
			swipe = nil
		end
	end

	function app.layout(wide)
		if wide then
			shaker.setBase(S2(0.46, 0.5))
			board.AnchorPoint, board.Size = V2(0.5, 0.5), S2(0.6, 0.97)
			pad.AnchorPoint, pad.Position, pad.Size = V2(1, 0.5), S2(0.995, 0.55), S2(0.25, 0.9)
			padRatio.AspectRatio = 1
		else
			shaker.setBase(S2(0.5, 0.015))
			board.AnchorPoint, board.Size = V2(0.5, 0), S2(0.98, 0.64)
			pad.AnchorPoint, pad.Position, pad.Size = V2(0.5, 1), S2(0.5, 0.985), S2(0.94, 0.31)
			padRatio.AspectRatio = 1.75
		end
		hint.Visible = wide
	end

	function app.step(dt)
		local now = os.clock()
		parts.update(dt)
		pops.update(dt)
		shaker.update(dt)
		local counting = cd.update(dt)
		if phase == "paused" then return end
		if phase == "count" and not counting then phase = "play" end
		local alpha = 1
		if phase == "play" then
			tickT = tickT + dt
			while tickT >= interval and phase == "play" do
				tickT = tickT - interval
				step()
			end
			alpha = (phase == "play") and clamp(tickT / interval, 0, 1) or 1
			if gold then
				gold.t = gold.t - dt
				if gold.t <= 0 then
					parts.burst((gold.pos.X + 0.5) * CELL, (gold.pos.Y + 0.5) * CELL, rgb(255, 230, 120), 8, 0.25, 0.025)
					gold = nil
				end
			end
		elseif phase == "count" then
			alpha = 0
		elseif phase == "dead" then
			deadT = deadT + dt
			flash.BackgroundTransparency = clamp(0.25 + deadT * 1.5, 0, 1)
			if deadT > 0.9 then showOver() end
		end
		-- the head turns smoothly towards where it's moving
		if #snake > 0 then
			local mv = snake[1] - (prev[1] or snake[1])
			if mv.Magnitude < 0.01 then mv = dir end
			headAngle = turnTo(headAngle, math.deg(atan2(mv.Y, mv.X)), dt * 16)
		end
		headScale.Scale = lerp(headScale.Scale, 1, clamp(dt * 10, 0, 1))
		-- tongue flick + blinking
		if phase == "play" or phase == "count" then
			tongueT = tongueT - dt
			if tongueT <= 0 then
				tongueT = 1 + math.random() * 1.6
				flickT = 0.32
			end
		end
		if flickT > 0 and phase ~= "dead" and phase ~= "over" then
			flickT = math.max(0, flickT - dt)
			local k = math.sin((1 - flickT / 0.32) * math.pi)
			tongue.Visible = k > 0.05
			tongue.Size = S2(0.6 * k, 0.24)
		else
			tongue.Visible = false
		end
		blinkT = blinkT - dt
		if blinkT <= 0 then
			blinkT = 2 + math.random() * 3
			blinkLeft = 0.13
		end
		blinkLeft = math.max(0, blinkLeft - dt)
		for _, e in ipairs(eyes) do e.e.Size = S2(0.38, (blinkLeft > 0 and phase ~= "dead" and phase ~= "over") and 0.08 or 0.38) end
		-- apples bob and shine
		if food then
			apple.spawnT = math.min(1, apple.spawnT + dt * 3)
			apple.h.Visible = true
			apple.h.Position = cellPos(food, math.sin(now * 3.2) * 0.07 - 0.05)
			apple.scale.Scale = backOut(apple.spawnT) * (1 + math.sin(now * 5) * 0.05)
		else
			apple.h.Visible = false
		end
		if gold then
			golden.spawnT = math.min(1, golden.spawnT + dt * 3)
			golden.h.Visible = gold.t > 2 or (math.floor(now * 8) % 2 == 0) -- blinks before it vanishes
			golden.h.Position = cellPos(gold.pos, math.sin(now * 4) * 0.08 - 0.05)
			golden.h.Rotation = math.sin(now * 3) * 12
			golden.scale.Scale = backOut(golden.spawnT) * (1.1 + math.sin(now * 7) * 0.07)
			goldBar.Visible = true
			goldBar.Position = cellPos(gold.pos, 0.72)
			goldBar.Size = S2(CELL * clamp(gold.t / gold.total, 0, 1), CELL * 0.14)
			if math.random() < dt * 6 then
				parts.emit((gold.pos.X + 0.2 + math.random() * 0.6) * CELL, (gold.pos.Y + 0.2) * CELL, 0, -0.05, rgb(255, 250, 200), 0.018, {g = 0, life = 0.6})
			end
		else
			golden.h.Visible = false
			goldBar.Visible = false
		end
		if #snake > 0 then render(alpha) end
	end

	render(1)
	hud()
	return app
end

------------------------------------------------------------------
-- BLOCK BLAST: drag (or tap + tap) pieces onto an 8x8 board, clear rows + columns, chain combos
------------------------------------------------------------------
local BLAST_COLORS = {rgb(255, 70, 85), rgb(255, 150, 40), rgb(255, 215, 50), rgb(80, 215, 90), rgb(40, 200, 240), rgb(70, 120, 255), rgb(170, 90, 255), rgb(255, 100, 190)}
local BLAST_SHAPES = (function()
	local base = {
		{{0, 0}}, {{0, 0}, {1, 0}}, {{0, 0}, {1, 0}, {2, 0}}, {{0, 0}, {1, 0}, {2, 0}, {3, 0}}, {{0, 0}, {1, 0}, {2, 0}, {3, 0}, {4, 0}},
		{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, {{0, 0}, {1, 0}, {2, 0}, {0, 1}, {1, 1}, {2, 1}},
		{{0, 0}, {1, 0}, {2, 0}, {0, 1}, {1, 1}, {2, 1}, {0, 2}, {1, 2}, {2, 2}},
		{{0, 0}, {0, 1}, {1, 1}}, {{0, 0}, {0, 1}, {0, 2}, {1, 2}}, {{1, 0}, {1, 1}, {1, 2}, {0, 2}},
		{{0, 0}, {1, 0}, {2, 0}, {1, 1}}, {{1, 0}, {2, 0}, {0, 1}, {1, 1}}, {{0, 0}, {1, 0}, {1, 1}, {2, 1}},
		{{0, 0}, {0, 1}, {0, 2}, {1, 2}, {2, 2}},
	}
	local out, seen = {}, {}
	for _, shape in ipairs(base) do
		local cells = shape
		for _ = 1, 4 do
			-- normalise + remember each rotation once
			local minX, minY = math.huge, math.huge
			for _, c in ipairs(cells) do minX, minY = math.min(minX, c[1]), math.min(minY, c[2]) end
			local norm, keys = {}, {}
			for _, c in ipairs(cells) do
				table.insert(norm, {c[1] - minX, c[2] - minY})
				table.insert(keys, (c[1] - minX) .. ":" .. (c[2] - minY))
			end
			table.sort(keys)
			local key = table.concat(keys, ",")
			if not seen[key] then
				seen[key] = true
				local w, h = 0, 0
				for _, c in ipairs(norm) do w, h = math.max(w, c[1] + 1), math.max(h, c[2] + 1) end
				table.insert(out, {cells = norm, w = w, h = h})
			end
			local rot = {}
			for _, c in ipairs(norm) do table.insert(rot, {-c[2], c[1]}) end
			cells = rot
		end
	end
	return out
end)()
local BEVEL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 255, 255)),
	ColorSequenceKeypoint.new(0.46, rgb(236, 236, 244)),
	ColorSequenceKeypoint.new(0.54, rgb(196, 196, 210)),
	ColorSequenceKeypoint.new(1, rgb(140, 140, 158)),
})

local function buildBlast(env)
	local N = 8
	local PAD = 0.025
	local CW = (1 - PAD * 2) / N -- one cell, as a fraction of the board
	local EMPTY = rgb(40, 46, 92)
	local pg = env.page("BlockBlast", {title = "Block Blast", color = rgb(160, 90, 255), bg0 = rgb(52, 36, 110), bg1 = rgb(16, 14, 42)})
	local content = pg.content
	local app = {}

	local board = frame(content, {Name = "Board", AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.01), Size = S2(0.98, 0.72), BackgroundColor3 = rgb(24, 26, 60), ZIndex = 5})
	square(board)
	round(board, 14)
	UI.stroke(board, 4, C.ink)
	grad(board, rgb(255, 255, 255), rgb(170, 170, 205))
	local shaker = makeShaker(board)

	-- one glossy bevelled block (board tiles, tray pieces and the piece you drag all use it)
	local function block(parent, z, strokePx)
		local f = frame(parent, {AnchorPoint = V2(0.5, 0.5), BackgroundColor3 = EMPTY, ZIndex = z})
		round(f, 0.22)
		local st = UI.stroke(f, strokePx or 2, C.ink)
		local g = new("UIGradient", {Rotation = 90, Color = BEVEL}, f)
		local gloss = frame(f, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.3, 0.26), Size = S2(0.26, 0.15), Rotation = -20, BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.2, ZIndex = z})
		round(gloss, true)
		return {f = f, stroke = st, grad = g, gloss = gloss, scale = new("UIScale", {}, f)}
	end
	local function paint(b, color, transparency)
		if color then
			b.f.BackgroundColor3 = color
			b.stroke.Color = color:Lerp(BLACK, 0.6)
			b.grad.Rotation = 90
			b.gloss.Visible = true
		else
			b.f.BackgroundColor3 = EMPTY
			b.stroke.Color = rgb(18, 20, 46)
			b.grad.Rotation = 270 -- (empty slots look pressed in)
			b.gloss.Visible = false
		end
		b.f.BackgroundTransparency = transparency or 0
		b.gloss.BackgroundTransparency = math.max(0.2, transparency or 0)
	end

	-- the 64 tiles (each with an overlay for the ghost / highlight / flash)
	local tiles = {}
	for x = 0, N - 1 do
		for y = 0, N - 1 do
			local b = block(board, 2, 2)
			b.f.Position = S2(PAD + (x + 0.5) * CW, PAD + (y + 0.5) * CW)
			b.f.Size = S2(CW * 0.92, CW * 0.92)
			b.ov = frame(b.f, {Size = S2(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 3})
			round(b.ov, 0.22)
			paint(b, nil)
			tiles[x * N + y] = b
		end
	end
	local parts = makeParticles(board, 70, 28)
	local pops = makePopups(board, 8, 29)
	local panel = makePanel(content, 60)
	local catcher = new("TextButton", {Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 25}, board)

	-- THE TRAY: three pieces to choose from
	local tray = frame(content, {Name = "Tray", AnchorPoint = V2(0.5, 1), Position = S2(0.5, 0.995), Size = S2(0.98, 0.25), BackgroundTransparency = 1, ZIndex = 2})
	local slots = {}
	for i = 1, 3 do
		local s = new("TextButton", {Name = "Piece" .. i, Text = "", AutoButtonColor = false, AnchorPoint = V2(0.5, 0.5), Position = S2(0.17 + (i - 1) * 0.33, 0.5),
			Size = S2(0.31, 1), BackgroundColor3 = rgb(30, 30, 72), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 2}, tray)
		square(s)
		round(s, 0.16)
		local st = UI.stroke(s, 2.5, rgb(90, 80, 170))
		local holder = frame(s, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundTransparency = 1, ZIndex = 3})
		local blocks = {}
		for k = 1, 9 do
			blocks[k] = block(holder, 3, 1.5)
			blocks[k].f.Visible = false
		end
		slots[i] = {btn = s, stroke = st, holder = holder, hscale = new("UIScale", {}, holder), blocks = blocks, appear = 1}
	end

	-- THE PIECE YOU DRAG: floats above your finger, a bit bigger than the board's blocks
	local float = frame(board, {Name = "Dragged", AnchorPoint = V2(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 30})
	local floatScale = new("UIScale", {}, float)
	local floatBlocks = {}
	for k = 1, 9 do
		floatBlocks[k] = block(float, 30, 2)
		floatBlocks[k].f.Visible = false
	end

	-- GAME STATE
	local grid, hand, anims = {}, {}, {}
	local score, shown, phase = 0, 0, "idle"
	local streak, sinceClear, bestStreak, linesTotal, newBest = 0, 0, 0, 0, false
	local drag, selected, ret, preview, hoverP = nil, nil, nil, nil, nil
	local endT = 0
	local SLOT_BS = 0.19 -- block size in a tray slot (fraction of the slot)
	local LINE_PTS = {10, 25, 45, 70, 100, 135}
	local BANNER = {"", "DOUBLE!", "TRIPLE!", "QUAD!", "MEGA!", "INSANE!"}

	local function fits(p, ox, oy)
		for _, c in ipairs(p.cells) do
			local x, y = ox + c[1], oy + c[2]
			if x < 0 or y < 0 or x >= N or y >= N or grid[x * N + y] then return false end
		end
		return true
	end
	local function canFit(p)
		for x = 0, N - p.w do
			for y = 0, N - p.h do
				if fits(p, x, y) then return true end
			end
		end
		return false
	end
	-- the board cell nearest to (gx, gy) where the piece fits (gx, gy = its top-left in cells, not rounded)
	local function snap(p, gx, gy)
		if gx < -p.w * 0.5 - 0.6 or gy < -p.h * 0.5 - 0.6 or gx > N - p.w * 0.5 + 0.6 or gy > N - p.h * 0.5 + 0.6 then return nil end
		local rx, ry = math.floor(gx + 0.5), math.floor(gy + 0.5)
		local bestD, bx, by = 1.25, nil, nil
		for dx = -1, 1 do
			for dy = -1, 1 do
				local ox, oy = rx + dx, ry + dy
				local d = math.sqrt((ox - gx) ^ 2 + (oy - gy) ^ 2)
				if d < bestD and fits(p, ox, oy) then bestD, bx, by = d, ox, oy end
			end
		end
		return bx, by
	end
	-- rows / columns that would be full with these cells added
	local function fullLines(extra)
		local rows, cols = {}, {}
		for k = 0, N - 1 do
			local row, col = true, true
			for j = 0, N - 1 do
				if not (grid[j * N + k] or extra[j * N + k]) then row = false end
				if not (grid[k * N + j] or extra[k * N + j]) then col = false end
			end
			if row then table.insert(rows, k) end
			if col then table.insert(cols, k) end
		end
		return rows, cols
	end

	-- PAINTING the board: the grid + the ghost of the piece + the lines it would clear
	local function repaint()
		for k, b in pairs(tiles) do
			if not anims[k] then
				paint(b, grid[k])
				b.ov.BackgroundTransparency = 1
			end
		end
		if not preview then return end
		for k in pairs(preview.lineCells) do
			local b = tiles[k]
			if not anims[k] then
				b.ov.BackgroundColor3 = preview.color:Lerp(WHITE, 0.35)
				b.ov.BackgroundTransparency = 0.3
			end
		end
		for k in pairs(preview.cells) do
			local b = tiles[k]
			if not anims[k] then
				paint(b, preview.color, 0.3)
				b.stroke.Color = rgb(150, 255, 170)
				b.ov.BackgroundColor3 = rgb(120, 255, 150)
				b.ov.BackgroundTransparency = 0.6
			end
		end
	end
	local function setPreview(p, ox, oy)
		local key = ox and (ox .. ":" .. oy .. ":" .. tostring(p)) or nil
		if (preview and preview.key) == key then return end
		if not key then
			preview = nil
		else
			local cells = {}
			for _, c in ipairs(p.cells) do cells[(ox + c[1]) * N + oy + c[2]] = true end
			local rows, cols = fullLines(cells)
			local lineCells = {}
			for _, r in ipairs(rows) do for j = 0, N - 1 do lineCells[j * N + r] = true end end
			for _, c in ipairs(cols) do for j = 0, N - 1 do lineCells[c * N + j] = true end end
			preview = {key = key, cells = cells, lineCells = lineCells, color = p.color}
		end
		repaint()
	end

	-- the tray
	local function slotCenter(i)
		local s, bp, bs = slots[i].btn, board.AbsolutePosition, board.AbsoluteSize
		if bs.X < 1 then return V2(0.5, 1.2) end
		local c = s.AbsolutePosition + s.AbsoluteSize / 2
		return V2((c.X - bp.X) / bs.X, (c.Y - bp.Y) / bs.Y)
	end
	local function trayScale(i)
		-- how big tray blocks are compared to board blocks
		local s, bs = slots[i].btn.AbsoluteSize, board.AbsoluteSize
		if bs.X < 1 then return 0.5 end
		return clamp((s.X * SLOT_BS) / (bs.X * CW), 0.25, 1.2)
	end
	local function drawSlot(i)
		local sl, p = slots[i], hand[i]
		local show = p and not p.used and not (drag and drag.active and drag.i == i) and not (ret and ret.i == i)
		local fitsAny = p and canFit(p)
		for k, b in ipairs(sl.blocks) do
			local c = show and p.cells[k]
			b.f.Visible = c ~= nil and c ~= false
			if c then
				b.f.Position = S2(0.5 + (c[1] - (p.w - 1) / 2) * SLOT_BS, 0.5 + (c[2] - (p.h - 1) / 2) * SLOT_BS)
				b.f.Size = S2(SLOT_BS * 0.92, SLOT_BS * 0.92)
				paint(b, fitsAny and p.color or p.color:Lerp(rgb(90, 90, 110), 0.7), fitsAny and 0 or 0.35)
			end
		end
		local sel = selected == i and show
		sl.stroke.Color = sel and rgb(255, 225, 80) or rgb(90, 80, 170)
		sl.stroke.Thickness = sel and 4.5 or 2.5
	end
	local function drawTray() for i = 1, 3 do drawSlot(i) end end
	local function deal()
		local tries = 0
		repeat
			tries = tries + 1
			for i = 1, 3 do
				local s = BLAST_SHAPES[math.random(1, #BLAST_SHAPES)]
				hand[i] = {cells = s.cells, w = s.w, h = s.h, color = BLAST_COLORS[math.random(1, #BLAST_COLORS)]}
			end
			local any = false
			for i = 1, 3 do if canFit(hand[i]) then any = true end end
		until any or tries > 25
		for i = 1, 3 do slots[i].appear = -(i - 1) * 0.07 end
		drawTray()
	end
	local function anyFits()
		for i = 1, 3 do
			if hand[i] and not hand[i].used and canFit(hand[i]) then return true end
		end
		return false
	end

	local function hud()
		pg.setBest(bests.BlockBlast)
	end
	local function confetti(n)
		for _ = 1, n do
			parts.emit(math.random(), -0.05, (math.random() - 0.5) * 0.4, math.random() * 0.3, BLAST_COLORS[math.random(1, #BLAST_COLORS)], 0.03,
				{rect = true, spin = math.random(-400, 400), g = 0.7, drag = 0.4, life = 1.2 + math.random() * 0.6})
		end
	end
	local function addScore(n)
		score = score + n
		if score > bests.BlockBlast then
			if bests.BlockBlast > 0 and not newBest then
				newBest = true
				pops.pop("NEW BEST!", 0.5, 0.18, rgb(255, 220, 80), {h = 0.12, life = 1.6, rise = 0.04})
				confetti(26)
			end
			bests.BlockBlast = score
			hud()
		end
	end
	local function showOver()
		phase = "over"
		panel.show({title = "NO MORE ROOM!", color = rgb(150, 70, 220),
			lines = "Score  " .. score .. "\nBest  " .. bests.BlockBlast .. "\nLines  " .. linesTotal .. "   Best combo  x" .. math.max(1, bestStreak),
			best = newBest, a = "PLAY AGAIN", onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
	end
	local function gameOver()
		phase = "ending"
		endT = 0
		selected = nil
		setPreview(nil)
		for k in pairs(grid) do
			anims[k] = {kind = "grey", t = -(k % N) * 0.07 - math.floor(k / N) * 0.015}
		end
		shaker.kick(0.012, 0.3)
		UI.SFX.play("error")
	end

	-- PLACE a piece: blocks pop in, full lines flash and burst, combos multiply
	local function place(i, ox, oy)
		local p = hand[i]
		p.used = true
		if selected == i then selected = nil end
		setPreview(nil)
		local placed = {}
		for _, c in ipairs(p.cells) do
			local k = (ox + c[1]) * N + oy + c[2]
			grid[k] = p.color
			placed[k] = true
			anims[k] = {kind = "in", t = 0}
			paint(tiles[k], p.color)
		end
		addScore(#p.cells)
		local cx, cy = PAD + (ox + p.w / 2) * CW, PAD + (oy + p.h / 2) * CW
		local rows, cols = fullLines({})
		local lines = #rows + #cols
		if lines > 0 then
			streak = streak + 1
			sinceClear = 0
			bestStreak = math.max(bestStreak, streak)
			linesTotal = linesTotal + lines
			local clear = {}
			for _, r in ipairs(rows) do for j = 0, N - 1 do clear[j * N + r] = true end end
			for _, c in ipairs(cols) do for j = 0, N - 1 do clear[c * N + j] = true end end
			for k in pairs(clear) do
				local x, y = math.floor(k / N), k % N
				local d = math.sqrt((PAD + (x + 0.5) * CW - cx) ^ 2 + (PAD + (y + 0.5) * CW - cy) ^ 2)
				anims[k] = {kind = "clear", t = -0.08 - d * 0.35, color = grid[k]}
				grid[k] = nil
			end
			local gain = LINE_PTS[math.min(lines, #LINE_PTS)] * math.max(1, streak)
			addScore(gain)
			pops.pop("+" .. gain, cx, cy, C.money, {h = 0.09, w = 0.5, rise = 0.1})
			if lines >= 2 then pops.pop(BANNER[math.min(lines, #BANNER)], 0.5, 0.36, rgb(120, 220, 255), {h = 0.12, life = 1.1, rise = 0.05, tilt = -4}) end
			if streak >= 2 then pops.pop("COMBO x" .. streak .. "!", 0.5, 0.5, rgb(255, 210, 60), {h = 0.13, life = 1.2, rise = 0.06, tilt = 3}) end
			shaker.kick(0.006 + lines * 0.004, 0.25)
			if next(grid) == nil then
				addScore(300)
				pops.pop("PERFECT CLEAR! +300", 0.5, 0.24, rgb(255, 120, 220), {h = 0.1, life = 1.8, rise = 0.04})
				confetti(40)
			end
			UI.SFX.play("ding", 1.4 + lines * 0.15, 0.5)
		else
			sinceClear = sinceClear + 1
			if sinceClear >= 3 then streak = 0 end -- the combo ends after 3 pieces without a clear
			UI.SFX.play("click", 2.2, 0.35)
		end
		if hand[1].used and hand[2].used and hand[3].used then deal() else drawTray() end
		if not anyFits() then gameOver() end
	end

	-- DRAGGING ------------------------------------------------------
	local function boardPoint(p)
		local fx, fy = fracIn(board, p)
		return V2(fx, fy)
	end
	-- where the dragged piece's middle is (above the finger on touch, so you can see it)
	local function floatCenter()
		local lift = drag.mouse and 0.25 or (hand[drag.i].h * 0.5 + 1.1)
		return V2(drag.p.X, drag.p.Y - lift * CW * easeOut(drag.t / 0.14))
	end
	local function dragTarget()
		local p, c = hand[drag.i], floatCenter()
		return snap(p, (c.X - PAD) / CW - p.w / 2, (c.Y - PAD) / CW - p.h / 2)
	end
	local function showFloat(p)
		float.Size = S2(p.w * CW, p.h * CW)
		for k, b in ipairs(floatBlocks) do
			local c = p.cells[k]
			b.f.Visible = c ~= nil
			if c then
				b.f.Position = S2((c[1] + 0.5) / p.w, (c[2] + 0.5) / p.h)
				b.f.Size = S2(0.92 / p.w, 0.92 / p.h)
				paint(b, p.color)
			end
		end
		float.Visible = true
	end
	local function finishReturn()
		if not ret then return end
		local i = ret.i
		ret = nil
		float.Visible = false
		drawSlot(i)
	end
	local function beginDrag(i, input, p)
		if phase ~= "play" or not hand[i] or hand[i].used or drag then return end
		finishReturn()
		drag = {i = i, input = input, mouse = input == nil or input.UserInputType ~= Enum.UserInputType.Touch, start = p, p = p, active = false, t = 0}
	end
	local function activate()
		drag.active = true
		drag.t = 0
		selected = nil
		local p = hand[drag.i]
		showFloat(p)
		drag.fromScale = trayScale(drag.i)
		floatScale.Scale = drag.fromScale
		float.Position = S2(drag.p.X, drag.p.Y)
		drawTray()
	end
	local function dragMoved(p)
		drag.p = boardPoint(p)
		if not drag.active then
			local d = (p - drag.start).Magnitude
			if d > math.max(8, slots[drag.i].btn.AbsoluteSize.X * 0.08) then activate() end
		end
	end
	local lastDown = 0
	for i = 1, 3 do
		local btn = slots[i].btn
		btn.InputBegan:Connect(function(input)
			if not isPress(input) or os.clock() - lastDown < 0.1 then return end
			lastDown = os.clock()
			local p = posOf(input)
			beginDrag(i, input, p)
			if drag then drag.p = boardPoint(p) end
		end)
	end
	local function drop()
		local d = drag
		drag = nil
		local p = hand[d.i]
		if not d.active then
			-- a TAP: select this piece (tap again to unselect), then tap the board to place it
			selected = (selected ~= d.i) and d.i or nil
			drawTray()
			return
		end
		local ox, oy = nil, nil
		if p and not p.used then
			drag = d
			ox, oy = dragTarget()
			drag = nil
		end
		if ox then
			float.Visible = false
			place(d.i, ox, oy)
		else
			-- no room there: the piece bounces back to the tray
			local c = float.Position
			ret = {i = d.i, t = 0, from = V2(c.X.Scale, c.Y.Scale), to = slotCenter(d.i), s0 = floatScale.Scale, s1 = trayScale(d.i)}
			setPreview(nil)
			UI.SFX.play("error")
		end
	end
	function app.move(input)
		if drag and ((drag.mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or (drag.input ~= nil and input == drag.input)) then
			dragMoved(posOf(input))
		elseif selected and input.UserInputType == Enum.UserInputType.MouseMovement then
			hoverP = boardPoint(posOf(input)) -- mouse hovering with a selected piece: show where it would go
		end
	end
	function app.release(input)
		if not drag then return end
		if (drag.mouse and input.UserInputType == Enum.UserInputType.MouseButton1) or (drag.input ~= nil and input == drag.input) then
			dragMoved(posOf(input))
			drop()
		end
	end
	-- TAP the board with a selected piece: it goes there (its middle on the cell you tapped)
	local function tapBoard(p)
		if phase ~= "play" or drag or not selected then return end
		local piece = hand[selected]
		if not piece or piece.used then selected = nil return end
		local bp = boardPoint(p)
		local ox, oy = snap(piece, (bp.X - PAD) / CW - piece.w / 2, (bp.Y - PAD) / CW - piece.h / 2)
		if ox then
			place(selected, ox, oy)
		else
			slots[selected].appear = 0.5 -- (a little wobble: it doesn't fit there)
			UI.SFX.play("error")
		end
	end
	catcher.InputBegan:Connect(function(input)
		if isPress(input) then tapBoard(posOf(input)) end
	end)

	function app.start()
		grid, anims, hand = {}, {}, {}
		score, shown, streak, sinceClear, bestStreak, linesTotal, newBest = 0, 0, 0, 0, 0, 0, false
		drag, selected, ret, preview, hoverP = nil, nil, nil, nil, nil
		float.Visible = false
		for _, b in pairs(tiles) do
			b.scale.Scale = 1
			b.f.Rotation = 0
		end
		parts.clear()
		pops.clear()
		panel.hide()
		repaint()
		deal()
		pg.setScore(0)
		hud()
		phase = "play"
	end
	local function resume()
		panel.hide()
		phase = "play"
	end
	function app.enter()
		if phase == "paused" then return end
		app.start()
	end
	function app.leave()
		if drag or ret then
			drag = nil
			finishReturn()
			setPreview(nil)
			float.Visible = false
			drawTray()
		end
		if phase == "play" then
			phase = "paused"
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Score  " .. score .. "\nBest  " .. bests.BlockBlast,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		if kc == Enum.KeyCode.P then
			if phase == "paused" then resume() else app.leave() end
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return then
			if phase == "over" then app.start() elseif phase == "paused" then resume() end
		end
	end
	function app.layout(wide)
		if wide then
			shaker.setBase(S2(0.4, 0.5))
			board.AnchorPoint, board.Size = V2(0.5, 0.5), S2(0.62, 0.98)
			tray.AnchorPoint, tray.Position, tray.Size = V2(1, 0.5), S2(0.99, 0.5), S2(0.24, 0.98)
			for i, s in ipairs(slots) do
				s.btn.Position, s.btn.Size = S2(0.5, 0.17 + (i - 1) * 0.33), S2(1, 0.31)
			end
		else
			shaker.setBase(S2(0.5, 0.01))
			board.AnchorPoint, board.Size = V2(0.5, 0), S2(0.98, 0.72)
			tray.AnchorPoint, tray.Position, tray.Size = V2(0.5, 1), S2(0.5, 0.995), S2(0.98, 0.25)
			for i, s in ipairs(slots) do
				s.btn.Position, s.btn.Size = S2(0.17 + (i - 1) * 0.33, 0.5), S2(0.31, 1)
			end
		end
	end

	function app.step(dt)
		local now = os.clock()
		parts.update(dt)
		pops.update(dt)
		shaker.update(dt)
		-- the score counts up
		if shown < score then
			shown = math.min(score, shown + math.max(1, (score - shown) * dt * 9))
			pg.setScore(math.floor(shown))
		end
		-- tile animations: pop in, flash + burst away, grey out at the end
		for k, a in pairs(anims) do
			local b = tiles[k]
			a.t = a.t + dt
			if a.kind == "in" then
				b.scale.Scale = lerp(1.3, 1, backOut(a.t / 0.2))
				if a.t >= 0.2 then
					b.scale.Scale = 1
					anims[k] = nil
				end
			elseif a.kind == "clear" then
				if a.t < 0 then
					paint(b, a.color)
					b.ov.BackgroundColor3 = WHITE
					b.ov.BackgroundTransparency = clamp(-a.t * 4, 0, 0.9) -- flashes white
				else
					if not a.burst then
						a.burst = true
						local x, y = math.floor(k / N), k % N
						parts.burst(PAD + (x + 0.5) * CW, PAD + (y + 0.5) * CW, {a.color, a.color:Lerp(WHITE, 0.5)}, 3, 0.55, 0.035, {rect = true, spin = 300})
					end
					local s = a.t / 0.26
					b.scale.Scale = (s < 0.3) and lerp(1, 1.18, s / 0.3) or lerp(1.18, 0, (s - 0.3) / 0.7)
					b.f.Rotation = s * 25
					b.ov.BackgroundTransparency = lerp(0, 1, s)
					if s >= 1 then
						anims[k] = nil
						b.scale.Scale = 1
						b.f.Rotation = 0
						b.ov.BackgroundTransparency = 1
						paint(b, grid[k])
						if preview then preview.dirty = true end
					end
				end
			elseif a.kind == "grey" then
				if a.t >= 0 and not a.done then
					a.done = true
					paint(b, grid[k] and grid[k]:Lerp(rgb(80, 80, 100), 0.75) or nil)
					b.scale.Scale = 0.85
				end
				if a.done then b.scale.Scale = lerp(b.scale.Scale, 1, clamp(dt * 12, 0, 1)) end
			end
		end
		if preview and preview.dirty then
			preview.dirty = nil
			repaint()
		end
		-- the tray: new pieces pop in, the selected one bobs
		for i, sl in ipairs(slots) do
			if sl.appear < 1 then
				sl.appear = math.min(1, sl.appear + dt * 3.2)
				sl.hscale.Scale = (sl.appear <= 0) and 0.01 or backOut(sl.appear)
			else
				sl.hscale.Scale = (selected == i) and (1.08 + math.sin(now * 7) * 0.05) or 1
			end
		end
		-- the dragged piece follows the finger and shows where it would land
		if drag and drag.active then
			drag.t = drag.t + dt
			local c = floatCenter()
			float.Position = S2(c.X, c.Y)
			floatScale.Scale = lerp(drag.fromScale, 1.08, easeOut(drag.t / 0.14))
			local ox, oy = dragTarget()
			setPreview(hand[drag.i], ox, oy)
		elseif ret then
			ret.t = ret.t + dt
			local k = ret.t / 0.34
			local pos = lerpV(ret.from, ret.to, backOut(k))
			float.Position = S2(pos.X, pos.Y)
			floatScale.Scale = lerp(ret.s0, ret.s1, easeOut(k))
			if k >= 1 then finishReturn() end
		elseif selected and hoverP and phase == "play" then
			local piece = hand[selected]
			if piece and not piece.used then
				local ox, oy = snap(piece, (hoverP.X - PAD) / CW - piece.w / 2, (hoverP.Y - PAD) / CW - piece.h / 2)
				setPreview(piece, ox, oy)
			end
		elseif preview then
			setPreview(nil)
		end
		-- the ghost + the lines it would clear glow
		if preview then
			local pulse = 0.5 + math.sin(now * 10) * 0.5
			for k in pairs(preview.lineCells) do
				if not anims[k] and not preview.cells[k] then tiles[k].ov.BackgroundTransparency = 0.15 + pulse * 0.35 end
			end
			for k in pairs(preview.cells) do
				if not anims[k] then tiles[k].ov.BackgroundTransparency = 0.45 + pulse * 0.25 end
			end
		end
		if phase == "ending" then
			endT = endT + dt
			if endT > 1.2 then showOver() end
		end
	end

	repaint()
	hud()
	return app
end

------------------------------------------------------------------
-- ARCHERY: pull back like a slingshot, mind the wind, hit the dummies (head 2, bullseye 3)
-- The world is measured in "units": x 0..1 across the scene, y 0..H down it (H = height / width).
------------------------------------------------------------------
local SKIES = { -- top, bottom, sun colour, ground (per round: day, afternoon, sunset, dusk, night)
	{rgb(100, 180, 255), rgb(215, 240, 255), rgb(255, 235, 120), rgb(95, 195, 75)},
	{rgb(80, 160, 245), rgb(255, 232, 190), rgb(255, 215, 90), rgb(100, 185, 70)},
	{rgb(255, 125, 90), rgb(255, 210, 140), rgb(255, 170, 70), rgb(110, 160, 60)},
	{rgb(110, 75, 170), rgb(255, 140, 120), rgb(255, 120, 90), rgb(80, 120, 70)},
	{rgb(16, 20, 64), rgb(64, 56, 128), rgb(240, 240, 255), rgb(40, 80, 60)},
}

-- the scenery, the archer and the HUD (no game logic here)
local function buildArcheryScene(pg)
	local V = {}
	local content = pg.content
	local scene = frame(content, {Name = "Scene", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundColor3 = WHITE, ClipsDescendants = true, ZIndex = 2})
	V.ratio = new("UIAspectRatioConstraint", {AspectRatio = 1.6}, scene)
	round(scene, 12)
	UI.stroke(scene, 4, C.ink)
	V.scene = scene
	V.sky = grad(scene, SKIES[1][1], SKIES[1][2])
	V.stars = {}
	for k = 1, 14 do
		local s = frame(scene, {AnchorPoint = V2(0.5, 0.5), Position = S2(math.random(), math.random() * 0.55), Size = S2(0.006, 0.006), BackgroundColor3 = WHITE, Visible = false, ZIndex = 1})
		square(s)
		round(s, true)
		V.stars[k] = s
	end
	V.sun = frame(scene, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.78, 0.2), Size = S2(0.11, 0.11), BackgroundColor3 = SKIES[1][3], ZIndex = 1})
	square(V.sun)
	round(V.sun, true)
	V.sunGlow = UI.stroke(V.sun, 6, WHITE, 0.6)
	V.clouds = {}
	for k = 1, 4 do
		local c = frame(scene, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.16, 0.08), BackgroundTransparency = 1, ZIndex = 2})
		for _, b in ipairs({{0.3, 0.6, 0.5}, {0.55, 0.45, 0.7}, {0.78, 0.62, 0.45}}) do
			local puff = frame(c, {AnchorPoint = V2(0.5, 0.5), Position = S2(b[1], b[2]), Size = S2(b[3], b[3] * 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.12, ZIndex = 2})
			round(puff, true)
		end
		V.clouds[k] = {f = c, x = math.random() * 1.2 - 0.1, y = 0.08 + math.random() * 0.3, s = 0.7 + math.random() * 0.6}
	end
	V.streaks = {}
	for k = 1, 6 do
		local s = frame(scene, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.05, 0.004), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, Visible = false, ZIndex = 3})
		round(s, true)
		V.streaks[k] = {f = s, x = math.random(), y = math.random() * 0.6}
	end
	-- the world (zooms in on a bullseye)
	local world = frame(scene, {Name = "World", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundTransparency = 1, ZIndex = 4})
	V.world, V.zoom = world, new("UIScale", {}, world)
	V.hills = {}
	for k, h in ipairs({{0.18, 0.5, 0.2}, {0.55, 0.62, 0.26}, {0.92, 0.48, 0.18}}) do
		local hill = frame(world, {AnchorPoint = V2(0.5, 0.5), Size = S2(h[2], h[3]), BackgroundColor3 = WHITE, ZIndex = 1})
		round(hill, true)
		V.hills[k] = {f = hill, x = h[1], w = h[2], h = h[3]}
	end
	V.ground = frame(world, {Size = S2(1.2, 0.3), Position = S2(-0.1, 0.86), BackgroundColor3 = SKIES[1][4], ZIndex = 2})
	V.groundGrad = grad(V.ground, WHITE, rgb(170, 190, 160))
	V.grassEdge = frame(V.ground, {Size = S2(1, 0.06), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, ZIndex = 2})
	-- YOU: your avatar's head on a little archer
	local me = frame(world, {Name = "Archer", AnchorPoint = V2(0.5, 1), BackgroundTransparency = 1, ZIndex = 6})
	for _, x in ipairs({0.36, 0.64}) do
		local leg = frame(me, {AnchorPoint = V2(0.5, 1), Position = S2(x, 1), Size = S2(0.2, 0.3), BackgroundColor3 = rgb(40, 50, 90), ZIndex = 6})
		round(leg, 0.3)
	end
	local torso = frame(me, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.36), Size = S2(0.66, 0.4), BackgroundColor3 = rgb(60, 170, 90), ZIndex = 7})
	round(torso, 0.25)
	UI.stroke(torso, 2, C.ink)
	grad(torso, WHITE, rgb(170, 180, 170))
	frame(torso, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.58), Size = S2(1, 0.14), BackgroundColor3 = rgb(120, 80, 40), ZIndex = 7}) -- belt
	local quiver = frame(me, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.2, 0.46), Size = S2(0.22, 0.4), Rotation = -20, BackgroundColor3 = rgb(140, 85, 40), ZIndex = 6})
	round(quiver, 0.3)
	local headImg = new("ImageLabel", {AnchorPoint = V2(0.5, 0), Position = S2(0.5, -0.04), Size = S2(1.1, 0.46), BackgroundColor3 = rgb(255, 220, 180),
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. (Players.LocalPlayer and Players.LocalPlayer.UserId or 1) .. "&w=150&h=150",
		ScaleType = Enum.ScaleType.Crop, BorderSizePixel = 0, ZIndex = 8}, me)
	new("UIAspectRatioConstraint", {AspectRatio = 1}, headImg)
	round(headImg, true)
	UI.stroke(headImg, 2.5, C.ink)
	V.me = me
	-- THE BOW (a square group that turns to aim; drawn facing right)
	local bow = frame(world, {Name = "Bow", AnchorPoint = V2(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 9})
	V.bow = bow
	local arm = frame(bow, {AnchorPoint = V2(0, 0.5), Position = S2(0.5, 0.5), Size = S2(0.27, 0.08), BackgroundColor3 = rgb(255, 214, 170), ZIndex = 9})
	round(arm, true)
	UI.stroke(arm, 1.5, C.ink)
	local function curve(t) return V2(0.72 + 0.1 * (1 - t * t), 0.5 + 0.42 * t) end
	for i = 0, 4 do
		local a, b = curve(-1 + i * 0.4), curve(-0.6 + i * 0.4)
		local d = b - a
		local seg = frame(bow, {AnchorPoint = V2(0.5, 0.5), Position = S2((a.X + b.X) / 2, (a.Y + b.Y) / 2), Size = S2(d.Magnitude * 1.2, 0.06),
			Rotation = math.deg(atan2(d.Y, d.X)), BackgroundColor3 = rgb(150, 85, 35), ZIndex = 10})
		round(seg, true)
		UI.stroke(seg, 1.5, rgb(60, 30, 10))
	end
	V.tips = {curve(-1), curve(1)}
	V.strings = {}
	for k = 1, 2 do
		V.strings[k] = frame(bow, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.4, 0.014), BackgroundColor3 = rgb(240, 240, 230), ZIndex = 11})
	end
	local nocked = frame(bow, {AnchorPoint = V2(0, 0.5), Position = S2(0.5, 0.5), Size = S2(0.62, 0.035), BackgroundColor3 = rgb(130, 80, 35), ZIndex = 12})
	local tipHead = frame(nocked, {AnchorPoint = V2(0.5, 0.5), Position = S2(1, 0.5), Size = S2(0.1, 3), Rotation = 45, BackgroundColor3 = rgb(200, 205, 215), ZIndex = 12})
	new("UIAspectRatioConstraint", {AspectRatio = 1}, tipHead)
	for _, s in ipairs({-1, 1}) do
		frame(nocked, {AnchorPoint = V2(0, 0.5), Position = S2(0, 0.5 + s * 1.1), Size = S2(0.18, 1.6), Rotation = s * 18, BackgroundColor3 = rgb(240, 70, 80), ZIndex = 12})
	end
	V.nocked = nocked
	V.hand = frame(bow, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.09, 0.09), BackgroundColor3 = rgb(255, 214, 170), ZIndex = 13})
	round(V.hand, true)
	UI.stroke(V.hand, 1.5, C.ink)
	-- the flying arrow (double length: the tip is in the middle, so turning it turns it around its tip)
	local function arrowSprite(parent, z)
		local a = frame(parent, {AnchorPoint = V2(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = z})
		frame(a, {AnchorPoint = V2(1, 0.5), Position = S2(0.5, 0.5), Size = S2(0.46, 0.35), BackgroundColor3 = rgb(130, 80, 35), ZIndex = z})
		local hd = frame(a, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.49, 0.5), Size = S2(0.06, 1), Rotation = 45, BackgroundColor3 = rgb(205, 210, 220), ZIndex = z})
		new("UIAspectRatioConstraint", {AspectRatio = 1}, hd)
		for _, s in ipairs({-1, 1}) do
			frame(a, {AnchorPoint = V2(0, 0.5), Position = S2(0.04, 0.5 + s * 0.3), Size = S2(0.1, 0.4), Rotation = s * 20, BackgroundColor3 = rgb(240, 70, 80), ZIndex = z})
		end
		return a
	end
	V.arrowSprite = arrowSprite
	V.arrow = arrowSprite(world, 14)
	V.dots = {}
	for k = 1, 22 do
		local d = frame(world, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.01, 0.01), BackgroundColor3 = WHITE, Visible = false, ZIndex = 13})
		round(d, true)
		UI.stroke(d, 1, C.ink, 0.4)
		V.dots[k] = d
	end
	-- pull band (from where you pressed to your finger) + power meter
	V.bandStart = frame(scene, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.03, 0.03), BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, Visible = false, ZIndex = 20})
	square(V.bandStart)
	round(V.bandStart, true)
	UI.stroke(V.bandStart, 2, C.ink, 0.3)
	V.band = frame(scene, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.1, 0.008), BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, Visible = false, ZIndex = 20})
	round(V.band, true)
	local meter = frame(scene, {AnchorPoint = V2(0, 1), Position = S2(0.015, 0.8), Size = S2(0.03, 0.4), BackgroundColor3 = rgb(20, 20, 30), BackgroundTransparency = 0.25, Visible = false, ZIndex = 21})
	round(meter, true)
	UI.stroke(meter, 2.5, C.ink)
	V.meter = meter
	V.meterFill = frame(meter, {AnchorPoint = V2(0, 1), Position = S2(0, 1), Size = S2(1, 0.5), BackgroundColor3 = C.green, ZIndex = 22})
	round(V.meterFill, true)
	V.meterText = text(scene, "", {AnchorPoint = V2(0, 1), Position = S2(0.05, 0.42), Size = S2(0.16, 0.07), TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 22, MaxSize = 30})
	-- HUD: round + goal (left), wind (middle), arrows left (right)
	local roundPill = pill(scene, rgb(40, 40, 70), {Position = S2(0.015, 0.025), Size = S2(0.3, 0.1), ZIndex = 24})
	V.roundText = text(roundPill, "ROUND 1", {Position = S2(0.06, 0.06), Size = S2(0.88, 0.5), ZIndex = 25, MaxSize = 26})
	local goalBack = frame(roundPill, {Position = S2(0.08, 0.62), Size = S2(0.84, 0.24), BackgroundColor3 = rgb(15, 15, 30), ZIndex = 25})
	round(goalBack, true)
	V.goalFill = frame(goalBack, {Size = S2(0, 1), BackgroundColor3 = C.yellow, ZIndex = 26})
	round(V.goalFill, true)
	V.goalText = text(goalBack, "", {Size = S2(1, 1.3), Position = S2(0, -0.15), ZIndex = 27, Stroke = 1.5, MaxSize = 16})
	local windPill = pill(scene, rgb(40, 40, 70), {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.025), Size = S2(0.26, 0.1), ZIndex = 24})
	V.windText = text(windPill, "WIND 0", {Position = S2(0.06, 0.1), Size = S2(0.55, 0.8), ZIndex = 25, MaxSize = 24})
	V.windChev = {}
	for k = 1, 3 do
		local ch = chevron(windPill, rgb(150, 220, 255), 0.6, 25)
		ch.Size = S2(0.16, 0.7)
		ch.Position = S2(0.66 + (k - 1) * 0.11, 0.5)
		V.windChev[k] = ch
	end
	local quiverPill = pill(scene, rgb(40, 40, 70), {AnchorPoint = V2(1, 0), Position = S2(0.985, 0.025), Size = S2(0.3, 0.1), ZIndex = 24})
	V.arrowIcons = {}
	for k = 1, 8 do
		local a = frame(quiverPill, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.1 + (k - 1) * 0.114, 0.5), Size = S2(0.05, 0.75), Rotation = 12, BackgroundColor3 = rgb(150, 95, 40), ZIndex = 25})
		round(a, true)
		frame(a, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, -0.05), Size = S2(1.8, 0.22), BackgroundColor3 = rgb(210, 215, 225), ZIndex = 26})
		frame(a, {AnchorPoint = V2(0.5, 1), Position = S2(0.5, 1.02), Size = S2(2, 0.25), BackgroundColor3 = rgb(240, 70, 80), ZIndex = 26})
		V.arrowIcons[k] = a
	end
	V.flash = frame(scene, {Size = S2(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 30})
	return V
end

local function buildArchery(env)
	local pg = env.page("Archery", {title = "Archery", color = rgb(255, 150, 40), bg0 = rgb(70, 46, 30), bg1 = rgb(22, 16, 14)})
	local app = {}
	local V = buildArcheryScene(pg)
	local world, scene = V.world, V.scene
	local parts = makeParticles(world, 60, 15)
	local pops = makePopups(scene, 8, 26)
	local shaker = makeShaker(scene)
	local panel = makePanel(pg.content, 60)
	local catcher = new("TextButton", {Name = "Aim", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 23}, scene)

	local G, VMAX, ARCH_X = 1.5, 1.85, 0.1
	local H, GROUND, archH, pivot = 1 / 1.6, 0.86 / 1.6, 0.18, V2(0.1, 0.4)
	local phase, round_, total, roundPts, goal, arrows, maxArrows = "idle", 1, 0, 0, 3, 5, 5
	local wind, hits, bulls, newBest = 0, 0, 0, false
	local targets, stuck, stuckNext = {}, {}, 1
	local aim, aimAngle, power, lastAngle = nil, -20, 0, -20
	local fly = nil -- {p, v}
	local waitT, introT, slowT, zoomT, vib, gameT = 0, 0, 0, 1, 0, 0
	local function U(x, y) return S2(x, y / H) end

	-- arrows that stick in targets / the ground (a reused pool)
	for k = 1, 16 do stuck[k] = {f = V.arrowSprite(world, 12)} end
	local function stick(parent, pos, size, rot)
		local s = stuck[stuckNext]
		stuckNext = stuckNext % #stuck + 1
		s.f.Parent = parent
		s.f.Position, s.f.Size, s.f.Rotation = pos, size, rot
		s.f.Visible = true
		return s
	end

	local function hud()
		pg.setScore(total)
		pg.setBest(bests.Archery)
		V.roundText.Text = "ROUND " .. round_
		V.goalFill.Size = S2(clamp(roundPts / math.max(1, goal), 0, 1), 1)
		V.goalFill.BackgroundColor3 = (roundPts >= goal) and C.green or C.yellow
		V.goalText.Text = roundPts .. " / " .. goal
		for k, a in ipairs(V.arrowIcons) do
			a.Visible = k <= maxArrows
			a.BackgroundTransparency = (k <= arrows) and 0 or 0.75
		end
	end
	local function setWind(w)
		wind = w
		local lvl = math.floor(math.abs(w) * 40 + 0.5)
		V.windText.Text = "WIND " .. lvl
		for k, ch in ipairs(V.windChev) do
			ch.Visible = lvl > 0 and (k == 1 or (k == 2 and lvl >= 5) or (k == 3 and lvl >= 10))
			ch.Rotation = (w < 0) and 180 or 0
		end
	end

	-- TARGETS ------------------------------------------------------
	local function clearTargets()
		for _, s in ipairs(stuck) do
			s.f.Visible = false
			s.f.Parent = world
		end
		for _, t in ipairs(targets) do t.f:Destroy() if t.rail then t.rail:Destroy() end end
		targets = {}
	end
	local function ring(parent, size, color, z)
		local r = frame(parent, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(size, size), BackgroundColor3 = color, ZIndex = z})
		round(r, true)
		return r
	end
	-- a straw dummy with a target for a head. The frame is twice its height so it falls over at its feet.
	local function addDummy(x, height, r, move)
		local w = r * 2.6
		local f = frame(world, {AnchorPoint = V2(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 7})
		local hf = 2 * r / (2 * height) -- head size as a fraction of the frame's height
		frame(f, {AnchorPoint = V2(0.5, 1), Position = S2(0.5, 0.5), Size = S2(0.14, 0.26), BackgroundColor3 = rgb(120, 75, 35), ZIndex = 7}) -- post
		frame(f, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.25), Size = S2(1.05, 0.025), BackgroundColor3 = rgb(120, 75, 35), ZIndex = 7}) -- arms
		local body = frame(f, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.15), Size = S2(0.72, 0.22), BackgroundColor3 = rgb(225, 190, 110), ZIndex = 8})
		round(body, 0.35)
		UI.stroke(body, 2, rgb(110, 80, 30))
		grad(body, WHITE, rgb(200, 190, 170))
		for _, y in ipairs({0.33, 0.66}) do
			frame(body, {Position = S2(0.1, y), Size = S2(0.8, 0.05), BackgroundColor3 = rgb(170, 130, 60), ZIndex = 8})
		end
		local head = frame(f, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0), Size = S2(2 * r / w, hf), BackgroundColor3 = WHITE, ZIndex = 9})
		round(head, true)
		UI.stroke(head, 2, C.ink)
		ring(head, 0.78, rgb(235, 60, 70), 9)
		ring(head, 0.56, WHITE, 9)
		ring(head, 0.36, rgb(255, 205, 50), 9)
		ring(head, 0.14, rgb(235, 60, 70), 9)
		local t = {kind = "dummy", f = f, x = x, baseX = x, height = height, r = r, w = w, move = move, alive = true, fall = 0}
		if move then
			t.rail = frame(world, {AnchorPoint = V2(0.5, 0.5), BackgroundColor3 = rgb(70, 60, 50), ZIndex = 3})
			round(t.rail, true)
		end
		table.insert(targets, t)
		return t
	end
	local BALLOON_C = {rgb(255, 80, 120), rgb(80, 180, 255), rgb(255, 200, 60), rgb(150, 100, 255)}
	local function addBalloon(x, y, r)
		local col = BALLOON_C[math.random(1, #BALLOON_C)]
		local f = frame(world, {AnchorPoint = V2(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 8})
		frame(f, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.5), Size = S2(0.03, 0.5), BackgroundColor3 = rgb(240, 240, 240), ZIndex = 8})
		local b = frame(f, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.25), Size = S2(1, 0.5), BackgroundColor3 = col, ZIndex = 9})
		round(b, true)
		UI.stroke(b, 2, col:Lerp(BLACK, 0.5))
		grad(b, WHITE, rgb(190, 190, 200), 45)
		local sh = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.32, 0.3), Size = S2(0.2, 0.28), Rotation = 25, BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, ZIndex = 9})
		round(sh, true)
		table.insert(targets, {kind = "balloon", f = f, x = x, baseY = y, y = y, r = r, color = col, alive = true, ph = math.random() * 6, sp = 1.5 + math.random()})
	end
	-- where a target is right now (moving ones slide / bob)
	local function updateTarget(t, dt)
		if t.kind == "dummy" then
			if t.alive and t.move then t.x = t.baseX + math.sin(gameT * t.move.speed + t.move.ph) * t.move.amp end
			if not t.alive then t.fall = math.min(1, t.fall + dt / 0.45) end
			t.f.Position = U(t.x, GROUND)
			t.f.Size = S2(t.w, 2 * t.height / H)
			t.f.Rotation = easeOut(t.fall) * 80
			if t.rail then
				t.rail.Position = U(t.baseX, GROUND + 0.006)
				t.rail.Size = S2(t.move.amp * 2 + t.w, 0.008 / H)
			end
		else
			if t.alive then t.y = t.baseY + math.sin(gameT * t.sp + t.ph) * 0.03 end
			t.f.Position = U(t.x, t.y + t.r)
			t.f.Size = S2(t.r * 2, t.r * 4.6 / H)
			t.f.Rotation = math.sin(gameT * 2 + t.ph) * 6
		end
	end

	-- LAYOUT: a wide scene on wide screens, a taller one on phones held upright
	local function placeWorld()
		GROUND = H * 0.86
		archH = math.min(0.19, H * 0.3)
		parts.H = H
		V.ground.Position = S2(-0.1, 0.86)
		for _, h in ipairs(V.hills) do
			h.f.Position = U(h.x, GROUND)
			h.f.Size = S2(h.w, h.h / H)
		end
		V.me.Position = U(ARCH_X, GROUND)
		V.me.Size = S2(archH * 0.45, archH / H)
		pivot = V2(ARCH_X + 0.012, GROUND - archH * 0.6)
		V.bow.Position = U(pivot.X, pivot.Y)
		V.bow.Size = S2(0.13, 0.13 / H)
		V.arrow.Size = S2(0.16, 0.02 / H)
		for _, d in ipairs(V.dots) do d.Size = S2(0.011, 0.011 / H) end
		for _, t in ipairs(targets) do updateTarget(t, 0) end
	end
	function app.layout(wide)
		local aspect = wide and 1.9 or 0.9
		V.ratio.AspectRatio = aspect
		H = 1 / aspect
		placeWorld()
		shaker.setBase(S2(0.5, 0.5))
	end

	local function setSky(r)
		local s = SKIES[math.min(r, #SKIES)]
		V.sky.Color = ColorSequence.new(s[1], s[2])
		V.sun.BackgroundColor3 = s[3]
		V.sun.Position = S2(0.8, r >= 5 and 0.16 or (0.14 + math.min(r - 1, 3) * 0.1))
		V.ground.BackgroundColor3 = s[4]
		for _, h in ipairs(V.hills) do h.f.BackgroundColor3 = s[4]:Lerp(s[2], 0.35) end
		for _, st in ipairs(V.stars) do st.Visible = r >= 5 end
	end

	-- ROUNDS ---------------------------------------------------------
	local function beginRound(r)
		round_ = r
		clearTargets()
		panel.hide()
		roundPts, hits, bulls = 0, 0, 0
		maxArrows = (r >= 4) and 6 or 5
		arrows = maxArrows
		goal = math.min(2 + r, 10)
		local maxWind = math.min(0.05 + (r - 1) * 0.07, 0.42)
		setWind((math.random() * 2 - 1) * maxWind)
		setSky(r)
		-- the targets: further, smaller and moving more as the rounds go on
		local n = math.min(3 + math.floor((r - 1) / 2), 5)
		local xs = {}
		for k = 1, n do
			local lo = 0.4 + (k - 1) * (0.55 / n)
			table.insert(xs, lo + math.random() * (0.55 / n) * 0.6)
		end
		local movers = math.min(n, r - 1)
		local r0 = math.max(0.02, 0.034 - r * 0.0018)
		for k, x in ipairs(xs) do
			local mv = nil
			if k > n - movers then mv = {amp = 0.03 + math.random() * 0.03, speed = 1 + r * 0.25 + math.random() * 0.6, ph = math.random() * 6} end
			addDummy(x, archH * (0.85 + math.random() * 0.55), r0 * (0.9 + math.random() * 0.25), mv)
		end
		if r >= 2 then
			for k = 1, (r >= 4) and 2 or 1 do
				addBalloon(0.45 + math.random() * 0.45, H * (0.25 + math.random() * 0.25) + (k - 1) * 0.04, 0.03)
			end
		end
		for _, t in ipairs(targets) do updateTarget(t, 0) end
		fly = nil
		V.arrow.Visible = false
		phase, introT = "intro", 1.3
		pops.pop("ROUND " .. r, 0.5, 0.36, rgb(255, 225, 90), {h = 0.16, life = 1.3, rise = 0.04})
		pops.pop("Goal: " .. goal .. " points", 0.5, 0.5, WHITE, {h = 0.08, life = 1.3, rise = 0.03})
		hud()
	end
	local function endRound()
		local passed = roundPts >= goal
		if total > bests.Archery then
			newBest = newBest or bests.Archery > 0
			bests.Archery = total
		end
		hud()
		local stats = "Hits  " .. hits .. " / " .. (maxArrows - arrows) .. "    Bullseyes  " .. bulls ..
			"\nRound  " .. roundPts .. " / " .. goal .. "    Total  " .. total .. "\nBest  " .. bests.Archery
		if passed then
			phase = "summary"
			panel.show({title = "ROUND " .. round_ .. " CLEAR!", color = rgb(60, 170, 80), lines = stats, a = "NEXT ROUND", aColor = C.green,
				onA = function() beginRound(round_ + 1) end, b = "Home", onB = function() env.goHome() end})
		else
			phase = "over"
			panel.show({title = "GAME OVER", color = rgb(200, 60, 70), lines = stats, best = newBest, a = "PLAY AGAIN",
				onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
		end
	end
	local function score(n, text, color, x, y)
		roundPts = roundPts + n
		total = total + n
		if total > bests.Archery and bests.Archery > 0 and not newBest then
			newBest = true
			pops.pop("NEW BEST!", 0.5, 0.25, rgb(255, 220, 80), {h = 0.1, life = 1.4, rise = 0.04})
		end
		pops.pop(text, x, (y - 0.03) / H, color, {h = 0.085, w = 0.6, rise = 0.12, life = 1.1})
		hud()
	end
	local function hitDummy(t, tip, angle)
		local headC = V2(t.x, GROUND - t.height + t.r)
		local d = (tip - headC).Magnitude
		local zone = (d < t.r * 0.36) and 3 or ((d < t.r * 1.02) and 2 or 1)
		hits = hits + 1
		t.alive = false
		-- the arrow sticks in the target (and falls over with it)
		local top = GROUND - t.height
		stick(t.f, S2((tip.X - (t.x - t.w / 2)) / t.w, (tip.Y - top) / (2 * t.height)), S2(0.16 / t.w, 0.02 / (2 * t.height)), angle)
		if zone == 3 then
			bulls = bulls + 1
			score(3, "BULLSEYE! +3", rgb(255, 215, 50), tip.X, tip.Y)
			slowT, zoomT = 0.5, 0
			world.AnchorPoint = V2(clamp(tip.X, 0, 1), clamp(tip.Y / H, 0, 1))
			world.Position = S2(clamp(tip.X, 0, 1), clamp(tip.Y / H, 0, 1))
			V.flash.BackgroundTransparency = 0.25
			parts.burst(tip.X, tip.Y, {rgb(255, 215, 50), WHITE, rgb(255, 120, 80)}, 26, 0.6, 0.016, {rect = true, spin = 400})
			UI.SFX.play("ding", 1.9, 0.5)
		elseif zone == 2 then
			score(2, "HEADSHOT! +2", rgb(255, 160, 60), tip.X, tip.Y)
			parts.burst(tip.X, tip.Y, {WHITE, rgb(235, 60, 70)}, 14, 0.45, 0.014, {rect = true, spin = 300})
			UI.SFX.play("ding", 1.6, 0.45)
		else
			score(1, "HIT +1", WHITE, tip.X, tip.Y)
			parts.burst(tip.X, tip.Y, {rgb(225, 190, 110), rgb(180, 140, 60)}, 12, 0.35, 0.012, {rect = true, spin = 200})
			UI.SFX.play("ding", 1.3, 0.4)
		end
		shaker.kick(zone == 3 and 0.012 or 0.006, 0.25)
	end

	-- SHOOTING -------------------------------------------------------
	local function launch(angle, pow)
		local a = math.rad(angle)
		local dirV = V2(math.cos(a), math.sin(a))
		return pivot + dirV * 0.05, dirV * (VMAX * pow)
	end
	local function shoot()
		local p, v = launch(aimAngle, power)
		fly = {p = p, v = v, trailT = 0}
		arrows = arrows - 1
		phase = "fly"
		vib = 1
		V.arrow.Visible = true
		UI.SFX.play("click", 1.3, 0.45)
		hud()
	end
	local function arrowDone()
		fly = nil
		V.arrow.Visible = false
		phase, waitT = "wait", 0.75
	end
	local function flyStep(dt)
		local acc = V2(wind, G)
		for _ = 1, 4 do
			local h = dt / 4
			fly.p = fly.p + fly.v * h + acc * (0.5 * h * h)
			fly.v = fly.v + acc * h
			local dirV = (fly.v.Magnitude > 1e-4) and fly.v.Unit or V2(1, 0)
			local tip = fly.p + dirV * 0.04
			local angle = math.deg(atan2(dirV.Y, dirV.X))
			for _, t in ipairs(targets) do
				if t.alive then
					if t.kind == "balloon" then
						if (tip - V2(t.x, t.y)).Magnitude < t.r * 1.1 then
							-- POP (the arrow flies on through)
							t.alive = false
							t.f.Visible = false
							hits = hits + 1
							parts.burst(t.x, t.y, {t.color, WHITE}, 18, 0.5, 0.016, {rect = true, spin = 500})
							score(2, "POP! +2", t.color:Lerp(WHITE, 0.3), t.x, t.y)
						end
					else
						local inHead = (tip - V2(t.x, GROUND - t.height + t.r)).Magnitude < t.r * 1.02
						local top = GROUND - t.height
						local inBody = math.abs(tip.X - t.x) < t.w * 0.36 and tip.Y > top + t.height * 0.28 and tip.Y < top + t.height * 0.75
						if inHead or inBody then
							hitDummy(t, tip, angle)
							arrowDone()
							return
						end
					end
				end
			end
			if tip.Y >= GROUND then
				-- stuck in the grass
				stick(world, U(tip.X, GROUND + 0.004), S2(0.16, 0.02 / H), angle)
				pops.pop("MISS", tip.X, (GROUND - 0.04) / H, rgb(220, 220, 230), {h = 0.06, w = 0.3, rise = 0.06, life = 0.8})
				parts.burst(tip.X, GROUND, {rgb(120, 90, 50), rgb(90, 160, 60)}, 6, 0.25, 0.01)
				arrowDone()
				return
			end
			if tip.X > 1.08 or tip.X < -0.08 or tip.Y < -1.5 then
				pops.pop("MISS", clamp(tip.X, 0.1, 0.9), 0.4, rgb(220, 220, 230), {h = 0.06, w = 0.3, rise = 0.06, life = 0.8})
				arrowDone()
				return
			end
		end
		local dirV = (fly.v.Magnitude > 1e-4) and fly.v.Unit or V2(1, 0)
		V.arrow.Position = U(fly.p.X + dirV.X * 0.04, fly.p.Y + dirV.Y * 0.04)
		V.arrow.Rotation = math.deg(atan2(dirV.Y, dirV.X))
		fly.trailT = fly.trailT + dt
		if fly.trailT > 0.02 then
			fly.trailT = 0
			parts.emit(fly.p.X - dirV.X * 0.04, fly.p.Y - dirV.Y * 0.04, 0, 0, WHITE, 0.007, {g = 0, drag = 0, life = 0.35})
		end
	end

	-- AIMING: press anywhere, pull back, let go
	local function maxPull()
		local w = scene.AbsoluteSize.X
		return clamp(150 / math.max(w, 1), 0.18, 0.4)
	end
	local function updateAim()
		local w = math.max(1, scene.AbsoluteSize.X)
		local d = (aim.start - aim.cur) / w
		power = clamp(d.Magnitude / maxPull(), 0, 1)
		if d.Magnitude > 0.01 then
			local a = math.deg(atan2(d.Y, d.X))
			if math.abs(a) > 90 then a = (a > 0 and 1 or -1) * (180 - math.abs(a)) end -- (pulling forwards still shoots forwards)
			aimAngle = clamp(a, -85, 70)
			lastAngle = aimAngle
		end
	end
	local function startAim(input, p)
		if phase ~= "ready" or arrows <= 0 or aim then return end
		aim = {input = input, mouse = input == nil or input.UserInputType ~= Enum.UserInputType.Touch, start = p, cur = p}
		power = 0
	end
	local lastDown = 0
	catcher.InputBegan:Connect(function(input)
		if not isPress(input) or os.clock() - lastDown < 0.1 then return end
		lastDown = os.clock()
		startAim(input, posOf(input))
	end)
	function app.move(input)
		if aim and ((aim.mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or (aim.input ~= nil and input == aim.input)) then
			aim.cur = posOf(input)
			updateAim()
		end
	end
	function app.release(input)
		if not aim then return end
		if (aim.mouse and input.UserInputType == Enum.UserInputType.MouseButton1) or (aim.input ~= nil and input == aim.input) then
			aim.cur = posOf(input)
			updateAim()
			aim = nil
			if phase == "ready" and power >= 0.12 then
				shoot()
			elseif phase == "ready" then
				pops.pop("Pull back further!", 0.5, 0.62, WHITE, {h = 0.07, life = 1, rise = 0.03})
			end
		end
	end

	-- draw the bow, the string, the dotted path and the power meter
	local function setString(nx)
		for k, tip in ipairs(V.tips) do
			local d = V2(nx, 0.5) - tip
			local s = V.strings[k]
			s.Position = S2((tip.X + nx) / 2, (tip.Y + 0.5) / 2)
			s.Size = S2(d.Magnitude, 0.014)
			s.Rotation = math.deg(atan2(d.Y, d.X))
		end
		V.nocked.Position = S2(nx, 0.5)
		V.hand.Position = S2(nx, 0.5)
	end
	local function drawAim(dt)
		local aiming = aim ~= nil
		local pw = aiming and power or 0
		V.bow.Rotation = turnTo(V.bow.Rotation, aiming and aimAngle or lastAngle, clamp(dt * 20, 0, 1))
		vib = math.max(0, vib - dt * 3)
		setString(0.72 - pw * 0.3 + math.sin(gameT * 70) * 0.04 * vib)
		V.nocked.Visible = (phase == "ready" or phase == "intro") and arrows > 0
		V.meter.Visible, V.meterText.Visible = aiming, aiming
		V.bandStart.Visible, V.band.Visible = aiming, aiming
		local dotsOn = aiming and pw > 0.05
		if aiming then
			V.meterFill.Size = S2(1, math.max(0.04, pw))
			V.meterFill.BackgroundColor3 = C.green:Lerp(C.yellow, clamp(pw * 2, 0, 1)):Lerp(C.red, clamp(pw * 2 - 1, 0, 1))
			V.meterText.Text = math.floor(pw * 100 + 0.5) .. "%"
			local sx, sy = fracIn(scene, aim.start)
			local cx, cy = fracIn(scene, aim.cur)
			V.bandStart.Position = S2(sx, sy)
			V.band.Position = S2((sx + cx) / 2, (sy + cy) / 2)
			local w, hgt = scene.AbsoluteSize.X, scene.AbsoluteSize.Y
			local dpx = V2((cx - sx) * w, (cy - sy) * hgt)
			V.band.Size = S2(dpx.Magnitude / math.max(w, 1), 0.008)
			V.band.Rotation = math.deg(atan2(dpx.Y, dpx.X))
		end
		-- the dotted path (with gravity AND wind)
		local p0, v0 = launch(aimAngle, pw)
		local acc = V2(wind, G)
		local ended = false
		for k, d in ipairs(V.dots) do
			local t = k * 0.05
			local p = p0 + v0 * t + acc * (0.5 * t * t)
			if not dotsOn or ended or p.Y > GROUND or p.X > 1.05 then
				ended = ended or (dotsOn and (p.Y > GROUND or p.X > 1.05))
				d.Visible = false
			else
				d.Visible = true
				d.Position = U(p.X, p.Y)
				d.BackgroundTransparency = clamp(k / #V.dots, 0, 0.85)
			end
		end
	end

	function app.start()
		total, newBest, gameT = 0, false, 0
		aim, fly = nil, nil
		slowT, zoomT = 0, 1
		parts.clear()
		pops.clear()
		beginRound(1)
	end
	local function resume()
		panel.hide()
		phase = app.resumeTo or "ready"
	end
	function app.enter()
		if phase == "paused" or phase == "summary" then return end -- (keeps your round)
		app.start()
	end
	function app.leave()
		aim = nil
		if phase == "ready" or phase == "fly" or phase == "intro" or phase == "wait" then
			app.resumeTo = phase
			phase = "paused"
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Round  " .. round_ .. "\nTotal  " .. total .. "\nBest  " .. bests.Archery,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		if kc == Enum.KeyCode.P then
			if phase == "paused" then resume() else app.leave() end
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return then
			if panel.isOpen() and panel.onA then panel.onA() end
		end
	end

	function app.step(dtReal)
		local now = os.clock()
		-- slow motion + zoom + flash after a bullseye
		local dt = dtReal
		if slowT > 0 then
			slowT = slowT - dtReal
			dt = dtReal * 0.3
		end
		if zoomT < 1 then
			zoomT = math.min(1, zoomT + dtReal / 1.1)
			V.zoom.Scale = 1 + 0.2 * math.sin(zoomT * math.pi)
		else
			V.zoom.Scale = 1
		end
		V.flash.BackgroundTransparency = math.min(1, V.flash.BackgroundTransparency + dtReal * 2.5)
		parts.update(dt)
		pops.update(dtReal)
		shaker.update(dtReal)
		-- clouds + wind streaks drift with the wind
		for _, c in ipairs(V.clouds) do
			c.x = c.x + (0.006 + wind * 0.15) * dt
			if c.x > 1.25 then c.x = -0.25 elseif c.x < -0.25 then c.x = 1.25 end
			c.f.Position = S2(c.x, c.y)
			c.f.Size = S2(0.16 * c.s, 0.08 * c.s / H * 0.6)
		end
		for _, s in ipairs(V.streaks) do
			s.f.Visible = math.abs(wind) > 0.04
			s.x = s.x + wind * 1.4 * dt
			if s.x > 1.1 then s.x, s.y = -0.1, math.random() * 0.6 elseif s.x < -0.1 then s.x, s.y = 1.1, math.random() * 0.6 end
			s.f.Position = S2(s.x, s.y)
		end
		V.sunGlow.Transparency = 0.55 + math.sin(now * 2) * 0.15
		if phase == "paused" or phase == "idle" then return end
		gameT = gameT + dt
		for _, t in ipairs(targets) do updateTarget(t, dt) end
		if phase == "intro" then
			introT = introT - dt
			if introT <= 0 then phase = "ready" end
		elseif phase == "fly" and fly then
			flyStep(dt)
		elseif phase == "wait" then
			waitT = waitT - dt
			if waitT <= 0 then
				local standing = 0
				for _, t in ipairs(targets) do if t.kind == "dummy" and t.alive then standing = standing + 1 end end
				if standing == 0 and arrows > 0 then
					-- every dummy down: the arrows you have left are bonus points
					local bonus = arrows * 2
					score(bonus, "ALL DOWN! +" .. bonus, rgb(120, 255, 140), 0.5, H * 0.45)
					arrows = 0
					hud()
					phase, waitT = "wait", 1
				elseif standing == 0 or arrows <= 0 then
					endRound()
				else
					phase = "ready"
				end
			end
		end
		drawAim(dt)
	end

	app.layout(false)
	setSky(1)
	setWind(0)
	hud()
	return app
end

------------------------------------------------------------------
-- THE PHONE: status bar, wallpaper, app icons, apps that zoom open from their icon
------------------------------------------------------------------
-- app icon pictures (drawn with frames)
local function drawSnakeIcon(b)
	for k = 0, 5 do
		local t = k / 5
		local seg = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.2 + t * 0.55, 0.62 + math.sin(t * math.pi * 1.6) * 0.14), Size = S2(0.2, 0.2),
			BackgroundColor3 = rgb(200, 255, 120):Lerp(rgb(255, 240, 90), (k % 2) * 0.5), ZIndex = 3})
		round(seg, true)
		UI.stroke(seg, 1.5, rgb(20, 70, 30))
	end
	local hd = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.8, 0.36), Size = S2(0.27, 0.25), BackgroundColor3 = rgb(200, 255, 120), ZIndex = 4})
	round(hd, 0.45)
	UI.stroke(hd, 1.5, rgb(20, 70, 30))
	for _, y in ipairs({0.3, 0.7}) do
		local e = frame(hd, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.6, y), Size = S2(0.3, 0.32), BackgroundColor3 = WHITE, ZIndex = 5})
		round(e, true)
		local p = frame(e, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.6, 0.5), Size = S2(0.5, 0.5), BackgroundColor3 = C.ink, ZIndex = 6})
		round(p, true)
	end
	frame(b, {AnchorPoint = V2(0, 0.5), Position = S2(0.92, 0.36), Size = S2(0.08, 0.03), BackgroundColor3 = rgb(230, 40, 70), ZIndex = 3})
	local apple = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.28, 0.27), Size = S2(0.18, 0.18), BackgroundColor3 = rgb(240, 50, 60), ZIndex = 3})
	round(apple, true)
	UI.stroke(apple, 1.5, rgb(120, 20, 30))
end
local function drawBlastIcon(b)
	local cols = {{rgb(255, 70, 85), rgb(255, 215, 50), nil}, {rgb(40, 200, 240), rgb(255, 215, 50), rgb(80, 215, 90)}, {rgb(40, 200, 240), rgb(255, 150, 40), rgb(80, 215, 90)}}
	for y = 1, 3 do
		for x = 1, 3 do
			local c = cols[y][x]
			if c then
				local blk = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.25 + (x - 1) * 0.25, 0.25 + (y - 1) * 0.25), Size = S2(0.23, 0.23), BackgroundColor3 = c, ZIndex = 3})
				round(blk, 0.22)
				UI.stroke(blk, 1.5, c:Lerp(BLACK, 0.6))
				new("UIGradient", {Rotation = 90, Color = BEVEL}, blk)
			end
		end
	end
	local spark = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.78, 0.22), Size = S2(0.16, 0.16), Rotation = 45, BackgroundColor3 = WHITE, ZIndex = 4})
	round(spark, 0.2)
end
local function drawArcheryIcon(b)
	for k, c in ipairs({WHITE, rgb(235, 60, 70), WHITE, rgb(235, 60, 70), rgb(255, 205, 50)}) do
		local r = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.46, 0.54), Size = S2(0.76 - (k - 1) * 0.15, 0.76 - (k - 1) * 0.15), BackgroundColor3 = c, ZIndex = 3})
		round(r, true)
		if k == 1 then UI.stroke(r, 1.5, C.ink) end
	end
	local arrow = frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.62, 0.38), Size = S2(0.62, 0.05), Rotation = -40, BackgroundColor3 = rgb(110, 65, 30), ZIndex = 4})
	for _, s in ipairs({-1, 1}) do
		frame(arrow, {AnchorPoint = V2(0, 0.5), Position = S2(0.8, 0.5 + s * 1.2), Size = S2(0.22, 1.6), Rotation = s * 25, BackgroundColor3 = rgb(70, 160, 255), ZIndex = 4})
	end
end
local APPS = {
	{key = "Snake", label = "Snake", c0 = rgb(110, 230, 120), c1 = rgb(30, 140, 70), draw = drawSnakeIcon, build = buildSnake},
	{key = "BlockBlast", label = "Block Blast", c0 = rgb(190, 130, 255), c1 = rgb(90, 40, 200), draw = drawBlastIcon, build = buildBlast},
	{key = "Archery", label = "Archery", c0 = rgb(255, 190, 80), c1 = rgb(235, 85, 45), draw = drawArcheryIcon, build = buildArchery},
}

function Phone.init(ctx)
	UI = ctx.UI
	C, new = UI.C, UI.new
	-- (made wide so the header has studs all the way: the size used is picked when it opens)
	local win = UI.window({Name = "Phone", Title = "Phone", Color = rgb(40, 40, 52), Size = Vector2.new(860, 700)})
	win.size = Vector2.new(440, 700)
	win.page.Visible = false
	-- the window IS the phone: a black case with rounded corners (no title bar)
	win.header.Visible = false
	win.frame.BackgroundColor3 = rgb(16, 16, 22)
	win.frame.BackgroundTransparency = 0
	local case = win.frame:FindFirstChildOfClass("UICorner")
	if case then case.CornerRadius = UDim.new(0, 34) end
	local rim = win.frame:FindFirstChildOfClass("UIStroke")
	if rim then
		rim.Color = rgb(90, 90, 110)
		rim.Thickness = 4
		rim.Transparency = 0
	end
	grad(win.frame, rgb(255, 255, 255), rgb(150, 150, 170), 30)
	for _, b in ipairs({{0.18, 46}, {0.3, 46}}) do -- volume buttons on the side
		local btn = frame(win.frame, {AnchorPoint = V2(1, 0), Position = UDim2.new(0, 1, b[1], 0), Size = UDim2.fromOffset(5, b[2]), BackgroundColor3 = rgb(70, 70, 86)})
		round(btn, 3)
	end
	win.body.Position = UDim2.fromOffset(10, 10)
	win.body.Size = UDim2.new(1, -20, 1, -20)
	local screen = new("Frame", {Name = "Screen", Size = S2(1, 1), BackgroundColor3 = rgb(10, 10, 16), ClipsDescendants = true, BorderSizePixel = 0, ZIndex = 2}, win.body)
	round(screen, 26)

	local env = {}
	local apps, current, layoutWide = {}, "Home", nil
	local scorePulses = {}

	-- WALLPAPER: a deep gradient with soft glowing bubbles
	local wall = frame(screen, {Name = "Wallpaper", Size = S2(1, 1), BackgroundColor3 = WHITE, ZIndex = 1})
	new("UIGradient", {Rotation = 120, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(120, 70, 230)),
		ColorSequenceKeypoint.new(0.5, rgb(60, 90, 220)),
		ColorSequenceKeypoint.new(1, rgb(30, 190, 210)),
	})}, wall)
	local bubbles = {}
	for k = 1, 7 do
		local s = 0.12 + math.random() * 0.25
		local f = frame(wall, {AnchorPoint = V2(0.5, 0.5), Size = S2(s, s), BackgroundColor3 = (k % 2 == 0) and rgb(255, 150, 230) or rgb(150, 230, 255),
			BackgroundTransparency = 0.8, ZIndex = 1})
		square(f)
		round(f, true)
		bubbles[k] = {f = f, x = math.random(), y = math.random(), ph = math.random() * 6, sp = 0.2 + math.random() * 0.3}
	end

	-- HOME SCREEN
	local home = frame(screen, {Name = "Home", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundTransparency = 1, ZIndex = 5})
	local homeScale = new("UIScale", {}, home)
	local clockBig = text(home, "12:00", {AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.new(0.8, 0, 0.13, 0), Stroke = 0, MaxSize = 96, ZIndex = 2})
	local dateL = text(home, "", {AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0.13, 38), Size = UDim2.new(0.8, 0, 0.045, 0), Stroke = 0, MaxSize = 22,
		TextColor3 = rgb(230, 230, 255), ZIndex = 2})
	local widget = frame(home, {AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0.19, 46), Size = UDim2.new(0.9, 0, 0.19, 0), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82, ZIndex = 2})
	round(widget, 18)
	UI.stroke(widget, 1.5, WHITE, 0.55)
	text(widget, "MY BEST SCORES", {Position = S2(0.05, 0.06), Size = S2(0.9, 0.24), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, MaxSize = 18,
		TextColor3 = rgb(255, 235, 140), ZIndex = 3})
	local bestLabels = {}
	for i, a in ipairs(APPS) do
		local col = frame(widget, {Position = S2(0.04 + (i - 1) * 0.32, 0.36), Size = S2(0.3, 0.58), BackgroundColor3 = a.c1, BackgroundTransparency = 0.35, ZIndex = 3})
		round(col, 12)
		text(col, a.label, {Position = S2(0.06, 0.06), Size = S2(0.88, 0.36), Stroke = 1.5, MaxSize = 16, ZIndex = 4})
		bestLabels[a.key] = text(col, "0", {Position = S2(0.06, 0.42), Size = S2(0.88, 0.54), Stroke = 2, MaxSize = 30, TextColor3 = rgb(255, 240, 160), ZIndex = 4})
	end
	local function refreshBests()
		for k, l in pairs(bestLabels) do l.Text = tostring(bests[k] or 0) end
	end
	local icons = {}
	for i, a in ipairs(APPS) do
		local slot = frame(home, {AnchorPoint = V2(0.5, 0), Position = S2(0.2 + (i - 1) * 0.3, 0.58), Size = S2(0.27, 0.25), BackgroundTransparency = 1, ZIndex = 2})
		local btn = new("TextButton", {Name = a.key, Text = "", AutoButtonColor = false, AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0), Size = S2(1, 0.74),
			BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3}, slot)
		square(btn)
		round(btn, 0.26)
		UI.stroke(btn, 2.5, C.ink)
		grad(btn, a.c0, a.c1, 100)
		local shine = frame(btn, {Position = S2(0.08, 0.05), Size = S2(0.84, 0.34), BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, ZIndex = 3})
		round(shine, 0.4)
		a.draw(btn)
		UI.pressable(btn)
		UI.label(slot, a.label, {Position = S2(0, 0.77), Size = S2(1, 0.21), Max = 18, Min = 8, Stroke = 2, TextWrapped = false, ZIndex = 3})
		icons[a.key] = btn
		btn.Activated:Connect(function() env.openApp(a.key) end)
	end
	text(home, "Tap an app to play!", {AnchorPoint = V2(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.new(0.7, 0, 0.04, 0), Stroke = 0, MaxSize = 18,
		TextColor3 = rgb(225, 225, 255), TextTransparency = 0.15, ZIndex = 2})

	-- STATUS BAR: time, the camera "island", signal and battery
	local status = frame(screen, {Name = "StatusBar", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, ZIndex = 50})
	local timeL = text(status, "12:00", {Position = UDim2.fromOffset(22, 5), Size = UDim2.new(0, 64, 0, 19), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 0, MaxSize = 17, ZIndex = 51})
	local island = frame(status, {AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(92, 22), BackgroundColor3 = BLACK, ZIndex = 51})
	round(island, true)
	local cam = frame(island, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.82, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = rgb(30, 40, 70), ZIndex = 52})
	round(cam, true)
	for k = 1, 4 do
		frame(status, {AnchorPoint = V2(0, 1), Position = UDim2.new(1, -96 + k * 5, 0, 21), Size = UDim2.fromOffset(3, 3 + k * 3), BackgroundColor3 = WHITE, ZIndex = 51})
	end
	local batt = frame(status, {AnchorPoint = V2(1, 0), Position = UDim2.new(1, -22, 0, 9), Size = UDim2.fromOffset(25, 12), BackgroundTransparency = 1, ZIndex = 51})
	round(batt, 4)
	UI.stroke(batt, 1.5, WHITE, 0.2)
	local battFill = frame(batt, {Position = UDim2.fromOffset(2, 2), Size = UDim2.new(0.9, -4, 1, -4), BackgroundColor3 = WHITE, ZIndex = 52})
	round(battFill, 2)
	frame(batt, {AnchorPoint = V2(0, 0.5), Position = UDim2.new(1, 1, 0.5, 0), Size = UDim2.fromOffset(2, 5), BackgroundColor3 = WHITE, ZIndex = 52})
	local battL = text(status, "92", {AnchorPoint = V2(1, 0), Position = UDim2.new(1, -50, 0, 7), Size = UDim2.fromOffset(24, 15), Stroke = 0, MaxSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 51})
	local battery, closedAt = 92, os.clock()
	local DAYS = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
	local MONTHS = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	local function updateClock()
		local ok, t = pcall(os.date, "*t")
		if ok and type(t) == "table" and t.hour then
			local hm = string.format("%d:%02d", t.hour, t.min)
			timeL.Text = hm
			clockBig.Text = hm
			dateL.Text = (DAYS[t.wday] or "") .. ", " .. tostring(t.day) .. " " .. (MONTHS[t.month] or "")
		end
		local b = math.floor(battery + 0.5)
		battL.Text = tostring(b)
		battFill.Size = UDim2.new(0.9 * b / 100, -4 * b / 100, 1, -4)
		battFill.BackgroundColor3 = (b <= 20) and C.red or WHITE
	end

	-- the bar at the bottom: tap it to go home
	local homeBar = new("TextButton", {Name = "HomeBar", Text = "", AutoButtonColor = false, AnchorPoint = V2(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.42, 0, 0, 18), BackgroundTransparency = 1, ZIndex = 52}, screen)
	local homePill = frame(homeBar, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, ZIndex = 53})
	round(homePill, true)

	-- AN APP PAGE: the app bar (back, title, score + best, pause) and the area for the game
	function env.page(name, opt)
		local f = frame(screen, {Name = name, AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundColor3 = WHITE, Visible = false, Active = true, ZIndex = 10})
		round(f, 26)
		grad(f, opt.bg0, opt.bg1)
		local zs = new("UIScale", {}, f)
		local bar = frame(f, {Name = "AppBar", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 5})
		local back = new("TextButton", {Name = "Back", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(10, 2), Size = UDim2.fromOffset(42, 36),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 6}, bar)
		round(back, 12)
		chevron(back, WHITE, 0.62, 7).Rotation = 180
		UI.pressable(back)
		back.Activated:Connect(function() env.goHome() end)
		UI.label(bar, opt.title, {Position = UDim2.fromOffset(60, 3), Size = UDim2.new(0.5, -110, 0, 34), Max = 24, Min = 10, Stroke = 2.5, TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6})
		local sp = pill(bar, opt.color, {AnchorPoint = V2(1, 0), Position = UDim2.new(1, -60, 0, 3), Size = UDim2.new(0.44, 0, 0, 34), ZIndex = 6})
		local spScale = new("UIScale", {}, sp)
		local scoreT = text(sp, "0", {Position = S2(0.07, 0.04), Size = S2(0.42, 0.92), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5, MaxSize = 28, ZIndex = 7})
		local bestT = text(sp, "BEST 0", {Position = S2(0.48, 0.22), Size = S2(0.46, 0.56), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 1.5, MaxSize = 15,
			TextColor3 = rgb(255, 240, 170), ZIndex = 7})
		local pause = new("TextButton", {Name = "Pause", Text = "", AutoButtonColor = false, AnchorPoint = V2(1, 0), Position = UDim2.new(1, -10, 0, 2), Size = UDim2.fromOffset(42, 36),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 6}, bar)
		round(pause, 12)
		for _, x in ipairs({0.38, 0.62}) do
			local b = frame(pause, {AnchorPoint = V2(0.5, 0.5), Position = S2(x, 0.5), Size = S2(0.14, 0.5), BackgroundColor3 = WHITE, ZIndex = 7})
			round(b, 2)
			UI.stroke(b, 1.5, C.ink)
		end
		UI.pressable(pause)
		pause.Activated:Connect(function()
			local a = apps[name]
			if a and a.app and current == name then a.app.key(Enum.KeyCode.P) end
		end)
		local content = frame(f, {Name = "Game", Position = UDim2.fromOffset(8, 74), Size = UDim2.new(1, -16, 1, -96), BackgroundTransparency = 1, ZIndex = 4})
		local pg = {frame = f, content = content, zs = zs, shownScore = nil}
		function pg.setScore(n)
			local s = tostring(n)
			if scoreT.Text ~= s then
				scoreT.Text = s
				spScale.Scale = 1.15
				scorePulses[spScale] = true
			end
		end
		function pg.setBest(n) bestT.Text = "BEST " .. tostring(n) end
		apps[name] = apps[name] or {}
		apps[name].page = pg
		return pg
	end
	function env.isOpen() return UI.isOpen("Phone") end
	function env.current() return current end

	-- OPEN / CLOSE an app: it zooms out of its icon (and back into it)
	local animToken = 0
	local function iconCenter(key)
		local btn, sp, ss = icons[key], screen.AbsolutePosition, screen.AbsoluteSize
		if not btn or ss.X < 1 or ss.Y < 1 then return S2(0.5, 0.5) end
		local c = btn.AbsolutePosition + btn.AbsoluteSize / 2
		return S2(clamp((c.X - sp.X) / ss.X, 0, 1), clamp((c.Y - sp.Y) / ss.Y, 0, 1))
	end
	local function relayout()
		local s = screen.AbsoluteSize
		local wide = s.X > s.Y * 1.05
		if wide == layoutWide then return end
		layoutWide = wide
		for _, a in pairs(apps) do
			if a.app then a.app.layout(wide) end
		end
	end
	function env.openApp(key)
		if current == key then return end
		local spec
		for _, a in ipairs(APPS) do if a.key == key then spec = a end end
		if not spec then return end
		if current ~= "Home" then
			local old = apps[current]
			if old and old.app then old.app.leave() end
			if old and old.page then old.page.frame.Visible = false end
		end
		local entry = apps[key] or {}
		apps[key] = entry
		if not entry.app then
			entry.app = spec.build(env)
			if layoutWide == nil then relayout() else entry.app.layout(layoutWide) end
		end
		current = key
		animToken = animToken + 1
		local f, zs = entry.page.frame, entry.page.zs
		f.Position = iconCenter(key)
		zs.Scale = 0.12
		f.Visible = true
		home.Visible = true
		UI.tween(zs, 0.34, {Scale = 1}, Enum.EasingStyle.Quint)
		UI.tween(f, 0.34, {Position = S2(0.5, 0.5)}, Enum.EasingStyle.Quint)
		UI.tween(homeScale, 0.34, {Scale = 1.12}, Enum.EasingStyle.Quint)
		local token = animToken
		task.delay(0.35, function()
			if token == animToken and current == key then home.Visible = false end
		end)
		UI.SFX.play("open", 1.6, 0.18)
		entry.app.enter()
	end
	function env.goHome()
		if current == "Home" then return end
		local key = current
		local entry = apps[key]
		current = "Home"
		if entry and entry.app then entry.app.leave() end
		refreshBests()
		home.Visible = true
		UI.tween(homeScale, 0.3, {Scale = 1}, Enum.EasingStyle.Quint)
		animToken = animToken + 1
		if entry and entry.page then
			local f, zs = entry.page.frame, entry.page.zs
			UI.tween(zs, 0.28, {Scale = 0.12}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			UI.tween(f, 0.28, {Position = iconCenter(key)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			local token = animToken
			task.delay(0.29, function()
				if token == animToken and current ~= key then f.Visible = false end
			end)
		end
		UI.SFX.play("close", 1.6, 0.15)
	end
	homeBar.Activated:Connect(function() env.goHome() end)
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

	-- ONE loop for the whole phone, connected only while the phone is open
	local loopConn, clockT = nil, 0
	local function frameStep(dt)
		dt = math.min(dt, 0.1)
		clockT = clockT - dt
		if clockT <= 0 then
			clockT = 1
			battery = math.max(5, battery - 1 / 45)
			updateClock()
		end
		for sc in pairs(scorePulses) do
			sc.Scale = lerp(sc.Scale, 1, clamp(dt * 10, 0, 1))
			if sc.Scale < 1.005 then
				sc.Scale = 1
				scorePulses[sc] = nil
			end
		end
		if current == "Home" or home.Visible then
			local t = os.clock()
			for _, b in ipairs(bubbles) do
				b.f.Position = S2(b.x + math.sin(t * b.sp + b.ph) * 0.06, b.y + math.cos(t * b.sp * 0.8 + b.ph) * 0.05)
			end
		end
		local a = apps[current]
		if a and a.app then a.app.step(dt) end
	end
	local function setLoop(on)
		if on and not loopConn then
			loopConn = RunService.RenderStepped:Connect(frameStep)
		elseif not on and loopConn then
			loopConn:Disconnect()
			loopConn = nil
		end
	end

	-- the phone picks its shape when it opens: upright on tall screens, sideways on short (phone) screens
	win.onOpen = function()
		local availH = (UI.vh or 720) - 94
		if availH < 560 then
			win.size = Vector2.new(math.clamp((UI.vw or 1280) - (UI.winLeft or 12) - 40, 460, 860), 700)
		else
			win.size = Vector2.new(440, 700)
		end
		battery = math.min(100, battery + (os.clock() - closedAt) / 6) -- it charges while it's closed
		refreshBests()
		updateClock()
		relayout()
	end

	-- keys + drags go to the app that's open
	UserInputService.InputBegan:Connect(function(input)
		if not UI.isOpen("Phone") or input.UserInputType ~= Enum.UserInputType.Keyboard or typing() then return end
		local a = apps[current]
		if a and a.app and a.app.key then a.app.key(input.KeyCode) end
	end)
	pcall(function()
		UserInputService.InputChanged:Connect(function(input)
			if not UI.isOpen("Phone") or not isMove(input) then return end
			local a = apps[current]
			if a and a.app and a.app.move then a.app.move(input) end
		end)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not isPress(input) then return end
		local a = apps[current]
		if a and a.app and a.app.release then a.app.release(input) end
	end)

	-- while the phone is open, the movement keys play the game instead of walking you around;
	-- closing it pauses the game and stops the loop
	local CAS = game:GetService("ContextActionService")
	local KEYS = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space}
	UI.WindowChanged:Connect(function(name)
		if name == "Phone" then
			pcall(function()
				CAS:BindActionAtPriority("StealABoxPhoneKeys", function() return Enum.ContextActionResult.Sink end, false, 3000, table.unpack(KEYS))
			end)
			setLoop(true)
		else
			pcall(function() CAS:UnbindAction("StealABoxPhoneKeys") end)
			if loopConn then closedAt = os.clock() end
			setLoop(false)
			local a = apps[current]
			if a and a.app then a.app.leave() end
		end
	end)
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt.Name == "PlayPhone" and not UI.isOpen("Phone") then UI.open("Phone") end
	end)
	-- click (or tap) the phone screen on your treadmill to play
	task.spawn(function()
		local root = workspace:WaitForChild("StealABox", 30)
		local plots = root and root:WaitForChild("Plots", 30)
		if not plots then return end
		for _, d in ipairs(plots:GetDescendants()) do
			if d:IsA("ClickDetector") and d.Name == "PhoneClick" then
				d.MouseClick:Connect(function(who)
					if who == game:GetService("Players").LocalPlayer and not UI.isOpen("Phone") then UI.open("Phone") end
				end)
			end
		end
	end)
	refreshBests()
	updateClock()
end

return Phone
