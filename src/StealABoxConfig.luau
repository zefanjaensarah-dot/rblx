--[[ STEAL A BOX - shared config (used by server, client AND the builder). Tweak freely! ]]
local Config = {}
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- The warehouse is one long lane: Area 1 starts at the front door, Area 10 is at the very back.
Config.Layout = {
	frontZ = -4,        -- inside face of the warehouse front wall
	sectionLen = 90,    -- area 1 is 90 studs deep; every next area is longer (see AreaLen)
	halfWidth = 63,     -- the warehouse is 126 studs wide (x -63..63)
	floorY = 0.75,
	wallHeight = 45,
	scale = 1.5,        -- the warehouse is built 1.5x the original size
}

-- ONE font everywhere: Fredoka One, the round bold font most big Roblox simulators use
Config.Font = Font.fromEnum(Enum.Font.FredokaOne)

-- the UI draws its own icons, so emoji are filtered out of text (the Robux symbol stays)
function Config.StripEmoji(str)
	if type(str) ~= "string" then return str end
	local out = {}
	local ok = pcall(function()
		for _, cp in utf8.codes(str) do
			local emoji = (cp >= 0x1F000 and cp <= 0x1FAFF) or (cp >= 0x2190 and cp <= 0x21FF) or (cp >= 0x2300 and cp <= 0x23FF)
				or (cp >= 0x2600 and cp <= 0x27BF) or (cp >= 0x2B00 and cp <= 0x2BFF)
				or cp == 0xFE0F or cp == 0x200D or cp == 0x20E3
			if not emoji then table.insert(out, utf8.char(cp)) end
		end
	end)
	if not ok then return str end
	local s = table.concat(out)
	s = s:gsub("%s%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

-- collision groups: players run straight through shoppers and shop furniture
Config.GroupPlayers = "SAB_Players"
Config.GroupPass = "SAB_Passthrough"

-- opening a box: better items charge up longer (and look a lot more epic). [tier] = seconds
Config.OpenTimes = {2.2, 3.0, 3.8, 5.0}
-- how long the 3D item hovers before it flies to your shelf
Config.RevealHold = {2.4, 2.9, 3.6, 4.8}
function Config.RevealTime(tier)
	return 0.55 + (Config.RevealHold[tier] or 2.4) + 0.8
end

-- the courtyard in front of the warehouse, with the 6 big plots
Config.Court = {
	halfWidth = 112,    -- x -112..112
	length = 300,       -- z 0..300
	plotWidth = 92,     -- along the street
	plotDepth = 92,     -- away from the street
}

-- rarity rules for the 3 boxes in each area: [1]=common [2]=rare [3]=epic
Config.Rarities = {
	{name = "Common", weight = 60, slow = 1,   hold = 0.4, color = rgb(220, 220, 220)},
	{name = "Rare",   weight = 30, slow = 2,   hold = 0.8, color = rgb(90, 170, 255)},
	{name = "Epic",   weight = 10, slow = 3,   hold = 1.3, color = rgb(200, 110, 255)},
}

-- MUTATIONS: rolled for every box. mult = cash multiplier
Config.Mutations = {
	{id = "Normal",  chance = 70,  mult = 1,  color = nil},
	{id = "Gold",    chance = 14,  mult = 2,  color = rgb(255, 200, 40)},
	{id = "Diamond", chance = 8,   mult = 3,  color = rgb(120, 230, 255)},
	{id = "Lava",    chance = 5,   mult = 4,  color = rgb(255, 95, 20)},
	{id = "Rainbow", chance = 2.5, mult = 6,  color = rgb(255, 120, 220)},
	{id = "Galaxy",  chance = 0.5, mult = 10, color = rgb(150, 80, 255)},
}

-- SIZES: rolled for every box. scale = how big, mult = cash multiplier, slow = extra carry slowdown
-- SIZE RNG: every box rolls a size. Bigger = worth more but slows you down while you carry it,
-- smaller = worth less but you run FASTER (slow < 0). Keep the order small -> big.
Config.Sizes = {
	{id = "Microscopic", chance = 3,   scale = 0.4, mult = 0.3, slow = -4},
	{id = "Tiny",        chance = 8,   scale = 0.6, mult = 0.5, slow = -2},
	{id = "Small",       chance = 18,  scale = 0.8, mult = 0.8, slow = -0.5},
	{id = "Normal",      chance = 40,  scale = 1,   mult = 1,   slow = 0},
	{id = "Big",         chance = 15,  scale = 1.3, mult = 1.6, slow = 1},
	{id = "Huge",        chance = 8,   scale = 1.5, mult = 2.5, slow = 2},
	{id = "Giant",       chance = 5,   scale = 1.8, mult = 4,   slow = 3.5},
	{id = "Colossal",    chance = 2.5, scale = 2.3, mult = 7,   slow = 5},
	{id = "Titanic",     chance = 0.5, scale = 2.8, mult = 12,  slow = 7},
}
Config.ShelfMaxSize = 5 -- boxes on warehouse shelves can be at most "Big" (index 5); pallets can hold anything

function Config.GetMutation(id)
	for _, m in ipairs(Config.Mutations) do if m.id == id then return m end end
	return Config.Mutations[1]
end
function Config.GetSize(id)
	for _, s in ipairs(Config.Sizes) do if s.id == id then return s end end
	for _, s in ipairs(Config.Sizes) do if s.id == "Normal" then return s end end
	return Config.Sizes[1]
end
function Config.BoxLabel(def, mutationId, sizeId)
	local parts = {}
	if sizeId and sizeId ~= "Normal" then table.insert(parts, sizeId) end
	if mutationId and mutationId ~= "Normal" then table.insert(parts, mutationId) end
	table.insert(parts, def.name)
	return table.concat(parts, " ")
end

-- AREAS. guard = the guardian of that area (weak at the start, terrifying at the end).
-- guardSpeed = chase speed, fling = how hard he flings you when he catches you.
Config.Areas = {
	{name = "Dusty Storage", face = "🙂", accent = rgb(200, 165, 110), guardSpeed = 12, fling = 60, recommended = 0,
		guard = "Sleepy Watchman", boxes = {
		{id = "OldBox",       name = "Old Box",        emoji = "📦", value = 5,     color = rgb(160, 130, 95),  material = M.SmoothPlastic},
		{id = "DustyCrate",   name = "Dusty Crate",    emoji = "🕸️", value = 12,    color = rgb(125, 100, 75),  material = M.WoodPlanks},
		{id = "AntiqueChest", name = "Antique Chest",  emoji = "🏺", value = 30,    color = rgb(120, 75, 40),   material = M.Wood},
	}},
	{name = "Farm Barn", face = "😐", accent = rgb(230, 80, 60), guardSpeed = 18, fling = 90, recommended = 0,
		guard = "Rookie Guard", boxes = {
		{id = "HayBox",       name = "Hay Box",        emoji = "🌾", value = 25,    color = rgb(235, 200, 90),  material = M.Fabric},
		{id = "EggCrate",     name = "Egg Crate",      emoji = "🥚", value = 45,    color = rgb(245, 238, 220), material = M.SmoothPlastic},
		{id = "GoldenEgg",    name = "Golden Egg Box", emoji = "🐣", value = 90,    color = rgb(255, 215, 90),  material = M.SmoothPlastic},
	}},
	{name = "Toy Factory", face = "😮", accent = rgb(90, 170, 255), guardSpeed = 22, fling = 120, recommended = 0,
		guard = "Mall Cop", boxes = {
		{id = "TeddyBox",     name = "Teddy Box",      emoji = "🧸", value = 60,    color = rgb(205, 145, 95),  material = M.Fabric},
		{id = "RobotToyBox",  name = "Robot Toy Box",  emoji = "🤖", value = 100,   color = rgb(120, 200, 255), material = M.SmoothPlastic},
		{id = "RocketToyBox", name = "Rocket Toy Box", emoji = "🚀", value = 180,   color = rgb(255, 90, 90),   material = M.SmoothPlastic},
	}},
	{name = "Candy Shop", face = "😬", accent = rgb(255, 110, 200), guardSpeed = 26, fling = 150, recommended = 0,
		guard = "Candy Bouncer", boxes = {
		{id = "CandyBox",     name = "Candy Box",      emoji = "🍬", value = 120,   color = rgb(255, 150, 210), material = M.SmoothPlastic},
		{id = "CupcakeBox",   name = "Cupcake Box",    emoji = "🧁", value = 200,   color = rgb(255, 220, 150), material = M.SmoothPlastic},
		{id = "ChocoBox",     name = "Chocolate Box",  emoji = "🍫", value = 350,   color = rgb(110, 60, 35),   material = M.SmoothPlastic},
	}},
	{name = "Pirate Cove", face = "😟", accent = rgb(60, 170, 220), guardSpeed = 30, fling = 180, recommended = 0,
		guard = "Pirate Brute", boxes = {
		{id = "PirateCrate",  name = "Pirate Crate",   emoji = "⚓", value = 250,   color = rgb(140, 100, 60),  material = M.WoodPlanks},
		{id = "TreasureChest",name = "Treasure Chest", emoji = "💰", value = 400,   color = rgb(185, 120, 40),  material = M.Wood},
		{id = "CursedChest",  name = "Cursed Chest",   emoji = "💀", value = 700,   color = rgb(100, 45, 140),  material = M.SmoothPlastic},
	}},
	{name = "Dino Museum", face = "😰", accent = rgb(130, 200, 80), guardSpeed = 34.5, fling = 210, recommended = 0,
		guard = "Riot Guard", boxes = {
		{id = "FossilBox",    name = "Fossil Box",     emoji = "🦴", value = 500,   color = rgb(225, 212, 180), material = M.Sandstone},
		{id = "DinoEggBox",   name = "Dino Egg Box",   emoji = "🦕", value = 800,   color = rgb(150, 205, 120), material = M.SmoothPlastic},
		{id = "TRexBox",      name = "T-Rex Box",      emoji = "🦖", value = 1400,  color = rgb(60, 145, 60),   material = M.SmoothPlastic},
	}},
	{name = "Frozen Lab", face = "😨", accent = rgb(140, 220, 255), guardSpeed = 39, fling = 240, recommended = 0,
		guard = "Yeti Guard", boxes = {
		{id = "IceBox",       name = "Ice Box",        emoji = "❄️", value = 1000,  color = rgb(185, 230, 255), material = M.Ice},
		{id = "PenguinBox",   name = "Penguin Box",    emoji = "🐧", value = 1600,  color = rgb(45, 45, 55),    material = M.SmoothPlastic},
		{id = "MammothBox",   name = "Mammoth Box",    emoji = "🐘", value = 2800,  color = rgb(135, 95, 70),   material = M.Fabric},
	}},
	{name = "Tech Lab", face = "😱", accent = rgb(60, 150, 255), guardSpeed = 44, fling = 270, recommended = 0,
		guard = "Security Mech", boxes = {
		{id = "CircuitBox",   name = "Circuit Box",    emoji = "💾", value = 2000,  color = rgb(40, 165, 85),   material = M.SmoothPlastic},
		{id = "RobotBox",     name = "Robot Box",      emoji = "🤖", value = 3200,  color = rgb(185, 195, 205), material = M.Metal},
		{id = "AICoreBox",    name = "AI Core Box",    emoji = "🧠", value = 5500,  color = rgb(60, 200, 255),  material = M.Neon},
	}},
	{name = "Alien Hangar", face = "💀", accent = rgb(90, 255, 90), guardSpeed = 49, fling = 300, recommended = 0,
		guard = "Alien Enforcer", boxes = {
		{id = "AlienBox",     name = "Alien Box",      emoji = "👽", value = 4000,  color = rgb(110, 230, 110), material = M.SmoothPlastic},
		{id = "UFOBox",       name = "UFO Box",        emoji = "🛸", value = 6500,  color = rgb(175, 185, 205), material = M.Metal},
		{id = "PlasmaBox",    name = "Plasma Core Box",emoji = "☢️", value = 11000, color = rgb(150, 255, 80),  material = M.Neon},
	}},
	{name = "Galaxy Vault", face = "👿", accent = rgb(180, 90, 255), guardSpeed = 55, fling = 340, recommended = 0,
		guard = "Void Warden", boxes = {
		{id = "StarBox",      name = "Star Box",       emoji = "⭐", value = 8000,  color = rgb(255, 230, 80),  material = M.Neon},
		{id = "GalaxyBox",    name = "Galaxy Box",     emoji = "🌌", value = 13000, color = rgb(95, 55, 185),   material = M.Glass},
		{id = "BlackHoleBox", name = "Black Hole Box", emoji = "🕳️", value = 25000, color = rgb(20, 12, 30),    material = M.SmoothPlastic},
	}},
}

-- lookup: Config.Boxes[id] = box def (with .area and .rarity filled in)
Config.Boxes = {}
for areaIndex, area in ipairs(Config.Areas) do
	area.index = areaIndex
	for r, box in ipairs(area.boxes) do
		box.area = areaIndex
		box.rarity = r
		Config.Boxes[box.id] = box
	end
end

-- z where an area starts (its entrance arch)
-- speed you should have (while carrying) to escape an area's guardian
function Config.RecommendedSpeed(areaIndex)
	return math.ceil(Config.Areas[areaIndex].guardSpeed * 0.88 + 2)
end

------------------------------------------------------------------
-- SPEED: your speed is a BIG number. It starts at 100 and grows into the thousands, millions
-- and beyond. How fast you actually run grows with it: every time your speed doubles you run
-- SpeedPerDoubling (walk speed) faster. 100 = normal, ~1K = quick, ~1M = really fast.
------------------------------------------------------------------
Config.StartSpeed = 100
Config.SpeedPerDoubling = 2.6
Config.MaxWalkSpeed = 120
function Config.PointsToWalk(points)
	points = math.max(Config.StartSpeed, tonumber(points) or Config.StartSpeed)
	return math.min(Config.MaxWalkSpeed, 16 + Config.SpeedPerDoubling * math.log(points / Config.StartSpeed, 2))
end
function Config.WalkToPoints(walk)
	return Config.StartSpeed * 2 ^ (math.max(0, (walk or 16) - 16) / Config.SpeedPerDoubling)
end
-- a round number (2 significant digits, rounded up): 1437 -> 1500
local function niceUp(n)
	if n <= 0 then return 0 end
	local mag = 10 ^ math.max(0, math.floor(math.log10(n)) - 1)
	return math.ceil(n / mag) * mag
end
-- the speed number you should have to escape an area's guardian
function Config.RecommendedPoints(areaIndex)
	return niceUp(Config.WalkToPoints(Config.RecommendedSpeed(areaIndex)))
end
-- 1234 -> "1234", 362900 -> "362.9K", 4500000 -> "4.5M" ... all the way up to decillions
local NUM_SUFFIXES = {"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
function Config.FormatNum(n)
	n = tonumber(n) or 0
	if n ~= n then return "0" end -- NaN
	local negative = n < 0
	n = math.floor(math.abs(n) + 0.5)
	local out
	if n < 1e4 then
		out = tostring(n)
	else
		local tier = math.min(#NUM_SUFFIXES, math.floor(math.log10(n) / 3))
		local v = n / 10 ^ (tier * 3)
		if v >= 1000 and tier < #NUM_SUFFIXES then -- log10 rounding (999.99... -> next suffix)
			tier += 1
			v = n / 10 ^ (tier * 3)
		elseif v < 1 and tier > 1 then
			tier -= 1
			v = n / 10 ^ (tier * 3)
		end
		local str = string.format("%.1f", math.floor(v * 10) / 10) -- round down: never show more than you have
		if str:sub(-2) == ".0" then str = str:sub(1, -3) end
		out = str .. NUM_SUFFIXES[tier]
	end
	return negative and ("-" .. out) or out
end
-- 75 -> "1:15", 3725 -> "1:02:05"
function Config.FormatTime(sec)
	sec = math.max(0, math.ceil(tonumber(sec) or 0))
	local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
	return string.format("%d:%02d", m, s)
end

function Config.AreaStartZ(areaIndex)
	local L = Config.Layout
	return L.frontZ - (areaIndex - 1) * L.sectionLen
end

-- which area a position is in (1..10), or nil when outside the warehouse
function Config.ZoneAt(pos)
	local L = Config.Layout
	if math.abs(pos.X) > L.halfWidth + 1 then return nil end
	local depth = L.frontZ - pos.Z
	if depth < 0 or depth > #Config.Areas * L.sectionLen then return nil end
	return math.min(#Config.Areas, math.floor(depth / L.sectionLen) + 1)
end

-- TRAILS sold at the TRAIL SHOP booth: a glowing trail behind you that makes
-- your treadmill give more speed per second (buy once, equip your favourite)
Config.Trails = {
	{id = "Dust",     name = "Dust Trail",     mult = 1.25, price = 150,     colors = {rgb(235, 225, 200), rgb(255, 255, 255)}},
	{id = "Leaf",     name = "Leaf Trail",     mult = 1.6,  price = 700,     colors = {rgb(90, 220, 90), rgb(200, 255, 140)}},
	{id = "Ocean",    name = "Ocean Trail",    mult = 2.2,  price = 3000,    colors = {rgb(40, 140, 255), rgb(120, 230, 255)}},
	{id = "Fire",     name = "Fire Trail",     mult = 3,    price = 12000,   colors = {rgb(255, 60, 20), rgb(255, 210, 60)}},
	{id = "Electric", name = "Electric Trail", mult = 4.2,  price = 50000,   colors = {rgb(80, 230, 255), rgb(255, 255, 120)}},
	{id = "Candy",    name = "Candy Trail",    mult = 6,    price = 200000,  colors = {rgb(255, 110, 200), rgb(140, 220, 255)}},
	{id = "Galaxy",   name = "Galaxy Trail",   mult = 9,    price = 900000,  colors = {rgb(120, 40, 255), rgb(255, 120, 255)}},
	{id = "Rainbow",  name = "Rainbow Trail",  mult = 14,   price = 4000000, colors = {rgb(255, 80, 80), rgb(255, 220, 60), rgb(90, 230, 110), rgb(80, 170, 255), rgb(200, 110, 255)}},
}
-- the VIP Trail comes with the VIP game pass (it isn't sold at the booth)
Config.VIPTrail = {id = "VIP", name = "VIP Trail", mult = 8, price = 0, vip = true, colors = {rgb(255, 215, 60), rgb(255, 250, 200), rgb(255, 170, 40)}}
Config.Upgrades = {} -- (old upgrades were replaced by trails)
function Config.GetTrail(id)
	for _, t in ipairs(Config.Trails) do if t.id == id then return t end end
	if id == Config.VIPTrail.id then return Config.VIPTrail end
	return nil
end
function Config.TrailColor(t)
	local keys = {}
	for i, c in ipairs(t.colors) do keys[i] = ColorSequenceKeypoint.new((i - 1) / math.max(1, #t.colors - 1), c) end
	return ColorSequence.new(keys)
end

-- TREADMILL on your plot: stand on the belt and run to earn speed.
-- Upgrading it makes you earn speed faster.
Config.Treadmill = {max = 10, beltSpeed = 10}
function Config.TreadRate(level) -- speed earned per second of running (3/s at level 1, ~7.6K/s at level 10)
	return 3 * 2.4 ^ ((level or 1) - 1)
end
function Config.TreadmillCost(level) -- price to go from `level` to `level + 1`
	if (level or 1) <= 1 then return 50 end -- the first upgrade is cheap (end of the tutorial)
	return math.floor(250 * 2.6 ^ ((level or 1) - 2))
end

-- ROBUX SPEED BOOSTS: multiply the speed your treadmill gives you (stacks with trails).
-- It keeps doubling: 2x for 3 Robux, 4x for 6, 8x for 12, 16x for 24 ... and so on.
-- Bought in order. Change SpeedBoostTiers to have more (or fewer) steps.
-- The product IDs live in ReplicatedStorage > StealABoxShop (SpeedBoostIds), with everything else you sell.
Config.SpeedBoostTiers = 10
Config.SpeedBoosts = {}
for n = 1, Config.SpeedBoostTiers do
	Config.SpeedBoosts[n] = {mult = 2 ^ n, robux = 3 * 2 ^ (n - 1)}
end
Config.RobuxIcon = utf8.char(0xE002) -- the Robux symbol in Roblox fonts

-- PLAYTIME GIFTS: the longer you stay, the better the gifts. Each gift is random:
-- cash or a free box (placed right on your plot). After the last one the timer starts over.
Config.Gifts = {
	{minutes = 1,  boxChance = 0.35}, {minutes = 3,  boxChance = 0.4}, {minutes = 6,  boxChance = 0.45},
	{minutes = 10, boxChance = 0.5},  {minutes = 15, boxChance = 0.55}, {minutes = 20, boxChance = 0.6},
	{minutes = 30, boxChance = 0.65}, {minutes = 45, boxChance = 0.75}, {minutes = 60, boxChance = 1},
}
function Config.GiftCash(index, incomePerSec) -- cash a gift is worth
	local base = math.floor(40 * 1.75 ^ (index - 1))
	return math.max(base, math.floor((incomePerSec or 0) * 20 * index))
end
function Config.GiftMaxArea(index) -- best warehouse a gift box can come from
	return math.min(#Config.Areas, 1 + math.floor(index * 0.75))
end

-- CUSTOMER KIOSK on your plot: more shoppers = more money
Config.CustomerMax = 10
function Config.CustomerRate(level) return 1 + 0.3 * ((level or 1) - 1) end -- x shoppers
function Config.CustomerCost(level) return math.floor(120 * 2.3 ^ ((level or 1) - 1)) end

------------------------------------------------------------------
-- INDEX REWARDS: find all 4 items of a warehouse area to complete that area's Index page.
-- Claim it once for a pile of cash and a PERMANENT cash bonus (every area adds more).
------------------------------------------------------------------
Config.IndexReward = {
	seconds = 900,     -- the cash = 15 minutes of what that area's 4 items earn together
	cashBonus = 0.1,   -- +10% cash forever for every completed area (all 10 = x2)
}
function Config.IndexCash(areaIndex)
	local total = 0
	for _, it in ipairs(Config.AreaItems[areaIndex] or {}) do
		local def = Config.Items[it[1]]
		if def then total = total + def.income end
	end
	return math.floor(total * Config.IndexReward.seconds)
end
function Config.IndexCashMult(claimedCount) return 1 + Config.IndexReward.cashBonus * (claimedCount or 0) end
-- true when every item of this area is in your Index
function Config.AreaComplete(itemsFound, areaIndex)
	for _, it in ipairs(Config.AreaItems[areaIndex] or {}) do
		if not (itemsFound and (itemsFound[it[1]] or 0) > 0) then return false end
	end
	return true
end
function Config.CountClaimed(claimed)
	local n = 0
	for _ in pairs(claimed or {}) do n = n + 1 end
	return n
end

------------------------------------------------------------------
-- DAILY REWARDS: log in every day for a 7-day streak (miss a day and it starts over).
-- kind = "cash" (worth `minutes` of your income, at least `base`), "box" (a free box from
-- your best warehouse area) or "luckybox" (a guaranteed Rainbow box).
------------------------------------------------------------------
Config.Daily = {
	{kind = "cash", minutes = 5, base = 500},
	{kind = "cash", minutes = 10, base = 1500},
	{kind = "box"},
	{kind = "cash", minutes = 20, base = 6000},
	{kind = "cash", minutes = 30, base = 15000},
	{kind = "box"},
	{kind = "luckybox"},
}
function Config.DailyCash(reward, incomePerSec)
	return math.max(reward.base or 0, math.floor((incomePerSec or 0) * 60 * (reward.minutes or 0)))
end
function Config.DayNumber(unixTime) return math.floor((unixTime or os.time()) / 86400) end

------------------------------------------------------------------
-- CODES: players type these in the Codes window (not case sensitive). Add your own!
-- cash = money, speed = speed points, box = true gives a free box.
-- Share new codes on your group / socials to bring players back.
------------------------------------------------------------------
Config.Codes = {
	RELEASE = {cash = 2500},
	STEALABOX = {box = true},
	ZOOM = {speed = 500},
}

-- OFFLINE EARNINGS: your shop keeps selling while you're away (a part of your income)
Config.Offline = {rate = 0.25, maxHours = 8, minMinutes = 2}

-- GAME PASS EFFECTS (the passes themselves are set up in ReplicatedStorage > StealABoxShop)
Config.PassEffects = {
	VIPCash = 1.5,     -- VIP: +50% cash
	DoubleCash = 2,    -- 2x Cash
	FastUnbox = 0.5,   -- Fast Unboxing: boxes take half the time
	ExtraPads = 4,     -- Bigger Base: +4 boxes unboxing at once
	LuckyRerolls = 1,  -- Lucky Hands: a Normal box you bring home gets 1 extra mutation roll
}
-- SERVER LUCK (a Robux product): everyone in the server gets more mutations for a while
Config.ServerLuck = {minutes = 15, mult = 2}

------------------------------------------------------------------
-- UNBOXING + ITEMS
------------------------------------------------------------------
Config.UnboxPads = 6          -- boxes you can have unboxing on your plot at the same time
Config.ShelfUnits = 5         -- shelves at the back of your plot
Config.ShelfLayers = 3        -- layers per shelf
Config.ShelfCols = 3          -- products per layer
Config.MaxStands = Config.ShelfUnits * Config.ShelfLayers * Config.ShelfCols -- 45 products on display
Config.BaseStands = Config.MaxStands
Config.MaxItems = 60          -- inventory size

-- CUSTOMERS: shoppers walk into your shop, take a product (stock never runs out) and pay on the spot.
-- Your shop earns its full $/s all the time: each shopper pays everything the shop earned since
-- the last sale, so you never lose money when the shop gets busy.
Config.SaleSeconds = 6
Config.MaxCustomers = 8       -- per shop at the same time (more = more lag for everyone)
Config.MinCustomerGap = 1.2   -- a new shopper at most every 1.2 s per shop
Config.CustomerSpeed = 16

-- how long a box takes to open (seconds)
function Config.UnboxTime(def, sizeId, unboxLevel)
	local t = (8 + def.area * 6) * ({1, 1.6, 2.4})[def.rarity] * math.sqrt(Config.GetSize(sizeId).scale)
	return math.floor(t * (1 - 0.08 * (unboxLevel or 0)) + 0.5)
end

-- item tiers: income/xp multipliers and roll weights for [common, rare, epic] boxes
Config.ItemTiers = {
	-- weights = drop chance in % for a {common, rare, epic} box (each column adds up to 100)
	{name = "Common",    mult = 1,  color = rgb(220, 220, 220), weights = {79, 55, 35}},
	{name = "Uncommon",  mult = 2,  color = rgb(110, 230, 110), weights = {15, 28, 32}},
	{name = "Rare",      mult = 4,  color = rgb(90, 170, 255),  weights = {5, 13, 23}},
	{name = "Legendary", mult = 10, color = rgb(255, 190, 40),  weights = {1, 4, 10}},
}

-- 4 themed items per area, from common to legendary
Config.AreaItems = {
	{{"OldSpoon", "Old Spoon", "🥄"}, {"RustyKey", "Rusty Key", "🗝️"}, {"PocketWatch", "Pocket Watch", "⌚"}, {"AntiqueVase", "Antique Vase", "🏺"}},
	{{"Carrot", "Carrot", "🥕"}, {"Corn", "Golden Corn", "🌽"}, {"MilkJug", "Milk Jug", "🥛"}, {"GoldenEgg", "Golden Egg", "🥚"}},
	{{"Teddy", "Teddy Bear", "🧸"}, {"Puzzle", "Puzzle", "🧩"}, {"Controller", "Game Controller", "🎮"}, {"ToyRobot", "Toy Robot", "🤖"}},
	{{"Lollipop", "Lollipop", "🍭"}, {"Donut", "Donut", "🍩"}, {"Cake", "Party Cake", "🍰"}, {"CandyCrown", "Candy Crown", "👑"}},
	{{"Shell", "Sea Shell", "🐚"}, {"Compass", "Compass", "🧭"}, {"Spyglass", "Spyglass", "🔭"}, {"TreasureMap", "Treasure Map", "🗺️"}},
	{{"Bone", "Dino Bone", "🦴"}, {"Footprint", "Fossil Print", "🐾"}, {"DinoPlush", "Dino Plushie", "🦕"}, {"TRexSkull", "T-Rex Skull", "💀"}},
	{{"Snowflake", "Snowflake", "❄️"}, {"FrozenFish", "Frozen Fish", "🐟"}, {"Snowman", "Snowman", "⛄"}, {"IceGem", "Ice Gem", "💎"}},
	{{"Battery", "Battery", "🔋"}, {"Chip", "Memory Chip", "💾"}, {"Laptop", "Laptop", "💻"}, {"Satellite", "Satellite", "🛰️"}},
	{{"Comet", "Comet Shard", "☄️"}, {"CrystalBall", "Crystal Ball", "🔮"}, {"UFOModel", "UFO Model", "🛸"}, {"AlienPlush", "Alien Plushie", "👽"}},
	{{"Moon", "Moon Rock", "🌙"}, {"Shooting", "Shooting Star", "🌠"}, {"GalaxyOrb", "Galaxy Orb", "🌌"}, {"BlackHoleCore", "Black Hole Core", "🕳️"}},
}
Config.Items = {}
for areaIndex, list in ipairs(Config.AreaItems) do
	for tier, it in ipairs(list) do
		Config.Items[it[1]] = {id = it[1], name = it[2], emoji = it[3], area = areaIndex, tier = tier,
			income = math.floor(2.2 ^ (areaIndex - 1) * Config.ItemTiers[tier].mult + 0.5)}
	end
end

-- income ($/s) of one owned item {id, mutation, size}
function Config.ItemIncome(item)
	local def = Config.Items[item.id]
	if not def then return 0 end
	return math.floor(def.income * Config.GetMutation(item.mutation).mult * Config.GetSize(item.size).mult + 0.5)
end
function Config.ItemLabel(item)
	local def = Config.Items[item.id]
	local parts = {}
	if item.size and item.size ~= "Normal" then table.insert(parts, item.size) end
	if item.mutation and item.mutation ~= "Normal" then table.insert(parts, item.mutation) end
	table.insert(parts, def and def.name or "?")
	return table.concat(parts, " ")
end

function Config.UpgradeCost(u, level)
	return math.floor(u.base * u.growth ^ level)
end

-- DAY / NIGHT (seconds): boxes only restock at night
Config.DayLength = 240
Config.NightLength = 30

-- Events: every few minutes a guaranteed Rainbow or Galaxy box appears somewhere
Config.SpecialBoxEvery = 120

------------------------------------------------------------------
-- CLASSIC R6 AVATAR (Noob / Bacon Hair) used by guardians and customers.
-- A real R6 rig (HumanoidRootPart + Motor6Ds) so the classic R6
-- animations can play on it. opt = {name, scale, cframe (HumanoidRootPart),
-- head, torso, leftArm, rightArm, leftLeg, rightLeg (Color3s), face = true/false}
------------------------------------------------------------------
Config.NoobColors = {
	head = Color3.fromRGB(245, 205, 48),   -- Bright yellow
	torso = Color3.fromRGB(13, 105, 172),  -- Bright blue
	legs = Color3.fromRGB(164, 189, 71),   -- Br. yellowish green
}
Config.R6Anims = { -- Roblox's own R6 animations (every game can use them)
	idle = "rbxassetid://180435571",
	walk = "rbxassetid://180426354",
	point = "rbxassetid://128853357",
	cheer = "rbxassetid://129423030",
	laugh = "rbxassetid://129423131",
	wave = "rbxassetid://128777973",
	dance = "rbxassetid://182435998",
}
Config.BaconHairId = 63690008 -- "Pal Hair", the classic bacon hair (made by Roblox)

function Config.MakeR6(opt)
	local s = opt.scale or 1
	local root = opt.cframe or CFrame.new(0, 3 * s, 0)
	local m = Instance.new("Model")
	m.Name = opt.name or "Noob"
	local function part(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = color or Color3.new(1, 1, 1)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = root * CFrame.new(offset * s)
		p.Parent = m
		return p
	end
	local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	hrp.Transparency = 1
	hrp.Anchored = true
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), opt.torso or Config.NoobColors.torso)
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), opt.head or Config.NoobColors.head)
	local la = part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), opt.leftArm or opt.head or Config.NoobColors.head)
	local ra = part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), opt.rightArm or opt.head or Config.NoobColors.head)
	local ll = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), opt.leftLeg or Config.NoobColors.legs)
	local rl = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), opt.rightLeg or Config.NoobColors.legs)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	if opt.face ~= false then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end
	for _, a in ipairs({{"HairAttachment", 0.6}, {"HatAttachment", 0.6}}) do
		local at = Instance.new("Attachment")
		at.Name = a[1]
		at.Position = Vector3.new(0, a[2] * s, 0)
		at.Parent = head
	end
	local fa = Instance.new("Attachment")
	fa.Name = "FaceFrontAttachment"
	fa.Position = Vector3.new(0, 0, -0.6 * s)
	fa.Parent = head
	-- the standard R6 attachment points, so real avatars' accessories fit (friend shoppers)
	local function att(part, name, x, y, z)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(x, y, z) * s
		a.Parent = part
	end
	att(head, "FaceCenterAttachment", 0, 0, 0)
	att(torso, "NeckAttachment", 0, 1, 0)
	att(torso, "BodyFrontAttachment", 0, 0, -0.5)
	att(torso, "BodyBackAttachment", 0, 0, 0.5)
	att(torso, "LeftCollarAttachment", -1, 1, 0)
	att(torso, "RightCollarAttachment", 1, 1, 0)
	att(torso, "WaistFrontAttachment", 0, -1, -0.5)
	att(torso, "WaistCenterAttachment", 0, -1, 0)
	att(torso, "WaistBackAttachment", 0, -1, 0.5)
	att(la, "LeftShoulderAttachment", 0, 1, 0)
	att(la, "LeftGripAttachment", 0, -1, 0)
	att(ra, "RightShoulderAttachment", 0, 1, 0)
	att(ra, "RightGripAttachment", 0, -1, 0)
	att(ll, "LeftFootAttachment", 0, -1, 0)
	att(rl, "RightFootAttachment", 0, -1, 0)
	-- the standard R6 joints
	local function motor(name, p0, p1, c0, c1, r)
		local j = Instance.new("Motor6D")
		j.Name = name
		j.Part0 = p0
		j.Part1 = p1
		j.C0 = CFrame.new(c0 * s) * r
		j.C1 = CFrame.new(c1 * s) * r
		j.MaxVelocity = 0.1
		j.Parent = p0
		return j
	end
	local RJ = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local RL = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	local RR = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	motor("RootJoint", hrp, torso, Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), RJ)
	motor("Neck", torso, head, Vector3.new(0, 1, 0), Vector3.new(0, -0.5, 0), RJ)
	motor("Left Shoulder", torso, la, Vector3.new(-1, 0.5, 0), Vector3.new(0.5, 0.5, 0), RL)
	motor("Right Shoulder", torso, ra, Vector3.new(1, 0.5, 0), Vector3.new(-0.5, 0.5, 0), RR)
	motor("Left Hip", torso, ll, Vector3.new(-1, -1, 0), Vector3.new(-0.5, 1, 0), RL)
	motor("Right Hip", torso, rl, Vector3.new(1, -1, 0), Vector3.new(0.5, 1, 0), RR)
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = m
	local animator = Instance.new("Animator")
	animator.Parent = hum
	m.PrimaryPart = hrp
	return m, {hrp = hrp, torso = torso, head = head, leftArm = la, rightArm = ra, leftLeg = ll, rightLeg = rl, humanoid = hum, animator = animator}
