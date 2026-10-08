--[[ STEAL A BOX - Client (starts every part of the UI and the world effects)
     The code lives in the ModuleScripts inside this script:
       UI          the look of everything: colours, buttons, windows, icons, sounds
       Hud         what's always on screen (cash, speed, menu, timers, notifications...)
       Windows     Items, Index, Trails, Gifts, Daily, Codes, Settings
       ShopWindow  the Robux shop
       Tutorial    the step-by-step tutorial for new players
       WorldFX     everything that happens in the 3D world on your screen ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("StealABoxConfig"))
local Shop = require(ReplicatedStorage:WaitForChild("StealABoxShop"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotesFolder = ReplicatedStorage:WaitForChild("StealABoxRemotes")

local UI = require(script:WaitForChild("UI"))
local Hud = require(script:WaitForChild("Hud"))
local Windows = require(script:WaitForChild("Windows"))
local ShopWindow = require(script:WaitForChild("ShopWindow"))
local Tutorial = require(script:WaitForChild("Tutorial"))
local WorldFX = require(script:WaitForChild("WorldFX"))

------------------------------------------------------------------
-- SHARED CONTEXT: everything the parts of the UI need from each other
------------------------------------------------------------------
local ctx = {
	UI = UI, Config = Config, Shop = Shop, player = player,
	data = nil,        -- your save, synced from the server
	settings = {Sfx = true, Effects = true, ShelfTags = true},
	prices = {},       -- real Robux prices once Roblox tells us
	remotes = {},
}
for _, name in ipairs({"Notify", "Drop", "Sync", "Action", "Fling", "FX", "Reveal", "PlaceBox", "ShopEvent"}) do
	ctx.remotes[name] = remotesFolder:WaitForChild(name)
end

function ctx.invoke(action, arg, extra)
	local ok, result = pcall(function() return ctx.remotes.Action:InvokeServer(action, arg, extra) end)
	if ok and type(result) == "table" then return result end
	return {ok = false, msg = "Something went wrong - try again."}
end

-- the price to show for a shop item: Roblox's real price if it's loaded, else the config's
function ctx.price(key, fallback)
	return ctx.prices[key] or fallback or 0
end

local dataListeners, cashListeners = {}, {}
function ctx.onData(fn) table.insert(dataListeners, fn) end
function ctx.onCash(fn) table.insert(cashListeners, fn) end
local function fire(list)
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn)
		if not ok then warn("[Steal a Box] UI update failed: " .. tostring(err)) end
	end
end

function ctx.setSetting(key, value)
	ctx.settings[key] = value
	UI.SFX.enabled = ctx.settings.Sfx ~= false
	ctx.invoke("SetSetting", key, value)
end

------------------------------------------------------------------
-- BUILD THE UI
------------------------------------------------------------------
UI.initRoot(playerGui)
Hud.init(ctx)
Windows.init(ctx)
ShopWindow.init(ctx)
Tutorial.init(ctx)
task.spawn(WorldFX.init, ctx) -- waits for the map, so it starts on its own

ctx.remotes.Notify.OnClientEvent:Connect(function(text, color)
	ctx.notify(text, typeof(color) == "Color3" and color or nil)
end)

------------------------------------------------------------------
-- DATA SYNC
------------------------------------------------------------------
local function onData(newData)
	if type(newData) ~= "table" then return end
	local first = ctx.data == nil
	ctx.data = newData
	-- your saved settings (only the first time: after that the switches are the truth)
	if first and type(newData.Settings) == "table" then
		for k, v in pairs(newData.Settings) do
			if type(v) == "boolean" then ctx.settings[k] = v end
		end
		UI.SFX.enabled = ctx.settings.Sfx ~= false
		for k, sw in pairs(ctx.settingSwitches or {}) do
			if ctx.settings[k] ~= nil then sw.set(ctx.settings[k], true) end
		end
	end
	ctx.hud.onCash(newData.Cash)
	fire(dataListeners)
	fire(cashListeners)
end
ctx.remotes.Sync.OnClientEvent:Connect(onData)

-- cash changes all the time (every sale): the server only sends the number
player:GetAttributeChangedSignal("Cash"):Connect(function()
	local cash = player:GetAttribute("Cash")
	if not ctx.data or type(cash) ~= "number" then return end
	ctx.data.Cash = cash
	ctx.hud.onCash(cash)
	fire(cashListeners)
end)

task.spawn(function()
	-- ask for the save (the server may still be loading it: keep asking)
	for _ = 1, 30 do
		if ctx.data then return end
		local r = ctx.invoke("GetData")
		if r.ok and r.data and not ctx.data then
			onData(r.data)
			return
		end
		task.wait(1)
	end
end)
