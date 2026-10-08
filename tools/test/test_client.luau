-- Smoke test: build the map, then run the CLIENT in a fake engine and click through everything.
local task = require("@lune/task")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local H = require("./env")
local Enum = roblox.Enum
task.delay(150, function()
	print("WATCHDOG: test took too long")
	for _, e in ipairs(H.errors) do print("  " .. e) end
	process.exit(2)
end)

local placePath = process.args[1]
local realGame = roblox.deserializePlace(fs.readFile(placePath))
local game = H.wrap(realGame)
H.game = game
H.isClient = true
local S = H.makeServices(game)
H.services = S

-- workspace + camera
local ws = game:GetService("Workspace")
H.workspace = ws
local cam = H.newInstance("Camera")
cam.Parent = ws
H.setValue(ws, "CurrentCamera", cam)

-- game:GetService -> fakes for engine services, real ones for containers
local players = H.newInstance("Folder")
players.Name = "Players"
local localPlayer = H.newInstance("Folder")
localPlayer.Name = "TestPlayer"
H.setValue(localPlayer, "UserId", 1)
H.setValue(localPlayer, "DisplayName", "Tester")
localPlayer.Parent = players
local pg = H.newInstance("Folder")
pg.Name = "PlayerGui"
pg.Parent = localPlayer
local ps = H.newInstance("Folder")
ps.Name = "PlayerScripts"
ps.Parent = localPlayer
S.Players = {LocalPlayer = localPlayer, PlayerAdded = H.newSignal("PlayerAdded"), PlayerRemoving = H.newSignal("PlayerRemoving")}
function S.Players:GetPlayers() return {localPlayer} end
function S.Players:GetPlayerByUserId(id) return (id == 1) and localPlayer or nil end
H.setOverrides(game, {
	GetService = function(self, name)
		if S[name] then return S[name] end
		return H.wrap(realGame:GetService(name))
	end,
	JobId = "test-job",
})