end

-- glue an extra decoration part onto a body part (keeps its current position)
function Config.Attach(part, to)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
	return part
end

-- a part-built bacon hair, used if the real Pal Hair can't be loaded
function Config.FakeBaconHair(head, s)
	s = s or 1
	local m = head.Parent
	local base = head.CFrame
	local function piece(name, size, offset, color, rot)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = base * CFrame.new(offset * s) * (rot or CFrame.new())
		p.Parent = m
		return Config.Attach(p, head)
	end
	local brown, light = Color3.fromRGB(110, 55, 30), Color3.fromRGB(200, 120, 80)
	piece("BaconTop", Vector3.new(1.35, 0.3, 1.35), Vector3.new(0, 0.72, 0.03), brown)
	for i = -2, 2 do
		piece("BaconStrip", Vector3.new(0.22, 0.34, 1.38), Vector3.new(i * 0.28, 0.78, 0.03), (i % 2 == 0) and light or brown, CFrame.Angles(0, 0, math.rad(i * 6)))
	end
	piece("BaconBack", Vector3.new(1.35, 0.9, 0.25), Vector3.new(0, 0.35, 0.62), brown)
	piece("BaconSideL", Vector3.new(0.2, 0.6, 1), Vector3.new(-0.66, 0.4, 0.1), brown)
	piece("BaconSideR", Vector3.new(0.2, 0.6, 1), Vector3.new(0.66, 0.4, 0.1), brown)
