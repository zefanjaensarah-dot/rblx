--[[ STEAL A BOX - HUD (what's always on screen)
     Every region is a list layout, so things stack instead of overlapping:
       top-left      cash + speed counters, then the menu buttons (2 columns)
       top-right     timers (night / rainbow box / server luck)
       right         Home + Steal teleports and the Speed offer
       top-centre    area banner -> tutorial card -> notifications
       bottom-centre your unbox card -> carried box + Drop -> treadmill bar
     Screen effects (red chase edges, flashes, BONK, confetti) live on their own layers. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Hud = {}

local function rgbLerp(a, b, t) return a:Lerp(b, t) end
local function IS_TOUCH()
	local UIS = game:GetService("UserInputService")
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

function Hud.init(ctx)
	local UI, Config, player = ctx.UI, ctx.Config, ctx.player
	local C, new, box = UI.C, UI.new, UI.box
	local root = UI.root
	local fmt = Config.FormatNum
	local hud = {}
	ctx.hud = hud

	------------------------------------------------------------------
	-- BOTTOM-LEFT: speed + cash (big candy pills, the icon sticks out on the left)
	------------------------------------------------------------------
	local TOUCH = UI.isTouch
	local CUR_W = TOUCH and 290 or 330
	local currency = box(root, {Name = "Currency", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(CUR_W, 150), ZIndex = 2})
	UI.list(currency, 8, nil, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
	hud.currency = currency

	-- just the numbers with a dark outline (no background); cash has its coin
	local function counter(iconName, iconColor, textColor, order)
		local holder = box(currency, {Size = UDim2.fromOffset(CUR_W - 10, 62), LayoutOrder = order})
		local icon
		if iconName then
			icon = UI.icon(iconName, holder, UDim2.fromOffset(54, 54), UDim2.fromOffset(0, 4), iconColor)
		else
			icon = box(holder, {Size = UDim2.fromOffset(0, 0), Visible = false})
		end
		local x = iconName and 62 or 4
		local value = UI.label(holder, "0", {Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x, 0, 40), TextXAlignment = Enum.TextXAlignment.Left,
			Max = 40, Min = 14, Stroke = 3.4, TextWrapped = false, TextColor3 = textColor})
		local sub = UI.label(holder, "", {Position = UDim2.fromOffset(x + 2, 40), Size = UDim2.new(1, -x - 2, 0, 20), TextXAlignment = Enum.TextXAlignment.Left,
			Max = 18, Stroke = 2.2, TextColor3 = textColor:Lerp(C.white, 0.6), TextWrapped = false})
		local vScale = new("UIScale", {}, value)
		local iScale = new("UIScale", {}, icon)
		return {holder = holder, icon = icon, value = value, sub = sub, vScale = vScale, iScale = iScale}
	end
	local speedC = counter("boot", UI.rgb(235, 55, 60), UI.rgb(150, 215, 255), 1)
	local cashC = counter("coin", C.gold, C.money, 2)
	hud.cash, hud.speed = cashC, speedC

	------------------------------------------------------------------
	-- TOP-LEFT MENU: a big shiny SHOP button, then candy-coloured square buttons
	------------------------------------------------------------------
	local MENU_COLS = TOUCH and 3 or 2
	local CELL_W, CELL_H, GAP = TOUCH and 84 or 92, TOUCH and 80 or 96, TOUCH and 8 or 10
	local MENU_W = MENU_COLS * CELL_W + (MENU_COLS - 1) * GAP
	-- (above the dark layer behind windows: you can jump from one window to another in one click)
	local menu = box(root, {Name = "Menu", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(MENU_W + 8, 520), ZIndex = 55})
	UI.list(menu, GAP)
	hud.menu = menu
	-- windows open to the right of the menu (on phones the menu hides while a window is open)
	if not TOUCH then UI.winLeft = 12 + MENU_W + 16 end
	local badges = {}
	ctx.badges = badges

	local grid = box(menu, {Size = UDim2.fromOffset(MENU_W, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1})
	new("UIGridLayout", {CellSize = UDim2.fromOffset(CELL_W, CELL_H), CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	local MENU = {
		{"Index", "Index", "book", UI.rgb(30, 190, 245)},
		{"Gifts", "Gifts", "gift", UI.rgb(255, 80, 165)},
		{"Daily", "Daily", "calendar", UI.rgb(80, 120, 255)},
	}
	hud.menuIcons = {}
	-- a menu button like the inspiration game: no box, just a big icon with its name under it
	local function squareButton(parent, key, label, iconName, color, order, size)
		local holder = box(parent, {Name = key, LayoutOrder = order, Size = size or UDim2.fromScale(1, 1)})
		local face = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, holder)
		local isz = math.floor(CELL_W * 0.78)
		local icon = UI.icon(iconName, face, UDim2.fromOffset(isz, isz), UDim2.new(0.5, 0, 0, -6), color:Lerp(C.white, 0.65), Vector2.new(0.5, 0))
		table.insert(hud.menuIcons, {icon = icon, pos = icon.Position, iconScale = new("UIScale", {}, icon), faceScale = new("UIScale", {}, face)})
		UI.label(face, label, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(1, 10, 0, 32), Max = 30, Min = 14, Stroke = 3.2, TextWrapped = false})
		UI.pressable(face, holder)
		return face
	end
	local shopFace = squareButton(menu, "Shop", "Shop", "shop", UI.rgb(110, 225, 40), 0, UDim2.fromOffset(MENU_W, CELL_H + 6))
	shopFace.Activated:Connect(function() UI.toggle("Shop") end)
	badges.Shop = UI.badge(shopFace, shopFace.ZIndex)
	local shopScale = new("UIScale", {}, shopFace.Parent)
	for i, m in ipairs(MENU) do
		local key, label, iconName, color = m[1], m[2], m[3], m[4]
		local face = squareButton(grid, key, label, iconName, color, i)
		face.Activated:Connect(function() UI.toggle(key) end)
		badges[key] = UI.badge(face, face.ZIndex)
	end

	-- SLOW MODE toggle under the menu: a dark green track with a red square knob (green when on)
	do
		local ROW_H = TOUCH and 40 or 46
		local row = box(menu, {Size = UDim2.fromOffset(MENU_W, ROW_H), LayoutOrder = 2})
		local track = new("TextButton", {Size = UDim2.fromOffset(ROW_H * 2, ROW_H), BackgroundColor3 = UI.rgb(45, 95, 35), Text = "", AutoButtonColor = false}, row)
		UI.corner(track, 7)
		UI.stroke(track, 3.5)
		local k = ROW_H - 8
		local knob = new("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(k, k), BackgroundColor3 = C.red}, track)
		UI.corner(knob, 6)
		UI.stroke(knob, 3)
		UI.shade(knob, C.white, UI.rgb(190, 190, 200))
		UI.label(row, "Slow Mode", {Position = UDim2.fromOffset(ROW_H * 2 + 10, 0), Size = UDim2.new(1, -ROW_H * 2 - 10, 1, 0), Max = TOUCH and 20 or 24,
			Stroke = 2.6, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local slowOn = false
		local function setSlow(on)
			slowOn = on
			UI.tween(knob, 0.25, {Position = UDim2.fromOffset(on and (ROW_H * 2 - k - 4) or 4, 4)}, Enum.EasingStyle.Back)
			knob.BackgroundColor3 = on and C.green or C.red
			track.BackgroundColor3 = on and UI.rgb(30, 130, 45) or UI.rgb(45, 95, 35)
		end
		hud.setSlowToggle = setSlow
		UI.pressable(track)
		track.Activated:Connect(function()
			setSlow(not slowOn)
			ctx.invoke("SlowMode", slowOn)
			local sw = ctx.settingSwitches and ctx.settingSwitches.SlowMode
			if sw then sw.set(slowOn, true) end
		end)
	end

	------------------------------------------------------------------
	-- BOTTOM-RIGHT: timers (on phones: top-right, the jump button lives bottom-right)
	------------------------------------------------------------------
	local PILL_H = TOUCH and 40 or 46
	local timers = box(root, {Name = "Timers", AnchorPoint = TOUCH and Vector2.new(1, 0) or Vector2.new(1, 1),
		Position = TOUCH and UDim2.new(1, -12, 0, 8) or UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(290, 3 * PILL_H + 16), ZIndex = 2})
	UI.list(timers, 8, nil, Enum.HorizontalAlignment.Right, TOUCH and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom)
	local function timerPill(iconName, iconColor, pillColor, order)
		local f = new("Frame", {Size = UDim2.fromOffset(TOUCH and 196 or 280, PILL_H), LayoutOrder = order}, timers)
		UI.corner(f, true)
		UI.stroke(f, 3)
		local grad = UI.vivid(f, pillColor)
		local shine = new("Frame", {Position = UDim2.new(0, 14, 0, 3), Size = UDim2.new(1, -28, 0, 9), BackgroundColor3 = C.white, BackgroundTransparency = 0.65, BorderSizePixel = 0}, f)
		UI.corner(shine, true)
		local isz = PILL_H + 8
		local ic = UI.icon(iconName, f, UDim2.fromOffset(isz, isz), UDim2.new(0, -10, 0.5, 0), iconColor, Vector2.new(0, 0.5))
		local l = UI.label(f, "", {Position = UDim2.fromOffset(isz - 4, 3), Size = UDim2.new(1, -isz - 8, 1, -6), TextXAlignment = Enum.TextXAlignment.Left,
			Max = TOUCH and 22 or 25, Stroke = 2.4, TextWrapped = false})
		return {frame = f, icon = ic, label = l, grad = grad}
	end
	local phaseT = timerPill("moon", UI.rgb(240, 240, 200), UI.rgb(70, 80, 200), 2)
	local sunIcon = UI.icon("sun", phaseT.frame, UDim2.fromOffset(PILL_H + 8, PILL_H + 8), UDim2.new(0, -10, 0.5, 0), UI.rgb(255, 210, 60), Vector2.new(0, 0.5))
	local rainbowT = timerPill("star", UI.rgb(255, 230, 90), UI.rgb(220, 70, 200), 1)
	-- the rainbow pill really is a rainbow
	rainbowT.grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.rgb(255, 80, 120)), ColorSequenceKeypoint.new(0.25, UI.rgb(255, 170, 40)),
		ColorSequenceKeypoint.new(0.5, UI.rgb(80, 210, 90)), ColorSequenceKeypoint.new(0.75, UI.rgb(60, 150, 255)),
		ColorSequenceKeypoint.new(1, UI.rgb(180, 90, 255))})
	rainbowT.grad.Rotation = 0
	local luckT = timerPill("clover", UI.rgb(120, 255, 120), UI.rgb(40, 175, 80), 0)
	luckT.frame.Visible = false
	-- a surprise event (takes the rainbow box timer's place while it runs)
	local eventT = timerPill("bolt", UI.rgb(255, 230, 90), UI.rgb(255, 140, 30), -1)
	eventT.frame.Visible = false

	------------------------------------------------------------------
	-- RIGHT: Home + Steal teleports, and the Speed offer
	------------------------------------------------------------------
	local RIGHT_Y = 0.5
	local RIGHT_W = TOUCH and (4 * CELL_W + 3 * GAP + 6) or 212
	local right = box(root, {Name = "Right", AnchorPoint = TOUCH and Vector2.new(1, 0) or Vector2.new(1, 0.5),
		Position = TOUCH and UDim2.new(1, -8, 0, 3 * PILL_H + 32) or UDim2.new(1, -12, RIGHT_Y, -30), Size = UDim2.fromOffset(RIGHT_W, TOUCH and 220 or 400), ZIndex = 2})
	-- side panels open just left of this column
	UI.dockRight = TOUCH and (RIGHT_W * 0.75 + 16) or (RIGHT_W + 28)
	UI.list(right, 10, nil, Enum.HorizontalAlignment.Right, TOUCH and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center)
	if TOUCH then new("UIScale", {Scale = 0.75}, right) end
	local tpRow = box(right, {Size = UDim2.fromOffset((TOUCH and 4 or 2) * CELL_W + (TOUCH and 3 or 1) * GAP, CELL_H), LayoutOrder = 1})
	UI.list(tpRow, GAP, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)
	-- Items + Unboxing open the side panels (on phones they share the row with Steal / Home)
	local panelRow = TOUCH and tpRow or box(right, {Size = UDim2.fromOffset(2 * CELL_W + GAP, CELL_H), LayoutOrder = 0})
	if not TOUCH then UI.list(panelRow, GAP, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right) end
	for _, b in ipairs({{"Items", "Items", "bag", UI.rgb(200, 120, 50)}, {"Unboxing", "Unbox", "box", UI.rgb(230, 40, 45)}}) do
		local face = squareButton(panelRow, b[1], b[2], b[3], b[4], -10, UDim2.fromOffset(CELL_W, CELL_H))
		face.Activated:Connect(function() UI.toggle(b[1]) end)
		badges[b[1]] = UI.badge(face, face.ZIndex)
	end
	squareButton(tpRow, "Steal", "Steal", "box", UI.rgb(255, 140, 30), 1, UDim2.fromOffset(CELL_W, CELL_H)).Activated:Connect(function()
		local r = ctx.invoke("Warehouse")
		if not r.ok and r.msg then ctx.notify(r.msg, C.red) end
	end)
	squareButton(tpRow, "Home", "Home", "home", UI.rgb(60, 205, 80), 2, UDim2.fromOffset(CELL_W, CELL_H)).Activated:Connect(function()
		local r = ctx.invoke("Home")
		if not r.ok and r.msg then ctx.notify(r.msg, C.red) end
	end)

	-- the bouncing Speed offer: "2x SPEED" + a green pill with the Robux icon and the price
	-- (a fixed slot with the card centred in it: the card bounces around its centre and
	-- always stays inside the slot, so it never pokes off the screen edge)
	local offer = box(right, {Size = UDim2.fromOffset(206, 108), LayoutOrder = 2})
	local offerCard = box(offer, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(184, 92)})
	local offerScale = new("UIScale", {}, offerCard)
	local offerBtn = UI.button(offerCard, {Text = "", Color = C.yellow, Size = UDim2.fromScale(1, 1), Radius = 18, Depth = 6})
	local offerTitle = UI.label(offerBtn.face, "2x SPEED", {Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 40), Max = 36, Stroke = 3.2, TextWrapped = false,
		ZIndex = offerBtn.face.ZIndex + 2})
	local offerPrice = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(120, 32), BackgroundColor3 = C.green,
		ZIndex = offerBtn.face.ZIndex + 2}, offerBtn.face)
	UI.corner(offerPrice, true)
	UI.stroke(offerPrice, 2.5)
	UI.vivid(offerPrice, UI.rgb(60, 205, 80))
	local offerRobux = UI.icon("robux", offerPrice, UDim2.fromOffset(26, 26), UDim2.new(0, 6, 0.5, 0), C.white, Vector2.new(0, 0.5))
	offerRobux.ZIndex = offerBtn.face.ZIndex + 3
	local offerPriceL = UI.label(offerPrice, "3", {Size = UDim2.new(1, -42, 1, -4), Position = UDim2.fromOffset(34, 2), Max = 24, Stroke = 2.4, TextWrapped = false,
		ZIndex = offerBtn.face.ZIndex + 3})
	local offerSheen = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = offerBtn.face.ZIndex + 4}, offerBtn.face)
	UI.corner(offerSheen, 18)
	local offerSheenGrad = new("UIGradient", {Rotation = 25, Offset = Vector2.new(-1.2, 0), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1)})}, offerSheen)
	local function nextSpeedTier()
		local have = player:GetAttribute("SpeedBoost") or (ctx.data and ctx.data.SpeedBoost) or 1
		for i, b in ipairs(Config.SpeedBoosts) do
			if have < b.mult then return i, b end
		end
		return nil, nil
	end
	local function drawOffer()
		local i, b = nextSpeedTier()
		offer.Visible = i ~= nil
		if b then
			UI.setText(offerTitle, fmt(b.mult) .. "x SPEED")
			UI.setText(offerPriceL, fmt(ctx.price("Speed" .. i, b.robux)))
		end
	end
	hud.drawOffer = drawOffer
	offerBtn.Activated:Connect(function()
		local i = nextSpeedTier()
		if not i then return end
		local r = ctx.invoke("BuyProduct", "Speed" .. i)
		if r.msg and r.msg ~= "" then ctx.notify(r.msg, r.ok and C.yellow or C.red) end
	end)
	player:GetAttributeChangedSignal("SpeedBoost"):Connect(function()
		drawOffer()
		offerScale.Scale = 1.15
	end)
	drawOffer()

	------------------------------------------------------------------
	-- TOP-CENTRE STACK: area banner -> tutorial -> notifications (never on top of each other)
	------------------------------------------------------------------
	local top = box(root, {Name = "TopStack", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 70})
	if TOUCH then
		-- phones: a bit smaller, centred in the gap between the menu and the timers
		new("UIScale", {Scale = 0.8}, top)
		top.Position = UDim2.new(0.5, math.floor((12 + MENU_W + 8 - 216) / 2), 0, 8)
	end
	UI.list(top, 8, nil, Enum.HorizontalAlignment.Center)
	hud.topStack = top
	local tutorialSlot = box(top, {Name = "TutorialSlot", Size = UDim2.fromOffset(560, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2})
	UI.list(tutorialSlot, 0, nil, Enum.HorizontalAlignment.Center)
	hud.tutorialSlot = tutorialSlot
	local toastList = box(top, {Name = "Toasts", Size = UDim2.fromOffset(560, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3})
	UI.list(toastList, 4, nil, Enum.HorizontalAlignment.Center)

	-- NOTIFICATIONS: a bright candy pill in the message's colour. Pops in with a hop, then fades away.
	local toastOrder = 0
	local function notify(str, color)
		str = Config.StripEmoji(tostring(str or ""))
		if str == "" then return end
		toastOrder = toastOrder + 1
		color = color or C.purple
		-- very light colours (white) get a purple pill so the white text stays readable
		local h, sat, v = color:ToHSV()
		local pillColor = (sat < 0.25) and C.purple or Color3.fromHSV(h, math.max(sat, 0.55), math.min(v, 0.88))
		-- fewer at once while a window is open (they sit above it)
		local maxToasts = UI.isOpen() and 1 or 4
		local existing = {}
		for _, c in ipairs(toastList:GetChildren()) do
			if c:IsA("CanvasGroup") then table.insert(existing, c) end
		end
		table.sort(existing, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		for k = 1, #existing - maxToasts + 1 do existing[k]:Destroy() end
		local row = new("CanvasGroup", {Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
			LayoutOrder = toastOrder, GroupTransparency = 1}, toastList)
		UI.padding(row, 3)
		local pill = new("Frame", {Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY}, row)
		UI.corner(pill, true)
		UI.stroke(pill, 3)
		UI.vivid(pill, pillColor)
		UI.padding(pill, 0, 8, 9, 50, 22)
		new("UISizeConstraint", {MaxSize = Vector2.new(600, 220)}, pill)
		local star = UI.icon("star", pill, UDim2.fromOffset(34, 34), UDim2.new(0, -42, 0.5, 0), UI.rgb(255, 225, 70), Vector2.new(0, 0.5))
		local l = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, FontFace = UI.Font,
			TextSize = 23, TextWrapped = true, Text = str, TextColor3 = C.white}, pill)
		new("UISizeConstraint", {MaxSize = Vector2.new(520, 200)}, l)
		new("UIStroke", {Thickness = 2.4, Color = C.ink, LineJoinMode = Enum.LineJoinMode.Round}, l)
		local s = new("UIScale", {Scale = 0.5}, row)
		UI.tween(row, 0.15, {GroupTransparency = 0})
		UI.tween(s, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
		star.Rotation = -40
		UI.tween(star, 0.6, {Rotation = 0}, Enum.EasingStyle.Back)
		task.delay(4, function()
			if not row.Parent then return end
			UI.tween(row, 0.35, {GroupTransparency = 1})
			UI.tween(s, 0.35, {Scale = 0.8})
			task.wait(0.36)
			row:Destroy()
		end)
	end
	ctx.notify = notify

	------------------------------------------------------------------
	-- AREA NAME: when you walk into an area, a big emoji pops up with the area's name under it
	------------------------------------------------------------------
	do
		local EMOJI = {"📦", "🐄", "🧸", "🍭", "🏴‍☠️", "🦖", "❄️", "🤖", "👽", "🌌"}
		local holder = box(top, {Name = "AreaBanner", Size = UDim2.fromOffset(560, 150), LayoutOrder = 1, Visible = false})
		hud.areaBanner = holder
		local group = new("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1}, holder)
		local gScale = new("UIScale", {}, group)
		-- (a plain TextLabel: UI.label filters emoji out)
		local emoji = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(120, 80), BackgroundTransparency = 1,
			Text = "", TextSize = 72, FontFace = UI.Font}, group)
		local nameL = UI.label(group, "", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.new(1, 0, 0, 60), Max = 56,
			Stroke = 4, TextWrapped = false})
		local token = 0
		local function showArea(zone)
			token = token + 1
			local tok = token
			local area = Config.Areas[zone]
			emoji.Text = EMOJI[zone] or "📦"
			UI.setText(nameL, string.upper(area.name))
			nameL.TextColor3 = area.accent:Lerp(C.white, 0.35)
			holder.Visible = not UI.isModalOpen()
			group.GroupTransparency = 1
			gScale.Scale = 0.6
			UI.tween(group, 0.25, {GroupTransparency = 0})
			UI.tween(gScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
			UI.SFX.play("open", 0.75, 0.35)
			task.delay(2.4, function()
				if tok ~= token then return end
				UI.tween(group, 0.4, {GroupTransparency = 1})
				task.delay(0.4, function() if tok == token then holder.Visible = false end end)
			end)
		end
		local lastZone = nil
		task.spawn(function()
			while true do
				task.wait(0.25)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local zone = hrp and Config.ZoneAt(hrp.Position) or nil
				if zone ~= lastZone then
					lastZone = zone
					if zone then showArea(zone) end
				end
			end
		end)
		hud.inArea = function() return false end -- (the name only shows for a moment)
		hud.showArea = showArea
	end

	-- windows sit above the HUD; while one is open the banner + tutorial step aside
	local topHome, topScale = top.Position, top:FindFirstChildOfClass("UIScale") or new("UIScale", {}, top)
	local topScaleHome = topScale.Scale
	UI.WindowChanged:Connect(function(name)
		local open = UI.isModalOpen()
		hud.areaBanner.Visible = (not open) and hud.inArea()
		tutorialSlot.Visible = not open
		hud.bottomStack.Visible = not open
		-- a side panel is open: the top + bottom stacks move into the free space left of it
		local bottomStack, bScale = hud.bottomStack, hud.bottomScale
		timers.Visible = (name == nil) or open -- the panel's big button sits where the timers are
		if name ~= nil and not open then
			local left = TOUCH and 8 or (UI.winLeft or 12)
			local free = math.max(120, (UI.dockLeft or 600) - left)
			topScale.Scale = math.min(topScaleHome, free / 560)
			top.Position = UDim2.new(0, left + free / 2, 0, 8)
			if bottomStack and bScale then
				bScale.Scale = math.min(bScale:GetAttribute("Home") or 1, free / 480)
				bottomStack.Position = UDim2.new(0, left + free / 2, 1, -160) -- (above the cash counter)
			end
		else
			topScale.Scale = topScaleHome
			top.Position = topHome
			if bottomStack and bScale then
				bScale.Scale = bScale:GetAttribute("Home") or 1
				bottomStack.Position = hud.bottomHome
			end
		end
		-- phones: the menu steps aside so the window can use the whole screen
		if TOUCH then menu.Visible = name == nil end
		if open then
			-- keep only the newest notification: it fits above the window
			local rows = {}
			for _, c in ipairs(toastList:GetChildren()) do
				if c:IsA("CanvasGroup") then table.insert(rows, c) end
			end
			table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			for k = 1, #rows - 1 do rows[k]:Destroy() end
		end
	end)

	------------------------------------------------------------------
	-- BOTTOM-CENTRE STACK: your unbox card -> carried box -> treadmill bar
	------------------------------------------------------------------
	local bottom = box(root, {Name = "BottomStack", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(560, 420), ZIndex = 3})
	if TOUCH then
		-- phones: between the cash counter (left) and the jump button (right)
		bottom.Position = UDim2.new(0.5, 40, 1, -12)
	end
	hud.bottomScale = new("UIScale", {Scale = TOUCH and 0.8 or 1}, bottom)
	hud.bottomScale:SetAttribute("Home", hud.bottomScale.Scale)
	hud.bottomHome = bottom.Position
	UI.list(bottom, 8, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	hud.bottomStack = bottom

	-- CARRYING: the box's name, a hint and a big Drop button
	local carry = box(bottom, {Name = "Carry", Size = UDim2.fromOffset(460, 104), LayoutOrder = 2, Visible = false})
	local carryBack = new("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.hud, BackgroundTransparency = 0.12}, carry)
	UI.corner(carryBack, 16)
	UI.stroke(carryBack, 3)
	UI.vivid(carryBack, UI.rgb(120, 70, 220))
	local carryName = UI.label(carryBack, "", {Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -24, 0, 26), Max = 22, Stroke = 2, TextColor3 = C.yellow, TextWrapped = false})
	local carryHint = UI.label(carryBack, IS_TOUCH() and "Tap your plot's floor to place it" or "Click your plot's floor to place it",
		{Position = UDim2.fromOffset(12, 29), Size = UDim2.new(1, -24, 0, 18), Max = 17, Stroke = 1.8, TextColor3 = UI.rgb(235, 225, 255), TextWrapped = false})
	local dropBtn = UI.button(carry, {Text = IS_TOUCH() and "Drop" or "Drop  [G]", Color = C.red, Icon = "down", IconColor = C.white, Size = UDim2.fromOffset(190, 46),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), TextSize = 22})
	dropBtn.Activated:Connect(function() ctx.remotes.Drop:FireServer() end)
	local function updateCarry()
		local id = player:GetAttribute("Carrying")
		carry.Visible = id ~= nil
		if id then
			local def = Config.Boxes[id]
			UI.setText(carryName, "Carrying: " .. (player:GetAttribute("CarryLabel") or id))
			if def then carryName.TextColor3 = (Config.Rarities[def.rarity] or Config.Rarities[1]).color:Lerp(C.white, 0.55) end
		end
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
	player:GetAttributeChangedSignal("CarryLabel"):Connect(updateCarry)
	updateCarry()
	hud.carryHint = carryHint

	-- YOUR UNBOX: a card with the rarity word, the item turning in 3D, its name and $/s
	do
		local card = new("CanvasGroup", {Name = "Reveal", Size = UDim2.fromOffset(470, 156), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, LayoutOrder = 1}, bottom)
		local cScale = new("UIScale", {}, card)
		local burst = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(260, 260), BackgroundTransparency = 1}, card)
		local rays = {}
		for k = 0, 11 do
			local ray = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 26, 0.5, 0), Rotation = k * 30,
				BackgroundColor3 = C.white, BorderSizePixel = 0}, burst)
			new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0.4)}, ray)
			rays[k + 1] = ray
		end
		local word = UI.label(card, "", {Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 50), Max = 44, Stroke = 3.4, TextWrapped = false})
		local wordGrad = new("UIGradient", {Rotation = 90}, word)
		local wordScale = new("UIScale", {}, word)
		local panel = new("Frame", {Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = UI.rgb(24, 22, 36), BackgroundTransparency = 0.05}, card)
		UI.corner(panel, 18)
		local pStroke = UI.stroke(panel, 3.5, C.white)
		local vpHolder = new("Frame", {Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = UI.rgb(14, 12, 24), BackgroundTransparency = 0.2}, panel)
		UI.corner(vpHolder, 14)
		local nameL = UI.label(panel, "", {Position = UDim2.fromOffset(104, 10), Size = UDim2.new(1, -116, 0, 30), Max = 26, Stroke = 2.4, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local incL = UI.label(panel, "", {Position = UDim2.fromOffset(104, 42), Size = UDim2.new(1, -116, 0, 24), Max = 22, Stroke = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.money, TextWrapped = false})
		local whereL = UI.label(panel, "", {Position = UDim2.fromOffset(104, 68), Size = UDim2.new(1, -116, 0, 20), Max = 17, Stroke = 1.6, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.sub, TextWrapped = false})
		local token, vp, list = 0, nil, nil
		ctx.showReveal = function(item, placed)
			local def = Config.Items[item.id]
			if not def then return end
			local tierDef = Config.ItemTiers[def.tier] or Config.ItemTiers[1]
			local mut = Config.GetMutation(item.mutation)
			local col = mut.color or tierDef.color
			local special = mut.id ~= "Normal"
			token = token + 1
			local tok = token
			UI.setText(word, (special and (string.upper(mut.id) .. " ") or "") .. string.upper(tierDef.name) .. ((def.tier >= 3) and "!!" or "!"))
			wordGrad.Color = ColorSequence.new(C.white, col)
			if vp then vp:Destroy() end
			vp, list = UI.itemView(vpHolder, item, {Size = UDim2.fromScale(1, 1)})
			UI.setText(nameL, Config.ItemLabel(item))
			nameL.TextColor3 = mut.color or C.white
			UI.setText(incL, "$" .. fmt(Config.ItemIncome(item)) .. "/s")
			UI.setText(whereL, placed and "Now for sale on your shelf!" or "Shelf full - sent to your backpack")
			pStroke.Color = col
			for i, ray in ipairs(rays) do ray.BackgroundColor3 = (i % 2 == 0) and col or col:Lerp(C.white, 0.5) end
			burst.Visible = def.tier >= 2 or special
			card.Visible = true
			card.GroupTransparency = 1
			cScale.Scale = 0.5
			wordScale.Scale = 1.8
			UI.tween(card, 0.25, {GroupTransparency = 0})
			UI.tween(cScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
			UI.tween(wordScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
			if (def.tier >= 3 or special) and ctx.confetti then
				ctx.confetti((def.tier >= 4 or special) and 90 or 40, {col, C.white, C.yellow, C.green, C.blue, C.pink})
			end
			task.spawn(function()
				local t0 = os.clock()
				while tok == token and card.Visible do
					local t = os.clock() - t0
					burst.Rotation = (t * 40) % 360
					if list then Config.PoseItemModel(list, CFrame.Angles(0, t * 2, 0) * CFrame.Angles(math.rad(10), 0, 0), 1) end
					task.wait()
				end
			end)
			task.delay((Config.RevealHold[def.tier] or 2.4) + 1, function()
				if tok ~= token then return end
				UI.tween(card, 0.3, {GroupTransparency = 1})
				task.delay(0.3, function() if tok == token then card.Visible = false end end)
			end)
		end
	end

	------------------------------------------------------------------
	-- SCREEN EFFECTS
	------------------------------------------------------------------
	-- red screen edges while a guardian is chasing you (under the HUD)
	do
		local vignette = box(UI.under, {Name = "ChaseEdges", Visible = false})
		local edges = {}
		for i, cfg in ipairs({
			{UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90},
			{UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), -90},
			{UDim2.new(0.18, 0, 1, 0), UDim2.fromScale(0, 0), 0},
			{UDim2.new(0.18, 0, 1, 0), UDim2.fromScale(0.82, 0), 180},
		}) do
			local f = new("Frame", {Size = cfg[1], Position = cfg[2], BackgroundColor3 = UI.rgb(255, 0, 0), BorderSizePixel = 0}, vignette)
			new("UIGradient", {Rotation = cfg[3], Transparency = NumberSequence.new(0.35, 1)}, f)
			edges[i] = f
		end
		local function update() vignette.Visible = player:GetAttribute("Chased") == true end
		player:GetAttributeChangedSignal("Chased"):Connect(update)
		update()
		RunService.RenderStepped:Connect(function()
			if vignette.Visible then
				local pulse = 0.5 + math.sin(os.clock() * 8) * 0.5
				for _, f in ipairs(edges) do f.BackgroundTransparency = pulse * 0.4 end
			end
		end)
	end

	-- confetti that rains over the whole screen
	ctx.confetti = function(count, colors)
		count = count or 60
		colors = colors or {C.yellow, C.pink, C.cyan, C.green, C.orange, C.purple}
		if ctx.settings.Effects == false then count = math.floor(count / 3) end
		for _ = 1, count do
			local sq = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(), 0, 0, -20 - math.random(0, 120)),
				Size = UDim2.fromOffset(math.random(8, 14), math.random(5, 9)), Rotation = math.random(0, 180), BorderSizePixel = 0, ZIndex = 49,
				BackgroundColor3 = colors[math.random(1, #colors)]}, UI.over)
			local dur = 1.8 + math.random() * 1.6
			UI.tween(sq, dur, {Position = UDim2.new(sq.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 40), Rotation = sq.Rotation + math.random(180, 720)},
				Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(sq, dur + 0.1)
		end
	end

	-- a full-screen flash
	ctx.flash = function(color, from, time)
		local f = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or C.white, BackgroundTransparency = from or 0.3, BorderSizePixel = 0, ZIndex = 60}, UI.over)
		UI.tween(f, time or 0.4, {BackgroundTransparency = 1})
		Debris:AddItem(f, (time or 0.4) + 0.05)
	end

	-- BONK! when a guardian flings you
	do
		local bonk = UI.label(UI.over, "BONK!", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(320, 96),
			TextColor3 = UI.rgb(255, 220, 60), Visible = false, ZIndex = 51, Max = 90, Stroke = 4})
		local bScale = new("UIScale", {}, bonk)
		ctx.bonk = function(text)
			UI.setText(bonk, text or "BONK!")
			bonk.Visible = true
			bonk.Rotation = math.random(-12, 12)
			bScale.Scale = 0.3 * UI.scale
			UI.tween(bScale, 0.35, {Scale = UI.scale}, Enum.EasingStyle.Back)
			task.delay(1.2, function() bonk.Visible = false end)
		end
	end

	-- STEAL SUCCESSFUL! (you got out of the warehouse with a box): green screen + big text
	do
		local word = UI.label(UI.over, "STEAL SUCCESSFUL!", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(700, 110),
			TextColor3 = UI.rgb(120, 255, 100), Visible = false, ZIndex = 52, Max = 84, Stroke = 5, TextWrapped = false})
		local wScale = new("UIScale", {}, word)
		local tok = 0
		ctx.stealSuccess = function()
			tok = tok + 1
			local my = tok
			ctx.flash(UI.rgb(60, 255, 90), 0.35, 0.9)
			word.Visible = true
			word.Rotation = math.random(-6, 6)
			wScale.Scale = 0.3 * UI.scale
			UI.tween(wScale, 0.45, {Scale = UI.scale}, Enum.EasingStyle.Back)
			UI.SFX.play("ding", 1.6, 0.6)
			task.delay(1.8, function() if my == tok then word.Visible = false end end)
		end
	end

	-- "THANK YOU!" after a Robux purchase
	do
		local splash = new("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(560, 150),
			BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 55}, UI.over)
		local sScale = new("UIScale", {}, splash)
		local big = UI.label(splash, "THANK YOU!", {Size = UDim2.new(1, 0, 0, 84), Max = 80, Stroke = 4.5, TextWrapped = false})
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(UI.rgb(255, 250, 200), UI.rgb(255, 190, 40))}, big)
		local sub = UI.label(splash, "", {Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 40), Max = 30, Stroke = 3, TextWrapped = false})
		local tok = 0
		ctx.thanks = function(title, bigText)
			UI.setText(big, bigText or "THANK YOU!")
			tok = tok + 1
			local my = tok
			UI.setText(sub, title or "")
			splash.Visible = true
			splash.GroupTransparency = 0
			sScale.Scale = 0.3 * UI.scale
			UI.tween(sScale, 0.55, {Scale = UI.scale}, Enum.EasingStyle.Back)
			ctx.confetti(110, {C.yellow, C.white, C.green, C.blue, C.pink, C.purple})
			UI.SFX.play("ding", 1.5, 0.7)
			task.delay(0.15, function() UI.SFX.play("ding", 2, 0.5) end)
			task.delay(2.4, function()
				if my ~= tok then return end
				UI.tween(splash, 0.4, {GroupTransparency = 1})
				task.delay(0.4, function() if my == tok then splash.Visible = false end end)
			end)
		end
	end

	-- CASH JUICE: "+$123" floats up next to the cash counter, coins fly into it
	do
		local lastCoins = 0
		ctx.cashJuice = function(gained)
			if gained < 1 then return end
			local pop = UI.label(cashC.holder, "+$" .. fmt(gained), {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 8, 0.5, 0), Size = UDim2.fromOffset(150, 24),
				TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.rgb(255, 240, 120), Max = 22, Stroke = 2.2, TextWrapped = false})
			UI.tween(pop, 1, {Position = UDim2.new(1, 8, 0.5, -34), TextTransparency = 1})
			local st = pop:FindFirstChildOfClass("UIStroke")
			if st then UI.tween(st, 1, {Transparency = 1}) end
			Debris:AddItem(pop, 1.05)
			-- a few coins fly from the middle of the screen into the counter (not too often)
			if os.clock() - lastCoins < 0.7 or ctx.settings.Effects == false then return end
			lastCoins = os.clock()
			local vp = UI.over.AbsoluteSize
			local target = cashC.icon.AbsolutePosition + cashC.icon.AbsoluteSize / 2 + Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)
			local n = math.clamp(math.floor(math.log10(math.max(gained, 1))) + 1, 2, 6)
			for k = 1, n do
				local start = Vector2.new(vp.X * (0.44 + math.random() * 0.12), vp.Y * (0.48 + math.random() * 0.1))
				local coin = UI.icon("coin", UI.over, UDim2.fromOffset(30, 30), UDim2.fromOffset(start.X, start.Y), C.gold, Vector2.new(0.5, 0.5))
				coin.ZIndex = 40
				local sc = new("UIScale", {Scale = 0}, coin)
				UI.tween(sc, 0.25, {Scale = UI.scale}, Enum.EasingStyle.Back)
				UI.tween(coin, 0.25, {Position = UDim2.fromOffset(start.X + (math.random() - 0.5) * 120, start.Y - 40 - math.random() * 50)})
				task.delay(0.28 + k * 0.06, function()
					UI.tween(coin, 0.45, {Position = UDim2.fromOffset(target.X, target.Y), Rotation = 200}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					UI.tween(sc, 0.45, {Scale = UI.scale * 0.55}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					task.delay(0.45, function()
						coin:Destroy()
						cashC.vScale.Scale = 1.18
						UI.tween(cashC.vScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
						if k == n then UI.SFX.play("click", 2.8, 0.2) end
					end)
				end)
			end
		end
	end

	------------------------------------------------------------------
	-- LIVE VALUES
	------------------------------------------------------------------
	local shownCash = new("NumberValue", {})
	shownCash.Changed:Connect(function(v) UI.setText(cashC.value, "$" .. fmt(v)) end)
	local lastCash = nil
	local function onCash(cash)
		cash = tonumber(cash) or 0
		if lastCash == nil then
			shownCash.Value = cash
			UI.setText(cashC.value, "$" .. fmt(cash))
		elseif cash ~= lastCash then
			UI.tween(shownCash, 0.5, {Value = cash})
			cashC.vScale.Scale = 1.15
			UI.tween(cashC.vScale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
			if cash > lastCash then ctx.cashJuice(cash - lastCash) end
		end
		lastCash = cash
	end
	hud.onCash = onCash
	local function onIncome()
		UI.setText(cashC.sub, "+$" .. fmt(player:GetAttribute("Income") or 0) .. "/s")
	end
	player:GetAttributeChangedSignal("Income"):Connect(onIncome)
	onIncome()
	local lastSpeed = nil
	local function onSpeed()
		local sp = player:GetAttribute("SpeedPoints") or Config.StartSpeed
		UI.setText(speedC.value, fmt(sp))
		local walk = player:GetAttribute("WalkSpeed")
		UI.setText(speedC.sub, player:GetAttribute("OnTreadmill") and ("+" .. fmt(player:GetAttribute("TreadRate") or 0) .. " speed/s")
			or (walk and ("Speed  |  walk " .. string.format("%.1f", walk)) or "Speed"))
		speedC.sub.TextColor3 = player:GetAttribute("OnTreadmill") and C.money or C.sub
		if lastSpeed and sp > lastSpeed then
			speedC.vScale.Scale = 1.15
			UI.tween(speedC.vScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
		end
		lastSpeed = sp
	end
	for _, a in ipairs({"SpeedPoints", "WalkSpeed", "OnTreadmill", "TreadRate"}) do player:GetAttributeChangedSignal(a):Connect(onSpeed) end
	onSpeed()

	-- timers + badges that depend on the clock
	task.spawn(function()
		while true do
			local nowT = workspace:GetServerTimeNow()
			local night = ReplicatedStorage:GetAttribute("IsNight")
			local ends = ReplicatedStorage:GetAttribute("PhaseEndsAt")
			phaseT.frame.Visible = ends ~= nil -- (no day/night in the Mega Mart)
			phaseT.icon.Visible = not night
			sunIcon.Visible = night == true
			local inWord = TOUCH and " " or " in "
			UI.setText(phaseT.label, ends and ((night and "Day" or "Night") .. inWord .. Config.FormatTime(ends - nowT)) or "")
			phaseT.grad.Color = ColorSequence.new(night and UI.rgb(255, 205, 70) or UI.rgb(120, 130, 255), night and UI.rgb(235, 130, 30) or UI.rgb(50, 50, 170))
			local special = ReplicatedStorage:GetAttribute("SpecialAt")
			UI.setText(rainbowT.label, special and ((TOUCH and "Rainbow " or "Rainbow box in ") .. Config.FormatTime(special - nowT)) or "")
			local luckUntil = ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0
			luckT.frame.Visible = luckUntil > nowT
			if luckUntil > nowT then UI.setText(luckT.label, Config.ServerLuck.mult .. "x LUCK  " .. Config.FormatTime(luckUntil - nowT)) end
			local evEnds = ReplicatedStorage:GetAttribute("EventEndsAt")
			local evOn = evEnds ~= nil and evEnds > nowT and ReplicatedStorage:GetAttribute("EventId") ~= "LuckyHour"
			eventT.frame.Visible = evOn
			rainbowT.frame.Visible = not evOn
			if evOn then UI.setText(eventT.label, (ReplicatedStorage:GetAttribute("EventName") or "EVENT") .. " " .. Config.FormatTime(evEnds - nowT)) end
			if ctx.updateClockBadges then ctx.updateClockBadges() end
			task.wait(0.25)
		end
	end)

	-- everything is alive: the menu icons bob and hop one after another in a wave, the counters
	-- and timer icons wiggle, the Shop button breathes, the offer bounces, sheens sweep
	local function hop(t, i)
		local p = (t - i * 0.11) % 3.4
		if p > 0.42 then return 0 end
		return math.sin(p / 0.42 * math.pi)
	end
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for i, e in ipairs(hud.menuIcons) do
			local w = hop(t, i)
			e.icon.Position = e.pos + UDim2.fromOffset(0, math.sin(t * 2.4 + i * 0.9) * 1.5 - w * 5)
			e.icon.Rotation = math.sin(t * 1.7 + i) * 6 + w * 10 * ((i % 2 == 0) and 1 or -1)
			e.iconScale.Scale = 1 + w * 0.18
			e.faceScale.Scale = 1 + w * 0.05
		end
		shopScale.Scale = 1 + 0.035 * math.sin(t * 3.2)
		cashC.icon.Rotation = math.sin(t * 2.1) * 10
		speedC.icon.Rotation = math.sin(t * 2.6 + 1) * 8
		cashC.iScale.Scale = 1 + 0.06 * math.abs(math.sin(t * 2.1))
		phaseT.icon.Rotation = math.sin(t * 1.3) * 12
		sunIcon.Rotation = (t * 30) % 360
		rainbowT.icon.Rotation = math.sin(t * 2.4) * 15
		rainbowT.grad.Offset = Vector2.new(math.sin(t * 0.8) * 0.25, 0)
		luckT.icon.Rotation = math.sin(t * 2) * 12
		local bits = hud.bannerBits
		if bits and bits.mini.Visible then bits.mini.Rotation = math.sin(t * 2) * 1.5 end
		if offer.Visible then
			local target = 1 + 0.05 * math.abs(math.sin(t * 3))
			offerScale.Scale = offerScale.Scale + (target - offerScale.Scale) * math.min(1, dt * 8)
			offerCard.Rotation = math.sin(t * 2.2) * 3
			offerSheenGrad.Offset = Vector2.new(((t * 0.55) % 2.4) - 1.2, 0)
		end
		for _, b in pairs(badges) do
			if b.frame.Visible then b.scale.Scale = 1 + 0.12 * math.abs(math.sin(t * 4)) end
		end
	end)

	-- the HUD slides in when you join
	do
		local slides = {
			{menu, UDim2.fromOffset(-MENU_W - 40, 8)},
			{currency, UDim2.new(0, -CUR_W - 40, 1, -12)},
			{right, right.Position + UDim2.fromOffset(300, 0)},
			{timers, timers.Position + UDim2.fromOffset(340, 0)},
		}
		for i, s in ipairs(slides) do
			local goal = s[1].Position
			s[1].Position = s[2]
			task.delay(0.4 + i * 0.12, function() UI.tween(s[1], 0.7, {Position = goal}, Enum.EasingStyle.Back) end)
		end
	end

	return hud
end

return Hud
