--[[ STEAL A BOX - the windows you open from the menu
     Items, Index, Trails, Gifts, Daily, Codes, Settings, Welcome Back.
     Every card has fixed slots for its texts (and text shrinks to fit), so nothing overlaps. ]]

local RunService = game:GetService("RunService")

local Windows = {}

------------------------------------------------------------------
-- QUESTS: 3 new quests every day (same for everybody). Finish one, claim its cash.
------------------------------------------------------------------
local function parseQuests(str)
	local list = {}
	for part in string.gmatch(str or "", "[^;]+") do
		local id, goal, progress, claimed = string.match(part, "^([^:]+):([^:]+):([^:]+):([^:]+)$")
		if id then
			table.insert(list, {id = id, goal = tonumber(goal) or 1, progress = tonumber(progress) or 0, claimed = claimed == "1"})
		end
	end
	return list
end

local function buildQuests(ctx)
	local UI, Config = ctx.UI, ctx.Config
	local C, fmt = UI.C, Config.FormatNum
	local win = UI.window({Name = "Quests", Title = "Daily Quests", Icon = "check", Color = UI.rgb(255, 150, 30), Size = Vector2.new(640, 470)})
	local page = win.page
	local cards = {}
	for slot = 1, 3 do
		local card = UI.card(page, UI.rgb(52, 46, 82), {Size = UDim2.new(1, -10, 0, 104), LayoutOrder = slot})
		local text = UI.label(card, "", {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -220, 0, 32), Max = 24, Stroke = 2.4,
			TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local bar = UI.bar(card, {Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -220, 0, 26)}, UI.rgb(255, 150, 30))
		local reward = UI.label(card, "", {Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -220, 0, 22), Max = 18, Stroke = 2,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.money, TextWrapped = false})
		local claim = UI.button(card, {Text = "Claim", Color = C.green, Size = UDim2.fromOffset(180, 56), AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0), TextSize = 26})
		claim.Activated:Connect(function()
			local r = ctx.invoke("ClaimQuest", slot)
			if r.msg and r.msg ~= "" then ctx.notify(r.msg, r.ok and C.green or C.red) end
			if r.ok and ctx.confetti then ctx.confetti(40) end
		end)
		cards[slot] = {text = text, bar = bar, reward = reward, claim = claim}
	end
	local resetL = UI.label(page, "", {Size = UDim2.new(1, -10, 0, 30), LayoutOrder = 9, Max = 20, Stroke = 2, TextColor3 = C.sub})
	local function refresh()
		local list = parseQuests(ctx.player:GetAttribute("Quests"))
		local income = ctx.player:GetAttribute("Income") or 0
		for slot, c in ipairs(cards) do
			local q = list[slot]
			if q then
				UI.setText(c.text, Config.QuestText(q.id, q.goal))
				c.bar.set(q.progress / math.max(1, q.goal), fmt(q.progress) .. " / " .. fmt(q.goal))
				UI.setText(c.reward, "Reward: $" .. fmt(Config.QuestReward(slot, income)))
				if q.claimed then
					c.claim.setText("Done!")
					c.claim.setEnabled(false)
				else
					c.claim.setText("Claim")
					c.claim.setEnabled(q.progress >= q.goal)
				end
			else
				UI.setText(c.text, "Loading...")
			end
		end
		local leftS = 86400 - (os.time() % 86400)
		local found = 0
		for _ in pairs(ctx.data and ctx.data.Achievements or {}) do found = found + 1 end
		UI.setText(resetL, "New quests in " .. Config.FormatTime(leftS) .. "   |   Secret achievements: " .. found .. " / " .. #Config.Achievements)
	end
	win.onOpen = refresh
	ctx.player:GetAttributeChangedSignal("Quests"):Connect(function() if UI.isOpen("Quests") then refresh() end end)
	-- badge: quests ready to claim
	return function()
		local n = 0
		for _, q in ipairs(parseQuests(ctx.player:GetAttribute("Quests"))) do
			if not q.claimed and q.progress >= q.goal then n = n + 1 end
		end
		local qb = ctx.badges.Quests or ctx.badges.Shop -- (quests live in the shop now)
		if qb then qb.set(n) end
		if UI.isOpen("Quests") then refresh() end
	end
end

------------------------------------------------------------------
-- INDEX: every item you can find, area by area (black silhouettes until you find them)
------------------------------------------------------------------
local function buildIndex(ctx)
	local UI, Config = ctx.UI, ctx.Config
	local C, new, fmt = UI.C, UI.new, Config.FormatNum
	local win = UI.window({Name = "Index", Title = "Index", Icon = "book", Color = C.cyan})
	local page = win.page
	local head = UI.box(page, {Size = UDim2.new(1, -10, 0, 96), LayoutOrder = 0})
	local title = UI.label(head, "", {Size = UDim2.new(1, 0, 0, 30), Max = 26, Stroke = 2.4, TextColor3 = C.yellow, TextWrapped = false})
	local bar = UI.bar(head, {Position = UDim2.new(0.15, 0, 0, 36), Size = UDim2.new(0.7, 0, 0, 26)}, C.cyan)
	local bonusL = UI.label(head, "", {Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 24), Max = 20, Stroke = 2, TextColor3 = C.money, TextWrapped = false})
	local items, boxes, views, rewards = {}, {}, {}, {}
	for areaIndex, area in ipairs(Config.Areas) do
		UI.section(page, areaIndex .. ". " .. string.upper(area.name), area.accent, areaIndex * 4)
		-- the area's completion reward: find all 4 items, then claim it once
		local rw = new("Frame", {Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = area.accent:Lerp(UI.rgb(30, 26, 50), 0.35), LayoutOrder = areaIndex * 4 + 1}, page)
		UI.corner(rw, 16)
		UI.stroke(rw, 3, area.accent)
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(C.white, UI.rgb(190, 190, 200))}, rw)
		UI.icon("gift", rw, UDim2.fromOffset(46, 46), UDim2.new(0, 10, 0.5, 0), area.accent:Lerp(C.white, 0.2), Vector2.new(0, 0.5))
		local rwTitle = UI.label(rw, "", {Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -270, 0, 28), Max = 22, Stroke = 2.2,
			TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local bat = Config.MineForArea and Config.MineForArea(areaIndex)
		UI.label(rw, "+$" .. fmt(Config.IndexCash(areaIndex)) .. "  and  +" .. math.floor(Config.IndexReward.cashBonus * 100 + 0.5) .. "% cash forever" .. (bat and ("  +  " .. bat.name .. "!") or ""),
			{Position = UDim2.fromOffset(66, 34), Size = UDim2.new(1, -270, 0, 22), Max = 18, Stroke = 1.8, TextColor3 = C.money, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local claim = UI.button(rw, {Text = "CLAIM!", Color = C.green, Size = UDim2.fromOffset(180, 50), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			TextSize = 24, Icon = "gift", IconSize = 28, Depth = 4})
		claim.Activated:Connect(function()
			local r = ctx.invoke("ClaimIndex", areaIndex)
			if r.msg and r.msg ~= "" then ctx.notify(r.msg, r.ok and area.accent or C.red) end
			if r.ok then
				if ctx.confetti then ctx.confetti() end
				if ctx.thanks then ctx.thanks("INDEX COMPLETE!") end
			end
		end)
		rewards[areaIndex] = {title = rwTitle, claim = claim, frame = rw}
		-- the 3 boxes of this area
		local boxRow = UI.box(page, {Size = UDim2.new(1, -10, 0, 52), LayoutOrder = areaIndex * 4 + 2})
		UI.list(boxRow, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		for r, def in ipairs(area.boxes) do
			local rar = Config.Rarities[r]
			local chip = new("Frame", {Size = UDim2.fromOffset(212, 50), BackgroundColor3 = UI.rgb(40, 36, 64), LayoutOrder = r}, boxRow)
			UI.corner(chip, 12)
			UI.stroke(chip, 2.5, rar.color)
			UI.icon("box", chip, UDim2.fromOffset(36, 36), UDim2.new(0, 7, 0.5, 0), def.color, Vector2.new(0, 0.5))
			UI.label(chip, def.name, {Position = UDim2.fromOffset(50, 5), Size = UDim2.new(1, -58, 0, 22), Max = 17, Stroke = 1.8, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
			local cnt = UI.label(chip, "", {Position = UDim2.fromOffset(50, 27), Size = UDim2.new(1, -58, 0, 16), Max = 14, Stroke = 1.4, TextColor3 = rar.color,
				TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
			boxes[def.id] = {chip = chip, count = cnt, def = def, rar = rar}
		end
		-- the 4 items you can get, with the chance for a common / rare / epic box
		local grid = UI.grid(page, UDim2.fromOffset(160, 176), 12, areaIndex * 4 + 3)
		for tier, it in ipairs(Config.AreaItems[areaIndex]) do
			local tierDef = Config.ItemTiers[tier]
			local card = UI.card(grid, UI.rgb(46, 42, 72), {LayoutOrder = tier})
			local vpBack = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7), Size = UDim2.fromOffset(110, 78),
				BackgroundColor3 = UI.rgb(14, 12, 24), BackgroundTransparency = 0.45}, card)
			UI.corner(vpBack, 12)
			local vp, list = UI.itemView(vpBack, {id = it[1], mutation = "Normal", size = "Normal"}, {Size = UDim2.fromScale(1, 1)})
			table.insert(views, list)
			local name = UI.label(card, "", {Position = UDim2.fromOffset(6, 88), Size = UDim2.new(1, -12, 0, 24), Max = 18, Stroke = 1.8, TextWrapped = false})
			UI.label(card, tierDef.name, {Position = UDim2.fromOffset(6, 112), Size = UDim2.new(1, -12, 0, 17), Max = 15, Stroke = 1.5, TextColor3 = tierDef.color, TextWrapped = false})
			UI.label(card, "Box chance: " .. tierDef.weights[1] .. "% / " .. tierDef.weights[2] .. "% / " .. tierDef.weights[3] .. "%",
				{Position = UDim2.fromOffset(6, 131), Size = UDim2.new(1, -12, 0, 15), Max = 12, Stroke = 1.2, TextColor3 = C.sub, TextWrapped = false})
			local found = UI.label(card, "", {Position = UDim2.fromOffset(6, 149), Size = UDim2.new(1, -12, 0, 18), Max = 15, Stroke = 1.5, TextWrapped = false})
			items[it[1]] = {vp = vp, name = name, found = found, def = Config.Items[it[1]]}
		end
	end
	UI.label(page, "Box chance = common / rare / epic box from that area", {Size = UDim2.new(1, -10, 0, 22), LayoutOrder = 999, Max = 15, Stroke = 1.4, TextColor3 = C.muted})
	win.onOpen = function()
		local data = ctx.data
		if not data then return end
		for _, b in pairs(boxes) do
			local n = data.Boxes and data.Boxes[b.def.id] or 0
			UI.setText(b.count, (n > 0) and (b.rar.name .. "  |  stolen x" .. fmt(n)) or (b.rar.name .. "  |  not stolen yet"))
			b.chip.BackgroundColor3 = (n > 0) and b.def.color:Lerp(UI.rgb(30, 26, 50), 0.55) or UI.rgb(40, 36, 64)
		end
		local foundN, total = 0, 0
		for id, c in pairs(items) do
			total = total + 1
			local n = data.ItemsFound and data.ItemsFound[id] or 0
			if n > 0 then
				foundN = foundN + 1
				UI.setText(c.name, c.def.name)
				c.name.TextColor3 = C.white
				c.vp.ImageColor3 = C.white
				UI.setText(c.found, "Found x" .. fmt(n))
				c.found.TextColor3 = C.money
			else
				UI.setText(c.name, "???")
				c.name.TextColor3 = C.muted
				c.vp.ImageColor3 = C.black -- a black silhouette until you find it
				UI.setText(c.found, "Not found yet")
				c.found.TextColor3 = C.muted
			end
		end
		UI.setText(title, "Items discovered: " .. foundN .. " / " .. total)
		bar.set(foundN / math.max(1, total), math.floor(foundN / math.max(1, total) * 100) .. "%")
		local claimed = data.IndexClaimed or {}
		local nClaimed = Config.CountClaimed(claimed)
		UI.setText(bonusL, "Areas completed: " .. nClaimed .. " / " .. #Config.Areas .. "   |   cash x" .. Config.IndexCashMult(nClaimed))
		for areaIndex, rw in pairs(rewards) do
			local have = 0
			for _, it in ipairs(Config.AreaItems[areaIndex]) do
				if data.ItemsFound and (data.ItemsFound[it[1]] or 0) > 0 then have = have + 1 end
			end
			local need = #Config.AreaItems[areaIndex]
			if claimed[tostring(areaIndex)] then
				UI.setText(rw.title, "COMPLETED!")
				rw.claim.setText("CLAIMED")
				rw.claim.setColor(C.grey)
				rw.claim.setEnabled(false)
			elseif have >= need then
				UI.setText(rw.title, "AREA COMPLETE! Claim it:")
				rw.claim.setText("CLAIM!")
				rw.claim.setColor(C.green)
				rw.claim.setEnabled(true)
			else
				UI.setText(rw.title, "Find all items: " .. have .. " / " .. need)
				rw.claim.setText(have .. " / " .. need)
				rw.claim.setColor(C.grey)
				rw.claim.setEnabled(false)
			end
		end
	end
	ctx.onData(function() if UI.isOpen("Index") then win.onOpen() end end)
	RunService.RenderStepped:Connect(function()
		if not UI.isOpen("Index") then return end
		local cf = CFrame.Angles(0, os.clock() * 0.9, 0)
		for _, l in ipairs(views) do Config.PoseItemModel(l, cf, 1) end
	end)
end

------------------------------------------------------------------
-- TRAILS: glow behind you and MULTIPLY the speed your treadmill gives
------------------------------------------------------------------
local function buildTrails(ctx)
	local UI, Config, player = ctx.UI, ctx.Config, ctx.player
	local C, new, fmt = UI.C, UI.new, Config.FormatNum
	local TIER_NAMES = {"COMMON", "COMMON", "RARE", "RARE", "EPIC", "EPIC", "LEGENDARY", "MYTHIC"}
	local TIER_COLS = {UI.rgb(200, 200, 210), UI.rgb(200, 200, 210), UI.rgb(90, 170, 255), UI.rgb(90, 170, 255),
		UI.rgb(200, 110, 255), UI.rgb(200, 110, 255), UI.rgb(255, 190, 40), UI.rgb(255, 90, 160)}
	local win = UI.window({Name = "Trails", Title = "Trail Shop", Icon = "trail", Color = C.orange})
	local page = win.page
	UI.label(page, "Trails glow behind you and MULTIPLY the speed your treadmill gives you!", {Size = UDim2.new(1, -10, 0, 24), LayoutOrder = 0, Max = 18, Stroke = 1.6, TextColor3 = C.sub})
	local current = UI.label(page, "", {Size = UDim2.new(1, -10, 0, 26), LayoutOrder = 1, Max = 20, Stroke = 2, TextColor3 = C.yellow})
	local grid = UI.grid(page, UDim2.fromOffset(162, 218), 12, 2)
	local list = {}
	for _, t in ipairs(Config.Trails) do table.insert(list, t) end
	table.insert(list, Config.VIPTrail)
	local cards, flows = {}, {}
	for i, t in ipairs(list) do
		local tcol = t.vip and C.gold or (TIER_COLS[i] or C.white)
		local card = UI.card(grid, t.colors[1]:Lerp(UI.rgb(36, 32, 54), 0.6), {LayoutOrder = i})
		local stroke = card:FindFirstChildOfClass("UIStroke")
		-- rarity ribbon across the top
		local rib = new("Frame", {Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 22), BackgroundColor3 = tcol}, card)
		UI.corner(rib, true)
		UI.stroke(rib, 2)
		UI.label(rib, t.vip and "VIP ONLY" or TIER_NAMES[i], {Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), Max = 15, Stroke = 1.6, TextWrapped = false})
		-- the flowing preview: a glowing swoosh with an orb at its head
		local lane = new("Frame", {Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 0, 56), BackgroundColor3 = UI.rgb(16, 14, 26), BackgroundTransparency = 0.2,
			ClipsDescendants = true}, card)
		UI.corner(lane, 12)
		local swoosh = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0), Size = UDim2.new(1, -4, 0, 16), BackgroundColor3 = C.white}, lane)
		UI.corner(swoosh, true)
		local grad = new("UIGradient", {Color = Config.TrailColor(t), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.3),
			NumberSequenceKeypoint.new(1, 0)})}, swoosh)
		local orb = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = t.colors[#t.colors]}, lane)
		UI.corner(orb, true)
		UI.stroke(orb, 2, C.white, 0.25)
		table.insert(flows, {swoosh = swoosh, grad = grad, orb = orb, phase = i})
		UI.label(card, t.name, {Position = UDim2.fromOffset(6, 96), Size = UDim2.new(1, -12, 0, 24), Max = 19, Stroke = 1.8, TextColor3 = t.colors[1]:Lerp(C.white, 0.35), TextWrapped = false})
		local chip = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.fromOffset(126, 26), BackgroundColor3 = UI.rgb(20, 18, 30),
			BackgroundTransparency = 0.2}, card)
		UI.corner(chip, true)
		UI.icon("boot", chip, UDim2.fromOffset(22, 22), UDim2.new(0, 4, 0.5, 0), C.blue, Vector2.new(0, 0.5))
		UI.label(chip, "x" .. t.mult .. " speed", {Position = UDim2.fromOffset(30, 3), Size = UDim2.new(1, -36, 1, -6), Max = 17, Stroke = 1.6, TextColor3 = C.yellow, TextWrapped = false})
		local btn = UI.button(card, {Text = "", Color = C.green, Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 162), TextSize = 21})
		btn.Activated:Connect(function()
			if t.vip and not player:GetAttribute("Pass_VIP") then
				UI.open("Shop", "Passes")
				return
			end
			local r = ctx.invoke("BuyUpgrade", t.id)
			ctx.notify(r.msg or "", r.ok and C.green or C.red)
			if r.ok then
				UI.SFX.play("ding", 1.5, 0.5)
				local ps = card:FindFirstChild("PopScale") or new("UIScale", {Name = "PopScale"}, card)
				ps.Scale = 1.12
				UI.tween(ps, 0.6, {Scale = 1}, Enum.EasingStyle.Elastic)
			end
		end)
		cards[i] = {t = t, btn = btn, stroke = stroke, strokeColor = stroke and stroke.Color}
	end
	local function refresh()
		local data = ctx.data
		if not data then return end
		local cur = data.Trail and Config.GetTrail(data.Trail)
		UI.setText(current, cur and ("Wearing: " .. cur.name .. "  (treadmill x" .. cur.mult .. ")") or "You're not wearing a trail yet - buy one below!")
		for _, c in ipairs(cards) do
			local owned = (data.Trails and data.Trails[c.t.id]) or (c.t.vip and player:GetAttribute("Pass_VIP"))
			local equipped = data.Trail == c.t.id
			if c.stroke then
				c.stroke.Color = equipped and C.white or c.strokeColor
				c.stroke.Thickness = equipped and 4.5 or 2.5
			end
			if equipped then
				c.btn.setText("EQUIPPED")
				c.btn.setColor(C.blue)
			elseif owned then
				c.btn.setText("EQUIP")
				c.btn.setColor(C.green)
			elseif c.t.vip then
				c.btn.setText("Get VIP")
				c.btn.setColor(C.yellow)
			else
				c.btn.setText("$" .. fmt(c.t.price))
				c.btn.setColor((data.Cash >= c.t.price) and C.green or C.grey)
			end
		end
	end
	win.onOpen = refresh
	ctx.onData(function() if UI.isOpen("Trails") then refresh() end end)
	ctx.onCash(function() if UI.isOpen("Trails") then refresh() end end)
	RunService.RenderStepped:Connect(function()
		if not UI.isOpen("Trails") then return end
		local t = os.clock()
		for _, f in ipairs(flows) do
			f.grad.Offset = Vector2.new(math.sin(t * 2 + f.phase) * 0.15, 0)
			f.swoosh.Position = UDim2.new(0, -10, 0.5, math.sin(t * 3 + f.phase) * 7)
			f.swoosh.Rotation = math.cos(t * 3 + f.phase) * 6
			local sz = 20 + math.sin(t * 6 + f.phase) * 3
			f.orb.Position = UDim2.new(1, -18, 0.5, math.sin(t * 3 + f.phase + 0.3) * 8)
			f.orb.Size = UDim2.fromOffset(sz, sz)
		end
	end)
	-- press E at the trail shop counter in the world
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenTrailShop" and not UI.isOpen("Trails") then UI.open("Trails") end
	end)
