Weather = {
    Enable = function()
        local playerState = LocalPlayer.state
        playerState.syncWeather = true
    end,
    Disable = function()
        local playerState = LocalPlayer.state
        playerState.syncWeather = false
    end
}

return Weather