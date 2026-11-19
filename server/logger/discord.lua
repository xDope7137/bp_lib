Logger = {
    GetPlayerData = function(playerId, isTarget)
        if not playerId then return "" end

        local hwdi = GetPlayerToken(playerId, 0) or "Not found"

        local data = isTarget and '\n\n**TARGET**\n' or '\n\n**SOURCE**\n'
        data = data..'Nickname: **'..(playerId > 0 and GetPlayerName(playerId) or 'Not known')..'**\n'
        data = data..'Player ID: **'..playerId..'**\n\n'
        data = data..'Steam ID: **'..Logger.GetPlayerIdentifier(playerId, 'steam')..'**\n'
        data = data..'License: **'..Logger.GetPlayerIdentifier(playerId, 'license')..'**\n'
        data = data..'Discord: **'..Logger.GetPlayerIdentifier(playerId, 'discord')..'**\n'
        data = data..'HWID: **'..hwdi..'**\n'
        
        return data
    end,

    GetPlayerIdentifier = function(playerId, identifier)
        local playerIdentifiers = GetPlayerIdentifiers(playerId)
        
        for _, playerIdentifier in pairs(playerIdentifiers) do
            if playerIdentifier:find(identifier..':') then
                return string.gsub(playerIdentifier, identifier..':', '')
            end
        end

        return '?'
    end,

    Send = function(type, title, description, playerId, targetId, important)
        if playerId and playerId > 0 then
            description = description..Logger.GetPlayerData(playerId, false)
        end
    
        if targetId then
            description = description..Logger.GetPlayerData(targetId, true)
        end
    
        description = {{
            ['color'] = '36095',
            ['title'] = '**'..title..'**',
            ['description'] = description,
            ['footer'] = {
                ['text'] = os.date('%x %X'),
                ['icon_url'] = Logs.CommunityLogo,
            }
        }}
    
        if Logs[type] then
            PerformHttpRequest(Logs[type], function(err, text, headers) end, 'POST', json.encode({username = 'BP Development', embeds = description}), { ['Content-Type'] = 'application/json' })
            
            if important then
                PerformHttpRequest(Logs[type], function(err, text, headers) end, 'POST', json.encode({username = 'BP Development', content = '@here'}), { ['Content-Type'] = 'application/json' })
            end
        elseif Logs['others'] then
            PerformHttpRequest(Logs['others'], function(err, text, headers) end, 'POST', json.encode({username = 'BP Development', embeds = description}), { ['Content-Type'] = 'application/json' })
            
            if important then
                PerformHttpRequest(Logs['others'], function(err, text, headers) end, 'POST', json.encode({username = 'BP Development', content = '@here'}), { ['Content-Type'] = 'application/json' })
            end
        end
    end
}

return Logger