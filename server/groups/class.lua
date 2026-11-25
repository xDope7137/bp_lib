Groups = {
    Data = {},
    
    Get = function(source, groupId, resource)
        if not source then return end

        resource = resource or GetInvokingResource()
        if not resource then return end

        local id = Framework.GetIdentifier(source)
        if not id then return end

        if not Groups.Data[resource] then
            Groups.Data[resource] = {}
        end

        if Groups.Data[resource][id] then
            return Groups.Data[resource][id]
        end

        for _, data in pairs(Groups.Data[resource]) do
            if data.groupId == groupId then return data end
        end

        return nil
    end,

    Update = function(source, groupId, data)
        if not source or not groupId then return end 

        local result = Groups.Get(source, groupId)
        if not result then return end

        local resource = GetInvokingResource()
        if not resource then return end

        Groups.Data[resource][result.owner] = data
        Groups.SendEvent(source, groupId, resource..':group:Updated', data)

        return data
    end,

    GetMember = function(source, groupId)
        if not source or not groupId then return end

        local data = Groups.Get(source, groupId)
        if not data then return end

        return data.players[tostring(source)]
    end,

    GetJobGroups = function()
        local resource = GetInvokingResource()
        if not resource then return end

        local result = {}

        if not Groups.Data[resource] then
            return result
        end

        for k,v in pairs(Groups.Data[resource]) do 
            if not v.started and not v.args?.started then 
                result[k] = v
            end
        end

        return result
    end,

    Set = function(source, args, maxPlayers)
        if not source then return end

        local resource = GetInvokingResource()
        if not resource then return end

        local data = Groups.Get(source)
        if data then return end

        local id = Framework.GetIdentifier(source)
        if not id then return end

        local password = Groups.CreatePassword()
        local groupId = Groups.CreateGroupId()
        local pName = Framework.GetCharName(source)

        args.groupId = groupId
        args.started = false

        Groups.Data[resource][id] = {
            resource = resource,
            groupId = groupId,
            pass = password,
            maxPlayers = maxPlayers or Config.Groups.MemberLimit,
            owner = id,
            args = args,
            started = false,
            pCount = 1,
            players = {
                [tostring(source)] = {
                    source = source,
                    id = id,
                    name = pName,
                    owner = true,
                    progress = 0
                }
            }
        }

        return Groups.Data[resource][id]
    end,

    Remove = function(source, groupId)
        if not source or not groupId then return end 

        local data = Groups.Get(source, groupId)
        if not data then return end

        local resource = GetInvokingResource()
        if not resource then return end
        
        Groups.SendEvent(source, groupId, resource..':group:Deleted')

        Groups.Data[resource][data.owner] = nil
        return true
    end,

    AddMember = function(source, groupId, password)
        if not source or not groupId then return end

        local data = Groups.Get(source, groupId)
        if not data then return end

        if password and tostring(password) ~= tostring(data.pass) then
            return 'wrong_pass'
        end

        local id = Framework.GetIdentifier(source)
        if not id then return end

        local resource = GetInvokingResource()
        if not resource then return end

        local pName = Framework.GetCharName(source)

        if data.pCount >= data.maxPlayers then
            return 'full'
        end

        if Groups.Data[resource][data.owner].players[tostring(source)] then 
            return
        end

        Groups.Data[resource][data.owner].pCount += 1
        Groups.Data[resource][data.owner].players[tostring(source)] = {
            source = source,
            id = id,
            name = pName
        }

        local resource = GetInvokingResource()
        if not resource then return end

        TriggerClientEvent(resource..':group:MemberAdded', source, Groups.Data[resource][data.owner], data.owner == id)
        Groups.SendEvent(source, groupId, resource..':group:Updated', data)

        return data
    end,

    RemoveMember = function(source, groupId)
        if not source or not groupId then return end

        local id = Framework.GetIdentifier(source)
        if not id then return end

        local data = Groups.Get(source, groupId)
        if not data then return end

        local resource = GetInvokingResource()
        if not resource then return end

        Groups.Data[resource][data.owner].pCount -= 1
        Groups.Data[resource][data.owner].players[tostring(source)] = nil
        TriggerClientEvent(resource..':group:MemberRemoved', source, {}, data.owner == id)
        Groups.SendEvent(source, groupId, resource..':group:Updated', data)

        return data
    end,

    GetLastPlayer = function(players)
        local lastPlayer = nil
        
        for key, player in pairs(players) do
            lastPlayer = player
        end
        
        return lastPlayer
    end,
    
    MemberDisconnected = function(source)
        if not source then return end

        local id = Framework.GetIdentifier(source)
        if not id then return end

        for resource, _ in pairs(Groups.Data) do
            for _, v in pairs(Groups.Data[resource]) do
                if v.players[tostring(source)] and v.players[tostring(source)].owner then
                    local timeout = os.time() + (Config.Groups.Timeout.min * 60) + Config.Groups.Timeout.sec

                    CreateThread(function()
                        while timeout > os.time() do
                            Wait(1000)
                        end

                        v.pCount -= 1
                        v.players[tostring(source)] = nil
                        Groups.Update(source, v.groupId, v)

                        local isOnline = Framework.GetIdentifierID(id)
                        if isOnline then return end

                        local newOwner = v.pCount > 0 and Groups.GetLastPlayer(v.players) or nil         
                        if not newOwner then
                            Groups.Data[resource][id] = nil
                            return
                        end

                        v.owner = newOwner.id
                        v.players[tostring(newOwner.source)].owner = true
                        
                        Groups.Data[v.resource][id] = nil
                        Groups.Data[v.resource][v.owner] = v

                        Groups.SendEvent(newOwner.source, v.groupId, v.resource..':group:Updated', v, v.resource)
                    end)
                end
            end
        end
    end,

    SendEvent = function(source, groupId, event, args, resource)
        if not source or not groupId then return end

        local data = Groups.Get(source, groupId, resource)
        if not data then return end

        for _, v in pairs(data.players) do
            TriggerClientEvent(event, v.source, args, v.owner)
            Wait(100)
        end

        return true
    end,

    SendGlobalJobEvent = function(event, args)
        for resource, _ in pairs(Groups.Data) do
            for _, v in pairs(Groups.Data[resource]) do
                for _, player in pairs(v.players) do
                    TriggerClientEvent(event, player.source, args, player.owner)
                    Wait(100)
                end
            end
        end

        return true
    end,

    IsPlayerInGroup = function(source)
        if not source then return end

        local resource = GetInvokingResource()
        if not resource then return end

        for _, group in pairs(Groups.Data) do
            for _, data in pairs(group) do
                if data.players[tostring(source)] and data.resource ~= resource then
                    TriggerClientEvent("bp_lib:notify", source, locale("group_job_title"), locale("you_are_already_working"), "error")
                    return true
                end
            end
        end

        return false
    end,

    --Generates a random 6 letter password
    CreatePassword = function()
        local id = ""

        if Config.Groups.password.type == 'char' then 
            math.randomseed(os.time())
            local characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
            for i = 1, Config.Groups.password.length do
                local index = math.random(1, #characters)
                id = id .. string.sub(characters, index, index)
            end
        else 
            math.randomseed(os.time())    

            for i = 1, Config.Groups.password.length do
                id = id .. tostring(math.random(0, 9))
            end
        end
    
        return id
    end,

    CreateGroupId = function()
        local characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        local id = ""
    
        for i = 1, 6 do
            local index = math.random(1, #characters)
            id = id .. string.sub(characters, index, index)
        end

        if Groups.Data[id] then
            return Groups.CreateGroupId()
        end
    
        return id
    end,
}

return Groups