--[[ BOXTOK (phone app): a TikTok-style feed. Swipe up / down (or scroll, or the arrow keys) to
     flick between short clips. Every clip is a live 3D scene made from the game's real models:
     the bosses, boxes and items. Big moments from players in YOUR server - a rare unbox, a
     giant steal, getting bonked by a boss - are posted to the feed (LIVE) and can be liked.
     Double-tap a clip to like it, tap the speech bubble for comments.
     Real videos: put Roblox video asset ids in Config.BoxTokVideos and they show up in the feed. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("StealABoxConfig"))

local CLIP = 9 -- seconds a clip runs before it loops (the progress bar)
local CREATORS = {"boxbandit", "warehouse.wally", "speedy_sam", "unboxqueen", "thiefcam", "lootgoblin", "shelfstocker", "bossrater", "forklift.fred", "rare.pulls"}
local BOSS_LINES = {
	"pov: you grabbed a box in %s and the %s woke up",
	"the %s really said NO",
	"%s speedrun any%% (i did not make it)",
	"this %s has no chill fr",
	"rating every boss: the %s is a solid 10/10",
	"me walking past the %s with a Giant box",
}
local BOX_LINES = {"rate my pull 1-10", "%s unboxing ASMR", "this %s is lowkey the best box in the game", "found this on the top shelf", "is this rare or am i tripping"}
local ITEM_LINES = {"my shelf is finally complete", "the %s hits different", "unboxed a %s first try", "pov: your shop after 3 days of grinding"}
local COMMENTS = {"W", "how do you get that", "the yeti is so scary", "bro got bonked", "first", "i got that yesterday", "drop your speed",
	"this is so real", "wait whats the best area", "galaxy boxes are rigged fr", "the dragon king took my giant box", "how many speed is that",
	"teach me pls", "LETS GOOO", "no way", "my treadmill is crying"}

local function pick(list) return list[math.random(1, #list)] end
local function short(n)
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end
local function areaAccent(a) return (Config.Areas[a] and Config.Areas[a].accent) or Color3.fromRGB(255, 80, 140) end

-- a made-up post from one of the BoxTok creators
local function genPost(n)
	local kind = (n % 4 == 0) and "item" or ((n % 3 == 0) and "box" or "boss")
	local post = {kind = kind, user = pick(CREATORS), likes = math.random(80, 95000), comments = math.random(4, 2400)}
	local maxArea = #Config.Areas
	local a = math.random(1, maxArea)
	post.area = a
	local area = Config.Areas[a]
	if kind == "boss" then
		local line = pick(BOSS_LINES)
		post.text = (line:find("%%s.*%%s")) and string.format(line, area.name, area.guard) or string.format(line, area.guard)
	elseif kind == "box" then
		local b = area.boxes[math.random(1, #area.boxes)]
		post.box = b.id
		local line = pick(BOX_LINES)
		post.text = line:find("%%s") and string.format(line, b.name) or line
	else
		local ids = Config.AreaItems and Config.AreaItems[a]
		local tier = ids and ids[math.random(1, #ids)]
		local id = tier and tier[1]
		post.item = {id = id or "", mutation = (math.random() < 0.3) and "Gold" or "Normal", size = "Normal"}
		local def = id and Config.Items[id]
		local line = pick(ITEM_LINES)
		post.text = line:find("%%s") and string.format(line, def and def.name or "item") or line
	end
	return post
end

-- the caption for a real moment from this server
local function liveText(post)
	if post.kind == "unbox" and post.item then
		local def = Config.Items[post.item.id]
		local mut = (post.item.mutation and post.item.mutation ~= "Normal") and (string.upper(post.item.mutation) .. " ") or ""
		local size = Config.SizeText and Config.SizeText(post.item.size)
		return "just unboxed a " .. mut .. (def and def.name or "mystery item") .. ((size and size ~= "") and (" (" .. size .. ")") or "") .. "!!"
	elseif post.kind == "steal" then
		local def = Config.Boxes[post.box]
		local mut = (post.mutation and post.mutation ~= "Normal") and (string.upper(post.mutation) .. " ") or ""
		local size = Config.SizeText and Config.SizeText(post.size)
		return "stole a " .. mut .. (def and def.name or "box") .. ((size and size ~= "") and (" (" .. size .. ")") or "") .. " from Area " .. tostring(post.area or 1)
	elseif post.kind == "bonk" then
		local area = Config.Areas[post.area or 1]
		return "got BONKED by the " .. (area and area.guard or "boss") .. " lol"
	end
	return post.text or ""
end

------------------------------------------------------------------
-- 3D: copies of the real models from the map, posed in a ViewportFrame
------------------------------------------------------------------
local function strip(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("ProximityPrompt") or d:IsA("Fire") or d:IsA("Light")
			or d:IsA("Sound") or d:IsA("BaseScript") or d:IsA("Trail") or d:IsA("Beam") then
			d:Destroy()
		end
	end
end
local function cloneGuard(area)
	local world = workspace:FindFirstChild("StealABox")
	local guards = world and world:FindFirstChild("Guards")
	local src = guards and guards:FindFirstChild("Guardian" .. tostring(area))
	if not src then return nil end
	local m = src:Clone()
	strip(m)
	return m
end
local function cloneBox(boxId)
	local world = workspace:FindFirstChild("StealABox")
	local holder = world and world:FindFirstChild("ActiveBoxes")
	if not holder then return nil end
	local src, all = nil, holder:GetChildren()
	for _, b in ipairs(all) do if b:GetAttribute("BoxId") == boxId then src = b break end end
	if not src and #all > 0 then src = all[math.random(1, #all)] end
	if not src then return nil end
	local part = src:Clone()
	part.Anchored = true
	local m = Instance.new("Model")
	part.Parent = m
	m.PrimaryPart = part
	strip(m)
	return m
end

local function build(env)
	local K = env.kit
	local UI, C, new, rgb, V2, S2, WHITE = K.UI, K.C, K.new, K.rgb, K.V2, K.S2, K.WHITE
	local clamp, lerp, frame, round, grad, text = K.clamp, K.lerp, K.frame, K.round, K.grad, K.text
	local PINK, CYAN = rgb(255, 60, 120), rgb(60, 230, 240)
	local pg = env.page("BoxTok", {title = "BoxTok", color = PINK, bg0 = rgb(16, 16, 22), bg1 = rgb(8, 8, 12)})
	-- (no score / pause here: it's not a game)
	local bar = pg.frame:FindFirstChild("AppBar")
	if bar then
		for _, c in ipairs(bar:GetChildren()) do
			if c.Name == "Pause" or (c:IsA("Frame") and c.Name ~= "Back") then c.Visible = false end
		end
	end
	local content = pg.content
	content.ClipsDescendants = true
	local app = {}
	local remote = ReplicatedStorage:WaitForChild("StealABoxRemotes"):FindFirstChild("BoxTok")
	local feed, idx, made = {}, 1, 0
	local cur = nil -- the card on screen
	local liked = {} -- [post] = true
	local open = false

	local function more(n)
		for _ = 1, n do
			made = made + 1
			table.insert(feed, genPost(made))
			local vids = Config.BoxTokVideos
			if vids and #vids > 0 and made % 4 == 0 then
				local v = vids[math.random(1, #vids)]
				table.insert(feed, {kind = "video", video = v.id, user = v.user or "boxtok", text = v.caption or "", likes = math.random(500, 60000), comments = math.random(10, 900)})
			end
		end
	end
	more(8)

	------------------------------------------------------------------
	-- little drawn icons (no emoji)
	------------------------------------------------------------------
	local function heartIcon(parent, color, z)
		local h = frame(parent, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.42), Size = S2(0.7, 0.7), BackgroundTransparency = 1, ZIndex = z})
		K.square(h)
		local bits = {}
		for k, spec in ipairs({{0.3, 0.36, 0.52, 0}, {0.7, 0.36, 0.52, 0}, {0.5, 0.58, 0.5, 45}}) do
			local f = frame(h, {AnchorPoint = V2(0.5, 0.5), Position = S2(spec[1], spec[2]), Size = S2(spec[3], spec[3]), Rotation = spec[4], BackgroundColor3 = color, ZIndex = z})
			round(f, k < 3 and true or 0.15)
			bits[k] = f
		end
		return h, bits
	end
	local function setHeart(bits, color) for _, b in ipairs(bits) do b.BackgroundColor3 = color end end

	------------------------------------------------------------------
	-- ONE CARD = one clip: the 3D scene + the overlay (creator, caption, like / comment / share)
	------------------------------------------------------------------
	local function makeCard(post)
		local card = {post = post, t = 0}
		local accent = areaAccent(post.area or 1)
		local f = frame(content, {Name = "Card", Size = S2(1, 1), BackgroundColor3 = WHITE, ZIndex = 2, ClipsDescendants = true})
		round(f, 16)
		grad(f, accent:Lerp(rgb(0, 0, 0), 0.55), rgb(10, 10, 16), 90)
		card.frame = f
		-- light rays spinning behind unboxes and steals
		if post.kind == "unbox" or post.kind == "item" or post.kind == "steal" or post.kind == "box" then
			local rays = frame(f, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.42), Size = S2(1.6, 1.6), BackgroundTransparency = 1, ZIndex = 2})
			K.square(rays)
			for k = 0, 5 do
				local r = frame(rays, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(0.16, 1), Rotation = k * 30, BackgroundColor3 = accent, BackgroundTransparency = 0.82, ZIndex = 2})
				round(r, 0.5)
			end
			card.rays = rays
		end
		-- THE CLIP
		if post.kind == "video" and post.video then
			local ok, vf = pcall(function()
				return new("VideoFrame", {Size = S2(1, 1), BackgroundTransparency = 1, Looped = true, Volume = 0.6, Video = post.video, ZIndex = 3}, f)
			end)
			if ok and vf then
				card.video = vf
				pcall(function() vf:Play() end)
			end
		else
			local vp = new("ViewportFrame", {Size = S2(1, 0.86), BackgroundTransparency = 1, Ambient = rgb(165, 165, 175), LightColor = rgb(255, 250, 240),
				LightDirection = Vector3.new(-1, -1.4, -0.8), ZIndex = 3}, f)
			local cam = new("Camera", {FieldOfView = 38}, vp)
			vp.CurrentCamera = cam
			card.vp, card.cam = vp, cam
			pcall(function()
				local model
				if post.kind == "boss" or post.kind == "bonk" then model = cloneGuard(post.area or 1)
				elseif post.kind == "box" or post.kind == "steal" then model = cloneBox(post.box)
				elseif (post.kind == "item" or post.kind == "unbox") and post.item and Config.Items[post.item.id] then
					model = Config.BuildItemModel(post.item, 1, CFrame.new())
				end
				if not model then return end
				model.Parent = vp
				model:PivotTo(CFrame.new())
				local cf, size = model:GetBoundingBox()
				card.model, card.r, card.center = model, math.max(size.X, size.Y, size.Z), cf.Position
				card.front = model:GetPivot().LookVector
			end)
		end
		-- RIGHT COLUMN: creator, like, comments, share, the spinning record
		-- (sized by the card's height, so it stays a slim column on wide screens too)
		local col = frame(f, {AnchorPoint = V2(1, 1), Position = S2(0.98, 0.9), Size = S2(0.3, 0.62), BackgroundTransparency = 1, ZIndex = 6})
		new("UIAspectRatioConstraint", {AspectRatio = 0.3, DominantAxis = Enum.DominantAxis.Height}, col)
		local avatar = frame(col, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0), Size = S2(0.8, 0.24), BackgroundColor3 = accent, ZIndex = 6})
		K.square(avatar)
		round(avatar, true)
		UI.stroke(avatar, 2, WHITE)
		text(avatar, string.upper(string.sub(post.user or "?", 1, 1)), {Size = S2(1, 1), Stroke = 1.5, MaxSize = 30, ZIndex = 7})
		if post.userId then
			local img = new("ImageLabel", {Size = S2(1, 1), BackgroundTransparency = 1, ZIndex = 8}, avatar)
			round(img, true)
			task.spawn(function()
				local ok, url = pcall(function() return Players:GetUserThumbnailAsync(post.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
				if ok and url and img.Parent then img.Image = url end
			end)
		end
		local plus = frame(avatar, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 1), Size = S2(0.36, 0.36), BackgroundColor3 = PINK, ZIndex = 9})
		round(plus, true)
		text(plus, "+", {Size = S2(1, 1), Stroke = 0, MaxSize = 16, ZIndex = 10})
		local function actionButton(y, label)
			local b = new("TextButton", {Text = "", AutoButtonColor = false, AnchorPoint = V2(0.5, 0), Position = S2(0.5, y), Size = S2(1, 0.19), BackgroundTransparency = 1, ZIndex = 6}, col)
			local cnt = text(b, label, {AnchorPoint = V2(0.5, 1), Position = S2(0.5, 1), Size = S2(1.3, 0.3), Stroke = 1.5, MaxSize = 14, ZIndex = 7})
			UI.pressable(b)
			return b, cnt
		end
		local likeB, likeT = actionButton(0.29, short(post.likes or 0))
		local _, hbits = heartIcon(likeB, liked[post] and PINK or WHITE, 7)
		card.likeT, card.hbits = likeT, hbits
		local comB = actionButton(0.5, short(post.comments or math.random(3, 40)))
		local bubble = frame(comB, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.38), Size = S2(0.62, 0.48), BackgroundColor3 = WHITE, ZIndex = 7})
		round(bubble, 0.45)
		for k = 0, 2 do
			local d = frame(bubble, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.28 + k * 0.22, 0.5), Size = S2(0.12, 0.2), BackgroundColor3 = rgb(40, 40, 50), ZIndex = 8})
			round(d, true)
		end
		local shareB = actionButton(0.71, "Share")
		K.chevron(shareB, WHITE, 0.5, 7).Position = S2(0.5, 0.36)
		local disc = frame(col, {AnchorPoint = V2(0.5, 1), Position = S2(0.5, 1.02), Size = S2(0.7, 0.21), BackgroundColor3 = rgb(30, 30, 36), ZIndex = 6})
		K.square(disc)
		round(disc, true)
		UI.stroke(disc, 3, rgb(70, 70, 80))
		local label = frame(disc, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(0.45, 0.45), BackgroundColor3 = accent, ZIndex = 7})
		round(label, true)
		card.disc = disc
		-- BOTTOM: @creator, caption, the sound
		local live = post.id ~= nil
		text(f, "@" .. tostring(post.user or "boxtok"), {Position = S2(0.04, 0.73), Size = S2(0.7, 0.055), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2, MaxSize = 20, ZIndex = 6})
		text(f, live and liveText(post) or (post.text or ""), {Position = S2(0.04, 0.79), Size = S2(0.76, 0.1), TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Stroke = 1.5, MaxSize = 17, ZIndex = 6})
		local sound = frame(f, {Position = S2(0.04, 0.9), Size = S2(0.62, 0.04), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 6})
		card.sound = text(sound, "original sound - " .. tostring(post.user or "boxtok") .. "     original sound - " .. tostring(post.user or "boxtok"),
			{Size = S2(2, 1), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1, MaxSize = 13, TextColor3 = rgb(230, 230, 240), ZIndex = 6})
		if live then
			local tag = frame(f, {Position = S2(0.04, 0.03), Size = S2(0.17, 0.045), BackgroundColor3 = rgb(255, 40, 80), ZIndex = 6})
			round(tag, 6)
			text(tag, "LIVE", {Size = S2(1, 1), Stroke = 0, MaxSize = 15, ZIndex = 7})
			text(f, "in this server", {Position = S2(0.23, 0.03), Size = S2(0.4, 0.045), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1, MaxSize = 13,
				TextColor3 = rgb(230, 230, 240), ZIndex = 6})
		end
		local prog = frame(f, {AnchorPoint = V2(0, 1), Position = S2(0, 1), Size = S2(1, 0.008), BackgroundColor3 = rgb(80, 80, 90), ZIndex = 6})
		card.progress = frame(prog, {Size = S2(0, 1), BackgroundColor3 = WHITE, ZIndex = 7})
		-- big BONK! stamp on bonk clips
		if post.kind == "bonk" then
			card.stamp = text(f, "BONK!", {AnchorPoint = V2(0.5, 0.5), Position = S2(0.45, 0.2), Size = S2(0.7, 0.14), Rotation = -12, Stroke = 4, MaxSize = 60,
				TextColor3 = rgb(255, 220, 60), ZIndex = 7})
		end
		-- a white flash for the zoom "beat" in boss clips
		card.flash = frame(f, {Size = S2(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 5})
		-- the hearts that fly up when you double-tap
		card.hearts = {}
		card.likeB, card.comB, card.shareB = likeB, comB, shareB
		return card
	end

	local function updateLikes(card)
		if not card then return end
		card.likeT.Text = short(card.post.likes or 0)
		setHeart(card.hbits, liked[card.post] and PINK or WHITE)
	end
	local function like(card, x, y)
		if not card then return end
		local post = card.post
		if not liked[post] then
			liked[post] = true
			post.likes = (post.likes or 0) + 1
			if post.id and remote then remote:FireServer("like", post.id) end
			UI.SFX.play("pop", 1.4, 0.2)
		end
		updateLikes(card)
		-- a big heart pops where you tapped
		local h = frame(card.frame, {AnchorPoint = V2(0.5, 0.5), Position = S2(x or 0.45, y or 0.4), Size = S2(0.3, 0.3), BackgroundTransparency = 1, ZIndex = 9, Rotation = math.random(-20, 20)})
		K.square(h)
		heartIcon(h, PINK, 9)
		local sc = new("UIScale", {Scale = 0.2}, h)
		table.insert(card.hearts, {f = h, sc = sc, t = 0})
	end

	-- COMMENTS: a sheet that slides up
	local sheet = frame(content, {Name = "Comments", AnchorPoint = V2(0.5, 0), Position = S2(0.5, 1), Size = S2(1, 0.62), BackgroundColor3 = rgb(250, 250, 252), ZIndex = 20, Visible = false})
	round(sheet, 18)
	local sheetTitle = text(sheet, "Comments", {Position = S2(0.05, 0.03), Size = S2(0.7, 0.09), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 0, MaxSize = 20,
		TextColor3 = rgb(30, 30, 40), ZIndex = 21})
	local closeB = new("TextButton", {Text = "X", AutoButtonColor = false, AnchorPoint = V2(1, 0), Position = S2(0.96, 0.02), Size = S2(0.12, 0.1),
		BackgroundColor3 = rgb(230, 230, 236), TextColor3 = rgb(40, 40, 50), FontFace = UI.Font, TextScaled = true, BorderSizePixel = 0, ZIndex = 21}, sheet)
	round(closeB, 10)
	UI.pressable(closeB)
	local rows = {}
	for i = 1, 5 do
		local row = frame(sheet, {Position = S2(0.04, 0.15 + (i - 1) * 0.165), Size = S2(0.92, 0.15), BackgroundTransparency = 1, ZIndex = 21})
		local av = frame(row, {Position = S2(0, 0.1), Size = S2(0.8, 0.8), BackgroundColor3 = rgb(200, 200, 210), ZIndex = 21})
		K.square(av)
		round(av, true)
		local name = text(row, "", {Position = S2(0.16, 0.02), Size = S2(0.8, 0.4), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 0, MaxSize = 13, TextColor3 = rgb(120, 120, 130), ZIndex = 21})
		local body = text(row, "", {Position = S2(0.16, 0.44), Size = S2(0.8, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 0, MaxSize = 16, TextColor3 = rgb(30, 30, 40), ZIndex = 21})
		rows[i] = {av = av, name = name, body = body}
	end
	local function showComments(show)
		if show then
			for _, r in ipairs(rows) do
				r.av.BackgroundColor3 = Color3.fromHSV(math.random(), 0.5, 0.95)
				r.name.Text = pick(CREATORS)
				r.body.Text = pick(COMMENTS)
			end
			sheetTitle.Text = short(cur and cur.post.comments or 0) .. " comments"
			sheet.Visible = true
			sheet.Position = S2(0.5, 1)
			TweenService:Create(sheet, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = S2(0.5, 0.38)}):Play()
		else
			TweenService:Create(sheet, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = S2(0.5, 1)}):Play()
			task.delay(0.21, function() if sheet.Position.Y.Scale > 0.9 then sheet.Visible = false end end)
		end
	end
	closeB.Activated:Connect(function() showComments(false) end)
	-- "Link copied!" toast
	local toast = frame(content, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.5), Size = S2(0.5, 0.07), BackgroundColor3 = rgb(20, 20, 26), BackgroundTransparency = 0.1, ZIndex = 22, Visible = false})
	round(toast, 10)
	text(toast, "Link copied!", {Size = S2(1, 1), Stroke = 0, MaxSize = 16, ZIndex = 23})
	-- a pill that appears when a new LIVE post arrives
	local newPill = new("TextButton", {Text = "", AutoButtonColor = false, AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0.02), Size = S2(0.56, 0.06), BackgroundColor3 = PINK, Visible = false, ZIndex = 19, BorderSizePixel = 0}, content)
	round(newPill, true)
	local newT = text(newPill, "New LIVE post", {Size = S2(1, 1), Stroke = 1.5, MaxSize = 15, ZIndex = 20})
	UI.pressable(newPill)

	------------------------------------------------------------------
	-- moving through the feed
	------------------------------------------------------------------
	local busy = false
	local function wire(card)
		card.likeB.Activated:Connect(function() like(card, 0.45, 0.4) end)
		card.comB.Activated:Connect(function() showComments(true) end)
		card.shareB.Activated:Connect(function()
			toast.Visible = true
			task.delay(1.1, function() toast.Visible = false end)
		end)
	end
	local function show(i, dir)
		if busy then return end
		i = math.max(1, i)
		if i > #feed - 2 then more(6) end
		local post = feed[i]
		if not post then return end
		busy = true
		showComments(false)
		local old = cur
		local card = makeCard(post)
		wire(card)
		idx, cur = i, card
		if old and dir ~= 0 then
			card.frame.Position = S2(0, dir)
			TweenService:Create(card.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Position = S2(0, 0)}):Play()
			TweenService:Create(old.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Position = S2(0, -dir)}):Play()
			task.delay(0.31, function()
				old.frame:Destroy()
				busy = false
			end)
		else
			if old then old.frame:Destroy() end
			busy = false
		end
	end
	local function nextClip() show(idx + 1, 1) end
	local function prevClip() if idx > 1 then show(idx - 1, -1) end end
	newPill.Activated:Connect(function()
		newPill.Visible = false
		nextClip()
	end)

	-- swipe / scroll / double-tap on the clip
	local catcher = new("TextButton", {Name = "Catcher", Text = "", AutoButtonColor = false, Size = S2(0.8, 0.88), BackgroundTransparency = 1, ZIndex = 4}, content)
	local press, lastTap, wheelAt = nil, 0, 0
	catcher.InputBegan:Connect(function(input)
		if not K.isPress(input) then return end
		press = K.posOf(input)
	end)
	catcher.InputEnded:Connect(function(input)
		if not K.isPress(input) or not press then return end
		local p = K.posOf(input)
		local dy = p.Y - press.Y
		press = nil
		local h = content.AbsoluteSize.Y
		if math.abs(dy) > math.max(30, h * 0.08) then
			if dy < 0 then nextClip() else prevClip() end
			return
		end
		local now = os.clock()
		if now - lastTap < 0.35 then
			local fx, fy = K.fracIn(content, p)
			like(cur, fx, fy)
			lastTap = 0
		else
			lastTap = now
		end
	end)
	catcher.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel and os.clock() - wheelAt > 0.35 then
			wheelAt = os.clock()
			if input.Position.Z < 0 then nextClip() else prevClip() end
		end
	end)

	-- LIVE posts from this server
	if remote then
		remote.OnClientEvent:Connect(function(action, a, b)
			if action == "post" and type(a) == "table" then
				table.insert(feed, idx + 1, a)
				newT.Text = "New: @" .. tostring(a.user) .. " - swipe up"
				newPill.Visible = open
			elseif action == "feed" and type(a) == "table" then
				for k = #a, math.max(1, #a - 5), -1 do table.insert(feed, idx + 1, a[k]) end
			elseif action == "likes" and type(a) == "number" then
				for _, p in ipairs(feed) do if p.id == a then p.likes = b end end
				if cur and cur.post.id == a then updateLikes(cur) end
			end
		end)
	end

	function app.enter()
		open = true
		if remote and not app.asked then
			app.asked = true
			remote:FireServer("feed")
		end
		if not cur then show(idx, 0) end
		if cur and cur.video then pcall(function() cur.video:Play() end) end
	end
	function app.leave()
		open = false
		newPill.Visible = false
		if cur and cur.video then pcall(function() cur.video:Pause() end) end
	end
	function app.key(kc)
		if kc == Enum.KeyCode.Down or kc == Enum.KeyCode.S then nextClip()
		elseif kc == Enum.KeyCode.Up or kc == Enum.KeyCode.W then prevClip()
		elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.L then like(cur, 0.45, 0.4)
		elseif kc == Enum.KeyCode.C then showComments(not sheet.Visible) end
	end
	function app.layout(_wide) end

	-- every frame: animate the clip on screen
	function app.step(dt)
		local c = cur
		if not c then return end
		c.t = c.t + dt
		local t = c.t
		c.progress.Size = S2((t % CLIP) / CLIP, 1)
		if c.disc then c.disc.Rotation = (t * 90) % 360 end
		if c.sound then c.sound.Position = S2(-((t * 0.08) % 1), 0) end
		if c.rays then c.rays.Rotation = (t * 25) % 360 end
		for i = #c.hearts, 1, -1 do
			local h = c.hearts[i]
			h.t = h.t + dt
			h.sc.Scale = (h.t < 0.15) and lerp(0.2, 1.25, h.t / 0.15) or math.max(0, 1.25 - (h.t - 0.15) * 0.6)
			h.f.Position = h.f.Position + UDim2.fromScale(0, -dt * 0.15)
			if h.t > 1 then
				h.f:Destroy()
				table.remove(c.hearts, i)
			end
		end
		if c.stamp then
			local beat = (t % 2) / 2
			c.stamp.Rotation = -12 + math.sin(t * 20) * ((beat < 0.15) and 6 or 0)
			c.stamp.TextTransparency = (beat < 0.6) and 0 or 1
		end
		if c.model and c.cam then
			local kind, r, center = c.post.kind, c.r or 4, c.center or Vector3.new()
			local front = c.front or Vector3.new(0, 0, -1)
			local beat = (t % 2.4) / 2.4
			local punch = (beat < 0.12) and (1 - beat / 0.12) or 0
			pcall(function()
				if kind == "boss" or kind == "bonk" then
					-- the boss bobs and glares; the camera swings round him and punches in on the beat
					local ang = math.sin(t * 0.55) * 0.7
					local dir = (CFrame.Angles(0, ang, 0) * front).Unit
					local dist = r * (1.55 - punch * 0.3)
					c.model:PivotTo(CFrame.new(0, math.abs(math.sin(t * 3.2)) * r * 0.03, 0) * CFrame.Angles(0, math.sin(t * 1.1) * 0.15, 0))
					c.cam.CFrame = CFrame.lookAt(center + dir * dist + Vector3.new(0, r * 0.12, 0), center + Vector3.new(0, r * 0.05, 0))
					c.flash.BackgroundTransparency = 1 - punch * 0.5
				else
					-- boxes and items float and spin, popping in at the start
					local pop = math.min(1, t / 0.35)
					local s = 0.4 + 0.6 * K.backOut(pop)
					c.model:PivotTo(CFrame.new(0, math.sin(t * 2) * r * 0.05, 0) * CFrame.Angles(0.15, t * 1.4, 0))
					c.cam.CFrame = CFrame.lookAt(center + Vector3.new(0, r * 0.45, r * 1.9 / s), center)
				end
			end)
		end
	end
	return app
end

-- the app icon: a white box with tape, with pink and cyan "glitch" copies behind it
local function drawIcon(b, K)
	local rgb, V2, S2 = K.rgb, K.V2, K.S2
	for k, c in ipairs({rgb(60, 230, 240), rgb(255, 60, 120), rgb(255, 255, 255)}) do
		local o = (k - 2) * 0.05
		local box = K.frame(b, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5 + o, 0.52 + o), Size = S2(0.5, 0.46), BackgroundColor3 = c, ZIndex = 3 + k})
		K.round(box, 0.18)
		if k == 3 then
			K.UI.stroke(box, 1.5, K.C.ink)
			K.frame(box, {AnchorPoint = V2(0.5, 0), Position = S2(0.5, 0), Size = S2(0.22, 1), BackgroundColor3 = rgb(225, 190, 130), ZIndex = 7})
			local play = K.frame(box, {AnchorPoint = V2(0.5, 0.5), Position = S2(0.5, 0.55), Size = S2(0.34, 0.34), Rotation = 45, BackgroundColor3 = rgb(255, 60, 120), ZIndex = 8})
			K.round(play, 0.15)
		end
	end
end

return {build = build, drawIcon = drawIcon}
