--[[ STACK (phone game): a block slides back and forth - tap (or Space) to drop it on the tower.
     Whatever hangs over the edge is sliced off and falls. Land it exactly for PERFECT! (bonus points,
     and 3 perfects in a row grow the block back a little). It gets faster as the tower grows. ]]

local function build(env)
	local K = env.kit
	local UI, C, new, rgb, V2, S2, WHITE = K.UI, K.C, K.new, K.rgb, K.V2, K.S2, K.WHITE
	local clamp, lerp, frame, round, grad, text = K.clamp, K.lerp, K.frame, K.round, K.grad, K.text
	local bests = K.bests
	local pg = env.page("Stack", {title = "Stack", color = rgb(70, 140, 255), bg0 = rgb(40, 60, 130), bg1 = rgb(12, 16, 40)})
	local content = pg.content
	local app = {}
	local AR, LH, POOL, GROUND = 0.68, 0.05, 30, 0.9
	local H = 1 / AR

	-- THE SKY (the tower lives in here; it scrolls up as it grows)
	local board = frame(content, {Name = "Board", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundColor3 = rgb(70, 90, 180),
		ClipsDescendants = true, ZIndex = 2})
	new("UIAspectRatioConstraint", {AspectRatio = AR}, board)
	round(board, 14)
	UI.stroke(board, 4, C.ink)
	grad(board, rgb(255, 255, 255), rgb(90, 90, 120))
	local stars = {}
	for i = 1, 14 do
		local s = 0.008 + math.random() * 0.012
		local f = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = S2(s, s * AR), BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, ZIndex = 2})
		round(f, true)
		stars[i] = {f = f, x = math.random(), y = math.random()}
	end
	local ground = frame(board, {Size = S2(1, 0.4), BackgroundColor3 = rgb(50, 60, 95), ZIndex = 3})
	grad(ground, WHITE, rgb(110, 110, 140))
	local function block(z)
		local f = frame(board, {Size = S2(0.5, LH), BackgroundColor3 = WHITE, Visible = false, ZIndex = z})
		round(f, 4)
		UI.stroke(f, 1.5, C.ink)
		grad(f, WHITE, rgb(180, 180, 200))
		frame(f, {Position = S2(0.04, 0.12), Size = S2(0.92, 0.18), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, ZIndex = z})
		return f
	end
	local pool = {}
	for i = 1, POOL do pool[i] = block(4) end
	local mover = block(5)
	local chunks = {}
	for i = 1, 6 do chunks[i] = {f = block(6), live = false} end
	-- a white ring that grows out of a PERFECT landing
	local glow = frame(board, {AnchorPoint = V2(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 7})
	round(glow, 6)
	local glowStroke = new("UIStroke", {Thickness = 3, Color = WHITE}, glow)
	local big = text(board, "0", {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.04), Size = S2(0.5, 0.11), ZIndex = 8, Stroke = 3, MaxSize = 80})
	local bigScale = new("UIScale", {}, big)
	local hint = text(board, "TAP TO DROP", {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.3), Size = S2(0.8, 0.07), ZIndex = 8, Stroke = 2.5, MaxSize = 40,
		TextColor3 = rgb(255, 240, 150)})
	local shaker = K.makeShaker(board)
	local parts = K.makeParticles(board, 40, 9)
	parts.H = H
	local pops = K.makePopups(board, 6, 10)
	local panel = K.makePanel(content, 60)
	local catcher = new("TextButton", {Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 40}, content)

	local S = {phase = "idle", layers = {}, top = 0, mx = 0, mw = 0.6, mdir = 1, speed = 0.55, cam = 0, score = 0, combo = 0, newBest = false,
		hue = math.random(), overT = 0, glowT = 1, glowY = 0, glowX = 0, glowW = 0, bg = rgb(70, 90, 180), t = 0}

	local function colorOf(i) return Color3.fromHSV((S.hue + i * 0.035) % 1, 0.6, 0.98) end
	local function yOf(i) return GROUND - (i + 1) * LH + S.cam end
	local function hud()
		pg.setScore(S.score)
		pg.setBest(bests.Stack)
		if big.Text ~= tostring(S.score) then
			big.Text = tostring(S.score)
			bigScale.Scale = 1.35
		end
	end
	local function addScore(n)
		S.score = S.score + n
		if S.score > bests.Stack then
			if bests.Stack > 0 and not S.newBest then pops.pop("NEW BEST!", 0.5, 0.2, rgb(255, 220, 80), {h = 0.08, life = 1.4, rise = 0.04}) end
			S.newBest = S.newBest or bests.Stack > 0
			bests.Stack = S.score
		end
		hud()
	end
	local function nextMover()
		local L = S.layers[S.top]
		S.mw = L.w
		S.speed = math.min(1.5, 0.55 + S.top * 0.022)
		if S.top % 2 == 0 then S.mx, S.mdir = -0.12, 1 else S.mx, S.mdir = 1.12 - S.mw, -1 end
		mover.BackgroundColor3 = colorOf(S.top + 1)
		mover.Visible = true
	end
	local function spawnChunk(x, w, i, dir)
		local c = chunks[1]
		for _, k in ipairs(chunks) do if not k.live then c = k break end end
		c.live, c.x, c.y, c.vx, c.vy, c.rs = true, x, yOf(i), dir * 0.12, 0, dir * (60 + math.random() * 60)
		c.f.Size, c.f.Rotation, c.f.BackgroundColor3, c.f.Visible = S2(w, LH), 0, colorOf(i), true
		c.f.Position = S2(c.x, c.y)
	end
	local function showOver()
		S.phase = "over"
		panel.show({title = "TOWER DOWN!", color = rgb(220, 80, 70),
			lines = "Score  " .. S.score .. "\nHeight  " .. S.top .. "\nBest  " .. bests.Stack,
			best = S.newBest, a = "PLAY AGAIN", onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
	end
	local function drop()
		if S.phase ~= "play" then return end
		local P = S.layers[S.top]
		local mx, mw = S.mx, S.mw
		local l, r = math.max(mx, P.x), math.min(mx + mw, P.x + P.w)
		hint.Visible = false
		if r - l <= 0.004 then -- missed the tower completely
			spawnChunk(mx, mw, S.top + 1, S.mdir)
			mover.Visible = false
			S.phase, S.overT = "falling", 0
			shaker.kick(0.03, 0.45)
			UI.SFX.play("error")
			return
		end
		local i = S.top + 1
		local perfect = math.abs(mx - P.x) < 0.014
		local nx, nw = l, r - l
		if perfect then
			S.combo = S.combo + 1
			nx, nw = P.x, P.w
			if S.combo >= 3 then
				nw = math.min(0.62, nw + 0.025)
				nx = clamp(nx - 0.0125, 0, 1 - nw)
			end
		else
			S.combo = 0
			if mx < P.x then spawnChunk(mx, P.x - mx, i, -1) end
			if mx + mw > P.x + P.w then spawnChunk(P.x + P.w, mx + mw - P.x - P.w, i, 1) end
		end
		S.layers[i] = {x = nx, w = nw, c = colorOf(i)}
		S.top = i
		local y = yOf(i)
		local bonus = perfect and (S.combo >= 3 and 2 or 1) or 0
		addScore(1 + bonus)
		if perfect then
			S.glowT, S.glowX, S.glowY, S.glowW = 0, nx + nw / 2, y - S.cam + LH / 2, nw
			parts.burst(nx + nw / 2, (y + LH / 2) * H, {colorOf(i), WHITE, rgb(255, 230, 90)}, 14 + S.combo * 2, 0.5, 0.025, {rect = true, spin = 200})
			pops.pop(S.combo >= 2 and ("PERFECT x" .. S.combo .. "!") or "PERFECT!", 0.5, y - 0.04, rgb(255, 235, 90), {h = 0.07, life = 1})
			UI.SFX.play("ding", 1.2 + math.min(S.combo, 8) * 0.1, 0.4)
		else
			pops.pop("+1", nx + nw / 2, y - 0.02, C.money, {h = 0.05, w = 0.3})
			UI.SFX.play("click", 2.2, 0.35)
		end
		if i % 10 == 0 then pops.pop(i .. " HIGH!", 0.5, 0.42, rgb(140, 230, 255), {h = 0.08, life = 1.2}) end
		S.bgT = Color3.fromHSV((S.hue + i * 0.035 + 0.55) % 1, 0.5, 0.75)
		nextMover()
	end

	function app.start()
		for _, f in ipairs(pool) do f.Visible = false end
		for _, c in ipairs(chunks) do
			c.live = false
			c.f.Visible = false
		end
		S.layers = {[0] = {x = 0.2, w = 0.6, c = colorOf(0)}}
		S.top, S.score, S.combo, S.newBest, S.cam, S.glowT = 0, 0, 0, false, 0, 1
		S.bgT = Color3.fromHSV((S.hue + 0.55) % 1, 0.5, 0.75)
		parts.clear()
		pops.clear()
		panel.hide()
		hint.Visible = true
		hud()
		nextMover()
		S.phase = "play"
	end
	local function resume()
		panel.hide()
		S.phase = "play"
	end
	function app.enter()
		if S.phase == "paused" then return end
		S.hue = math.random()
		app.start()
	end
	function app.leave()
		if S.phase == "play" then
			S.phase = "paused"
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Score  " .. S.score .. "\nBest  " .. bests.Stack,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		if kc == Enum.KeyCode.P then
			if S.phase == "paused" then resume() else app.leave() end
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return or K.dirKey(kc) == "Down" then
			if S.phase == "over" then app.start() elseif S.phase == "paused" then resume() else drop() end
		end
	end
	catcher.InputBegan:Connect(function(input)
		if K.isPress(input) then drop() end
	end)
	function app.layout(_wide)
		shaker.setBase(S2(0.5, 0.5))
	end

	function app.step(dt)
		parts.update(dt)
		pops.update(dt)
		shaker.update(dt)
		bigScale.Scale = lerp(bigScale.Scale, 1, clamp(dt * 10, 0, 1))
		if S.phase == "paused" or S.phase == "idle" then return end
		S.t = S.t + dt
		-- the tower: keep the top in view
		local camT = math.max(0, (S.top - 9) * LH)
		S.cam = lerp(S.cam, camT, clamp(dt * 6, 0, 1))
		for i = math.max(0, S.top - POOL + 1), S.top do
			local L = S.layers[i]
			local f = pool[i % POOL + 1]
			local y = yOf(i)
			f.Visible = y < 1.05
			f.Position, f.Size, f.BackgroundColor3 = S2(L.x, y), S2(L.w, LH), L.c
		end
		ground.Position = S2(0, GROUND + S.cam)
		for _, s in ipairs(stars) do s.f.Position = S2(s.x, (s.y + S.cam * 0.3) % 1) end
		if S.bgT then S.bg = S.bg:Lerp(S.bgT, clamp(dt * 2, 0, 1)) board.BackgroundColor3 = S.bg end
		-- the sliding block
		if S.phase == "play" then
			S.mx = S.mx + S.mdir * S.speed * dt
			local lo, hi = -0.12, 1.12 - S.mw
			if S.mx > hi then S.mx, S.mdir = hi, -1 elseif S.mx < lo then S.mx, S.mdir = lo, 1 end
			mover.Position, mover.Size = S2(S.mx, yOf(S.top + 1) + math.sin(S.t * 6) * 0.002), S2(S.mw, LH)
			hint.TextTransparency = 0.25 + math.sin(S.t * 5) * 0.25
		end
		-- sliced-off pieces tumble away
		for _, c in ipairs(chunks) do
			if c.live then
				c.vy = c.vy + 2.4 * dt
				c.x, c.y = c.x + c.vx * dt, c.y + c.vy * dt
				c.f.Position = S2(c.x, c.y)
				c.f.Rotation = c.f.Rotation + c.rs * dt
				if c.y > 1.2 then
					c.live = false
					c.f.Visible = false
				end
			end
		end
		if S.glowT < 1 then
			S.glowT = math.min(1, S.glowT + dt * 2.5)
			local g = K.easeOut(S.glowT)
			glow.Visible = S.glowT < 1
			glow.Position = S2(S.glowX, S.glowY + S.cam)
			glow.Size = S2(S.glowW + g * 0.12, LH + g * 0.06)
			glowStroke.Transparency = g
		end
		if S.phase == "falling" then
			S.overT = S.overT + dt
			if S.overT > 0.9 then showOver() end
		end
	end
	return app
end

local function drawIcon(b, K)
	local rgb, V2, S2 = K.rgb, K.V2, K.S2
	local xs = {0.2, 0.24, 0.22, 0.3}
	for k = 1, 4 do
		local c = Color3.fromHSV(0.55 + k * 0.06, 0.6, 1)
		local f = K.frame(b, {Position = S2(xs[k], 0.78 - k * 0.15), Size = S2(0.56 - (k == 4 and 0.08 or 0), 0.14), BackgroundColor3 = c, ZIndex = 3 + k % 2})
		K.round(f, 0.25)
		K.UI.stroke(f, 1.5, K.C.ink)
	end
	local chip = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.84, 0.3), Size = S2(0.12, 0.12), Rotation = 30, BackgroundColor3 = rgb(255, 240, 120), ZIndex = 4})
	K.round(chip, 0.2)
end

return {build = build, drawIcon = drawIcon}
