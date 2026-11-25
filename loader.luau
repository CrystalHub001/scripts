repeat
	task.wait()
until game:IsLoaded()

local placeid = game.PlaceId
local ars = placeid == 286090429

if ars then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/arsenal.luau"))()
end
