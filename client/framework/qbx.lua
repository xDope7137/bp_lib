Framework = {
    PlayerLoaded = exports.qbx_core:GetPlayerData() ~= nil and next(exports.qbx_core:GetPlayerData()) ~= nil,
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
            local PlayerData = exports.qbx_core:GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.name
        end,
        GetLabel = function()
            local PlayerData = exports.qbx_core:GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.label
        end,
        GetGrade = function()
            local PlayerData = exports.qbx_core:GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.grade.level
        end,
        GetGradeLabel = function()
            local PlayerData = exports.qbx_core:GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.grade.name
        end
    },

    SpawnVehicle = function(model, pos, cb, networked)
        local result = lib.callback.await('bp_lib:SpawnVehicle', false, model, pos)
        cb(NetToVeh(result))
    end,

    GetIdentifier = function()
        return exports.qbx_core:GetPlayerData().citizenid
    end,

    GetPlayerGender = function()
        local PlayerData = exports.qbx_core:GetPlayerData()
        if not PlayerData then return end
        if PlayerData.charinfo.gender == 1 then
            return "female"
        end
        return "male"
    end
}

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('peuren_lib:PlayerLoaded')
    TriggerEvent('bp_lib:PlayerLoaded')
    Framework.PlayerLoaded = true
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(newJob)
    TriggerEvent('peuren_lib:PlayerJobUpdated', newJob)
end)

return Framework