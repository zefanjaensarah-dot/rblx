--[[ STEAL A BOX - tutorial for new players
     One clear step at a time. A card in the top stack of the HUD shows a big icon, the
     step, what to do and the progress. The camera swoops over to show you where to go, a
     glowing line + bouncing arrow point at it in the world, and an arrow points at it on
     screen (or at the edge of your screen when it's behind you). It ends when you buy your
     first treadmill upgrade (or press Skip). Settings > "Show the tutorial again" replays it. ]]

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Tutorial = {}

function Tutorial.init(ctx)
	local UI, Config, player = ctx.UI, ctx.Config, ctx.player
	local C, new, fmt = UI.C, UI.new, Config.FormatNum
	local playerGui = player:WaitForChild("PlayerGui")

	local STEPS = {
		{title = "Steal a box", icon = "box", color = C.orange, tip = "Run into the warehouse and hold E on a box to steal it!"},
		{title = "Bring it home", icon = "home", color = C.green, tip = "Carry it to YOUR plot and click the floor to place it."},
		{title = "Open your box", icon = "gift", color = C.pink, tip = "Your box is unboxing... When it says OPEN!, press E on it."},
		{title = "Get faster", icon = "boot", color = C.cyan, tip = "Step onto your treadmill - it runs for you and makes you faster!"},
		{title = "Earn cash", icon = "coin", color = C.gold, tip = "Shoppers buy from your shelves. Save up for an upgrade!"},
		{title = "Upgrade it!", icon = "star", color = C.purple, tip = "You have enough! Press E at your treadmill's screen to upgrade it."},
	}

	------------------------------------------------------------------
	-- THE CARD (fixed slots: icon | step chip + title | text | progress)
	------------------------------------------------------------------
	local W, H = 540, 116
	local tut = new("Frame", {Name = "TutorialCard", Size = UDim2.fromOffset(W, H), BackgroundColor3 = UI.rgb(30, 28, 46), BackgroundTransparency = 0.04, Visible = false}, ctx.hud.tutorialSlot)
	UI.corner(tut, 20)
	UI.shade(tut, C.white, UI.rgb(170, 170, 185))
	local tutStroke = UI.stroke(tut, 3, C.orange)
	local tutScale = new("UIScale", {}, tut)
	local bubble = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(52, H / 2), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.orange}, tut)
	UI.corner(bubble, true)
	UI.stroke(bubble, 3)
	UI.shade(bubble, C.white, UI.rgb(175, 175, 185))
	local bubbleScale = new("UIScale", {}, bubble)
	local icon = nil
	local chip = new("Frame", {Position = UDim2.fromOffset(100, 10), Size = UDim2.fromOffset(104, 26), BackgroundColor3 = C.orange}, tut)
	UI.corner(chip, true)
	UI.stroke(chip, 2)
	local chipText = UI.label(chip, "STEP 1 / 6", {Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Max = 15, Stroke = 1.4, TextWrapped = false})
	local title = UI.label(tut, "", {Position = UDim2.fromOffset(212, 7), Size = UDim2.fromOffset(W - 212 - 92, 32), Max = 26, Stroke = 2.4,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false})
	local desc = UI.label(tut, "", {Position = UDim2.fromOffset(100, 42), Size = UDim2.fromOffset(W - 116, 42), Max = 18, Stroke = 1.6,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = UI.rgb(235, 235, 245)})
	local dots = {}
	for k = 1, #STEPS do
		local d = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(108 + (k - 1) * 22, 98), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = UI.rgb(70, 70, 85)}, tut)
		UI.corner(d, true)
		UI.stroke(d, 2)
		dots[k] = {frame = d, scale = new("UIScale", {}, d)}
	end
	local cashBar = UI.bar(tut, {Position = UDim2.fromOffset(250, 88), Size = UDim2.fromOffset(W - 266, 20), Visible = false}, C.money)
	local skip = UI.button(tut, {Text = "Skip", Color = C.grey, Size = UDim2.fromOffset(80, 32), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), TextSize = 16, Depth = 3, Radius = 10})
	local doneStamp = UI.label(tut, "DONE!", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(240, 60),
		TextColor3 = C.money, Max = 54, Stroke = 3.4, Visible = false, Rotation = -8, ZIndex = 5})
	local doneScale = new("UIScale", {}, doneStamp)

	-- the bubble bobs, the current dot pulses
	RunService.RenderStepped:Connect(function()
		if not tut.Visible then return end
		local t = os.clock()
		if icon then
			icon.Rotation = math.sin(t * 2.2) * 8
			icon.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 3) * 3)
		end
		for _, d in ipairs(dots) do
			if d.current then d.scale.Scale = 1.15 + math.sin(t * 6) * 0.15 end
		end
	end)

	------------------------------------------------------------------
	-- POINTERS: a glowing line from you to the target + a bouncing arrow above it,
	-- and on screen an arrow at the target (or at the edge of your screen)
	------------------------------------------------------------------
	local pointerFolder = new("Folder", {Name = "TutorialPointer"}, workspace)
	local beam = new("Beam", {Color = ColorSequence.new(UI.rgb(255, 230, 60), UI.rgb(120, 255, 80)), FaceCamera = true, Width0 = 0.5, Width1 = 0.5,
		LightEmission = 1, Transparency = NumberSequence.new(0.2, 0.5), Segments = 1, Enabled = false}, pointerFolder)
	local arrow = new("BillboardGui", {Size = UDim2.fromOffset(60, 60), AlwaysOnTop = true, LightInfluence = 0, Enabled = false}, pointerFolder)
	UI.icon("down", arrow, UDim2.fromScale(1, 1), nil, UI.rgb(255, 230, 60))
	local cursorGui = new("ScreenGui", {Name = "TutorialCursor", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 8}, playerGui)
	local ring = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Visible = false}, cursorGui)
	UI.corner(ring, true)
	local ringStroke = new("UIStroke", {Thickness = 4, Color = UI.rgb(255, 230, 60)}, ring)
	local hand = UI.icon("arrow", cursorGui, UDim2.fromOffset(54, 54), nil, UI.rgb(255, 230, 60), Vector2.new(0.5, 0))
	hand.Visible = false
	local edge = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Visible = false}, cursorGui)
	local edgeArrow = UI.icon("arrow", edge, UDim2.fromScale(1, 1), nil, UI.rgb(255, 230, 60))
	local edgeDist = UI.label(edge, "", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(100, 22), Max = 18, Stroke = 2, TextWrapped = false})

	local fromAttach, toAttach, currentTarget = nil, nil, nil
	local function pointAt(part)
		currentTarget = part
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not part or not hrp then
			beam.Enabled = false
			arrow.Enabled = false
			return
		end
		if not fromAttach or fromAttach.Parent ~= hrp then
			if fromAttach then fromAttach:Destroy() end
			fromAttach = new("Attachment", {Name = "TutorialFrom", Position = Vector3.new(0, -1.5, 0)}, hrp)
		end
		if not toAttach or toAttach.Parent ~= part then
			if toAttach then toAttach:Destroy() end
			toAttach = new("Attachment", {Name = "TutorialTo"}, part)
		end
		beam.Attachment0 = fromAttach
		beam.Attachment1 = toAttach
		beam.Enabled = true
		arrow.Adornee = part
		arrow.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 3 + math.abs(math.sin(os.clock() * 4)) * 1.5, 0)
		arrow.Enabled = true
	end

	local zooming = false
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local part = currentTarget
		if not part or not part.Parent or not cam or zooming or not tut.Visible or UI.isOpen() then
			hand.Visible, ring.Visible, edge.Visible = false, false, false
			return
		end
		local t = os.clock()
		local p, onScreen = cam:WorldToViewportPoint(part.Position)
		local vp = cam.ViewportSize
		if onScreen and p.X > 30 and p.X < vp.X - 30 and p.Y > 30 and p.Y < vp.Y - 30 then
			edge.Visible = false
			hand.Visible, ring.Visible = true, true
			local tap = math.abs(math.sin(t * 3.5))
			hand.Position = UDim2.fromOffset(p.X + 8, p.Y + 6 + tap * 16)
			hand.Rotation = -90 + math.sin(t * 3.5) * 8
			local r = 26 + ((t * 1.4) % 1) * 46
			ring.Size = UDim2.fromOffset(r, r)
			ring.Position = UDim2.fromOffset(p.X, p.Y)
			ringStroke.Transparency = (t * 1.4) % 1
		else
			hand.Visible, ring.Visible = false, false
			local rel = cam.CFrame:PointToObjectSpace(part.Position)
			local dir = Vector2.new(rel.X, -rel.Y)
			if dir.Magnitude < 0.01 then dir = Vector2.new(0, 1) end
			dir = dir.Unit
			local cx, cy = vp.X / 2, vp.Y / 2
			local k = math.min((cx - 60) / math.max(0.001, math.abs(dir.X)), (cy - 60) / math.max(0.001, math.abs(dir.Y)))
			local pulse = 1 + math.sin(t * 6) * 0.08
			edge.Position = UDim2.fromOffset(cx + dir.X * k, cy + dir.Y * k)
			edge.Size = UDim2.fromOffset(64 * pulse, 64 * pulse)
			edgeArrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			UI.setText(edgeDist, hrp and (math.floor((hrp.Position - part.Position).Magnitude) .. " studs") or "")
			edge.Visible = true
		end
	end)

	-- the camera swoops over to the target for a moment, then comes back
	local function zoomTo(part)
		local cam = workspace.CurrentCamera
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if zooming or not cam or not part or not hrp or UI.isOpen() then return end
		zooming = true
		local startCF = cam.CFrame
		local look = part.Position
		local away = hrp.Position - look
		away = Vector3.new(away.X, 0, away.Z)
		away = (away.Magnitude > 0.1) and away.Unit or Vector3.new(0, 0, 1)
		local eye = look + away * 22 + Vector3.new(0, 14, 0)
		cam.CameraType = Enum.CameraType.Scriptable
		UI.tween(cam, 0.9, {CFrame = CFrame.lookAt(eye, look)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		task.delay(2.3, function()
			UI.tween(cam, 0.7, {CFrame = startCF}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			task.delay(0.72, function()
				cam.CameraType = Enum.CameraType.Custom
				zooming = false
			end)
		end)
	end

	------------------------------------------------------------------
	-- STEPS
	------------------------------------------------------------------
	local typeToken = 0
	local function showStep(step, msg)
		msg = Config.StripEmoji(msg)
		local st = STEPS[step] or STEPS[1]
		typeToken = typeToken + 1
		local token = typeToken
		UI.setText(chipText, "STEP " .. step .. " / " .. #STEPS)
		UI.setText(title, st.title)
		title.TextColor3 = st.color:Lerp(C.white, 0.25)
		UI.tween(tutStroke, 0.3, {Color = st.color})
		UI.tween(chip, 0.3, {BackgroundColor3 = st.color})
		UI.tween(bubble, 0.3, {BackgroundColor3 = st.color})
		if icon then icon:Destroy() end
		icon = UI.icon(st.icon, bubble, UDim2.fromOffset(52, 52), UDim2.fromScale(0.5, 0.5), st.color:Lerp(C.white, 0.2), Vector2.new(0.5, 0.5))
		bubbleScale.Scale = 0.3
		UI.tween(bubbleScale, 0.6, {Scale = 1}, Enum.EasingStyle.Elastic)
		for k, d in ipairs(dots) do
			d.current = (k == step)
			if k < step then
				d.frame.BackgroundColor3 = C.money
				d.scale.Scale = 1
			elseif k == step then
				d.frame.BackgroundColor3 = st.color
			else
				d.frame.BackgroundColor3 = UI.rgb(70, 70, 85)
				d.scale.Scale = 1
			end
		end
		-- type the description
		task.spawn(function()
			for n = 1, #msg do
				if token ~= typeToken then return end
				desc.Text = msg:sub(1, n)
				if n % 2 == 0 then task.wait(0.012) end
			end
			desc.Text = msg
		end)
		UI.SFX.play("ding", 1.2 + step * 0.08, 0.35)
	end
	local function stepDone()
		doneStamp.Visible = true
		doneScale.Scale = 2.2
		UI.tween(doneScale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		tutStroke.Color = C.money
		for k = 1, 16 do
			local sq = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BorderSizePixel = 0, ZIndex = 4,
				Rotation = math.random(0, 90), BackgroundColor3 = ({C.money, C.yellow, C.cyan, C.white})[k % 4 + 1]}, tut)
			local ang = (k / 16) * math.pi * 2
			UI.tween(sq, 0.7, {Position = UDim2.new(0.5, math.cos(ang) * 240, 0.5, math.sin(ang) * 80), BackgroundTransparency = 1, Rotation = 300})
			Debris:AddItem(sq, 0.75)
		end
		task.delay(0.8, function() doneStamp.Visible = false end)
	end
	local function slideIn()
		tut.Visible = true
		tutScale.Scale = 0.5
		UI.tween(tutScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
	end
	local function hide()
		UI.tween(tutScale, 0.3, {Scale = 0.6}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.3, function() tut.Visible = false end)
	end

	local triedTreadmill = false
	local finished = false
	local replay = nil -- replay mode (from Settings): {step = n}
	local lastStep = nil
	local function myPlot()
		local plotName = player:GetAttribute("PlotName")
		local root = workspace:FindFirstChild("StealABox")
		local plots = root and root:FindFirstChild("Plots")
		return plots and plotName and plots:FindFirstChild(plotName), root
	end
	local function nearestStarterBox(hrp, root)
		local active = root and root:FindFirstChild("ActiveBoxes")
		local best, bestD = nil, math.huge
		if not active then return nil end
		for _, b in ipairs(active:GetChildren()) do
			local id = b:GetAttribute("BoxId")
			if id and Config.Boxes[id] and Config.Boxes[id].area == 1 and b:FindFirstChildOfClass("ProximityPrompt") then
				local d = (b.Position - hrp.Position).Magnitude
				if d < bestD then best, bestD = b, d end
			end
		end
		return best
	end
	-- where each step points
	local function targetFor(step, hrp, plot, root)
		if step == 1 then
			if hrp and hrp.Position.Z > Config.Layout.frontZ + 2 then return root and root:FindFirstChild("EntrancePoint", true) end
			return hrp and nearestStarterBox(hrp, root)
		elseif step == 2 then
			return plot and plot:FindFirstChild("PlotFloor")
		elseif step == 3 then
			local f = plot and plot:FindFirstChild("Unboxing")
			return f and f:GetChildren()[1]
		elseif step == 4 then
			return plot and plot:FindFirstChild("TreadBelt", true)
		elseif step == 5 then
			return plot and plot:FindFirstChild("ShopSign")
		end
		return plot and plot:FindFirstChild("TreadConsole", true)
	end

	local function finish(skipped)
		if finished then return end
		finished = true
		pointAt(nil)
		cashBar.frame.Visible = false
		if not replay then ctx.invoke("TutorialDone") end
		replay = nil
		skip.setText("Skip")
		skip.setColor(C.grey)
		if skipped then
			hide()
			return
		end
		stepDone()
		for _, d in ipairs(dots) do
			d.current = false
			d.scale.Scale = 1
			d.frame.BackgroundColor3 = C.money
		end
		UI.setText(title, "All done!")
		title.TextColor3 = C.money
		desc.Text = "You're ready! Steal fancier boxes deeper in the warehouse."
		task.delay(3.2, function() ctx.notify("Tip: Trails make your treadmill give way more speed - press Trails!", C.orange) end)
		task.delay(7, function() ctx.notify("Tip: free Gifts + Daily rewards - check the menu on the left!", C.pink) end)
		task.delay(11, function() ctx.notify("Tip: better boxes are deeper in - but their guardians are faster!", UI.rgb(255, 110, 100)) end)
		task.delay(2.8, hide)
	end
	skip.Activated:Connect(function()
		if replay then
			-- in a replay the button goes to the next step
			replay.step = replay.step + 1
			if replay.step > #STEPS then finish(false) end
			return
		end
		finish(true)
	end)

	ctx.restartTutorial = function()
		finished = false
		lastStep = nil
		replay = {step = 1}
		skip.setText("Next")
		skip.setColor(C.green)
		slideIn()
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			local data = ctx.data
			if finished or not data then
				if not finished and tut.Visible and not data then tut.Visible = false end
			elseif replay or not data.TutorialDone then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local plot, root = myPlot()
				local step, msg
				cashBar.frame.Visible = false
				if replay then
					step = replay.step
					msg = STEPS[step].tip
				else
					if player:GetAttribute("OnTreadmill") or (data.SpeedPoints or Config.StartSpeed) > Config.StartSpeed + 5 then triedTreadmill = true end
					local carrying = player:GetAttribute("Carrying")
					local unboxing = next(data.Unboxing or {}) ~= nil
					local cost = Config.TreadmillCost(1)
					if (data.Treadmill or 1) >= 2 or (data.Rebirths or 0) > 0 then
						finish(false)
						continue
					elseif #data.Items == 0 and not unboxing then
						step = carrying and 2 or 1
					elseif #data.Items == 0 then
						step = 3
					elseif not triedTreadmill then
						step = 4
					elseif (data.Cash or 0) < cost then
						step = 5
						cashBar.frame.Visible = true
						cashBar.set((data.Cash or 0) / cost, "$" .. fmt(data.Cash or 0) .. " / $" .. fmt(cost))
					else
						step = 6
					end
					msg = STEPS[step].tip
				end
				if not tut.Visible then slideIn() end
				local target = targetFor(step, hrp, plot, root)
				if step ~= lastStep then
					if lastStep and step > lastStep and not replay then stepDone() end
					lastStep = step
					showStep(step, msg)
					-- show where to go (not while you're carrying a box or running)
					if target and not player:GetAttribute("Carrying") and not player:GetAttribute("OnTreadmill") then
						task.delay(0.6, function() zoomTo(target) end)
					end
				end
				pointAt(target)
			elseif tut.Visible then
				tut.Visible = false
				pointAt(nil)
			end
		end
	end)
end

return Tutorial
