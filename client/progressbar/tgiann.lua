ProgressBar = function(label, time, options)
    local p = promise:new()

    exports[Config.ProgessBarResource]:Progress({
        name = "peuron_lib",
        duration = time,
        label = label,
        useWhileDead = options.useWhileDead,
        canCancel = options.canCancel,
        controlDisables = {
            car = options.disableCarMovement,
            move = options.disableMovement,
            combat = options.disableCombat,
            mouse = options.disableMouse,
        },
        animation = options.animation, 
        prop = {},
        propTwo = {},
    }, function(cancelled)
        if not cancelled then
            p:resolve(true)
        else
            p:resolve(false)
        end
    end)

    return Citizen.Await(p)
end

return ProgressBar