-- 1) build the map (the server's map script)
local mapScript = game:GetService("ServerScriptService"):FindFirstChild("StealABoxMap")
H.runScript(mapScript)
task.wait(0.5)
assert(ws:FindFirstChild("StealABox"), "map was not built")
print("map built: " .. #ws:FindFirstChild("StealABox"):GetDescendants() .. " instances")

-- a character for the player
local char = H.newInstance("Model")
char.Name = "TestPlayer"
local hrp = H.newInstance("Part")
hrp.Name = "HumanoidRootPart"
hrp.CFrame = roblox.CFrame.new(0, 3, 150)
hrp.Parent = char
local hum = H.newInstance("Humanoid")
hum.Parent = char
char.Parent = ws
H.setValue(localPlayer, "Character", char)

-- fake server answers
local profile = {Cash = 123456, Stolen = 3, Boxes = {OldBox = 2, HayBox = 1}, Mutations = {Normal = 3}, ItemsFound = {OldSpoon = 2, Carrot = 1},
	Items = {{id = "OldSpoon", mutation = "Normal", size = "Normal", stand = 1}, {id = "Carrot", mutation = "Gold", size = "Big"},
		{id = "GoldenEgg", mutation = "Rainbow", size = "Giant", stand = 2}},
	Unboxing = {["1"] = {id = "OldBox", mutation = "Normal", size = "Normal", readyAt = 0, duration = 10, u = 0, w = 30, rot = 0}},
	Treadmill = 1, SpeedPoints = 150, TutorialDone = false, Trails = {Dust = true}, Trail = "Dust", Customers = 2, SpeedBoost = 2,
	Receipts = {}, IndexClaimed = {["2"] = true}, Daily = {Streak = 2, Last = math.floor((os.clock() + 1.7e9) / 86400) - 1}, Codes = {}, Settings = {Sfx = true}}
H.onInvokeServer = function(action, arg, extra)
	if action == "GetData" then return {ok = true, data = profile} end
	return {ok = true, msg = "server says ok: " .. tostring(action)}
end

-- 2) run the client
local client = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts"):FindFirstChild("StealABoxClient")
H.runScript(client)
task.wait(1)

-- server pushes
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("StealABoxRemotes")
local function fireClient(name, ...) H.signalFor(remotes:FindFirstChild(name), "OnClientEvent"):Fire(...) end
fireClient("Sync", profile)
localPlayer:SetAttribute("Cash", 200000)
localPlayer:SetAttribute("Income", 1234)
localPlayer:SetAttribute("SpeedPoints", 4567)
localPlayer:SetAttribute("PlotName", "Plot1")
localPlayer:SetAttribute("GiftStart", os.clock() + 1.7e9 - 400)
localPlayer:SetAttribute("GiftClaimed", "1")
localPlayer:SetAttribute("Carrying", "OldBox")
localPlayer:SetAttribute("CarryLabel", "Gold Big Old Box")
localPlayer:SetAttribute("Chased", true)
localPlayer:SetAttribute("OfflineEarned", 5000)
localPlayer:SetAttribute("OfflineAway", 3600)
localPlayer:SetAttribute("SpeedBoost", 2)
localPlayer:SetAttribute("Pass_VIP", true)
fireClient("Notify", "Hello from the server!", roblox.Color3.new(1, 1, 0))
fireClient("Notify", "A really long notification message that should wrap onto a second line instead of running off the edge of the screen and over other text, yes really.")
for i = 1, 6 do fireClient("Notify", "Spam " .. i) end
H.step(10)

-- FX events
local box = ws.StealABox:FindFirstChild("BoxSpawns"):GetChildren()[1]
fireClient("FX", "Spawn", roblox.Vector3.new(0, 3, -20), 3)
fireClient("FX", "Grab", roblox.Vector3.new(0, 3, -20), 3)
fireClient("FX", "Stash", roblox.Vector3.new(0, 3, -20), 4)
fireClient("FX", "Bonk", roblox.Vector3.new(0, 3, -20), 2)
fireClient("FX", "Sale", roblox.Vector3.new(0, 3, -20), 1)
fireClient("FX", "Ready", roblox.Vector3.new(0, 3, -20), 1)
fireClient("FX", "LevelUp", roblox.Vector3.new(0, 3, -20), 1)
fireClient("FX", "Wake", roblox.Vector3.new(0, 3, -20), 1.5)
-- an unboxing box + opening animation + 3D reveal
local plot = ws.StealABox.Plots:FindFirstChild("Plot1")
plot:SetAttribute("Owner", 1)
local unboxF = H.newInstance("Folder")
unboxF.Name = "Unboxing"
unboxF.Parent = plot
local ub = H.newInstance("Part")
ub.Name = "UnboxBox1"
ub.Size = roblox.Vector3.new(4, 4, 4)
ub.CFrame = roblox.CFrame.new(10, 3, 40)
ub:SetAttribute("ReadyAt", 0)
ub:SetAttribute("Duration", 10)
ub:SetAttribute("Owner", 1)
ub:SetAttribute("BaseCF", ub.CFrame)
ub.Parent = unboxF
S.CollectionService:AddTag(ub, "UnboxingBox")
local timer = H.newInstance("BillboardGui")
timer.Name = "Timer"
timer.Parent = ub
local nameL = H.newInstance("TextLabel")
nameL.Name = "Name"
nameL.Parent = timer
local bar = H.newInstance("Frame")
bar.Name = "Bar"
bar.Parent = timer
local fill = H.newInstance("Frame")
fill.Name = "Fill"
fill.Parent = bar
local tl = H.newInstance("TextLabel")
tl.Name = "Time"
tl.Parent = bar
fireClient("FX", "Opening", ub.Position, 4, ub, 2)
for _ = 1, 30 do H.step(1, 0.1) end
fireClient("FX", "Reveal3D", ub.Position, 4, {item = {id = "AntiqueVase", mutation = "Galaxy", size = "Huge"}, target = roblox.CFrame.new(0, 5, 80), targetScale = 1.2, owner = 1})
fireClient("Reveal", {id = "AntiqueVase", mutation = "Galaxy", size = "Huge"}, true)
for _ = 1, 30 do H.step(1, 0.1) end
-- shopper bubble + sale pop
local think = H.newInstance("BillboardGui")
think.Name = "Think"
think:SetAttribute("Item", "Carrot")
think.Parent = ub
S.CollectionService:AddTag(think, "ItemBubble")
local pop = H.newInstance("BillboardGui")
pop.Name = "PopText"
local popL = H.newInstance("TextLabel")
popL.Name = "Label"
popL.Parent = pop
pop.Parent = ub
S.CollectionService:AddTag(pop, "PopText")
local tag = H.newInstance("BillboardGui")
tag.Name = "ItemTag"
tag.Parent = plot:FindFirstChild("Stand1")
S.CollectionService:AddTag(tag, "ShelfTag")
hrp.CFrame = plot:FindFirstChild("Stand1").CFrame
H.step(20, 0.05)
task.wait(0.5)
-- shop purchase granted
fireClient("ShopEvent", "Granted", {title = "2x Cash", msg = "Thanks"})
-- fling
H.signalFor(remotes:FindFirstChild("Fling"), "OnClientEvent"):Fire(roblox.Vector3.new(0, 50, 80), 0.3, "Sleepy Watchman")
H.step(10)

-- 3) open every window and press every button
local Client = client
local UIm = H.requireModule(Client:FindFirstChild("UI"))
local opened = 0
for _, name in ipairs({"Shop", "Items", "Index", "Trails", "Gifts", "Daily", "Codes", "Settings", "Welcome"}) do
	UIm.open(name)
	opened += 1
	H.step(3)
	local win = UIm.getWindow(name)
	if win and win.setTab then
		for key in pairs(win.pages) do
			win.setTab(key)
			H.step(2)
		end
	end