end

------------------------------------------------------------------
-- GIFTS: free cash / boxes the longer you play
------------------------------------------------------------------
local function buildGifts(ctx)
	local UI, Config, player = ctx.UI, ctx.Config, ctx.player
	local C = UI.C
	local win = UI.window({Name = "Gifts", Title = "Free Gifts", Icon = "gift", Color = C.pink})
	local page = win.page
	UI.label(page, "Stay in the game to unlock gifts: random cash or free boxes!", {Size = UDim2.new(1, -10, 0, 24), LayoutOrder = 0, Max = 18, Stroke = 1.6, TextColor3 = C.sub})
	local grid = UI.grid(page, UDim2.fromOffset(132, 168), 12, 1)
	local function giftInfo()
		local start = player:GetAttribute("GiftStart")
		local claimed = {}
		for idx in string.gmatch(player:GetAttribute("GiftClaimed") or "", "%d+") do claimed[tonumber(idx)] = true end
		return start and (workspace:GetServerTimeNow() - start) or 0, claimed, start ~= nil
	end
	local cards = {}
	for i, g in ipairs(Config.Gifts) do
		local big = g.boxChance >= 1
		local card = UI.card(grid, big and UI.rgb(110, 50, 160) or UI.rgb(150, 50, 100), {LayoutOrder = i})
		local icon = UI.icon(big and "box" or "gift", card, UDim2.fromOffset(56, 56), UDim2.new(0.5, 0, 0, 8), big and UI.rgb(215, 160, 95) or UI.rgb(255, 120, 180), Vector2.new(0.5, 0))
		local iconScale = UI.new("UIScale", {}, icon)
		UI.label(card, g.minutes .. " min", {Position = UDim2.fromOffset(6, 68), Size = UDim2.new(1, -12, 0, 24), Max = 21, Stroke = 2, TextWrapped = false})
		UI.label(card, big and "Big box!" or "Cash or box", {Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 17), Max = 15, Stroke = 1.4, TextColor3 = UI.rgb(255, 235, 250), TextWrapped = false})
		local btn = UI.button(card, {Text = "", Color = C.green, Size = UDim2.new(1, -14, 0, 42), Position = UDim2.fromOffset(7, 116), TextSize = 19})
		btn.Activated:Connect(function()
			local r = ctx.invoke("ClaimGift", i)
			ctx.notify(r.msg or "", r.ok and C.yellow or C.red)
			if r.ok then
				UI.SFX.play("ding", 1.3, 0.5)
				iconScale.Scale = 1.5
				UI.tween(iconScale, 0.6, {Scale = 1}, Enum.EasingStyle.Elastic)
			end
		end)
		cards[i] = {btn = btn, icon = iconScale, gift = g}
	end
	local function draw()
		local played, claimed = giftInfo()
		for i, gc in ipairs(cards) do
			local left = gc.gift.minutes * 60 - played
			if claimed[i] then
				gc.btn.setText("Claimed")
				gc.btn.setEnabled(false)
				gc.icon.Scale = 0.85
			elseif left <= 0 then
				gc.btn.setText("CLAIM!")
				gc.btn.setEnabled(true)
				gc.btn.setColor(C.green)
				gc.icon.Scale = 1 + 0.08 * math.sin(os.clock() * 6) -- ready gifts wobble
			else
				gc.btn.setText(Config.FormatTime(left))
				gc.btn.setEnabled(false)
				gc.icon.Scale = 0.92
			end
		end
	end
	win.onOpen = draw
	-- badge + countdown
	return function()
		local played, claimed, known = giftInfo()
		local ready = 0
		if known then
			for i, g in ipairs(Config.Gifts) do
				if not claimed[i] and g.minutes * 60 - played <= 0 then ready = ready + 1 end
			end
		end
		if ctx.badges.Gifts then ctx.badges.Gifts.set(ready) end
		if UI.isOpen("Gifts") then draw() end
	end
