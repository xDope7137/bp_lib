Fuel = {
    GetFuel = function(veh, plate)
        if not veh or not plate then return 0 end
        return DecorGetFloat(veh, '_ANDY_FUEL_DECORE_')
    end,

    SetFuel = function(veh, plate, level)
        SetVehicleFuelLevel(veh, level + 0.0)
		DecorSetFloat(veh, '_ANDY_FUEL_DECORE_', level + 0.0)
    end
}

return Fuel