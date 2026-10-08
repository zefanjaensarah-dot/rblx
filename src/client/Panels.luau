--[[ STEAL A BOX - the side panels on the right (they don't darken the screen)
     Items     "3/8 Active": your products. Equip puts one on your shop shelf (it sells),
               Unequip takes it back, "+1 Equip" buys another shelf spot, Equip Best fills the shelf.
     Unboxing  the boxes on your base: time left, Open when ready, Open All. ]]

local Panels = {}

function Panels.init(ctx)
	local UI, Config = ctx.UI, ctx.Config
	local C, new, fmt = UI.C, UI.new, Config.FormatNum
	local TAN, TAN_DARK = UI.rgb(222, 165, 100), UI.rgb(160, 110, 60)

	-- one row: tan card with a black outline, like the screenshot
	local function row(page, order, height)
		local r = new("Frame", {Size = UDim2.new(1, -8, 0, height or 72), BackgroundColor3 = TAN, LayoutOrder = order}, page)
		UI.corner(r, 6)
		UI.stroke(r, 3)
		UI.shade(r, C.white, UI.rgb(215, 205, 195))
		return r
	end
	local function clear(page)
		for _, c in ipairs(page:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end
	local function emptyText(page, text)
		UI.label(page, text, {Size = UDim2.new(1, -20, 0, 80), Max = 20, Stroke = 2, TextColor3 = UI.rgb(200, 200, 210)})
	end

	------------------------------------------------------------------
	-- ITEMS
	------------------------------------------------------------------
	local items = UI.window({Name = "Items", Title = "0/8 Active", Docked = true, Size = Vector2.new(400, 430),
		HeaderButton = {Text = "+1 Equip", Color = UI.rgb(120, 120, 130)},
		Footer = {Text = "Equip Best", Color = UI.rgb(90, 220, 40)}})
	local function stands()
		return ctx.player:GetAttribute("Stands") or Config.BaseStands
	end
	local lastSig = nil
	local function drawItems(force)
		local data = ctx.data
		if not data or not data.Items then return end
		local unlocked = stands()
		local sig = {tostring(unlocked), tostring(data.Customers), tostring((data.Cash or 0) >= Config.CustomerCost(data.Customers or 1))}
		for _, it in ipairs(data.Items) do table.insert(sig, it.id .. it.mutation .. it.size .. tostring(it.stand)) end
		sig = table.concat(sig, "|")
		-- header: "3/8 Active" and the price of the next shelf spot
		local onShelf = 0
		for _, it in ipairs(data.Items) do if it.stand then onShelf = onShelf + 1 end end
		UI.setText(items.title, onShelf .. "/" .. unlocked .. " Active")
		local hb = items.headerBtn
		if unlocked >= Config.MaxStands then
			hb.holder.Visible = false
		else
			hb.holder.Visible = true
			local cost = Config.StandCost(unlocked)
			hb.setText("+1 Equip [$" .. fmt(cost) .. "]")
			hb.setColor((data.Cash or 0) >= cost and UI.rgb(70, 190, 60) or UI.rgb(120, 120, 130))
		end
		if sig == lastSig and not force then return end
		lastSig = sig
		local page = items.page
		clear(page)
		-- more shoppers (this used to be the kiosk on your base)
		do
			local level = data.Customers or 1
			local r = row(page, 0, 60)
			r.BackgroundColor3 = UI.rgb(120, 200, 255)
			UI.icon("star", r, UDim2.fromOffset(44, 44), UDim2.fromOffset(8, 8), C.yellow)
			UI.label(r, "Shoppers  Lv " .. level .. "/" .. Config.CustomerMax, {Position = UDim2.fromOffset(60, 4), Size = UDim2.new(1, -190, 0, 28), Max = 21,
				Stroke = 2.4, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
			UI.label(r, "x" .. string.format("%.1f", Config.CustomerRate(level)) .. " cash from your shelf", {Position = UDim2.fromOffset(60, 32), Size = UDim2.new(1, -190, 0, 22),
				Max = 17, Stroke = 2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextColor3 = C.money})
			local maxed = level >= Config.CustomerMax
			local cost = (not maxed) and Config.CustomerCost(level) or 0
			local up = UI.button(r, {Text = maxed and "MAX" or ("$" .. fmt(cost)), Color = (maxed or (data.Cash or 0) < cost) and UI.rgb(120, 120, 130) or UI.rgb(70, 200, 50),
				Size = UDim2.fromOffset(112, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), TextSize = 20, Depth = 4})
			up.Activated:Connect(function()
				if maxed then return end
				local res = ctx.invoke("UpgradeShoppers")
				if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.green or C.red) end
			end)
		end
		if #data.Items == 0 then
			emptyText(page, "No items yet - steal a box from the Mega Mart and open it!")
			return
		end
		-- shelf items first, then the backpack; best income first
		local order = {}
		for i in ipairs(data.Items) do table.insert(order, i) end
		table.sort(order, function(a, b)
			local ia, ib = data.Items[a], data.Items[b]
			if (ia.stand ~= nil) ~= (ib.stand ~= nil) then return ia.stand ~= nil end
			return Config.ItemIncome(ia) > Config.ItemIncome(ib)
		end)
		for n, i in ipairs(order) do
			local item = data.Items[i]
			local onIt = item.stand ~= nil
			local mut = Config.GetMutation(item.mutation)
			local r = row(page, n)
			local vpBack = new("Frame", {Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(60, 60), BackgroundColor3 = TAN_DARK}, r)
			UI.corner(vpBack, 6)
			UI.itemView(vpBack, item, {Size = UDim2.fromScale(1, 1)})
			UI.label(r, Config.ItemLabel(item), {Position = UDim2.fromOffset(74, 6), Size = UDim2.new(1, -200, 0, 30), Max = 22, Stroke = 2.4,
				TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextColor3 = mut.color and mut.color:Lerp(C.white, 0.4) or C.white})
			UI.label(r, "($" .. fmt(Config.ItemIncome(item)) .. "/s)", {Position = UDim2.fromOffset(74, 38), Size = UDim2.new(1, -200, 0, 24), Max = 20,
				Stroke = 2.2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextColor3 = C.money})
			local main = UI.button(r, {Text = onIt and "Unequip" or "Equip", Color = onIt and UI.rgb(225, 30, 40) or UI.rgb(70, 200, 50),
				Size = UDim2.fromOffset(112, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), TextSize = 22, Depth = 4})
			main.Activated:Connect(function()
				local res = ctx.invoke(onIt and "RemoveItem" or "PlaceItem", i, item.id)
				if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.green or C.red) end
			end)
			-- small Sell button: tap once to arm, again to sell
			local sellText = "Sell $" .. fmt(Config.ItemIncome(item) * 30)
			local sell = UI.button(r, {Text = sellText, Color = UI.rgb(120, 120, 130), Size = UDim2.fromOffset(112, 22),
				AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -4), TextSize = 13, Depth = 2, Radius = 5})
			local armedAt = nil
			sell.Activated:Connect(function()
				if not armedAt or os.clock() - armedAt > 2.5 then
					armedAt = os.clock()
					sell.setText("Sure? Tap again")
					sell.setColor(C.orange)
					return
				end
				armedAt = nil
				local res = ctx.invoke("SellItem", i, item.id)
				if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.green or C.red) end
			end)
		end
	end
	items.onOpen = function() drawItems(true) end
	items.headerBtn.Activated:Connect(function()
		local res = ctx.invoke("BuyStand")
		if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.green or C.red) end
		if res.ok and ctx.confetti then ctx.confetti(30) end
	end)
	items.footerBtn.Activated:Connect(function()
		local res = ctx.invoke("EquipAll")
		if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.green or C.red) end
	end)
	ctx.onData(function() if UI.isOpen("Items") then drawItems() end end)
	ctx.onCash(function() if UI.isOpen("Items") then drawItems() end end)
	ctx.player:GetAttributeChangedSignal("Stands"):Connect(function() if UI.isOpen("Items") then drawItems() end end)

	------------------------------------------------------------------
	-- UNBOXING
	------------------------------------------------------------------
	local unbox = UI.window({Name = "Unboxing", Title = "Unboxing", Docked = true, Size = Vector2.new(400, 430),
		HeaderButton = {Text = "Open All", Color = UI.rgb(255, 170, 30)},
		Footer = {Text = "Instant Open", Color = UI.rgb(170, 80, 255)}})
	local timers = {} -- {label, button, readyAt}
	local function readyCount()
		local n = 0
		local t = workspace:GetServerTimeNow()
		for _, e in pairs(ctx.data and ctx.data.Unboxing or {}) do
			if type(e) == "table" and (e.readyAt or 0) <= t then n = n + 1 end
		end
		return n
	end
	local function drawUnbox()
		local data = ctx.data
		if not data then return end
		local page = unbox.page
		clear(page)
		timers = {}
		local keys = {}
		for k, e in pairs(data.Unboxing or {}) do
			if type(e) == "table" and Config.Boxes[e.id] then table.insert(keys, k) end
		end
		table.sort(keys, function(a, b) return (data.Unboxing[a].readyAt or 0) < (data.Unboxing[b].readyAt or 0) end)
		if #keys == 0 then
			emptyText(page, "Steal boxes from the Mega Mart and put them on your base!")
		end
		for n, k in ipairs(keys) do
			local e = data.Unboxing[k]
			local def = Config.Boxes[e.id]
			local rar = Config.Rarities[def.rarity] or Config.Rarities[1]
			local r = row(page, n, 64)
			UI.icon("box", r, UDim2.fromOffset(48, 48), UDim2.fromOffset(8, 8), def.color)
			UI.label(r, Config.BoxLabel(def, e.mutation, e.size), {Position = UDim2.fromOffset(64, 6), Size = UDim2.new(1, -190, 0, 28), Max = 21, Stroke = 2.4,
				TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextColor3 = rar.color:Lerp(C.white, 0.35)})
			local left = UI.label(r, "", {Position = UDim2.fromOffset(64, 34), Size = UDim2.new(1, -190, 0, 24), Max = 20, Stroke = 2.2,
				TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
			local open = UI.button(r, {Text = "Open", Color = UI.rgb(70, 200, 50), Size = UDim2.fromOffset(104, 44),
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), TextSize = 22, Depth = 4})
			open.Activated:Connect(function()
				local res = ctx.invoke("OpenBox", k)
				if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.green or C.red) end
			end)
			table.insert(timers, {label = left, button = open, readyAt = e.readyAt or 0})
		end
	end
	-- time left: once a second, only while the panel is open
	local function tick()
		local t = workspace:GetServerTimeNow()
		for _, tm in ipairs(timers) do
			local leftS = math.ceil(tm.readyAt - t)
			if leftS <= 0 then
				UI.setText(tm.label, "READY!")
				tm.label.TextColor3 = C.money
				tm.button.setEnabled(true)
			else
				UI.setText(tm.label, Config.FormatTime(leftS))
				tm.label.TextColor3 = C.white
				tm.button.setEnabled(false)
			end
		end
		unbox.headerBtn.setEnabled(readyCount() > 0)
		local product = ctx.Shop.GetProduct("SkipUnbox")
		unbox.footerBtn.setText("Instant Open  R$ " .. fmt(ctx.price("SkipUnbox", product and product.robux or 39)))
	end
	unbox.onOpen = function()
		drawUnbox()
		tick()
	end
	unbox.headerBtn.Activated:Connect(function()
		local res = ctx.invoke("OpenAll")
		if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.green or C.red) end
	end)
	unbox.footerBtn.Activated:Connect(function()
		local res = ctx.invoke("BuyProduct", "SkipUnbox")
		if res.msg and res.msg ~= "" then ctx.notify(res.msg, res.ok and C.yellow or C.red) end
	end)
	ctx.onData(function() if UI.isOpen("Unboxing") then unbox.onOpen() end end)
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.isOpen("Unboxing") then tick() end
			if ctx.badges and ctx.badges.Unboxing then ctx.badges.Unboxing.set(readyCount()) end
		end
	end)
end

return Panels
