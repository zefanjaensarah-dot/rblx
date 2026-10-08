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
	local GRASS, SW = RGB(100, 210, 45), 16
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

-- (helpers the warehouse uses)
local function outline(part, thickness)
	local sb = Instance.new("SelectionBox")
	sb.Name = "Outline"
	sb.Adornee = part
	sb.Color3 = Color3.new(1, 1, 1)
	sb.LineThickness = thickness or 0.07
	sb.SurfaceTransparency = 1
	sb.Parent = part
	return part
end
local function OP(...) return outline(P(...)) end
local function surfaceText(part, face, text, color)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = part
	local tl = Instance.new("TextLabel")
	tl.Name = "Label"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.FontFace = Config.Font
	tl.TextScaled = true
	tl.TextColor3 = color
	tl.TextStrokeTransparency = 0.3
	tl.Text = Config.StripEmoji(text)
	tl.Parent = sg
	sg.MaxDistance = 140
	return sg
end

------------------------------------------------------------------
-- THE WAREHOUSE FRONT: a brick wall across the courtyard with a big open doorway
------------------------------------------------------------------
do
	local front = folder(root, "WarehouseFront")
	local FZ, FH, DOOR_HW, DOOR_H = FRONT_Z + 1, WALL_H, 20, 28
	local side = MAPW + 4 - DOOR_HW
	for _, sx in ipairs({-1, 1}) do
		P(front, "Wall", V(side, FH, 2), C(sx * (DOOR_HW + side / 2), FH / 2, FZ), RGB(185, 95, 75), M.Brick)
	end
	P(front, "Wall", V(DOOR_HW * 2, FH - DOOR_H, 2), C(0, (FH + DOOR_H) / 2, FZ), RGB(185, 95, 75), M.Brick)
	P(front, "WallCap", V(MAPW * 2 + 8, 1.6, 3), C(0, FH + 0.8, FZ), RGB(235, 225, 210))
	local sign = P(front, "WarehouseSign", V(56, 9, 0.6), C(0, DOOR_H + 6, FZ + 1.3), RGB(150, 95, 50), M.WoodPlanks, NOHIT)
	signText(sign, Enum.NormalId.Back, "WAREHOUSE", 16, 7, 600)
	-- the big metal door: open by day, the server closes it at night
	local door = P(front, "Barrier", V(DOOR_HW * 2, DOOR_H, 1), C(0, DOOR_H / 2, FZ), RGB(120, 125, 135), M.DiamondPlate, {Transparency = 1, CanCollide = false})
	door:SetAttribute("Door", true)
	local closedSign = surfaceGui(door, Enum.NormalId.Back, 12, 400)
	closedSign.Name = "ClosedSign"
	closedSign.Enabled = false
	local closedText = textLabel(closedSign, "CLOSED\nOpens at sunrise", RGB(255, 80, 70), 4)
	closedText.Size = UDim2.fromScale(0.9, 0.5)
	closedText.Position = UDim2.fromScale(0.05, 0.25)
end

------------------------------------------------------------------
-- THE WAREHOUSE: one long lane, 10 themed areas back to back
------------------------------------------------------------------
local L = Config.Layout
local SC = L.scale                -- every area is built 2x bigger
local F = L.floorY / SC           -- (design units below; helpers multiply by SC)
local WH = L.wallHeight / SC
local HW = L.halfWidth / SC
local SL = L.sectionLen / SC
local NA = #Config.Areas
local BACKZ = L.frontZ - NA * L.sectionLen

local wh = folder(root, "Warehouse")
local spawns = folder(root, "BoxSpawns")
local guardsFolder = folder(root, "Guards")
-- invisible walls keep you on the lane; you can still see the open zones around it
P(wh, "BackWall", V(L.halfWidth * 2 + 8, L.wallHeight, 4), C(0, L.wallHeight / 2, BACKZ - 2), RGB(60, 50, 70), M.SmoothPlastic)

------------------------------------------------------------------
-- section helpers. x = sideways (-35..35), d = depth into the area (0..50), y = height
------------------------------------------------------------------
local function SCF(r, x, y, d, rot)
	local cf = CFrame.new(x * SC, y * SC, r.z0 - d * SC)
	if rot then cf = cf * rot end
	return cf
end
local function D(r, name, size, x, y, d, color, mat, props, rot)
	return P(r.folder, name, size * SC, SCF(r, x, y, d, rot), color, mat, props)
end
local function ball(r, name, dia, x, y, d, color, mat, props)
	local p = D(r, name, V(dia, dia, dia), x, y, d, color, mat, props)
	p.Shape = Enum.PartType.Ball
	return p
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function pillar(r, name, h, dia, x, y, d, color, mat, props) -- vertical cylinder standing on y
	local p = D(r, name, V(h, dia, dia), x, y + h / 2, d, color, mat, props, UPRIGHT)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function disc(r, name, thick, dia, x, y, d, color, mat, props, rot) -- flat round plate
	local p = D(r, name, V(thick, dia, dia), x, y, d, color, mat, props, rot or UPRIGHT)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(60, (range or 16) * SC)
	l.Brightness = brightness or 1.5
	l.Parent = part
	return l
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end
-- ambient particles that fill an area (dust, snow, stars...)
local function ambience(r, colors, opts)
	local zone = D(r, "Ambience", V(HW * 2 - 4, 1, SL - 4), 0, opts.y or (WH - 2), SL / 2, RGB(0, 0, 0), nil, GHOST)
	local keys = {}
	for i, c in ipairs(colors) do table.insert(keys, ColorSequenceKeypoint.new((#colors == 1) and 0 or (i - 1) / (#colors - 1), c)) end
	if #colors == 1 then table.insert(keys, ColorSequenceKeypoint.new(1, colors[1])) end
	emitter(zone, {
		Color = ColorSequence.new(keys), Rate = opts.rate or 15, Lifetime = NumberRange.new(opts.life or 6, (opts.life or 6) + 3),
		Speed = NumberRange.new(opts.speed or 1), Size = NumberSequence.new(opts.size or 0.3), LightEmission = opts.glow or 0,
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(1, 1)}),
		EmissionDirection = opts.dir or Enum.NormalId.Bottom, Acceleration = opts.accel or Vector3.new(0, -1, 0),
		RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360), SpreadAngle = Vector2.new(20, 20),
	})
end
local NO_COLLIDE = {CanCollide = false}
local FX = {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}

------------------------------------------------------------------
-- AREA STYLES (old & dusty -> high-tech -> cosmic)
------------------------------------------------------------------
local STYLE = {
	{floor = RGB(110, 88, 64),  wallA = RGB(130, 112, 92), wallB = RGB(112, 95, 78),  shelf = RGB(105, 80, 55),  shelfMat = M.WoodPlanks, post = RGB(80, 60, 42)},
	{floor = RGB(190, 150, 90), wallA = RGB(190, 60, 48),  wallB = RGB(165, 50, 40),  shelf = RGB(150, 105, 60), shelfMat = M.WoodPlanks, post = RGB(245, 245, 245)},
	{floor = RGB(235, 238, 250),wallA = RGB(120, 190, 255),wallB = RGB(255, 210, 90), shelf = RGB(255, 90, 90),  shelfMat = M.SmoothPlastic, post = RGB(90, 170, 255)},
	{floor = RGB(255, 190, 225),wallA = RGB(255, 235, 245),wallB = RGB(170, 240, 220),shelf = RGB(255, 120, 190),shelfMat = M.SmoothPlastic, post = RGB(255, 255, 255)},
	{floor = RGB(226, 200, 140),wallA = RGB(40, 110, 190), wallB = RGB(30, 90, 165),  shelf = RGB(130, 92, 55),  shelfMat = M.WoodPlanks, post = RGB(90, 60, 35)},
	{floor = RGB(232, 226, 214),wallA = RGB(120, 160, 90), wallB = RGB(100, 140, 75), shelf = RGB(180, 150, 110),shelfMat = M.Wood, post = RGB(212, 175, 55)},
	{floor = RGB(225, 240, 252),wallA = RGB(200, 235, 255),wallB = RGB(170, 215, 245),shelf = RGB(160, 210, 240),shelfMat = M.Ice, post = RGB(235, 245, 255)},
	{floor = RGB(55, 60, 72),   wallA = RGB(35, 40, 55),   wallB = RGB(28, 32, 45),   shelf = RGB(70, 75, 90),   shelfMat = M.DiamondPlate, post = RGB(60, 170, 255)},
	{floor = RGB(70, 76, 88),   wallA = RGB(40, 55, 45),   wallB = RGB(30, 45, 36),   shelf = RGB(80, 90, 85),   shelfMat = M.Metal, post = RGB(90, 255, 90)},
	{floor = RGB(22, 16, 38),   wallA = RGB(30, 20, 55),   wallB = RGB(20, 12, 40),   shelf = RGB(40, 25, 70),   shelfMat = M.SmoothPlastic, post = RGB(255, 80, 200)},
}

------------------------------------------------------------------
-- GUARDIANS: weak & sleepy in area 1 ... terrifying in area 10
------------------------------------------------------------------
local LOOKS = {
	{scale = 0.85, shirt = RGB(150, 150, 160), pants = RGB(90, 90, 100), skin = RGB(240, 205, 175), hat = "cap", hatColor = RGB(90, 90, 100), eyes = RGB(20, 20, 20), extras = {"glasses", "mustache", "chair"}},
	{scale = 1.0, shirt = RGB(70, 110, 200), pants = RGB(30, 40, 85), skin = RGB(234, 184, 146), hat = "cap", hatColor = RGB(30, 40, 85), eyes = RGB(20, 20, 20), extras = {"badge"}},
	{scale = 1.2, shirt = RGB(235, 235, 245), pants = RGB(40, 40, 50), skin = RGB(200, 150, 110), hat = "cap", hatColor = RGB(40, 40, 50), eyes = RGB(20, 20, 20), extras = {"belly", "badge"}},
	{scale = 1.4, shirt = RGB(25, 25, 30), pants = RGB(25, 25, 30), skin = RGB(160, 110, 80), hat = nil, eyes = RGB(20, 20, 20), extras = {"shades", "bigarms"}},
	{scale = 1.6, shirt = RGB(170, 30, 40), pants = RGB(50, 35, 25), skin = RGB(220, 170, 130), hat = "tricorn", hatColor = RGB(30, 25, 25), eyes = RGB(20, 20, 20), extras = {"eyepatch", "beard", "bigarms"}},
	{scale = 1.85, shirt = RGB(40, 45, 55), pants = RGB(30, 33, 40), skin = RGB(200, 150, 110), hat = "helmet", hatColor = RGB(40, 45, 55), eyes = RGB(255, 60, 60), extras = {"visor", "shield", "bigarms"}},
	{scale = 2.15, shirt = RGB(245, 248, 255), pants = RGB(235, 240, 250), skin = RGB(245, 248, 255), hat = nil, eyes = RGB(80, 200, 255), extras = {"fur", "claws", "horns", "bigarms"}},
	{scale = 2.45, shirt = RGB(150, 160, 175), pants = RGB(90, 95, 110), skin = RGB(150, 160, 175), hat = "antenna", hatColor = RGB(60, 170, 255), eyes = RGB(255, 40, 40), extras = {"visorbar", "chestlight", "bigarms"}},
	{scale = 2.75, shirt = RGB(110, 60, 160), pants = RGB(70, 40, 110), skin = RGB(110, 230, 110), hat = "antenna", hatColor = RGB(90, 255, 90), eyes = RGB(10, 10, 10), extras = {"alieneyes", "hover", "bigarms"}},
	{scale = 3.2, shirt = RGB(15, 10, 25), pants = RGB(10, 6, 18), skin = RGB(20, 12, 30), hat = nil, eyes = RGB(255, 60, 220), extras = {"horns", "spikes", "cracks", "aura", "claws", "bigarms"}},
}

local function has(list, name)
	for _, v in ipairs(list) do if v == name then return true end end
	return false
end

