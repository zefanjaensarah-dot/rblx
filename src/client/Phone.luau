--[[ STEAL A BOX - the big phone on your treadmill: press E and play while you run.
     Snake        arrow keys / WASD / swipe / buttons. Eat apples, don't hit yourself or the walls.
     Block Blast  DRAG a piece onto the board. Full rows and columns clear (combos score more).
     Archery      press and pull BACK (like a slingshot): the further, the stronger. Hit the dummies!
     While the phone is open your character doesn't walk with the arrow keys / WASD. ]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Phone = {}

-- the mouse / finger position in the same space as AbsolutePosition
local function pointer()
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end
-- where the pointer is inside `frame`, as fractions 0..1
local function relative(frame)
	local m, p, s = pointer(), frame.AbsolutePosition, frame.AbsoluteSize
	if s.X < 1 or s.Y < 1 then return 0.5, 0.5 end
	return (m.X - p.X) / s.X, (m.Y - p.Y) / s.Y
end
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

------------------------------------------------------------------
-- SNAKE
------------------------------------------------------------------
local function buildSnake(env)
	local UI, C, new, frame = env.UI, env.UI.C, env.UI.new, env.frame
	local G = 15
	local S = env.page("Snake")
	local area = env.board(S.frame, 0.08, 0.62)
	-- a checkered grass board
	for x = 0, G - 1 do
		for y = 0, G - 1 do
			frame(area, {Size = UDim2.fromScale(1 / G, 1 / G), Position = UDim2.fromScale(x / G, y / G),
				BackgroundColor3 = ((x + y) % 2 == 0) and UI.rgb(120, 200, 70) or UI.rgb(105, 185, 60)})
		end
	end
	local over = env.overText(area)
	local dirs = {Up = Vector2.new(0, -1), Down = Vector2.new(0, 1), Left = Vector2.new(-1, 0), Right = Vector2.new(1, 0)}
	local snake, dir, nextDir, food, acc, alive, score, best = {}, dirs.Right, dirs.Right, nil, 0, false, 0, 0
	local segs = {}
	local apple = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1.3 / G, 1.3 / G), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "🍎", TextScaled = true, ZIndex = 5}, area)
	local function cellPos(p) return UDim2.fromScale((p.X + 0.5) / G, (p.Y + 0.5) / G) end
	local function seg(i)
		if not segs[i] then
			local f = frame(area, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.92 / G, 0.92 / G), BackgroundColor3 = UI.rgb(60, 120, 255), ZIndex = 4})
			UI.corner(f, 6)
			new("UIGradient", {Rotation = 90, Color = ColorSequence.new(UI.rgb(255, 255, 255), UI.rgb(190, 190, 200))}, f)
			UI.stroke(f, 1.5, UI.rgb(30, 50, 140))
			segs[i] = f
		end
		return segs[i]
	end
	-- the head has eyes that look where it's going
	local head = seg(1)
	head.BackgroundColor3 = UI.rgb(80, 150, 255)
	local eyes = {}
	for k = 1, 2 do
		local e = frame(head, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.34, 0.34), BackgroundColor3 = C.white, ZIndex = 5})
		UI.corner(e, true)
		local pupil = frame(e, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.6, 0.5), Size = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.black, ZIndex = 6})
		UI.corner(pupil, true)
		eyes[k] = {e = e, pupil = pupil}
	end
	local function draw()
		for i = 1, math.max(#snake, #segs) do
			local p = snake[i]
			if p then
				local f = seg(i)
				f.Visible = true
				f.Position = cellPos(p)
				if i > 1 then f.BackgroundColor3 = UI.rgb(60, 120, 255):Lerp(UI.rgb(40, 200, 255), (i % 4) / 6) end
			elseif segs[i] then
				segs[i].Visible = false
			end
		end
		-- eyes: side by side, across the direction it moves
		local side = Vector2.new(-dir.Y, dir.X)
		for k, e in ipairs(eyes) do
			local o = dir * 0.18 + side * ((k == 1) and -0.2 or 0.2)
			e.e.Position = UDim2.fromScale(0.5 + o.X, 0.5 + o.Y)
			e.pupil.Position = UDim2.fromScale(0.5 + dir.X * 0.2, 0.5 + dir.Y * 0.2)
		end
		apple.Position = cellPos(food)
	end
	local function placeFood()
		repeat
			food = Vector2.new(math.random(0, G - 1), math.random(0, G - 1))
			local onSnake = false
			for _, p in ipairs(snake) do if p == food then onSnake = true end end
		until not onSnake
	end
	local function hud() env.score("Score " .. score .. "   Best " .. best) end
	S.start = function()
		snake = {Vector2.new(5, 7), Vector2.new(4, 7), Vector2.new(3, 7)}
		dir, nextDir, acc, alive, score = dirs.Right, dirs.Right, 0, true, 0
		over.Visible = false
		placeFood()
		draw()
		hud()
		env.setStep(function(dt)
			if not alive then return end
			acc = acc + dt
			if acc < math.max(0.07, 0.16 - score * 0.004) then return end -- faster and faster
			acc = 0
			if (nextDir + dir).Magnitude > 0.5 then dir = nextDir end -- (no turning straight back)
			local h = snake[1] + dir
			local hit = h.X < 0 or h.Y < 0 or h.X >= G or h.Y >= G
			for i = 1, #snake - 1 do if snake[i] == h then hit = true end end
			if hit then
				alive = false
				best = math.max(best, score)
				hud()
				over.Visible = true
				UI.setText(over, "Game over! Score " .. score .. "\nTap to play again")
				UI.SFX.play("error")
				return
			end
			table.insert(snake, 1, h)
			if h == food then
				score = score + 1
				best = math.max(best, score)
				hud()
				UI.SFX.play("click", 2.6, 0.35)
				placeFood()
			else
				table.remove(snake)
			end
			draw()
		end)
	end
	-- buttons under the board
	for name, pos in pairs({Up = {0.5, 0.75}, Left = {0.26, 0.84}, Right = {0.74, 0.84}, Down = {0.5, 0.93}}) do
		local b = UI.button(S.frame, {Text = ({Up = "^", Down = "v", Left = "<", Right = ">"})[name], Color = C.blue, Size = UDim2.fromOffset(84, 46),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(pos[1], pos[2]), TextSize = 28, Depth = 4, ZIndex = 4})
		b.Activated:Connect(function() nextDir = dirs[name] end)
	end
	-- swipe on the board (phones) / tap to restart
	local pad = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 7}, area)
	local swipeFrom = nil
	pad.MouseButton1Down:Connect(function() swipeFrom = pointer() end)
	pad.Activated:Connect(function()
		if not alive and env.current() == "Snake" then S.start() end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not swipeFrom or not isPress(input) then return end
		local d = pointer() - swipeFrom
		swipeFrom = nil
		if d.Magnitude < 20 then return end
		if math.abs(d.X) > math.abs(d.Y) then nextDir = (d.X > 0) and dirs.Right or dirs.Left
		else nextDir = (d.Y > 0) and dirs.Down or dirs.Up end
	end)
	local KEYS = {[Enum.KeyCode.Up] = "Up", [Enum.KeyCode.W] = "Up", [Enum.KeyCode.Down] = "Down", [Enum.KeyCode.S] = "Down",
		[Enum.KeyCode.Left] = "Left", [Enum.KeyCode.A] = "Left", [Enum.KeyCode.Right] = "Right", [Enum.KeyCode.D] = "Right"}
	UserInputService.InputBegan:Connect(function(input)
		if env.current() == "Snake" and env.isOpen() and KEYS[input.KeyCode] then nextDir = dirs[KEYS[input.KeyCode]] end
	end)
