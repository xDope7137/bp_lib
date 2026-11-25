CarKeys = {
    Give = function(veh, plate)
        exports[Config.VehicleKeysResource]:addTemporaryVehicle(plate)
    end
}

return CarKeys