local function makeGuardian(areaIndex, pos, accent)
	local area = Config.Areas[areaIndex]
	local look = LOOKS[areaIndex]
	local CS = game:GetService("CollectionService")
	local s = math.min(4.4, look.scale * 1.35)
	local F = L.floorY
	local base = F
	-- a classic R6 body in the area's outfit; every detail below is glued onto the body parts,
	-- so it moves with the R6 walk / idle animations
	local skin = (areaIndex <= 6) and Config.NoobColors.head or look.skin
	local m, R = Config.MakeR6({
		name = "Guardian" .. areaIndex, scale = s, cframe = CFrame.new(0, base + 3 * s, 0),
		head = skin, torso = look.shirt, leftLeg = look.pants, rightLeg = look.pants,
		face = false, -- every boss gets a detailed face made of parts
	})
	m:SetAttribute("Area", areaIndex)
	m:SetAttribute("Scale", s)
	local head, torso = R.head, R.torso
	local LA, RA, LL, RL = R.leftArm, R.rightArm, R.leftLeg, R.rightLeg
	local function partFor(oy) return (oy >= 3.95) and head or torso end
	-- decorations: positions in "body units" (feet at 0, torso centre 3, head centre 4.5, front = -z)
	local function G(name, size, ox, oy, oz, color, mat, rot, to, props)
		local cf = CFrame.new(ox * s, base + oy * s, oz * s)
		if rot then cf = cf * rot end
		local p = P(m, name, size * s, cf, color, mat or M.SmoothPlastic, FX)
		if props then for k, v in pairs(props) do p[k] = v end end
		return Config.Attach(p, to or partFor(oy))
	end
	local function GB(name, d, ox, oy, oz, color, mat, to, props)
		local p = G(name, V(d, d, d), ox, oy, oz, color, mat, nil, to, props)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local function ELL(name, size, ox, oy, oz, color, mat, to, rot) -- a squashed ball (ellipsoid)
		local p = G(name, size, ox, oy, oz, color, mat, rot, to)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	-- a rod from point a to point b (body units), w x h thick
	local UP = Vector3.new(0.01, 1, 0.02).Unit
	local function stick(name, a, b, w, h, color, mat, to, round)
		local pa = Vector3.new(a.X * s, base + a.Y * s, a.Z * s)
		local pb = Vector3.new(b.X * s, base + b.Y * s, b.Z * s)
		local len = (pb - pa).Magnitude
		local cf = CFrame.lookAt(pa, pb, UP) * CFrame.new(0, 0, -len / 2)
		local p
		if round then
			p = P(m, name, Vector3.new(len, w * s, w * s), cf * CFrame.Angles(0, math.rad(90), 0), color, mat or M.SmoothPlastic, FX)
			p.Shape = Enum.PartType.Cylinder
		else
			p = P(m, name, Vector3.new(w * s, (h or w) * s, len), cf, color, mat or M.SmoothPlastic, FX)
		end
		return Config.Attach(p, to or torso)
	end
	local function A(deg) return math.rad(deg) end
	local ROTZ = function(deg) return CFrame.Angles(0, 0, A(deg)) end
	local UPRIGHT_DISC = CFrame.Angles(0, 0, A(90))
	local shirt, pants = look.shirt, look.pants
	local dark = shirt:Lerp(RGB(0, 0, 0), 0.35)
	local light2 = shirt:Lerp(RGB(255, 255, 255), 0.35)
	local gold = RGB(255, 200, 40)
	local leather = RGB(60, 40, 28)
	local metal = RGB(170, 175, 185)
	local black = RGB(25, 25, 30)
	local white = RGB(245, 245, 250)

	------------------------------------------------------------------
	-- building blocks
	------------------------------------------------------------------
	-- a proper uniform: sleeves + cuffs, pockets, buttons, collar flaps, belt with pouches, boots
	local function uniform(o)
		o = o or {}
		for _, sx in ipairs({-1, 1}) do
			local arm = (sx < 0) and LA or RA
			local leg = (sx < 0) and LL or RL
			G("Sleeve", V(1.05, 1.32, 1.05), sx * 1.5, 3.36, 0, o.sleeve or shirt, nil, nil, arm)
			G("Cuff", V(1.09, 0.2, 1.09), sx * 1.5, 2.72, 0, o.cuff or dark, nil, nil, arm)
			if o.gloves then G("Glove", V(1.08, 0.62, 1.08), sx * 1.5, 2.3, 0, o.gloves, nil, nil, arm) end
			if o.epaulette then G("Epaulette", V(0.64, 0.14, 1.1), sx * 0.72, 4.03, 0, o.epaulette, nil, nil, torso) end
			local boot = o.boots or RGB(40, 32, 28)
			local bh = o.tallBoots and 1.25 or 0.7
			G("Boot", V(1.09, bh, 1.13), sx * 0.5, bh / 2, -0.02, boot, nil, nil, leg)
			G("BootSole", V(1.13, 0.12, 1.24), sx * 0.5, 0.06, -0.05, RGB(20, 18, 18), nil, nil, leg)
			G("ToeCap", V(1.0, 0.42, 0.26), sx * 0.5, 0.26, -0.6, boot:Lerp(RGB(255, 255, 255), 0.12), nil, nil, leg)
			if o.tallBoots then
				G("BootFlap", V(1.2, 0.26, 1.2), sx * 0.5, 1.28, 0, boot:Lerp(RGB(255, 255, 255), 0.08), nil, nil, leg)
			else
				G("PantCuff", V(1.07, 0.12, 1.07), sx * 0.5, 0.76, 0, pants:Lerp(RGB(0, 0, 0), 0.3), nil, nil, leg)
			end
			G("PantSeam", V(0.06, 1.3, 1.07), sx * 0.98, 1.35, 0, pants:Lerp(RGB(0, 0, 0), 0.25), nil, nil, leg)
			if not o.noPockets then
				G("Pocket", V(0.56, 0.48, 0.06), sx * 0.5, 3.38, -0.53, dark, nil, nil, torso)
				G("PocketFlap", V(0.6, 0.14, 0.08), sx * 0.5, 3.64, -0.54, dark:Lerp(RGB(0, 0, 0), 0.2), nil, nil, torso)
			end
			if not o.noCollar then
				G("CollarFlap", V(0.42, 0.3, 0.07), sx * 0.24, 3.86, -0.53, o.collar or light2, nil, ROTZ(sx * 28), torso)
			end
		end
		if not o.noButtons then
			for k = 0, 2 do GB("Button", 0.12, 0, 3.62 - k * 0.42, -0.54, o.buttons or gold, M.Metal, torso) end
		end
		G("Belt", V(2.07, 0.3, 1.08), 0, 2.15, 0, o.belt or leather, nil, nil, torso)
		G("Buckle", V(0.42, 0.3, 0.08), 0, 2.15, -0.56, gold, M.Metal, nil, torso)
		G("BuckleInner", V(0.22, 0.14, 0.09), 0, 2.15, -0.57, o.belt or leather, nil, nil, torso)
		if not o.noPouches then
			for _, sx in ipairs({-1, 1}) do
				G("Pouch", V(0.38, 0.36, 0.24), sx * 0.72, 2.1, -0.6, (o.belt or leather):Lerp(RGB(0, 0, 0), 0.2), nil, nil, torso)
				G("PouchFlap", V(0.4, 0.1, 0.26), sx * 0.72, 2.27, -0.6, (o.belt or leather):Lerp(RGB(0, 0, 0), 0.35), nil, nil, torso)
			end
		end
	end

	-- a face made of parts: eyes with pupils + shine, eyelids that close while he sleeps,
	-- brows, nose, mouth and ears
	local function face(o)
		o = o or {}
		local lid = skin:Lerp(RGB(0, 0, 0), 0.1)
		for _, sx in ipairs({-1, 1}) do
			if not o.noEyes then
				G("EyeWhite", V(0.3, 0.3, 0.04), sx * 0.25, 4.62, -0.625, o.eyeWhite or white, nil, nil, head)
				local pu = G("Pupil", V(0.14, 0.17, 0.04), sx * 0.24, 4.6, -0.645, o.pupil or RGB(25, 20, 20), o.glow and M.Neon or M.SmoothPlastic, nil, head)
				if o.glow then pu.Name = "GlowEye" end
				G("Glint", V(0.05, 0.05, 0.02), sx * 0.24 + 0.04, 4.65, -0.665, white, M.Neon, nil, head)
				if not o.noLids then
					-- eyelids (+ a lash line): the server hides these when he wakes up
					G("Eyelid", V(0.34, 0.33, 0.05), sx * 0.25, 4.62, -0.672, lid, nil, nil, head)
					G("Eyelid", V(0.3, 0.05, 0.02), sx * 0.25, 4.58, -0.7, RGB(40, 25, 20), nil, nil, head)
				end
			end
			if not o.noBrows then
				G("Brow", V(0.38, 0.09, 0.05), sx * 0.26, 4.86, -0.64, o.brow or RGB(50, 35, 25), nil, ROTZ(sx * (o.browAngle or -6)), head)
			end
			if not o.noEars then GB("Ear", 0.3, sx * 0.66, 4.5, 0, skin, nil, head) end
		end
		if not o.noNose then GB("Nose", 0.26, 0, 4.45, -0.65, skin:Lerp(RGB(255, 120, 110), 0.18), nil, head) end
		if not o.noMouth then
			G("Mouth", V(0.44, 0.08, 0.04), 0, 4.22, -0.64, RGB(80, 25, 25), nil, nil, head)
			if o.fangs then
				for _, sx in ipairs({-1, 1}) do G("Fang", V(0.09, 0.16, 0.04), sx * 0.13, 4.15, -0.65, white, nil, nil, head) end
			end
		end
	end

	-- a flat disc (cylinder lying flat)
	local FACE_FWD = CFrame.Angles(0, A(90), 0) -- a disc facing forward (instead of lying flat)
	local function disc(name, thick, d, ox, oy, oz, color, mat, to, rot)
		local p = G(name, V(thick, d, d), ox, oy, oz, color, mat, rot or UPRIGHT_DISC, to)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- fur tufts sticking out of a body part
	local function tufts(to, list, color)
		for i, t in ipairs(list) do
			G("Fur", V(0.36, 0.5, 0.3), t[1], t[2], t[3], (i % 2 == 0) and color or color:Lerp(RGB(170, 210, 255), 0.25), nil, CFrame.Angles(A(t[4] or 0), A(i * 37), A(t[5] or 0)), to)
		end
	end

	-- floating orbs that circle the boss (moved by the clients, not part of the body)
	local function bossOrbs(count, color, radius, height, size)
		for k = 1, count do
			local orb = P(guardsFolder, "BossOrb", V(size, size, size) * s, CFrame.new(pos + V(0, height * s, 0)), color, M.Neon, FX)
			orb.Shape = Enum.PartType.Ball
			orb:SetAttribute("Boss", "Guardian" .. areaIndex)
			orb:SetAttribute("Index", k)
			orb:SetAttribute("Count", count)
			orb:SetAttribute("Radius", radius * s)
			orb:SetAttribute("Height", height * s)
			CS:AddTag(orb, "BossOrb")
			light(orb, color, 6, 1.5)
			local a0 = Instance.new("Attachment")
			a0.Position = V(0, size * s * 0.4, 0)
			a0.Parent = orb
			local a1 = Instance.new("Attachment")
			a1.Position = V(0, -size * s * 0.4, 0)
			a1.Parent = orb
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Color = ColorSequence.new(color, RGB(255, 255, 255))
			tr.LightEmission = 1
			tr.Lifetime = 0.4
			tr.FaceCamera = true
			tr.Transparency = NumberSequence.new(0.1, 1)
			tr.Parent = orb
		end
	end

	------------------------------------------------------------------
	-- the 10 bosses
	------------------------------------------------------------------
	if areaIndex == 1 then
		-- SLEEPY WATCHMAN: old night guard with a striped nightcap, glasses, mustache and his coffee
		uniform({epaulette = RGB(120, 120, 130), boots = RGB(110, 80, 60), buttons = RGB(200, 200, 210)})
		face({browAngle = 10, brow = RGB(225, 225, 225)})
		for k, seg in ipairs({{1.34, 5.12, 0, 0}, {1.04, 5.42, 0.05, 0.05}, {0.74, 5.7, 0.12, 0.1}, {0.46, 5.95, 0.24, 0.18}}) do
			G("NightCap", V(seg[1], 0.34, seg[1]), seg[3], seg[2], seg[4], (k % 2 == 1) and RGB(80, 100, 175) or white, M.Fabric, ROTZ(-k * 6), head)
		end
		GB("CapPom", 0.36, 0.4, 6.12, 0.27, white, M.Fabric, head)
		for _, sx in ipairs({-1, 1}) do
			G("GlassLens", V(0.36, 0.3, 0.03), sx * 0.25, 4.62, -0.71, RGB(200, 230, 255), M.Glass, nil, head, {Transparency = 0.55})
			G("GlassRim", V(0.4, 0.05, 0.04), sx * 0.25, 4.78, -0.71, RGB(60, 50, 40), nil, nil, head)
			G("Mustache", V(0.38, 0.13, 0.09), sx * 0.17, 4.33, -0.66, RGB(230, 230, 230), nil, ROTZ(-sx * 14), head)
		end
		G("GlassBridge", V(0.16, 0.04, 0.04), 0, 4.66, -0.71, RGB(60, 50, 40), nil, nil, head)
		-- flashlight in his right hand
		stick("Flashlight", V(1.5, 2.0, -0.2), V(1.5, 1.95, -1.3), 0.3, 0.3, RGB(30, 30, 35), M.Metal, RA, true)
		disc("FlashlightLens", 0.06, 0.36, 1.5, 1.95, -1.31, RGB(255, 245, 190), M.Neon, RA, FACE_FWD)
		-- coffee mug with steam in his left hand
		local mug = G("Mug", V(0.5, 0.44, 0.44), -1.5, 1.75, -0.35, white, nil, UPRIGHT_DISC, LA)
		mug.Shape = Enum.PartType.Cylinder
		disc("Coffee", 0.04, 0.38, -1.5, 1.98, -0.35, RGB(90, 55, 30), nil, LA)
		G("MugHandle", V(0.08, 0.3, 0.2), -1.5, 1.75, -0.08, white, nil, nil, LA)
		emitter(mug, {Color = ColorSequence.new(RGB(255, 255, 255)), Transparency = NumberSequence.new(0.6, 1), Rate = 4,
			Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(1, 2), Size = NumberSequence.new(0.2 * s, 0.6 * s), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10)})
		-- a big ring of keys on his belt
		local ring = G("KeyRing", V(0.05, 0.34, 0.34), 0.95, 2.0, -0.35, metal, M.Metal, CFrame.Angles(0, A(90), 0), torso)
		ring.Shape = Enum.PartType.Cylinder
		for k = 1, 3 do G("Key", V(0.07, 0.3, 0.05), 0.88 + k * 0.06, 1.82, -0.42, gold, M.Metal, ROTZ(-15 + k * 12), torso) end

	elseif areaIndex == 2 then
		-- ROOKIE GUARD (farm): cowboy hat, bandana, badge, straw in his mouth and a pitchfork
		uniform({epaulette = gold})
		face({browAngle = -4})
		disc("HatBrim", 0.12, 2.2, 0, 5.08, 0, RGB(225, 185, 95), M.Fabric, head)
		G("HatCrown", V(1.15, 0.62, 1.05), 0, 5.42, 0, RGB(225, 185, 95), M.Fabric, nil, head)
		G("HatDent", V(0.2, 0.1, 1.06), 0, 5.72, 0, RGB(200, 160, 75), M.Fabric, nil, head)
		G("HatBand", V(1.17, 0.14, 1.07), 0, 5.18, 0, RGB(200, 50, 45), nil, nil, head)
		G("Bandana", V(0.7, 0.7, 0.06), 0, 3.72, -0.54, RGB(220, 50, 50), M.Fabric, CFrame.Angles(0, 0, A(45)), torso)
		for k = 0, 3 do GB("BandanaDot", 0.09, -0.15 + k * 0.1, 3.72 - (k % 2) * 0.12, -0.58, white, nil, torso) end
		G("Badge", V(0.32, 0.38, 0.06), 0.5, 3.42, -0.575, gold, M.Metal, nil, torso)
		stick("Straw", V(0.12, 4.22, -0.68), V(0.6, 4.05, -0.95), 0.05, 0.05, RGB(240, 210, 90), nil, head, true)
		-- pitchfork
		stick("ForkShaft", V(1.55, 0.4, -0.6), V(1.55, 5.6, -0.62), 0.16, 0.16, RGB(150, 105, 60), M.Wood, RA, true)
		G("ForkHead", V(0.95, 0.12, 0.12), 1.55, 5.62, -0.62, metal, M.Metal, nil, RA)
		for k = -1, 1 do G("ForkTine", V(0.08, 0.7, 0.08), 1.55 + k * 0.4, 6.0, -0.62, metal, M.Metal, nil, RA) end

	elseif areaIndex == 3 then
		-- MALL COP: police hat, aviators, shoulder radio, whistle, baton and a big belly
		uniform({epaulette = RGB(40, 40, 50), buttons = RGB(40, 40, 50), noButtons = true, noPockets = true, boots = RGB(20, 20, 24)})
		face({browAngle = 12})
		ELL("Belly", V(2.1, 1.45, 0.75), 0, 2.78, -0.38, shirt, nil, torso)
		for k = 0, 2 do GB("Button", 0.13, 0, 3.3 - k * 0.38, -0.78 + k * 0.03, RGB(40, 40, 50), nil, torso) end
		G("CopHat", V(1.42, 0.5, 1.42), 0, 5.27, 0, RGB(30, 35, 55), nil, nil, head)
		G("CopHatTop", V(1.6, 0.13, 1.6), 0, 5.55, 0, RGB(30, 35, 55), nil, nil, head)
		G("CopBrim", V(1.3, 0.08, 0.62), 0, 5.04, -0.82, RGB(15, 15, 18), nil, CFrame.Angles(A(-8), 0, 0), head, {Reflectance = 0.2})
		G("HatBadge", V(0.34, 0.32, 0.05), 0, 5.3, -0.73, gold, M.Metal, nil, head)
		for _, sx in ipairs({-1, 1}) do
			G("Aviator", V(0.38, 0.28, 0.04), sx * 0.25, 4.6, -0.71, RGB(30, 30, 40), M.Glass, nil, head, {Transparency = 0.15, Reflectance = 0.35})
		end
		G("AviatorBridge", V(0.18, 0.04, 0.04), 0, 4.68, -0.71, gold, M.Metal, nil, head)
		G("ShoulderRadio", V(0.3, 0.45, 0.2), 0.72, 3.75, -0.56, black, nil, nil, torso)
		stick("RadioAntenna", V(0.8, 3.95, -0.56), V(0.84, 4.5, -0.56), 0.05, 0.05, black, nil, torso, true)
		G("Whistle", V(0.25, 0.2, 0.35), -0.3, 3.55, -0.75, RGB(230, 230, 240), M.Metal, nil, torso)
		G("NamePlate", V(0.5, 0.12, 0.05), -0.5, 3.75, -0.565, gold, M.Metal, nil, torso)
		stick("Baton", V(1.08, 2.4, -0.3), V(1.08, 1.0, -0.36), 0.16, 0.16, black, nil, torso, true)
		stick("Flashlight", V(1.5, 2.0, -0.2), V(1.5, 1.95, -1.2), 0.28, 0.28, RGB(30, 30, 35), M.Metal, RA, true)

	elseif areaIndex == 4 then
		-- CANDY BOUNCER: black suit + tie, shades, earpiece, gold chain and a candy-cane bat
		uniform({sleeve = shirt, cuff = white, noPockets = true, noButtons = true, noCollar = true, boots = RGB(15, 15, 18), belt = RGB(15, 15, 18)})
		face({browAngle = 16, noEyes = true})
		G("ShirtFront", V(0.55, 1.05, 0.05), 0, 3.45, -0.515, white, nil, nil, torso)
		G("Tie", V(0.2, 0.9, 0.06), 0, 3.35, -0.55, RGB(255, 80, 170), nil, nil, torso)
		G("TieKnot", V(0.26, 0.2, 0.08), 0, 3.85, -0.56, RGB(230, 50, 140), nil, nil, torso)
		for _, sx in ipairs({-1, 1}) do
			G("Lapel", V(0.36, 1.15, 0.06), sx * 0.4, 3.4, -0.535, RGB(40, 40, 48), nil, ROTZ(sx * 12), torso)
			GB("Muscle", 1.05, sx * 1.55, 3.6, 0, shirt, nil, (sx < 0) and LA or RA)
		end
		G("Shades", V(1.18, 0.3, 0.08), 0, 4.62, -0.68, RGB(10, 10, 14), M.Glass, nil, head, {Reflectance = 0.45})
		GB("Earpiece", 0.16, 0.66, 4.48, -0.12, black, nil, head)
		stick("EarWire", V(0.66, 4.4, -0.1), V(0.55, 3.85, 0.1), 0.04, 0.04, RGB(200, 200, 210), nil, head, true)
		for k = 0, 11 do
			local a = (k / 12) * math.pi * 2
			GB("Chain", 0.15, math.cos(a) * 0.6, 3.92 - math.max(0, -math.sin(a)) * 0.25, math.sin(a) * 0.42, gold, M.Metal, torso)
		end
		-- candy cane bat (red / white segments + a hook)
		for k = 0, 6 do
			G("CaneSeg", V(0.3, 0.55, 0.3), 1.55, 0.9 + k * 0.52, -0.65, (k % 2 == 0) and RGB(230, 40, 50) or white, nil, ROTZ(8), RA)
		end
		stick("CaneHook", V(1.95, 4.55, -0.65), V(2.4, 4.85, -0.65), 0.3, 0.3, RGB(230, 40, 50), nil, RA)
		stick("CaneHook2", V(2.4, 4.85, -0.65), V(2.6, 4.4, -0.65), 0.3, 0.3, white, nil, RA)

	elseif areaIndex == 5 then
		-- PIRATE BRUTE: long red coat, tricorn with a feather, eyepatch, braided beard, cutlass and a parrot
		uniform({sleeve = shirt, cuff = gold, buttons = gold, noPockets = true, tallBoots = true, boots = RGB(25, 20, 18), belt = RGB(40, 40, 110)})
		face({browAngle = 18, noEyes = false})
		for _, sx in ipairs({-1, 1}) do
			G("CoatTail", V(0.95, 1.7, 0.12), sx * 0.5, 1.25, 0.55, shirt, M.Fabric, CFrame.Angles(A(6), 0, 0), torso)
			G("CoatTrim", V(0.12, 2.0, 0.06), sx * 0.34, 3, -0.535, gold, nil, nil, torso)
		end
		G("Sash", V(2.1, 0.42, 1.1), 0, 2.22, 0, RGB(40, 40, 110), M.Fabric, nil, torso)
		G("SashKnot", V(0.35, 0.6, 0.15), 0.6, 1.95, -0.58, RGB(40, 40, 110), M.Fabric, ROTZ(-20), torso)
		G("Tricorn", V(2.2, 0.35, 1.6), 0, 5.22, 0, RGB(30, 25, 25), nil, nil, head)
		G("TricornTop", V(1.3, 0.6, 1.2), 0, 5.62, 0, RGB(30, 25, 25), nil, nil, head)
		G("TricornTrim", V(2.24, 0.08, 1.64), 0, 5.4, 0, gold, M.Metal, nil, head)
		G("Skull", V(0.36, 0.34, 0.05), 0, 5.58, -0.62, white, nil, nil, head)
		stick("Feather", V(0.5, 5.6, 0.2), V(1.05, 6.6, 0.55), 0.14, 0.4, white, M.Fabric, head)
		G("Eyepatch", V(0.38, 0.36, 0.06), -0.25, 4.62, -0.7, black, nil, nil, head)
		G("PatchStrap", V(0.95, 0.06, 0.04), -0.05, 4.8, -0.68, black, nil, ROTZ(-22), head)
		G("Beard", V(1.15, 0.6, 0.32), 0, 4.06, -0.55, RGB(70, 40, 22), M.Fabric, nil, head)
		for _, sx in ipairs({-1, 1}) do
			G("Braid", V(0.17, 0.55, 0.17), sx * 0.2, 3.6, -0.66, RGB(70, 40, 22), M.Fabric, nil, head)
			GB("BraidBead", 0.2, sx * 0.2, 3.3, -0.66, gold, M.Metal, head)
		end
		local ear = G("Earring", V(0.05, 0.24, 0.24), -0.7, 4.33, -0.05, gold, M.Metal, nil, head)
		ear.Shape = Enum.PartType.Cylinder
		-- cutlass: hilt in the right hand, blade pointing forward
		G("Hilt", V(0.5, 0.12, 0.5), 1.5, 1.92, -0.45, gold, M.Metal, nil, RA)
		stick("Blade", V(1.5, 1.9, -0.6), V(1.5, 1.35, -3.0), 0.08, 0.34, metal, M.Metal, RA)
		-- the parrot on his shoulder
		ELL("ParrotBody", V(0.45, 0.62, 0.45), -0.8, 4.32, 0.05, RGB(230, 40, 40), nil, torso)
		GB("ParrotHead", 0.36, -0.8, 4.7, -0.05, RGB(230, 40, 40), nil, torso)
		G("ParrotBeak", V(0.13, 0.16, 0.2), -0.8, 4.66, -0.27, RGB(255, 200, 40), nil, nil, torso)
		for _, wx in ipairs({-1.05, -0.55}) do G("ParrotWing", V(0.1, 0.45, 0.36), wx, 4.3, 0.06, RGB(40, 110, 230), nil, nil, torso) end
		G("ParrotTail", V(0.16, 0.55, 0.1), -0.8, 3.92, 0.27, RGB(50, 190, 80), nil, CFrame.Angles(A(-20), 0, 0), torso)
		for _, ex in ipairs({-0.9, -0.7}) do GB("ParrotEye", 0.07, ex, 4.76, -0.18, black, nil, torso) end

	elseif areaIndex == 6 then
		-- RIOT GUARD: helmet with a dark visor, body armour, pads, riot shield and baton. Red eyes.
		local armor = RGB(55, 60, 72)
		uniform({sleeve = dark, gloves = black, boots = black, noPockets = true, noButtons = true, noCollar = true})
		face({glow = true, pupil = RGB(255, 50, 50), eyeWhite = RGB(40, 10, 10), noLids = false, noBrows = true, browAngle = 20})
		G("ChestPlate", V(1.72, 1.25, 0.26), 0, 3.35, -0.56, armor, M.Metal, nil, torso)
		for k = 0, 2 do G("PlateRidge", V(1.5, 0.08, 0.06), 0, 3.0 + k * 0.32, -0.7, armor:Lerp(RGB(255, 255, 255), 0.25), nil, nil, torso) end
		G("BackPlate", V(1.72, 1.6, 0.22), 0, 3.15, 0.56, armor, M.Metal, nil, torso)
		for _, sx in ipairs({-1, 1}) do
			local arm, leg = (sx < 0) and LA or RA, (sx < 0) and LL or RL
			G("ShoulderPad", V(1.28, 0.48, 1.24), sx * 1.52, 3.98, 0, armor, M.Metal, ROTZ(-sx * 12), arm)
			G("ElbowPad", V(1.12, 0.32, 0.36), sx * 1.5, 2.95, -0.45, armor, M.Metal, nil, arm)
			G("KneePad", V(1.1, 0.42, 0.28), sx * 0.5, 1.05, -0.55, armor, M.Metal, nil, leg)
		end
		G("Helmet", V(1.52, 0.85, 1.52), 0, 5.05, 0, RGB(40, 45, 55), M.Metal, nil, head)
		G("HelmetRidge", V(0.26, 0.2, 1.45), 0, 5.5, 0, RGB(30, 33, 40), M.Metal, nil, head)
		G("Visor", V(1.38, 0.62, 0.08), 0, 4.62, -0.74, RGB(30, 30, 40), M.Glass, nil, head, {Transparency = 0.35, Reflectance = 0.3})
		-- riot shield on his left arm (see-through, with a dark window band)
		G("Shield", V(0.25, 2.7, 1.85), -2.15, 3, -0.6, RGB(150, 200, 255), M.Glass, nil, LA, {Transparency = 0.45})
		G("ShieldRim", V(0.27, 2.75, 0.1), -2.15, 3, -1.53, RGB(40, 45, 55), M.Metal, nil, LA)
		G("ShieldRim", V(0.27, 2.75, 0.1), -2.15, 3, 0.33, RGB(40, 45, 55), M.Metal, nil, LA)
		G("ShieldBand", V(0.28, 0.35, 1.85), -2.15, 3.6, -0.6, RGB(255, 255, 255), nil, nil, LA)
		stick("Baton", V(1.5, 2.0, -0.2), V(1.5, 1.6, -1.8), 0.17, 0.17, black, nil, RA, true)
		light(head, RGB(255, 60, 60), 6 * s, 2)

	elseif areaIndex == 7 then
		-- YETI GUARD: shaggy white fur, horns, fangs, claws, an ice club and frosty breath. Blue eyes.
		local fur = look.skin
		face({glow = true, pupil = RGB(80, 200, 255), eyeWhite = RGB(20, 40, 70), browAngle = 22, brow = RGB(200, 210, 230), fangs = true, noEars = true})
		G("Muzzle", V(0.75, 0.45, 0.25), 0, 4.28, -0.6, RGB(210, 225, 245), nil, nil, head)
		GB("Nose", 0.24, 0, 4.48, -0.72, RGB(60, 90, 140), nil, head)
		tufts(torso, {{-0.8, 3.8, -0.4, -20, 10}, {0.8, 3.8, -0.4, -20, -10}, {-0.6, 2.4, -0.45, 10}, {0.6, 2.4, -0.45, 10}, {0, 3.1, -0.48, 0}, {-0.95, 2.9, 0.3, 0, 20}, {0.95, 2.9, 0.3, 0, -20}, {0, 3.6, 0.5, 15}}, fur)
		tufts(LA, {{-1.95, 3.6, 0, 0, 30}, {-1.95, 2.8, 0, 0, 40}, {-1.5, 3.2, -0.48, -20}}, fur)
		tufts(RA, {{1.95, 3.6, 0, 0, -30}, {1.95, 2.8, 0, 0, -40}, {1.5, 3.2, -0.48, -20}}, fur)
		tufts(LL, {{-0.95, 1.2, 0, 0, 30}, {-0.5, 0.6, -0.5, -15}}, fur)
		tufts(RL, {{0.95, 1.2, 0, 0, -30}, {0.5, 0.6, -0.5, -15}}, fur)
		tufts(head, {{-0.4, 5.15, 0, 0, 20}, {0, 5.25, 0.1, 0}, {0.4, 5.15, 0, 0, -20}, {-0.62, 4.8, 0.1, 0, 40}, {0.62, 4.8, 0.1, 0, -40}}, fur)
		for _, sx in ipairs({-1, 1}) do
			stick("Horn", V(sx * 0.45, 5.1, 0), V(sx * 0.95, 5.65, 0.1), 0.26, 0.26, RGB(225, 225, 235), nil, head, true)
			stick("HornTip", V(sx * 0.95, 5.65, 0.1), V(sx * 1.05, 6.15, -0.05), 0.16, 0.16, RGB(190, 220, 255), M.Ice, head, true)
			local arm = (sx < 0) and LA or RA
			for k = -1, 1 do stick("Claw", V(sx * 1.5 + k * 0.28, 2.0, -0.3), V(sx * 1.5 + k * 0.3, 1.5, -0.6), 0.12, 0.12, RGB(30, 35, 45), nil, arm) end
		end
		-- ice club
		stick("ClubHandle", V(1.55, 1.9, -0.4), V(1.55, 1.2, -2.2), 0.24, 0.24, RGB(110, 80, 60), M.Wood, RA, true)
		for k = 1, 4 do
			G("ClubIce", V(0.6, 0.9, 0.6), 1.55 + (k - 2.5) * 0.2, 1.15 + (k % 2) * 0.2, -2.3 - k * 0.12, RGB(150, 215, 255), M.Ice, CFrame.Angles(A(k * 23), A(k * 41), A(k * 17)), RA, {Transparency = 0.15})
		end
		local breath = G("Breath", V(0.3, 0.3, 0.3), 0, 4.2, -0.8, white, nil, nil, head, {Transparency = 1})
		emitter(breath, {Color = ColorSequence.new(RGB(230, 245, 255)), Transparency = NumberSequence.new(0.4, 1), Rate = 8, Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.2 * s, 0.8 * s), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(15, 15)})
		emitter(torso, {Color = ColorSequence.new(RGB(200, 235, 255)), LightEmission = 0.6, Rate = 6, Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(1, 2), Size = NumberSequence.new(0.25 * s, 0), SpreadAngle = Vector2.new(180, 180)})
		light(head, RGB(80, 200, 255), 6 * s, 2)

	elseif areaIndex == 8 then
		-- SECURITY MECH: metal armour plates, a glowing reactor core, visor, antenna, shoulder cannon and a jetpack
		local plate, plateDark, neon = RGB(150, 160, 175), RGB(70, 76, 90), RGB(60, 170, 255)
		face({noEyes = true, noBrows = true, noNose = true, noMouth = true, noEars = true})
		G("HeadPlate", V(1.42, 1.2, 1.42), 0, 4.55, 0.02, plate, M.Metal, nil, head)
		G("Visor", V(1.2, 0.28, 0.1), 0, 4.62, -0.72, RGB(255, 40, 40), M.Neon, nil, head).Name = "GlowEye"
		G("VisorFrame", V(1.3, 0.4, 0.06), 0, 4.62, -0.7, plateDark, M.Metal, nil, head)
		G("JawPlate", V(1.0, 0.35, 0.12), 0, 4.15, -0.7, plateDark, M.Metal, nil, head)
		for k = -1, 1 do G("Grill", V(0.12, 0.2, 0.04), k * 0.25, 4.15, -0.77, RGB(20, 20, 25), nil, nil, head) end
		stick("Antenna", V(0.45, 5.2, 0), V(0.5, 6.4, 0.05), 0.08, 0.08, plateDark, M.Metal, head, true)
		local tip = GB("AntennaTip", 0.26, 0.5, 6.45, 0.05, RGB(255, 50, 50), M.Neon, head)
		tip:SetAttribute("Blink", 0)
		G("ChestPlate", V(1.8, 1.4, 0.3), 0, 3.3, -0.56, plate, M.Metal, nil, torso)
		disc("ReactorRing", 0.12, 0.85, 0, 3.4, -0.73, plateDark, M.Metal, torso, FACE_FWD)
		local core = G("Reactor", V(0.14, 0.6, 0.6), 0, 3.4, -0.76, neon, M.Neon, CFrame.Angles(0, A(90), 0), torso)
		core.Shape = Enum.PartType.Cylinder
		core.Name = "GlowEye"
		light(core, neon, 10, 2)
		for k = 0, 2 do G("Vent", V(0.5, 0.06, 0.05), -0.55, 2.75 + k * 0.14, -0.72, RGB(20, 20, 25), nil, nil, torso) end
		G("HazardStripe", V(1.82, 0.22, 0.32), 0, 2.2, -0.56, RGB(255, 200, 30), nil, nil, torso)
		for _, sx in ipairs({-1, 1}) do
			local arm, leg = (sx < 0) and LA or RA, (sx < 0) and LL or RL
			G("ShoulderPlate", V(1.3, 0.55, 1.28), sx * 1.52, 4.0, 0, plate, M.Metal, ROTZ(-sx * 10), arm)
			G("Forearm", V(1.12, 0.9, 1.12), sx * 1.5, 2.45, 0, plateDark, M.Metal, nil, arm)
			GB("JointLight", 0.3, sx * 1.02, 3.75, -0.2, neon, M.Neon, arm)
			G("ThighPlate", V(1.1, 0.8, 1.1), sx * 0.5, 1.5, 0, plate, M.Metal, nil, leg)
			G("Foot", V(1.2, 0.5, 1.5), sx * 0.5, 0.25, -0.15, plateDark, M.Metal, nil, leg)
			GB("KneeLight", 0.26, sx * 0.5, 1.0, -0.55, neon, M.Neon, leg)
			stick("Piston", V(sx * 0.5, 0.55, 0.52), V(sx * 0.5, 1.7, 0.52), 0.14, 0.14, RGB(200, 200, 210), M.Metal, leg, true)
		end
		-- shoulder cannon
		G("CannonBase", V(0.7, 0.4, 0.8), 1.2, 4.35, 0.1, plateDark, M.Metal, nil, torso)
		stick("CannonBarrel", V(1.2, 4.6, 0.3), V(1.2, 4.62, -1.0), 0.32, 0.32, plate, M.Metal, torso, true)
		disc("CannonMuzzle", 0.06, 0.24, 1.2, 4.62, -1.01, RGB(255, 60, 40), M.Neon, torso, FACE_FWD)
		-- jetpack with flames
		for _, sx in ipairs({-1, 1}) do
			local tank = G("JetTank", V(1.4, 0.55, 0.55), sx * 0.45, 3.1, 0.82, plateDark, M.Metal, UPRIGHT_DISC, torso)
			tank.Shape = Enum.PartType.Cylinder
			local nozzle = G("JetNozzle", V(0.3, 0.4, 0.4), sx * 0.45, 2.3, 0.82, RGB(40, 40, 45), M.Metal, UPRIGHT_DISC, torso)
			nozzle.Shape = Enum.PartType.Cylinder
			emitter(nozzle, {Color = ColorSequence.new(RGB(120, 220, 255), RGB(60, 120, 255)), LightEmission = 1, Rate = 25, Lifetime = NumberRange.new(0.2, 0.35),
				Speed = NumberRange.new(6, 10), Size = NumberSequence.new(0.25 * s, 0), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(8, 8)})
		end
		bossOrbs(2, neon, 2.4, 4.8, 0.32) -- two little security drones

	elseif areaIndex == 9 then
		-- ALIEN ENFORCER: huge glossy eyes, antennae, armoured collar, ray gun, cape and a hover disc
		local suit, glowG = RGB(110, 60, 160), RGB(90, 255, 90)
		face({noEyes = true, noBrows = true, noNose = true, noEars = true, noLids = true})
		for _, sx in ipairs({-1, 1}) do
			ELL("AlienEye", V(0.48, 0.36, 0.12), sx * 0.29, 4.62, -0.64, RGB(10, 10, 14), M.Glass, head, ROTZ(-sx * 22))
			GB("EyeShine", 0.09, sx * 0.24, 4.7, -0.71, white, M.Neon, head)
			stick("Antenna", V(sx * 0.3, 5.1, 0), V(sx * 0.55, 6.1, 0.1), 0.07, 0.07, RGB(90, 200, 90), nil, head, true)
			GB("AntennaOrb", 0.3, sx * 0.55, 6.15, 0.1, RGB(255, 120, 230), M.Neon, head)
			G("CollarPlate", V(0.8, 0.35, 1.1), sx * 0.55, 3.95, 0, suit:Lerp(RGB(0, 0, 0), 0.3), M.Metal, ROTZ(-sx * 18), torso)
			local arm = (sx < 0) and LA or RA
			G("Bracer", V(1.12, 0.55, 1.12), sx * 1.5, 2.5, 0, suit:Lerp(RGB(0, 0, 0), 0.3), M.Metal, nil, arm)
			G("BracerLight", V(1.14, 0.1, 1.14), sx * 1.5, 2.5, 0, glowG, M.Neon, nil, arm)
			G("Cape", V(0.95, 3.3, 0.1), sx * 0.48, 2.5, 0.62, RGB(60, 20, 90), M.Fabric, CFrame.Angles(A(8), 0, A(-sx * 4)), torso)
		end
		G("Mouth", V(0.3, 0.06, 0.04), 0, 4.2, -0.64, RGB(20, 70, 20), nil, nil, head)
		G("ChestEmblem", V(0.6, 0.6, 0.06), 0, 3.4, -0.53, glowG, M.Neon, CFrame.Angles(0, 0, A(45)), torso)
		G("SuitBelt", V(2.07, 0.3, 1.08), 0, 2.15, 0, suit:Lerp(RGB(0, 0, 0), 0.4), M.Metal, nil, torso)
		for k = -2, 2 do GB("BeltLight", 0.12, k * 0.35, 2.15, -0.56, glowG, M.Neon, torso) end
		-- ray gun
		G("GunGrip", V(0.25, 0.5, 0.3), 1.5, 1.8, -0.4, RGB(60, 60, 70), M.Metal, nil, RA)
		stick("GunBarrel", V(1.5, 2.0, -0.4), V(1.5, 2.0, -1.6), 0.28, 0.28, RGB(170, 175, 190), M.Metal, RA, true)
		for k = 1, 3 do disc("GunRing", 0.08, 0.38, 1.5, 2.0, -0.6 - k * 0.25, glowG, M.Neon, RA, FACE_FWD) end
		GB("GunTip", 0.24, 1.5, 2.0, -1.65, glowG, M.Neon, RA)
		local disc2 = disc("HoverDisc", 0.2, 2.6, 0, -0.05, 0, RGB(170, 175, 190), M.Metal, torso)
		local glowRing = disc("HoverGlow", 0.08, 2.2, 0, -0.18, 0, glowG, M.Neon, torso)
		light(glowRing, glowG, 12, 3)
		emitter(disc2, {Color = ColorSequence.new(glowG), LightEmission = 1, Rate = 15, Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.3 * s, 0), EmissionDirection = Enum.NormalId.Bottom})
		bossOrbs(3, RGB(255, 120, 230), 2.2, 3.4, 0.3)

	else
		-- VOID WARDEN (final boss): a crown of neon horns, glowing cracks, cape, a giant scythe,
		-- spikes, a purple aura and void orbs circling him
		local void, pink, purple = RGB(15, 10, 25), RGB(255, 60, 220), RGB(150, 70, 255)
		face({glow = true, pupil = pink, eyeWhite = RGB(30, 0, 40), noBrows = false, browAngle = 26, brow = pink, fangs = true, noEars = true, noNose = true, noLids = true})
		for k = -2, 2 do
			stick("CrownHorn", V(k * 0.28, 5.05, -0.1 + math.abs(k) * 0.12), V(k * 0.5, 5.8 + (2 - math.abs(k)) * 0.35, math.abs(k) * 0.1), 0.18, 0.18, pink, M.Neon, head, true)
		end
		G("CrownBand", V(1.3, 0.22, 1.3), 0, 5.08, 0, RGB(40, 20, 60), M.Metal, nil, head)
		for _, c in ipairs({{-0.4, 3.0, 20, 1.6}, {0.5, 3.2, -30, 1.2}, {0.1, 2.5, 60, 0.8}, {-0.6, 3.6, -50, 0.7}}) do
			G("Crack", V(0.14, c[4], 0.05), c[1], c[2], -0.52, pink, M.Neon, ROTZ(c[3]), torso)
		end
		for _, sx in ipairs({-1, 1}) do
			local arm, leg = (sx < 0) and LA or RA, (sx < 0) and LL or RL
			G("Pauldron", V(1.35, 0.6, 1.32), sx * 1.52, 4.02, 0, RGB(35, 20, 55), M.Metal, ROTZ(-sx * 14), arm)
			for k = -1, 1 do stick("Spike", V(sx * (1.5 + k * 0.32), 4.25, 0), V(sx * (1.75 + k * 0.45), 4.95, k * 0.1), 0.16, 0.16, pink, M.Neon, arm, true) end
			G("ArmCrack", V(0.1, 1.0, 0.05), sx * 1.5, 3.0, -0.52, pink, M.Neon, ROTZ(sx * 25), arm)
			G("LegCrack", V(0.1, 0.9, 0.05), sx * 0.5, 1.0, -0.52, pink, M.Neon, ROTZ(-sx * 20), leg)
			for k = -1, 1 do stick("Claw", V(sx * 1.5 + k * 0.28, 2.0, -0.3), V(sx * 1.5 + k * 0.32, 1.45, -0.65), 0.12, 0.12, pink, M.Neon, arm) end
			G("Cape", V(1.0, 3.6, 0.1), sx * 0.5, 2.3, 0.64, RGB(30, 10, 50), M.Fabric, CFrame.Angles(A(9), 0, A(-sx * 4)), torso)
			G("CapeLining", V(0.98, 3.5, 0.04), sx * 0.5, 2.32, 0.58, purple, M.Fabric, CFrame.Angles(A(9), 0, A(-sx * 4)), torso)
		end
		-- the scythe
		stick("ScytheHandle", V(1.55, 0.2, -0.6), V(1.55, 6.8, -0.62), 0.2, 0.2, RGB(40, 25, 55), M.Metal, RA, true)
		stick("ScytheBlade", V(1.55, 6.7, -0.62), V(1.55, 6.2, -3.0), 0.08, 0.6, RGB(200, 200, 220), M.Metal, RA)
		stick("ScytheEdge", V(1.55, 6.45, -0.7), V(1.55, 5.95, -3.0), 0.09, 0.12, pink, M.Neon, RA)
		GB("ScytheGem", 0.4, 1.55, 6.8, -0.62, purple, M.Neon, RA)
		emitter(torso, {Color = ColorSequence.new(pink, RGB(90, 0, 160)), LightEmission = 1, Rate = 25,
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 4), Size = NumberSequence.new(1.2, 0),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 4, 0)})
		light(head, pink, 7 * s, 2.5)
		bossOrbs(4, purple, 2.6, 3.6, 0.38)
	end
	if areaIndex == 1 then
		-- the sleepy watchman dozes next to his old chair (not part of the model, so it stays put)
		local seat = P(guardsFolder, "Chair", V(2.2, 0.3, 2.2) * s, CFrame.new(pos.X, F + 1.4 * s, pos.Z - 1.6 * s), RGB(120, 85, 55), M.WoodPlanks)
		P(guardsFolder, "ChairBack", V(2.2, 2.4, 0.3) * s, CFrame.new(pos.X, F + 2.7 * s, pos.Z - 2.6 * s), RGB(120, 85, 55), M.WoodPlanks)
		for _, ox in ipairs({-0.9, 0.9}) do
			for _, oz in ipairs({0.8, 2.4}) do
				P(guardsFolder, "ChairLeg", V(0.25, 1.3, 0.25) * s, CFrame.new(pos.X + ox * s, F + 0.65 * s, pos.Z - oz * s), RGB(90, 60, 40), M.WoodPlanks)
			end
		end
		seat.CanCollide = false
	end

	------------------------------------------------------------------
	-- ZZZ (sleeping), ! (awake), boss name plate, red glow + rage particles when chasing
	------------------------------------------------------------------
	-- all of these are sized in STUDS (not pixels), so they shrink with distance like real
	-- objects and never pile up on top of each other from far away
	local function bb(name, text, color, offset, enabled, studs)
		local b = Instance.new("BillboardGui")
		b.Name = name
		b.Size = UDim2.fromScale(studs, studs)
		b.StudsOffset = V(0, offset, 0)
		b.AlwaysOnTop = false
		b.MaxDistance = (name == "Alert") and 100 or 55
		b.LightInfluence = 0
		b.Enabled = enabled
		b.Parent = head
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.FontFace = Config.Font
		tl.TextScaled = true
		tl.TextColor3 = color
		tl.Text = text
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Parent = tl
		tl.Parent = b
		return b
	end
	local zzz = bb("Zzz", "Z", RGB(120, 220, 255), 2.4 * s, true, 0.9 * s)
	zzz.StudsOffset = V(1.2 * s, 2.2 * s, 0)
	bb("Alert", "!", RGB(255, 40, 40), 2.6 * s, false, 1.2 * s)
	-- name plate: dark rounded card, BOSS chip + threat diamonds (more in deeper areas)
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
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0.3, 0)
	cc.Parent = card
	local cs = Instance.new("UIStroke")
	cs.Thickness = 2.5
	cs.Color = accent
	cs.Parent = card
	local nameL = Instance.new("TextLabel")
	nameL.BackgroundTransparency = 1
	nameL.Position = UDim2.fromScale(0.05, 0.06)
	nameL.Size = UDim2.fromScale(0.9, 0.5)
	nameL.FontFace = Config.Font
	nameL.TextScaled = true
	nameL.TextColor3 = RGB(255, 255, 255)
	nameL.Text = string.upper(area.guard)
	nameL.Parent = card
	local ns = Instance.new("UIStroke")
	ns.Thickness = 2
	ns.Parent = nameL
	local chip = Instance.new("Frame")
	chip.Position = UDim2.fromScale(0.05, 0.6)
	chip.Size = UDim2.fromScale(0.24, 0.3)
	chip.BackgroundColor3 = accent
	chip.Parent = card
	local chc = Instance.new("UICorner")
	chc.CornerRadius = UDim.new(1, 0)
	chc.Parent = chip
	local chipL = Instance.new("TextLabel")
	chipL.BackgroundTransparency = 1
	chipL.Position = UDim2.fromScale(0.1, 0.08)
	chipL.Size = UDim2.fromScale(0.8, 0.84)
	chipL.FontFace = Config.Font
	chipL.TextScaled = true
	chipL.TextColor3 = RGB(255, 255, 255)
	chipL.Text = "BOSS"
	chipL.Parent = chip
	local chs = Instance.new("UIStroke")
	chs.Thickness = 1.5
	chs.Parent = chipL
	local threat = math.clamp(math.ceil(areaIndex / 2), 1, 5)
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

	local hl = Instance.new("Highlight")
	hl.Name = "Angry"
	hl.FillColor = RGB(255, 30, 30)
	hl.FillTransparency = 0.45
	hl.OutlineColor = RGB(255, 120, 120)
	hl.Enabled = false
	hl.Parent = m
	emitter(torso, {Name = "RageFX", Enabled = false, Color = ColorSequence.new(RGB(255, 80, 30), RGB(255, 0, 0)), LightEmission = 1,
		Rate = 40, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(3, 6), Size = NumberSequence.new(0.8 * s, 0),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 6, 0)})

	m.Parent = guardsFolder
	local at = V(pos.X, F + 3 * s, pos.Z)
	m:PivotTo(CFrame.lookAt(at, at + V(0, 0, 1))) -- face the entrance
	-- the boss orbs start around him
	for _, orb in ipairs(guardsFolder:GetChildren()) do
		if orb.Name == "BossOrb" and orb:GetAttribute("Boss") == m.Name then
			orb.CFrame = CFrame.new(at + V(orb:GetAttribute("Radius"), orb:GetAttribute("Height") - 3 * s, 0))
		end
	end
