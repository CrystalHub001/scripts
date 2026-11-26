local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CrystalUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/CrystalUI.luau"))()

local Window = CrystalUI:CreateWindow({
	Title = "Crystal Hub",
	Author = "By CrystalHub",
	Icon = "129839496275500",
	Tag = "Premium",
	Folder = "CrystalHub",
	Size = UDim2.fromOffset(540, 320),
	Theme = "Purple",
	Columns = 2,
})

local IsUnloaded = false

local AimConfig = {
	Enabled = false,
	Triggerbot = false,
	TriggerDelay = 90,
	TriggerRadius = 55,
	SilentShot = false,
	SilentPart = "Head",
	WallCheck = false,
	TeamCheck = true,
	ShowFOV = false,
	FOV = 240,
	Smoothness = 0.25,
}

local HitboxConfig = {
	Enabled = false,
	Size = 14,
	Transparency = 0.6,
	NoCollision = true,
	TeamMode = "Enemy",
}

local MoveConfig = {
	Fly = false,
	FlySpeed = 40,
	AutoFarm = false,
}

local ESPConfig = {
	Enabled = false,
	Boxes = true,
	Names = true,
	TeamCheck = true,
}

local currentTarget = nil
local lastTriggerTime = 0
local cachedMobileFireBtn = nil
local lastBtnScan = 0

local hitboxBackup = {}
local flyBP = nil
local flyBG = nil
local flyAnchorPos = nil
local isFlying = false

local SharedRaycastParams = RaycastParams.new()
SharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
SharedRaycastParams.IgnoreWater = true

-- ==========================================
-- OVERLAY GUI (FOV + ESP)
-- ==========================================
local ParentGui = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
local oldOverlay = ParentGui:FindFirstChild("CrystalMobileOverlay")
if oldOverlay then
	oldOverlay:Destroy()
end

local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "CrystalMobileOverlay"
OverlayGui.IgnoreGuiInset = true
OverlayGui.ResetOnSpawn = false
OverlayGui.Parent = ParentGui

local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "FOVCircle"
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.fromScale(0.5, 0.5)
FOVFrame.Size = UDim2.fromOffset(AimConfig.FOV * 2, AimConfig.FOV * 2)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Visible = false
FOVFrame.Parent = OverlayGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVFrame

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = Color3.fromRGB(236, 72, 153)
FOVStroke.Thickness = 1.6
FOVStroke.Transparency = 0.15
FOVStroke.Parent = FOVFrame

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "CrystalESPFolder"
ESPFolder.Parent = OverlayGui

local function isSameTeam(player)
	if player.Team and LocalPlayer.Team then
		if player.Team == LocalPlayer.Team or player.Team.Name == LocalPlayer.Team.Name then
			return true
		end
	end
	if player.TeamColor and LocalPlayer.TeamColor and player.TeamColor == LocalPlayer.TeamColor then
		return true
	end
	return false
end

local function isHitboxTarget(player)
	if HitboxConfig.TeamMode == "FFA" or HitboxConfig.TeamMode == "Everyone" then
		return true
	end
	return not isSameTeam(player)
end

-- ==========================================
-- HITBOX EXPANDER & RESTORE
-- ==========================================
local hitboxParts = { "Head", "UpperTorso", "HumanoidRootPart" }

local function savePartProps(player, part)
	if not hitboxBackup[player] then
		hitboxBackup[player] = {}
	end
	if not hitboxBackup[player][part] then
		hitboxBackup[player][part] = {
			Size = part.Size,
			Transparency = part.Transparency,
			CanCollide = part.CanCollide,
		}
	end
end

local function restorePlayerHitbox(player)
	local charMap = hitboxBackup[player]
	if not charMap then
		return
	end
	for part, props in pairs(charMap) do
		if part and part.Parent then
			pcall(function()
				part.Size = props.Size
				part.Transparency = props.Transparency
				part.CanCollide = props.CanCollide
			end)
		end
	end
	hitboxBackup[player] = nil
end

local function restoreAllHitboxes()
	for player in pairs(hitboxBackup) do
		restorePlayerHitbox(player)
	end
	hitboxBackup = {}
end

