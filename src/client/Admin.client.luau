--[[ STEAL A BOX - ADMIN PANEL (client)
This script lives in ServerStorage: the server only hands it to admins, inside their PlayerGui.
It is just the buttons - the server checks EVERY request again, so it's useless to exploiters.
Open / close: the ADMIN button at the top, or F2. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("StealABoxConfig"))
local remote = ReplicatedStorage:WaitForChild("StealABoxRemotes"):WaitForChild("AdminAction")
local gui = script.Parent

local FONT = Config.Font
local WHITE, INK = Color3.new(1, 1, 1), Color3.fromRGB(22, 18, 38)
local GREEN, BLUE, RED, GOLD, PURPLE, ORANGE, PINK, TEAL = Color3.fromRGB(70, 210, 60), Color3.fromRGB(60, 150, 255), Color3.fromRGB(235, 60, 70),
	Color3.fromRGB(255, 190, 40), Color3.fromRGB(150, 90, 230), Color3.fromRGB(255, 130, 40), Color3.fromRGB(255, 90, 170), Color3.fromRGB(40, 200, 190)
local BG_TOP, BG_BOTTOM, CARD, SLOT = Color3.fromRGB(48, 38, 92), Color3.fromRGB(22, 18, 44), Color3.fromRGB(60, 50, 104), Color3.fromRGB(80, 70, 130)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function round(o, r) return new("UICorner", {CornerRadius = (r == true) and UDim.new(1, 0) or UDim.new(0, r or 10)}, o) end
local function stroke(o, t, c) return new("UIStroke", {Thickness = t or 2.5, Color = c or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function textStroke(o) return new("UIStroke", {Thickness = 2, Color = INK}, o) end
local function shine(o)
	-- a soft top-to-bottom shade, like the rest of the game's buttons
	return new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(195, 195, 205))}, o)
end
local function tween(o, t, props) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end

-- "1.5M" / "2B" / "1e12" / "250000" -> number
local SUFFIX = {k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30}
local function parseNum(str)
	str = string.lower((str or ""):gsub("[%s,%$x]", ""))
	local n = tonumber(str)
	if n then return n end
	local num, suf = str:match("^([%d%.]+)(%a+)$")
	if num and tonumber(num) and SUFFIX[suf] then return tonumber(num) * SUFFIX[suf] end
	return nil
end

------------------------------------------------------------------
-- the toggle button + the window
------------------------------------------------------------------
local toggle = new("TextButton", {Name = "AdminToggle", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(130, 38), BackgroundColor3 = RED, Text = "ADMIN", TextColor3 = WHITE, FontFace = FONT, TextSize = 22}, gui)
round(toggle, true)
stroke(toggle, 3)
textStroke(toggle)
shine(toggle)

local win = new("Frame", {Name = "AdminWindow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.fromScale(0.95, 0.86), BackgroundColor3 = WHITE, Visible = false}, gui)
new("UISizeConstraint", {MaxSize = Vector2.new(520, 700)}, win)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(BG_TOP, BG_BOTTOM)}, win)
round(win, 20)
stroke(win, 4)
local winScale = new("UIScale", {}, win)

local header = new("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = WHITE}, win)
round(header, 20)
new("UIGradient", {Rotation = 0, Color = ColorSequence.new(Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 150, 50))}, header)
local title = new("TextLabel", {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0), BackgroundTransparency = 1, Text = "ADMIN PANEL",
	TextColor3 = WHITE, FontFace = FONT, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left}, header)
textStroke(title)
local roleTag = new("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -50, 0.5, 0), Size = UDim2.fromOffset(80, 26),
	BackgroundColor3 = GOLD, Text = "ADMIN", TextColor3 = WHITE, FontFace = FONT, TextSize = 16}, header)
round(roleTag, true)
stroke(roleTag, 2)
textStroke(roleTag)
local close = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(210, 40, 55), Text = "X", TextColor3 = WHITE, FontFace = FONT, TextSize = 22}, header)
round(close, 10)
stroke(close, 2.5)
textStroke(close)

local status = new("TextLabel", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -6), Size = UDim2.new(1, -24, 0, 28),
	BackgroundColor3 = Color3.fromRGB(30, 24, 56), BackgroundTransparency = 0.2, Text = "Pick a player, then use the tabs.", TextColor3 = GOLD,
	FontFace = FONT, TextScaled = true}, win)
