Fuel = {
    GetFuel = function(veh, plate)
        if not veh then return 0 end
        return exports[Config.FuelResource]:GetVehicleFuelPercentage(veh)
    end,

    SetFuel = function(veh, plate, level)
        exports[Config.FuelResource]:SetVehicleFuel(veh, level)
    end
}

return Fuel