local function updateHitboxes()
	if IsUnloaded or not HitboxConfig.Enabled then
		if next(hitboxBackup) ~= nil then
			restoreAllHitboxes()
		end
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and hum and hum.Health > 0 and isHitboxTarget(player) then
				for _, partName in ipairs(hitboxParts) do
					local part = char:FindFirstChild(partName)
					if part and part:IsA("BasePart") then
						savePartProps(player, part)
						pcall(function()
							part.Size = Vector3.new(HitboxConfig.Size, HitboxConfig.Size, HitboxConfig.Size)
							part.Transparency = HitboxConfig.Transparency
							part.CanCollide = not HitboxConfig.NoCollision
						end)
					end
				end
			else
				restorePlayerHitbox(player)
			end
		end
	end
end

-- ==========================================
-- STABLE MOBILE FLY & AUTOFARM (0, 3, 0)
-- ==========================================
local function stopMobileFly()
	isFlying = false
	flyAnchorPos = nil
	if flyBP and flyBP.Parent then
		flyBP:Destroy()
	end
	if flyBG and flyBG.Parent then
		flyBG:Destroy()
	end
	flyBP = nil
	flyBG = nil

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function updateMobileFly(dt)
	if IsUnloaded or not MoveConfig.Fly then
		if isFlying then
			stopMobileFly()
		end
		return
	end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not char or not hum or not root or not cam then
		return
	end

	if not isFlying or not flyBP or not flyBP.Parent or not flyBG or not flyBG.Parent then
		stopMobileFly()
		isFlying = true
		flyAnchorPos = root.Position
		hum.PlatformStand = true

		flyBP = Instance.new("BodyPosition")
		flyBP.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		flyBP.P = 15000
		flyBP.D = 1200
		flyBP.Position = flyAnchorPos
		flyBP.Parent = root

		flyBG = Instance.new("BodyGyro")
		flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
		flyBG.P = 15000
		flyBG.D = 800
		flyBG.CFrame = cam.CFrame
		flyBG.Parent = root
	end

	local moveDir = hum.MoveDirection
	if moveDir.Magnitude > 0.05 then
		local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
		if flatDir.Magnitude > 0.001 then
			flatDir = flatDir.Unit
		end
		local verticalVel = cam.CFrame.LookVector.Y * (moveDir.Magnitude * MoveConfig.FlySpeed * 0.65)
		local stepVel = (flatDir * MoveConfig.FlySpeed) + Vector3.new(0, verticalVel, 0)
		flyAnchorPos = flyAnchorPos + (stepVel * math.clamp(dt, 0, 0.1))
	end

	flyBP.Position = flyAnchorPos
	flyBG.CFrame = CFrame.lookAt(root.Position, root.Position + cam.CFrame.LookVector)
end

local function getNearestEnemyRoot()
	local myChar = LocalPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		return nil
	end

	local nearest = nil
	local shortest = math.huge

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not isSameTeam(plr) then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if char and hum and hum.Health > 0 and root then
				local dist = (root.Position - myRoot.Position).Magnitude
				if dist < shortest then
					shortest = dist
					nearest = root
				end
			end
		end
	end

	return nearest
end

local function updateAutoFarm()
	if IsUnloaded or not MoveConfig.AutoFarm then
		return
	end
	local myChar = LocalPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local enemyRoot = getNearestEnemyRoot()
	if myRoot and enemyRoot then
		local goalPos = enemyRoot.Position + Vector3.new(0, 3, 0)
		myRoot.CFrame = CFrame.lookAt(goalPos, enemyRoot.Position)
		if isFlying then
			flyAnchorPos = goalPos
		end
	end
end

-- ==========================================
-- TRIGGERBOT (โหมดมือถือ)
-- ==========================================
local function findMobileFireButton(cam)
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end

	local bestBtn = nil
	local bestScore = -1
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)

	for _, obj in ipairs(pg:GetDescendants()) do
		if (obj:IsA("ImageButton") or obj:IsA("TextButton")) and obj.Visible and obj.AbsoluteSize.Magnitude > 18 then
			local n = obj.Name:lower()
			local txt = (obj:IsA("TextButton") and obj.Text:lower()) or ""
			local score = 0

			if n:find("fire") or n:find("shoot") or n:find("attack") or txt:find("fire") or txt:find("shoot") then
				score = score + 100
			end
			if obj.AbsolutePosition.X > (vp.X * 0.55) then
				score = score + 20
			end

			if score > bestScore then
				bestScore = score
				bestBtn = obj
			end
		end
	end

	return bestScore >= 20 and bestBtn or nil
