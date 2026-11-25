local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CrystalUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/CrystalUI.luau"))()

local Win = CrystalUI:CreateWindow({
	Title = "Crystal Hub",
	SubTitle = "v4",
	Icon = "129839496275500",
	ToggleIcon = 129839496275500,
	Tag = "V1",
	Size = UDim2.fromOffset(540, 320),
	Columns = 2,
	ConfigFolder = "CrystalHub",
})

local AimConfig = {
	Enabled = false,
	SilentShot = false,
	SilentPart = "Head",
	WallCheck = true,
	TeamCheck = true,
	ShowFOV = false,
	FOV = 220,
	Smoothness = 0.25,
}

local ESPConfig = {
	Enabled = false,
	Boxes = true,
	Names = true,
	TeamCheck = true,
}

local currentTarget = nil
local SharedRaycastParams = RaycastParams.new()
SharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
SharedRaycastParams.IgnoreWater = true

-- ==========================================
-- FOV CIRCLE (ScreenGui รองรับมือถือ)
-- ==========================================
local ParentGui = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
local oldOverlay = ParentGui:FindFirstChild("CrystalMobileOverlay")
if oldOverlay then oldOverlay:Destroy() end

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

-- ==========================================
-- ESP (Highlight + BillboardGui)
-- ==========================================
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

local function clearESP()
	ESPFolder:ClearAllChildren()
end

local function updateRobloxESP()
	if not ESPConfig.Enabled then
		if #ESPFolder:GetChildren() > 0 then
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
			local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))

			local valid = char and hum and hum.Health > 0 and head and not (ESPConfig.TeamCheck and isSameTeam(player))

			if not valid then
				if existing then existing:Destroy() end
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
-- TARGETING & ACTOR / GC HOOK
-- ==========================================
local function isVisible(part)
	if not AimConfig.WallCheck then return true end
	local cam = workspace.CurrentCamera
	if not cam or not part then return false end

	local origin = cam.CFrame.Position
	SharedRaycastParams.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}

	local direction = part.Position - origin
	local result = workspace:Raycast(origin, direction, SharedRaycastParams)
	if result then
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		return hitChar ~= nil and Players:GetPlayerFromCharacter(hitChar) ~= nil
	end
	return true
end

local function getTargetPart(char, preferredName)
	if not char then return nil end
	local part = char:FindFirstChild(preferredName)
	if part and part:IsA("BasePart") then
		return part
	end
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return nil
end

local function getClosestPlayerTarget()
	local cam = workspace.CurrentCamera
	if not cam then return nil end

	local closestDistance = AimConfig.FOV
	local closest = nil
	local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if AimConfig.TeamCheck and isSameTeam(player) then continue end

		local char = player.Character
		if not char then continue end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then continue end

		local aimPart = getTargetPart(char, AimConfig.SilentPart)
		if not aimPart then continue end

		local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
		if onScreen and screenPos.Z > 0 then
			local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
			if dist < closestDistance and isVisible(aimPart) then
				closestDistance = dist
				closest = aimPart
			end
		end
	end

	return closest
end

local function hookGCFunctions()
	if type(getgc) ~= "function" or type(hookfunction) ~= "function" then return end
	for _, v in pairs(getgc()) do
		if type(v) == "function" and (type(islclosure) ~= "function" or islclosure(v)) then
			local ok, matched = pcall(function()
				local argCount = debug.info(v, "a")
				local nameLen = debug.info(v, "n"):len()
				local upvals = debug.getupvalues and #debug.getupvalues(v) or -1
				local consts = debug.getconstants and #debug.getconstants(v) or -1
				return argCount == 2 and upvals == 2 and consts == 17 and nameLen <= 10
			end)
			if ok and matched then
				local oldFn
				oldFn = hookfunction(v, function(p1, p2)
					if AimConfig.SilentShot and currentTarget and currentTarget.Parent then
						local myChar = LocalPlayer.Character
						local head = myChar and myChar:FindFirstChild("Head")
						if head and head:IsA("BasePart") then
							local direction = currentTarget.Position - head.Position
							p1 = Ray.new(head.Position, direction)
						end
					end
					return oldFn(p1, p2)
				end)
			end
		end
	end
