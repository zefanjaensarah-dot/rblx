--[[ STEAL A BOX - ADMIN PANEL (client)
This script lives in ServerStorage: the server only hands it to admins, inside their PlayerGui.
It is just the buttons - the server checks EVERY request again, so it's useless to exploiters.
Open / close: the ADMIN button at the top, or F2. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("StealABoxConfig"))
local remote = ReplicatedStorage:WaitForChild("StealABoxRemotes"):WaitForChild("AdminAction")
local gui = script.Parent

local FONT = Config.Font
local WHITE, INK = Color3.new(1, 1, 1), Color3.fromRGB(25, 20, 40)
local GREEN, BLUE, RED, GOLD, PURPLE, ORANGE = Color3.fromRGB(70, 210, 60), Color3.fromRGB(60, 150, 255), Color3.fromRGB(235, 60, 70),
	Color3.fromRGB(255, 190, 40), Color3.fromRGB(150, 90, 230), Color3.fromRGB(255, 130, 40)
local PANEL, TAB_OFF = Color3.fromRGB(40, 34, 64), Color3.fromRGB(70, 60, 105)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function round(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 10)}, o) end
local function stroke(o, t) new("UIStroke", {Thickness = t or 2.5, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function textStroke(o) new("UIStroke", {Thickness = 2, Color = INK}, o) end

-- "1.5M" / "2B" / "1e12" / "250000" -> number
local SUFFIX = {k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30}
local function parseNum(str)
	str = string.lower((str or ""):gsub("[%s,%$]", ""))
	local n = tonumber(str)
	if n then return n end
	local num, suf = str:match("^([%d%.]+)(%a+)$")
	if num and tonumber(num) and SUFFIX[suf] then return tonumber(num) * SUFFIX[suf] end
	return nil
end

------------------------------------------------------------------
-- the toggle button + the window with tabs
------------------------------------------------------------------
local toggle = new("TextButton", {Name = "AdminToggle", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(120, 36), BackgroundColor3 = RED, Text = "ADMIN", TextColor3 = WHITE, FontFace = FONT, TextSize = 22}, gui)
round(toggle, 12)
stroke(toggle, 3)
textStroke(toggle)

local win = new("Frame", {Name = "AdminWindow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.94, 0.84), BackgroundColor3 = PANEL, Visible = false}, gui)
new("UISizeConstraint", {MaxSize = Vector2.new(480, 660)}, win)
round(win, 16)
stroke(win, 4)
local header = new("TextLabel", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = RED, Text = "ADMIN PANEL", TextColor3 = WHITE,
	FontFace = FONT, TextSize = 28}, win)
round(header, 16)
textStroke(header)
local close = new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = Color3.fromRGB(200, 40, 50), Text = "X", TextColor3 = WHITE, FontFace = FONT, TextSize = 22}, win)
round(close, 8)
stroke(close, 2)
local status = new("TextLabel", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.new(1, -20, 0, 26),
	BackgroundTransparency = 1, Text = "", TextColor3 = GOLD, FontFace = FONT, TextScaled = true}, win)
textStroke(status)
local tabBar = new("Frame", {Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 0, 36), BackgroundTransparency = 1}, win)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, tabBar)

local function setOpen(open) win.Visible = open end
toggle.Activated:Connect(function() setOpen(not win.Visible) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F2 then setOpen(not win.Visible) end
end)

-- tabs: each one is its own scrolling page
local pages, tabButtons = {}, {}
local page, order = nil, 0
local function showTab(name)
	for n, pg in pairs(pages) do pg.Visible = (n == name) end
	for n, b in pairs(tabButtons) do b.BackgroundColor3 = (n == name) and ORANGE or TAB_OFF end
end
local function tab(name, layoutOrder)
	local pg = new("ScrollingFrame", {Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 1, -130), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false}, win)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, pg)
	local b = new("TextButton", {Size = UDim2.new(0.25, -5, 1, 0), BackgroundColor3 = TAB_OFF, Text = name, TextColor3 = WHITE,
		FontFace = FONT, TextScaled = true, LayoutOrder = layoutOrder}, tabBar)
	round(b, 8)
	stroke(b, 2)
	textStroke(b)
	new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, b)
	b.Activated:Connect(function() showTab(name) end)
	pages[name], tabButtons[name] = pg, b
	page, order = pg, 0
	return pg, b
end

local function row(height)
	order = order + 1
	return new("Frame", {Size = UDim2.new(1, -8, 0, height or 40), BackgroundTransparency = 1, LayoutOrder = order}, page)
end
local function section(title, color)
	local r = row(32)
	local l = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Text = title, TextColor3 = WHITE, FontFace = FONT, TextSize = 22}, r)
	round(l, 8)
	textStroke(l)
	return r
