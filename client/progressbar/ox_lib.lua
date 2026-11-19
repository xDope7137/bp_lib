ProgressBar = function(label, time, options)
    local anim = false
    
    if options.animation then
        anim = {
            clip = options.animation.anim,
            dict = options.animation.animDict,
            flag = options.animation.flags
        }
    end

    return lib.progressBar({
        duration = time,
        label = label,
        useWhileDead = options.useWhileDead,
        canCancel = options.canCancel,
        disable = {
            car = options.disableCarMovement,
            move = options.disableMovement,
            mouse = options.disableMouse,
            combat = options.disableCombat,
        },
        anim = anim
    }) 
end

return ProgressBar