end

pcall(function()
	if type(getactors) == "function" and type(run_on_actor) == "function" then
		local actors = getactors()
		if actors and actors[1] then
			run_on_actor(actors[1], [=[
				local Players = game:GetService("Players")
				local RunService = game:GetService("RunService")
				local LocalPlayer = Players.LocalPlayer
				local actorTarget = nil

				local function actorVisible(part)
					local cam = workspace.CurrentCamera
					if not cam or not part then return false end
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
					params.IgnoreWater = true
					local result = workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, params)
					if result then
						local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
						return hitChar ~= nil and Players:GetPlayerFromCharacter(hitChar) ~= nil
					end
					return true
				end

				local function actorClosest()
					local cam = workspace.CurrentCamera
					if not cam then return nil end
					local bestDist = math.huge
					local bestPart = nil
					local center = cam.ViewportSize * 0.5
					for _, plr in ipairs(Players:GetPlayers()) do
						if plr == LocalPlayer then continue end
						if plr.Team and LocalPlayer.Team and plr.Team.Name == LocalPlayer.Team.Name then continue end
						local char = plr.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						local head = char and char:FindFirstChild("Head")
						if hrp and hum and hum.Health > 0 and head then
							local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
							if onScreen and pos.Z > 0 then
								local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
								if d < bestDist and actorVisible(head) then
									bestDist = d
									bestPart = head
								end
							end
						end
					end
					return bestPart
				end

				RunService.RenderStepped:Connect(function()
					actorTarget = actorClosest()
				end)

				if type(getgc) == "function" and type(hookfunction) == "function" then
					for _, v in pairs(getgc()) do
						if type(v) == "function" and (type(islclosure) ~= "function" or islclosure(v)) then
							local ok, matched = pcall(function()
								return debug.info(v, "a") == 2
									and #debug.getupvalues(v) == 2
									and #debug.getconstants(v) == 17
									and debug.info(v, "n"):len() <= 10
							end)
							if ok and matched then
								local oldFn
								oldFn = hookfunction(v, function(p1, p2)
									if actorTarget and actorTarget.Position then
										local myChar = LocalPlayer.Character
										local head = myChar and myChar:FindFirstChild("Head")
										if head then
											p1 = Ray.new(head.Position, actorTarget.Position - head.Position)
										end
									end
									return oldFn(p1, p2)
								end)
							end
						end
					end
				end
			]=])
		end
	end
	hookGCFunctions()
end)

local lastESPUpdate = 0
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end

	FOVFrame.Visible = AimConfig.ShowFOV
	FOVFrame.Size = UDim2.fromOffset(AimConfig.FOV * 2, AimConfig.FOV * 2)

	if os.clock() - lastESPUpdate >= 0.12 then
		lastESPUpdate = os.clock()
		updateRobloxESP()
	end

	currentTarget = getClosestPlayerTarget()

	if AimConfig.Enabled and currentTarget then
		local targetCFrame = CFrame.new(cam.CFrame.Position, currentTarget.Position)
		if AimConfig.Smoothness <= 0 then
			cam.CFrame = targetCFrame
		else
			cam.CFrame = cam.CFrame:Lerp(targetCFrame, math.clamp(AimConfig.Smoothness, 0.01, 1))
		end
	end
end)

-- ==========================================
-- UI LAYOUT (Crystal UI v4)
-- ==========================================
Win:CreateCategory("Main")

local CombatTab = Win:CreateTab("Combat", "crosshair")

