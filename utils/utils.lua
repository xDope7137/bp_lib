Utils = {
    CompareTables = function(first, second)
        for k, v in pairs(first) do
            if not second[k] then return false end
            if type(v) == "table"  then
                if not Utils.CompareTables(v, second[k]) then return false end
            else
                if second[k] ~= v then
                    return false
                end
            end
        end
        
        return true
    end,

    Print = function(...)
        if not Config.Debug then return end
        print(...)
    end,

    GetClosestVehicle = function(coords, radius)
        -- Find the first vehicle the player is facing within the given radius
        local playerPed = PlayerPedId and PlayerPedId() or -1
        local playerCoords = coords or (playerPed ~= -1 and GetEntityCoords(playerPed) or vector3(0,0,0))
        local forwardVector = GetEntityForwardVector(playerPed)
        local vehicles = GetGamePool('CVehicle')
        local foundVehicle = nil
        local foundDistance = radius

        for _, vehicle in pairs(vehicles) do
            local vehCoords = GetEntityCoords(vehicle)
            local toVeh = vehCoords - playerCoords
            local distance = #(toVeh)
            if distance < radius then
                -- Check if vehicle is in front of player (dot product > 0.7 ~ within 45 degrees cone)
                local dirToVeh = toVeh / (distance > 0 and distance or 1)
                local dot = forwardVector.x * dirToVeh.x + forwardVector.y * dirToVeh.y + forwardVector.z * dirToVeh.z
                if dot > 0.7 then
                    foundVehicle = vehicle
                    foundDistance = distance
                    break -- first vehicle in facing direction
                end
            end
        end

        return foundVehicle, foundDistance
    end
}