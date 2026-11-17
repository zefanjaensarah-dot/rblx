--[[ WHACK-A-THIEF (phone game): thieves pop out of 9 holes - tap them (or Q W E / A S D / Z X C,
     or the number pad) before they get away. Golden thieves are worth 5 and add 3 seconds.
     DON'T hit the guards: that costs a life. Hit thieves in a row for a combo multiplier.
     3 lives, 60 seconds, and they get faster and faster. ]]

local KEYMAP = {Q = 1, W = 2, E = 3, A = 4, S = 5, D = 6, Z = 7, X = 8, C = 9,
	One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8, Nine = 9,
	KeypadSeven = 1, KeypadEight = 2, KeypadNine = 3, KeypadFour = 4, KeypadFive = 5, KeypadSix = 6, KeypadOne = 7, KeypadTwo = 8, KeypadThree = 9}
local TIME, RISE = 60, 0.12

local function build(env)
	local K = env.kit
	local UI, C, new, rgb, V2, S2, WHITE = K.UI, K.C, K.new, K.rgb, K.V2, K.S2, K.WHITE
	local clamp, lerp, frame, round, grad, text = K.clamp, K.lerp, K.frame, K.round, K.grad, K.text
	local bests = K.bests
	local pg = env.page("Whack", {title = "Whack-a-Thief", color = rgb(220, 70, 60), bg0 = rgb(120, 60, 40), bg1 = rgb(40, 18, 14)})
	local content = pg.content
	local app = {}

	-- HUD: hearts + the timer bar
	local hud = frame(content, {Size = S2(1, 0.08), BackgroundTransparency = 1, ZIndex = 3})
	local hearts = {}
	for i = 1, 3 do
		local hh = frame(hud, {Position = S2((i - 1) * 0.1, 0.1), Size = S2(0.09, 0.8), BackgroundTransparency = 1, ZIndex = 3})
		K.square(hh)
		local bits = {}
		for k, spec in ipairs({{0.3, 0.36, 0.52, 0}, {0.7, 0.36, 0.52, 0}, {0.5, 0.58, 0.5, 45}}) do
			local f = frame(hh, {AnchorPoint = V2(0.5, 0.5), Position = S2(spec[1], spec[2]), Size = S2(spec[3], spec[3]), Rotation = spec[4], BackgroundColor3 = rgb(255, 70, 90), ZIndex = 3})
			round(f, k < 3 and true or 0.15)
			bits[k] = f
		end
		hearts[i] = {bits = bits, sc = new("UIScale", {}, hh)}
	end
	local barBack = frame(hud, {AnchorPoint = V2(1, 0.5), Position = S2(1, 0.5), Size = S2(0.6, 0.55), BackgroundColor3 = rgb(30, 20, 30), ZIndex = 3})
	round(barBack, true)
	UI.stroke(barBack, 2.5, C.ink)
	local bar = frame(barBack, {Size = S2(1, 1), BackgroundColor3 = C.green, ZIndex = 4})
	round(bar, true)
	grad(bar, WHITE, rgb(180, 180, 190))
	local timeT = text(barBack, "60", {Size = S2(1, 0.9), Position = S2(0, 0.05), Stroke = 2, MaxSize = 26, ZIndex = 5})

	-- THE YARD: 3 x 3 holes
	local board = frame(content, {Name = "Board", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.55), Size = S2(1, 0.9), BackgroundColor3 = rgb(110, 200, 80), ZIndex = 2})
	K.square(board)
	round(board, 16)
	UI.stroke(board, 4, rgb(60, 40, 25))
	grad(board, WHITE, rgb(170, 200, 160))
	local holes = {}
	for i = 1, 9 do
		local r, c = math.floor((i - 1) / 3), (i - 1) % 3
		local cell = frame(board, {Position = S2(c / 3, r / 3), Size = S2(1 / 3, 1 / 3), BackgroundTransparency = 1, ZIndex = 2})
		local hole = frame(cell, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.74), Size = S2(0.76, 0.24), BackgroundColor3 = rgb(40, 25, 20), ZIndex = 2})
		round(hole, true)
		local mask = frame(cell, {AnchorPoint = V2(0.5, 1), Position = S2(0.5, 0.75), Size = S2(0.8, 0.74), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3})
		local ch = frame(mask, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 1.05), Size = S2(0.84, 1), BackgroundTransparency = 1, ZIndex = 3})
		local body = frame(ch, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.68), Size = S2(0.92, 0.5), ZIndex = 3})
		round(body, 0.4)
		UI.stroke(body, 2, C.ink)
		local stripe = frame(body, {Position = S2(0, 0.25), Size = S2(1, 0.16), BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, ZIndex = 3})
		local badge = frame(body, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.68, 0.3), Size = S2(0.16, 0.3), Rotation = 45, BackgroundColor3 = rgb(255, 210, 50), ZIndex = 4})
		K.square(badge)
		local head = frame(ch, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.42), Size = S2(0.78, 0.56), ZIndex = 4})
		round(head, true)
		UI.stroke(head, 2, C.ink)
		local hat = frame(ch, {AnchorPoint = V2(0.5, 1), Position = S2(0.5, 0.3), Size = S2(0.66, 0.2), ZIndex = 5})
		round(hat, 0.45)
		UI.stroke(hat, 2, C.ink)
		local brim = frame(ch, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.6, 0.29), Size = S2(0.62, 0.07), BackgroundColor3 = rgb(20, 40, 110), ZIndex = 6})
		round(brim, true)
		local mask2 = frame(head, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.42), Size = S2(0.98, 0.28), BackgroundColor3 = rgb(20, 18, 28), ZIndex = 5})
		round(mask2, true)
		local eyes = {}
		for k, x in ipairs({0.32, 0.68}) do
			local e = frame(head, {AnchorPoint = V2(0.5, 0.5), Position = S2(x, 0.42), Size = S2(0.24, 0.5), BackgroundColor3 = WHITE, ZIndex = 6})
			K.square(e)
			round(e, true)
			local pu = frame(e, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.55, 0.55), Size = S2(0.5, 0.5), BackgroundColor3 = C.ink, ZIndex = 7})
			round(pu, true)
			eyes[k] = pu
		end
		local mouth = frame(head, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.74), Size = S2(0.3, 0.07), BackgroundColor3 = rgb(120, 40, 40), ZIndex = 6})
		round(mouth, true)
		local lip = frame(cell, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.74), Size = S2(0.8, 0.13), BackgroundColor3 = rgb(130, 90, 55), ZIndex = 8})
		round(lip, true)
		UI.stroke(lip, 2, rgb(60, 40, 25))
		holes[i] = {ch = ch, body = body, stripe = stripe, badge = badge, head = head, hat = hat, brim = brim, mask = mask2, eyes = eyes, mouth = mouth,
			x = (c + 0.5) / 3, y = (r + 0.62) / 3, kind = nil, t = 0, dur = 1, pop = 0, hit = false, hitT = 0}
	end
	-- the mallet that swings where you tap
	local mallet = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = S2(0.24, 0.24), BackgroundTransparency = 1, Visible = false, ZIndex = 20})
	local handle = frame(mallet, {AnchorPoint = V2(0.5, 0), Position = S2(0.62, 0.32), Size = S2(0.09, 0.62), BackgroundColor3 = rgb(150, 95, 50), ZIndex = 20})
	UI.stroke(handle, 2, C.ink)
	local mhead = frame(mallet, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.62, 0.28), Size = S2(0.56, 0.3), BackgroundColor3 = rgb(230, 60, 60), ZIndex = 21})
	round(mhead, 0.3)
	UI.stroke(mhead, 2.5, C.ink)
	grad(mhead, WHITE, rgb(170, 160, 170))
	local flash = frame(board, {Size = S2(1, 1), BackgroundColor3 = rgb(255, 50, 60), BackgroundTransparency = 1, ZIndex = 22})
	round(flash, 16)
	local shaker = K.makeShaker(board)
	local parts = K.makeParticles(board, 48, 23)
	local pops = K.makePopups(board, 8, 24)
	local cd = K.makeCountdown(board, 25)
	local panel = K.makePanel(content, 60)
	local catcher = new("TextButton", {Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 40}, content)

	local S = {phase = "idle", score = 0, lives = 3, time = TIME, elapsed = 0, combo = 0, maxCombo = 0, caught = 0, newBest = false, spawnT = 0.5, malletT = 1, endT = 0, why = ""}
	local SKIN = rgb(255, 205, 165)

	local function setKind(h, kind)
		h.kind, h.t, h.pop, h.hit, h.hitT = kind, 0, 0, false, 0
		local guard, gold = kind == "guard", kind == "gold"
		h.head.BackgroundColor3 = gold and rgb(255, 220, 90) or SKIN
		h.hat.BackgroundColor3 = guard and rgb(40, 90, 210) or (gold and rgb(255, 170, 30) or rgb(45, 40, 55))
		h.body.BackgroundColor3 = guard and rgb(50, 100, 220) or (gold and rgb(255, 200, 60) or rgb(55, 50, 70))
		h.brim.Visible, h.badge.Visible = guard, guard
		h.mask.Visible, h.stripe.Visible = not guard, not guard
		h.mask.BackgroundColor3 = gold and rgb(160, 90, 10) or rgb(20, 18, 28)
		h.mouth.BackgroundColor3 = guard and rgb(90, 60, 30) or rgb(120, 40, 40)
		h.mouth.Size = guard and S2(0.46, 0.1) or S2(0.3, 0.07)
		h.ch.Rotation = 0
	end
	local function hudRefresh()
		pg.setScore(S.score)
		pg.setBest(bests.Whack)
		for i, hh in ipairs(hearts) do
			for _, f in ipairs(hh.bits) do
				f.BackgroundColor3 = (i <= S.lives) and rgb(255, 70, 90) or rgb(80, 70, 80)
				f.BackgroundTransparency = (i <= S.lives) and 0 or 0.4
			end
		end
	end
	local function addScore(n)
		S.score = S.score + n
		if S.score > bests.Whack then
			if bests.Whack > 0 and not S.newBest then pops.pop("NEW BEST!", 0.5, 0.12, rgb(255, 220, 80), {h = 0.09, life = 1.4, rise = 0.04}) end
			S.newBest = S.newBest or bests.Whack > 0
			bests.Whack = S.score
		end
		hudRefresh()
	end
	local function finish(why)
		S.phase, S.endT, S.why = "end", 0, why
		for _, h in ipairs(holes) do if h.kind and not h.hit then h.hit, h.hitT = true, 0.1 end end
	end
	local function showOver()
		S.phase = "over"
		panel.show({title = S.why, color = rgb(210, 70, 60),
			lines = "Score  " .. S.score .. "\nThieves  " .. S.caught .. "   Best combo  " .. S.maxCombo .. "\nBest  " .. bests.Whack,
			best = S.newBest, a = "PLAY AGAIN", onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
	end
	local function whack(i, mx, my)
		if S.phase ~= "play" then return end
		local h = holes[i]
		mallet.Position, mallet.Visible = S2(mx or h.x, (my or h.y) - 0.04), true
		S.malletT = 0
		if not h or not h.kind or h.hit or h.pop < 0.3 then
			S.combo = 0
			UI.SFX.play("click", 1.4, 0.2)
			return
		end
		h.hit, h.hitT = true, 0
		if h.kind == "guard" then
			S.lives, S.combo = S.lives - 1, 0
			flash.BackgroundTransparency = 0.35
			shaker.kick(0.03, 0.4)
			hearts[S.lives + 1].sc.Scale = 1.6
			pops.pop("OUCH! A GUARD!", h.x, h.y - 0.12, rgb(255, 90, 90), {h = 0.08, w = 0.6})
			UI.SFX.play("error")
			hudRefresh()
			if S.lives <= 0 then finish("CAUGHT!") end
			return
		end
		S.combo, S.caught = S.combo + 1, S.caught + 1
		S.maxCombo = math.max(S.maxCombo, S.combo)
		local mult = 1 + math.floor(S.combo / 5)
		local gold = h.kind == "gold"
		local pts = (gold and 5 or 1) * mult
		addScore(pts)
		parts.burst(h.x, h.y - 0.06, gold and {rgb(255, 220, 60), WHITE} or {rgb(255, 240, 120), WHITE, rgb(255, 150, 60)}, gold and 22 or 10, 0.5, 0.03, {rect = true, spin = 300})
		pops.pop("+" .. pts, h.x, h.y - 0.14, gold and rgb(255, 220, 60) or C.money, {h = 0.08, w = 0.35})
		if gold then
			S.time = S.time + 3
			pops.pop("+3s", h.x, h.y - 0.04, rgb(140, 230, 255), {h = 0.06, w = 0.3, life = 1.1})
			UI.SFX.play("ding", 1.8, 0.45)
		else
			UI.SFX.play("click", 2.6, 0.35)
		end
		if S.combo % 5 == 0 then
			pops.pop("COMBO x" .. mult .. "!", 0.5, 0.5, rgb(255, 160, 220), {h = 0.1, life = 1.1})
			shaker.kick(0.012, 0.2)
		end
	end
	local function tick(dt)
		S.time = S.time - dt
		S.elapsed = S.elapsed + dt
		local prog = clamp(S.elapsed / TIME, 0, 1)
		S.spawnT = S.spawnT - dt
		if S.spawnT <= 0 then
			S.spawnT = lerp(0.85, 0.36, prog) * (0.8 + math.random() * 0.4)
			for _ = 1, (prog > 0.5 and math.random() < 0.3) and 2 or 1 do
				local free = {}
				for k, h in ipairs(holes) do if not h.kind then table.insert(free, k) end end
				if #free > 0 then
					local h = holes[free[math.random(1, #free)]]
					local r = math.random()
					setKind(h, (r < 0.06) and "gold" or ((r < 0.06 + lerp(0.18, 0.3, prog)) and "guard" or "thief"))
					h.dur = lerp(1.1, 0.55, prog) + math.random() * 0.2
					if h.kind == "gold" then h.dur = h.dur * 0.7 end
				end
			end
		end
		if S.time <= 0 then
			S.time = 0
			finish("TIME'S UP!")
		end
	end

	function app.start()
		for _, h in ipairs(holes) do
			setKind(h, nil)
			h.ch.Position = S2(0.5, 1.05)
		end
		S.score, S.lives, S.time, S.elapsed, S.combo, S.maxCombo, S.caught, S.newBest, S.spawnT = 0, 3, TIME, 0, 0, 0, 0, false, 0.4
		flash.BackgroundTransparency = 1
		mallet.Visible = false
		parts.clear()
		pops.clear()
		panel.hide()
		hudRefresh()
		S.phase = "count"
		cd.start(3)
	end
	local function resume()
		panel.hide()
		S.phase = "count"
		cd.start(2)
	end
	function app.enter()
		if S.phase == "paused" then return end
		app.start()
	end
	function app.leave()
		if S.phase == "play" or S.phase == "count" then
			S.phase = "paused"
			cd.stop()
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Score  " .. S.score .. "\nBest  " .. bests.Whack,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		if kc == Enum.KeyCode.P then
			if S.phase == "paused" then resume() else app.leave() end
			return
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return then
			if S.phase == "over" then app.start() elseif S.phase == "paused" then resume() end
			return
		end
		local ok, name = pcall(function() return kc.Name end)
		local i = ok and KEYMAP[name] or nil
		if i then whack(i) end
	end
	catcher.InputBegan:Connect(function(input)
		if not K.isPress(input) then return end
		local fx, fy = K.fracIn(board, K.posOf(input))
		if fx < 0 or fx > 1 or fy < 0 or fy > 1 then return end
		whack(clamp(math.floor(fy * 3), 0, 2) * 3 + clamp(math.floor(fx * 3), 0, 2) + 1, fx, fy)
	end)
	function app.layout(_wide)
		shaker.setBase(S2(0.5, 0.55))
	end

	function app.step(dt)
		parts.update(dt)
		pops.update(dt)
		shaker.update(dt)
		local counting = cd.update(dt)
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 2.5)
		for _, hh in ipairs(hearts) do hh.sc.Scale = lerp(hh.sc.Scale, 1, clamp(dt * 8, 0, 1)) end
		if S.malletT < 1 then
			S.malletT = S.malletT + dt
			local k = S.malletT
			mallet.Rotation = (k < 0.08) and lerp(-55, 15, k / 0.08) or 15
			mallet.Visible = k < 0.3
		end
		if S.phase == "paused" or S.phase == "idle" then return end
		if S.phase == "count" and not counting then S.phase = "play" end
		if S.phase == "play" then tick(dt) end
		local f = S.time / TIME
		bar.Size = S2(clamp(f, 0, 1), 1)
		bar.BackgroundColor3 = C.red:Lerp(C.green, clamp(f * 1.6, 0, 1))
		timeT.Text = tostring(math.ceil(S.time))
		-- the characters pop up, wait, and duck back down
		for _, h in ipairs(holes) do
			if h.kind then
				if S.phase == "play" or S.phase == "end" then h.t = h.t + dt end
				if h.hit then
					h.hitT = h.hitT + dt
					h.pop = math.max(0, 1 - h.hitT / 0.28)
					h.ch.Rotation = math.sin(h.hitT * 40) * 14
					if h.hitT > 0.3 then setKind(h, nil) end
				else
					local t = h.t
					h.pop = (t < RISE) and t / RISE or ((t < RISE + h.dur) and 1 or math.max(0, 1 - (t - RISE - h.dur) / RISE))
					local look = math.sin(t * 6) * 0.15
					for _, e in ipairs(h.eyes) do e.Position = S2(0.55 + look, 0.55) end
					if t > h.dur + RISE * 2 then
						if h.kind ~= "guard" and S.phase == "play" then
							S.combo = 0
							pops.pop("got away!", h.x, h.y - 0.1, rgb(220, 220, 230), {h = 0.05, w = 0.4})
						end
						setKind(h, nil)
					end
				end
				h.ch.Position = S2(0.5, lerp(1.05, 0.06, K.backOut(h.pop)))
			end
		end
		if S.phase == "end" then
			S.endT = S.endT + dt
			if S.endT > 0.9 then showOver() end
		end
	end
	return app
end

local function drawIcon(b, K)
	local rgb, V2, S2 = K.rgb, K.V2, K.S2
	local hole = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.78), Size = S2(0.7, 0.18), BackgroundColor3 = rgb(40, 25, 20), ZIndex = 3})
	K.round(hole, true)
	local head = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.45, 0.55), Size = S2(0.42, 0.42), BackgroundColor3 = rgb(255, 205, 165), ZIndex = 4})
	K.round(head, true)
	K.UI.stroke(head, 1.5, K.C.ink)
	local m = K.frame(head, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.45), Size = S2(1, 0.3), BackgroundColor3 = rgb(20, 18, 28), ZIndex = 5})
	K.round(m, true)
	local mh = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.72, 0.26), Size = S2(0.36, 0.2), Rotation = -30, BackgroundColor3 = rgb(230, 60, 60), ZIndex = 6})
	K.round(mh, 0.3)
	K.UI.stroke(mh, 1.5, K.C.ink)
end

return {build = build, drawIcon = drawIcon}
