-- Smoke test: run the SERVER in a fake engine with one player and play through the game.
local task = require("@lune/task")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local H = require("./env")
local Enum = roblox.Enum
local V3, CF = roblox.Vector3.new, roblox.CFrame.new

task.delay(170, function()
	print("WATCHDOG: test took too long")
	for _, e in ipairs(H.errors) do print("  " .. e) end
	process.exit(2)
end)

local realGame = roblox.deserializePlace(fs.readFile(process.args[1]))
-- give a few products real IDs so the ProcessReceipt path can be tested
local shopModule = realGame:GetService("ReplicatedStorage"):FindFirstChild("StealABoxShop")
local src = shopModule.Source
src = src:gsub('(key = "%w+",%s+id = )%d+', '%10') -- (passes/products back to id 0: Studio test grants)
src = src:gsub('{key = "CashS",  id = 0,', '{key = "CashS",  id = 1111,', 1)
src = src:gsub('{key = "LuckyBox",   id = 0,', '{key = "LuckyBox",   id = 2222,', 1)
shopModule.Source = src

local game = H.wrap(realGame)
H.game = game
H.isClient = false
local S = H.makeServices(game)
H.services = S
local ws = game:GetService("Workspace")
H.workspace = ws
local cam = H.newInstance("Camera")
cam.Parent = ws
H.setValue(ws, "CurrentCamera", cam)

-- Players
local playersFolder = H.newInstance("Folder")
playersFolder.Name = "Players"
local list = {}
S.Players = {PlayerAdded = H.newSignal("PlayerAdded"), PlayerRemoving = H.newSignal("PlayerRemoving")}
function S.Players:GetPlayers() local out = {} for _, p in ipairs(list) do if p.Parent then table.insert(out, p) end end return out end
function S.Players:GetPlayerByUserId(id) for _, p in ipairs(list) do if p.UserId == id and p.Parent then return p end end return nil end
function S.Players:GetFriendsAsync() error("no friends in tests") end
function S.Players:GetHumanoidDescriptionFromUserId() error("no avatars in tests") end
H.setOverrides(game, {
	GetService = function(self, name)
		if S[name] then return S[name] end
		return H.wrap(realGame:GetService(name))
	end,
	JobId = "server-A",
})

local function check(cond, msg)
	if not cond then H.record("CHECK", msg) print("FAIL: " .. msg) else print("ok: " .. msg) end
end