end

------------------------------------------------------------------
-- DAILY REWARDS: a 7-day streak
------------------------------------------------------------------
local function buildDaily(ctx)
	local UI, Config = ctx.UI, ctx.Config
	local C, new, fmt = UI.C, UI.new, Config.FormatNum
	local win = UI.window({Name = "Daily", Title = "Daily Rewards", Icon = "calendar", Color = C.blue, Size = Vector2.new(780, 430)})
	local page = win.page
	local streakL = UI.label(page, "", {Size = UDim2.new(1, -10, 0, 30), LayoutOrder = 0, Max = 24, Stroke = 2.2, TextColor3 = C.yellow})
	local row = UI.box(page, {Size = UDim2.new(1, -10, 0, 150), LayoutOrder = 1})
	UI.list(row, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	local days = {}
	for d, reward in ipairs(Config.Daily) do
		local card = UI.card(row, UI.rgb(46, 42, 72), {Size = UDim2.fromOffset(96, 144), LayoutOrder = d})
		local stroke = card:FindFirstChildOfClass("UIStroke")
		UI.label(card, "Day " .. d, {Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 22), Max = 19, Stroke = 1.8, TextWrapped = false})
		local iconName = (reward.kind == "cash") and "cash" or ((reward.kind == "luckybox") and "star" or "box")
		local iconCol = (reward.kind == "cash") and C.green or ((reward.kind == "luckybox") and UI.rgb(255, 120, 220) or UI.rgb(215, 160, 95))
		UI.icon(iconName, card, UDim2.fromOffset(50, 50), UDim2.new(0.5, 0, 0, 32), iconCol, Vector2.new(0.5, 0))
		local what = UI.label(card, "", {Position = UDim2.fromOffset(4, 86), Size = UDim2.new(1, -8, 0, 32), Max = 14, Stroke = 1.4, TextColor3 = C.sub})
		local check = UI.icon("check", card, UDim2.fromOffset(34, 34), UDim2.new(0.5, 0, 1, -6), C.money, Vector2.new(0.5, 1))
		check.Visible = false
		days[d] = {card = card, stroke = stroke, what = what, check = check, reward = reward}
	end
	local claim = UI.button(page, {Text = "CLAIM", Color = C.green, Size = UDim2.fromOffset(260, 56), LayoutOrder = 2, TextSize = 28, Icon = "gift", IconSize = 34})
	local nextL = UI.label(page, "", {Size = UDim2.new(1, -10, 0, 24), LayoutOrder = 3, Max = 18, Stroke = 1.6, TextColor3 = C.sub})
	UI.label(page, "Come back every day! Miss a day and your streak starts over.", {Size = UDim2.new(1, -10, 0, 22), LayoutOrder = 4, Max = 16, Stroke = 1.4, TextColor3 = C.muted})
	local function state()
		local data = ctx.data
		local d = data and data.Daily or {Streak = 0, Last = -1}
		local today = Config.DayNumber(workspace:GetServerTimeNow())
		local canClaim = d.Last ~= today
		local streak = d.Streak or 0
		local nextStreak = (d.Last == today) and streak or ((d.Last == today - 1) and streak + 1 or 1)
		return canClaim, nextStreak, streak, d.Last == today - 1 or d.Last == today
	end
	local function refresh()
		local canClaim, nextStreak, streak, alive = state()
		local income = ctx.player:GetAttribute("Income") or 0
		local current = ((nextStreak - 1) % #Config.Daily) + 1
		local doneUpTo = canClaim and (current - 1) or current
		for d, e in ipairs(days) do
			local r = e.reward
			UI.setText(e.what, (r.kind == "cash") and ("$" .. fmt(Config.DailyCash(r, income))) or ((r.kind == "luckybox") and "RAINBOW box!" or "Free box"))
			e.check.Visible = d <= doneUpTo
			local isToday = d == current
			e.stroke.Color = (isToday and canClaim) and C.yellow or C.ink
			e.stroke.Thickness = (isToday and canClaim) and 4.5 or 2.5
			e.card.BackgroundColor3 = (d <= doneUpTo) and UI.rgb(40, 90, 55) or ((isToday and canClaim) and UI.rgb(90, 76, 30) or UI.rgb(46, 42, 72))
		end
		UI.setText(streakL, (alive and streak > 0) and ("Streak: " .. streak .. " day" .. (streak == 1 and "" or "s") .. "!") or "Start your streak today!")
		claim.setEnabled(canClaim)
		claim.setText(canClaim and ("CLAIM DAY " .. current) or "Claimed!")
		local tomorrow = (Config.DayNumber(workspace:GetServerTimeNow()) + 1) * 86400
		UI.setText(nextL, canClaim and "Your reward is ready!" or ("Next reward in " .. Config.FormatTime(tomorrow - workspace:GetServerTimeNow())))
	end
	claim.Activated:Connect(function()
		local r = ctx.invoke("ClaimDaily")
		ctx.notify(r.msg or "", r.ok and C.yellow or C.red)
		if r.ok then
			UI.SFX.play("ding", 1.4, 0.6)
			if ctx.confetti then ctx.confetti(50, {C.yellow, C.white, C.blue, C.green}) end
		end
	end)
	win.onOpen = refresh
	ctx.onData(function() if UI.isOpen("Daily") then refresh() end end)
	-- badge + open it by itself once per session when there's a reward waiting
	-- (waits until no other window is open, e.g. "Welcome back")
	local autoOpened = false
	local startedAt = os.clock()
	return function()
		local canClaim = state()
		if ctx.badges.Daily then ctx.badges.Daily.set(canClaim and ctx.data ~= nil) end
		if UI.isOpen("Daily") then refresh() end
		if canClaim and ctx.data and ctx.data.TutorialDone and not autoOpened and not UI.isOpen() and os.clock() - startedAt > 6 then
			autoOpened = true
			UI.open("Daily")
		end
	end
end

------------------------------------------------------------------
-- CODES
------------------------------------------------------------------
local function buildCodes(ctx)
	local UI = ctx.UI
	local C, new = UI.C, UI.new
	local win = UI.window({Name = "Codes", Title = "Codes", Icon = "ticket", Color = C.red, Size = Vector2.new(560, 360)})
	local page = win.page
	UI.label(page, "Got a code? Type it in for free rewards!", {Size = UDim2.new(1, -10, 0, 26), LayoutOrder = 0, Max = 20, Stroke = 1.8, TextColor3 = C.sub})
	local boxF = new("Frame", {Size = UDim2.fromOffset(420, 58), BackgroundColor3 = UI.rgb(16, 14, 26), LayoutOrder = 1}, page)
	UI.corner(boxF, 14)
	UI.stroke(boxF, 3, C.white, 0.2)
	local input = new("TextBox", {Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), BackgroundTransparency = 1, FontFace = UI.Font, TextSize = 26,
		Text = "", PlaceholderText = "Enter code...", PlaceholderColor3 = C.muted, TextColor3 = C.white, ClearTextOnFocus = false}, boxF)
	local redeem = UI.button(page, {Text = "REDEEM", Color = C.green, Size = UDim2.fromOffset(220, 54), LayoutOrder = 2, TextSize = 26, Icon = "check", IconSize = 30, IconColor = C.white})
	local result = UI.label(page, "", {Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 3, Max = 19, Stroke = 1.8})
	local function go()
		local r = ctx.invoke("RedeemCode", input.Text)
		UI.setText(result, r.msg or "")
		result.TextColor3 = r.ok and C.money or C.red
		if r.ok then
			input.Text = ""
			UI.SFX.play("ding", 1.5, 0.6)
			if ctx.confetti then ctx.confetti(40, {C.yellow, C.white, C.green}) end
		else
			UI.SFX.play("error")
		end
	end
	redeem.Activated:Connect(go)
	input.FocusLost:Connect(function(enter) if enter then go() end end)
	win.onOpen = function() UI.setText(result, "") end
