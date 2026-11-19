--[[ TMC reads the fuel from the `fuel` state bag, like ox_fuel. Set it the way ox_fuel.lua
     here does: the game's own fuel level too (a fuel loop that copies the game level into the
     bag then keeps it), and the bag replicated (a client's plain `state.fuel = x` stays local).
     The bag only replicates from the client that owns the vehicle. ]]
Fuel = {
    GetFuel = function(veh, plate)
        if not veh or not plate then return 0 end
        return Entity(veh).state.fuel or GetVehicleFuelLevel(veh)
    end,

    SetFuel = function(veh, plate, level)
        if not veh or not DoesEntityExist(veh) then return end
        level = math.max(0.0, math.min((tonumber(level) or 0) + 0.0, 100.0))
        SetVehicleFuelLevel(veh, level)
        Entity(veh).state:set('fuel', level, true)
    end
}

return Fuel
