CarKeys = {
    Give = function(veh, plate)
        exports[Config.VehicleKeysResource]:addKey(plate)
    end
}

RegisterNetEvent('bp_lib:RemoveVehKeys', function(veh, plate)
    exports[Config.VehicleKeysResource]:removeKey(plate)
end)

return CarKeys