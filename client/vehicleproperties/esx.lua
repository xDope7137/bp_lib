VehicleProperties = {
    Set = function(vehicle, properties)
        ESX.Game.SetVehicleProperties(vehicle, properties)
    end,

    Get = function(vehicle)
        return ESX.Game.GetVehicleProperties(vehicle)
    end,
}

return VehicleProperties