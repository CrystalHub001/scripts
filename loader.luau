if not game:IsLoaded() then
	game.Loaded:Wait()
end

local placeid = game.PlaceId

local ars = placeid == 286090429
local untitled = placeid == 13621938427

if ars then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/arsenal.luau"))()
elseif untitled then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/untitledboxing.luau"))()
end
