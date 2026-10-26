ESX = nil

if Config.IsOldESX then 
    CreateThread(function()
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) 
                ESX = obj 
            end)
            Citizen.Wait(0)
        end
    end)
else 
    ESX = exports[Config.FrameworkResource]:getSharedObject()
end

Framework = {
    PlayerLoaded = ESX.IsPlayerLoaded(),
    Callbacks = {
        Trigger = function(name, ...)
            local p = promise:new()
            ESX.TriggerServerCallback(name, function(...)
                p:resolve(...)
            end, ...)
            return Citizen.Await(p)
        end,
        TriggerAsync = function(name, cb, ...)
            ESX.TriggerServerCallback(name, cb, ...)
        end
    },
    Job = {
        Get = function()
            return ESX.PlayerData.job?.name
        end,
        GetLabel = function()
            return ESX.PlayerData.job?.label
        end,
        GetGrade = function()
            return ESX.PlayerData.job?.grade?.level
        end,
        GetGradeLabel = function()
            return ESX.PlayerData.job?.grade?.name
        end
    },

    SpawnVehicle = function(model, pos, cb, networked)
        ESX.Game.SpawnVehicle(model, pos, heading, cb, networked)
    end,

    GetIdentifier = function()
        return ESX.GetPlayerData().identifier
    end,

    GetPlayerGender = function()
        if not ESX.PlayerData then return end
        if ESX.PlayerData.sex  == 1 then
            return "female"
        end
        return "male"
    end
}

AddEventHandler('esx:onPlayerSpawn', function()
    TriggerEvent('peuren_lib:PlayerLoaded')
    TriggerEvent('bp_lib:PlayerLoaded')
    Framework.PlayerLoaded = true
    ESX.PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded', function(playerData, isNew, skin)
    Framework.PlayerLoaded = true
end)

RegisterNetEvent('esx:setJob', function(newJob)
    TriggerEvent('peuren_lib:PlayerJobUpdated', newJob)
    ESX.PlayerData = ESX.GetPlayerData()
end)

return Framework