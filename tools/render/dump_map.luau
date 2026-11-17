-- Builds the map (runs the real map script in the fake engine from tools/test) and writes every
-- visible part to a JSON file, so tools/render/view.html can draw it in a browser.
-- usage (from tools/test): lune run ../render/dump_map.luau ../../StealABox_v5.rbxl out.json
local task = require("@lune/task")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local H = require("../test/env")

local realGame = roblox.deserializePlace(fs.readFile(process.args[1]))
local game = H.wrap(realGame)
H.game = game
H.isClient = false
local S = H.makeServices(game)
H.services = S
local ws = game:GetService("Workspace")
H.workspace = ws
S.Players = {PlayerAdded = H.newSignal("PlayerAdded"), PlayerRemoving = H.newSignal("PlayerRemoving")}
function S.Players:GetPlayers() return {} end
H.setOverrides(game, {
	GetService = function(self, name)
		if S[name] then return S[name] end
		return H.wrap(realGame:GetService(name))
	end,
	JobId = "render",
})
H.runScript(game:GetService("ServerScriptService"):FindFirstChild("StealABoxMap"))
task.wait(1)

local out = {}
local function r3(n) return math.floor(n * 1000 + 0.5) / 1000 end
for _, d in ipairs(realGame:GetService("Workspace"):GetDescendants()) do
	if d:IsA("BasePart") and d.Transparency < 0.98 then
		local cf = d.CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		local shape = d.ClassName
		if d:IsA("Part") then shape = tostring(d.Shape.Name) end
		local mesh = d:FindFirstChildOfClass("SpecialMesh")
		local ms = nil
		if mesh then
			shape = "Mesh" .. tostring(mesh.MeshType.Name)
			ms = {r3(mesh.Scale.X), r3(mesh.Scale.Y), r3(mesh.Scale.Z)}
		end
		table.insert(out, {
			k = shape, s = {r3(d.Size.X), r3(d.Size.Y), r3(d.Size.Z)},
			p = {r3(x), r3(y), r3(z)}, r = {r3(r00), r3(r01), r3(r02), r3(r10), r3(r11), r3(r12), r3(r20), r3(r21), r3(r22)},
			c = {math.floor(d.Color.R * 255), math.floor(d.Color.G * 255), math.floor(d.Color.B * 255)},
			m = tostring(d.Material.Name), t = r3(d.Transparency), ms = ms, n = d.Name,
		})
	end
end
fs.writeFile(process.args[2], serde.encode("json", out))
print("parts: " .. #out)
process.exit(0)
