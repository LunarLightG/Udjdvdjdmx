-- Trick or Treat (PlaceId 92909830836407) | TP + TPWalk + Egg->Home | v4
-- v4: แก้พิกัดล็อบบี้ให้ตรงจริง (PenSpawn / ShopZone), เพิ่มวาร์ปกลับ plot ตัวเอง
--     และสวิตช์ "ถือไข่แล้ววาร์ปกลับ plot อัตโนมัติ" (อ่านจาก attribute CarryingEgg)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local LIB_URL = "https://raw.githubusercontent.com/LunarLightG/Moon-Light/refs/heads/main/Library.lua"
local MIN_SPEED, MAX_SPEED = 50, 500
local STAND_Y = 5

if _G.__TPStop then pcall(_G.__TPStop) end

---------------------------------------------------------------- destinations
-- { ชื่อ, x, z }
local ZONES = {
	{ "Zone 01 PumpkinPatch", 141, 0 }, { "Zone 02 WhisperingGraveyard", 273, 0 },
	{ "Zone 03 WitchwoodSwamp", 428, 0 }, { "Zone 04 HauntedManor", 650, 0 },
	{ "Zone 05 CandyCornFields", 910, 0 }, { "Zone 06 BoneDesert", 1251, 0 },
	{ "Zone 07 SpiderCaverns", 1648, 0 }, { "Zone 08 WitchsVolcano", 2107, 0 },
	{ "Zone 09 GhostShipCove", 2655, 0 }, { "Zone 10 BloodMoonEclipse", 3282, 0 },
	{ "Zone 11 MadScientistLab", 3959, 0 }, { "Zone 12 HauntedCarnival", 4686, 0 },
	{ "Zone 13 VampireCastle", 5462, 0 }, { "Zone 14 PumpkinKingsThrone", 6289, 0 },
	{ "Zone 15 WerewolfWoods", 7166, 0 }, { "Zone 16 HauntedClocktower", 8093, 0 },
	{ "Zone 17 GhostTrainStation", 9070, 0 }, { "Zone 18 BatCavern", 10076, 0 },
	{ "Zone 19 CursedToyFactory", 11082, 0 }, { "Zone 20 HauntedLighthouse", 12088, 0 },
	{ "Zone 21 SkeletonCryptKingdom", 13094, 0 }, { "Zone 22 FrostbiteGraveyard", 14097, 0 },
}

-- พิกัดจริงจาก dump: PenSpawn_N = (23, z) | ShopZone = (85.6, z) | BossArena.Patch = (62, 242)
local PLACES = {
	{ "My Plot (home)", 0, 0 }, -- ตัวแทน: หา plot ตัวเองตอนรัน
	{ "Lobby Spawn", 60, 0 },
	{ "Plot 1 (spawn)", 23, 0 },
	{ "Plot 2 (spawn)", 23, -100 },
	{ "Plot 3 (spawn)", 23, 100 },
	{ "Plot 4 (spawn)", 23, -200 },
	{ "Plot 5 (spawn)", 23, 200 },
	{ "Shop: Costume", 85.6, -96 },
	{ "Shop: Trail", 85.6, -198 },
	{ "Shop: Pet", 85.6, 96 },
	{ "Shop: Event", 85.6, 198 },
	{ "Boss Arena", 62, 242 },
}
local PLOT_SPAWN = { Plot1 = Vector3.new(23, STAND_Y, 0), Plot2 = Vector3.new(23, STAND_Y, -100),
	Plot3 = Vector3.new(23, STAND_Y, 100), Plot4 = Vector3.new(23, STAND_Y, -200), Plot5 = Vector3.new(23, STAND_Y, 200) }

local NAMES, POS = {}, {}
for _, list in ipairs({ PLACES, ZONES }) do
	for _, d in ipairs(list) do
		table.insert(NAMES, d[1])
		POS[d[1]] = Vector3.new(d[2], STAND_Y, d[3])
	end
end

---------------------------------------------------------------- helpers
local State = { enabled = false, speed = 100, eggHome = false }
local conn, eggConn

local function say(msg)
	print("[TP] " .. msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "TP/TPWalk", Text = msg, Duration = 4 })
	end)
end

local function getRoot()
	local char = LocalPlayer.Character
	return char, char and char:FindFirstChild("HumanoidRootPart")
end

-- ส่งตัวไปที่พิกัด แล้วเช็กว่าโดนดึงกลับไหม (ถ้าโดนจะลองซ้ำ 1 ครั้งและแจ้งเตือน)
local function moveTo(pos, label)
	local char, hrp = getRoot()
	if not hrp then return false end
	char:PivotTo(CFrame.new(pos))
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.spawn(function()
		task.wait(0.6)
		local _, h = getRoot()
		if h and ((h.Position - pos) * Vector3.new(1, 0, 1)).Magnitude > 80 then
			hrp = h
			h.CFrame = CFrame.new(pos)
			task.wait(0.6)
			local _, h2 = getRoot()
			if h2 and ((h2.Position - pos) * Vector3.new(1, 0, 1)).Magnitude > 80 then
				say("โดนเซิร์ฟเวอร์ดึงกลับ: " .. tostring(label))
			end
		end
	end)
	return true
