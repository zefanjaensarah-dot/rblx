--[[ STEAL A BOX - Server script (installed by the builder)
     One long warehouse lane with 10 themed areas. Each area has ONE sleeping guardian.
     Steal a box -> he wakes up, chases you, and if he catches you he ragdolls and FLINGS you.
     Boxes roll a mutation (Gold, Diamond, Lava, Rainbow, Galaxy) and a size (Tiny ... Giant).
     Balance numbers live in ReplicatedStorage > StealABoxConfig. ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("StealABoxConfig"))
local Shop = require(ReplicatedStorage:WaitForChild("StealABoxShop"))
local L = Config.Layout
local world = workspace:WaitForChild("StealABox")
local remotes = ReplicatedStorage:WaitForChild("StealABoxRemotes")
-- make sure every remote exists (older places were built without some of them)
for _, spec in ipairs({{"Notify", "RemoteEvent"}, {"Drop", "RemoteEvent"}, {"Sync", "RemoteEvent"}, {"Fling", "RemoteEvent"},
	{"FX", "RemoteEvent"}, {"Reveal", "RemoteEvent"}, {"PlaceBox", "RemoteEvent"}, {"ShopEvent", "RemoteEvent"}, {"Action", "RemoteFunction"}}) do
	if not remotes:FindFirstChild(spec[1]) then
		local r = Instance.new(spec[2])
		r.Name = spec[1]
		r.Parent = remotes
	end
end
local ShopEvent = remotes:WaitForChild("ShopEvent")
local NotifyEvent = remotes:WaitForChild("Notify")
local DropEvent = remotes:WaitForChild("Drop")
local SyncEvent = remotes:WaitForChild("Sync")
local ActionFunc = remotes:WaitForChild("Action")
local FlingEvent = remotes:WaitForChild("Fling")
local FXEvent = remotes:WaitForChild("FX")
local RevealEvent = remotes:WaitForChild("Reveal")
local PlaceBoxEvent = remotes:WaitForChild("PlaceBox")

------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------
local BASE_SPEED = 16
local LABEL_FONT = Config.Font -- Fredoka One, the same round font as the UI
local SPEED_PER_LEVEL = 1.2
local GUARD_RETURN_SPEED = 9
local RAGDOLL_TIME = 2.2
local MAX_DISPLAY_BOXES = 28
local LOOSE_BOX_LIFETIME = 30

local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(120, 255, 140)
local YELLOW = Color3.fromRGB(255, 230, 110)

------------------------------------------------------------------
-- STATE + HELPERS
------------------------------------------------------------------
local profiles = {}
local carrying = {}      -- [player] = {box, id, mutation, size}
local buyUpgrade, refreshTreadmill, save, applyTrail -- defined further down
local dontSave = {} -- [player] = true if their data failed to load (protects their real save)
local immuneUntil = {}
local ragdolled = {}
local playerPlot = {}
local lastWrongBase = {}
local boxSpawnOf = {}
local spawnFilled = {}

local activeBoxes = Instance.new("Folder")
activeBoxes.Name = "ActiveBoxes"
activeBoxes.Parent = world

------------------------------------------------------------------
-- COLLISION GROUPS: players run straight through shoppers and everything
-- standing in the shops / lobby (shelves, fences, kiosks, lamps...)
------------------------------------------------------------------
local PhysicsService = game:GetService("PhysicsService")
local GROUP_PLAYERS, GROUP_PASS = Config.GroupPlayers, Config.GroupPass
for _, g in ipairs({GROUP_PLAYERS, GROUP_PASS}) do
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(g) then PhysicsService:RegisterCollisionGroup(g) end
	end)
end
pcall(function() PhysicsService:CollisionGroupSetCollidable(GROUP_PLAYERS, GROUP_PASS, false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(GROUP_PASS, GROUP_PASS, false) end)

-- put a part / everything inside a model into a collision group (and keep doing it for new parts)
local function setGroup(inst, group, keepWatching)
	local function apply(p)
		if p:IsA("BasePart") then p.CollisionGroup = group end
	end
	apply(inst)
	for _, d in ipairs(inst:GetDescendants()) do apply(d) end
	if keepWatching then inst.DescendantAdded:Connect(apply) end
end

local function notify(player, text, color)
	NotifyEvent:FireClient(player, text, color or Color3.new(1, 1, 1))
end
local function notifyAll(text, color)
	NotifyEvent:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function getChar(player)
	local char = player and player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return char, hrp, hum end
	return nil
end

local function isImmune(player)
	return (immuneUntil[player] or 0) > os.clock()
end

local function groundBelow(pos, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0), params)
	if result then return result.Position end
	return pos - Vector3.new(0, 3, 0)
end

local function outline(part, thickness)
	local sb = Instance.new("SelectionBox")
	sb.Name = "Outline"
	sb.Adornee = part
	sb.Color3 = Color3.new(1, 1, 1)
	sb.LineThickness = thickness or 0.06
	sb.SurfaceTransparency = 1
	sb.Parent = part
end

local function playSound(parent, id, volume, speed)
	if string.find(id, "electronicping", 1, true) then return end -- (no more beeps)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = parent
	s:Play()
	task.delay(3, function() s:Destroy() end)
end

local function weightedPick(list)
	local total = 0
	for _, item in ipairs(list) do total = total + item.chance end
	local roll = math.random() * total
	for _, item in ipairs(list) do
		roll = roll - item.chance
		if roll <= 0 then return item end
	end
	return list[1]
end

------------------------------------------------------------------
-- PROFILES
------------------------------------------------------------------
local function newProfile()
	local p = {Cash = 0, Stolen = 0, Boxes = {}, Mutations = {}, ItemsFound = {},
		Items = {}, Unboxing = {}, Upgrades = {}, Treadmill = 1, SpeedPoints = Config.StartSpeed, TutorialDone = false,
		Trails = {}, Trail = nil, Customers = 1, SpeedBoost = 1, Receipts = {}, PayoutLevel = 1, UnboxLevel = 1,
		IndexClaimed = {}, Daily = {Streak = 0, Last = -1}, Codes = {}, Settings = {}, SaveVersion = 2, ExtraStands = 0,
		Achievements = {}, Flings = 0}
	return p
end

-- IntValues can't hold giant numbers: keep the leaderboard safe
local MAX_INT = 2 ^ 53
local function setStat(player, name, value)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	if v then v.Value = math.clamp(math.floor(tonumber(value) or 0), -MAX_INT, MAX_INT) end
end

-- cheap update for the money counter (shoppers pay all the time - no need to send the whole save)
local function syncCash(player)
	local prof = profiles[player]
	if not prof then return end
	setStat(player, "Cash", prof.Cash)
	player:SetAttribute("Cash", prof.Cash)
end

local function sync(player)
	local prof = profiles[player]
	if not prof then return end
	syncCash(player)
	player:SetAttribute("Stands", math.min(Config.MaxStands, Config.BaseStands + (prof.ExtraStands or 0)))
	SyncEvent:FireClient(player, prof)
end

-- shelf spots you can use: 8 to start, buy more with "+1 Equip"
local function unlockedStands(prof)
	return math.min(Config.MaxStands, Config.BaseStands + (prof and prof.ExtraStands or 0))
end

-- DAILY QUESTS: 3 a day (the same for everybody), progress is saved, the client reads the "Quests" attribute
local questDirty = {}
local function questState(prof)
	local day = Config.DayNumber()
	if type(prof.Quests) ~= "table" or prof.Quests.Day ~= day or type(prof.Quests.List) ~= "table" then
		local list = {}
		for i, q in ipairs(Config.QuestsForDay(day)) do list[i] = {id = q.id, goal = q.goal, progress = 0, claimed = false} end
		prof.Quests = {Day = day, List = list}
	end
	return prof.Quests
end
local function publishQuests(player)
	local prof = profiles[player]
	if not prof then return end
	local parts = {}
	for _, q in ipairs(questState(prof).List) do
		table.insert(parts, q.id .. ":" .. q.goal .. ":" .. math.floor(q.progress) .. ":" .. (q.claimed and "1" or "0"))
	end
	player:SetAttribute("Quests", table.concat(parts, ";"))
end
local function questProgress(player, id, n)
	local prof = profiles[player]
	if not prof then return end
	for _, q in ipairs(questState(prof).List) do
		if q.id == id and not q.claimed and q.progress < q.goal then
			q.progress = math.min(q.goal, q.progress + (n or 1))
			questDirty[player] = true
		end
	end
end
task.spawn(function()
	while true do
		task.wait(1)
		for player in pairs(questDirty) do
			questDirty[player] = nil
			if player.Parent then publishQuests(player) end
		end
	end
end)

-- SECRET ACHIEVEMENTS: unlocked once, with a big popup and a cash reward
local function achieve(player, id)
	local prof = profiles[player]
	local a = Config.GetAchievement(id)
	if not prof or not a then return end
	prof.Achievements = prof.Achievements or {}
	if prof.Achievements[id] then return end
	prof.Achievements[id] = true
	local cash = Config.AchievementReward(a, player:GetAttribute("Income") or 0)
	prof.Cash = prof.Cash + cash
	sync(player)
	FXEvent:FireClient(player, "Achievement", Vector3.zero, 0, a.name .. "  +$" .. Config.FormatNum(cash))
end

local slowMode = {} -- [player] = true while Slow Mode is on
local function walkSpeedFor(player, c)
	local prof = profiles[player]
	local speed = BASE_SPEED
	if prof and not slowMode[player] then
		-- your speed NUMBER (100 ... millions) turns into how fast you actually run
		speed = math.floor(Config.PointsToWalk(prof.SpeedPoints) * 10) / 10
	end
	if c then
		local def = Config.Boxes[c.id]
		speed = speed - Config.Rarities[def.rarity].slow - Config.GetSize(c.size).slow
	end
	return math.max(6, speed)
end

-- GAME PASSES: checked when you join and right after you buy one (see the ROBUX SHOP section)
local passOwned = {} -- [player] = {[passKey] = true}
local function hasPass(player, key)
	local owned = passOwned[player]
	return owned ~= nil and owned[key] == true
end

-- everything that multiplies the cash your shoppers pay: completed Index areas, VIP and 2x Cash
local function cashMultiplier(player)
	local prof = profiles[player]
	local m = Config.IndexCashMult(Config.CountClaimed(prof and prof.IndexClaimed))
	if hasPass(player, "VIP") then m = m * Config.PassEffects.VIPCash end
	if hasPass(player, "DoubleCash") then m = m * Config.PassEffects.DoubleCash end
	if ReplicatedStorage:GetAttribute("EventId") == "DoubleCash" then m = m * 2 end -- (surprise event)
	m = m * Config.PayoutMult(prof and prof.PayoutLevel) -- the Payouts upgrade
	return m
end

-- how many boxes can unbox on your plot at once
local function padLimit(player)
	return Config.UnboxPads + (hasPass(player, "BigBase") and Config.PassEffects.ExtraPads or 0)
end

-- how long a box takes to unbox for this player
local function unboxDuration(player, def, sizeId)
	local d = Config.UnboxTime(def, sizeId, 0)
	if hasPass(player, "FastUnbox") then d = math.max(1, math.floor(d * Config.PassEffects.FastUnbox + 0.5)) end
	local uprof = profiles[player]
	if uprof then d = math.max(1, math.floor(d * Config.UnboxMult(uprof.UnboxLevel) + 0.5)) end -- the Unbox Speed upgrade
	return d
end

-- the mutation table, with Server Luck (a Robux product) making mutations more likely
local function serverLuckActive()
	return (ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0) > workspace:GetServerTimeNow()
end
local function mutationTable()
	if not serverLuckActive() then return Config.Mutations end
	local list = {}
	for _, m in ipairs(Config.Mutations) do
		table.insert(list, {id = m.id, chance = (m.id == "Normal") and m.chance or m.chance * Config.ServerLuck.mult})
	end
	return list
end

-- set a player's walk speed and show it on the leaderboard / HUD
local function applySpeed(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local sp = walkSpeedFor(player, carrying[player])
	if hum then hum.WalkSpeed = sp end
	player:SetAttribute("WalkSpeed", sp)
	local prof = profiles[player]
	local points = math.floor(prof and prof.SpeedPoints or Config.StartSpeed)
	player:SetAttribute("SpeedPoints", points)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Speed") then ls.Speed.Value = points end
end

------------------------------------------------------------------
-- BOX VISUALS (shared by world boxes and base displays)
------------------------------------------------------------------
local function styleBox(box, def, mutationId, scaleMult)
	local mut = Config.GetMutation(mutationId)
	local s = box.Size.X
	box.Color = mut.color or def.color
	box.Material = def.material
	if mutationId == "Gold" then
		box.Material = Enum.Material.SmoothPlastic
		box.Reflectance = 0.35
	elseif mutationId == "Diamond" then
		box.Material = Enum.Material.Glass
		box.Transparency = 0.15
		box.Reflectance = 0.3
	elseif mutationId == "Lava" then
		box.Material = Enum.Material.CrackedLava
		local fire = Instance.new("Fire")
		fire.Size = s * 1.2
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
		fire.Parent = box
	elseif mutationId == "Rainbow" then
		box.Material = Enum.Material.SmoothPlastic
		CollectionService:AddTag(box, "RainbowBox") -- clients cycle its colour
	elseif mutationId == "Galaxy" then
		box.Material = Enum.Material.Neon
		box.Color = Color3.fromRGB(60, 20, 110)
		local stars = Instance.new("ParticleEmitter")
		stars.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 120, 255))
		stars.LightEmission = 1
		stars.Size = NumberSequence.new(0.25 * s / 2.6, 0)
		stars.Lifetime = NumberRange.new(1, 2)
		stars.Rate = 18
		stars.Speed = NumberRange.new(1, 2)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Parent = box
	end
	if mutationId ~= "Normal" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "MutationSparkle"
		sparkle.Color = ColorSequence.new(mut.color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = box
		local light = Instance.new("PointLight")
		light.Color = mut.color
		light.Range = 8 + s * 2
		light.Brightness = 1.5
		light.Parent = box
	end

	-- give the box real shape: lid, tape cross, corner rims and a printed picture
	local base = mut.color or def.color
	local dark = base:Lerp(Color3.new(0, 0, 0), 0.3)
	local tapeColor = (def.material == Enum.Material.SmoothPlastic or def.material == Enum.Material.Fabric) and Color3.fromRGB(210, 170, 110) or dark
	if mutationId ~= "Normal" then tapeColor = base:Lerp(Color3.new(1, 1, 1), 0.35) end
	local function deco(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = box.CFrame * offset
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = (mutationId == "Diamond") and 0.25 or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = box
		w.Part1 = p
		w.Parent = p
		p.Parent = box
		if mutationId == "Rainbow" then CollectionService:AddTag(p, "RainbowBox") end
		return p
	end
	local X, Y, Z = box.Size.X, box.Size.Y, box.Size.Z
	-- lid (slightly wider, darker)
	deco("Lid", Vector3.new(X * 1.04, Y * 0.12, Z * 1.04), CFrame.new(0, Y * 0.44, 0), dark, box.Material)
	-- tape: across the top and down the front and back
	deco("Tape", Vector3.new(X * 0.2, Y * 0.13, Z * 1.06), CFrame.new(0, Y * 0.445, 0), tapeColor)
	deco("TapeFront", Vector3.new(X * 0.2, Y * 0.35, Z * 0.04), CFrame.new(0, Y * 0.28, -Z * 0.51), tapeColor)
	deco("TapeBack", Vector3.new(X * 0.2, Y * 0.35, Z * 0.04), CFrame.new(0, Y * 0.28, Z * 0.51), tapeColor)
	-- corner rims: plain on common boxes, silver on rare ones, shiny gold on epic ones
	local rimCol, rimMat = dark, nil
	if def.rarity == 2 then rimCol, rimMat = Color3.fromRGB(200, 205, 215), Enum.Material.Metal end
	if def.rarity >= 3 then rimCol, rimMat = Color3.fromRGB(255, 200, 50), Enum.Material.Metal end
	for _, cx in ipairs({-1, 1}) do
		for _, cz in ipairs({-1, 1}) do
			local rim = deco("Rim", Vector3.new(X * 0.09, Y * 1.02, Z * 0.09), CFrame.new(cx * X * 0.48, 0, cz * Z * 0.48), rimCol, rimMat)
			if def.rarity >= 2 then rim.Reflectance = 0.25 end
		end
	end
	-- rare + epic: a metal band around the middle; epic: it glows, and a gold gem sits on the lid
	if def.rarity >= 2 then
		local glow = def.rarity >= 3
		deco("Band", Vector3.new(X * 1.03, Y * 0.09, Z * 1.03), CFrame.new(0, -Y * 0.12, 0),
			glow and (Config.Rarities[def.rarity].color) or Color3.fromRGB(190, 195, 205), glow and Enum.Material.Neon or Enum.Material.Metal)
	end
	if def.rarity >= 3 then
		local gem = deco("Gem", Vector3.new(X * 0.22, X * 0.22, X * 0.22), CFrame.new(0, Y * 0.56, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
		gem.Reflectance = 0.2
	end
	-- printed on the sides: a real shipping label (rarity band, name, barcode) and "this side up" arrows
	local rar = Config.Rarities[def.rarity] or Config.Rarities[1]
	local function frame(parent, props)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		for k, v in pairs(props) do f[k] = v end
		f.Parent = parent
		return f
	end
	local ink = Color3.fromRGB(45, 36, 30)
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Print"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.LightInfluence = 1
		sg.Parent = box
		if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
			local card = frame(sg, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.66, 0.44), BackgroundColor3 = Color3.fromRGB(252, 248, 236)})
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0.1, 0)
			cc.Parent = card
			local band = frame(card, {Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = rar.color})
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0.3, 0)
			bc.Parent = band
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.fromScale(0.06, 0.32)
			name.Size = UDim2.fromScale(0.88, 0.34)
			name.FontFace = LABEL_FONT
			name.TextScaled = true
			name.TextColor3 = ink
			name.Text = string.upper(def.name)
			name.Parent = card
			-- barcode: one frame with hard black/white gradient stripes
			local bar = frame(card, {Position = UDim2.fromScale(0.12, 0.7), Size = UDim2.fromScale(0.76, 0.2), BackgroundColor3 = Color3.new(1, 1, 1)})
			local keys = {}
			local x = 0
			for n = 0, 8 do -- at most 19 keypoints (Roblox allows 20)
				local w = ({0.09, 0.14, 0.06, 0.12})[(n % 4) + 1]
				local c = (n % 2 == 0) and ink or Color3.fromRGB(252, 248, 236)
				table.insert(keys, ColorSequenceKeypoint.new(x, c))
				local e = math.min(0.99, x + w)
				table.insert(keys, ColorSequenceKeypoint.new(e, c))
				x = e + 0.002
				if x >= 0.985 then break end
			end
			table.insert(keys, ColorSequenceKeypoint.new(1, keys[#keys].Value))
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(keys)
			g.Parent = bar
		else
			-- two "this side up" arrows, like on a real moving box
			for k = 0, 1 do
				local cx = 0.36 + k * 0.28
				frame(sg, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(cx, 0.46), Size = UDim2.fromScale(0.07, 0.3), BackgroundColor3 = ink, BackgroundTransparency = 0.15})
				local head = frame(sg, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, 0.44), Size = UDim2.fromScale(0.17, 0.17), Rotation = 45, BackgroundColor3 = ink, BackgroundTransparency = 0.15})
				local ar = Instance.new("UIAspectRatioConstraint")
				ar.Parent = head
			end
			frame(sg, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.5, 0.05), BackgroundColor3 = rar.color})
		end
	end