end

local function isTargetNearCenter(cam, part)
	if not cam or not part or not part.Parent then
		return false
	end
	local pos, onScreen = cam:WorldToViewportPoint(part.Position)
	if not onScreen or pos.Z <= 0 then
		return false
	end
	local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
	local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
	return dist <= AimConfig.TriggerRadius
end

local function updateTriggerbot(cam)
	if IsUnloaded or not AimConfig.Triggerbot or not currentTarget then
		return
	end
	if not isTargetNearCenter(cam, currentTarget) then
		return
	end

	local now = os.clock()
	if (now - lastTriggerTime) < (AimConfig.TriggerDelay / 1000) then
		return
	end
	lastTriggerTime = now

	local char = LocalPlayer.Character
	if char then
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			pcall(function()
				tool:Activate()
			end)
		end
	end

	if not cachedMobileFireBtn or not cachedMobileFireBtn.Parent or (now - lastBtnScan) > 2 then
		lastBtnScan = now
		cachedMobileFireBtn = findMobileFireButton(cam)
	end

	if cachedMobileFireBtn and type(firesignal) == "function" then
		pcall(function()
			firesignal(cachedMobileFireBtn.MouseButton1Down)
			firesignal(cachedMobileFireBtn.Activated)
			task.delay(0.02, function()
				pcall(function()
					firesignal(cachedMobileFireBtn.MouseButton1Up)
				end)
			end)
		end)
	end
end

-- ==========================================
-- ESP (Highlight + BillboardGui)
-- ==========================================
local function clearESP()
	if ESPFolder and ESPFolder.Parent then
		ESPFolder:ClearAllChildren()
	end
end

local function updateRobloxESP()
	if IsUnloaded or not ESPConfig.Enabled then
		if ESPFolder and #ESPFolder:GetChildren() > 0 then
			clearESP()
		end
		return
	end

	local myChar = LocalPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local tagName = "ESP_" .. player.UserId
			local existing = ESPFolder:FindFirstChild(tagName)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("FakeHead") or char:FindFirstChild("HumanoidRootPart"))

			local valid = char and hum and hum.Health > 0 and head and not (ESPConfig.TeamCheck and isSameTeam(player))

			if not valid then
				if existing then
					existing:Destroy()
				end
			else
				if not existing then
					existing = Instance.new("Folder")
					existing.Name = tagName
					existing.Parent = ESPFolder

					local hl = Instance.new("Highlight")
					hl.Name = "BoxHL"
					hl.FillColor = Color3.fromRGB(168, 85, 247)
					hl.OutlineColor = Color3.fromRGB(236, 72, 153)
					hl.FillTransparency = 0.75
					hl.OutlineTransparency = 0
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = existing

					local bb = Instance.new("BillboardGui")
					bb.Name = "NameBB"
					bb.Size = UDim2.fromOffset(180, 36)
					bb.StudsOffset = Vector3.new(0, 2.5, 0)
					bb.AlwaysOnTop = true
					bb.Parent = existing

					local lbl = Instance.new("TextLabel")
					lbl.Name = "Info"
					lbl.Size = UDim2.fromScale(1, 1)
					lbl.BackgroundTransparency = 1
					lbl.Font = Enum.Font.GothamBold
					lbl.TextSize = 13
					lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
					lbl.TextStrokeTransparency = 0.2
					lbl.Parent = bb
				end

				local hl = existing:FindFirstChild("BoxHL")
				if hl then
					hl.Adornee = char
					hl.Enabled = ESPConfig.Boxes
				end

				local bb = existing:FindFirstChild("NameBB")
				if bb then
					bb.Adornee = head
					bb.Enabled = ESPConfig.Names
					local lbl = bb:FindFirstChild("Info")
					if lbl then
						local distStr = ""
						if myRoot then
							distStr = string.format(" [%dm]", math.floor((head.Position - myRoot.Position).Magnitude + 0.5))
						end
						lbl.Text = string.format("%s | %d HP%s", player.DisplayName, math.floor(hum.Health + 0.5), distStr)
					end
				end
			end
		end
	end
end

