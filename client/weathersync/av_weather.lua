Weather = {
    Enable = function()
        TriggerEvent('av_weather:freeze', false)
    end,
    Disable = function()
        local state = true
        local hours = 23
        local minutes = 0
        local weather = "CLEAR"
        local blackout = false
        local fog = false
        local snow = false -- render snow on ground
        -- Fog options: "automatic", "no", "normal", "low", "medium", "high", "max" or false
        TriggerEvent('av_weather:freeze', state, hours, minutes, weather, blackout, fog, snow)
    end
}

return Weather