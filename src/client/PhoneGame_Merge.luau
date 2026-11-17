--[[ BOX MERGE (phone game): 2048 with boxes. Swipe, arrow keys or WASD slide every tile; two equal
     tiles that bump merge into the next one up. Game over when nothing can move. ]]

local N, GAP, ANIM = 4, 0.024, 0.11
local CS = (1 - (N + 1) * GAP) / N
local LOOK = {
	[2] = {255, 236, 205, "📦"}, [4] = {255, 212, 150, "🎁"}, [8] = {255, 172, 92, "🧸"}, [16] = {255, 128, 80, "🎮"},
	[32] = {255, 92, 110, "💎"}, [64] = {240, 70, 160, "👑"}, [128] = {190, 90, 255, "🚀"}, [256] = {120, 110, 255, "🌟"},
	[512] = {60, 160, 255, "🏆"}, [1024] = {40, 210, 200, "🦄"}, [2048] = {255, 210, 40, "🐉"},
}
local DIRS = {Up = {-1, 0}, Down = {1, 0}, Left = {0, -1}, Right = {0, 1}}
local function cellPos(r, c) return GAP + (c - 1) * (CS + GAP) + CS / 2, GAP + (r - 1) * (CS + GAP) + CS / 2 end
local function order(d)
	if d == 1 then return {4, 3, 2, 1} end
	return {1, 2, 3, 4}
end

