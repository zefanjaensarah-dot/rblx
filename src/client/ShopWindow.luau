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
	local win = UI.window({Name = "Shop", Title = "Shop", Icon = "shop", Color = C.yellow, Size = Vector2.new(800, 500),
		Tabs = {{Key = "Passes", Label = "Passes", Icon = "crown"}, {Key = "Cash", Label = "Cash", Icon = "cash"},
			{Key = "Boosts", Label = "Boosts", Icon = "clover"}, {Key = "Speed", Label = "Speed", Icon = "bolt"}}})
	local refreshers = {}

	-- the price button of a card: "R$ 99", "OWNED" or "SOON"
	local function priceButton(parent, key, id, fallback, onBuy, pos, size)
		local b = UI.button(parent, {Text = "", Color = C.green, Size = size or UDim2.new(1, -16, 0, 46), Position = pos or UDim2.new(0, 8, 1, -54), TextSize = 22})
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
				b.setText("R$ " .. fmt(ctx.price(key, fallback)))
				b.setEnabled(true)
				b.setColor(C.green)
			end
		end
		return b, draw
	end

	local function buy(action, key)
		local r = ctx.invoke(action, key)
		if r.msg and r.msg ~= "" then ctx.notify(r.msg, r.ok and C.yellow or C.red) end
	end

	-- a card with an icon in a coloured circle, a title and a description
	local function card(parent, color, order, size)
		local c = UI.card(parent, color:Lerp(UI.rgb(30, 26, 50), 0.65), {LayoutOrder = order, Size = size})
		return c
	end
	local function iconCircle(parent, iconName, color, y)
		local circle = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y or 10), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = color}, parent)
		UI.corner(circle, true)
		UI.stroke(circle, 3)
		UI.shade(circle, C.white, UI.rgb(190, 190, 200))
		UI.icon(iconName, circle, UDim2.fromOffset(44, 44), UDim2.fromScale(0.5, 0.5), color:Lerp(C.white, 0.25), Vector2.new(0.5, 0.5))
		return circle
	end

	------------------------------------------------------------------
	-- PASSES
	------------------------------------------------------------------
	do
		local page = win.pages.Passes
		UI.label(page, "Bought once, yours forever!", {Size = UDim2.new(1, -10, 0, 26), LayoutOrder = 0, Max = 20, Stroke = 1.8, TextColor3 = C.sub})
		local grid = UI.grid(page, UDim2.fromOffset(226, 226), 12, 1)
		for i, pass in ipairs(Shop.Passes) do
			local c = card(grid, pass.color, i)
			iconCircle(c, pass.icon, pass.color)
			UI.label(c, pass.name, {Position = UDim2.fromOffset(8, 78), Size = UDim2.new(1, -16, 0, 28), Max = 24, Stroke = 2.2, TextColor3 = pass.color:Lerp(C.white, 0.4), TextWrapped = false})
			UI.label(c, pass.desc, {Position = UDim2.fromOffset(10, 108), Size = UDim2.new(1, -20, 0, 56), Max = 15, Stroke = 1.4, TextColor3 = C.sub})
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
		UI.label(page, "Cash packs grow with your income - the more you earn, the bigger they get!", {Size = UDim2.new(1, -10, 0, 26), LayoutOrder = 0, Max = 19, Stroke = 1.8, TextColor3 = C.sub})
		local grid = UI.grid(page, UDim2.fromOffset(168, 238), 12, 1)
		local n = 0
		for _, p in ipairs(Shop.Products) do
			if p.kind == "cash" then
				n = n + 1
				local c = card(grid, C.green, n)
				iconCircle(c, p.icon or "cash", C.green:Lerp(C.yellow, n / 5))
				UI.label(c, p.name, {Position = UDim2.fromOffset(8, 78), Size = UDim2.new(1, -16, 0, 24), Max = 19, Stroke = 1.8, TextWrapped = false})
				local amount = UI.label(c, "", {Position = UDim2.fromOffset(8, 104), Size = UDim2.new(1, -16, 0, 40), Max = 36, Stroke = 2.8, TextColor3 = C.money, TextWrapped = false})
				local worth = UI.label(c, "", {Position = UDim2.fromOffset(8, 146), Size = UDim2.new(1, -16, 0, 30), Max = 13, Stroke = 1.2, TextColor3 = C.sub})
				local _, draw = priceButton(c, p.key, p.id, p.robux, function() buy("BuyProduct", p.key) end)
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
		UI.label(page, "Speed things up and get lucky!", {Size = UDim2.new(1, -10, 0, 26), LayoutOrder = 0, Max = 20, Stroke = 1.8, TextColor3 = C.sub})
		local grid = UI.grid(page, UDim2.fromOffset(226, 246), 12, 1)
		local colors = {skip = C.blue, luckybox = C.pink, serverluck = C.green}
		local n = 0
		for _, p in ipairs(Shop.Products) do
			if p.kind ~= "cash" then
				n = n + 1
				local col = colors[p.kind] or C.purple
				local c = card(grid, col, n)
				iconCircle(c, p.icon or "star", col)
				UI.label(c, p.name, {Position = UDim2.fromOffset(8, 78), Size = UDim2.new(1, -16, 0, 28), Max = 24, Stroke = 2.2, TextColor3 = col:Lerp(C.white, 0.4), TextWrapped = false})
				UI.label(c, p.desc or "", {Position = UDim2.fromOffset(10, 108), Size = UDim2.new(1, -20, 0, 52), Max = 15, Stroke = 1.4, TextColor3 = C.sub})
				local status = UI.label(c, "", {Position = UDim2.fromOffset(8, 160), Size = UDim2.new(1, -16, 0, 22), Max = 16, Stroke = 1.6, TextColor3 = C.yellow, TextWrapped = false})
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
		UI.label(page, "Speed boosts multiply the speed your treadmill gives you - forever!", {Size = UDim2.new(1, -10, 0, 26), LayoutOrder = 0, Max = 19, Stroke = 1.8, TextColor3 = C.sub})
		local big = card(page, C.yellow, 1, UDim2.fromOffset(560, 130))
		UI.icon("bolt", big, UDim2.fromOffset(90, 90), UDim2.new(0, 16, 0.5, 0), C.yellow, Vector2.new(0, 0.5))
		local bigTitle = UI.label(big, "", {Position = UDim2.fromOffset(118, 14), Size = UDim2.new(1, -330, 0, 52), Max = 46, Stroke = 3.2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
		local bigSub = UI.label(big, "", {Position = UDim2.fromOffset(118, 70), Size = UDim2.new(1, -330, 0, 44), Max = 16, Stroke = 1.5, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left})
		local bigBtn = UI.button(big, {Text = "", Color = C.green, Size = UDim2.fromOffset(190, 60), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), TextSize = 28})
		local ladder = UI.grid(page, UDim2.fromOffset(104, 74), 10, 2)
		local chips = {}
		for i, b in ipairs(Config.SpeedBoosts) do
			local chip = new("Frame", {BackgroundColor3 = UI.rgb(46, 42, 72), LayoutOrder = i}, ladder)
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
				c.frame.BackgroundColor3 = owned and UI.rgb(40, 100, 55) or ((nextTier == i) and UI.rgb(100, 82, 26) or UI.rgb(46, 42, 72))
				c.stroke.Color = (nextTier == i) and C.yellow or C.ink
				UI.setText(c.sub, owned and "OWNED" or ("R$ " .. fmt(ctx.price("Speed" .. i, b.robux))))
				c.sub.TextColor3 = owned and C.money or C.sub
			end
			if nextTier then
				local b = Config.SpeedBoosts[nextTier]
				UI.setText(bigTitle, fmt(b.mult) .. "x SPEED")
				UI.setText(bigSub, "Your treadmill gives " .. fmt(b.mult) .. "x speed (now " .. fmt(have) .. "x). Stacks with trails and rebirths!")
				local id = Shop.SpeedBoostIds[nextTier] or 0
				if id == 0 and not IS_STUDIO then
					bigBtn.setText("SOON")
					bigBtn.setEnabled(false)
				else
					bigBtn.setText("R$ " .. fmt(ctx.price("Speed" .. nextTier, b.robux)))
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

	local function refreshAll()
		for _, f in ipairs(refreshers) do f() end
		drawSpeed()
	end
	win.onOpen = refreshAll
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