end

------------------------------------------------------------------
-- 3D ITEM MODELS: every item is a little model built from parts.
-- Each entry: {shape, sizeX, sizeY, sizeZ, x, y, z, color, material, rotX, rotY, rotZ}
--   shape: "B" block, "S" sphere/ellipsoid, "C" cylinder (axis = X; rotZ 90 = standing up, rotY 90 = facing you)
-- Models are about 2 studs tall and face -Z (towards the viewer).
------------------------------------------------------------------
local function B(...) return {"B", ...} end
local function S(...) return {"S", ...} end
local function C(...) return {"C", ...} end
local MAT = Enum.Material
local metal, gold, bone = rgb(175, 178, 188), rgb(235, 190, 60), rgb(242, 236, 215)
local black, white = rgb(25, 25, 30), rgb(250, 250, 250)

Config.ItemModels = {
	-- 1 DUSTY STORAGE
	OldSpoon = {B(0.25, 1.5, 0.1, 0, 0.35, 0, metal, MAT.Metal), S(0.75, 0.95, 0.28, 0, -0.65, 0, metal, MAT.Metal), S(0.2, 0.25, 0.12, 0.1, -0.5, -0.12, rgb(150, 95, 55), MAT.CorrodedMetal)},
	RustyKey = {C(0.2, 1, 1, 0, 0.55, 0, rgb(150, 85, 45), MAT.CorrodedMetal, 0, 90, 0), C(0.22, 0.45, 0.45, 0, 0.55, 0, rgb(70, 40, 25), MAT.SmoothPlastic, 0, 90, 0),
		B(0.2, 1.3, 0.2, 0, -0.35, 0, rgb(150, 85, 45), MAT.CorrodedMetal), B(0.42, 0.16, 0.2, 0.2, -0.85, 0, rgb(150, 85, 45), MAT.CorrodedMetal), B(0.32, 0.16, 0.2, 0.15, -0.58, 0, rgb(150, 85, 45), MAT.CorrodedMetal)},
	PocketWatch = {C(0.35, 1.4, 1.4, 0, 0, 0, gold, MAT.Metal, 0, 90, 0), C(0.37, 1.15, 1.15, 0, 0, 0, white, MAT.SmoothPlastic, 0, 90, 0),
		B(0.07, 0.45, 0.04, 0, 0.18, -0.2, black), B(0.35, 0.07, 0.04, 0.15, 0, -0.2, black), C(0.22, 0.25, 0.25, 0, 0.8, 0, gold, MAT.Metal, 0, 0, 90), C(0.12, 0.42, 0.42, 0, 1.02, 0, gold, MAT.Metal, 0, 90, 0)},
	AntiqueVase = {S(1.25, 1.3, 1.25, 0, -0.2, 0, rgb(205, 110, 60)), C(0.6, 0.5, 0.5, 0, 0.6, 0, rgb(205, 110, 60), MAT.SmoothPlastic, 0, 0, 90), C(0.15, 0.78, 0.78, 0, 0.92, 0, rgb(205, 110, 60), MAT.SmoothPlastic, 0, 0, 90),
		C(0.22, 0.75, 0.75, 0, -0.85, 0, rgb(170, 85, 45), MAT.SmoothPlastic, 0, 0, 90), C(0.18, 1.24, 1.24, 0, -0.1, 0, black, MAT.SmoothPlastic, 0, 0, 90), C(0.08, 1.2, 1.2, 0, -0.42, 0, black, MAT.SmoothPlastic, 0, 0, 90)},
	-- 2 FARM BARN
	Carrot = {C(0.45, 0.62, 0.62, 0, 0.3, 0, rgb(255, 140, 30), MAT.SmoothPlastic, 0, 0, 90), C(0.45, 0.47, 0.47, 0, -0.12, 0, rgb(255, 140, 30), MAT.SmoothPlastic, 0, 0, 90),
		C(0.4, 0.32, 0.32, 0, -0.52, 0, rgb(255, 140, 30), MAT.SmoothPlastic, 0, 0, 90), C(0.3, 0.16, 0.16, 0, -0.85, 0, rgb(255, 140, 30), MAT.SmoothPlastic, 0, 0, 90),
		B(0.13, 0.7, 0.13, -0.14, 0.92, 0, rgb(70, 190, 70), MAT.SmoothPlastic, 0, 0, 20), B(0.13, 0.8, 0.13, 0, 0.98, 0, rgb(70, 190, 70)), B(0.13, 0.7, 0.13, 0.14, 0.92, 0, rgb(70, 190, 70), MAT.SmoothPlastic, 0, 0, -20)},
	Corn = {S(0.72, 1.8, 0.72, 0, 0.05, 0, rgb(255, 215, 60)), B(0.3, 1.3, 0.12, -0.36, -0.35, 0, rgb(90, 180, 70), MAT.SmoothPlastic, 0, 0, 15),
		B(0.3, 1.3, 0.12, 0.36, -0.35, 0, rgb(90, 180, 70), MAT.SmoothPlastic, 0, 0, -15), B(0.12, 1.3, 0.3, 0, -0.35, 0.36, rgb(90, 180, 70), MAT.SmoothPlastic, -15, 0, 0)},
	MilkJug = {B(1, 1.2, 0.8, 0, -0.3, 0, white), B(0.6, 0.45, 0.6, 0, 0.48, 0, white), C(0.22, 0.42, 0.42, 0, 0.8, 0, rgb(70, 140, 255), MAT.SmoothPlastic, 0, 0, 90),
		B(0.15, 0.8, 0.25, 0.6, 0, 0, white), B(1.02, 0.42, 0.62, 0, -0.3, 0, rgb(70, 140, 255))},
	GoldenEgg = {S(1.2, 1.6, 1.2, 0, 0, 0, gold, MAT.Metal), S(0.28, 0.32, 0.1, -0.25, 0.35, -0.55, white, MAT.Neon)},
	-- 3 TOY FACTORY
	Teddy = {S(1.1, 1.2, 0.9, 0, -0.35, 0, rgb(165, 105, 60)), S(0.92, 0.85, 0.8, 0, 0.55, 0, rgb(165, 105, 60)), S(0.36, 0.36, 0.2, -0.38, 0.95, 0, rgb(165, 105, 60)),
		S(0.36, 0.36, 0.2, 0.38, 0.95, 0, rgb(165, 105, 60)), S(0.42, 0.3, 0.3, 0, 0.45, -0.38, rgb(230, 190, 140)), S(0.16, 0.12, 0.1, 0, 0.52, -0.53, black),
		S(0.1, 0.1, 0.06, -0.17, 0.68, -0.38, black), S(0.1, 0.1, 0.06, 0.17, 0.68, -0.38, black), S(0.36, 0.6, 0.36, -0.6, -0.2, -0.1, rgb(165, 105, 60)),
		S(0.36, 0.6, 0.36, 0.6, -0.2, -0.1, rgb(165, 105, 60)), S(0.4, 0.36, 0.5, -0.3, -0.9, -0.2, rgb(165, 105, 60)), S(0.4, 0.36, 0.5, 0.3, -0.9, -0.2, rgb(165, 105, 60)),
		S(0.6, 0.6, 0.2, 0, -0.35, -0.4, rgb(230, 190, 140)), B(0.5, 0.12, 0.12, 0, 0.12, -0.4, rgb(230, 60, 80))},
	Puzzle = {B(1.4, 1.4, 0.3, 0, 0, 0, rgb(80, 140, 255)), C(0.3, 0.46, 0.46, 0, 0.85, 0, rgb(80, 140, 255), MAT.SmoothPlastic, 0, 90, 0),
		C(0.3, 0.46, 0.46, 0.85, 0, 0, rgb(80, 140, 255), MAT.SmoothPlastic, 0, 90, 0), C(0.32, 0.46, 0.46, -0.52, 0, 0, rgb(40, 80, 170), MAT.SmoothPlastic, 0, 90, 0)},
	Controller = {B(1.8, 0.8, 0.42, 0, 0, 0, rgb(50, 50, 62)), S(0.72, 0.95, 0.46, -0.75, -0.25, 0, rgb(50, 50, 62)), S(0.72, 0.95, 0.46, 0.75, -0.25, 0, rgb(50, 50, 62)),
		B(0.36, 0.11, 0.06, -0.55, 0.08, -0.23, rgb(20, 20, 25)), B(0.11, 0.36, 0.06, -0.55, 0.08, -0.23, rgb(20, 20, 25)),
		S(0.15, 0.15, 0.08, 0.5, 0.2, -0.23, rgb(240, 60, 60)), S(0.15, 0.15, 0.08, 0.67, 0.04, -0.23, rgb(70, 220, 90)),
		S(0.15, 0.15, 0.08, 0.33, 0.04, -0.23, rgb(70, 140, 255)), S(0.15, 0.15, 0.08, 0.5, -0.12, -0.23, rgb(255, 210, 50))},
	ToyRobot = {B(1, 1, 0.7, 0, -0.2, 0, metal, MAT.Metal), B(0.75, 0.6, 0.6, 0, 0.6, 0, metal, MAT.Metal), S(0.16, 0.16, 0.06, -0.17, 0.65, -0.31, rgb(60, 230, 255), MAT.Neon),
		S(0.16, 0.16, 0.06, 0.17, 0.65, -0.31, rgb(60, 230, 255), MAT.Neon), B(0.06, 0.35, 0.06, 0, 1.05, 0, black), S(0.18, 0.18, 0.18, 0, 1.25, 0, rgb(255, 60, 60), MAT.Neon),
		B(0.25, 0.8, 0.25, -0.65, -0.2, 0, rgb(120, 125, 140), MAT.Metal), B(0.25, 0.8, 0.25, 0.65, -0.2, 0, rgb(120, 125, 140), MAT.Metal),
		B(0.3, 0.5, 0.35, -0.25, -0.95, 0, rgb(120, 125, 140), MAT.Metal), B(0.3, 0.5, 0.35, 0.25, -0.95, 0, rgb(120, 125, 140), MAT.Metal), B(0.5, 0.35, 0.05, 0, -0.1, -0.36, rgb(230, 60, 60))},
	-- 4 CANDY SHOP
	Lollipop = {C(0.25, 1.25, 1.25, 0, 0.42, 0, rgb(255, 90, 170), MAT.SmoothPlastic, 0, 90, 0), C(0.27, 0.8, 0.8, 0, 0.42, 0, white, MAT.SmoothPlastic, 0, 90, 0),
		C(0.29, 0.4, 0.4, 0, 0.42, 0, rgb(255, 90, 170), MAT.SmoothPlastic, 0, 90, 0), B(0.12, 1.2, 0.12, 0, -0.6, 0, white)},
	Donut = {C(0.5, 1.6, 1.6, 0, 0, 0, rgb(220, 160, 90), MAT.SmoothPlastic, 0, 90, 0), C(0.1, 1.42, 1.42, 0, 0, -0.25, rgb(255, 120, 190), MAT.SmoothPlastic, 0, 90, 0),
		C(0.62, 0.5, 0.5, 0, 0, 0, rgb(130, 85, 50), MAT.SmoothPlastic, 0, 90, 0), B(0.22, 0.06, 0.04, -0.45, 0.25, -0.31, rgb(255, 230, 60)),
		B(0.22, 0.06, 0.04, 0.35, 0.4, -0.31, rgb(90, 200, 255), MAT.SmoothPlastic, 0, 0, 40), B(0.22, 0.06, 0.04, 0.45, -0.3, -0.31, rgb(120, 230, 110), MAT.SmoothPlastic, 0, 0, -30),
		B(0.22, 0.06, 0.04, -0.3, -0.45, -0.31, white, MAT.SmoothPlastic, 0, 0, 70)},
	Cake = {C(0.7, 1.6, 1.6, 0, -0.5, 0, rgb(255, 232, 205), MAT.SmoothPlastic, 0, 0, 90), C(0.15, 1.66, 1.66, 0, -0.1, 0, rgb(255, 130, 190), MAT.SmoothPlastic, 0, 0, 90),
		C(0.5, 1.05, 1.05, 0, 0.2, 0, rgb(255, 232, 205), MAT.SmoothPlastic, 0, 0, 90), C(0.12, 1.1, 1.1, 0, 0.48, 0, rgb(255, 130, 190), MAT.SmoothPlastic, 0, 0, 90),
		S(0.32, 0.32, 0.32, 0, 0.7, 0, rgb(230, 30, 50)), B(0.08, 0.35, 0.08, -0.3, 0.7, 0, rgb(120, 200, 255)), B(0.08, 0.35, 0.08, 0.3, 0.7, 0, rgb(255, 220, 80)),
		S(0.1, 0.16, 0.1, -0.3, 0.95, 0, rgb(255, 200, 60), MAT.Neon), S(0.1, 0.16, 0.1, 0.3, 0.95, 0, rgb(255, 200, 60), MAT.Neon)},
	CandyCrown = {C(0.6, 1.4, 1.4, 0, -0.35, 0, gold, MAT.Metal, 0, 0, 90), C(0.62, 1.15, 1.15, 0, -0.32, 0, rgb(170, 30, 60), MAT.Fabric, 0, 0, 90),
		B(0.3, 0.6, 0.12, 0, 0.2, -0.62, gold, MAT.Metal), B(0.3, 0.6, 0.12, -0.59, 0.2, -0.19, gold, MAT.Metal, 0, 72, 0), B(0.3, 0.6, 0.12, 0.59, 0.2, -0.19, gold, MAT.Metal, 0, -72, 0),
		B(0.3, 0.6, 0.12, -0.36, 0.2, 0.5, gold, MAT.Metal, 0, 144, 0), B(0.3, 0.6, 0.12, 0.36, 0.2, 0.5, gold, MAT.Metal, 0, -144, 0),
		S(0.24, 0.24, 0.24, 0, 0.55, -0.62, rgb(255, 80, 170)), S(0.24, 0.24, 0.24, -0.59, 0.55, -0.19, rgb(90, 200, 255)), S(0.24, 0.24, 0.24, 0.59, 0.55, -0.19, rgb(120, 230, 110)),
		S(0.2, 0.2, 0.12, 0, -0.35, -0.72, rgb(255, 80, 170))},
	-- 5 PIRATE COVE
	Shell = {S(1.5, 1.2, 0.5, 0, 0.05, 0, rgb(255, 190, 160)), B(0.08, 1.05, 0.52, -0.45, 0.05, 0, rgb(230, 140, 120), MAT.SmoothPlastic, 0, 0, 35),
		B(0.08, 1.15, 0.54, -0.2, 0.08, 0, rgb(230, 140, 120), MAT.SmoothPlastic, 0, 0, 15), B(0.08, 1.15, 0.54, 0.2, 0.08, 0, rgb(230, 140, 120), MAT.SmoothPlastic, 0, 0, -15),
		B(0.08, 1.05, 0.52, 0.45, 0.05, 0, rgb(230, 140, 120), MAT.SmoothPlastic, 0, 0, -35), B(0.5, 0.28, 0.4, 0, -0.6, 0, rgb(240, 160, 130))},
	Compass = {C(0.3, 1.4, 1.4, 0, 0, 0, gold, MAT.Metal, 0, 90, 0), C(0.32, 1.18, 1.18, 0, 0, 0, rgb(245, 235, 210), MAT.SmoothPlastic, 0, 90, 0),
		B(0.13, 0.55, 0.04, 0, 0.25, -0.18, rgb(230, 40, 40)), B(0.13, 0.55, 0.04, 0, -0.25, -0.18, white), S(0.14, 0.14, 0.06, 0, 0, -0.2, black),
		C(0.12, 0.38, 0.38, 0, 0.86, 0, gold, MAT.Metal, 0, 90, 0)},
	Spyglass = {C(1, 0.46, 0.46, -0.3, 0, 0, rgb(200, 150, 60), MAT.Metal, 0, 0, 20), C(0.8, 0.38, 0.38, 0.55, 0.31, 0, rgb(220, 180, 70), MAT.Metal, 0, 0, 20),
		C(0.14, 0.52, 0.52, -0.75, -0.16, 0, rgb(110, 70, 40), MAT.Wood, 0, 0, 20), C(0.12, 0.5, 0.5, 0.1, 0.04, 0, rgb(110, 70, 40), MAT.Wood, 0, 0, 20),
		C(0.04, 0.34, 0.34, 0.96, 0.46, 0, rgb(170, 220, 255), MAT.Glass, 0, 0, 20)},
	TreasureMap = {B(1.5, 1.2, 0.05, 0, 0, 0, rgb(235, 215, 160)), C(1.65, 0.26, 0.26, 0, 0.62, 0, rgb(215, 190, 130)), C(1.65, 0.26, 0.26, 0, -0.62, 0, rgb(215, 190, 130)),
		B(0.4, 0.09, 0.06, 0.32, -0.15, -0.04, rgb(220, 40, 40), MAT.SmoothPlastic, 0, 0, 45), B(0.4, 0.09, 0.06, 0.32, -0.15, -0.04, rgb(220, 40, 40), MAT.SmoothPlastic, 0, 0, -45),
		B(0.14, 0.06, 0.05, -0.45, 0.25, -0.04, rgb(120, 80, 40)), B(0.14, 0.06, 0.05, -0.2, 0.15, -0.04, rgb(120, 80, 40)), B(0.14, 0.06, 0.05, 0.05, 0.02, -0.04, rgb(120, 80, 40)),
		S(0.35, 0.25, 0.04, -0.4, -0.2, -0.04, rgb(110, 180, 110))},
	-- 6 DINO MUSEUM
	Bone = {C(1.5, 0.32, 0.32, 0, 0, 0, bone, MAT.SmoothPlastic, 0, 0, 30), S(0.42, 0.42, 0.42, -0.72, -0.27, 0.13, bone), S(0.42, 0.42, 0.42, -0.55, -0.55, -0.13, bone),
		S(0.42, 0.42, 0.42, 0.55, 0.55, 0.13, bone), S(0.42, 0.42, 0.42, 0.72, 0.27, -0.13, bone)},
	Footprint = {C(0.4, 1.7, 1.7, 0, 0, 0, rgb(150, 140, 125), MAT.Slate, 0, 90, 0), S(0.55, 0.65, 0.12, 0, -0.2, -0.2, rgb(90, 82, 72)),
		S(0.2, 0.38, 0.1, -0.3, 0.35, -0.2, rgb(90, 82, 72), MAT.SmoothPlastic, 0, 0, 20), S(0.2, 0.4, 0.1, 0, 0.45, -0.2, rgb(90, 82, 72)),
		S(0.2, 0.38, 0.1, 0.3, 0.35, -0.2, rgb(90, 82, 72), MAT.SmoothPlastic, 0, 0, -20)},
	DinoPlush = {S(1, 0.9, 1.3, 0, -0.35, 0.1, rgb(110, 200, 90)), S(0.45, 0.9, 0.45, 0, 0.25, -0.42, rgb(110, 200, 90)), S(0.55, 0.5, 0.7, 0, 0.75, -0.55, rgb(110, 200, 90)),
		S(0.1, 0.1, 0.06, -0.15, 0.85, -0.85, black), S(0.1, 0.1, 0.06, 0.15, 0.85, -0.85, black), S(0.3, 0.3, 0.9, 0, -0.45, 0.9, rgb(110, 200, 90)),
		S(0.3, 0.45, 0.3, -0.3, -0.8, -0.3, rgb(90, 175, 70)), S(0.3, 0.45, 0.3, 0.3, -0.8, -0.3, rgb(90, 175, 70)), S(0.3, 0.45, 0.3, -0.3, -0.8, 0.45, rgb(90, 175, 70)),
		S(0.3, 0.45, 0.3, 0.3, -0.8, 0.45, rgb(90, 175, 70)), B(0.12, 0.25, 0.25, 0, 0.12, 0.1, rgb(255, 160, 50), MAT.SmoothPlastic, 45, 0, 0),
		B(0.12, 0.25, 0.25, 0, 0.05, 0.45, rgb(255, 160, 50), MAT.SmoothPlastic, 45, 0, 0)},
	TRexSkull = {S(1, 0.95, 1.3, 0, 0.25, 0.2, bone), B(0.75, 0.55, 0.9, 0, 0.05, -0.55, bone), B(0.72, 0.28, 1.1, 0, -0.38, -0.3, rgb(225, 218, 195)),
		S(0.3, 0.32, 0.1, -0.3, 0.4, -0.3, rgb(50, 40, 35)), S(0.3, 0.32, 0.1, 0.3, 0.4, -0.3, rgb(50, 40, 35)), S(0.12, 0.08, 0.05, -0.15, 0.25, -1.0, rgb(50, 40, 35)),
		S(0.12, 0.08, 0.05, 0.15, 0.25, -1.0, rgb(50, 40, 35)), B(0.08, 0.2, 0.08, -0.25, -0.18, -0.95, white), B(0.08, 0.2, 0.08, 0, -0.18, -1.0, white),
		B(0.08, 0.2, 0.08, 0.25, -0.18, -0.95, white), B(0.08, 0.2, 0.08, -0.33, -0.18, -0.6, white), B(0.08, 0.2, 0.08, 0.33, -0.18, -0.6, white)},
	-- 7 FROZEN LAB
	Snowflake = {B(0.16, 2, 0.12, 0, 0, 0, rgb(200, 240, 255), MAT.Ice), B(0.16, 2, 0.12, 0, 0, 0, rgb(200, 240, 255), MAT.Ice, 0, 0, 60), B(0.16, 2, 0.12, 0, 0, 0, rgb(200, 240, 255), MAT.Ice, 0, 0, -60),
		S(0.4, 0.4, 0.2, 0, 0, 0, rgb(150, 220, 255), MAT.Neon), B(0.1, 0.45, 0.1, 0.15, 0.7, 0, rgb(200, 240, 255), MAT.Ice, 0, 0, -40), B(0.1, 0.45, 0.1, -0.15, 0.7, 0, rgb(200, 240, 255), MAT.Ice, 0, 0, 40),
		B(0.1, 0.45, 0.1, 0.15, -0.7, 0, rgb(200, 240, 255), MAT.Ice, 0, 0, 40), B(0.1, 0.45, 0.1, -0.15, -0.7, 0, rgb(200, 240, 255), MAT.Ice, 0, 0, -40)},
	FrozenFish = {S(1.1, 0.55, 0.32, -0.1, 0, 0, rgb(255, 150, 60)), B(0.35, 0.5, 0.1, 0.55, 0, 0, rgb(255, 120, 40), MAT.SmoothPlastic, 0, 0, 45), S(0.1, 0.1, 0.05, -0.45, 0.08, -0.15, black),
		B(1.7, 1.15, 0.8, 0, 0, 0, rgb(170, 225, 255), MAT.Glass, 0, 0, 0, 0.45)},
	Snowman = {S(1.1, 1.1, 1.1, 0, -0.55, 0, white, MAT.Snow), S(0.85, 0.85, 0.85, 0, 0.25, 0, white, MAT.Snow), S(0.62, 0.62, 0.62, 0, 0.88, 0, white, MAT.Snow),
		C(0.4, 0.42, 0.42, 0, 1.3, 0, black, MAT.SmoothPlastic, 0, 0, 90), C(0.06, 0.66, 0.66, 0, 1.12, 0, black, MAT.SmoothPlastic, 0, 0, 90),
		B(0.08, 0.08, 0.32, 0, 0.86, -0.42, rgb(255, 140, 30)), S(0.08, 0.08, 0.05, -0.12, 0.98, -0.28, black), S(0.08, 0.08, 0.05, 0.12, 0.98, -0.28, black),
		C(0.16, 0.76, 0.76, 0, 0.6, 0, rgb(230, 40, 50), MAT.Fabric, 0, 0, 90), S(0.1, 0.1, 0.06, 0, 0.28, -0.42, black), S(0.1, 0.1, 0.06, 0, 0.05, -0.4, black)},
	IceGem = {B(1, 1, 1, 0, 0, 0, rgb(120, 220, 255), MAT.Glass, 45, 0, 45, 0.15), B(0.55, 0.55, 0.55, 0, 0, 0, rgb(200, 245, 255), MAT.Neon, 45, 0, 45)},
	-- 8 TECH LAB
	Battery = {C(1.5, 0.8, 0.8, 0, -0.1, 0, rgb(35, 35, 40), MAT.SmoothPlastic, 0, 0, 90), C(0.6, 0.82, 0.82, 0, 0.35, 0, rgb(90, 230, 90), MAT.SmoothPlastic, 0, 0, 90),
		C(0.15, 0.32, 0.32, 0, 0.72, 0, metal, MAT.Metal, 0, 0, 90), B(0.26, 0.07, 0.03, 0, 0.35, -0.42, white, MAT.Neon), B(0.07, 0.26, 0.03, 0, 0.35, -0.42, white, MAT.Neon)},
	Chip = {B(1.5, 1.5, 0.12, 0, 0, 0, rgb(40, 140, 70)), B(0.8, 0.8, 0.16, 0, 0, -0.1, rgb(25, 25, 30)), B(0.06, 0.2, 0.06, -0.25, 0.48, -0.08, gold, MAT.Metal),
		B(0.06, 0.2, 0.06, 0, 0.48, -0.08, gold, MAT.Metal), B(0.06, 0.2, 0.06, 0.25, 0.48, -0.08, gold, MAT.Metal), B(0.06, 0.2, 0.06, -0.25, -0.48, -0.08, gold, MAT.Metal),
		B(0.06, 0.2, 0.06, 0, -0.48, -0.08, gold, MAT.Metal), B(0.06, 0.2, 0.06, 0.25, -0.48, -0.08, gold, MAT.Metal), B(0.2, 0.06, 0.06, -0.48, 0.2, -0.08, gold, MAT.Metal),
		B(0.2, 0.06, 0.06, -0.48, -0.2, -0.08, gold, MAT.Metal), B(0.2, 0.06, 0.06, 0.48, 0.2, -0.08, gold, MAT.Metal), B(0.2, 0.06, 0.06, 0.48, -0.2, -0.08, gold, MAT.Metal),
		B(0.6, 0.04, 0.02, -0.4, 0.62, -0.07, rgb(255, 215, 80), MAT.Neon), B(0.04, 0.5, 0.02, 0.6, -0.4, -0.07, rgb(255, 215, 80), MAT.Neon)},
	Laptop = {B(1.7, 0.1, 1.15, 0, -0.55, -0.2, metal, MAT.Metal), B(1.35, 0.03, 0.55, 0, -0.49, -0.3, rgb(40, 40, 48)), B(1.7, 1.1, 0.08, 0, 0.0, 0.4, metal, MAT.Metal, -12, 0, 0),
		B(1.5, 0.92, 0.02, 0, 0.0, 0.35, rgb(80, 170, 255), MAT.Neon, -12, 0, 0)},
	Satellite = {B(0.6, 0.6, 0.8, 0, 0, 0, rgb(225, 180, 60), MAT.Foil), B(0.9, 0.55, 0.04, -0.8, 0, 0, rgb(40, 80, 210), MAT.SmoothPlastic), B(0.9, 0.55, 0.04, 0.8, 0, 0, rgb(40, 80, 210), MAT.SmoothPlastic),
		B(0.4, 0.06, 0.06, -0.38, 0, 0, metal, MAT.Metal), B(0.4, 0.06, 0.06, 0.38, 0, 0, metal, MAT.Metal), C(0.1, 0.75, 0.75, 0, 0.45, 0, white, MAT.SmoothPlastic, 0, 0, 90),
		B(0.05, 0.5, 0.05, 0, 0.75, 0, metal, MAT.Metal), S(0.12, 0.12, 0.12, 0, 1.0, 0, rgb(255, 60, 60), MAT.Neon)},
	-- 9 ALIEN HANGAR
	Comet = {S(0.85, 0.85, 0.85, -0.35, -0.35, 0, rgb(130, 120, 145), MAT.Slate), S(0.5, 0.5, 1.8, 0.25, 0.25, 0, rgb(90, 220, 255), MAT.Neon, 0, 45, 0, 0.35),
		S(0.3, 0.3, 1.4, 0.3, 0.3, 0, white, MAT.Neon, 0, 45, 0, 0.2)},
	CrystalBall = {S(1.3, 1.3, 1.3, 0, 0.25, 0, rgb(190, 140, 255), MAT.Glass, 0, 0, 0, 0.25), S(0.55, 0.55, 0.55, 0, 0.25, 0, rgb(255, 120, 230), MAT.Neon),
		C(0.35, 1.05, 1.05, 0, -0.6, 0, rgb(120, 85, 40), MAT.Wood, 0, 0, 90), C(0.12, 1.25, 1.25, 0, -0.8, 0, gold, MAT.Metal, 0, 0, 90)},
	UFOModel = {C(0.3, 1.9, 1.9, 0, -0.1, 0, metal, MAT.Metal, 0, 0, 90), S(0.95, 0.65, 0.95, 0, 0.2, 0, rgb(120, 230, 255), MAT.Glass, 0, 0, 0, 0.2),
		C(0.12, 1.0, 1.0, 0, -0.3, 0, rgb(120, 255, 120), MAT.Neon, 0, 0, 90), S(0.14, 0.14, 0.14, -0.85, -0.1, 0, rgb(255, 230, 80), MAT.Neon),
		S(0.14, 0.14, 0.14, 0.85, -0.1, 0, rgb(255, 230, 80), MAT.Neon), S(0.14, 0.14, 0.14, 0, -0.1, -0.85, rgb(255, 230, 80), MAT.Neon),
		S(0.14, 0.14, 0.14, -0.6, -0.1, -0.6, rgb(255, 230, 80), MAT.Neon), S(0.14, 0.14, 0.14, 0.6, -0.1, -0.6, rgb(255, 230, 80), MAT.Neon)},
	AlienPlush = {S(1, 0.92, 0.85, 0, 0.35, 0, rgb(120, 230, 110)), S(0.36, 0.22, 0.1, -0.22, 0.4, -0.38, rgb(15, 15, 20), MAT.Glass, 0, 0, -20),
		S(0.36, 0.22, 0.1, 0.22, 0.4, -0.38, rgb(15, 15, 20), MAT.Glass, 0, 0, 20), S(0.7, 0.8, 0.6, 0, -0.45, 0, rgb(120, 230, 110)),
		B(0.05, 0.38, 0.05, -0.22, 0.95, 0, rgb(90, 200, 90), MAT.SmoothPlastic, 0, 0, 20), B(0.05, 0.38, 0.05, 0.22, 0.95, 0, rgb(90, 200, 90), MAT.SmoothPlastic, 0, 0, -20),
		S(0.15, 0.15, 0.15, -0.29, 1.15, 0, rgb(255, 120, 230), MAT.Neon), S(0.15, 0.15, 0.15, 0.29, 1.15, 0, rgb(255, 120, 230), MAT.Neon),
		S(0.25, 0.5, 0.25, -0.45, -0.4, 0, rgb(110, 215, 100)), S(0.25, 0.5, 0.25, 0.45, -0.4, 0, rgb(110, 215, 100))},
	-- 10 GALAXY VAULT
	Moon = {S(1.45, 1.45, 1.45, 0, 0, 0, rgb(185, 185, 195), MAT.Slate), S(0.38, 0.38, 0.16, -0.3, 0.3, -0.62, rgb(140, 140, 150)),
		S(0.26, 0.26, 0.12, 0.35, -0.2, -0.64, rgb(140, 140, 150)), S(0.2, 0.2, 0.1, 0.1, 0.45, -0.62, rgb(140, 140, 150)), S(0.3, 0.3, 0.12, -0.15, -0.4, -0.62, rgb(140, 140, 150))},
	Shooting = {S(0.65, 0.65, 0.4, 0, 0, 0, rgb(255, 220, 60), MAT.Neon), B(0.36, 0.75, 0.3, 0, 0.5, 0, rgb(255, 220, 60), MAT.Neon),
		B(0.36, 0.75, 0.3, 0.48, 0.15, 0, rgb(255, 220, 60), MAT.Neon, 0, 0, -72), B(0.36, 0.75, 0.3, 0.29, -0.4, 0, rgb(255, 220, 60), MAT.Neon, 0, 0, -144),
		B(0.36, 0.75, 0.3, -0.29, -0.4, 0, rgb(255, 220, 60), MAT.Neon, 0, 0, 144), B(0.36, 0.75, 0.3, -0.48, 0.15, 0, rgb(255, 220, 60), MAT.Neon, 0, 0, 72),
		S(0.35, 0.35, 1.7, 0.55, -0.55, 0.3, rgb(255, 120, 220), MAT.Neon, 0, -40, 0, 0.35)},
	GalaxyOrb = {S(1.4, 1.4, 1.4, 0, 0, 0, rgb(140, 60, 255), MAT.Neon, 0, 0, 0, 0.1), S(0.6, 0.6, 0.6, 0, 0, 0, white, MAT.Neon),
		C(0.06, 2.1, 2.1, 0, 0, 0, rgb(90, 220, 255), MAT.Neon, 0, 0, 70, 0.45)},
	BlackHoleCore = {S(1.05, 1.05, 1.05, 0, 0, 0, rgb(8, 6, 12)), C(0.06, 2.3, 2.3, 0, 0, 0, rgb(255, 140, 30), MAT.Neon, 20, 0, 80, 0.3),
		C(0.07, 1.5, 1.5, 0, 0, 0, rgb(255, 230, 120), MAT.Neon, 20, 0, 80, 0.1), S(1.35, 1.35, 1.35, 0, 0, 0, rgb(170, 60, 255), MAT.Neon, 0, 0, 0, 0.75)},
}