end

------------------------------------------------------------------
-- BOXES
------------------------------------------------------------------
local pickUp
local alertGuard -- defined in the guard section
local openBox, clearPlotVisuals
local openingNow = {} -- [unboxing entry] = true while its opening animation plays
local OPEN_TIME = 2.2  -- seconds of charging-up VFX before the item pops out
local REVEAL_TIME = 4.1 -- the 3D item hovers, then flies to the shelf; the shelf updates after this

local function makeBox(boxId, bottomPos, mutationId, sizeId)
	local def = Config.Boxes[boxId]
	local sizeDef = Config.GetSize(sizeId)
	local s = (2.4 + def.rarity * 0.25) * sizeDef.scale * Config.Layout.scale
	local box = Instance.new("Part")
	box.Name = def.id
	box.Size = Vector3.new(s, s, s)
	box.Anchored = true
	box.CanCollide = true
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	box.CFrame = CFrame.new(bottomPos + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, math.rad(math.random(-15, 15)), 0)
	box:SetAttribute("BoxId", def.id)
	box:SetAttribute("Mutation", mutationId)
	box:SetAttribute("Size", sizeId)
	outline(box, 0.05 + s * 0.012)
	styleBox(box, def, mutationId)

	-- floating tag only for special boxes (no prices!)
	if mutationId ~= "Normal" or sizeId ~= "Normal" then
		local mut = Config.GetMutation(mutationId)
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromScale(4.6, 0.85) -- in studs (shrinks with distance)
		bb.StudsOffset = Vector3.new(0, s / 2 + 1.5, 0)
		bb.MaxDistance = 45
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.FontFace = LABEL_FONT
		tl.TextScaled = true
		tl.TextColor3 = mut.color or Color3.new(1, 1, 1)
		local words = {}
		if mutationId ~= "Normal" then table.insert(words, string.upper(mutationId)) end
		if sizeId ~= "Normal" then table.insert(words, string.upper(sizeId)) end
		tl.Text = table.concat(words, " • ")
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Parent = tl
		tl.Parent = bb
		bb.Parent = box
		if mutationId == "Rainbow" then CollectionService:AddTag(tl, "RainbowText") end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = Config.BoxLabel(def, mutationId, sizeId)
	local hold = Config.Rarities[def.rarity].hold * (0.8 + sizeDef.scale * 0.2)
	prompt.HoldDuration = hold
	prompt:SetAttribute("BaseHold", hold)
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player) pickUp(player, box) end)

	box.Parent = activeBoxes
	return box
end

local function spawnBox(sp, forcedMutation)
	if not sp.Parent or spawnFilled[sp] then return nil end
	local area = Config.Areas[sp:GetAttribute("Area")] or Config.Areas[1]
	local weights = {}
	for r, b in ipairs(area.boxes) do table.insert(weights, {chance = Config.Rarities[r].weight, def = b}) end
	local def = weightedPick(weights).def
	local mutation = forcedMutation or weightedPick(mutationTable()).id
	local sizeDef = weightedPick(Config.Sizes)
	if sp:GetAttribute("Shelf") then
		-- big boxes don't fit on shelves
		while table.find(Config.Sizes, sizeDef) > Config.ShelfMaxSize do sizeDef = weightedPick(Config.Sizes) end
	end
	local box = makeBox(def.id, sp.Position, mutation, sizeDef.id)
	boxSpawnOf[box] = sp
	spawnFilled[sp] = box
	FXEvent:FireAllClients("Spawn", box.Position, box.Size.X)
	return box
end

local function releaseCarry(player, dropPos)
	local c = carrying[player]
	if not c then return end
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarryLabel", nil)
	player:SetAttribute("CarrySize", nil)
	if c.box then c.box:Destroy() end
	applySpeed(player)
	if dropPos then
		local loose = makeBox(c.id, dropPos, c.mutation, c.size)
		task.delay(LOOSE_BOX_LIFETIME, function()
			if loose.Parent and not loose:GetAttribute("Taken") then loose:Destroy() end
		end)
	end
end

pickUp = function(player, box)
	if box:GetAttribute("Taken") or not box.Parent or ragdolled[player] then return end
	if carrying[player] then
		notify(player, "Hands full! Stash that box first (or press G to drop it).", RED)
		return
	end
	local char, hrp, hum = getChar(player)
	if not char then return end
	local c = {id = box:GetAttribute("BoxId"), mutation = box:GetAttribute("Mutation") or "Normal", size = box:GetAttribute("Size") or "Normal",
		pickedAt = os.clock(), pickedPos = hrp.Position}
	local def = Config.Boxes[c.id]
	box:SetAttribute("Taken", true)
	local prompt = box:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt:Destroy() end
	local tag = box:FindFirstChild("Tag")
	if tag then tag.Enabled = false end

	local sp = boxSpawnOf[box]
	if sp then
		boxSpawnOf[box] = nil
		spawnFilled[sp] = nil
		-- it only comes back at night (at nightfall every empty spot restocks)
		task.delay(6 + def.area + def.rarity * 3, function()
			if ReplicatedStorage:GetAttribute("IsNight") and not spawnFilled[sp] then spawnBox(sp) end
		end)
	end

	-- hold the box in front of you
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Massless = true
	box.CFrame = hrp.CFrame * CFrame.new(0, 0.4 + math.max(0, box.Size.Y / 2 - 2.5), -(0.8 + box.Size.Z / 2))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = box
	weld.Parent = box
	box.Parent = char
	box.Anchored = false
	c.box = box

	carrying[player] = c
	applySpeed(player)
	player:SetAttribute("CarryLabel", Config.BoxLabel(def, c.mutation, c.size))
	player:SetAttribute("CarrySize", math.min(6, (2.4 + def.rarity * 0.25) * Config.GetSize(c.size).scale * Config.Layout.scale))
	player:SetAttribute("Carrying", c.id)
	playSound(hrp, "rbxasset://sounds/electronicpingshort.wav", 0.7, 1.3)
	FXEvent:FireAllClients("Grab", box.Position, box.Size.X)

	-- wake up the guardian of this area!
	local area = Config.ZoneAt(hrp.Position)
	if area then alertGuard(area, player) end
end

local boxSpawns = {}
for _, sp in ipairs(world:WaitForChild("BoxSpawns"):GetChildren()) do
	if sp:IsA("BasePart") then
		table.insert(boxSpawns, sp)
		spawnBox(sp)
	end
end

DropEvent.OnServerEvent:Connect(function(player)
	if not carrying[player] then return end
	local char, hrp = getChar(player)
	local dropAt = nil
	if hrp then dropAt = groundBelow((hrp.CFrame * CFrame.new(0, 0, -3)).Position, {char}) end
	releaseCarry(player, dropAt)
	notify(player, "You dropped the box.", YELLOW)
end)

------------------------------------------------------------------
-- BASES
------------------------------------------------------------------
local plotsFolder = world:WaitForChild("Plots")
local lobbySpawn = world:FindFirstChild("LobbySpawn")

local function sortedPlots()
	local list = plotsFolder:GetChildren()
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end

local function setOwnerVisuals(plot, player)
	local sign = plot:FindFirstChild("SignBoard")
	if sign then
		local vip = player ~= nil and hasPass(player, "VIP")
		for _, g in ipairs(sign:GetChildren()) do
			if g:IsA("SurfaceGui") and g:FindFirstChild("Label") then
				g.Label.Text = player and ((vip and "VIP " or "") .. player.DisplayName .. "'s Base") or "Empty Base"
				g.Label.TextColor3 = vip and Color3.fromRGB(255, 215, 60) or Color3.new(1, 1, 1)
			end
		end
	end
	local anchor = plot:FindFirstChild("TagAnchor")
	local tag = anchor and anchor:FindFirstChild("OwnerTag")
	if tag then
		tag.Enabled = player ~= nil
		if player then
			tag.Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
			tag.PlayerName.Text = player.DisplayName
		end
	end
end

local function assignPlot(player)
	for _, plot in ipairs(sortedPlots()) do
		if plot:GetAttribute("Owner") == 0 then
			plot:SetAttribute("Owner", player.UserId)
			playerPlot[player] = plot
			setOwnerVisuals(plot, player)
			player:SetAttribute("PlotName", plot.Name)
			return plot
		end
	end
	return nil
end

local function freePlot(player)
	local plot = playerPlot[player]
	if not plot then return end
	playerPlot[player] = nil
	plot:SetAttribute("Owner", 0)
	setOwnerVisuals(plot, nil)
	clearPlotVisuals(plot)
end

-- upgrade signs (treadmill / kiosk) are flat boards with text on both sides
local function setSign(plot, signName, levelText, rateText)
	local sign = plot and plot:FindFirstChild(signName, true)
	if not sign then return end
	for _, g in ipairs(sign:GetChildren()) do
		if (g:IsA("SurfaceGui") or g:IsA("BillboardGui")) and g:FindFirstChild("Level") then
			g.Level.Text = levelText
			if g:FindFirstChild("Rate") then g.Rate.Text = rateText end
		end
	end
end

-- a "+$123" that floats up and fades out. The server only creates it: every client animates it
-- on its own screen (smooth, and no network traffic for every frame of the animation).
local function popText(part, text, color, y0, x0)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PopText"
	bb.Size = UDim2.fromScale(3.2, 0.8) -- in studs: shrinks with distance, never piles up on screen
	bb.StudsOffset = Vector3.new(x0 or 0, y0 or 3, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	bb:SetAttribute("Y0", y0 or 3)
	bb:SetAttribute("X0", x0 or 0)
	local tl = Instance.new("TextLabel")
	tl.Name = "Label"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.FontFace = LABEL_FONT
	tl.TextScaled = true
	tl.TextColor3 = color
	tl.Text = text
	local st = Instance.new("UIStroke")
	st.Thickness = 1.5
	st.Parent = tl
	tl.Parent = bb
	bb.Parent = part
	CollectionService:AddTag(bb, "PopText")
	Debris:AddItem(bb, 1)
end

local function sendTo(player, pos)
	local char = player.Character
	if char and pos then char:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0))) end
end

local function sendHome(player)
	local plot = playerPlot[player]
	local sp = plot and plot:FindFirstChild("SpawnPoint")
	if sp then sendTo(player, sp.Position)
	elseif lobbySpawn then sendTo(player, lobbySpawn.Position) end
end

------------------------------------------------------------------
-- UNBOXING PADS + SHOP STANDS + REGISTER
------------------------------------------------------------------
local function now() return workspace:GetServerTimeNow() end

local function billboard(parent, name, size, offset, alwaysOnTop)
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = size
	bb.StudsOffset = offset
	bb.AlwaysOnTop = alwaysOnTop or false
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = parent
	return bb
end
local function label(parent, name, text, color, size, pos, strokeSize)
	local tl = Instance.new("TextLabel")
	tl.Name = name
	tl.BackgroundTransparency = 1
	tl.FontFace = LABEL_FONT
	tl.TextScaled = true
	tl.TextColor3 = color
	tl.Text = Config.StripEmoji(text)
	tl.Size = size or UDim2.fromScale(1, 1)
	tl.Position = pos or UDim2.new()
	local st = Instance.new("UIStroke")
	st.Thickness = strokeSize or 2.5
	st.Parent = tl
	tl.Parent = parent
	return tl
end


-- draw the boxes placed on the plot floor
local function plotFrame(plot)
	local o = plot:FindFirstChild("PlotOrigin")
	return o and o.CFrame or CFrame.new()
end
local function unboxFolder(plot)
	local f = plot:FindFirstChild("Unboxing")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Unboxing"
		f.Parent = plot
	end
	return f
end
local function boxSizeFor(entry)
	local def = Config.Boxes[entry.id]
	return math.min(6, (2.4 + def.rarity * 0.25) * Config.GetSize(entry.size).scale * Config.Layout.scale)
end

local function refreshPads(player)
	local plot, prof = playerPlot[player], profiles[player]
	if not plot or not prof then return end
	local folderU = unboxFolder(plot)
	folderU:ClearAllChildren()
	local frame = plotFrame(plot)
	for key, entry in pairs(prof.Unboxing) do
		local def = Config.Boxes[entry.id]
		if def then
			local sz = boxSizeFor(entry)
			local box = Instance.new("Part")
			box.Name = "UnboxBox" .. key
			box.Size = Vector3.new(sz, sz, sz)
			box.Anchored = true
			box.CanCollide = false
			box.TopSurface = Enum.SurfaceType.Smooth
			box.BottomSurface = Enum.SurfaceType.Smooth
			box.CFrame = frame * CFrame.new(entry.u or 0, 0.4 + sz / 2, -(entry.w or 30)) * CFrame.Angles(0, math.rad(entry.rot or 0), 0)
			box:SetAttribute("ReadyAt", entry.readyAt)
			box:SetAttribute("Duration", entry.duration)
			box:SetAttribute("Owner", player.UserId)
			box:SetAttribute("Key", key)
			box:SetAttribute("BaseCF", box.CFrame)
			box.Parent = folderU
			outline(box, 0.06)
			styleBox(box, def, entry.mutation)
			CollectionService:AddTag(box, "UnboxingBox")
			-- timer above the box. The box name only shows on the box you're closest to (the client
			-- decides), so the names of boxes standing next to each other never pile up.
			local bb = billboard(box, "Timer", UDim2.fromScale(4.2, 1.35), Vector3.new(0, sz / 2 + 1.6, 0), false)
			bb.MaxDistance = 70
			local nameL = label(bb, "Name", Config.BoxLabel(def, entry.mutation, entry.size), Config.GetMutation(entry.mutation).color or Color3.new(1, 1, 1), UDim2.fromScale(1, 0.44), nil, 2)
			nameL.Visible = false
			local barBack = Instance.new("Frame")
			barBack.Name = "Bar"
			barBack.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
			barBack.Position = UDim2.fromScale(0.06, 0.52)
			barBack.Size = UDim2.fromScale(0.88, 0.46)
			barBack.Parent = bb
			local c1 = Instance.new("UICorner")
			c1.CornerRadius = UDim.new(0.5, 0)
			c1.Parent = barBack
			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
			fill.Size = UDim2.fromScale(0, 1)
			fill.Parent = barBack
			local c2 = Instance.new("UICorner")
			c2.CornerRadius = UDim.new(0.5, 0)
			c2.Parent = fill
			label(barBack, "Time", "", Color3.new(1, 1, 1), UDim2.fromScale(1, 1), nil, 2).ZIndex = 2
			if openingNow[entry] then box:SetAttribute("Opening", true) end
			if now() >= entry.readyAt and not openingNow[entry] then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Open!"
				prompt.ObjectText = def.name
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = box
				local k = key
				prompt.Triggered:Connect(function(who)
					if who ~= player then
						notify(who, "That's not your box!", RED)
						return
					end
					openBox(player, k)
				end)
			end
		end
	end
end

-- show items on the shop stands
-- where a product's 3D model stands on a shelf slot (facing the shoppers)
local function shelfModelCF(stand, item)
	local sc = Config.ShelfItemScale(item)
	return stand.CFrame * CFrame.new(0, 0.15 + 1.05 * sc, 0) * CFrame.Angles(0, math.pi, 0), sc
end
local function shelfFolder(plot)
	local f = plot:FindFirstChild("ShelfModels")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ShelfModels"
		f.Parent = plot
	end
	return f
end

-- the Expand Plot pad shows the price of the next slot
local function refreshExpandPad(player)
	local plot, prof = playerPlot[player], profiles[player]
	local pad = plot and plot:FindFirstChild("ExpandPad", true)
	local price = pad and pad:FindFirstChild("ExpandGui") and pad.ExpandGui:FindFirstChild("Price")
	if price and prof then
		local have = unlockedStands(prof)
		price.Text = (have >= Config.MaxStands) and "MAXED" or ("$" .. Config.FormatNum(Config.StandCost(have)))
	end
end

local function refreshStands(player)
	local plot, prof = playerPlot[player], profiles[player]
	if not plot or not prof then return end
	shelfFolder(plot):ClearAllChildren()
	local onStand = {}
	for i, item in ipairs(prof.Items) do
		if item.stand then onStand[item.stand] = i end
	end
	local unlocked = unlockedStands(prof)
	refreshExpandPad(player)
	for s = 1, Config.MaxStands do
		local stand = plot:FindFirstChild("Stand" .. s)
		local top = plot:FindFirstChild("StandTop" .. s)
		if stand then
			for _, c in ipairs(stand:GetChildren()) do
				if c.Name == "ItemTag" or c:IsA("ProximityPrompt") or c:IsA("ParticleEmitter") then c:Destroy() end
			end
			if top then CollectionService:RemoveTag(top, "RainbowBox") end
			local idx = onStand[s]
			if s > unlocked then
				stand.Color = Color3.fromRGB(90, 90, 100)
				if top then top.Color = Color3.fromRGB(60, 60, 70) end -- locked spot (grey): buy it with "+1 Equip"
				if s == unlocked + 1 then -- the next slot you can buy shows its price
					local bb = billboard(stand, "ItemTag", UDim2.fromScale(6, 2.4), Vector3.new(0, 2.8, 0))
					bb.MaxDistance = 70
					label(bb, "Name", "Slot " .. s, Color3.new(1, 1, 1), UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0), 2)
					label(bb, "Income", "$" .. Config.FormatNum(Config.StandCost(unlocked)), Color3.fromRGB(124, 255, 106), UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.5), 2.5)
				end
			elseif idx then
				local item = prof.Items[idx]
				local def = Config.Items[item.id]
				local mut = Config.GetMutation(item.mutation)
				stand.Color = Color3.fromRGB(245, 245, 250)
				if top then
					top.Color = mut.color or Config.ItemTiers[def.tier].color
					if item.mutation == "Rainbow" then CollectionService:AddTag(top, "RainbowBox") end
				end
				-- the product itself, as a slowly spinning 3D model on the shelf
				local cf, sc = shelfModelCF(stand, item)
				local model = Config.BuildItemModel(item, sc, cf)
				model.Name = "Shelf" .. s
				model:SetAttribute("BaseCF", cf)
				model.Parent = shelfFolder(plot)
				CollectionService:AddTag(model, "ShelfItem")
				if item.mutation == "Rainbow" then
					for _, p in ipairs(model:GetChildren()) do CollectionService:AddTag(p, "RainbowBox") end
				end
				-- name + $/s tag. It starts hidden: each client only shows the tag of the ONE product
				-- you're standing closest to (45 tags on a shelf would pile up into unreadable text)
				local bb = billboard(stand, "ItemTag", UDim2.fromScale(4.4, 1.2), Vector3.new(0, 0.9 + 2.1 * sc, 1))
				bb.MaxDistance = 30
				bb.Enabled = false
				label(bb, "Name", Config.ItemLabel(item), mut.color or Config.ItemTiers[def.tier].color, UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0), 2)
				label(bb, "Income", "$" .. Config.FormatNum(Config.ItemIncome(item)) .. "/s", Color3.fromRGB(124, 255, 106), UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.5), 2.5)
				CollectionService:AddTag(bb, "ShelfTag")
				if item.mutation ~= "Normal" then
					local e = Instance.new("ParticleEmitter")
					e.Color = ColorSequence.new(mut.color)
					e.LightEmission = 1
					e.Size = NumberSequence.new(0.3, 0)
					e.Lifetime = NumberRange.new(0.8, 1.4)
					e.Rate = 8
					e.Speed = NumberRange.new(1.5)
					e.SpreadAngle = Vector2.new(60, 60)
					e.EmissionDirection = Enum.NormalId.Right
					e.Parent = stand
				end
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Take back"
				prompt.ObjectText = def.name
				prompt.HoldDuration = 0.4
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = stand
				prompt.Triggered:Connect(function(who)
					if who ~= player then return end
					local p2 = profiles[player]
					if p2 and p2.Items[idx] and p2.Items[idx].stand == s then
						p2.Items[idx].stand = nil
						refreshStands(player)
						sync(player)
						notify(player, "Moved " .. Config.ItemLabel(item) .. " to your backpack.", YELLOW)
					end
				end)
			else
				stand.Color = Color3.fromRGB(245, 245, 250)
				local plotCol = plot:FindFirstChild("GlowStrip")
				if top then top.Color = plotCol and plotCol.Color or Color3.fromRGB(200, 200, 200) end
				-- empty spot: just the glowing strip, no label (45 spots would be too busy)
			end
		end
	end
