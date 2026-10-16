-- Compile every script the way Roblox Studio does (no optimisation, full debug info): that build
-- uses MORE registers, so the 200-local limit hits sooner than with the default settings.
-- usage: lune run tools/check_compile.luau src/*.luau src/client/*.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local bad = 0
for _, path in ipairs(process.args) do
	local src = fs.readFile(path)
	for _, opt in ipairs({{optimizationLevel = 0, debugLevel = 2}, {optimizationLevel = 1, debugLevel = 1}, {optimizationLevel = 2, debugLevel = 0}}) do
		local ok, err = pcall(luau.compile, src, opt)
		if not ok then
			print("FAIL " .. path .. " (O" .. opt.optimizationLevel .. " g" .. opt.debugLevel .. "): " .. tostring(err))
			bad = bad + 1
			break
		end
	end
end
if bad == 0 then print("STRICT OK") end
process.exit(bad > 0 and 1 or 0)
