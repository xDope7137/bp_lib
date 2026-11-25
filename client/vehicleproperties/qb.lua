VehicleProperties = {
    Set = function(vehicle, properties)
        QBCore.Functions.SetVehicleProperties(vehicle, properties)
    end,

    Get = function(vehicle)
        return QBCore.Functions.GetVehicleProperties(vehicle)
    end,
}

return VehicleProperties