-- ==========================================
-- TARGETING & SILENT SHOT
-- ==========================================
local function isVisible(part, targetChar)
	if not AimConfig.WallCheck then
		return true
	end
	local cam = workspace.CurrentCamera
	if not cam or not part then
		return false
	end

	local origin = cam.CFrame.Position
	local ignoreList = {}
	if LocalPlayer.Character then
		table.insert(ignoreList, LocalPlayer.Character)
	end
	table.insert(ignoreList, cam)
	SharedRaycastParams.FilterDescendantsInstances = ignoreList

	local direction = part.Position - origin
	local result = workspace:Raycast(origin, direction, SharedRaycastParams)
	if not result then
		return true
	end
	if targetChar and result.Instance:IsDescendantOf(targetChar) then
		return true
	end
	local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
	return hitChar ~= nil and Players:GetPlayerFromCharacter(hitChar) ~= nil
end

local function getTargetPart(char, preferredName)
	if not char then
		return nil
	end
	local part = char:FindFirstChild(preferredName)
	if part and part:IsA("BasePart") then
		return part
	end
	local fallback = char:FindFirstChild("Head")
		or char:FindFirstChild("FakeHead")
		or char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("UpperTorso")
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end
	return nil
end

local function getClosestPlayerTarget()
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end

	local closestDistance = AimConfig.FOV
	local closest = nil
	local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then
			continue
		end
		if AimConfig.TeamCheck and isSameTeam(player) then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end

		local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			continue
		end

		local aimPart = getTargetPart(char, AimConfig.SilentPart)
		if not aimPart then
			continue
		end

		local screenPos, onScreen = cam:WorldToViewportPoint(aimPart.Position)
		if onScreen and screenPos.Z > 0 then
			local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
			if dist < closestDistance and isVisible(aimPart, char) then
				closestDistance = dist
				closest = aimPart
			end
		end
	end

	return closest
end

pcall(function()
	if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			if not IsUnloaded and AimConfig.SilentShot and self == workspace then
				local method = getnamecallmethod()
				if method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
					local targetPart = currentTarget
					if targetPart and targetPart.Parent then
						local args = {...}
						if method == "Raycast" and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
							local mag = args[2].Magnitude
							if mag > 0 then
								args[2] = (targetPart.Position - args[1]).Unit * mag
								return oldNamecall(self, unpack(args))
							end
						elseif typeof(args[1]) == "Ray" then
							local oldRay = args[1]
							local mag = oldRay.Direction.Magnitude
							if mag > 0 then
								args[1] = Ray.new(oldRay.Origin, (targetPart.Position - oldRay.Origin).Unit * mag)
								return oldNamecall(self, unpack(args))
							end
						end
					end
				end
			end
			return oldNamecall(self, ...)
		end)
	end
end)

-- ==========================================
-- MAIN LOOP & COMPLETE CLEANUP
-- ==========================================
local lastESPUpdate = 0
local lastHitboxUpdate = 0
local mainConnection

mainConnection = RunService.RenderStepped:Connect(function(dt)
	if IsUnloaded then
		if mainConnection then
			mainConnection:Disconnect()
		end
		return
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return
	end

	FOVFrame.Visible = AimConfig.ShowFOV
	FOVFrame.Size = UDim2.fromOffset(AimConfig.FOV * 2, AimConfig.FOV * 2)

	local now = os.clock()
	if now - lastESPUpdate >= 0.12 then
		lastESPUpdate = now
		updateRobloxESP()
	end

	if now - lastHitboxUpdate >= 0.25 then
		lastHitboxUpdate = now
		updateHitboxes()
	end

	updateMobileFly(dt)
	updateAutoFarm()

	if AimConfig.Enabled or AimConfig.SilentShot or AimConfig.Triggerbot then
		currentTarget = getClosestPlayerTarget()
	else
		currentTarget = nil
	end

	if AimConfig.Enabled and currentTarget then
		local targetCFrame = CFrame.new(cam.CFrame.Position, currentTarget.Position)
		if AimConfig.Smoothness <= 0 then
			cam.CFrame = targetCFrame
		else
			cam.CFrame = cam.CFrame:Lerp(targetCFrame, math.clamp(AimConfig.Smoothness, 0.01, 1))
		end
	end

	updateTriggerbot(cam)
end)

