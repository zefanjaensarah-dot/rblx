--[[ BOX CATCHER (phone game): drag the basket (or A / D, arrow keys) to catch falling boxes.
     Box = 1, gold = 3, diamond = 5, rainbow = 10. Bombs cost a life (3 lives). Catch in a row for a
     combo multiplier. Everything falls faster and faster. ]]

local KINDS = {
	box = {pts = 1, c = {215, 160, 95}},
	gold = {pts = 3, c = {255, 205, 50}},
	diamond = {pts = 5, c = {90, 220, 255}},
	rainbow = {pts = 10, c = {255, 255, 255}},
	bomb = {pts = 0, c = {40, 40, 52}},
}

local function build(env)
	local K = env.kit
	local UI, C, new, rgb, V2, S2, WHITE = K.UI, K.C, K.new, K.rgb, K.V2, K.S2, K.WHITE
	local clamp, lerp, frame, round, grad, text = K.clamp, K.lerp, K.frame, K.round, K.grad, K.text
	local bests = K.bests
	local UIS = game:GetService("UserInputService")
	local pg = env.page("Catch", {title = "Box Catcher", color = rgb(30, 170, 150), bg0 = rgb(40, 120, 130), bg1 = rgb(10, 30, 40)})
	local content = pg.content
	local app = {}
	local AR = 0.68
	local H = 1 / AR -- width units: x 0..1, y 0..H
	local BW, BY, IS = 0.24, H - 0.13, 0.085
	local function P(x, y) return S2(x, y / H) end
	local RAINBOW = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 80, 80)), ColorSequenceKeypoint.new(0.25, rgb(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, rgb(80, 230, 110)), ColorSequenceKeypoint.new(0.75, rgb(70, 160, 255)), ColorSequenceKeypoint.new(1, rgb(200, 90, 255))})
	local PLAIN = ColorSequence.new(WHITE, rgb(185, 180, 195))

	local board = frame(content, {Name = "Board", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundColor3 = rgb(80, 170, 190),
		ClipsDescendants = true, ZIndex = 2})
	new("UIAspectRatioConstraint", {AspectRatio = AR}, board)
	round(board, 14)
	UI.stroke(board, 4, C.ink)
	grad(board, rgb(160, 200, 255), rgb(255, 255, 255))
	local floor = frame(board, {Position = P(0, H - 0.06), Size = P(1, 0.1), BackgroundColor3 = rgb(90, 70, 60), ZIndex = 2})
	grad(floor, WHITE, rgb(140, 130, 130))
	-- falling things (pooled)
	local items = {}
	for i = 1, 14 do
		local f = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = P(IS, IS), BackgroundTransparency = 1, Visible = false, ZIndex = 4})
		local body = frame(f, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(1, 1), BackgroundColor3 = WHITE, ZIndex = 4})
		local corner = round(body, 0.18)
		UI.stroke(body, 2, C.ink)
		local g = grad(body, WHITE, rgb(185, 180, 195), 45)
		local tape = frame(body, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0), Size = S2(0.22, 1), BackgroundColor3 = rgb(170, 115, 60), ZIndex = 5})
		local fuse = frame(f, {AnchorPoint = V2(0.5, 1), Position = S2(0.62, 0.12), Size = S2(0.12, 0.3), Rotation = 25, BackgroundColor3 = rgb(140, 110, 80), ZIndex = 3})
		local spark = frame(f, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.72, -0.14), Size = S2(0.22, 0.22), BackgroundColor3 = rgb(255, 200, 60), ZIndex = 5})
		round(spark, true)
		local shine = frame(body, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.3, 0.28), Size = S2(0.22, 0.14), Rotation = -30, BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, ZIndex = 6})
		round(shine, true)
		items[i] = {f = f, body = body, corner = corner, g = g, tape = tape, fuse = fuse, spark = spark, live = false}
	end
	-- the basket
	local basket = frame(board, {AnchorPoint = V2(0.5, 0), Size = P(BW, 0.11), BackgroundTransparency = 1, ZIndex = 6})
	local handle = frame(basket, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.05), Size = S2(0.7, 0.5), BackgroundTransparency = 1, ZIndex = 5})
	round(handle, true)
	new("UIStroke", {Thickness = 4, Color = rgb(150, 95, 45)}, handle)
	local bowl = frame(basket, {Position = S2(0, 0.25), Size = S2(1, 0.75), BackgroundColor3 = rgb(220, 160, 80), ZIndex = 6})
	round(bowl, 0.3)
	UI.stroke(bowl, 2.5, C.ink)
	grad(bowl, WHITE, rgb(170, 140, 110))
	for k = 1, 2 do frame(bowl, {Position = S2(0.04, k * 0.3), Size = S2(0.92, 0.1), BackgroundColor3 = rgb(160, 105, 50), ZIndex = 7}) end
	frame(bowl, {Position = S2(-0.03, 0), Size = S2(1.06, 0.22), BackgroundColor3 = rgb(180, 120, 60), ZIndex = 7})
	local bScale = new("UIScale", {}, basket)
	local hearts = {}
	for i = 1, 3 do
		hearts[i] = text(board, "❤", {AnchorPoint = V2(0, 0), Position = P(0.03 + (i - 1) * 0.08, 0.03), Size = P(0.08, 0.08), Stroke = 0, MaxSize = 40,
			TextColor3 = rgb(255, 70, 90), ZIndex = 10})
	end
	local comboT = text(board, "", {AnchorPoint = V2(1, 0), Position = P(0.97, 0.03), Size = P(0.4, 0.07), Stroke = 2.5, MaxSize = 32, TextColor3 = rgb(255, 230, 120),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10})
	local hint = text(board, UI.isTouch and "DRAG THE BASKET" or "DRAG OR A / D", {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.7), Size = S2(0.8, 0.06),
		ZIndex = 10, Stroke = 2.5, MaxSize = 36, TextColor3 = rgb(255, 240, 150)})
	local flash = frame(board, {Size = S2(1, 1), BackgroundColor3 = rgb(255, 60, 40), BackgroundTransparency = 1, ZIndex = 12})
	local shaker = K.makeShaker(board)
	local parts = K.makeParticles(board, 56, 11)
	parts.H = H
	local pops = K.makePopups(board, 8, 13)
	local cd = K.makeCountdown(board, 20)
	local panel = K.makePanel(content, 60)
	local catcher = new("TextButton", {Name = "Drag", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 40}, content)

	local S = {phase = "idle", score = 0, lives = 3, combo = 0, caught = 0, newBest = false, bx = 0.5, tx = 0.5, t = 0, spawnT = 0.6, drag = nil, endT = 0, poll = true}

	local function hud()
		pg.setScore(S.score)
		pg.setBest(bests.Catch)
		for i, h in ipairs(hearts) do h.TextTransparency = (i <= S.lives) and 0 or 0.75 end
		comboT.Text = (S.combo >= 5) and ("x" .. (1 + math.floor(S.combo / 5)) .. " COMBO") or ""
	end
	local function addScore(n)
		S.score = S.score + n
		if S.score > bests.Catch then
			if bests.Catch > 0 and not S.newBest then pops.pop("NEW BEST!", 0.5, 0.2, rgb(255, 220, 80), {h = 0.07, life = 1.4, rise = 0.04}) end
			S.newBest = S.newBest or bests.Catch > 0
			bests.Catch = S.score
		end
		hud()
	end
	local function spawnItem()
		local it
		for _, k in ipairs(items) do if not k.live then it = k break end end
		if not it then return end
		local prog = clamp(S.t / 90, 0, 1)
		local r = math.random()
		local kind = (r < 0.14 + prog * 0.12) and "bomb" or ((r < 0.2 + prog * 0.12) and "rainbow" or ((r < 0.3 + prog * 0.12) and "diamond"
			or ((r < 0.45 + prog * 0.12) and "gold" or "box")))
		local spec = KINDS[kind]
		it.kind, it.live = kind, true
		it.x, it.y = 0.08 + math.random() * 0.84, -0.1
		it.vy = (0.42 + prog * 0.7) * (0.85 + math.random() * 0.3)
		it.rs = (math.random() * 2 - 1) * 120
		it.body.BackgroundColor3 = rgb(spec.c[1], spec.c[2], spec.c[3])
		it.g.Color = (kind == "rainbow") and RAINBOW or PLAIN
		it.corner.CornerRadius = (kind == "bomb") and UDim.new(1, 0) or UDim.new(0.18, 0)
		it.body.Rotation = (kind == "diamond") and 45 or 0
		it.body.Size = (kind == "diamond") and S2(0.78, 0.78) or S2(1, 1)
		it.tape.Visible = kind == "box" or kind == "gold"
		it.tape.BackgroundColor3 = (kind == "gold") and rgb(220, 150, 20) or rgb(170, 115, 60)
		it.fuse.Visible, it.spark.Visible = kind == "bomb", kind == "bomb"
		it.f.Rotation = 0
		it.f.Visible = true
	end
	local function release(it)
		it.live = false
		it.f.Visible = false
	end
	local function showOver()
		S.phase = "over"
		panel.show({title = "OUT OF LIVES!", color = rgb(30, 150, 140),
			lines = "Score  " .. S.score .. "\nBoxes caught  " .. S.caught .. "\nBest  " .. bests.Catch,
			best = S.newBest, a = "PLAY AGAIN", onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
	end
	local function caught(it)
		release(it)
		local spec = KINDS[it.kind]
		if it.kind == "bomb" then
			S.lives, S.combo = S.lives - 1, 0
			flash.BackgroundTransparency = 0.3
			shaker.kick(0.035, 0.45)
			parts.burst(it.x, it.y, {rgb(255, 140, 40), rgb(255, 220, 60), rgb(60, 60, 70)}, 24, 0.7, 0.04)
			pops.pop("BOOM!", it.x, it.y / H - 0.08, rgb(255, 120, 60), {h = 0.08, w = 0.5})
			UI.SFX.play("error")
			hud()
			if S.lives <= 0 then
				S.phase, S.endT = "end", 0
				for _, k in ipairs(items) do release(k) end
			end
			return
		end
		S.combo, S.caught = S.combo + 1, S.caught + 1
		local pts = spec.pts * (1 + math.floor(S.combo / 5))
		addScore(pts)
		bScale.Scale = 1.18
		local col = rgb(spec.c[1], spec.c[2], spec.c[3])
		local big = spec.pts >= 5
		parts.burst(it.x, BY, big and {rgb(255, 80, 80), rgb(255, 220, 60), rgb(80, 230, 110), rgb(70, 160, 255)} or {col, WHITE}, big and 20 or 8, big and 0.6 or 0.35, 0.025,
			{rect = true, spin = 250})
		pops.pop("+" .. pts, it.x, BY / H - 0.07, big and rgb(255, 220, 60) or C.money, {h = big and 0.07 or 0.055, w = 0.35})
		if S.combo % 10 == 0 then pops.pop(S.combo .. " IN A ROW!", 0.5, 0.35, rgb(140, 230, 255), {h = 0.07, life = 1.1}) end
		UI.SFX.play(big and "ding" or "click", big and 1.6 or 2.4, 0.35)
	end

	function app.start()
		for _, it in ipairs(items) do release(it) end
		S.score, S.lives, S.combo, S.caught, S.newBest, S.bx, S.tx, S.t, S.spawnT, S.drag = 0, 3, 0, 0, false, 0.5, 0.5, 0, 0.6, nil
		flash.BackgroundTransparency = 1
		parts.clear()
		pops.clear()
		panel.hide()
		hint.Visible = true
		hud()
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
		S.drag = nil
		if S.phase == "play" or S.phase == "count" then
			S.phase = "paused"
			cd.stop()
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Score  " .. S.score .. "\nBest  " .. bests.Catch,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		local d = K.dirKey(kc)
		if d == "Left" or d == "Right" then
			if not S.poll then S.tx = clamp(S.tx + (d == "Left" and -0.15 or 0.15), BW / 2, 1 - BW / 2) end
			return
		end
		if kc == Enum.KeyCode.P then
			if S.phase == "paused" then resume() else app.leave() end
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return then
			if S.phase == "over" then app.start() elseif S.phase == "paused" then resume() end
		end
	end
	local function dragTo(input)
		local fx = K.fracIn(board, K.posOf(input))
		S.tx = clamp(fx, BW / 2, 1 - BW / 2)
		hint.Visible = false
	end
	catcher.InputBegan:Connect(function(input)
		if not K.isPress(input) then return end
		S.drag = {input = input, mouse = input.UserInputType == Enum.UserInputType.MouseButton1}
		dragTo(input)
	end)
	function app.move(input)
		local dr = S.drag
		if dr and ((dr.mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or input == dr.input) then dragTo(input) end
	end
	function app.release(input)
		local dr = S.drag
		if dr and ((dr.mouse and input.UserInputType == Enum.UserInputType.MouseButton1) or input == dr.input) then S.drag = nil end
	end
	function app.layout(_wide)
		shaker.setBase(S2(0.5, 0.5))
	end
	local function held(a, b)
		local ok, down = pcall(function() return UIS:IsKeyDown(a) or UIS:IsKeyDown(b) end)
		if not ok then S.poll = false end
		return ok and down == true
	end

	function app.step(dt)
		parts.update(dt)
		pops.update(dt)
		shaker.update(dt)
		local counting = cd.update(dt)
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 2.5)
		bScale.Scale = lerp(bScale.Scale, 1, clamp(dt * 10, 0, 1))
		if S.phase == "paused" or S.phase == "idle" then return end
		if S.phase == "count" and not counting then S.phase = "play" end
		-- the basket: keys move it, a drag puts it under the finger
		if S.poll and (S.phase == "play" or S.phase == "count") then
			local dir = (held(Enum.KeyCode.A, Enum.KeyCode.Left) and -1 or 0) + (held(Enum.KeyCode.D, Enum.KeyCode.Right) and 1 or 0)
			if dir ~= 0 then
				S.tx = clamp(S.tx + dir * 1.3 * dt, BW / 2, 1 - BW / 2)
				hint.Visible = false
			end
		end
		local prev = S.bx
		S.bx = lerp(S.bx, S.tx, clamp(dt * 18, 0, 1))
		basket.Position = P(S.bx, BY)
		basket.Rotation = clamp((S.bx - prev) / math.max(dt, 0.001) * 6, -10, 10)
		if S.phase == "play" then
			S.t = S.t + dt
			S.spawnT = S.spawnT - dt
			if S.spawnT <= 0 then
				S.spawnT = math.max(0.32, 0.9 - S.t * 0.008) * (0.75 + math.random() * 0.5)
				spawnItem()
			end
		end
		for _, it in ipairs(items) do
			if it.live then
				if S.phase == "play" then
					local prevY = it.y
					it.y = it.y + it.vy * dt
					if prevY < BY and it.y >= BY - 0.01 and math.abs(it.x - S.bx) < BW / 2 + IS * 0.3 then
						caught(it)
					elseif it.y > H + 0.1 then
						if it.kind ~= "bomb" then
							S.combo = 0
							hud()
						end
						release(it)
					end
				end
				if it.live then
					it.f.Position = P(it.x, it.y)
					it.f.Rotation = it.f.Rotation + it.rs * dt * ((S.phase == "play") and 1 or 0)
					if it.kind == "rainbow" then it.g.Rotation = (S.t * 200) % 360 end
					if it.kind == "bomb" then it.spark.BackgroundTransparency = 0.5 + math.sin(S.t * 30) * 0.5 end
				end
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
	local bowl = K.frame(b, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.6), Size = S2(0.66, 0.26), BackgroundColor3 = rgb(220, 160, 80), ZIndex = 4})
	K.round(bowl, 0.3)
	K.UI.stroke(bowl, 1.5, K.C.ink)
	for k, spec in ipairs({{0.32, 0.22, rgb(255, 205, 50)}, {0.62, 0.36, rgb(90, 220, 255)}}) do
		local f = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(spec[1], spec[2]), Size = S2(0.22, 0.22), Rotation = k * 20, BackgroundColor3 = spec[3], ZIndex = 3})
		K.round(f, 0.2)
		K.UI.stroke(f, 1.5, K.C.ink)
	end
end

return {build = build, drawIcon = drawIcon}
