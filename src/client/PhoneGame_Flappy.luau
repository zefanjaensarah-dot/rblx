--[[ FLAPPY BOX (phone game): a cardboard box with wings. Tap / Space / Up to flap through the gaps
     between the warehouse shelves. Coins are worth +3. The gaps shrink and the shelves speed up. ]]

local function build(env)
	local K = env.kit
	local UI, C, new, rgb, V2, S2, WHITE = K.UI, K.C, K.new, K.rgb, K.V2, K.S2, K.WHITE
	local clamp, lerp, frame, round, grad, text = K.clamp, K.lerp, K.frame, K.round, K.grad, K.text
	local bests = K.bests
	local pg = env.page("Flappy", {title = "Flappy Box", color = rgb(240, 150, 30), bg0 = rgb(255, 200, 90), bg1 = rgb(200, 90, 30)})
	local content = pg.content
	local app = {}
	local AR = 0.68
	local H = 1 / AR -- everything is in "width units": x 0..1, y 0..H
	local GH, PW, SP, BX, BS = 0.16, 0.17, 0.62, 0.3, 0.1
	local FLOOR = H - GH
	local function P(x, y) return S2(x, y / H) end

	local board = frame(content, {Name = "Board", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundColor3 = rgb(110, 200, 255),
		ClipsDescendants = true, ZIndex = 2})
	new("UIAspectRatioConstraint", {AspectRatio = AR}, board)
	round(board, 14)
	UI.stroke(board, 4, C.ink)
	grad(board, rgb(200, 240, 255), rgb(255, 255, 255))
	local clouds = {}
	for i = 1, 4 do
		local w = 0.22 + math.random() * 0.15
		local f = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = P(w, w * 0.4), BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, ZIndex = 2})
		round(f, true)
		clouds[i] = {f = f, x = i * 0.35, y = 0.1 + math.random() * 0.6, w = w}
	end
	-- shelves: a top column + a bottom column, each with a lip at the gap
	local SHELF_C = {rgb(255, 130, 60), rgb(80, 150, 255), rgb(170, 100, 255), rgb(40, 200, 160)}
	local pipes = {}
	for i = 1, 4 do
		local p = {}
		for _, k in ipairs({"top", "bot"}) do
			local col = frame(board, {Size = P(PW, 0.5), BackgroundColor3 = SHELF_C[i], ZIndex = 3})
			UI.stroke(col, 2.5, C.ink)
			grad(col, WHITE, rgb(170, 170, 190), 0)
			for s = 1, 3 do frame(col, {Position = S2(0, s * 0.25), Size = S2(1, 0.03), BackgroundColor3 = C.ink, BackgroundTransparency = 0.6, ZIndex = 3}) end
			local lip = frame(board, {Size = P(PW + 0.04, 0.05), BackgroundColor3 = SHELF_C[i], ZIndex = 4})
			round(lip, 4)
			UI.stroke(lip, 2.5, C.ink)
			grad(lip, WHITE, rgb(190, 190, 205))
			p[k], p[k .. "Lip"] = col, lip
		end
		local coin = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = P(0.07, 0.07), BackgroundColor3 = rgb(255, 210, 50), Visible = false, ZIndex = 5})
		round(coin, true)
		UI.stroke(coin, 2, rgb(150, 90, 10))
		local inner = frame(coin, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(0.5, 0.5), BackgroundColor3 = rgb(255, 240, 140), ZIndex = 5})
		round(inner, true)
		p.coin, p.color = coin, SHELF_C[i]
		pipes[i] = p
	end
	local ground = frame(board, {Position = P(0, FLOOR), Size = P(1, GH + 0.05), BackgroundColor3 = rgb(120, 90, 60), ZIndex = 6})
	UI.stroke(ground, 3, C.ink)
	frame(ground, {Size = S2(1, 0.16), BackgroundColor3 = rgb(110, 210, 80), ZIndex = 6})
	local stripes = {}
	for i = 1, 8 do
		stripes[i] = frame(ground, {Position = S2(i * 0.18, 0.3), Size = S2(0.08, 0.5), Rotation = 20, BackgroundColor3 = rgb(95, 70, 45), ZIndex = 6})
	end
	-- THE BOX: cardboard with tape, eyes, a beak and two flapping wings
	local bird = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = P(BS, BS), BackgroundTransparency = 1, ZIndex = 7})
	local wings = {}
	for k, s in ipairs({-1, 1}) do
		local w = frame(bird, {AnchorPoint = V2(s < 0 and 1 or 0, 0.5), Position = S2(s < 0 and 0.12 or 0.88, 0.48), Size = S2(0.6, 0.32),
			BackgroundColor3 = rgb(255, 250, 235), ZIndex = 7})
		round(w, true)
		UI.stroke(w, 2, C.ink)
		wings[k] = {f = w, s = s}
	end
	local body = frame(bird, {Size = S2(1, 1), BackgroundColor3 = rgb(215, 160, 95), ZIndex = 8})
	round(body, 0.18)
	UI.stroke(body, 2.5, C.ink)
	grad(body, WHITE, rgb(190, 170, 150))
	frame(body, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0), Size = S2(0.22, 1), BackgroundColor3 = rgb(180, 120, 60), ZIndex = 8})
	for _, x in ipairs({0.62, 0.86}) do
		local e = frame(body, {AnchorPoint = V2(0.5, 0.5), Position = S2(x, 0.36), Size = S2(0.24, 0.26), BackgroundColor3 = WHITE, ZIndex = 9})
		round(e, true)
		UI.stroke(e, 1.5, C.ink)
		local pu = frame(e, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.62, 0.55), Size = S2(0.5, 0.5), BackgroundColor3 = C.ink, ZIndex = 10})
		round(pu, true)
	end
	local beak = frame(body, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.98, 0.62), Size = S2(0.26, 0.26), Rotation = 45, BackgroundColor3 = rgb(255, 150, 40), ZIndex = 9})
	round(beak, 0.2)
	UI.stroke(beak, 1.5, C.ink)
	local birdScale = new("UIScale", {}, bird)
	local flash = frame(board, {Size = S2(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 12})
	local big = text(board, "0", {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.05), Size = S2(0.5, 0.1), ZIndex = 11, Stroke = 3.5, MaxSize = 80})
	local bigScale = new("UIScale", {}, big)
	local hint = text(board, "TAP TO FLAP", {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.62), Size = S2(0.8, 0.07), ZIndex = 11, Stroke = 2.5, MaxSize = 40,
		TextColor3 = rgb(255, 240, 150)})
	local shaker = K.makeShaker(board)
	local parts = K.makeParticles(board, 40, 10)
	parts.H = H
	local pops = K.makePopups(board, 6, 11)
	local panel = K.makePanel(content, 60)
	local catcher = new("TextButton", {Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 40}, content)

	local S = {phase = "idle", y = 0.6, vy = 0, t = 0, scroll = 0, speed = 0.36, passed = 0, score = 0, coins = 0, newBest = false, flapT = 1, deadT = 0}

	local function hud()
		pg.setScore(S.score)
		pg.setBest(bests.Flappy)
		if big.Text ~= tostring(S.score) then
			big.Text = tostring(S.score)
			bigScale.Scale = 1.35
		end
	end
	local function addScore(n)
		S.score = S.score + n
		if S.score > bests.Flappy then
			if bests.Flappy > 0 and not S.newBest then pops.pop("NEW BEST!", 0.5, 0.22, rgb(255, 220, 80), {h = 0.08, life = 1.4, rise = 0.04}) end
			S.newBest = S.newBest or bests.Flappy > 0
			bests.Flappy = S.score
		end
		hud()
	end
	local function gapHalf() return math.max(0.15, 0.25 - S.passed * 0.004) end
	local function placePipe(p, x)
		p.x, p.done = x, false
		p.gh = gapHalf()
		p.gy = p.gh + 0.12 + math.random() * (FLOOR - 2 * p.gh - 0.24)
		p.coinOn = math.random() < 0.6
		p.cy = 0.25 + math.random() * (FLOOR - 0.5)
		p.coin.Visible = p.coinOn
	end
	local function drawPipe(p)
		local top, bot = p.gy - p.gh, p.gy + p.gh
		p.top.Position, p.top.Size = P(p.x, -0.05), P(PW, top + 0.05)
		p.topLip.Position = P(p.x - 0.02, top - 0.05)
		p.bot.Position, p.bot.Size = P(p.x, bot), P(PW, FLOOR - bot + 0.02)
		p.botLip.Position = P(p.x - 0.02, bot)
		if p.coinOn then
			p.coin.Position = P(p.x + PW / 2 + SP / 2, p.cy + math.sin(S.t * 4 + p.x) * 0.01)
			p.coin.Size = P(0.07 * math.max(0.15, math.abs(math.cos(S.t * 4 + p.x))), 0.07)
		end
	end
	local function flap()
		if S.phase == "ready" then
			S.phase = "play"
			hint.Visible = false
		end
		if S.phase ~= "play" then return end
		S.vy = -1.05
		S.flapT = 0
		parts.burst(BX - 0.04, S.y + 0.03, {WHITE, rgb(255, 240, 200)}, 4, 0.25, 0.02, {g = 0.5})
		UI.SFX.play("click", 2.8, 0.25)
	end
	local function showOver()
		S.phase = "over"
		panel.show({title = "CRASH!", color = rgb(230, 110, 40),
			lines = "Score  " .. S.score .. "\nShelves  " .. S.passed .. "   Coins  " .. S.coins .. "\nBest  " .. bests.Flappy,
			best = S.newBest, a = "PLAY AGAIN", onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
	end
	local function die()
		if S.phase ~= "play" then return end
		S.phase, S.deadT = "dead", 0
		S.vy = math.min(S.vy, -0.6)
		flash.BackgroundTransparency = 0.2
		shaker.kick(0.03, 0.4)
		parts.burst(BX, S.y, {rgb(215, 160, 95), rgb(180, 120, 60), WHITE}, 16, 0.5, 0.03, {rect = true, spin = 300})
		UI.SFX.play("error")
	end

	function app.start()
		S.y, S.vy, S.scroll, S.speed, S.passed, S.score, S.coins, S.newBest, S.flapT = 0.6, 0, 0, 0.36, 0, 0, 0, false, 1
		for i, p in ipairs(pipes) do placePipe(p, 1.25 + (i - 1) * SP) end
		flash.BackgroundTransparency = 1
		bird.Rotation = 0
		parts.clear()
		pops.clear()
		panel.hide()
		hint.Visible = true
		hud()
		S.phase = "ready"
	end
	local function resume()
		panel.hide()
		S.phase = S.wasReady and "ready" or "play"
		if S.phase == "play" then S.vy = -0.6 end
	end
	function app.enter()
		if S.phase == "paused" then return end
		app.start()
	end
	function app.leave()
		if S.phase == "play" or S.phase == "ready" then
			S.wasReady = S.phase == "ready"
			S.phase = "paused"
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Score  " .. S.score .. "\nBest  " .. bests.Flappy,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		if kc == Enum.KeyCode.P then
			if S.phase == "paused" then resume() else app.leave() end
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return or K.dirKey(kc) == "Up" then
			if S.phase == "over" then app.start() elseif S.phase == "paused" then resume() else flap() end
		end
	end
	catcher.InputBegan:Connect(function(input)
		if K.isPress(input) then flap() end
	end)
	function app.layout(_wide)
		shaker.setBase(S2(0.5, 0.5))
	end

	function app.step(dt)
		parts.update(dt)
		pops.update(dt)
		shaker.update(dt)
		bigScale.Scale = lerp(bigScale.Scale, 1, clamp(dt * 10, 0, 1))
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 3)
		if S.phase == "paused" or S.phase == "idle" then return end
		S.t = S.t + dt
		local moving = S.phase == "play" or S.phase == "ready"
		if moving then S.scroll = S.scroll + S.speed * dt end
		for _, c in ipairs(clouds) do
			c.f.Position = P((c.x - S.scroll * 0.25) % 1.5 - 0.25, c.y)
		end
		for i, s in ipairs(stripes) do s.Position = S2((i * 0.18 - S.scroll) % 1.44 - 0.2, 0.3) end
		-- the box
		if S.phase == "ready" then
			S.y = 0.6 + math.sin(S.t * 4) * 0.03
		elseif S.phase == "play" or S.phase == "dead" then
			S.vy = S.vy + 3.5 * dt
			S.y = S.y + S.vy * dt
			if S.y < BS / 2 then S.y, S.vy = BS / 2, 0 end
			if S.y > FLOOR - BS / 2 then
				S.y = FLOOR - BS / 2
				if S.phase == "play" then die() end
				S.vy = 0
			end
		end
		S.flapT = S.flapT + dt
		local ang = (S.flapT < 0.25) and math.sin(S.flapT * 50) * 50 or math.sin(S.t * 8) * 12
		for _, w in ipairs(wings) do w.f.Rotation = -w.s * ang end
		bird.Position = P(BX, S.y)
		bird.Rotation = (S.phase == "ready") and 0 or clamp(S.vy * 40, -25, (S.phase == "dead") and 120 or 75)
		birdScale.Scale = lerp(birdScale.Scale, 1, clamp(dt * 8, 0, 1))
		-- the shelves (and their coins)
		local maxX = -10
		for _, p in ipairs(pipes) do maxX = math.max(maxX, p.x) end
		for _, p in ipairs(pipes) do
			if S.phase == "play" then
				p.x = p.x - S.speed * dt
				if p.x < -PW - 0.06 then
					placePipe(p, maxX + SP)
					maxX = p.x
				end
				local hs = BS * 0.42
				if BX + hs > p.x and BX - hs < p.x + PW and (S.y - hs < p.gy - p.gh or S.y + hs > p.gy + p.gh) then die() end
				if not p.done and p.x + PW < BX - hs then
					p.done = true
					S.passed = S.passed + 1
					S.speed = math.min(0.6, 0.36 + S.passed * 0.008)
					addScore(1)
					UI.SFX.play("click", 2.2, 0.3)
					if S.passed % 10 == 0 then pops.pop(S.passed .. " SHELVES!", 0.5, 0.3, rgb(140, 230, 255), {h = 0.08, life = 1.2}) end
				end
				if p.coinOn then
					local cx = p.x + PW / 2 + SP / 2
					if math.abs(cx - BX) < 0.08 and math.abs(p.cy - S.y) < 0.09 then
						p.coinOn, p.coin.Visible = false, false
						S.coins = S.coins + 1
						addScore(3)
						parts.burst(cx, p.cy, {rgb(255, 220, 60), WHITE}, 14, 0.45, 0.025)
						pops.pop("+3", cx, p.cy / H - 0.05, rgb(255, 220, 60), {h = 0.06, w = 0.3})
						birdScale.Scale = 1.25
						UI.SFX.play("ding", 1.6, 0.4)
					end
				end
			end
			drawPipe(p)
		end
		if S.phase == "dead" then
			S.deadT = S.deadT + dt
			if S.deadT > 1 then showOver() end
		end
		if hint.Visible then hint.TextTransparency = 0.25 + math.sin(S.t * 5) * 0.25 end
	end
	return app
end

local function drawIcon(b, K)
	local rgb, V2, S2 = K.rgb, K.V2, K.S2
	for _, y in ipairs({{0, 0.3}, {0.68, 0.32}}) do
		local col = K.frame(b, {Position = S2(0.66, y[1]), Size = S2(0.2, y[2]), BackgroundColor3 = rgb(80, 150, 255), ZIndex = 3})
		K.UI.stroke(col, 1.5, K.C.ink)
	end
	local w = K.frame(b, {AnchorPoint = V2(1, 0.5), Position = S2(0.3, 0.5), Size = S2(0.2, 0.12), Rotation = 25, BackgroundColor3 = K.WHITE, ZIndex = 4})
	K.round(w, true)
	K.UI.stroke(w, 1.5, K.C.ink)
	local bx = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.42, 0.52), Size = S2(0.3, 0.3), Rotation = -10, BackgroundColor3 = rgb(215, 160, 95), ZIndex = 5})
	K.round(bx, 0.18)
	K.UI.stroke(bx, 1.5, K.C.ink)
	local e = K.frame(bx, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.7, 0.35), Size = S2(0.28, 0.28), BackgroundColor3 = K.WHITE, ZIndex = 6})
	K.round(e, true)
end

return {build = build, drawIcon = drawIcon}