end

------------------------------------------------------------------
-- BLOCK BLAST: drag pieces onto an 8x8 board
------------------------------------------------------------------
local function buildBlast(env)
	local UI, C, new, frame = env.UI, env.UI.C, env.UI.new, env.frame
	local N = 8
	local B = env.page("BlockBlast")
	local area = env.board(B.frame, 0.08, 0.6)
	area.BackgroundColor3 = UI.rgb(28, 32, 58)
	local over = env.overText(area)
	local SHAPES = {
		{{0, 0}}, {{0, 0}, {1, 0}}, {{0, 0}, {0, 1}}, {{0, 0}, {1, 0}, {2, 0}}, {{0, 0}, {0, 1}, {0, 2}},
		{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, {{0, 0}, {0, 1}, {1, 1}}, {{1, 0}, {0, 1}, {1, 1}}, {{0, 0}, {1, 0}, {1, 1}},
		{{0, 0}, {1, 0}, {2, 0}, {3, 0}}, {{0, 0}, {0, 1}, {0, 2}, {0, 3}}, {{0, 0}, {1, 0}, {2, 0}, {1, 1}},
		{{0, 0}, {0, 1}, {0, 2}, {1, 2}}, {{0, 0}, {1, 0}, {2, 0}, {0, 1}, {1, 1}, {2, 1}}, {{0, 0}, {1, 0}, {2, 0}, {0, 1}, {1, 1}, {2, 1}, {0, 2}, {1, 2}, {2, 2}},
	}
	local COLORS = {UI.rgb(255, 80, 90), UI.rgb(255, 170, 40), UI.rgb(255, 225, 60), UI.rgb(80, 210, 90), UI.rgb(60, 160, 255), UI.rgb(170, 100, 255), UI.rgb(255, 110, 200)}
	local EMPTY = UI.rgb(44, 50, 84)
	-- one block: a bevelled square (lighter top, darker bottom)
	local function block(parent, color, size, pos, z)
		local f = frame(parent, {Size = size, Position = pos, BackgroundColor3 = color, ZIndex = z or 4})
		UI.corner(f, 5)
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(UI.rgb(255, 255, 255), UI.rgb(175, 175, 185))}, f)
		return f
	end
	local grid, tiles, hand, score, best = {}, {}, {}, 0, 0
	for x = 0, N - 1 do
		for y = 0, N - 1 do
			local t = block(area, EMPTY, UDim2.fromScale(0.92 / N, 0.92 / N), UDim2.fromScale((x + 0.04) / N, (y + 0.04) / N), 3)
			tiles[x * N + y] = t
		end
	end
	local function fits(shape, ox, oy)
		for _, c in ipairs(shape) do
			local x, y = ox + c[1], oy + c[2]
			if x < 0 or y < 0 or x >= N or y >= N or grid[x * N + y] then return false end
		end
		return true
	end
	local function paint(preview)
		for k, t in pairs(tiles) do t.BackgroundColor3 = grid[k] or EMPTY end
		if preview then
			for _, k in ipairs(preview.cells) do
				if tiles[k] then tiles[k].BackgroundColor3 = preview.ok and preview.color:Lerp(C.white, 0.35) or UI.rgb(200, 60, 70) end
			end
		end
	end
	local slots = {}
	local function drawHand()
		for i, slot in ipairs(slots) do
			for _, c in ipairs(slot.cells) do c:Destroy() end
			slot.cells = {}
			local h = hand[i]
			if h and not h.used then
				for _, c in ipairs(h.shape) do
					table.insert(slot.cells, block(slot.face, h.color, UDim2.fromScale(0.19, 0.19), UDim2.fromScale(0.05 + c[1] * 0.2, 0.05 + c[2] * 0.2), 5))
				end
			end
		end
	end
	local function deal()
		for i = 1, 3 do hand[i] = {shape = SHAPES[math.random(1, #SHAPES)], color = COLORS[math.random(1, #COLORS)]} end
		drawHand()
	end
	local function canPlaceAny()
		for _, h in ipairs(hand) do
			if not h.used then
				for x = 0, N - 1 do for y = 0, N - 1 do if fits(h.shape, x, y) then return true end end end
			end
		end
		return false
	end
	local function hud() env.score("Score " .. score .. "   Best " .. best) end
	-- a floating "+20 COMBO!" over the board
	local function popText(str, color)
		local l = UI.label(area, str, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.9, 0.18), Max = 44,
			Stroke = 3, TextColor3 = color, ZIndex = 9, TextWrapped = false})
		local sc = new("UIScale", {Scale = 0.4}, l)
		UI.tween(sc, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
		UI.tween(l, 0.9, {Position = UDim2.fromScale(0.5, 0.3)})
		task.delay(0.9, function() l:Destroy() end)
	end
	local function place(h, ox, oy)
		for _, c in ipairs(h.shape) do grid[(ox + c[1]) * N + oy + c[2]] = h.color end
		score = score + #h.shape
		h.used = true
		-- full rows / columns clear (flash white first)
		local clear, lines = {}, 0
		for k = 0, N - 1 do
			local row, col = true, true
			for j = 0, N - 1 do
				if not grid[j * N + k] then row = false end
				if not grid[k * N + j] then col = false end
			end
			if row then lines = lines + 1 for j = 0, N - 1 do clear[j * N + k] = true end end
			if col then lines = lines + 1 for j = 0, N - 1 do clear[k * N + j] = true end end
		end
		paint()
		if lines > 0 then
			for key in pairs(clear) do
				grid[key] = nil
				tiles[key].BackgroundColor3 = C.white
			end
			task.delay(0.15, function() paint() end)
			local gain = lines * 10 * lines -- 2 lines = 40, 3 lines = 90 ...
			score = score + gain
			popText(lines > 1 and ("+" .. gain .. " COMBO x" .. lines .. "!") or ("+" .. gain), lines > 1 and C.yellow or C.money)
			UI.SFX.play("ding", 1.4 + lines * 0.15, 0.5)
		else
			UI.SFX.play("click", 2.2, 0.35)
		end
		best = math.max(best, score)
		hud()
		if hand[1].used and hand[2].used and hand[3].used then deal() else drawHand() end
		if not canPlaceAny() then
			over.Visible = true
			UI.setText(over, "No room left! Score " .. score .. "\nTap to play again")
		end
	end
	-- DRAGGING: a copy of the piece follows your finger, the board shows where it would land
	local drag = nil -- {index, ghost}
	local ghostHolder = frame(B.frame, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10})
	local function landing(h)
		-- the piece's top-left block sits at the ghost's top-left
		local fx, fy = relative(area)
		local w = 0
		for _, c in ipairs(h.shape) do w = math.max(w, c[1]) end
		-- the ghost is drawn a little ABOVE your finger so you can see it
		local ox = math.floor(fx * N - (w + 1) / 2 + 0.5)
		local oy = math.floor(fy * N - 2.2 + 0.5)
		return ox, oy
	end
	for i = 1, 3 do
		local face = new("TextButton", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.18 + (i - 1) * 0.32, 0.74), Size = UDim2.fromScale(0.27, 0.2),
			BackgroundColor3 = UI.rgb(36, 40, 70), Text = "", AutoButtonColor = false, ZIndex = 4}, B.frame)
		new("UIAspectRatioConstraint", {AspectRatio = 1}, face)
		UI.corner(face, 8)
		UI.stroke(face, 2.5)
		slots[i] = {face = face, cells = {}}
		face.MouseButton1Down:Connect(function()
			local h = hand[i]
			if not h or h.used or over.Visible then return end
			-- the ghost: board-sized blocks
			local cell = area.AbsoluteSize.X / N
			local g = frame(ghostHolder, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 10})
			for _, c in ipairs(h.shape) do
				block(g, h.color, UDim2.fromOffset(cell * 0.92, cell * 0.92), UDim2.fromOffset(c[1] * cell, c[2] * cell), 11).BackgroundTransparency = 0.15
			end
			drag = {index = i, ghost = g, cell = cell}
			for _, c in ipairs(slots[i].cells) do c.Visible = false end
		end)
	end
	UserInputService.InputEnded:Connect(function(input)
		if not drag or not isPress(input) then return end
		local d = drag
		drag = nil
		d.ghost:Destroy()
		local h = hand[d.index]
		if h and not h.used then
			local ox, oy = landing(h)
			if fits(h.shape, ox, oy) then place(h, ox, oy) return end
			UI.SFX.play("error")
		end
		paint()
		drawHand()
	end)
	RunService.RenderStepped:Connect(function()
		if not drag then return end
		local h = hand[drag.index]
		local m = pointer() - ghostHolder.AbsolutePosition
		local w = 0
		for _, c in ipairs(h.shape) do w = math.max(w, c[1]) end
		drag.ghost.Position = UDim2.fromOffset(m.X - (w + 1) * drag.cell / 2, m.Y - 2.2 * drag.cell)
		local ox, oy = landing(h)
		local cells = {}
		for _, c in ipairs(h.shape) do
			local x, y = ox + c[1], oy + c[2]
			if x >= 0 and y >= 0 and x < N and y < N then table.insert(cells, x * N + y) end
		end
		paint({cells = cells, ok = fits(h.shape, ox, oy), color = h.color})
	end)
	local tap = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8}, area)
	tap.Activated:Connect(function() if over.Visible and env.current() == "BlockBlast" then B.start() end end)
	B.start = function()
		grid, score = {}, 0
		over.Visible = false
		hud()
		paint()
		deal()
	end
