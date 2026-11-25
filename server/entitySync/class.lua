EntitySync = {
    CreateEntity = function(model, pos, args)
        if not model or not pos then return false end

        model = joaat(model)
        local entity = CreateObjectNoOffset(model, pos.x, pos.y, pos.z, true, true, false)
        while not DoesEntityExist(entity) do Citizen.Wait(10) end

        if args?.freeze then
            FreezeEntityPosition(entity, true)
        end

        if pos?.w then
            SetEntityHeading(entity, pos.w)
        end

        SetEntityIgnoreRequestControlFilter(entity, true)
        local netId = NetworkGetNetworkIdFromEntity(entity)

        while NetworkGetEntityOwner(entity) == -1 or not DoesEntityExist(entity) do
            Wait(100)
        end

        return { entity = entity, netId = netId }
    end,

    CreatePed = function(model, pos, args)
        if not model or not pos then return false end

        model = joaat(model)
        local entity = CreatePed(0, model, pos.x, pos.y, pos.z, pos.w or 0, true, true)
        while not DoesEntityExist(entity) do Citizen.Wait(10) end

        if args?.freeze then
            FreezeEntityPosition(entity, true)
        end

        if pos?.w then
            SetEntityHeading(entity, pos.w)
        end

        SetEntityIgnoreRequestControlFilter(entity, true)
        local netId = NetworkGetNetworkIdFromEntity(entity)

        while NetworkGetEntityOwner(entity) == -1 or not DoesEntityExist(entity) do
            Wait(100)
        end

        return { entity = entity, netId = netId }
    end,

    CreateVehicle = function(model, pos, args)
        if not model or not pos then return false end

        model = joaat(GetHashKey(model))
        local vehicle = CreateVehicle(model, pos.x, pos.y, pos.z, pos.w or 0, true, true)
        while not DoesEntityExist(vehicle) do Citizen.Wait(100) end

        if args?.freeze then
            FreezeEntityPosition(vehicle, true)
        end

        SetEntityIgnoreRequestControlFilter(vehicle, true)
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        
        while NetworkGetEntityOwner(vehicle) == -1 or not DoesEntityExist(vehicle) do
            Wait(100)
        end

        return { entity = vehicle, netId = netId }
    end,
}

return EntitySync