-- 3D models for the upgrades at the Upgrade Shop booth
Config.ItemModels.UP_Speed = {B(0.95, 0.22, 2, 0, -0.62, 0.05, white), S(0.9, 0.8, 1.55, 0, -0.2, 0.2, rgb(60, 170, 255)), S(0.85, 0.55, 0.85, 0, -0.35, -0.6, rgb(60, 170, 255)),
	B(0.8, 0.4, 0.65, 0, 0.18, 0.45, rgb(30, 110, 210)), B(0.5, 0.07, 0.09, 0, 0.12, -0.05, white), B(0.5, 0.07, 0.09, 0, 0.0, -0.3, white),
	B(0.06, 0.18, 0.9, 0.46, -0.3, 0.15, white, MAT.SmoothPlastic, 15, 0, 0), B(0.06, 0.18, 0.9, -0.46, -0.3, 0.15, white, MAT.SmoothPlastic, 15, 0, 0),
	B(0.3, 0.4, 0.12, 0, 0.32, 0.8, rgb(255, 90, 90))}
Config.ItemModels.UP_Hands = {B(1.05, 1.1, 0.42, 0, -0.1, 0, rgb(235, 60, 60)), B(0.22, 0.65, 0.36, -0.38, 0.72, 0, rgb(235, 60, 60)), B(0.22, 0.72, 0.36, -0.13, 0.76, 0, rgb(235, 60, 60)),
	B(0.22, 0.72, 0.36, 0.13, 0.76, 0, rgb(235, 60, 60)), B(0.22, 0.6, 0.36, 0.38, 0.68, 0, rgb(235, 60, 60)), B(0.26, 0.55, 0.36, -0.62, -0.05, 0, rgb(235, 60, 60), MAT.SmoothPlastic, 0, 0, 35),
	B(1.15, 0.38, 0.5, 0, -0.82, 0, white), B(0.18, 0.5, 0.05, 0.05, 0, -0.23, rgb(255, 230, 70), MAT.Neon, 0, 0, -25), B(0.18, 0.4, 0.05, -0.08, -0.32, -0.23, rgb(255, 230, 70), MAT.Neon, 0, 0, 25)}
