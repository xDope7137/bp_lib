-- FRFuel (thers/FRFuel, FRFuel.cs) keeps the level in litres, 0 to fPetrolTankVolume, in the game
-- level and in the float decor '_Fuel_Level'. It reads the decor back (consumption, getting in), so
-- a write to the game level alone is lost. bp_lib speaks percent (0-100) on both sides.
local DECOR = '_Fuel_Level'

local function tank(veh)
    local volume = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
    if type(volume) ~= 'number' or volume <= 0 then return nil end
    return volume
end

Fuel = {
    GetFuel = function(veh, plate)
        if not veh or not plate then return 0 end
        local level = GetVehicleFuelLevel(veh)
        local volume = tank(veh)
        if not volume then return level end
        return math.floor(100 / volume * level * 10 + 0.5) / 10
    end,

    SetFuel = function(veh, plate, level)
        level = math.max(0.0, math.min(100.0, tonumber(level) or 0))
        local volume = tank(veh)
        local litres = volume and (level / 100 * volume) or level
        SetVehicleFuelLevel(veh, litres + 0.0)
        if DecorIsRegisteredAsType(DECOR, 1) then
            DecorSetFloat(veh, DECOR, litres + 0.0)
        end
    end
}

return Fuel