round(status, 10)
textStroke(status)
new("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3)}, status)

local function setOpen(open)
	win.Visible = open
	if open then
		winScale.Scale = 0.85
		TweenService:Create(winScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end
end
toggle.Activated:Connect(function() setOpen(not win.Visible) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F2 then setOpen(not win.Visible) end
end)

------------------------------------------------------------------
-- PLAYER STRIP: everybody in the server (with their avatar) + EVERYONE. Shared by all tabs.
------------------------------------------------------------------
local selected = player.UserId
local strip = new("ScrollingFrame", {Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 78), BackgroundColor3 = Color3.fromRGB(30, 24, 56),
	BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X}, win)
round(strip, 12)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center}, strip)
new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, strip)
local cards = {}
local function paintCards()
	for id, c in pairs(cards) do
		c.stroke.Color = (id == selected) and GOLD or INK
		c.stroke.Thickness = (id == selected) and 4 or 2
		c.frame.BackgroundColor3 = (id == selected) and Color3.fromRGB(110, 90, 190) or SLOT
	end
end
local function rebuildStrip()
	for _, c in pairs(cards) do c.frame:Destroy() end
	cards = {}
	local list = {{id = player.UserId, name = "Me"}}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then table.insert(list, {id = p.UserId, name = p.Name}) end
	end
	table.insert(list, {id = -1, name = "EVERYONE"})
	local still = false
	for i, e in ipairs(list) do
		if e.id == selected then still = true end
		local f = new("TextButton", {Size = UDim2.fromOffset(66, 66), BackgroundColor3 = SLOT, Text = "", AutoButtonColor = false, LayoutOrder = i}, strip)
		round(f, 12)
		local st = stroke(f, 2)
		if e.id == -1 then
			new("TextLabel", {Size = UDim2.new(1, 0, 0.7, 0), BackgroundTransparency = 1, Text = "🌍", TextScaled = true}, f)
		else
			local img = new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(44, 44),
				BackgroundColor3 = Color3.fromRGB(230, 235, 245), Image = "rbxthumb://type=AvatarHeadShot&id=" .. e.id .. "&w=150&h=150"}, f)
			round(img, true)
		end
		local nl = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -4, 0, 16),
			BackgroundTransparency = 1, Text = e.name, TextColor3 = WHITE, FontFace = FONT, TextScaled = true}, f)
		textStroke(nl)
		f.Activated:Connect(function()
			selected = e.id
			paintCards()
		end)
		cards[e.id] = {frame = f, stroke = st}
	end
	if not still then selected = player.UserId end
	paintCards()
end
Players.PlayerAdded:Connect(rebuildStrip)
Players.PlayerRemoving:Connect(function() task.defer(rebuildStrip) end)
rebuildStrip()

------------------------------------------------------------------
-- TABS
------------------------------------------------------------------
local tabBar = new("Frame", {Position = UDim2.fromOffset(10, 140), Size = UDim2.new(1, -20, 0, 38), BackgroundTransparency = 1}, win)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, tabBar)
local pages, tabButtons, tabColors = {}, {}, {}
local page, holder, order = nil, nil, 0
local function showTab(name)
	for n, pg in pairs(pages) do pg.Visible = (n == name) end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and tabColors[n] or SLOT
		b.TextColor3 = (n == name) and WHITE or Color3.fromRGB(205, 200, 230)
	end
end
local function tab(name, color, layoutOrder)
	local pg = new("ScrollingFrame", {Position = UDim2.fromOffset(10, 184), Size = UDim2.new(1, -20, 1, -224), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false}, win)
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, pg)
	new("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, pg)
	local b = new("TextButton", {Size = UDim2.new(0.2, -4, 1, 0), BackgroundColor3 = SLOT, Text = name, TextColor3 = WHITE,
		FontFace = FONT, TextScaled = true, LayoutOrder = layoutOrder}, tabBar)
	round(b, 10)
	stroke(b, 2)
	textStroke(b)
	new("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2)}, b)
	b.Activated:Connect(function() showTab(name) end)
	pages[name], tabButtons[name], tabColors[name] = pg, b, color
	page, holder, order = pg, pg, 0
	return pg, b
end

-- a card: a rounded panel with a coloured title; rows go inside it
local function card(titleText, color)
	order = order + 1
	local c = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD, LayoutOrder = order}, page)
	round(c, 14)
	stroke(c, 2.5, color:Lerp(INK, 0.4))
	new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, c)
	new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, c)
	local t = new("TextLabel", {Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = color, Text = titleText, TextColor3 = WHITE, FontFace = FONT,
		TextSize = 20, LayoutOrder = 0}, c)
	round(t, 8)
	shine(t)
	textStroke(t)
	holder = c
	return c