end

local function freeStand(prof)
	local used = {}
	for _, it in ipairs(prof.Items) do if it.stand then used[it.stand] = true end end
	for s = 1, unlockedStands(prof) do
		if not used[s] then return s end
	end
	return nil
end

-- what your shop earns per second: products on display x kiosk (more shoppers) x Index rewards / passes.
-- This is exactly what you get paid (shoppers pay everything the shop earned since the last sale).
local function totalIncome(player)
	local prof = profiles[player]
	if not prof then return 0 end
	local income = 0
	for _, item in ipairs(prof.Items) do
		if item.stand and item.stand <= unlockedStands(prof) then
			income = income + Config.ItemIncome(item)
		end
	end
	return math.floor(income * Config.CustomerRate(prof.Customers or 1) * cashMultiplier(player))
end

-- roll the item inside a box
local function rollItem(boxDef, mutation, size)
	local list = {}
	for tier, t in ipairs(Config.ItemTiers) do
		table.insert(list, {chance = t.weights[boxDef.rarity], tier = tier})
	end
	local tier = weightedPick(list).tier
	local itemId = Config.AreaItems[boxDef.area][tier][1]
	return {id = itemId, mutation = mutation, size = size}
end

openBox = function(player, slot)
	local prof, plot = profiles[player], playerPlot[player]
	if not prof or not plot then return end
	local entry = prof.Unboxing[slot]
	if not entry or now() < entry.readyAt or openingNow[entry] then return end
	if #prof.Items >= Config.MaxItems then
		notify(player, "Your backpack is full! Sell some items first.", RED)
		return
	end
	local boxDef = Config.Boxes[entry.id]
	local item = rollItem(boxDef, entry.mutation, entry.size)
	local tier = Config.Items[item.id].tier
	-- better items charge up longer (the client climbs through the rarity colours one by one)
	local openTime = Config.OpenTimes[tier] or OPEN_TIME
	-- 1) build-up: the box shakes, glows and shoots light beams (client VFX)
	openingNow[entry] = true
	local boxPart = unboxFolder(plot):FindFirstChild("UnboxBox" .. slot)
	if boxPart then
		local prompt = boxPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then prompt:Destroy() end
		boxPart:SetAttribute("Opening", true)
		boxPart:SetAttribute("OpenMutation", item.mutation)
		FXEvent:FireAllClients("Opening", boxPart.Position, tier, boxPart, openTime)
		playSound(boxPart, "rbxasset://sounds/electronicpingshort.wav", 0.6, 0.6)
	end
	-- 2) after the build-up the box bursts and the item is revealed
	task.delay(openTime, function()
		openingNow[entry] = nil
		if not player.Parent or profiles[player] ~= prof or prof.Unboxing[slot] ~= entry then return end
		if #prof.Items >= Config.MaxItems then
			notify(player, "Your backpack is full! Sell some items first.", RED)
			refreshPads(player)
			return
		end
		prof.Unboxing[slot] = nil
		table.insert(prof.Items, item)
		questProgress(player, "open")
		if (Config.Items[item.id].tier or 1) >= 3 then questProgress(player, "rare") end
		if (Config.Items[item.id].tier or 1) >= 4 then achieve(player, "Legendary") end
		if item.mutation == "Galaxy" then achieve(player, "Galaxy") end
		prof.ItemsFound[item.id] = (prof.ItemsFound[item.id] or 0) + 1
		local itemDef = Config.Items[item.id]
		if prof.ItemsFound[item.id] == 1 and itemDef and Config.AreaComplete(prof.ItemsFound, itemDef.area) then
			local doneArea = Config.Areas[itemDef.area]
			task.delay(Config.RevealTime(itemDef.tier), function()
				notify(player, doneArea.name .. " Index complete! Claim your reward in the Index!", doneArea.accent)
			end)
		end
		local s = freeStand(prof)
		if s then item.stand = s end
		local part = unboxFolder(plot):FindFirstChild("UnboxBox" .. slot)
		local revealPos = part and part.Position or plotFrame(plot).Position
		-- the item pops out as a 3D model, spins, then flies to its shelf slot (or into your backpack)
		local target, targetScale = nil, nil
		local stand = s and plot:FindFirstChild("Stand" .. s)
		if stand then target, targetScale = shelfModelCF(stand, item) end
		FXEvent:FireAllClients("Reveal3D", revealPos, tier, {item = item, target = target, targetScale = targetScale, owner = player.UserId})
		if part then playSound(part, "rbxasset://sounds/electronicpingshort.wav", 1, 1.2) end
		refreshPads(player)
		sync(player)
		RevealEvent:FireClient(player, item, s ~= nil)
		-- the shelf shows the product once the flying model has landed
		task.delay(Config.RevealTime(tier), function() if player.Parent then refreshStands(player) end end)
		local def = Config.Items[item.id]
		if def.tier == 4 or item.mutation == "Rainbow" or item.mutation == "Galaxy" then
			notifyAll(player.DisplayName .. " unboxed a " .. Config.ItemTiers[def.tier].name .. " " .. Config.ItemLabel(item) .. "!", Config.ItemTiers[def.tier].color)
		end
	end)
end

-- where on a plot boxes may be placed (plot-local): open floor in front of the shop shelf
local PLACE_U = Config.Court.plotWidth / 2 - 4
local PLACE_W_MIN, PLACE_W_MAX = 5, 40 -- (the Expand pad sits at w 44, the podium rows start at w 46)

local function placeBoxAt(player, worldPos)
	local prof, c, plot = profiles[player], carrying[player], playerPlot[player]
	if not prof or not c or not plot or typeof(worldPos) ~= "Vector3" then return end
	local _, hrp = getChar(player)
	if not hrp or (hrp.Position - worldPos).Magnitude > 90 then return end
	-- anti-teleport: you can't get home faster than your legs allow (generous margin for lag + jumps)
	if c.pickedPos then
		local elapsed = os.clock() - (c.pickedAt or 0)
		local flat = Vector3.new(hrp.Position.X - c.pickedPos.X, 0, hrp.Position.Z - c.pickedPos.Z).Magnitude
		local topSpeed = Config.PointsToWalk(prof.SpeedPoints) + 8 -- ignores Slow Mode on purpose
		if flat > topSpeed * elapsed * 1.6 + 60 then
			warn("[Steal a Box] " .. player.Name .. " moved a box too fast (" .. math.floor(flat) .. " studs in " .. string.format("%.1f", elapsed) .. "s)")
			releaseCarry(player)
			notify(player, "Whoa, too fast! The box fell apart.", RED)
			return
		end
	end
	local lp = plotFrame(plot):PointToObjectSpace(worldPos)
	local u, w = lp.X, -lp.Z
	local function nope(msg)
		if (lastWrongBase[player] or 0) + 1.5 < os.clock() then
			lastWrongBase[player] = os.clock()
			notify(player, msg, RED)
		end
	end
	if math.abs(u) > PLACE_U or w < PLACE_W_MIN or w > PLACE_W_MAX then
		return nope("Click on the open floor of YOUR plot to place the box!")
	end
	if u > 26 and w < 42 then
		return nope("That spot is for your treadmill - place the box somewhere else!")
	end
	if u < -26 and w < 15 then
		return nope("That spot is for your customer kiosk - place the box somewhere else!")
	end
	local count = 0
	local newSize = boxSizeFor(c)
	for _, e in pairs(prof.Unboxing) do
		count = count + 1
		local d = math.sqrt(((e.u or 0) - u) ^ 2 + ((e.w or 0) - w) ^ 2)
		-- keep a little gap so the timers above the boxes don't overlap
		if d < (boxSizeFor(e) + newSize) / 2 + 2 then return nope("Too close to another box!") end
	end
	local limit = padLimit(player)
	if count >= limit then
		return nope("You can only unbox " .. limit .. " boxes at once - open one first!")
	end
	local key
	for k = 1, 99 do
		if not prof.Unboxing[tostring(k)] then key = tostring(k) break end
	end
	if not key then return end
	local def = Config.Boxes[c.id]
	-- Lucky Hands (game pass): a plain box gets an extra roll for a mutation
	if c.mutation == "Normal" and hasPass(player, "Lucky") then
		for _ = 1, Config.PassEffects.LuckyRerolls do
			local roll = weightedPick(mutationTable()).id
			if roll ~= "Normal" then
				c.mutation = roll
				notify(player, "LUCKY! Your box turned " .. string.upper(roll) .. "!", Config.GetMutation(roll).color)
				break
			end
		end
	end
	local duration = unboxDuration(player, def, c.size)
	if (prof.Stolen or 0) == 0 then duration = math.min(duration, 5) end -- the tutorial's first box is quick
	prof.Unboxing[key] = {id = c.id, mutation = c.mutation, size = c.size, readyAt = now() + duration, duration = duration,
		u = math.floor(u * 10) / 10, w = math.floor(w * 10) / 10, rot = math.random(-20, 20)}
	prof.Stolen = prof.Stolen + 1
	questProgress(player, "steal")
	if def.area >= 3 then questProgress(player, "deep") end
	if prof.Stolen >= 1 then achieve(player, "FirstSteal") end
	if prof.Stolen >= 25 then achieve(player, "Steal25") end
	if prof.Stolen >= 100 then achieve(player, "Steal100") end
	if prof.Stolen >= 500 then achieve(player, "Steal500") end
	if def.area >= 5 then achieve(player, "Deep5") end
	if def.area >= 10 then achieve(player, "Deep10") end
	prof.Boxes[def.id] = (prof.Boxes[def.id] or 0) + 1
	prof.Mutations[c.mutation] = (prof.Mutations[c.mutation] or 0) + 1
	if prof.Boxes[def.id] == 1 then
		notify(player, "NEW in your Index: " .. def.emoji .. " " .. def.name .. "!", def.color)
	end
	local label2 = Config.BoxLabel(def, c.mutation, c.size)
	releaseCarry(player)
	refreshPads(player)
	sync(player)
	FXEvent:FireAllClients("Stash", worldPos, 4)
	local placed = unboxFolder(plot):FindFirstChild("UnboxBox" .. key)
	if placed then playSound(placed, "rbxasset://sounds/electronicpingshort.wav", 0.8, 0.8) end
	local mins = math.floor(duration / 60)
	notify(player, label2 .. " is unboxing! Ready in " .. (mins > 0 and (mins .. "m ") or "") .. (duration % 60) .. "s", GREEN)
end

PlaceBoxEvent.OnServerEvent:Connect(placeBoxAt)

------------------------------------------------------------------
-- PLAYTIME GIFTS: claim free cash / boxes the longer you play
------------------------------------------------------------------
local giftStart = {}   -- [player] = server time when the current gift round started
local giftClaimed = {} -- [player] = {[index] = true}

-- find an open spot on the plot floor for a box of this size (nil if the plot is full)
local function freePlotSpot(prof, size)
	local spots = {}
	for w = PLACE_W_MIN + 4, PLACE_W_MAX - 4, 6 do
		for u = -PLACE_U + 4, PLACE_U - 4, 6 do
			local blocked = (u > 26 and w < 42) or (u < -26 and w < 15)
			if not blocked then
				for _, e in pairs(prof.Unboxing) do
					local d = math.sqrt(((e.u or 0) - u) ^ 2 + ((e.w or 0) - w) ^ 2)
					if d < (boxSizeFor(e) + size) / 2 + 2 then blocked = true break end
				end
			end
			if not blocked then table.insert(spots, {u, w}) end
		end
	end
	if #spots == 0 then return nil end
	-- prefer spots near the front middle of the plot so you see your gift
	table.sort(spots, function(a, b) return math.abs(a[1]) + a[2] * 0.6 < math.abs(b[1]) + b[2] * 0.6 end)
	local pickN = math.min(#spots, 6)
	local sp = spots[math.random(1, pickN)]
	return sp[1], sp[2]
end

local function giftState(player)
	local start = giftStart[player] or now()
	local claimed = giftClaimed[player] or {}
	return {start = start, claimed = claimed}
end

local function syncGifts(player)
	player:SetAttribute("GiftStart", giftStart[player])
	local list = {}
	for i in pairs(giftClaimed[player] or {}) do table.insert(list, tostring(i)) end
	player:SetAttribute("GiftClaimed", table.concat(list, ","))
end

-- the deepest warehouse area you've stolen from (free boxes come from there)
local function bestArea(prof)
	local best = 1
	for id in pairs(prof.Boxes or {}) do
		local def = Config.Boxes[id]
		if def and def.area > best then best = def.area end
	end
	return best
end

-- put a free box on the player's plot (gifts, daily rewards, codes, the Lucky Box).
-- areaIdx = which warehouse area it comes from, forcedMutation = nil for a normal random roll
local function giveBox(player, prof, areaIdx, forcedMutation)
	local plot = playerPlot[player]
	if not plot then return nil, "You need a plot to get a box!" end
	local count = 0
	for _ in pairs(prof.Unboxing) do count = count + 1 end
	if count >= padLimit(player) then return nil, "Your plot is full of boxes - open one first!" end
	local area = Config.Areas[math.clamp(math.floor(areaIdx or 1), 1, #Config.Areas)]
	local weights = {}
	for r, b in ipairs(area.boxes) do table.insert(weights, {chance = Config.Rarities[r].weight, def = b}) end
	local def = weightedPick(weights).def
	local mutation = forcedMutation or weightedPick(mutationTable()).id
	local sizeDef = weightedPick(Config.Sizes)
	while table.find(Config.Sizes, sizeDef) > Config.ShelfMaxSize do sizeDef = weightedPick(Config.Sizes) end
	local entry = {id = def.id, mutation = mutation, size = sizeDef.id}
	local u, w = freePlotSpot(prof, boxSizeFor(entry))
	if not u then return nil, "No room on your plot - open a box first!" end
	local key
	for k = 1, 99 do
		if not prof.Unboxing[tostring(k)] then key = tostring(k) break end
	end
	if not key then return nil, "Your plot is full of boxes - open one first!" end
	local duration = unboxDuration(player, def, entry.size)
	entry.readyAt = now() + duration
	entry.duration = duration
	entry.u, entry.w, entry.rot = u, w, math.random(-20, 20)
	prof.Unboxing[key] = entry
	prof.Boxes[def.id] = (prof.Boxes[def.id] or 0) + 1
	prof.Mutations[mutation] = (prof.Mutations[mutation] or 0) + 1
	refreshPads(player)
	local placed = unboxFolder(plot):FindFirstChild("UnboxBox" .. key)
	if placed then
		FXEvent:FireAllClients("Stash", placed.Position, 5)
		playSound(placed, "rbxasset://sounds/electronicpingshort.wav", 0.9, 1.2)
	end
	return Config.BoxLabel(def, mutation, entry.size), def
end

local function giveGiftBox(player, prof, index)
	-- better warehouses for later gifts
	local maxArea = Config.GiftMaxArea(index)
	return giveBox(player, prof, math.random(math.max(1, maxArea - 2), maxArea))
end

local function claimGift(player, index)
	local prof = profiles[player]
	local gift = Config.Gifts[tonumber(index) or 0]
	if not prof or not gift then return {ok = false, msg = "That gift doesn't exist."} end
	index = tonumber(index)
	giftClaimed[player] = giftClaimed[player] or {}
	if giftClaimed[player][index] then return {ok = false, msg = "Already claimed!"} end
	local waited = now() - (giftStart[player] or now())
	if waited < gift.minutes * 60 then
		return {ok = false, msg = "Not yet! Ready in " .. math.ceil((gift.minutes * 60 - waited) / 60) .. " min"}
	end
	local result
	if math.random() < gift.boxChance then
		local label2, def = giveGiftBox(player, prof, index)
		if label2 then
			result = {ok = true, kind = "box", label = label2, emoji = def.emoji, msg = "🎁 Gift: a free " .. label2 .. "! It's unboxing on your plot."}
		elseif gift.boxChance >= 1 then
			return {ok = false, msg = "This gift is a box - make room on your plot first!"}
		end
	end
	if not result then
		local cash = Config.GiftCash(index, totalIncome(player))
		prof.Cash = prof.Cash + cash
		result = {ok = true, kind = "cash", amount = cash, msg = "🎁 Gift: $" .. cash .. "!"}
	end
	giftClaimed[player][index] = true
	-- all claimed? start a new round
	local all = true
	for i = 1, #Config.Gifts do if not giftClaimed[player][i] then all = false break end end
	if all then
		giftClaimed[player] = {}
		giftStart[player] = now()
		task.delay(1.5, function() if player.Parent then notify(player, "🎁 All gifts claimed! A new round of gifts has started.", YELLOW) end end)
	end
	syncGifts(player)
	sync(player)
	return result
end

------------------------------------------------------------------
-- ROBUX SHOP: game passes (bought once) + developer products (cash packs, speed boosts,
-- instant unbox, lucky box, server luck). Every ID lives in ReplicatedStorage > StealABoxShop.
-- While an ID is 0 the item is free in Studio (for testing) and "not on sale" in real servers.
------------------------------------------------------------------
-- speed boosts may have been made as game passes instead of developer products: find out once per id
local speedPassCache = {}
function speedIsPass(id)
	if speedPassCache[id] == nil then
		local okProduct = pcall(function() return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product) end)
		local okPass = (not okProduct) and pcall(function() return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass) end)
		speedPassCache[id] = (not okProduct) and okPass or false
	end
	return speedPassCache[id]
end
local productByKey = {}  -- [key] = product
local productById = {}   -- [developer product id] = product
for _, p in ipairs(Shop.Products) do productByKey[p.key] = p end
for n, b in ipairs(Config.SpeedBoosts) do
	productByKey["Speed" .. n] = {key = "Speed" .. n, kind = "speed", tier = n, id = Shop.SpeedBoostIds[n] or 0,
		robux = b.robux, name = Config.FormatNum(b.mult) .. "x Speed"}
end
for _, p in pairs(productByKey) do
	if (p.id or 0) ~= 0 then productById[p.id] = p end
end

local function celebrate(player, title, msg, color)
	ShopEvent:FireClient(player, "Granted", {title = title, msg = msg})
	notify(player, msg, color or YELLOW)
	local _, hrp = getChar(player)
	if hrp then FXEvent:FireAllClients("LevelUp", hrp.Position, 2) end
end

-- the Income attribute drives the $/s on the HUD (and cash pack sizes in the shop)
local function refreshIncome(player)
	if profiles[player] then player:SetAttribute("Income", totalIncome(player)) end
end

-- pass attributes let the client show "OWNED" (and what each pass does)
local function syncPasses(player)
	local prof = profiles[player]
	for _, p in ipairs(Shop.Passes) do player:SetAttribute("Pass_" .. p.key, hasPass(player, p.key) or nil) end
	-- the VIP Trail only works while you own VIP
	if prof and prof.Trail == Config.VIPTrail.id and not hasPass(player, "VIP") then prof.Trail = nil end
	local plot = playerPlot[player]
	if plot then setOwnerVisuals(plot, player) end
	refreshIncome(player)
	if prof and applyTrail then applyTrail(player) end
	if prof and refreshTreadmill then refreshTreadmill(player) end
end

local function grantPass(player, key, announce)
	local pass = Shop.GetPass(key)
	if not pass then return end
	passOwned[player] = passOwned[player] or {}
	if passOwned[player][key] then return end
	passOwned[player][key] = true
	-- VIP: wear the VIP Trail right away if it's better than what you have on
	local prof = profiles[player]
	if key == "VIP" and prof then
		local cur = prof.Trail and Config.GetTrail(prof.Trail)
		if not cur or cur.mult < Config.VIPTrail.mult then prof.Trail = Config.VIPTrail.id end
	end
	syncPasses(player)
	sync(player)
	if announce then celebrate(player, pass.name, "Thank you! " .. pass.name .. " is now active. " .. pass.desc, YELLOW) end
end

-- which passes does this player own? (asked once when they join)
local function loadPasses(player)
	passOwned[player] = passOwned[player] or {}
	for _, p in ipairs(Shop.Passes) do
		if (p.id or 0) ~= 0 and not passOwned[player][p.key] then
			local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id) end)
			if ok and owns then passOwned[player][p.key] = true end
		end
	end
	syncPasses(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	local pass = Shop.PassById(passId)
	if pass and player.Parent then grantPass(player, pass.key, true) end
end)

