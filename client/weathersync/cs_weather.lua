Weather = {
    Enable = function()
        TriggerEvent('cs:weather:client:EnableSync')
    end,
    Disable = function()
        TriggerEvent("cs:weather:client:DisableSync")
    end
}

return Weather