CarKeys = {
    Give = function(veh, plate)
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    end
}

return CarKeys