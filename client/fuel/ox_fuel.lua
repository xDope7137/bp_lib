--[[ ox_fuel keeps a vehicle's level in two places: the game's own fuel level and the `fuel`
     state bag. While someone drives, its loop writes the game level into the bag every second,
     so a bag set alone is overwritten by the game level (about 65 on a new car). Set both, the
     way ox_fuel's own fuel.setFuel does: the game level, then the bag replicated (a client's
     plain `state.fuel = x` stays local). The bag only replicates from the client that owns the
     vehicle (the one that spawned it or has network control). ]]
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