Config.ItemModels.UP_Stands = {B(0.12, 1.9, 0.7, -0.85, 0, 0, rgb(200, 150, 95), MAT.WoodPlanks), B(0.12, 1.9, 0.7, 0.85, 0, 0, rgb(200, 150, 95), MAT.WoodPlanks),
	B(1.7, 0.12, 0.7, 0, -0.9, 0, rgb(220, 170, 110), MAT.WoodPlanks), B(1.7, 0.12, 0.7, 0, 0, 0, rgb(220, 170, 110), MAT.WoodPlanks), B(1.7, 0.12, 0.7, 0, 0.9, 0, rgb(220, 170, 110), MAT.WoodPlanks),
	B(1.7, 1.9, 0.08, 0, 0, 0.32, rgb(255, 200, 90)), B(0.42, 0.42, 0.42, -0.45, -0.62, 0, rgb(255, 90, 90)), B(0.42, 0.5, 0.42, 0.1, -0.58, 0, rgb(90, 200, 255)),
	B(0.42, 0.42, 0.42, -0.2, 0.27, 0, rgb(120, 230, 110)), B(0.42, 0.36, 0.42, 0.45, 0.24, 0, rgb(255, 220, 70)),
	B(0.55, 0.16, 0.1, 0.62, 1.25, -0.2, rgb(90, 255, 90), MAT.Neon), B(0.16, 0.55, 0.1, 0.62, 1.25, -0.2, rgb(90, 255, 90), MAT.Neon)}