end
local function row(height)
	order = order + 1
	return new("Frame", {Size = UDim2.new(1, 0, 0, height or 40), BackgroundTransparency = 1, LayoutOrder = order}, holder)
end
local function button(parent, text, color, x, w, onClick)
	local b = new("TextButton", {Position = UDim2.new(x, 2, 0, 2), Size = UDim2.new(w, -4, 1, -4), BackgroundColor3 = color, Text = text,
		TextColor3 = WHITE, FontFace = FONT, TextScaled = true, AutoButtonColor = false}, parent)
	round(b, 10)
	stroke(b, 2.5)
	textStroke(b)
	shine(b)
	new("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, b)
	local sc = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() tween(sc, 0.12, {Scale = 1.05}) end)
	b.MouseLeave:Connect(function() tween(sc, 0.12, {Scale = 1}) end)
	b.Activated:Connect(function()
		sc.Scale = 0.9
		tween(sc, 0.18, {Scale = 1})
		onClick()
	end)
	return b
end
local function input(parent, placeholder, x, w)
	local t = new("TextBox", {Position = UDim2.new(x, 2, 0, 2), Size = UDim2.new(w, -4, 1, -4), BackgroundColor3 = Color3.fromRGB(245, 244, 252), Text = "",
		PlaceholderText = placeholder, TextColor3 = INK, PlaceholderColor3 = Color3.fromRGB(140, 140, 155), FontFace = FONT, TextScaled = true,
		ClearTextOnFocus = false}, parent)
	round(t, 10)
	stroke(t, 2)
	new("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, t)
	return t
end
local function textLine(height, text)
	local r = row(height)
	return new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text or "", TextColor3 = WHITE, FontFace = FONT,
		TextScaled = true, TextWrapped = true}, r)
end
-- < value > picker. getList() returns {{label, value}, ...}
local function picker(titleText, getList, onChange)
	local r = row(40)
	new("TextLabel", {Size = UDim2.new(0.28, 0, 1, 0), BackgroundTransparency = 1, Text = titleText, TextColor3 = WHITE, FontFace = FONT,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, r)
	local state = {i = 1}
	local label
	local function show()
		local list = getList()
		if state.i > #list then state.i = 1 elseif state.i < 1 then state.i = #list end
		label.Text = list[state.i] and list[state.i][1] or "-"
	end
	local function step(d)
		state.i = state.i + d
		show()
		if onChange then onChange() end
	end
	button(r, "<", PURPLE, 0.28, 0.13, function() step(-1) end)
	label = new("TextLabel", {Position = UDim2.new(0.41, 2, 0, 2), Size = UDim2.new(0.46, -4, 1, -4), BackgroundColor3 = SLOT,
		Text = "", TextColor3 = WHITE, FontFace = FONT, TextScaled = true}, r)
	round(label, 10)
	textStroke(label)
	new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, label)
	button(r, ">", PURPLE, 0.87, 0.13, function() step(1) end)
	function state.value() local list = getList() return list[state.i] and list[state.i][2] end
	state.show = show
	show()
	return state
end

local busy = false
local function say(msg, good)
	status.Text = msg
	status.TextColor3 = good and Color3.fromRGB(130, 255, 120) or Color3.fromRGB(255, 120, 120)
end
local function send(action, args)
	if busy then return nil end
	busy = true
	status.Text = "..."
	status.TextColor3 = GOLD
	local ok, r = pcall(function() return remote:InvokeServer(action, args) end)
	busy = false
	if not ok or type(r) ~= "table" then
		say("Something went wrong.", false)
		return nil
	end
	say(tostring(r.msg or (r.ok and "Done!" or "No.")), r.ok)
	return r
end