local function build(env)
	local K = env.kit
	local UI, C, new, rgb, V2, S2, WHITE = K.UI, K.C, K.new, K.rgb, K.V2, K.S2, K.WHITE
	local lerp, frame, round, grad, text = K.lerp, K.frame, K.round, K.grad, K.text
	local bests = K.bests
	local pg = env.page("Merge", {title = "Box Merge", color = rgb(230, 80, 160), bg0 = rgb(120, 50, 110), bg1 = rgb(36, 14, 40)})
	local content = pg.content
	local app = {}

	local board = frame(content, {Name = "Board", AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.45), Size = S2(0.98, 0.86), BackgroundColor3 = rgb(150, 110, 150), ZIndex = 2})
	K.square(board)
	round(board, 14)
	UI.stroke(board, 4, C.ink)
	grad(board, WHITE, rgb(170, 160, 185))
	for r = 1, N do
		for c = 1, N do
			local x, y = cellPos(r, c)
			local slot = frame(board, {AnchorPoint = V2(0.5, 0.5), Position = S2(x, y), Size = S2(CS, CS), BackgroundColor3 = rgb(90, 60, 100), BackgroundTransparency = 0.3, ZIndex = 2})
			round(slot, 0.16)
		end
	end
	-- tiles (pooled: 16 on the board + the ones sliding into a merge)
	local pool = {}
	for i = 1, 24 do
		local f = frame(board, {AnchorPoint = V2(0.5, 0.5), Size = S2(CS, CS), BackgroundColor3 = WHITE, Visible = false, ZIndex = 4})
		round(f, 0.16)
		local st = UI.stroke(f, 2.5, C.ink)
		grad(f, WHITE, rgb(195, 190, 205))
		local emo = text(f, "", {Position = S2(0.15, 0.05), Size = S2(0.7, 0.52), Stroke = 0, MaxSize = 70, ZIndex = 5})
		local num = text(f, "", {Position = S2(0.05, 0.56), Size = S2(0.9, 0.38), Stroke = 2, MaxSize = 44, ZIndex = 5})
		pool[i] = {f = f, st = st, emo = emo, num = num, sc = new("UIScale", {}, f), used = false}
	end
	local hint = UI.label(content, UI.isTouch and "Swipe to slide the boxes" or "Swipe, arrows or WASD.  P = pause",
		{AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.95), Size = S2(0.95, 0.07), Max = 20, Min = 8, Stroke = 2, TextColor3 = rgb(255, 210, 240)})
	local shaker = K.makeShaker(board)
	local parts = K.makeParticles(board, 48, 9)
	local pops = K.makePopups(board, 6, 10)
	local panel = K.makePanel(content, 60)
	local catcher = new("TextButton", {Name = "Swipe", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = S2(1, 1), ZIndex = 40}, content)

	local S = {phase = "idle", grid = {}, live = {}, score = 0, moves = 0, newBest = false, anim = false, animT = 0, overT = 0, top = 2, won = false, swipe = nil}

	local function look(t, v)
		t.shown = v
		local L = LOOK[v] or {60, 60, 80, "🌈"}
		local col = rgb(L[1], L[2], L[3])
		t.f.BackgroundColor3 = col
		t.st.Color = col:Lerp(C.ink, 0.7)
		t.emo.Text = L[4]
		t.num.Text = tostring(v)
		t.num.TextColor3 = (v <= 4) and rgb(120, 70, 40) or WHITE
	end
	local function hud()
		pg.setScore(S.score)
		pg.setBest(bests.Merge)
	end
	local function newTile(r, c, v)
		local t
		for _, p in ipairs(pool) do if not p.used then t = p break end end
		if not t then return nil end
		t.used, t.v, t.r, t.c, t.fr, t.fc, t.dying, t.merged = true, v, r, c, r, c, false, false
		look(t, v)
		local x, y = cellPos(r, c)
		t.f.Position, t.f.Visible, t.f.ZIndex = S2(x, y), true, 4
		t.sc.Scale = 0
		S.grid[r][c] = t
		table.insert(S.live, t)
		return t
	end
	local function spawn()
		local free = {}
		for r = 1, N do for c = 1, N do if not S.grid[r][c] then table.insert(free, {r, c}) end end end
		if #free == 0 then return end
		local p = free[math.random(1, #free)]
		newTile(p[1], p[2], (math.random() < 0.1 + math.min(0.15, S.moves * 0.0006)) and 4 or 2)
	end
	local function stuck()
		for r = 1, N do
			for c = 1, N do
				local t = S.grid[r][c]
				if not t then return false end
				local rt, dn = S.grid[r][c + 1], S.grid[r + 1] and S.grid[r + 1][c]
				if (rt and rt.v == t.v) or (dn and dn.v == t.v) then return false end
			end
		end
		return true
	end
	local function showOver()
		S.phase = "over"
		panel.show({title = "NO MOVES!", color = rgb(210, 60, 140),
			lines = "Score  " .. S.score .. "\nBest tile  " .. S.top .. "\nBest  " .. bests.Merge,
			best = S.newBest, a = "PLAY AGAIN", onA = function() app.start() end, b = "Home", onB = function() env.goHome() end})
	end
	-- the slide is over: merged tiles show their new value and pop, a new tile appears
	local function finishAnim()
		if not S.anim then return end
		S.anim = false
		local keep = {}
		for _, t in ipairs(S.live) do
			local x, y = cellPos(t.r, t.c)
			t.f.Position = S2(x, y)
			if t.dying then
				t.used, t.f.Visible = false, false
			else
				table.insert(keep, t)
				if t.shown ~= t.v then
					look(t, t.v)
					t.sc.Scale = 1.25
					t.f.ZIndex = 6
					parts.burst(x, y, {t.f.BackgroundColor3, WHITE}, t.v >= 64 and 16 or 7, t.v >= 64 and 0.5 or 0.3, 0.025, {rect = true, spin = 200})
					if t.v >= 32 then pops.pop("+" .. t.v, x, y - CS * 0.4, rgb(255, 230, 120), {h = 0.07, w = 0.4}) end
					if t.v > S.top then S.top = t.v end
					if t.v == 2048 and not S.won then
						S.won = true
						pops.pop("2048! DRAGON BOX!", 0.5, 0.45, rgb(255, 220, 60), {h = 0.12, life = 2, rise = 0.04})
						shaker.kick(0.02, 0.4)
					end
				end
			end
		end
		S.live = keep
		spawn()
		if stuck() then
			S.phase, S.overT = "stuck", 0
			shaker.kick(0.025, 0.4)
			UI.SFX.play("error")
		end
	end
	local function doMove(dir)
		if S.phase ~= "play" then return end
		finishAnim()
		if S.phase ~= "play" then return end
		local dr, dc = DIRS[dir][1], DIRS[dir][2]
		local moved, merges, gained = false, 0, 0
		for _, t in ipairs(S.live) do
			t.fr, t.fc, t.merged = t.r, t.c, false
			t.f.ZIndex = 4
		end
		for _, r in ipairs(order(dr)) do
			for _, c in ipairs(order(dc)) do
				local t = S.grid[r][c]
				if t then
					local nr, nc, target = r, c, nil
					while true do
						local tr, tc = nr + dr, nc + dc
						if tr < 1 or tr > N or tc < 1 or tc > N then break end
						local o = S.grid[tr][tc]
						if not o then
							nr, nc = tr, tc
						else
							if o.v == t.v and not o.merged then target = o end
							break
						end
					end
					if target then
						S.grid[r][c] = nil
						t.r, t.c, t.dying = target.r, target.c, true
						t.f.ZIndex = 3
						target.v, target.merged = target.v * 2, true
						gained, merges, moved = gained + target.v, merges + 1, true
					elseif nr ~= r or nc ~= c then
						S.grid[r][c] = nil
						S.grid[nr][nc] = t
						t.r, t.c, moved = nr, nc, true
					end
				end
			end
		end
		if not moved then
			shaker.kick(0.008, 0.15)
			return
		end
		S.moves = S.moves + 1
		S.anim, S.animT = true, 0
		if gained > 0 then
			S.score = S.score + gained
			if S.score > bests.Merge then
				if bests.Merge > 0 and not S.newBest then pops.pop("NEW BEST!", 0.5, 0.12, rgb(255, 220, 80), {h = 0.09, life = 1.4, rise = 0.04}) end
				S.newBest = S.newBest or bests.Merge > 0
				bests.Merge = S.score
			end
			hud()
			if merges >= 3 then pops.pop(merges .. "x MERGE!", 0.5, 0.5, rgb(140, 230, 255), {h = 0.1, life = 1}) end
			UI.SFX.play("ding", 1.1 + math.min(merges, 4) * 0.15, 0.35)
		else
			UI.SFX.play("click", 2.4, 0.25)
		end
	end

	function app.start()
		for _, p in ipairs(pool) do
			p.used = false
			p.f.Visible = false
		end
		S.grid, S.live = {}, {}
		for r = 1, N do S.grid[r] = {} end
		S.score, S.moves, S.newBest, S.anim, S.top, S.won, S.swipe = 0, 0, false, false, 2, false, nil
		parts.clear()
		pops.clear()
		panel.hide()
		spawn()
		spawn()
		hud()
		S.phase = "play"
	end
	local function resume()
		panel.hide()
		S.phase = "play"
	end
	function app.enter()
		if S.phase == "paused" then return end
		app.start()
	end
	function app.leave()
		S.swipe = nil
		if S.phase == "play" then
			S.phase = "paused"
			panel.show({title = "PAUSED", color = rgb(60, 120, 220), lines = "Score  " .. S.score .. "\nBest  " .. bests.Merge,
				a = "RESUME", onA = resume, b = "Restart", onB = function() app.start() end})
		end
	end
	function app.key(kc)
		local d = K.dirKey(kc)
		if d then doMove(d) return end
		if kc == Enum.KeyCode.P then
			if S.phase == "paused" then resume() else app.leave() end
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return then
			if S.phase == "over" then app.start() elseif S.phase == "paused" then resume() end
		end
	end
	-- swipes: one move per swipe, as soon as the finger has gone far enough
	local function swipeTo(p, final)
		local sw = S.swipe
		if not sw then return end
		local d = p - sw.origin
		if d.Magnitude < math.max(12, board.AbsoluteSize.X * (final and 0.04 or 0.07)) then return end
		S.swipe = nil
		if math.abs(d.X) > math.abs(d.Y) then doMove(d.X > 0 and "Right" or "Left") else doMove(d.Y > 0 and "Down" or "Up") end
	end
	catcher.InputBegan:Connect(function(input)
		if K.isPress(input) then S.swipe = {input = input, origin = K.posOf(input), mouse = input.UserInputType == Enum.UserInputType.MouseButton1} end
	end)
	function app.move(input)
		local sw = S.swipe
		if sw and ((sw.mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or input == sw.input) then swipeTo(K.posOf(input), false) end
	end
	function app.release(input)
		local sw = S.swipe
		if sw and ((sw.mouse and input.UserInputType == Enum.UserInputType.MouseButton1) or input == sw.input) then
			swipeTo(K.posOf(input), true)
			S.swipe = nil
		end
	end
	function app.layout(wide)
		if wide then
			board.Size = S2(0.98, 0.98)
			shaker.setBase(S2(0.5, 0.5))
		else
			board.Size = S2(0.98, 0.86)
			shaker.setBase(S2(0.5, 0.45))
		end
		hint.Visible = not wide
	end

	function app.step(dt)
		parts.update(dt)
		pops.update(dt)
		shaker.update(dt)
		if S.phase == "paused" or S.phase == "idle" then return end
		if S.anim then
			S.animT = S.animT + dt
			local e = K.easeOut(S.animT / ANIM)
			for _, t in ipairs(S.live) do
				local x0, y0 = cellPos(t.fr, t.fc)
				local x1, y1 = cellPos(t.r, t.c)
				t.f.Position = S2(lerp(x0, x1, e), lerp(y0, y1, e))
			end
			if S.animT >= ANIM then finishAnim() end
		end
		for _, t in ipairs(S.live) do
			if t.sc.Scale ~= 1 then
				t.sc.Scale = (t.sc.Scale < 1) and math.min(1, t.sc.Scale + dt * 7) or math.max(1, t.sc.Scale - dt * 2.5)
			end
		end
		if S.phase == "stuck" then
			S.overT = S.overT + dt
			if S.overT > 0.9 then showOver() end
		end
	end
	return app
end

local function drawIcon(b, K)
	local rgb, S2, V2 = K.rgb, K.S2, K.V2
	local cols = {{rgb(255, 236, 205), rgb(255, 172, 92)}, {rgb(255, 92, 110), rgb(190, 90, 255)}}
	local nums = {{"2", "8"}, {"32", "128"}}
	for r = 1, 2 do
		for c = 1, 2 do
			local f = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.3 + (c - 1) * 0.4, 0.3 + (r - 1) * 0.4), Size = S2(0.36, 0.36), BackgroundColor3 = cols[r][c], ZIndex = 3})
			K.round(f, 0.2)
			K.UI.stroke(f, 1.5, K.C.ink)
			K.text(f, nums[r][c], {Position = S2(0.1, 0.15), Size = S2(0.8, 0.7), Stroke = 1.5, MaxSize = 30, ZIndex = 4})
		end
	end
end

return {build = build, drawIcon = drawIcon}