Config.ItemModels.UP_Unbox = {B(0.45, 1.5, 0.28, 0, -0.35, 0, rgb(255, 140, 30)), B(0.47, 0.12, 0.3, 0, -0.75, 0, rgb(40, 40, 45)), B(0.47, 0.12, 0.3, 0, -0.5, 0, rgb(40, 40, 45)),
	B(0.47, 0.12, 0.3, 0, -0.25, 0, rgb(40, 40, 45)), B(0.16, 0.3, 0.34, 0, 0.1, 0, rgb(40, 40, 45)), B(0.3, 0.72, 0.06, 0, 0.75, 0, rgb(225, 230, 240), MAT.Metal),
	B(0.3, 0.3, 0.06, 0.07, 1.12, 0, rgb(225, 230, 240), MAT.Metal, 0, 0, 45), B(0.05, 0.7, 0.07, -0.1, 0.75, 0, white, MAT.Neon)}

-- mutations tint the model: Gold, Diamond, Lava, Rainbow, Galaxy
local MUT_MATERIAL = {Gold = MAT.Metal, Diamond = MAT.Glass, Lava = MAT.Neon, Galaxy = MAT.Neon}

-- Build an item as a model. Returns the model and a list of {part, offset, rot, size} at scale 1,
-- so animations can move / resize every part around one centre.
-- rarer items get extra detail on top of their model: sparkles (Uncommon), a gold stand + gems (Rare),
-- and a gold stand, a halo and glowing gems all around (Legendary)
local function rarityExtras(spec, tier)
	local out = table.clone(spec)
	local gold, tcol = rgb(255, 200, 50), (Config.ItemTiers[tier] or Config.ItemTiers[1]).color
	if tier >= 2 then
		table.insert(out, S(0.25, 0.25, 0.25, 1.15, 0.8, 0, tcol, MAT.Neon))
		table.insert(out, S(0.2, 0.2, 0.2, -1.1, 0.4, 0.3, tcol, MAT.Neon))
	end
	if tier >= 3 then
		table.insert(out, C(0.25, 2.6, 2.6, 0, -1.2, 0, gold, MAT.Metal, 0, 0, 90))
		table.insert(out, C(0.15, 2.9, 2.9, 0, -1.38, 0, tcol, MAT.Neon, 0, 0, 90))
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			table.insert(out, B(0.3, 0.3, 0.3, math.cos(a) * 1.25, -1.05, math.sin(a) * 1.25, tcol, MAT.Neon, 45, 45, 0))
		end
	end
	if tier >= 4 then
		for k = 0, 7 do -- a golden halo
			local a = k / 8 * math.pi * 2
			table.insert(out, S(0.28, 0.28, 0.28, math.cos(a) * 0.85, 1.55, math.sin(a) * 0.85, gold, MAT.Neon))
		end
		table.insert(out, C(0.3, 3.2, 3.2, 0, -1.5, 0, gold, MAT.Metal, 0, 0, 90))
		for k = 0, 3 do -- big gems all around
			local a = k / 4 * math.pi * 2 + 0.4
			table.insert(out, B(0.4, 0.4, 0.4, math.cos(a) * 1.5, 0.3 + (k % 2) * 0.6, math.sin(a) * 1.5, tcol:Lerp(rgb(255, 255, 255), 0.2), MAT.Neon, 45, 45, 0))
		end
	end
	return out
