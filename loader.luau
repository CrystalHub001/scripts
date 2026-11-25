repeat
	task.wait()
until game:IsLoaded()

local placeid = game.PlaceId
local gameid = game.GameId

local ars = placeid == 286090429
local untitled= placeid == 13621938427

if ars then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/arsenal.luau"))()
end

if untitled then
loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/untitledboxing.luau"))()
end
