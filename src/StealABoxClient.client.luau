--[[ STEAL A BOX - Client (starts every part of the UI and the world effects)
     The code lives in the ModuleScripts inside this script:
       UI          the look of everything: colours, buttons, windows, icons, sounds
       Hud         what's always on screen (cash, speed, menu, timers, notifications...)
       Panels      the side panels on the right: Items (your shelf) and Unboxing
       Windows     Index, Quests, Trails, Gifts, Daily, Codes, Settings
       ShopWindow  the Robux shop
       Phone       the big phone on your base with mini games (Snake, Block Blast, Archery)
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
local Panels = require(script:WaitForChild("Panels"))
local Windows = require(script:WaitForChild("Windows"))
local ShopWindow = require(script:WaitForChild("ShopWindow"))
local Phone = require(script:WaitForChild("Phone"))
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

-- BACKGROUND MUSIC ("Morning Mood"), switched off with Settings > Music. Tries Config.MusicId, then
-- every id in Config.MusicIds, and keeps the first one that really loads (private audio fails to load).
local music = nil
task.spawn(function()
	local ids = {}
	if (tonumber(Config.MusicId) or 0) > 0 then table.insert(ids, tonumber(Config.MusicId)) end
	for _, id in ipairs(Config.MusicIds or {}) do
		if (tonumber(id) or 0) > 0 then table.insert(ids, tonumber(id)) end
	end
	local ContentProvider = game:GetService("ContentProvider")
	for _, id in ipairs(ids) do
		local s = Instance.new("Sound")
		s.Name = "StealABoxMusic"
		s.SoundId = "rbxassetid://" .. id
		s.Looped = true
		s.Volume = Config.MusicVolume or 0.3
		s.Parent = game:GetService("SoundService")
		local ok = false
		pcall(function()
			ContentProvider:PreloadAsync({s}, function(_, status)
				if status == Enum.AssetFetchStatus.Success then ok = true end
			end)
		end)
		-- (a sound that loaded has a length; give it a moment)
		local t0 = os.clock()
		while not (ok and s.TimeLength > 0) and os.clock() - t0 < 4 do
			if s.TimeLength > 0 then ok = true end
			task.wait(0.2)
		end
		if ok and s.TimeLength > 0 then
			music = s
			if ctx.settings.Music ~= false then s:Play() end
			return
		end
		s:Destroy()
	end
	if #ids > 0 then warn("[Steal a Box] none of the music ids could be loaded - paste a working one into Config.MusicId") end
end)
local function applyMusic()
	if not music then return end
	local on = ctx.settings.Music ~= false
	if on and not music.IsPlaying then music:Play() elseif not on and music.IsPlaying then music:Pause() end
end

function ctx.setSetting(key, value)
	ctx.settings[key] = value
	UI.SFX.enabled = ctx.settings.Sfx ~= false
	applyMusic()
	ctx.invoke("SetSetting", key, value)
end

------------------------------------------------------------------
-- BUILD THE UI
------------------------------------------------------------------
UI.initRoot(playerGui)
-- every part starts on its own: if one breaks, the rest still works (and the error shows on screen)
local initErrors = {}
local function start(name, mod)
	local ok, err = pcall(mod.init, ctx)
	if not ok then
		warn("[Steal a Box] " .. name .. " failed: " .. tostring(err))
		table.insert(initErrors, name .. ": " .. tostring(err))
	end
end
start("Hud", Hud)
start("Panels", Panels)
start("Windows", Windows)
start("ShopWindow", ShopWindow)
start("Phone", Phone)
start("Tutorial", Tutorial)
task.delay(3, function()
	for _, e in ipairs(initErrors) do
		if ctx.notify then ctx.notify("UI error - " .. e, Color3.fromRGB(255, 70, 70)) end
	end
end)
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
		applyMusic()
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
