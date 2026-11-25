VehicleProperties = {
    Set = function(vehicle, properties)
        lib.setVehicleProperties(vehicle, properties)
    end,

    Get = function(vehicle)
        return lib.getVehicleProperties(vehicle)
    end,
}

return VehicleProperties