end

function Config.BuildItemModel(item, scale, cframe)
	scale = scale or 1
	cframe = cframe or CFrame.new()
	local spec = Config.ItemModels[item.id] or {S(1.2, 1.2, 1.2, 0, 0, 0, rgb(200, 200, 200))}
	local idef = Config.Items[item.id]
	if idef and idef.tier >= 2 then spec = rarityExtras(spec, idef.tier) end
	local mut = Config.GetMutation(item.mutation)
	local m = Instance.new("Model")
	m.Name = "Item_" .. item.id
	local list = {}
	for i, p in ipairs(spec) do
		local shape, sx, sy, sz, x, y, z, color, mat, rx, ry, rz, transp = p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13]
		local part = Instance.new("Part")
		part.Name = "P" .. i
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Material = mat or MAT.SmoothPlastic
		part.Color = color or white
		part.Transparency = transp or 0
		if shape == "C" then part.Shape = Enum.PartType.Cylinder end
		if shape == "S" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		if mut.id ~= "Normal" and mut.color then
			part.Color = part.Color:Lerp(mut.color, (part.Material == MAT.Neon) and 0.35 or 0.6)
			if MUT_MATERIAL[mut.id] and part.Transparency < 0.3 then part.Material = MUT_MATERIAL[mut.id] end
			if mut.id == "Gold" then part.Reflectance = 0.2 end
			if mut.id == "Diamond" then part.Transparency = math.max(part.Transparency, 0.15) end
		end
		local size = Vector3.new(sx, sy, sz)
		local offset = Vector3.new(x, y, z)
		local rot = CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
		part.Size = size * scale
		part.CFrame = cframe * CFrame.new(offset * scale) * rot
		part.Parent = m
		list[i] = {part = part, offset = offset, rot = rot, size = size}
	end
	m.WorldPivot = cframe
	return m, list
