--[[ STEAL A BOX - MAP BUILDER
     Builds the lobby (6 bases, the street, Trails Shop, FREE gift, leaderboards) and the MEGA MART
     supermarket (10 departments + security guards). If the map was built in Studio, this does nothing. ]]

local RS = game:GetService("ReplicatedStorage")
if workspace:FindFirstChild("StealABox") then return end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") or (d:IsA("BasePart") and d.Name == "Baseplate") then d:Destroy() end
end
local Config = require(RS:WaitForChild("StealABoxConfig"))
local CS = game:GetService("CollectionService")

math.randomseed(42) -- the same store every time
local function V(x, y, z) return Vector3.new(x, y, z) end
local function C(x, y, z) return CFrame.new(x, y, z) end
local function RGB(r, g, b) return Color3.fromRGB(r, g, b) end
local M = Enum.Material
local WHITE = RGB(255, 255, 255)
local INK = RGB(25, 22, 30)       -- the dark outline around every sign text
local GOLD = RGB(255, 200, 40)

-- one anchored, smooth part
local function P(parent, name, size, cf, color, mat, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in pairs(props) do p[k] = v end end
	p.Parent = parent
	return p
end
local GHOST = {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}
local NOHIT = {CanCollide = false, CanQuery = false, CanTouch = false}
-- players only bump into parts with a SOLID name (Wall, Floor, ...) or this attribute (shelves, counters)
local function solid(p)
	p:SetAttribute("Solid", true)
	return p
end
local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function prompt(parent, name, action, object, hold)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold or 0
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

-- friendly sign text: white Fredoka with a thick dark outline
local function textLabel(parent, text, color, stroke)
	local tl = Instance.new("TextLabel")
	tl.Name = "Label"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.FontFace = Config.Font
	tl.TextScaled = true
	tl.TextColor3 = color or WHITE
	tl.Text = Config.StripEmoji(text)
	local st = Instance.new("UIStroke")
	st.Thickness = stroke or 3
	st.Color = INK
	st.Parent = tl
	tl.Parent = parent
	return tl
end
local function surfaceGui(part, face, pixelsPerStud, maxDistance)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = pixelsPerStud or 20
	sg.LightInfluence = 0
	sg.MaxDistance = maxDistance or 200 -- far-away signs are not drawn at all
	sg.Parent = part
	return sg
end
-- one centred line of text on a part face
local function signText(part, face, text, pixelsPerStud, stroke, maxDistance)
	local tl = textLabel(surfaceGui(part, face, pixelsPerStud, maxDistance), text, nil, stroke)
	tl.AnchorPoint = Vector2.new(0.5, 0.5)
	tl.Position = UDim2.fromScale(0.5, 0.5)
	tl.Size = UDim2.fromScale(0.9, 0.78)
	return tl
end

local root = Instance.new("Folder") -- parented at the very end, so the other scripts only see a finished map
root.Name = "StealABox"

------------------------------------------------------------------
-- THE WORLD (everything inside walls, nothing outside)
--   z 0..300   : the street with the 6 bases (3 on each side)
--   z 300..360 : the plaza: spawn, Trails Shop, FREE gift, leaderboards
--   z < -4     : the MEGA MART, 10 departments that get bigger + harder
------------------------------------------------------------------
local L = Config.Layout
local FY = L.floorY                 -- top of every floor
local WALL_H = L.wallHeight         -- the store ceiling
local FRONT_Z = L.frontZ            -- inside face of the store front
local MAPW = Config.Court.halfWidth
local COURT_LEN = Config.Court.length
local NA = #Config.Areas
local STORE_END = Config.StoreEndZ()
local STORE_HW = Config.StoreHalfWidth()

-- bright cartoon day, set once. No lamps needed: without shadows the store is lit like outside.
do
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = RGB(150, 156, 172)
	Lighting.OutdoorAmbient = RGB(150, 156, 172)
	Lighting.GlobalShadows = false
	for _, e in ipairs(Lighting:GetChildren()) do
		if e.Name == "StealABoxFX" or e:IsA("Atmosphere") or e:IsA("Sky") then e:Destroy() end
	end
	pcall(function() -- no clouds from older versions of the map
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then clouds:Destroy() end
	end)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StealABoxFX"
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "StealABoxFX"
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

------------------------------------------------------------------
-- THE LOBBY: lime grass, a grey street, red brick walls
------------------------------------------------------------------
do
	P(root, "CourtBase", V(MAPW * 2 + 12, 2, COURT_LEN + 12), C(0, -1, COURT_LEN / 2), RGB(110, 90, 70))
	P(root, "WarehouseBase", V(STORE_HW * 2 + 8, 2, FRONT_Z - STORE_END + 2), C(0, -1, (FRONT_Z + STORE_END - 2) / 2), RGB(110, 90, 70))
	-- grass: 3 big parts (left, right, behind the street)
	local GRASS, SW = RGB(120, 222, 45), 16
	local grass = folder(root, "Grass")
	for _, sx in ipairs({-1, 1}) do
		P(grass, "Tile", V(MAPW - SW, 0.2, COURT_LEN + 2), C(sx * (MAPW + SW) / 2, 0.1, COURT_LEN / 2 - 1), GRASS, M.Grass)
	end
	P(grass, "Tile", V(SW * 2, 0.2, COURT_LEN - 300), C(0, 0.1, (COURT_LEN + 300) / 2), GRASS, M.Grass)
	-- the street from the spawn to the store door
	local streetEnd = Config.LobbySpawnZ - 7
	P(root, "Street", V(SW * 2, 0.3, streetEnd), C(0, 0.15, streetEnd / 2), RGB(100, 104, 118), M.Concrete)
	for z = 10, 290, 20 do
		P(root, "LaneDash", V(1, 0.05, 8), C(0, 0.32, z), RGB(255, 225, 90), M.SmoothPlastic, NOHIT)
	end
	for _, sx in ipairs({-1, 1}) do
		P(root, "Curb", V(1.4, 0.6, 300), C(sx * (SW - 0.7), 0.3, 150), RGB(235, 235, 240), M.SmoothPlastic, NOHIT)
	end
	-- red brick walls all around (they meet the store front at z -4)
	local BRICK, CAP = RGB(186, 88, 66), RGB(240, 222, 196)
	for _, sx in ipairs({-1, 1}) do
		P(root, "CourtWall", V(4, 40, COURT_LEN + 8), C(sx * (MAPW + 2), 20, COURT_LEN / 2), BRICK, M.Brick)
		P(root, "WallCap", V(5, 1.5, COURT_LEN + 8), C(sx * (MAPW + 2), 40.75, COURT_LEN / 2), CAP)
	end
	P(root, "BackWall", V(MAPW * 2 + 8, 44, 4), C(0, 22, COURT_LEN + 2), BRICK, M.Brick)
	P(root, "BackWallCap", V(MAPW * 2 + 9, 1.5, 5), C(0, 44.75, COURT_LEN + 2), CAP)
	-- the "Warehouse" teleport lands here, right in front of the store door
	P(root, "EntrancePoint", V(2, 0.2, 2), C(0, 0.5, 10), RGB(0, 0, 0), nil, GHOST)
	-- the spawn in the middle of the plaza, facing the street
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "LobbySpawn"
	spawnLoc.Size = V(14, 1, 14)
	spawnLoc.CFrame = C(0, 0.5, Config.LobbySpawnZ) -- (no rotation = looking down -Z)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Duration = 0
	spawnLoc.Color = RGB(255, 205, 60)
	spawnLoc.Material = M.SmoothPlastic
	spawnLoc.TopSurface = Enum.SurfaceType.Smooth
	spawnLoc.Parent = root
end

------------------------------------------------------------------
-- THE PLAZA: two leaderboards on the back wall, the Trails Shop stall
-- and the FREE gift (the client draws the lists + the gift timer)
------------------------------------------------------------------
do
	local lobby = folder(root, "Lobby")
	local BZ = COURT_LEN - 1.5 -- the boards hang on the brick back wall, facing the street (-Z)
	local function leaderboard(name, x, title, color)
		P(lobby, name, V(22, 30, 1), C(x, 18, BZ), RGB(40, 44, 56))
		-- a chunky coloured frame
		for _, sx in ipairs({-1, 1}) do
			P(lobby, "BoardFrame", V(1.6, 33.2, 1.6), C(x + sx * 11.8, 18, BZ - 0.1), color)
		end
		P(lobby, "BoardFrame", V(25.2, 1.6, 1.6), C(x, 2.2, BZ - 0.1), color)
		-- the title ribbon on top, with pointed ends and a point down to the list
		local banner = P(lobby, "BoardBanner", V(22, 5.6, 1.4), C(x, 37.2, BZ - 0.9), color)
		local tip = color:Lerp(RGB(0, 0, 0), 0.2)
		for _, ex in ipairs({-11, 11}) do
			P(lobby, "BannerTip", V(4, 4, 1.2), C(x + ex, 37.2, BZ - 0.8) * CFrame.Angles(0, 0, math.rad(45)), tip)
		end
		P(lobby, "BannerTip", V(3, 3, 1.2), C(x, 34.4, BZ - 0.8) * CFrame.Angles(0, 0, math.rad(45)), color)
		signText(banner, Enum.NormalId.Front, title, 30, 5, 300)
	end
	-- looking at the back wall: Top Money on the left, Top Speed on the right
	leaderboard("BoardTopMoney", 15, "Top Money", RGB(80, 200, 60))
	leaderboard("BoardTopSpeed", -15, "Top Speed", RGB(60, 135, 255))

	-- TRAILS SHOP: a wooden market stall with a green + white striped awning (press E at the counter)
	do
		local stall = Instance.new("Model")
		stall.Name = "TrailStall"
		local SX, SZ = 46, COURT_LEN - 16
		local wood, woodDark, woodTop = RGB(176, 112, 60), RGB(120, 74, 40), RGB(222, 168, 108)
		local counter = solid(P(stall, "Counter", V(16, 4, 3.6), C(SX, 2.2, SZ - 2), wood, M.WoodPlanks))
		P(stall, "CounterTop", V(17, 0.5, 4.4), C(SX, 4.45, SZ - 2), woodTop, M.WoodPlanks)
		for _, px in ipairs({-8, 8}) do
			P(stall, "Post", V(0.8, 11.8, 0.8), C(SX + px, 6.1, SZ - 3.6), woodDark, M.WoodPlanks)
			P(stall, "Post", V(0.8, 13.6, 0.8), C(SX + px, 7, SZ + 3.6), woodDark, M.WoodPlanks)
		end
		local tilt = CFrame.Angles(math.rad(-14), 0, 0) -- slopes down to the front
		for k = 0, 7 do
			local x = SX - 7.875 + k * 2.25
			local c = (k % 2 == 0) and RGB(80, 205, 60) or WHITE
			P(stall, "Awning", V(2.25, 0.4, 9.6), C(x, 12.9, SZ) * tilt, c)
			P(stall, "Valance", V(2.25, 1.6, 0.3), C(x, 11, SZ - 4.75), c)
		end
		-- a few trail samples on the counter
		for k, t in ipairs({1, 3, 5}) do
			local trail = Config.Trails[t]
			if trail then
				P(stall, "TrailSample", V(1.6, 1.2, 1.6), C(SX - 5 + (k - 1) * 5, 5.3, SZ - 2) * CFrame.Angles(0, math.rad(20 * k), 0), trail.colors[1], M.Neon, NOHIT)
			end
		end
		-- the floating green "Trails Shop" title
		local anchor = P(stall, "SignAnchor", V(1, 1, 1), C(SX, 18, SZ), RGB(0, 0, 0), nil, GHOST)
		local bb = Instance.new("BillboardGui")
		bb.Name = "TrailsShopSign"
		bb.Size = UDim2.fromScale(18, 4.5)
		bb.MaxDistance = 200
		bb.LightInfluence = 0
		bb.Parent = anchor
		textLabel(bb, "Trails Shop", RGB(130, 235, 60), 4)
		prompt(counter, "OpenTrailShop", "Trails", "Trails Shop")
		stall.Parent = lobby
	end

	-- the FREE GIFT: a big red present with a yellow ribbon (claim it every few minutes)
	do
		local gift = Instance.new("Model")
		gift.Name = "FreeGift"
		local RED, YEL = RGB(230, 45, 55), RGB(255, 210, 40)
		local box = P(gift, "Box", V(6, 5, 6), C(-44, 2.7, COURT_LEN - 18), RED, M.SmoothPlastic, {CanCollide = false})
		-- everything else is glued to the Box, so the client can bob the whole gift by moving the Box
		local function deco(name, size, offset, color, shape)
			local p = P(gift, name, size, box.CFrame * offset, color, M.SmoothPlastic, NOHIT)
			if shape then p.Shape = shape end
			return Config.Attach(p, box)
		end
		deco("Ribbon", V(1.3, 5.04, 6.04), CFrame.new(), YEL)
		deco("Ribbon", V(6.04, 5.04, 1.3), CFrame.new(), YEL)
		deco("Lid", V(6.6, 1.2, 6.6), CFrame.new(0, 2.5, 0), RED)
		deco("Ribbon", V(1.35, 1.24, 6.64), CFrame.new(0, 2.5, 0), YEL)
		deco("Ribbon", V(6.64, 1.24, 1.35), CFrame.new(0, 2.5, 0), YEL)
		deco("Bow", V(2.4, 1.6, 0.8), CFrame.new(-1.1, 3.7, 0) * CFrame.Angles(0, 0, math.rad(30)), YEL)
		deco("Bow", V(2.4, 1.6, 0.8), CFrame.new(1.1, 3.7, 0) * CFrame.Angles(0, 0, math.rad(-30)), YEL)
		deco("Knot", V(1.1, 1.1, 1.1), CFrame.new(0, 3.4, 0), YEL, Enum.PartType.Ball)
		gift.PrimaryPart = box
		prompt(box, "FreeGiftPrompt", "Claim", "FREE Gift")
		local label = Instance.new("Attachment") -- the client hangs its "FREE!" / countdown billboard here
		label.Name = "Label"
		label.Position = V(0, 8, 0)
		label.Parent = box
		gift.Parent = lobby
	end
end

------------------------------------------------------------------
-- THE MEGA MART
------------------------------------------------------------------
local store = folder(root, "Store")
local spawnsF = folder(root, "BoxSpawns")
local guardsF = folder(root, "Guards")
local CREAM = RGB(250, 246, 236)
local SHELF_WHITE = RGB(246, 246, 249)
local BASE_GREY = RGB(200, 204, 212)
local DECK = FY + 1     -- top of every bottom deck (boxes sit here)
local SHELF2 = 9        -- 2nd shelf board (centre); boxes sit on its top
local SHELF3 = 16.2     -- the top board of the wall shelves
local BOARD = 0.35      -- shelf board thickness
local GD = 9            -- gondola depth (z)

-- the store front: white walls, big windows, the red MEGA MART band and a wide open doorway
do
	local FZ, FH, DOOR_HW, DOOR_H = FRONT_Z + 1, WALL_H + 4, 16, 26
	local side = MAPW + 4 - DOOR_HW
	for _, sx in ipairs({-1, 1}) do
		P(store, "Wall", V(side, FH, 2), C(sx * (DOOR_HW + side / 2), FH / 2, FZ), CREAM)
	end
	P(store, "Wall", V(DOOR_HW * 2, FH - DOOR_H, 2), C(0, (FH + DOOR_H) / 2, FZ), CREAM)
	P(store, "Floor", V(DOOR_HW * 2, 0.6, 4), C(0, FY - 0.3, FZ + 1), RGB(70, 72, 82)) -- door mat
	local W = MAPW * 2 + 8
	P(store, "BrandBand", V(W, 11, 0.4), C(0, 39, FZ + 1.2), RGB(225, 40, 45), nil, NOHIT)
	P(store, "BrandStripe", V(W, 1.2, 0.5), C(0, 33, FZ + 1.25), GOLD, nil, NOHIT)
	P(store, "FacadeCap", V(W, 1.6, 3), C(0, FH + 0.8, FZ), WHITE, nil, NOHIT)
	local sign = P(store, "StoreSign", V(76, 10, 0.4), C(0, 39, FZ + 1.55), RGB(225, 40, 45), nil, NOHIT)
	signText(sign, Enum.NormalId.Back, "MEGA MART", 16, 7, 600)
	-- a little yellow shopping cart on both sides of the name
	for _, sx in ipairs({-1, 1}) do
		local cx = sx * 47
		P(store, "CartLogo", V(6, 3.4, 0.4), C(cx, 39.6, FZ + 1.6), GOLD, nil, NOHIT)
		P(store, "CartLogo", V(0.6, 3, 0.4), C(cx - sx * 3.6, 41.2, FZ + 1.6) * CFrame.Angles(0, 0, math.rad(sx * 20)), GOLD, nil, NOHIT)
		for _, wx in ipairs({-1.8, 1.8}) do
			local wheel = P(store, "CartLogo", V(1.4, 1.4, 0.4), C(cx + wx, 37.1, FZ + 1.6), GOLD, nil, NOHIT)
			wheel.Shape = Enum.PartType.Ball
		end
	end
	-- big tinted windows
	for _, sx in ipairs({-1, 1}) do
		for k = 0, 3 do
			P(store, "Window", V(18, 20, 0.3), C(sx * (31 + k * 22), 15, FZ + 1.15), RGB(70, 125, 165), M.Glass, {Transparency = 0.2, Reflectance = 0.25, CanCollide = false, CanQuery = false, CanTouch = false})
		end
	end
	-- the doorway: metal frame + two sliding glass doors standing open
	local METAL = RGB(150, 156, 168)
	for _, sx in ipairs({-1, 1}) do
		P(store, "DoorFrame", V(1.4, DOOR_H, 3.4), C(sx * 16.7, DOOR_H / 2, FZ), METAL, M.Metal, NOHIT)
		P(store, "SlidingDoor", V(8, DOOR_H - 1.5, 0.3), C(sx * 21.5, (DOOR_H - 1.5) / 2 + 0.2, FZ + 1.5), RGB(185, 225, 245), M.Glass, {Transparency = 0.45, CanCollide = false, CanQuery = false, CanTouch = false})
	end
	P(store, "DoorFrame", V(34.8, 1.4, 3.4), C(0, DOOR_H + 0.7, FZ), METAL, M.Metal, NOHIT)
end

-- product colours per department (shelves are stocked with a few big coloured blocks)
local PRODUCTS = {
	{RGB(230, 60, 50), RGB(255, 200, 40), RGB(110, 200, 60), RGB(255, 140, 40), RGB(150, 70, 160)},      -- Fruit & Veg
	{RGB(205, 145, 75), RGB(245, 210, 140), RGB(160, 95, 50), RGB(255, 235, 190), RGB(235, 130, 160)},   -- Bakery
	{RGB(250, 250, 255), RGB(120, 180, 255), RGB(255, 225, 90), RGB(200, 230, 255), RGB(255, 175, 195)}, -- Dairy
	{RGB(220, 70, 70), RGB(255, 155, 150), RGB(175, 40, 50), RGB(245, 205, 190), RGB(255, 110, 95)},     -- Butcher
	{RGB(170, 225, 255), RGB(250, 252, 255), RGB(255, 160, 200), RGB(110, 185, 255), RGB(255, 220, 120)}, -- Frozen
	{RGB(255, 100, 180), RGB(255, 210, 40), RGB(150, 90, 230), RGB(80, 200, 255), RGB(255, 130, 50)},    -- Snacks & Candy
	{RGB(220, 40, 40), RGB(255, 150, 30), RGB(60, 190, 90), RGB(60, 140, 255), RGB(240, 240, 245)},      -- Drinks
	{RGB(255, 70, 70), RGB(60, 140, 255), RGB(255, 210, 40), RGB(80, 200, 90), RGB(200, 110, 255)},      -- Toys
	{RGB(45, 48, 60), RGB(70, 110, 220), RGB(200, 205, 215), RGB(30, 30, 36), RGB(90, 200, 255)},        -- Electronics
	{RGB(255, 200, 40), RGB(240, 170, 30), RGB(255, 230, 120), RGB(210, 150, 40), RGB(90, 170, 90)},     -- Manager's Vault
}
local FRIDGES = {[3] = true, [5] = true, [7] = true} -- Dairy, Frozen and Drinks have glass-door fridges

-- the department name along a wall band (repeated on long walls)
local function bandText(band, face, text, width, count)
	count = count or math.max(1, math.floor(width / 45))
	local sg = surfaceGui(band, face, 10, 220)
	for k = 1, count do
		local tl = textLabel(sg, text, nil, 3)
		tl.AnchorPoint = Vector2.new(0.5, 0)
		tl.Position = UDim2.fromScale((k - 0.5) / count, 0.03)
		tl.Size = UDim2.fromScale(math.min(0.9 / count, 40 / width), 0.22)
	end
end

-- ONE DEPARTMENT: floor, walls, archway, ceiling, gondola aisles, wall shelves (or fridges),
-- pallets and its box spawns
local function buildDepartment(i)
	local area = Config.Areas[i]
	local acc = area.accent
	local pal = PRODUCTS[(i - 1) % #PRODUCTS + 1]
	local pmat = (i == NA) and M.Metal or M.SmoothPlastic -- the vault is full of gold
	local z0, z1 = Config.AreaStartZ(i), Config.AreaEndZ(i)
	local len, hw = Config.AreaLen(i), Config.AreaHalfWidth(i)
	local zc = (z0 + z1) / 2
	local title = string.upper(area.name)
	local dept = Instance.new("Model")
	dept.Name = "Dept" .. i .. "_" .. (area.name:gsub("[^%w]", ""))
	dept.Parent = store
	local pick = i * 2
	local function product(size, x, y, z) -- y = the shelf top it stands on
		pick += 3
		return solid(P(dept, "Product", size, C(x, y + size.Y / 2, z), pal[pick % #pal + 1], pmat))
	end

	-- light floor with a coloured lane down the middle
	P(dept, "Floor", V(hw * 2, 0.6, len), C(0, FY - 0.3, zc), RGB(236, 237, 241))
	P(dept, "LaneStripe", V(18, 0.04, len), C(0, FY + 0.02, zc), acc:Lerp(WHITE, 0.6), nil, NOHIT)
	for _, sx in ipairs({-1, 1}) do
		P(dept, "LaneLine", V(0.8, 0.06, len), C(sx * 9.4, FY + 0.03, zc), acc, nil, NOHIT)
	end

	-- walls on both sides, up to the ceiling: coloured lower band with the name, white trim, cream top
	for _, s in ipairs({-1, 1}) do
		P(dept, "Wall", V(2, WALL_H + 1.5, len), C(s * (hw + 1), (WALL_H + 1.5) / 2, zc), CREAM)
		local band = P(dept, "WallBand", V(0.4, 26 - FY, len), C(s * (hw - 0.2), (26 + FY) / 2, zc), acc, nil, NOHIT)
		P(dept, "WallTrim", V(0.5, 1, len), C(s * (hw - 0.25), 26.5, zc), WHITE, nil, NOHIT)
		P(dept, "WallCove", V(0.5, 1.2, len), C(s * (hw - 0.25), WALL_H - 0.6, zc), acc, nil, NOHIT)
		bandText(band, (s < 0) and Enum.NormalId.Right or Enum.NormalId.Left, title, len)
	end

	-- the way in: department 1 gets a hanging sign; the others an archway where the wall steps out
	if i == 1 then
		local hz = z0 - 22
		local sign = P(dept, "DeptSign", V(44, 7, 1), C(0, 31, hz), acc, nil, NOHIT)
		signText(sign, Enum.NormalId.Back, "1  " .. title, 16, 5, 300)
		for _, sx in ipairs({-18, 18}) do
			P(dept, "SignCable", V(0.2, WALL_H - 34.5, 0.2), C(sx, (WALL_H + 34.5) / 2, hz), RGB(60, 60, 70), M.Metal, NOHIT)
		end
	else
		local phw = Config.AreaHalfWidth(i - 1)
		for _, s in ipairs({-1, 1}) do
			-- the "shoulder": closes the step between the narrower room and this one
			local w = hw + 2 - phw
			P(dept, "Wall", V(w, WALL_H + 1.5, 2), C(s * (phw + w / 2), (WALL_H + 1.5) / 2, z0 + 1), acc)
			solid(P(dept, "ArchPillar", V(2.4, WALL_H, 2.4), C(s * (phw - 1.2), WALL_H / 2, z0 + 1.2), acc))
		end
		local arch = P(dept, "ArchSign", V(phw * 2, 10, 2), C(0, WALL_H - 5, z0), acc, nil, NOHIT)
		signText(arch, Enum.NormalId.Back, i .. "  " .. title, 10, 5, 400)
	end

	-- "SPEED 180 recommended" (or START HERE!) next to the lane
	do
		local sz = (i == 1) and (z0 - 21) or (z0 - 5)
		P(dept, "SpeedSignPost", V(0.5, 5.5, 0.5), C(-14, FY + 2.75, sz), RGB(70, 72, 82), M.Metal, NOHIT)
		local board = P(dept, "SpeedSign", V(8, 4.2, 0.4), C(-14, FY + 7.2, sz), acc, nil, NOHIT)
		local sg = surfaceGui(board, Enum.NormalId.Back, 24)
		if i == 1 then
			local t = textLabel(sg, "START HERE!", nil, 3)
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Position = UDim2.fromScale(0.5, 0.5)
			t.Size = UDim2.fromScale(0.9, 0.6)
		else
			local t = textLabel(sg, "SPEED " .. Config.FormatNum(Config.RecommendedPoints(i)), nil, 3)
			t.Position = UDim2.fromScale(0.05, 0.08)
			t.Size = UDim2.fromScale(0.9, 0.52)
			local t2 = textLabel(sg, "recommended", RGB(255, 245, 210), 2)
			t2.Position = UDim2.fromScale(0.12, 0.62)
			t2.Size = UDim2.fromScale(0.76, 0.28)
		end
	end

	-- ceiling with long glowing light panels (no lamps needed)
	P(dept, "Ceiling", V(hw * 2 + 4, 1.5, len), C(0, WALL_H + 0.75, zc), RGB(242, 242, 246))
	for _, f in ipairs({-0.55, 0, 0.55}) do
		P(dept, "CeilingLight", V(2.5, 0.3, len - 8), C(f * hw, WALL_H - 0.15, zc), RGB(255, 255, 250), M.Neon, NOHIT)
	end

	------------------------------------------------------------------
	-- layout: rows of gondolas on both sides of the centre lane (|x| < 10 stays clear,
	-- so the guard's post is clear too), wall shelves / fridges along both walls
	------------------------------------------------------------------
	local front = (i == 1) and 26 or 14 -- room for the checkouts / the archway
	local back = (i == 1) and 6 or 8
	local pitch = (i == 1) and 22 or 24
	local avail = len - front - back
	local rows = math.max(1, math.floor((avail - GD) / pitch) + 1)
	local zRow1 = z0 - front - (avail - ((rows - 1) * pitch + GD)) / 2 - GD / 2
	local gx0, gx1 = 12, hw - 13.5 -- from the lane to the walkway in front of the wall shelves
	local glen = gx1 - gx0
	local n = math.clamp(math.floor(glen / 12), 2, 4) -- product groups per side
	local slotLen = (glen - 1.6) / n
	local gondolas = {}
	for r = 1, rows do
		for _, s in ipairs({-1, 1}) do
			table.insert(gondolas, {s = s, z = zRow1 - (r - 1) * pitch})
		end
	end
	local fridges = FRIDGES[i]
	local wzA, wzB = z0 - ((i == 1) and 20 or 4), z1 + 4
	local wlen = wzA - wzB
	local bays = math.max(2, math.floor(wlen / 18))
	local bayLen = wlen / bays

	-- BOX SPAWNS: 8 + i per department, spread over the shelves, plus 1-3 pallets on the floor
	local pallets = math.min(3, 1 + math.floor(i / 4))
	local want = 8 + i - pallets
	local cands = {}
	for gi, g in ipairs(gondolas) do
		for _, sd in ipairs({-1, 1}) do
			for k = 1, n do
				table.insert(cands, {key = "g" .. gi .. ":" .. sd .. ":" .. k, r = math.random(),
					pos = V(g.s * (gx0 + 0.8 + (k - 0.5) * slotLen), DECK, g.z + sd * 3.5)})
			end
		end
	end
	if not fridges then
		for _, s in ipairs({-1, 1}) do
			for b = 1, bays do
				for l = 1, 2 do
					local half = (math.random() < 0.5) and -1 or 1
					table.insert(cands, {key = "w" .. s .. ":" .. b .. ":" .. l, r = math.random(), half = half,
						pos = V(s * (hw - 3.5), (l == 1) and DECK or SHELF2 + BOARD / 2, wzA - (b - 0.5) * bayLen + half * bayLen / 4)})
				end
			end
		end
	end
	-- front to back (ties shuffled), then take every few: spread over the whole department
	table.sort(cands, function(a, b)
		local za, zb = math.floor(a.pos.Z / 6), math.floor(b.pos.Z / 6)
		if za ~= zb then return za > zb end
		return a.r < b.r
	end)
	local chosen, spots = {}, {}
	for j = 1, math.min(want, #cands) do
		local c = cands[math.floor((j - 0.5) * #cands / want) + 1]
		chosen[c.key] = c
		table.insert(spots, {pos = c.pos, shelf = true})
	end

	-- GONDOLAS: double-sided shelves with a coloured end cap facing the lane
	for gi, g in ipairs(gondolas) do
		local s, z = g.s, g.z
		local xc = s * (gx0 + glen / 2)
		solid(P(dept, "GondolaBase", V(glen, 1, GD), C(xc, FY + 0.5, z), BASE_GREY))
		solid(P(dept, "GondolaSpine", V(glen, 11.5, 0.8), C(xc, DECK + 5.75, z), SHELF_WHITE))
		solid(P(dept, "GondolaShelf", V(glen, BOARD, GD - 0.4), C(xc, SHELF2, z), SHELF_WHITE))
		solid(P(dept, "EndCap", V(0.8, 13.4, GD + 0.4), C(s * (gx0 + 0.4), FY + 6.7, z), acc))
		solid(P(dept, "EndCap", V(0.8, 13.4, GD + 0.4), C(s * (gx1 - 0.4), FY + 6.7, z), SHELF_WHITE))
		for _, sd in ipairs({-1, 1}) do
			for k = 1, n do
				local x, pz = s * (gx0 + 0.8 + (k - 0.5) * slotLen), z + sd * 2
				if not chosen["g" .. gi .. ":" .. sd .. ":" .. k] then -- (a box spot stays empty)
					product(V(slotLen - 0.8, 3.4 + math.random() * 1.2, 3), x, DECK, pz)
				end
				product(V(slotLen - 0.8, 2.4 + math.random() * 0.8, 3), x, SHELF2 + BOARD / 2, pz)
			end
		end
	end

	-- WALL SHELVES: 3 long boards, bays split by uprights, one product block per bay and level
	local function wallShelf(s)
		local x, wzc = s * (hw - 2.65), (wzA + wzB) / 2
		solid(P(dept, "ShelfBase", V(4.5, 1, wlen), C(x, FY + 0.5, wzc), BASE_GREY))
		solid(P(dept, "Shelf", V(4.5, BOARD, wlen), C(x, SHELF2, wzc), SHELF_WHITE))
		solid(P(dept, "Shelf", V(4.5, BOARD, wlen), C(x, SHELF3, wzc), SHELF_WHITE))
		local topY = SHELF3 + BOARD / 2 + 0.4
		for b = 0, bays do
			local edge = (b == 0 or b == bays)
			solid(P(dept, "ShelfSide", V(4.7, topY - FY, edge and 0.6 or 0.4), C(x, (topY + FY) / 2, wzA - b * bayLen), edge and acc or SHELF_WHITE))
		end
		for b = 1, bays do
			local bz = wzA - (b - 0.5) * bayLen
			for l = 1, 3 do
				local y = (l == 1) and DECK or ((l == 2) and SHELF2 or SHELF3) + BOARD / 2
				local h = (l == 3) and (2 + math.random() * 0.8) or (3.4 + math.random() * 1.4)
				local c = chosen["w" .. s .. ":" .. b .. ":" .. l]
				if c then -- a box sits in one half of this bay
					product(V(3.2, h, bayLen / 2 - 0.8), s * (hw - 2.1), y, bz - c.half * bayLen / 4)
				else
					product(V(3.2, h, bayLen - 0.8), s * (hw - 2.1), y, bz)
				end
			end
		end
	end

	-- FRIDGES: a long cold case with glass doors, lit from inside
	local function fridge(s)
		local wzc = (wzA + wzB) / 2
		local top = FY + 17.5
		local gy0, gy1 = FY + 1.2, top - 2.4 -- the glass doors
		solid(P(dept, "FridgeBack", V(2, top - FY, wlen), C(s * (hw - 1.4), (top + FY) / 2, wzc), WHITE))
		solid(P(dept, "FridgeBase", V(5, 1.2, wlen), C(s * (hw - 2.9), FY + 0.6, wzc), RGB(80, 86, 98)))
		solid(P(dept, "FridgeTop", V(5.2, 2.4, wlen), C(s * (hw - 3), top - 1.2, wzc), acc))
		solid(P(dept, "FridgeGlass", V(0.3, gy1 - gy0, wlen), C(s * (hw - 5.25), (gy0 + gy1) / 2, wzc), RGB(200, 232, 255), M.Glass, {Transparency = 0.6}))
		P(dept, "FridgeLight", V(0.4, 0.3, wlen - 1), C(s * (hw - 4.7), gy1 - 0.4, wzc), WHITE, M.Neon, NOHIT)
		for _, y in ipairs({6.4, 11}) do
			P(dept, "FridgeShelf", V(3.4, 0.15, wlen), C(s * (hw - 3.9), y, wzc), RGB(225, 232, 240), M.Metal, NOHIT)
		end
		local doors = math.max(2, math.floor(wlen / 9 + 0.5))
		for d = 1, doors - 1 do
			P(dept, "FridgeDoor", V(0.5, gy1 - gy0, 0.45), C(s * (hw - 5.25), (gy0 + gy1) / 2, wzA - d * wlen / doors), RGB(215, 220, 228), M.Metal, NOHIT)
		end
		for b = 1, bays do
			local bz = wzA - (b - 0.5) * bayLen
			for _, y in ipairs({gy0, 6.475, 11.075}) do
				product(V(2.2, 3 + math.random() * 0.8, bayLen - 1), s * (hw - 3.7), y, bz)
			end
		end
	end
	for _, s in ipairs({-1, 1}) do
		if fridges then fridge(s) else wallShelf(s) end
	end

	-- PALLETS in the aisles next to the lane (big boxes can only spawn here)
	for p = 1, pallets do
		local aisle = math.floor((p - 0.5) * math.max(1, rows - 1) / pallets) + 1
		local s = (p % 2 == 1) and 1 or -1
		local z = (rows >= 2) and (zRow1 - (aisle - 0.5) * pitch) or (zRow1 + pitch / 2)
		P(dept, "PalletBase", V(6, 0.5, 6), C(s * 18, FY + 0.25, z), RGB(130, 90, 55), M.WoodPlanks)
		P(dept, "Pallet", V(6.2, 0.3, 6.2), C(s * 18, FY + 0.65, z), RGB(200, 150, 95), M.WoodPlanks)
		table.insert(spots, {pos = V(s * 18, FY + 0.8, z), shelf = false})
	end

	-- CHECKOUTS at the front of the store (the centre lane stays open)
	if i == 1 then
		for _, x in ipairs({-29, -15, 15, 29}) do
			local cz = z0 - 11
			solid(P(dept, "Checkout", V(3, 3.6, 12), C(x, FY + 1.8, cz), RGB(225, 45, 45)))
			P(dept, "Conveyor", V(2.4, 0.2, 7), C(x, FY + 3.7, cz - 2), RGB(35, 35, 40), nil, NOHIT)
			solid(P(dept, "Register", V(2, 1.6, 2), C(x, FY + 4.4, cz + 3.6), RGB(70, 72, 82)))
			P(dept, "LanePole", V(0.4, 6, 0.4), C(x, FY + 6.6, cz + 5.6), RGB(70, 72, 82), M.Metal, NOHIT)
			P(dept, "LaneLight", V(1.4, 1.4, 1.4), C(x, FY + 10.2, cz + 5.6), GOLD, M.Neon, NOHIT)
		end
	end

	-- the back wall of the whole store, with the manager's big round vault door
	if i == NA then
		P(dept, "BackWall", V(hw * 2 + 4, WALL_H + 1.5, 2), C(0, (WALL_H + 1.5) / 2, z1 - 1), CREAM)
		local band = P(dept, "WallBand", V(hw * 2, 26 - FY, 0.4), C(0, (26 + FY) / 2, z1 + 0.2), acc, nil, NOHIT)
		P(dept, "WallTrim", V(hw * 2, 1, 0.5), C(0, 26.5, z1 + 0.25), WHITE, nil, NOHIT)
		P(dept, "WallCove", V(hw * 2, 1.2, 0.5), C(0, WALL_H - 0.6, z1 + 0.25), acc, nil, NOHIT)
		bandText(band, Enum.NormalId.Back, title, hw * 2, 2)
		local function disc(name, thick, dia, z, color)
			local p = P(dept, name, V(thick, dia, dia), C(0, FY + 12.5, z) * CFrame.Angles(0, math.rad(90), 0), color, M.Metal, NOHIT)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		disc("VaultFrame", 0.4, 27, z1 + 0.6, RGB(70, 72, 82))
		disc("VaultDoor", 1, 24, z1 + 1, RGB(180, 185, 195))
		disc("VaultWheel", 0.6, 8, z1 + 1.7, GOLD)
		P(dept, "VaultSpoke", V(10, 0.8, 0.5), C(0, FY + 12.5, z1 + 2), GOLD, M.Metal, NOHIT)
		P(dept, "VaultSpoke", V(0.8, 10, 0.5), C(0, FY + 12.5, z1 + 2), GOLD, M.Metal, NOHIT)
	end

	-- the box spawns (front first): invisible pads, Position = bottom centre of the box
	table.sort(spots, function(a, b) return a.pos.Z > b.pos.Z end)
	for _, sp in ipairs(spots) do
		local p = P(spawnsF, "Spawn", V(2, 0.2, 2), CFrame.new(sp.pos), RGB(0, 0, 0), nil, GHOST)
		p:SetAttribute("Area", i)
		if sp.shelf then p:SetAttribute("Shelf", true) end
	end
end

------------------------------------------------------------------
-- SECURITY GUARDS: one per department, napping at his post in the middle of the lane.
-- Bigger + faster deeper in; the Store Manager guards the vault.
------------------------------------------------------------------
local GUARD_SIZE = {0.85, 1.0, 1.2, 1.4, 1.6, 1.85, 2.15, 2.45, 2.75, 3.2} -- x1.35 = the final scale
local NAVY, TROUSERS, BLACK = RGB(35, 52, 105), RGB(30, 30, 36), RGB(22, 22, 26)
local FX = {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}

local function makeGuard(i)
	local area = Config.Areas[i]
	local acc = area.accent
	local s = math.min(4.4, (GUARD_SIZE[i] or 3.2) * 1.35)
	local boss = (i == NA)
	local at = V(0, FY + 3 * s, Config.AreaStartZ(i) - Config.AreaLen(i) * 0.5)
	local cf = CFrame.new(at) * CFrame.Angles(0, math.pi, 0) -- turned around: faces the front door (+Z)
	local skin = Config.NoobColors.head
	local shirt = boss and RGB(48, 48, 58) or NAVY
	local m, R = Config.MakeR6({
		name = "Guardian" .. i, scale = s, cframe = cf, face = false,
		head = skin, torso = shirt, leftArm = shirt, rightArm = shirt, leftLeg = TROUSERS, rightLeg = TROUSERS,
	})
	m:SetAttribute("Area", i)
	m:SetAttribute("Scale", s)
	local head, torso = R.head, R.torso
	-- a detail glued onto a body part (offsets in body units, front = -z), so it moves with the animations
	local function G(name, size, to, x, y, z, color, mat, rot)
		local pcf = to.CFrame * CFrame.new(x * s, y * s, z * s)
		if rot then pcf = pcf * rot end
		return Config.Attach(P(m, name, size * s, pcf, color, mat or M.SmoothPlastic, FX), to)
	end
	local function tilt(deg) return CFrame.Angles(0, 0, math.rad(deg)) end
	-- face: eyes with eyelids (shut while he naps, the server opens them), grumpy brows, a mouth
	local lid = skin:Lerp(RGB(0, 0, 0), 0.12)
	for _, sx in ipairs({-1, 1}) do
		G("EyeWhite", V(0.3, 0.3, 0.04), head, sx * 0.25, 0.12, -0.625, WHITE)
		G("Pupil", V(0.14, 0.17, 0.04), head, sx * 0.24, 0.1, -0.645, RGB(25, 20, 20))
		G("Eyelid", V(0.34, 0.33, 0.05), head, sx * 0.25, 0.12, -0.672, lid)
		G("Brow", V(0.38, 0.09, 0.05), head, sx * 0.26, 0.36, -0.64, RGB(50, 35, 25), nil, tilt(sx * 10))
	end
	G("Mouth", V(0.44, 0.08, 0.04), head, 0, -0.28, -0.64, RGB(80, 25, 25))
	for _, leg in ipairs({R.leftLeg, R.rightLeg}) do
		G("Shoe", V(1.06, 0.45, 1.16), leg, 0, -0.8, -0.05, BLACK)
	end
	if boss then
		-- THE STORE MANAGER: dark suit, white shirt, gold tie and a fancy mustache
		G("Hair", V(1.32, 0.4, 1.32), head, 0, 0.62, 0.04, RGB(70, 45, 30))
		G("Mustache", V(0.62, 0.14, 0.09), head, 0, -0.15, -0.66, RGB(70, 45, 30))
		G("ShirtFront", V(0.6, 1.1, 0.05), torso, 0, 0.42, -0.515, WHITE)
		G("Tie", V(0.22, 1, 0.07), torso, 0, 0.3, -0.55, GOLD, M.Metal)
		for _, sx in ipairs({-1, 1}) do
			G("Lapel", V(0.36, 1.15, 0.06), torso, sx * 0.42, 0.38, -0.535, shirt:Lerp(RGB(0, 0, 0), 0.3), nil, tilt(sx * 12))
		end
		G("Badge", V(0.4, 0.22, 0.06), torso, -0.6, 0.55, -0.53, GOLD, M.Metal)
	else
		-- SECURITY GUARD: navy uniform, cap with a gold badge, black tie, radio, belt + baton,
		-- and armbands in the colour of his department
		G("Cap", V(1.42, 0.5, 1.42), head, 0, 0.77, 0, NAVY:Lerp(RGB(0, 0, 0), 0.25))
		G("CapBand", V(1.46, 0.16, 1.46), head, 0, 0.6, 0, acc)
		G("CapBrim", V(1.3, 0.08, 0.62), head, 0, 0.54, -0.82, BLACK, nil, CFrame.Angles(math.rad(-8), 0, 0))
		G("CapBadge", V(0.34, 0.32, 0.05), head, 0, 0.8, -0.73, GOLD, M.Metal)
		G("Tie", V(0.2, 0.9, 0.06), torso, 0, 0.35, -0.53, BLACK)
		G("Badge", V(0.32, 0.38, 0.06), torso, 0.5, 0.42, -0.53, GOLD, M.Metal)
		G("Radio", V(0.3, 0.45, 0.2), torso, -0.62, 0.62, -0.58, BLACK)
		G("Belt", V(2.06, 0.3, 1.08), torso, 0, -0.85, 0, BLACK)
		G("Buckle", V(0.42, 0.3, 0.08), torso, 0, -0.85, -0.56, GOLD, M.Metal)
		G("Baton", V(0.18, 1.4, 0.18), torso, 1.12, -1.15, -0.25, BLACK)
		for _, arm in ipairs({R.leftArm, R.rightArm}) do
			G("Armband", V(1.06, 0.3, 1.06), arm, 0, 0.45, 0, acc)
		end
	end

	-- Zzz (asleep) and ! (awake), sized in studs so they shrink with distance
	local function bb(name, text, color, studs, offset, enabled)
		local b = Instance.new("BillboardGui")
		b.Name = name
		b.Size = UDim2.fromScale(studs, studs)
		b.StudsOffset = offset
		b.MaxDistance = (name == "Alert") and 100 or 55
		b.LightInfluence = 0
		b.Enabled = enabled
		b.Parent = head
		textLabel(b, text, color, 3)
		return b
	end
	bb("Zzz", "Z", RGB(120, 220, 255), 0.9 * s, V(1.2 * s, 2.2 * s, 0), true)
	bb("Alert", "!", RGB(255, 40, 40), 1.2 * s, V(0, 2.6 * s, 0), false)
	-- name plate: dark card in the department colour, a chip and threat diamonds (more = harder)
	local pw = math.clamp(3.4 * s, 6, 12)
	local plate = Instance.new("BillboardGui")
	plate.Name = "NameTag"
	plate.Size = UDim2.fromScale(pw, pw * 0.27)
	plate.StudsOffset = V(0, 1.6 * s + pw * 0.14, 0)
	plate.MaxDistance = 60
	plate.LightInfluence = 0
	plate.Parent = head
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = RGB(20, 18, 30)
	card.BackgroundTransparency = 0.15
	card.Parent = plate
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = card
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 2.5
	cardStroke.Color = acc
	cardStroke.Parent = card
	local nameL = textLabel(card, string.upper(area.guard), nil, 2)
	nameL.Position = UDim2.fromScale(0.05, 0.06)
	nameL.Size = UDim2.fromScale(0.9, 0.5)
	local chip = Instance.new("Frame")
	chip.Position = UDim2.fromScale(0.05, 0.6)
	chip.Size = UDim2.fromScale(0.26, 0.3)
	chip.BackgroundColor3 = acc
	chip.Parent = card
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(1, 0)
	chipCorner.Parent = chip
	local chipL = textLabel(chip, boss and "BOSS" or "GUARD", nil, 1.5)
	chipL.Position = UDim2.fromScale(0.1, 0.08)
	chipL.Size = UDim2.fromScale(0.8, 0.84)
	local threat = math.clamp(math.ceil(i / 2), 1, 5)
	for k = 1, 5 do
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.fromScale(0.42 + (k - 1) * 0.11, 0.75)
		d.Size = UDim2.fromScale(0.055, 0.2)
		d.Rotation = 45
		d.BorderSizePixel = 0
		d.BackgroundColor3 = (k <= threat) and RGB(255, 70, 70) or RGB(70, 70, 85)
		d.Parent = card
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.Parent = d
	end
	-- red glow + rage sparks while he chases you (the server switches these on)
	local hl = Instance.new("Highlight")
	hl.Name = "Angry"
	hl.FillColor = RGB(255, 30, 30)
	hl.FillTransparency = 0.45
	hl.OutlineColor = RGB(255, 120, 120)
	hl.Enabled = false
	hl.Parent = m
	local rage = Instance.new("ParticleEmitter")
	rage.Name = "RageFX"
	rage.Enabled = false
	rage.Color = ColorSequence.new(RGB(255, 80, 30), RGB(255, 0, 0))
	rage.LightEmission = 1
	rage.Rate = 40
	rage.Lifetime = NumberRange.new(0.4, 0.8)
	rage.Speed = NumberRange.new(3, 6)
	rage.Size = NumberSequence.new(0.8 * s, 0)
	rage.SpreadAngle = Vector2.new(180, 180)
	rage.Acceleration = V(0, 6, 0)
	rage.Parent = torso

	m.Parent = guardsF
	m:PivotTo(cf) -- the server reads his post + facing from the pivot
end

for i = 1, NA do
	buildDepartment(i)
	makeGuard(i)
end

------------------------------------------------------------------
-- PLAYER BASES: 6 tidy little shops along the street (3 left, 3 right), facing the street.
-- Plot-local coords: u = sideways (-46..46), w = depth from the street (0..92).
-- Open floor (w 5..72): click it while carrying a box to place the box anywhere.
-- Back (w 81..88): the display shelf where shoppers buy your products.
------------------------------------------------------------------
local plots = folder(root, "Plots")
local PLOT_COLORS = {RGB(255, 170, 40), RGB(245, 245, 245), RGB(160, 90, 255), RGB(40, 200, 255), RGB(255, 90, 90), RGB(255, 220, 50)}
local CW, CD = Config.Court.plotWidth, Config.Court.plotDepth
local HU = CW / 2
local PLOT_Z = {6 + CW / 2, 6 + CW * 1.5 + 6, 6 + CW * 2.5 + 12}

local function buildPlot(i, side, zc)
	local col = PLOT_COLORS[i]
	local glow = col:Lerp(WHITE, 0.35)
	local m = Instance.new("Model")
	m.Name = "Plot" .. i
	m.Parent = plots
	local front = V(side * 16, 0, zc)
	local origin = CFrame.lookAt(front, front + V(side, 0, 0)) -- local -Z points into the plot
	local function W(u, y, w) return origin * CFrame.new(u, y, -w) end
	local function PP(name, size, u, y, w, color, mat, props, rot)
		local cf = W(u, y, w)
		if rot then cf = cf * rot end
		return P(m, name, size, cf, color, mat, props)
	end
	-- a dark board with the same title / level / rate text on both faces (the server updates it)
	local function upgradeSign(name, guiName, size, u, y, w, title, level, rate)
		local board = PP(name, size, u, y, w, RGB(30, 30, 38))
		PP(name .. "Trim", V(size.X + 0.3, 0.3, size.Z + 0.1), u, y + size.Y / 2, w, col, nil, NOHIT)
		for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
			local sg = surfaceGui(board, face, 40, 150)
			sg.Name = (face == Enum.NormalId.Front) and guiName or (guiName .. "Back")
			for _, row in ipairs({{"Title", title, 0.08, 0.36, WHITE}, {"Level", level, 0.46, 0.22, RGB(255, 230, 120)}, {"Rate", rate, 0.7, 0.22, RGB(120, 255, 40)}}) do
				local l = textLabel(sg, row[2], row[5], 3)
				l.Name = row[1]
				l.Position = UDim2.fromScale(0.05, row[3])
				l.Size = UDim2.fromScale(0.9, row[4])
			end
		end
		return board
	end
	local o = P(m, "PlotOrigin", V(1, 1, 1), origin, RGB(0, 0, 0), nil, GHOST)
	o:SetAttribute("Side", side)

	-- the clean shop floor you click to place boxes on, with a low border (open at the front)
	local floor = PP("PlotFloor", V(CW, 0.4, CD), 0, 0.2, CD / 2, col:Lerp(WHITE, 0.82))
	floor:SetAttribute("Placeable", true)
	local function border(u0, w0, u1, w1)
		local a, b = W(u0, 0, w0).Position, W(u1, 0, w1).Position
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 1.2
		local cf = CFrame.lookAt(mid, mid + (b - a).Unit)
		P(m, "Border", V(1.2, 2.2, len), cf + V(0, 1.1, 0), col, M.SmoothPlastic, NOHIT)
		P(m, "BorderCap", V(1.6, 0.4, len + 0.4), cf + V(0, 2.4, 0), WHITE, M.SmoothPlastic, NOHIT)
	end
	border(-HU, 0, -HU, CD)
	border(HU, 0, HU, CD)
	border(-HU, CD, HU, CD)
	border(-HU, 0, -12, 0)
	border(12, 0, HU, 0)
	PP("SpawnPoint", V(2, 0.2, 2), -18, 0.6, 10, RGB(0, 0, 0), nil, GHOST)

	-- THE SHOP: one long display shelf (5 units x 3 layers x 3 spots = 45 stands)
	local UW, UGAP = 15.6, 16.8
	local WIDE = UGAP * (Config.ShelfUnits - 1) + UW
	PP("ShelfBase", V(WIDE, 2, 5.6), 0, 1.2, 84, WHITE)
	PP("ShelfBack", V(WIDE + 1.2, 17, 0.6), 0, 8.6, 87.2, col)
	for _, y in ipairs({6.5, 10.9}) do
		PP("ShelfTier", V(WIDE, 0.4, 5.4), 0, y, 84.2, RGB(245, 245, 248))
	end
	PP("ShelfTop", V(WIDE + 1.2, 0.7, 6.2), 0, 15.6, 84, WHITE)
	for d = 0, Config.ShelfUnits do
		PP("ShelfSide", V(1, 15.4, 6), -WIDE / 2 - 0.6 + d * UGAP, 8, 84, WHITE)
	end
	-- the glowing price rail (the server uses its colour for empty spots)
	PP("GlowStrip", V(WIDE, 0.25, 0.3), 0, 16.1, 80.9, glow, M.Neon, NOHIT)
	for k = 1, Config.ShelfUnits do
		local cu = -33.6 + (k - 1) * UGAP
		for layer = 0, Config.ShelfLayers - 1 do
			local y = ({2.35, 6.85, 11.25})[layer + 1]
			for c = 0, Config.ShelfCols - 1 do
				local s = (k - 1) * Config.ShelfLayers * Config.ShelfCols + layer * Config.ShelfCols + c + 1
				local su = cu + (c - 1) * 5
				local stand = PP("Stand" .. s, V(4.4, 0.3, 4.2), su, y, 83.6, RGB(245, 245, 250))
				stand:SetAttribute("Slot", s)
				PP("StandTop" .. s, V(4.4, 0.12, 0.35), su, y + 0.05, 81.55, glow, M.Neon, NOHIT)
			end
		end
	end
	local shopSign = PP("ShopSign", V(26, 4.6, 0.6), 0, 19.4, 87, col)
	PP("ShopSignFrame", V(27.4, 6, 0.4), 0, 19.4, 87.4, WHITE)
	signText(shopSign, Enum.NormalId.Back, "SHOP", 40, 4, 200)

	-- TREADMILL (right front corner): run on the belt to earn speed, upgrade at the console
	do
		local TU = 34                 -- centre of the treadmill (sideways)
		local W0, W1 = 15, 35         -- belt from w 15 (console end) to w 35
		local metal, darkMetal = RGB(70, 74, 86), RGB(40, 42, 50)
		PP("TreadBase", V(11, 0.8, W1 - W0 + 4), TU, 0.8, (W0 + W1) / 2, metal, M.Metal)
		for _, sd in ipairs({-1, 1}) do
			PP("TreadRail", V(1, 1.2, W1 - W0 + 4), TU + sd * 5.2, 1.4, (W0 + W1) / 2, col)
			PP("TreadUpright", V(0.7, 5.2, 0.7), TU + sd * 4.2, 3.6, W0 - 0.6, darkMetal, M.Metal)
			PP("TreadSignPole", V(0.5, 2.6, 0.5), TU + sd * 4.2, 7.4, W0 - 0.6, darkMetal, M.Metal)
		end
		PP("TreadHandle", V(9, 0.6, 0.6), TU, 6, W0 - 0.6, col)
		local belt = PP("TreadBelt", V(8.4, 0.25, W1 - W0), TU, 1.32, (W0 + W1) / 2, RGB(28, 28, 32), M.Fabric)
		-- the belt runs by itself: step on and your character runs in place (client), jump to hop off
		local dir = (W(TU, 0, W1).Position - W(TU, 0, W0).Position).Unit
		belt:SetAttribute("BeltDir", dir)
		-- moving stripes on the belt (animated by the client)
		for k = 0, 6 do
			local stripe = PP("TreadStripe", V(8.2, 0.06, 0.5), TU, 1.47, W0 + 0.5, RGB(90, 90, 100), M.SmoothPlastic, NOHIT)
			stripe:SetAttribute("Start", W(TU, 1.47, W0 + 0.5))
			stripe:SetAttribute("Dir", dir)
			stripe:SetAttribute("Len", W1 - W0 - 1)
			stripe:SetAttribute("Offset", k * (W1 - W0 - 1) / 7)
			CS:AddTag(stripe, "TreadStripe")
		end
		local console = PP("TreadConsole", V(7, 2.8, 1), TU, 7.1, W0 - 1.2, darkMetal, M.Metal, nil, CFrame.Angles(math.rad(25), 0, 0))
		prompt(console, "ProximityPrompt", "Upgrade", "Treadmill", 0.3)
		upgradeSign("TreadSign", "TreadTag", V(9.4, 3.6, 0.4), TU, 10.4, W0 - 0.6,
			"TREADMILL", "Lv 1/" .. Config.Treadmill.max, "+" .. Config.FormatNum(Config.TreadRate(1)) .. " speed/s")
	end

	-- CUSTOMER KIOSK (front left corner): press the big red button to get more shoppers
	do
		local KU, KW = -32, 8
		PP("KioskBody", V(5.2, 6.4, 3.6), KU, 3.6, KW, col)
		PP("KioskTop", V(6, 0.5, 4.4), KU, 7.05, KW, WHITE)
		local horn = PP("Megaphone", V(2.6, 1.3, 1.3), KU, 8.4, KW - 0.4, WHITE, M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(90), 0))
		horn.Shape = Enum.PartType.Cylinder
		local bell = PP("MegaphoneBell", V(0.6, 2.6, 2.6), KU, 8.4, KW - 1.9, RGB(255, 90, 90), M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(90), 0))
		bell.Shape = Enum.PartType.Cylinder
		local button = PP("CustomerKiosk", V(0.6, 1.6, 1.6), KU, 4.4, KW - 1.95, RGB(255, 60, 60), M.Neon, nil, CFrame.Angles(0, math.rad(90), 0))
		button.Shape = Enum.PartType.Cylinder
		prompt(button, "ProximityPrompt", "Upgrade", "More Customers", 0.3)
		PP("KioskSignPole", V(0.5, 3.2, 0.5), KU, 8.9, KW + 1.4, RGB(60, 62, 72), M.Metal)
		upgradeSign("CustomerSign", "CustomerTag", V(7.4, 3.2, 0.4), KU, 11.9, KW + 1.4,
			"CUSTOMERS", "Lv 1/" .. Config.CustomerMax, "x1 shoppers")
	end

	-- name sign at the front (the server writes "<name>'s Base")
	PP("SignPostL", V(1, 16, 1), -11, 8, -0.8, col)
	PP("SignPostR", V(1, 16, 1), 11, 8, -0.8, col)
	local board = PP("SignBoard", V(24, 6, 0.8), 0, 15, -0.8, RGB(40, 40, 50))
	signText(board, Enum.NormalId.Front, "Empty Base", 40, 4, 200)
	signText(board, Enum.NormalId.Back, "Empty Base", 40, 4, 200)

	-- floating owner headshot (filled in by the server)
	local anchor = PP("TagAnchor", V(1, 1, 1), 0, 40, 46, RGB(0, 0, 0), nil, GHOST)
	local tag = Instance.new("BillboardGui")
	tag.Name = "OwnerTag"
	tag.Size = UDim2.fromOffset(96, 116)
	tag.MaxDistance = 400
	tag.LightInfluence = 0
	tag.Enabled = false
	tag.Parent = anchor
	local av = Instance.new("ImageLabel")
	av.Name = "Avatar"
	av.AnchorPoint = Vector2.new(0.5, 0)
	av.Position = UDim2.fromScale(0.5, 0)
	av.Size = UDim2.fromScale(0.8, 0.65)
	av.BackgroundColor3 = col
	av.Parent = tag
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = av
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(1, 0)
	ac.Parent = av
	local ast = Instance.new("UIStroke")
	ast.Thickness = 4
	ast.Color = Color3.new(0, 0, 0)
	ast.Parent = av
	local nm = textLabel(tag, "", nil, 3)
	nm.Name = "PlayerName"
	nm.Position = UDim2.fromScale(0, 0.7)
	nm.Size = UDim2.fromScale(1, 0.25)

	m:SetAttribute("Owner", 0)
end

local plotIndex = 0
for _, side in ipairs({-1, 1}) do
	for _, zc in ipairs(PLOT_Z) do
		plotIndex += 1
		buildPlot(plotIndex, side, zc)
	end
end

------------------------------------------------------------------
-- DONE: show the map
------------------------------------------------------------------
root.Parent = workspace
print("STEAL A BOX map built!")