end

------------------------------------------------------------------
-- THEMES: decorations per area. Free space: back corners (|x| 14..33, d 24..48),
-- front corners (|x| 20..33, d 1..5) and the strip by the walls between shelves.
------------------------------------------------------------------
local THEMES = {}

THEMES[1] = function(r) -- DUSTY STORAGE: old, broken, cobwebs, flickering bulb
	for i = 1, 7 do
		local x = (i % 2 == 0) and 24 or -24
		D(r, "BrokenCrate", V(3, 3, 3), x + (i % 3), F + 1.3, 26 + i * 3, RGB(110, 90, 70), M.WoodPlanks, nil, CFrame.Angles(math.rad(10), math.rad(i * 25), math.rad(-8)))
	end
	for i = 1, 3 do pillar(r, "RustyBarrel", 3.4, 2.4, -30, F, 25 + i * 3, RGB(120, 70, 40), M.CorrodedMetal) end
	D(r, "TippedBarrel", V(3.4, 2.4, 2.4), 28, F + 1.2, 46, RGB(110, 65, 40), M.CorrodedMetal, {Shape = Enum.PartType.Cylinder})
	for _, x in ipairs({-(HW - 1.5), HW - 1.5}) do
		for _, d in ipairs({2, 48}) do
			D(r, "Cobweb", V(0.1, 7, 7), x, WH - 4, d, RGB(240, 240, 240), M.SmoothPlastic, {Transparency = 0.5, CanCollide = false, CanQuery = false}, CFrame.Angles(math.rad(45), 0, 0))
		end
	end
	for i = 1, 8 do
		D(r, "Crack", V(5 + i % 4, 0.05, 0.35), -20 + i * 5, F + 0.03, 6 + i * 5, RGB(70, 55, 40), M.Slate, FX, CFrame.Angles(0, math.rad(i * 37), 0))
	end
	for i = 1, 5 do
		D(r, "DustPile", V(3 + i % 2, 0.25, 2.5), -12 + i * 6, F + 0.12, 3 + (i % 2) * 40, RGB(150, 135, 115), M.Sand, FX, CFrame.Angles(0, math.rad(i * 50), 0))
	end
	D(r, "LampWire", V(0.15, 8, 0.15), 0, WH - 4, 25, RGB(40, 40, 40), M.SmoothPlastic, FX)
	local bulb = ball(r, "OldBulb", 1.3, 0, WH - 8.5, 25, RGB(255, 190, 90), M.Neon, FX)
	bulb:SetAttribute("Flicker", true)
	light(bulb, RGB(255, 170, 80), 40, 1.5)
	ambience(r, {RGB(220, 200, 170)}, {rate = 18, speed = 0.3, size = 0.18, accel = Vector3.new(0, -0.2, 0), life = 8})
end

