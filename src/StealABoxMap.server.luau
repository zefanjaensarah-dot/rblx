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
--   z 0..44    : the square in front of the warehouse: leaderboards + Trails Shop
--   z 44..332  : the street with the 6 bases (3 on each side), spawn at the far end
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

-- a sunny afternoon with soft shadows; inside the warehouse the skylights and high-bay lamps light it
do
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = RGB(150, 152, 160)
	Lighting.OutdoorAmbient = RGB(165, 168, 178)
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.ShadowSoftness = 0.3
		Lighting.EnvironmentDiffuseScale = 0.6
		Lighting.EnvironmentSpecularScale = 0.5
	end)
	for _, e in ipairs(Lighting:GetChildren()) do
		if e.Name == "StealABoxFX" or e:IsA("Atmosphere") or e:IsA("Sky") then e:Destroy() end
	end
	pcall(function() -- no clouds from older versions of the map
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then clouds:Destroy() end
	end)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StealABoxFX"
	cc.Saturation = 0.18
	cc.Contrast = 0.1
	cc.TintColor = RGB(255, 252, 245)
	cc.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.14
	atm.Offset = 0.2
	atm.Color = RGB(205, 228, 255)
	atm.Decay = RGB(120, 170, 235)
	atm.Glare = 0
	atm.Haze = 0.6
	atm.Parent = Lighting
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
	local GRASS, SW = RGB(95, 215, 60), 16
	local grass = folder(root, "Grass")
	for _, sx in ipairs({-1, 1}) do
		P(grass, "Tile", V(MAPW - SW, 0.2, COURT_LEN + 2), C(sx * (MAPW + SW) / 2, 0.1, COURT_LEN / 2 - 1), GRASS).TopSurface = Enum.SurfaceType.Studs
	end
	-- the street from the spawn to the store door
	local streetEnd = COURT_LEN
	P(root, "Street", V(SW * 2, 0.3, streetEnd), C(0, 0.15, streetEnd / 2), RGB(52, 54, 62))
	for _, x in ipairs({-0.6, 0.6}) do -- the double yellow line
		P(root, "LaneLine", V(0.5, 0.04, COURT_LEN), C(x, 0.32, COURT_LEN / 2), RGB(255, 210, 40), nil, NOHIT)
	end
	for _, sx in ipairs({-1, 1}) do
		P(root, "EdgeLine", V(0.5, 0.04, COURT_LEN), C(sx * (SW - 3), 0.32, COURT_LEN / 2), RGB(245, 245, 245), nil, NOHIT)
		P(root, "Curb", V(2, 0.8, COURT_LEN), C(sx * (SW - 1), 0.4, COURT_LEN / 2), RGB(205, 205, 212), nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
	end
	-- red brick walls all around (they meet the store front at z -4)
	local BRICK, CAP = RGB(186, 88, 66), RGB(240, 222, 196)
	-- chunky brown checker dirt walls with grass on top (an invisible wall keeps everyone in)
	local DIRT1, DIRT2, LIP = RGB(195, 125, 72), RGB(168, 104, 60), RGB(95, 215, 60)
	local DH = 7 -- each checker block is 8 long and 7 tall, 2 rows
	local function dirt(name, size, cf, k)
		P(root, name, size, cf, (k % 2 == 0) and DIRT1 or DIRT2, nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
	end
	for _, sx in ipairs({-1, 1}) do
		P(root, "CourtWall", V(4, 60, COURT_LEN + 8), C(sx * (MAPW + 2), 30, COURT_LEN / 2), BRICK, nil, {Transparency = 1})
		for k = 0, math.ceil((COURT_LEN + 8) / 8) - 1 do
			for row = 0, 1 do
				dirt("DirtWall", V(6, DH, 8), C(sx * (MAPW + 3), DH * (row + 0.5), -4 + k * 8 + 4), k + row)
			end
		end
		P(root, "GrassLip", V(7, 1.2, COURT_LEN + 8), C(sx * (MAPW + 3), DH * 2 + 0.6, COURT_LEN / 2), LIP, nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
	end
	P(root, "BackWall", V(MAPW * 2 + 8, 60, 4), C(0, 30, COURT_LEN + 2), BRICK, nil, {Transparency = 1})
	for k = 0, math.ceil((MAPW * 2) / 8) - 1 do
		for row = 0, 1 do
			dirt("DirtWall", V(8, DH, 6), C(-MAPW + k * 8 + 4, DH * (row + 0.5), COURT_LEN + 3), k + row)
		end
	end
	P(root, "GrassLip", V(MAPW * 2 + 12, 1.2, 7), C(0, DH * 2 + 0.6, COURT_LEN + 3), LIP, nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
	-- the "Warehouse" teleport lands here, right in front of the store door
	P(root, "EntrancePoint", V(2, 0.2, 2), C(0, 0.5, 10), RGB(0, 0, 0), nil, GHOST)
	-- the tutorial points here (inside the door) while you're still outside
	P(root, "TutorialDoorPoint", V(2, 0.2, 2), C(0, 0.5, FRONT_Z - 20), RGB(0, 0, 0), nil, GHOST)
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
-- LEADERBOARDS: two big boards standing at the back of the lobby (behind the spawn), facing the
-- street. (Trails are bought on the UPGRADES board on your own plot.)
------------------------------------------------------------------
do
	local lobby = folder(root, "Lobby")
	local function leaderboard(name, base, title, color)
		-- base: where the board stands; its front (-Z) faces the players
		local function B(x, y, d) return base * CFrame.new(x, y, -d) end
		P(lobby, name, V(24, 30, 1), B(0, 19, 0), RGB(28, 32, 50))
		local glow = color:Lerp(WHITE, 0.35)
		-- two chunky posts behind it, a coloured frame with a glowing inner edge
		for _, sx in ipairs({-1, 1}) do
			P(lobby, "BoardPost", V(2, 36, 2), B(sx * 9, 18, -1.6), RGB(128, 80, 44)).TopSurface = Enum.SurfaceType.Studs
			P(lobby, "BoardFrame", V(1.8, 33.4, 1.8), B(sx * 12.9, 19, 0.1), color)
			P(lobby, "BoardGlow", V(0.4, 30, 0.3), B(sx * 11.9, 19, 0.55), glow, M.Neon, NOHIT)
		end
		P(lobby, "BoardFrame", V(27.6, 1.8, 1.8), B(0, 3.1, 0.1), color)
		P(lobby, "BoardGlow", V(23.6, 0.4, 0.3), B(0, 4.1, 0.55), glow, M.Neon, NOHIT)
		-- the title ribbon on top, with pointed ends
		local banner = P(lobby, "BoardBanner", V(24, 6, 1.4), B(0, 38.4, 0.9), color)
		local tip = color:Lerp(RGB(0, 0, 0), 0.2)
		for _, ex in ipairs({-12, 12}) do
			P(lobby, "BannerTip", V(4.2, 4.2, 1.2), B(ex, 38.4, 0.8) * CFrame.Angles(0, 0, math.rad(45)), tip)
		end
		P(lobby, "BannerTip", V(3, 3, 1.2), B(0, 35.4, 0.8) * CFrame.Angles(0, 0, math.rad(45)), color)
		signText(banner, Enum.NormalId.Front, title, 30, 5, 300)
		local star = P(lobby, "BoardStar", V(1.2, 4.4, 4.4), B(0, 43.2, 0.9) * CFrame.Angles(0, math.rad(90), 0), RGB(255, 210, 50), M.SmoothPlastic, NOHIT)
		star.Shape = Enum.PartType.Cylinder
		P(lobby, "BoardStage", V(30, 1.2, 8), B(0, 0.6, 4), color:Lerp(WHITE, 0.6)).TopSurface = Enum.SurfaceType.Studs
		P(lobby, "BoardStageEdge", V(30.4, 0.3, 0.4), B(0, 1.3, 8), glow, M.Neon, NOHIT)
	end
	-- (no rotation: the front of each board looks down -Z, back up the street)
	leaderboard("BoardTopMoney", CFrame.new(-42, 0, COURT_LEN - 9), "Top Money", RGB(80, 200, 60))
	leaderboard("BoardTopSpeed", CFrame.new(42, 0, COURT_LEN - 9), "Top Speed", RGB(60, 135, 255))
	-- the HALL OF FAME in the middle: only the people an admin puts there (admin panel)
	leaderboard("BoardFeatured", CFrame.new(0, 0, COURT_LEN - 9), "Hall of Fame", RGB(255, 170, 30))
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
	local W = MAPW + 4
	local OZ = FZ + 1 -- the outside face of the wall
	local CLADF, RIBF, DARK = RGB(206, 212, 220), RGB(184, 190, 199), RGB(66, 70, 78)
	local ORANGE, YELLOW, BLACK = RGB(242, 114, 24), RGB(255, 196, 0), RGB(32, 32, 36)
	for _, sx in ipairs({-1, 1}) do
		P(front, "Wall", V(side, FH, 2), C(sx * (DOOR_HW + side / 2), FH / 2, FZ), CLADF, M.Metal)
		-- concrete plinth, ribbed cladding, the door frame and striped guard posts by the door
		P(front, "FrontPlinth", V(side, 8, 0.6), C(sx * (DOOR_HW + side / 2), 4, OZ + 0.3), RGB(150, 152, 156), M.Concrete, NOHIT)
		for x = DOOR_HW + 3, W - 2, 5 do P(front, "FrontRib", V(0.6, FH - 9, 0.4), C(sx * x, 8 + (FH - 9) / 2, OZ + 0.2), RIBF, M.Metal, NOHIT) end
		P(front, "DoorFrame", V(2, DOOR_H + 1, 1.2), C(sx * (DOOR_HW + 1), (DOOR_H + 1) / 2, OZ + 0.6), DARK, M.Metal, NOHIT)
		for k = 0, 5 do P(front, "DoorGuard", V(1.6, 1, 1.6), C(sx * (DOOR_HW + 2.6), 0.5 + k, OZ + 2), (k % 2 == 0) and YELLOW or BLACK, M.SmoothPlastic, NOHIT) end
		-- tie rods holding up the canopy
		local ra, rb = V(sx * (DOOR_HW + 2), DOOR_H + 10, OZ), V(sx * (DOOR_HW + 2), DOOR_H + 2.8, OZ + 9.6)
		P(front, "CanopyRod", V(0.35, 0.35, (rb - ra).Magnitude), CFrame.lookAt((ra + rb) / 2, rb), DARK, M.Metal, NOHIT)
	end
	P(front, "Wall", V(DOOR_HW * 2, FH - DOOR_H, 2), C(0, (FH + DOOR_H) / 2, FZ), CLADF, M.Metal)
	P(front, "FrontBand", V(W * 2, 2.2, 0.5), C(0, FH - 2.6, OZ + 0.45), ORANGE, M.SmoothPlastic, NOHIT)
	P(front, "WallCap", V(W * 2 + 4, 2.2, 3), C(0, FH + 1.1, FZ + 0.5), DARK, M.Metal)
	P(front, "DoorHeader", V(DOOR_HW * 2 + 4, 1.6, 1.2), C(0, DOOR_H + 0.8, OZ + 0.6), DARK, M.Metal, NOHIT)
	-- a steel canopy with lights over the entrance
	P(front, "Canopy", V(DOOR_HW * 2 + 10, 0.8, 10), C(0, DOOR_H + 2.4, OZ + 5), RGB(60, 64, 72), M.Metal, NOHIT)
	P(front, "CanopyEdge", V(DOOR_HW * 2 + 10, 1.2, 0.4), C(0, DOOR_H + 2.4, OZ + 10), ORANGE, M.SmoothPlastic, NOHIT)
	for _, x in ipairs({-13, 0, 13}) do P(front, "CanopyLight", V(6, 0.15, 1.4), C(x, DOOR_H + 1.95, OZ + 6), RGB(255, 246, 228), M.Neon, NOHIT) end
	-- the sign above the canopy
	local sign = P(front, "WarehouseSign", V(56, 8, 0.6), C(0, DOOR_H + 8.5, OZ + 0.5), RGB(26, 32, 44), M.SmoothPlastic, NOHIT)
	P(front, "WarehouseSignFrame", V(57.4, 9.4, 0.4), C(0, DOOR_H + 8.5, OZ + 0.2), ORANGE, M.SmoothPlastic, NOHIT)
	signText(sign, Enum.NormalId.Back, "WAREHOUSE", 16, 7, 600)
	-- loading docks: roll-up doors with slats, a hood, rubber bumpers, a number and a dock light
	local n = 0
	for _, sx in ipairs({-1, 1}) do
		for _, x in ipairs({40, 64, 88}) do
			n = n + 1
			local cx = sx * x
			P(front, "DockFrame", V(15, 17.2, 0.5), C(cx, 9.6, OZ + 0.25), DARK, M.Metal, NOHIT)
			P(front, "DockDoor", V(13.4, 15.6, 0.4), C(cx, 9.8, OZ + 0.55), RGB(198, 204, 212), M.Metal, NOHIT)
			for k = 1, 9 do P(front, "DockSlat", V(13.4, 0.22, 0.15), C(cx, 2 + k * 1.6, OZ + 0.8), RGB(158, 164, 173), M.Metal, NOHIT) end
			P(front, "DockHood", V(15.6, 1.3, 1.6), C(cx, 18.6, OZ + 0.8), DARK, M.Metal, NOHIT)
			for _, o in ipairs({-5.2, 5.2}) do P(front, "DockBumper", V(1.4, 2.4, 1.2), C(cx + o, 3.2, OZ + 1.1), RGB(24, 24, 26), M.Rubber, NOHIT) end
			local num = P(front, "DockNumber", V(3.2, 2.4, 0.2), C(cx + 9.4, 15, OZ + 0.35), YELLOW, M.SmoothPlastic, NOHIT)
			local tl = signText(num, Enum.NormalId.Back, tostring(n), 30, 2, 220)
			tl.TextColor3 = BLACK
			P(front, "DockLight", V(1.4, 0.9, 0.9), C(cx - 9.4, 16.5, OZ + 0.6), RGB(255, 250, 230), M.Neon, NOHIT)
		end
		-- flood lights between the docks
		for _, x in ipairs({52, 76}) do
			P(front, "FloodLight", V(2.4, 1.4, 1.6), C(sx * x, 23, OZ + 0.8), DARK, M.Metal, NOHIT)
			P(front, "FloodLens", V(2.0, 1.0, 0.2), C(sx * x, 23, OZ + 1.65), RGB(255, 248, 232), M.Neon, NOHIT)
		end
	end
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
local BACKZ = Config.StoreEndZ()

local wh = folder(root, "Warehouse")
local spawns = folder(root, "BoxSpawns")
local guardsFolder = folder(root, "Guards")
-- the end wall of the warehouse (after the last area)
P(wh, "BackWall", V(L.halfWidth * 2 + 8, L.wallHeight, 4), C(0, L.wallHeight / 2, BACKZ - 2), RGB(204, 210, 218), M.Metal)

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
	{scale = 3.4, shirt = RGB(58, 46, 42), pants = RGB(46, 37, 34), skin = RGB(64, 50, 45), hat = nil, eyes = RGB(255, 160, 40), extras = {"rock", "lava", "hammer", "bigarms"}},
	{scale = 3.6, shirt = RGB(150, 165, 210), pants = RGB(110, 118, 160), skin = RGB(200, 215, 255), hat = "helmet", hatColor = RGB(120, 130, 170), eyes = RGB(140, 255, 220), extras = {"ghost", "plume", "sword", "shield"}},
	{scale = 3.8, shirt = RGB(84, 72, 150), pants = RGB(62, 56, 116), skin = RGB(120, 210, 240), hat = nil, eyes = RGB(255, 110, 220), extras = {"crystals", "spikes", "club"}},
	{scale = 4.0, shirt = RGB(70, 92, 145), pants = RGB(52, 62, 100), skin = RGB(175, 195, 232), hat = "crown", hatColor = RGB(255, 205, 60), eyes = RGB(255, 240, 120), extras = {"cloudbeard", "lightning", "wings", "crown"}},
	{scale = 4.4, shirt = RGB(175, 28, 42), pants = RGB(120, 16, 30), skin = RGB(190, 36, 46), hat = "crown", hatColor = RGB(255, 200, 50), eyes = RGB(255, 210, 40), extras = {"horns", "wings", "tail", "crown", "claws"}},
}

local function has(list, name)
	for _, v in ipairs(list) do if v == name then return true end end
	return false
end

-- printed text on some bosses' uniforms: SECURITY / POLICE / SEC-08 across the back, RIOT on the shield
-- (a global function so makeGuardian stays under Luau's 200-local limit)
function BOSS_DECALS(areaIndex, model, torso)
	local back = ({[4] = {"SECURITY", Color3.fromRGB(255, 225, 80)}, [6] = {"POLICE", Color3.fromRGB(255, 255, 255)}, [8] = {"SEC-08", Color3.fromRGB(255, 210, 60)}})[areaIndex]
	local function stamp(part, face, text, color)
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Print"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 1
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.42)
		l.Size = UDim2.fromScale(0.94, 0.34)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.3
		l.Parent = sg
		sg.Parent = part
	end
	if back and torso then stamp(torso, Enum.NormalId.Back, back[1], back[2]) end
	if areaIndex == 6 then
		local shield = model:FindFirstChild("Shield", true)
		if shield then stamp(shield, Enum.NormalId.Left, "RIOT", Color3.fromRGB(255, 255, 255)) end
	end
end

local function makeGuardian(areaIndex, pos, accent)
	local area = Config.Areas[areaIndex]
	local look = LOOKS[areaIndex] or LOOKS[#LOOKS]
	local CS = game:GetService("CollectionService")
	local s = math.min(5.6, look.scale * 1.35) -- (areas 1-10 stay <= 4.32; the 5 deepest bosses keep growing)
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
	-- the 15 bosses
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

	elseif areaIndex == 10 then
		-- VOID WARDEN (boss of the Galaxy Vault): a crown of neon horns, glowing cracks, cape, a giant scythe,
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

	elseif areaIndex == 11 then
		-- MAGMA GOLEM: a walking pile of basalt boulders held together by lava - glowing cracks,
		-- molten eyes, smoking vents on his back and a giant forge hammer
		local rock, rockDark = look.shirt, RGB(38, 30, 28)
		local lava, hot = RGB(255, 110, 30), RGB(255, 200, 70)
		G("HeadRock", V(1.42, 1.25, 1.35), 0, 4.55, 0.02, rock, M.Slate, nil, head)
		G("BrowRock", V(1.5, 0.32, 0.45), 0, 4.87, -0.5, rockDark, M.Slate, ROTZ(2), head)
		for _, sx in ipairs({-1, 1}) do
			G("GlowEye", V(0.34, 0.16, 0.06), sx * 0.3, 4.62, -0.75, hot, M.Neon, ROTZ(-sx * 14), head)
			G("CheekRock", V(0.45, 0.4, 0.4), sx * 0.6, 4.3, -0.45, rockDark, M.Slate, CFrame.Angles(A(10), A(sx * 20), 0), head)
		end
		G("LavaMouth", V(0.72, 0.14, 0.06), 0, 4.25, -0.75, lava, M.Neon, nil, head)
		for k = -1, 1 do G("MouthFang", V(0.12, 0.16, 0.05), k * 0.24, 4.3, -0.77, rockDark, M.Slate, nil, head) end
		G("HeadBoulder", V(0.75, 0.55, 0.7), -0.32, 5.25, 0.08, rock, M.Slate, CFrame.Angles(A(12), A(30), A(-8)), head)
		G("HeadBoulder", V(0.55, 0.45, 0.55), 0.36, 5.2, -0.08, rockDark, M.Slate, CFrame.Angles(A(-10), A(15), A(12)), head)
		-- a body of stacked boulders with lava running through the cracks
		G("ChestRock", V(2.25, 1.45, 1.25), 0, 3.35, -0.02, rock, M.Slate, nil, torso)
		G("BellyRock", V(1.9, 0.95, 1.15), 0, 2.3, 0, rockDark, M.Slate, CFrame.Angles(0, A(5), A(-3)), torso)
		for _, c in ipairs({{-0.45, 3.35, 25, 1.2}, {0.5, 3.05, -35, 1.0}, {0.05, 2.5, 70, 0.9}, {-0.6, 2.75, -55, 0.6}, {0.62, 3.75, 15, 0.5}}) do
			G("LavaCrack", V(0.13, c[4], 0.05), c[1], c[2], -0.68, lava, M.Neon, ROTZ(c[3]), torso)
		end
		local core = disc("MagmaCore", 0.08, 0.62, 0, 3.4, -0.69, hot, M.Neon, torso, FACE_FWD)
		light(core, lava, 10, 2)
		for _, sx in ipairs({-1, 1}) do
			local arm, leg = (sx < 0) and LA or RA, (sx < 0) and LL or RL
			GB("ShoulderBoulder", 1.55, sx * 1.62, 4.0, 0, rock, M.Slate, arm)
			G("ArmRock", V(1.3, 1.05, 1.3), sx * 1.52, 2.95, 0, rockDark, M.Slate, ROTZ(sx * 6), arm)
			G("ArmCrack", V(0.1, 0.9, 0.05), sx * 1.5, 3.0, -0.69, lava, M.Neon, ROTZ(sx * 25), arm)
			G("Fist", V(1.45, 1.05, 1.45), sx * 1.5, 1.65, 0, rock, M.Slate, CFrame.Angles(0, A(sx * 8), 0), arm)
			G("FistGlow", V(1.47, 0.12, 1.47), sx * 1.5, 1.8, 0, lava, M.Neon, CFrame.Angles(0, A(sx * 8), 0), arm)
			G("LegRock", V(1.22, 1.15, 1.22), sx * 0.5, 1.4, 0, rock, M.Slate, nil, leg)
			G("FootRock", V(1.3, 0.6, 1.55), sx * 0.5, 0.3, -0.12, rockDark, M.Slate, nil, leg)
			G("LegCrack", V(0.1, 0.8, 0.05), sx * 0.5, 1.3, -0.64, lava, M.Neon, ROTZ(-sx * 20), leg)
		end
		-- smoking volcanic vents on his back
		for k = -1, 1 do
			local top = V(k * 0.8, 4.4 - math.abs(k) * 0.3, 1.15)
			stick("BackVent", V(k * 0.55, 3.3, 0.5), top, 0.42, 0.42, rockDark, M.Slate, torso, true)
			local vent = GB("VentLava", 0.36, top.X, top.Y, top.Z, lava, M.Neon, torso)
			if k == 0 then
				emitter(vent, {Color = ColorSequence.new(RGB(90, 80, 80), RGB(40, 35, 35)), Transparency = NumberSequence.new(0.3, 1), Rate = 6,
					Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.4 * s, 1.2 * s), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15)})
			end
		end
		-- the forge hammer
		stick("HammerShaft", V(1.55, 0.5, -0.6), V(1.55, 6.0, -0.62), 0.24, 0.24, RGB(70, 48, 36), M.Wood, RA, true)
		G("HammerHead", V(1.0, 1.0, 2.0), 1.55, 6.2, -0.62, RGB(60, 60, 68), M.Metal, nil, RA)
		G("HammerGlow", V(1.04, 0.22, 2.04), 1.55, 6.2, -0.62, lava, M.Neon, nil, RA)
		for _, dz in ipairs({-1, 1}) do G("HammerFace", V(1.1, 1.1, 0.12), 1.55, 6.2, -0.62 + dz, RGB(90, 90, 100), M.Metal, nil, RA) end
		emitter(torso, {Color = ColorSequence.new(hot, lava), LightEmission = 1, Rate = 18,
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.9, 0),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 5, 0)})
		light(head, lava, 7 * s, 2.5)
		bossOrbs(3, lava, 2.4, 3.8, 0.36) -- fireballs circling him

	elseif areaIndex == 12 then
		-- PHANTOM KNIGHT: see-through ghostly armour, a great helm with a glowing slit and a purple plume,
		-- a tattered cape, a spectral sword and a kite shield. Lost souls circle him.
		local armor, armorDark = RGB(160, 175, 215), RGB(90, 98, 140)
		local ghost, purple = RGB(140, 255, 220), RGB(150, 90, 220)
		for _, p in ipairs({head, torso, LA, RA, LL, RL}) do p.Transparency = 0.45 end
		G("Helm", V(1.45, 1.35, 1.45), 0, 4.62, 0, armor, M.Metal, nil, head, {Transparency = 0.2})
		G("HelmCrest", V(0.18, 0.3, 1.5), 0, 5.38, 0, armorDark, M.Metal, nil, head)
		G("GlowEye", V(1.05, 0.14, 0.05), 0, 4.66, -0.74, ghost, M.Neon, nil, head)
		G("VisorBar", V(0.1, 0.65, 0.05), 0, 4.45, -0.75, armorDark, M.Metal, nil, head)
		for k = 0, 3 do G("BreathHole", V(0.08, 0.08, 0.04), -0.3 + k * 0.2, 4.3, -0.74, RGB(30, 30, 50), nil, nil, head) end
		for i, pl in ipairs({{5.5, -0.15, -10}, {5.75, 0.2, -35}, {5.85, 0.55, -60}, {5.78, 0.9, -85}, {5.58, 1.18, -110}, {5.3, 1.38, -135}}) do
			G("Plume", V(0.3, 0.6 - i * 0.04, 0.42), 0, pl[1], pl[2], (i % 2 == 0) and purple or purple:Lerp(white, 0.25), M.Fabric, CFrame.Angles(A(pl[3]), 0, 0), head)
		end
		-- breastplate, skirt, pauldrons, gauntlets, greaves - all a little see-through
		G("Breastplate", V(2.15, 1.6, 1.2), 0, 3.22, 0, armor, M.Metal, nil, torso, {Transparency = 0.25})
		G("Emblem", V(0.5, 0.5, 0.06), 0, 3.4, -0.63, ghost, M.Neon, CFrame.Angles(0, 0, A(45)), torso)
		G("Tasset", V(2.2, 0.72, 1.25), 0, 1.86, 0, armorDark, M.Metal, nil, torso, {Transparency = 0.25})
		G("ArmorBelt", V(2.22, 0.2, 1.27), 0, 2.25, 0, purple, M.Neon, nil, torso)
		for _, sx in ipairs({-1, 1}) do
			local arm, leg = (sx < 0) and LA or RA, (sx < 0) and LL or RL
			G("Pauldron", V(1.4, 0.58, 1.38), sx * 1.55, 4.0, 0, armor, M.Metal, ROTZ(-sx * 15), arm, {Transparency = 0.2})
			G("PauldronTrim", V(1.42, 0.1, 1.4), sx * 1.55, 3.74, 0, purple, M.Neon, ROTZ(-sx * 15), arm)
			G("Gauntlet", V(1.14, 0.85, 1.14), sx * 1.5, 2.42, 0, armor, M.Metal, nil, arm, {Transparency = 0.2})
			G("Greave", V(1.12, 1.25, 1.14), sx * 0.5, 0.75, -0.02, armor, M.Metal, nil, leg, {Transparency = 0.2})
			G("KneeGuard", V(0.7, 0.45, 0.2), sx * 0.5, 1.35, -0.62, armorDark, M.Metal, nil, leg)
			G("Cape", V(1.0, 3.7, 0.1), sx * 0.5, 2.2, 0.66, RGB(55, 35, 85), M.Fabric, CFrame.Angles(A(9), 0, A(-sx * 4)), torso, {Transparency = 0.25})
			for k = 0, 1 do
				G("CapeTatter", V(0.36, 0.5, 0.08), sx * (0.25 + k * 0.5), 0.2, 0.95, RGB(55, 35, 85), M.Fabric, CFrame.Angles(A(9), 0, A(sx * (12 - k * 24))), torso, {Transparency = 0.35})
			end
		end
		-- the spectral sword (right hand) and a kite shield (left arm)
		G("SwordGrip", V(0.18, 0.18, 0.7), 1.5, 1.95, -0.3, RGB(50, 40, 60), M.Fabric, nil, RA)
		G("SwordGuard", V(1.1, 0.16, 0.2), 1.5, 1.95, -0.72, RGB(200, 170, 90), M.Metal, nil, RA)
		local blade = stick("SwordBlade", V(1.5, 1.98, -0.8), V(1.5, 2.4, -4.6), 0.1, 0.42, ghost, M.Neon, RA)
		blade.Transparency = 0.15
		GB("SwordPommel", 0.24, 1.5, 1.95, 0.08, purple, M.Neon, RA)
		G("Shield", V(0.22, 2.5, 1.7), -2.12, 2.9, -0.35, armorDark, M.Metal, nil, LA, {Transparency = 0.15})
		G("ShieldTip", V(0.2, 1.0, 1.0), -2.12, 1.65, -0.35, armorDark, M.Metal, CFrame.Angles(A(45), 0, 0), LA, {Transparency = 0.15})
		G("ShieldCross", V(0.24, 1.9, 0.26), -2.14, 2.95, -0.35, ghost, M.Neon, nil, LA)
		G("ShieldCross", V(0.24, 0.26, 1.3), -2.14, 3.3, -0.35, ghost, M.Neon, nil, LA)
		emitter(torso, {Color = ColorSequence.new(ghost, purple), LightEmission = 0.8, Rate = 14, Transparency = NumberSequence.new(0.3, 1),
			Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(1, 2), Size = NumberSequence.new(1.0, 0),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 3, 0)})
		light(head, ghost, 7 * s, 2.2)
		bossOrbs(3, ghost, 2.4, 3.8, 0.34) -- lost souls

	elseif areaIndex == 13 then
		-- CRYSTAL TITAN: an amethyst rock giant with cyan + pink crystals growing out of his head,
		-- shoulders, fists and back, a glowing heart gem and a crystal club
		local cyan, pink, amethyst = RGB(90, 230, 255), RGB(255, 110, 220), RGB(150, 100, 235)
		local rock = look.shirt
		local DIAMOND = CFrame.Angles(A(45), 0, A(45))
		local function crystal(name, a, b, w, color, to) -- a crystal rod from a to b with a glowing tip
			stick(name, a, b, w, w, color, M.Glass, to)
			G(name .. "Tip", V(w * 0.72, w * 0.72, w * 0.72), b.X, b.Y, b.Z, color:Lerp(white, 0.3), M.Neon, DIAMOND, to)
		end
		G("HeadRock", V(1.38, 1.3, 1.38), 0, 4.55, 0, look.skin:Lerp(rock, 0.55), M.Slate, nil, head)
		G("BrowRidge", V(1.42, 0.22, 0.3), 0, 4.9, -0.58, rock, M.Slate, nil, head)
		for _, sx in ipairs({-1, 1}) do
			G("GlowEye", V(0.26, 0.26, 0.06), sx * 0.3, 4.62, -0.71, pink, M.Neon, ROTZ(45), head)
		end
		G("Mouth", V(0.55, 0.1, 0.05), 0, 4.22, -0.71, cyan, M.Neon, nil, head)
		for k = -2, 2 do
			local ak = math.abs(k)
			crystal("HeadCrystal", V(k * 0.24, 5.05, 0.05 * ak), V(k * 0.5, 5.65 + (2 - ak) * 0.38, 0.12 * ak), 0.3 - ak * 0.04, (k % 2 == 0) and cyan or pink, head)
		end
		-- body: rocky plates + a glowing crystal heart
		G("ChestRock", V(2.2, 1.5, 1.22), 0, 3.3, 0, rock, M.Slate, nil, torso)
		G("ChestCrystal", V(1.0, 1.0, 0.3), 0, 3.35, -0.6, amethyst, M.Glass, ROTZ(45), torso)
		local heart = G("CrystalHeart", V(0.55, 0.55, 0.22), 0, 3.35, -0.72, pink, M.Neon, ROTZ(45), torso)
		light(heart, pink, 10, 2)
		G("HipRock", V(2.15, 0.6, 1.18), 0, 2.2, 0, rock:Lerp(RGB(0, 0, 0), 0.25), M.Slate, nil, torso)
		for _, sx in ipairs({-1, 1}) do
			local arm, leg = (sx < 0) and LA or RA, (sx < 0) and LL or RL
			G("ShoulderRock", V(1.4, 0.7, 1.35), sx * 1.55, 3.95, 0, rock, M.Slate, ROTZ(-sx * 10), arm)
			for k = -1, 1 do
				crystal("ShoulderCrystal", V(sx * (1.55 + k * 0.32), 4.2, k * 0.25), V(sx * (1.95 + k * 0.4), 5.4 - math.abs(k) * 0.35, k * 0.4),
					0.36 - math.abs(k) * 0.08, (k == 0) and cyan or ((k < 0) and pink or amethyst), arm)
			end
			G("CrystalArm", V(1.22, 1.15, 1.22), sx * 1.5, 2.45, 0, cyan, M.Glass, nil, arm, {Transparency = 0.15})
			for k = -1, 1 do
				crystal("KnuckleCrystal", V(sx * 1.5 + k * 0.3, 1.95, -0.45), V(sx * 1.5 + k * 0.34, 1.7, -0.95), 0.18, pink, arm)
			end
			G("CrystalBoot", V(1.16, 0.95, 1.3), sx * 0.5, 0.47, -0.06, amethyst, M.Glass, nil, leg, {Transparency = 0.1})
			G("LegRock", V(1.12, 0.6, 1.12), sx * 0.5, 1.45, 0, rock, M.Slate, nil, leg)
		end
		-- big crystals growing out of his back
		for k = -1, 1 do
			crystal("BackCrystal", V(k * 0.5, 3.4, 0.45), V(k * 0.95, 4.9 - math.abs(k) * 0.4, 1.35), 0.5 - math.abs(k) * 0.12, (k == 0) and cyan or pink, torso)
		end
		-- a crystal club in his right hand
		stick("ClubHandle", V(1.55, 1.9, -0.4), V(1.55, 1.25, -2.2), 0.26, 0.26, rock, M.Slate, RA, true)
		for k = 1, 4 do
			G("ClubCrystal", V(0.55, 1.0, 0.55), 1.55 + (k - 2.5) * 0.22, 1.2 + (k % 2) * 0.22, -2.3 - k * 0.12, (k % 2 == 0) and cyan or pink, M.Glass,
				CFrame.Angles(A(k * 23), A(k * 41), A(k * 17)), RA, {Transparency = 0.1})
		end
		emitter(torso, {Color = ColorSequence.new(cyan, pink), LightEmission = 1, Rate = 14,
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.6, 0),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0)})
		light(head, cyan, 7 * s, 2.2)
		bossOrbs(4, cyan, 2.6, 3.8, 0.34)

	elseif areaIndex == 14 then
		-- STORM GIANT: a sky king with a fluffy cloud beard, a golden crown and feathered wings,
		-- storm-cloud shoulders, a lightning bolt in his hand and his very own rain cloud
		local cloud, cloudGrey, bolt = RGB(250, 252, 255), RGB(150, 160, 185), RGB(255, 235, 90)
		uniform({sleeve = shirt, cuff = gold, boots = RGB(200, 170, 90), tallBoots = true, noPockets = true, noButtons = true, noCollar = true, noPouches = true, belt = RGB(200, 160, 40)})
		face({glow = true, pupil = bolt, eyeWhite = RGB(30, 40, 75), browAngle = 18, brow = cloud})
		-- the cloud beard, mustache and hair
		for _, b in ipairs({{0, 4.0, -0.6, 0.85}, {-0.38, 4.1, -0.52, 0.62}, {0.38, 4.1, -0.52, 0.62}, {0, 3.6, -0.66, 0.7}, {-0.3, 3.72, -0.62, 0.55}, {0.3, 3.72, -0.62, 0.55}, {0, 3.22, -0.68, 0.5}}) do
			GB("CloudBeard", b[4], b[1], b[2], b[3], cloud, M.SmoothPlastic, head)
		end
		for _, sx in ipairs({-1, 1}) do
			GB("CloudMustache", 0.38, sx * 0.2, 4.3, -0.68, cloud, M.SmoothPlastic, head)
			GB("CloudHair", 0.7, sx * 0.5, 4.85, 0.32, cloud, M.SmoothPlastic, head)
		end
		GB("CloudHair", 0.85, 0, 4.95, 0.45, cloud, M.SmoothPlastic, head)
		-- golden crown with a lightning gem
		G("CrownBand", V(1.36, 0.32, 1.36), 0, 5.1, 0, gold, M.Metal, nil, head)
		for k = 0, 7 do
			local a = k * math.pi / 4
			G("CrownPoint", V(0.3, 0.3, 0.3), math.cos(a) * 0.62, 5.4, math.sin(a) * 0.62, gold, M.Metal, CFrame.Angles(A(45), 0, A(45)), head)
		end
		GB("CrownGem", 0.26, 0, 5.1, -0.7, bolt, M.Neon, head)
		-- feathered wings (white, gold tips), storm-cloud shoulders, gold bracers
		for _, sx in ipairs({-1, 1}) do
			for k = 0, 3 do
				stick("WingFeather", V(sx * 0.5, 3.7 - k * 0.15, 0.58), V(sx * (2.8 - k * 0.35), 5.6 - k * 0.75, 1.0 + k * 0.08), 0.08, 0.75 - k * 0.08,
					(k % 2 == 0) and cloud or RGB(232, 238, 255), M.SmoothPlastic, torso)
			end
			GB("WingTip", 0.4, sx * 2.8, 5.6, 1.0, gold, M.Metal, torso)
			local arm = (sx < 0) and LA or RA
			GB("StormShoulder", 1.25, sx * 1.6, 4.05, 0, cloudGrey, M.SmoothPlastic, arm)
			GB("StormShoulder", 0.85, sx * 1.95, 4.3, 0.3, cloudGrey:Lerp(cloud, 0.4), M.SmoothPlastic, arm)
			G("Bracer", V(1.14, 0.42, 1.14), sx * 1.5, 2.55, 0, gold, M.Metal, nil, arm)
		end
		G("Sash", V(0.45, 2.7, 1.12), 0.05, 3.0, 0, gold, M.Fabric, ROTZ(35), torso)
		disc("ChestBolt", 0.06, 0.5, -0.5, 3.55, -0.58, bolt, M.Neon, torso, FACE_FWD)
		-- a lightning bolt in his right hand
		local pts = {V(1.5, 1.6, -0.5), V(1.85, 2.9, -0.8), V(1.35, 3.5, -0.95), V(1.75, 4.8, -1.15), V(1.3, 5.4, -1.3), V(1.55, 6.8, -1.5)}
		for k = 1, #pts - 1 do stick("Lightning", pts[k], pts[k + 1], 0.2, 0.2, bolt, M.Neon, RA) end
		local spark = GB("BoltSpark", 0.45, 1.55, 6.8, -1.5, RGB(255, 255, 220), M.Neon, RA)
		light(spark, bolt, 10, 2.5)
		-- his own little rain cloud floating over his head
		for _, c in ipairs({{0, 6.7, 0.1, 1.1}, {-0.6, 6.55, 0.15, 0.8}, {0.6, 6.55, 0.05, 0.8}}) do
			GB("RainCloud", c[4], c[1], c[2], c[3], cloudGrey, M.SmoothPlastic, head)
		end
		local rain = G("RainZone", V(1.4, 0.2, 0.8), 0, 6.3, 0.1, cloudGrey, nil, nil, head, {Transparency = 1})
		emitter(rain, {Color = ColorSequence.new(RGB(170, 200, 255)), Transparency = NumberSequence.new(0.2, 0.6), Rate = 18, Lifetime = NumberRange.new(0.35, 0.5),
			Speed = NumberRange.new(10, 14), Size = NumberSequence.new(0.12 * s, 0.08 * s), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(4, 4)})
		light(head, bolt, 7 * s, 2.2)
		bossOrbs(3, bolt, 2.6, 4.2, 0.3) -- crackling ball lightning

	elseif areaIndex == 15 then
		-- DRAGON KING (the final boss): a red dragon in a golden crown - a snout full of fangs, curved horns,
		-- huge bat wings, a spiked tail, golden claws + belly, a ruby medallion, and he breathes fire
		local scaleDark = RGB(110, 14, 26)
		local belly, horn, fire = RGB(255, 190, 80), RGB(240, 225, 190), RGB(255, 120, 30)
		G("Snout", V(0.95, 0.55, 0.85), 0, 4.32, -0.95, look.skin, nil, nil, head)
		G("Jaw", V(0.85, 0.22, 0.7), 0, 3.98, -0.85, scaleDark, nil, nil, head)
		for k = -1.5, 1.5 do G("Fang", V(0.1, 0.22, 0.1), k * 0.24, 3.98, -1.3, white, nil, nil, head) end
		for _, sx in ipairs({-1, 1}) do
			GB("Nostril", 0.14, sx * 0.22, 4.52, -1.36, RGB(40, 10, 10), nil, head)
			G("GlowEye", V(0.32, 0.16, 0.06), sx * 0.3, 4.68, -0.66, gold, M.Neon, ROTZ(-sx * 15), head)
			G("EyePupil", V(0.05, 0.15, 0.03), sx * 0.3, 4.68, -0.7, RGB(20, 10, 10), nil, nil, head)
			G("BrowScale", V(0.45, 0.14, 0.3), sx * 0.3, 4.86, -0.6, scaleDark, nil, ROTZ(sx * 20), head)
			stick("Horn", V(sx * 0.42, 5.0, 0.15), V(sx * 0.85, 5.55, 0.55), 0.28, 0.28, horn, nil, head, true)
			stick("HornTip", V(sx * 0.85, 5.55, 0.55), V(sx * 0.9, 6.1, 1.1), 0.18, 0.18, horn, nil, head, true)
			G("CheekSpike", V(0.12, 0.12, 0.5), sx * 0.66, 4.45, 0.1, horn, nil, CFrame.Angles(0, A(sx * 30), 0), head)
		end
		G("CrownBand", V(1.32, 0.3, 1.32), 0, 5.12, 0, gold, M.Metal, nil, head)
		for k = 0, 5 do
			local a = k * math.pi / 3
			G("CrownPoint", V(0.28, 0.28, 0.28), math.cos(a) * 0.6, 5.38, math.sin(a) * 0.6, gold, M.Metal, CFrame.Angles(A(45), 0, A(45)), head)
		end
		GB("CrownGem", 0.24, 0, 5.12, -0.68, RGB(255, 40, 60), M.Neon, head)
		-- golden spines down his back, a golden belly, a royal chain with a ruby medallion
		for k = 0, 4 do G("Spine", V(0.12, 0.42, 0.42), 0, 4.0 - k * 0.5, 0.55, gold, M.Metal, CFrame.Angles(A(45), 0, 0), torso) end
		G("Belly", V(1.3, 1.75, 0.08), 0, 2.95, -0.52, belly, nil, nil, torso)
		for k = 0, 3 do G("BellyRidge", V(1.32, 0.07, 0.1), 0, 2.3 + k * 0.42, -0.55, belly:Lerp(RGB(0, 0, 0), 0.25), nil, nil, torso) end
		for k = 0, 9 do
			local a = (k / 10) * math.pi * 2
			GB("Chain", 0.15, math.cos(a) * 0.62, 3.9 - math.max(0, -math.sin(a)) * 0.3, math.sin(a) * 0.45, gold, M.Metal, torso)
		end
		GB("Medallion", 0.4, 0, 3.58, -0.6, RGB(255, 40, 60), M.Neon, torso)
		for _, sx in ipairs({-1, 1}) do
			local arm, leg = (sx < 0) and LA or RA, (sx < 0) and LL or RL
			-- a huge bat wing: two bones with the skin hanging under them
			local sh, el, tip = V(sx * 0.6, 3.9, 0.6), V(sx * 2.6, 5.9, 1.2), V(sx * 4.6, 4.6, 1.5)
			stick("WingBone", sh, el, 0.2, 0.2, scaleDark, nil, torso, true)
			stick("WingBone", el, tip, 0.15, 0.15, scaleDark, nil, torso, true)
			GB("WingClaw", 0.26, el.X, el.Y + 0.1, el.Z, horn, nil, torso)
			stick("WingSkin", sh - V(0, 0.95, 0), el - V(0, 0.95, 0), 0.06, 1.9, RGB(150, 20, 35), nil, torso)
			stick("WingSkin", el - V(0, 1.1, 0), tip - V(0, 1.1, 0), 0.06, 2.2, RGB(150, 20, 35), nil, torso)
			G("Pauldron", V(1.35, 0.55, 1.32), sx * 1.52, 4.02, 0, gold, M.Metal, ROTZ(-sx * 14), arm)
			for k = -1, 1 do stick("PauldronSpike", V(sx * (1.5 + k * 0.32), 4.25, 0), V(sx * (1.75 + k * 0.42), 4.85, k * 0.1), 0.15, 0.15, horn, nil, arm, true) end
			G("ArmScales", V(1.1, 0.9, 1.1), sx * 1.5, 2.8, 0, scaleDark, nil, nil, arm)
			for k = -1, 1 do stick("Claw", V(sx * 1.5 + k * 0.28, 2.0, -0.3), V(sx * 1.5 + k * 0.32, 1.45, -0.65), 0.12, 0.12, gold, M.Metal, arm) end
			G("LegScales", V(1.1, 0.8, 1.1), sx * 0.5, 1.5, 0, scaleDark, nil, nil, leg)
			for k = -1, 1 do stick("ToeClaw", V(sx * 0.5 + k * 0.3, 0.2, -0.5), V(sx * 0.5 + k * 0.32, 0.05, -0.85), 0.12, 0.12, horn, nil, leg) end
		end
		-- a long spiked tail
		for k = 1, 6 do
			local w = 0.72 - k * 0.08
			local y, z = 2.05 - k * 0.24, 0.45 + k * 0.62
			G("Tail", V(w, w, 0.75), 0, y, z, (k % 2 == 0) and look.skin or scaleDark, nil, CFrame.Angles(A(-12 - k * 2), 0, 0), torso)
			G("TailSpike", V(0.08, 0.28, 0.28), 0, y + w / 2, z, gold, M.Metal, CFrame.Angles(A(45), 0, 0), torso)
		end
		G("TailSpade", V(0.08, 0.7, 0.7), 0, 0.45, 4.6, gold, M.Metal, CFrame.Angles(A(45), 0, 0), torso)
		-- fire breath + embers
		local mouth = G("FireBreath", V(0.3, 0.3, 0.3), 0, 4.15, -1.4, fire, nil, nil, head, {Transparency = 1})
		emitter(mouth, {Color = ColorSequence.new(RGB(255, 220, 90), RGB(255, 60, 20)), LightEmission = 1, Rate = 14, Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(5, 9), Size = NumberSequence.new(0.35 * s, 0.9 * s), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(12, 12)})
		emitter(torso, {Color = ColorSequence.new(RGB(255, 210, 60), fire), LightEmission = 1, Rate = 14,
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.9, 0),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 5, 0)})
		light(head, fire, 8 * s, 2.5)
		bossOrbs(4, fire, 2.8, 3.8, 0.4) -- fireballs
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
	BOSS_DECALS(areaIndex, m, torso)

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
	local threat = math.clamp(math.ceil(areaIndex * 5 / math.max(10, #Config.Areas)), 1, 5) -- (5 diamonds = the last areas)
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
-- THE WAREHOUSE BAYS: a real warehouse - polished concrete with painted safety lines, steel
-- columns, cladded walls, roof trusses with skylights and high-bay lamps, orange/blue pallet
-- racking (the boxes spawn on it), pallets, a forklift and bollards. Every area is one
-- department: its colour is on the wall band, the hanging sign and the wall signs.
-- (one global function, so the map script stays under Luau's 200-local limit)
------------------------------------------------------------------
function WAREHOUSE_BAYS()
	local CONCRETE = RGB(164, 166, 169)
	local JOINT = RGB(136, 138, 142)
	local YELLOW = RGB(255, 196, 0)
	local STRIPE = RGB(32, 32, 36)
	local STEEL = RGB(96, 102, 112)
	local STEEL_DARK = RGB(64, 68, 76)
	local CLAD = RGB(204, 210, 218)
	local CLAD_RIB = RGB(182, 188, 197)
	local BLOCK = RGB(146, 148, 152)
	local RACK_BLUE = RGB(30, 88, 170)
	local RACK_ORANGE = RGB(242, 114, 24)
	local DECK = RGB(158, 164, 172)
	local WOOD = RGB(200, 156, 100)
	local WOOD_DARK = RGB(158, 116, 70)
	local CARD = RGB(198, 152, 98)
	local TAPE = RGB(226, 196, 140)
	local LAMP = RGB(255, 244, 226)
	local LEVELS = {0.6, 5.6, 10.6}

	-- a part placed relative to a local frame (base is a CFrame in studs, offsets in design units)
	local function piece(r, base, name, size, lx, ly, lz, color, mat, shape, rot)
		local cf = base * CFrame.new(lx * SC, ly * SC, lz * SC)
		if rot then cf = cf * rot end
		local p = P(r.folder, name, size * SC, cf, color, mat, FX)
		if shape == "cyl" then p.Shape = Enum.PartType.Cylinder elseif shape == "ball" then p.Shape = Enum.PartType.Ball end
		return p
	end
	local SIDEWAYS = CFrame.Angles(0, 0, math.rad(90))

	------------------------------------------------------------------
	-- floor: polished concrete, saw-cut joints, yellow aisle lines, a dashed forklift lane
	------------------------------------------------------------------
	local function floor(r, SLen)
		D(r, "Floor", V(HW * 2, 0.4, SLen), 0, 0.3, SLen / 2, CONCRETE, M.Concrete)
		for _, x in ipairs({-28, -14, 14, 28}) do D(r, "FloorJoint", V(0.12, 0.05, SLen), x, F + 0.01, SLen / 2, JOINT, M.SmoothPlastic, FX) end
		for d = 14, SLen - 1, 14 do D(r, "FloorJoint", V(HW * 2, 0.05, 0.12), 0, F + 0.01, d, JOINT, M.SmoothPlastic, FX) end
		for _, x in ipairs({-9, 9, -(HW - 7.2), HW - 7.2}) do D(r, "AisleLine", V(0.45, 0.06, SLen - 2.4), x, F + 0.02, SLen / 2 + 1.2, YELLOW, M.SmoothPlastic, FX) end
		for d = 4, SLen - 4, 7 do D(r, "LaneDash", V(0.35, 0.06, 3.4), 0, F + 0.02, d, RGB(240, 240, 240), M.SmoothPlastic, FX) end
		-- yellow/black hazard band where the area starts
		local n = 14
		local w = HW * 2 / n
		for k = 0, n - 1 do
			D(r, "HazardStripe", V(w, 0.06, 1.4), -HW + w * (k + 0.5), F + 0.02, 0.9, (k % 2 == 0) and YELLOW or STRIPE, M.SmoothPlastic, FX)
		end
	end

	------------------------------------------------------------------
	-- walls: concrete block at the bottom, ribbed cladding above, a department colour band
	------------------------------------------------------------------
	local function walls(r, SLen, acc)
		for _, side in ipairs({-1, 1}) do
			D(r, "Wall", V(2, WH, SLen), side * (HW + 1), WH / 2, SLen / 2, CLAD, M.Metal)
			D(r, "BlockBase", V(0.6, 6, SLen), side * (HW - 0.2), F + 3, SLen / 2, BLOCK, M.Concrete, FX)
			for _, y in ipairs({2, 4, 6}) do D(r, "Mortar", V(0.64, 0.1, SLen), side * (HW - 0.2), F + y, SLen / 2, RGB(122, 124, 128), M.SmoothPlastic, FX) end
			for d = 3, SLen - 1, 6 do D(r, "CladRib", V(0.3, WH - 7.5, 0.6), side * (HW - 0.1), F + 6.5 + (WH - 7.5) / 2, d, CLAD_RIB, M.Metal, FX) end
			D(r, "DeptBand", V(0.4, 1.6, SLen), side * (HW - 0.3), F + 7.6, SLen / 2, acc, M.SmoothPlastic, FX)
			D(r, "DeptTrim", V(0.42, 0.24, SLen), side * (HW - 0.3), F + 8.55, SLen / 2, RGB(245, 245, 245), M.SmoothPlastic, FX)
		end
	end

	-- a steel I-beam column with a yellow guard at its foot (+ a fire extinguisher on some)
	local function column(r, side, d, extinguisher)
		local x = side * (HW - 1.3)
		D(r, "Column", V(1.2, WH, 0.3), x, WH / 2, d, STEEL, M.Metal, FX)
		for _, o in ipairs({-0.55, 0.55}) do D(r, "ColumnFlange", V(0.3, WH, 1.4), x + o, WH / 2, d, STEEL, M.Metal, FX) end
		D(r, "ColumnGuard", V(2.3, 3, 2.3), x, F + 1.5, d, YELLOW, M.SmoothPlastic, FX)
		D(r, "ColumnGuardBand", V(2.36, 0.45, 2.36), x, F + 2.3, d, STRIPE, M.SmoothPlastic, FX)
		D(r, "BasePlate", V(2.8, 0.15, 2.8), x, F + 0.08, d, STEEL_DARK, M.Metal, FX)
		if extinguisher then
			local ex = x - side * 1.05
			pillar(r, "Extinguisher", 1.7, 0.6, ex, F + 3.4, d - 0.9, RGB(205, 30, 30), M.SmoothPlastic, FX)
			D(r, "ExtinguisherHead", V(0.35, 0.35, 0.5), ex, F + 5.25, d - 0.9, RGB(30, 30, 30), M.Metal, FX)
			local sign = D(r, "FireSign", V(0.12, 1.3, 1.3), ex + side * 0.4, F + 7, d - 0.9, RGB(205, 30, 30), M.SmoothPlastic, FX)
			surfaceText(sign, (side < 0) and Enum.NormalId.Right or Enum.NormalId.Left, "FIRE", WHITE)
		end
	end

	------------------------------------------------------------------
	-- roof: deck, purlins, skylight strips, steel trusses and hanging high-bay lamps
	------------------------------------------------------------------
	local function truss(r, d)
		local yb, yt = WH - 5.5, WH - 0.9
		D(r, "TrussChord", V(HW * 2, 0.6, 0.6), 0, yb, d, STEEL, M.Metal, FX)
		D(r, "TrussChord", V(HW * 2, 0.6, 0.6), 0, yt, d, STEEL, M.Metal, FX)
		local panels = 6
		local pw = HW * 2 / panels
		local h = yt - yb
		for k = 0, panels do
			local x = -HW + k * pw
			D(r, "TrussPost", V(0.35, h, 0.35), x, (yb + yt) / 2, d, STEEL, M.Metal, FX)
			if k < panels then
				local sgn = (k < panels / 2) and 1 or -1
				D(r, "TrussWeb", V(math.sqrt(pw * pw + h * h), 0.3, 0.3), x + pw / 2, (yb + yt) / 2, d, STEEL, M.Metal, FX, CFrame.Angles(0, 0, sgn * math.atan2(h, pw)))
			end
		end
	end
	local function lamp(r, x, d)
		local y = WH - 7.5
		local cable = D(r, "LampCable", V(0.1, 7, 0.1), x, WH - 3.5, d, RGB(40, 40, 44), M.Metal, FX)
		pillar(r, "LampHousing", 1.1, 2.0, x, y, d, RGB(72, 76, 84), M.Metal, FX)
		pillar(r, "LampReflector", 0.7, 3.4, x, y - 0.6, d, RGB(150, 156, 166), M.Metal, FX)
		disc(r, "LampLens", 0.15, 3.0, x, y - 0.65, d, LAMP, M.Neon, FX)
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Color = LAMP
		sl.Range = 60
		sl.Angle = 110
		sl.Brightness = 1.6
		sl.Parent = cable
	end
	local function roof(r, SLen, frames)
		D(r, "Ceiling", V(HW * 2 + 4, 1.2, SLen + 0.2), 0, WH + 0.6, SLen / 2, RGB(92, 96, 104), M.Metal)
		for _, x in ipairs({-31.5, -10.5, 10.5, 31.5}) do D(r, "Purlin", V(0.5, 0.8, SLen), x, WH - 0.4, SLen / 2, STEEL, M.Metal, FX) end
		for _, x in ipairs({-21, 21}) do
			local sky = D(r, "Skylight", V(7, 0.2, SLen - 8), x, WH - 0.05, SLen / 2, RGB(232, 244, 255), M.Neon, FX)
			sky.Transparency = 0.2
			for _, o in ipairs({-3.7, 3.7}) do D(r, "SkylightFrame", V(0.4, 0.5, SLen - 8), x + o, WH - 0.25, SLen / 2, STEEL_DARK, M.Metal, FX) end
		end
		for _, d in ipairs(frames) do truss(r, d) end
		for d = 12, SLen - 6, 24 do
			for _, x in ipairs({-17, 17}) do lamp(r, x, d) end
		end
	end

	------------------------------------------------------------------
	-- pallets, wrapped stock and pallet racking
	------------------------------------------------------------------
	local function pallet(r, x, y, d, size)
		local s = size or 1
		for _, k in ipairs({-1, 0, 1}) do D(r, "PalletRunner", V(6 * s, 0.35, 0.8), x, y + 0.18, d + k * 2.4 * s, WOOD_DARK, M.WoodPlanks, FX) end
		for k = -2, 2 do D(r, "PalletSlat", V(1, 0.25, 6 * s), x + k * 1.25 * s, y + 0.48, d, WOOD, M.WoodPlanks, FX) end
	end
	-- a pallet of cardboard boxes, stretch-wrapped (+ tape lines and a shipping label)
	local function load(r, x, y, d, w, h, tint)
		local col = tint and CARD:Lerp(tint, 0.25) or CARD
		D(r, "StockPallet", V(w + 0.2, 0.45, w + 0.2), x, y + 0.23, d, WOOD_DARK, M.WoodPlanks, FX)
		D(r, "Stock", V(w, h, w), x, y + 0.45 + h / 2, d, col, M.SmoothPlastic, FX)
		D(r, "StockTape", V(0.4, h + 0.04, w + 0.04), x, y + 0.45 + h / 2, d, TAPE, M.SmoothPlastic, FX)
		local wrap = D(r, "StretchWrap", V(w + 0.15, h * 0.85, w + 0.15), x, y + 0.45 + h * 0.48, d, RGB(235, 240, 245), M.Glass, FX)
		wrap.Transparency = 0.7
	end
	-- orange beams, blue upright frames with zig-zag bracing, steel decks; boxes spawn on levels 1-2
	local function rack(r, side, d1, d2, spots, tint)
		local x = side * (HW - 3)
		local len = d2 - d1
		local dMid = (d1 + d2) / 2
		local xf, xb = x - side * 2.1, x + side * 2.1
		for _, d in ipairs({d1, dMid, d2}) do
			for _, px in ipairs({xf, xb}) do D(r, "RackPost", V(0.45, 13.6, 0.45), px, F + 6.8, d, RACK_BLUE, M.Metal, FX) end
		end
		for _, d in ipairs({d1, d2}) do -- the end frames are braced
			for _, y in ipairs({1.0, 13.2}) do D(r, "RackBrace", V(4.2, 0.18, 0.18), x, F + y, d, RACK_BLUE, M.Metal, FX) end
			for k = 0, 2 do
				local h = 4.07
				D(r, "RackBrace", V(math.sqrt(4.2 * 4.2 + h * h), 0.16, 0.16), x, F + 1.0 + h * (k + 0.5), d, RACK_BLUE, M.Metal, FX,
					CFrame.Angles(0, 0, ((k % 2 == 0) and 1 or -1) * math.atan2(h, 4.2)))
			end
		end
		for li, y in ipairs(LEVELS) do
			for _, px in ipairs({xf, xb}) do D(r, "RackBeam", V(0.35, 0.7, len), px, F + y - 0.2, dMid, RACK_ORANGE, M.Metal, FX) end
			D(r, "ShelfBoard", V(4.4, 0.25, len), x, F + y + 0.07, dMid, DECK, M.DiamondPlate, FX)
			if li == 1 then D(r, "RackLabel", V(0.06, 0.42, 1.4), xf - side * 0.2, F + y - 0.2, d1 + 1.6, RGB(250, 250, 250), M.SmoothPlastic, FX) end
			if li == #LEVELS then -- the top level holds wrapped stock (boxes only spawn on the lower two)
				for _, f in ipairs({0.27, 0.73}) do load(r, x, F + y + 0.2, d1 + len * f, 3.6, 2.4, tint) end
			end
		end
		for _, sp in ipairs(spots) do
			local p = D(r, "Spawn", V(2, 0.2, 2), x, F + LEVELS[sp[1]] + 0.2, sp[2], RGB(255, 255, 0), nil, GHOST)
			p:SetAttribute("Area", r.index)
			p:SetAttribute("Shelf", true)
			p.Parent = spawns
		end
	end

	------------------------------------------------------------------
	-- a parked forklift: body, counterweight, overhead guard, mast, forks, wheels, beacon
	------------------------------------------------------------------
	local function forklift(r, x, d, yaw)
		local base = SCF(r, x, F, d) * CFrame.Angles(0, yaw, 0)
		local Y, G2, BK = RGB(250, 186, 22), RGB(58, 60, 66), RGB(26, 26, 30)
		piece(r, base, "ForkliftBody", V(3.2, 1.3, 4.6), 0, 1.25, 0.2, Y, M.SmoothPlastic)
		piece(r, base, "ForkliftHood", V(2.7, 0.9, 1.9), 0, 2.3, 1.2, Y, M.SmoothPlastic)
		piece(r, base, "ForkliftWeight", V(3.3, 1.9, 1.2), 0, 1.6, 2.6, G2, M.Metal)
		for k = 0, 2 do piece(r, base, "ForkliftChevron", V(0.5, 1.5, 0.08), -1.1 + k * 1.1, 1.6, 3.22, (k % 2 == 0) and Y or BK, M.SmoothPlastic) end
		piece(r, base, "ForkliftSeat", V(1.3, 0.45, 1.1), 0, 2.95, 0.1, BK, M.Fabric)
		piece(r, base, "ForkliftSeatBack", V(1.3, 1.1, 0.3), 0, 3.6, 0.65, BK, M.Fabric)
		piece(r, base, "ForkliftColumn", V(0.25, 1.4, 0.25), 0, 2.6, -1.0, G2, M.Metal, nil, CFrame.Angles(math.rad(-20), 0, 0))
		piece(r, base, "ForkliftWheel", V(0.15, 0.9, 0.9), 0, 3.3, -0.85, BK, M.SmoothPlastic, "cyl", CFrame.Angles(math.rad(-70), 0, math.rad(90)))
		for _, px in ipairs({-1.45, 1.45}) do
			for _, pz in ipairs({-1.0, 1.7}) do piece(r, base, "GuardPost", V(0.2, 3.4, 0.2), px, 3.5, pz, G2, M.Metal) end
			piece(r, base, "Headlight", V(0.35, 0.35, 0.15), px, 4.8, -1.12, RGB(255, 250, 225), M.Neon)
		end
		piece(r, base, "GuardRoof", V(3.1, 0.2, 2.9), 0, 5.25, 0.35, G2, M.Metal)
		for k = -1, 1 do piece(r, base, "GuardSlat", V(0.12, 0.12, 2.9), k * 0.9, 5.4, 0.35, BK, M.Metal) end
		piece(r, base, "Beacon", V(0.45, 0.4, 0.45), 0, 5.6, 1.4, RGB(255, 140, 20), M.Neon)
		for _, px in ipairs({-0.95, 0.95}) do piece(r, base, "MastRail", V(0.3, 5.4, 0.45), px, 2.9, -2.35, G2, M.Metal) end
		piece(r, base, "MastTop", V(2.2, 0.3, 0.45), 0, 5.5, -2.35, G2, M.Metal)
		piece(r, base, "Carriage", V(2.5, 1.1, 0.25), 0, 1.0, -2.7, BK, M.Metal)
		for _, px in ipairs({-0.65, 0.65}) do
			piece(r, base, "ForkUpright", V(0.35, 1.1, 0.15), px, 0.85, -2.9, BK, M.Metal)
			piece(r, base, "Fork", V(0.35, 0.15, 3.3), px, 0.38, -4.5, BK, M.Metal)
		end
		for _, w in ipairs({{-1.5, 0.75, -1.4, 1.5}, {1.5, 0.75, -1.4, 1.5}, {-1.45, 0.6, 1.9, 1.2}, {1.45, 0.6, 1.9, 1.2}}) do
			piece(r, base, "Tyre", V(0.65, w[4], w[4]), w[1], w[2], w[3], BK, M.SmoothPlastic, "cyl")
			piece(r, base, "Hub", V(0.68, w[4] * 0.5, w[4] * 0.5), w[1], w[2], w[3], RGB(200, 200, 205), M.Metal, "cyl")
		end
	end
	local function bollard(r, x, d)
		pillar(r, "Bollard", 3.2, 0.9, x, F, d, YELLOW, M.SmoothPlastic, FX)
		for _, y in ipairs({1.1, 2.3}) do disc(r, "BollardBand", 0.35, 0.95, x, F + y, d, STRIPE, M.SmoothPlastic, FX) end
		disc(r, "BollardCap", 0.2, 0.7, x, F + 3.25, d, STRIPE, M.SmoothPlastic, FX)
	end
	local function palletStack(r, x, d, n)
		for k = 0, n - 1 do
			D(r, "StackedPallet", V(6, 0.32, 6), x, F + 0.16 + k * 0.62, d, (k % 2 == 0) and WOOD or WOOD_DARK, M.WoodPlanks, FX)
			D(r, "StackedPalletGap", V(5.6, 0.3, 5.6), x, F + 0.47 + k * 0.62, d, WOOD_DARK:Lerp(RGB(0, 0, 0), 0.3), M.WoodPlanks, FX)
		end
	end

	------------------------------------------------------------------
	-- department signs: one hanging over the entrance, one on each wall
	------------------------------------------------------------------
	local function deptSign(part, face, areaIndex, area, acc)
		local sg = surfaceGui(part, face, 14, 260)
		local band = Instance.new("Frame")
		band.BorderSizePixel = 0
		band.BackgroundColor3 = acc
		band.Size = UDim2.fromScale(1, 0.14)
		band.Position = UDim2.fromScale(0, 0.86)
		band.Parent = sg
		local num = textLabel(sg, "AREA " .. areaIndex, acc, 3)
		num.Size = UDim2.fromScale(0.9, 0.28)
		num.Position = UDim2.fromScale(0.05, 0.06)
		local name = textLabel(sg, string.upper(area.name), WHITE, 4)
		name.Size = UDim2.fromScale(0.94, 0.48)
		name.Position = UDim2.fromScale(0.03, 0.34)
	end

	for areaIndex, area in ipairs(Config.Areas) do
		SL = Config.AreaLen(areaIndex) / SC -- (this area's length: harder areas are longer)
		local SLen = SL
		local r = {index = areaIndex, z0 = Config.AreaStartZ(areaIndex), folder = Instance.new("Model")}
		r.folder.Name = "Area" .. areaIndex .. "_" .. area.name:gsub(" ", "")
		r.folder.Parent = wh
		local acc = area.accent

		floor(r, SLen)
		walls(r, SLen, acc)
		-- rack layout (the box spawn spots are the same as before)
		local racks = {{6, 20, {{1, 9}, {1, 17}, {2, 13}}}, {30, 42, {{1, 33}, {1, 39}}}}
		for d0 = 54, SLen - 16, 26 do table.insert(racks, {d0, d0 + 12, {{1, d0 + 3}, {2, d0 + 9}}}) end
		for _, rk in ipairs(racks) do
			for _, side in ipairs({-1, 1}) do rack(r, side, rk[1], rk[2], rk[3], acc) end
		end
		-- columns + roof frames sit in the gaps between the racks
		local frames = {1.2}
		for i = 1, #racks - 1 do table.insert(frames, (racks[i][2] + racks[i + 1][1]) / 2) end
		if SLen - racks[#racks][2] > 6 then table.insert(frames, (racks[#racks][2] + SLen) / 2) end
		for i, d in ipairs(frames) do
			for _, side in ipairs({-1, 1}) do column(r, side, d, i % 2 == 0) end
		end
		roof(r, SLen, frames)
		bollard(r, -(HW - 6.8), 4.6)
		bollard(r, HW - 6.8, 4.6)

		-- the hanging department sign over the entrance + a sign on each wall
		local sign = D(r, "DeptSign", V(30, 6, 0.5), 0, WH - 9.5, 3, RGB(28, 32, 40), M.SmoothPlastic, FX)
		D(r, "DeptSignFrame", V(30.8, 6.8, 0.3), 0, WH - 9.5, 3.1, acc, M.SmoothPlastic, FX)
		for _, x in ipairs({-12, 12}) do D(r, "SignCable", V(0.1, 6, 0.1), x, WH - 3.5, 3, RGB(40, 40, 44), M.Metal, FX) end
		deptSign(sign, Enum.NormalId.Back, areaIndex, area, acc)
		deptSign(sign, Enum.NormalId.Front, areaIndex, area, acc)
		for _, side in ipairs({-1, 1}) do
			local ws = D(r, "WallSign", V(0.3, 5, 20), side * (HW - 0.45), F + 18, SLen * 0.5, RGB(28, 32, 40), M.SmoothPlastic, FX)
			deptSign(ws, (side < 0) and Enum.NormalId.Right or Enum.NormalId.Left, areaIndex, area, acc)
		end

		-- the recommended speed for this area, on a safety sign by the entrance
		local rec = D(r, "SpeedSign", V(7, 3.2, 0.3), -26, F + 4.6, 1.6, RGB(255, 196, 0), M.SmoothPlastic, FX)
		D(r, "SpeedSignBorder", V(7.4, 3.6, 0.2), -26, F + 4.6, 1.75, STRIPE, M.SmoothPlastic, FX)
		for _, x in ipairs({-28.6, -23.4}) do D(r, "SpeedSignPost", V(0.3, 3.2, 0.3), x, F + 1.6, 1.75, STEEL, M.Metal, FX) end
		surfaceText(rec, Enum.NormalId.Back, (areaIndex > 1) and (Config.FormatNum(Config.RecommendedPoints(areaIndex)) .. " SPEED\nrecommended") or "START HERE!", RGB(30, 30, 34))

		-- the 2 pallets in the open aisle for the big ones (Huge / Giant boxes only spawn here)
		for _, x in ipairs({-12, 12}) do
			pallet(r, x, F, 30)
			for _, e in ipairs({{0, 4.4, 8.8, 0.35}, {0, -4.4, 8.8, 0.35}, {4.4, 0, 0.35, 8.8}, {-4.4, 0, 0.35, 8.8}}) do
				D(r, "PalletZone", V(e[3], 0.06, e[4]), x + e[1], F + 0.02, 30 + e[2], YELLOW, M.SmoothPlastic, FX)
			end
			local p = D(r, "Spawn", V(2, 0.2, 2), x, F + 0.62, 30, RGB(255, 255, 0), nil, GHOST)
			p:SetAttribute("Area", areaIndex)
			p.Parent = spawns
		end

		-- a parked forklift and a stack of empty pallets at the back
		local fs = (areaIndex % 2 == 0) and 1 or -1
		forklift(r, fs * 24, SLen - 9, math.rad(fs * 90))
		palletStack(r, -fs * 24, SLen - 8, 4 + areaIndex % 3)

		-- the guardian sleeps in the middle, facing the entrance
		makeGuardian(areaIndex, SCF(r, 0, 0, SLen * 0.45).Position, acc)
	end
end
WAREHOUSE_BAYS()


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
local SQUARE = 6 -- the first bases start right by the warehouse
local PLOT_Z = {SQUARE + CW / 2, SQUARE + CW * 1.5 + 6, SQUARE + CW * 2.5 + 12}

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
	local floor = PP("PlotFloor", V(CW, 0.4, CD), 0, 0.2, CD / 2, RGB(100, 215, 65))
	floor.TopSurface = Enum.SurfaceType.Studs
	floor:SetAttribute("Placeable", true)
	local TILE_N = 8
	local ts = CW / TILE_N
	for i = 0, TILE_N - 1 do
		for j = 0, TILE_N - 1 do
			if (i + j) % 2 == 0 then
				PP("FloorTile", V(ts, 0.06, ts), -HU + ts * (i + 0.5), 0.43, ts * (j + 0.5), RGB(125, 228, 80), nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
			end
		end
	end
	-- a chunky wooden fence all around (open in the middle of the front for the gate)
	local function fence(u0, w0, u1, w1)
		local a, b = W(u0, 0, w0).Position, W(u1, 0, w1).Position
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 1.2
		local cf = CFrame.lookAt(mid, mid + (b - a).Unit)
		local WOOD, WOOD_DARK = RGB(170, 110, 62), RGB(128, 80, 44)
		P(m, "FenceRail", V(0.7, 0.9, len), cf + V(0, 1.6, 0), WOOD, nil, NOHIT)
		P(m, "FenceRail", V(0.7, 0.9, len), cf + V(0, 3.3, 0), WOOD, nil, NOHIT)
		local posts = math.max(1, math.floor(len / 9))
		for k = 0, posts do
			local pos = a:Lerp(b, k / posts)
			P(m, "FencePost", V(1.3, 4.6, 1.3), CFrame.new(pos + V(0, 2.3, 0)), WOOD_DARK, nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
		end
	end
	-- THE UPGRADES BOARD: a big wooden sign behind the front fence. The owner's client puts the
	-- bouncy upgrade cards on it (both sides), everyone else sees "UPGRADES".
	-- (on the right side of the plot, facing the middle; the posts stand just outside the board)
	local TURN = CFrame.Angles(0, math.rad(90), 0)
	for _, w in ipairs({55.6, 80.4}) do
		PP("UpgradeBoardPost", V(1.4, 15, 1.4), 44, 7.5, w, RGB(128, 80, 44)).TopSurface = Enum.SurfaceType.Studs
	end
	local ub = PP("UpgradeBoard", V(22, 11, 0.8), 44, 10, 68, RGB(176, 116, 66), nil, nil, TURN)
	PP("UpgradeBoardTrim", V(23.2, 0.9, 1.3), 44, 15.9, 68, RGB(128, 80, 44), nil, nil, TURN).TopSurface = Enum.SurfaceType.Studs
	PP("UpgradeBoardTrim", V(23.2, 0.9, 1.3), 44, 4.1, 68, RGB(128, 80, 44), nil, nil, TURN)
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		signText(ub, face, "UPGRADES", 30, 4, 200)
	end
	fence(-HU, 0, -12, 0)
	fence(12, 0, HU, 0)
	fence(-HU, 0, -HU, CD)
	fence(HU, 0, HU, CD)
	fence(-HU, CD, HU, CD)

	PP("SpawnPoint", V(2, 0.2, 2), -18, 0.6, 10, RGB(0, 0, 0), nil, GHOST)

	-- THE SHOP: rows of podiums on dirt strips (9 across x 5 rows = 45 slots, slot 1 front-left)
	local COLS, ROWS = 9, 5
	for r = 0, ROWS - 1 do
		local w = 50 + r * 9
		PP("DirtRow", V(CW - 6, 0.08, 7.4), 0, 0.45, w, RGB(226, 186, 122), nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
		for c = 0, COLS - 1 do
			local s = r * COLS + c + 1
			local u = -38 + c * 9.5
			-- round podiums: the square Stand stays as an invisible anchor (items sit on its top),
			-- the round disc on it is what you see (the server colours both)
			local UPR = CFrame.Angles(0, 0, math.rad(90))
			PP("Podium", V(2, 5, 5), u, 1.2, w, RGB(150, 156, 172), nil, nil, UPR).Shape = Enum.PartType.Cylinder
			PP("PodiumRim", V(0.3, 5.5, 5.5), u, 2.1, w, glow, M.Neon, NOHIT, UPR).Shape = Enum.PartType.Cylinder
			PP("StandDisc" .. s, V(0.4, 5.8, 5.8), u, 2.4, w, RGB(245, 245, 250), nil, NOHIT, UPR).Shape = Enum.PartType.Cylinder
			local stand = PP("Stand" .. s, V(5.8, 0.4, 5.8), u, 2.4, w, RGB(245, 245, 250), nil, {Transparency = 1})
			stand.TopSurface = Enum.SurfaceType.Studs
			stand:SetAttribute("Slot", s)
			PP("StandTop" .. s, V(5.8, 0.5, 0.4), u, 1.6, w - 2.75, glow, M.Neon, NOHIT)
		end
	end
	PP("GlowStrip", V(1, 0.2, 1), 0, -2, 50, glow, M.Neon, GHOST)
	-- the EXPAND PLOT sign: a big standing board right beside the gate (seen from the street and
	-- from inside). The owner's client puts a bouncy "EXPAND $X" button on it; click to buy the
	-- next podium slot (the server writes the price for everyone else)
	for _, u in ipairs({-23.4, -12.6}) do
		PP("ExpandPost", V(1.2, 9.4, 1.2), u, 4.7, 3, RGB(128, 80, 44)).TopSurface = Enum.SurfaceType.Studs
	end
	local pad = PP("ExpandPad", V(10, 6.4, 0.7), -18, 5.6, 3, RGB(60, 190, 70))
	PP("ExpandTrim", V(11, 0.7, 1), -18, 9.1, 3, RGB(128, 80, 44), nil, NOHIT).TopSurface = Enum.SurfaceType.Studs
	PP("ExpandTrim", V(11, 0.7, 1), -18, 2.1, 3, RGB(128, 80, 44), nil, NOHIT)
	local padClick = Instance.new("ClickDetector")
	padClick.Name = "ExpandClick"
	padClick.MaxActivationDistance = 60
	padClick.Parent = pad
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local sg = surfaceGui(pad, face, 40, 160)
		sg.Name = (face == Enum.NormalId.Front) and "ExpandGui" or "ExpandGuiBack"
		local t1 = textLabel(sg, "EXPAND PLOT", WHITE, 4)
		t1.Name = "Title"
		t1.Position = UDim2.fromScale(0.05, 0.06)
		t1.Size = UDim2.fromScale(0.9, 0.3)
		local t2 = textLabel(sg, "", RGB(255, 240, 120), 4)
		t2.Name = "Price"
		t2.Position = UDim2.fromScale(0.1, 0.48)
		t2.Size = UDim2.fromScale(0.8, 0.36)
	end
	-- a wooden SHOP board at the back
	for _, u in ipairs({-11, 11}) do PP("ShopSignPost", V(1.2, 9, 1.2), u, 4.5, 91, RGB(128, 80, 44)) end
	local shopSign = PP("ShopSign", V(24, 5, 0.8), 0, 8.6, 91, RGB(170, 110, 62))
	signText(shopSign, Enum.NormalId.Back, "SHOP", 40, 4, 200)

	-- TREADMILL (right front corner): run on the belt to earn speed, upgrade at the console
	do
		local TU = 34                 -- centre of the treadmill (sideways)
		local W0, W1 = 15, 35         -- belt from w 15 (console end) to w 35
		local metal, darkMetal = RGB(70, 74, 86), RGB(40, 42, 50)
		PP("TreadBase", V(11, 0.8, W1 - W0 + 4), TU, 0.8, (W0 + W1) / 2, metal, M.Metal)
		local CYL = Enum.PartType.Cylinder
		local ALONG = CFrame.Angles(0, math.rad(90), 0) -- a cylinder lying along the belt
		local STAND = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up
		for _, sd in ipairs({-1, 1}) do
			-- chunky rounded side rails in the base colour with a glowing strip under them
			PP("TreadRail", V(W1 - W0 + 4, 1.6, 1.6), TU + sd * 5.2, 1.6, (W0 + W1) / 2, col, nil, nil, ALONG).Shape = CYL
			PP("TreadGlow", V(0.3, 0.3, W1 - W0 + 3), TU + sd * 5.6, 0.55, (W0 + W1) / 2, glow, M.Neon, NOHIT)
			-- side handles to hold on to while you run (up front, beside the phone)
			for _, w in ipairs({W0 + 1, W0 + 9}) do
				PP("TreadPost", V(4, 0.6, 0.6), TU + sd * 5.2, 4, w, RGB(60, 64, 78), M.Metal, NOHIT, STAND).Shape = CYL
				PP("TreadKnob", V(1, 1, 1), TU + sd * 5.2, 6, w, col:Lerp(WHITE, 0.25), nil, NOHIT).Shape = Enum.PartType.Ball
			end
			PP("TreadHandle", V(9, 0.7, 0.7), TU + sd * 5.2, 6, W0 + 5, col:Lerp(WHITE, 0.25), nil, NOHIT, ALONG).Shape = CYL
		end
		-- glowing speed chevrons on the base behind the belt
		for k = 0, 2 do
			PP("TreadArrow", V(2.4 - k * 0.6, 0.08, 2.4 - k * 0.6), TU, 1.22 + k * 0.01, W1 + 1.2, glow:Lerp(WHITE, k * 0.3), M.Neon, NOHIT, CFrame.Angles(0, math.rad(45), 0))
		end
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
		-- THE PHONE stands at the front of the belt, so you can play while you run
		do
			local pw = W0 - 1.6
			local ALONG_W = CFrame.Angles(0, math.rad(90), 0) -- a cylinder lying front-to-back
			-- chrome stand: a round foot and a short arm
			local foot = PP("PhoneStand", V(0.8, 6, 6), TU, 0.6, pw - 0.6, RGB(190, 195, 210), M.Metal, nil, CFrame.Angles(0, 0, math.rad(90)))
			foot.Shape = Enum.PartType.Cylinder
			foot:SetAttribute("Solid", true)
			PP("PhoneArm", V(1.6, 2.4, 1), TU, 2.1, pw - 0.6, RGB(170, 175, 190), M.Metal, NOHIT)
			-- the case (in the base colour) with rounded corners
			PP("PhoneBody", V(9, 13.4, 1.2), TU, 9.6, pw, col):SetAttribute("Solid", true)
			PP("PhoneEdge", V(7.4, 15, 1.2), TU, 9.6, pw, col, nil, NOHIT)
			for _, cx in ipairs({-3.7, 3.7}) do
				for _, cy in ipairs({2.9, 16.3}) do
					PP("PhoneCorner", V(1.2, 1.6, 1.6), TU + cx, cy, pw, col, nil, NOHIT, ALONG_W).Shape = Enum.PartType.Cylinder
				end
			end
			-- side buttons
			PP("PhoneButton", V(0.3, 2, 0.5), TU + 4.6, 13, pw, col:Lerp(RGB(0, 0, 0), 0.25), nil, NOHIT)
			PP("PhoneButton", V(0.3, 1.2, 0.5), TU - 4.6, 14, pw, col:Lerp(RGB(0, 0, 0), 0.25), nil, NOHIT)
			-- black bezel, the glowing screen and the camera notch
			PP("PhoneBezel", V(8.4, 14.4, 0.1), TU, 9.6, pw + 0.62, RGB(15, 15, 20), nil, NOHIT)
			local screen = PP("PhoneScreen", V(7.8, 13.2, 0.1), TU, 9.5, pw + 0.68, RGB(40, 60, 140), nil, NOHIT)
			PP("PhoneNotch", V(2.4, 0.6, 0.08), TU, 16.5, pw + 0.72, RGB(5, 5, 8), nil, NOHIT)
			do
				local l = Instance.new("PointLight")
				l.Color = RGB(130, 170, 255)
				l.Range = 12
				l.Brightness = 1.2
				l.Parent = screen
				-- a little home screen: wallpaper, clock, app icons and a TAP TO PLAY pill
				local sg = surfaceGui(screen, Enum.NormalId.Front, 40, 140)
				local bg = Instance.new("Frame")
				bg.Size = UDim2.fromScale(1, 1)
				bg.BackgroundColor3 = WHITE
				bg.Parent = sg
				local bgg = Instance.new("UIGradient")
				bgg.Rotation = 120
				bgg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, RGB(90, 120, 255)), ColorSequenceKeypoint.new(0.5, RGB(190, 90, 255)), ColorSequenceKeypoint.new(1, RGB(255, 120, 170))})
				bgg.Parent = bg
				local clock = textLabel(bg, "12:00", WHITE, 3)
				clock.Position = UDim2.fromScale(0.1, 0.05)
				clock.Size = UDim2.fromScale(0.8, 0.12)
				local APP = {{"🐍", RGB(80, 220, 90)}, {"💥", RGB(255, 140, 40)}, {"🎯", RGB(255, 80, 90)}, {"🧱", RGB(70, 170, 255)},
					{"🐦", RGB(255, 210, 60)}, {"🔢", RGB(170, 110, 255)}, {"🔨", RGB(255, 110, 190)}, {"🧺", RGB(60, 220, 200)}, {"🎮", RGB(120, 130, 150)}}
				for k, a in ipairs(APP) do
					local cx, cy = (k - 1) % 3, math.floor((k - 1) / 3)
					local icon = Instance.new("Frame")
					icon.Position = UDim2.fromScale(0.1 + cx * 0.28, 0.22 + cy * 0.18)
					icon.Size = UDim2.fromScale(0.24, 0.14)
					icon.BackgroundColor3 = a[2]
					icon.Parent = bg
					local ic = Instance.new("UICorner")
					ic.CornerRadius = UDim.new(0.28, 0)
					ic.Parent = icon
					local ist = Instance.new("UIStroke")
					ist.Thickness = 3
					ist.Color = RGB(30, 25, 50)
					ist.Parent = icon
					local emoji = Instance.new("TextLabel")
					emoji.BackgroundTransparency = 1
					emoji.Size = UDim2.fromScale(1, 1)
					emoji.Text = a[1]
					emoji.TextScaled = true
					emoji.Parent = icon
				end
				local pill = Instance.new("Frame")
				pill.Position = UDim2.fromScale(0.12, 0.8)
				pill.Size = UDim2.fromScale(0.76, 0.11)
				pill.BackgroundColor3 = RGB(80, 220, 70)
				pill.Parent = bg
				local pc = Instance.new("UICorner")
				pc.CornerRadius = UDim.new(1, 0)
				pc.Parent = pill
				local pst = Instance.new("UIStroke")
				pst.Thickness = 4
				pst.Color = RGB(30, 25, 50)
				pst.Parent = pill
				local tap = textLabel(pill, "TAP TO PLAY", WHITE, 3)
				tap.Size = UDim2.fromScale(0.9, 0.8)
				tap.Position = UDim2.fromScale(0.05, 0.1)
			end
			-- click (or tap) the screen to play
			screen.CanQuery = true
			local click = Instance.new("ClickDetector")
			click.Name = "PhoneClick"
			click.MaxActivationDistance = 40
			click.Parent = screen
		end
		-- the upgrade is just a sign beside the belt: "UPGRADE" and the price (the server keeps it current)
		local su, sw = TU - 10, W0 + 3
		for _, sd in ipairs({-1, 1}) do
			PP("TreadSignPole", V(0.5, 4, 0.5), su + sd * 3, 2, sw, darkMetal, M.Metal)
		end
		local sign = upgradeSign("TreadConsole", "TreadTag", V(7.4, 4, 0.4), su, 5.6, sw,
			"UPGRADE", "$" .. Config.FormatNum(Config.TreadmillCost(1)), Config.LevelText(1, Config.Treadmill.max) .. "  +" .. Config.FormatNum(Config.TreadRate(1)) .. "/s")
		-- (each player's client puts a bouncy UPGRADE button on their own sign)
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
-- LIFE: round cartoon trees, bushes, flowers, lamps with bunting, a fountain, crates at the
-- door, hills and clouds outside. All decoration: you walk through it and it never blocks anything.
------------------------------------------------------------------
do
	local deco = folder(root, "Decor")
	local DECO = {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}
	local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up
	local function D(name, size, cf, color, shape, mat)
		local p = P(deco, name, size, cf, color, mat, DECO)
		if shape then p.Shape = shape end
		return p
	end
	local LEAVES = {RGB(70, 190, 60), RGB(95, 210, 70), RGB(55, 165, 75), RGB(125, 220, 80)}
	local BLOSSOM = RGB(255, 170, 205)
	local FLOWERS = {RGB(255, 120, 170), RGB(255, 220, 60), RGB(255, 255, 255), RGB(180, 120, 255), RGB(255, 140, 60)}
	local function pick(t) return t[math.random(1, #t)] end

	local function tree(x, z, s, simple)
		s = s or 1
		local leaf = (math.random() < 0.15) and BLOSSOM or pick(LEAVES)
		D("TreeTrunk", V(10 * s, 2.4 * s, 2.4 * s), C(x, 5 * s, z) * UP, RGB(140, 90, 50), CYL)
		D("TreeTop", V(11 * s, 11 * s, 11 * s), C(x, 12 * s, z), leaf, BALL)
		D("TreeTop", V(8 * s, 8 * s, 8 * s), C(x + 3.5 * s, 10 * s, z + 1.5 * s), leaf:Lerp(WHITE, 0.12), BALL)
		if not simple then
			D("TreeTop", V(7.5 * s, 7.5 * s, 7.5 * s), C(x - 3 * s, 10.5 * s, z - 2 * s), leaf:Lerp(RGB(0, 0, 0), 0.1), BALL)
		end
	end
	local function bush(x, z, s)
		s = s or 1
		local c = pick(LEAVES)
		D("Bush", V(5 * s, 5 * s, 5 * s), C(x, 1.6 * s, z), c, BALL)
		D("Bush", V(3.6 * s, 3.6 * s, 3.6 * s), C(x + 2.4 * s, 1.2 * s, z + 0.8 * s), c:Lerp(WHITE, 0.1), BALL)
		if math.random() < 0.7 then
			D("BushFlower", V(1.1, 1.1, 1.1), C(x + 0.6 * s, 3.9 * s, z - 0.6 * s), pick(FLOWERS), BALL)
		end
	end
	local function flowers(x0, z0, x1, z1, n)
		for _ = 1, n do
			D("Flower", V(1.3, 1.3, 1.3), C(x0 + math.random() * (x1 - x0), 0.5, z0 + math.random() * (z1 - z0)), pick(FLOWERS), BALL)
		end
	end
	local LAMP = RGB(45, 60, 85)
	local function lamp(x, z, light)
		D("LampBase", V(1.2, 1.8, 1.8), C(x, 0.6, z) * UP, LAMP, CYL)
		D("LampPole", V(14, 0.7, 0.7), C(x, 7, z) * UP, LAMP, CYL)
		local globe = D("LampGlobe", V(2.6, 2.6, 2.6), C(x, 14.8, z), RGB(255, 236, 170), BALL, M.Neon)
		D("LampCap", V(0.6, 3, 3), C(x, 16.3, z) * UP, LAMP, CYL)
		if light then
			local l = Instance.new("PointLight")
			l.Color = RGB(255, 225, 160)
			l.Range = 30
			l.Brightness = 1
			l.Shadows = false
			l.Parent = globe
		end
	end
	-- lamps on both sides of the street
	local GAP1 = (PLOT_Z[1] + PLOT_Z[2]) / 2
	local GAP2 = (PLOT_Z[2] + PLOT_Z[3]) / 2
	local PLOTS_END = PLOT_Z[3] + CW / 2
	for i, z in ipairs({SQUARE - 4, GAP1, GAP2, PLOTS_END + 3}) do
		lamp(-18, z, i % 2 == 1)
		lamp(18, z, i % 2 == 0)
	end

	-- bushes in the alleys between the bases
	for _, z in ipairs({GAP1, GAP2}) do
		for _, sx in ipairs({-1, 1}) do
			for _, x in ipairs({30, 62, 94}) do bush(sx * x, z, 0.9) end
		end
	end

	local WOOD = RGB(170, 110, 60) -- (benches)
	-- THE BACK (behind the spawn): a fountain at the end of the street, trees, benches, flowers
	do
		local fz = COURT_LEN - 11
		local STONE = RGB(228, 222, 240)
		D("FountainRim", V(1.6, 15, 15), C(0, 0.8, fz) * UP, STONE, CYL)
		local water = D("FountainWater", V(1.7, 13, 13), C(0, 0.85, fz) * UP, RGB(90, 200, 255), CYL)
		water.Transparency = 0.15
		D("FountainPillar", V(6, 1.8, 1.8), C(0, 3, fz) * UP, STONE, CYL)
		D("FountainBowl", V(0.8, 6.5, 6.5), C(0, 6, fz) * UP, STONE, CYL)
		D("FountainWater", V(0.85, 5.5, 5.5), C(0, 6.05, fz) * UP, RGB(90, 200, 255), CYL)
		local jet = D("FountainJet", V(2, 2, 2), C(0, 7.2, fz), RGB(170, 230, 255), BALL, M.Neon)
		local splash = Instance.new("ParticleEmitter")
		splash.Color = ColorSequence.new(RGB(200, 240, 255))
		splash.Size = NumberSequence.new(0.5, 0.2)
		splash.Transparency = NumberSequence.new(0.2, 1)
		splash.Lifetime = NumberRange.new(0.8, 1.2)
		splash.Rate = 18
		splash.Speed = NumberRange.new(9, 12)
		splash.SpreadAngle = Vector2.new(18, 18)
		splash.Acceleration = V(0, -25, 0)
		splash.Parent = jet
		for _, sx in ipairs({-1, 1}) do
			D("BenchSeat", V(2.2, 0.5, 7), C(sx * 12, 2, fz), WOOD, nil, M.WoodPlanks)
			D("BenchBack", V(0.4, 2.2, 7), C(sx * 13.1, 3.3, fz), WOOD, nil, M.WoodPlanks)
			for _, dz in ipairs({-3, 3}) do D("BenchLeg", V(1.8, 1.8, 0.5), C(sx * 12, 0.9, fz + dz), LAMP) end
		end
	end
	for _, sx in ipairs({-1, 1}) do
		for _, x in ipairs({76, 92, 106}) do tree(sx * x + math.random(-2, 2), COURT_LEN - 9 + math.random(-2, 2), 0.9 + math.random() * 0.3) end
		for _, x in ipairs({34, 54, 72, 90}) do bush(sx * x, PLOTS_END + 7) end
		flowers(sx * 20, PLOTS_END + 4, sx * 108, COURT_LEN - 4, 26)
	end

	-- OUTSIDE THE WALLS: grass, rows of big trees, rolling hills and clouds
	local GRASS = RGB(100, 210, 45)
	local OUT = 120
	for _, sx in ipairs({-1, 1}) do
		D("OuterGrass", V(OUT, 1, COURT_LEN + OUT + 8), C(sx * (MAPW + 4 + OUT / 2), -0.45, (COURT_LEN + OUT) / 2), GRASS, nil, M.Grass)
	end
	D("OuterGrass", V(MAPW * 2 + 8, 1, OUT), C(0, -0.45, COURT_LEN + 4 + OUT / 2), GRASS, nil, M.Grass)
	for _, sx in ipairs({-1, 1}) do
		for z = 4, COURT_LEN + 50, 19 do
			tree(sx * (128 + math.random(-3, 3)), z + math.random(-4, 4), 1.3 + math.random() * 0.4, true)
			tree(sx * (156 + math.random(-4, 4)), z + 9 + math.random(-4, 4), 1.6 + math.random() * 0.5, true)
		end
	end
	for x = -110, 110, 22 do
		tree(x + math.random(-4, 4), COURT_LEN + 18 + math.random(-3, 3), 1.3 + math.random() * 0.4, true)
		tree(x + 11 + math.random(-4, 4), COURT_LEN + 44 + math.random(-4, 4), 1.7 + math.random() * 0.4, true)
	end
	local HILLS = {RGB(110, 200, 80), RGB(90, 185, 85), RGB(130, 210, 95)}
	for _, h in ipairs({{-270, 60, 220}, {-260, 260, 260}, {270, 120, 240}, {265, 330, 200}, {-150, 520, 260}, {40, 540, 300}, {210, 500, 240}}) do
		D("Hill", V(h[3], h[3], h[3]), C(h[1], -h[3] * 0.32, h[2]), pick(HILLS), BALL)
	end
	for _ = 1, 14 do
		local x, y, z = math.random(-320, 320), math.random(115, 160), math.random(-60, 560)
		local s = 16 + math.random() * 12
		D("Cloud", V(s, s, s), C(x, y, z), WHITE, BALL)
		D("Cloud", V(s * 0.75, s * 0.75, s * 0.75), C(x + s * 0.6, y - s * 0.12, z + 2), WHITE, BALL)
		D("Cloud", V(s * 0.7, s * 0.7, s * 0.7), C(x - s * 0.6, y - s * 0.15, z - 2), RGB(245, 248, 255), BALL)
	end
end

------------------------------------------------------------------
-- DONE: show the map
------------------------------------------------------------------
root.Parent = workspace
print("STEAL A BOX map built!")