end

------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------
local function buildSettings(ctx)
	local UI = ctx.UI
	local C, new = UI.C, UI.new
	local win = UI.window({Name = "Settings", Title = "Settings", Icon = "gear", Color = C.grey, Size = Vector2.new(600, 476)})
	local page = win.page
	local rows = {
		{key = "Music", title = "Music", desc = "Background music"},
		{key = "Sfx", title = "Sound effects", desc = "Whooshes and pops"},
		{key = "Effects", title = "Screen effects", desc = "Camera shake, cinematic unboxing camera, confetti"},
		{key = "ShelfTags", title = "Product labels", desc = "Name + $/s over the product you stand closest to"},
		{key = "SlowMode", title = "Slow mode", desc = "Walk at normal speed (handy on your treadmill)", session = true},
	}
	for i, r in ipairs(rows) do
		local row = UI.card(page, UI.rgb(46, 42, 72), {Size = UDim2.new(1, -10, 0, 70), LayoutOrder = i})
		UI.label(row, r.title, {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -120, 0, 28), Max = 22, Stroke = 2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		UI.label(row, r.desc, {Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -120, 0, 22), Max = 15, Stroke = 1.4, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local sw = UI.switch(row, ctx.settings[r.key] ~= false and not r.session, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0)})
		if r.session then sw.set(false, true) end
		sw.Changed:Connect(function(on)
			if r.key == "SlowMode" then
				ctx.invoke("SlowMode", on)
				if ctx.hud and ctx.hud.setSlowToggle then ctx.hud.setSlowToggle(on) end
			else
				ctx.setSetting(r.key, on)
			end
		end)
		ctx.settingSwitches = ctx.settingSwitches or {}
		ctx.settingSwitches[r.key] = sw
	end
	local tut = UI.button(page, {Text = "Show the tutorial again", Color = C.blue, Size = UDim2.fromOffset(300, 48), LayoutOrder = 10, TextSize = 20})
	tut.Activated:Connect(function()
		UI.close()
		if ctx.restartTutorial then ctx.restartTutorial() end
	end)