THEMES[2] = function(r) -- FARM BARN: hay, fences, scarecrow, trough, lantern
	for i = 0, 3 do
		for j = 0, 1 do
			D(r, "HayBale", V(4, 2.4, 3), 27, F + 1.2 + j * 2.4, 27 + i * 4 + j, RGB(230, 195, 90), M.Fabric)
		end
	end
	for _, x in ipairs({-20, 20}) do
		D(r, "FenceRail", V(0.3, 0.4, 20), x, F + 1.2, 36, RGB(250, 250, 250), M.WoodPlanks)
		D(r, "FenceRail", V(0.3, 0.4, 20), x, F + 2.6, 36, RGB(250, 250, 250), M.WoodPlanks)
		for d = 26, 46, 4 do D(r, "FencePost", V(0.4, 3.4, 0.4), x, F + 1.7, d, RGB(250, 250, 250), M.WoodPlanks) end
	end
	D(r, "Trough", V(2.2, 1.4, 6), -27, F + 0.7, 30, RGB(130, 90, 55), M.WoodPlanks)
	D(r, "Water", V(1.6, 0.2, 5.4), -27, F + 1.35, 30, RGB(80, 170, 240), M.SmoothPlastic, FX)
	D(r, "ScarecrowPole", V(0.4, 7, 0.4), -27, F + 3.5, 42, RGB(120, 85, 50), M.Wood)
	D(r, "ScarecrowArms", V(5, 0.4, 0.4), -27, F + 5.5, 42, RGB(120, 85, 50), M.Wood)
	D(r, "ScarecrowShirt", V(2.2, 2, 1.2), -27, F + 5, 42, RGB(80, 120, 200), M.Fabric)
	ball(r, "ScarecrowHead", 1.6, -27, F + 6.8, 42, RGB(235, 200, 120), M.Fabric)
	D(r, "StrawHat", V(2.6, 0.3, 2.6), -27, F + 7.6, 42, RGB(220, 180, 80), M.Fabric)
	for i = 1, 12 do
		D(r, "LooseHay", V(2.5, 0.1, 1.2), -25 + (i * 7) % 50, F + 0.05, (i * 11) % 48 + 1, RGB(235, 205, 110), M.Fabric, FX, CFrame.Angles(0, math.rad(i * 50), 0))
	end
	for _, x in ipairs({-15, 15}) do
		D(r, "LanternHook", V(0.15, 5, 0.15), x, WH - 2.5, 25, RGB(40, 40, 40), M.Metal, FX)
		light(D(r, "Lantern", V(0.9, 1.3, 0.9), x, WH - 5.6, 25, RGB(255, 200, 100), M.Neon, FX), RGB(255, 190, 90), 28, 1.4)
	end
	ambience(r, {RGB(240, 210, 120), RGB(200, 160, 80)}, {rate = 12, speed = 0.6, size = 0.25, accel = Vector3.new(0.5, -1, 0), life = 7})
end

THEMES[3] = function(r) -- TOY FACTORY: conveyor, giant blocks, ball, rocket, confetti
	local cols = {RGB(255, 80, 80), RGB(80, 160, 255), RGB(255, 210, 40), RGB(90, 220, 110), RGB(200, 110, 255)}
	D(r, "Conveyor", V(4, 1.2, 22), 28, F + 0.6, 36, RGB(50, 50, 60), M.SmoothPlastic)
	for d = 26, 46, 2 do D(r, "Roller", V(4.2, 0.2, 0.4), 28, F + 1.25, d, RGB(255, 210, 40), M.SmoothPlastic) end
	for i = 1, 4 do D(r, "ToyBlock", V(2.6, 2.6, 2.6), 28, F + 2.5, 26 + i * 5, cols[i], M.SmoothPlastic) end
	for i = 0, 2 do
		for j = 0, 2 - i do
			D(r, "GiantBlock", V(3.5, 3.5, 3.5), -28 + j * 3.6 + i * 1.8, F + 1.75 + i * 3.5, 46, cols[(i + j) % 5 + 1], M.SmoothPlastic)
		end
	end
	ball(r, "GiantBall", 6, -25, F + 3, 31, RGB(255, 80, 80), M.SmoothPlastic)
	disc(r, "BallStripe", 1.2, 6.1, -25, F + 3, 31, RGB(255, 255, 255), M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(90), 0))
	pillar(r, "ToyRocket", 7, 2.4, 28, F, 3, RGB(240, 240, 250), M.SmoothPlastic)
	ball(r, "RocketNose", 2.4, 28, F + 7.4, 3, RGB(255, 80, 80), M.SmoothPlastic)
	for _, ox in ipairs({-1.6, 1.6}) do D(r, "RocketFin", V(0.3, 2.2, 1.6), 28 + ox, F + 1.1, 3, RGB(80, 160, 255), M.SmoothPlastic) end
	for i = 0, 4 do
		D(r, "WallStripe", V(0.2, 1.5, SL), -HW + 0.3, F + 3 + i * 3.5, SL / 2, cols[i + 1], M.Neon, FX)
		D(r, "WallStripe", V(0.2, 1.5, SL), HW - 0.3, F + 3 + i * 3.5, SL / 2, cols[5 - i], M.Neon, FX)
	end
	ambience(r, cols, {rate = 20, speed = 1, size = 0.35, accel = Vector3.new(0, -2, 0), life = 6})
end

THEMES[4] = function(r) -- CANDY SHOP: lollipops, candy canes, gumdrops, sprinkles
	local cols = {RGB(255, 90, 160), RGB(110, 220, 255), RGB(255, 220, 60), RGB(150, 255, 140)}
	for i, d in ipairs({27, 33, 39, 45}) do
		local x = (i % 2 == 0) and 27 or -27
		pillar(r, "LollipopStick", 8, 0.6, x, F, d, RGB(250, 250, 250), M.SmoothPlastic)
		disc(r, "Lollipop", 1, 6, x, F + 10.5, d, cols[i], M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(90), 0))
		disc(r, "Swirl", 1.1, 3, x, F + 10.5, d, RGB(255, 255, 255), M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(90), 0))
	end
	for _, xd in ipairs({{-31, 2}, {31, 2}, {-18, 47}, {18, 47}}) do
		for k = 0, 9 do
			pillar(r, "CandyCane", 1.2, 1.6, xd[1], F + k * 1.2, xd[2], (k % 2 == 0) and RGB(230, 40, 50) or RGB(255, 255, 255), M.SmoothPlastic)
		end
		ball(r, "CaneTop", 1.6, xd[1], F + 12.2, xd[2], RGB(230, 40, 50), M.SmoothPlastic)
	end
	for i = 1, 10 do
		ball(r, "Gumdrop", 2.4, -24 + (i * 9) % 48, F + 0.4, 21.5 + (i % 3), cols[i % 4 + 1], M.SmoothPlastic, {Reflectance = 0.15})
	end
	D(r, "Counter", V(14, 3, 3), -24, F + 1.5, 46, RGB(255, 200, 225), M.SmoothPlastic)
	D(r, "CounterTop", V(14.4, 0.4, 3.4), -24, F + 3.2, 46, RGB(130, 70, 40), M.SmoothPlastic)
	for i = 1, 4 do ball(r, "Cupcake", 1.6, -29 + i * 3, F + 4, 46, cols[i], M.SmoothPlastic) end
	ambience(r, {RGB(255, 255, 255), RGB(255, 150, 220), RGB(150, 230, 255)}, {rate = 25, speed = 0.8, size = 0.2, glow = 0.6, accel = Vector3.new(0, -1.5, 0), life = 6})
end

THEMES[5] = function(r) -- PIRATE COVE: water, ship, palm, treasure, bubbles
	D(r, "Water", V(14, 0.3, 26), 26, F + 0.1, 36, RGB(40, 140, 220), M.SmoothPlastic, {Transparency = 0.15, CanCollide = false})
	D(r, "Hull", V(5, 3.5, 16), 26, F + 1.6, 36, RGB(110, 70, 40), M.WoodPlanks)
	D(r, "Deck", V(5.4, 0.4, 16.4), 26, F + 3.4, 36, RGB(150, 105, 60), M.WoodPlanks)
	D(r, "Bow", V(3.6, 3.5, 3.6), 26, F + 1.6, 26.5, RGB(110, 70, 40), M.WoodPlanks, nil, CFrame.Angles(0, math.rad(45), 0))
	pillar(r, "Mast", 13, 0.7, 26, F + 3.4, 37, RGB(90, 60, 35), M.Wood)
	D(r, "Sail", V(8, 7, 0.2), 26, F + 10, 37, RGB(245, 240, 225), M.Fabric)
	D(r, "SailSkull", V(2, 2, 0.25), 26, F + 10, 37, RGB(30, 30, 30), M.SmoothPlastic)
	D(r, "Flag", V(2.4, 1.6, 0.1), 27.2, F + 16, 37, RGB(20, 20, 20), M.Fabric)
	pillar(r, "PalmTrunk", 11, 1.3, -29, F, 30, RGB(150, 110, 70), M.Wood)
	for k = 0, 4 do
		D(r, "PalmLeaf", V(7, 0.2, 1.8), -29, F + 11, 30, RGB(60, 175, 60), M.SmoothPlastic, NO_COLLIDE, CFrame.Angles(0, math.rad(k * 72), math.rad(-22)))
	end
	for i = 1, 3 do ball(r, "Coconut", 0.9, -29 + (i - 2) * 0.8, F + 10.4, 30.6, RGB(110, 70, 40), M.SmoothPlastic) end
	for i = 1, 10 do
		ball(r, "GoldCoins", 1 + (i % 3) * 0.5, -26 + (i % 4), F + 0.3, 42 + (i % 5), RGB(255, 200, 40), M.SmoothPlastic, {Reflectance = 0.25})
	end
	D(r, "Chest", V(3, 2, 2), -27, F + 1, 46, RGB(150, 95, 45), M.Wood)
	light(D(r, "ChestGlow", V(2.6, 0.3, 1.6), -27, F + 2.1, 46, RGB(255, 210, 60), M.Neon, FX), RGB(255, 200, 60), 14, 2)
	for i = 1, 2 do pillar(r, "Barrel", 3, 2.2, -31, F, 1.6 + (i - 1) * 2.4, RGB(140, 95, 55), M.WoodPlanks) end
	for i = 1, 6 do
		D(r, "Coral", V(0.5, 2 + i % 3, 0.5), -HW + 0.6, F + 6 + i * 2, 22 + i * 4, (i % 2 == 0) and RGB(255, 80, 200) or RGB(255, 140, 60), M.SmoothPlastic, FX, CFrame.Angles(math.rad(15 * (i % 3 - 1)), 0, 0))
	end
	ambience(r, {RGB(200, 240, 255), RGB(120, 200, 255)}, {rate = 18, speed = 2, size = 0.4, glow = 0.3, accel = Vector3.new(0, 2, 0), dir = Enum.NormalId.Top, y = F + 1, life = 5})
end

THEMES[6] = function(r) -- DINO MUSEUM: T-Rex skeleton, ropes, ferns, spotlights
	local bone = RGB(242, 236, 215)
	D(r, "Platform", V(10, 1, 24), 25, F + 0.5, 36, RGB(120, 100, 80), M.Marble)
	local b = F + 1
	for _, dz in ipairs({-2, 2}) do
		D(r, "Leg", V(1, 5, 1), 25 + dz * 0.4, b + 2.5, 38 + dz, bone, M.SmoothPlastic)
		D(r, "Foot", V(1.4, 0.5, 2.2), 25 + dz * 0.4, b + 0.25, 37 + dz, bone, M.SmoothPlastic)
	end
	D(r, "Pelvis", V(2.4, 2, 3), 25, b + 5.5, 38, bone, M.SmoothPlastic)
	for i = 1, 6 do
		D(r, "Spine", V(1, 1, 1.4), 25, b + 5.8 + i * 0.5, 38 - i * 1.3, bone, M.SmoothPlastic)
		D(r, "Rib", V(3.2, 0.3, 0.3), 25, b + 4.6 + i * 0.4, 38 - i * 1.3, bone, M.SmoothPlastic)
	end
	D(r, "Neck", V(1, 1, 2.4), 25, b + 9.2, 29, bone, M.SmoothPlastic, nil, CFrame.Angles(math.rad(30), 0, 0))
	D(r, "Skull", V(2.4, 2.2, 4), 25, b + 10.2, 26.5, bone, M.SmoothPlastic)
	D(r, "Jaw", V(2, 0.6, 3.4), 25, b + 8.8, 26.2, bone, M.SmoothPlastic, nil, CFrame.Angles(math.rad(12), 0, 0))
	for _, ox in ipairs({-0.8, 0.8}) do D(r, "EyeSocket", V(0.6, 0.6, 0.2), 25 + ox, b + 10.6, 24.45, RGB(30, 30, 30), M.SmoothPlastic) end
	for i = 1, 4 do D(r, "Tooth", V(0.2, 0.4, 0.2), 24.3 + i * 0.35, b + 9.3, 24.8, RGB(255, 255, 255), M.SmoothPlastic) end
	for i = 1, 7 do
		local sz = 1.1 - i * 0.1
		D(r, "Tail", V(sz, sz, 1.6), 25, b + 5.5 - i * 0.45, 40 + i * 1.4, bone, M.SmoothPlastic)
	end
	for _, x in ipairs({19, 31}) do
		for _, d in ipairs({24, 48}) do pillar(r, "RopePost", 3, 0.5, x, F, d, RGB(212, 175, 55), M.Metal) end
		D(r, "Rope", V(0.25, 0.25, 24), x, F + 2.6, 36, RGB(180, 30, 40), M.Fabric, NO_COLLIDE)
	end
	for _, d in ipairs({28, 44}) do
		local spot = D(r, "Spotlight", V(1, 1, 1.4), 25, WH - 1, d, RGB(30, 30, 30), M.Metal, FX)
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Angle = 50
		sl.Range = 30
		sl.Brightness = 4
		sl.Color = RGB(255, 245, 220)
		sl.Parent = spot
	end
	for i = 1, 8 do
		ball(r, "Fern", 2.4 + (i % 3) * 0.6, -31 + (i % 2) * 3, F + 0.6, 24 + i * 3, RGB(60, 150 + i * 10, 60), M.Grass)
	end
	local sign = D(r, "InfoSign", V(5, 2.6, 0.3), 25, F + 1.6, 23, RGB(40, 40, 50), M.SmoothPlastic)
	surfaceText(sign, Enum.NormalId.Back, "T-REX", RGB(255, 230, 150))
	ambience(r, {RGB(180, 255, 140), RGB(255, 255, 200)}, {rate = 10, speed = 0.4, size = 0.25, glow = 1, accel = Vector3.new(0, 0.2, 0), y = 6, life = 8})
end

THEMES[7] = function(r) -- FROZEN LAB: ice crystals, snow piles, frozen mammoth, snowfall
	for i = 1, 6 do
		local x = (i % 2 == 0) and 30 or -30
		for k = 0, 2 do
			D(r, "IceCrystal", V(1.6, 5 + k * 2, 1.6), x + (k - 1) * 1.2, F + 2.5 + k, 3 + i * 0.5 + (i > 3 and 42 or 0), RGB(150, 220, 255), M.Glass, {Transparency = 0.25}, CFrame.Angles(0, 0, math.rad((k - 1) * 18)))
		end
	end
	for i = 1, 10 do
		ball(r, "SnowPile", 3 + (i % 3), -26 + (i * 13) % 52, F - 0.7, 22 + (i % 2) * 26, RGB(250, 252, 255), M.Snow)
	end
	D(r, "IceBlock", V(14, 9, 10), 25, F + 4.5, 37, RGB(170, 220, 255), M.Glass, {Transparency = 0.4})
	D(r, "FrozenMammoth", V(8, 4.5, 4.5), 25, F + 3.2, 37, RGB(110, 75, 55), M.Fabric)
	ball(r, "MammothHead", 3.8, 20.5, F + 4.4, 37, RGB(110, 75, 55), M.Fabric)
	for _, dz in ipairs({-1.2, 1.2}) do
		D(r, "Tusk", V(3, 0.45, 0.45), 18.6, F + 2.6, 37 + dz, RGB(250, 245, 230), M.SmoothPlastic, nil, CFrame.Angles(0, 0, math.rad(-25)))
	end
	light(D(r, "ColdLight", V(2, 0.4, 2), 0, WH - 1, 25, RGB(180, 230, 255), M.Neon, FX), RGB(160, 220, 255), 45, 1.5)
	ambience(r, {RGB(255, 255, 255)}, {rate = 45, speed = 2, size = 0.35, accel = Vector3.new(0.6, -3, 0), life = 7})
end

THEMES[8] = function(r) -- TECH LAB: server racks, neon, monitors, hologram, data sparks
	local neon = RGB(60, 170, 255)
	for _, y in ipairs({F + 0.2, WH - 1, 12}) do
		D(r, "NeonStrip", V(0.3, 0.3, SL), -HW + 0.3, y, SL / 2, neon, M.Neon, FX)
		D(r, "NeonStrip", V(0.3, 0.3, SL), HW - 0.3, y, SL / 2, neon, M.Neon, FX)
	end
	for i = 0, 3 do
		local d = 26 + i * 6
		D(r, "ServerRack", V(4, 10, 3), 29, F + 5, d, RGB(25, 25, 30), M.SmoothPlastic)
		for k = 0, 6 do
			D(r, "Led", V(0.3, 0.3, 0.1), 27.8 + (k % 3) * 0.6, F + 1.5 + k * 1.2, d - 1.55, (k % 3 == 0) and RGB(80, 255, 120) or neon, M.Neon, FX)
		end
	end
	for _, d in ipairs({30, 40}) do
		D(r, "Desk", V(8, 0.4, 3), -26, F + 3, d, RGB(220, 225, 235), M.SmoothPlastic)
		D(r, "DeskLegs", V(7.6, 2.8, 0.4), -26, F + 1.4, d, RGB(120, 125, 135), M.Metal)
		for _, x in ipairs({-29, -23}) do
			D(r, "Monitor", V(2.4, 1.6, 0.2), x, F + 4.2, d + 0.9, RGB(30, 30, 35), M.SmoothPlastic)
			D(r, "Screen", V(2.1, 1.3, 0.05), x, F + 4.2, d + 0.78, neon, M.Neon, FX)
		end
	end
	pillar(r, "HoloBase", 1, 4, -26, F, 46, RGB(40, 45, 55), M.Metal)
	light(ball(r, "Hologram", 3.4, -26, F + 4.5, 46, neon, M.Neon, {Transparency = 0.45, CanCollide = false}), neon, 20, 2)
	disc(r, "HoloRing", 0.2, 5.5, -26, F + 4.5, 46, neon, M.Neon, {Transparency = 0.3, CanCollide = false}, CFrame.Angles(0, 0, math.rad(70)))
	ambience(r, {RGB(60, 170, 255), RGB(140, 255, 255)}, {rate = 25, speed = 3, size = 0.2, glow = 1, accel = Vector3.new(0, 3, 0), dir = Enum.NormalId.Top, y = F + 1, life = 4})
end

THEMES[9] = function(r) -- ALIEN HANGAR: landed UFO with tractor beam, slime, spores
	local green = RGB(90, 255, 90)
	for _, y in ipairs({F + 0.2, WH - 1}) do
		D(r, "NeonStrip", V(0.3, 0.3, SL), -HW + 0.3, y, SL / 2, green, M.Neon, FX)
		D(r, "NeonStrip", V(0.3, 0.3, SL), HW - 0.3, y, SL / 2, green, M.Neon, FX)
	end
	local ux, ud = 24, 36
	disc(r, "UFOHull", 2, 18, ux, F + 6, ud, RGB(180, 190, 205), M.Metal)
	disc(r, "UFORim", 0.6, 19, ux, F + 6, ud, RGB(110, 120, 135), M.Metal)
	disc(r, "UFOBelly", 1.6, 11, ux, F + 4.6, ud, RGB(120, 130, 145), M.Metal)
	ball(r, "UFODome", 8, ux, F + 7.6, ud, RGB(120, 255, 160), M.Glass, {Transparency = 0.35})
	ball(r, "AlienPilot", 2.2, ux, F + 8.2, ud, RGB(110, 230, 110), M.SmoothPlastic)
	for k = 0, 11 do
		local a = math.rad(k * 30)
		local bulb = ball(r, "UFOLight", 0.9, ux + math.cos(a) * 9, F + 6, ud + math.sin(a) * 9, (k % 2 == 0) and green or RGB(255, 240, 80), M.Neon, FX)
		bulb:SetAttribute("Blink", k % 2)
	end
	for k = 0, 2 do
		local a = math.rad(k * 120 + 30)
		D(r, "UFOLeg", V(0.5, 4.5, 0.5), ux + math.cos(a) * 6, F + 2.2, ud + math.sin(a) * 6, RGB(90, 95, 105), M.Metal)
	end
	local beam = pillar(r, "TractorBeam", 4, 9, ux, F, ud, green, M.Neon, {Transparency = 0.75, CanCollide = false, CanQuery = false})
	light(beam, green, 30, 2)
	for i = 1, 5 do
		disc(r, "Slime", 0.15, 3 + i, -26 + (i % 2) * 6, F + 0.08, 22 + i * 5, green, M.Neon, {Transparency = 0.2, CanCollide = false})
	end
	for i = 0, 2 do
		D(r, "AlienCrate", V(3, 3, 3), -30, F + 1.5 + i * 3, 46, RGB(70, 80, 70), M.DiamondPlate)
		D(r, "CrateGlow", V(3.1, 0.3, 3.1), -30, F + 1.5 + i * 3, 46, green, M.Neon, FX)
	end
	ambience(r, {RGB(150, 255, 120), RGB(60, 255, 200)}, {rate = 20, speed = 1, size = 0.35, glow = 1, accel = Vector3.new(0, 1.5, 0), dir = Enum.NormalId.Top, y = F + 1, life = 7})
end