local function makePlayer(userId, name)
	local p = H.newInstance("Folder")
	p.Name = name
	H.setValue(p, "UserId", userId)
	H.setValue(p, "DisplayName", name)
	local char = H.newInstance("Model")
	char.Name = name
	local hrp = H.newInstance("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = V3(2, 2, 1)
	hrp.CFrame = CF(0, 3, 200)
	hrp.Parent = char
	local hum = H.newInstance("Humanoid")
	hum.Parent = char
	char.Parent = ws
	p.Parent = playersFolder
	H.setValue(p, "Character", char)
	table.insert(list, p)
	return p, char, hrp
end

-- map + server
H.runScript(game:GetService("ServerScriptService"):FindFirstChild("StealABoxMap"))
task.wait(0.3)
H.runScript(game:GetService("ServerScriptService"):FindFirstChild("StealABoxServer"))
task.wait(0.5)
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("StealABoxRemotes")
local Action = remotes:FindFirstChild("Action")
local invoke = function(plr, ...) return Action.OnServerInvoke(plr, ...) end
local root = ws:FindFirstChild("StealABox")
check(root ~= nil, "map exists")

-- player joins
local player, char, hrp = makePlayer(1, "Tester")
S.Players.PlayerAdded:Fire(player)
for _ = 1, 40 do if player:GetAttribute("Loaded") then break end task.wait(0.05) end
check(player:GetAttribute("Loaded") == true, "player loaded")
local plotName = player:GetAttribute("PlotName")
check(plotName ~= nil, "player got a plot: " .. tostring(plotName))
local plot = root.Plots:FindFirstChild(plotName)
local origin = plot:FindFirstChild("PlotOrigin").CFrame
local function plotPos(u, w) return (origin * CF(u, 0.5, -w)).Position end
local r = invoke(player, "GetData")
check(r.ok and r.data and r.data.Cash == 0, "GetData returns a fresh profile")
local prof = r.data

-- steal a box: walk to it, trigger its prompt
local boxes = root:FindFirstChild("ActiveBoxes"):GetChildren()
check(#boxes > 0, "boxes spawned: " .. #boxes)
local target
for _, b in ipairs(boxes) do if b:GetAttribute("BoxId") and Config == nil then target = b break end end
target = target or boxes[1]
hrp.CFrame = CF(target.Position + V3(0, 0, 4))
local prompt = target:FindFirstChildOfClass("ProximityPrompt")
H.signalFor(prompt, "Triggered"):Fire(player)
check(player:GetAttribute("Carrying") ~= nil, "carrying a box: " .. tostring(player:GetAttribute("CarryLabel")))
check(player:GetAttribute("Chased") == true, "the guardian woke up")
for _ = 1, 30 do H.step(1, 0.05) end
-- teleporting home with it is caught by the anti-teleport check
hrp.CFrame = CF(plotPos(0, 30) + V3(0, 3, 0))
H.signalFor(remotes:FindFirstChild("PlaceBox"), "OnServerEvent"):Fire(player, plotPos(0, 30))
check(player:GetAttribute("Carrying") == nil, "teleporting with a box drops it")
-- second try: walk home at a believable speed
boxes = root:FindFirstChild("ActiveBoxes"):GetChildren()
target = nil
for _, b in ipairs(boxes) do
	if b:FindFirstChildOfClass("ProximityPrompt") and (not target or b.Position.Z > target.Position.Z) then target = b end
end
print("nearest box at z=" .. target.Position.Z)
hrp.CFrame = CF(target.Position + V3(0, 0, 4))
H.signalFor(target:FindFirstChildOfClass("ProximityPrompt"), "Triggered"):Fire(player)
check(player:GetAttribute("Carrying") ~= nil, "picked up another box")
H.maxWait = 1
task.wait(5.5)
H.maxWait = 0.05
hrp.CFrame = CF(plotPos(0, 30) + V3(0, 3, 0))
H.signalFor(remotes:FindFirstChild("PlaceBox"), "OnServerEvent"):Fire(player, plotPos(0, 30))
check(player:GetAttribute("Carrying") == nil, "placed the box on the plot")
prof = invoke(player, "GetData").data
check(next(prof.Unboxing) ~= nil, "box is unboxing")
check((prof.Stolen or 0) == 1, "stolen counter = 1")

-- Studio test purchase: Instant Unbox -> open it
task.wait(0.15)
r = invoke(player, "BuyProduct", "SkipUnbox")
check(r.ok, "Instant Unbox (Studio test) works: " .. tostring(r.msg))
local ub = plot:FindFirstChild("Unboxing"):GetChildren()[1]
check(ub and ub:FindFirstChildOfClass("ProximityPrompt") ~= nil, "box has an Open! prompt")
H.signalFor(ub:FindFirstChildOfClass("ProximityPrompt"), "Triggered"):Fire(player)
task.wait(2)
prof = invoke(player, "GetData").data
check(#prof.Items == 1 and prof.Items[1].stand == 1, "item unboxed and put on the shelf")
check(prof.Items[1] and Config == nil, "item: " .. tostring(prof.Items[1] and prof.Items[1].id))

-- shoppers pay
local income = player:GetAttribute("Income") or 0
check(income > 0, "income attribute: " .. income)
for _ = 1, 400 do H.step(1, 0.1) end
task.wait(0.3)
prof = invoke(player, "GetData").data
check((player:GetAttribute("Cash") or 0) > 0, "shoppers paid: $" .. tostring(player:GetAttribute("Cash")))
local custFolder = root:FindFirstChild("Customers")
check(custFolder ~= nil, "customers folder exists (" .. (custFolder and #custFolder:GetChildren() or 0) .. " shoppers)")

-- codes
check(invoke(player, "RedeemCode", "release").ok, "code RELEASE works (lowercase)")
task.wait(1.1)
check(not invoke(player, "RedeemCode", "RELEASE").ok, "code can't be used twice")
task.wait(1.1)
check(not invoke(player, "RedeemCode", "NOPE").ok, "unknown code rejected")
task.wait(1.1)
check(invoke(player, "RedeemCode", "  stealabox ").ok, "code STEALABOX gives a box")
task.wait(1.1)
check(invoke(player, "RedeemCode", "ZOOM").ok, "code ZOOM gives speed")

-- daily
task.wait(0.15)
r = invoke(player, "ClaimDaily")
check(r.ok, "daily claim: " .. tostring(r.msg))
task.wait(0.15)
check(not invoke(player, "ClaimDaily").ok, "daily can't be claimed twice")

-- trails
task.wait(0.15)
r = invoke(player, "BuyUpgrade", "Dust")
check(r.ok, "bought the Dust trail: " .. tostring(r.msg))
task.wait(0.15)
check(not invoke(player, "BuyUpgrade", "VIP").ok, "VIP trail needs the pass")

-- game passes (Studio test grants)
for _, key in ipairs({"VIP", "DoubleCash", "FastUnbox", "Lucky", "BigBase"}) do
	task.wait(0.15)
	r = invoke(player, "BuyPass", key)
	check(r.ok and player:GetAttribute("Pass_" .. key) == true, "pass " .. key .. " granted")
end
task.wait(0.15)
check(not invoke(player, "BuyPass", "VIP").ok, "can't buy a pass twice")
prof = invoke(player, "GetData").data
check(prof.Trail == "VIP", "VIP auto-equips the VIP trail")
task.wait(0.15)
check(invoke(player, "BuyUpgrade", "VIP").ok, "VIP trail can be equipped with the pass")
local income2 = player:GetAttribute("Income") or 0
H.step(2)
task.wait(1.1)
income2 = player:GetAttribute("Income") or 0
check(income2 >= income * 2.9, "VIP + 2x cash multiply income: " .. income .. " -> " .. income2)

-- products (Studio test grants)
for _, key in ipairs({"CashM", "LuckyBox", "ServerLuck"}) do -- (speed boosts have real ids now: Studio shows the real purchase)
	task.wait(0.15)
	r = invoke(player, "BuyProduct", key)
	check(r.ok, "product " .. key .. ": " .. tostring(r.msg))
end
task.wait(0.15)
check(not invoke(player, "BuyProduct", "Speed5").ok, "speed tiers in order")
check((game:GetService("ReplicatedStorage"):GetAttribute("ServerLuckUntil") or 0) > 0, "server luck is on")

-- real receipts (IDs patched in): granted once, never twice
local cashBefore = player:GetAttribute("Cash")
local decision = S.MarketplaceService.ProcessReceipt({PlayerId = 1, ProductId = 1111, PurchaseId = "receipt-1", CurrencySpent = 25})
check(decision == Enum.ProductPurchaseDecision.PurchaseGranted, "receipt granted")
local cashAfter = player:GetAttribute("Cash")
check(cashAfter > cashBefore, "receipt gave cash: " .. cashBefore .. " -> " .. cashAfter)
decision = S.MarketplaceService.ProcessReceipt({PlayerId = 1, ProductId = 1111, PurchaseId = "receipt-1", CurrencySpent = 25})
check(decision == Enum.ProductPurchaseDecision.PurchaseGranted and player:GetAttribute("Cash") == cashAfter, "same receipt is not granted twice")
decision = S.MarketplaceService.ProcessReceipt({PlayerId = 1, ProductId = 9999, PurchaseId = "receipt-2"})
check(decision == Enum.ProductPurchaseDecision.NotProcessedYet, "unknown product is not granted")
decision = S.MarketplaceService.ProcessReceipt({PlayerId = 77, ProductId = 1111, PurchaseId = "receipt-3"})
check(decision == Enum.ProductPurchaseDecision.NotProcessedYet, "player not in server: try later")
decision = S.MarketplaceService.ProcessReceipt({PlayerId = 1, ProductId = 2222, PurchaseId = "receipt-4"})
check(decision == Enum.ProductPurchaseDecision.PurchaseGranted, "lucky box receipt granted")

-- items
task.wait(0.15)
check(invoke(player, "EquipAll").ok, "Equip Best")
prof = invoke(player, "GetData").data
task.wait(0.15)
r = invoke(player, "RemoveItem", 1, prof.Items[1].id)
check(r.ok, "take an item back: " .. tostring(r.msg))
task.wait(0.15)
r = invoke(player, "PlaceItem", 1, prof.Items[1].id)
check(r.ok, "put it back on the shelf")
task.wait(0.15)
check(not invoke(player, "SellItem", 1, "WrongId").ok, "selling checks the item id")

-- treadmill + kiosk upgrades through their prompts
local console = plot:FindFirstChild("TreadConsole", true)
task.wait(0.15) -- (actions closer than 0.12s apart are ignored as double clicks)
invoke(player, "UpgradeTreadmill")
task.wait(0.15)
check(invoke(player, "UpgradeShoppers").ok, "shop upgraded from the UI")
prof = invoke(player, "GetData").data
check(prof.Treadmill == 2 and prof.Customers == 2, "treadmill + kiosk upgraded")
task.wait(0.15)
local pay = invoke(player, "UpgradePayout")
task.wait(0.15)
local unb = invoke(player, "UpgradeUnbox")
prof = invoke(player, "GetData").data
check(pay.ok and unb.ok and prof.PayoutLevel == 2 and prof.UnboxLevel == 2, "payouts + unbox speed upgraded: " .. tostring(pay.msg) .. " / " .. tostring(unb.msg))
-- mines: every player gets them (the fake player gets a Backpack first), and placing one works
do
	local bp = H.newInstance("Backpack")
	bp.Parent = player
	task.wait(2.3)
	local tool = bp:FindFirstChild("Mines")
	check(tool ~= nil and tool:FindFirstChild("Handle") ~= nil, "got mines: " .. tostring(tool and tool.ToolTip))
	if tool then H.signalFor(tool, "Activated"):Fire() end
	task.wait(0.1)
	local folder = root:FindFirstChild("Mines")
	check(folder ~= nil and #folder:GetChildren() == 1, "placed a mine")
end
-- treadmill earns speed
local belt = plot:FindFirstChild("TreadBelt", true)
hrp.CFrame = belt.CFrame + V3(0, 3, 0)
local sp0 = player:GetAttribute("SpeedPoints")
task.wait(1)
check((player:GetAttribute("SpeedPoints") or 0) > sp0, "treadmill gives speed: " .. sp0 .. " -> " .. tostring(player:GetAttribute("SpeedPoints")))

-- index rewards: area 1 can't be claimed until all its items are found, then only once
local Config = H.requireModule(game:GetService("ReplicatedStorage"):FindFirstChild("StealABoxConfig"))
check(invoke(player, "Rebirth").ok ~= true, "rebirth is gone")
check(invoke(player, "GetData").data.Achievements.FirstSteal == true, "secret achievement: First Heist")
task.wait(0.15)
local standsBefore = player:GetAttribute("Stands")
prof = invoke(player, "GetData").data
prof.Cash = prof.Cash + Config.StandCost(standsBefore)
r = invoke(player, "BuyStand")
check(r.ok and player:GetAttribute("Stands") == standsBefore + 1, "bought a shelf spot: " .. tostring(r.msg))
task.wait(0.15)
check(invoke(player, "OpenAll").opened ~= nil, "open all answers")
task.wait(0.15)
local q1 = prof.Quests and prof.Quests.List and prof.Quests.List[1]
check(q1 ~= nil, "daily quests exist")
if q1 then
	q1.progress = q1.goal
	local c0 = prof.Cash
	r = invoke(player, "ClaimQuest", 1)
	check(r.ok and prof.Cash > c0, "claimed a quest: " .. tostring(r.msg))
	task.wait(0.15)
	check(not invoke(player, "ClaimQuest", 1).ok, "a quest pays only once")
end
prof = invoke(player, "GetData").data
local area1Items = Config.AreaItems[1]
prof.ItemsFound[area1Items[#area1Items][1]] = nil
task.wait(0.15)
r = invoke(player, "ClaimIndex", 1)
check(not r.ok, "index reward locked until the area is complete: " .. tostring(r.msg))
for _, it in ipairs(area1Items) do prof.ItemsFound[it[1]] = 1 end
local cashBefore = prof.Cash
local incomeBefore = player:GetAttribute("Income") or 0
task.wait(0.15)
r = invoke(player, "ClaimIndex", 1)
check(r.ok and prof.Cash >= cashBefore + Config.IndexCash(1) and prof.IndexClaimed["1"] == true, "index reward claimed: " .. tostring(r.msg))
check((player:GetAttribute("Income") or 0) >= incomeBefore, "index bonus keeps/raises income")
task.wait(0.15)
check(not invoke(player, "ClaimIndex", 1).ok, "index reward only once")
task.wait(0.15)
check(invoke(player, "SetSetting", "Effects", false).ok and invoke(player, "GetData").data.Settings.Effects == false, "settings are stored")
task.wait(0.15)
check(invoke(player, "Warehouse").ok and invoke(player, "Home").ok ~= nil, "teleports")
task.wait(0.15)
task.wait(0.15)

-- guardian: grab a box next to the area 1 guard and let him catch you
do
	local guard = root:FindFirstChild("Guards"):FindFirstChild("Guardian1")
	local area1
	for _, b in ipairs(root:FindFirstChild("ActiveBoxes"):GetChildren()) do
		if b:FindFirstChildOfClass("ProximityPrompt") and b.Position.Z > Config.AreaEndZ(1) and b.Position.Z < Config.AreaStartZ(1) then area1 = b break end
	end
	check(area1 ~= nil, "found a box in area 1")
	hrp.CFrame = CF(area1.Position + V3(0, 0, 3))
	H.signalFor(area1:FindFirstChildOfClass("ProximityPrompt"), "Triggered"):Fire(player)
	check(player:GetAttribute("Carrying") ~= nil, "carrying an area 1 box")
	local flung = false
	H.onFireClient = function(name, plr, ...)
		if name == "Fling" then flung = true end
	end
	task.wait(1)
	local gp = guard:GetPivot().Position
	hrp.CFrame = CF(gp.X, 3, gp.Z + 1.5)
	for _ = 1, 40 do H.step(1, 0.05) if flung then break end end
	check(flung, "the guardian caught + flung the player")
	check(player:GetAttribute("Carrying") == nil, "a flung player drops the box")
	H.onFireClient = nil
	task.wait(2.5)
	-- drop with G
	for _, b in ipairs(root:FindFirstChild("ActiveBoxes"):GetChildren()) do
		if b:FindFirstChildOfClass("ProximityPrompt") and b.Position.Z > Config.AreaEndZ(1) and b.Position.Z < Config.AreaStartZ(1) then area1 = b break end
	end
	hrp.CFrame = CF(area1.Position + V3(0, 0, 3))
	H.signalFor(area1:FindFirstChildOfClass("ProximityPrompt"), "Triggered"):Fire(player)
	H.signalFor(remotes:FindFirstChild("Drop"), "OnServerEvent"):Fire(player)
	check(player:GetAttribute("Carrying") == nil, "Drop puts the box down")
end

-- leave -> saved (session released)
local store = S.DataStoreService.stores["StealABox_v5"]
S.Players.PlayerRemoving:Fire(player)
player.Parent = nil
task.wait(0.3)
local saved = store.data["player_1"]
check(saved ~= nil and saved.SessionActive == false and saved.SessionJob == "server-A", "saved on leave, session released")
check(saved and saved.IndexClaimed and saved.IndexClaimed["1"] == true and saved.Receipts["receipt-1"] ~= nil, "save has index rewards + receipts")

-- come back 2 hours later: offline earnings
saved.LastOnline = os.time() - 7200
local player2 = makePlayer(1, "Tester")
S.Players.PlayerAdded:Fire(player2)
for _ = 1, 60 do if player2:GetAttribute("Loaded") then break end task.wait(0.05) end
check(player2:GetAttribute("Loaded") == true, "rejoined")
check((player2:GetAttribute("OfflineEarned") or 0) > 0, "offline earnings: $" .. tostring(player2:GetAttribute("OfflineEarned")))
local prof2 = invoke(player2, "GetData").data
check(prof2.IndexClaimed["1"] == true and #prof2.Items > 0 and prof2.Codes.RELEASE == true, "progress came back")
check(store.data["player_1"].SessionActive == true, "save is claimed by this server again")

-- another server that still has the save open: we must not load stale data
S.Players.PlayerRemoving:Fire(player2)
player2.Parent = nil
task.wait(0.3)
store.data["player_7"] = {Cash = 999, SessionActive = true, SessionJob = "server-B", SessionTime = os.time()}
local player3 = makePlayer(7, "Other")
S.Players.PlayerAdded:Fire(player3)
for _ = 1, 100 do if player3:GetAttribute("Loaded") then break end task.wait(0.05) end
check(player3:GetAttribute("Loaded") == true, "loads after the other server's claim times out (or it finishes)")
check(store.data["player_7"].SessionJob == "server-A", "took over the dead session")

print(("server calls: %d, log lines: %d"):format(#H.calls, #H.log))
for _, l in ipairs(H.log) do if l:find("warn") then print(l) end end
if #H.errors > 0 then
	print("ERRORS (" .. #H.errors .. "):")
	local seen = {}
	for _, e in ipairs(H.errors) do
		if not seen[e] then seen[e] = true print("  " .. e) end
	end
	process.exit(1)
end
print("SERVER SMOKE TEST PASSED")
process.exit(0)