local function unloadEverything()
	if IsUnloaded then
		return
	end
	IsUnloaded = true

	AimConfig.Enabled = false
	AimConfig.Triggerbot = false
	AimConfig.SilentShot = false
	AimConfig.ShowFOV = false
	HitboxConfig.Enabled = false
	MoveConfig.Fly = false
	MoveConfig.AutoFarm = false
	ESPConfig.Enabled = false
	currentTarget = nil
	cachedMobileFireBtn = nil

	if mainConnection then
		mainConnection:Disconnect()
		mainConnection = nil
	end

	stopMobileFly()
	restoreAllHitboxes()
	clearESP()

	if OverlayGui and OverlayGui.Parent then
		OverlayGui:Destroy()
	end
end

if Window and type(Window.Destroy) == "function" then
	local oldDestroy = Window.Destroy
	Window.Destroy = function(self, ...)
		unloadEverything()
		return oldDestroy(self, ...)
	end
end

task.spawn(function()
	local gethuiFolder = (gethui and gethui()) or game:GetService("CoreGui")
	local childRemovedConn
	childRemovedConn = gethuiFolder.ChildRemoved:Connect(function(child)
		if tostring(child.Name):find("Crystal") then
			unloadEverything()
			if childRemovedConn then
				childRemovedConn:Disconnect()
			end
		end
	end)
end)

-- ==========================================
-- UI LAYOUT (Crystal UI Latest API)
-- ==========================================
Window:Category("Main")

local CombatTab = Window:Tab({ Title = "Combat", Icon = "crosshair" })

CombatTab:Section({ Title = "Aim & Silent", Side = "Left" })
CombatTab:Toggle({
	Title = "Head Lock",
	Desc = "เปิด/ปิดระบบล็อกหัว (มือถือ)",
	Flag = "HeadLock",
	Callback = function(v)
		AimConfig.Enabled = v
	end,
})
CombatTab:Toggle({
	Title = "Triggerbot",
	Desc = "ยิงอัตโนมัติเมื่อเป้าอยู่กลางจอ",
	Flag = "Triggerbot",
	Callback = function(v)
		AimConfig.Triggerbot = v
	end,
})
CombatTab:Slider({
	Title = "Trigger Delay (ms)",
	Value = { Min = 30, Max = 1000, Default = 90 },
	Flag = "TriggerDelay",
	Callback = function(v)
		AimConfig.TriggerDelay = v
	end,
})
CombatTab:Toggle({
	Title = "Silent Shot",
	Desc = "เบี่ยงวิถีกระสุนเข้าเป้าในระยะ FOV",
	Flag = "SilentShot",
	Callback = function(v)
		AimConfig.SilentShot = v
	end,
})
CombatTab:Dropdown({
	Title = "Target Part",
	Values = { "Head", "HumanoidRootPart", "UpperTorso" },
	Value = "Head",
	Flag = "TargetPart",
	Callback = function(v)
		if type(v) == "string" then
			AimConfig.SilentPart = v
		end
	end,
})
CombatTab:Slider({
	Title = "Smoothness (%)",
	Value = { Min = 0, Max = 100, Default = 25 },
	Flag = "Smoothness",
	Callback = function(v)
		if v <= 0 then
			AimConfig.Smoothness = 0
		else
			AimConfig.Smoothness = math.clamp(1 - (v / 105), 0.03, 1)
		end
	end,
})

