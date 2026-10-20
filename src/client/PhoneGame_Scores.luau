--[[ LEADERBOARD (phone app): the top 10 scores in every phone game - in THIS server, or of all
     time (Global). Pick a game at the top; your own best and rank are at the bottom. Your best
     scores are saved on the server, so they're still there next time you play. ]]

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("StealABoxConfig"))

local GOLD, SILVER, BRONZE = Color3.fromRGB(255, 205, 50), Color3.fromRGB(205, 215, 230), Color3.fromRGB(220, 140, 80)

local function build(env)
	local K = env.kit
	local UI, C, new, rgb, V2, S2, WHITE = K.UI, K.C, K.new, K.rgb, K.V2, K.S2, K.WHITE
	local frame, round, grad, text = K.frame, K.round, K.grad, K.text
	local pg = env.page("Scores", {title = "Leaderboard", color = rgb(230, 140, 20), bg0 = rgb(40, 34, 80), bg1 = rgb(14, 12, 30)})
	-- (no score / pause in the bar: this isn't a game)
	local bar = pg.frame:FindFirstChild("AppBar")
	if bar then
		for _, c in ipairs(bar:GetChildren()) do
			if c.Name == "Pause" or (c:IsA("Frame") and c.Name ~= "Back") then c.Visible = false end
		end
	end
	local content = pg.content
	local app = {}
	local games = env.games or {}
	local sel, scope = (games[1] and games[1].key) or "Snake", "server"
	local cache = {} -- [game] = {at = os.clock(), data = answer}
	local loading = 0

	-- GAME PICKER: 8 chips, 2 rows
	local chips = {}
	for i, g in ipairs(games) do
		local b = new("TextButton", {Text = "", AutoButtonColor = false, Position = S2(((i - 1) % 4) * 0.25 + 0.005, math.floor((i - 1) / 4) * 0.075), Size = S2(0.24, 0.068),
			BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4}, content)
		round(b, 10)
		grad(b, g.c0, g.c1, 90)
		local st = UI.stroke(b, 2, WHITE, 1)
		text(b, g.label, {Size = S2(0.92, 0.8), Position = S2(0.04, 0.1), Stroke = 1.5, MaxSize = 14, ZIndex = 5})
		UI.pressable(b)
		chips[g.key] = {b = b, st = st}
		b.Activated:Connect(function() app.pick(g.key) end)
	end
	-- THIS SERVER / GLOBAL
	local tabs = {}
	for i, t in ipairs({{"server", "This server"}, {"global", "Global"}}) do
		local b = new("TextButton", {Text = "", AutoButtonColor = false, Position = S2((i - 1) * 0.5 + 0.01, 0.165), Size = S2(0.48, 0.06), BackgroundColor3 = rgb(60, 54, 110),
			BorderSizePixel = 0, ZIndex = 4}, content)
		round(b, true)
		local l = text(b, t[2], {Size = S2(1, 0.8), Position = S2(0, 0.1), Stroke = 1.5, MaxSize = 16, ZIndex = 5})
		UI.pressable(b)
		tabs[t[1]] = {b = b, l = l}
		b.Activated:Connect(function()
			scope = t[1]
			app.draw()
		end)
	end
	-- THE LIST: 10 rows
	local list = frame(content, {Position = S2(0, 0.24), Size = S2(1, 0.64), BackgroundColor3 = rgb(10, 8, 24), BackgroundTransparency = 0.35, ZIndex = 3})
	round(list, 14)
	local rows = {}
	local avatars = {}
	for i = 1, 10 do
		local row = frame(list, {Position = S2(0.02, 0.01 + (i - 1) * 0.098), Size = S2(0.96, 0.09), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, ZIndex = 4})
		round(row, 8)
		local badge = frame(row, {AnchorPoint = V2(0, 0.5), Position = S2(0.015, 0.5), Size = S2(0.8, 0.8), BackgroundColor3 = rgb(90, 90, 120), ZIndex = 5})
		new("UIAspectRatioConstraint", {AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height}, badge)
		round(badge, true)
		local rank = text(badge, tostring(i), {Size = S2(1, 0.8), Position = S2(0, 0.1), Stroke = 1.5, MaxSize = 16, ZIndex = 6})
		local av = new("ImageLabel", {AnchorPoint = V2(0, 0.5), Position = S2(0.13, 0.5), Size = S2(0.8, 0.8), BackgroundColor3 = rgb(70, 70, 100), BorderSizePixel = 0, ZIndex = 5}, row)
		new("UIAspectRatioConstraint", {AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height}, av)
		round(av, true)
		local name = text(row, "", {Position = S2(0.25, 0.12), Size = S2(0.5, 0.76), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, MaxSize = 17, ZIndex = 5})
		local score = text(row, "", {Position = S2(0.72, 0.12), Size = S2(0.26, 0.76), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 1.5, MaxSize = 18,
			TextColor3 = rgb(255, 235, 140), ZIndex = 5})
		rows[i] = {f = row, badge = badge, rank = rank, av = av, name = name, score = score}
	end
	local empty = text(list, "", {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(0.86, 0.12), Stroke = 1.5, MaxSize = 18, ZIndex = 6})
	-- YOU
	local me = frame(content, {Position = S2(0, 0.9), Size = S2(1, 0.09), BackgroundColor3 = rgb(230, 140, 20), ZIndex = 3})
	round(me, 12)
	grad(me, WHITE, rgb(200, 200, 210), 90)
	local meT = text(me, "", {Size = S2(0.94, 0.7), Position = S2(0.03, 0.15), Stroke = 2, MaxSize = 18, ZIndex = 4})

	local function avatarOf(id, img)
		if avatars[id] then
			img.Image = avatars[id]
			return
		end
		img.Image = ""
		task.spawn(function()
			local ok, url = pcall(function() return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
			if ok and url then
				avatars[id] = url
				if img:GetAttribute("For") == id then img.Image = url end
			end
		end)
	end
	local function label(key)
		for _, g in ipairs(games) do if g.key == key then return g.label end end
		return key
	end

	function app.draw()
		for k, c in pairs(chips) do
			local on = k == sel
			c.st.Transparency = on and 0 or 1
			c.b.BackgroundTransparency = on and 0 or 0.45
		end
		for k, t in pairs(tabs) do
			t.b.BackgroundColor3 = (k == scope) and rgb(230, 140, 20) or rgb(60, 54, 110)
		end
		local entry = cache[sel]
		local data = entry and entry.data
		local listData = data and data[scope] or {}
		local myId = env.player and env.player.UserId
		for i, r in ipairs(rows) do
			local e = listData[i]
			r.f.Visible = e ~= nil
			if e then
				r.badge.BackgroundColor3 = (i == 1 and GOLD) or (i == 2 and SILVER) or (i == 3 and BRONZE) or rgb(90, 90, 120)
				r.name.Text = tostring(e.name or "?")
				r.score.Text = Config.FormatNum(tonumber(e.value) or 0)
				r.f.BackgroundTransparency = (e.id == myId) and 0.7 or 0.92
				r.av:SetAttribute("For", e.id)
				avatarOf(e.id, r.av)
			end
		end
		if not data then
			empty.Text = "Loading..."
		elseif #listData == 0 then
			empty.Text = (scope == "global") and "No global scores yet - check back in a minute!" or "No scores yet in " .. label(sel) .. ". Be the first!"
		else
			empty.Text = ""
		end
		local best = data and data.best or 0
		meT.Text = "Your best: " .. Config.FormatNum(tonumber(best) or 0) .. ((data and data.rank) and ("   -   #" .. data.rank .. " in this server") or "")
	end
	function app.refresh(force)
		local key = sel
		local entry = cache[key]
		if entry and not force and os.clock() - entry.at < 10 then return end
		loading = loading + 1
		task.spawn(function()
			local ok, res = pcall(env.invoke, "PhoneBoard", key)
			loading = loading - 1
			if ok and type(res) == "table" and res.ok then
				cache[key] = {at = os.clock(), data = res}
				if sel == key then app.draw() end
			end
		end)
	end
	function app.pick(key)
		sel = key
		app.draw()
		app.refresh()
	end

	function app.enter()
		app.draw()
		app.refresh(true)
	end
	function app.leave() end
	function app.key(kc)
		local ok, name = pcall(function() return kc.Name end)
		if not ok then return end
		if name == "Tab" then
			scope = (scope == "server") and "global" or "server"
			app.draw()
		elseif name == "Right" or name == "Left" then
			local idx = 1
			for i, g in ipairs(games) do if g.key == sel then idx = i end end
			idx = (idx + ((name == "Right") and 1 or -1) - 1) % math.max(1, #games) + 1
			if games[idx] then app.pick(games[idx].key) end
		end
	end
	function app.layout(_wide) end
	function app.step(_dt) end
	return app
end

-- the app icon: a gold trophy
local function drawIcon(b, K)
	local rgb, V2, S2 = K.rgb, K.V2, K.S2
	local gold, dark = rgb(255, 215, 70), rgb(200, 130, 20)
	local cup = K.frame(b, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.18), Size = S2(0.48, 0.38), BackgroundColor3 = gold, ZIndex = 4})
	K.round(cup, 0.35)
	K.UI.stroke(cup, 1.5, K.C.ink)
	for _, s in ipairs({-1, 1}) do
		local h = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5 + s * 0.27, 0.33), Size = S2(0.14, 0.2), BackgroundColor3 = dark, ZIndex = 3})
		K.round(h, true)
	end
	K.frame(b, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.55), Size = S2(0.1, 0.14), BackgroundColor3 = dark, ZIndex = 4})
	local base = K.frame(b, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.68), Size = S2(0.38, 0.12), BackgroundColor3 = gold, ZIndex = 4})
	K.round(base, 0.3)
	K.UI.stroke(base, 1.5, K.C.ink)
	K.text(cup, "1", {Size = S2(1, 0.8), Position = S2(0, 0.1), Stroke = 1.5, MaxSize = 30, ZIndex = 5})
end

return {build = build, drawIcon = drawIcon}
