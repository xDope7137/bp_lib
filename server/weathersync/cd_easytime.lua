Weather = {
    Blackout = function(state)
        local data = exports[Config.WeatherSyncResource]:GetAllData()
        data.blackOut = state
        TriggerEvent('cd_easytime:ForceUpdate', data)
    end,
}

return Weather