THEMES[10] = function(r) -- GALAXY VAULT: neon grid, black hole, planets, crystals, stars
	local purple, pink = RGB(180, 90, 255), RGB(255, 80, 200)
	for x = -32, 32, 8 do D(r, "GridLine", V(0.2, 0.05, SL), x, F + 0.03, SL / 2, purple, M.Neon, FX) end
	for d = 4, 48, 8 do D(r, "GridLine", V(HW * 2, 0.05, 0.2), 0, F + 0.03, d, purple, M.Neon, FX) end
	for _, y in ipairs({F + 0.2, WH - 1, 12}) do
		D(r, "NeonStrip", V(0.3, 0.3, SL), -HW + 0.3, y, SL / 2, pink, M.Neon, FX)
		D(r, "NeonStrip", V(0.3, 0.3, SL), HW - 0.3, y, SL / 2, pink, M.Neon, FX)
	end
	ball(r, "BlackHole", 10, 0, 15, 47, RGB(5, 0, 10), M.SmoothPlastic, FX)
	local ring = disc(r, "BlackHoleRing", 0.3, 17, 0, 15, 47, purple, M.Neon, {Transparency = 0.25, CanCollide = false}, CFrame.Angles(math.rad(75), 0, math.rad(90)))
	light(ring, purple, 50, 3)
	emitter(ring, {Color = ColorSequence.new(purple, pink), LightEmission = 1, Rate = 30, Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(4, 8), Size = NumberSequence.new(0.6, 0), SpreadAngle = Vector2.new(180, 180)})
	local planet = ball(r, "Planet", 6, -24, 15, 30, RGB(255, 140, 60), M.SmoothPlastic, FX)
	light(planet, RGB(255, 160, 80), 16, 1)
	disc(r, "PlanetRing", 0.2, 11, -24, 15, 30, RGB(255, 220, 160), M.Neon, {Transparency = 0.4, CanCollide = false}, CFrame.Angles(math.rad(20), 0, math.rad(75)))
	ball(r, "Planet2", 4, 25, 16, 26, RGB(80, 170, 255), M.SmoothPlastic, FX)
	ball(r, "Moon", 1.5, 28, 18, 24, RGB(220, 220, 230), M.SmoothPlastic, FX)
	for i = 1, 6 do
		local x = (i % 2 == 0) and 29 or -29
		pillar(r, "CrystalPillar", 4 + i, 1.4, x, F, 26 + i * 3, (i % 3 == 0) and purple or pink, M.Neon, {Transparency = 0.15})
	end
	ambience(r, {RGB(255, 255, 255), RGB(220, 170, 255)}, {rate = 40, speed = 0.3, size = 0.2, glow = 1, accel = Vector3.new(0, 0, 0), y = 12, life = 6})
end

------------------------------------------------------------------
-- OPEN-AIR BIOMES (v18): every area is an open zone on a floating island
-- under the night sky. The lane itself stays the same (invisible walls keep
-- you in), but around it: crystals, palms, blocky trees, tombstones...
------------------------------------------------------------------
local BW = 30 -- width of the decorated strip on each side of the lane (design units)
local WEDGE_TIP = CFrame.Angles(0, math.rad(45), 0)
local function shard(r, x, y, d, w, h, color, tilt, yaw, mat)
	-- a crystal shard: a tall block with a pointy (rotated) tip
	local rot = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(tilt), 0, math.rad(tilt * 0.6))
	local base = D(r, "Crystal", V(w, h, w), x, y + h / 2, d, color, mat or M.Glass, {Transparency = (mat == M.Neon) and 0.1 or 0.05, Reflectance = 0.1}, rot)
	local tip = D(r, "CrystalTip", V(w * 0.72, w * 0.72, w * 0.72), x, y + h, d, color:Lerp(RGB(255, 255, 255), 0.25), mat or M.Glass, {Transparency = 0.05, CanCollide = false},
		rot * CFrame.Angles(math.rad(45), 0, math.rad(45)))
	return base, tip
