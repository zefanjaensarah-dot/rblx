--[[ STEAL A BOX - the big phone on your base: walk up, press E, play mini games.
     Snake        eat the dots, don't hit yourself or the walls (arrow keys / WASD / buttons)
     Block Blast  tap a piece, then tap the board to place it; full rows and columns clear
     Archery      tap where you want to shoot: the further you tap, the harder the arrow flies ]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Phone = {}

function Phone.init(ctx)
	local UI = ctx.UI
	local C, new = UI.C, UI.new
	local win = UI.window({Name = "Phone", Title = "Phone", Icon = "star", Color = UI.rgb(40, 40, 52), Size = Vector2.new(440, 660)})
	win.page.Visible = false
	-- the phone screen: everything is placed with fractions (0..1) so it fits any size
	local screen = new("Frame", {Name = "Screen", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundColor3 = UI.rgb(18, 20, 30),
		ClipsDescendants = true, ZIndex = 2}, win.body)
	UI.corner(screen, 14)
	local function frame(parent, props)
		local f = new("Frame", {BorderSizePixel = 0, ZIndex = 3}, parent)
		for k, v in pairs(props) do f[k] = v end
		return f
	end
	local function tapPoint(target)
		-- where you tapped inside `target`, as fractions 0..1
		local m = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		local p, s = target.AbsolutePosition, target.AbsoluteSize
		if s.X < 1 or s.Y < 1 then return 0.5, 0.5 end
		return math.clamp((m.X - p.X) / s.X, 0, 1), math.clamp((m.Y - p.Y) / s.Y, 0, 1)
	end

	-- every screen of the phone is a page; only one is visible
	local pages, current, step = {}, nil, nil
	local scoreL = UI.label(screen, "", {Position = UDim2.fromScale(0.05, 0.015), Size = UDim2.fromScale(0.6, 0.06), Max = 26, Stroke = 2.4,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ZIndex = 6})
	local home = UI.button(screen, {Text = "Home", Color = C.grey, Size = UDim2.fromOffset(100, 40), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6), TextSize = 18, Depth = 3, ZIndex = 6})
	local function show(name)
		current = name
		step = nil
		for k, pg in pairs(pages) do pg.frame.Visible = (k == name) end
		home.holder.Visible = name ~= "Home"
		UI.setText(scoreL, name == "Home" and "Games" or "")
		if pages[name].start then pages[name].start() end
	end
	local function page(name)
		local f = frame(screen, {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false})
		pages[name] = {frame = f}
		return pages[name]
	end
	local function board(parent, y, h)
		-- a square play area, centred
		local b = frame(parent, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromScale(0.92, h),
			BackgroundColor3 = UI.rgb(30, 34, 48)})
		new("UIAspectRatioConstraint", {AspectRatio = 1}, b)
		UI.corner(b, 8)
		return b
	end
	local function overText(parent)
		return UI.label(parent, "", {Position = UDim2.fromScale(0.05, 0.4), Size = UDim2.fromScale(0.9, 0.2), Max = 40, Stroke = 3, ZIndex = 8, Visible = false})
	end

	------------------------------------------------------------------
	-- HOME: the app icons
	------------------------------------------------------------------
	local HOME = page("Home")
	for i, app in ipairs({{"Snake", UI.rgb(70, 200, 70)}, {"BlockBlast", UI.rgb(160, 90, 255)}, {"Archery", UI.rgb(255, 150, 40)}}) do
		local b = UI.button(HOME.frame, {Text = (app[1] == "BlockBlast") and "Block Blast" or app[1], Color = app[2], Size = UDim2.new(0.8, 0, 0, 90),
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.12 + (i - 1) * 0.27, 0), TextSize = 34, Depth = 6, ZIndex = 4})
		b.Activated:Connect(function() show(app[1]) end)
	end
	home.Activated:Connect(function() show("Home") end)

	------------------------------------------------------------------
	-- SNAKE
	------------------------------------------------------------------
	do
		local G = 14
		local S = page("Snake")
		local area = board(S.frame, 0.09, 0.6)
		local over = overText(area)
		local dirs = {Up = Vector2.new(0, -1), Down = Vector2.new(0, 1), Left = Vector2.new(-1, 0), Right = Vector2.new(1, 0)}
		local snake, dir, nextDir, food, cells, foodF, acc, alive, score
		local function cell(p, color)
			local f = frame(area, {Size = UDim2.fromScale(1 / G * 0.9, 1 / G * 0.9), Position = UDim2.fromScale((p.X + 0.05) / G, (p.Y + 0.05) / G), BackgroundColor3 = color})
			UI.corner(f, 4)
			return f
		end
		local function placeFood()
			repeat
				food = Vector2.new(math.random(0, G - 1), math.random(0, G - 1))
				local onSnake = false
				for _, p in ipairs(snake) do if p == food then onSnake = true end end
			until not onSnake
			if foodF then foodF:Destroy() end
			foodF = cell(food, C.red)
		end
		local function draw()
			for _, f in ipairs(cells) do f:Destroy() end
			cells = {}
			for i, p in ipairs(snake) do table.insert(cells, cell(p, (i == 1) and UI.rgb(150, 255, 120) or UI.rgb(70, 200, 70))) end
		end
		S.start = function()
			snake = {Vector2.new(5, 7), Vector2.new(4, 7), Vector2.new(3, 7)}
			dir, nextDir, acc, alive, score = dirs.Right, dirs.Right, 0, true, 0
			cells = cells or {}
			over.Visible = false
			placeFood()
			draw()
			UI.setText(scoreL, "Score: 0")
			step = function(dt)
				if not alive then return end
				acc = acc + dt
				if acc < 0.14 then return end
				acc = 0
				if (nextDir + dir).Magnitude > 0.5 then dir = nextDir end -- (no turning straight back)
				local head = snake[1] + dir
				local hit = head.X < 0 or head.Y < 0 or head.X >= G or head.Y >= G
				for _, p in ipairs(snake) do if p == head then hit = true end end
				if hit then
					alive = false
					over.Visible = true
					UI.setText(over, "Game over! Score " .. score .. "\nTap to play again")
					return
				end
				table.insert(snake, 1, head)
				if head == food then
					score = score + 1
					UI.setText(scoreL, "Score: " .. score)
					UI.SFX.play("click", 2.6, 0.3)
					placeFood()
				else
					table.remove(snake)
				end
				draw()
			end
		end
		-- arrow buttons (for phones) under the board
		for name, pos in pairs({Up = {0.5, 0.72}, Left = {0.3, 0.83}, Right = {0.7, 0.83}, Down = {0.5, 0.94}}) do
			local b = UI.button(S.frame, {Text = name, Color = C.blue, Size = UDim2.fromOffset(96, 50), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(pos[1], pos[2] - 0.03), TextSize = 20, Depth = 4, ZIndex = 4})
			b.Activated:Connect(function() nextDir = dirs[name] end)
		end
		local restart = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 7}, area)
		restart.Activated:Connect(function() if not alive and current == "Snake" then S.start() end end)
		local KEYS = {[Enum.KeyCode.Up] = "Up", [Enum.KeyCode.W] = "Up", [Enum.KeyCode.Down] = "Down", [Enum.KeyCode.S] = "Down",
			[Enum.KeyCode.Left] = "Left", [Enum.KeyCode.A] = "Left", [Enum.KeyCode.Right] = "Right", [Enum.KeyCode.D] = "Right"}
		UserInputService.InputBegan:Connect(function(input)
			if current == "Snake" and UI.isOpen("Phone") and KEYS[input.KeyCode] then nextDir = dirs[KEYS[input.KeyCode]] end
		end)
	end

	------------------------------------------------------------------
	-- BLOCK BLAST: place pieces on an 8x8 board, full rows / columns clear
	------------------------------------------------------------------
	do
		local N = 8
		local B = page("BlockBlast")
		local area = board(B.frame, 0.09, 0.56)
		local over = overText(area)
		local SHAPES = {
			{{0, 0}}, {{0, 0}, {1, 0}}, {{0, 0}, {0, 1}}, {{0, 0}, {1, 0}, {2, 0}}, {{0, 0}, {0, 1}, {0, 2}},
			{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, {{0, 0}, {0, 1}, {1, 1}}, {{1, 0}, {0, 1}, {1, 1}}, {{0, 0}, {1, 0}, {1, 1}},
			{{0, 0}, {1, 0}, {2, 0}, {3, 0}}, {{0, 0}, {1, 0}, {2, 0}, {1, 1}}, {{0, 0}, {0, 1}, {0, 2}, {1, 2}},
		}
		local COLORS = {UI.rgb(255, 90, 90), UI.rgb(255, 180, 50), UI.rgb(90, 210, 90), UI.rgb(70, 160, 255), UI.rgb(180, 110, 255), UI.rgb(255, 120, 200)}
		local grid, tiles, hand, selected, score = {}, {}, {}, nil, 0
		for x = 0, N - 1 do
			for y = 0, N - 1 do
				local t = frame(area, {Size = UDim2.fromScale(0.94 / N, 0.94 / N), Position = UDim2.fromScale((x + 0.03) / N, (y + 0.03) / N), BackgroundColor3 = UI.rgb(48, 54, 74)})
				UI.corner(t, 4)
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
		local function canPlaceAny()
			for _, h in ipairs(hand) do
				if not h.used then
					for x = 0, N - 1 do for y = 0, N - 1 do if fits(h.shape, x, y) then return true end end end
				end
			end
			return false
		end
		local function paint()
			for k, t in pairs(tiles) do t.BackgroundColor3 = grid[k] or UI.rgb(48, 54, 74) end
		end
		local slots = {}
		local function drawHand()
			for i, h in ipairs(hand) do
				local slot = slots[i]
				for _, c in ipairs(slot.cells) do c:Destroy() end
				slot.cells = {}
				slot.face.BackgroundColor3 = (selected == i) and UI.rgb(90, 90, 120) or UI.rgb(40, 44, 60)
				if not h.used then
					for _, c in ipairs(h.shape) do
						local f = frame(slot.face, {Size = UDim2.fromScale(0.19, 0.19), Position = UDim2.fromScale(0.1 + c[1] * 0.2, 0.1 + c[2] * 0.2), BackgroundColor3 = h.color, ZIndex = 5})
						UI.corner(f, 3)
						table.insert(slot.cells, f)
					end
				end
			end
		end
		local function deal()
			hand = {}
			for i = 1, 3 do hand[i] = {shape = SHAPES[math.random(1, #SHAPES)], color = COLORS[math.random(1, #COLORS)]} end
			selected = nil
			drawHand()
		end
		for i = 1, 3 do
			local face = new("TextButton", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.2 + (i - 1) * 0.3, 0.72), Size = UDim2.fromScale(0.27, 0.2),
				BackgroundColor3 = UI.rgb(40, 44, 60), Text = "", AutoButtonColor = false, ZIndex = 4}, B.frame)
			new("UIAspectRatioConstraint", {AspectRatio = 1}, face)
			UI.corner(face, 8)
			UI.stroke(face, 2.5)
			slots[i] = {face = face, cells = {}}
			face.Activated:Connect(function()
				if hand[i] and not hand[i].used then
					selected = i
					drawHand()
				end
			end)
		end
		local tap = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 7}, area)
		tap.Activated:Connect(function()
			if current ~= "BlockBlast" then return end
			if over.Visible then B.start() return end
			local h = selected and hand[selected]
			if not h or h.used then return end
			local fx, fy = tapPoint(area)
			local ox, oy = math.floor(fx * N), math.floor(fy * N)
			if not fits(h.shape, ox, oy) then UI.SFX.play("error") return end
			for _, c in ipairs(h.shape) do grid[(ox + c[1]) * N + oy + c[2]] = h.color end
			score = score + #h.shape
			h.used = true
			selected = nil
			-- clear full rows and columns
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
			for key in pairs(clear) do grid[key] = nil end
			if lines > 0 then
				score = score + lines * 10
				UI.SFX.play("ding", 1.6, 0.4)
			else
				UI.SFX.play("click", 2.2, 0.3)
			end
			UI.setText(scoreL, "Score: " .. score)
			if hand[1].used and hand[2].used and hand[3].used then deal() else drawHand() end
			paint()
			if not canPlaceAny() then
				over.Visible = true
				UI.setText(over, "No room left! Score " .. score .. "\nTap to play again")
			end
		end)
		B.start = function()
			grid, score = {}, 0
			over.Visible = false
			UI.setText(scoreL, "Score: 0")
			paint()
			deal()
		end
	end

	------------------------------------------------------------------
	-- ARCHERY: tap to shoot; hit the target before you run out of arrows
	------------------------------------------------------------------
	do
		local A = page("Archery")
		local area = board(A.frame, 0.09, 0.7)
		area.BackgroundColor3 = UI.rgb(120, 190, 255)
		frame(area, {Position = UDim2.fromScale(0, 0.9), Size = UDim2.fromScale(1, 0.1), BackgroundColor3 = UI.rgb(90, 200, 70)})
		local over = overText(area)
		local ARCHER = Vector2.new(0.1, 0.85)
		local archer = frame(area, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(ARCHER.X, 0.9), Size = UDim2.fromScale(0.06, 0.12), BackgroundColor3 = UI.rgb(120, 70, 40)})
		UI.corner(archer, 4)
		local target = frame(area, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.1, 0.1), BackgroundColor3 = C.white})
		UI.corner(target, true)
		UI.stroke(target, 3, C.red)
		local bull = frame(target, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.45, 0.45), BackgroundColor3 = C.red})
		UI.corner(bull, true)
		local arrow = frame(area, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.08, 0.012), BackgroundColor3 = UI.rgb(60, 40, 20), Visible = false})
		local tPos, aPos, aVel, arrows, score, flying = Vector2.new(0.75, 0.5), nil, nil, 10, 0, false
		local function newTarget()
			tPos = Vector2.new(0.45 + math.random() * 0.45, 0.2 + math.random() * 0.6)
			target.Position = UDim2.fromScale(tPos.X, tPos.Y)
		end
		local function hud() UI.setText(scoreL, "Hits: " .. score .. "   Arrows: " .. arrows) end
		A.start = function()
			arrows, score, flying = 10, 0, false
			arrow.Visible = false
			over.Visible = false
			newTarget()
			hud()
			step = function(dt)
				if not flying then return end
				aVel = aVel + Vector2.new(0, 1.2) * dt -- gravity
				aPos = aPos + aVel * dt
				arrow.Position = UDim2.fromScale(aPos.X, aPos.Y)
				arrow.Rotation = math.deg(math.atan2(aVel.Y, aVel.X))
				if (aPos - tPos).Magnitude < 0.055 then
					flying = false
					arrow.Visible = false
					score = score + 1
					UI.SFX.play("ding", 1.5, 0.5)
					newTarget()
					hud()
				elseif aPos.X > 1.05 or aPos.Y > 0.92 or aPos.X < -0.05 then
					flying = false
					arrow.Visible = false
					if arrows <= 0 then
						over.Visible = true
						UI.setText(over, "Out of arrows! Hits: " .. score .. "\nTap to play again")
					end
				end
			end
		end
		local tap = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 7}, area)
		tap.Activated:Connect(function()
			if current ~= "Archery" then return end
			if over.Visible then A.start() return end
			if flying or arrows <= 0 then return end
			local fx, fy = tapPoint(area)
			-- shoot towards where you tapped (further = stronger), a little upwards to fight gravity
			aVel = (Vector2.new(fx, fy) - ARCHER) * 1.9 + Vector2.new(0, -0.25)
			aPos = ARCHER
			arrows = arrows - 1
			flying = true
			arrow.Visible = true
			UI.SFX.play("click", 1.4, 0.4)
			hud()
		end)
	end

	-- one loop runs the game on screen (only while the phone is open)
	RunService.Heartbeat:Connect(function(dt)
		if step and UI.isOpen("Phone") then step(math.min(dt, 0.1)) end
	end)
	win.onOpen = function() show("Home") end
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt.Name == "PlayPhone" and not UI.isOpen("Phone") then UI.open("Phone") end
	end)
	show("Home")
end

return Phone
