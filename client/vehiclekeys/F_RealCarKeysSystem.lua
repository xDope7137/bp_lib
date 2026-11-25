CarKeys = {
    Give = function(veh, plate)
        TriggerServerEvent('F_RealCarKeysSystem:generateVehicleKeys', plate)
    end
}

return CarKeys