local function grantSpeedBoost(player, tier)
	local prof = profiles[player]
	local b = Config.SpeedBoosts[tier]
	if not prof or not b then return false end
	prof.SpeedBoost = math.max(prof.SpeedBoost or 1, b.mult)
	player:SetAttribute("SpeedBoost", prof.SpeedBoost)
	if refreshTreadmill then refreshTreadmill(player) end
	sync(player)
	local nxt = Config.SpeedBoosts[tier + 1]
	celebrate(player, Config.FormatNum(b.mult) .. "x SPEED", Config.FormatNum(b.mult) .. "x SPEED unlocked! Your treadmill gives way more speed now."
		.. (nxt and (" Next: " .. Config.FormatNum(nxt.mult) .. "x") or ""), YELLOW)
	return true
end

-- speed boosts made as game passes: buying one grants it; owning one gives it back every time you join
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or not player.Parent then return end
	for n, id in ipairs(Shop.SpeedBoostIds) do
		if id ~= 0 and id == passId then grantSpeedBoost(player, n) end
	end
end)
task.spawn(function()
	local done = {}
	while true do
		task.wait(3)
		for _, p in ipairs(Players:GetPlayers()) do
			local prof = profiles[p]
			if prof and not done[p] then
				done[p] = true
				task.spawn(function()
					for n, id in ipairs(Shop.SpeedBoostIds) do
						local b = Config.SpeedBoosts[n]
						if id ~= 0 and b and (prof.SpeedBoost or 1) < b.mult and speedIsPass(id) then
							local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(p.UserId, id) end)
							if ok and owns then
								prof.SpeedBoost = math.max(prof.SpeedBoost or 1, b.mult)
								p:SetAttribute("SpeedBoost", prof.SpeedBoost)
								if refreshTreadmill then refreshTreadmill(p) end
								sync(p)
							end
						end
					end
				end)
			end
		end
		for p in pairs(done) do if not p.Parent then done[p] = nil end end
	end
end)

-- boxes bought with Robux wait here if your plot is full, and arrive as soon as there's room
local function deliverPendingBoxes(player)
	local prof = profiles[player]
	if not prof or type(prof.PendingBoxes) ~= "table" or #prof.PendingBoxes == 0 then return end
	local nextBox = prof.PendingBoxes[1]
	local label2 = giveBox(player, prof, nextBox.area or bestArea(prof), nextBox.mutation)
	if label2 then
		table.remove(prof.PendingBoxes, 1)
		notify(player, "Your " .. label2 .. " arrived! It's unboxing on your plot.", Config.GetMutation(nextBox.mutation).color or YELLOW)
		sync(player)
	end
end

-- give what a developer product is for. Returns ok, message
local function grantProduct(player, prof, product)
	if product.kind == "cash" then
		local amount = Shop.CashAmount(product, totalIncome(player))
		prof.Cash = prof.Cash + amount
		syncCash(player)
		celebrate(player, product.name, "+$" .. Config.FormatNum(amount) .. "! Thanks for your purchase!", Color3.fromRGB(124, 255, 106))
		return true, "+$" .. Config.FormatNum(amount)
	elseif product.kind == "skip" then
		local n = 0
		for _, entry in pairs(prof.Unboxing) do
			if entry.readyAt > now() then
				entry.readyAt = now()
				n = n + 1
			end
		end
		refreshPads(player)
		sync(player)
		celebrate(player, product.name, (n > 0) and ("All " .. n .. " boxes are ready to open!") or "Your next boxes are ready!", GREEN)
		return true
	elseif product.kind == "luckybox" then
		local mutation = (math.random() < 0.2) and "Galaxy" or "Rainbow"
		prof.PendingBoxes = prof.PendingBoxes or {}
		table.insert(prof.PendingBoxes, {area = bestArea(prof), mutation = mutation})
		deliverPendingBoxes(player)
		local waiting = #prof.PendingBoxes > 0
		celebrate(player, product.name, "A " .. string.upper(mutation) .. " Lucky Box!" .. (waiting and " It arrives as soon as your plot has room." or ""),
			Config.GetMutation(mutation).color)
		return true
	elseif product.kind == "serverluck" then
		local nowT = workspace:GetServerTimeNow()
		local untilT = math.max(nowT, ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0) + Config.ServerLuck.minutes * 60
		ReplicatedStorage:SetAttribute("ServerLuckUntil", untilT)
		ReplicatedStorage:SetAttribute("ServerLuckBy", player.DisplayName)
		notifyAll(player.DisplayName .. " bought SERVER LUCK! " .. Config.ServerLuck.mult .. "x mutations for everyone!", Color3.fromRGB(120, 255, 150))
		celebrate(player, product.name, "Server Luck is on for " .. math.floor((untilT - nowT) / 60 + 0.5) .. " minutes. Everyone says thanks!", GREEN)
		return true
	elseif product.kind == "speed" then
		return grantSpeedBoost(player, product.tier)
	end
	return false
end

local function buyProduct(player, key)
	local prof = profiles[player]
	local product = type(key) == "string" and productByKey[key]
	if not prof or not product then return {ok = false, msg = "Unknown item."} end
	if product.kind == "speed" then
		local b = Config.SpeedBoosts[product.tier]
		if (prof.SpeedBoost or 1) >= b.mult then return {ok = false, msg = "You already own " .. Config.FormatNum(b.mult) .. "x Speed!"} end
		local prev = Config.SpeedBoosts[product.tier - 1]
		if prev and (prof.SpeedBoost or 1) < prev.mult then return {ok = false, msg = "Buy " .. Config.FormatNum(prev.mult) .. "x Speed first!"} end
	elseif product.kind == "skip" then
		local waiting = false
		for _, entry in pairs(prof.Unboxing) do if entry.readyAt > now() then waiting = true end end
		if not waiting then return {ok = false, msg = "None of your boxes are unboxing right now!"} end
	end
	if (product.id or 0) == 0 then
		if RunService:IsStudio() then
			local ok = grantProduct(player, prof, product)
			return {ok = ok, msg = ok and "(Studio test: free. Paste the product ID into StealABoxShop to sell it.)" or "Couldn't give that."}
		end
		return {ok = false, msg = "This isn't on sale yet - check back soon!"}
	end
	if product.kind == "speed" and speedIsPass(product.id) then
		-- (this speed boost was made as a game pass, not a developer product)
		local okP = pcall(function() MarketplaceService:PromptGamePassPurchase(player, product.id) end)
		return {ok = okP, msg = okP and "" or "Couldn't open the purchase window. Try again!"}
	end
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, product.id) end)
	return {ok = ok, msg = ok and "" or "Couldn't open the purchase window. Try again!"}
end

local function buyPass(player, key)
	local pass = type(key) == "string" and Shop.GetPass(key)
	if not profiles[player] or not pass then return {ok = false, msg = "Unknown pass."} end
	if hasPass(player, pass.key) then return {ok = false, msg = "You already own " .. pass.name .. "!"} end
	if (pass.id or 0) == 0 then
		if RunService:IsStudio() then
			grantPass(player, pass.key, true)
			return {ok = true, msg = "(Studio test: free for this session. Paste the pass ID into StealABoxShop to sell it.)"}
		end
		return {ok = false, msg = "This pass isn't on sale yet - check back soon!"}
	end
	local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, pass.id) end)
	return {ok = ok, msg = ok and "" or "Couldn't open the purchase window. Try again!"}
end

-- old saves (and the old speed button) used tiers: keep that working
local function buySpeed(player, tier)
	return buyProduct(player, "Speed" .. tostring(tonumber(tier) or 0))
end

