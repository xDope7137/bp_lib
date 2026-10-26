TMC = exports[Config.FrameworkResource]:getCoreObject()

-- Debug utility function
local function Debug(message)
    -- print('^3[DEBUG:PeurenLib:TMC] ^7' .. tostring(message))
end

Debug('Initializing TMC framework wrapper')

if TMC then
    Debug('TMC framework loaded successfully')
else
    Debug('ERROR: Failed to load TMC framework')
end

Framework = {
    PlayerLoaded = TMC.Functions.GetPlayerData() ~= nil,
    Callbacks = {
        Trigger = function(name, ...)
            Debug('Triggering synchronous server callback: ' .. name)
            local startTime = GetGameTimer()
            
            local p = promise.new()
            local args = {...}
            Debug('Callback args: ' .. json.encode(args))
            
            TMC.Functions.TriggerServerCallback(name, function(...)
                local duration = GetGameTimer() - startTime
                Debug('Callback "' .. name .. '" resolved after ' .. duration .. 'ms')
                p:resolve({...})
            end, ...)
            
            local result = Citizen.Await(p)
            local totalDuration = GetGameTimer() - startTime
            Debug('Total callback "' .. name .. '" execution time: ' .. totalDuration .. 'ms')
            return table.unpack(result)
        end,
        
        TriggerAsync = function(name, cb, ...)
            Debug('Triggering asynchronous server callback: ' .. name)
            local startTime = GetGameTimer()
            local args = {...}
            Debug('Callback args: ' .. json.encode(args))
            
            TMC.Functions.TriggerServerCallback(name, function(...)
                local duration = GetGameTimer() - startTime
                Debug('Async callback "' .. name .. '" resolved after ' .. duration .. 'ms')
                cb(...)
            end, ...)
        end
    },
    Job = {
        Get = function()
            local PlayerData = TMC.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.name
        end,
        GetLabel = function()
            local PlayerData = TMC.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.label
        end,
        GetGrade = function()
            local PlayerData = TMC.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.grade.level
        end,
        GetGradeLabel = function()
            local PlayerData = TMC.Functions.GetPlayerData()
            if not PlayerData then return end
            return PlayerData.job.grade.name
        end
    },

    SpawnVehicle = function(model, pos, cb, networked)
        Debug('Spawning vehicle: ' .. model)
        Debug('Position: ' .. json.encode(pos))
        Debug('Networked: ' .. tostring(networked))
        
        TMC.Functions.SpawnVehicle(model, function(vehicle)
            Debug('Vehicle spawned with ID: ' .. tostring(vehicle))
            if cb then cb(vehicle) end
        end, pos, networked)
    end, 

    GetIdentifier = function()
        return TMC.Functions.GetPlayerData().citizenid
    end
}

Debug('Player loaded state: ' .. tostring(Framework.PlayerLoaded))

AddEventHandler('TMC:Client:OnPlayerLoaded', function()
    Debug('Player loaded event received')
    TriggerEvent('peuren_lib:PlayerLoaded')
    TriggerEvent('bp_lib:PlayerLoaded')
    Framework.PlayerLoaded = true
    Debug('Framework.PlayerLoaded set to true')
end)

AddEventHandler('TMC:Client:OnPlayerUnload', function()
    Debug('Player unloaded event received')
    Framework.PlayerLoaded = false
    Debug('Framework.PlayerLoaded set to false')
end)

RegisterNetEvent('TMC:Client:OnJobUpdate', function(newJob)
    Debug('Player job updated event received')
    TriggerEvent('peuren_lib:PlayerJobUpdated', newJob)
end)

Debug('TMC framework wrapper initialized')

return Framework