end

------------------------------------------------------------------
-- WELCOME BACK: what your shop earned while you were away
------------------------------------------------------------------
local function buildWelcome(ctx)
	local UI, Config, player = ctx.UI, ctx.Config, ctx.player
	local C = UI.C
	local win = UI.window({Name = "Welcome", Title = "Welcome back!", Icon = "coin", Color = C.yellow, Size = Vector2.new(520, 330)})
	local page = win.page
	UI.label(page, "While you were away, your shop kept selling:", {Size = UDim2.new(1, -10, 0, 26), LayoutOrder = 0, Max = 19, Stroke = 1.8, TextColor3 = C.sub})
	local amount = UI.label(page, "", {Size = UDim2.new(1, -10, 0, 64), LayoutOrder = 1, Max = 58, Stroke = 3.4, TextColor3 = C.money, TextWrapped = false})
	local away = UI.label(page, "", {Size = UDim2.new(1, -10, 0, 22), LayoutOrder = 2, Max = 17, Stroke = 1.6, TextColor3 = C.muted})
	local ok = UI.button(page, {Text = "COLLECT!", Color = C.green, Size = UDim2.fromOffset(240, 56), LayoutOrder = 3, TextSize = 28, Icon = "cash", IconSize = 34})
	ok.Activated:Connect(function()
		UI.close()
		if ctx.confetti then ctx.confetti(60, {C.money, C.yellow, C.white}) end
	end)
	local shown = false
	local function check()
		local earned = player:GetAttribute("OfflineEarned")
		if shown or not earned or earned <= 0 then return end
		shown = true
		UI.setText(amount, "+$" .. Config.FormatNum(earned))
		local secs = player:GetAttribute("OfflineAway") or 0
		UI.setText(away, "(" .. Config.FormatTime(secs) .. " away - up to " .. Config.Offline.maxHours .. " hours count)")
		task.delay(2.5, function() UI.open("Welcome") end)
	end
	player:GetAttributeChangedSignal("OfflineEarned"):Connect(check)
	check()
