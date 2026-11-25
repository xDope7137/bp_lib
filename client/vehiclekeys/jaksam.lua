CarKeys = {
    Give = function(veh, plate)
        TriggerServerEvent("vehicles_keys:selfGiveVehicleKeys", plate)
    end
}

return CarKeys