end

-- move / resize a built item model (centre CFrame + scale)
function Config.PoseItemModel(list, cframe, scale)
	for _, e in ipairs(list) do
		e.part.Size = e.size * scale
		e.part.CFrame = cframe * CFrame.new(e.offset * scale) * e.rot
	end
end

-- how big products look on the shop shelf
function Config.ShelfItemScale(item)
	return 1.75 * math.min(1.15, math.sqrt(Config.GetSize(item.size).scale))
end

------------------------------------------------------------------
-- NEW FEATURES (side panels, quests, free gift, lobby plaza)
------------------------------------------------------------------
-- the courtyard got a plaza at the back (spawn, Trails Shop, FREE gift, leaderboards)
Config.Court.length = 360
Config.LobbySpawnZ = 330
-- every area is the same size (helpers used by the server / client)
-- harder area = longer area: 90 studs for area 1, +14 for every area after it (216 for area 10)
function Config.AreaLen(areaIndex) return Config.Layout.sectionLen + ((areaIndex or 1) - 1) * 14 end
function Config.AreaStartZ(areaIndex)
	local z = Config.Layout.frontZ
	for k = 1, (areaIndex or 1) - 1 do z = z - Config.AreaLen(k) end
	return z
end
function Config.ZoneAt(pos)
	if math.abs(pos.X) > Config.Layout.halfWidth + 1 or pos.Z > Config.Layout.frontZ then return nil end
	for i = 1, #Config.Areas do
		if pos.Z >= Config.AreaStartZ(i) - Config.AreaLen(i) then return i end
	end
	return nil
end
function Config.AreaHalfWidth(areaIndex) return Config.Layout.halfWidth end
function Config.AreaEndZ(areaIndex) return Config.AreaStartZ(areaIndex) - Config.AreaLen(areaIndex) end
function Config.StoreEndZ() return Config.AreaEndZ(#Config.Areas) end
function Config.StoreHalfWidth() return Config.Layout.halfWidth end
-- an empty shelf spot gets a new box this many seconds after it was emptied
function Config.RestockTime(areaIndex, rarity)
	return 8 + (areaIndex or 1) + (rarity or 1) * 4
end
-- shelf spots ("+1 Equip"): you start with 8 and buy more with cash
Config.BaseStands = 8
function Config.StandCost(unlocked) -- price of the NEXT slot when you have `unlocked` slots
	unlocked = math.max(Config.BaseStands, tonumber(unlocked) or Config.BaseStands)
	return math.floor(2500 * 1.45 ^ (unlocked - Config.BaseStands))
end
-- shoppers at the same time per shop (fewer = less lag)
Config.MaxCustomers = 4
-- the FREE gift in the lobby: claim once every `minutes`
Config.FreeGift = {minutes = 15, boxChance = 0.35}
function Config.FreeGiftCash(incomePerSec)
	return math.max(300, math.floor((incomePerSec or 0) * 120))
end
-- daily quests: 3 a day, the same for everybody
Config.Quests = {
	{id = "steal", text = "Steal %s boxes",                    goals = {3, 8, 15}},
	{id = "open",  text = "Open %s boxes",                     goals = {3, 6, 12}},
	{id = "sales", text = "Make %s sales in your shop",        goals = {20, 60, 150}},
	{id = "run",   text = "Run %s seconds on your treadmill",  goals = {30, 90, 180}},
	{id = "rare",  text = "Unbox %s Rare or better items",     goals = {1, 2, 4}},
	{id = "deep",  text = "Steal %s boxes from department 3+", goals = {2, 5, 10}},
}
function Config.GetQuest(id)
	for _, q in ipairs(Config.Quests) do if q.id == id then return q end end
	return nil
end
-- today's 3 quests: {{id = "steal", goal = 3}, ...} (3 different quests, picked from the day number)
function Config.QuestsForDay(day)
	day = math.floor(tonumber(day) or Config.DayNumber())
	local pool = {}
	for i = 1, #Config.Quests do pool[i] = i end
	local seed = (day * 7919 + 1013) % 2147483647
	local list = {}
	for slot = 1, 3 do
		seed = (seed * 48271) % 2147483647 -- a tiny random number generator (same result on every server)
		local q = Config.Quests[table.remove(pool, seed % #pool + 1)]
		list[slot] = {id = q.id, goal = q.goals[slot] or q.goals[#q.goals]}
	end
	return list
end
-- cash for finishing quest `slot` (harder slot = bigger reward, grows with your income)
function Config.QuestReward(slot, incomePerSec)
	local base, minutes = ({500, 2000, 6000})[slot] or 500, ({5, 10, 20})[slot] or 5
	return math.max(base, math.floor((incomePerSec or 0) * 60 * minutes))
end
function Config.QuestText(id, goal)
	local q = Config.GetQuest(id)
	if not q then return "Quest" end
	return string.format(q.text, Config.FormatNum(goal or q.goals[1]))
end
-- SECRET ACHIEVEMENTS: nobody sees this list in the game - they pop up when you unlock them.
-- reward = minutes of your income (at least `base` cash)
Config.Achievements = {
	{id = "FirstSteal",  name = "First Heist",        minutes = 2,  base = 300},    -- steal your first box
	{id = "Steal25",     name = "Professional Thief", minutes = 5,  base = 2000},   -- steal 25 boxes
	{id = "Steal100",    name = "Master Thief",       minutes = 15, base = 20000},  -- steal 100 boxes
	{id = "Steal500",    name = "Legendary Robber",   minutes = 40, base = 200000}, -- steal 500 boxes
	{id = "Bonk",        name = "BONK!",              minutes = 2,  base = 300},    -- get flung by a guard
	{id = "Bonk25",      name = "Bouncy Castle",      minutes = 8,  base = 5000},   -- get flung 25 times
	{id = "Deep5",       name = "Deep Diver",         minutes = 8,  base = 5000},   -- steal from area 5 or deeper
	{id = "Deep10",      name = "To The Galaxy",      minutes = 25, base = 100000}, -- steal from area 10
	{id = "Legendary",   name = "Legendary!",         minutes = 10, base = 10000},  -- unbox a Legendary item
	{id = "Galaxy",      name = "Out Of This World",  minutes = 15, base = 20000},  -- get a Galaxy item
	{id = "Million",     name = "Millionaire",        minutes = 5,  base = 0},      -- have $1M
	{id = "Billion",     name = "Billionaire",        minutes = 10, base = 0},      -- have $1B
	{id = "Speedy",      name = "Speed Demon",        minutes = 5,  base = 3000},   -- reach 10K speed
	{id = "FullShelf",   name = "Shopkeeper",         minutes = 8,  base = 5000},   -- 20 items on your shelf
}
function Config.GetAchievement(id)
	for _, a in ipairs(Config.Achievements) do if a.id == id then return a end end
	return nil
end
function Config.AchievementReward(a, incomePerSec)
	return math.max(a.base or 0, math.floor((incomePerSec or 0) * 60 * (a.minutes or 1)))
end

-- SURPRISE EVENTS: start at a random moment (no warning), for everybody in the server
Config.Events = {
	{id = "DoubleCash",   name = "DOUBLE CASH!",      text = "Every shop earns 2x cash!",           seconds = 90},
	{id = "SpeedRush",    name = "SPEED RUSH!",       text = "Treadmills give 3x speed!",           seconds = 90},
	{id = "SleepyGuards", name = "SLEEPY GUARDS!",    text = "The guards wake up slowly and run slower!", seconds = 60, warehouse = true},
	{id = "GoldRain",     name = "GOLDEN BOX RAIN!",  text = "Golden boxes appeared in the warehouse!", seconds = 60, warehouse = true},
	{id = "LuckyHour",    name = "LUCKY TIME!",       text = "2x mutation luck for everybody!",     seconds = 120},
}
Config.EventGap = {150, 360} -- seconds between events (random)

-- (saves are already in this format: nothing to convert)
Config.SaveVersion = 2
Config.OldBoxToNew, Config.OldItemToNew = {}, {}

return Config