end

function Windows.init(ctx)
	local questsTick = buildQuests(ctx)
	buildIndex(ctx)
	buildTrails(ctx)
	local giftsTick = buildGifts(ctx)
	local dailyTick = buildDaily(ctx)
	buildCodes(ctx)
	buildSettings(ctx)
	buildWelcome(ctx)
	-- badges that depend on time (called a few times a second by the HUD)
	ctx.updateClockBadges = function()
		giftsTick()
		dailyTick()
		questsTick()
	end
	-- badges that depend on your data
	local function dataBadges()
		local data = ctx.data
		if not data then return end
		local onShelf, inBag = 0, 0
		for _, it in ipairs(data.Items or {}) do
			if it.stand then onShelf = onShelf + 1 else inBag = inBag + 1 end
		end
		local stands = ctx.player:GetAttribute("Stands") or ctx.Config.BaseStands
		if ctx.badges.Items then ctx.badges.Items.set((inBag > 0 and onShelf < stands) and math.min(inBag, stands - onShelf) or 0) end
		local canBuy = false
		for _, t in ipairs(ctx.Config.Trails) do
			if not (data.Trails and data.Trails[t.id]) and (data.Cash or 0) >= t.price then canBuy = true end
		end
		if ctx.badges.Trails then ctx.badges.Trails.set(canBuy) end
		-- Index: a reward is waiting to be claimed
		local claimable = 0
		for areaIndex in ipairs(ctx.Config.Areas) do
			if not (data.IndexClaimed and data.IndexClaimed[tostring(areaIndex)]) and ctx.Config.AreaComplete(data.ItemsFound, areaIndex) then
				claimable = claimable + 1
			end
		end
		ctx.badges.Index.set(claimable)
	end
	ctx.onData(dataBadges)
	ctx.onCash(dataBadges)
end

return Windows