end
local PROPS = {}
PROPS.crystal = function(r, x, d, b)
	local s = 0.8 + math.random() * 0.8
	local c = b.crystal[math.random(1, #b.crystal)]
	shard(r, x, F, d, 2.2 * s, 7 * s, c, 0, math.random(0, 90))
	shard(r, x + 1.6 * s, F, d + 0.8 * s, 1.5 * s, 4.5 * s, c, 22, math.random(0, 90))
	shard(r, x - 1.4 * s, F, d - 0.6 * s, 1.3 * s, 3.6 * s, c:Lerp(RGB(255, 255, 255), 0.2), -24, math.random(0, 90))
	if math.random() < 0.35 then
		local glow = D(r, "CrystalGlow", V(1, 1, 1), x, F + 2, d, c, M.Neon, GHOST)
		light(glow, c, 18, 1.2)
	end
end
PROPS.bigcrystal = function(r, x, d, b)
	local c = b.crystal[math.random(1, #b.crystal)]
	shard(r, x, F, d, 4.2, 15, c, 6, math.random(0, 90))
	shard(r, x + 3, F, d + 1, 2.6, 9, c, 25, math.random(0, 90))
	shard(r, x - 2.6, F, d - 1.4, 2.2, 7, c, -28, math.random(0, 90))
	local glow = D(r, "CrystalGlow", V(1, 1, 1), x, F + 4, d, c, M.Neon, GHOST)
	light(glow, c, 26, 1.5)
end
local function voxelCanopy(r, x, y, d, size, colors, n)
	for k = 1, n do
		local a = k * 2.4
		local s = size * (0.55 + math.random() * 0.45)
		local rr = size * 0.45
		D(r, "Leaves", V(s, s * 0.8, s), x + math.cos(a) * rr * math.random(), y + (math.random() - 0.3) * size * 0.4, d + math.sin(a) * rr * math.random(),
			colors[(k - 1) % #colors + 1], M.SmoothPlastic, NO_COLLIDE, CFrame.Angles(0, math.rad(math.random(0, 60)), 0))
	end
end
PROPS.tree = function(r, x, d, b) -- blocky tree (blossom / willow / jungle)
	local h = 7 + math.random() * 4
	D(r, "Trunk", V(1.3, h, 1.3), x, F + h / 2, d, b.trunk, M.Wood)
	D(r, "Branch", V(0.7, 3, 0.7), x + 1, F + h * 0.75, d, b.trunk, M.Wood, nil, CFrame.Angles(0, 0, math.rad(-35)))
	voxelCanopy(r, x, F + h + 1, d, 6.5, b.leaves, 6)
	if b.hanging then -- glowing light strings hanging down (like willow lights)
		for k = 1, 5 do
			local a = k * 1.25
			D(r, "HangLight", V(0.25, 4.5, 0.25), x + math.cos(a) * 3.2, F + h - 2.2, d + math.sin(a) * 3.2, b.hanging, M.Neon, FX)
		end
	end
end
PROPS.palm = function(r, x, d, b)
	local h = 9 + math.random() * 4
	local lean = math.random(-12, 12)
	for k = 0, 3 do
		D(r, "PalmTrunk", V(1.4 - k * 0.1, h / 4 + 0.3, 1.4 - k * 0.1), x + k * lean * 0.03, F + h / 8 + k * h / 4, d, (k % 2 == 0) and RGB(150, 105, 65) or RGB(125, 85, 50), M.Wood, nil, CFrame.Angles(0, 0, math.rad(lean * 0.4)))
	end
	local top = x + 3 * lean * 0.03
	for k = 0, 5 do
		D(r, "PalmLeaf", V(7.5, 0.3, 2), top, F + h + 0.2, d, (k % 2 == 0) and RGB(50, 200, 60) or RGB(30, 160, 50), M.SmoothPlastic, NO_COLLIDE,
			CFrame.Angles(0, math.rad(k * 60 + math.random(0, 20)), 0) * CFrame.new(3.2, 0, 0) * CFrame.Angles(0, 0, math.rad(-25)))
	end
	for i = 1, 2 do ball(r, "Coconut", 0.9, top + (i - 1.5) * 0.9, F + h - 0.6, d + 0.5, RGB(110, 70, 40), M.SmoothPlastic, NO_COLLIDE) end
end
PROPS.deadtree = function(r, x, d, b)
	local h = 8 + math.random() * 4
	D(r, "DeadTrunk", V(1.3, h, 1.3), x, F + h / 2, d, RGB(70, 40, 35), M.Wood)
	for k = 1, 4 do
		local side = (k % 2 == 0) and 1 or -1
		D(r, "DeadBranch", V(0.5, 3.5 + k * 0.4, 0.5), x + side * 1.3, F + h * (0.45 + k * 0.12), d + (k - 2.5) * 0.4, RGB(70, 40, 35), M.Wood, nil,
			CFrame.Angles(math.rad((k - 2.5) * 12), 0, math.rad(-side * 45)))
	end
end
PROPS.tombstone = function(r, x, d, b)
	local c = b.stone or RGB(120, 110, 160)
	local yaw = CFrame.Angles(0, math.rad(math.random(-15, 15)), math.rad(math.random(-8, 8)))
	if math.random() < 0.3 then
		D(r, "GraveCross", V(0.6, 3.6, 0.6), x, F + 1.8, d, c, M.Slate, nil, yaw)
		D(r, "GraveCrossArm", V(2.2, 0.6, 0.6), x, F + 2.6, d, c, M.Slate, nil, yaw)
	else
		D(r, "Tombstone", V(2.2, 2.4, 0.7), x, F + 1.2, d, c, M.Slate, nil, yaw)
		disc(r, "TombTop", 0.7, 2.2, x, F + 2.4, d, c, M.Slate, nil, yaw * CFrame.Angles(0, math.rad(90), 0))
	end
	D(r, "GraveDirt", V(2.4, 0.3, 3.6), x, F + 0.15, d + 2, RGB(70, 40, 45), M.Ground, FX)
end
PROPS.rock = function(r, x, d, b)
	local s = 1.5 + math.random() * 2.5
	D(r, "Rock", V(s * 1.4, s, s * 1.2), x, F + s * 0.35, d, b.rock or RGB(90, 95, 120), M.Slate, nil, CFrame.Angles(math.rad(math.random(-20, 20)), math.rad(math.random(0, 90)), math.rad(math.random(-20, 20))))
end
PROPS.lantern = function(r, x, d, b)
	D(r, "LanternPost", V(0.6, 8, 0.6), x, F + 4, d, RGB(40, 40, 50), M.Metal)
	D(r, "LanternCap", V(1.8, 0.4, 1.8), x, F + 9.4, d, RGB(40, 40, 50), M.Metal)
	local head = D(r, "LanternLight", V(1.3, 1.4, 1.3), x, F + 8.5, d, b.lamp, M.Neon, NO_COLLIDE)
	light(head, b.lamp, 30, 1.6)
end
PROPS.mushroom = function(r, x, d, b)
	local h = 2 + math.random() * 4
	local c = b.crystal[math.random(1, #b.crystal)]
	pillar(r, "ShroomStem", h, 1, x, F, d, RGB(235, 230, 220), M.SmoothPlastic)
	local cap = ball(r, "ShroomCap", 3 + h * 0.4, x, F + h, d, c, M.Neon, {Transparency = 0.1})
	if math.random() < 0.4 then light(cap, c, 16, 1) end
end
PROPS.haybale = function(r, x, d, b)
	D(r, "HayBale", V(4, 2.4, 3), x, F + 1.2, d, RGB(230, 195, 90), M.Fabric, nil, CFrame.Angles(0, math.rad(math.random(0, 90)), 0))
	if math.random() < 0.5 then D(r, "HayBale", V(4, 2.4, 3), x, F + 3.6, d, RGB(220, 185, 80), M.Fabric, nil, CFrame.Angles(0, math.rad(math.random(0, 90)), 0)) end
end
PROPS.pumpkin = function(r, x, d, b)
	local s = 1.6 + math.random() * 1.4
	ball(r, "Pumpkin", s, x, F + s * 0.4, d, RGB(255, 130, 30), M.SmoothPlastic)
	D(r, "PumpkinStem", V(0.3, 0.6, 0.3), x, F + s * 0.9, d, RGB(70, 120, 40), M.Wood)
end
PROPS.toyblock = function(r, x, d, b)
	local cols = {RGB(255, 80, 80), RGB(80, 160, 255), RGB(255, 210, 40), RGB(90, 220, 110), RGB(200, 110, 255)}
	for k = 0, math.random(0, 2) do
		local s = 2.6 + math.random()
		D(r, "ToyBlock", V(s, s, s), x + (math.random() - 0.5), F + s / 2 + k * s, d, cols[math.random(1, #cols)], M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(math.random(0, 90)), 0))
	end
end
PROPS.lollipop = function(r, x, d, b)
	local h = 5 + math.random() * 4
	local c = b.crystal[math.random(1, #b.crystal)]
	pillar(r, "LollipopStick", h, 0.5, x, F, d, RGB(250, 250, 250), M.SmoothPlastic)
	disc(r, "Lollipop", 0.9, 4.5, x, F + h + 1.8, d, c, M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(math.random(0, 180)), 0) * CFrame.Angles(0, math.rad(90), 0))
	disc(r, "Swirl", 1, 2.2, x, F + h + 1.8, d, RGB(255, 255, 255), M.SmoothPlastic, NO_COLLIDE, CFrame.Angles(0, math.rad(math.random(0, 180)), 0) * CFrame.Angles(0, math.rad(90), 0))
end
PROPS.gumdrop = function(r, x, d, b)
	local c = b.crystal[math.random(1, #b.crystal)]
	ball(r, "Gumdrop", 2.6 + math.random() * 1.5, x, F + 0.6, d, c, M.SmoothPlastic, {Reflectance = 0.15})
end
PROPS.fern = function(r, x, d, b)
	for k = 0, 4 do
		D(r, "FernLeaf", V(4, 0.2, 1.2), x, F + 1, d, RGB(50, 160 + k * 12, 60), M.Grass, NO_COLLIDE,
			CFrame.Angles(0, math.rad(k * 72), 0) * CFrame.new(1.6, 0, 0) * CFrame.Angles(0, 0, math.rad(30)))
	end
end
PROPS.volcano = function(r, x, d, b)
	D(r, "Volcano", V(12, 7, 12), x, F + 2, d, RGB(80, 55, 45), M.Slate, nil, CFrame.Angles(0, math.rad(45), 0))
	D(r, "VolcanoTop", V(8, 4, 8), x, F + 6.5, d, RGB(70, 48, 40), M.Slate, nil, CFrame.Angles(0, math.rad(20), 0))
	local lava = D(r, "Lava", V(4.5, 0.5, 4.5), x, F + 8.6, d, RGB(255, 100, 20), M.Neon, NO_COLLIDE)
	light(lava, RGB(255, 120, 40), 30, 2)
	emitter(lava, {Color = ColorSequence.new(RGB(255, 160, 60), RGB(120, 40, 20)), LightEmission = 0.6, Rate = 6, Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(3, 6), Size = NumberSequence.new(1.2, 3), Transparency = NumberSequence.new(0.2, 1), SpreadAngle = Vector2.new(15, 15)})
end
PROPS.neonpillar = function(r, x, d, b)
	local h = 6 + math.random() * 10
	local c = b.crystal[math.random(1, #b.crystal)]
	D(r, "TechPillar", V(2, h, 2), x, F + h / 2, d, RGB(30, 34, 46), M.Metal)
	for k = 1, math.floor(h / 3) do
		D(r, "TechStripe", V(2.1, 0.3, 2.1), x, F + k * 3, d, c, M.Neon, FX)
	end
	if math.random() < 0.4 then light(D(r, "TechGlow", V(1, 1, 1), x, F + h, d, c, M.Neon, GHOST), c, 20, 1.2) end
end
PROPS.floatrock = function(r, x, d, b)
	local s = 2 + math.random() * 3
	local y = 10 + math.random() * 14
	D(r, "FloatRock", V(s * 1.3, s, s), x, y, d, RGB(60, 45, 90), M.Slate, NO_COLLIDE, CFrame.Angles(math.rad(math.random(0, 40)), math.rad(math.random(0, 90)), 0))
	local c = b.crystal[math.random(1, #b.crystal)]
	shard(r, x, y + s * 0.4, d, s * 0.4, s * 1.1, c, 10, math.random(0, 90), M.Neon)
end
PROPS.snowpile = function(r, x, d, b)
	ball(r, "SnowPile", 3 + math.random() * 3, x, F - 0.8, d, RGB(250, 252, 255), M.Snow)
end
PROPS.crate = function(r, x, d, b)
	D(r, "OldCrate", V(3, 3, 3), x, F + 1.4, d, RGB(120, 95, 70), M.WoodPlanks, nil, CFrame.Angles(math.rad(math.random(-8, 8)), math.rad(math.random(0, 90)), 0))
end
PROPS.fence = function(r, x, d, b)
	D(r, "FenceRail", V(0.3, 0.4, 7), x, F + 1.3, d, RGB(250, 250, 250), M.WoodPlanks)
	D(r, "FenceRail", V(0.3, 0.4, 7), x, F + 2.6, d, RGB(250, 250, 250), M.WoodPlanks)
	for k = -1, 1 do D(r, "FencePost", V(0.45, 3.4, 0.45), x, F + 1.7, d + k * 3.2, RGB(250, 250, 250), M.WoodPlanks) end
end

-- what grows in each area: ground colour + weighted prop list
local BIOMES = {
	{ -- 1 Dusty Storage -> spooky graveyard yard
		ground = RGB(115, 50, 60), lane = RGB(140, 70, 78), cliff = RGB(55, 30, 45), stone = RGB(130, 115, 170), trunk = RGB(70, 40, 35),
		leaves = {RGB(150, 90, 200)}, crystal = {RGB(170, 110, 255), RGB(110, 140, 255)}, lamp = RGB(255, 140, 60), rock = RGB(90, 70, 100),
		props = {{"tombstone", 6}, {"deadtree", 3}, {"crystal", 2}, {"lantern", 1}, {"pumpkin", 1}, {"crate", 1}},
		fog = {RGB(200, 140, 255)},
	},
	{ -- 2 Farm Barn -> moonlit farm
		ground = RGB(80, 160, 70), lane = RGB(170, 135, 85), cliff = RGB(80, 55, 40), trunk = RGB(110, 75, 45),
		leaves = {RGB(70, 190, 70), RGB(50, 160, 60)}, crystal = {RGB(255, 200, 80)}, lamp = RGB(255, 200, 110), rock = RGB(120, 115, 105),
		props = {{"tree", 4}, {"haybale", 3}, {"pumpkin", 3}, {"fence", 2}, {"lantern", 1}, {"rock", 1}},
	},
	{ -- 3 Toy Factory -> toy land
		ground = RGB(120, 200, 255), lane = RGB(225, 232, 250), cliff = RGB(70, 90, 170), trunk = RGB(250, 250, 250),
		leaves = {RGB(255, 120, 120), RGB(255, 220, 80), RGB(120, 220, 120)}, crystal = {RGB(255, 90, 90), RGB(90, 170, 255), RGB(255, 220, 60)}, lamp = RGB(255, 255, 220),
		props = {{"toyblock", 5}, {"tree", 2}, {"lollipop", 2}, {"crystal", 2}, {"lantern", 1}},
	},
	{ -- 4 Candy Shop -> blossom candy land
		ground = RGB(255, 175, 215), lane = RGB(255, 210, 230), cliff = RGB(160, 80, 130), trunk = RGB(130, 75, 70),
		leaves = {RGB(255, 170, 215), RGB(255, 205, 230), RGB(240, 140, 200)}, crystal = {RGB(255, 90, 160), RGB(110, 220, 255), RGB(255, 220, 60), RGB(150, 255, 140)}, lamp = RGB(255, 190, 230),
		props = {{"tree", 5}, {"lollipop", 3}, {"gumdrop", 3}, {"crystal", 1}, {"lantern", 1}},
	},
	{ -- 5 Pirate Cove -> tropical beach
		ground = RGB(240, 205, 140), lane = RGB(235, 210, 160), cliff = RGB(150, 110, 70), trunk = RGB(150, 105, 65),
		leaves = {RGB(60, 190, 70)}, crystal = {RGB(120, 220, 255)}, lamp = RGB(255, 170, 70), rock = RGB(130, 120, 110),
		props = {{"palm", 6}, {"rock", 2}, {"crate", 1}, {"lantern", 2}},
		sea = true,
	},
	{ -- 6 Dino Museum -> jungle with a volcano
		ground = RGB(70, 140, 60), lane = RGB(205, 185, 140), cliff = RGB(70, 55, 40), trunk = RGB(100, 70, 45),
		leaves = {RGB(40, 150, 50), RGB(80, 190, 60), RGB(30, 120, 45)}, crystal = {RGB(255, 140, 40)}, lamp = RGB(255, 180, 90), rock = RGB(105, 100, 90),
		props = {{"tree", 4}, {"fern", 4}, {"palm", 2}, {"rock", 2}, {"lantern", 1}},
		landmark = "volcano",
	},
	{ -- 7 Frozen Lab -> ice crystal field (like the video)
		ground = RGB(225, 238, 255), lane = RGB(205, 225, 250), cliff = RGB(110, 140, 200), trunk = RGB(150, 120, 190),
		leaves = {RGB(160, 150, 255), RGB(190, 180, 255), RGB(140, 170, 255)}, hanging = RGB(150, 220, 255),
		crystal = {RGB(120, 200, 255), RGB(80, 160, 255), RGB(170, 230, 255)}, lamp = RGB(170, 230, 255), rock = RGB(170, 190, 220),
		props = {{"crystal", 5}, {"tree", 3}, {"snowpile", 2}, {"lantern", 1}},
		landmark = "bigcrystal",
	},
	{ -- 8 Tech Lab -> neon cyber city
		ground = RGB(40, 46, 66), lane = RGB(60, 66, 84), cliff = RGB(25, 28, 40), trunk = RGB(40, 40, 50),
		leaves = {RGB(60, 170, 255)}, crystal = {RGB(60, 170, 255), RGB(140, 255, 255), RGB(255, 80, 200)}, lamp = RGB(120, 220, 255),
		props = {{"neonpillar", 6}, {"crystal", 2}, {"rock", 1}},
		grid = RGB(60, 170, 255),
	},
	{ -- 9 Alien Hangar -> alien planet
		ground = RGB(70, 50, 100), lane = RGB(85, 80, 105), cliff = RGB(40, 25, 60), trunk = RGB(60, 40, 80),
		leaves = {RGB(110, 255, 140)}, crystal = {RGB(90, 255, 120), RGB(60, 255, 210), RGB(200, 255, 80)}, lamp = RGB(140, 255, 140), rock = RGB(90, 70, 120),
		props = {{"mushroom", 5}, {"crystal", 3}, {"rock", 2}},
	},
	{ -- 10 Galaxy Vault -> space island
		ground = RGB(35, 25, 65), lane = RGB(30, 22, 52), cliff = RGB(20, 12, 40), trunk = RGB(60, 40, 90),
		leaves = {RGB(200, 120, 255)}, crystal = {RGB(200, 100, 255), RGB(255, 90, 210), RGB(110, 140, 255)}, lamp = RGB(220, 150, 255), rock = RGB(70, 55, 110),
		props = {{"crystal", 4}, {"floatrock", 3}, {"mushroom", 1}, {"rock", 1}},
		landmark = "bigcrystal",
	},
}

local function pickProp(list)
	local total = 0
	for _, e in ipairs(list) do total = total + e[2] end
	local roll = math.random() * total
	for _, e in ipairs(list) do
		roll = roll - e[2]
		if roll <= 0 then return e[1] end
	end
	return list[1][1]
end

local function buildBiome(r, b)
	-- ground strips on both sides of the lane + a rocky cliff underneath (floating island look)
	for _, side in ipairs({-1, 1}) do
		local g = D(r, "Ground", V(BW, 0.4, SL), side * (HW + BW / 2), 0.3, SL / 2, b.ground, M.SmoothPlastic)
		g.TopSurface = Enum.SurfaceType.Studs
		D(r, "GroundEdge", V(0.6, 0.5, SL), side * (HW + BW - 0.3), 0.5, SL / 2, b.ground:Lerp(RGB(255, 255, 255), 0.35), M.SmoothPlastic, FX)
	end
	D(r, "Cliff", V((HW + BW) * 2, 10, SL), 0, -5.2, SL / 2, b.cliff, M.Slate)
	D(r, "CliffLow", V((HW + BW) * 2 - 14, 10, SL - 6), 0, -14, SL / 2, b.cliff:Lerp(RGB(0, 0, 0), 0.35), M.Slate)
	if b.sea then
		for _, side in ipairs({-1, 1}) do
			D(r, "Sea", V(60, 0.6, SL), side * (HW + BW + 28), -0.4, SL / 2, RGB(40, 150, 230), M.SmoothPlastic, {Transparency = 0.15, Reflectance = 0.15, CanCollide = false})
			D(r, "Foam", V(1.2, 0.65, SL), side * (HW + BW - 0.5), -0.35, SL / 2, RGB(240, 250, 255), M.SmoothPlastic, FX)
		end
	end
	if b.grid then
		for _, side in ipairs({-1, 1}) do
			for k = 1, 3 do D(r, "GridLine", V(0.2, 0.06, SL), side * (HW + k * BW / 4), F + 0.04, SL / 2, b.grid, M.Neon, FX) end
			for d = 5, SL - 5, 10 do D(r, "GridLine", V(BW, 0.06, 0.2), side * (HW + BW / 2), F + 0.04, d, b.grid, M.Neon, FX) end
		end
	end
	-- scatter props on a jittered grid (never inside the lane)
	for _, side in ipairs({-1, 1}) do
		for row = 0, 5 do
			for col = 0, 2 do
				local x = side * (HW + 5 + col * 9 + (math.random() - 0.5) * 4)
				local d = 4 + row * 8.4 + (math.random() - 0.5) * 4
				local kind = pickProp(b.props)
				PROPS[kind](r, x, d, b)
			end
		end
	end
	if b.landmark then PROPS[b.landmark](r, (r.index % 2 == 0) and (HW + BW * 0.55) or -(HW + BW * 0.55), SL * 0.5, b) end
	-- soft coloured mist over the zone
	if b.fog then ambience(r, b.fog, {rate = 8, speed = 0.3, size = 2.5, glow = 0.3, accel = Vector3.new(0.2, 0, 0), y = F + 1.5, life = 9}) end
end

-- the floating zone title (text on an invisible board: stays in the world, never piles up on screen)
local function zoneTitle(r, area, acc)
	local board = D(r, "ZoneTitle", V(44, 9, 0.2), 0, 21, 0, RGB(0, 0, 0), nil, GHOST)
	for _, face in ipairs({Enum.NormalId.Back, Enum.NormalId.Front}) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Title"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 20
		sg.LightInfluence = 0
		sg.Parent = board
		local small = Instance.new("TextLabel")
		small.BackgroundTransparency = 1
		small.Size = UDim2.fromScale(1, 0.28)
		small.FontFace = Config.Font
		small.TextScaled = true
		small.TextColor3 = acc
		small.Text = "AREA " .. r.index
		small.Parent = sg
		local s1 = Instance.new("UIStroke")
		s1.Thickness = 4
		s1.Color = RGB(20, 15, 40)
		s1.Parent = small
		local big = Instance.new("TextLabel")
		big.BackgroundTransparency = 1
		big.Position = UDim2.fromScale(0, 0.28)
		big.Size = UDim2.fromScale(1, 0.72)
		big.FontFace = Config.Font
		big.TextScaled = true
		big.TextColor3 = RGB(255, 255, 255)
		big.Text = string.upper(area.name)
		big.Parent = sg
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 6
		s2.Color = RGB(20, 15, 40)
		s2.Parent = big
	end
end

------------------------------------------------------------------
-- LIVING AREAS: critters that walk / fly around and set pieces that spin, bob and sway.
-- Everything here is moved by the CLIENTS (smooth, and free for the server):
-- tag "Animated" + attribute Anim = spin / bob / hover / bounce / sway / orbit / leap / pulse / wander / fly.
-- Parts inside a moving model can flap (wings), spin (rotors) or step (legs).
------------------------------------------------------------------
local CSS = game:GetService("CollectionService")
local function animate(inst, kind, attrs)
	inst:SetAttribute("Anim", kind)
	for k, v in pairs(attrs or {}) do inst:SetAttribute(k, v) end
	CSS:AddTag(inst, "Animated")
	return inst
end
-- one part of a moving thing: rc = the thing's root CFrame (world), off = offset in studs
local function CP(mdl, name, size, rc, off, color, mat, shape, rot)
	local p = P(mdl, name, size, rc * CFrame.new(off) * (rot or CFrame.new()), color, mat or M.SmoothPlastic, FX)
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "ell" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	return p
end
local function newThing(r, name)
	local mdl = Instance.new("Model")
	mdl.Name = name
	mdl.Parent = r.folder
	return mdl
end
local function finish(mdl, rc, kind, attrs)
	mdl.WorldPivot = rc
	return animate(mdl, kind, attrs)
end
local GROUND_Y = L.floorY
-- the walk-around box of a side strip (world coords)
local function stripBox(r, side, y0, y1)
	local x1, x2 = side * (HW + 6) * SC, side * (HW + BW - 6) * SC
	local z1, z2 = r.z0 - 5 * SC, r.z0 - (SL - 5) * SC
	return Vector3.new(math.min(x1, x2), y0, math.min(z1, z2)), Vector3.new(math.max(x1, x2), y1, math.max(z1, z2))
end
-- a box over the lane (for flyers)
local function laneBox(r, y0, y1)
	local z1, z2 = r.z0 - 6 * SC, r.z0 - (SL - 6) * SC
	return Vector3.new(-HW * SC * 0.8, y0, math.min(z1, z2)), Vector3.new(HW * SC * 0.8, y1, math.max(z1, z2))
end
local function randIn(mn, mx)
	return Vector3.new(mn.X + math.random() * (mx.X - mn.X), mn.Y + math.random() * (mx.Y - mn.Y), mn.Z + math.random() * (mx.Z - mn.Z))
end

------------------------------------------------------------------
-- critters (built facing -Z, feet at the root)
------------------------------------------------------------------
local CRITTER = {}
CRITTER.chicken = function(r, rc)
	local m = newThing(r, "Chicken")
	CP(m, "Body", V(1.3, 1.1, 1.6), rc, V(0, 1.2, 0), RGB(250, 250, 245), nil, "ell")
	CP(m, "Head", V(0.75, 0.75, 0.75), rc, V(0, 2.0, -0.7), RGB(250, 250, 245), nil, "ball")
	CP(m, "Beak", V(0.22, 0.18, 0.35), rc, V(0, 1.95, -1.15), RGB(255, 180, 40))
	CP(m, "Comb", V(0.12, 0.35, 0.5), rc, V(0, 2.45, -0.7), RGB(230, 40, 40))
	CP(m, "Wattle", V(0.12, 0.25, 0.15), rc, V(0, 1.72, -1.0), RGB(230, 40, 40))
	for _, sx in ipairs({-1, 1}) do
		CP(m, "Eye", V(0.1, 0.12, 0.08), rc, V(sx * 0.3, 2.1, -0.95), RGB(20, 20, 20))
		local w = CP(m, "Wing", V(0.5, 0.15, 0.9), rc, V(sx * 0.8, 1.35, 0.05), RGB(235, 235, 230), nil, "ell")
		w:SetAttribute("Flap", sx)
		local leg = CP(m, "Leg", V(0.12, 0.7, 0.12), rc, V(sx * 0.3, 0.35, 0), RGB(255, 180, 40))
		leg:SetAttribute("Step", sx)
	end
	CP(m, "Tail", V(0.6, 0.7, 0.3), rc, V(0, 1.6, 0.85), RGB(240, 240, 235), nil, nil, CFrame.Angles(math.rad(25), 0, 0))
	return m
end
CRITTER.cow = function(r, rc)
	local m = newThing(r, "Cow")
	CP(m, "Body", V(2.2, 1.9, 3.6), rc, V(0, 2.4, 0), RGB(250, 250, 250))
	for _, sp in ipairs({{0.6, 2.6, -0.8, 1.1}, {-0.5, 2.2, 0.6, 1.3}, {0.3, 2.9, 1.1, 0.8}}) do
		CP(m, "Spot", V(2.25, sp[4], sp[4]), rc, V(0, sp[2], sp[3]), RGB(30, 30, 30))
	end
	CP(m, "Head", V(1.4, 1.3, 1.4), rc, V(0, 3.0, -2.3), RGB(250, 250, 250))
	CP(m, "Snout", V(1.2, 0.7, 0.5), rc, V(0, 2.6, -3.1), RGB(255, 180, 190))
	for _, sx in ipairs({-1, 1}) do
		CP(m, "Eye", V(0.14, 0.2, 0.08), rc, V(sx * 0.4, 3.25, -3.0), RGB(20, 20, 20))
		CP(m, "Horn", V(0.18, 0.5, 0.18), rc, V(sx * 0.5, 3.85, -2.2), RGB(240, 230, 200))
		CP(m, "Ear", V(0.5, 0.2, 0.3), rc, V(sx * 0.9, 3.4, -2.2), RGB(250, 250, 250))
		for _, dz in ipairs({-1.2, 1.2}) do
			local leg = CP(m, "Leg", V(0.5, 1.5, 0.5), rc, V(sx * 0.7, 0.75, dz), RGB(250, 250, 250))
			leg:SetAttribute("Step", sx * (dz > 0 and -1 or 1))
		end
	end
	CP(m, "Udder", V(0.8, 0.4, 0.8), rc, V(0, 1.35, 0.7), RGB(255, 170, 185))
	CP(m, "Tail", V(0.15, 1.3, 0.15), rc, V(0, 2.4, 1.85), RGB(240, 240, 240), nil, nil, CFrame.Angles(math.rad(-20), 0, 0))
	return m
end
CRITTER.bat = function(r, rc)
	local m = newThing(r, "Bat")
	CP(m, "Body", V(0.7, 0.8, 0.9), rc, V(0, 0, 0), RGB(35, 25, 45), nil, "ell")
	CP(m, "Head", V(0.55, 0.55, 0.55), rc, V(0, 0.35, -0.45), RGB(35, 25, 45), nil, "ball")
	for _, sx in ipairs({-1, 1}) do
		CP(m, "Ear", V(0.15, 0.35, 0.12), rc, V(sx * 0.18, 0.75, -0.45), RGB(35, 25, 45))
		CP(m, "Eye", V(0.1, 0.1, 0.05), rc, V(sx * 0.13, 0.42, -0.72), RGB(255, 60, 60), M.Neon)
		local w = CP(m, "Wing", V(1.5, 0.08, 0.8), rc, V(sx * 1.05, 0.1, 0), RGB(60, 40, 75))
		w:SetAttribute("Flap", sx)
	end
	return m
end
CRITTER.butterfly = function(r, rc, color)
	local m = newThing(r, "Butterfly")
	CP(m, "Body", V(0.12, 0.12, 0.6), rc, V(0, 0, 0), RGB(40, 30, 30))
	for _, sx in ipairs({-1, 1}) do
		local w = CP(m, "Wing", V(0.6, 0.04, 0.7), rc, V(sx * 0.35, 0, -0.05), color, M.Neon, nil)
		w.Transparency = 0.1
		w:SetAttribute("Flap", sx)
	end
	return m
end
CRITTER.seagull = function(r, rc)
	local m = newThing(r, "Seagull")
	CP(m, "Body", V(0.7, 0.6, 1.4), rc, V(0, 0, 0), RGB(250, 250, 250), nil, "ell")
	CP(m, "Head", V(0.5, 0.5, 0.5), rc, V(0, 0.25, -0.7), RGB(250, 250, 250), nil, "ball")
	CP(m, "Beak", V(0.14, 0.12, 0.4), rc, V(0, 0.2, -1.05), RGB(255, 200, 40))
	CP(m, "Tail", V(0.5, 0.08, 0.5), rc, V(0, 0.05, 0.85), RGB(200, 200, 205))
	for _, sx in ipairs({-1, 1}) do
		local w = CP(m, "Wing", V(1.7, 0.08, 0.6), rc, V(sx * 1.15, 0.1, 0), RGB(235, 235, 240))
		w:SetAttribute("Flap", sx)
	end
	return m
end
CRITTER.fish = function(r, rc, color)
	local m = newThing(r, "Fish")
	CP(m, "Body", V(0.5, 0.8, 1.6), rc, V(0, 0, 0), color, nil, "ell")
	CP(m, "Tail", V(0.08, 0.7, 0.6), rc, V(0, 0, 0.95), color:Lerp(RGB(0, 0, 0), 0.15))
	CP(m, "Fin", V(0.08, 0.35, 0.5), rc, V(0, 0.45, 0), color:Lerp(RGB(255, 255, 255), 0.2))
	for _, sx in ipairs({-1, 1}) do CP(m, "Eye", V(0.08, 0.14, 0.14), rc, V(sx * 0.22, 0.12, -0.5), RGB(20, 20, 20)) end
	return m
end
CRITTER.ptero = function(r, rc)
	local m = newThing(r, "Pterodactyl")
	CP(m, "Body", V(1.0, 0.9, 2.2), rc, V(0, 0, 0), RGB(170, 110, 70), nil, "ell")
	CP(m, "Head", V(0.7, 0.7, 1.3), rc, V(0, 0.4, -1.4), RGB(170, 110, 70), nil, "ell")
	CP(m, "Beak", V(0.25, 0.25, 1.2), rc, V(0, 0.3, -2.4), RGB(230, 200, 140))
	CP(m, "Crest", V(0.12, 0.5, 1.1), rc, V(0, 0.75, -0.9), RGB(200, 60, 40), nil, nil, CFrame.Angles(math.rad(-25), 0, 0))
	for _, sx in ipairs({-1, 1}) do
		local w = CP(m, "Wing", V(3.4, 0.1, 1.4), rc, V(sx * 2.1, 0.2, 0), RGB(200, 140, 90))
		w:SetAttribute("Flap", sx)
		CP(m, "Eye", V(0.08, 0.14, 0.14), rc, V(sx * 0.3, 0.55, -1.6), RGB(255, 220, 40), M.Neon)
	end
	return m
end
CRITTER.dino = function(r, rc)
	local m = newThing(r, "BabyDino")
	local g = RGB(110, 200, 90)
	CP(m, "Body", V(1.4, 1.3, 2.2), rc, V(0, 1.4, 0), g, nil, "ell")
	CP(m, "Neck", V(0.6, 1.2, 0.6), rc, V(0, 2.3, -0.9), g, nil, nil, CFrame.Angles(math.rad(-25), 0, 0))
	CP(m, "Head", V(0.9, 0.8, 1.2), rc, V(0, 2.95, -1.4), g, nil, "ell")
	CP(m, "Tail", V(0.5, 0.5, 1.6), rc, V(0, 1.3, 1.6), g, nil, nil, CFrame.Angles(math.rad(10), 0, 0))
	CP(m, "Belly", V(1.0, 0.9, 1.6), rc, V(0, 1.2, -0.1), RGB(240, 230, 150), nil, "ell")
	for k = 0, 3 do CP(m, "Plate", V(0.12, 0.45, 0.45), rc, V(0, 2.1 - k * 0.12, -0.3 + k * 0.55), RGB(255, 150, 50), nil, nil, CFrame.Angles(math.rad(45), 0, 0)) end
	for _, sx in ipairs({-1, 1}) do
		CP(m, "Eye", V(0.08, 0.18, 0.18), rc, V(sx * 0.4, 3.1, -1.6), RGB(20, 20, 20))
		local leg = CP(m, "Leg", V(0.45, 0.9, 0.5), rc, V(sx * 0.45, 0.45, 0.2), g:Lerp(RGB(0, 0, 0), 0.1))
		leg:SetAttribute("Step", sx)
	end
	return m
end
CRITTER.penguin = function(r, rc)
	local m = newThing(r, "Penguin")
	CP(m, "Body", V(1.1, 1.7, 1.0), rc, V(0, 1.1, 0), RGB(30, 30, 40), nil, "ell")
	CP(m, "Belly", V(0.85, 1.3, 0.6), rc, V(0, 1.0, -0.25), RGB(250, 250, 250), nil, "ell")
	CP(m, "Head", V(0.85, 0.8, 0.8), rc, V(0, 2.1, -0.05), RGB(30, 30, 40), nil, "ball")
	CP(m, "Beak", V(0.25, 0.15, 0.4), rc, V(0, 2.05, -0.5), RGB(255, 150, 40))
	for _, sx in ipairs({-1, 1}) do
		CP(m, "EyeWhite", V(0.2, 0.22, 0.08), rc, V(sx * 0.18, 2.25, -0.38), RGB(255, 255, 255))
		CP(m, "Eye", V(0.1, 0.12, 0.05), rc, V(sx * 0.18, 2.25, -0.42), RGB(20, 20, 20))
		local f = CP(m, "Flipper", V(0.18, 0.9, 0.5), rc, V(sx * 0.6, 1.25, 0), RGB(30, 30, 40))
		f:SetAttribute("Flap", sx)
		CP(m, "Foot", V(0.4, 0.12, 0.5), rc, V(sx * 0.25, 0.06, -0.25), RGB(255, 150, 40))
	end
	return m
end
CRITTER.drone = function(r, rc)
	local m = newThing(r, "Drone")
	CP(m, "Body", V(1.4, 0.45, 1.4), rc, V(0, 0, 0), RGB(50, 55, 70), M.Metal)
	local eye = CP(m, "Lens", V(0.4, 0.3, 0.1), rc, V(0, -0.05, -0.72), RGB(60, 170, 255), M.Neon)
	eye:SetAttribute("Blink", 0)
	for _, c in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
		CP(m, "Arm", V(0.12, 0.12, 0.9), rc, V(c[1] * 0.75, 0.1, c[2] * 0.75), RGB(80, 85, 100), M.Metal, nil, CFrame.Angles(0, math.rad(45 * c[1] * c[2]), 0))
		local rotor = CP(m, "Rotor", V(1.1, 0.05, 0.14), rc, V(c[1] * 1.05, 0.28, c[2] * 1.05), RGB(200, 210, 220))
		rotor:SetAttribute("SubSpin", 30 * c[1])
	end
	CP(m, "Light", V(0.2, 0.2, 0.2), rc, V(0, -0.3, 0), RGB(255, 60, 60), M.Neon, "ball"):SetAttribute("Blink", 1)
	return m
end
CRITTER.ufo = function(r, rc)
	local m = newThing(r, "MiniUFO")
	CP(m, "Hull", V(0.5, 3.2, 3.2), rc, V(0, 0, 0), RGB(180, 190, 205), M.Metal, "cyl", CFrame.Angles(0, 0, math.rad(90)))
	CP(m, "Dome", V(1.6, 1.3, 1.6), rc, V(0, 0.45, 0), RGB(120, 255, 160), M.Glass, "ell").Transparency = 0.3
	for k = 0, 5 do
		local a = k * math.pi / 3
		CP(m, "Light", V(0.3, 0.3, 0.3), rc, V(math.cos(a) * 1.45, -0.05, math.sin(a) * 1.45), (k % 2 == 0) and RGB(90, 255, 90) or RGB(255, 240, 80), M.Neon, "ball"):SetAttribute("Blink", k % 2)
	end
	local beam = CP(m, "Beam", V(4, 1.2, 1.2), rc, V(0, -2.2, 0), RGB(120, 255, 140), M.Neon, "cyl", CFrame.Angles(0, 0, math.rad(90)))
	beam.Transparency = 0.8
	return m
end
CRITTER.blob = function(r, rc)
	local m = newThing(r, "AlienBlob")
	CP(m, "Body", V(1.6, 1.3, 1.6), rc, V(0, 0.65, 0), RGB(120, 255, 140), M.SmoothPlastic, "ell").Reflectance = 0.15
	for _, sx in ipairs({-1, 1}) do
		CP(m, "Stalk", V(0.1, 0.7, 0.1), rc, V(sx * 0.3, 1.55, -0.2), RGB(100, 220, 120))
		CP(m, "Eye", V(0.32, 0.32, 0.32), rc, V(sx * 0.3, 1.95, -0.2), RGB(255, 255, 255), nil, "ball")
		CP(m, "Pupil", V(0.14, 0.14, 0.08), rc, V(sx * 0.3, 1.95, -0.36), RGB(20, 20, 20))
	end
	return m
end
CRITTER.ghost = function(r, rc)
	local m = newThing(r, "Ghost")
	local body = CP(m, "Body", V(1.8, 2.4, 1.8), rc, V(0, 0, 0), RGB(235, 240, 255), M.SmoothPlastic, "ell")
	body.Transparency = 0.35
	local tail = CP(m, "Tail", V(1.2, 1.4, 1.2), rc, V(0, -1.3, 0.2), RGB(235, 240, 255), M.SmoothPlastic, "ell")
	tail.Transparency = 0.55
	for _, sx in ipairs({-1, 1}) do CP(m, "Eye", V(0.3, 0.45, 0.1), rc, V(sx * 0.35, 0.3, -0.85), RGB(30, 20, 50)) end
	CP(m, "Mouth", V(0.4, 0.3, 0.1), rc, V(0, -0.2, -0.86), RGB(30, 20, 50), nil, "ell")
	local glow = Instance.new("PointLight")
	glow.Color = RGB(180, 200, 255)
	glow.Range = 14
	glow.Brightness = 1.2
	glow.Parent = body
	return m
end

-- place a critter at a random spot of a strip and let it wander there
local function walker(r, kind, side, speed, extra)
	local mn, mx = stripBox(r, side, GROUND_Y, GROUND_Y)
	local p = randIn(mn, mx)
	local rc = CFrame.new(p) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local m = CRITTER[kind](r, rc)
	local attrs = {Min = mn, Max = mx, Speed = speed, Amp = 0.25}
	for k, v in pairs(extra or {}) do attrs[k] = v end
	return finish(m, rc, "wander", attrs)
end
local function flyer(r, kind, mn, mx, speed, color)
	local p = randIn(mn, mx)
	local rc = CFrame.new(p)
	local m = CRITTER[kind](r, rc, color)
	return finish(m, rc, "fly", {Min = mn, Max = mx, Speed = speed, FlapSpeed = (kind == "ptero") and 4 or ((kind == "butterfly") and 22 or 12)})
end
local function orbiter(r, kind, center, radius, height, speed, phase, color)
	local rc = CFrame.new(center + Vector3.new(radius, height, 0))
	local m = CRITTER[kind](r, rc, color)
	return finish(m, rc, "orbit", {Center = CFrame.new(center + Vector3.new(0, height, 0)), Radius = radius, Speed = speed, Phase = phase or 0, Amp = 1.2, FlapSpeed = 5})
end

------------------------------------------------------------------
-- moving set pieces
------------------------------------------------------------------
local function windmill(r, x, d)
	local base = SCF(r, x, F, d).Position
	local tower = newThing(r, "Windmill")
	for k = 0, 4 do
		P(tower, "Tower", V(5 - k * 0.6, 3, 5 - k * 0.6) * SC, CFrame.new(base + V(0, (1.5 + k * 3) * SC, 0)), (k % 2 == 0) and RGB(200, 70, 60) or RGB(240, 235, 225), M.WoodPlanks)
	end
	P(tower, "Roof", V(3.6, 3.6, 3.6) * SC, CFrame.new(base + V(0, 16.5 * SC, 0)) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), RGB(90, 60, 45), M.WoodPlanks)
	-- the blades spin around the axis pointing at the lane
	local face = -math.sign(x)
	local hub = CFrame.lookAt(base + V(face * 2.4 * SC, 14 * SC, 0), base + V(face * 10 * SC, 14 * SC, 0))
	local blades = newThing(r, "WindmillBlades")
	CP(blades, "Hub", V(1.2, 1.2, 1.2) * SC, hub, V(0, 0, 0), RGB(90, 60, 45), M.Wood, "ball")
	for k = 0, 3 do
		local rot = CFrame.Angles(0, 0, k * math.pi / 2)
		CP(blades, "Blade", V(1.6, 7, 0.2) * SC, hub, V(0, 0, 0), RGB(245, 240, 230), M.Fabric, nil, rot * CFrame.new(0, 4 * SC, -0.3 * SC))
		CP(blades, "BladeBar", V(0.3, 8, 0.3) * SC, hub, V(0, 0, 0), RGB(110, 75, 50), M.Wood, nil, rot * CFrame.new(0, 4 * SC, -0.15 * SC))
	end
	finish(blades, hub, "spin", {Axis = Vector3.new(0, 0, 1), Speed = 0.9})
end

local function pinwheel(r, x, d, h)
	local stickBase = SCF(r, x, F, d).Position
	P(r.folder, "PinwheelStick", V(0.3, h, 0.3) * SC, CFrame.new(stickBase + V(0, h * SC / 2, 0)), RGB(250, 250, 250), M.SmoothPlastic, FX)
	local hub = CFrame.new(stickBase + V(0, h * SC, -0.3 * SC))
	local wheel = newThing(r, "Pinwheel")
	local cols = {RGB(255, 80, 80), RGB(255, 210, 40), RGB(80, 170, 255), RGB(90, 220, 110)}
	for k = 0, 3 do
		CP(wheel, "Vane", V(1.6, 1.6, 0.1) * SC, hub, V(0, 0, 0), cols[k + 1], M.SmoothPlastic, nil, CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0.8 * SC, 0.8 * SC, 0) * CFrame.Angles(0, 0, math.rad(45)))
	end
	CP(wheel, "Pin", V(0.5, 0.5, 0.5) * SC, hub, V(0, 0, -0.1 * SC), RGB(255, 255, 255), nil, "ball")
	finish(wheel, hub, "spin", {Axis = Vector3.new(0, 0, 1), Speed = 3 + math.random() * 2})
end

local function balloon(r, x, d, color)
	local p = SCF(r, x, F + 8 + math.random() * 6, d).Position
	local m = newThing(r, "Balloon")
	local rc = CFrame.new(p)
	CP(m, "Balloon", V(2.4, 3, 2.4) * SC, rc, V(0, 0, 0), color, nil, "ell").Reflectance = 0.15
	CP(m, "Knot", V(0.4, 0.4, 0.4) * SC, rc, V(0, -1.6 * SC, 0), color, nil, "ball")
	CP(m, "String", V(0.06, 4, 0.06) * SC, rc, V(0, -3.6 * SC, 0), RGB(255, 255, 255))
	finish(m, rc, "bob", {Speed = 1 + math.random(), Amp = 1.2, Phase = math.random() * 6})
end

local function bigLollipop(r, x, d, color)
	local base = SCF(r, x, F, d).Position
	P(r.folder, "LolliStick", V(0.5, 9, 0.5) * SC, CFrame.new(base + V(0, 4.5 * SC, 0)), RGB(250, 250, 250), M.SmoothPlastic, FX)
	local face = -math.sign(x)
	local hub = CFrame.lookAt(base + V(0, 11 * SC, 0), base + V(face * 10, 11 * SC, 0))
	local m = newThing(r, "SpinningLollipop")
	CP(m, "Candy", V(0.9, 6, 6) * SC, hub, V(0, 0, 0), color, nil, "cyl", CFrame.Angles(0, math.rad(90), 0))
	for k = 0, 3 do
		CP(m, "Swirl", V(0.6, 5.8, 0.95) * SC, hub, V(0, 0, -0.05 * SC), RGB(255, 255, 255), nil, nil, CFrame.Angles(0, 0, k * math.pi / 4))
	end
	finish(m, hub, "spin", {Axis = Vector3.new(0, 0, 1), Speed = 1.2})
end

local function bouncyBall(r, x, d, color, size)
	local rc = SCF(r, x, F + size / 2, d)
	local m = newThing(r, "BouncyBall")
	CP(m, "Ball", V(size, size, size) * SC, rc, V(0, 0, 0), color, nil, "ball")
	CP(m, "Stripe", V(size * 0.25, size * 1.01, size * 1.01) * SC, rc, V(0, 0, 0), RGB(255, 255, 255), nil, "cyl")
	finish(m, rc, "bounce", {Speed = 3, Amp = 6, Phase = math.random() * 3})
end

local function trainLoop(r, x, d)
	local center = SCF(r, x, F, d).Position
	local radius = 7 * SC
	-- the track: a ring of sleepers
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local p = center + V(math.cos(a) * radius, 0.15, math.sin(a) * radius)
		P(r.folder, "Sleeper", V(0.5, 0.2, 2.2) * SC, CFrame.lookAt(p, center) , RGB(130, 90, 60), M.WoodPlanks, FX)
	end
	local cols = {RGB(230, 50, 50), RGB(60, 140, 255), RGB(255, 200, 40)}
	for car = 0, 2 do
		local rc = CFrame.new(center + V(radius, 0, 0))
		local m = newThing(r, (car == 0) and "TrainEngine" or "TrainCar")
		local col = cols[car + 1]
		CP(m, "Body", V(1.8, 1.6, 2.6) * SC, rc, V(0, 1.4 * SC, 0), col)
		CP(m, "Roof", V(2, 0.3, 2.8) * SC, rc, V(0, 2.35 * SC, 0), RGB(40, 40, 50))
		if car == 0 then
			CP(m, "Chimney", V(0.7, 1.4, 0.7) * SC, rc, V(0, 3.0 * SC, -0.8 * SC), RGB(40, 40, 50), nil, "cyl", CFrame.Angles(0, 0, math.rad(90)))
			CP(m, "Lamp", V(0.5, 0.5, 0.2) * SC, rc, V(0, 1.6 * SC, -1.35 * SC), RGB(255, 240, 160), M.Neon)
		end
		for _, sx in ipairs({-1, 1}) do
			for _, dz in ipairs({-0.8, 0.8}) do
				CP(m, "Wheel", V(0.3, 0.9, 0.9) * SC, rc, V(sx * 0.95 * SC, 0.5 * SC, dz * SC), RGB(30, 30, 35), nil, "cyl")
			end
		end
		finish(m, rc, "orbit", {Center = CFrame.new(center), Radius = radius, Speed = -0.7, Phase = car * 0.42, Amp = 0})
	end
end

local function radarTower(r, x, d)
	local base = SCF(r, x, F, d).Position
	P(r.folder, "RadarTower", V(1.4, 12, 1.4) * SC, CFrame.new(base + V(0, 6 * SC, 0)), RGB(60, 65, 80), M.Metal, FX)
	local hub = CFrame.new(base + V(0, 12.4 * SC, 0))
	local m = newThing(r, "RadarDish")
	CP(m, "Dish", V(0.4, 5, 5) * SC, hub, V(0, 0.8 * SC, 0), RGB(220, 225, 235), M.Metal, "cyl", CFrame.Angles(0, 0, math.rad(60)))
	CP(m, "Feed", V(0.2, 0.2, 2) * SC, hub, V(0.8 * SC, 1.6 * SC, 0), RGB(80, 85, 100), M.Metal, nil, CFrame.Angles(0, math.rad(90), 0))
	CP(m, "Tip", V(0.5, 0.5, 0.5) * SC, hub, V(1.6 * SC, 2.1 * SC, 0), RGB(255, 60, 60), M.Neon, "ball"):SetAttribute("Blink", 0)
	finish(m, hub, "spin", {Axis = Vector3.new(0, 1, 0), Speed = 1.1})
end

local function iceCrystal(r, x, d, color)
	local rc = SCF(r, x, F + 4 + math.random() * 3, d)
	local m = newThing(r, "FloatingCrystal")
	CP(m, "Crystal", V(1.6, 4, 1.6) * SC, rc, V(0, 0, 0), color, M.Glass, nil, CFrame.Angles(0, math.rad(45), 0)).Transparency = 0.1
	CP(m, "Core", V(0.7, 2.4, 0.7) * SC, rc, V(0, 0, 0), color:Lerp(RGB(255, 255, 255), 0.4), M.Neon, nil, CFrame.Angles(0, math.rad(45), 0))
	CP(m, "TipTop", V(1.1, 1.1, 1.1) * SC, rc, V(0, 2.2 * SC, 0), color, M.Glass, nil, CFrame.Angles(math.rad(45), 0, math.rad(45)))
	CP(m, "TipBottom", V(1.1, 1.1, 1.1) * SC, rc, V(0, -2.2 * SC, 0), color, M.Glass, nil, CFrame.Angles(math.rad(45), 0, math.rad(45)))
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 16
	l.Brightness = 1.4
	l.Parent = m.PrimaryPart or m:FindFirstChild("Core")
	finish(m, rc, "hover", {Speed = 1.2 + math.random() * 0.6, Amp = 1.2, Phase = math.random() * 6})
end

local function planetOrbit(r, center, radius, size, color, speed, phase, ringed)
	local rc = CFrame.new(center + V(radius, 0, 0))
	local m = newThing(r, "OrbitPlanet")
	CP(m, "Planet", V(size, size, size), rc, V(0, 0, 0), color, nil, "ball")
	CP(m, "Band", V(size * 0.2, size * 1.01, size * 1.01), rc, V(0, size * 0.15, 0), color:Lerp(RGB(255, 255, 255), 0.3), nil, "cyl", CFrame.Angles(0, 0, math.rad(90)))
	if ringed then
		local ring = CP(m, "Ring", V(0.15, size * 1.9, size * 1.9), rc, V(0, 0, 0), RGB(255, 220, 160), M.Neon, "cyl", CFrame.Angles(math.rad(20), 0, math.rad(75)))
		ring.Transparency = 0.4
	end
	finish(m, rc, "orbit", {Center = CFrame.new(center), Radius = radius, Speed = speed, Phase = phase, Amp = 1.5})
end

local function hangingLantern(r, x, d, color)
	local top = SCF(r, x, F + 13, d).Position
	P(r.folder, "LanternPost", V(0.5, 13, 0.5) * SC, CFrame.new(top - V(0, 6.5 * SC, 0) + V(1.6 * SC, 0, 0)), RGB(40, 40, 50), M.Metal, FX)
	P(r.folder, "LanternArm", V(2, 0.4, 0.4) * SC, CFrame.new(top + V(0.8 * SC, 0, 0)), RGB(40, 40, 50), M.Metal, FX)
	local pivot = CFrame.new(top)
	local m = newThing(r, "SwingLantern")
	CP(m, "Chain", V(0.1, 2, 0.1) * SC, pivot, V(0, -1 * SC, 0), RGB(60, 60, 70), M.Metal)
	CP(m, "Cap", V(1.2, 0.3, 1.2) * SC, pivot, V(0, -2.1 * SC, 0), RGB(40, 40, 50), M.Metal)
	local glass = CP(m, "Glass", V(1, 1.3, 1) * SC, pivot, V(0, -2.9 * SC, 0), color, M.Neon)
	glass.Transparency = 0.15
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 26
	l.Brightness = 1.6
	l.Parent = glass
	finish(m, pivot, "sway", {Axis = Vector3.new(0, 0, 1), Speed = 1.4, Amp = 0.25, Phase = math.random() * 6})
end

local function fishJumps(r, x, d, color, phase)
	local base = SCF(r, x, F - 0.5, d)
	local rc = base * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local m = CRITTER.fish(r, rc, color)
	finish(m, rc, "leap", {Speed = 1.1, Amp = 6, Length = 9, Phase = phase})
end

------------------------------------------------------------------
-- what moves in each area
------------------------------------------------------------------
local ALIVE = {}
ALIVE[1] = function(r) -- graveyard: bats, a floating ghost, swinging lanterns
	for i = 1, 3 do flyer(r, "bat", Vector3.new(-HW * SC, 14, r.z0 - SL * SC + 8), Vector3.new(HW * SC, 24, r.z0 - 8), 11) end
	for _, side in ipairs({-1, 1}) do
		local mn, mx = stripBox(r, side, 10, 18)
		flyer(r, "bat", mn, mx, 9)
		orbiter(r, "ghost", SCF(r, side * (HW + 16), F, 25).Position, 8, 5, 0.5 * side, math.random() * 6)
		hangingLantern(r, side * (HW + 5), 10, RGB(255, 150, 60))
	end
end
ALIVE[2] = function(r) -- farm: a windmill, chickens, a cow, butterflies
	windmill(r, (r.index % 2 == 0) and (HW + 18) or -(HW + 18), 38)
	for _, side in ipairs({-1, 1}) do
		for i = 1, 3 do walker(r, "chicken", side, 4 + math.random() * 2, {Amp = 0.35}) end
		local mn, mx = stripBox(r, side, 3, 7)
		flyer(r, "butterfly", mn, mx, 5, ({RGB(255, 170, 60), RGB(120, 200, 255), RGB(255, 120, 200)})[math.random(1, 3)])
	end
	walker(r, "cow", (r.index % 2 == 0) and -1 or 1, 2.5, {Amp = 0.1})
end
ALIVE[3] = function(r) -- toy land: a toy train, pinwheels, bouncy balls, balloons
	trainLoop(r, -(HW + 16), 30)
	for k, d in ipairs({8, 20, 44}) do pinwheel(r, (k % 2 == 0) and (HW + 6) or -(HW + 6), d, 8 + k) end
	bouncyBall(r, HW + 18, 18, RGB(255, 80, 80), 4)
	bouncyBall(r, HW + 24, 40, RGB(80, 170, 255), 3)
	for i = 1, 3 do balloon(r, (i % 2 == 0) and (HW + 10 + i * 4) or -(HW + 10 + i * 4), 10 + i * 10, ({RGB(255, 90, 90), RGB(255, 220, 60), RGB(90, 200, 255)})[i]) end
end
ALIVE[4] = function(r) -- candy land: giant spinning lollipops, balloons, hopping gumdrop blobs
	bigLollipop(r, HW + 10, 12, RGB(255, 90, 160))
	bigLollipop(r, -(HW + 10), 30, RGB(110, 220, 255))
	bigLollipop(r, HW + 14, 44, RGB(255, 220, 60))
	for i = 1, 5 do balloon(r, ((i % 2 == 0) and 1 or -1) * (HW + 8 + i * 3), 6 + i * 8, ({RGB(255, 150, 200), RGB(150, 230, 255), RGB(255, 230, 120), RGB(180, 255, 160), RGB(220, 170, 255)})[i]) end
	for _, side in ipairs({-1, 1}) do
		for i = 1, 2 do walker(r, "blob", side, 4, {Amp = 0.9}) end
	end
end
ALIVE[5] = function(r) -- beach: seagulls, jumping fish, floating barrels
	for _, side in ipairs({-1, 1}) do
		local mn, mx = stripBox(r, side, 16, 26)
		flyer(r, "seagull", mn, mx, 13)
	end
	flyer(r, "seagull", Vector3.new(-HW * SC, 20, r.z0 - SL * SC + 8), Vector3.new(HW * SC, 30, r.z0 - 8), 14)
	-- fish jumping out of the lagoon in the lane
	for k = 1, 3 do fishJumps(r, 22 + k * 2, 28 + k * 6, ({RGB(255, 140, 40), RGB(80, 200, 255), RGB(255, 220, 60)})[k], k * 2.1) end
	for _, side in ipairs({-1, 1}) do
		for k = 1, 2 do
			local rc = SCF(r, side * (HW + BW + 8 + k * 6), F - 0.6, 12 + k * 18)
			local m = newThing(r, "FloatingBarrel")
			CP(m, "Barrel", V(2.4, 1.8, 1.8) * SC, rc, V(0, 0, 0), RGB(140, 95, 55), M.WoodPlanks, "cyl")
			for _, bx in ipairs({-0.7, 0.7}) do CP(m, "Hoop", V(0.2, 1.9, 1.9) * SC, rc, V(bx * SC, 0, 0), RGB(60, 60, 70), M.Metal, "cyl") end
			finish(m, rc, "sway", {Axis = Vector3.new(1, 0, 0.3).Unit, Speed = 1.3, Amp = 0.25, Phase = k * 1.7})
		end
	end
end
ALIVE[6] = function(r) -- jungle: pterodactyls circling, baby dinos
	local mid = SCF(r, 0, F, SL / 2).Position
	orbiter(r, "ptero", mid, 34, 26, 0.35, 0)
	orbiter(r, "ptero", mid, 46, 32, -0.28, 2.5)
	for _, side in ipairs({-1, 1}) do
		walker(r, "dino", side, 3.5, {Amp = 0.15})
		local mn, mx = stripBox(r, side, 4, 8)
		flyer(r, "butterfly", mn, mx, 5, RGB(120, 255, 120))
	end
end
ALIVE[7] = function(r) -- ice field: waddling penguins, floating crystals
	for _, side in ipairs({-1, 1}) do
		for i = 1, 3 do walker(r, "penguin", side, 2.5, {Amp = 0.12, Waddle = 0.22}) end
		iceCrystal(r, side * (HW + 12), 14, RGB(140, 210, 255))
		iceCrystal(r, side * (HW + 20), 36, RGB(180, 160, 255))
	end
end
ALIVE[8] = function(r) -- cyber city: security drones, a rotating radar
	for i = 1, 3 do flyer(r, "drone", Vector3.new(-HW * SC * 0.8, 12, r.z0 - SL * SC + 8), Vector3.new(HW * SC * 0.8, 20, r.z0 - 8), 10) end
	for _, side in ipairs({-1, 1}) do
		local mn, mx = stripBox(r, side, 10, 20)
		flyer(r, "drone", mn, mx, 8)
	end
	radarTower(r, (r.index % 2 == 0) and -(HW + 14) or (HW + 14), 40)
end
ALIVE[9] = function(r) -- alien planet: little UFOs and alien blobs
	for i = 1, 2 do flyer(r, "ufo", Vector3.new(-HW * SC * 0.7, 20, r.z0 - SL * SC + 10), Vector3.new(HW * SC * 0.7, 30, r.z0 - 10), 9) end
	for _, side in ipairs({-1, 1}) do
		local mn, mx = stripBox(r, side, 16, 26)
		flyer(r, "ufo", mn, mx, 7)
		for i = 1, 2 do walker(r, "blob", side, 3.5, {Amp = 0.8}) end
	end
end
ALIVE[10] = function(r) -- space: planets orbiting, floating crystals
	local center = SCF(r, 0, 15, 47).Position -- the black hole (see THEMES[10])
	planetOrbit(r, center, 22, 4, RGB(255, 140, 60), 0.35, 0, true)
	planetOrbit(r, center, 30, 3, RGB(80, 170, 255), -0.25, 2, false)
	planetOrbit(r, center, 38, 2.4, RGB(150, 255, 160), 0.18, 4, false)
	for _, side in ipairs({-1, 1}) do
		iceCrystal(r, side * (HW + 10), 12, RGB(200, 110, 255))
		iceCrystal(r, side * (HW + 22), 30, RGB(255, 90, 210))
	end
end

-- things that already exist in an area but should move too
local function bringToLife(r)
	for _, p in ipairs(r.folder:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "ZoneTitle" then animate(p, "bob", {Speed = 1.1, Amp = 0.8})
			elseif p.Name == "HoloRing" or p.Name == "BlackHoleRing" or p.Name == "PlanetRing" then animate(p, "spin", {Axis = Vector3.new(0, 1, 0), Speed = 0.8})
			elseif p.Name == "Hologram" then animate(p, "pulse", {Speed = 3, Amp = 0.3})
			elseif p.Name == "TractorBeam" then animate(p, "pulse", {Speed = 2, Amp = 0.18})
			elseif p.Name == "GateBand" or p.Name == "LaneCurbGlow" then animate(p, "pulse", {Speed = 2.5, Amp = 0.35, Phase = r.index})
			elseif p.Name == "CrystalTip" and math.random() < 0.5 then animate(p, "pulse", {Speed = 1.5 + math.random(), Amp = 0.3, Phase = math.random() * 6})
			elseif p.Name == "FloatRock" then animate(p, "hover", {Speed = 0.6 + math.random() * 0.4, Amp = 1.4, Phase = math.random() * 6})
			elseif p.Name == "Planet" or p.Name == "Planet2" or p.Name == "Moon" then animate(p, "bob", {Speed = 0.7, Amp = 1.2, Phase = math.random() * 6})
			end
		end
	end
	-- the pirate ship rocks on the waves (it doesn't block you while it moves)
	if r.index == 5 then
		local ship = newThing(r, "PirateShip")
		local pivot = nil
		for _, p in ipairs(r.folder:GetChildren()) do
			if p:IsA("BasePart") and (p.Name == "Hull" or p.Name == "Deck" or p.Name == "Bow" or p.Name == "Mast" or p.Name == "Sail" or p.Name == "SailSkull" or p.Name == "Flag") then
				p.CanCollide = false
				p.Parent = ship
				if p.Name == "Hull" then pivot = p.CFrame - Vector3.new(0, p.Size.Y / 2, 0) end
			end
		end
		if pivot then finish(ship, pivot, "sway", {Axis = Vector3.new(0, 0, 1), Speed = 0.9, Amp = 0.07}) end
	end
end

------------------------------------------------------------------
-- BUILD THE 10 AREAS
------------------------------------------------------------------
local SHELF_D = {6, 20}    -- shelves run from d=6 to d=20 on both walls
local LEVELS = {0.6, 5.6, 10.6}

local function buildShelf(r, side, st, d1, d2, spots)
	local x = side * (HW - 3)
	local len = d2 - d1
	local dMid = (d1 + d2) / 2
	local SHELF_D = {d1, d2}
	D(r, "ShelfBack", V(0.4, 12, len), side * (HW - 0.8), F + 6, dMid, st.shelf:Lerp(RGB(0, 0, 0), 0.25), st.shelfMat)
	for _, y in ipairs(LEVELS) do
		D(r, "ShelfBoard", V(4.4, 0.4, len), x, F + y, dMid, st.shelf, st.shelfMat)
		D(r, "ShelfEdge", V(0.2, 0.5, len), x - side * 2.2, F + y + 0.1, dMid, st.post, (st.post.R + st.post.G + st.post.B > 2.2) and M.SmoothPlastic or M.Neon, FX)
	end
	for _, d in ipairs({SHELF_D[1], dMid, SHELF_D[2]}) do
		for _, ox in ipairs({-2.1, 2.1}) do
			D(r, "ShelfPost", V(0.4, 12.4, 0.4), x + ox, F + 6.2, d, st.post, M.SmoothPlastic)
		end
	end
	-- diagonal cross braces on the back + label strips
	for _, sgn in ipairs({-1, 1}) do
		D(r, "Brace", V(0.25, math.sqrt(len * len + 100), 0.25), side * (HW - 1.1), F + 6, dMid, st.post, M.SmoothPlastic, nil, CFrame.Angles(math.atan2(len, 10) * sgn, 0, 0))
	end
	for _, y in ipairs(LEVELS) do
		D(r, "Label", V(0.1, 0.35, len * 0.6), x - side * 2.32, F + y + 0.1, dMid, RGB(250, 250, 250), M.SmoothPlastic, FX)
	end
	-- box spawns on this shelf
	for _, sp in ipairs(spots) do
		local p = D(r, "Spawn", V(2, 0.2, 2), x, F + LEVELS[sp[1]] + 0.2, sp[2], RGB(255, 255, 0), nil, GHOST)
		p:SetAttribute("Area", r.index)
		p:SetAttribute("Shelf", true)
		p.Parent = spawns
	end
end

-- each room has its own mood: lamp colour, brightness, reach (dusty = dim, toy factory = bright, galaxy = dark)
local MOOD = {
	{RGB(255, 200, 140), 0.7, 26},  -- Dusty Storage: dim, old bulbs
	{RGB(255, 210, 150), 0.9, 30},  -- Farm Barn: warm lanterns
	{RGB(255, 250, 235), 1.3, 34},  -- Toy Factory: bright
	{RGB(255, 190, 230), 1.1, 32},  -- Candy Shop: pink glow
	{RGB(150, 200, 255), 0.75, 28}, -- Pirate Cove: under-water blue
	{RGB(255, 225, 170), 1.0, 30},  -- Dino Museum: museum spotlights
	{RGB(190, 235, 255), 1.0, 32},  -- Frozen Lab: cold light
	{RGB(120, 220, 255), 0.85, 28}, -- Tech Lab: cyan
	{RGB(140, 255, 140), 0.7, 26},  -- Alien Hangar: eerie green
	{RGB(190, 130, 255), 0.6, 24},  -- Galaxy Vault: dark purple
}

------------------------------------------------------------------
-- THE CEILING: a roof over the lane of every area - beams, a glowing strip down the middle,
-- neon trims and swinging lamps (+ a starry ceiling in the Galaxy Vault). It sits high up
-- (above everything that flies around) and the sides stay open, so you still see the islands.
------------------------------------------------------------------
local CEIL_MAT = {M.WoodPlanks, M.WoodPlanks, M.SmoothPlastic, M.SmoothPlastic, M.WoodPlanks, M.Marble, M.Ice, M.DiamondPlate, M.Metal, M.SmoothPlastic}
local function buildCeiling(r, st, acc)
	local idx = r.index
	local mood = MOOD[idx] or MOOD[1]
	local roofCol = st.wallA:Lerp(RGB(0, 0, 0), 0.3)
	local beamCol = st.shelf:Lerp(RGB(0, 0, 0), 0.15)
	D(r, "Ceiling", V(HW * 2 + 6, 1.2, SL + 0.2), 0, WH + 0.6, SL / 2, roofCol, CEIL_MAT[idx] or M.SmoothPlastic)
	for k = 0, 5 do
		D(r, "CeilingBeam", V(HW * 2 + 6, 1.4, 1.4), 0, WH - 0.3, 4 + k * 8.4, beamCol, st.shelfMat, FX)
	end
	for _, side in ipairs({-1, 1}) do
		D(r, "CeilingSideBeam", V(1.8, 2, SL + 0.2), side * (HW + 0.6), WH - 0.5, SL / 2, beamCol, st.shelfMat, FX)
		D(r, "CeilingTrim", V(0.4, 0.4, SL), side * (HW - 0.4), WH - 1.4, SL / 2, acc, M.Neon, FX)
	end
	-- a glowing strip down the middle (it breathes slowly)
	local glow = D(r, "CeilingGlow", V(5, 0.25, SL - 6), 0, WH - 0.05, SL / 2, acc:Lerp(RGB(255, 255, 255), 0.4), M.Neon, FX)
	glow.Transparency = 0.15
	animate(glow, "pulse", {Speed = 1.2, Amp = 0.25, Phase = idx})
	for k = 0, 2 do
		local lp = D(r, "CeilingLight", V(1, 1, 1), 0, WH - 1, 8 + k * 17, RGB(0, 0, 0), nil, GHOST)
		light(lp, mood[1], mood[3] + 14, mood[2] + 0.4)
	end
	-- swinging lamps hanging from the beams
	for _, pos in ipairs({{-20, 12.4}, {20, 12.4}, {-20, 37.6}, {20, 37.6}}) do
		local top = SCF(r, pos[1], WH - 1, pos[2])
		local m = newThing(r, "HangingLamp")
		CP(m, "Chain", V(0.15, 4, 0.15) * SC, top, V(0, -2 * SC, 0), RGB(50, 50, 60), M.Metal)
		CP(m, "Shade", V(1.2, 3, 3) * SC, top, V(0, -4.4 * SC, 0), beamCol, M.SmoothPlastic, "cyl", CFrame.Angles(0, 0, math.rad(90)))
		local bulb = CP(m, "Bulb", V(1.4, 1.4, 1.4) * SC, top, V(0, -5.3 * SC, 0), mood[1], M.Neon, "ball")
		local l = Instance.new("PointLight")
		l.Color = mood[1]
		l.Range = 26
		l.Brightness = 1.2
		l.Parent = bulb
		finish(m, top, "sway", {Axis = Vector3.new(1, 0, 0.5).Unit, Speed = 0.9 + math.random() * 0.4, Amp = 0.08, Phase = math.random() * 6})
	end
	-- the galaxy vault gets a starry ceiling that twinkles
	if idx == #Config.Areas then
		for k = 1, 28 do
			local star = ball(r, "CeilingStar", 0.4 + math.random() * 0.4, -HW + math.random() * HW * 2, WH - 0.1, 2 + math.random() * (SL - 4), RGB(255, 255, 255), M.Neon, FX)
			animate(star, "pulse", {Speed = 1 + math.random() * 2, Amp = 0.7, Phase = math.random() * 6})
		end
	end
end

for areaIndex, area in ipairs(Config.Areas) do
	local r = {index = areaIndex, z0 = Config.AreaStartZ(areaIndex), folder = Instance.new("Model")}
	r.folder.Name = "Area" .. areaIndex .. "_" .. area.name:gsub(" ", "")
	r.folder.Parent = wh
	local st = STYLE[areaIndex]
	local acc = area.accent
	local bio = BIOMES[areaIndex]

	-- floor (studded, like the classic Roblox look) + accent border
	local floor = D(r, "Floor", V(HW * 2, 0.4, SL), 0, 0.3, SL / 2, bio.lane, M.SmoothPlastic)
	floor.TopSurface = Enum.SurfaceType.Studs
	-- glowing line where this area starts
	D(r, "AreaLine", V(HW * 2, 0.06, 1.6), 0, F + 0.03, 0.8, acc, M.Neon, FX)
	D(r, "AreaLineCore", V(HW * 2, 0.08, 0.5), 0, F + 0.05, 0.8, RGB(255, 255, 255), M.Neon, FX)
	-- solid walls on both sides, with a coloured band in the area's colour
	for _, side in ipairs({-1, 1}) do
		D(r, "Wall", V(2, WH, SL), side * (HW + 1), WH / 2, SL / 2, st.wallA, M.SmoothPlastic)
		D(r, "WallBase", V(0.4, 4, SL), side * (HW - 0.1), F + 2, SL / 2, st.wallA:Lerp(RGB(0, 0, 0), 0.3), M.SmoothPlastic, FX)
		D(r, "WallBand", V(0.4, 1.2, SL), side * (HW - 0.1), F + 9, SL / 2, acc, M.Neon, FX)
		-- a low glowing curb shows where the lane ends
		D(r, "LaneCurb", V(1.2, 0.8, SL), side * (HW - 0.2), F + 0.4, SL / 2, bio.ground:Lerp(RGB(255, 255, 255), 0.5), M.SmoothPlastic)
		D(r, "LaneCurbGlow", V(1.25, 0.15, SL), side * (HW - 0.2), F + 0.85, SL / 2, acc, M.Neon, FX)
		for _, d in ipairs({25, 47}) do
			local x = side * (HW - 4)
			D(r, "LampPost", V(0.6, 10, 0.6), x, F + 5, d, RGB(40, 42, 55), M.Metal)
			D(r, "LampArm", V(2.6, 0.4, 0.4), x - side * 1.1, F + 10, d, RGB(40, 42, 55), M.Metal)
			local mood = MOOD[areaIndex]
			local bulb = ball(r, "LampBulb", 1.4, x - side * 2.2, F + 9.4, d, mood[1], M.Neon, FX)
			light(bulb, mood[1], mood[3] + 6, mood[2] + 0.4)
		end
	end

	-- glowing gate posts + the floating zone name
	for _, side in ipairs({-1, 1}) do
		local pil = D(r, "GatePost", V(3, 12, 3), side * (HW - 1.5), F + 6, 0, acc:Lerp(RGB(30, 30, 40), 0.35), M.SmoothPlastic)
		D(r, "GateGlow", V(3.2, 0.5, 3.2), side * (HW - 1.5), F + 0.3, 0, acc, M.Neon, FX)
		D(r, "GateBand", V(3.2, 0.6, 3.2), side * (HW - 1.5), F + 8, 0, acc, M.Neon, FX)
		shard(r, side * (HW - 1.5), F + 12, 0, 2.2, 3.5, acc, 0, 45, M.Neon)
		light(pil, acc, 18, 1)
	end
	-- (no floating area title in the sky any more: it piled up with the other areas' titles;
	--  the area banner on your screen shows where you are)
	-- recommended speed sign (like the video!)
	local rec = D(r, "SpeedSign", V(7, 3.2, 0.4), -26, F + 4, 1.2, RGB(150, 95, 50), M.WoodPlanks)
	D(r, "SpeedSignPost", V(0.5, 3, 0.5), -26, F + 1.5, 1.2, RGB(110, 70, 40), M.WoodPlanks)
	surfaceText(rec, Enum.NormalId.Back, (areaIndex > 1) and (Config.FormatNum(Config.RecommendedPoints(areaIndex)) .. " SPEED\nrecommended") or "START HERE!", RGB(255, 60, 40))

	-- shelves with boxes on both walls
	buildShelf(r, -1, st, 6, 20, {{1, 9}, {1, 17}, {2, 13}})
	buildShelf(r, 1, st, 6, 20, {{1, 9}, {1, 17}, {2, 13}})
	buildShelf(r, -1, st, 30, 42, {{1, 33}, {1, 39}})
	buildShelf(r, 1, st, 30, 42, {{1, 33}, {1, 39}})
	-- the areas are longer now: one more pair of shelves at the back
	buildShelf(r, -1, st, 54, 66, {{1, 57}, {2, 63}})
	buildShelf(r, 1, st, 54, 66, {{1, 57}, {2, 63}})

	-- 2 pallets in the open for the big ones (Huge / Giant boxes can only spawn here)
	for _, x in ipairs({-12, 12}) do
		for k = -1, 1 do
			D(r, "PalletBlock", V(6, 0.35, 0.8), x, F + 0.18, 30 + k * 2.4, RGB(140, 100, 60), M.WoodPlanks)
		end
		for k = -2, 2 do
			D(r, "PalletSlat", V(1, 0.25, 6), x + k * 1.25, F + 0.48, 30, RGB(185, 140, 85), M.WoodPlanks)
		end
		local p = D(r, "Spawn", V(2, 0.2, 2), x, F + 0.62, 30, RGB(255, 255, 0), nil, GHOST)
		p:SetAttribute("Area", areaIndex)
		p.Parent = spawns
	end

	-- theme decorations + effects
	THEMES[areaIndex](r)
	-- the lane has a roof again: the hanging bulbs, lanterns, cobwebs and spotlights are back.
	-- Only things that were stuck on the (now invisible) side walls are removed.
	-- the roof over the lane
	buildCeiling(r, st, acc)
	-- critters + moving set pieces (animated by the clients)
	bringToLife(r)

	-- the guardian sleeps at the back, facing the entrance
	makeGuardian(areaIndex, SCF(r, 0, 0, SL * 0.45).Position, acc)
end




------------------------------------------------------------------
-- BIKE OBBY: a floating course far behind the lobby (the phone on your base takes you here).
-- Walls to crash into, ramps, gaps, a narrow bridge and a gold finish pad.
------------------------------------------------------------------
do
	local ob = folder(root, "BikeObby")
	local TRACK, EDGE = RGB(70, 80, 110), RGB(255, 210, 60)
	local function floor(size, pos, color, tilt)
		local cf = CFrame.new(pos) * CFrame.Angles(math.rad(tilt or 0), 0, 0)
		P(ob, "Floor", size, cf, color or TRACK)
		-- yellow edges so you can see where the track ends
		for _, sx in ipairs({-1, 1}) do
			P(ob, "Edge", V(0.6, 0.3, size.Z), cf * CFrame.new(sx * (size.X / 2 - 0.3), size.Y / 2 + 0.15, 0), EDGE, M.Neon, NOHIT)
		end
	end
	local function wallBlock(x, y, z, w, color)
		P(ob, "Wall", V(w or 10, 8, 2), C(x, y, z), color, M.SmoothPlastic)
	end
	floor(V(40, 2, 40), V(0, 49, 470), RGB(90, 100, 140))                       -- start pad
	P(ob, "BikeStart", V(2, 0.2, 2), C(0, 51, 462), RGB(0, 0, 0), nil, GHOST)
	local sign = P(ob, "ObbySign", V(30, 6, 1), C(0, 64, 486), RGB(230, 50, 60), nil, NOHIT)
	signText(sign, Enum.NormalId.Back, "BIKE OBBY", 20, 4, 300)
	floor(V(24, 2, 110), V(0, 49, 545))                                           -- straight with walls
	for k, x in ipairs({-7, 7, -7, 7}) do wallBlock(x, 54, 515 + (k - 1) * 25, 10, ({RGB(255, 90, 90), RGB(90, 170, 255), RGB(255, 200, 60), RGB(120, 230, 90)})[k]) end
	floor(V(24, 2, 32), V(0, 54.4, 615), nil, -18.4)                              -- ramp up
	floor(V(24, 2, 60), V(0, 55, 670))                                            -- landing (after a gap)
	floor(V(8, 2, 60), V(0, 55, 730))                                             -- narrow bridge
	floor(V(24, 2, 50), V(0, 55, 785))                                            -- bumpers
	wallBlock(-5, 60, 775, 14, RGB(255, 140, 40))
	wallBlock(5, 60, 797, 14, RGB(200, 100, 255))
	floor(V(24, 2, 30), V(0, 60.4, 824), nil, -19.6)                              -- final ramp
	floor(V(40, 2, 40), V(0, 61, 870), RGB(255, 200, 40))                        -- finish pad
	P(ob, "BikeFinish", V(2, 0.2, 2), C(0, 63, 870), RGB(0, 0, 0), nil, GHOST)
	local fin = P(ob, "FinishSign", V(30, 6, 1), C(0, 74, 888), RGB(40, 180, 60), nil, NOHIT)
	signText(fin, Enum.NormalId.Back, "FINISH!", 20, 4, 300)
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

	-- the tiled shop floor you click to place boxes on (a checker in the base's colour)
	local floor = PP("PlotFloor", V(CW, 0.4, CD), 0, 0.2, CD / 2, col:Lerp(WHITE, 0.85))
	floor:SetAttribute("Placeable", true)
	local TILE_N = 8
	local ts = CW / TILE_N
	for i = 0, TILE_N - 1 do
		for j = 0, TILE_N - 1 do
			if (i + j) % 2 == 0 then
				PP("FloorTile", V(ts, 0.06, ts), -HU + ts * (i + 0.5), 0.43, ts * (j + 0.5), col:Lerp(WHITE, 0.55), nil, NOHIT)
			end
		end
	end
	-- real shop walls on the sides and at the back (white, a coloured band, a glowing light strip on top)
	local WALL_COL = RGB(248, 246, 240)
	local function wall(u0, w0, u1, w1, lamp)
		local a, b = W(u0, 0, w0).Position, W(u1, 0, w1).Position
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 1.2
		local cf = CFrame.lookAt(mid, mid + (b - a).Unit)
		P(m, "Wall", V(1.2, 16, len), cf + V(0, 8, 0), WALL_COL)
		P(m, "WallBand", V(1.4, 4, len), cf + V(0, 2, 0), col, nil, NOHIT)
		P(m, "WallTrim", V(1.6, 0.8, len + 0.4), cf + V(0, 16.2, 0), col, nil, NOHIT)
		local strip = P(m, "WallLight", V(1.7, 0.5, len - 2), cf + V(0, 14.6, 0), RGB(255, 250, 235), M.Neon, NOHIT)
		if lamp then
			local l = Instance.new("PointLight")
			l.Color = RGB(255, 244, 220)
			l.Range = 48
			l.Brightness = 0.9
			l.Shadows = false
			l.Parent = strip
		end
	end
	wall(-HU, 0, -HU, CD, true)
	wall(HU, 0, HU, CD, true)
	wall(-HU, CD, HU, CD, false)
	-- a low wooden fence at the front (open in the middle for the door)
	local function fence(u0, w0, u1, w1)
		local a, b = W(u0, 0, w0).Position, W(u1, 0, w1).Position
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 1.2
		local cf = CFrame.lookAt(mid, mid + (b - a).Unit)
		local WOOD, WOOD_DARK = RGB(165, 105, 55), RGB(120, 75, 40)
		P(m, "FenceRail", V(0.5, 0.6, len), cf + V(0, 1.4, 0), WOOD, M.Wood, NOHIT)
		P(m, "FenceRail", V(0.5, 0.6, len), cf + V(0, 2.8, 0), WOOD, M.Wood, NOHIT)
		local posts = math.max(1, math.floor(len / 12))
		for k = 0, posts do
			local pos = a:Lerp(b, k / posts)
			P(m, "FencePost", V(0.9, 3.6, 0.9), CFrame.new(pos + V(0, 1.8, 0)), WOOD_DARK, M.Wood, NOHIT)
		end
	end
	fence(-HU, 0, -12, 0)
	fence(12, 0, HU, 0)

	-- THE BIG PHONE (front left corner): walk up and press E to play mini games on it
	do
		local u, w = -34, 9
		PP("PhoneStand", V(7, 1, 4), u, 0.9, w, RGB(60, 60, 70)):SetAttribute("Solid", true)
		PP("PhoneBody", V(9, 16, 1.2), u, 9.4, w, RGB(25, 25, 32)):SetAttribute("Solid", true)
		local screen = PP("PhoneScreen", V(8, 14, 0.2), u, 9.6, w + 0.62, RGB(60, 150, 255), M.Neon, NOHIT)
		PP("PhoneCamera", V(0.8, 0.8, 0.2), u, 17, w + 0.62, RGB(10, 10, 14), nil, NOHIT)
		signText(screen, Enum.NormalId.Front, "GAMES\nPress E", 30, 3, 120)
		prompt(screen, "PlayPhone", "Play", "Phone Games", 0)
	end
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
