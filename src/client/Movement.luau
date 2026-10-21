--[[ Movement: a parkour movement system on top of the normal Roblox controls
     DASH        Q / gamepad X / the DASH button: a burst in the way you're moving (3 charges that refill)
     DOUBLE JUMP press jump again in the air: a second jump with a front flip (once per jump)
     WALL RUN    jump at a wall from the side while moving: you run along it for a moment
     WALL JUMP   jump while wall running: kick off the wall (refills your double jump)
     SLIDE       C / Ctrl / gamepad B / the SLIDE button while running: a fast low slide
     + landing impacts, speed lines, FOV kicks, camera tilt on walls, and a dash bar at the bottom.
     Carrying a box makes dashes and slides weaker (Config.Movement). Others see your bursts too. ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Movement = {}
local WHITE = Color3.new(1, 1, 1)
local HState = Enum.HumanoidStateType

function Movement.init(ctx)
	local Config = ctx.Config
	local M = Config.Movement
	local player = ctx.player
	local remote = ReplicatedStorage:WaitForChild("StealABoxRemotes"):WaitForChild("MoveFX", 10)
	local fx = Instance.new("Folder")
	fx.Name = "MovementFX"
	fx.Parent = workspace
	local function effectsOn() return not (ctx.settings and ctx.settings.Effects == false) end

	------------------------------------------------------------------
	-- effects (also played for other players when they dash / jump)
	------------------------------------------------------------------
	local function glow(size, cf, transp, shape)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color, p.Size, p.CFrame, p.Transparency = WHITE, size, cf, transp or 0.3
		if shape then p.Shape = shape end
		p.Parent = fx
		return p
	end
	local function fade(p, life, size)
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = size, Transparency = 1}):Play()
		Debris:AddItem(p, life + 0.05)
	end
	-- a thin ring facing `dir` that grows and fades (a cylinder seen end-on)
	local function ring(pos, dir, d0, d1, life)
		local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
		local r = glow(Vector3.new(0.12, d0, d0), cf, 0.35, Enum.PartType.Cylinder)
		fade(r, life or 0.35, Vector3.new(0.05, d1, d1))
	end
	local function burst(pos, n, speed)
		local a = Instance.new("Attachment")
		a.Parent = workspace.Terrain
		a.WorldPosition = pos
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Color = ColorSequence.new(WHITE)
		e.LightEmission = 0.5
		e.Size = NumberSequence.new(0.5, 0)
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 4
		e.Parent = a
		e:Emit(n)
		Debris:AddItem(a, 1)
	end
	-- the "+" sparkle where you kick off a wall
	local function sparkle(pos, normal)
		local cf = CFrame.lookAt(pos, pos + normal)
		for _, rot in ipairs({0, 90}) do
			local s = glow(Vector3.new(0.25, 3.2, 0.1), cf * CFrame.Angles(0, 0, math.rad(rot)), 0.05)
			fade(s, 0.3, Vector3.new(0.05, 5, 0.05))
		end
	end
	local function play(kind, hrp, dir)
		if not hrp or not effectsOn() then return end
		local pos = hrp.Position
		dir = (dir and dir.Magnitude > 0.1) and dir.Unit or hrp.CFrame.LookVector
		if kind == "dash" then
			ring(pos, dir, 2, 7, 0.3)
			task.delay(0.06, function() ring(pos + dir * 3, dir, 2.5, 9, 0.35) end)
			burst(pos, 10, 14)
		elseif kind == "djump" then
			local feet = pos - Vector3.new(0, 2.6, 0)
			ring(feet, Vector3.yAxis, 2, 9, 0.4)
			task.delay(0.05, function() ring(feet - Vector3.new(0, 0.8, 0), Vector3.yAxis, 1.5, 6, 0.35) end)
		elseif kind == "wjump" then
			sparkle(pos - dir * 1.2, dir)
			ring(pos, dir, 2, 6, 0.3)
		elseif kind == "slide" then
			burst(pos - Vector3.new(0, 2.6, 0), 14, 8)
		elseif kind == "land" then
			local feet = pos - Vector3.new(0, 2.9, 0)
			ring(feet, Vector3.yAxis, 3, 12, 0.4)
			burst(feet, 16, 12)
		end
	end
	-- other players' moves
	if remote then
		remote.OnClientEvent:Connect(function(kind, who, dir)
			if who == player or typeof(who) ~= "Instance" then return end
			local c = who.Character
			play(kind, c and c:FindFirstChild("HumanoidRootPart"), typeof(dir) == "Vector3" and dir or nil)
		end)
	end
	local lastSent = 0
	local function tell(kind, dir)
		if remote and os.clock() - lastSent > 0.12 then
			lastSent = os.clock()
			remote:FireServer(kind, dir)
		end
	end

	------------------------------------------------------------------
	-- the dash bar (bottom middle)
	------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "MovementHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local barRow = Instance.new("Frame")
	barRow.AnchorPoint = Vector2.new(0.5, 1)
	barRow.Position = UDim2.new(0.5, 0, 1, -8)
	barRow.Size = UDim2.fromOffset(M.dashCharges * 34, 6)
	barRow.BackgroundTransparency = 1
	barRow.Parent = gui
	local pips = {}
	for i = 1, M.dashCharges do
		local back = Instance.new("Frame")
		back.Position = UDim2.fromOffset((i - 1) * 34 + 2, 0)
		back.Size = UDim2.fromOffset(30, 6)
		back.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		back.BackgroundTransparency = 0.5
		back.BorderSizePixel = 0
		back.Parent = barRow
		local c1 = Instance.new("UICorner")
		c1.CornerRadius = UDim.new(1, 0)
		c1.Parent = back
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = WHITE
		fill.BorderSizePixel = 0
		fill.Parent = back
		local c2 = Instance.new("UICorner")
		c2.CornerRadius = UDim.new(1, 0)
		c2.Parent = fill
		pips[i] = fill
	end

	------------------------------------------------------------------
	-- state
	------------------------------------------------------------------
	local char, hum, hrp, joint, jointC0
	local trails = {}
	local charges, recharge = M.dashCharges, 0
	local dashUntil, dashDir, dashSpeed = 0, nil, 0
	local airDashed, doubleJumped, leftGround = false, false, 0
	local wall, wallCooldown = nil, 0
	local slideUntil, slideDir, slideStart = 0, nil, 0
	local flipStart = nil
	local lastJump, fallSpeed = 0, 0
	local fovKick, camRoll, fovApplied = 0, 0, 0

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	pcall(function() rayParams.CollisionGroup = Config.GroupPlayers end) -- (only real, solid walls)

	local function trailOn(on)
		for _, t in ipairs(trails) do t.Enabled = on and effectsOn() end
	end
	local function setup(c)
		char, hum, hrp, joint, wall = c, nil, nil, nil, nil
		hum = c:WaitForChild("Humanoid", 10)
		hrp = c:WaitForChild("HumanoidRootPart", 10)
		if not hum or not hrp then return end
		local lower = c:FindFirstChild("LowerTorso")
		joint = hrp:FindFirstChild("RootJoint") or (lower and lower:FindFirstChild("Root"))
		jointC0 = joint and joint.C0
		rayParams.FilterDescendantsInstances = {c, fx}
		trails = {}
		-- speed lines from the hands and feet (on while dashing, sliding, wall running, flipping)
		for _, spot in ipairs({{-0.5, -2.6}, {0.5, -2.6}, {-1.5, -0.4}, {1.5, -0.4}}) do
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(spot[1], spot[2], 0)
			a0.Parent = hrp
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(spot[1], spot[2] + 0.18, 0)
			a1.Parent = hrp
			local t = Instance.new("Trail")
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = ColorSequence.new(WHITE)
			t.LightEmission = 0.6
			t.Lifetime = 0.28
			t.Transparency = NumberSequence.new(0.15, 1)
			t.FaceCamera = true
			t.Enabled = false
			t.Parent = hrp
			table.insert(trails, t)
		end
		hum.StateChanged:Connect(function(_, new)
			if new == HState.Landed then
				if fallSpeed > M.landImpactSpeed then
					play("land", hrp)
					tell("land")
					if ctx.shake then ctx.shake(0.2, math.min(6, fallSpeed / 20)) end
				end
				airDashed, doubleJumped, wall = false, false, nil
			elseif new == HState.Freefall or new == HState.Jumping then
				leftGround = os.clock()
			end
		end)
	end
	if player.Character then task.spawn(setup, player.Character) end
	player.CharacterAdded:Connect(setup)

	local function busy()
		if not hum or not hrp or hum.Health <= 0 or hum.Sit or hum.PlatformStand then return true end
		if hum:GetState() == HState.Physics then return true end -- (ragdolled by a boss)
		if player:GetAttribute("OnTreadmill") then return true end
		if ctx.UI and ctx.UI.isOpen and ctx.UI.isOpen("Phone") then return true end
		local ok, tb = pcall(function() return UserInputService:GetFocusedTextBox() end)
		return ok and tb ~= nil
	end
	local function airborne()
		local s = hum:GetState()
		return s == HState.Freefall or s == HState.Jumping
	end
	local function moveDir()
		local d = hum.MoveDirection
		if d.Magnitude > 0.1 then return Vector3.new(d.X, 0, d.Z).Unit end
		local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or hrp.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		return look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	end
	local function carryMult() return player:GetAttribute("Carrying") and M.carryMult or 1 end

	------------------------------------------------------------------
	-- the moves
	------------------------------------------------------------------
	local function dash()
		if busy() or charges < 1 or os.clock() < dashUntil then return end
		if airborne() and airDashed then return end
		if airborne() then airDashed = true end
		charges = charges - 1
		dashDir = moveDir()
		dashSpeed = math.max(M.dashSpeed, hum.WalkSpeed * 2.2) * carryMult()
		dashUntil = os.clock() + M.dashTime
		wall, slideUntil = nil, 0
		hrp.AssemblyLinearVelocity = dashDir * dashSpeed + Vector3.new(0, airborne() and 4 or 0, 0)
		trailOn(true)
		fovKick = 14
		play("dash", hrp, dashDir)
		tell("dash", dashDir)
	end
	local function slide()
		if busy() or airborne() or os.clock() < slideUntil or hum.MoveDirection.Magnitude < 0.5 then return end
		slideDir = moveDir()
		slideStart = os.clock()
		slideUntil = slideStart + M.slideTime
		trailOn(true)
		fovKick = 8
		play("slide", hrp)
		tell("slide")
	end
	local function jumpPressed()
		if busy() then return end
		local now = os.clock()
		local held = now - lastJump < 0.15 -- (a held jump button keeps firing: only a fresh press counts)
		lastJump = now
		if held then return end
		if wall then
			-- WALL JUMP: kick off the wall, up and away
			local n = wall.normal
			hrp.AssemblyLinearVelocity = n * M.wallJumpOut + Vector3.new(0, M.wallJumpUp, 0) + wall.tangent * 18
			sparkle(hrp.Position - n * 1.2, n)
			play("wjump", hrp, n)
			tell("wjump", n)
			wall, wallCooldown = nil, now + 0.3
			doubleJumped = false
			flipStart = now
			return
		end
		if airborne() and not doubleJumped and now - leftGround > 0.12 then
			-- DOUBLE JUMP with a front flip
			doubleJumped = true
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, M.doubleJumpPower, v.Z)
			flipStart = now
			trailOn(true)
			play("djump", hrp)
			tell("djump")
		elseif os.clock() < slideUntil then
			slideUntil = 0 -- (jumping out of a slide keeps its speed)
		end
	end

	-- inputs: keyboard, gamepad and on-screen buttons (phones / tablets)
	pcall(function()
		ContextActionService:BindAction("SAB_Dash", function(_, state)
			if state == Enum.UserInputState.Begin then dash() end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("SAB_Dash", "DASH")
		ContextActionService:BindAction("SAB_Slide", function(_, state)
			if state == Enum.UserInputState.Begin then slide() end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("SAB_Slide", "SLIDE")
	end)
	pcall(function() UserInputService.JumpRequest:Connect(jumpPressed) end)

	------------------------------------------------------------------
	-- every frame
	------------------------------------------------------------------
	RunService.Heartbeat:Connect(function(dt)
		-- the dash bar
		if charges < M.dashCharges then
			recharge = recharge + dt / (M.dashRecharge / carryMult())
			if recharge >= 1 then
				recharge = 0
				charges = charges + 1
			end
		else
			recharge = 0
		end
		for i, p in ipairs(pips) do
			local f = (i <= charges) and 1 or ((i == charges + 1) and recharge or 0)
			p.Size = UDim2.fromScale(f, 1)
			p.BackgroundTransparency = (i <= charges) and 0 or 0.5
		end
		if not hum or not hrp or not hrp.Parent then return end
		local now = os.clock()
		local v = hrp.AssemblyLinearVelocity
		if airborne() then fallSpeed = math.max(0, -v.Y) end
		local stop = busy()
		-- DASH: hold the burst for a moment (in the air it also holds your height)
		if now < dashUntil and dashDir and not stop then
			hrp.AssemblyLinearVelocity = Vector3.new(dashDir.X * dashSpeed, airborne() and math.max(v.Y, -2) or v.Y, dashDir.Z * dashSpeed)
		end
		-- SLIDE: fast at first, then slows down to your normal speed
		if now < slideUntil and slideDir and not stop then
			local k = 1 - (now - slideStart) / M.slideTime
			local sp = hum.WalkSpeed + (math.max(M.slideSpeed, hum.WalkSpeed * 1.8) * carryMult() - hum.WalkSpeed) * k
			hrp.AssemblyLinearVelocity = Vector3.new(slideDir.X * sp, v.Y, slideDir.Z * sp)
			hum.CameraOffset = Vector3.new(0, -1.4 * math.min(1, k * 3), 0)
		elseif hum.CameraOffset.Y < 0 then
			hum.CameraOffset = Vector3.new(0, math.min(0, hum.CameraOffset.Y + dt * 6), 0)
		end
		-- WALL RUN: jumping at a wall from the side while moving sticks you to it for a moment
		if not stop and airborne() and now > wallCooldown and now >= dashUntil and hum.MoveDirection.Magnitude > 0.5 then
			if not wall or now - wall.t0 > M.wallRunTime then
				if wall then wall, wallCooldown = nil, now + 0.4 end
				if not wall and now > wallCooldown and Vector3.new(v.X, 0, v.Z).Magnitude > 8 then
					for _, side in ipairs({-1, 1}) do
						local hit = workspace:Raycast(hrp.Position, hrp.CFrame.RightVector * side * 3, rayParams)
						if hit and hit.Instance.Transparency < 0.9 and math.abs(hit.Normal.Y) < 0.3 then
							local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
							local md = hum.MoveDirection
							local tan = (md - n * md:Dot(n))
							if tan.Magnitude > 0.2 then
								wall = {normal = n, tangent = tan.Unit, side = side, t0 = now}
								airDashed, doubleJumped = false, false
								trailOn(true)
								break
							end
						end
					end
				end
			end
		elseif wall and (not airborne() or stop) then
			wall = nil
		end
		if wall then
			local still = workspace:Raycast(hrp.Position, -wall.normal * 3.4, rayParams)
			if not still then
				wall = nil
			else
				local sp = math.max(hum.WalkSpeed * 1.15, 24)
				hrp.AssemblyLinearVelocity = wall.tangent * sp - wall.normal * 3 + Vector3.new(0, -3, 0)
			end
		end
		-- speed lines on while something's happening
		if now >= dashUntil and now >= slideUntil and not wall and not flipStart then trailOn(false) end
		-- the body: a front flip after a double jump, a lean into the wall, a lean back in a slide
		if joint and jointC0 then
			local rot = CFrame.new()
			if flipStart then
				local p = (now - flipStart) / 0.42
				if p >= 1 then flipStart = nil else rot = CFrame.Angles(-math.pi * 2 * (1 - (1 - p) ^ 2), 0, 0) end
			elseif wall then
				rot = CFrame.Angles(0, 0, math.rad(22) * -wall.side)
			elseif now < slideUntil then
				rot = CFrame.Angles(math.rad(28), 0, 0)
			end
			joint.C0 = jointC0 * rot
		end
	end)
	-- camera: an FOV kick on dashes, a tilt while wall running
	pcall(function()
		RunService:BindToRenderStep("SAB_MoveCam", Enum.RenderPriority.Camera.Value + 2, function(dt)
			local cam = workspace.CurrentCamera
			if not cam then return end
			fovKick = fovKick + (0 - fovKick) * math.min(1, dt * 7)
			local wantRoll = wall and math.rad(8) * wall.side or 0
			camRoll = camRoll + (wantRoll - camRoll) * math.min(1, dt * 8)
			cam.FieldOfView = cam.FieldOfView - fovApplied + fovKick -- (on top of any other FOV effect)
			fovApplied = fovKick
			if math.abs(camRoll) > 0.001 then cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, camRoll) end
		end)
	end)
	-- (the moves, for the smoke test)
	return {dash = dash, slide = slide, jump = jumpPressed, charges = function() return charges end}
end

return Movement
