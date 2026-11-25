Fuel = {
    GetFuel = function(veh, plate)
        if not veh or not plate then return 0 end
        return exports[Config.FuelResource]:GetFuel(veh)
    end,

    SetFuel = function(veh, plate, level)
        exports[Config.FuelResource]:SetFuel(veh, level)
    end
}

return Fuel