--[[ STEAL A BOX - shared config (used by server, client AND the map builder). Tweak freely! ]]
local Config = {}
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- The MEGA MART is one long supermarket: department 1 is at the front door, department 10 at the very back.
-- Every department is a bit deeper and wider than the one before (see Config.AreaLen / AreaHalfWidth).
Config.Layout = {
	frontZ = -4,        -- inside face of the store's front wall (the store goes towards -Z)
	floorY = 0.75,
	wallHeight = 44,
	scale = 1.5,        -- boxes are built 1.5x bigger
	sectionLen = 64,    -- depth of department 1 (old callers; use Config.AreaLen(i))
	halfWidth = 40,     -- half width of department 1 (old callers; use Config.AreaHalfWidth(i))
	growLen = 10,       -- every next department is 10 studs deeper ...
	growWidth = 4,      -- ... and 4 studs wider on each side
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

-- the lobby in front of the store: the street, the 6 shops and (at the far end) the plaza
Config.Court = {
	halfWidth = 112,    -- x -112..112
	length = 360,       -- z 0..360 (z 300..360 is the plaza: spawn, Trails Shop, FREE gift, leaderboards)
	plotWidth = 92,     -- along the street
	plotDepth = 92,     -- away from the street
}
Config.LobbySpawnZ = 330 -- where you spawn (on the plaza, facing the store)

-- rarity rules for the 3 boxes in each department: [1]=common [2]=rare [3]=epic
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
Config.Sizes = {
	{id = "Tiny",   chance = 8,  scale = 0.6, mult = 0.5, slow = -1},
	{id = "Small",  chance = 20, scale = 0.8, mult = 0.8, slow = 0},
	{id = "Normal", chance = 50, scale = 1,   mult = 1,   slow = 0},
	{id = "Big",    chance = 14, scale = 1.3, mult = 1.6, slow = 1},
	{id = "Huge",   chance = 6,  scale = 1.5, mult = 2.5, slow = 2},
	{id = "Giant",  chance = 2,  scale = 1.8, mult = 4,   slow = 3.5},
}
Config.ShelfMaxSize = 4 -- boxes on shelves can be at most "Big" (index 4); pallets can hold anything

function Config.GetMutation(id)
	for _, m in ipairs(Config.Mutations) do if m.id == id then return m end end
	return Config.Mutations[1]
end
function Config.GetSize(id)
	for _, s in ipairs(Config.Sizes) do if s.id == id then return s end end
	return Config.Sizes[3]
end
function Config.BoxLabel(def, mutationId, sizeId)
	local parts = {}
	if sizeId and sizeId ~= "Normal" then table.insert(parts, sizeId) end
	if mutationId and mutationId ~= "Normal" then table.insert(parts, mutationId) end
	table.insert(parts, def.name)
	return table.concat(parts, " ")
end

------------------------------------------------------------------
-- THE DEPARTMENTS of the MEGA MART (easy at the door, scary at the back).
-- guard = the security guard of that department, guardSpeed = his chase speed,
-- fling = how hard he throws you out when he catches you.
-- Every department has exactly 3 boxes (common, rare, epic) and 4 items (see Config.AreaItems).
------------------------------------------------------------------
Config.Areas = {
	{name = "Fruit & Veg", accent = rgb(110, 200, 70), guardSpeed = 12, fling = 60, guard = "Sleepy Stock Boy", boxes = {
		{id = "AppleCrate",     name = "Apple Crate",     color = rgb(205, 150, 90),  material = M.Wood},
		{id = "BananaBox",      name = "Banana Box",      color = rgb(250, 210, 60),  material = M.SmoothPlastic},
		{id = "MelonCrate",     name = "Melon Crate",     color = rgb(90, 175, 75),   material = M.Wood},
	}},
	{name = "Bakery", accent = rgb(235, 160, 70), guardSpeed = 18, fling = 90, guard = "Grumpy Baker", boxes = {
		{id = "BreadBox",       name = "Bread Box",       color = rgb(215, 165, 105), material = M.SmoothPlastic},
		{id = "BagelBox",       name = "Bagel Box",       color = rgb(235, 135, 55),  material = M.SmoothPlastic},
		{id = "CakeCrate",      name = "Cake Crate",      color = rgb(255, 165, 205), material = M.SmoothPlastic},
	}},
	{name = "Dairy", accent = rgb(120, 190, 255), guardSpeed = 22, fling = 120, guard = "Dairy Clerk", boxes = {
		{id = "MilkCrate",      name = "Milk Crate",      color = rgb(70, 140, 255),  material = M.Plastic},
		{id = "CheeseBox",      name = "Cheese Box",      color = rgb(255, 205, 60),  material = M.SmoothPlastic},
		{id = "ButterCrate",    name = "Butter Crate",    color = rgb(255, 235, 150), material = M.SmoothPlastic},
	}},
	{name = "Butcher", accent = rgb(230, 80, 80), guardSpeed = 26, fling = 150, guard = "The Butcher", boxes = {
		{id = "SausageBox",     name = "Sausage Box",     color = rgb(205, 95, 75),   material = M.SmoothPlastic},
		{id = "FishCrate",      name = "Fish Crate",      color = rgb(90, 175, 230),  material = M.Plastic},
		{id = "SteakBox",       name = "Steak Box",       color = rgb(165, 40, 50),   material = M.SmoothPlastic},
	}},
	{name = "Frozen", accent = rgb(130, 220, 255), guardSpeed = 30, fling = 180, guard = "Freezer Guard", boxes = {
		{id = "IcePopBox",      name = "Ice Pop Box",     color = rgb(150, 225, 255), material = M.SmoothPlastic},
		{id = "PizzaBox",       name = "Pizza Box",       color = rgb(230, 80, 50),   material = M.SmoothPlastic},
		{id = "IceCreamCrate",  name = "Ice Cream Crate", color = rgb(210, 240, 255), material = M.Ice},
	}},
	{name = "Snacks & Candy", accent = rgb(255, 110, 190), guardSpeed = 34.5, fling = 210, guard = "Candy Cop", boxes = {
		{id = "ChipsBox",       name = "Chips Box",       color = rgb(255, 180, 40),  material = M.SmoothPlastic},
		{id = "SweetsBox",      name = "Sweets Box",      color = rgb(255, 120, 200), material = M.SmoothPlastic},
		{id = "ChocolateCrate", name = "Chocolate Crate", color = rgb(115, 62, 35),   material = M.Wood},
	}},
	{name = "Drinks", accent = rgb(60, 200, 200), guardSpeed = 39, fling = 240, guard = "Drinks Manager", boxes = {
		{id = "SodaCrate",      name = "Soda Crate",      color = rgb(230, 45, 50),   material = M.Plastic},
		{id = "JuiceBox",       name = "Juice Box",       color = rgb(255, 150, 30),  material = M.SmoothPlastic},
		{id = "EnergyCrate",    name = "Energy Crate",    color = rgb(70, 220, 80),   material = M.SmoothPlastic},
	}},
	{name = "Toys", accent = rgb(255, 200, 60), guardSpeed = 44, fling = 270, guard = "Toy Store Guard", boxes = {
		{id = "ToyBox",         name = "Toy Box",         color = rgb(80, 150, 255),  material = M.SmoothPlastic},
		{id = "PlushBox",       name = "Plush Box",       color = rgb(255, 150, 190), material = M.Fabric},
		{id = "RocketBox",      name = "Rocket Box",      color = rgb(235, 60, 60),   material = M.SmoothPlastic},
	}},
	{name = "Electronics", accent = rgb(90, 120, 255), guardSpeed = 49, fling = 300, guard = "Tech Security", boxes = {
		{id = "GadgetBox",      name = "Gadget Box",      color = rgb(70, 75, 95),    material = M.SmoothPlastic},
		{id = "ConsoleBox",     name = "Console Box",     color = rgb(235, 235, 245), material = M.SmoothPlastic},
		{id = "TVBox",          name = "TV Box",          color = rgb(55, 60, 75),    material = M.Metal},
	}},
	{name = "Manager's Vault", accent = rgb(255, 195, 40), guardSpeed = 55, fling = 340, guard = "Store Manager", boxes = {
		{id = "CoinBox",        name = "Coin Box",        color = rgb(255, 200, 50),  material = M.Metal},
		{id = "SafeBox",        name = "Safe Box",        color = rgb(125, 130, 145), material = M.Metal},
		{id = "VaultCrate",     name = "Vault Crate",     color = rgb(255, 215, 70),  material = M.Neon},
	}},
}

-- fill in the department sizes + lookups: Config.Boxes[id] = box def (with .area and .rarity)
Config.Boxes = {}
local areaStartZ, areaEndZ = {}, {} -- cached z range of every department
do
	local L = Config.Layout
	local z = L.frontZ
	for areaIndex, area in ipairs(Config.Areas) do
		area.index = areaIndex
		area.len = area.len or (L.sectionLen + (areaIndex - 1) * L.growLen)             -- 64, 74 ... 154
		area.halfWidth = area.halfWidth or (L.halfWidth + (areaIndex - 1) * L.growWidth) -- 40, 44 ... 76
		areaStartZ[areaIndex] = z
		z -= area.len
		areaEndZ[areaIndex] = z
		for r, box in ipairs(area.boxes) do
			box.area = areaIndex
			box.rarity = r
			box.emoji = box.emoji or ""
			Config.Boxes[box.id] = box
		end
	end
end

------------------------------------------------------------------
-- STORE GEOMETRY: department i covers x in [-AreaHalfWidth(i), AreaHalfWidth(i)]
-- and z in [AreaEndZ(i), AreaStartZ(i)] (the store grows towards -Z).
------------------------------------------------------------------
function Config.AreaLen(areaIndex)
	local area = Config.Areas[areaIndex]
	return area and area.len or Config.Layout.sectionLen
end
function Config.AreaHalfWidth(areaIndex)
	local area = Config.Areas[areaIndex]
	return area and area.halfWidth or Config.Layout.halfWidth
end
-- z where a department starts (its entrance, the side closest to the front door)
function Config.AreaStartZ(areaIndex)
	if areaIndex <= 1 then return Config.Layout.frontZ end
	return areaStartZ[areaIndex] or areaEndZ[#areaEndZ]
end
-- z of the back of a department (where the next one starts)
function Config.AreaEndZ(areaIndex)
	return areaEndZ[math.clamp(areaIndex, 1, #areaEndZ)]
end
-- z of the store's back wall
function Config.StoreEndZ()
	return areaEndZ[#areaEndZ]
end
-- half width of the widest department
function Config.StoreHalfWidth()
	local hw = 0
	for i = 1, #Config.Areas do hw = math.max(hw, Config.AreaHalfWidth(i)) end
	return hw
end
-- which department a position is in (1..10), or nil when outside the store
function Config.ZoneAt(pos)
	if not pos then return nil end
	local z = pos.Z
	if z >= areaStartZ[1] or z < areaEndZ[#areaEndZ] then return nil end
	for i = 1, #areaEndZ do
		if z >= areaEndZ[i] then
			if math.abs(pos.X) <= Config.Areas[i].halfWidth + 1 then return i end
			return nil
		end
	end
	return nil
end

-- speed you should have (while carrying) to escape a department's guard
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
-- the speed number you should have to escape a department's guard
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

-- TRAILS sold at the TRAILS SHOP stall: a glowing trail behind you that makes
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
-- the VIP Trail comes with the VIP game pass (it isn't sold at the stall)
Config.VIPTrail = {id = "VIP", name = "VIP Trail", mult = 8, price = 0, vip = true, colors = {rgb(255, 215, 60), rgb(255, 250, 200), rgb(255, 170, 40)}}
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

-- TREADMILL on your base: stand on the belt and run to earn speed.
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
-- cash or a free box (placed right on your base). After the last one the timer starts over.
Config.Gifts = {
	{minutes = 1,  boxChance = 0.35}, {minutes = 3,  boxChance = 0.4}, {minutes = 6,  boxChance = 0.45},
	{minutes = 10, boxChance = 0.5},  {minutes = 15, boxChance = 0.55}, {minutes = 20, boxChance = 0.6},
	{minutes = 30, boxChance = 0.65}, {minutes = 45, boxChance = 0.75}, {minutes = 60, boxChance = 1},
}
function Config.GiftCash(index, incomePerSec) -- cash a gift is worth
	local base = math.floor(40 * 1.75 ^ (index - 1))
	return math.max(base, math.floor((incomePerSec or 0) * 20 * index))
end
function Config.GiftMaxArea(index) -- best department a gift box can come from
	return math.min(#Config.Areas, 1 + math.floor(index * 0.75))
end

-- the FREE GIFT in the lobby plaza: claim it once every `minutes` (cash, or sometimes a box)
Config.FreeGift = {minutes = 15, boxChance = 0.35}
function Config.FreeGiftCash(incomePerSec)
	return math.max(300, math.floor((incomePerSec or 0) * 120))
end

-- CUSTOMER KIOSK on your base: more shoppers = more money
Config.CustomerMax = 10
function Config.CustomerRate(level) return 1 + 0.3 * ((level or 1) - 1) end -- x shoppers
function Config.CustomerCost(level) return math.floor(120 * 2.3 ^ ((level or 1) - 1)) end

------------------------------------------------------------------
-- DAILY QUESTS: 3 a day (the same 3 for everybody), new ones every UTC day.
-- text: %s is replaced by the goal. goals = {easy, normal, hard}: quest slot 1/2/3 uses goals[1]/[2]/[3].
------------------------------------------------------------------
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

------------------------------------------------------------------
-- INDEX REWARDS: find all 4 items of a department to complete its Index page.
-- Claim it once for a pile of cash and a PERMANENT cash bonus (every department adds more).
------------------------------------------------------------------
Config.IndexReward = {
	seconds = 900,     -- the cash = 15 minutes of what that department's 4 items earn together
	cashBonus = 0.1,   -- +10% cash forever for every completed department (all 10 = x2)
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
-- true when every item of this department is in your Index
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
-- your best department) or "luckybox" (a guaranteed Rainbow box).
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
-- UNBOXING + YOUR SHOP SHELVES
------------------------------------------------------------------
Config.UnboxPads = 6          -- boxes you can have unboxing on your base at the same time
Config.ShelfUnits = 5         -- shelves at the back of your shop
Config.ShelfLayers = 3        -- layers per shelf
Config.ShelfCols = 3          -- products per layer
Config.MaxStands = Config.ShelfUnits * Config.ShelfLayers * Config.ShelfCols -- 45 shelf slots
Config.MaxItems = 60          -- inventory size

-- SHELF SLOTS ("+1 Equip"): you start with BaseStands active slots and buy the rest with cash
Config.BaseStands = 8
function Config.StandCost(unlocked) -- price of the NEXT slot when you have `unlocked` slots
	unlocked = math.max(Config.BaseStands, tonumber(unlocked) or Config.BaseStands)
	return math.floor(2500 * 1.45 ^ (unlocked - Config.BaseStands))
end

-- SHOPPERS: they walk from the street to one of your products and pay when they get there.
-- Your shop earns its full $/s all the time: each shopper pays everything the shop earned since
-- the last sale, so you never lose money when the shop gets busy.
Config.SaleSeconds = 6
Config.MaxCustomers = 4       -- shoppers in one shop at the same time
Config.MinCustomerGap = 1.2   -- a new shopper at most every 1.2 s per shop
Config.CustomerSpeed = 16     -- walk speed of a shopper
Config.CustomerWalk = 3.5     -- seconds from the street to the shelf (the sale happens when they arrive)

-- how long a box takes to open (seconds)
function Config.UnboxTime(def, sizeId, unboxLevel)
	local t = (8 + def.area * 6) * ({1, 1.6, 2.4})[def.rarity] * math.sqrt(Config.GetSize(sizeId).scale)
	return math.floor(t * (1 - 0.08 * (unboxLevel or 0)) + 0.5)
end

-- RESTOCK: seconds until an emptied box spot in the store gets a new box
function Config.RestockTime(areaIndex, rarity)
	return 8 + (areaIndex or 1) + (rarity or 1) * 4
end

-- Events: every few minutes a guaranteed Rainbow or Galaxy box appears somewhere
Config.SpecialBoxEvery = 120

-- item tiers: income multipliers and roll weights for [common, rare, epic] boxes
Config.ItemTiers = {
	-- weights = drop chance in % for a {common, rare, epic} box (each column adds up to 100)
	{name = "Common",    mult = 1,  color = rgb(220, 220, 220), weights = {79, 55, 35}},
	{name = "Uncommon",  mult = 2,  color = rgb(110, 230, 110), weights = {15, 28, 32}},
	{name = "Rare",      mult = 4,  color = rgb(90, 170, 255),  weights = {5, 13, 23}},
	{name = "Legendary", mult = 10, color = rgb(255, 190, 40),  weights = {1, 4, 10}},
}

-- 4 products per department, from common to legendary: {id, name}
Config.AreaItems = {
	{{"Apple", "Apple"},             {"Banana", "Banana"},           {"Watermelon", "Watermelon"},     {"GoldPineapple", "Golden Pineapple"}},
	{{"BreadLoaf", "Bread Loaf"},    {"Croissant", "Croissant"},     {"Doughnut", "Doughnut"},         {"BirthdayCake", "Birthday Cake"}},
	{{"MilkCarton", "Milk Carton"},  {"YogurtCup", "Yogurt"},        {"CheeseWheel", "Cheese Wheel"},  {"GoldEgg", "Golden Egg"}},
	{{"Sausage", "Sausage"},         {"FreshFish", "Fresh Fish"},    {"HamLeg", "Ham"},                {"GoldSteak", "Golden Steak"}},
	{{"IcePop", "Ice Pop"},          {"FrozenPizza", "Frozen Pizza"}, {"IceCreamTub", "Ice Cream Tub"}, {"FrozenTurkey", "Frozen Turkey"}},
	{{"ChipsBag", "Chips"},          {"SwirlPop", "Swirl Lollipop"}, {"ChocolateBar", "Chocolate Bar"}, {"CandyJar", "Candy Jar"}},
	{{"SodaCan", "Soda Can"},        {"OrangeJuice", "Orange Juice"}, {"EnergyDrink", "Energy Drink"}, {"GoldSoda", "Golden Soda"}},
	{{"RubberDuck", "Rubber Duck"},  {"TeddyBear", "Teddy Bear"},    {"RobotToy", "Toy Robot"},        {"ToyRocket", "Toy Rocket"}},
	{{"Headphones", "Headphones"},   {"Smartphone", "Smartphone"},   {"GameConsole", "Game Console"},  {"BigTV", "Big TV"}},
	{{"GoldCoin", "Gold Coin"},      {"MoneyBag", "Money Bag"},      {"GoldBar", "Gold Bar"},          {"GoldenCart", "Golden Cart"}},
}
Config.Items = {}
for areaIndex, list in ipairs(Config.AreaItems) do
	for tier, it in ipairs(list) do
		Config.Items[it[1]] = {id = it[1], name = it[2], emoji = it[3] or "", area = areaIndex, tier = tier,
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

------------------------------------------------------------------
-- OLD SAVES: before the MEGA MART the game had other box/item ids. The server swaps them
-- for the new ids (same department + same slot, so incomes and Index pages stay the same).
-- Never edit these two lists.
------------------------------------------------------------------
Config.SaveVersion = 2
Config.LegacyBoxIds = {
	{"OldBox", "DustyCrate", "AntiqueChest"}, {"HayBox", "EggCrate", "GoldenEgg"}, {"TeddyBox", "RobotToyBox", "RocketToyBox"},
	{"CandyBox", "CupcakeBox", "ChocoBox"}, {"PirateCrate", "TreasureChest", "CursedChest"}, {"FossilBox", "DinoEggBox", "TRexBox"},
	{"IceBox", "PenguinBox", "MammothBox"}, {"CircuitBox", "RobotBox", "AICoreBox"}, {"AlienBox", "UFOBox", "PlasmaBox"},
	{"StarBox", "GalaxyBox", "BlackHoleBox"},
}
Config.LegacyItemIds = {
	{"OldSpoon", "RustyKey", "PocketWatch", "AntiqueVase"}, {"Carrot", "Corn", "MilkJug", "GoldenEgg"},
	{"Teddy", "Puzzle", "Controller", "ToyRobot"}, {"Lollipop", "Donut", "Cake", "CandyCrown"},
	{"Shell", "Compass", "Spyglass", "TreasureMap"}, {"Bone", "Footprint", "DinoPlush", "TRexSkull"},
	{"Snowflake", "FrozenFish", "Snowman", "IceGem"}, {"Battery", "Chip", "Laptop", "Satellite"},
	{"Comet", "CrystalBall", "UFOModel", "AlienPlush"}, {"Moon", "Shooting", "GalaxyOrb", "BlackHoleCore"},
}
Config.OldBoxToNew, Config.OldItemToNew = {}, {}
for a, ids in ipairs(Config.LegacyBoxIds) do
	for r, old in ipairs(ids) do Config.OldBoxToNew[old] = Config.Areas[a].boxes[r].id end
end
for a, ids in ipairs(Config.LegacyItemIds) do
	for t, old in ipairs(ids) do Config.OldItemToNew[old] = Config.AreaItems[a][t][1] end
end

------------------------------------------------------------------
-- CLASSIC R6 AVATAR used by the security guards (map) and the shoppers (client).
-- A real R6 rig (HumanoidRootPart + Motor6Ds) so the classic R6 animations can play on it.
-- opt = {name, scale, cframe (HumanoidRootPart), face = true/false, and Color3s:
--   skin, shirt, pants, sleeves = true (arms in the shirt colour),
--   or per part: head, torso, leftArm, rightArm, arms, leftLeg, rightLeg}
------------------------------------------------------------------
Config.NoobColors = {
	head = Color3.fromRGB(245, 205, 48),   -- Bright yellow
	torso = Color3.fromRGB(13, 105, 172),  -- Bright blue
	legs = Color3.fromRGB(164, 189, 71),   -- Br. yellowish green
}
Config.R6Anims = {
	idle = "rbxassetid://180435571",
	walk = "rbxassetid://180426354",
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
	local skin = opt.skin or opt.head or Config.NoobColors.head
	local arms = opt.arms or (opt.sleeves and opt.shirt) or skin
	local legs = opt.pants or Config.NoobColors.legs
	local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	hrp.Transparency = 1
	hrp.Anchored = true
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), opt.torso or opt.shirt or Config.NoobColors.torso)
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), opt.head or skin)
	local la = part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), opt.leftArm or arms)
	local ra = part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), opt.rightArm or arms)
	local ll = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), opt.leftLeg or legs)
	local rl = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), opt.rightLeg or legs)
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
	-- the standard R6 attachment points, so accessories fit
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
-- 3D PRODUCT MODELS: every item is a little model built from a few parts.
-- Each entry: {shape, sizeX, sizeY, sizeZ, x, y, z, color, material, rotX, rotY, rotZ, transparency}
--   shape: "B" block, "S" sphere/ellipsoid, "C" cylinder (axis = X; rotZ 90 = standing up, rotY 90 = facing you),
--          "W" wedge (full at the bottom and the back, the slope faces the front, like a WedgePart)
-- Models are about 2 studs tall, stand on y = -1 (the shelf) and face -Z (towards the shoppers).
------------------------------------------------------------------
local function B(...) return {"B", ...} end
local function S(...) return {"S", ...} end
local function C(...) return {"C", ...} end
local function W(...) return {"W", ...} end
local MAT = Enum.Material
local SP, MET, NEON, GLASS, FAB = MAT.SmoothPlastic, MAT.Metal, MAT.Neon, MAT.Glass, MAT.Fabric
local white, black, silver = rgb(250, 250, 250), rgb(30, 30, 36), rgb(195, 200, 210)
local gold, goldDark, goldLight = rgb(255, 196, 45), rgb(215, 145, 25), rgb(255, 230, 130)
local leaf, bone = rgb(75, 190, 65), rgb(245, 238, 220)
-- a little twinkle for the golden products (put it LAST in a model: it adds 2 parts)
local function sparkle(x, y, z)
	local c = rgb(255, 250, 200)
	return S(0.1, 0.62, 0.04, x, y, z, c, NEON), S(0.62, 0.1, 0.04, x, y, z, c, NEON)
