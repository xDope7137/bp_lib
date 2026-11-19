EntitySync = {
    Data = {},

    CreateEntity = function(model, pos, args)
        if not model or not pos then return end

        local result = Core.Framework.Callbacks.Trigger('bp_lib:CreateEntity', model, pos, args)
        return result
    end,

    CreateVehicle = function(model, pos, args)
        if not model or not pos then return end

        local result = Core.Framework.Callbacks.Trigger('bp_lib:CreateVehicle', model, pos, args)
        return result
    end,

    CreatePed = function(model, pos, args)
        if not model or not pos then return end

        local result = Core.Framework.Callbacks.Trigger('bp_lib:CreatePed', model, pos, args)
        return result
    end,

    RequestEntityControl = function(netId)
        if not netId then return end

        local entity = NetworkGetEntityFromNetworkId(netId)
        while not DoesEntityExist(entity) do Wait(100) end

        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
        NetworkRequestControlOfEntity(entity)

        local timeout = 500
        while not NetworkHasControlOfEntity(entity) and timeout > 0 do
            Wait(10)
            timeout -= 10
        end

        return NetworkHasControlOfEntity(entity)
    end,

    AttachEntities = function(parentNetId, childNetId, offset, rot)
        if not parentNetId or not childNetId then return end

        local parentEntity = NetworkGetEntityFromNetworkId(parentNetId)
        EntitySync.RequestEntityControl(parentNetId)

        local childEntity = NetworkGetEntityFromNetworkId(childNetId)
        EntitySync.RequestEntityControl(childEntity)

        while not DoesEntityExist(parentEntity) or not DoesEntityExist(childEntity) do
            Wait(100)
            parentEntity = NetworkGetEntityFromNetworkId(parentNetId)
            childEntity = NetworkGetEntityFromNetworkId(childNetId)
        end

        AttachEntityToEntity(childEntity, parentEntity, 0, offset.x, offset.y, offset.z, rot.x, rot.z, rot.z, false, false, false, false, 2, true)
    end,
}