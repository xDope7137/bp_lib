Framework = {
    PlayerLoaded = player ~= nil,
    Callbacks = {
        Trigger = function(name, ...)
            return lib.callback.await(name, false, ...)
        end,
        TriggerAsync = function(name, cb, ...)
            cb(lib.callback.await(name, false, ...))
        end
    },
    Job = {
        Get = function()
            return nil
        end,
        GetLabel = function()
            return nil
        end,
        GetGrade = function()
            return nil
        end,
        GetGradeLabel = function()
            return nil
        end
    },

    SpawnVehicle = function(model, pos, cb, networked)
        local result = lib.callback.await('bp_lib:SpawnVehicle', false, model, pos, 90)
        cb(NetToVeh(result))
    end
}

AddEventHandler('esx:onPlayerSpawn', function()
    TriggerEvent('peuren_lib:PlayerLoaded')
    TriggerEvent('bp_lib:PlayerLoaded')
    Framework.PlayerLoaded = true
end)

return Framework