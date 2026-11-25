CarKeys = {
    Give = function(veh, plate)
        DecorSetInt(veh, 'owner', GetPlayerServerId(PlayerId()))
    end
}

return CarKeys