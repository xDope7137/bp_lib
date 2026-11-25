local TMC = exports.core:getCoreObject()

Weather = {
    Enable = function()
        TriggerEvent('weather:syncWeatherTime')
        TriggerEvent('weather:client:forceClientWeather', GlobalState.CurrentWeather, false)
        TriggerEvent('weather:client:forceClientTime', GlobalState.CurrentTime.hour, GlobalState.CurrentTime.minute, false)
    end,

    Disable = function()
        TriggerEvent('weather:client:forceClientWeather', 'CLEAR', true)
    end,

    ForceWeather = function(weather)
        TriggerEvent('weather:client:forceClientWeather', weather, true)
    end,

    ForceTime = function(hour, minute)
        TriggerEvent('weather:client:forceClientTime', hour, minute, true)
    end,

    SetInsideShell = function(isInside)
        TriggerEvent('weather:setInsideShell', isInside)
    end,

    CreateSnowball = function()
        TriggerEvent('weather:createSnowball')
    end,

    GetCurrentWeather = function()
        return GlobalState.CurrentWeather
    end,

    GetCurrentTime = function()
        return GlobalState.CurrentTime
    end,

    IsBlackout = function()
        return GlobalState.Blackout
    end,

    IsFrozen = function()
        return GlobalState.TimeFrozen
    end
}

return Weather