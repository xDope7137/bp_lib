ProgressBar = function(label, time, options)
    local p = promise:new()
    
    QBCore.Functions.Progressbar("peuron_lib", label, time, options.useWhileDead, options.canCancel, {
        disableMovement = options.disableMovement,
        disableCarMovement = options.disableCarMovement,
        disableMouse = options.disableMouse,
        disableCombat = options.disableCombat,
        }, options.animation, {}, {}, function()
            p:resolve(true)
        end, function()
            p:resolve(false)
    end)

    return Citizen.Await(p)
end

return ProgressBar