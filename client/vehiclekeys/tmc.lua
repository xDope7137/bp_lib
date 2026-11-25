CarKeys = {
    Give = function(veh, plate)
        TriggerEvent('vehiclelock:client:addKeys', veh, false)
    end
}

return CarKeys