CombatTab:Section({ Title = "Hitbox & FOV", Side = "Right" })
CombatTab:Toggle({
	Title = "Enable Hitbox",
	Desc = "ขยายเป้าตัวละครและคืนค่าอัตโนมัติเมื่อปิด",
	Flag = "HitboxEnabled",
	Callback = function(v)
		HitboxConfig.Enabled = v
		if not v then
			restoreAllHitboxes()
		else
			updateHitboxes()
		end
	end,
})
CombatTab:Slider({
	Title = "Hitbox Size",
	Value = { Min = 2, Max = 25, Default = 14 },
	Flag = "HitboxSize",
	Callback = function(v)
		HitboxConfig.Size = v
	end,
})
CombatTab:Toggle({
	Title = "No Collision",
	Desc = "ไม่ชนตัวละครที่ขยาย Hitbox",
	Flag = "HitboxNoCollision",
	Callback = function(v)
		HitboxConfig.NoCollision = v
	end,
})
CombatTab:Dropdown({
	Title = "Hitbox Team Mode",
	Values = { "Enemy", "FFA", "Everyone" },
	Value = "Enemy",
	Flag = "HitboxTeamMode",
	Callback = function(v)
		if type(v) == "string" then
			HitboxConfig.TeamMode = v
		end
	end,
})
CombatTab:Toggle({
	Title = "Wall Check",
	Desc = "ไม่ล็อกหรือยิงทะลุสิ่งกีดขวาง",
	Flag = "WallCheck",
	Callback = function(v)
		AimConfig.WallCheck = v
	end,
})
CombatTab:Toggle({
	Title = "Team Check",
	Desc = "ไม่ล็อกหรือยิงทีมเดียวกัน",
	Flag = "TeamCheck",
	Callback = function(v)
		AimConfig.TeamCheck = v
	end,
})
CombatTab:Toggle({
	Title = "Show FOV",
	Desc = "แสดงวงกลม FOV กลางจอ",
	Flag = "ShowFOV",
	Callback = function(v)
		AimConfig.ShowFOV = v
	end,
})
CombatTab:Slider({
	Title = "FOV Radius",
	Value = { Min = 30, Max = 600, Default = 240 },
	Flag = "FOVRadius",
	Callback = function(v)
		AimConfig.FOV = v
	end,
})

local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })

VisualsTab:Section({ Title = "ESP Main", Side = "Left" })
VisualsTab:Toggle({
	Title = "ESP Enabled",
	Desc = "เปิด/ปิดมองทะลุผู้เล่น",
	Flag = "ESPEnabled",
	Callback = function(v)
		ESPConfig.Enabled = v
		if not v then
			clearESP()
		end
	end,
})
VisualsTab:Toggle({
	Title = "Box Highlight",
	Desc = "ไฮไลต์กรอบตัวละคร",
	Flag = "ESPBoxes",
	Callback = function(v)
		ESPConfig.Boxes = v
	end,
})

VisualsTab:Section({ Title = "ESP Details", Side = "Right" })
VisualsTab:Toggle({
	Title = "Name & HP",
	Desc = "แสดงชื่อ เลือด และระยะ",
	Flag = "ESPNames",
	Callback = function(v)
		ESPConfig.Names = v
	end,
})
VisualsTab:Toggle({
	Title = "ESP Team Check",
	Desc = "ซ่อนทีมเดียวกัน",
	Flag = "ESPTeamCheck",
	Callback = function(v)
		ESPConfig.TeamCheck = v
	end,
})

local FarmTab = Window:Tab({ Title = "Farm & Move", Icon = "zap" })

FarmTab:Section({ Title = "Mobile Fly", Side = "Left" })
FarmTab:Toggle({
	Title = "Mobile Fly",
	Desc = "บินนิ่งด้วยปุ่มเดินและเอียงกล้องบนมือถือ",
	Flag = "MobileFly",
	Callback = function(v)
		MoveConfig.Fly = v
		if not v then
			stopMobileFly()
		end
	end,
})
FarmTab:Slider({
	Title = "Fly Speed",
	Value = { Min = 15, Max = 120, Default = 40 },
	Flag = "FlySpeed",
	Callback = function(v)
		MoveConfig.FlySpeed = v
	end,
})

FarmTab:Section({ Title = "Auto Farm", Side = "Right" })
FarmTab:Toggle({
	Title = "Auto Farm",
	Desc = "วาปไปตำแหน่ง (0, 3, 0) เหนือศัตรูใกล้สุด",
	Flag = "AutoFarm",
	Callback = function(v)
		MoveConfig.AutoFarm = v
	end,
})

Window:Category("Misc")
local SettingsTab = Window:AddSettingsTab("Settings")
if SettingsTab and SettingsTab.Section then
	SettingsTab:Section({ Title = "Unload", Side = "Left" })
	SettingsTab:Button({
		Title = "ปิดเมนูและหยุดระบบทั้งหมด",
		Desc = "ล้างค่าและหยุดการทำงานทั้งหมดทันที",
		Callback = function()
			Window:Destroy()
		end,
	})
end

Window:SelectTab(1)

CrystalUI:Notify({
	Title = "Crystal Hub",
	Content = "โหลดสำเร็จ (UI ล่าสุด 540x320)",
	Duration = 4,
	Type = "success",
})