------------------------------------------------------------------
-- TAB: PLAYERS
------------------------------------------------------------------
tab("Players", BLUE, 1)
card("PLAYER", BLUE)
local statsLabel
do
	local r = row(44)
	button(r, "STATS", PURPLE, 0, 0.34, function()
		local res = send("Stats", {target = selected})
		if res and res.ok and type(res.stats) == "table" then
			local lines = {}
			for _, kv in ipairs(res.stats) do table.insert(lines, tostring(kv[1]) .. ": " .. tostring(kv[2])) end
			statsLabel.Text = table.concat(lines, "   •   ")
		end
	end)
	button(r, "GO TO", BLUE, 0.34, 0.33, function() send("Goto", {target = selected}) end)
	button(r, "BRING", TEAL, 0.67, 0.33, function() send("Bring", {target = selected}) end)
	statsLabel = textLine(64, "Pick a player above and press STATS.")
end
for _, kind in ipairs({{"MONEY", "Cash", GREEN, "Cash (e.g. 1.5M, 2B)"}, {"SPEED", "Speed", GOLD, "Speed (e.g. 50K, 1T)"}}) do
	card(kind[1], kind[3])
	local r = row(44)
	local box = input(r, kind[4], 0, 0.5)
	local function go(mode)
		local amount = parseNum(box.Text)
		if not amount then return say("Type a number first.", false) end
		send(kind[2], {target = selected, amount = amount, mode = mode})
	end
	button(r, "SET", BLUE, 0.5, 0.25, function() go("set") end)
	button(r, "ADD", GREEN, 0.75, 0.25, function() go("add") end)
end
card("UPGRADE LEVELS", PURPLE)
do
	local stat = picker("Upgrade", function()
		return {{"Treadmill", "Treadmill"}, {"Shoppers", "Shoppers"}, {"Payouts", "Payouts"}, {"Unbox Speed", "Unbox"},
			{"Podium slots (" .. Config.BaseStands .. "-" .. Config.MaxStands .. ")", "Slots"}}
	end)
	local r = row(44)
	local lvl = input(r, "Level (e.g. 50)", 0, 0.6)
	button(r, "SET LEVEL", PURPLE, 0.6, 0.4, function()
		local n = parseNum(lvl.Text)
		if not n then return say("Type a level first.", false) end
		send("Level", {target = selected, stat = stat.value(), level = n})
	end)
end
card("KICK / BAN", RED)
do
	local r = row(44)
	local reason = input(r, "Reason (optional)", 0, 1)
	local r2 = row(44)
	button(r2, "KICK", ORANGE, 0, 0.5, function() send("Kick", {target = selected, reason = reason.Text}) end)
	button(r2, "BAN", RED, 0.5, 0.5, function() send("Ban", {target = selected, reason = reason.Text}) end)
	local r3 = row(44)
	local name = input(r3, "Username (offline ban / unban)", 0, 0.5)
	button(r3, "BAN", RED, 0.5, 0.25, function() send("Ban", {name = name.Text, reason = reason.Text}) end)
	button(r3, "UNBAN", GREEN, 0.75, 0.25, function() send("Unban", {name = name.Text}) end)
end
card("LEADERBOARDS", ORANGE)
do
	local r = row(44)
	local name = input(r, "Username (empty = picked player)", 0, 1)
	local r2 = row(44)
	local function args()
		local n = (name.Text or ""):gsub("%s", "")
		return {name = n, target = (n == "") and selected or nil}
	end
	button(r2, "REMOVE FROM BOARDS", RED, 0, 0.6, function() send("LbRemove", args()) end)
	button(r2, "PUT BACK", GREEN, 0.6, 0.4, function() send("LbRestore", args()) end)
end
card("HALL OF FAME", GOLD)
do
	local r = row(44)
	local name = input(r, "Username (empty = picked)", 0, 0.6)
	local fameTitle = input(r, "Title (optional)", 0.6, 0.4)
	local r2 = row(44)
	local function args()
		local n = (name.Text or ""):gsub("%s", "")
		return {name = n, target = (n == "") and selected or nil, title = fameTitle.Text}
	end
	button(r2, "ADD TO HALL OF FAME", GREEN, 0, 0.6, function() send("FameAdd", args()) end)
	button(r2, "REMOVE", RED, 0.6, 0.4, function() send("FameRemove", args()) end)
