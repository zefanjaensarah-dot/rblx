--[[ BossFX: the bosses' special moves on your screen
     - a title card when a boss wakes up to chase YOU ("AREA 7 BOSS - YETI GUARD - Blizzard Roar")
     - the warning before a special move lands (a glowing zone that fills up) and then the move itself
     - a coloured flash + push when a move hits you
     - themed trails while a boss chases (candy sparkles, sea spray, snow, jet sparks, lava, ghost mist...) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BossFX = {}

function BossFX.init(ctx)
	local Config = ctx.Config
	local player = ctx.player
	local FX = ReplicatedStorage:WaitForChild("StealABoxRemotes"):WaitForChild("FX")
	local world = workspace:WaitForChild("StealABox")
	local folder = Instance.new("Folder")
	folder.Name = "BossFX"
	folder.Parent = workspace
	local WHITE = Color3.new(1, 1, 1)
	local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder upright: thin = a disc on the floor, long = a pillar
	local LINEAR = Enum.EasingStyle.Linear
	local function effectsOn() return not (ctx.settings and ctx.settings.Effects == false) end

	------------------------------------------------------------------
	-- little helpers
	------------------------------------------------------------------
	local function glow(size, cf, color, shape, transp)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color, p.Size, p.CFrame, p.Transparency = color, size, cf, transp or 0.2
		if shape then p.Shape = shape end
		p.Parent = folder
		return p
	end
	-- grow (or shrink) while fading out, then disappear
	local function fade(p, life, size, extra)
		local goal = {Size = size or p.Size, Transparency = 1}
		if extra then for k, v in pairs(extra) do goal[k] = v end end
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
		Debris:AddItem(p, life + 0.1)
	end
	local function burst(pos, count, props)
		if not effectsOn() then count = math.ceil(count * 0.3) end
		local a = Instance.new("Attachment")
		a.Parent = workspace.Terrain
		a.WorldPosition = pos
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-200, 200)
		for k, v in pairs(props) do e[k] = v end
		e.Parent = a
		e:Emit(count)
		Debris:AddItem(a, 4)
	end
	local function near(pos, dist)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		return hrp ~= nil and (hrp.Position - pos).Magnitude < (dist or 80)
	end
	local function shake(pos, t, power)
		if ctx.shake and near(pos, 90) then ctx.shake(t, power) end
	end
	-- the floor under a point (so warnings sit on the ground even under a hovering boss)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function ground(pos)
		local skip = {folder}
		local guards = world:FindFirstChild("Guards")
		if guards then table.insert(skip, guards) end
		for _, p in ipairs(game:GetService("Players"):GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
		rayParams.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams)
		return hit and Vector3.new(pos.X, hit.Position.Y, pos.Z) or pos
	end
	local function sparks(pos, col, n, speed)
		burst(pos, n, {Color = ColorSequence.new(WHITE, col), LightEmission = 1, Size = NumberSequence.new(0.7, 0), Lifetime = NumberRange.new(0.4, 0.9),
			Speed = NumberRange.new(speed * 0.4, speed), Drag = 3, Acceleration = Vector3.new(0, -30, 0)})
	end
	local function shockwave(pos, radius, col)
		local ring = glow(Vector3.new(0.3, radius * 0.4, radius * 0.4), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * FLAT, col, Enum.PartType.Cylinder, 0.15)
		fade(ring, 0.55, Vector3.new(0.3, radius * 2.6, radius * 2.6))
		local core = glow(Vector3.new(0.4, radius * 0.3, radius * 0.3), CFrame.new(pos + Vector3.new(0, 0.35, 0)) * FLAT, WHITE, Enum.PartType.Cylinder, 0.2)
		fade(core, 0.3, Vector3.new(0.4, radius * 1.6, radius * 1.6))
		burst(pos + Vector3.new(0, 1, 0), 30, {Color = ColorSequence.new(Color3.fromRGB(200, 190, 180), Color3.fromRGB(110, 100, 95)), Size = NumberSequence.new(radius * 0.25, radius * 0.5),
			Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(radius * 1.5, radius * 2.5), Drag = 4,
			SpreadAngle = Vector2.new(5, 180), EmissionDirection = Enum.NormalId.Top})
	end
	local function pillar(pos, width, height, col, life)
		local p = glow(Vector3.new(height, width, width), CFrame.new(pos + Vector3.new(0, height / 2, 0)) * FLAT, col, Enum.PartType.Cylinder, 0.25)
		fade(p, life or 0.6, Vector3.new(height, width * 0.15, width * 0.15))
	end
	local function bolt(top, bottom, col)
		local last = top
		for k = 1, 7 do
			local p = top:Lerp(bottom, k / 7)
			if k < 7 then p = p + Vector3.new(math.random(-30, 30) / 10, 0, math.random(-30, 30) / 10) end
			local seg = glow(Vector3.new(0.6, 0.6, (p - last).Magnitude), CFrame.lookAt(last, p) * CFrame.new(0, 0, -(p - last).Magnitude / 2), WHITE, nil, 0)
			fade(seg, 0.35)
			local halo = glow(Vector3.new(1.8, 1.8, (p - last).Magnitude), seg.CFrame, col, nil, 0.5)
			fade(halo, 0.4)
			last = p
		end
	end
	-- crystals / ice shards punching up out of the floor
	local function spikes(pos, radius, n, cols)
		for k = 1, n do
			local a = math.random() * math.pi * 2
			local r = math.random() * radius
			local h = 2 + math.random() * 4
			local base = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local sp = glow(Vector3.new(1.2, 0.2, 1.2), CFrame.new(base) * CFrame.Angles(math.random() * 0.5 - 0.25, a, math.random() * 0.5 - 0.25), cols[k % #cols + 1], nil, 0.1)
			TweenService:Create(sp, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.new(1.2, h, 1.2), CFrame = sp.CFrame * CFrame.new(0, h / 2, 0)}):Play()
			task.delay(0.6, function() fade(sp, 0.5) end)
		end
	end

	------------------------------------------------------------------
	-- BOSS TITLE CARD (when a boss wakes up to chase you)
	------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossFX"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	local band = Instance.new("Frame")
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.32)
	band.Size = UDim2.fromScale(1, 0.19)
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BackgroundTransparency = 1
	band.BorderSizePixel = 0
	band.Visible = false
	band.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 0.2), NumberSequenceKeypoint.new(0.78, 0.2), NumberSequenceKeypoint.new(1, 1)})
	grad.Parent = band
	local pop = Instance.new("UIScale")
	pop.Parent = band
	local function line(y, h, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.Font = font
		l.TextScaled = true
		l.TextColor3 = WHITE
		l.TextStrokeTransparency = 0
		l.Parent = band
		return l
	end
	local areaL = line(0.05, 0.2, Enum.Font.GothamBlack)
	local nameL = line(0.25, 0.5, Enum.Font.LuckiestGuy)
	local moveL = line(0.76, 0.19, Enum.Font.GothamBold)
	local labels = {areaL, nameL, moveL}
	local token = 0
	local function showTitle(area)
		local def = Config.Areas[area]
		if not def then return end
		local ab = Config.BossAbilities[area]
		local col = ab and ab.color or Color3.fromRGB(255, 80, 80)
		token = token + 1
		local my = token
		areaL.Text, areaL.TextColor3 = "AREA " .. area .. " BOSS", col
		nameL.Text = string.upper(def.guard)
		moveL.Text, moveL.TextColor3 = ab and ("SPECIAL MOVE: " .. string.upper(ab.name)) or "RUN!", col
		band.Visible, band.BackgroundTransparency = true, 0.1
		pop.Scale = 2.4
		for _, l in ipairs(labels) do l.TextTransparency, l.TextStrokeTransparency = 0, 0 end
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		task.delay(2.5, function()
			if token ~= my then return end
			for _, l in ipairs(labels) do TweenService:Create(l, TweenInfo.new(0.35), {TextTransparency = 1, TextStrokeTransparency = 1}):Play() end
			TweenService:Create(band, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
			task.delay(0.4, function() if token == my then band.Visible = false end end)
		end)
	end

	------------------------------------------------------------------
	-- THE WARNING: the boss charges up and the floor lights up where the move will land
	------------------------------------------------------------------
	local function telegraph(from, area, info)
		local ab = Config.BossAbilities[area]
		if not ab or not info then return end
		local col, w, s, dir = ab.color, info.windup or 0.9, info.scale or 1, info.dir or Vector3.new(0, 0, -1)
		local core = from + Vector3.new(0, 3.4 * s, 0) + dir * 1.4 * s
		local orb = glow(Vector3.one * 0.6, CFrame.new(core), col, Enum.PartType.Ball, 0.1)
		TweenService:Create(orb, TweenInfo.new(w), {Size = Vector3.one * 2.4 * s}):Play()
		Debris:AddItem(orb, w)
		burst(core, 24, {Color = ColorSequence.new(WHITE, col), LightEmission = 1, Size = NumberSequence.new(0.5 * s, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4 * s, 9 * s), Drag = 5})
		local function zoneWarn(pos, radius)
			local g = ground(pos)
			local base = glow(Vector3.new(0.2, radius * 2, radius * 2), CFrame.new(g + Vector3.new(0, 0.12, 0)) * FLAT, col, Enum.PartType.Cylinder, 0.7)
			local fill = glow(Vector3.new(0.25, 0.5, 0.5), CFrame.new(g + Vector3.new(0, 0.16, 0)) * FLAT, col, Enum.PartType.Cylinder, 0.35)
			TweenService:Create(fill, TweenInfo.new(w, LINEAR), {Size = Vector3.new(0.25, radius * 2, radius * 2)}):Play()
			Debris:AddItem(base, w)
			Debris:AddItem(fill, w)
		end
		if ab.kind == "zone" then
			zoneWarn(info.spots[1], ab.radius)
		elseif ab.kind == "storm" then
			for _, sp in ipairs(info.spots) do zoneWarn(sp, ab.radius) end
		else -- a strip from the boss toward where you were
			local g = ground(from)
			local len, wid = ab.length, ab.width
			local start = CFrame.lookAt(g, g + dir)
			local base = glow(Vector3.new(wid, 0.2, len), start * CFrame.new(0, 0.12, -len / 2), col, nil, 0.7)
			local fill = glow(Vector3.new(wid, 0.25, 0.5), start * CFrame.new(0, 0.16, -0.25), col, nil, 0.35)
			TweenService:Create(fill, TweenInfo.new(w, LINEAR), {Size = Vector3.new(wid, 0.25, len), CFrame = start * CFrame.new(0, 0.16, -len / 2)}):Play()
			Debris:AddItem(base, w)
			Debris:AddItem(fill, w)
		end
	end

	------------------------------------------------------------------
	-- THE MOVE ITSELF (one look per boss)
	------------------------------------------------------------------
	local function strike(from, area, info)
		local ab = Config.BossAbilities[area]
		if not ab or not info then return end
		local col, s, dir = ab.color, info.scale or 1, info.dir or Vector3.new(0, 0, -1)
		local target = ground(info.spots[1])
		local g = ground(from)
		local start = CFrame.lookAt(g, g + dir)
		local len, wid = ab.length or 0, ab.width or 0
		local mid = start * CFrame.new(0, 0, -len / 2)
		if area == 4 then -- SUGAR SLAM: pink shockwave + a fountain of candy
			shockwave(target, ab.radius, col)
			burst(target + Vector3.new(0, 1, 0), 70, {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 95, 180)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 215, 255))}),
				LightEmission = 0.6, Size = NumberSequence.new(0.8, 0.4), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(20, 34), Acceleration = Vector3.new(0, -40, 0),
				SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top})
		elseif area == 5 then -- ANCHOR WAVE: a wall of sea water rolls down the strip
			local wave = glow(Vector3.new(wid, 5, 3), start * CFrame.new(0, 2.5, -1.5), Color3.fromRGB(120, 220, 255), nil, 0.35)
			wave.Material = Enum.Material.Glass
			TweenService:Create(wave, TweenInfo.new(0.55, LINEAR), {CFrame = start * CFrame.new(0, 2.5, -len)}):Play()
			task.delay(0.55, function() fade(wave, 0.3, Vector3.new(wid, 0.5, 3)) end)
			for k = 1, 5 do
				task.delay(k * 0.1, function()
					burst((start * CFrame.new(0, 1, -len * k / 5)).Position, 20, {Color = ColorSequence.new(WHITE, col), Size = NumberSequence.new(1, 0.3), Transparency = NumberSequence.new(0.2, 1),
						Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(12, 20), Acceleration = Vector3.new(0, -50, 0), SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top})
				end)
			end
		elseif area == 6 then -- SHIELD BASH: a red shock plate slams forward
			local plate = glow(Vector3.new(wid, 6, 0.6), start * CFrame.new(0, 3, -1), col, nil, 0.2)
			TweenService:Create(plate, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = start * CFrame.new(0, 3, -len)}):Play()
			task.delay(0.3, function() fade(plate, 0.25, Vector3.new(wid * 1.4, 8, 0.2)) end)
			sparks((start * CFrame.new(0, 2, -len)).Position, col, 40, 26)
		elseif area == 7 then -- BLIZZARD ROAR: a frost cone, ice spikes and snow
			local cone = glow(Vector3.new(wid, 4, len), mid * CFrame.new(0, 2, 0), Color3.fromRGB(200, 235, 255), nil, 0.5)
			fade(cone, 0.6, Vector3.new(wid * 1.3, 6, len))
			for k = 1, 6 do spikes((start * CFrame.new(0, 0, -len * k / 6)).Position, wid / 2, 3, {Color3.fromRGB(190, 235, 255), WHITE}) end
			burst(mid.Position + Vector3.new(0, 3, 0), 60, {Color = ColorSequence.new(WHITE), Size = NumberSequence.new(1.2, 2.5), Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(6, 14), Drag = 2})
		elseif area == 8 then -- LASER SWEEP: a red beam across the floor, then sparks and a scorch line
			local y = 3 * s
			local beam = glow(Vector3.new(1.4, 1.4, len), mid * CFrame.new(0, y * 0.5, 0), WHITE, nil, 0)
			fade(beam, 0.45, Vector3.new(0.2, 0.2, len))
			local halo = glow(Vector3.new(wid, 0.8, len), mid * CFrame.new(0, 0.4, 0), col, nil, 0.3)
			fade(halo, 0.6)
			local scorch = glow(Vector3.new(1.2, 0.1, len), mid * CFrame.new(0, 0.08, 0), Color3.fromRGB(30, 20, 20), nil, 0.2)
			scorch.Material = Enum.Material.SmoothPlastic
			task.delay(1, function() fade(scorch, 1.2) end)
			for k = 1, 6 do sparks((start * CFrame.new(0, 0.5, -len * k / 6)).Position, col, 12, 16) end
		elseif area == 9 then -- TRACTOR BEAM: a green beam with rings sliding back toward the alien
			local beam = glow(Vector3.new(len, wid, wid), mid * CFrame.new(0, wid / 2, 0) * CFrame.Angles(0, math.rad(90), 0), col, Enum.PartType.Cylinder, 0.6)
			fade(beam, 0.8)
			for k = 0, 4 do
				task.delay(k * 0.08, function()
					local ring = glow(Vector3.new(0.4, wid * 1.1, wid * 1.1), start * CFrame.new(0, wid / 2, -len) * CFrame.Angles(0, math.rad(90), 0), col, Enum.PartType.Cylinder, 0.2)
					TweenService:Create(ring, TweenInfo.new(0.5, LINEAR), {CFrame = start * CFrame.new(0, wid / 2, -2) * CFrame.Angles(0, math.rad(90), 0), Size = Vector3.new(0.4, wid * 0.4, wid * 0.4), Transparency = 0.8}):Play()
					Debris:AddItem(ring, 0.55)
				end)
			end
		elseif area == 10 then -- BLACK HOLE: a dark sphere sucks everything in, then implodes
			local hole = glow(Vector3.one * 2, CFrame.new(target + Vector3.new(0, 3, 0)), Color3.new(0, 0, 0), Enum.PartType.Ball, 0)
			hole.Material = Enum.Material.SmoothPlastic
			local disc = glow(Vector3.new(0.3, ab.radius * 2.2, ab.radius * 2.2), CFrame.new(target + Vector3.new(0, 3, 0)) * FLAT, col, Enum.PartType.Cylinder, 0.3)
			TweenService:Create(hole, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.one * 7}):Play()
			TweenService:Create(disc, TweenInfo.new(0.9, LINEAR), {Size = Vector3.new(0.3, 1, 1), CFrame = disc.CFrame * CFrame.Angles(math.rad(360), 0, 0)}):Play()
			task.delay(0.9, function()
				fade(hole, 0.2, Vector3.one * 0.5)
				fade(disc, 0.1)
				sparks(target + Vector3.new(0, 3, 0), col, 50, 30)
			end)
		elseif area == 11 then -- ERUPTION SLAM: shockwave, a lava pillar and flying embers
			shockwave(target, ab.radius, col)
			pillar(target, 5, 26, Color3.fromRGB(255, 150, 40), 0.8)
			burst(target + Vector3.new(0, 1, 0), 60, {Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 60, 10)), LightEmission = 1, Size = NumberSequence.new(0.9, 0),
				Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(20, 40), Acceleration = Vector3.new(0, -45, 0), SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top})
		elseif area == 12 then -- SPECTRAL SLASH: three ghostly blades sweep down the strip
			for k = 0, 2 do
				task.delay(k * 0.07, function()
					local blade = glow(Vector3.new(wid, 0.3, 2.2), start * CFrame.new(0, 2.5 + k, -2) * CFrame.Angles(0, 0, math.rad(-20 + k * 20)), (k == 1) and WHITE or col, nil, 0.15)
					TweenService:Create(blade, TweenInfo.new(0.35, LINEAR), {CFrame = start * CFrame.new(0, 2.5 + k, -len) * CFrame.Angles(0, 0, math.rad(-20 + k * 20)), Transparency = 0.7}):Play()
					Debris:AddItem(blade, 0.4)
				end)
			end
			burst(mid.Position + Vector3.new(0, 2, 0), 40, {Color = ColorSequence.new(WHITE, col), LightEmission = 1, Size = NumberSequence.new(1.5, 0), Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(3, 8)})
		elseif area == 13 then -- PRISM QUAKE: shockwave + crystals bursting out of the floor
			shockwave(target, ab.radius, col)
			spikes(target, ab.radius, 16, {col, Color3.fromRGB(255, 140, 216), WHITE})
			sparks(target + Vector3.new(0, 1, 0), col, 40, 24)
		elseif area == 14 then -- THUNDER CALL: lightning bolts strike every marked spot
			for k, sp in ipairs(info.spots) do
				task.delay((k - 1) * 0.08, function()
					local p = ground(sp)
					bolt(p + Vector3.new(0, 55, 0), p, col)
					shockwave(p, ab.radius, col)
					sparks(p + Vector3.new(0, 1, 0), col, 25, 22)
				end)
			end
		elseif area == 15 then -- INFERNO BREATH: a roaring cone of fire
			for k = 1, 8 do
				task.delay(k * 0.04, function()
					local p = (start * CFrame.new(0, 2 + k * 0.15, -len * k / 8)).Position
					burst(p, 26, {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 20)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 10))}),
						LightEmission = 1, Size = NumberSequence.new(wid * (0.15 + k * 0.05), wid * (0.3 + k * 0.06)), Transparency = NumberSequence.new(0.1, 1),
						Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(4, 10), Drag = 2})
				end)
			end
			local core = glow(Vector3.new(wid * 0.6, 3, len), mid * CFrame.new(0, 2, 0), Color3.fromRGB(255, 160, 40), nil, 0.4)
			fade(core, 0.6, Vector3.new(wid, 5, len))
		end
		shake(target, 0.45, 5)
	end

	------------------------------------------------------------------
	-- CHASE TRAILS: each boss leaves its own trail while it's after someone
	------------------------------------------------------------------
	local TRAIL = {
		[4] = {Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 230, 90), 0.5, 0.9, 6, 30, 1, -15},
		[5] = {Color3.fromRGB(230, 250, 255), Color3.fromRGB(90, 210, 240), 0.5, 0.7, 10, 30, 0.3, -40},
		[6] = {Color3.fromRGB(255, 60, 60), Color3.fromRGB(70, 110, 255), 0.4, 0.4, 4, 25, 1, 0},
		[7] = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 230, 255), 1.2, 1, 5, 25, 0, -5},
		[8] = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(60, 150, 255), 0.4, 0.35, 14, 40, 1, 0},
		[9] = {Color3.fromRGB(210, 255, 200), Color3.fromRGB(70, 220, 70), 0.6, 0.6, 4, 25, 1, -10},
		[10] = {Color3.fromRGB(150, 70, 230), Color3.fromRGB(20, 6, 30), 1.4, 1, 2, 25, 0.2, 2},
		[11] = {Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 60, 10), 0.35, 1.2, 4, 40, 1, 10},
		[12] = {Color3.fromRGB(190, 255, 240), Color3.fromRGB(120, 90, 220), 1.4, 1, 2, 22, 0.6, 3},
		[13] = {Color3.fromRGB(150, 245, 255), Color3.fromRGB(255, 140, 216), 0.4, 0.7, 8, 25, 1, -20},
		[14] = {Color3.fromRGB(245, 248, 255), Color3.fromRGB(150, 160, 190), 1.6, 1.2, 3, 25, 0.1, 0},
		[15] = {Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 50, 10), 0.5, 1, 4, 40, 1, 12},
	}
	local function addTrail(model)
		local area = model:GetAttribute("Area")
		local t = area and TRAIL[area]
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not t or not root or root:FindFirstChild("BossTrail") then return end
		local s = model:GetAttribute("Scale") or 1
		local at = Instance.new("Attachment")
		at.Name = "BossTrail"
		at.Position = Vector3.new(0, -2.6 * s, 0.6 * s)
		at.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(t[1], t[2])
		e.Size = NumberSequence.new(t[3] * s, 0)
		e.Lifetime = NumberRange.new(t[4] * 0.6, t[4])
		e.Speed = NumberRange.new(t[5] * 0.5, t[5])
		e.Rate = t[6]
		e.LightEmission = t[7]
		e.Acceleration = Vector3.new(0, t[8], 0)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.SpreadAngle = Vector2.new(60, 60)
		e.EmissionDirection = Enum.NormalId.Top
		e.Rotation = NumberRange.new(0, 360)
		e.Enabled = false
		e.Parent = at
		local function sync() e.Enabled = model:GetAttribute("Mode") == "chase" and effectsOn() end
		model:GetAttributeChangedSignal("Mode"):Connect(sync)
		sync()
	end
	task.spawn(function()
		local guards = world:WaitForChild("Guards", 30)
		if not guards then return end
		for _, m in ipairs(guards:GetChildren()) do if m:IsA("Model") then addTrail(m) end end
		guards.ChildAdded:Connect(function(m) if m:IsA("Model") then task.wait() addTrail(m) end end)
	end)

	------------------------------------------------------------------
	-- EVENTS FROM THE SERVER
	------------------------------------------------------------------
	FX.OnClientEvent:Connect(function(kind, pos, area, info)
		if kind == "BossIntro" then
			showTitle(area)
		elseif kind == "BossCast" then
			if near(pos, 160) then telegraph(pos, area, info) end
		elseif kind == "BossHit" then
			if near(pos, 160) then strike(pos, area, info) end
		elseif kind == "BossHitYou" then
			local ab = Config.BossAbilities[area]
			flash.BackgroundColor3 = ab and ab.color or WHITE
			flash.BackgroundTransparency = 0.45
			TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and typeof(info) == "Vector3" then hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + info end
			if ctx.shake then ctx.shake(0.4, 6) end
		end
	end)
end

return BossFX
