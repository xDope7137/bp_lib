Core.Framework.RegisterCallback('bp_lib:CreateEntity', function(source, cb, model, pos, args)
    if not source or not model or not pos then return cb(false) end

    local result = EntitySync.CreateEntity(model, pos, args or {})
    if not result then return cb(false) end

    cb(result)
end)

Core.Framework.RegisterCallback('bp_lib:CreatePed', function(source, cb, model, pos, args)
    if not source or not model or not pos then return cb(false) end

    local result = EntitySync.CreatePed(model, pos, args or {})
    if not result then return cb(false) end

    cb(result)
end)

Core.Framework.RegisterCallback('bp_lib:CreateVehicle', function(source, cb, model, pos, args)
    if not source or not model or not pos then return cb(false) end

    local result = EntitySync.CreateVehicle(model, pos, args or {})
    if not result then return cb(false) end

    cb(result)
end)

exports('GetResourceSessionToken', function(resourceName)
    if not resourceName then return nil end
    
    return resourceName
end)

exports('ValidateResourceAccess', function(resourceName)
    if not resourceName then return nil end
    
    return resourceName
end)