end

------------------------------------------------------------------
-- ARCHERY: your avatar with a bow. Press and pull BACK, let go to shoot. Hit the dummies!
------------------------------------------------------------------
local function buildArchery(env)
	local UI, C, new, frame = env.UI, env.UI.C, env.UI.new, env.frame
	local A = env.page("Archery")
	local area = frame(A.frame, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.08), Size = UDim2.fromScale(0.96, 0.86),
		BackgroundColor3 = UI.rgb(120, 190, 255), ClipsDescendants = true})
	UI.corner(area, 8)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(UI.rgb(150, 210, 255), UI.rgb(220, 240, 255))}, area)
	-- hills + grass
	for k, h in ipairs({{0.15, 0.25}, {0.55, 0.32}, {0.9, 0.22}}) do
		local hill = frame(area, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(h[1], 0.88), Size = UDim2.fromScale(h[2] * 2.2, h[2]),
			BackgroundColor3 = UI.rgb(120, 200, 110):Lerp(UI.rgb(80, 160, 90), k / 4)})
		UI.corner(hill, true)
	end
	local GROUND = 0.86
	frame(area, {Position = UDim2.fromScale(0, GROUND), Size = UDim2.fromScale(1, 1 - GROUND), BackgroundColor3 = UI.rgb(90, 190, 70)})
	local over = env.overText(area)
	-- YOU: your own avatar's head on a little body, holding a bow
	local ARCHER = Vector2.new(0.12, GROUND - 0.12)
	local me = frame(area, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(ARCHER.X, GROUND), Size = UDim2.fromScale(0.09, 0.2), BackgroundTransparency = 1, ZIndex = 5})
	frame(me, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.5, 0.55), BackgroundColor3 = UI.rgb(60, 120, 220), ZIndex = 5})
	local headImg = new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 0.5), BackgroundTransparency = 1,
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. (Players.LocalPlayer and Players.LocalPlayer.UserId or 1) .. "&w=150&h=150", ZIndex = 6}, me)
	new("UIAspectRatioConstraint", {AspectRatio = 1}, headImg)
	local bow = frame(area, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(ARCHER.X + 0.03, ARCHER.Y), Size = UDim2.fromScale(0.02, 0.13),
		BackgroundColor3 = UI.rgb(140, 80, 30), ZIndex = 7})
	UI.corner(bow, true)
	-- the aiming dots (where the arrow would fly)
	local dots = {}
	for k = 1, 10 do
		dots[k] = frame(area, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.012, 0.012), BackgroundColor3 = C.white, BackgroundTransparency = 0.2 + k * 0.06, Visible = false, ZIndex = 6})
		UI.corner(dots[k], true)
	end
	local arrow = frame(area, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.09, 0.012), BackgroundColor3 = UI.rgb(90, 55, 25), Visible = false, ZIndex = 7})
	frame(arrow, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1.1, 0.5), Size = UDim2.fromScale(0.18, 3), BackgroundColor3 = UI.rgb(200, 200, 210), ZIndex = 7})
	local GRAV = 1.1
	-- training dummies: a post, a straw body and a target head
	local dummies = {}
	local function spawnDummy()
		local x = 0.45 + math.random() * 0.48
		local tall = 0.14 + math.random() * 0.08
		local d = frame(area, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(x, GROUND), Size = UDim2.fromScale(0.07, tall), BackgroundTransparency = 1, ZIndex = 4})
		frame(d, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.16, 0.5), BackgroundColor3 = UI.rgb(120, 80, 40), ZIndex = 4})
		local body = frame(d, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.75, 0.35), BackgroundColor3 = UI.rgb(220, 190, 110), ZIndex = 4})
		UI.corner(body, 6)
		local headF = frame(d, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.8, 0.3), BackgroundColor3 = C.white, ZIndex = 5})
		new("UIAspectRatioConstraint", {AspectRatio = 1}, headF)
		UI.corner(headF, true)
		UI.stroke(headF, 2, C.red)
		local bull = frame(headF, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.4, 0.4), BackgroundColor3 = C.red, ZIndex = 6})
		UI.corner(bull, true)
		table.insert(dummies, {frame = d, x = x, top = GROUND - tall, alive = true})
	end
	local arrows, kills, best, flying, aPos, aVel = 15, 0, 0, false, nil, nil
	local function hud() env.score("Hits " .. kills .. "   Arrows " .. arrows .. "   Best " .. best) end
	local function velocityFor(pull)
		-- pulling back = shooting the other way; longer pull = more power
		local v = -pull * 3.2
		if v.Magnitude > 2.4 then v = v.Unit * 2.4 end
		return v
	end
	local function knockDown(dm, headshot)
		dm.alive = false
		kills = kills + (headshot and 2 or 1)
		best = math.max(best, kills)
		UI.tween(dm.frame, 0.4, {Rotation = 85})
		task.delay(0.6, function() dm.frame:Destroy() end)
		local l = UI.label(area, headshot and "HEADSHOT! +2" or "+1", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(dm.x, dm.top - 0.05),
			Size = UDim2.fromScale(0.4, 0.08), Max = 30, Stroke = 3, TextColor3 = headshot and C.yellow or C.money, ZIndex = 9, TextWrapped = false})
		UI.tween(l, 0.8, {Position = UDim2.fromScale(dm.x, dm.top - 0.15)})
		task.delay(0.8, function() l:Destroy() end)
		UI.SFX.play("ding", headshot and 1.8 or 1.4, 0.5)
		task.delay(0.5, spawnDummy)
	end
	A.start = function()
		for _, dm in ipairs(dummies) do if dm.frame.Parent then dm.frame:Destroy() end end
		dummies = {}
		arrows, kills, flying = 15, 0, false
		arrow.Visible = false
		over.Visible = false
		for _ = 1, 3 do spawnDummy() end
		hud()
		env.setStep(function(dt)
			if not flying then return end
			aVel = aVel + Vector2.new(0, GRAV) * dt
			aPos = aPos + aVel * dt
			arrow.Position = UDim2.fromScale(aPos.X, aPos.Y)
			arrow.Rotation = math.deg(math.atan2(aVel.Y, aVel.X))
			for _, dm in ipairs(dummies) do
				if dm.alive and math.abs(aPos.X - dm.x) < 0.03 and aPos.Y > dm.top and aPos.Y < GROUND then
					flying = false
					arrow.Visible = false
					knockDown(dm, aPos.Y < dm.top + 0.05)
					hud()
					break
				end
			end
			if flying and (aPos.X > 1.05 or aPos.Y > GROUND or aPos.X < -0.05) then
				flying = false
				arrow.Visible = false
			end
			if not flying and arrows <= 0 and not over.Visible then
				task.delay(0.7, function()
					over.Visible = true
					UI.setText(over, "Out of arrows! Hits: " .. kills .. "\nTap to play again")
				end)
			end
		end)
	end
	-- press anywhere, pull back, let go
	local pad = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8}, area)
	local pullFrom = nil
	pad.MouseButton1Down:Connect(function()
		if over.Visible then A.start() return end
		if flying or arrows <= 0 then return end
		pullFrom = Vector2.new(relative(area))
	end)
	RunService.RenderStepped:Connect(function()
		if not pullFrom then return end
		local pull = Vector2.new(relative(area)) - pullFrom
		local v = velocityFor(pull)
		bow.Rotation = math.deg(math.atan2(v.Y, v.X))
		-- the dotted path the arrow will take
		for k, d in ipairs(dots) do
			local t = k * 0.06
			local p = ARCHER + v * t + Vector2.new(0, GRAV) * t * t * 0.5
			d.Position = UDim2.fromScale(p.X, p.Y)
			d.Visible = v.Magnitude > 0.2
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not pullFrom or not isPress(input) then return end
		local v = velocityFor(Vector2.new(relative(area)) - pullFrom)
		pullFrom = nil
		for _, d in ipairs(dots) do d.Visible = false end
		if v.Magnitude < 0.3 then return end
		aPos, aVel = ARCHER, v
		arrows = arrows - 1
		flying = true
		arrow.Visible = true
		UI.SFX.play("click", 1.3, 0.45)
		hud()
	end)
