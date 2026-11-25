local CrystalUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/CrystalUI.luau"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local lastPerfect

local Config = {
	AutoDodgeEnabled = false,
	IgnoreFeints = true,
	MaxRange = 14,
}

if getgenv().dodge then
	getgenv().dodge:Disconnect()
	getgenv().dodge = nil
end

if getgenv().dodgeChar then
	getgenv().dodgeChar:Disconnect()
	getgenv().dodgeChar = nil
end

local function getState()
	local states = workspace:FindFirstChild("States")
	return states and states:FindFirstChild(player.Name) or nil
end

local function getOpponent()
	local state = getState()
	local occupied = state and state:FindFirstChild("Occupied")
	local locked = occupied and occupied:FindFirstChild("LockedOn")
	return locked and locked.Value or nil
end

local function isDashing()
	local state = getState()
	local occupied = state and state:FindFirstChild("Occupied")
	local dash = occupied and occupied:FindFirstChild("Dashing")
	return dash and dash.Value or false
end

local function dodge()
	local character = player.Character
	if not character then return end

	local perfect = character:GetAttribute("Perfect")
	if perfect == nil or perfect == lastPerfect then
		return
	end

	local direction = character:GetAttribute("NeededDirection")
	if direction ~= "Left" and direction ~= "Right" and direction ~= "Backward" and direction ~= "Forward" then
		return
	end

	local opponent = getOpponent()
	if not opponent then return end

	if Config.IgnoreFeints and (opponent:GetAttribute("IsFeinting") == true or opponent:GetAttribute("LocalIsFeinting") == true) then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local eroot = opponent:FindFirstChild("HumanoidRootPart")
	if root and eroot then
		if (root.Position - eroot.Position).Magnitude > Config.MaxRange then
			return
		end
	end

	if isDashing() then
		return
	end

	local events = ReplicatedStorage:FindFirstChild("Events")
	local dashEvent = events and events:FindFirstChild("ForceDash")
	if not dashEvent then
		return
	end

	lastPerfect = perfect
	dashEvent:Fire({ Direction = direction })

	for _ = 1, 2 do
		RunService.Heartbeat:Once(function()
			if player.Character == character and character:GetAttribute("Perfect") == perfect and not isDashing() then
				dashEvent:Fire({ Direction = direction })
			end
		end)
	end
end

getgenv().dodge = RunService.Heartbeat:Connect(function()
	if not Config.AutoDodgeEnabled or not player.Character then
		return
	end
	dodge()
end)

getgenv().dodgeChar = player.CharacterAdded:Connect(function()
	lastPerfect = nil
end)

local Win = CrystalUI:CreateWindow({
	Title = "Crystal Hub",
	SubTitle = "v4",
	Icon = "129839496275500",
	ToggleIcon = 129839496275500,
	Tag = "V1",
	Size = UDim2.fromOffset(640, 420),
	Columns = 2,
	ConfigFolder = "CrystalHub",
})

Win:CreateCategory("Main")
local Tab = Win:CreateTab("Combat", "swords")

Tab:CreateSection("Auto Dodge", "Left")

Tab:CreateToggle({
	Name = "Auto Dodge",
	Desc = "Automatically triggers ForceDash on Perfect window",
	Flag = "AutoDodgeEnabled",
	Default = Config.AutoDodgeEnabled,
	Callback = function(v)
		Config.AutoDodgeEnabled = v
		if not v then
			lastPerfect = nil
		end
	end,
})

Tab:CreateToggle({
	Name = "Ignore Feints",
	Desc = "Skip dodging when opponent is feinting",
	Flag = "IgnoreFeints",
	Default = Config.IgnoreFeints,
	Callback = function(v)
		Config.IgnoreFeints = v
	end,
})

Tab:CreateSection("Settings", "Right")

Tab:CreateSlider({
	Name = "Max Range",
	Min = 5,
	Max = 30,
	Default = Config.MaxRange,
	Flag = "DodgeMaxRange",
	Callback = function(v)
		Config.MaxRange = v
	end,
})

Win:CreateCategory("Misc")
Win:AddSettingsTab("Settings")

CrystalUI:Notify({
	Title = "Crystal Hub",
	Content = "Auto Dodge loaded.",
	Duration = 4,
	Type = "success",
})