end
local yellow = rgb(255, 215, 60)

-- (the camera looks at the front, so +X is on the viewer's LEFT)
Config.ItemModels = {
	-- 1 FRUIT & VEG
	Apple = {S(1.7, 1.55, 1.7, 0, -0.15, 0, rgb(225, 35, 45)), S(0.3, 0.42, 0.1, 0.38, 0.12, -0.7, rgb(255, 160, 160)),
		B(0.13, 0.5, 0.13, -0.04, 0.78, 0, rgb(105, 65, 30), SP, 0, 0, 12), S(0.55, 0.14, 0.3, -0.33, 0.8, 0, leaf, SP, 0, 0, -25)},
	Banana = {C(0.47, 0.36, 0.36, -0.76, -0.59, 0, yellow, SP, 0, 0, -30), C(0.47, 0.46, 0.46, -0.39, -0.72, 0, yellow, SP, 0, 0, -10),
		C(0.47, 0.52, 0.52, 0, -0.72, 0, yellow, SP, 0, 0, 10), C(0.47, 0.52, 0.52, 0.37, -0.59, 0, yellow, SP, 0, 0, 30),
		C(0.47, 0.46, 0.46, 0.67, -0.33, 0, yellow, SP, 0, 0, 50), C(0.47, 0.38, 0.38, 0.87, 0.01, 0, yellow, SP, 0, 0, 70),
		S(0.24, 0.24, 0.24, -0.97, -0.46, 0, rgb(90, 60, 30)), C(0.38, 0.17, 0.17, 0.97, 0.36, 0, rgb(130, 105, 50), SP, 0, 0, 80)},
	Watermelon = {S(2.2, 1.75, 1.75, 0, -0.15, 0, rgb(85, 180, 65)), S(2.2, 1.85, 0.66, 0, -0.15, 0, rgb(35, 115, 45)),
		S(2.2, 1.85, 0.66, 0, -0.15, 0, rgb(35, 115, 45), SP, 45, 0, 0), S(2.2, 1.85, 0.66, 0, -0.15, 0, rgb(35, 115, 45), SP, 90, 0, 0),
		S(2.2, 1.85, 0.66, 0, -0.15, 0, rgb(35, 115, 45), SP, -45, 0, 0), B(0.12, 0.3, 0.12, 0.25, 0.8, 0, rgb(120, 95, 45), SP, 0, 0, -25)},
	GoldPineapple = {S(1.25, 1.55, 1.25, 0, -0.35, 0, gold, MET),
		S(0.2, 0.2, 0.12, -0.3, -0.05, -0.49, goldDark, MET), S(0.2, 0.2, 0.12, 0.3, -0.05, -0.49, goldDark, MET), S(0.2, 0.2, 0.12, 0, -0.35, -0.62, goldDark, MET),
		S(0.2, 0.2, 0.12, -0.3, -0.65, -0.49, goldDark, MET), S(0.2, 0.2, 0.12, 0.3, -0.65, -0.49, goldDark, MET),
		S(0.3, 0.95, 0.18, 0, 0.8, 0, leaf), S(0.28, 0.8, 0.16, -0.24, 0.7, 0, leaf, SP, 0, 0, 32), S(0.28, 0.8, 0.16, 0.24, 0.7, 0, leaf, SP, 0, 0, -32),
		S(0.16, 0.75, 0.28, 0, 0.68, -0.22, leaf, SP, -32, 0, 0)},
	-- 2 BAKERY
	BreadLoaf = {B(1.5, 0.85, 1.7, 0, -0.575, 0, rgb(205, 130, 55)), C(1.7, 1.5, 1.5, 0, -0.15, 0, rgb(205, 130, 55), SP, 0, 90, 0),
		B(1.32, 0.8, 0.04, 0, -0.58, -0.85, rgb(255, 235, 185)), C(0.04, 1.32, 1.32, 0, -0.15, -0.85, rgb(255, 235, 185), SP, 0, 90, 0),
		S(0.7, 0.1, 0.16, 0, 0.56, -0.3, rgb(240, 180, 100)), S(0.7, 0.1, 0.16, 0, 0.56, 0.25, rgb(240, 180, 100))},
	Croissant = {S(0.85, 0.95, 1.0, 0, -0.02, 0, rgb(225, 145, 55)), S(0.72, 0.75, 0.82, -0.5, -0.14, 0, rgb(245, 190, 105), SP, 0, 0, 26),
		S(0.72, 0.75, 0.82, 0.5, -0.14, 0, rgb(245, 190, 105), SP, 0, 0, -26), S(0.6, 0.55, 0.6, -0.84, -0.42, 0, rgb(225, 145, 55), SP, 0, 0, 56),
		S(0.6, 0.55, 0.6, 0.84, -0.42, 0, rgb(225, 145, 55), SP, 0, 0, -56), S(0.48, 0.34, 0.38, -0.95, -0.8, 0, rgb(245, 190, 105), SP, 0, 0, -87),
		S(0.48, 0.34, 0.38, 0.95, -0.8, 0, rgb(245, 190, 105), SP, 0, 0, 87)},
	Doughnut = {S(1.9, 1.9, 0.75, 0, -0.05, 0, rgb(215, 150, 80)), S(1.72, 1.72, 0.66, 0, -0.03, -0.08, rgb(255, 125, 185)),
		C(0.9, 0.55, 0.55, 0, -0.05, 0, rgb(110, 65, 35), SP, 0, 90, 0),
		B(0.24, 0.07, 0.07, -0.5, 0.25, -0.32, rgb(255, 235, 70), SP, 0, 0, 20), B(0.24, 0.07, 0.07, 0.38, 0.4, -0.32, rgb(90, 200, 255), SP, 0, 0, -40),
		B(0.24, 0.07, 0.07, 0.52, -0.3, -0.32, rgb(120, 230, 110), SP, 0, 0, 60), B(0.24, 0.07, 0.07, -0.35, -0.5, -0.32, white, SP, 0, 0, -15),
		B(0.24, 0.07, 0.07, 0.05, 0.6, -0.3, rgb(255, 90, 90), SP, 0, 0, 80)},
	BirthdayCake = {C(0.75, 1.9, 1.9, 0, -0.6, 0, rgb(255, 240, 225), SP, 0, 0, 90), C(0.16, 1.96, 1.96, 0, -0.26, 0, rgb(255, 130, 185), SP, 0, 0, 90),
		C(0.55, 1.3, 1.3, 0, 0.05, 0, rgb(255, 240, 225), SP, 0, 0, 90), C(0.12, 1.36, 1.36, 0, 0.32, 0, rgb(255, 130, 185), SP, 0, 0, 90),
		C(0.55, 0.16, 0.16, 0, 0.65, 0, rgb(110, 190, 255), SP, 0, 0, 90), S(0.18, 0.3, 0.18, 0, 1.03, 0, rgb(255, 190, 40), NEON),
		S(0.22, 0.22, 0.1, -0.5, -0.62, -0.82, rgb(255, 90, 90)), S(0.22, 0.22, 0.1, 0, -0.62, -0.96, rgb(90, 200, 255)),
		S(0.22, 0.22, 0.1, 0.5, -0.62, -0.82, rgb(255, 220, 60))},
	-- 3 DAIRY
	MilkCarton = {B(1.1, 1.45, 1.1, 0, -0.275, 0, white), B(0.778, 0.778, 1.1, 0, 0.45, 0, rgb(70, 140, 255), SP, 0, 0, 45),
		B(0.12, 0.2, 1.1, 0, 1.02, 0, white), B(1.12, 0.5, 1.12, 0, -0.3, 0, rgb(70, 140, 255)), S(0.36, 0.36, 0.08, 0, -0.3, -0.57, white)},
	YogurtCup = {C(1.55, 1.35, 1.35, 0, -0.225, 0, white, SP, 0, 0, 90), C(0.62, 1.38, 1.38, 0, -0.25, 0, rgb(255, 140, 185), SP, 0, 0, 90),
		C(0.1, 1.5, 1.5, 0, 0.57, 0, white, SP, 0, 0, 90), C(0.05, 1.46, 1.46, 0, 0.63, 0, silver, MET, 0, 0, 90),
		B(0.32, 0.05, 0.3, 0, 0.63, -0.84, silver, MET), S(0.36, 0.42, 0.1, 0, -0.28, -0.69, rgb(230, 40, 60)),
		S(0.28, 0.12, 0.08, 0, -0.06, -0.69, leaf)},
	CheeseWheel = {C(0.75, 1.85, 1.85, -0.18, -0.07, 0.2, rgb(240, 175, 40), SP, 0, 90, 0), C(0.04, 1.62, 1.62, -0.18, -0.07, -0.19, rgb(255, 222, 105), SP, 0, 90, 0),
		S(0.32, 0.32, 0.06, -0.45, 0.28, -0.21, rgb(225, 160, 35)), S(0.24, 0.24, 0.06, 0.12, -0.3, -0.21, rgb(225, 160, 35)),
		S(0.2, 0.2, 0.06, -0.6, -0.4, -0.21, rgb(225, 160, 35)),
		W(0.55, 0.85, 0.95, 0.6, -0.575, -0.45, rgb(255, 222, 105), SP, 0, 90, 0), B(0.08, 0.85, 0.55, 1.05, -0.575, -0.45, rgb(240, 175, 40)),
		S(0.2, 0.2, 0.06, 0.82, -0.78, -0.73, rgb(225, 160, 35)), S(0.14, 0.14, 0.06, 0.55, -0.9, -0.73, rgb(225, 160, 35))},
	GoldEgg = {S(1.3, 1.65, 1.3, 0, 0.1, 0, gold, MET), S(0.26, 0.4, 0.1, 0.3, 0.42, -0.53, rgb(255, 250, 215), NEON),
		C(0.55, 1.0, 1.0, 0, -0.73, 0, white, SP, 0, 0, 90), C(0.1, 1.1, 1.1, 0, -0.47, 0, rgb(255, 120, 170), SP, 0, 0, 90),
		sparkle(-0.62, 0.65, -0.3)},
	-- 4 BUTCHER
	Sausage = {S(1.35, 0.62, 0.62, -0.31, -0.63, 0, rgb(200, 95, 70), SP, 0, 0, -8), S(1.35, 0.62, 0.62, 0.61, -0.18, 0, rgb(200, 95, 70), SP, 0, 0, 60),
		S(0.22, 0.26, 0.26, 0.3, -0.72, 0, rgb(170, 75, 55)), S(0.16, 0.2, 0.16, -0.99, -0.54, 0, rgb(170, 75, 55)), S(0.16, 0.2, 0.16, 0.96, 0.42, 0, rgb(170, 75, 55)),
		S(0.24, 0.13, 0.06, -0.15, -0.44, -0.24, rgb(230, 140, 110)), S(0.24, 0.13, 0.06, 0.6, 0.02, -0.27, rgb(230, 140, 110))},
	FreshFish = {S(1.8, 0.9, 0.55, 0, -0.25, 0, rgb(110, 165, 215), SP, 0, 0, -18), S(1.45, 0.42, 0.5, -0.11, -0.42, -0.03, rgb(225, 235, 245), SP, 0, 0, -18),
		S(0.7, 0.32, 0.12, 1.03, -0.37, 0, rgb(80, 130, 195), SP, 0, 0, 17), S(0.7, 0.32, 0.12, 0.91, -0.76, 0, rgb(80, 130, 195), SP, 0, 0, -53),
		S(0.75, 0.4, 0.08, 0.18, 0.13, 0, rgb(80, 130, 195), SP, 0, 0, -26), S(0.26, 0.26, 0.08, -0.49, 0.02, -0.21, white),
		S(0.13, 0.13, 0.06, -0.52, 0.02, -0.25, black)},
	HamLeg = {S(1.55, 1.2, 1.05, -0.28, -0.35, 0, rgb(195, 95, 60), SP, 0, 0, 40), S(0.4, 0.2, 0.08, -0.42, -0.2, -0.5, rgb(235, 150, 110), SP, 0, 0, 40),
		C(0.12, 0.6, 0.6, 0.24, 0.09, 0, rgb(255, 175, 170), SP, 0, 0, 40), C(0.95, 0.3, 0.3, 0.5, 0.31, 0, bone, SP, 0, 0, 40),
		S(0.38, 0.38, 0.38, 0.82, 0.75, 0, bone), S(0.38, 0.38, 0.38, 1.0, 0.54, 0, bone)},
	GoldSteak = {S(1.95, 1.5, 0.32, 0.1, -0.2, 0, goldLight, MET), S(1.15, 1.0, 0.32, -0.55, -0.45, 0, goldLight, MET),
		S(1.8, 1.35, 0.4, 0.1, -0.2, 0, gold, MET), S(1.0, 0.85, 0.4, -0.55, -0.45, 0, gold, MET),
		C(0.12, 0.46, 0.46, -0.58, -0.45, -0.17, rgb(255, 248, 225), SP, 0, 90, 0), C(0.14, 0.2, 0.2, -0.58, -0.45, -0.17, goldDark, MET, 0, 90, 0),
		S(0.55, 0.08, 0.06, 0.42, 0.05, -0.19, goldLight, MET, 0, 0, 20), S(0.45, 0.07, 0.06, 0.2, -0.45, -0.19, goldLight, MET, 0, 0, -15),
		sparkle(0.75, 0.5, -0.3)},
	-- 5 FROZEN
	IcePop = {B(0.28, 0.8, 0.12, 0, -0.6, 0, rgb(225, 190, 135)), B(0.95, 0.5, 0.42, 0, 0.0, 0, rgb(80, 165, 255)),
		B(0.95, 0.3, 0.42, 0, 0.4, 0, white), B(0.95, 0.25, 0.42, 0, 0.67, 0, rgb(240, 50, 60)),
		C(0.42, 0.95, 0.95, 0, 0.75, 0, rgb(240, 50, 60), SP, 0, 90, 0)},
	FrozenPizza = {B(1.8, 1.8, 0.3, 0, -0.1, 0, rgb(90, 170, 255)), B(1.82, 0.36, 0.32, 0, 0.6, 0, rgb(230, 50, 50)),
		B(1.84, 0.1, 0.34, 0, 0.83, 0, white), C(0.04, 1.3, 1.3, 0, -0.2, -0.16, rgb(235, 175, 90), SP, 0, 90, 0),
		C(0.04, 1.08, 1.08, 0, -0.2, -0.18, rgb(255, 205, 70), SP, 0, 90, 0), S(0.24, 0.24, 0.05, -0.25, 0.0, -0.2, rgb(205, 40, 40)),
		S(0.24, 0.24, 0.05, 0.28, -0.12, -0.2, rgb(205, 40, 40)), S(0.24, 0.24, 0.05, -0.05, -0.45, -0.2, rgb(205, 40, 40))},
	IceCreamTub = {C(1.05, 1.65, 1.65, 0, -0.475, 0, rgb(255, 245, 230), SP, 0, 0, 90), C(0.45, 1.68, 1.68, 0, -0.5, 0, rgb(255, 125, 175), SP, 0, 0, 90),
		C(0.1, 1.75, 1.75, 0, 0.05, 0, rgb(255, 125, 175), SP, 0, 0, 90), S(0.85, 0.7, 0.85, -0.38, 0.25, 0.15, rgb(255, 160, 200)),
		S(0.85, 0.7, 0.85, 0.38, 0.25, 0.15, rgb(140, 85, 50)), S(0.85, 0.7, 0.85, 0, 0.3, -0.3, rgb(255, 240, 200)),
		S(0.28, 0.28, 0.28, 0.05, 0.7, -0.2, rgb(230, 30, 50)), B(0.12, 0.6, 0.25, 0.45, 0.6, 0, rgb(235, 190, 120), SP, 0, 0, -20)},
	FrozenTurkey = {S(1.75, 1.15, 1.3, -0.2, -0.38, 0, rgb(225, 145, 60)), S(0.85, 0.5, 0.5, 0.48, -0.05, -0.3, rgb(205, 120, 50), SP, 0, 0, 40),
		S(0.85, 0.5, 0.5, 0.48, -0.05, 0.3, rgb(205, 120, 50), SP, 0, 0, 40), C(0.32, 0.15, 0.15, 0.85, 0.26, -0.3, bone, SP, 0, 0, 40),
		C(0.32, 0.15, 0.15, 0.85, 0.26, 0.3, bone, SP, 0, 0, 40), C(0.14, 0.28, 0.28, 0.97, 0.36, -0.3, white, SP, 0, 0, 40),
		C(0.14, 0.28, 0.28, 0.97, 0.36, 0.3, white, SP, 0, 0, 40),
		B(2.25, 1.75, 1.65, 0, -0.125, 0, rgb(185, 230, 255), GLASS, 0, 0, 0, 0.6), B(2.27, 0.12, 1.67, 0, 0.72, 0, white, SP, 0, 0, 0, 0.25)},
	-- 6 SNACKS & CANDY
	ChipsBag = {B(1.45, 1.6, 0.4, 0, -0.1, 0, rgb(230, 45, 45)), S(1.45, 1.55, 0.72, 0, -0.1, 0, rgb(230, 45, 45)),
		B(1.5, 0.18, 0.16, 0, 0.78, 0, rgb(170, 25, 30)), B(1.5, 0.18, 0.16, 0, -0.98, 0, rgb(170, 25, 30)),
		S(0.85, 0.85, 0.1, 0, -0.05, -0.35, rgb(255, 210, 50)), S(0.55, 0.36, 0.08, 0.04, -0.03, -0.4, rgb(235, 165, 60), SP, 0, 0, 20)},
	SwirlPop = {B(0.14, 0.95, 0.14, 0, -0.52, 0, white), C(0.24, 1.55, 1.55, 0, 0.42, 0, rgb(255, 80, 170), SP, 0, 90, 0),
		C(0.26, 1.2, 1.2, 0.06, 0.38, 0, rgb(255, 225, 70), SP, 0, 90, 0), C(0.28, 0.88, 0.88, -0.02, 0.45, 0, rgb(80, 190, 255), SP, 0, 90, 0),
		C(0.3, 0.56, 0.56, 0.04, 0.4, 0, white, SP, 0, 90, 0), C(0.32, 0.26, 0.26, 0, 0.43, 0, rgb(255, 80, 170), SP, 0, 90, 0)},
	ChocolateBar = {B(1.2, 1.9, 0.26, 0, -0.05, 0, rgb(105, 55, 30)),
		B(0.5, 0.38, 0.08, -0.29, 0.66, -0.14, rgb(135, 75, 42)), B(0.5, 0.38, 0.08, 0.29, 0.66, -0.14, rgb(135, 75, 42)),
		B(0.5, 0.38, 0.08, -0.29, 0.24, -0.14, rgb(135, 75, 42)), B(0.5, 0.38, 0.08, 0.29, 0.24, -0.14, rgb(135, 75, 42)),
		B(1.28, 0.95, 0.34, 0, -0.55, 0, rgb(140, 60, 210)), B(1.26, 0.1, 0.32, 0, -0.03, 0, gold, MET), B(1.3, 0.24, 0.36, 0, -0.55, 0, gold)},
	CandyJar = {C(1.5, 1.5, 1.5, 0, -0.25, 0, rgb(205, 235, 255), GLASS, 0, 0, 90, 0.55),
		S(0.5, 0.5, 0.5, -0.35, -0.68, -0.2, rgb(255, 80, 150)), S(0.5, 0.5, 0.5, 0.3, -0.7, -0.25, rgb(255, 220, 60)),
		S(0.5, 0.5, 0.5, 0, -0.3, -0.3, rgb(80, 190, 255)), S(0.5, 0.5, 0.5, -0.38, -0.2, 0.2, rgb(120, 230, 100)),
		S(0.5, 0.5, 0.5, 0.35, -0.25, 0.15, rgb(255, 150, 60)), C(0.3, 1.2, 1.2, 0, 0.62, 0, rgb(230, 50, 70), SP, 0, 0, 90),
		S(0.36, 0.26, 0.36, 0, 0.82, 0, rgb(230, 50, 70))},
	-- 7 DRINKS
	SodaCan = {C(1.7, 1.05, 1.05, 0, -0.15, 0, rgb(225, 35, 45), SP, 0, 0, 90), C(0.1, 0.95, 0.95, 0, 0.73, 0, silver, MET, 0, 0, 90),
		C(0.1, 0.95, 0.95, 0, -0.97, 0, silver, MET, 0, 0, 90), C(0.26, 1.08, 1.08, 0, -0.15, 0, white, SP, 0, 0, 75),
		B(0.24, 0.05, 0.36, 0, 0.8, -0.08, silver, MET)},
	OrangeJuice = {C(1.2, 1.05, 1.05, 0, -0.4, 0, rgb(255, 160, 35), SP, 0, 0, 90), S(1.05, 0.7, 1.05, 0, 0.2, 0, rgb(255, 160, 35)),
		C(0.35, 0.45, 0.45, 0, 0.6, 0, rgb(255, 160, 35), SP, 0, 0, 90), C(0.25, 0.55, 0.55, 0, 0.85, 0, rgb(70, 190, 70), SP, 0, 0, 90),
		C(0.6, 1.08, 1.08, 0, -0.4, 0, white, SP, 0, 0, 90), S(0.42, 0.42, 0.12, 0, -0.4, -0.54, rgb(255, 140, 20)),
		S(0.22, 0.1, 0.06, 0.1, -0.16, -0.54, leaf, SP, 0, 0, 20)},
	EnergyDrink = {C(1.9, 0.85, 0.85, 0, -0.05, 0, rgb(35, 35, 45), SP, 0, 0, 90), C(0.08, 0.76, 0.76, 0, 0.92, 0, silver, MET, 0, 0, 90),
		C(0.08, 0.76, 0.76, 0, -0.98, 0, silver, MET, 0, 0, 90), B(0.16, 0.55, 0.06, -0.06, 0.3, -0.41, rgb(120, 255, 60), NEON, 0, 0, 28),
		B(0.34, 0.12, 0.06, 0, 0.06, -0.41, rgb(120, 255, 60), NEON), B(0.16, 0.55, 0.06, 0.06, -0.2, -0.41, rgb(120, 255, 60), NEON, 0, 0, 28),
		B(0.2, 0.04, 0.3, 0, 0.97, -0.06, silver, MET)},
	GoldSoda = {C(1.1, 0.95, 0.95, 0, -0.45, 0, gold, MET, 0, 0, 90), S(0.95, 0.9, 0.95, 0, 0.1, 0, gold, MET),
		C(0.6, 0.4, 0.4, 0, 0.65, 0, gold, MET, 0, 0, 90), C(0.08, 0.48, 0.48, 0, 0.93, 0, goldLight, MET, 0, 0, 90),
		C(0.12, 0.5, 0.5, 0, 1.0, 0, rgb(230, 50, 50), SP, 0, 0, 90), C(0.45, 0.98, 0.98, 0, -0.5, 0, rgb(230, 50, 50), SP, 0, 0, 90),
		sparkle(-0.6, 0.5, -0.3)},
	-- 8 TOYS
	RubberDuck = {S(1.75, 1.05, 1.3, 0.12, -0.47, 0, rgb(255, 215, 40)), S(0.55, 0.38, 0.5, 0.9, -0.15, 0, rgb(255, 215, 40), SP, 0, 0, 40),
		S(1.0, 1.0, 0.95, -0.38, 0.35, 0, rgb(255, 215, 40)), S(0.62, 0.26, 0.5, -0.92, 0.25, 0, rgb(255, 140, 30)),
		S(0.15, 0.2, 0.1, -0.6, 0.5, -0.4, black), S(0.8, 0.5, 0.2, 0.25, -0.42, -0.58, rgb(255, 190, 30), SP, 0, 0, -12)},
	TeddyBear = {S(1.15, 1.15, 0.95, 0, -0.45, 0, rgb(180, 115, 65)), S(1.0, 0.92, 0.85, 0, 0.42, 0, rgb(180, 115, 65)),
		S(0.38, 0.38, 0.22, -0.38, 0.8, 0, rgb(180, 115, 65)), S(0.38, 0.38, 0.22, 0.38, 0.8, 0, rgb(180, 115, 65)),
		S(0.45, 0.32, 0.3, 0, 0.3, -0.33, rgb(235, 195, 145)), S(0.17, 0.12, 0.1, 0, 0.38, -0.47, black),
		S(0.11, 0.13, 0.06, -0.18, 0.55, -0.37, black), S(0.11, 0.13, 0.06, 0.18, 0.55, -0.37, black),
		S(0.42, 0.36, 0.55, -0.32, -0.88, -0.25, rgb(180, 115, 65)), S(0.42, 0.36, 0.55, 0.32, -0.88, -0.25, rgb(180, 115, 65))},
	RobotToy = {B(1.0, 0.9, 0.7, 0, -0.2, 0, rgb(70, 150, 255)), B(0.8, 0.62, 0.62, 0, 0.6, 0, silver),
		S(0.18, 0.18, 0.06, -0.18, 0.62, -0.32, rgb(90, 240, 255), NEON), S(0.18, 0.18, 0.06, 0.18, 0.62, -0.32, rgb(90, 240, 255), NEON),
		B(0.06, 0.2, 0.06, 0, 0.98, 0, black), S(0.2, 0.2, 0.2, 0, 1.12, 0, rgb(255, 60, 60), NEON),
		B(0.24, 0.75, 0.3, -0.64, -0.2, 0, silver), B(0.24, 0.75, 0.3, 0.64, -0.2, 0, silver),
		B(0.32, 0.4, 0.36, -0.25, -0.85, 0, rgb(255, 200, 50)), B(0.32, 0.4, 0.36, 0.25, -0.85, 0, rgb(255, 200, 50))},
	ToyRocket = {C(1.25, 0.8, 0.8, 0, -0.05, 0, white, SP, 0, 0, 90), S(0.8, 1.0, 0.8, 0, 0.55, 0, rgb(235, 50, 50)),
		C(0.1, 0.42, 0.42, 0, 0.12, -0.39, rgb(120, 210, 255), SP, 0, 90, 0), C(0.06, 0.52, 0.52, 0, 0.12, -0.37, rgb(235, 50, 50), SP, 0, 90, 0),
		W(0.12, 0.75, 0.42, -0.58, -0.62, 0, rgb(235, 50, 50), SP, 0, 90, 0), W(0.12, 0.75, 0.42, 0.58, -0.62, 0, rgb(235, 50, 50), SP, 0, -90, 0),
		C(0.15, 0.82, 0.82, 0, -0.45, 0, rgb(235, 50, 50), SP, 0, 0, 90), C(0.18, 0.5, 0.5, 0, -0.75, 0, silver, MET, 0, 0, 90),
		S(0.34, 0.36, 0.34, 0, -0.88, 0, rgb(255, 160, 40), NEON)},
	-- 9 ELECTRONICS
	Headphones = {B(0.68, 0.2, 0.32, 0.7, 0.04, 0, rgb(50, 50, 60), SP, 0, 0, -67.5), B(0.68, 0.2, 0.32, 0.29, 0.45, 0, rgb(50, 50, 60), SP, 0, 0, -22.5),
		B(0.68, 0.2, 0.32, -0.29, 0.45, 0, rgb(50, 50, 60), SP, 0, 0, 22.5), B(0.68, 0.2, 0.32, -0.7, 0.04, 0, rgb(50, 50, 60), SP, 0, 0, 67.5),
		S(0.45, 0.85, 0.75, -0.85, -0.55, 0, rgb(255, 80, 130)), S(0.45, 0.85, 0.75, 0.85, -0.55, 0, rgb(255, 80, 130)),
		C(0.14, 0.62, 0.62, -0.6, -0.55, 0, rgb(50, 50, 60)), C(0.14, 0.62, 0.62, 0.6, -0.55, 0, rgb(50, 50, 60))},
	Smartphone = {B(1.05, 1.95, 0.14, 0, -0.025, 0, rgb(120, 70, 220)), B(0.92, 1.68, 0.02, 0, 0, -0.075, rgb(40, 140, 255), NEON),
		B(0.22, 0.22, 0.02, -0.2, 0.5, -0.088, rgb(255, 90, 90)), B(0.22, 0.22, 0.02, 0.2, 0.5, -0.088, rgb(255, 220, 60)),
		B(0.22, 0.22, 0.02, -0.2, 0.15, -0.088, rgb(90, 230, 110)), B(0.22, 0.22, 0.02, 0.2, 0.15, -0.088, white),
		B(0.3, 0.06, 0.02, 0, 0.78, -0.088, black)},
	GameConsole = {B(0.75, 1.75, 1.3, 0.35, -0.125, 0.25, white), B(0.25, 1.77, 1.32, 0.35, -0.125, 0.25, black),
		B(0.05, 0.5, 0.02, 0.35, 0.35, -0.42, rgb(60, 160, 255), NEON),
		B(0.9, 0.42, 0.3, -0.35, -0.55, -0.65, rgb(40, 40, 50)), S(0.42, 0.62, 0.36, -0.72, -0.72, -0.65, rgb(40, 40, 50), SP, 0, 0, 20),
		S(0.42, 0.62, 0.36, 0.02, -0.72, -0.65, rgb(40, 40, 50), SP, 0, 0, -20), S(0.13, 0.13, 0.08, -0.6, -0.52, -0.8, rgb(110, 110, 120)),
		S(0.11, 0.11, 0.06, -0.12, -0.48, -0.8, rgb(255, 70, 70)), S(0.11, 0.11, 0.06, -0.02, -0.6, -0.8, rgb(70, 220, 90))},
	BigTV = {B(2.3, 1.45, 0.16, 0, 0.12, 0, rgb(35, 35, 42)), B(2.12, 1.28, 0.02, 0, 0.12, -0.085, rgb(110, 200, 255)),
		B(2.12, 0.38, 0.02, 0, -0.33, -0.09, rgb(90, 210, 90)), S(0.36, 0.36, 0.02, 0.6, 0.45, -0.095, rgb(255, 225, 60), NEON),
		S(0.55, 0.24, 0.02, -0.5, 0.48, -0.095, white), B(0.22, 0.35, 0.14, 0, -0.75, 0.02, rgb(35, 35, 42)),
		B(1.0, 0.08, 0.55, 0, -0.96, 0.02, rgb(35, 35, 42))},
	-- 10 MANAGER'S VAULT
	GoldCoin = {C(0.26, 1.9, 1.9, 0, -0.05, 0, gold, MET, 0, 90, 0), C(0.28, 1.5, 1.5, 0, -0.05, 0, goldDark, MET, 0, 90, 0),
		B(0.55, 0.12, 0.06, 0, 0.3, -0.16, goldLight, MET), B(0.55, 0.12, 0.06, 0, -0.05, -0.16, goldLight, MET),
		B(0.55, 0.12, 0.06, 0, -0.4, -0.16, goldLight, MET), B(0.12, 0.47, 0.06, 0.215, 0.125, -0.16, goldLight, MET),
		B(0.12, 0.47, 0.06, -0.215, -0.225, -0.16, goldLight, MET), B(0.09, 1.02, 0.06, 0, -0.05, -0.15, goldLight, MET),
		sparkle(-0.75, 0.7, -0.3)},
	MoneyBag = {S(1.65, 1.5, 1.45, 0, -0.3, 0, rgb(215, 175, 105), FAB), S(0.8, 0.6, 0.75, 0, 0.66, 0, rgb(215, 175, 105), FAB),
		C(0.2, 0.55, 0.55, 0, 0.43, 0, rgb(150, 95, 45), SP, 0, 0, 90),
		B(0.55, 0.12, 0.2, 0, 0.02, -0.62, rgb(50, 170, 70)), B(0.55, 0.12, 0.2, 0, -0.3, -0.68, rgb(50, 170, 70)),
		B(0.55, 0.12, 0.2, 0, -0.62, -0.62, rgb(50, 170, 70)), B(0.12, 0.44, 0.2, 0.215, -0.14, -0.65, rgb(50, 170, 70)),
		B(0.12, 0.44, 0.2, -0.215, -0.46, -0.65, rgb(50, 170, 70)), B(0.09, 0.95, 0.2, 0, -0.3, -0.66, rgb(50, 170, 70))},
	GoldBar = {B(1.1, 0.5, 0.62, -0.58, -0.75, 0.08, gold, MET), W(1.1, 0.5, 0.2, -0.58, -0.75, -0.33, gold, MET),
		B(1.1, 0.5, 0.62, 0.58, -0.75, 0.08, gold, MET), W(1.1, 0.5, 0.2, 0.58, -0.75, -0.33, gold, MET),
		B(1.1, 0.5, 0.62, 0, -0.25, 0.12, gold, MET), W(1.1, 0.5, 0.2, 0, -0.25, -0.29, gold, MET),
		sparkle(-0.5, 0.3, -0.3)},
	GoldenCart = {B(1.3, 1.0, 1.05, 0.15, 0, 0, gold, MET), W(1.05, 1.0, 0.45, -0.725, 0, 0, gold, MET, 180, 90, 0),
		B(1.8, 0.1, 1.1, -0.07, 0.53, 0, goldLight, MET), B(1.25, 0.06, 0.02, 0.15, 0.05, -0.535, goldDark, MET),
		B(0.06, 0.9, 0.02, 0.35, 0, -0.535, goldDark, MET), B(0.1, 0.5, 0.9, 0.9, 0.72, 0, gold, MET, 0, 0, -27),
		C(1.1, 0.16, 0.16, 1.02, 0.95, 0, rgb(230, 50, 50), SP, 0, 90, 0), B(1.2, 0.08, 0.9, 0.15, -0.55, 0, goldDark, MET),
		C(0.18, 0.36, 0.36, -0.35, -0.78, -0.35, black, SP, 0, 90, 0), C(0.18, 0.36, 0.36, 0.65, -0.78, -0.35, black, SP, 0, 90, 0)},
}

-- mutations tint the model: Gold, Diamond, Lava, Rainbow, Galaxy
local MUT_MATERIAL = {Gold = MAT.Metal, Diamond = MAT.Glass, Lava = MAT.Neon, Galaxy = MAT.Neon}

-- Build an item as a model. Returns the model and a list of {part, offset, rot, size} at scale 1,
-- so animations can move / resize every part around one centre.
function Config.BuildItemModel(item, scale, cframe)
	scale = scale or 1
	cframe = cframe or CFrame.new()
	local spec = Config.ItemModels[item.id] or {S(1.2, 1.2, 1.2, 0, 0, 0, rgb(200, 200, 200))}
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
		if shape == "S" or shape == "W" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = (shape == "S") and Enum.MeshType.Sphere or Enum.MeshType.Wedge
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
	return 1.3 * math.min(1.15, math.sqrt(Config.GetSize(item.size).scale))
end

return Config