-- Roblox calls this for every developer product purchase (again and again until we say it's granted).
-- The purchase ID is stored in the player's save, so a purchase is never given twice.
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local prof = player and profiles[player]
	-- not in this server, still loading, or their save didn't load: try again later
	if not prof or dontSave[player] then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local product = productById[info.ProductId]
	if not product then
		warn("[Steal a Box] unknown developer product " .. tostring(info.ProductId) .. " - add its ID to StealABoxShop")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptKey = tostring(info.PurchaseId)
	prof.Receipts = prof.Receipts or {}
	if not prof.Receipts[receiptKey] then
		local ok, granted = pcall(grantProduct, player, prof, product)
		if not ok or granted == false then
			warn("[Steal a Box] could not grant " .. product.key .. ": " .. tostring(granted))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		prof.Receipts[receiptKey] = os.time()
	end
	-- only tell Roblox it's done once the save (with the receipt in it) is written
	if not save(player) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	plot:SetAttribute("Owner", 0)
	setOwnerVisuals(plot, nil)
end

-- NOTHING blocks your way: players run straight through every obstacle in the whole world -
-- shelves, crates, pallets, decorations, fences, boxes, guardians, shoppers...
-- Only what you stand on, the invisible border walls and the roof stay solid.
local SOLID = {
	-- floors you walk on
	CourtBase = true, WarehouseBase = true, Tile = true, Street = true, Floor = true, Ground = true,
	Cliff = true, CliffLow = true, LobbySpawn = true, PlotFloor = true, TreadBase = true, TreadBelt = true, BoothFloor = true,
	-- the borders of the map + the roof over the lanes
	Wall = true, Barrier = true, BackWall = true, CourtWall = true, WallCap = true, BackWallCap = true, Ceiling = true,
}
local function passThrough(p)
	if p:IsA("BasePart") and not SOLID[p.Name] and p:GetAttribute("Solid") ~= true then p.CollisionGroup = GROUP_PASS end
end
for _, p in ipairs(world:GetDescendants()) do passThrough(p) end
-- new things too (boxes that spawn, dropped boxes, unboxing boxes, shelf products...)
world.DescendantAdded:Connect(passThrough)

clearPlotVisuals = function(plot)
	local f = plot:FindFirstChild("Unboxing")
	if f then f:ClearAllChildren() end
	local sm = plot:FindFirstChild("ShelfModels")
	if sm then sm:ClearAllChildren() end
	for s = 1, Config.MaxStands do
		local stand = plot:FindFirstChild("Stand" .. s)
		if stand then
			for _, c in ipairs(stand:GetChildren()) do
				if c.Name == "ItemTag" or c:IsA("ProximityPrompt") or c:IsA("ParticleEmitter") then c:Destroy() end
			end
		end
	end
	setSign(plot, "CustomerSign", "Lv 1/" .. Config.CustomerMax, "x1 shoppers")
	setSign(plot, "TreadConsole", "$" .. Config.FormatNum(Config.TreadmillCost(1)), "Lv 1/" .. Config.Treadmill.max .. "  +" .. Config.FormatNum(Config.TreadRate(1)) .. "/s")
end

-- every second: finished boxes get an "Open!" prompt
task.spawn(function()
	while true do
		task.wait(1)
		for player, prof in pairs(profiles) do
			local plot = playerPlot[player]
			if plot and player.Parent then
				player:SetAttribute("Income", totalIncome(player)) -- what your shop earns per second
				deliverPendingBoxes(player) -- Lucky Boxes that waited for room on your plot
				local folderU = unboxFolder(plot)
				for key, entry in pairs(prof.Unboxing) do
					local box = folderU:FindFirstChild("UnboxBox" .. key)
					if box and now() >= entry.readyAt and not openingNow[entry] and not box:FindFirstChildOfClass("ProximityPrompt") then
						local pos = box.Position -- (refreshPads re-draws the boxes)
						refreshPads(player)
						notify(player, "A box is ready to open at your base!", YELLOW)
						FXEvent:FireAllClients("Ready", pos, 1)
						break
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- CUSTOMERS: shoppers walk in, pick a product off a stand, pay at the register, leave
------------------------------------------------------------------
local loadTracks, playAnim, loadFriends, friendsOf -- (made in the CUSTOMERS block below, used later)
do
local customersFolder = Instance.new("Folder")
customersFolder.Name = "Customers"
customersFolder.Parent = world
local customers = {}          -- list of active customer tables
local lastSpawn = {}          -- [plot] = os.clock()
local pendingCash = {}        -- [plot] = cash the shop earned since its last sale (the next shopper pays it)

local SKINS = {Color3.fromRGB(255, 220, 177), Color3.fromRGB(234, 184, 146), Color3.fromRGB(200, 140, 100), Color3.fromRGB(141, 85, 56), Color3.fromRGB(245, 205, 48)}
local SHIRTS = {Color3.fromRGB(230, 70, 70), Color3.fromRGB(70, 140, 230), Color3.fromRGB(80, 200, 120), Color3.fromRGB(250, 200, 60), Color3.fromRGB(170, 100, 230), Color3.fromRGB(255, 140, 60), Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 50)}
local PANTS = {Color3.fromRGB(40, 50, 90), Color3.fromRGB(60, 60, 65), Color3.fromRGB(120, 90, 60), Color3.fromRGB(30, 30, 30), Color3.fromRGB(90, 130, 200)}
local function pick(list) return list[math.random(1, #list)] end

-- the real bacon hair ("Pal Hair", made by Roblox) - loaded once; if it can't load we use a part-built one
local baconHair = nil
task.spawn(function()
	local ok, asset = pcall(function() return game:GetService("InsertService"):LoadAsset(Config.BaconHairId) end)
	if ok and asset then
		baconHair = asset:FindFirstChildOfClass("Accessory")
		if baconHair then
			baconHair.Parent = nil
			local handle = baconHair:FindFirstChild("Handle")
			if handle then
				handle.CanCollide = false
				handle.CanQuery = false
				handle.CanTouch = false
				handle.Massless = true
			end
		end
	end
end)

-- classic R6 animations on any rig (guardians + customers)
function loadTracks(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	local tracks = {}
	local set = (hum.RigType == Enum.HumanoidRigType.R15 and Config.R15Anims) or Config.R6Anims
	for name, id in pairs(set) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok and track then
			track.Looped = true
			tracks[name] = track
		end
	end
	return tracks
end

function playAnim(obj, name, speed)
	local tracks = obj.tracks
	if not tracks then return end
	if obj.anim ~= name then
		for k, t in pairs(tracks) do
			if k ~= name then pcall(function() t:Stop(0.2) end) end
		end
		if tracks[name] then pcall(function() tracks[name]:Play(0.2) end) end
		obj.anim = name
		obj.animSpeed = nil -- each track keeps its own speed: always set it on a switch
	end
	if speed and tracks[name] and obj.animSpeed ~= speed then
		obj.animSpeed = speed
		pcall(function() tracks[name]:AdjustSpeed(speed) end)
	end
end

local function bubble(parent, name, offset, size)
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.fromScale(size * 0.9, size * 0.9) -- in studs (shrinks with distance)
	bb.StudsOffset = offset
	bb.LightInfluence = 0
	bb.MaxDistance = 60
	bb.Enabled = false
	bb.Parent = parent
	if name == "Think" then
		-- a white speech bubble with a little tail
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Size = UDim2.fromScale(1, 0.86)
		back.BackgroundColor3 = Color3.new(1, 1, 1)
		back.Parent = bb
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.35, 0)
		c.Parent = back
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Color = Color3.fromRGB(40, 40, 50)
		st.Parent = back
		local tail = Instance.new("Frame")
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.fromScale(0.5, 0.86)
		tail.Size = UDim2.fromScale(0.2, 0.2)
		tail.Rotation = 45
		tail.BackgroundColor3 = Color3.new(1, 1, 1)
		tail.BorderSizePixel = 0
		tail.Parent = bb
	end
	local tl = Instance.new("TextLabel")
	tl.Name = "Icon"
	tl.AnchorPoint = Vector2.new(0.5, 0)
	tl.Position = UDim2.fromScale(0.5, 0.08)
	tl.Size = (name == "Think") and UDim2.fromScale(0.72, 0.7) or UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.Text = ""
	tl.ZIndex = 2
	tl.Parent = bb
	return bb
end

-- shoppers are classic Noobs or Bacon Hairs
-- shoppers look like your Roblox connections (friends)!
friendsOf = {}   -- [player] = {{id, name}, ...}
local descCache = {}   -- [userId] = HumanoidDescription, or false while loading / if it failed
local function fetchDescription(userId)
	if descCache[userId] ~= nil then return descCache[userId] or nil end
	descCache[userId] = false
	task.spawn(function()
		local ok, d = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
		if ok and d then descCache[userId] = d end
	end)
	return nil
end
function loadFriends(player)
	task.spawn(function()
		local list = {}
		local ok, pages = pcall(function() return Players:GetFriendsAsync(player.UserId) end)
		if ok and pages then
			while #list < 60 do
				for _, f in ipairs(pages:GetCurrentPage()) do
					table.insert(list, {id = f.Id, name = f.DisplayName or f.Username or "Friend"})
				end
				if pages.IsFinished then break end
				if not pcall(function() pages:AdvanceToNextPageAsync() end) then break end
			end
		end
		friendsOf[player] = list
		-- warm up the first looks so shoppers are friends right away
		for i = 1, math.min(#list, 24) do
			fetchDescription(list[i].id)
			task.wait(0.15)
		end
	end)
end

-- R15 SHOPPERS: classic noobs / bacons and funny avatars (tiny, giant, big-headed, rainbow),
-- built once from HumanoidDescriptions, then cloned for every shopper
local r15Shoppers = {}
task.spawn(function()
	local NOOB = {head = Color3.fromRGB(245, 205, 48), arms = Color3.fromRGB(245, 205, 48), torso = Color3.fromRGB(13, 105, 172), legs = Color3.fromRGB(75, 151, 75)}
	local looks = {
		{name = "Noob", colors = NOOB},
		{name = "Noob", colors = NOOB, scale = 0.7},
		{name = "BigHeadNoob", colors = NOOB, headScale = 1.6},
	}
	for _ = 1, 4 do
		local skin = pick(SKINS)
		table.insert(looks, {name = "BaconHair", hair = Config.BaconHairId, colors = {head = skin, arms = skin, torso = pick(SHIRTS), legs = pick(PANTS)}})
	end
	local FUNNY = {Color3.fromRGB(255, 80, 200), Color3.fromRGB(80, 255, 120), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 160, 40), Color3.fromRGB(170, 90, 255)}
	for _, f in ipairs({{scale = 0.6}, {scale = 1.35}, {headScale = 1.7}, {height = 1.3, width = 0.7}}) do
		local skin = pick(SKINS)
		table.insert(looks, {name = "Funny", colors = {head = skin, arms = pick(FUNNY), torso = pick(FUNNY), legs = pick(FUNNY)}, scale = f.scale, headScale = f.headScale,
			height = f.height, width = f.width, hair = (math.random() < 0.5) and Config.BaconHairId or nil})
	end
	for _, look in ipairs(looks) do
		local ok, model = pcall(function()
			local d = Instance.new("HumanoidDescription")
			d.HeadColor, d.TorsoColor = look.colors.head, look.colors.torso
			d.LeftArmColor, d.RightArmColor = look.colors.arms, look.colors.arms
			d.LeftLegColor, d.RightLegColor = look.colors.legs, look.colors.legs
			if look.hair then d.HairAccessory = tostring(look.hair) end
			d.HeadScale = look.headScale or 1
			d.HeightScale = look.height or 1
			d.WidthScale = look.width or 1
			d.DepthScale = look.width or 1
			return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
		end)
		if ok and model then
			if look.scale then pcall(function() model:ScaleTo(look.scale) end) end
			model.Name = look.name
			table.insert(r15Shoppers, model)
		end
	end
end)
local function makeR15Shopper()
	if #r15Shoppers == 0 then return nil end
	local m = r15Shoppers[math.random(1, #r15Shoppers)]:Clone()
	local hum = m:FindFirstChildOfClass("Humanoid")
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then m:Destroy() return nil end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hrp.Anchored = true
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	m:SetAttribute("RootHeight", hum.HipHeight + hrp.Size.Y / 2)
	m:PivotTo(CFrame.new(0, -500, 0))
	return m, {hrp = hrp, torso = m:FindFirstChild("UpperTorso") or hrp, head = m:FindFirstChild("Head") or hrp, humanoid = hum, animator = animator}
end

local function makeCustomerModel(owner)
	local friend = nil
	local list = owner and friendsOf[owner]
	if false and list and #list > 0 then -- (friend avatars: too heavy, shoppers are simple noobs / bacons now)
		friend = list[math.random(1, #list)]
	end
	local desc = friend and fetchDescription(friend.id)
	if friend and not desc then friend = nil end -- not loaded yet: a Noob / Bacon this time
	local m, R = makeR15Shopper()
	local isBacon = false
	if not m then -- (no R15 avatars, e.g. offline: the old R6 noob / bacon)
		isBacon = (not friend) and math.random() < 0.5
		local opt = {name = isBacon and "BaconHair" or "Noob", cframe = CFrame.new(0, -500, 0)}
		if isBacon then
			local skin = pick(SKINS)
			opt.head, opt.torso = skin, pick(SHIRTS)
			opt.leftLeg = pick(PANTS)
			opt.rightLeg = opt.leftLeg
		end
		m, R = Config.MakeR6(opt)
	end
	m:SetAttribute("Customer", true)
	local held = Instance.new("Part")
	held.Name = "Held"
	held.Size = Vector3.new(0.2, 0.2, 0.2)
	held.Transparency = 1
	held.CFrame = R.torso.CFrame * CFrame.new(0, 0.2, -1.4)
	held.Parent = m
	Config.Attach(held, R.torso)
	if R.rightArm and math.random() < 0.35 then
		local bag = Instance.new("Part")
		bag.Name = "Bag"
		bag.Size = Vector3.new(0.5, 1.1, 1.2)
		bag.Color = pick(SHIRTS)
		bag.CFrame = R.rightArm.CFrame * CFrame.new(0.55, -1.4, 0)
		bag.Parent = m
		Config.Attach(bag, R.rightArm)
	end
	m.Parent = customersFolder
	if isBacon then
		local ok = false
		if baconHair then
			ok = pcall(function() R.humanoid:AddAccessory(baconHair:Clone()) end)
		end
		if not ok then Config.FakeBaconHair(R.head, 1) end
	end
	if friend and desc then
		-- dress the shopper like your friend (their real avatar)
		task.spawn(function()
			pcall(function() R.humanoid:ApplyDescription(desc) end)
		end)
		local nameTag = Instance.new("BillboardGui")
		nameTag.Name = "FriendName"
		nameTag.Size = UDim2.fromScale(4.5, 0.7)
		nameTag.StudsOffset = Vector3.new(0, 1.05, 0)
		nameTag.LightInfluence = 0
		nameTag.MaxDistance = 40
		nameTag.Parent = R.head
		local nl = Instance.new("TextLabel")
		nl.Size = UDim2.fromScale(1, 1)
		nl.BackgroundTransparency = 1
		nl.FontFace = LABEL_FONT
		nl.TextScaled = true
		nl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nl.Text = friend.name
		local st = Instance.new("UIStroke")
		st.Thickness = 1.5
		st.Parent = nl
		nl.Parent = nameTag
	end
	local think = bubble(R.head, "Think", Vector3.new(0, 2.95, 0), 2.6) -- above the friend name, below the rich tag
	local heldBB = bubble(held, "HeldItem", Vector3.new(0, 0, 0), 1.6)
	-- the clients draw a little 3D model of the product inside these bubbles
	CollectionService:AddTag(think, "ItemBubble")
	CollectionService:AddTag(heldBB, "ItemBubble")
	-- players run straight through shoppers (also through hair / hats added later)
	setGroup(m, GROUP_PASS, true)
	return m, R, think, heldBB
end

local function poseCustomer(c, dt)
	c.t = c.t + dt
	-- move only the root: the rest of the body follows through its joints (much less network traffic)
	if c.parts and c.parts.hrp then
		c.parts.hrp.CFrame = c.cf
	else
		c.model:PivotTo(c.cf)
	end
	if c.moving then
		playAnim(c, "walk", Config.CustomerSpeed / 14.5)
	else
		playAnim(c, c.pose or "idle", 1) -- at your shelf: cheer, point, wave or dance
	end
end


-- RICH SHOPPERS: Gold / Diamond / Rainbow / Galaxy customers pay a lot more and tip more often
local SHOPPER_MUTATIONS = {
	{id = "Gold",    chance = 10, pay = 1.5, tip = 0.6, color = Color3.fromRGB(255, 200, 40),  label = "💰 GOLD SHOPPER"}, -- (pay = x the sale)
	{id = "Diamond", chance = 5,  pay = 2,   tip = 0.7, color = Color3.fromRGB(120, 230, 255), label = "💎 DIAMOND SHOPPER"},
	{id = "Rainbow", chance = 2,  pay = 3,   tip = 0.8, color = Color3.fromRGB(255, 120, 220), label = "🌈 RAINBOW SHOPPER"},
	{id = "Galaxy",  chance = 1,  pay = 5,   tip = 0.9, color = Color3.fromRGB(150, 80, 255),  label = "🌌 GALAXY SHOPPER"},
}
local function pickShopperMutation()
	local roll = math.random() * 100
	local acc = 0
	for _, m in ipairs(SHOPPER_MUTATIONS) do
		acc = acc + m.chance
		if roll < acc then return m end
	end
	return nil
end
local function dressRichShopper(c)
	local m, R = c.rich, c.parts
	local hl = Instance.new("Highlight")
	hl.FillColor = m.color
	hl.FillTransparency = 0.6
	hl.OutlineColor = m.color:Lerp(Color3.new(1, 1, 1), 0.5)
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = c.model
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 10
	sparkle.LightEmission = 1
	sparkle.Lifetime = NumberRange.new(0.6, 1.1)
	sparkle.Speed = NumberRange.new(1, 2.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.3, 0)
	if m.id == "Rainbow" then
		sparkle.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 140, 255))})
	else
		sparkle.Color = ColorSequence.new(m.color, Color3.new(1, 1, 1))
	end
	sparkle.Parent = R.torso
	local light = Instance.new("PointLight")
	light.Color = m.color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = R.torso
	-- a little label above them
	local tag = Instance.new("BillboardGui")
	tag.Name = "RichTag"
	tag.Size = UDim2.fromScale(4.8, 0.65)
	tag.StudsOffset = Vector3.new(0, 4.6, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 50
	tag.Parent = R.head
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.FontFace = LABEL_FONT
	tl.TextScaled = true
	tl.TextColor3 = m.color
	tl.Text = Config.StripEmoji(m.label)
	local st = Instance.new("UIStroke")
	st.Thickness = 1.5
	st.Parent = tl
	tl.Parent = tag
	-- the speech bubble gets the mutation colour too
	local back = c.think:FindFirstChild("Back")
	if back then back.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(m.color, 0.35) end
end

local function spawnCustomer(player, plot, standIndex, item)
	local stand = plot:FindFirstChild("Stand" .. standIndex)
	local origin = plot:FindFirstChild("PlotOrigin")
	if not stand or not origin then return end
	local frame = origin.CFrame
	-- plot-local coords: u = sideways, w = depth from the street
	local function toWorld(u, w) local p = (frame * CFrame.new(u, 0, -w)).Position return Vector3.new(p.X, 0, p.Z) end
	local function toLocal(pos) local p = frame:PointToObjectSpace(pos) return p.X, -p.Z end
	local su, sw = toLocal(stand.Position)
	local aisle = su + 4.75 -- walk between the podium columns
	local side = (math.random() < 0.5) and -1 or 1
	local W = {}
	local function go(u, w, wait, action) table.insert(W, {pos = toWorld(u, w), wait = wait or 0, action = action}) end
	-- walk in through the gate, straight to the shelf, grab it (pays instantly), leave
	go(side * 5, -6)
	go(side * 3, 4)
	go(aisle, 45)
	go(aisle, sw - 4.5)
	go(su, sw - 3.6, 1.2, "take")
	go(aisle, sw - 4.5)
	go(aisle, 45)
	go(side * 3, 4)
	go(side * 5, -6)
	go(side * 50, -10, 0, "leave")
	local function ground(pos)
		local _, w = toLocal(pos)
		return (w > 0 and w < Config.Court.plotDepth) and 0.4 or 0.3
	end

	local model, parts, think, held = makeCustomerModel(player)
	local start = toWorld(side * 52, -10)
	local c = {
		owner = player, plot = plot, item = item, standIndex = standIndex,
		model = model, parts = parts, think = think, held = held,
		pos = start, facing = (toWorld(side * 5, -6) - start).Unit, waypoints = W, index = 1, waitLeft = 0, ground = ground, plotFrame = frame,
		moving = true, holding = false, t = math.random() * 10, rootH = model:GetAttribute("RootHeight") or 3,
	}
	c.cf = CFrame.lookAt(Vector3.new(start.X, ground(start) + c.rootH, start.Z), Vector3.new(start.X, ground(start) + c.rootH, start.Z) + c.facing)
	-- some shoppers are RICH: they have a mutation, glow, pay more and tip more
	c.rich = nil -- (rich glowing shoppers removed: cheaper)
	if c.rich then dressRichShopper(c) end
	-- thought bubble shows what they want (the clients draw the 3D product in it)
	think.Icon.Text = ""
	think:SetAttribute("Item", item.id)
	think:SetAttribute("Mutation", item.mutation)
	think.Enabled = true
	c.tracks = loadTracks(model)
	c.pose = ({"cheer", "point", "wave", "dance"})[math.random(1, 4)]
	table.insert(customers, c)
	poseCustomer(c, 0)
end

local function customerAction(c, action)
	local prof = profiles[c.owner]
	if action == "take" then
		-- grab it off the shelf and pay on the spot
		c.think.Enabled = false
		c.held.Icon.Text = ""
		c.held:SetAttribute("Item", c.item.id)
		c.held:SetAttribute("Mutation", c.item.mutation)
		c.held.Enabled = true
		c.holding = true
		local stand = c.plot:FindFirstChild("Stand" .. c.standIndex)
		if prof and c.owner.Parent and playerPlot[c.owner] == c.plot then
			-- the shopper pays everything the shop earned since the last sale, so your income is
			-- exactly your $/s no matter how busy the shop is. Rich shoppers + tips are a bonus on top.
			local base = pendingCash[c.plot] or 0
			pendingCash[c.plot] = 0
			local price = math.max(1, math.floor(base * (c.rich and c.rich.pay or 1) + 0.5))
			-- tips: normal shoppers tip sometimes, rich ones almost always (and more)
			local tip = 0
			if math.random() < (c.rich and c.rich.tip or 0.25) then
				tip = math.max(1, math.floor(price * (0.05 + math.random() * (c.rich and 0.3 or 0.1)) + 0.5))
			end
			prof.Cash = prof.Cash + price + tip
			syncCash(c.owner)
			questProgress(c.owner, "sales")
			-- "+$123" floats up from the shopper (not from the shelf, where the product tags are)
			local head = c.parts and c.parts.head
			if head then
				popText(head, "+$" .. Config.FormatNum(price), c.rich and c.rich.color or Color3.fromRGB(124, 255, 106), 2.2, 2.6)
				if tip > 0 then
					task.delay(0.4, function()
						if head.Parent then popText(head, "+$" .. Config.FormatNum(tip) .. " TIP!", Color3.fromRGB(255, 220, 80), 1.4, 2.6) end
					end)
				end
			end
			if stand then
				FXEvent:FireAllClients("Sale", stand.Position + Vector3.new(0, 2, -2), 1)
				playSound(stand, "rbxasset://sounds/electronicpingshort.wav", 0.35, 1.8)
			end
		end
		-- a happy heart (drawn by the clients) instead of the product
		c.think.Icon.Text = ""
		c.think:SetAttribute("Item", nil)
		c.think:SetAttribute("Mood", c.rich and "rich" or "happy")
		task.delay(0.9, function()
			if c.think.Parent then c.think.Enabled = true end
		end)
	elseif action == "leave" then
		c.dead = true
	end
end

local function productsOnDisplay(player)
	local prof = profiles[player]
	local list = {}
	if not prof then return list end
	local unlocked = unlockedStands(prof)
	for _, item in ipairs(prof.Items) do
		if item.stand and item.stand <= unlocked then table.insert(list, item) end
	end
	return list
end

-- every shop earns its $/s all the time (the next shopper pays it) + shoppers walk in
task.spawn(function()
	while true do
		local dt = task.wait(0.25)
		for player, prof in pairs(profiles) do
			local plot = playerPlot[player]
			if plot and player.Parent then
				local products = productsOnDisplay(player)
				pendingCash[plot] = (pendingCash[plot] or 0) + totalIncome(player) * dt
				local count = 0
				for _, c in ipairs(customers) do if c.plot == plot then count = count + 1 end end
				local level = prof.Customers or 1
				-- higher kiosk levels: shoppers come more often (the extra money is in totalIncome)
				local interval = math.max(Config.MinCustomerGap, Config.SaleSeconds / (math.max(1, #products) * Config.CustomerRate(level)))
				local cap = Config.MaxCustomers + math.floor((level - 1) / 3)
				if #products > 0 and count < cap and os.clock() - (lastSpawn[plot] or -1e9) >= interval then
					lastSpawn[plot] = os.clock()
					local item = products[math.random(1, #products)]
					spawnCustomer(player, plot, item.stand, {id = item.id, mutation = item.mutation, size = item.size})
				end
			elseif plot then
				pendingCash[plot] = nil
			end
		end
	end
end)

-- walk them around (20 times a second is plenty and much cheaper than every frame)
local shopperAcc = 0
RunService.Heartbeat:Connect(function(frameDt)
	shopperAcc = shopperAcc + frameDt
	if shopperAcc < 0.05 then return end
	local dt = shopperAcc
	shopperAcc = 0
	for i = #customers, 1, -1 do
		local c = customers[i]
		if c.dead or not c.model.Parent or not c.owner.Parent or playerPlot[c.owner] ~= c.plot then
			c.model:Destroy()
			table.remove(customers, i)
		else
			if c.waitLeft > 0 then
				c.waitLeft = c.waitLeft - dt
				c.moving = false
			else
				local wp = c.waypoints[c.index]
				if not wp then
					c.dead = true
				else
					local flat = Vector3.new(wp.pos.X - c.pos.X, 0, wp.pos.Z - c.pos.Z)
					local d = flat.Magnitude
					local step = Config.CustomerSpeed * dt
					if d <= step then
						c.pos = Vector3.new(wp.pos.X, 0, wp.pos.Z)
						c.index = c.index + 1
						if wp.wait > 0 then
							c.waitLeft = wp.wait
							-- face the stand / register while waiting
							if wp.action == "take" then
								local stand = c.plot:FindFirstChild("Stand" .. c.standIndex)
								if stand then
									local f = Vector3.new(stand.Position.X - c.pos.X, 0, stand.Position.Z - c.pos.Z)
									if f.Magnitude > 0.1 then c.facing = f.Unit end
								end
							end
						end
						if wp.action then customerAction(c, wp.action) end
					else
						c.facing = flat.Unit
						c.pos = c.pos + c.facing * step
						c.moving = true
					end
				end
			end
			local at = Vector3.new(c.pos.X, c.ground(c.pos) + (c.rootH or 3), c.pos.Z)
			c.cf = CFrame.lookAt(at, at + c.facing)
			poseCustomer(c, dt)
		end
	end
end)

end
------------------------------------------------------------------
-- SHOP / CRATES / HELPERS / HOME
------------------------------------------------------------------
-- TRAIL SHOP BOOTH: buy a trail once, then equip it. Your equipped trail
-- glows behind you and multiplies the speed your treadmill gives you.
------------------------------------------------------------------
-- Robux speed boosts: multiplies the speed your treadmill gives
local function speedMult(prof)
	if not prof then return 1 end
	return prof.SpeedBoost or 1
end
local function trailMult(prof)
	local t = prof and prof.Trail and Config.GetTrail(prof.Trail)
	return t and t.mult or 1
end

applyTrail = function(player)
	local prof = profiles[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local trail = hrp and hrp:FindFirstChild("SpeedTrail")
	if not trail then return end
	local t = prof and prof.Trail and Config.GetTrail(prof.Trail)
	if t then
		trail.Color = Config.TrailColor(t)
		trail.LightEmission = 1
		trail.Lifetime = 0.45 + t.mult * 0.02
		trail.WidthScale = NumberSequence.new(1.4, 0.2)
	else
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 220, 230))
		trail.LightEmission = 0.4
		trail.Lifetime = 0.3
		trail.WidthScale = NumberSequence.new(0.8, 0.2)
	end
	player:SetAttribute("TrailMult", t and t.mult or 1)
end

buyUpgrade = function(player, id) -- buy or equip a trail
	local prof = profiles[player]
	if not prof then return {ok = false, msg = "Still loading..."} end
	local t = Config.GetTrail(id)
	if not t then return {ok = false, msg = "Unknown trail"} end
	prof.Trails = prof.Trails or {}
	-- the VIP Trail comes with the VIP pass
	if t.vip then
		if not hasPass(player, "VIP") then return {ok = false, msg = "The VIP Trail comes with the VIP pass - get it in the Shop!"} end
		prof.Trail = t.id
		applyTrail(player)
		refreshTreadmill(player)
		sync(player)
		return {ok = true, msg = "Equipped the " .. t.name .. "! (treadmill x" .. t.mult .. ")"}
	end
	if prof.Trails[t.id] then
		prof.Trail = t.id
		applyTrail(player)
		refreshTreadmill(player)
		sync(player)
		return {ok = true, msg = "Equipped the " .. t.name .. "! (treadmill x" .. t.mult .. ")"}
	end
	if prof.Cash < t.price then return {ok = false, msg = "Not enough cash! The " .. t.name .. " costs $" .. Config.FormatNum(t.price)} end
	prof.Cash = prof.Cash - t.price
	prof.Trails[t.id] = true
	-- automatically wear it if it's better than what you have on
	if trailMult(prof) < t.mult then prof.Trail = t.id end
	applyTrail(player)
	refreshTreadmill(player)
	sync(player)
	local _, hrp = getChar(player)
	if hrp then
		FXEvent:FireAllClients("LevelUp", hrp.Position, 1)
		playSound(hrp, "rbxasset://sounds/electronicpingshort.wav", 1, 1.6)
	end
	return {ok = true, msg = "✨ You bought the " .. t.name .. "! Your treadmill now gives x" .. trailMult(prof) .. " speed!"}
end

local booth = world:FindFirstChild("UpgradeBooth")
if booth then
	for _, item in ipairs(booth:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("TrailId") then
			local prompt = item:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(who)
					local r = buyUpgrade(who, item:GetAttribute("TrailId"))
					notify(who, r.msg, r.ok and GREEN or RED)
				end)
			end
		end
	end
end

-- the shopkeeper idles behind the counter
local keeper = booth and booth:FindFirstChild("Shopkeeper")
if keeper then
	local k = {tracks = loadTracks(keeper)}
	playAnim(k, "idle", 1)
end

------------------------------------------------------------------
-- TREADMILL on every plot: run on the belt to earn speed, upgrade at the console
------------------------------------------------------------------
local function upgradeTreadmill(player)
	local prof = profiles[player]
	if not prof then return end
	local level = prof.Treadmill or 1
	if level >= Config.Treadmill.max then
		notify(player, "Your treadmill is already maxed!", YELLOW)
		return
	end
	local cost = Config.TreadmillCost(level)
	if prof.Cash < cost then
		notify(player, "Not enough cash! Treadmill level " .. (level + 1) .. " costs $" .. cost, RED)
		return
	end
	prof.Cash = prof.Cash - cost
	prof.Treadmill = level + 1
	refreshTreadmill(player)
	sync(player)
	local plot = playerPlot[player]
	local console = plot and plot:FindFirstChild("TreadConsole", true)
	local belt = plot and plot:FindFirstChild("TreadBelt", true)
	if belt then FXEvent:FireClient(player, "TreadUpgrade", belt.Position, prof.Treadmill) end -- the upgrade cutscene
	if console then
		FXEvent:FireAllClients("LevelUp", console.Position, 1)
		playSound(console, "rbxasset://sounds/electronicpingshort.wav", 1, 1.6)
	end
	notify(player, "Treadmill upgraded to level " .. prof.Treadmill .. "! (+" .. Config.FormatNum(Config.TreadRate(prof.Treadmill) * trailMult(prof) * speedMult(prof)) .. " speed/s)", GREEN)
end

refreshTreadmill = function(player)
	local plot, prof = playerPlot[player], profiles[player]
	if not plot or not prof then return end
	local screen = plot:FindFirstChild("TreadScreen", true)
	local label = screen and screen:FindFirstChild("ScreenGui", true)
	local level = prof.Treadmill or 1
	local price = (level >= Config.Treadmill.max) and "MAXED" or ("$" .. Config.FormatNum(Config.TreadmillCost(level)))
	setSign(plot, "TreadConsole", price, "Lv " .. level .. "/" .. Config.Treadmill.max .. "  +" .. Config.FormatNum(Config.TreadRate(level) * trailMult(prof) * speedMult(prof)) .. "/s")
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	local console = plot:FindFirstChild("TreadConsole", true)
	local function onUpgrade(who)
		if playerPlot[who] ~= plot then
			notify(who, "That's not your treadmill!", RED)
			return
		end
		upgradeTreadmill(who)
	end
	local prompt = console and console:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt.Triggered:Connect(onUpgrade) end
	local click = console and console:FindFirstChildOfClass("ClickDetector")
	if click then click.MouseClick:Connect(onUpgrade) end
end

-- CUSTOMER KIOSK: more shoppers
local function refreshKiosk(player)
	local plot, prof = playerPlot[player], profiles[player]
	if not plot then return end
	local level = prof and prof.Customers or 1
	setSign(plot, "CustomerSign", "Lv " .. level .. "/" .. Config.CustomerMax, "x" .. string.format("%.1f", Config.CustomerRate(level)) .. " shoppers")
end
-- PAYOUTS / UNBOX SPEED: upgraded on the UPGRADES board on your plot
local function upgradeStat(who, field, max, costFn, what)
	local prof = profiles[who]
	if not prof then return {ok = false, msg = "Still loading..."} end
	local level = prof[field] or 1
	if level >= max then return {ok = false, msg = what .. " is maxed!"} end
	local cost = costFn(level)
	if prof.Cash < cost then return {ok = false, msg = "Not enough cash! You need $" .. Config.FormatNum(cost)} end
	prof.Cash = prof.Cash - cost
	prof[field] = level + 1
	refreshIncome(who)
	sync(who)
	local _, hrp = getChar(who)
	if hrp then FXEvent:FireAllClients("LevelUp", hrp.Position, 1) end
	return {ok = true, msg = what .. " upgraded to level " .. prof[field] .. "!"}
end
-- MORE SHOPPERS: upgraded from the Items panel (the kiosk on the plot is gone)
local function upgradeShoppers(who)
	local prof = profiles[who]
	if not prof then return {ok = false, msg = "Still loading..."} end
	local level = prof.Customers or 1
	if level >= Config.CustomerMax then return {ok = false, msg = "Your shop is maxed!"} end
	local cost = Config.CustomerCost(level)
	if prof.Cash < cost then return {ok = false, msg = "Not enough cash! Shop level " .. (level + 1) .. " costs $" .. Config.FormatNum(cost)} end
	prof.Cash = prof.Cash - cost
	prof.Customers = level + 1
	refreshKiosk(who)
	sync(who)
	local _, hrp = getChar(who)
	if hrp then FXEvent:FireAllClients("LevelUp", hrp.Position, 1) end
	return {ok = true, msg = "More shoppers! Shop level " .. prof.Customers .. " (x" .. string.format("%.1f", Config.CustomerRate(prof.Customers)) .. " shoppers)"}
end

-- earn speed while standing on your own belt
task.spawn(function()
	local STEP = 0.25
	while true do
		task.wait(STEP)
		for player, prof in pairs(profiles) do
			local plot = playerPlot[player]
			local belt = plot and plot:FindFirstChild("TreadBelt", true)
			local _, hrp = getChar(player)
			local on = false
			if belt and hrp and not ragdolled[player] then
				local lp = belt.CFrame:PointToObjectSpace(hrp.Position)
				on = math.abs(lp.X) <= belt.Size.X / 2 + 0.5 and math.abs(lp.Z) <= belt.Size.Z / 2 + 0.5 and lp.Y > 0 and lp.Y < 7
			end
			-- no cap: your speed number keeps growing (into the millions); trails and Robux boosts multiply it
			if on then
				local rate = Config.TreadRate(prof.Treadmill) * trailMult(prof) * speedMult(prof)
					* ((ReplicatedStorage:GetAttribute("EventId") == "SpeedRush") and 3 or 1)
				prof.SpeedPoints = (prof.SpeedPoints or Config.StartSpeed) + rate * STEP
				player:SetAttribute("TreadRate", rate)
				applySpeed(player)
				questProgress(player, "run", STEP)
			end
			if (player:GetAttribute("OnTreadmill") == true) ~= on then
				player:SetAttribute("OnTreadmill", on or nil)
				if not on then sync(player) end
			end
		end
	end
end)

------------------------------------------------------------------
-- INDEX REWARDS: find every item of an area, then claim its reward once:
-- a pile of cash and a permanent cash bonus.
------------------------------------------------------------------
local function claimIndex(player, areaIndex)
	local prof = profiles[player]
	if not prof then return {ok = false, msg = "Still loading..."} end
	areaIndex = math.floor(tonumber(areaIndex) or 0)
	local area = Config.Areas[areaIndex]
	if not area then return {ok = false} end
	local key = tostring(areaIndex)
	if prof.IndexClaimed[key] then return {ok = false, msg = "You already claimed this reward!"} end
	if not Config.AreaComplete(prof.ItemsFound, areaIndex) then
		return {ok = false, msg = "Find all 4 items from " .. area.name .. " first!"}
	end
	prof.IndexClaimed[key] = true
	local cash = Config.IndexCash(areaIndex)
	prof.Cash = prof.Cash + cash
	refreshIncome(player)
	sync(player)
	local _, hrp = getChar(player)
	if hrp then
		FXEvent:FireAllClients("LevelUp", hrp.Position, 3)
		playSound(hrp, "rbxasset://sounds/electronicpingshort.wav", 1, 0.8)
	end
	notifyAll(player.DisplayName .. " completed the " .. area.name .. " Index!", area.accent)
	task.spawn(save, player)
	return {ok = true, cash = cash, msg = "INDEX COMPLETE! +$" .. Config.FormatNum(cash) .. " and +"
		.. math.floor(Config.IndexReward.cashBonus * 100 + 0.5) .. "% cash forever!"}
end

------------------------------------------------------------------
-- DAILY REWARDS: one claim per day (UTC). Claim on the next day to keep your streak going.
------------------------------------------------------------------
local function dailyState(prof)
	prof.Daily = type(prof.Daily) == "table" and prof.Daily or {Streak = 0, Last = -1}
	local d = prof.Daily
	local today = Config.DayNumber(workspace:GetServerTimeNow())
	local canClaim = d.Last ~= today
	local nextStreak
	if d.Last == today then
		nextStreak = d.Streak or 0
	elseif d.Last == today - 1 then
		nextStreak = (d.Streak or 0) + 1
	else
		nextStreak = 1 -- missed a day: start over
	end
	return canClaim, nextStreak, today
end

local function claimDaily(player)
	local prof = profiles[player]
	if not prof then return {ok = false, msg = "Still loading..."} end
	local canClaim, nextStreak, today = dailyState(prof)
	if not canClaim then return {ok = false, msg = "Already claimed today - come back tomorrow!"} end
	local day = ((nextStreak - 1) % #Config.Daily) + 1
	local reward = Config.Daily[day]
	local msg
	if reward.kind == "box" or reward.kind == "luckybox" then
		local label2, err = giveBox(player, prof, bestArea(prof), (reward.kind == "luckybox") and "Rainbow" or nil)
		if not label2 then return {ok = false, msg = (err or "No room on your plot!") .. " Then claim your daily box."} end
		msg = "Day " .. day .. ": a free " .. label2 .. "!"
	else
		local cash = Config.DailyCash(reward, totalIncome(player))
		prof.Cash = prof.Cash + cash
		msg = "Day " .. day .. ": +$" .. Config.FormatNum(cash) .. "!"
	end
	prof.Daily.Streak = nextStreak
	prof.Daily.Last = today
	sync(player)
	return {ok = true, msg = msg, day = day}
end

------------------------------------------------------------------
-- CODES (Config.Codes): each code works once per player
------------------------------------------------------------------
local codeLookup = {}
for code, reward in pairs(Config.Codes) do codeLookup[string.upper(code)] = reward end
local nextCodeTry = {}

local function redeemCode(player, code)
	local prof = profiles[player]
	if not prof then return {ok = false, msg = "Still loading..."} end
	if type(code) ~= "string" or code == "" then return {ok = false, msg = "Type a code first!"} end
	if (nextCodeTry[player] or 0) > os.clock() then return {ok = false, msg = "Slow down a little!"} end
	nextCodeTry[player] = os.clock() + 1
	code = string.upper(string.sub((code:gsub("%s", "")), 1, 40))
	local reward = codeLookup[code]
	if not reward or (reward.expires and os.time() > reward.expires) then
		return {ok = false, msg = "That code doesn't exist (or it expired)."}
	end
	prof.Codes = type(prof.Codes) == "table" and prof.Codes or {}
	if prof.Codes[code] then return {ok = false, msg = "You already used this code!"} end
	local got = {}
	if reward.box then
		local label2, err = giveBox(player, prof, bestArea(prof))
		if not label2 then return {ok = false, msg = (err or "No room on your plot!") .. " Then try the code again."} end
		table.insert(got, "a free " .. label2)
	end
	if reward.cash then
		prof.Cash = prof.Cash + reward.cash
		table.insert(got, "$" .. Config.FormatNum(reward.cash))
	end
	if reward.speed then
		prof.SpeedPoints = (prof.SpeedPoints or Config.StartSpeed) + reward.speed
		applySpeed(player)
		table.insert(got, "+" .. Config.FormatNum(reward.speed) .. " speed")
	end
	prof.Codes[code] = true
	sync(player)
	return {ok = true, msg = "Code redeemed: " .. table.concat(got, " + ") .. "!"}
end

-- settings the client may store in your save
local SETTINGS = {Sfx = true, Music = true, Effects = true, ShelfTags = true}

------------------------------------------------------------------
local lastAction = {}
local ITEM_ACTIONS = {PlaceItem = true, RemoveItem = true, SellItem = true}

ActionFunc.OnServerInvoke = function(player, action, arg, expectedId)
	local prof = profiles[player]
	if not prof then return {ok = false, msg = "Still loading..."} end
	if type(action) ~= "string" then return {ok = false} end

	if action == "GetData" then
		return {ok = true, data = prof}
	end

	-- light spam protection (double clicks, exploit spam)
	local t = os.clock()
	if (lastAction[player] or 0) + 0.12 > t then return {ok = false, msg = ""} end
	lastAction[player] = t

	-- item actions use the backpack index: make sure it's still the item the player clicked
	if ITEM_ACTIONS[action] then
		local item = type(arg) == "number" and prof.Items[arg]
		if not item then return {ok = false, msg = "Item not found."} end
		if expectedId ~= nil and item.id ~= expectedId then
			sync(player)
			return {ok = false, msg = "Your backpack changed - try again."}
		end
	end

	if action == "BuyUpgrade" then
		return buyUpgrade(player, arg)

	elseif action == "SlowMode" then
		slowMode[player] = (arg == true) or nil
		applySpeed(player)
		return {ok = true}

	elseif action == "Booth" then
		if carrying[player] then return {ok = false, msg = "Can't teleport while carrying a box!"} end
		local front = world:FindFirstChild("BoothFront", true)
		if front then sendTo(player, front.Position) end
		return {ok = true}

	elseif action == "PlaceItem" then
		local item = prof.Items[arg]
		if not item then return {ok = false, msg = "Item not found."} end
		if item.stand then return {ok = false, msg = "Already on display."} end
		local st = freeStand(prof)
		if not st then return {ok = false, msg = "All " .. unlockedStands(prof) .. " shelf spots are full! Take one back first."} end
		item.stand = st
		refreshStands(player)
		sync(player)
		return {ok = true, msg = Config.ItemLabel(item) .. " is now on display!"}

	elseif action == "TutorialDone" then
		prof.TutorialDone = true
		sync(player)
		return {ok = true}

	elseif action == "EquipAll" then
		-- put your best products on the shelf (highest $/s first)
		local order = {}
		for i in ipairs(prof.Items) do table.insert(order, i) end
		table.sort(order, function(a, b) return Config.ItemIncome(prof.Items[a]) > Config.ItemIncome(prof.Items[b]) end)
		local slots = unlockedStands(prof)
		for _, it in ipairs(prof.Items) do it.stand = nil end
		local placed = 0
		for rank, i in ipairs(order) do
			if rank <= slots then
				prof.Items[i].stand = rank
				placed = placed + 1
			end
		end
		refreshStands(player)
		sync(player)
		if placed == 0 then return {ok = false, msg = "You don't have any items yet!"} end
		return {ok = true, msg = (placed == 1) and "Put your best item on the shelf!" or ("Put your " .. placed .. " best items on the shelf!")}

	elseif action == "RemoveItem" then
		local item = prof.Items[arg]
		if not item or not item.stand then return {ok = false, msg = "Not on display."} end
		item.stand = nil
		refreshStands(player)
		sync(player)
		return {ok = true, msg = "Moved to your backpack."}

	elseif action == "SellItem" then
		local item = prof.Items[arg]
		if not item then return {ok = false, msg = "Item not found."} end
		local price = Config.ItemIncome(item) * 30
		table.remove(prof.Items, arg)
		prof.Cash = prof.Cash + price
		refreshStands(player)
		sync(player)
		return {ok = true, msg = "Sold " .. Config.ItemLabel(item) .. " for $" .. price .. "!"}

	elseif action == "ClaimGift" then
		return claimGift(player, arg)

	elseif action == "BuySpeed" then
		return buySpeed(player, arg)

	elseif action == "BuyProduct" then
		return buyProduct(player, arg)

	elseif action == "BuyPass" then
		return buyPass(player, arg)

	elseif action == "UpgradePayout" then
		return upgradeStat(player, "PayoutLevel", Config.PayoutMax, Config.PayoutCost, "Shopper payouts")

	elseif action == "UpgradeUnbox" then
		return upgradeStat(player, "UnboxLevel", Config.UnboxMax, Config.UnboxCost, "Unbox speed")

	elseif action == "UpgradeShoppers" then
		return upgradeShoppers(player)

	elseif action == "UpgradeTreadmill" then
		upgradeTreadmill(player)
		return {ok = true}

	elseif action == "BuyStand" then
		local have = unlockedStands(prof)
		if have >= Config.MaxStands then return {ok = false, msg = "Your shelves are full!"} end
		local cost = Config.StandCost(have)
		if prof.Cash < cost then return {ok = false, msg = "You need $" .. Config.FormatNum(cost) .. " for another shelf spot!"} end
		prof.Cash = prof.Cash - cost
		prof.ExtraStands = (prof.ExtraStands or 0) + 1
		refreshStands(player)
		refreshIncome(player)
		sync(player)
		return {ok = true, msg = "+1 shelf spot! (" .. unlockedStands(prof) .. " now)", stands = unlockedStands(prof)}

	elseif action == "OpenBox" then
		local e = prof.Unboxing[tostring(arg)]
		if not e then return {ok = false, msg = "That box is gone."} end
		if now() < e.readyAt then return {ok = false, msg = "Not ready yet!"} end
		openBox(player, tostring(arg))
		return {ok = true}

	elseif action == "OpenAll" then
		local n = 0
		for k, e in pairs(prof.Unboxing) do
			if now() >= e.readyAt then
				n = n + 1
				task.delay((n - 1) * 0.5, function() openBox(player, k) end) -- one after another
			end
		end
		return {ok = n > 0, msg = (n > 0) and ("Opening " .. n .. " box" .. (n > 1 and "es" or "") .. "!") or "No boxes are ready yet.", opened = n}

	elseif action == "ClaimQuest" then
		local slot = math.floor(tonumber(arg) or 0)
		local q = questState(prof).List[slot]
		if not q then return {ok = false} end
		if q.claimed then return {ok = false, msg = "You already claimed this quest!"} end
		if q.progress < q.goal then return {ok = false, msg = "Not done yet!"} end
		q.claimed = true
		local cash = Config.QuestReward(slot, totalIncome(player))
		prof.Cash = prof.Cash + cash
		sync(player)
		publishQuests(player)
		return {ok = true, msg = "Quest complete! +$" .. Config.FormatNum(cash), cash = cash}

	elseif action == "ClaimIndex" then
		return claimIndex(player, arg)

	elseif action == "ClaimDaily" then
		return claimDaily(player)

	elseif action == "RedeemCode" then
		return redeemCode(player, arg)

	elseif action == "SetSetting" then
		if type(arg) ~= "string" or not SETTINGS[arg] or type(expectedId) ~= "boolean" then return {ok = false} end
		prof.Settings = type(prof.Settings) == "table" and prof.Settings or {}
		prof.Settings[arg] = expectedId
		return {ok = true}

	elseif action == "Home" then
		if carrying[player] then return {ok = false, msg = "Can't teleport while carrying a box!"} end
		sendHome(player)
		return {ok = true}

	elseif action == "Warehouse" then
		if carrying[player] then return {ok = false, msg = "Can't teleport while carrying a box!"} end
		local entrance = world:FindFirstChild("EntrancePoint", true)
		if entrance then sendTo(player, entrance.Position) end
		return {ok = true}
	end
	return {ok = false, msg = "Unknown action"}
end

------------------------------------------------------------------
-- RAGDOLL + FLING
------------------------------------------------------------------
local function setRagdoll(char, on)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if on then
		hum.RequiresNeck = false
		for _, m in ipairs(char:GetDescendants()) do
			if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Name ~= "RootJoint" and m.Name ~= "Root" then
				local a0 = Instance.new("Attachment")
				a0.Name = "RagdollA0"
				a0.CFrame = m.C0
				a0.Parent = m.Part0
				local a1 = Instance.new("Attachment")
				a1.Name = "RagdollA1"
				a1.CFrame = m.C1
				a1.Parent = m.Part1
				local bs = Instance.new("BallSocketConstraint")
				bs.Name = "RagdollSocket"
				bs.Attachment0 = a0
				bs.Attachment1 = a1
				bs.LimitsEnabled = true
				bs.UpperAngle = 60
				bs.TwistLimitsEnabled = true
				bs.TwistLowerAngle = -45
				bs.TwistUpperAngle = 45
				bs.Parent = m.Parent
				m.Enabled = false
			end
		end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Parent == char then
				p:SetAttribute("WasCollide", p.CanCollide)
				p.CanCollide = true
			end
		end
	else
		for _, d in ipairs(char:GetDescendants()) do
			if d.Name == "RagdollSocket" or d.Name == "RagdollA0" or d.Name == "RagdollA1" then
				d:Destroy()
			elseif d:IsA("Motor6D") then
				d.Enabled = true
			elseif d:IsA("BasePart") and d:GetAttribute("WasCollide") ~= nil then
				d.CanCollide = d:GetAttribute("WasCollide")
				d:SetAttribute("WasCollide", nil)
			end
		end
	end
end

local function flingPlayer(player, guardPos, areaIndex)
	local char, hrp = getChar(player)
	if not char or ragdolled[player] then return end
	local area = Config.Areas[areaIndex]
	ragdolled[player] = true
	immuneUntil[player] = os.clock() + RAGDOLL_TIME + 2
	local fprof = profiles[player]
	if fprof then
		fprof.Flings = (fprof.Flings or 0) + 1
		achieve(player, "Bonk")
		if fprof.Flings >= 25 then achieve(player, "Bonk25") end
	end

	local away = Vector3.new(hrp.Position.X - guardPos.X, 0, hrp.Position.Z - guardPos.Z)
	if away.Magnitude < 0.1 then away = Vector3.new(0, 0, 1) end
	local dir = (away.Unit + Vector3.new(0, 0, 1.2)).Unit -- mostly back toward the entrance
	local velocity = dir * area.fling + Vector3.new(0, math.min(30 + areaIndex * 5, 75), 0)

	releaseCarry(player)
	setRagdoll(char, true)
	playSound(hrp, "rbxasset://sounds/swoosh.wav", 1, 0.8)
	playSound(hrp, "rbxasset://sounds/collide.wav", 1, 0.7)
	FlingEvent:FireClient(player, velocity, RAGDOLL_TIME, area.guard)
	FXEvent:FireAllClients("Bonk", hrp.Position, areaIndex)
	notify(player, "BONK! The " .. area.guard .. " flung you across the warehouse!", RED)

	task.delay(RAGDOLL_TIME, function()
		ragdolled[player] = nil
		if char.Parent then setRagdoll(char, false) end
	end)
end

------------------------------------------------------------------
-- GUARDIANS: sleep at their post, wake when you steal in their area,
-- chase you (even into the next area), fling you when they catch you.
------------------------------------------------------------------
local guardsFolder = world:WaitForChild("Guards")
local guards = {}

for _, model in ipairs(guardsFolder:GetChildren()) do
	if model:IsA("Model") then
		local pivot = model:GetPivot()
		local facing = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
		facing = (facing.Magnitude > 0.01) and facing.Unit or Vector3.new(0, 0, 1)
		local area = model:GetAttribute("Area") or 1
		local lids = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Eyelid" then table.insert(lids, d) end
		end
		model:SetAttribute("Mode", "sleep")
		table.insert(guards, {
			model = model, area = area, hrp = model.PrimaryPart, lids = lids,
			speed = Config.Areas[area].guardSpeed,
			scale = model:GetAttribute("Scale") or 1,
			post = Vector3.new(pivot.X, 0, pivot.Z), postFacing = facing,
			pos = Vector3.new(pivot.X, 0, pivot.Z), baseY = pivot.Y, facing = facing,
			mode = "sleep", target = nil,
			alert = model:FindFirstChild("Alert", true),
			zzz = model:FindFirstChild("Zzz", true),
			angry = model:FindFirstChild("Angry", true),
			rage = model:FindFirstChild("RageFX", true),
			t = math.random() * 10,
			tracks = loadTracks(model),
		})
	end
end

local function setAwake(g, awake)
	if g.alert then g.alert.Enabled = awake end
	if g.zzz then g.zzz.Enabled = not awake end
	if g.angry then g.angry.Enabled = awake end
	if g.rage then g.rage.Enabled = awake end
	-- eyes snap open when he wakes up, close again when he dozes off
	for _, lid in ipairs(g.lids or {}) do lid.Transparency = awake and 1 or 0 end
end

-- the clients read this to drive extra boss effects (glowing eyes, orbiting orbs, cape...)
local function setMode(g, mode)
	if g.mode ~= mode then g.mode = mode end
	if g.model:GetAttribute("Mode") ~= mode then g.model:SetAttribute("Mode", mode) end
end

local function setChased(player, on)
	if player and player.Parent then player:SetAttribute("Chased", on or nil) end
end

alertGuard = function(area, player)
	for _, g in ipairs(guards) do
		if g.area == area and g.mode ~= "chase" then
			setMode(g, "chase")
			g.target = player
			-- he needs a moment to get up
			g.wakeUntil = os.clock() + 0.8
			g.laughUntil = nil
			setAwake(g, true)
			setChased(player, true)
			playSound(g.model.PrimaryPart, "rbxasset://sounds/electronicpingshort.wav", 1, 0.5)
			FXEvent:FireAllClients("Wake", g.model:GetPivot().Position, g.scale)
			notify(player, "The " .. Config.Areas[area].guard .. " WOKE UP - RUN!", RED)
		end
	end
end

local function stepToward(g, goal, speed, dt)
	local flat = Vector3.new(goal.X - g.pos.X, 0, goal.Z - g.pos.Z)
	local d = flat.Magnitude
	if d < 0.05 then return 0 end
	local stepLen = math.min(d, speed * dt)
	g.facing = flat.Unit
	g.pos = g.pos + g.facing * stepLen
	return d - stepLen
end

local function anyoneElseChasing(player, except)
	for _, other in ipairs(guards) do
		if other ~= except and other.mode == "chase" and other.target == player then return true end
	end
	return false
end

------------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	for _, g in ipairs(guards) do
		g.t = g.t + dt
		if g.mode == "chase" then
			local p = g.target
			local _, hrp = getChar(p)
			-- they chase you into the next area, but not further
			-- chase through this department and the one before it, never out into the courtyard
			-- he keeps chasing you through the whole warehouse - only the door stops him (steal successful!)
			local keep = hrp and carrying[p] and not isImmune(p) and hrp.Position.Z < L.frontZ and math.abs(hrp.Position.X) < Config.AreaHalfWidth(g.area) + 2
			if keep then
				local flat = Vector3.new(hrp.Position.X - g.pos.X, 0, hrp.Position.Z - g.pos.Z)
				if os.clock() < (g.wakeUntil or 0) then
					if flat.Magnitude > 0.1 then g.facing = flat.Unit end -- turn and glare before running
				elseif flat.Magnitude <= 2.5 + g.scale * 1.2 then
					flingPlayer(p, g.pos, g.area)
					g.laughUntil = os.clock() + 2
					keep = false
				else
					stepToward(g, hrp.Position, g.speed, dt)
				end
			end
			if not keep then
				if not anyoneElseChasing(p, g) then setChased(p, false) end
				setMode(g, "return")
				g.target = nil
				setAwake(g, false)
				if g.zzz then g.zzz.Enabled = false end
			end
		elseif g.mode == "return" then
			-- he finishes laughing before he walks back (no sliding mid-laugh)
			if os.clock() >= (g.laughUntil or 0) and stepToward(g, g.post, GUARD_RETURN_SPEED, dt) < 0.3 then
				setMode(g, "sleep")
				g.facing = g.postFacing
				if g.zzz then g.zzz.Enabled = true end
			end
		end

		local cf
		local at = Vector3.new(g.pos.X, g.baseY, g.pos.Z)
		if g.mode == "sleep" then
			-- dozing: head drooped forward, slow sleepy idle
			cf = CFrame.lookAt(at, at + g.facing) * CFrame.Angles(math.rad(-4 + math.sin(g.t * 0.8) * 2), 0, 0)
			playAnim(g, "idle", 0.4)
		elseif g.mode == "chase" and os.clock() < (g.wakeUntil or 0) then
			-- just woke up: points at the thief
			cf = CFrame.lookAt(at, at + g.facing)
			playAnim(g, "point", 1.4)
		elseif os.clock() < (g.laughUntil or 0) then
			-- just flung someone: laughs about it
			cf = CFrame.lookAt(at, at + g.facing)
			playAnim(g, "laugh", 1)
		else
			-- classic R6 walk, sped up to match how fast he's running
			local spd = (g.mode == "chase") and g.speed or GUARD_RETURN_SPEED
			cf = CFrame.lookAt(at, at + g.facing) * CFrame.Angles((g.mode == "chase") and math.rad(-6) or 0, 0, 0)
			playAnim(g, "walk", math.clamp(spd / (14.5 * g.scale), 0.6, 3))
		end
		-- move only the root part: the whole (detailed) body follows through its joints and welds
		if g.hrp then
			g.hrp.CFrame = cf
		else
			g.model:PivotTo(cf)
		end
	end
end)

------------------------------------------------------------------
-- STEAL SUCCESSFUL: out of the warehouse door with a box = you got away with it
------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.2)
		for p, c in pairs(carrying) do
			if not c.escaped then
				local _, hrp = getChar(p)
				if hrp and hrp.Position.Z > L.frontZ + 1 then
					c.escaped = true
					setChased(p, false)
					FXEvent:FireClient(p, "StealSuccess", hrp.Position)
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- ACHIEVEMENTS that depend on numbers (checked every couple of seconds)
------------------------------------------------------------------
task.spawn(function()
	local nextCheck = os.clock()
	while true do
		task.wait(0.5)
		if os.clock() >= nextCheck then
			nextCheck = os.clock() + 2
			for p, prof in pairs(profiles) do
				if p.Parent then
					if prof.Cash >= 1e6 then achieve(p, "Million") end
					if prof.Cash >= 1e9 then achieve(p, "Billion") end
					if (prof.SpeedPoints or 0) >= 10000 then achieve(p, "Speedy") end
					local onShelf = 0
					for _, it in ipairs(prof.Items) do if it.stand then onShelf = onShelf + 1 end end
					if onShelf >= 20 then achieve(p, "FullShelf") end
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- SURPRISE EVENTS: at a random moment (no warning!) an event starts for the whole server
------------------------------------------------------------------
task.spawn(function()
	local function now() return workspace:GetServerTimeNow() end
	local function waitUntil(t) while now() < t do task.wait(1) end end
	while true do
		waitUntil(now() + math.random(Config.EventGap[1], Config.EventGap[2]))
		-- warehouse events only make sense while the warehouse is open
		local choices = {}
		for _, e in ipairs(Config.Events) do
			if not (e.warehouse and ReplicatedStorage:GetAttribute("IsNight")) then table.insert(choices, e) end
		end
		local e = choices[math.random(1, #choices)]
		local ends = now() + e.seconds
		ReplicatedStorage:SetAttribute("EventId", e.id)
		ReplicatedStorage:SetAttribute("EventName", e.name)
		ReplicatedStorage:SetAttribute("EventEndsAt", ends)
		notifyAll(e.name .. " " .. e.text, Color3.fromRGB(255, 200, 60))
		if e.id == "GoldRain" then
			for _ = 1, 14 do
				local sp = boxSpawns[math.random(1, #boxSpawns)]
				local old = spawnFilled[sp]
				if old then
					boxSpawnOf[old] = nil
					spawnFilled[sp] = nil
					old:Destroy()
				end
				spawnBox(sp, (math.random() < 0.15) and "Rainbow" or "Gold")
			end
		elseif e.id == "LuckyHour" then
			ReplicatedStorage:SetAttribute("ServerLuckUntil", math.max(ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0, ends))
		end
		waitUntil(ends)
		ReplicatedStorage:SetAttribute("EventId", nil)
		ReplicatedStorage:SetAttribute("EventName", nil)
		ReplicatedStorage:SetAttribute("EventEndsAt", nil)
		notifyAll("The " .. e.name:gsub("!", "") .. " event is over.", Color3.fromRGB(200, 200, 220))
	end
end)

------------------------------------------------------------------
-- DAY / NIGHT: by day the shelves slowly empty out. At night the warehouse door is CLOSED
-- (everyone inside is sent home) and every empty shelf spot gets a new box for the morning.
------------------------------------------------------------------
task.spawn(function()
	local Lighting = game:GetService("Lighting")
	local TweenService = game:GetService("TweenService")
	local front = world:FindFirstChild("WarehouseFront")
	local door = front and front:FindFirstChild("Barrier")
	local function setDoor(closed)
		if not door then return end
		door.Transparency = closed and 0 or 1
		door.CanCollide = closed
		local sign = door:FindFirstChild("ClosedSign")
		if sign then sign.Enabled = closed end
	end
	local night = false
	local phaseEnds = workspace:GetServerTimeNow() + Config.DayLength
	ReplicatedStorage:SetAttribute("IsNight", false)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", phaseEnds)
	while true do
		task.wait(1)
		if night then
			-- 5x unbox speed at night: every second takes 4 more seconds off every box that's unboxing
			for p, prof in pairs(profiles) do
				local plot = playerPlot[p]
				local changed = false
				for key, e in pairs(prof.Unboxing) do
					if e.readyAt > now() then
						e.readyAt = math.max(now(), e.readyAt - 4)
						changed = true
						local part = plot and unboxFolder(plot):FindFirstChild("UnboxBox" .. key)
						if part then part:SetAttribute("ReadyAt", e.readyAt) end
					end
				end
				if changed then sync(p) end
			end
		end
		if workspace:GetServerTimeNow() >= phaseEnds then
			night = not night
			phaseEnds = workspace:GetServerTimeNow() + (night and Config.NightLength or Config.DayLength)
			ReplicatedStorage:SetAttribute("IsNight", night)
			ReplicatedStorage:SetAttribute("PhaseEndsAt", phaseEnds)
			setDoor(night)
			if night then
				notifyAll("Night time! The warehouse is closed - but your boxes unbox 5x FASTER until sunrise!", Color3.fromRGB(170, 190, 255))
				-- everybody still inside goes home (a carried box is dropped)
				for _, p in ipairs(Players:GetPlayers()) do
					local _, hrp = getChar(p)
					if hrp and hrp.Position.Z < L.frontZ + 1 then
						if carrying[p] then releaseCarry(p) end
						sendHome(p)
					end
				end
				-- restock every empty spot (a few at a time)
				for i, sp in ipairs(boxSpawns) do
					if not spawnFilled[sp] then
						spawnBox(sp)
						if i % 6 == 0 then task.wait(0.05) end
					end
				end
				pcall(function()
					TweenService:Create(Lighting, TweenInfo.new(6), {ClockTime = 20.5, Brightness = 1.2, OutdoorAmbient = Color3.fromRGB(100, 110, 190)}):Play()
				end)
			else
				notifyAll("Good morning! The warehouse is open again - go steal!", Color3.fromRGB(255, 230, 120))
				pcall(function()
					Lighting.ClockTime = 6
					TweenService:Create(Lighting, TweenInfo.new(6), {ClockTime = 14, Brightness = 3, OutdoorAmbient = Color3.fromRGB(175, 175, 185)}):Play()
				end)
			end
		end
	end
end)

------------------------------------------------------------------
-- EVENT: a guaranteed Rainbow or Galaxy box appears every few minutes
------------------------------------------------------------------
task.spawn(function()
	while true do
		ReplicatedStorage:SetAttribute("SpecialAt", workspace:GetServerTimeNow() + Config.SpecialBoxEvery)
		task.wait(Config.SpecialBoxEvery)
		local sp = boxSpawns[math.random(1, #boxSpawns)]
		local old = spawnFilled[sp]
		if old then
			boxSpawnOf[old] = nil
			spawnFilled[sp] = nil
			old:Destroy()
		end
		local mutation = (math.random() < 0.2) and "Galaxy" or "Rainbow"
		local box = spawnBox(sp, mutation)
		if box then
			local def = Config.Boxes[box:GetAttribute("BoxId")]
			notifyAll("A " .. string.upper(mutation) .. " " .. def.name .. " appeared in " .. Config.Areas[def.area].name .. "!", Config.GetMutation(mutation).color)
		end
	end
end)

------------------------------------------------------------------
-- PLAYERS + SAVING
------------------------------------------------------------------
local store = nil
pcall(function() store = DataStoreService:GetDataStore("StealABox_v5") end)

-- SESSION LOCK: a save is "open" in one server at a time. If you leave a server and join
-- another one quickly, the new server waits until the old one has finished saving, so a
-- fast rejoin can never load old data (and then save it over your newer progress).
local SESSION_TIMEOUT = 75 -- seconds without a save before a server's claim counts as dead
local JOB_ID = (game.JobId ~= "" and game.JobId) or ("studio-" .. game:GetService("HttpService"):GenerateGUID(false))
local function saveKey(player) return "player_" .. player.UserId end

-- load the save AND claim it for this server. Returns ok, data
local function loadData(player)
	local failures = 0
	local maxFailures = RunService:IsStudio() and 1 or 3
	for attempt = 1, 8 do
		local data, locked = nil, false
		local ok = pcall(function()
			store:UpdateAsync(saveKey(player), function(old)
				data, locked = nil, false
				if type(old) == "table" and old.SessionActive and old.SessionJob ~= JOB_ID
					and os.time() - (tonumber(old.SessionTime) or 0) < SESSION_TIMEOUT and attempt < 8 then
					locked = true
					return nil -- another server still has it open: don't touch it, ask again in a moment
				end
				data = old
				local claimed = (type(old) == "table") and old or {}
				claimed.SessionJob = JOB_ID
				claimed.SessionActive = true
				claimed.SessionTime = os.time()
				return claimed
			end)
		end)
		if ok and not locked then return true, data end
		if not ok then
			failures = failures + 1
			if failures >= maxFailures then return false, nil end
			task.wait(1.5 * failures)
		else
			task.wait(3) -- the other server is still saving: give it a moment
		end
		if not player.Parent then return false, nil end
	end
	return false, nil
end

local savesInFlight = 0
-- final = true when the player is leaving (releases this server's claim on the save)
save = function(player, final)
	local prof = profiles[player]
	if not prof then return false end
	if not store then return true end -- no DataStores here (Studio without API access): nothing to write
	if dontSave[player] then return false end
	savesInFlight = savesInFlight + 1
	local saved = false
	for attempt = 1, 3 do
		local written = false
		local ok = pcall(function()
			store:UpdateAsync(saveKey(player), function(old)
				written = false
				-- another server claimed this save after us: never overwrite its newer data
				if type(old) == "table" and old.SessionJob ~= nil and old.SessionJob ~= JOB_ID then return nil end
				local out = table.clone(prof)
				out.SessionJob = JOB_ID
				out.SessionActive = not final
				out.SessionTime = os.time()
				out.LastOnline = os.time()
				written = true
				return out
			end)
		end)
		if ok then
			saved = written
			break
		end
		task.wait(attempt)
	end
	savesInFlight = savesInFlight - 1
	if not saved then warn("[Steal a Box] could not save data for " .. player.Name) end
	return saved
end

local function addTrail(char)
	local hrp = char:WaitForChild("HumanoidRootPart")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.6, 0)
	a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.MinLength = 0.2
	trail.LightEmission = 0.7
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(80, 255, 120), Color3.fromRGB(190, 255, 200))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Parent = hrp
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	-- players are in their own collision group, so they run through shoppers and shop furniture
	setGroup(char, GROUP_PLAYERS, true)
	applySpeed(player)
	hum.BreakJointsOnDeath = false
	addTrail(char)
	applyTrail(player)
	hum.Died:Connect(function()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local dropAt = nil
		if hrp then dropAt = groundBelow(hrp.Position, {char}) end
		releaseCarry(player, dropAt)
		ragdolled[player] = nil
		setChased(player, false)
	end)
	task.wait(0.2)
	sendHome(player)
end

-- copy a loaded save into a fresh profile (only fields we know, with sane values)
local function readSave(prof, data)
	-- saves from before the Mega Mart: turn the old box / item ids into the new supermarket ones
	local legacyStands = nil
	if (tonumber(data.SaveVersion) or 1) < 2 then
		-- shelf spots became buyable: keep everything that was already on the shelf
		local onShelf = 0
		for _, it in ipairs(type(data.Items) == "table" and data.Items or {}) do
			if type(it) == "table" and it.stand then onShelf = onShelf + 1 end
		end
		legacyStands = math.max(0, onShelf - Config.BaseStands)
		local function remap(t, map)
			if type(t) ~= "table" then return t end
			local out = {}
			for k, v in pairs(t) do
				local nk = map[k] or k
				out[nk] = (type(v) == "number" and type(out[nk]) == "number") and (out[nk] + v) or v
			end
			return out
		end
		data.Boxes = remap(data.Boxes, Config.OldBoxToNew)
		data.ItemsFound = remap(data.ItemsFound, Config.OldItemToNew)
		for _, it in ipairs(type(data.Items) == "table" and data.Items or {}) do
			if type(it) == "table" then it.id = Config.OldItemToNew[it.id] or it.id end
		end
		for _, e in pairs(type(data.Unboxing) == "table" and data.Unboxing or {}) do
			if type(e) == "table" then e.id = Config.OldBoxToNew[e.id] or e.id end
		end
	end
	prof.SaveVersion = 2
	prof.FreeGiftAt = tonumber(data.FreeGiftAt) or 0
	prof.ExtraStands = math.max(0, math.floor(tonumber(data.ExtraStands) or 0))
	if legacyStands then prof.ExtraStands = legacyStands end
	if type(data.Quests) == "table" then prof.Quests = data.Quests end
	prof.TutorialDone = (data.TutorialDone == true) or ((tonumber(data.Treadmill) or 1) >= 2)
	prof.Cash = math.max(0, tonumber(data.Cash) or 0)
	prof.Stolen = tonumber(data.Stolen) or 0
	prof.Treadmill = math.clamp(tonumber(data.Treadmill) or 1, 1, Config.Treadmill.max)
	prof.Customers = math.clamp(tonumber(data.Customers) or 1, 1, Config.CustomerMax)
	prof.PayoutLevel = math.clamp(math.floor(tonumber(data.PayoutLevel) or 1), 1, Config.PayoutMax)
	prof.UnboxLevel = math.clamp(math.floor(tonumber(data.UnboxLevel) or 1), 1, Config.UnboxMax)
	-- old saves: speed from levels turns into treadmill speed
	local oldTread = tonumber(data.TreadSpeed) or math.max(0, ((tonumber(data.Level) or 1) - 1) * 0.5)
	prof.Cash = prof.Cash + (tonumber(data.Register) or 0) -- old saves: register money goes straight to cash
	if type(data.Items) == "table" then
		for _, it in ipairs(data.Items) do
			if type(it) == "table" and Config.Items[it.id] and #prof.Items < Config.MaxItems then table.insert(prof.Items, it) end
		end
	end
	-- two items can't share one shelf spot (old bug): the extra ones go back to the backpack
	local usedStands = {}
	for _, it in ipairs(prof.Items) do
		if it.stand ~= nil then
			if type(it.stand) ~= "number" or usedStands[it.stand] or it.stand < 1 or it.stand > Config.MaxStands then
				it.stand = nil
			else
				usedStands[it.stand] = true
			end
		end
	end
	if type(data.Trails) == "table" then
		for k in pairs(data.Trails) do if Config.GetTrail(k) then prof.Trails[k] = true end end
	end
	if type(data.Trail) == "string" and (prof.Trails[data.Trail] or data.Trail == Config.VIPTrail.id) then prof.Trail = data.Trail end
	prof.SpeedBoost = math.max(1, tonumber(data.SpeedBoost) or 1)
	-- purchase receipts: keep the newest 100 (old ones can't come back)
	if type(data.Receipts) == "table" then
		local list = {}
		for k, v in pairs(data.Receipts) do table.insert(list, {tostring(k), tonumber(v) or 0}) end
		table.sort(list, function(a, b) return a[2] > b[2] end)
		for i = 1, math.min(#list, 100) do prof.Receipts[list[i][1]] = list[i][2] end
	end
	-- old saves: Sneakers levels turn into treadmill speed (the upgrade shop is gone)
	if type(data.Upgrades) == "table" and not data.UpgradesMigrated then
		oldTread = oldTread + (tonumber(data.Upgrades.Speed) or 0) * 1.2
	end
	prof.UpgradesMigrated = true
	-- the big speed number: old saves get the number that runs as fast as they did
	prof.SpeedPoints = math.max(Config.StartSpeed, tonumber(data.SpeedPoints) or Config.WalkToPoints(16 + oldTread))
	prof.Flings = tonumber(data.Flings) or 0
	for _, key in ipairs({"Boxes", "Mutations", "ItemsFound", "Unboxing", "Codes", "Settings", "Achievements"}) do
		if type(data[key]) == "table" then
			for k, v in pairs(data[key]) do prof[key][k] = v end
		end
	end
	if type(data.IndexClaimed) == "table" then
		for k in pairs(data.IndexClaimed) do
			local n = tonumber(k)
			if n and Config.Areas[n] then prof.IndexClaimed[tostring(n)] = true end
		end
	end
	if type(data.Daily) == "table" then
		prof.Daily = {Streak = tonumber(data.Daily.Streak) or 0, Last = tonumber(data.Daily.Last) or -1}
	end
	if type(data.PendingBoxes) == "table" then
		prof.PendingBoxes = {}
		for _, b in ipairs(data.PendingBoxes) do
			if type(b) == "table" then table.insert(prof.PendingBoxes, {area = tonumber(b.area) or 1, mutation = Config.GetMutation(b.mutation).id}) end
		end
	end
	return tonumber(data.LastOnline)
end

-- your shop kept selling while you were away (a part of your income)
local function giveOfflineEarnings(player, prof, lastOnline)
	if not lastOnline then return end
	local away = os.time() - lastOnline
	if away < Config.Offline.minMinutes * 60 then return end
	away = math.min(away, Config.Offline.maxHours * 3600)
	local earned = math.floor(totalIncome(player) * away * Config.Offline.rate)
	if earned <= 0 then return end
	prof.Cash = prof.Cash + earned
	-- the client shows a "Welcome back" window with this
	player:SetAttribute("OfflineEarned", earned)
	player:SetAttribute("OfflineAway", away)
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local spd = Instance.new("NumberValue")
	spd.Name = "Speed"
	spd.Value = Config.StartSpeed
	spd.Parent = ls
	ls.Parent = player

	local prof = newProfile()
	local loadFailed = false
	local lastOnline = nil
	if store then
		-- if loading keeps failing we must NOT save over the player's real data later
		local ok, data = loadData(player)
		if not ok then
			loadFailed = true
			task.delay(4, function()
				if not player.Parent then return end
				if RunService:IsStudio() then
					notify(player, "Saving is OFF in Studio: Game Settings > Security > Enable Studio Access to API Services.", YELLOW)
				else
					notify(player, "Couldn't load your save - progress this session won't be saved. Try rejoining!", RED)
				end
			end)
		elseif type(data) == "table" then
			lastOnline = readSave(prof, data)
		end
	end
	-- older saves had fixed pads: give those boxes a spot on the floor
	local fixed, n = {}, 0
	for k, e in pairs(prof.Unboxing) do
		if type(e) == "table" and e.id and Config.Boxes[e.id] then
			n = n + 1
			e.readyAt = tonumber(e.readyAt) or 0
			e.duration = tonumber(e.duration) or 1
			if e.u == nil then
				e.u = -30 + ((n - 1) % 6) * 12
				e.w = 30 + math.floor((n - 1) / 6) * 12
				e.rot = 0
			end
			fixed[tostring(k)] = e
		end
	end
	prof.Unboxing = fixed
	if not player.Parent then return end
	profiles[player] = prof
	if loadFailed then dontSave[player] = true end
	if not store then
		task.delay(4, function()
			if player.Parent then notify(player, "Saving is OFF here (in Studio: Game Settings > Security > Enable Studio Access to API Services).", YELLOW) end
		end)
	end

	loadPasses(player) -- which game passes they own
	if not player.Parent then return end
	giftStart[player] = now()
	giftClaimed[player] = {}
	syncGifts(player)
	player:SetAttribute("SpeedBoost", prof.SpeedBoost or 1)
	applySpeed(player) -- shows your speed number right away
	local plot = assignPlot(player)
	loadFriends(player)
	refreshPads(player)
	refreshStands(player)
	refreshTreadmill(player)
	refreshKiosk(player)
	giveOfflineEarnings(player, prof, lastOnline)
	refreshIncome(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	-- character removed without dying (reset / respawn): the carried box went with it
	player.CharacterRemoving:Connect(function()
		releaseCarry(player)
		ragdolled[player] = nil
		setChased(player, false)
	end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	sync(player)
	player:SetAttribute("Loaded", true)

	task.delay(2, function()
		if not player.Parent then return end
		notify(player, "Welcome to STEAL A BOX!", YELLOW)
		if not plot then notify(player, "All bases are taken - you can't stash boxes this round.", RED) end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

Players.PlayerRemoving:Connect(function(player)
	save(player, true)
	friendsOf[player] = nil
	giftStart[player] = nil
	giftClaimed[player] = nil
	dontSave[player] = nil
	releaseCarry(player)
	freePlot(player)
	profiles[player] = nil
	passOwned[player] = nil
	carrying[player] = nil
	immuneUntil[player] = nil
	ragdolled[player] = nil
	lastWrongBase[player] = nil
	lastAction[player] = nil
	nextCodeTry[player] = nil
	slowMode[player] = nil
end)

-- server shutting down: save everyone at the same time and wait until every save is done
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(save, p, true) end
	task.wait()
	local started = os.clock()
	while savesInFlight > 0 and os.clock() - started < 25 do task.wait(0.1) end
end)

-- autosave every minute (also keeps this server's claim on the save fresh)
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do
			if profiles[p] then task.spawn(save, p) end
		end
	end
end)

------------------------------------------------------------------
-- FREE GIFT in the lobby: walk up and claim free cash every few minutes
------------------------------------------------------------------
do
	local lobby = world:FindFirstChild("Lobby")
	local gift = lobby and lobby:FindFirstChild("FreeGift")
	local prompt = gift and gift:FindFirstChild("FreeGiftPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			local prof = profiles[player]
			if not prof then return end
			local now = os.time()
			if (prof.FreeGiftAt or 0) > now then
				notify(player, "Next free gift in " .. Config.FormatTime((prof.FreeGiftAt or 0) - now), Color3.fromRGB(255, 220, 90))
				return
			end
			local cash = Config.FreeGiftCash(totalIncome(player))
			prof.Cash = prof.Cash + cash
			prof.FreeGiftAt = now + Config.FreeGift.minutes * 60
			sync(player)
			notify(player, "FREE GIFT! +$" .. Config.FormatNum(cash), Color3.fromRGB(120, 255, 90))
			FXEvent:FireAllClients("LevelUp", gift:GetPivot().Position, 2)
		end)
	end
end

------------------------------------------------------------------
-- LEADERBOARDS: Top Money and Top Speed on the lobby wall (all servers, best 10)
------------------------------------------------------------------
do
	local lobby = world:FindFirstChild("Lobby")
	local boards = {
		{key = "Cash", stat = "TopMoney", part = lobby and lobby:FindFirstChild("BoardTopMoney"), prefix = "$", color = Color3.fromRGB(120, 255, 90)},
		{key = "SpeedPoints", stat = "TopSpeed", part = lobby and lobby:FindFirstChild("BoardTopSpeed"), prefix = "", color = Color3.fromRGB(110, 190, 255)},
	}
	local names = {}
	local function nameOf(userId)
		if names[userId] then return names[userId] end
		local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		names[userId] = ok and n or ("Player " .. userId)
		return names[userId]
	end
	-- each board gets 10 rows of text
	for _, b in ipairs(boards) do
		if b.part then
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.LightInfluence = 0
			gui.Parent = b.part
			local list = Instance.new("Frame")
			list.BackgroundTransparency = 1
			list.Size = UDim2.new(0.86, 0, 0.78, 0)
			list.Position = UDim2.fromScale(0.07, 0.17)
			list.Parent = gui
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0.01, 0)
			layout.Parent = list
			b.rows = {}
			for i = 1, 10 do
				local row = Instance.new("TextLabel")
				row.Size = UDim2.new(1, 0, 0.09, 0)
				row.BackgroundColor3 = ({Color3.fromRGB(255, 190, 40), Color3.fromRGB(185, 195, 215), Color3.fromRGB(205, 125, 60)})[i] or Color3.fromRGB(50, 56, 80)
				row.BackgroundTransparency = 0.15
				local rc = Instance.new("UICorner")
				rc.CornerRadius = UDim.new(0.25, 0)
				rc.Parent = row
				row.FontFace = Config.Font
				row.TextScaled = true
				row.TextColor3 = Color3.new(1, 1, 1)
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Text = ""
				row.LayoutOrder = i
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Parent = row
				row.Parent = list
				b.rows[i] = row
			end
			pcall(function() b.store = DataStoreService:GetOrderedDataStore("StealABox_" .. b.stat) end)
		end
	end
	-- big numbers don't fit an ordered store: store log10(value) * 1e6, it only has to keep the order
	local function encode(v) return math.floor(math.log10(math.max(1, v)) * 1e6) end
	local function decode(v) return 10 ^ (v / 1e6) end
	local function refresh()
		for _, b in ipairs(boards) do
			if b.rows then
				local best = {}
				for _, p in ipairs(Players:GetPlayers()) do
					local prof = profiles[p]
					if prof then
						best[p.UserId] = {name = p.Name, value = tonumber(prof[b.key]) or 0}
						if b.store and not dontSave[p] then
							pcall(function() b.store:SetAsync(tostring(p.UserId), encode(tonumber(prof[b.key]) or 0)) end)
						end
					end
				end
				if b.store then
					pcall(function()
						local page = b.store:GetSortedAsync(false, 10):GetCurrentPage()
						for _, e in ipairs(page) do
							local id = tonumber(e.key)
							if id and not best[id] then best[id] = {name = nameOf(id), value = decode(e.value)} end
						end
					end)
				end
				local list = {}
				for _, e in pairs(best) do table.insert(list, e) end
				table.sort(list, function(x, y) return x.value > y.value end)
				for i, row in ipairs(b.rows) do
					local e = list[i]
					row.Text = e and ("  #" .. i .. "  " .. e.name .. "   " .. b.prefix .. Config.FormatNum(e.value)) or ""
					row.BackgroundTransparency = e and 0.15 or 1
				end
			end
		end
	end
	task.spawn(function()
		task.wait(5)
		while true do
			pcall(refresh)
			task.wait(60)
		end
	end)
end

------------------------------------------------------------------
-- EXPAND PLOT pads: stand on your green pad and press E to buy the next podium slot
------------------------------------------------------------------
do
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local pad = plot:FindFirstChild("ExpandPad", true)
		local pp = pad and (pad:FindFirstChild("ExpandClick") or pad:FindFirstChild("ExpandPrompt"))
		if pp then
			local signal = pp:IsA("ClickDetector") and pp.MouseClick or pp.Triggered
			signal:Connect(function(who)
				if playerPlot[who] ~= plot then
					notify(who, "That's not your plot!", RED)
					return
				end
				local prof = profiles[who]
				if not prof then return end
				local have = unlockedStands(prof)
				if have >= Config.MaxStands then
					notify(who, "Your plot is fully expanded!", YELLOW)
					return
				end
				local cost = Config.StandCost(have)
				if prof.Cash < cost then
					notify(who, "You need $" .. Config.FormatNum(cost) .. " to expand your plot!", RED)
					return
				end
				prof.Cash = prof.Cash - cost
				prof.ExtraStands = (prof.ExtraStands or 0) + 1
				refreshStands(who)
				refreshIncome(who)
				sync(who)
				FXEvent:FireAllClients("LevelUp", pad.Position, 1)
				notify(who, "Plot expanded! You now have " .. unlockedStands(prof) .. " slots.", GREEN)
			end)
		end
	end
end

------------------------------------------------------------------
-- ICON SHEETS: if an id is a Decal, use the image inside it. Clients read IconSheet1..3.
------------------------------------------------------------------
do
	local okIS, InsertService = pcall(function() return game:GetService("InsertService") end)
	for i, id in ipairs(Config.IconSheets or {}) do
		task.spawn(function()
			local image = "rbxassetid://" .. id
			if okIS and InsertService then
				local ok, model = pcall(function() return InsertService:LoadAsset(id) end)
				if ok and model then
					local d = model:FindFirstChildWhichIsA("Decal", true)
					if d and d.Texture ~= "" then image = d.Texture end
					model:Destroy()
				end
			end
			ReplicatedStorage:SetAttribute("IconSheet" .. i, image)
		end)
	end
end
