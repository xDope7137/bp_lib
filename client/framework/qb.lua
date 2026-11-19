QBCore = exports[Config.FrameworkResource]:GetCoreObject()

Framework = {
    PlayerLoaded = QBCore.Functions.GetPlayerData() ~= nil and next(QBCore.Functions.GetPlayerData()) ~= nil,
    Callbacks = {
        Trigger = function(name, ...)
            local p = promise:new()
            QBCore.Functions.TriggerCallback(name, function(...)
                p:resolve(...)
            end, ...)
            return Citizen.Await(p)
        end,
        TriggerAsync = function(name, cb, ...)
            QBCore.Functions.TriggerCallback(name, cb, ...)
        end
    },
    Job = {
        Get = function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.name
        end,
        GetLabel = function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.label
        end,
        GetGrade = function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.grade.level
        end,
        GetGradeLabel = function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.grade.name
        end
    },

    SpawnVehicle = function(model, pos, cb, networked)
        QBCore.Functions.SpawnVehicle(model, cb, pos, networked)
    end,

    GetIdentifier = function()
        return QBCore.Functions.GetPlayerData().citizenid
    end,

    GetPlayerGender = function()
        local PlayerData = QBCore.Functions.GetPlayerData()
        if not PlayerData then return end
        if PlayerData.charinfo.gender == 1 then
            return "female"
        end
        return "male"
    end
}

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Framework.PlayerLoaded = true
    TriggerEvent('bp_lib:PlayerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(newJob)
    TriggerEvent('bp_lib:PlayerJobUpdated', newJob)
end)

return Framework