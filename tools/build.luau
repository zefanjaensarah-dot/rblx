--[[ Builds the Roblox place file from the scripts in src/.
     Run from the repository root with Lune (https://lune-org.github.io/docs):

         lune run tools/build.luau <input.rbxl> <output.rbxl>

     It opens the input place, puts every script from src/ where it belongs, regenerates
     ServerStorage > BuildMapInStudio from the map script, and saves the output place. ]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance

local input, output = process.args[1], process.args[2]
assert(input and output, "usage: lune run tools/build.luau <input.rbxl> <output.rbxl>")

local game = roblox.deserializePlace(fs.readFile(input))
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local function read(path)
	local src = fs.readFile(path)
	assert(#src > 0, path .. " is empty")
	return src
end

-- put a script with this source at parent/name (creating or replacing it)
local function script(parent, name, className, source)
	local s = parent:FindFirstChild(name)
	if s and s.ClassName ~= className then
		s:Destroy()
		s = nil
	end
	if not s then
		s = Instance.new(className)
		s.Name = name
		s.Parent = parent
	end
	s.Source = source
	return s
end

-- shared modules
script(RS, "StealABoxConfig", "ModuleScript", read("src/StealABoxConfig.luau"))
script(RS, "StealABoxShop", "ModuleScript", read("src/StealABoxShop.luau"))

-- remotes (the server also creates any that are missing, this just keeps the place tidy)
local remotes = RS:FindFirstChild("StealABoxRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "StealABoxRemotes"
	remotes.Parent = RS
end
for _, spec in { {"Notify", "RemoteEvent"}, {"Drop", "RemoteEvent"}, {"Sync", "RemoteEvent"}, {"Fling", "RemoteEvent"}, {"FX", "RemoteEvent"},
	{"Reveal", "RemoteEvent"}, {"PlaceBox", "RemoteEvent"}, {"ShopEvent", "RemoteEvent"}, {"Action", "RemoteFunction"} } do
	if not remotes:FindFirstChild(spec[1]) then
		local r = Instance.new(spec[2])
		r.Name = spec[1]
		r.Parent = remotes
	end
end

-- server
script(SSS, "StealABoxServer", "Script", read("src/StealABoxServer.server.luau"))
local mapSource = read("src/StealABoxMap.server.luau")
script(SSS, "StealABoxMap", "Script", mapSource)

-- client: the LocalScript + its modules
local client = script(SPS, "StealABoxClient", "LocalScript", read("src/StealABoxClient.client.luau"))
for _, name in { "UI", "Hud", "Panels", "Windows", "ShopWindow", "Tutorial", "WorldFX" } do
	script(client, name, "ModuleScript", read("src/client/" .. name .. ".luau"))
end

-- ServerStorage > BuildMapInStudio: the same map code, for building the map in Studio
-- (paste its source into the command bar). It only builds the MAP - it never touches scripts.
local MAP_HEAD = [[local RS = game:GetService("ReplicatedStorage")
if workspace:FindFirstChild("StealABox") then return end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") or (d:IsA("BasePart") and d.Name == "Baseplate") then d:Destroy() end
end]]
local headStart, headEnd = string.find(mapSource, MAP_HEAD, 1, true)
assert(headStart, "map script header changed - update tools/build.luau")
local builder = [[--[[ ===========================================================
  STEAL A BOX - BUILD THE MAP IN STUDIO (optional)
  Copy this whole script, paste it into Roblox Studio's COMMAND BAR
  (View > Command Bar) and press Enter. The map appears in the Workspace,
  so you can look at it / edit it in Studio. Safe to run again: it deletes
  the old map first.
  This ONLY builds the map. Your scripts are never touched.
  (Without this, ServerScriptService > StealABoxMap builds the map when the game starts.)
=========================================================== ]] .. "]]" .. [[

local RS = game:GetService("ReplicatedStorage")
local oldMap = workspace:FindFirstChild("StealABox")
if oldMap then oldMap:Destroy() end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") or (d:IsA("BasePart") and d.Name == "Baseplate") then d:Destroy() end
end]] .. string.sub(mapSource, headEnd + 1) .. "\nreturn true\n"
script(SS, "BuildMapInStudio", "ModuleScript", builder)

fs.writeFile(output, roblox.serializePlace(game))
print("built " .. output)
