Weather = {
    Enable = function()
        TriggerEvent('cd_easytime:PauseSync', false)
    end,
    Disable = function()
        TriggerEvent('cd_easytime:PauseSync', true)
    end
}

return Weather