end

------------------------------------------------------------------
-- TAB: BOXES
------------------------------------------------------------------
tab("Boxes", PURPLE, 2)
card("WHAT BOX?", PURPLE)
local kind
local area = picker("Area", function()
	local list = {{"Random", 0}}
	for i, a in ipairs(Config.Areas) do table.insert(list, {i .. ". " .. a.name, i}) end
	return list
end, function() if kind then kind.show() end end)
kind = picker("Box", function()
	local a = Config.Areas[area.value() or 0]
	local list = {{"Random", 0}}
	for r, name in ipairs({"Common", "Rare", "Epic"}) do
		table.insert(list, {a and a.boxes[r] and a.boxes[r].name or name, r})
	end
	return list
end)
local mutation = picker("Mutation", function()
	local list = {{"Random", "Random"}}
	for _, m in ipairs(Config.Mutations) do table.insert(list, {m.id, m.id}) end
	return list
end)
local sizeBox, countBox
do
	local r = row(44)
	new("TextLabel", {Size = UDim2.new(0.28, 0, 1, 0), BackgroundTransparency = 1, Text = "Size", TextColor3 = WHITE, FontFace = FONT,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, r)
	sizeBox = input(r, "1 = normal, 5 = huge (empty = random)", 0.28, 0.72)
	local r2 = row(44)
	new("TextLabel", {Size = UDim2.new(0.28, 0, 1, 0), BackgroundTransparency = 1, Text = "How many", TextColor3 = WHITE, FontFace = FONT,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, r2)
	countBox = input(r2, "1-50", 0.28, 0.72)
	countBox.Text = "10"
	textLine(22, "No size limit - bigger boxes are worth way more (and slower to carry).")
end
local function boxArgs(where)
	local size = parseNum(sizeBox.Text)
	return {area = area.value(), rarity = kind.value(), mutation = mutation.value(), size = size, where = where, target = selected,
		count = math.clamp(math.floor(tonumber(countBox.Text) or 10), 1, 50)}
end
card("SPAWN", GREEN)
do
	local r = row(46)
	button(r, "SPAWN AROUND ME", GREEN, 0, 0.5, function() send("Boxes", boxArgs("me")) end)
	button(r, "FILL WAREHOUSE", BLUE, 0.5, 0.5, function() send("Boxes", boxArgs("everywhere")) end)
	local r2 = row(46)
	button(r2, "GIVE TO PICKED PLAYER", PINK, 0, 0.6, function()
		if selected == -1 then return say("Pick one player (not EVERYONE).", false) end
		send("GiveBox", boxArgs("plot"))
	end)
	button(r2, "CLEAN UP", RED, 0.6, 0.4, function() send("ClearBoxes", {}) end)
end

------------------------------------------------------------------
-- TAB: SERVER
------------------------------------------------------------------
tab("Server", RED, 3)
card("ANNOUNCEMENT", RED)
do
	local r = row(76)
	local msg = input(r, "Type your announcement (max 200)", 0, 1)
	msg.TextWrapped = true
	msg.MultiLine = true
	local r2 = row(46)
	local function go(global)
		if (msg.Text or ""):gsub("%s", "") == "" then return say("Type a message first.", false) end
		local res = send("Announce", {text = msg.Text, global = global})
		if res and res.ok then msg.Text = "" end
	end
	button(r2, "THIS SERVER", BLUE, 0, 0.5, function() go(false) end)
	button(r2, "ALL SERVERS", RED, 0.5, 0.5, function() go(true) end)
end
card("EVENTS", GOLD)
do
	local event = picker("Event", function()
		local list = {}
		for _, e in ipairs(Config.Events) do table.insert(list, {e.name, e.id}) end
		return list
	end)
	local r = row(46)
	button(r, "START EVENT", GREEN, 0, 0.5, function() send("Event", {id = event.value()}) end)
	button(r, "SERVER LUCK", PURPLE, 0.5, 0.5, function() send("Luck", {}) end)
	local r2 = row(44)
	button(r2, "SERVER INFO", TEAL, 0, 1, function() send("ServerInfo", {}) end)
end

------------------------------------------------------------------
-- TAB: TOOLS (just for you): fly, noclip, god mode, spectate
------------------------------------------------------------------
tab("Tools", TEAL, 4)
card("MOVE", TEAL)
local flying, noclip, spectating = false, false, nil
local flyBtn, clipBtn, godBtn, specBtn
local function paint(b, on, label)
	b.Text = label .. (on and ": ON" or ": OFF")
	b.BackgroundColor3 = on and GREEN or SLOT
end
do
	local r = row(46)
	flyBtn = button(r, "FLY: OFF", SLOT, 0, 0.5, function()
		flying = not flying
		paint(flyBtn, flying, "FLY")
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and not flying then hum.PlatformStand = false end
	end)
	clipBtn = button(r, "NOCLIP: OFF", SLOT, 0.5, 0.5, function()
		noclip = not noclip
		paint(clipBtn, noclip, "NOCLIP")
	end)
	textLine(22, "Fly: move with WASD / joystick, Space = up, Shift = down.")
end
card("SAFETY", GOLD)
do
	local r = row(46)
	godBtn = button(r, "GOD MODE: OFF", SLOT, 0, 1, function()
		local res = send("God", {})
		if res and res.ok then paint(godBtn, res.on == true, "GOD MODE") end
	end)
	textLine(22, "God mode: the guardians ignore you.")
end
card("SPECTATE", PURPLE)
do
	local r = row(46)
	specBtn = button(r, "WATCH PICKED PLAYER", PURPLE, 0, 0.65, function()
		local p = Players:GetPlayerByUserId(selected)
		local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not hum or p == player then return say("Pick another player to watch.", false) end
		spectating = p
		workspace.CurrentCamera.CameraSubject = hum
		say("Watching " .. p.Name, true)
	end)
	button(r, "STOP", RED, 0.65, 0.35, function()
		spectating = nil
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then workspace.CurrentCamera.CameraSubject = hum end
		say("Back to you.", true)
	end)
end
-- fly + noclip run every frame on your own character (your client moves it anyway)
RunService.Stepped:Connect(function()
	if not noclip then return end
	local char = player.Character
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
end)
RunService.RenderStepped:Connect(function()
	if not flying then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not hum or not hrp or not cam then return end
	hum.PlatformStand = true
	local md = hum.MoveDirection
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local right = cam.CFrame.RightVector
	local f, s = md:Dot(flat), md:Dot(Vector3.new(right.X, 0, right.Z).Unit)
	local up = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0)
	local vel = (look * f + right * s) * 90 + Vector3.new(0, up * 60, 0)
	hrp.AssemblyLinearVelocity = vel
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
end)
player.CharacterAdded:Connect(function()
	flying = false
	paint(flyBtn, false, "FLY")
end)

------------------------------------------------------------------
-- TAB: ADMINS (only the owner can give / remove admin)
------------------------------------------------------------------
local _, adminsTab = tab("Admins", GOLD, 5)
adminsTab.Visible = false
local function buildOwnerPart(info)
	adminsTab.Visible = true
	roleTag.Text = "OWNER"
	card("GIVE ADMIN (owner only)", GOLD)
	local r = row(44)
	local name = input(r, "Roblox username", 0, 1)
	local r2 = row(46)
	local listL
	local function showList(list)
		local names = {}
		for _, a in ipairs(list or {}) do table.insert(names, tostring(a.name)) end
		listL.Text = (#names > 0) and ("Admins: " .. table.concat(names, ", ")) or "No other admins yet."
	end
	local function refreshList()
		local res = send("Info", {})
		if res and res.ok then showList(res.admins) end
	end
	button(r2, "GIVE ADMIN", GREEN, 0, 0.5, function()
		local res = send("Grant", {name = name.Text})
		if res and res.ok then task.delay(0.3, refreshList) end
	end)
	button(r2, "REMOVE ADMIN", RED, 0.5, 0.5, function()
		local res = send("Revoke", {name = name.Text})
		if res and res.ok then task.delay(0.3, refreshList) end
	end)
	listL = textLine(64, "")
	showList(info.admins)
end
showTab("Players")
task.spawn(function()
	local ok, info = pcall(function() return remote:InvokeServer("Info", {}) end)
	if ok and type(info) == "table" and info.owner then
		page, holder, order = pages.Admins, pages.Admins, 0
		buildOwnerPart(info)
	end
end)