end

function Phone.init(ctx)
	local UI = ctx.UI
	local C, new = UI.C, UI.new
	local win = UI.window({Name = "Phone", Title = "Phone", Icon = "star", Color = UI.rgb(40, 40, 52), Size = Vector2.new(460, 700)})
	win.page.Visible = false
	local screen = new("Frame", {Name = "Screen", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundColor3 = UI.rgb(18, 20, 30),
		ClipsDescendants = true, ZIndex = 2}, win.body)
	UI.corner(screen, 14)
	local env = {UI = UI}
	function env.frame(parent, props)
		local f = new("Frame", {BorderSizePixel = 0, ZIndex = 3}, parent)
		for k, v in pairs(props) do f[k] = v end
		return f
	end
	local pages, current, step = {}, nil, nil
	local scoreL = UI.label(screen, "", {Position = UDim2.fromScale(0.04, 0.012), Size = UDim2.fromScale(0.66, 0.05), Max = 24, Stroke = 2.4,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ZIndex = 6})
	local home = UI.button(screen, {Text = "Home", Color = C.grey, Size = UDim2.fromOffset(96, 38), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6), TextSize = 18, Depth = 3, ZIndex = 6})
	function env.page(name)
		local f = env.frame(screen, {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false})
		pages[name] = {frame = f}
		return pages[name]
	end
	function env.board(parent, y, h)
		local b = env.frame(parent, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromScale(0.94, h), BackgroundColor3 = UI.rgb(30, 34, 48),
			ClipsDescendants = true})
		new("UIAspectRatioConstraint", {AspectRatio = 1}, b)
		UI.corner(b, 8)
		UI.stroke(b, 3)
		return b
	end
	function env.overText(parent)
		local o = UI.label(parent, "", {Position = UDim2.fromScale(0.05, 0.35), Size = UDim2.fromScale(0.9, 0.3), Max = 38, Stroke = 3.5, ZIndex = 12, Visible = false})
		return o
	end
	function env.score(text) UI.setText(scoreL, text) end
	function env.setStep(fn) step = fn end
	function env.current() return current end
	function env.isOpen() return UI.isOpen("Phone") end
	local function show(name)
		current = name
		step = nil
		for k, pg in pairs(pages) do pg.frame.Visible = (k == name) end
		home.holder.Visible = name ~= "Home"
		UI.setText(scoreL, name == "Home" and "Games" or "")
		if pages[name].start then pages[name].start() end
	end

	-- HOME: the app icons
	local HOME = env.page("Home")
	for i, app in ipairs({{"Snake", "Snake", UI.rgb(70, 200, 70)}, {"BlockBlast", "Block Blast", UI.rgb(160, 90, 255)}, {"Archery", "Archery", UI.rgb(255, 150, 40)}}) do
		local b = UI.button(HOME.frame, {Text = app[2], Color = app[3], Size = UDim2.new(0.8, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.14 + (i - 1) * 0.27, 0), TextSize = 34, Depth = 6, ZIndex = 4})
		b.Activated:Connect(function() show(app[1]) end)
	end
	home.Activated:Connect(function() show("Home") end)
	buildSnake(env)
	buildBlast(env)
	buildArchery(env)

	-- one loop runs the game on screen (only while the phone is open)
	RunService.Heartbeat:Connect(function(dt)
		if step and UI.isOpen("Phone") then step(math.min(dt, 0.1)) end
	end)
	-- while the phone is open, the movement keys play the game instead of walking you around
	local CAS = game:GetService("ContextActionService")
	local KEYS = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space}
	UI.WindowChanged:Connect(function(name)
		if name == "Phone" then
			pcall(function()
				CAS:BindActionAtPriority("StealABoxPhoneKeys", function() return Enum.ContextActionResult.Sink end, false, 3000, table.unpack(KEYS))
			end)
		else
			pcall(function() CAS:UnbindAction("StealABoxPhoneKeys") end)
		end
	end)
	win.onOpen = function() show("Home") end
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt.Name == "PlayPhone" and not UI.isOpen("Phone") then UI.open("Phone") end
	end)
	show("Home")
end

return Phone
