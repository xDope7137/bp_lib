CarKeys = {
    Give = function(veh, plate)
        TriggerServerEvent('t1ger_keys:giveCopyKeys', plate, veh, GetPlayerServerId(NetworkGetPlayerIndexFromPed(PlayerPedId())))
    end
}

return CarKeys