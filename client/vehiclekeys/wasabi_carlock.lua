CarKeys = {
    Give = function(veh, plate)
        exports[Config.VehicleKeysResource]:GiveKey(plate)
    end
}

RegisterNetEvent('bp_lib:RemoveVehKeys', function(veh, plate)
    exports[Config.VehicleKeysResource]:RemoveKey(plate)
end)

return CarKeys
