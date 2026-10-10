--[[ STEAL A BOX - the Robux Shop window
     Tabs: Passes (bought once) | Cash (packs that grow with your income) | Boosts | Speed.
     Prices come from Roblox itself (so they're always right); until they load, the shop shows
     the `robux` number from ReplicatedStorage > StealABoxShop. Items with ID 0 say "SOON"
     in real servers and are free to test in Studio. ]]

local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local ShopWindow = {}

function ShopWindow.init(ctx)
	local UI, Config, Shop, player = ctx.UI, ctx.Config, ctx.Shop, ctx.player
	local C, new, fmt = UI.C, UI.new, Config.FormatNum
	local IS_STUDIO = RunService:IsStudio()
	-- a yellow studded header with the red basket poking out of its corner (like the inspiration)
	local win = UI.window({Name = "Shop", Title = "Shop", Icon = "shop", Color = UI.rgb(255, 200, 30), Size = Vector2.new(900, 520),
		Tabs = {{Key = "Passes", Label = "Passes", Icon = "crown"}, {Key = "Cash", Label = "Cash", Icon = "cash"},
			{Key = "Boosts", Label = "Boosts", Icon = "clover"}, {Key = "Speed", Label = "Speed", Icon = "bolt"},
			{Key = "Quests", Label = "Quests", Icon = "check"}, {Key = "Codes", Label = "Codes", Icon = "ticket"}, {Key = "Settings", Label = "Settings", Icon = "gear"}}})
	-- Quests, Codes and Settings live in the shop now: their tabs open those windows
	local LINKS = {Quests = true, Codes = true, Settings = true}
	win.onTab = function(key)
		if LINKS[key] then task.defer(function() UI.open(key) end) end
	end
	local refreshers = {}

	-- the price button of a card: "Buy (robux) 99", "OWNED" or "SOON" (a yellow-orange pill like the inspiration)
	local BUY_COLOR = UI.rgb(255, 190, 40)
	local function priceButton(parent, key, id, fallback, onBuy, pos, size, textSize)
		local b = UI.buyButton(parent, {Color = BUY_COLOR, Size = size or UDim2.fromOffset(196, 54), AnchorPoint = Vector2.new(0.5, 1),
			Position = pos or UDim2.new(0.5, 0, 1, -10), TextSize = textSize or 30, ZIndex = 4, Depth = 5})
		b.Activated:Connect(function()
			if not b.enabled then return end
			onBuy()
		end)
		local function draw(owned)
			if owned then
				b.setText("OWNED")
				b.setEnabled(false)
			elseif (id or 0) == 0 and not IS_STUDIO then
				b.setText("SOON")
				b.setEnabled(false)
			else
				b.setPrice(fmt(ctx.price(key, fallback)))
				b.setEnabled(true)
				b.setColor(BUY_COLOR)
			end
		end
		return b, draw
	end

	local function buy(action, key)
		local r = ctx.invoke(action, key)
		if r.msg and r.msg ~= "" then ctx.notify(r.msg, r.ok and C.yellow or C.red) end
	end

	-- the rays behind every big icon turn slowly while the shop is open
	local bursts = {}
	-- a card like the inspiration: one bright colour with faint studs, a big white title at the top,
	-- a big icon on white light rays in the middle, a short description and the Buy pill at the bottom
	local function card(parent, color, order, w, h, title, iconName, iconSize, iconY)
		-- (clipped: the rays stay inside the card)
		local c = UI.studCard(parent, color, {LayoutOrder = order, Size = UDim2.fromOffset(w, h), ClipsDescendants = true}, Vector2.new(w, h))
		table.insert(bursts, UI.sunburst(c, UDim2.fromOffset(w * 0.92, w * 0.92), UDim2.new(0.5, 0, 0, iconY), {ZIndex = 2, Transparency = 0.35}))
		local ic = UI.icon(iconName, c, UDim2.fromOffset(iconSize, iconSize), UDim2.new(0.5, 0, 0, iconY), color:Lerp(C.white, 0.25), Vector2.new(0.5, 0.5))
		ic.ZIndex = 3
		local t = UI.label(c, title, {Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 50), Max = 42, Min = 16, Stroke = 3.6, TextWrapped = false, ZIndex = 4})
		return c, t, ic
	end
	-- the white title over each page (like "Gamepasses" in the inspiration) + a small line under it
	local function pageTitle(page, text, sub)
		UI.label(page, text, {Size = UDim2.new(1, -10, 0, 40), LayoutOrder = -2, Max = 34, Stroke = 3.4, TextWrapped = false})
		if sub then
			UI.label(page, sub, {Size = UDim2.new(1, -10, 0, 22), LayoutOrder = -1, Max = 17, Stroke = 1.8, TextColor3 = UI.rgb(225, 225, 235)})
		end
	end
	-- 3 big cards per row (the page is ~860 wide)
	local BIG_W, SMALL_W = 272, 204

	------------------------------------------------------------------
	-- PASSES (Gamepasses)
	------------------------------------------------------------------
	do
		local page = win.pages.Passes
		pageTitle(page, "Gamepasses")
		local H = 284
		local grid = UI.grid(page, UDim2.fromOffset(BIG_W, H), 12, 1)
		for i, pass in ipairs(Shop.Passes) do
			local c = card(grid, pass.color, i, BIG_W, H, pass.name, pass.icon, 126, 118)
			UI.label(c, pass.desc, {Position = UDim2.fromOffset(10, 176), Size = UDim2.new(1, -20, 0, 40), Max = 17, Min = 10, Stroke = 2.2, ZIndex = 4})
			local _, draw = priceButton(c, "Pass_" .. pass.key, pass.id, pass.robux, function() buy("BuyPass", pass.key) end)
			table.insert(refreshers, function() draw(player:GetAttribute("Pass_" .. pass.key) == true) end)
			player:GetAttributeChangedSignal("Pass_" .. pass.key):Connect(function() draw(player:GetAttribute("Pass_" .. pass.key) == true) end)
		end
	end

	------------------------------------------------------------------
	-- CASH PACKS (they grow with your income, so they're always worth it)
	------------------------------------------------------------------
	do
		local page = win.pages.Cash
		pageTitle(page, "Cash Packs", "Cash packs grow with your income - the more you earn, the bigger they get!")
		local H = 290
		local grid = UI.grid(page, UDim2.fromOffset(SMALL_W, H), 12, 1)
		local n = 0
		for _, p in ipairs(Shop.Products) do
			if p.kind == "cash" then
				n = n + 1
				local c = card(grid, UI.rgb(75, 205, 60):Lerp(UI.rgb(40, 170, 90), (n - 1) / 4), n, SMALL_W, H, p.name, p.icon or "cash", 96, 104)
				local amount = UI.label(c, "", {Position = UDim2.fromOffset(8, 152), Size = UDim2.new(1, -16, 0, 38), Max = 34, Stroke = 3, TextColor3 = UI.rgb(255, 240, 110),
					TextWrapped = false, ZIndex = 4})
				local worth = UI.label(c, "", {Position = UDim2.fromOffset(8, 190), Size = UDim2.new(1, -16, 0, 30), Max = 15, Min = 10, Stroke = 1.8, ZIndex = 4})
				local _, draw = priceButton(c, p.key, p.id, p.robux, function() buy("BuyProduct", p.key) end, nil, UDim2.fromOffset(170, 52), 28)
				table.insert(refreshers, function()
					UI.setText(amount, "$" .. fmt(Shop.CashAmount(p, player:GetAttribute("Income") or 0)))
					UI.setText(worth, "= " .. ((p.minutes >= 60) and (math.floor(p.minutes / 60 * 10) / 10 .. " hours") or (p.minutes .. " min")) .. " of your income")
					draw(false)
				end)
			end
		end
	end

	------------------------------------------------------------------
	-- BOOSTS: instant unbox, lucky box, server luck
	------------------------------------------------------------------
	local luckStatus
	do
		local page = win.pages.Boosts
		pageTitle(page, "Boosts", "Speed things up and get lucky!")
		local H = 300
		local grid = UI.grid(page, UDim2.fromOffset(BIG_W, H), 12, 1)
		local colors = {skip = UI.rgb(60, 150, 255), luckybox = UI.rgb(240, 70, 85), serverluck = UI.rgb(75, 205, 60)}
		local n = 0
		for _, p in ipairs(Shop.Products) do
			if p.kind ~= "cash" then
				n = n + 1
				local col = colors[p.kind] or C.purple
				local c = card(grid, col, n, BIG_W, H, p.name, p.icon or "star", 120, 114)
				UI.label(c, p.desc or "", {Position = UDim2.fromOffset(10, 170), Size = UDim2.new(1, -20, 0, 40), Max = 17, Min = 10, Stroke = 2.2, ZIndex = 4})
				local status = UI.label(c, "", {Position = UDim2.fromOffset(8, 210), Size = UDim2.new(1, -16, 0, 22), Max = 18, Stroke = 2, TextColor3 = UI.rgb(255, 240, 110),
					TextWrapped = false, ZIndex = 4})
				if p.kind == "serverluck" then luckStatus = status end
				local _, draw = priceButton(c, p.key, p.id, p.robux, function() buy("BuyProduct", p.key) end)
				table.insert(refreshers, function() draw(false) end)
			end
		end
	end

	------------------------------------------------------------------
	-- SPEED: the next speed boost, big, and the whole ladder
	------------------------------------------------------------------
	local drawSpeed
	do
		local page = win.pages.Speed
		pageTitle(page, "Speed Boosts", "Speed boosts multiply the speed your treadmill gives you - forever!")
		local BW, BH = 620, 150
		local big = UI.studCard(page, UI.rgb(255, 170, 30), {LayoutOrder = 1, Size = UDim2.fromOffset(BW, BH), ClipsDescendants = true}, Vector2.new(BW, BH))
		table.insert(bursts, UI.sunburst(big, UDim2.fromOffset(200, 200), UDim2.new(0, 72, 0.5, 0), {ZIndex = 2, Transparency = 0.35}))
		local bolt = UI.icon("bolt", big, UDim2.fromOffset(104, 104), UDim2.new(0, 72, 0.5, 0), C.yellow, Vector2.new(0.5, 0.5))
		bolt.ZIndex = 3
		local bigTitle = UI.label(big, "", {Position = UDim2.fromOffset(136, 16), Size = UDim2.new(1, -364, 0, 56), Max = 48, Stroke = 3.6, TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false, ZIndex = 4})
		local bigSub = UI.label(big, "", {Position = UDim2.fromOffset(136, 76), Size = UDim2.new(1, -364, 0, 56), Max = 17, Stroke = 2.2, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4})
		local bigBtn = UI.buyButton(big, {Color = BUY_COLOR, Size = UDim2.fromOffset(206, 66), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
			TextSize = 32, ZIndex = 4, Depth = 5})
		local ladder = UI.grid(page, UDim2.fromOffset(104, 74), 10, 2)
		local chips = {}
		for i, b in ipairs(Config.SpeedBoosts) do
			local chip = new("Frame", {BackgroundColor3 = UI.rgb(45, 42, 40), BackgroundTransparency = 0.05, LayoutOrder = i}, ladder)
			UI.corner(chip, 12)
			local st = UI.stroke(chip, 2.5)
			UI.label(chip, fmt(b.mult) .. "x", {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 32), Max = 28, Stroke = 2.4, TextWrapped = false})
			local sub = UI.label(chip, "", {Position = UDim2.fromOffset(6, 42), Size = UDim2.new(1, -12, 0, 22), Max = 16, Stroke = 1.5, TextWrapped = false})
			chips[i] = {frame = chip, stroke = st, sub = sub}
		end
		local nextTier = nil
		bigBtn.Activated:Connect(function()
			if nextTier and bigBtn.enabled then buy("BuyProduct", "Speed" .. nextTier) end
		end)
		drawSpeed = function()
			local have = player:GetAttribute("SpeedBoost") or (ctx.data and ctx.data.SpeedBoost) or 1
			nextTier = nil
			for i, b in ipairs(Config.SpeedBoosts) do
				local owned = have >= b.mult
				if not owned and not nextTier then nextTier = i end
				local c = chips[i]
				c.frame.BackgroundColor3 = owned and UI.rgb(40, 110, 50) or ((nextTier == i) and UI.rgb(120, 85, 20) or UI.rgb(45, 42, 40))
				c.stroke.Color = (nextTier == i) and C.yellow or C.ink
				UI.setText(c.sub, owned and "OWNED" or ("R$ " .. fmt(ctx.price("Speed" .. i, b.robux))))
				c.sub.TextColor3 = owned and C.money or UI.rgb(255, 215, 90)
			end
			if nextTier then
				local b = Config.SpeedBoosts[nextTier]
				UI.setText(bigTitle, fmt(b.mult) .. "x SPEED")
				UI.setText(bigSub, "Your treadmill gives " .. fmt(b.mult) .. "x speed (now " .. fmt(have) .. "x). Stacks with trails!")
				local id = Shop.SpeedBoostIds[nextTier] or 0
				if id == 0 and not IS_STUDIO then
					bigBtn.setText("SOON")
					bigBtn.setEnabled(false)
				else
					bigBtn.setPrice(fmt(ctx.price("Speed" .. nextTier, b.robux)))
					bigBtn.setEnabled(true)
				end
			else
				UI.setText(bigTitle, "MAX SPEED!")
				UI.setText(bigSub, "You own every speed boost. You're a legend!")
				bigBtn.setText("OWNED")
				bigBtn.setEnabled(false)
			end
		end
		player:GetAttributeChangedSignal("SpeedBoost"):Connect(drawSpeed)
	end

	-- the light rays turn slowly while the shop is open
	RunService.RenderStepped:Connect(function()
		if not win.frame.Visible then return end
		local r = (os.clock() * 9) % 360
		for _, b in ipairs(bursts) do b.Rotation = r end
	end)

	local function refreshAll()
		for _, f in ipairs(refreshers) do f() end
		drawSpeed()
	end
	win.onOpen = function()
		if LINKS[win.tab] then win.setTab("Passes") end
		refreshAll()
	end
	player:GetAttributeChangedSignal("Income"):Connect(function() if UI.isOpen("Shop") then refreshAll() end end)

	-- the Server Luck timer on its card
	task.spawn(function()
		while true do
			task.wait(0.5)
			if luckStatus and UI.isOpen("Shop") then
				local left = (game:GetService("ReplicatedStorage"):GetAttribute("ServerLuckUntil") or 0) - workspace:GetServerTimeNow()
				UI.setText(luckStatus, (left > 0) and ("Active: " .. Config.FormatTime(left)) or "")
			end
		end
	end)

	-- real prices from Roblox (async): the shop + the Speed offer update when they arrive
	task.spawn(function()
		local function fetch(key, id, infoType)
			if (id or 0) == 0 then return end
			local ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, infoType) end)
			if ok and info and tonumber(info.PriceInRobux) then ctx.prices[key] = tonumber(info.PriceInRobux) end
		end
		for _, p in ipairs(Shop.Passes) do fetch("Pass_" .. p.key, p.id, Enum.InfoType.GamePass) end
		for _, p in ipairs(Shop.Products) do fetch(p.key, p.id, Enum.InfoType.Product) end
		for i, id in ipairs(Shop.SpeedBoostIds) do fetch("Speed" .. i, id, Enum.InfoType.Product) end
		if ctx.hud and ctx.hud.drawOffer then ctx.hud.drawOffer() end
		if UI.isOpen("Shop") then refreshAll() end
	end)

	-- purchase granted: THANK YOU! + refresh
	ctx.remotes.ShopEvent.OnClientEvent:Connect(function(kind, info)
		if kind == "Granted" then
			if ctx.thanks then ctx.thanks(type(info) == "table" and info.title or "") end
			if UI.isOpen("Shop") then refreshAll() end
		end
	end)
end

return ShopWindow
