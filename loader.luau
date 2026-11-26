if not game:IsLoaded() then
	game.Loaded:Wait()
end

local StarterGui = game:GetService("StarterGui")
local placeid = game.PlaceId

local ars = placeid == 286090429
local untitled = placeid == 13621938427
local rdsc = placeid == 106931373443671

if ars then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/arsenal.luau"))()
elseif untitled then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/untitledboxing.luau"))()
elseif rdsc then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/ragdollfootball.luau"))()
else
	StarterGui:SetCore("SendNotification", {
		Title = "Crystal Hub",
		Text = "❌ Not Supported ❌",
		Duration = 5
	})
end
