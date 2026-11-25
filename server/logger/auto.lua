--[[
    The logger of Config.Logger = 'auto' on a server that filled in a Discord webhook (0.14.0).
    A log type with a real webhook in shared/discordLogs.lua (its own line, or `others`) goes to
    Discord; every other type goes to ox_lib's logger when ox_lib runs, else nowhere.
    server/main.lua picks this file; it is not a value for Config.Logger.
]]

local function realWebhook(url)
    return type(url) == 'string' and url:find('^https?://%S+') ~= nil
end

local discord = LoadModule('logger', 'discord')
local ox = GetResourceState('ox_lib') == 'started' and lib and lib.logger and LoadModule('logger', 'ox_lib') or nil

Logger = {
    GetPlayerData = discord.GetPlayerData,
    GetPlayerIdentifier = discord.GetPlayerIdentifier,

    Send = function(type, title, description, playerId, targetId, important)
        local hooks = _G.Logs or {}
        if realWebhook(hooks[type]) or (not hooks[type] and realWebhook(hooks.others)) then
            return discord.Send(type, title, description, playerId, targetId, important)
        end
        if ox then return ox.Send(type, title, description, playerId, targetId, important) end
    end
}

return Logger