end

-- หา plot ของตัวเอง: Lobby.Pens.PlotN ที่ OwnerUserId = UserId เรา
local function findMyPlot()
	local pens
	pcall(function() pens = workspace.HalloweenMap.Lobby.Pens end)
	if not pens then return nil end
	for _, plot in ipairs(pens:GetChildren()) do
		local owner = plot:GetAttribute("OwnerUserId")
		if owner and tonumber(owner) == LocalPlayer.UserId then
			local n = plot.Name:match("%d+")
			local spawn = n and plot:FindFirstChild("PenSpawn_" .. n)
			if spawn and spawn:IsA("BasePart") then
				return spawn.Position + Vector3.new(0, STAND_Y, 0), plot.Name
			end
			if PLOT_SPAWN[plot.Name] then return PLOT_SPAWN[plot.Name], plot.Name end
		end
	end
	return nil
end

local function goHome()
	local pos, name = findMyPlot()
	if not pos then say("ไม่พบ plot ของคุณ (ยังไม่มี OwnerUserId = คุณ)") return end
	moveTo(pos, name)
end

local function teleport(name)
	if name == "My Plot (home)" then return goHome() end
	local pos = POS[name]
	if pos then moveTo(pos, name) end
end

local function stepZone(dir)
	local _, hrp = getRoot()
	if not hrp then return end
	local x, best, bestD = hrp.Position.X, 1, math.huge
	for i, z in ipairs(ZONES) do
		local d = math.abs(z[2] - x)
		if d < bestD then best, bestD = i, d end
	end
	local target = best
	if (dir > 0 and x >= ZONES[best][2] - 40) or (dir < 0 and x <= ZONES[best][2] + 40) then
		target = best + dir
	end
	target = math.clamp(target, 1, #ZONES)
	teleport(ZONES[target][1])
end

---------------------------------------------------------------- egg -> home
local function setEggHome(on)
	State.eggHome = on
	if eggConn then eggConn:Disconnect() eggConn = nil end
	if not on then return end
	local last = 0
	local function check()
		if State.eggHome and LocalPlayer:GetAttribute("CarryingEgg") == true and os.clock() - last > 1.5 then
			last = os.clock()
			task.wait(0.15)
			goHome()
		end
	end
	eggConn = LocalPlayer:GetAttributeChangedSignal("CarryingEgg"):Connect(check)
	check() -- ถ้าถือไข่อยู่ตอนเปิดสวิตช์ ให้วาร์ปเลย
end

---------------------------------------------------------------- TPWalk
local function stopWalk()
	if conn then conn:Disconnect() conn = nil end
end

local function setEnabled(on)
	State.enabled = on
	stopWalk()
	if on then
		conn = RunService.Heartbeat:Connect(function(dt)
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and hum.MoveDirection.Magnitude > 0 then
				char:TranslateBy(hum.MoveDirection * State.speed * dt)
			end
		end)
	end
end

local function setSpeed(v)
	State.speed = math.clamp(tonumber(v) or State.speed, MIN_SPEED, MAX_SPEED)
end

_G.__TPStop = function()
	stopWalk()
	if eggConn then eggConn:Disconnect() eggConn = nil end
	if _G.__TPGui then pcall(function() _G.__TPGui:Destroy() end) end
end

---------------------------------------------------------------- Lunar UI
local function guiExists()
	local roots = { LocalPlayer:FindFirstChild("PlayerGui") }
	pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
	pcall(function() if gethui then table.insert(roots, gethui()) end end)
	for _, r in ipairs(roots) do
		if r and r:FindFirstChild("LunarHubGui") then return true end
	end
	return false
end

local function tryLunar()
	if type(loadstring) ~= "function" then return false, "ไม่มี loadstring" end
	local okGet, src = pcall(function() return game:HttpGet(LIB_URL) end)
	if not okGet or type(src) ~= "string" or #src < 100 then return false, "ดึง Library ไม่ได้" end
	local fn, cerr = loadstring(src)
	if not fn then return false, "compile ไม่ผ่าน: " .. tostring(cerr) end
	local okRun, Lunar = pcall(fn)
	if not okRun then return false, "Library error: " .. tostring(Lunar) end

	local selected = NAMES[1]
	local Context = {
		Id = "TrickOrTreatTP",
		GameName = "Trick or Treat",
		Systems = {{
			Name = "TP",
			Build = function(UI)
				local page = UI.CreatePage("Teleport")
				UI.CreateTab("Teleport", "T")

				UI.Section(page, "Egg")
				UI.Toggle(page, "Egg -> TP Home", false, function(on) setEggHome(on) end)
				UI.Button(page, "TP My Plot", goHome)

				UI.Section(page, "Teleport")
				UI.Dropdown(page, "Destination", {
					Options = NAMES, Default = selected,
					OnChange = function(v) selected = v or selected end,
				})
				UI.Button(page, "Teleport", function() teleport(selected) end)
				UI.Button(page, "Next Zone", function() stepZone(1) end)
				UI.Button(page, "Prev Zone", function() stepZone(-1) end)

				UI.Section(page, "TPWalk")
				UI.Toggle(page, "TPWalk", false, function(on) setEnabled(on) end)
				UI.Slider(page, "Speed", MIN_SPEED, MAX_SPEED, State.speed, 0, function(v) setSpeed(v) end)
				UI.addCleanup(stopWalk)
				UI.addCleanup(function() setEggHome(false) end)
			end,
		}},
	}

	local starters, used = {}, {}
	if type(Lunar) == "function" then
		table.insert(starters, { "<return>", Lunar })
	elseif type(Lunar) == "table" then
		for _, n in ipairs({ "Build", "Run", "Start", "Init", "Create", "New", "Load", "Launch", "Open", "Mount", "Setup" }) do
			if type(Lunar[n]) == "function" then used[n] = true table.insert(starters, { n, Lunar[n] }) end
		end
		for k, v in pairs(Lunar) do
			if type(v) == "function" and not used[k] then table.insert(starters, { tostring(k), v }) end
		end
	else
		return false, "Library ไม่ได้ return ค่าที่ใช้ได้"
	end

	for _, s in ipairs(starters) do
		local ok1 = pcall(s[2], Context)
		if ok1 and guiExists() then return true, s[1] end
		local ok2 = pcall(s[2], Lunar, Context)
		if ok2 and guiExists() then return true, s[1] end
	end
	return false, "ไม่พบฟังก์ชันเริ่มต้นของ Library"
end

---------------------------------------------------------------- fallback UI
local function buildFallback()
	local parent
	pcall(function() parent = (gethui and gethui()) or game:GetService("CoreGui") end)
	parent = parent or LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "TPGui"
	gui.ResetOnSpawn = false
	gui.Parent = parent
	_G.__TPGui = gui

	local function mk(class, props, par)
		local o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		o.Parent = par
		if class ~= "Frame" and class ~= "ScrollingFrame" then
			Instance.new("UICorner", o).CornerRadius = UDim.new(0, 7)
		end
		return o
	end
	local OFF, ON = Color3.fromRGB(60, 60, 75), Color3.fromRGB(70, 160, 90)

	local frame = mk("Frame", {
		Size = UDim2.fromOffset(260, 380), Position = UDim2.new(0.5, -130, 0.1, 0),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28), Active = true, Draggable = true,
	}, gui)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	mk("TextLabel", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "TP + TPWalk",
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 14 }, frame)

	local function btn(text, x, y, w, cb, base)
		local b = mk("TextButton", {
			Size = UDim2.new(w, -8, 0, 28), Position = UDim2.new(x, 6, 0, y),
			BackgroundColor3 = base or Color3.fromRGB(45, 45, 62), Text = text,
			TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12,
		}, frame)
		b.Activated:Connect(function() cb(b) end)
		return b
	end

	-- แถว 1: TPWalk + ช่องความเร็ว
	btn("TPWalk: OFF", 0, 28, 0.5, function(b)
		setEnabled(not State.enabled)
		b.Text = "TPWalk: " .. (State.enabled and "ON" or "OFF")
		b.BackgroundColor3 = State.enabled and ON or OFF
	end, OFF)
	local box = mk("TextBox", {
		Size = UDim2.new(0.5, -8, 0, 28), Position = UDim2.new(0.5, 6, 0, 28),
		BackgroundColor3 = Color3.fromRGB(35, 35, 48), Text = tostring(State.speed), PlaceholderText = "50-500",
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false,
	}, frame)
	box.FocusLost:Connect(function() setSpeed(box.Text) box.Text = tostring(State.speed) end)

	-- แถว 2: ไข่ + กลับ plot
	btn("Egg->Home: OFF", 0, 62, 0.5, function(b)
		setEggHome(not State.eggHome)
		b.Text = "Egg->Home: " .. (State.eggHome and "ON" or "OFF")
		b.BackgroundColor3 = State.eggHome and ON or OFF
	end, OFF)
	btn("TP My Plot", 0.5, 62, 0.5, goHome)

	-- แถว 3: ข้ามโซน
	btn("< Zone", 0, 96, 0.5, function() stepZone(-1) end)
	btn("Zone >", 0.5, 96, 0.5, function() stepZone(1) end)

	local list = mk("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -134), Position = UDim2.fromOffset(8, 130),
		BackgroundTransparency = 1, ScrollBarThickness = 4,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, frame)
	mk("UIListLayout", { Padding = UDim.new(0, 4) }, list)
	for _, name in ipairs(NAMES) do
		local b = mk("TextButton", {
			Size = UDim2.new(1, -6, 0, 26), BackgroundColor3 = Color3.fromRGB(35, 35, 48),
			Text = name, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham, TextSize = 12,
		}, list)
		b.Activated:Connect(function() teleport(name) end)
	end
end

---------------------------------------------------------------- run
local ok, info = tryLunar()
if ok then
	say("Lunar UI พร้อมใช้งาน (แท็บ Teleport)")
else
	warn("[TP] Lunar UI ไม่ติด: " .. tostring(info))
	say("ใช้ UI สำรองแทน")
	buildFallback()
end