CombatTab:CreateSection("Aim & Silent", "Left")
CombatTab:CreateToggle({
	Name = "Head Lock",
	Desc = "เปิด/ปิดระบบล็อกหัว (มือถือ)",
	Flag = "HeadLock",
	Callback = function(v)
		AimConfig.Enabled = v
	end,
})
CombatTab:CreateToggle({
	Name = "Silent Shot (Actor GC)",
	Desc = "เบี่ยงวิถีกระสุนผ่านฟังก์ชันที่ค้นพบใน GC",
	Flag = "SilentShot",
	Callback = function(v)
		AimConfig.SilentShot = v
	end,
})
CombatTab:CreateDropdown({
	Name = "Target Part",
	Options = {"Head", "HumanoidRootPart", "UpperTorso"},
	Default = "Head",
	Flag = "TargetPart",
	Callback = function(v)
		if type(v) == "string" then
			AimConfig.SilentPart = v
		end
	end,
})
CombatTab:CreateSlider({
	Name = "Smoothness (%)",
	Min = 0,
	Max = 100,
	Default = 25,
	Flag = "Smoothness",
	Callback = function(v)
		if v <= 0 then
			AimConfig.Smoothness = 0
		else
			AimConfig.Smoothness = math.clamp(1 - (v / 105), 0.03, 1)
		end
	end,
})

CombatTab:CreateSection("Checks & FOV", "Right")
CombatTab:CreateToggle({
	Name = "Wall Check",
	Desc = "ไม่ล็อกหรือยิงทะลุสิ่งกีดขวาง",
	Default = true,
	Flag = "WallCheck",
	Callback = function(v)
		AimConfig.WallCheck = v
	end,
})
CombatTab:CreateToggle({
	Name = "Team Check",
	Desc = "ไม่ล็อกหรือยิงทีมเดียวกัน",
	Default = true,
	Flag = "TeamCheck",
	Callback = function(v)
		AimConfig.TeamCheck = v
	end,
})
CombatTab:CreateToggle({
	Name = "Show FOV",
	Desc = "แสดงวงกลม FOV กลางจอ",
	Flag = "ShowFOV",
	Callback = function(v)
		AimConfig.ShowFOV = v
	end,
})
CombatTab:CreateSlider({
	Name = "FOV Radius",
	Min = 30,
	Max = 600,
	Default = 220,
	Flag = "FOVRadius",
	Callback = function(v)
		AimConfig.FOV = v
	end,
})

local VisualsTab = Win:CreateTab("Visuals", "eye")

VisualsTab:CreateSection("ESP Main", "Left")
VisualsTab:CreateToggle({
	Name = "ESP Enabled",
	Desc = "เปิด/ปิดมองทะลุผู้เล่น",
	Flag = "ESPEnabled",
	Callback = function(v)
		ESPConfig.Enabled = v
		if not v then clearESP() end
	end,
})
VisualsTab:CreateToggle({
	Name = "Box Highlight",
	Desc = "ไฮไลต์กรอบตัวละคร",
	Default = true,
	Flag = "ESPBoxes",
	Callback = function(v)
		ESPConfig.Boxes = v
	end,
})

VisualsTab:CreateSection("ESP Details", "Right")
VisualsTab:CreateToggle({
	Name = "Name & HP",
	Desc = "แสดงชื่อ เลือด และระยะ",
	Default = true,
	Flag = "ESPNames",
	Callback = function(v)
		ESPConfig.Names = v
	end,
})
VisualsTab:CreateToggle({
	Name = "ESP Team Check",
	Desc = "ซ่อนทีมเดียวกัน",
	Default = true,
	Flag = "ESPTeamCheck",
	Callback = function(v)
		ESPConfig.TeamCheck = v
	end,
})

Win:CreateCategory("Misc")
Win:AddSettingsTab("Settings")

CrystalUI:Notify({
	Title = "Crystal Hub v4",
	Content = "โหลดพร้อม Actor GC Silent Aim และ ESP แล้ว",
	Duration = 4,
	Type = "success",
})