end
local function button(parent, text, color, x, w, onClick)
	local b = new("TextButton", {Position = UDim2.new(x, 2, 0, 2), Size = UDim2.new(w, -4, 1, -4), BackgroundColor3 = color, Text = text,
		TextColor3 = WHITE, FontFace = FONT, TextScaled = true}, parent)
	round(b, 8)
	stroke(b, 2)
	textStroke(b)
	new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, b)
	b.Activated:Connect(onClick)
	return b
end
local function input(parent, placeholder, x, w)
	local t = new("TextBox", {Position = UDim2.new(x, 2, 0, 2), Size = UDim2.new(w, -4, 1, -4), BackgroundColor3 = WHITE, Text = "",
		PlaceholderText = placeholder, TextColor3 = INK, PlaceholderColor3 = Color3.fromRGB(140, 140, 150), FontFace = FONT, TextScaled = true,
		ClearTextOnFocus = false}, parent)
	round(t, 8)
	stroke(t, 2)
	new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, t)
	return t
end
local function textLine(height, text)
	local r = row(height)
	local l = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text or "", TextColor3 = WHITE, FontFace = FONT,
		TextScaled = true, TextWrapped = true}, r)
	return l
end
-- < value > picker. getList() returns {{label, value}, ...}
local function picker(title, getList, onChange)
	local r = row(40)
	new("TextLabel", {Size = UDim2.new(0.3, 0, 1, 0), BackgroundTransparency = 1, Text = title, TextColor3 = WHITE, FontFace = FONT,
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
	button(r, "<", PURPLE, 0.3, 0.12, function() step(-1) end)
	label = new("TextLabel", {Position = UDim2.new(0.42, 2, 0, 2), Size = UDim2.new(0.46, -4, 1, -4), BackgroundColor3 = TAB_OFF,
		Text = "", TextColor3 = WHITE, FontFace = FONT, TextScaled = true}, r)
	round(label, 8)
	button(r, ">", PURPLE, 0.88, 0.12, function() step(1) end)
	function state.value() local list = getList() return list[state.i] and list[state.i][2] end
	state.show = show
	show()
	return state
end

local busy = false
local function send(action, args)
	if busy then return nil end
	busy = true
	status.Text = "..."
	local ok, r = pcall(function() return remote:InvokeServer(action, args) end)
	busy = false
	if not ok or type(r) ~= "table" then
		status.Text = "Something went wrong."
		status.TextColor3 = RED
		return nil
	end
	status.Text = tostring(r.msg or (r.ok and "Done!" or "No."))
	status.TextColor3 = r.ok and GREEN or RED
	return r
end
local function fail(msg)
	status.Text = msg
	status.TextColor3 = RED
end

------------------------------------------------------------------
-- TAB 1: PLAYERS - stats, money, speed, teleport, kick / ban, leaderboards
------------------------------------------------------------------
tab("Players", 1)
section("PLAYER", BLUE)
local who = picker("Who", function()
	local list = {{"Me (" .. player.Name .. ")", player.UserId}}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then table.insert(list, {p.Name, p.UserId}) end
	end
	table.insert(list, {"EVERYONE (money/speed)", -1})
	return list
end)
Players.PlayerAdded:Connect(function() who.show() end)
Players.PlayerRemoving:Connect(function() task.defer(who.show) end)
local statsLabel
do
	local r = row(42)
	button(r, "STATS", PURPLE, 0, 0.34, function()
		local res = send("Stats", {target = who.value()})
		if res and res.ok and type(res.stats) == "table" then
			local lines = {}
			for _, kv in ipairs(res.stats) do table.insert(lines, tostring(kv[1]) .. ": " .. tostring(kv[2])) end
			statsLabel.Text = table.concat(lines, "   |   ")
		end
	end)
	button(r, "GO TO", BLUE, 0.34, 0.33, function() send("Goto", {target = who.value()}) end)
	button(r, "BRING", BLUE, 0.67, 0.33, function() send("Bring", {target = who.value()}) end)
	statsLabel = textLine(70, "Pick a player and press STATS.")
end
for _, kind in ipairs({{"MONEY", "Cash", GREEN, "Cash (e.g. 1.5M, 2B)"}, {"SPEED", "Speed", GOLD, "Speed (e.g. 50K, 1T)"}}) do
	section(kind[1], kind[3])
	local r = row(42)
	local box = input(r, kind[4], 0, 0.5)
	local function go(mode)
		local amount = parseNum(box.Text)
		if not amount then return fail("Type a number first.") end
		send(kind[2], {target = who.value(), amount = amount, mode = mode})
	end
	button(r, "SET", BLUE, 0.5, 0.25, function() go("set") end)
	button(r, "ADD", GREEN, 0.75, 0.25, function() go("add") end)
end
section("KICK / BAN", RED)
do
	local r = row(42)
	local reason = input(r, "Reason (optional)", 0, 1)
	local r2 = row(44)
	button(r2, "KICK", ORANGE, 0, 0.5, function() send("Kick", {target = who.value(), reason = reason.Text}) end)
	button(r2, "BAN", RED, 0.5, 0.5, function() send("Ban", {target = who.value(), reason = reason.Text}) end)
	local r3 = row(42)
	local name = input(r3, "Username to ban / unban", 0, 0.5)
	button(r3, "BAN", RED, 0.5, 0.25, function() send("Ban", {name = name.Text, reason = reason.Text}) end)
	button(r3, "UNBAN", GREEN, 0.75, 0.25, function() send("Unban", {name = name.Text}) end)
end
section("LEADERBOARDS", ORANGE)
do
	local r = row(42)
	local name = input(r, "Username (empty = picked player)", 0, 1)
	local r2 = row(44)
	local function args()
		local n = (name.Text or ""):gsub("%s", "")
		return {name = n, target = (n == "") and who.value() or nil}
	end
	button(r2, "REMOVE FROM BOARDS", RED, 0, 0.6, function() send("LbRemove", args()) end)
	button(r2, "PUT BACK", GREEN, 0.6, 0.4, function() send("LbRestore", args()) end)
end

------------------------------------------------------------------
-- TAB 2: BOXES
------------------------------------------------------------------
tab("Boxes", 2)
section("SPAWN BOXES", PURPLE)
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
local size = picker("Size", function()
	local list = {{"Random", "Random"}}
	for _, s in ipairs(Config.Sizes) do table.insert(list, {s.id, s.id}) end
	return list
end)
do
	local r = row(42)
	new("TextLabel", {Size = UDim2.new(0.3, 0, 1, 0), BackgroundTransparency = 1, Text = "How many", TextColor3 = WHITE, FontFace = FONT,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, r)
	local count = input(r, "1-50", 0.3, 0.7)
	count.Text = "10"
	local function args(where)
		return {area = area.value(), rarity = kind.value(), mutation = mutation.value(), size = size.value(), where = where,
			count = math.clamp(math.floor(tonumber(count.Text) or 10), 1, 50)}
	end
	local r2 = row(46)
	button(r2, "SPAWN AROUND ME", GREEN, 0, 0.5, function() send("Boxes", args("me")) end)
	button(r2, "FILL WAREHOUSE", BLUE, 0.5, 0.5, function() send("Boxes", args("everywhere")) end)
	local r3 = row(42)
	button(r3, "REMOVE MY SPAWNED BOXES", RED, 0, 1, function() send("ClearBoxes", {}) end)
end

------------------------------------------------------------------
-- TAB 3: SERVER - announcements, events, server luck
------------------------------------------------------------------
tab("Server", 3)
section("ANNOUNCEMENT", RED)
do
	local r = row(70)
	local msg = input(r, "Type your announcement (max 200)", 0, 1)
	msg.TextWrapped = true
	msg.MultiLine = true
	local r2 = row(46)
	local function go(global)
		if (msg.Text or ""):gsub("%s", "") == "" then return fail("Type a message first.") end
		local res = send("Announce", {text = msg.Text, global = global})
		if res and res.ok then msg.Text = "" end
	end
	button(r2, "THIS SERVER", BLUE, 0, 0.5, function() go(false) end)
	button(r2, "ALL SERVERS", RED, 0.5, 0.5, function() go(true) end)
end
section("EVENTS", GOLD)
do
	local event = picker("Event", function()
		local list = {}
		for _, e in ipairs(Config.Events) do table.insert(list, {e.name, e.id}) end
		return list
	end)
	local r = row(46)
	button(r, "START EVENT", GREEN, 0, 0.5, function() send("Event", {id = event.value()}) end)
	button(r, "SERVER LUCK", PURPLE, 0.5, 0.5, function() send("Luck", {}) end)
end

------------------------------------------------------------------
-- TAB 4: ADMINS (only the owner can give / remove admin)
------------------------------------------------------------------
local _, adminsTab = tab("Admins", 4)
adminsTab.Visible = false
local function buildOwnerPart(info)
	adminsTab.Visible = true
	section("GIVE ADMIN (owner only)", RED)
	local r = row(42)
	local name = input(r, "Roblox username", 0, 1)
	local r2 = row(44)
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
	listL = textLine(70, "")
	showList(info.admins)
end
showTab("Players")
task.spawn(function()
	local ok, info = pcall(function() return remote:InvokeServer("Info", {}) end)
	if ok and type(info) == "table" and info.owner then
		page, order = pages.Admins, 0
		buildOwnerPart(info)
	end
end)
