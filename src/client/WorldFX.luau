--[[ STEAL A BOX - world effects (everything that happens in the 3D world on YOUR screen)
     Click-to-place ghost box, particle bursts, the box opening + 3D item reveal, treadmill
     running, rainbow boxes, critters, guardian orbs, shopper bubbles, sale pops, ragdoll fling.
     Also keeps world text tidy: only the product / box you're closest to shows its label. ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local WorldFX = {}

function WorldFX.init(ctx)
	local UI, Config, player = ctx.UI, ctx.Config, ctx.player
	local playerGui = player:WaitForChild("PlayerGui")

	-- THE UPGRADE BUTTON on your treadmill sign (both sides): it grows and wiggles when you hover
	-- over it, squishes when you click it, and breathes while you can afford the upgrade
	-- bouncy buttons on signs in the world: they grow and wiggle when you hover over them, squish
	-- when you click them, and breathe while you can afford what they buy
	local bounceList = {}
	local function bouncy(b, onClick)
		local sc = Instance.new("UIScale")
		sc.Parent = b
		local st = {b = b, sc = sc, hover = false, press = -10, can = true}
		b.MouseEnter:Connect(function() st.hover = true end)
		b.MouseLeave:Connect(function() st.hover = false end)
		b.Activated:Connect(function()
			if os.clock() - st.press < 0.3 then return end
			st.press = os.clock()
			onClick()
		end)
		table.insert(bounceList, st)
		return st
	end
	RunService.RenderStepped:Connect(function()
		if #bounceList == 0 then return end
		local t = os.clock()
		for i = #bounceList, 1, -1 do -- (buttons of a sign that was taken down are dropped)
			if not bounceList[i].b.Parent then table.remove(bounceList, i) end
		end
		for i, st in ipairs(bounceList) do
			local since = t - st.press
			local squish = (since < 0.4) and (1 - math.sin(since / 0.4 * math.pi) * 0.25) or 1
			local target = (st.hover and 1.12 or 1) * squish * (st.can and (1 + 0.04 * math.sin(t * 5 + i)) or 1)
			st.sc.Scale = st.sc.Scale + (target - st.sc.Scale) * 0.35
			st.b.Rotation = st.hover and math.sin(t * 10) * 3 or 0
		end
	end)
	local GREEN_BTN, GREY_BTN, INK = Color3.fromRGB(70, 210, 60), Color3.fromRGB(130, 130, 142), Color3.fromRGB(25, 22, 30)
	local function chunkyButton(parent, props)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.FontFace = UI.Font
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextStrokeTransparency = 0
		b.TextStrokeColor3 = INK
		b.BackgroundColor3 = GREEN_BTN
		for k, v in pairs(props) do b[k] = v end
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.3, 0)
		c.Parent = b
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Thickness = 4
		st.Color = INK
		st.Parent = b
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
		g.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
		pad.Parent = b
		b.Parent = parent
		return b
	end

	-- WORLD SIGNS on your plot, in the inspiration game's style: the wooden "Plot Upgrades" board at the
	-- end of your path and the slanted "Speed per Step" sign by your treadmill. Each upgrade is one dark
	-- rounded row: a big icon, a coloured title, a small white line, "now -> next", a green price pill
	-- (bouncy: grows + wiggles on hover, squishes on click, grey when you can't pay, "MAXED" at the top)
	-- and a yellow Robux pill that opens the matching Shop page. Only YOU see these on your own plot
	-- (built in your PlayerGui); the plain copies the map put on the parts are switched off on your screen.
	local Signs = {}
	do
		local PPS = 50 -- pixels per stud on the sign faces
		local ROW_BG, ROW_LINE = Color3.fromRGB(45, 42, 40), Color3.fromRGB(26, 22, 20)
		local GREEN_PILL, YELLOW_PILL = Color3.fromRGB(60, 200, 60), Color3.fromRGB(255, 196, 30)
		local CYAN_T, ORANGE_T = Color3.fromRGB(80, 210, 255), Color3.fromRGB(255, 170, 40)
		local GREEN_T, PINK_T = Color3.fromRGB(120, 235, 80), Color3.fromRGB(255, 120, 200)
		local WOOD_LINE = Color3.fromRGB(122, 82, 48)
		-- "$4,000" like the reference (FormatNum for the really big ones)
		local function price(n)
			if Config.FormatCommas and n < 1e9 then return "$" .. Config.FormatCommas(n) end
			return "$" .. Config.FormatNum(n)
		end
		local function pct(l)
			local p = math.floor((1 - Config.UnboxMult(l)) * 100 + 0.5)
			return (p == 0) and "0%" or ("-" .. p .. "%")
		end
		-- the rows of the big board (same order + actions as before)
		Signs.BOARD = {
			{key = "shoppers", title = "More Shoppers", desc = "More shoppers visit.", icon = "shop", color = CYAN_T, action = "UpgradeShoppers", tab = "Cash",
				level = function(d) return d.Customers or 1 end, max = function() return Config.CustomerMax end,
				cost = function(l) return Config.CustomerCost(l) end, value = function(l) return "x" .. string.format("%.1f", Config.CustomerRate(l)) end},
			{key = "payout", title = "Payouts", desc = "Shoppers pay more.", icon = "cash", color = GREEN_T, action = "UpgradePayout", tab = "Passes",
				level = function(d) return d.PayoutLevel or 1 end, max = function() return Config.PayoutMax end,
				cost = function(l) return Config.PayoutCost(l) end, value = function(l) return "x" .. string.format("%.2f", Config.PayoutMult(l)) end},
			{key = "unbox", title = "Unbox Speed", desc = "Boxes open faster.", icon = "bolt", color = ORANGE_T, action = "UpgradeUnbox", tab = "Boosts",
				level = function(d) return d.UnboxLevel or 1 end, max = function() return Config.UnboxMax end,
				cost = function(l) return Config.UnboxCost(l) end, value = pct},
			{key = "trails", title = "Trails", desc = "Cool trails behind you!", icon = "star", color = PINK_T, open = "Trails", tab = "Passes",
				change = "Boosts your treadmill speed"},
		}
		-- the treadmill row: speed you earn per second of running (with your trail + Robux boost)
		local function treadRate(l)
			local d = ctx.data or {}
			local t = d.Trail and Config.GetTrail and Config.GetTrail(d.Trail)
			return Config.TreadRate(l) * ((t and t.mult) or 1) * (d.SpeedBoost or 1)
		end
		Signs.TREAD = {key = "tread", title = "Speed per Step", desc = "Earn more speed.", icon = "boot", color = CYAN_T, action = "UpgradeTreadmill", tab = "Speed",
			level = function(d) return d.Treadmill or 1 end, max = function() return Config.Treadmill.max end,
			cost = function(l) return Config.TreadmillCost(l) end, value = function(l) return Config.FormatNum(treadRate(l)) end}

		-- the plain sign the map put on a part is turned off on this screen (our rows replace it)
		local hiddenOn = {} -- [part] = {SurfaceGui, ...}
		local function hideMapGuis(part, on)
			if on then
				local list = hiddenOn[part] or {}
				hiddenOn[part] = list
				for _, g in ipairs(part:GetChildren()) do
					if g:IsA("SurfaceGui") and g.Enabled then
						g.Enabled = false
						table.insert(list, g)
					end
				end
			elseif hiddenOn[part] then
				for _, g in ipairs(hiddenOn[part]) do g.Enabled = true end
				hiddenOn[part] = nil
			end
		end
		local function faceGui(name, part, face)
			local sg = Instance.new("SurfaceGui")
			sg.Name = name
			sg.Adornee = part
			sg.Face = face
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = PPS
			sg.LightInfluence = 0
			sg.ZOffset = 2
			sg.ResetOnSpawn = false
			sg.Parent = playerGui
			return sg
		end
		-- the face size of a part in sign pixels (Front/Back face = X by Y)
		local function faceSize(part, fallback)
			local ok, s = pcall(function() return part.Size end)
			if not ok or typeof(s) ~= "Vector3" or s.X < 1 or s.Y < 1 then s = fallback end
			return s.X * PPS, s.Y * PPS
		end
		-- a thin dark line just inside the sign's edge (the wooden panel's border; the part's own
		-- studded wood shows through everything else)
		local function panelEdge(sg, w, h)
			local edge = Instance.new("Frame")
			edge.Name = "Edge"
			edge.BackgroundTransparency = 1
			edge.AnchorPoint = Vector2.new(0.5, 0.5)
			edge.Position = UDim2.fromScale(0.5, 0.5)
			edge.Size = UDim2.new(1, -math.floor(h * 0.05), 1, -math.floor(h * 0.05))
			edge.Parent = sg
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, math.floor(h * 0.03))
			c.Parent = edge
			local s = Instance.new("UIStroke")
			s.Thickness = math.max(3, math.floor(h * 0.012))
			s.Color = WOOD_LINE
			s.Transparency = 0.15
			s.Parent = edge
		end
		local function text(parent, str, color, x, y, w, h, maxSize, props)
			local l = UI.label(parent, str, {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Max = math.floor(maxSize),
				Stroke = math.max(2, math.floor(maxSize * 0.09)), TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
			l.ZIndex = parent.ZIndex + 2
			for k, v in pairs(props or {}) do l[k] = v end
			return l
		end
		-- a yellow pill: Robux icon + "Shop" (opens the Shop on the page that helps with this upgrade)
		local function robuxPill(parent, x, y, w, h, tab)
			local b = chunkyButton(parent, {Name = "RobuxPill", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
				BackgroundColor3 = YELLOW_PILL, Text = ""})
			b.ZIndex = parent.ZIndex + 2
			local inner = h * 0.72 -- (the button's padding takes 14% top + bottom)
			local isz = math.floor(inner * 0.95)
			local ic = UI.icon("robux", b, UDim2.fromOffset(isz, isz), UDim2.new(0, math.floor(w * 0.1), 0.5, 0), Color3.new(1, 1, 1), Vector2.new(0, 0.5))
			ic.ZIndex = b.ZIndex + 1
			local tx = math.floor(w * 0.1) + isz + math.floor(w * 0.04)
			local l = UI.label(b, "Shop", {Position = UDim2.new(0, tx, 0, 0), Size = UDim2.new(1, -tx - math.floor(w * 0.08), 1, 0), Max = math.floor(inner * 0.92),
				Stroke = math.max(2, math.floor(h * 0.05)), TextWrapped = false})
			l.ZIndex = b.ZIndex + 1
			bouncy(b, function() UI.open("Shop", tab) end)
			return b
		end
		-- one dark rounded row. Wide rows (the board) keep everything on one line like the reference;
		-- tall rows (the small treadmill sign) put the two pills along the bottom.
		local function makeRow(sg, def, x, y, w, h)
			local f = Instance.new("Frame")
			f.Name = "Row_" .. def.key
			f.Position = UDim2.fromOffset(x, y)
			f.Size = UDim2.fromOffset(w, h)
			f.BackgroundColor3 = ROW_BG
			f.BackgroundTransparency = 0.05
			f.BorderSizePixel = 0
			f.ZIndex = 2
			f.Parent = sg
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, math.floor(math.min(h, w * 0.25) * 0.22))
			c.Parent = f
			local s = Instance.new("UIStroke")
			s.Thickness = math.max(2, math.floor(math.min(h, w * 0.25) * 0.035))
			s.Color = ROW_LINE
			s.Transparency = 0.2
			s.Parent = f
			local r = {def = def}
			local function onBuy()
				if def.open then
					UI.open(def.open)
					return
				end
				task.spawn(function()
					local ok, res = pcall(ctx.invoke, def.action)
					if ok and type(res) == "table" and res.msg and res.msg ~= "" and ctx.notify then
						ctx.notify(res.msg, res.ok and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 90, 90))
					end
				end)
			end
			local gx, gy, gw, gh, rx, rw
			if w / h >= 4 then
				-- [icon] Title / small line / now -> next ......... [$price] [R Shop]
				local isz = math.floor(h * 1.18)
				local ic = UI.icon(def.icon, f, UDim2.fromOffset(isz, isz), UDim2.new(0, -math.floor(isz * 0.12), 0.5, 0), def.color, Vector2.new(0, 0.5))
				ic.ZIndex = f.ZIndex + 3
				local gap = math.floor(h * 0.14)
				gh = math.floor(h * 0.64)
				rw = math.floor(w * 0.16)
				gw = math.floor(w * 0.22)
				rx = w - gap - rw
				gx = rx - gap - gw
				gy = math.floor(h / 2)
				local tx = math.floor(isz * 0.95)
				local tw = gx - gap - tx
				r.title = text(f, def.title, def.color, tx, math.floor(h * 0.04), tw, math.floor(h * 0.4), h * 0.36)
				r.desc = text(f, def.desc, Color3.new(1, 1, 1), tx, math.floor(h * 0.43), tw, math.floor(h * 0.24), h * 0.21)
				r.change = text(f, "", Color3.new(1, 1, 1), tx, math.floor(h * 0.66), tw, math.floor(h * 0.29), h * 0.25)
			else
				-- [icon] Title / small line / now -> next
				-- [   $price   ] [ R Shop ]
				local pad = math.floor(w * 0.035)
				local isz = math.floor(math.min(h * 0.6, w * 0.3))
				local ic = UI.icon(def.icon, f, UDim2.fromOffset(isz, isz), UDim2.fromOffset(pad - math.floor(isz * 0.06), math.floor(h * 0.03)), def.color)
				ic.ZIndex = f.ZIndex + 3
				local tx = pad + isz + math.floor(w * 0.02)
				local tw = w - tx - pad
				r.title = text(f, def.title, def.color, tx, math.floor(h * 0.05), tw, math.floor(h * 0.24), h * 0.21)
				r.desc = text(f, def.desc, Color3.new(1, 1, 1), tx, math.floor(h * 0.29), tw, math.floor(h * 0.15), h * 0.13)
				r.change = text(f, "", Color3.new(1, 1, 1), tx, math.floor(h * 0.44), tw, math.floor(h * 0.18), h * 0.155)
				gh = math.floor(h * 0.29)
				gy = math.floor(h * 0.8)
				gx = pad
				local gap = math.floor(w * 0.03)
				gw = math.floor((w - pad * 2 - gap) * 0.6)
				rx = gx + gw + gap
				rw = w - pad - rx
			end
			r.btn = chunkyButton(f, {Name = "PricePill", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(gx, gy), Size = UDim2.fromOffset(gw, gh),
				BackgroundColor3 = GREEN_PILL, Text = ""})
			r.btn.ZIndex = f.ZIndex + 2
			r.st = bouncy(r.btn, onBuy)
			r.robux = robuxPill(f, rx, gy, rw, gh, def.tab)
			return r
		end
		-- fill one row from your data
		local function fillRow(r, data)
			local def = r.def
			if def.open then
				UI.setText(r.change, def.change or "")
				r.btn.Text = "OPEN"
				r.btn.BackgroundColor3 = GREEN_PILL
				r.st.can = true
				return
			end
			local lvl, max = def.level(data), def.max()
			local maxed = lvl >= max
			local cost = maxed and 0 or def.cost(lvl)
			local can = (not maxed) and (data.Cash or 0) >= cost
			UI.setText(r.change, maxed and (def.value(lvl) .. "  (max)") or (def.value(lvl) .. " -> " .. def.value(lvl + 1)))
			r.btn.Text = maxed and "MAXED" or price(cost)
			r.btn.BackgroundColor3 = can and GREEN_PILL or GREY_BTN
			r.st.can = can
		end

		-- THE PLOT UPGRADES BOARD (both faces: you can read it from the path and from behind)
		local board = nil -- {part, guis, rows}
		function Signs.board(part, data)
			if board and board.part ~= part then
				hideMapGuis(board.part, false)
				for _, sg in ipairs(board.guis) do sg:Destroy() end
				board = nil
			end
			if not board then
				board = {part = part, guis = {}, rows = {}}
				local W, H = faceSize(part, Vector3.new(22, 11, 0.6))
				for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
					local sg = faceGui("UpgradeBoardCards", part, face)
					table.insert(board.guis, sg)
					panelEdge(sg, W, H)
					local title = UI.label(sg, "Plot Upgrades", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, math.floor(H * 0.03)),
						Size = UDim2.fromOffset(math.floor(W * 0.8), math.floor(H * 0.13)), Max = math.floor(H * 0.115), Stroke = math.max(3, math.floor(H * 0.011)), TextWrapped = false})
					title.Name = "Title"
					title.ZIndex = 4
					local top, bottom = H * 0.18, H * 0.97
					local gap = H * 0.022
					local n = #Signs.BOARD
					local rh = math.floor((bottom - top - gap * (n - 1)) / n)
					local rx = math.floor(W * 0.035)
					for i, def in ipairs(Signs.BOARD) do
						local r = makeRow(sg, def, rx, math.floor(top + (i - 1) * (rh + gap)), W - rx * 2, rh)
						table.insert(board.rows, r)
					end
				end
			end
			hideMapGuis(part, true)
			for _, r in ipairs(board.rows) do fillRow(r, data) end
		end

		-- THE TREADMILL SIGN: one "Speed per Step" row (both faces)
		local tread = nil -- {part, guis, rows}
		function Signs.tread(part, data)
			if tread and tread.part ~= part then
				hideMapGuis(tread.part, false)
				for _, sg in ipairs(tread.guis) do sg:Destroy() end
				tread = nil
			end
			if not tread then
				tread = {part = part, guis = {}, rows = {}}
				local W, H = faceSize(part, Vector3.new(9, 4.6, 0.5))
				for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
					local sg = faceGui("TreadUpgradeButton", part, face)
					table.insert(tread.guis, sg)
					panelEdge(sg, W, H)
					local mx, my = math.floor(W * 0.04), math.floor(H * 0.1)
					table.insert(tread.rows, makeRow(sg, Signs.TREAD, mx, my, W - mx * 2, H - my * 2))
				end
			end
			-- (the map's own "Level" + "Rate" lines are hidden with the rest of its sign)
			hideMapGuis(part, true)
			for _, r in ipairs(tread.rows) do fillRow(r, data) end
		end
	end
	local new, ICON, SFX = UI.new, UI.ICON, UI.SFX
	local WHITE, BLACK, MONEY = UI.C.white, UI.C.black, UI.C.money
	local CARD_DARK = UI.rgb(24, 24, 30)
	local formatNum = Config.FormatNum
	local NUMBER_FONT = UI.Font
	local PlaceBoxEvent, FlingEvent, FXEvent, RevealEvent = ctx.remotes.PlaceBox, ctx.remotes.Fling, ctx.remotes.FX, ctx.remotes.Reveal
	local function effectsOn() return ctx.settings.Effects ~= false end
	-- round corners (old helper: small radii are doubled)
	local function corner(parent, r)
		r = r or 12
		if r < 100 then r = math.max(10, r * 2.2) end
		return new("UICorner", {CornerRadius = UDim.new(0, r)}, parent)
	end
	-- a label for world billboards (TextScaled + outline). props.StrokeSize = outline thickness
	local function text(parent, str, props)
		local l = new("TextLabel", {BackgroundTransparency = 1, FontFace = UI.Font, TextScaled = true, TextColor3 = WHITE,
			Text = Config.StripEmoji(str), Size = UDim2.fromScale(1, 1)}, parent)
		for k, v in pairs(props or {}) do
			if k ~= "StrokeSize" then l[k] = v end
		end
		new("UIStroke", {Thickness = ((props and props.StrokeSize) or 2) * 1.15, Color = UI.C.ink, LineJoinMode = Enum.LineJoinMode.Round}, l)
		return l
	end

	------------------------------------------------------------------
	-- CAMERA SHAKE (off when "Screen effects" is off in Settings)
	------------------------------------------------------------------
	local shakeUntil, shakePower = 0, 0
	RunService:BindToRenderStep("StealABoxShake", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		if cam and os.clock() < shakeUntil and effectsOn() then
			local p = shakePower * (shakeUntil - os.clock())
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * p), math.rad((math.random() - 0.5) * p), 0)
		end
	end)
	local updateWorldPrices
	do
	------------------------------------------------------------------
	-- CLICK-TO-PLACE: while carrying a box, a ghost box follows your mouse
	-- over your own plot floor. Click (or tap) to drop the box right there.
	------------------------------------------------------------------
	local ghost = new("Part", {Name = "PlaceGhost", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.ForceField, Transparency = 0.35, Size = Vector3.new(4, 4, 4)})
	local ghostRing = new("SelectionBox", {LineThickness = 0.08, Color3 = Color3.new(1, 1, 1), Adornee = ghost}, ghost)
	local placeValid, placePos, placeNear = false, nil, false
	local myFloor = nil
	local function findMyFloor()
		local plotName = player:GetAttribute("PlotName")
		local root = workspace:FindFirstChild("StealABox")
		local plots = root and root:FindFirstChild("Plots")
		local plot = plots and plotName and plots:FindFirstChild(plotName)
		myFloor = plot and plot:FindFirstChild("PlotFloor")
		return myFloor
	end
	local function aimAt(screenPos, isTouch)
		local cam = workspace.CurrentCamera
		if not cam or not (myFloor or findMyFloor()) then return nil end
		local ray = isTouch and cam:ScreenPointToRay(screenPos.X, screenPos.Y) or cam:ViewportPointToRay(screenPos.X, screenPos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {myFloor}
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
		return hit and hit.Position
	end
	local function nearEnough(pos)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		return hrp and (hrp.Position - pos).Magnitude <= 85
	end
	-- the server's rules (Config.PlotPlaceSpot): boxes go on the free grass beside your booths, not on
	-- the path, the treadmill or the Expand pad. Returns where the box would really land, or nil.
	local function placeSpot(pos, sz)
		local plot = myFloor and myFloor.Parent
		local origin = plot and plot:FindFirstChild("PlotOrigin")
		if not origin or not Config.PlotPlaceSpot then return pos end
		local lp = origin.CFrame:PointToObjectSpace(pos)
		local u, w = Config.PlotPlaceSpot(lp.X, -lp.Z, sz)
		if not u then return nil end
		return origin.CFrame:PointToWorldSpace(Vector3.new(u, lp.Y, -w))
	end
	RunService.RenderStepped:Connect(function()
		if not player:GetAttribute("Carrying") then
			ghost.Parent = nil
			placeValid, placeNear = false, false
			return
		end
		local pos = aimAt(UserInputService:GetMouseLocation())
		if not pos then
			ghost.Parent = nil
			placeValid, placeNear = false, false
			return
		end
		local sz = player:GetAttribute("CarrySize") or 4
		ghost.Size = Vector3.new(sz, sz, sz)
		local spot = placeSpot(pos, sz)
		local at = spot or pos
		ghost.CFrame = CFrame.new(at + Vector3.new(0, sz / 2 + 0.05, 0)) * CFrame.Angles(0, os.clock() % (math.pi * 2), 0)
		placeNear = nearEnough(pos) == true
		placeValid = placeNear and spot ~= nil
		ghost.Color = placeValid and Color3.fromRGB(90, 255, 110) or Color3.fromRGB(255, 70, 70)
		ghostRing.Color3 = ghost.Color
		placePos = at
		ghost.Parent = workspace
	end)
	player:GetAttributeChangedSignal("PlotName"):Connect(function()
		myFloor = nil
		if updateWorldPrices then updateWorldPrices() end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not player:GetAttribute("Carrying") then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- (a red spot still asks the server, so it can tell you why the box can't go there)
			if placeNear and placePos then PlaceBoxEvent:FireServer(placePos) end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local pos = aimAt(Vector2.new(input.Position.X, input.Position.Y), true)
			if pos and nearEnough(pos) then PlaceBoxEvent:FireServer(placeSpot(pos, player:GetAttribute("CarrySize") or 4) or pos) end
		end
	end)

	local marker = new("BillboardGui", {Name = "BaseMarker", Size = UDim2.fromOffset(150, 38), StudsOffset = Vector3.new(0, -6, 0), AlwaysOnTop = true, Enabled = false, ResetOnSpawn = false}, playerGui)
	text(marker, "YOUR BASE", {TextColor3 = Color3.fromRGB(110, 255, 90), StrokeSize = 3})

	local function updateMarker()
		local plotName = player:GetAttribute("PlotName")
		if not plotName then return end
		local plot = workspace:WaitForChild("StealABox"):WaitForChild("Plots"):WaitForChild(plotName, 10)
		if plot then marker.Adornee = plot:FindFirstChild("TagAnchor") or plot:FindFirstChild("SignBoard") end
	end
	player:GetAttributeChangedSignal("PlotName"):Connect(updateMarker)
	task.spawn(updateMarker)
	-- the "YOUR BASE" marker shows while you carry a box
	local function updateMarkerOn() marker.Enabled = player:GetAttribute("Carrying") ~= nil end
	player:GetAttributeChangedSignal("Carrying"):Connect(updateMarkerOn)
	updateMarkerOn()
	end
	do
	------------------------------------------------------------------
	-- WORLD PRICE TAGS: the Upgrade Shop booth and your treadmill show YOUR level and price
	------------------------------------------------------------------
	updateWorldPrices = function()
		local data = ctx.data
		if not data then return end
		local root = workspace:FindFirstChild("StealABox")
		if not root then return end
		for _, item in ipairs(CollectionService:GetTagged("BoothItem")) do
			local t = Config.GetTrail(item:GetAttribute("TrailId"))
			if t then
				local owned = data.Trails and data.Trails[t.id]
				local equipped = data.Trail == t.id
				local tag = item:FindFirstChild("PriceTag")
				local prompt = item:FindFirstChildOfClass("ProximityPrompt")
				if tag and tag:FindFirstChild("Price") then
					if equipped then
						tag.Price.Text = "EQUIPPED"
						tag.Price.TextColor3 = Color3.fromRGB(120, 220, 255)
					elseif owned then
						tag.Price.Text = "OWNED"
						tag.Price.TextColor3 = WHITE
					else
						tag.Price.Text = "$" .. formatNum(t.price)
						tag.Price.TextColor3 = (data.Cash >= t.price) and MONEY or Color3.fromRGB(255, 90, 80)
					end
				end
				if prompt then prompt.ActionText = equipped and "Equipped" or (owned and "Equip" or ("Buy $" .. formatNum(t.price))) end
			end
		end
		local plotName = player:GetAttribute("PlotName")
		local plots = root:FindFirstChild("Plots")
		local plot = plots and plotName and plots:FindFirstChild(plotName)
		-- a big "Your Plot" label floats over your own plot (only you see it)
		local anchor = plot and plot:FindFirstChild("TagAnchor", true)
		if anchor and not anchor:FindFirstChild("YourPlotTag") then
			local bb = Instance.new("BillboardGui")
			bb.Name = "YourPlotTag"
			bb.Size = UDim2.fromScale(26, 6)
			bb.StudsOffset = Vector3.new(0, 9, 0)
			bb.MaxDistance = 600
			bb.LightInfluence = 0
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = "Your Plot"
			t.TextScaled = true
			t.FontFace = UI.Font
			t.TextColor3 = Color3.new(1, 1, 1)
			local st = Instance.new("UIStroke")
			st.Thickness = 4
			st.Parent = t
			t.Parent = bb
			bb.Parent = anchor
		end
		local kiosk = plot and plot:FindFirstChild("CustomerKiosk", true)
		if kiosk then
			local level = data.Customers or 1
			local kp = kiosk:FindFirstChildOfClass("ProximityPrompt")
			if kp then kp.ActionText = (level >= Config.CustomerMax) and "Maxed" or ("Upgrade $" .. formatNum(Config.CustomerCost(level))) end
		end
		local console = plot and plot:FindFirstChild("TreadConsole", true)
		if console then
			local level = data.Treadmill or 1
			local maxed = level >= Config.Treadmill.max
			local cost = Config.TreadmillCost(level)
			local prompt = console:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.ActionText = maxed and "Maxed" or ("Upgrade $" .. formatNum(cost)) end
			-- the "Speed per Step" row (it replaces the sign's own Level + Rate lines on your screen)
			Signs.tread(console, data)
		end
		-- the Plot Upgrades board at the end of your path
		local ubBoard = plot and plot:FindFirstChild("UpgradeBoard", true)
		if ubBoard then Signs.board(ubBoard, data) end
	end
	ctx.onData(updateWorldPrices)
	ctx.onCash(updateWorldPrices)
	end
	------------------------------------------------------------------
	-- FLING: ragdoll physics + big launch + camera shake + "BONK!"
	------------------------------------------------------------------
	FlingEvent.OnClientEvent:Connect(function(velocity, duration, guardName)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp then return end
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		hrp.AssemblyLinearVelocity = velocity
		hrp.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
		shakeUntil = os.clock() + 0.6
		shakePower = 6 + velocity.Magnitude / 25
		if ctx.flash then ctx.flash(WHITE, 0.2, 0.4) end
		if ctx.bonk then ctx.bonk(guardName == "CRASH" and "CRASH!" or nil) end
		task.delay(duration, function()
			if hum.Parent and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
		end)
	end)
	------------------------------------------------------------------
	-- PARTICLE BURSTS (spawn poof, grab sparkle, stash confetti, bonk stars, wake shockwave)
	------------------------------------------------------------------
	local fxFolder = new("Folder", {Name = "LocalFX"}, workspace)
	local openingFX, reveal3D -- defined further down
	-- hides a box on this screen only (the crate animation replaces it)
	local function hideRealBox(boxPart)
		boxPart.LocalTransparencyModifier = 1
		for _, d in ipairs(boxPart:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
			if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then d.Enabled = false end
			if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("PointLight") then d.Enabled = false end
			if d:IsA("SelectionBox") then d.Visible = false end -- the white outline used to stay behind and glitch
		end
		boxPart:SetAttribute("HiddenLocally", true)
	end
	local openingStart = {} -- [box] = {t0, dur}
	local function burst(pos, count, props)
		local part = new("Part", {Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = CFrame.new(pos)}, fxFolder)
		local e = new("ParticleEmitter", {Enabled = false, SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200)}, part)
		for k, v in pairs(props) do e[k] = v end
		e:Emit(count)
		Debris:AddItem(part, 4)
	end
	local CONFETTI = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 120)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
	})
	FXEvent.OnClientEvent:Connect(function(kind, pos, size, obj, dur)
		if kind == "Opening" then
			openingFX(obj, size, dur)
		elseif kind == "Reveal3D" then
			reveal3D(pos, size, obj)
		elseif kind == "Spawn" then
			burst(pos, 12, {Color = ColorSequence.new(WHITE), LightEmission = 0.5, Size = NumberSequence.new(size * 0.35, 0), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(4, 8), Drag = 5})
		elseif kind == "Grab" then
			burst(pos, 18, {Color = ColorSequence.new(Color3.fromRGB(255, 240, 120)), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(8, 14), Drag = 4})
		elseif kind == "Stash" then
			burst(pos + Vector3.new(0, 2, 0), 60, {Color = CONFETTI, Size = NumberSequence.new(0.5, 0.3), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(20, 32), Acceleration = Vector3.new(0, -30, 0), Drag = 1.5, SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top})
			burst(pos + Vector3.new(0, 1, 0), 20, {Color = ColorSequence.new(Color3.fromRGB(120, 255, 120)), LightEmission = 1, Size = NumberSequence.new(1.2, 0), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(6, 10)})
		elseif kind == "Achievement" then
			-- a secret achievement unlocked: big popup with confetti
			if ctx.thanks then ctx.thanks(tostring(obj or ""), "ACHIEVEMENT!") end
		elseif kind == "StealSuccess" then
			shakeUntil, shakePower = os.clock() + 0.5, 7
			if ctx.stealSuccess then ctx.stealSuccess() end
		elseif kind == "Bonk" then
			burst(pos, 30, {Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), WHITE), LightEmission = 1, Size = NumberSequence.new(1, 0), Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(15, 30), Drag = 3})
		elseif kind == "Unbox" then
			local tier = Config.ItemTiers[size] or Config.ItemTiers[1]
			burst(pos, 60 + size * 25, {Color = ColorSequence.new(tier.color, WHITE), LightEmission = 1, Size = NumberSequence.new(1.4, 0), Lifetime = NumberRange.new(0.6, 1.3), Speed = NumberRange.new(18, 34), Drag = 3})
			burst(pos, 30, {Color = ColorSequence.new(WHITE, tier.color), LightEmission = 1, Size = NumberSequence.new(0.3, 2.5), Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(2, 4)})
			burst(pos, 40, {Color = CONFETTI, Size = NumberSequence.new(0.5, 0.3), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(18, 28), Acceleration = Vector3.new(0, -30, 0), Drag = 1.5, SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top})
		elseif kind == "Sale" then
			burst(pos, 14, {Color = ColorSequence.new(Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 250, 180)), LightEmission = 0.8, Size = NumberSequence.new(0.45, 0.2), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(8, 14), Acceleration = Vector3.new(0, -25, 0), SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top})
		elseif kind == "Take" then
			burst(pos, 10, {Color = ColorSequence.new(WHITE), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4, 8)})
		elseif kind == "Ready" then
			burst(pos, 25, {Color = ColorSequence.new(Color3.fromRGB(255, 240, 120)), LightEmission = 1, Size = NumberSequence.new(0.7, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(6, 12)})
		elseif kind == "TreadUpgrade" then
			-- the treadmill upgrade cutscene: the camera swoops round the treadmill while it powers up
			if ctx.cinematic then ctx.cinematic(pos + Vector3.new(0, 1.5, 0), 2.2, 0.7, 22) end
			burst(pos, 90, {Color = ColorSequence.new(Color3.fromRGB(120, 255, 90), Color3.fromRGB(255, 240, 120)), LightEmission = 1, Size = NumberSequence.new(1.2, 0),
				Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(14, 26), Acceleration = Vector3.new(0, 18, 0), SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top})
			task.delay(0.8, function()
				burst(pos, 70, {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(90, 220, 255)), LightEmission = 1, Size = NumberSequence.new(0.8, 0),
					Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(30, 40), Drag = 5})
				if ctx.thanks then ctx.thanks("TREADMILL UPGRADED!", "LEVEL " .. tostring(size or "")) end
				if ctx.confetti then ctx.confetti(60) end
			end)
		elseif kind == "LevelUp" then
			burst(pos, 60, {Color = ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 255, 200)), LightEmission = 1, Size = NumberSequence.new(1, 0), Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(10, 20), Acceleration = Vector3.new(0, 12, 0)})
		elseif kind == "Wake" then
			burst(pos + Vector3.new(0, 3 * size, 0), 40, {Color = ColorSequence.new(Color3.fromRGB(255, 60, 40)), LightEmission = 1, Size = NumberSequence.new(1.5 * size, 0), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(20, 35), Drag = 4})
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - pos).Magnitude < 70 then
				shakeUntil = os.clock() + 0.4
				shakePower = 3 + size * 2
			end
		end
	end)
	do
	------------------------------------------------------------------
	-- LIVING WORLD: rainbow boxes, snoring Zzz, flickering bulbs, blinking UFO lights
	------------------------------------------------------------------
	local world = workspace:WaitForChild("StealABox")
	local zzzLabels, flickers, blinkers = {}, {}, {}
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Name == "Zzz" then
			local l = d:FindFirstChildOfClass("TextLabel")
			if l then table.insert(zzzLabels, l) end
		elseif d:IsA("BasePart") and d:GetAttribute("Flicker") then
			table.insert(flickers, d)
		elseif d:IsA("BasePart") and d:GetAttribute("Blink") ~= nil then
			table.insert(blinkers, d)
		end
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local hue = Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
		for _, p in ipairs(CollectionService:GetTagged("RainbowBox")) do p.Color = hue end
		-- products on shelves turn slowly
		local camPos = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position
		for _, m in ipairs(CollectionService:GetTagged("ShelfItem")) do
			local base = m:GetAttribute("BaseCF")
			if base and camPos and (base.Position - camPos).Magnitude < 90 then
				m:PivotTo(base * CFrame.Angles(0, t * 0.9, 0) * CFrame.new(0, math.sin(t * 2 + base.Position.X) * 0.12, 0))
			end
		end
		-- trail shop: little orbs fly circles to show off each trail
		for _, orb in ipairs(CollectionService:GetTagged("TrailDemo")) do
			local c = orb:GetAttribute("Center")
			if c and camPos and (c.Position - camPos).Magnitude < 120 then
				local a = t * 3 + (orb:GetAttribute("Phase") or 0)
				orb.CFrame = c * CFrame.new(math.cos(a) * 1.4, math.sin(a * 2) * 0.35, math.sin(a) * 1.4)
				-- the showcase orb cycles through the colours of every trail
				if orb:GetAttribute("Cycle") then
					local idx = math.floor(t / 2.5) % #Config.Trails + 1
					if orb:GetAttribute("ShownTrail") ~= idx then
						orb:SetAttribute("ShownTrail", idx)
						local tr = Config.Trails[idx]
						local trail = orb:FindFirstChildOfClass("Trail")
						if trail then trail.Color = Config.TrailColor(tr) end
						orb.Color = tr.colors[#tr.colors]
						local pl = orb:FindFirstChildOfClass("PointLight")
						if pl then pl.Color = tr.colors[1] end
					end
				end
			end
		end
		-- treadmill belts scroll toward the back
		for _, st in ipairs(CollectionService:GetTagged("TreadStripe")) do
			local start, dir, len = st:GetAttribute("Start"), st:GetAttribute("Dir"), st:GetAttribute("Len")
			if start and dir and len then
				local d = ((st:GetAttribute("Offset") or 0) + t * Config.Treadmill.beltSpeed) % len
				st.CFrame = start + dir * d
			end
		end
		for _, l in ipairs(CollectionService:GetTagged("RainbowText")) do l.TextColor3 = hue end
	end)
	task.spawn(function()
		local frames = {"z", "zZ", "zZz", "ZzZ"}
		local i = 0
		while true do
			i = i + 1
			for _, l in ipairs(zzzLabels) do l.Text = frames[i % #frames + 1] end
			for _, b in ipairs(flickers) do
				local on = math.random() > 0.12
				b.Transparency = on and 0 or 0.8
				local pl = b:FindFirstChildOfClass("PointLight")
				if pl then pl.Enabled = on end
			end
			for _, b in ipairs(blinkers) do
				b.Transparency = ((i + b:GetAttribute("Blink")) % 2 == 0) and 0 or 0.7
			end
			task.wait(0.45)
		end
	end)
	end
	do
	------------------------------------------------------------------
	-- UNBOXING TIMERS on the pads (progress bar + countdown, "OPEN!" when ready)
	------------------------------------------------------------------
	-- only the box you stand closest to shows its NAME above the timer (no piles of names)
	local nearestBox = nil
	task.spawn(function()
		while true do
			task.wait(0.15)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local best, bestD = nil, 22
			if hrp then
				for _, box in ipairs(CollectionService:GetTagged("UnboxingBox")) do
					local d = (box.Position - hrp.Position).Magnitude
					if d < bestD then best, bestD = box, d end
				end
			end
			nearestBox = best
		end
	end)
	RunService.RenderStepped:Connect(function()
		local nowT = workspace:GetServerTimeNow()
		local t = os.clock()
		for _, box in ipairs(CollectionService:GetTagged("UnboxingBox")) do
			local timerBB = box:FindFirstChild("Timer")
			local nameL = timerBB and timerBB:FindFirstChild("Name")
			if nameL then nameL.Visible = (box == nearestBox) end
			-- a box that's being opened (even if the server re-drew it) stays hidden behind the crate
			if box:GetAttribute("Opening") and not box:GetAttribute("HiddenLocally") then hideRealBox(box) end
			local readyAt = box:GetAttribute("ReadyAt") or 0
			local duration = math.max(1, box:GetAttribute("Duration") or 1)
			local bb = box:FindFirstChild("Timer")
			local bar = bb and bb:FindFirstChild("Bar")
			if bar then
				local left = readyAt - nowT
				local progress = math.clamp(1 - left / duration, 0, 1)
				bar.Fill.Size = UDim2.fromScale(progress, 1)
				if left <= 0 then
					bar.Fill.BackgroundColor3 = Color3.fromHSV((t * 0.6) % 1, 0.6, 1)
					bar.Time.Text = openingStart[box] and "OPENING..." or "OPEN!"
				else
					bar.Fill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
					local secs = math.ceil(left)
					bar.Time.Text = (secs >= 60) and (math.floor(secs / 60) .. "m " .. (secs % 60) .. "s") or (secs .. "s")
				end
				-- wobble when it's almost ready / ready
				local base = box:GetAttribute("BaseCF")
				local op = openingStart[box]
				if base and op then
					-- opening: shake harder and harder and lift off the floor
					local a = math.clamp((t - op[1]) / op[2], 0, 1)
					local amt = 0.05 + a * a * 0.35
					box.CFrame = base * CFrame.new((math.random() - 0.5) * a * 0.6, a * 1.5 + math.abs(math.sin(t * 30)) * a * 0.4, (math.random() - 0.5) * a * 0.6)
						* CFrame.Angles(math.sin(t * 41) * amt, t * a * 8, math.sin(t * 37) * amt)
				elseif base then
					local amount = (left <= 0) and 0.12 or ((left < 5) and 0.06 or 0)
					box.CFrame = base * CFrame.Angles(0, 0, math.sin(t * 25) * amount) * CFrame.new(0, (left <= 0) and math.abs(math.sin(t * 4)) * 0.4 or 0, 0)
				end
			end
		end
		for _, icon in ipairs(CollectionService:GetTagged("FloatingIcon")) do
			icon.Position = UDim2.fromScale(0.5, 0.04 + math.sin(t * 2 + icon.AbsolutePosition.X * 0.01) * 0.04)
		end
	end)
	end
	------------------------------------------------------------------
	-- BOX OPENING (in the world): your box becomes a real crate that charges up. The better
	-- the item inside, the longer and crazier it gets: the light climbs through the rarities one
	-- by one (white -> green -> blue -> gold, + the mutation colour) with a flash, a shockwave,
	-- a floating "RARE!" and a higher "ding" at every step. Then the lid bursts open, the walls
	-- fall outward and the item rises out.
	------------------------------------------------------------------
	do -- (own scope: keeps the main script under Roblox's 200-local limit)
	local NORMAL_FOV = 70
	local function fxPart(props, parent)
		local p = new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Material = Enum.Material.Neon, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth})
		for k, v in pairs(props) do p[k] = v end
		p.Parent = parent
		return p
	end

	-- screen effects for YOUR big unboxings: a coloured glow around the screen + cinematic black bars
	local screenFX = {}
	do
		local edgeHolder = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 44}, UI.under)
		local glowEdges = {}
		for i, cfg in ipairs({{UDim2.new(1, 0, 0.28, 0), UDim2.fromScale(0, 0), 90}, {UDim2.new(1, 0, 0.28, 0), UDim2.fromScale(0, 0.72), -90},
			{UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(0, 0), 0}, {UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(0.78, 0), 180}}) do
			local f = new("Frame", {Size = cfg[1], Position = cfg[2], BackgroundColor3 = WHITE, BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 44}, edgeHolder)
			new("UIGradient", {Rotation = cfg[3], Transparency = NumberSequence.new(0, 1)}, f)
			glowEdges[i] = f
		end
		local barTop = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 0, -40), Size = UDim2.new(1, 0, 0.12, 40), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 46, Visible = false}, UI.over)
		local barBot = new("Frame", {AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.12, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 46, Visible = false}, UI.over)
		local barsToken = 0
		function screenFX.edge(color, amount)
			edgeHolder.Visible = amount > 0.01
			for _, f in ipairs(glowEdges) do
				f.BackgroundColor3 = color
				f.BackgroundTransparency = 1 - math.clamp(amount, 0, 1) * 0.8
			end
		end
		function screenFX.bars(on)
			if on and not effectsOn() then return end
			barsToken = barsToken + 1
			local tok = barsToken
			if on then
				barTop.Visible, barBot.Visible = true, true
				TweenService:Create(barTop, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0.12, 0)}):Play()
				TweenService:Create(barBot, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.fromScale(0, 0.88)}):Play()
			else
				TweenService:Create(barTop, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, -40)}):Play()
				TweenService:Create(barBot, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.fromScale(0, 1)}):Play()
				task.delay(0.5, function()
					if tok == barsToken then barTop.Visible, barBot.Visible = false, false end
				end)
			end
		end
	end

	-- EXTRA EPIC: a glowing energy box that GROWS in rainbow colours, lightning from the sky
	-- (more bolts for better items), then a rainbow over the box and an RGB explosion
	local RAINBOW = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 160, 40)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 60)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 230, 90)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 255))})
	local BANDS = {Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 240, 60), Color3.fromRGB(80, 230, 90),
		Color3.fromRGB(60, 150, 255), Color3.fromRGB(110, 80, 255), Color3.fromRGB(180, 90, 255)}
	local function lightning(from, to, parent)
		local pts, n = {from}, 7
		for k = 1, n - 1 do
			local p = from:Lerp(to, k / n)
			table.insert(pts, p + Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 6))
		end
		table.insert(pts, to)
		local last
		for k = 1, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			last = fxPart({Size = Vector3.new(0.45, 0.45, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = Color3.fromRGB(210, 235, 255)}, parent)
		end
		if last then new("PointLight", {Range = 40, Brightness = 8, Color = Color3.fromRGB(190, 220, 255), Shadows = false}, last) end
	end
	local function epicOpening(center, sz, tier, dur, isMine)
		local fx = new("Folder", {Name = "EpicFX"}, fxFolder)
		Debris:AddItem(fx, dur + 3.5)
		-- the energy box grows around the crate
		local energy = fxPart({Name = "Energy", Size = Vector3.one * sz * 1.15, CFrame = CFrame.new(center), Transparency = 0.75}, fx)
		TweenService:Create(energy, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.one * sz * (2 + tier * 0.45)}):Play()
		task.spawn(function()
			local t0 = os.clock()
			while energy.Parent and os.clock() - t0 < dur do
				energy.Color = Color3.fromHSV(((os.clock() - t0) * 1.6) % 1, 0.8, 1)
				energy.CFrame = CFrame.new(center) * CFrame.Angles(0, (os.clock() - t0) * 2, 0)
				task.wait(0.05)
			end
			energy:Destroy()
		end)
		-- lightning bolts from the sky
		local strikes = tier + 1
		for k = 1, strikes do
			task.delay(dur * (k / (strikes + 0.5)), function()
				if not fx.Parent then return end
				local bolt = new("Folder", {}, fx)
				lightning(center + Vector3.new((math.random() - 0.5) * 20, 90, (math.random() - 0.5) * 20), center + Vector3.new(0, sz * 0.6, 0), bolt)
				burst(center + Vector3.new(0, sz * 0.6, 0), 20, {Color = ColorSequence.new(Color3.fromRGB(200, 230, 255), WHITE), LightEmission = 1,
					Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(10, 20)})
				if isMine and ctx.flash and effectsOn() then ctx.flash(Color3.fromRGB(220, 235, 255), 0.6, 0.25) end
				Debris:AddItem(bolt, 0.18)
			end)
		end
		-- the reveal: an RGB explosion and a rainbow over the box
		task.delay(dur, function()
			if not fx.Parent then return end
			burst(center, 90 + tier * 30, {Color = RAINBOW, LightEmission = 1, Size = NumberSequence.new(1.2, 0), Lifetime = NumberRange.new(0.6, 1.3),
				Speed = NumberRange.new(25, 45), Drag = 3})
			for i, col in ipairs({Color3.fromRGB(255, 50, 50), Color3.fromRGB(50, 255, 80), Color3.fromRGB(60, 120, 255)}) do
				local ring = fxPart({Shape = Enum.PartType.Ball, Size = Vector3.one * sz, CFrame = CFrame.new(center), Color = col, Transparency = 0.4}, fx)
				TweenService:Create(ring, TweenInfo.new(0.5 + i * 0.15, Enum.EasingStyle.Quad), {Size = Vector3.one * sz * (6 + i * 2), Transparency = 1}):Play()
			end
			local arc = new("Folder", {Name = "Rainbow"}, fx)
			for b, col in ipairs(BANDS) do
				local r = sz * 2.2 + (b - 1) * 0.7
				for k = 0, 10 do
					local a = math.pi * k / 10
					local pos = center + Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)
					fxPart({Size = Vector3.new(0.7, 0.7, 0.7) * (1 + r * 0.02) + Vector3.new(r * 0.28, 0, 0), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, a + math.pi / 2),
						Color = col, Transparency = 0.15}, arc)
				end
			end
			Debris:AddItem(arc, 2.8)
		end)
	end

	openingFX = function(boxPart, tier, dur)
		if typeof(boxPart) ~= "Instance" or not boxPart.Parent then return end
		dur = dur or 2.2
		tier = math.clamp(tonumber(tier) or 1, 1, #Config.ItemTiers)
		local isMine = boxPart:GetAttribute("Owner") == player.UserId
		local mutId = boxPart:GetAttribute("OpenMutation")
		local mut = mutId and Config.GetMutation(mutId)
		-- the rarity climbs stage by stage
		local stages = {}
		for k = 1, tier do
			local td = Config.ItemTiers[k]
			table.insert(stages, {col = td.color, name = string.upper(td.name)})
		end
		if mut and mut.id ~= "Normal" and mut.color then table.insert(stages, {col = mut.color, name = string.upper(mut.id)}) end
		local nStages = #stages
		local finalCol = stages[nStages].col
		local epic = tier >= 3 or nStages > tier
		local sz = boxPart.Size.X
		local baseCF = boxPart:GetAttribute("BaseCF") or boxPart.CFrame
		local center = baseCF.Position
		local ground = center - Vector3.new(0, sz / 2 - 0.1, 0)
		local boxCol = boxPart.Color
		local lidCol = boxCol:Lerp(Color3.new(0, 0, 0), 0.25)
		-- the printed labels of the real box go onto the crate's walls
		local prints = {}
		for _, d in ipairs(boxPart:GetChildren()) do
			if d:IsA("SurfaceGui") and d.Name == "Print" then table.insert(prints, d) end
		end
		-- hide the real box (only on this screen) and swap in a crate that can open
		hideRealBox(boxPart)
		openingStart[boxPart] = {os.clock(), dur}
		epicOpening(center, sz, tier, dur, isMine)

		local holder = new("Folder", {Name = "OpeningFX"}, fxFolder)
		local th = sz * 0.07
		local function slab(name, size, color, mat)
			local p = fxPart({Name = name, Size = size, Color = color, Material = mat or Enum.Material.SmoothPlastic, CastShadow = true}, holder)
			new("SelectionBox", {Adornee = p, Color3 = WHITE, LineThickness = 0.04, SurfaceTransparency = 1}, p)
			return p
		end
		local bottom = slab("Bottom", Vector3.new(sz, th, sz), boxCol)
		-- walls: {part, hinge offset, axis, outward sign}
		local walls = {
			{slab("Front", Vector3.new(sz, sz, th), boxCol), Vector3.new(0, -sz / 2, -sz / 2 + th / 2), "x", -1},
			{slab("Back", Vector3.new(sz, sz, th), boxCol), Vector3.new(0, -sz / 2, sz / 2 - th / 2), "x", 1},
			{slab("Left", Vector3.new(th, sz, sz), boxCol), Vector3.new(-sz / 2 + th / 2, -sz / 2, 0), "z", 1},
			{slab("Right", Vector3.new(th, sz, sz), boxCol), Vector3.new(sz / 2 - th / 2, -sz / 2, 0), "z", -1},
		}
		local FACES = {Front = Enum.NormalId.Front, Back = Enum.NormalId.Back, Left = Enum.NormalId.Left, Right = Enum.NormalId.Right}
		for _, w in ipairs(walls) do
			for _, pr in ipairs(prints) do
				if pr.Face == FACES[w[1].Name] then
					local c = pr:Clone()
					c.Enabled = true
					c.Parent = w[1]
				end
			end
		end
		-- two lid flaps with tape that rip open
		local flaps = {
			{slab("FlapL", Vector3.new(sz / 2 + th * 0.3, th * 1.2, sz * 1.03), lidCol), Vector3.new(-sz / 2, sz / 2, 0), 1},
			{slab("FlapR", Vector3.new(sz / 2 + th * 0.3, th * 1.2, sz * 1.03), lidCol), Vector3.new(sz / 2, sz / 2, 0), -1},
		}
		local tapeL = slab("TapeL", Vector3.new(sz * 0.12, th * 1.3, sz * 1.05), Color3.fromRGB(215, 175, 115))
		local tapeR = slab("TapeR", Vector3.new(sz * 0.12, th * 1.3, sz * 1.05), Color3.fromRGB(215, 175, 115))
		-- light glowing through the seams, and a bright core inside
		local seam = fxPart({Name = "Seam", Size = Vector3.new(th * 0.6, th * 0.5, sz * 0.98), Color = stages[1].col, Transparency = 1}, holder)
		local rimGlow = {}
		for i = 1, 4 do rimGlow[i] = fxPart({Name = "RimGlow", Size = Vector3.new(sz * 0.98, th * 0.4, th * 0.4), Color = stages[1].col, Transparency = 1}, holder) end
		local core = fxPart({Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * sz * 0.5, Color = WHITE, Transparency = 1, CFrame = baseCF}, holder)
		local light = new("PointLight", {Range = 2, Brightness = 5, Color = stages[1].col, Shadows = false}, core)
		local spill = new("ParticleEmitter", {Rate = 0, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(stages[1].col, WHITE),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0)}), Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(10, 60), EmissionDirection = Enum.NormalId.Top}, seam)
		-- energy gets sucked into the box from all around (charging up)
		local gather = fxPart({Transparency = 1, Size = Vector3.new(1, 1, 1) * sz * 4, CFrame = CFrame.new(center)}, holder)
		local suck = new("ParticleEmitter", {Rate = 0, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(WHITE, stages[1].col),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new(0.2, 0), Lifetime = NumberRange.new(0.45, 0.6), Speed = NumberRange.new(sz * 3.5, sz * 4.5),
			Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward}, gather)
		local ring = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, sz, sz), Color = stages[1].col, Transparency = 0.5}, holder)
		local aura = fxPart({Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * sz * 1.8, Color = stages[1].col, Transparency = 1}, holder)
		local sparks = {}
		for i = 1, 4 + nStages * 2 do sparks[i] = fxPart({Size = Vector3.new(0.08, 0.08, sz * 0.5), Color = WHITE, Transparency = 1}, holder) end
		local cracks = {}
		for i = 1, 6 + nStages do cracks[i] = {fxPart({Size = Vector3.new(0.2, 0.06, 1), Color = stages[1].col, Transparency = 1}, holder), (i / (6 + nStages)) * math.pi * 2 + math.random() * 0.4} end
		local pillar = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, sz * 0.4, sz * 0.4), Color = stages[1].col, Transparency = 1}, holder)
		-- the charge bar above the crate shows the rarity it has reached
		local chargeBB = new("BillboardGui", {Size = UDim2.fromOffset(170, 38), StudsOffset = Vector3.new(0, sz * 0.5 + 2.6, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 80}, core)
		local chargeText = text(chargeBB, "OPENING...", {Size = UDim2.new(1, 0, 0, 20), TextColor3 = WHITE, StrokeSize = 2})
		local chargeBack = new("Frame", {Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 11), BackgroundColor3 = CARD_DARK}, chargeBB)
		corner(chargeBack, 5)
		local chargeFill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = stages[1].col}, chargeBack)
		corner(chargeFill, 5)
		-- one notch on the bar per rarity step
		for k = 1, nStages - 1 do
			new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(k / nStages, 0, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 2}, chargeBack)
		end

		local OPEN_AT = dur - 0.35 -- flaps burst open, then the walls fall outward
		local stageIdx, stageStart = 0, 0
		local function stageFor(a) return math.clamp(math.floor(a * nStages * 0.97) + 1, 1, nStages) end
		local function onStage(k)
			local st = stages[k]
			burst(center + Vector3.new(0, sz * 0.4, 0), 14 + k * 8, {Color = ColorSequence.new(st.col, WHITE), LightEmission = 1, Size = NumberSequence.new(0.5 + k * 0.12, 0),
				Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(10, 18 + k * 4), Drag = 4})
			local wave = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, sz, sz), Color = st.col, Transparency = 0.2, CFrame = CFrame.new(ground + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))}, fxFolder)
			TweenService:Create(wave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.12, sz * (3 + k), sz * (3 + k)), Transparency = 1}):Play()
			Debris:AddItem(wave, 0.5)
			-- the rarity word floats up out of the crate
			local wordBB = new("BillboardGui", {Size = UDim2.fromOffset(260, 54), StudsOffset = Vector3.new(0, sz * 0.5 + 4.5, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 100}, core)
			local wl = text(wordBB, st.name .. "!", {TextColor3 = st.col, StrokeSize = 3})
			local ws = new("UIScale", {Scale = 0.3}, wl)
			TweenService:Create(ws, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = (k == nStages) and 1.35 or 1}):Play()
			TweenService:Create(wordBB, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffset = Vector3.new(0, sz * 0.5 + 7.5, 0)}):Play()
			task.delay(0.55, function()
				if not wl.Parent then return end
				TweenService:Create(wl, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
				local stroke = wl:FindFirstChildOfClass("UIStroke")
				if stroke then TweenService:Create(stroke, TweenInfo.new(0.35), {Transparency = 1}):Play() end
			end)
			Debris:AddItem(wordBB, 1)
			SFX.play("ding", 0.7 + k * 0.22, 0.3 + k * 0.08)
			if isMine and k > 1 then
				shakeUntil = os.clock() + 0.22 + k * 0.04
				shakePower = 1.5 + k * 1.2
			end
		end
		if isMine and epic and effectsOn() then
			-- CUTSCENE: black bars + the camera swoops in and circles the box until the item is out
			screenFX.bars(true)
			if ctx.cinematic then ctx.cinematic(center + Vector3.new(0, sz + 2.5, 0), dur + Config.RevealTime(tier) - 0.5, 0.7, 12 + sz * 2) end
			local cam = workspace.CurrentCamera
			if cam then TweenService:Create(cam, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FieldOfView = NORMAL_FOV - 8 - nStages * 2}):Play() end
		end

		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local t = now - t0
			if not holder.Parent or t > dur + 1.4 then
				conn:Disconnect()
				holder:Destroy()
				openingStart[boxPart] = nil
				return
			end
			local a = math.clamp(t / OPEN_AT, 0, 1)
			local e = a * a
			-- climb through the rarities
			if t < OPEN_AT then
				local k = stageFor(a)
				if k ~= stageIdx then
					stageIdx, stageStart = k, t
					onStage(k)
				end
			end
			local col = (t < OPEN_AT) and stages[math.max(1, stageIdx)].col or finalCol
			local flashK = math.clamp(1 - (t - stageStart) / 0.2, 0, 1)
			if t < OPEN_AT and flashK > 0 then col = col:Lerp(WHITE, flashK * 0.7) end
			-- the crate: shakes harder and harder (more for better items), then settles when it opens
			local shake = (t < OPEN_AT) and (0.04 + e * (0.16 + nStages * 0.03)) or 0
			local hop = (t < OPEN_AT) and math.abs(math.sin(t * (8 + e * 22))) * sz * 0.08 * e or 0
			local root = baseCF * CFrame.new(0, hop + (epic and e * sz * 0.25 or 0), 0) * CFrame.Angles(math.sin(now * 37) * shake, math.sin(now * 23) * shake * 0.5, math.sin(now * 41) * shake)
			bottom.CFrame = root * CFrame.new(0, -sz / 2 + th / 2, 0)
			local open = math.clamp((t - OPEN_AT) / 0.3, 0, 1)
			local fall = math.clamp((t - OPEN_AT - 0.15) / 0.45, 0, 1)
			local fallE = 1 - (1 - fall) ^ 3
			for _, w in ipairs(walls) do
				local part, hinge, axis, sign = w[1], w[2], w[3], w[4]
				local ang = math.rad(95) * fallE
				local rot = (axis == "x") and CFrame.Angles(sign * ang, 0, 0) or CFrame.Angles(0, 0, sign * ang)
				part.CFrame = root * CFrame.new(hinge) * rot * CFrame.new(0, sz / 2, 0)
				part.Transparency = math.clamp((t - dur - 0.4) / 0.9, 0, 1)
			end
			local rattle = (t < OPEN_AT) and math.abs(math.sin(now * 30)) * math.rad(10 + nStages * 3) * e or 0
			local flapAng = rattle + math.rad(200) * (1 - (1 - open) ^ 2)
			for i, f in ipairs(flaps) do
				local part, hinge, sign = f[1], f[2], f[3]
				local cf = root * CFrame.new(hinge) * CFrame.Angles(0, 0, sign * flapAng) * CFrame.new(-sign * -1 * (sz / 4), th * 0.6, 0)
				part.CFrame = cf
				part.Transparency = math.clamp((t - dur - 0.4) / 0.9, 0, 1)
				local tape = (i == 1) and tapeL or tapeR
				tape.CFrame = cf * CFrame.new(-sign * -1 * (sz / 4 - sz * 0.06), th * 0.1, 0)
				tape.Transparency = part.Transparency
			end
			seam.CFrame = root * CFrame.new(0, sz / 2 + th * 0.3, 0)
			seam.Color = col
			seam.Transparency = (t < OPEN_AT) and (1 - e * 0.9) or 1
			spill.Rate = (t < OPEN_AT) and (e * (40 + nStages * 15)) or 0
			spill.Color = ColorSequence.new(col, WHITE)
			for i, g in ipairs(rimGlow) do
				local yaw = (i - 1) * math.pi / 2
				g.CFrame = root * CFrame.Angles(0, yaw, 0) * CFrame.new(0, sz / 2 - th * 0.2, -sz / 2 + th * 0.1)
				g.Color = col
				g.Transparency = (t < OPEN_AT) and (1 - e * 0.85) or 1
			end
			core.CFrame = root
			core.Color = col:Lerp(WHITE, 0.5)
			core.Transparency = (t < OPEN_AT) and 1 or math.clamp(0.1 + (t - OPEN_AT) * 1.5, 0, 1)
			light.Range = 4 + e * (14 + nStages * 4) + ((t >= OPEN_AT) and 10 or 0)
			light.Color = col
			suck.Rate = (t < OPEN_AT) and (30 + a * (100 + nStages * 30)) or 0
			suck.Color = ColorSequence.new(WHITE, col)
			local r = sz * (1.1 + e * (2 + nStages * 0.4))
			ring.Size = Vector3.new(0.12, r, r)
			ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, now * 2, math.rad(90))
			ring.Color = col
			ring.Transparency = (t < dur) and 0.45 or math.clamp(0.45 + (t - dur), 0, 1)
			local beat = (t < OPEN_AT) and (0.5 + 0.5 * math.sin(now * (6 + e * 20))) or 0
			aura.CFrame = root
			aura.Color = col
			aura.Size = Vector3.new(1, 1, 1) * sz * (1.5 + beat * 0.35 * e)
			aura.Transparency = (t < OPEN_AT) and (0.92 - beat * 0.12 * e) or 1
			for _, sp in ipairs(sparks) do
				if t < OPEN_AT and math.random() < 0.25 + e * 0.5 then
					local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
					local p = center + dir * sz * 0.75
					sp.CFrame = CFrame.lookAt(p, p + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5))
					sp.Color = (math.random() < 0.5) and WHITE or col
					sp.Transparency = 0
				else
					sp.Transparency = 1
				end
			end
			for _, ck in ipairs(cracks) do
				local len = sz * (0.4 + e * (1.2 + nStages * 0.25))
				local dir = Vector3.new(math.cos(ck[2]), 0, math.sin(ck[2]))
				local p = ground + Vector3.new(0, 0.06, 0) + dir * (sz * 0.55 + len / 2)
				ck[1].CFrame = CFrame.lookAt(p, p + dir)
				ck[1].Size = Vector3.new(0.18 + e * 0.12, 0.06, len)
				ck[1].Color = col
				ck[1].Transparency = (t < OPEN_AT) and (1 - e * 0.85) or math.clamp(0.15 + (t - OPEN_AT) * 1.2, 0, 1)
			end
			local maxH = 20 + nStages * 14
			local ph = (t < OPEN_AT) and (2 + e * maxH) or (maxH + 4)
			local pw = (t < OPEN_AT) and sz * (0.15 + e * 0.2) or sz * (0.35 + math.clamp((t - OPEN_AT) * 3, 0, 1) * (0.6 + nStages * 0.15))
			pillar.Size = Vector3.new(ph, pw, pw)
			pillar.CFrame = CFrame.new(ground + Vector3.new(0, ph / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			pillar.Color = col
			pillar.Transparency = (t < OPEN_AT) and (1 - e * 0.55) or math.clamp(0.45 + (t - OPEN_AT) * 0.8, 0, 1)
			chargeFill.Size = UDim2.fromScale(a, 1)
			chargeFill.BackgroundColor3 = col
			chargeBB.Enabled = t < OPEN_AT
			chargeBB.StudsOffset = Vector3.new(math.sin(now * 40) * 0.08 * e, sz * 0.5 + 2.6, 0)
			chargeText.Text = (stageIdx > 0 and stages[stageIdx].name or "OPENING") .. ((a > 0.85) and "!!!" or "...")
			chargeText.TextColor3 = col:Lerp(WHITE, 0.3)
			if isMine and epic and effectsOn() then screenFX.edge(col, (t < OPEN_AT) and (e * 0.85 + beat * 0.15 * e) or math.clamp(1 - (t - OPEN_AT) * 2, 0, 1)) end
		end)
		-- when it bursts: white flash, shockwaves, debris and a camera shake (bigger for better items)
		task.delay(OPEN_AT, function()
			for k = 1, 1 + math.min(nStages, 3) do
				local wave = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, sz, sz), Color = (k == 1) and WHITE or stages[math.min(k, nStages)].col, Transparency = 0.15,
					CFrame = CFrame.new(ground + Vector3.new(0, 0.1 * k, 0)) * CFrame.Angles(0, 0, math.rad(90))}, fxFolder)
				TweenService:Create(wave, TweenInfo.new(0.45 + k * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.15, sz * (6 + k * 4), sz * (6 + k * 4)), Transparency = 1}):Play()
				Debris:AddItem(wave, 1.3)
			end
			burst(center, 30 + nStages * 15, {Color = ColorSequence.new(WHITE, finalCol), LightEmission = 1, Size = NumberSequence.new(0.6 + nStages * 0.1, 0), Lifetime = NumberRange.new(0.4, 0.9),
				Speed = NumberRange.new(20, 30 + nStages * 6), Drag = 4})
			if epic then
				burst(center + Vector3.new(0, sz, 0), 40 + nStages * 20, {Color = CONFETTI, Size = NumberSequence.new(0.6, 0.35), Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(24, 40),
					Acceleration = Vector3.new(0, -32, 0), Drag = 1.2, SpreadAngle = Vector2.new(45, 45), EmissionDirection = Enum.NormalId.Top})
			end
			if isMine then
				local white = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = epic and finalCol:Lerp(WHITE, 0.5) or WHITE, BackgroundTransparency = epic and 0.1 or 0.35, ZIndex = 60}, UI.over)
				TweenService:Create(white, TweenInfo.new(epic and 0.6 or 0.35), {BackgroundTransparency = 1}):Play()
				Debris:AddItem(white, 0.7)
			end
			local flashBall = fxPart({Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * sz, Color = WHITE, Transparency = 0.1, CFrame = CFrame.new(center)}, fxFolder)
			TweenService:Create(flashBall, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(1, 1, 1) * sz * (4 + nStages), Transparency = 1}):Play()
			Debris:AddItem(flashBall, 0.45)
			burst(center + Vector3.new(0, sz / 2, 0), 24, {Color = ColorSequence.new(Color3.fromRGB(215, 175, 115), boxCol), Size = NumberSequence.new(0.35, 0.2),
				Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(10, 18), Acceleration = Vector3.new(0, -35, 0), SpreadAngle = Vector2.new(50, 50), EmissionDirection = Enum.NormalId.Top})
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - center).Magnitude < 60 then
				shakeUntil = os.clock() + 0.3 + nStages * 0.06
				shakePower = 2.5 + nStages * 1.4
			end
			SFX.play("ding", epic and 1.9 or 1.4, epic and 0.9 or 0.6)
		end)
		-- safety: the cinematic bars always go away again
		if isMine and epic then
			task.delay(dur + Config.RevealTime(tier) + 1.5, function() screenFX.bars(false) end)
		end
	end
	------------------------------------------------------------------
	-- 3D REVEAL: the item pops out of the box as a real 3D model, spins fast, hovers in a beam
	-- of light with sparkles and a name tag, then flies onto its shelf slot (or into your
	-- backpack). Better items hover longer and get more: light rays, a sky beam, golden rain,
	-- and (for YOUR rare finds) the camera swoops in for a close look.
	------------------------------------------------------------------
	local function easeOutBack(x)
		local c1, c3 = 1.70158, 2.70158
		return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	end
	local function easeInOut(x) return x < 0.5 and 2 * x * x or 1 - (-2 * x + 2) ^ 2 / 2 end
	local cinematicBusy = false

	-- the camera swoops in to look at the item, holds, and swoops back
	local function cinematic(focus, hold, spin, dist)
		spin, dist = spin or 0.25, dist or 13
		local cam = workspace.CurrentCamera
		if cinematicBusy or not cam or not effectsOn() then return end
		cinematicBusy = true
		local startCF = cam.CFrame
		local away = startCF.Position - focus
		away = Vector3.new(away.X, 0, away.Z)
		away = (away.Magnitude > 0.1) and away.Unit or Vector3.new(0, 0, 1)
		local eye = focus + away * dist + Vector3.new(0, 3.5, 0)
		cam.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(cam, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CFrame = CFrame.lookAt(eye, focus)}):Play()
		-- a slow orbit while it holds
		local t0 = os.clock()
		local conn
		task.delay(0.7, function()
			conn = RunService.RenderStepped:Connect(function()
				local k = os.clock() - t0 - 0.7
				local rot = CFrame.Angles(0, k * spin, 0)
				local p = focus + rot:VectorToWorldSpace(away * dist) + Vector3.new(0, 3.5, 0)
				cam.CFrame = CFrame.lookAt(p, focus)
			end)
		end)
		task.delay(0.7 + hold, function()
			if conn then conn:Disconnect() end
			TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {CFrame = startCF}):Play()
			task.delay(0.62, function()
				cam.CameraType = Enum.CameraType.Custom
				cinematicBusy = false
			end)
		end)
	end

	ctx.cinematic = cinematic

	reveal3D = function(pos, tier, info)
		if type(info) ~= "table" or not info.item then return end
		local item = info.item
		local def = Config.Items[item.id]
		if not def then return end
		local tierCol = (Config.ItemTiers[def.tier] or Config.ItemTiers[1]).color
		local mut = Config.GetMutation(item.mutation)
		local glow = mut.color or tierCol
		local special = mut.id ~= "Normal"
		local epic = def.tier >= 3 or special
		local big = math.clamp(2.6 * math.sqrt(Config.GetSize(item.size).scale), 2, 3.8) * (1 + (def.tier - 1) * 0.1)
		local isMine = info.owner == player.UserId
		local ground = pos - Vector3.new(0, 1.5, 0)
		local hover = pos + Vector3.new(0, 2.6 + big, 0)

		local holder = new("Folder", {Name = "Reveal3D"}, fxFolder)
		local model, list = Config.BuildItemModel(item, 0.01, CFrame.new(pos))
		model.Parent = holder
		local rainbow = item.mutation == "Rainbow"
		local hl = new("Highlight", {FillColor = glow, FillTransparency = 0.2, OutlineColor = WHITE, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded}, model)
		local anchor = fxPart({Transparency = 1, Size = Vector3.new(1, 1, 1) * big * 2, CFrame = CFrame.new(pos)}, holder)
		local light = new("PointLight", {Color = glow, Brightness = 4 + def.tier, Range = 18, Shadows = false}, anchor)
		new("ParticleEmitter", {Rate = 18 + def.tier * 10, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(glow, WHITE),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0)}),
			Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(1.5, 3.5), Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200)}, anchor)
		local pillar = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(26, 1.1 * big, 1.1 * big), Color = glow, Transparency = 0.75,
			CFrame = CFrame.new(ground + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90))}, holder)
		-- legendary / mutated: a beam of light all the way up into the sky
		local skyBeam = nil
		if def.tier >= 4 or special then
			skyBeam = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(400, big * 0.8, big * 0.8), Color = glow, Transparency = 0.3,
				CFrame = CFrame.new(ground + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90))}, holder)
		end
		local ring = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, big * 3, big * 3), Color = glow, Transparency = 0.35}, holder)
		local orbiters = {}
		for i = 1, 2 + def.tier do
			local o = fxPart({Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = (i % 2 == 0) and WHITE or glow}, holder)
			local a0 = new("Attachment", {Position = Vector3.new(0, 0.15, 0)}, o)
			local a1 = new("Attachment", {Position = Vector3.new(0, -0.15, 0)}, o)
			new("Trail", {Attachment0 = a0, Attachment1 = a1, Lifetime = 0.35, LightEmission = 1, Color = ColorSequence.new(glow, WHITE),
				Transparency = NumberSequence.new(0.1, 1), FaceCamera = true}, o)
			orbiters[i] = o
		end
		local rays = {}
		if epic then
			for i = 1, 4 + def.tier * 2 do rays[i] = fxPart({Size = Vector3.new(0.35, 0.35, 1), Color = glow, Transparency = 0.6}, holder) end
		end
		-- name tag
		local tag = new("BillboardGui", {Size = UDim2.fromOffset(240, 80), StudsOffset = Vector3.new(0, big * 1.3 + 1.2, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 140}, anchor)
		local tagScale = new("UIScale", {Scale = 0}, tag)
		local t1 = text(tag, string.upper((Config.ItemTiers[def.tier] or Config.ItemTiers[1]).name), {Size = UDim2.new(1, 0, 0, 26), TextColor3 = WHITE, StrokeSize = 2.2})
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(WHITE, tierCol)}, t1)
		text(tag, Config.ItemLabel(item), {Size = UDim2.new(1, 0, 0, 25), Position = UDim2.fromOffset(0, 27), TextColor3 = mut.color or WHITE, StrokeSize = 2})
		local inc = text(tag, "$" .. formatNum(Config.ItemIncome(item)) .. "/s", {Size = UDim2.new(1, 0, 0, 23), Position = UDim2.fromOffset(0, 54), TextColor3 = MONEY, StrokeSize = 2})
		inc.FontFace = NUMBER_FONT

		-- the pop: confetti, flash and a shockwave
		burst(pos, 50 + def.tier * 25, {Color = ColorSequence.new(glow, WHITE), LightEmission = 1, Size = NumberSequence.new(1.1, 0), Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(16, 30), Drag = 3})
		burst(pos, 40 + def.tier * 10, {Color = CONFETTI, Size = NumberSequence.new(0.45, 0.3), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(16, 26), Acceleration = Vector3.new(0, -30, 0), Drag = 1.5, SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top})
		local shock = fxPart({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2, 2), Color = glow, Transparency = 0.2, CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))}, fxFolder)
		TweenService:Create(shock, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.2, 34 + def.tier * 6, 34 + def.tier * 6), Transparency = 1}):Play()
		Debris:AddItem(shock, 0.7)
		TweenService:Create(tagScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), {Scale = epic and 1.15 or 1}):Play()
		-- legendary: golden rain from above, three times
		if def.tier >= 4 or special then
			for k = 0, 2 do
				task.delay(0.4 + k * 0.7, function()
					burst(hover + Vector3.new(0, 10, 0), 40, {Color = ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 250, 200)), LightEmission = 0.8,
						Size = NumberSequence.new(0.5, 0.3), Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(2, 6), Acceleration = Vector3.new(0, -14, 0),
						SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Bottom})
				end)
			end
		end

		local hold = Config.RevealHold[def.tier] or 2.4
		local RISE, FLY = 0.55, 0.8
		local FLY_AT = RISE + hold
		local cam = workspace.CurrentCamera
		if isMine and cam then
			if epic then
				cinematic(hover, math.max(0.6, hold - 0.9))
			else
				TweenService:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {FieldOfView = NORMAL_FOV - 10}):Play()
			end
			task.delay(FLY_AT - 0.2, function()
				TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {FieldOfView = NORMAL_FOV}):Play()
				screenFX.bars(false)
				screenFX.edge(glow, 0)
			end)
		end

		local target = typeof(info.target) == "CFrame" and info.target or nil
		local targetScale = info.targetScale or 1
		local t0 = os.clock()
		local spin = 0
		local last = t0
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local dt = now - last
			last = now
			local t = now - t0
			if not holder.Parent then conn:Disconnect() return end
			spin = spin + (2.2 + 26 * math.exp(-t * 2.4)) * dt
			local p, scale
			if t < RISE then
				local k = easeOutBack(t / RISE)
				p = pos:Lerp(hover, math.clamp(k, 0, 1.2))
				scale = big * math.max(0.05, k)
			elseif t < FLY_AT then
				p = hover + Vector3.new(0, math.sin((t - RISE) * 2.2) * 0.35, 0)
				scale = big * (1 + math.sin(t * 5) * 0.03)
			else
				local k = math.clamp((t - FLY_AT) / FLY, 0, 1)
				local e = easeInOut(k)
				local goal, goalScale
				if target then
					goal, goalScale = target.Position, targetScale
				else
					local owner = Players:GetPlayerByUserId(info.owner or 0)
					local char = owner and owner.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					goal, goalScale = hrp and hrp.Position or pos, 0.05
				end
				local mid = (hover + goal) / 2 + Vector3.new(0, 6, 0)
				p = hover:Lerp(mid, e):Lerp(mid:Lerp(goal, e), e)
				scale = big + (goalScale - big) * e
				hl.FillTransparency = 0.2 + 0.8 * e
				hl.OutlineTransparency = e
				if k >= 1 then
					burst(goal, 16, {Color = ColorSequence.new(glow, WHITE), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(6, 12), Drag = 4})
					conn:Disconnect()
					holder:Destroy()
					return
				end
			end
			local cf = CFrame.new(p) * CFrame.Angles(0, spin, 0) * CFrame.Angles(math.rad(math.sin(t * 2) * 8), 0, 0)
			Config.PoseItemModel(list, cf, scale)
			if rainbow then
				local hue = Color3.fromHSV((now * 0.3) % 1, 0.75, 1)
				for _, e in ipairs(list) do e.part.Color = hue end
			end
			anchor.CFrame = CFrame.new(p)
			hl.FillTransparency = (t < FLY_AT) and math.clamp(0.2 + t * 0.4, 0.2, 0.8) or hl.FillTransparency
			light.Range = 14 + def.tier * 2 + math.sin(t * 6) * 3
			local fade = (t < FLY_AT) and 0 or math.clamp((t - FLY_AT) / FLY, 0, 1)
			pillar.Transparency = 0.75 + 0.25 * math.max(fade, math.clamp((t - 1.2) / 1.5, 0, 1) * 0.7)
			if skyBeam then
				skyBeam.Transparency = 0.3 + 0.7 * math.max(fade, math.clamp((t - hold) / 1.5, 0, 1))
				skyBeam.Size = Vector3.new(400, big * (0.7 + math.sin(t * 8) * 0.1), big * (0.7 + math.sin(t * 8) * 0.1))
			end
			ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, now * 2, math.rad(90))
			ring.Transparency = 0.35 + 0.65 * fade
			for i, o in ipairs(orbiters) do
				local ang = now * 4 + i * (math.pi * 2 / #orbiters)
				o.CFrame = CFrame.new(p + Vector3.new(math.cos(ang) * scale * 1.15, math.sin(now * 3 + i) * scale * 0.5, math.sin(ang) * scale * 1.15))
				o.Transparency = fade
			end
			for i, r in ipairs(rays) do
				local len = scale * (3.2 + def.tier * 0.4)
				local ang = (i / #rays) * math.pi * 2 + now * 0.8
				local dirCF = CFrame.lookAt(p, cam and cam.CFrame.Position or p + Vector3.new(0, 0, 1)) * CFrame.Angles(0, 0, ang)
				r.Size = Vector3.new(0.35 * scale * 0.4, len, 0.05)
				r.CFrame = dirCF * CFrame.new(0, len / 2, 0.8 * scale)
				r.Transparency = 0.5 + 0.5 * fade + math.sin(now * 6 + i) * 0.08
			end
			if t > FLY_AT then tag.Enabled = false end
		end)
	end
	end -- (opening + reveal scope)

	-- your own unbox: the reveal card at the bottom of the screen (in the HUD)
	RevealEvent.OnClientEvent:Connect(function(item, placed)
		if type(item) == "table" and Config.Items[item.id] and ctx.showReveal then ctx.showReveal(item, placed) end
	end)
	do -- (own scope: keeps the main script under Roblox's 200-local limit)
	------------------------------------------------------------------
	-- TREADMILL: step onto your belt and you run by yourself (you earn speed
	-- every second). Press jump (or the button) to hop off.
	------------------------------------------------------------------
	local treadOn, treadCooldown = false, 0
	local controls = nil
	task.spawn(function()
		local ok, pm = pcall(function() return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)) end)
		if ok and pm and pm.GetControls then controls = pm:GetControls() end
	end)
	-- the treadmill bar in the bottom stack of the HUD: a line of text + a Jump off button
	local jumpHolder = UI.box(ctx.hud.bottomStack, {Name = "Treadmill", Size = UDim2.fromOffset(380, 84), LayoutOrder = 3, Visible = false})
	UI.label(jumpHolder, "Running! You earn speed every second.", {Size = UDim2.new(1, 0, 0, 26), Max = 20, Stroke = 2, TextColor3 = MONEY, TextWrapped = false})
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local jumpBtn = UI.button(jumpHolder, {Text = isTouch and "Jump off" or "Jump off  [Space]", Color = UI.C.orange, Icon = "arrow", IconColor = WHITE,
		Size = UDim2.fromOffset(240, 50), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), TextSize = 22})

	local function myBelt()
		local plotName = player:GetAttribute("PlotName")
		local root = workspace:FindFirstChild("StealABox")
		local plots = root and root:FindFirstChild("Plots")
		local plot = plots and plotName and plots:FindFirstChild(plotName)
		return plot and plot:FindFirstChild("TreadBelt", true)
	end

	local function leaveTreadmill()
		if not treadOn then return end
		treadOn = false
		treadCooldown = os.clock() + 1.5
		jumpHolder.Visible = false
		if controls then pcall(function() controls:Enable() end) end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local belt = myBelt()
		if hum and hrp and belt then
			local back = belt:GetAttribute("BeltDir") or Vector3.new(0, 0, 1)
			hum:Move(Vector3.new(), false)
			-- hop off the back of the treadmill
			local offPos = belt.Position + back * (belt.Size.Z / 2 + 3) + Vector3.new(0, 3, 0)
			hrp.CFrame = CFrame.lookAt(offPos, offPos + back)
			hrp.AssemblyLinearVelocity = back * 20 + Vector3.new(0, 35, 0)
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
	jumpBtn.Activated:Connect(leaveTreadmill)
	UserInputService.JumpRequest:Connect(function() if treadOn then leaveTreadmill() end end)
	UserInputService.InputBegan:Connect(function(input)
		if treadOn and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then leaveTreadmill() end
	end)

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local belt = myBelt()
		if not hum or not hrp or not belt or hum.Health <= 0 then
			if treadOn then leaveTreadmill() end
			return
		end
		local lp = belt.CFrame:PointToObjectSpace(hrp.Position)
		local onBelt = math.abs(lp.X) <= belt.Size.X / 2 and math.abs(lp.Z) <= belt.Size.Z / 2 and lp.Y > 0 and lp.Y < 6
		if not treadOn then
			if onBelt and os.clock() > treadCooldown and not player:GetAttribute("Carrying") then
				treadOn = true
				jumpHolder.Visible = true
				if controls then pcall(function() controls:Disable() end) end
			end
			return
		end
		if player:GetAttribute("Carrying") then leaveTreadmill() return end
		-- keep running in place on the middle of the belt, facing the console
		local back = belt:GetAttribute("BeltDir") or Vector3.new(0, 0, 1)
		local face = -back
		local spot = belt.Position + Vector3.new(0, hrp.Position.Y - belt.Position.Y, 0)
		hrp.CFrame = CFrame.lookAt(spot, spot + face)
		hum:Move(face, false)
	end)
	end -- (treadmill scope)
	------------------------------------------------------------------
	-- LIVING WORLD 2: everything tagged "Animated" moves here - critters walk and fly around,
	-- set pieces spin / bob / sway, fish leap, wings flap, rotors turn, legs step.
	-- It all runs on your own screen (smooth + free for the server); far-away things pause.
	------------------------------------------------------------------
	do
		local items = {}
		local rng = Random.new()
		local function randBox(mn, mx)
			return Vector3.new(rng:NextNumber(mn.X, mx.X), rng:NextNumber(mn.Y, mx.Y), rng:NextNumber(mn.Z, mx.Z))
		end
		local function setup(inst)
			if items[inst] or not inst.Parent then return end
			local kind = inst:GetAttribute("Anim")
			if not kind then return end
			local isModel = inst:IsA("Model")
			local base = isModel and inst:GetPivot() or (inst:IsA("BasePart") and inst.CFrame) or nil
			if not base then return end
			local e = {inst = inst, kind = kind, model = isModel, base = base,
				speed = inst:GetAttribute("Speed") or 1, amp = inst:GetAttribute("Amp") or 1, phase = inst:GetAttribute("Phase") or rng:NextNumber(0, 6),
				axis = inst:GetAttribute("Axis") or Vector3.new(0, 1, 0), radius = inst:GetAttribute("Radius") or 6,
				center = inst:GetAttribute("Center"), min = inst:GetAttribute("Min"), max = inst:GetAttribute("Max"),
				flapSpeed = inst:GetAttribute("FlapSpeed") or 12, waddle = inst:GetAttribute("Waddle"), len = inst:GetAttribute("Length") or 8,
				pos = base.Position, subs = {}, moving = true}
			if e.axis.Magnitude < 0.01 then e.axis = Vector3.new(0, 1, 0) end
			e.axis = e.axis.Unit
			if not isModel and kind == "pulse" then e.baseT = inst.Transparency end
			if isModel then
				for _, p in ipairs(inst:GetDescendants()) do
					if p:IsA("BasePart") then
						local flap, spin, step = p:GetAttribute("Flap"), p:GetAttribute("SubSpin"), p:GetAttribute("Step")
						if flap or spin or step then
							local off = base:ToObjectSpace(p.CFrame)
							local sub = {part = p, off = off, flap = flap, spin = spin, step = step}
							if flap then
								sub.half = p.Size.X / 2
								sub.hinge = off * CFrame.new(-flap * sub.half, 0, 0)
							end
							if step then
								sub.halfY = p.Size.Y / 2
								sub.hip = off * CFrame.new(0, sub.halfY, 0)
							end
							table.insert(e.subs, sub)
						end
					end
				end
			end
			if (kind == "wander" or kind == "fly") and e.min and e.max then
				e.target = randBox(e.min, e.max)
				e.vel = Vector3.new()
				e.wait = rng:NextNumber(0, 2)
				e.facing = base.LookVector
			end
			items[inst] = e
		end

		local function update(e, t, dt)
			local inst, k = e.inst, e.kind
			local cf
			if k == "spin" then
				cf = e.base * CFrame.fromAxisAngle(e.axis, t * e.speed + e.phase)
			elseif k == "bob" then
				cf = e.base + Vector3.new(0, math.sin(t * e.speed + e.phase) * e.amp, 0)
			elseif k == "hover" then
				cf = e.base * CFrame.new(0, math.sin(t * e.speed + e.phase) * e.amp, 0) * CFrame.Angles(0, t * e.speed * 0.6 + e.phase, 0)
			elseif k == "bounce" then
				cf = e.base + Vector3.new(0, math.abs(math.sin(t * e.speed + e.phase)) * e.amp, 0)
			elseif k == "sway" then
				cf = e.base * CFrame.fromAxisAngle(e.axis, math.sin(t * e.speed + e.phase) * e.amp)
			elseif k == "orbit" then
				local c = e.center or e.base
				local a = t * e.speed + e.phase
				local function at(ang)
					return c.Position + Vector3.new(math.cos(ang) * e.radius, math.sin(ang * 2) * e.amp, math.sin(ang) * e.radius)
				end
				local p = at(a)
				cf = CFrame.lookAt(p, at(a + ((e.speed >= 0) and 0.05 or -0.05)))
				e.pos = p
			elseif k == "leap" then
				local cyc = ((t * e.speed + e.phase) % (math.pi * 2)) / (math.pi * 2)
				local fwd = e.base.LookVector
				if cyc < 0.32 then
					local u = cyc / 0.32
					local p = e.base.Position + fwd * ((u - 0.5) * e.len) + Vector3.new(0, math.sin(u * math.pi) * e.amp, 0)
					local dy = math.cos(u * math.pi) * e.amp * math.pi / e.len
					cf = CFrame.lookAt(p, p + fwd + Vector3.new(0, dy, 0))
				else
					cf = e.base - Vector3.new(0, 8, 0) -- under the water until the next jump
				end
			elseif k == "pulse" then
				if not e.model and e.baseT then
					inst.Transparency = math.clamp(e.baseT + (math.sin(t * e.speed + e.phase) * 0.5 + 0.5) * e.amp, 0, 1)
				end
				return
			elseif (k == "wander" or k == "fly") and e.target then
				local fly = k == "fly"
				if e.wait > 0 then
					e.wait = e.wait - dt
					e.moving = false
				else
					local to = e.target - e.pos
					if not fly then to = Vector3.new(to.X, 0, to.Z) end
					if to.Magnitude < 1.2 then
						e.target = randBox(e.min, e.max)
						e.wait = fly and 0 or rng:NextNumber(0.6, 2.8)
					else
						local want = to.Unit * e.speed
						e.vel = fly and e.vel:Lerp(want, math.min(1, dt * 1.5)) or want
						e.pos = e.pos + e.vel * dt
						if e.vel.Magnitude > 0.1 then e.facing = e.vel.Unit end
						e.moving = true
					end
				end
				local look = Vector3.new(e.facing.X, fly and e.facing.Y * 0.4 or 0, e.facing.Z)
				if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
				local hop = (not fly and e.moving) and math.abs(math.sin(t * 9 + e.phase)) * e.amp or 0
				local bob = fly and math.sin(t * 2 + e.phase) * 0.4 or 0
				cf = CFrame.lookAt(e.pos, e.pos + look) + Vector3.new(0, hop + bob, 0)
				if e.waddle and e.moving then cf = cf * CFrame.Angles(0, 0, math.sin(t * 10 + e.phase) * e.waddle) end
				if fly then
					-- lean into turns
					local turn = e.vel:Cross(e.target - e.pos).Y
					cf = cf * CFrame.Angles(0, 0, math.clamp(-turn * 0.002, -0.5, 0.5))
				end
			end
			if not cf then return end
			if e.model then inst:PivotTo(cf) else inst.CFrame = cf end
			-- wings flap, rotors spin, legs step
			for _, sub in ipairs(e.subs) do
				if sub.flap then
					local ang = math.sin(t * e.flapSpeed + e.phase) * 0.7
					sub.part.CFrame = cf * sub.hinge * CFrame.Angles(0, 0, sub.flap * ang) * CFrame.new(sub.flap * sub.half, 0, 0)
				elseif sub.spin then
					sub.part.CFrame = cf * sub.off * CFrame.Angles(0, t * sub.spin, 0)
				elseif sub.step then
					local sw = e.moving and math.sin(t * 11 + e.phase) * 0.6 * sub.step or 0
					sub.part.CFrame = cf * sub.hip * CFrame.Angles(sw, 0, 0) * CFrame.new(0, -sub.halfY, 0)
				end
			end
		end

		for _, inst in ipairs(CollectionService:GetTagged("Animated")) do setup(inst) end
		CollectionService:GetInstanceAddedSignal("Animated"):Connect(function(inst) task.defer(setup, inst) end)
		CollectionService:GetInstanceRemovedSignal("Animated"):Connect(function(inst) items[inst] = nil end)

		------------------------------------------------------------------
		-- BOSSES: orbs that circle them (faster when they chase you) and eyes that blaze while chasing
		------------------------------------------------------------------
		local orbs = {}
		local function addOrb(orb) if orb:IsA("BasePart") then orbs[orb] = true end end
		for _, o in ipairs(CollectionService:GetTagged("BossOrb")) do addOrb(o) end
		CollectionService:GetInstanceAddedSignal("BossOrb"):Connect(addOrb)
		CollectionService:GetInstanceRemovedSignal("BossOrb"):Connect(function(o) orbs[o] = nil end)
		local guardCache = {}
		local function guardModel(name)
			local g = guardCache[name]
			if g and g.Parent then return g end
			local root = workspace:FindFirstChild("StealABox")
			local folder = root and root:FindFirstChild("Guards")
			g = folder and folder:FindFirstChild(name)
			guardCache[name] = g
			return g
		end
		local eyes = {} -- [part] = base transparency
		local function scanEyes()
			local root = workspace:FindFirstChild("StealABox")
			local folder = root and root:FindFirstChild("Guards")
			if not folder then return end
			for _, d in ipairs(folder:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "GlowEye" and eyes[d] == nil then eyes[d] = d.Transparency end
			end
		end
		task.delay(2, scanEyes)

		local last = os.clock()
		RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local dt = math.min(0.1, now - last)
			last = now
			local cam = workspace.CurrentCamera
			if not cam then return end
			local camPos = cam.CFrame.Position
			for inst, e in pairs(items) do
				if not inst.Parent then
					items[inst] = nil
				elseif ((e.pos or e.base.Position) - camPos).Magnitude < 260 then
					update(e, now, dt)
				end
			end
			for orb in pairs(orbs) do
				if not orb.Parent then
					orbs[orb] = nil
				else
					local g = guardModel(orb:GetAttribute("Boss") or "")
					local hrp = g and g.PrimaryPart
					if hrp and (hrp.Position - camPos).Magnitude < 220 then
						local chasing = g:GetAttribute("Mode") == "chase"
						local n = orb:GetAttribute("Count") or 1
						local i = orb:GetAttribute("Index") or 1
						local s = g:GetAttribute("Scale") or 1
						local a = now * (chasing and 4.5 or 1.4) + i * (math.pi * 2 / n)
						local r = (orb:GetAttribute("Radius") or 4) * (chasing and 1.25 or 1)
						local y = hrp.Position.Y + (orb:GetAttribute("Height") or 4) - 3 * s + math.sin(now * 2.2 + i) * 0.6 * s
						orb.CFrame = CFrame.new(hrp.Position.X + math.cos(a) * r, y, hrp.Position.Z + math.sin(a) * r)
					end
				end
			end
			for eye, baseT in pairs(eyes) do
				if not eye.Parent then
					eyes[eye] = nil
				else
					local g = eye:FindFirstAncestorOfClass("Model")
					local mode = g and g:GetAttribute("Mode")
					if mode == "chase" then
						eye.Transparency = 0.05 + math.abs(math.sin(now * 10)) * 0.25
					else
						eye.Transparency = math.max(baseT, 0.35 + math.sin(now * 1.5) * 0.15)
					end
				end
			end
		end)
	end
	------------------------------------------------------------------
	-- CUSTOMER BUBBLES: a little turning 3D model of the product they want (or carry),
	-- or a bouncing heart when they're happy (gold for rich shoppers)
	------------------------------------------------------------------
	do
		local live = {}
		local function setup(bb)
			if live[bb] or not bb:IsA("BillboardGui") then return end
			local isThink = bb.Name == "Think"
			local vp = new("ViewportFrame", {Name = "ItemView", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, isThink and 0.05 or 0),
				Size = isThink and UDim2.fromScale(0.76, 0.74) or UDim2.fromScale(1, 1), BackgroundTransparency = 1, LightColor = WHITE,
				Ambient = Color3.fromRGB(185, 185, 185), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 3}, bb)
			vp.CurrentCamera = new("Camera", {FieldOfView = 34, CFrame = CFrame.lookAt(Vector3.new(0, 0.5, -5), Vector3.new(0, 0, 0))}, vp)
			local heart = ICON.new("heart", bb, UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.5, 0.42), Color3.fromRGB(255, 80, 120), Vector2.new(0.5, 0.5))
			heart.Visible = false
			local heartScale = new("UIScale", {}, heart)
			local e = {bb = bb, vp = vp, heart = heart, heartScale = heartScale}
			live[bb] = e
			local function refresh()
				local id = bb:GetAttribute("Item")
				local mood = bb:GetAttribute("Mood")
				if id and id ~= e.id then
					if e.model then e.model:Destroy() end
					local ok, m, list = pcall(Config.BuildItemModel, {id = id, mutation = bb:GetAttribute("Mutation") or "Normal", size = "Normal"}, 1, CFrame.new())
					if ok and m then
						m.Parent = vp
						e.model, e.list = m, list
					end
					e.id = id
				end
				vp.Visible = id ~= nil
				local showHeart = (id == nil) and mood ~= nil
				if showHeart and not heart.Visible then
					heartScale.Scale = 0.2
					TweenService:Create(heartScale, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Scale = 1}):Play()
					-- rich shoppers: gold heart
					for _, d in ipairs(heart:GetDescendants()) do
						if d:IsA("Frame") and d.BackgroundColor3 ~= Color3.fromRGB(26, 22, 36) and d.BackgroundTransparency < 0.1 then
							d.BackgroundColor3 = (mood == "rich") and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(255, 80, 120)
						end
					end
				end
				heart.Visible = showHeart
			end
			bb:GetAttributeChangedSignal("Item"):Connect(refresh)
			bb:GetAttributeChangedSignal("Mood"):Connect(refresh)
			refresh()
		end
		for _, bb in ipairs(CollectionService:GetTagged("ItemBubble")) do task.spawn(setup, bb) end
		CollectionService:GetInstanceAddedSignal("ItemBubble"):Connect(function(bb) task.defer(setup, bb) end)
		CollectionService:GetInstanceRemovedSignal("ItemBubble"):Connect(function(bb) live[bb] = nil end)
		RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			local camPos = cam and cam.CFrame.Position
			local t = os.clock()
			local cf = CFrame.Angles(0, t * 2, 0) * CFrame.Angles(math.rad(10), 0, 0)
			for bb, e in pairs(live) do
				if not bb.Parent then
					live[bb] = nil
				elseif bb.Enabled then
					local adorn = bb.Parent
					local near = adorn and adorn:IsA("BasePart") and camPos and (adorn.Position - camPos).Magnitude < 70
					if near and e.list and e.vp.Visible then Config.PoseItemModel(e.list, cf, 1) end
					if e.heart.Visible then e.heart.Rotation = math.sin(t * 7) * 12 end
				end
			end
		end)
	end

	------------------------------------------------------------------
	-- SHELF LABELS: 45 products on a shelf would mean 45 name tags piled on top of each other.
	-- Only the product you're standing closest to shows its name + $/s (Settings can turn it off).
	------------------------------------------------------------------
	do
		local shown = nil
		task.spawn(function()
			while true do
				task.wait(0.15)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local best, bestD = nil, 13
				if hrp and ctx.settings.ShelfTags ~= false then
					for _, bb in ipairs(CollectionService:GetTagged("ShelfTag")) do
						local stand = bb.Parent
						if stand and stand:IsA("BasePart") then
							local d = (stand.Position - hrp.Position).Magnitude
							if d < bestD then best, bestD = bb, d end
						end
					end
				end
				if shown ~= best then
					if shown and shown.Parent then shown.Enabled = false end
					shown = best
					if best then best.Enabled = true end
				end
			end
		end)
	end

	------------------------------------------------------------------
	-- SALE POPS: "+$123" floats up and fades (the server only creates them)
	------------------------------------------------------------------
	do
		local function animate(bb)
			if not bb:IsA("BillboardGui") then return end
			local label = bb:FindFirstChild("Label")
			if not label then return end
			local stroke = label:FindFirstChildOfClass("UIStroke")
			local y0, x0 = bb:GetAttribute("Y0") or 3, bb:GetAttribute("X0") or 0
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local k = (os.clock() - t0) / 0.9
				if k >= 1 or not bb.Parent then
					conn:Disconnect()
					if bb.Parent then bb.Enabled = false end
					return
				end
				bb.StudsOffset = Vector3.new(x0, y0 + k * 1.2, 0)
				local fade = math.clamp((k - 0.5) / 0.5, 0, 1)
				label.TextTransparency = fade
				if stroke then stroke.Transparency = fade end
			end)
		end
		CollectionService:GetInstanceAddedSignal("PopText"):Connect(animate)
	end

	------------------------------------------------------------------
	-- TREADMILL STEPS: "+123" pops fly up from you many times a second while you run
	------------------------------------------------------------------
	task.spawn(function()
		while true do
			task.wait(0.12)
			if player:GetAttribute("OnTreadmill") then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local rate = player:GetAttribute("TreadRate") or 0
				if hrp and rate > 0 then
					local bb = new("BillboardGui", {Size = UDim2.fromOffset(130, 44), StudsOffset = Vector3.new((math.random() - 0.5) * 3.5, 2.2, 0),
						AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 80}, hrp)
					local l = text(bb, "+" .. Config.FormatNum(math.max(1, math.floor(rate * 0.12 + 0.5))), {Size = UDim2.fromScale(1, 1),
						TextColor3 = Color3.fromRGB(150, 215, 255), StrokeSize = 2.4})
					TweenService:Create(bb, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {StudsOffset = bb.StudsOffset + Vector3.new(0, 3.5, 0)}):Play()
					TweenService:Create(l, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
					Debris:AddItem(bb, 0.85)
				end
			end
		end
	end)

	------------------------------------------------------------------
	-- OTHER PEOPLE'S PROMPTS: "Take back", "Open!", "Upgrade" on someone else's plot only
	-- clutter your screen (they don't work for you) - so they're hidden for you.
	------------------------------------------------------------------
	do
		local root = workspace:WaitForChild("StealABox")
		local plots = root:WaitForChild("Plots")
		local function plotOf(inst)
			local p = inst
			while p and p.Parent ~= plots do p = p.Parent end
			return p
		end
		local function apply(prompt)
			if not prompt:IsA("ProximityPrompt") then return end
			local plot = plotOf(prompt)
			if plot then prompt.Enabled = plot:GetAttribute("Owner") == player.UserId end
		end
		local function refreshPlot(plot)
			for _, d in ipairs(plot:GetDescendants()) do apply(d) end
		end
		for _, plot in ipairs(plots:GetChildren()) do
			refreshPlot(plot)
			plot:GetAttributeChangedSignal("Owner"):Connect(function() refreshPlot(plot) end)
			plot.DescendantAdded:Connect(function(d) task.defer(apply, d) end)
		end
	end

end

return WorldFX
