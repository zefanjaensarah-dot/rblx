-- A tiny fake Roblox engine for smoke-testing the game scripts in Lune (see tools/test/README.md).
local task = require("@lune/task")
-- Instances are real Lune instances (so every property name + value type is validated),
-- wrapped in proxies that add events, attributes signals and the methods Lune lacks.
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local RI = roblox.Instance
local Enum = roblox.Enum

local H = {errors = {}, calls = {}, log = {}}

local function record(kind, msg)
	table.insert(H.errors, kind .. ": " .. tostring(msg))
end
H.record = record

------------------------------------------------------------------
-- signals
------------------------------------------------------------------
local SignalMT = {}
SignalMT.__index = SignalMT
local function newSignal(name)
	return setmetatable({name = name, conns = {}}, SignalMT)
end
function SignalMT:Connect(fn)
	local c = {fn = fn, connected = true}
	table.insert(self.conns, c)
	c.Connected = true
	function c.Disconnect() c.connected = false c.Connected = false end
	return c
end
function SignalMT:Once(fn)
	local c
	c = self:Connect(function(...) c.Disconnect() fn(...) end)
	return c
end
function SignalMT:Wait()
	local th = coroutine.running()
	self:Once(function(...) task.spawn(th, ...) end)
	return coroutine.yield()
end
function SignalMT:Fire(...)
	for _, c in ipairs(table.clone(self.conns)) do
		if c.connected then
			local ok, err = pcall(c.fn, ...)
			if not ok then record("signal " .. tostring(self.name), err) end
		end
	end
end
H.newSignal = newSignal

------------------------------------------------------------------
-- proxies
------------------------------------------------------------------
local nextId = 0
local proxies = {}            -- [id] = proxy
local realOf = setmetatable({}, {__mode = "k"})
local extras = {}             -- [id] = {signals, values}
H.realOf = realOf

local EVENTS = {}
for _, n in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseEnter", "MouseLeave",
	"Changed", "FocusLost", "Focused", "Triggered", "TriggerEnded", "Event", "OnClientEvent", "OnServerEvent", "InputBegan", "InputEnded", "InputChanged",
	"ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Destroying", "Touched", "TouchEnded",
	"Died", "Running", "StateChanged", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "PromptTriggered", "Completed",
	"MoveToFinished", "Ended", "Played", "Stopped", "DidLoop"}) do
	EVENTS[n] = true
end

local wrap, unwrap
local function idOf(real)
	local id = real:GetAttribute("HarnessId")
	if not id then
		nextId = nextId + 1
		id = nextId
		real:SetAttribute("HarnessId", id)
	end
	return id
end
local function ex(p) return extras[rawget(p, "__id")] end
H.hierarchyListeners = 0
local function signalFor(p, key)
	local e = ex(p)
	if not e.signals[key] then
		e.signals[key] = newSignal(key)
		if key == "DescendantAdded" or key == "ChildAdded" then H.hierarchyListeners += 1 end
	end
	return e.signals[key]
end
H.signalFor = signalFor

local function wrapAll(...)
	local n = select("#", ...)
	local out = table.pack(...)
	for i = 1, n do out[i] = wrap(out[i]) end
	return table.unpack(out, 1, n)
end
local function unwrapAll(...)
	local n = select("#", ...)
	local out = table.pack(...)
	for i = 1, n do out[i] = unwrap(out[i]) end
	return table.unpack(out, 1, n)
end

