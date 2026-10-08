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
	-- TOP-LEFT: cash + speed counters
	------------------------------------------------------------------
	local currency = box(root, {Name = "Currency", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(260, 150), ZIndex = 2})
	UI.list(currency, 6)
	hud.currency = currency

	-- a counter pill: the icon sticks out on the left, value on top, a small line under it
	local function counter(iconName, iconColor, order)
		local holder = box(currency, {Size = UDim2.fromOffset(250, 52), LayoutOrder = order})
		local back = new("Frame", {Position = UDim2.fromOffset(20, 4), Size = UDim2.new(1, -20, 1, -8), BackgroundColor3 = C.hud, BackgroundTransparency = 0.12}, holder)
		UI.corner(back, true)
		UI.stroke(back, 2.5)
		local icon = UI.icon(iconName, holder, UDim2.fromOffset(52, 52), UDim2.fromOffset(0, 0), iconColor)
		local value = UI.label(holder, "0", {Position = UDim2.fromOffset(60, 5), Size = UDim2.new(1, -70, 0, 26), TextXAlignment = Enum.TextXAlignment.Left,
			Max = 26, Stroke = 2.5, TextWrapped = false})
		local sub = UI.label(holder, "", {Position = UDim2.fromOffset(60, 31), Size = UDim2.new(1, -70, 0, 15), TextXAlignment = Enum.TextXAlignment.Left,
			Max = 15, Stroke = 1.5, TextColor3 = C.sub, TextWrapped = false})
		local vScale = new("UIScale", {}, value)
		return {holder = holder, icon = icon, value = value, sub = sub, vScale = vScale}
	end
	local cashC = counter("coin", C.gold, 1)
	cashC.value.TextColor3 = C.money
	cashC.sub.TextColor3 = rgbLerp(C.money, C.white, 0.35)
	local speedC = counter("boot", C.blue, 2)
	hud.cash, hud.speed = cashC, speedC
	-- rebirth chip (shows once you've rebirthed)
	local rebChip = new("Frame", {Size = UDim2.fromOffset(190, 26), BackgroundColor3 = C.purple, LayoutOrder = 3, Visible = false}, currency)
	UI.corner(rebChip, true)
	UI.stroke(rebChip, 2)
	UI.shade(rebChip, C.white, UI.rgb(200, 190, 220))
	local rebLabel = UI.label(rebChip, "", {Size = UDim2.new(1, -16, 1, -4), Position = UDim2.fromOffset(8, 2), Max = 15, Stroke = 1.5, TextWrapped = false})

	------------------------------------------------------------------
	-- LEFT MENU: a big SHOP button, then 2 columns of square buttons
	------------------------------------------------------------------
	local MENU_COLS = UI.isTouch and 3 or 2
	local MENU_W = MENU_COLS * 64 + (MENU_COLS - 1) * 8
	-- (above the dark layer behind windows: you can jump from one window to another in one click)
	local menu = box(root, {Name = "Menu", Position = UDim2.fromOffset(12, 160), Size = UDim2.fromOffset(MENU_W + 4, 360), ZIndex = 55})
	UI.list(menu, 8)
	hud.menu = menu
	local badges = {}
	ctx.badges = badges

	local shopBtn = UI.button(menu, {Name = "Shop", Text = "SHOP", Color = C.yellow, Size = UDim2.fromOffset(MENU_W, 54), Icon = "shop", IconSize = 36,
		IconColor = C.red, TextSize = 28, LayoutOrder = 0})
	-- a light sweep runs over the Shop button every few seconds
	local shopSheen = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = shopBtn.face.ZIndex + 1}, shopBtn.face)
	UI.corner(shopSheen, 12)
	local shopSheenGrad = new("UIGradient", {Rotation = 25, Offset = Vector2.new(-1.2, 0), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1)})}, shopSheen)
	shopBtn.Activated:Connect(function() UI.toggle("Shop") end)
	badges.Shop = UI.badge(shopBtn.face, shopBtn.face.ZIndex)

	local grid = box(menu, {Size = UDim2.fromOffset(MENU_W, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1})
	new("UIGridLayout", {CellSize = UDim2.fromOffset(64, 66), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	local MENU = {
		{"Items", "Items", "bag", C.green},
		{"Index", "Index", "book", C.cyan},
		{"Trails", "Trails", "trail", C.orange},
		{"Gifts", "Gifts", "gift", C.pink},
		{"Daily", "Daily", "calendar", C.blue},
		{"Rebirth", "Rebirth", "rebirth", C.purple},
		{"Codes", "Codes", "ticket", C.red},
		{"Settings", "Settings", "gear", C.grey},
	}
	hud.menuIcons = {}
	for i, m in ipairs(MENU) do
		local key, label, iconName, color = m[1], m[2], m[3], m[4]
		local holder = box(grid, {Name = key, LayoutOrder = i})
		local shadow = new("Frame", {Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -4), BackgroundColor3 = color:Lerp(C.black, 0.45)}, holder)
		UI.corner(shadow, 14)
		UI.stroke(shadow, 2.5)
		local face = new("TextButton", {Size = UDim2.new(1, 0, 1, -4), BackgroundColor3 = color, Text = "", AutoButtonColor = false}, holder)
		UI.corner(face, 14)
		UI.stroke(face, 2.5)
		UI.shade(face, C.white, UI.rgb(205, 205, 212))
		local icon = UI.icon(iconName, face, UDim2.fromOffset(34, 34), UDim2.new(0.5, 0, 0, 4), color:Lerp(C.white, 0.2), Vector2.new(0.5, 0))
		table.insert(hud.menuIcons, {icon = icon, pos = icon.Position})
		UI.label(face, label, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -6, 0, 16), Max = 14, Stroke = 1.8, TextWrapped = false})
		UI.pressable(face, holder)
		face.Activated:Connect(function() UI.toggle(key) end)
		badges[key] = UI.badge(face, face.ZIndex)
	end

	------------------------------------------------------------------
	-- TOP-RIGHT: timers
	------------------------------------------------------------------
	local timers = box(root, {Name = "Timers", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(230, 140), ZIndex = 2})
	UI.list(timers, 6, nil, Enum.HorizontalAlignment.Right)
	local function timerPill(iconName, iconColor, order)
		local f = new("Frame", {Size = UDim2.fromOffset(224, 36), BackgroundColor3 = C.hud, BackgroundTransparency = 0.12, LayoutOrder = order}, timers)
		UI.corner(f, true)
		UI.stroke(f, 2.5)
		local ic = UI.icon(iconName, f, UDim2.fromOffset(30, 30), UDim2.new(0, 5, 0.5, 0), iconColor, Vector2.new(0, 0.5))
		local l = UI.label(f, "", {Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -50, 1, -8), TextXAlignment = Enum.TextXAlignment.Left, Max = 18, Stroke = 2, TextWrapped = false})
		return {frame = f, icon = ic, label = l}
	end
	local phaseT = timerPill("moon", UI.rgb(235, 235, 200), 1)
	local sunIcon = UI.icon("sun", phaseT.frame, UDim2.fromOffset(30, 30), UDim2.new(0, 5, 0.5, 0), UI.rgb(255, 210, 60), Vector2.new(0, 0.5))
	local rainbowT = timerPill("star", UI.rgb(255, 120, 220), 2)
	local luckT = timerPill("clover", C.green, 3)
	luckT.frame.Visible = false
	luckT.frame.BackgroundColor3 = UI.rgb(20, 70, 40)

	------------------------------------------------------------------
	-- RIGHT: Home + Steal teleports, and the Speed offer
	------------------------------------------------------------------
	local RIGHT_Y = UI.isTouch and 0.4 or 0.5
	local right = box(root, {Name = "Right", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, RIGHT_Y, 10), Size = UDim2.fromOffset(190, 260), ZIndex = 2})
	UI.list(right, 8, nil, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local tpRow = box(right, {Size = UDim2.fromOffset(136, 66), LayoutOrder = 1})
	UI.list(tpRow, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)
	local function squareButton(name, label, iconName, color, order)
		local holder = box(tpRow, {Name = name, Size = UDim2.fromOffset(64, 66), LayoutOrder = order})
		local shadow = new("Frame", {Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -4), BackgroundColor3 = color:Lerp(C.black, 0.45)}, holder)
		UI.corner(shadow, 14)
		UI.stroke(shadow, 2.5)
		local face = new("TextButton", {Size = UDim2.new(1, 0, 1, -4), BackgroundColor3 = color, Text = "", AutoButtonColor = false}, holder)
		UI.corner(face, 14)
		UI.stroke(face, 2.5)
		UI.shade(face, C.white, UI.rgb(205, 205, 212))
		local icon = UI.icon(iconName, face, UDim2.fromOffset(34, 34), UDim2.new(0.5, 0, 0, 4), color:Lerp(C.white, 0.2), Vector2.new(0.5, 0))
		table.insert(hud.menuIcons, {icon = icon, pos = icon.Position})
		UI.label(face, label, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -6, 0, 16), Max = 14, Stroke = 1.8, TextWrapped = false})
		UI.pressable(face, holder)
		return face
	end
	squareButton("Steal", "Steal", "box", C.orange, 1).Activated:Connect(function()
		local r = ctx.invoke("Warehouse")
		if not r.ok and r.msg then ctx.notify(r.msg, C.red) end
	end)
	squareButton("Home", "Home", "home", C.green, 2).Activated:Connect(function()
		local r = ctx.invoke("Home")
		if not r.ok and r.msg then ctx.notify(r.msg, C.red) end
	end)

	-- the bouncing Speed offer: "2x SPEED - R$ 3"
	-- (a fixed slot with the card centred in it: the card bounces around its centre and
	-- always stays inside the slot, so it never pokes off the screen edge)
	local offer = box(right, {Size = UDim2.fromOffset(186, 94), LayoutOrder = 2})
	local offerCard = box(offer, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(164, 80)})
	local offerScale = new("UIScale", {}, offerCard)
	local offerBtn = UI.button(offerCard, {Text = "", Color = C.yellow, Size = UDim2.fromScale(1, 1), Radius = 16})
	local offerTitle = UI.label(offerBtn.face, "2x SPEED", {Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 36), Max = 30, Stroke = 3, TextWrapped = false,
		ZIndex = offerBtn.face.ZIndex + 2})
	local offerPrice = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 41), Size = UDim2.fromOffset(104, 27), BackgroundColor3 = C.green,
		ZIndex = offerBtn.face.ZIndex + 2}, offerBtn.face)
	UI.corner(offerPrice, true)
	UI.stroke(offerPrice, 2)
	local offerPriceL = UI.label(offerPrice, "R$ 3", {Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Max = 19, Stroke = 2, TextWrapped = false,
		ZIndex = offerBtn.face.ZIndex + 3})
	local offerSheen = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = offerBtn.face.ZIndex + 4}, offerBtn.face)
	UI.corner(offerSheen, 16)
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
			UI.setText(offerPriceL, "R$ " .. fmt(ctx.price("Speed" .. i, b.robux)))
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
	UI.list(top, 8, nil, Enum.HorizontalAlignment.Center)
	hud.topStack = top
	local tutorialSlot = box(top, {Name = "TutorialSlot", Size = UDim2.fromOffset(560, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2})
	hud.tutorialSlot = tutorialSlot
	local toastList = box(top, {Name = "Toasts", Size = UDim2.fromOffset(560, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3})
	UI.list(toastList, 4, nil, Enum.HorizontalAlignment.Center)

	-- NOTIFICATIONS: a dark pill with a coloured edge + dot. Pops in, then fades away.
	local toastOrder = 0
	local function notify(str, color)
		str = Config.StripEmoji(tostring(str or ""))
		if str == "" then return end
		toastOrder = toastOrder + 1
		color = color or C.white
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
		local pill = new("Frame", {Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = UI.rgb(22, 20, 36),
			BackgroundTransparency = 0.08}, row)
		UI.corner(pill, 18)
		UI.stroke(pill, 2.5, color, 0.1)
		UI.padding(pill, 0, 7, 7, 34, 16)
		new("UISizeConstraint", {MaxSize = Vector2.new(540, 200)}, pill)
		local dot = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -22, 0.5, 0), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = color}, pill)
		UI.corner(dot, true)
		local l = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, FontFace = UI.Font,
			TextSize = 18, TextWrapped = true, Text = str, TextColor3 = color:Lerp(C.white, 0.3)}, pill)
		new("UISizeConstraint", {MaxSize = Vector2.new(490, 200)}, l)
		new("UIStroke", {Thickness = 1.6, Color = C.ink}, l)
		local s = new("UIScale", {Scale = 0.7}, row)
		UI.tween(row, 0.18, {GroupTransparency = 0})
		UI.tween(s, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
		task.delay(4, function()
			if not row.Parent then return end
			UI.tween(row, 0.35, {GroupTransparency = 1})
			task.wait(0.36)
			row:Destroy()
		end)
	end
	ctx.notify = notify

	------------------------------------------------------------------
	-- AREA BANNER (top of the stack): entering a warehouse area shows a big title card
	-- for a moment, then a small banner stays while you're in that area.
	------------------------------------------------------------------
	do
		local holder = box(top, {Name = "AreaBanner", Size = UDim2.fromOffset(560, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Visible = false})
		UI.list(holder, 0, nil, Enum.HorizontalAlignment.Center)
		hud.areaBanner = holder
		-- the big card
		local big = new("CanvasGroup", {Size = UDim2.fromOffset(520, 124), BackgroundColor3 = UI.rgb(16, 14, 28), BackgroundTransparency = 0.08, LayoutOrder = 1, Visible = false}, holder)
		UI.corner(big, 20)
		local bigStroke = UI.stroke(big, 3, C.white)
		local bigScale = new("UIScale", {}, big)
		local areaL = UI.label(big, "", {Position = UDim2.fromOffset(20, 8), Size = UDim2.new(1, -40, 0, 22), Max = 20, Stroke = 2})
		local nameL = UI.label(big, "", {Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -40, 0, 46), Max = 42, Stroke = 3.2, TextWrapped = false})
		local nameGrad = new("UIGradient", {Rotation = 90}, nameL)
		local guardL = UI.label(big, "", {Position = UDim2.fromOffset(20, 78), Size = UDim2.new(0.5, -30, 0, 20), Max = 17, Stroke = 1.8,
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.rgb(255, 120, 110), TextWrapped = false})
		local speedL = UI.label(big, "", {Position = UDim2.fromOffset(20, 100), Size = UDim2.new(1, -40, 0, 18), Max = 16, Stroke = 1.6, TextWrapped = false})
		local function pips(parent, x, y, size, gap, z)
			local list = {}
			for k = 1, 5 do
				local d = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x.Scale, x.Offset + (k - 1) * gap, 0, y), Size = UDim2.fromOffset(size, size),
					Rotation = 45, BorderSizePixel = 0, BackgroundColor3 = UI.rgb(70, 70, 85), ZIndex = z or 1}, parent)
				UI.stroke(d, 1.5)
				list[k] = d
			end
			return list
		end
		local bigPips = pips(big, UDim.new(0.5, 14), 88, 12, 20)
		-- the small banner: number chip | name | danger diamonds (fixed columns: nothing overlaps)
		local mini = new("Frame", {Size = UDim2.fromOffset(400, 44), BackgroundColor3 = UI.rgb(16, 14, 28), BackgroundTransparency = 0.1, LayoutOrder = 2}, holder)
		UI.corner(mini, true)
		local miniStroke = UI.stroke(mini, 2.5, C.white)
		local miniChip = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = C.white}, mini)
		UI.corner(miniChip, true)
		UI.stroke(miniChip, 2)
		local miniNum = UI.label(miniChip, "1", {Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), Max = 20, Stroke = 2})
		local miniName = UI.label(mini, "", {Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -160, 1, -12), Max = 22, Stroke = 2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local miniPips = pips(mini, UDim.new(1, -94), 22, 9, 15)
		local miniScale = new("UIScale", {}, mini)
		local function setPips(list, n, color)
			for k, d in ipairs(list) do d.BackgroundColor3 = (k <= n) and color or UI.rgb(70, 70, 85) end
		end
		local token = 0
		local shownAt = {}
		local function showArea(zone)
			token = token + 1
			local tok = token
			local area = Config.Areas[zone]
			local danger = math.clamp(math.ceil(zone / 2), 1, 5)
			local dangerCol = UI.rgb(255, 220, 80):Lerp(UI.rgb(255, 50, 60), (danger - 1) / 4)
			holder.Visible = not UI.isOpen()
			UI.setText(miniNum, tostring(zone))
			miniChip.BackgroundColor3 = area.accent
			UI.setText(miniName, string.upper(area.name))
			miniName.TextColor3 = area.accent:Lerp(C.white, 0.2)
			miniStroke.Color = area.accent
			setPips(miniPips, danger, dangerCol)
			miniScale.Scale = 1.25
			UI.tween(miniScale, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
			-- the big card only if you haven't been here for a while (no spam while running through)
			if os.clock() - (shownAt[zone] or -100) < 25 then
				big.Visible = false
				mini.Visible = true
				return
			end
			shownAt[zone] = os.clock()
			UI.setText(areaL, "AREA " .. zone)
			areaL.TextColor3 = area.accent
			UI.setText(nameL, string.upper(area.name))
			nameGrad.Color = ColorSequence.new(C.white, area.accent:Lerp(C.white, 0.2))
			UI.setText(guardL, "Guardian: " .. area.guard)
			bigStroke.Color = area.accent
			local rec = Config.RecommendedPoints(zone)
			local mine = player:GetAttribute("SpeedPoints") or Config.StartSpeed
			UI.setText(speedL, (zone > 1) and ("Recommended speed: " .. fmt(rec) .. "   (you: " .. fmt(mine) .. ")") or "The easiest area - start here!")
			speedL.TextColor3 = (zone > 1 and mine < rec) and UI.rgb(255, 110, 100) or UI.rgb(150, 255, 120)
			setPips(bigPips, 0, dangerCol)
			for k = 1, danger do
				task.delay(0.2 + k * 0.08, function()
					if tok == token then bigPips[k].BackgroundColor3 = dangerCol end
				end)
			end
			mini.Visible = false
			big.Visible = true
			big.GroupTransparency = 1
			bigScale.Scale = 0.7
			UI.tween(big, 0.25, {GroupTransparency = 0})
			UI.tween(bigScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
			UI.SFX.play("open", 0.75, 0.35)
			task.delay(2.8, function()
				if tok ~= token then return end
				UI.tween(big, 0.3, {GroupTransparency = 1})
				task.delay(0.3, function()
					if tok ~= token then return end
					big.Visible = false
					mini.Visible = true
				end)
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
					if zone then
						showArea(zone)
					else
						token = token + 1
						holder.Visible = false
					end
				end
			end
		end)
		hud.inArea = function() return lastZone ~= nil end
	end

	-- windows sit above the HUD; while one is open the banner + tutorial step aside
	UI.WindowChanged:Connect(function(name)
		local open = name ~= nil
		hud.areaBanner.Visible = (not open) and hud.inArea()
		tutorialSlot.Visible = not open
		hud.bottomStack.Visible = not open
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
	UI.list(bottom, 8, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	hud.bottomStack = bottom

	-- CARRYING: the box's name, a hint and a big Drop button
	local carry = box(bottom, {Name = "Carry", Size = UDim2.fromOffset(460, 104), LayoutOrder = 2, Visible = false})
	local carryBack = new("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.hud, BackgroundTransparency = 0.12}, carry)
	UI.corner(carryBack, 16)
	UI.stroke(carryBack, 2.5)
	local carryName = UI.label(carryBack, "", {Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -24, 0, 26), Max = 22, Stroke = 2, TextColor3 = C.yellow, TextWrapped = false})
	local carryHint = UI.label(carryBack, IS_TOUCH() and "Tap your plot's floor to place it" or "Click your plot's floor to place it",
		{Position = UDim2.fromOffset(12, 29), Size = UDim2.new(1, -24, 0, 18), Max = 16, Stroke = 1.5, TextColor3 = C.sub, TextWrapped = false})
	local dropBtn = UI.button(carry, {Text = IS_TOUCH() and "Drop" or "Drop  [G]", Color = C.red, Icon = "down", IconColor = C.white, Size = UDim2.fromOffset(190, 46),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), TextSize = 22})
	dropBtn.Activated:Connect(function() ctx.remotes.Drop:FireServer() end)
	local function updateCarry()
		local id = player:GetAttribute("Carrying")
		carry.Visible = id ~= nil
		if id then
			local def = Config.Boxes[id]
			UI.setText(carryName, "Carrying: " .. (player:GetAttribute("CarryLabel") or id))
			if def then carryName.TextColor3 = (Config.Rarities[def.rarity] or Config.Rarities[1]).color:Lerp(C.yellow, 0.3) end
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
		ctx.bonk = function()
			bonk.Visible = true
			bonk.Rotation = math.random(-12, 12)
			bScale.Scale = 0.3 * UI.scale
			UI.tween(bScale, 0.35, {Scale = UI.scale}, Enum.EasingStyle.Back)
			task.delay(1.2, function() bonk.Visible = false end)
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
		ctx.thanks = function(title)
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
	local function onRebirths()
		local n = player:GetAttribute("Rebirths") or 0
		rebChip.Visible = n > 0
		UI.setText(rebLabel, "REBIRTH " .. n .. "  |  x" .. Config.RebirthCashMult(n) .. " cash")
	end
	player:GetAttributeChangedSignal("Rebirths"):Connect(onRebirths)
	onRebirths()

	-- timers + badges that depend on the clock
	task.spawn(function()
		while true do
			local nowT = workspace:GetServerTimeNow()
			local night = ReplicatedStorage:GetAttribute("IsNight")
			local ends = ReplicatedStorage:GetAttribute("PhaseEndsAt")
			phaseT.icon.Visible = not night
			sunIcon.Visible = night == true
			UI.setText(phaseT.label, ends and ((night and "Day in " or "Night in ") .. Config.FormatTime(ends - nowT)) or "")
			phaseT.label.TextColor3 = night and UI.rgb(255, 230, 120) or UI.rgb(180, 200, 255)
			local special = ReplicatedStorage:GetAttribute("SpecialAt")
			UI.setText(rainbowT.label, special and ("Rainbow box in " .. Config.FormatTime(special - nowT)) or "")
			local luckUntil = ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0
			luckT.frame.Visible = luckUntil > nowT
			if luckUntil > nowT then UI.setText(luckT.label, Config.ServerLuck.mult .. "x LUCK  " .. Config.FormatTime(luckUntil - nowT)) end
			if ctx.updateClockBadges then ctx.updateClockBadges() end
			task.wait(0.25)
		end
	end)

	-- the menu icons bob gently, the offer bounces, sheens sweep
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for i, e in ipairs(hud.menuIcons) do
			e.icon.Position = e.pos + UDim2.fromOffset(0, math.sin(t * 2.4 + i * 0.9) * 1.5)
			e.icon.Rotation = math.sin(t * 1.7 + i) * 5
		end
		if offer.Visible then
			local target = 1 + 0.05 * math.abs(math.sin(t * 3))
			offerScale.Scale = offerScale.Scale + (target - offerScale.Scale) * math.min(1, dt * 8)
			offerCard.Rotation = math.sin(t * 2.2) * 3
			offerSheenGrad.Offset = Vector2.new(((t * 0.55) % 2.4) - 1.2, 0)
		end
		shopSheenGrad.Offset = Vector2.new(((t * 0.4 + 1) % 2.8) - 1.4, 0)
		for _, b in pairs(badges) do
			if b.frame.Visible then b.scale.Scale = 1 + 0.12 * math.abs(math.sin(t * 4)) end
		end
	end)

	-- the HUD slides in when you join
	do
		local slides = {
			{currency, UDim2.fromOffset(-300, 8)},
			{menu, UDim2.fromOffset(-200, 160)},
			{timers, UDim2.new(1, 300, 0, 8)},
			{right, UDim2.new(1, 240, RIGHT_Y, 10)},
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
