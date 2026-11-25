Weather = {
    Enable = function()
        TriggerEvent('qb-weathersync:client:EnableSync')
    end,
    Disable = function()
        TriggerEvent('qb-weathersync:client:DisableSync')
    end
}

return Weather