-- methods every instance gets (or that Lune doesn't have)
local OV = {}
function OV.GetPropertyChangedSignal(self, prop) return signalFor(self, "prop:" .. prop) end
function OV.GetAttributeChangedSignal(self, name) return signalFor(self, "attr:" .. name) end
function OV.SetAttribute(self, k, v)
	local real = realOf[self]
	local old = real:GetAttribute(k)
	real:SetAttribute(k, v)
	if old ~= v then
		signalFor(self, "attr:" .. k):Fire()
		signalFor(self, "AttributeChanged"):Fire(k)
	end
end
function OV.WaitForChild(self, name, timeout)
	local c = realOf[self]:FindFirstChild(name)
	if c then return wrap(c) end
	if timeout then return nil end
	error("WaitForChild would wait forever: " .. realOf[self]:GetFullName() .. "." .. name, 2)
end
function OV.Clone(self)
	local c = realOf[self]:Clone()
	c:SetAttribute("HarnessId", nil)
	for _, d in ipairs(c:GetDescendants()) do d:SetAttribute("HarnessId", nil) end
	return wrap(c)
end
function OV.GetPivot(self)
	local real = realOf[self]
	if real:IsA("BasePart") then return real.CFrame end
	local ok, v = pcall(function() return real.WorldPivot end)
	return ok and v or roblox.CFrame.new()
end
function OV.PivotTo(self, cf)
	local real = realOf[self]
	if real:IsA("BasePart") then real.CFrame = cf return end
	pcall(function() real.WorldPivot = cf end)
end
function OV.Fire(self, ...)
	local real = realOf[self]
	if real:IsA("BindableEvent") then return signalFor(self, "Event"):Fire(...) end
	error("Fire on " .. real.ClassName, 2)
end
function OV.FireServer(self, ...)
	table.insert(H.calls, {"FireServer", realOf[self].Name, ...})
	if H.onFireServer then H.onFireServer(realOf[self].Name, ...) end
end
function OV.FireClient(self, plr, ...)
	table.insert(H.calls, {"FireClient", realOf[self].Name, ...})
	if H.onFireClient then H.onFireClient(realOf[self].Name, plr, ...) end
end
function OV.FireAllClients(self, ...)
	table.insert(H.calls, {"FireAllClients", realOf[self].Name, ...})
	if H.onFireClient then H.onFireClient(realOf[self].Name, nil, ...) end
end
function OV.InvokeServer(self, ...)
	table.insert(H.calls, {"InvokeServer", ...})
	if H.onInvokeServer then return H.onInvokeServer(...) end
	return nil
end
-- methods that exist in Roblox but not in Lune: harmless no-ops for the test
local NOOP = {"ChangeState", "Move", "MoveTo", "Emit", "Play", "Stop", "Pause", "Resume", "AdjustSpeed", "AddAccessory", "ApplyDescription",
	"BreakJoints", "SetNetworkOwner", "Capture", "CaptureFocus", "ReleaseFocus", "TakeDamage", "LoadCharacter", "Kick"}
for _, n in ipairs(NOOP) do OV[n] = function() return nil end end
function OV.LoadAnimation(self, anim)
	local t = {Looped = false, IsPlaying = false, Length = 1, Speed = 1}
	function t.Play() t.IsPlaying = true end
	function t.Stop() t.IsPlaying = false end
	function t.AdjustSpeed(_, s) t.Speed = s end
	t.Stopped = newSignal("Stopped")
	return t
end
function OV.GetServerTimeNow() return os.clock() + 1.7e9 end
function OV.Raycast() return nil end
function OV.WorldToViewportPoint(self, pos) return roblox.Vector3.new(640, 360, 10), true end
function OV.WorldToScreenPoint(self, pos) return roblox.Vector3.new(640, 360, 10), true end
function OV.ViewportPointToRay(self, x, y) return {Origin = roblox.Vector3.new(0, 50, 0), Direction = roblox.Vector3.new(0, -1, 0)} end
function OV.ScreenPointToRay(self, x, y) return {Origin = roblox.Vector3.new(0, 50, 0), Direction = roblox.Vector3.new(0, -1, 0)} end
H.tagIndex = {}
local function indexTag(p, tag, on)
	H.tagIndex[tag] = H.tagIndex[tag] or {}
	H.tagIndex[tag][p] = on or nil
end
H.indexTag = indexTag
function OV.AddTag(self, tag)
	realOf[self]:AddTag(tag)
	indexTag(self, tag, true)
	local sig = H.services and H.services.CollectionService.added[tag]
	if sig then sig:Fire(self) end
end
function OV.RemoveTag(self, tag)
	realOf[self]:RemoveTag(tag)
	indexTag(self, tag, false)
end
function OV.Destroy(self)
	local real = realOf[self]
	for _, tags in pairs(H.tagIndex) do tags[self] = nil end
	pcall(function() real:Destroy() end)
end
function OV.GetChildren(self) return H.wrapList(realOf[self]:GetChildren()) end
function OV.GetDescendants(self) return H.wrapList(realOf[self]:GetDescendants()) end
function OV.BindToClose() end

-- read defaults for properties Lune can't read
local DEFAULTS = {
	AbsoluteSize = roblox.Vector2.new(1280, 720), AbsolutePosition = roblox.Vector2.new(10, 10), ViewportSize = roblox.Vector2.new(1280, 720),
	AbsoluteRotation = 0, TextBounds = roblox.Vector2.new(50, 18), Health = 100, MaxHealth = 100, AbsoluteCanvasSize = roblox.Vector2.new(100, 100),
	CanvasPosition = roblox.Vector2.new(0, 0), AssemblyLinearVelocity = roblox.Vector3.new(), AssemblyAngularVelocity = roblox.Vector3.new(),
	LocalTransparencyModifier = 0, Text = "",
}
-- properties we keep on the proxy instead (Lune can't set/read them)
local SHADOW = {OnServerInvoke = true, OnClientInvoke = true, CurrentCamera = true, Character = true, UserId = true, DisplayName = true, LocalPlayer = true, LocalTransparencyModifier = true,
	AssemblyLinearVelocity = true, AssemblyAngularVelocity = true, CameraType = false}

local ProxyMT = {}
ProxyMT.__index = function(p, k)
	local real = realOf[p]
	local e = extras[rawget(p, "__id")]
	if e.values[k] ~= nil then return e.values[k] end
	if e.overrides and e.overrides[k] ~= nil then return e.overrides[k] end
	if OV[k] then return OV[k] end
	if EVENTS[k] then return signalFor(p, k) end
	if k == "Position" and real:IsA("BasePart") then return real.CFrame.Position end
	if k == "Orientation" and real:IsA("BasePart") then local x, y, z = real.CFrame:ToOrientation() return roblox.Vector3.new(math.deg(x), math.deg(y), math.deg(z)) end
	local ok, v = pcall(function() return real[k] end)
	if not ok then
		if k == "AbsoluteSize" and H.phoneSize then return roblox.Vector2.new(844, 354) end
		if DEFAULTS[k] ~= nil then return DEFAULTS[k] end
		if SHADOW[k] then return nil end
		error(tostring(v), 2)
	end
	if type(v) == "function" then
		return function(self, ...)
			return wrapAll(v(realOf[self] or self, unwrapAll(...)))
		end
	end
	return wrap(v)
end
ProxyMT.__newindex = function(p, k, v)
	local real = realOf[p]
	local e = extras[rawget(p, "__id")]
	if SHADOW[k] then
		e.values[k] = v
	elseif k == "Position" and real:IsA("BasePart") then
		real.CFrame = real.CFrame - real.CFrame.Position + v
	else
		local ok, err = pcall(function() real[k] = unwrap(v) end)
		if not ok then error("set " .. real.ClassName .. "." .. tostring(k) .. " = " .. tostring(v) .. ": " .. tostring(err), 2) end
	end
	local s = e.signals["prop:" .. k]
	if s then s:Fire() end
	local ch = e.signals.Changed
	if ch then
		if real:IsA("ValueBase") and k == "Value" then ch:Fire(v) else ch:Fire(k) end
	end
	if k == "Parent" and v ~= nil and H.hierarchyListeners > 0 then
		-- DescendantAdded / ChildAdded on the new ancestors
		local parent = v
		local cp = rawget(parent, "__id") and extras[rawget(parent, "__id")]
		if cp and cp.signals.ChildAdded then cp.signals.ChildAdded:Fire(p) end
		local anc = parent
		while anc do
			local ae = rawget(anc, "__id") and extras[rawget(anc, "__id")]
			if ae and ae.signals.DescendantAdded then ae.signals.DescendantAdded:Fire(p) end
			local okp, par = pcall(function() return anc.Parent end)
			anc = okp and par or nil
		end
	end
end
ProxyMT.__tostring = function(p) return tostring(realOf[p]) end

wrap = function(v)
	if typeof(v) ~= "Instance" then return v end
	local id = idOf(v)
	local p = proxies[id]
	if p then return p end
	p = setmetatable({__id = id}, ProxyMT)
	realOf[p] = v
	extras[id] = {signals = {}, values = {}}
	proxies[id] = p
	return p
end
unwrap = function(v)
	if type(v) == "table" and realOf[v] then return realOf[v] end
	return v
end
H.wrap, H.unwrap = wrap, unwrap
function H.wrapList(list)
	local out = {}
	for i, v in ipairs(list) do out[i] = wrap(v) end
	return out
end
function H.isProxy(v) return type(v) == "table" and realOf[v] ~= nil end
function H.setOverrides(p, t) ex(p).overrides = t end
function H.setValue(p, k, v) ex(p).values[k] = v end
function H.newInstance(className)
	local ok, real = pcall(RI.new, className)
	if not ok then error("Instance.new(" .. tostring(className) .. "): " .. tostring(real), 2) end
	return wrap(real)
end
function H.allProxies() return proxies end

------------------------------------------------------------------
-- fake datatypes Lune doesn't have
------------------------------------------------------------------
local TweenInfo = {}
function TweenInfo.new(time, style, dir, repeatCount, reverses, delay)
	return {Time = time or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = repeatCount or 0, Reverses = reverses, DelayTime = delay or 0}
end
local RaycastParams = {}
function RaycastParams.new() return {FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false} end
local Random = {}
function Random.new(seed)
	local r = {}
	function r:NextNumber(a, b) a = a or 0 b = b or 1 return a + math.random() * (b - a) end
	function r:NextInteger(a, b) return math.random(a, b) end
	return r
end

------------------------------------------------------------------
-- services
------------------------------------------------------------------
function H.makeServices(game)
	local S = {}
	S.RunService = {RenderStepped = newSignal("RenderStepped"), Heartbeat = newSignal("Heartbeat"), Stepped = newSignal("Stepped"),
		renderSteps = {}}
	function S.RunService:BindToRenderStep(name, prio, fn) self.renderSteps[name] = fn end
	function S.RunService:UnbindFromRenderStep(name) self.renderSteps[name] = nil end
	function S.RunService:IsStudio() return true end
	function S.RunService:IsClient() return H.isClient == true end
	function S.RunService:IsServer() return H.isClient ~= true end
	S.TweenService = {}
	function S.TweenService:Create(obj, info, props)
		assert(H.isProxy(obj), "TweenService:Create needs an Instance")
		assert(type(info) == "table", "TweenInfo expected")
		assert(type(props) == "table", "props expected")
		local t = {Completed = newSignal("Completed")}
		function t.Play()
			for k, v in pairs(props) do obj[k] = v end -- validates the property + type
			t.Completed:Fire(Enum.PlaybackState.Completed)
		end
		function t.Cancel() end
		function t.Pause() end
		return t
	end
	S.UserInputService = {InputBegan = newSignal("InputBegan"), InputEnded = newSignal("InputEnded"), JumpRequest = newSignal("JumpRequest"),
		TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true, GamepadEnabled = false}
	function S.UserInputService:GetMouseLocation() return roblox.Vector2.new(640, 360) end
	S.CollectionService = {tags = {}, added = {}, removed = {}}
	local CS = S.CollectionService
	local function tagList(tag)
		local list = {}
		for p in pairs(H.tagIndex[tag] or {}) do
			local okp, alive = pcall(function() return realOf[p].Parent ~= nil end)
			if okp and alive then table.insert(list, p) end
		end
		return list
	end
	function CS:GetTagged(tag) return tagList(tag) end
	function CS:AddTag(inst, tag) OV.AddTag(inst, tag) end
	function CS:RemoveTag(inst, tag) OV.RemoveTag(inst, tag) end
	function CS:HasTag(inst, tag) return realOf[inst]:HasTag(tag) end
	function CS:GetInstanceAddedSignal(tag) CS.added[tag] = CS.added[tag] or newSignal("added:" .. tag) return CS.added[tag] end
	function CS:GetInstanceRemovedSignal(tag) CS.removed[tag] = CS.removed[tag] or newSignal("removed:" .. tag) return CS.removed[tag] end
	S.Debris = {}
	function S.Debris:AddItem(obj, t)
		task.delay(math.min(t or 10, 0.5), function() pcall(function() obj:Destroy() end) end)
	end
	S.MarketplaceService = {PromptGamePassPurchaseFinished = newSignal("PGPPF"), PromptProductPurchaseFinished = newSignal("PPPF")}
	function S.MarketplaceService:GetProductInfo(id, infoType) return {PriceInRobux = 42, Name = "Test"} end
	function S.MarketplaceService:PromptProductPurchase(plr, id) table.insert(H.calls, {"PromptProductPurchase", id}) end
	function S.MarketplaceService:PromptGamePassPurchase(plr, id) table.insert(H.calls, {"PromptGamePassPurchase", id}) end
	function S.MarketplaceService:UserOwnsGamePassAsync(uid, id) return false end
	-- text measuring: about 0.55 x size per character, wrapped to the frame width
	S.TextService = {}
	function S.TextService:GetTextSize(text, size, font, frame)
		assert(type(text) == "string" and type(size) == "number", "GetTextSize(text, size, font, frameSize)")
		assert(typeof(font) == "EnumItem" and tostring(font):find("Font") ~= nil, "GetTextSize needs an Enum.Font")
		local w = #text * size * 0.55
		local lines = math.max(1, math.ceil(w / math.max(1, frame.X)))
		return roblox.Vector2.new(math.min(w, frame.X), lines * size)
	end
	S.ProximityPromptService = {PromptTriggered = newSignal("PromptTriggered")}
	S.GuiService = {}
	function S.GuiService:GetGuiInset() return roblox.Vector2.new(0, 58), roblox.Vector2.new(0, 0) end
	S.PhysicsService = {}
	function S.PhysicsService:IsCollisionGroupRegistered() return false end
	function S.PhysicsService:RegisterCollisionGroup() end
	function S.PhysicsService:CollisionGroupSetCollidable() end
	S.HttpService = {}
	function S.HttpService:GenerateGUID() return "GUID-TEST" end
	S.InsertService = {}
	function S.InsertService:LoadAsset() error("no assets in tests") end
	S.DataStoreService = {stores = {}}
	function S.DataStoreService:GetDataStore(name)
		local store = {data = {}}
		S.DataStoreService.stores[name] = store
		function store:GetAsync(key) return store.data[key] end
		function store:SetAsync(key, v) store.data[key] = v end
		function store:UpdateAsync(key, fn)
			local new = fn(store.data[key] and table.clone(store.data[key]) or nil)
			if new ~= nil then store.data[key] = new end
			return new
		end
		return store
	end
	return S
end

------------------------------------------------------------------
-- environment + running scripts
------------------------------------------------------------------
function H.makeEnv(game, workspaceProxy, services, scriptProxy)
	local env = {}
	env.game = game
	env.workspace = workspaceProxy
	env.Workspace = workspaceProxy
	env.script = scriptProxy
	for _, name in ipairs({"Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "Enum", "ColorSequence", "ColorSequenceKeypoint",
		"NumberSequence", "NumberSequenceKeypoint", "NumberRange", "Rect", "Font", "BrickColor", "PhysicalProperties", "Ray", "Region3", "Faces", "Axes"}) do
		env[name] = roblox[name]
	end
	-- Lune's NumberSequence.new(a, b) keeps only a: build the 2 keypoints ourselves (like Roblox)
	env.NumberSequence = setmetatable({new = function(a, b, ...)
		if type(a) == "number" and type(b) == "number" then
			return roblox.NumberSequence.new({roblox.NumberSequenceKeypoint.new(0, a), roblox.NumberSequenceKeypoint.new(1, b)})
		end
		return roblox.NumberSequence.new(a, b, ...)
	end}, {__index = roblox.NumberSequence})
	env.ColorSequence = setmetatable({new = function(a, b, ...)
		if typeof(a) == "Color3" and typeof(b) == "Color3" then
			return roblox.ColorSequence.new({roblox.ColorSequenceKeypoint.new(0, a), roblox.ColorSequenceKeypoint.new(1, b)})
		end
		return roblox.ColorSequence.new(a, b, ...)
	end}, {__index = roblox.ColorSequence})
	env.TweenInfo = TweenInfo
	env.RaycastParams = RaycastParams
	env.Random = Random
	env.Instance = {new = function(className, parent)
		local p = H.newInstance(className)
		if parent then p.Parent = parent end
		return p
	end}
	env.typeof = function(v)
		if H.isProxy(v) then return "Instance" end
		if type(v) == "table" and v.Connect and v.conns then return "RBXScriptSignal" end
		return typeof(v)
	end
	env.require = function(m)
		if H.isProxy(m) then return H.requireModule(m) end
		return require(m)
	end
	env.task = {
		spawn = function(f, ...)
			if type(f) == "thread" then return task.spawn(f, ...) end
			return task.spawn(function(...)
				local ok, err = pcall(f, ...)
				if not ok then record("task.spawn", err) end
			end, ...)
		end,
		defer = function(f, ...)
			return task.defer(function(...)
				local ok, err = pcall(f, ...)
				if not ok then record("task.defer", err) end
			end, ...)
		end,
		delay = function(t, f, ...)
			return task.delay(math.min(t, H.maxDelay or 1.5), function(...)
				local ok, err = pcall(f, ...)
				if not ok then record("task.delay", err) end
			end, ...)
		end,
		wait = function(t) return task.wait(math.min(t or 0, H.maxWait or 0.05)) end,
		cancel = task.cancel,
	}
	env.wait = env.task.wait
	env.warn = function(...) table.insert(H.log, "warn: " .. table.concat(table.pack(...), " ")) end
	env.print = function(...) table.insert(H.log, "print: " .. table.concat((function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end return t end)(...), " ")) end
	env.tick = os.clock
	env.time = os.clock
	env.utf8 = utf8
	return setmetatable(env, {__index = getfenv and getfenv(1) or _G})
end

local moduleCache = {}
function H.requireModule(m)
	local id = rawget(m, "__id")
	if moduleCache[id] ~= nil then return moduleCache[id] end
	local src = realOf[m].Source
	local env = H.makeEnv(H.game, H.workspace, H.services, m)
	local fn = luau.load(src, {debugName = realOf[m]:GetFullName(), environment = env})
	local result = fn()
	moduleCache[id] = result
	return result
end
function H.runScript(scriptProxy)
	local env = H.makeEnv(H.game, H.workspace, H.services, scriptProxy)
	local fn = luau.load(realOf[scriptProxy].Source, {debugName = realOf[scriptProxy]:GetFullName(), environment = env})
	return task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then record("script " .. realOf[scriptProxy].Name, err) end
	end)
end

-- step every per-frame callback a few times
function H.step(frames, dt)
	for _ = 1, frames or 1 do
		H.services.RunService.RenderStepped:Fire(dt or 1 / 60)
		H.services.RunService.Heartbeat:Fire(dt or 1 / 60)
		for name, fn in pairs(H.services.RunService.renderSteps) do
			local ok, err = pcall(fn, dt or 1 / 60)
			if not ok then record("renderstep " .. name, err) end
		end
		task.wait()
	end
end

return H