end
UIm.close()
print("opened " .. opened .. " windows")
-- press every button once (twice for "tap again to confirm" buttons)
local pressed = 0
for _, p in pairs(H.allProxies()) do
	local okc, cls = pcall(function() return p.ClassName end)
	if okc and (cls == "TextButton" or cls == "ImageButton") then
		local okp, inGui = pcall(function() return p:IsDescendantOf(H.unwrap(pg)) end)
		if okp then
			H.signalFor(p, "MouseEnter"):Fire()
			H.signalFor(p, "MouseButton1Down"):Fire()
			H.signalFor(p, "MouseButton1Up"):Fire()
			H.signalFor(p, "Activated"):Fire()
			H.signalFor(p, "MouseLeave"):Fire()
			pressed += 1
		end
	end
end
H.step(5)
print("pressed " .. pressed .. " buttons")
-- settings toggles + inputs
S.UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.G, UserInputType = Enum.UserInputType.Keyboard, Position = roblox.Vector3.new()}, false)
S.UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1, Position = roblox.Vector3.new(640, 360, 0)}, false)
localPlayer:SetAttribute("Carrying", nil)
localPlayer:SetAttribute("Chased", nil)
localPlayer:SetAttribute("OnTreadmill", true)
localPlayer:SetAttribute("TreadRate", 55)
H.step(10)
-- walk into the warehouse: the area banner
hrp.CFrame = roblox.CFrame.new(0, 3, -30)
task.wait(0.6)
H.step(5)
hrp.CFrame = roblox.CFrame.new(0, 3, -110)
task.wait(0.6)
H.step(5)
task.wait(2)
H.step(5)

-- report
print(("calls to server: %d"):format(#H.calls))
for _, l in ipairs(H.log) do print(l) end
if #H.errors > 0 then
	print("ERRORS (" .. #H.errors .. "):")
	local seen = {}
	for _, e in ipairs(H.errors) do
		if not seen[e] then
			seen[e] = true
			print("  " .. e)
		end
	end
	process.exit(1)
end
print("CLIENT SMOKE TEST PASSED")
process.exit(0)
