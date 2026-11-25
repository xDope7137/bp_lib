CarKeys = {
    Give = function(veh, plate)
        TriggerEvent('cd_garage:AddKeys', exports['cd_garage']:GetPlate(veh))
    end
}

return CarKeys