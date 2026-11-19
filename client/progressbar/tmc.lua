local TMC = exports.core:getCoreObject()

ProgressBar = function(label, time, options)
    local anim = false
    local animProps = {}
    
    if options.animation then
        if options.animation.animDict and options.animation.anim then
            animProps = {
                animDict = options.animation.animDict,
                anim = options.animation.anim,
                flags = options.animation.flags or 0
            }
        end
    end

    local tmcOptions = {
        canCancel = options.canCancel,
        disableMovement = options.disableMovement,
        disableCarMovement = options.disableCarMovement,
        disableMouse = options.disableMouse,
        disableCombat = options.disableCombat,
        useWhileDead = options.useWhileDead
    }

    local promise = promise.new()
    
    TMC.Functions.ProgressBar(function(complete)
        if complete then
            promise:resolve(true)
        else
            promise:resolve(false)
        end
    end, time, label, animProps, tmcOptions)

    return Citizen.Await(promise)
end

return ProgressBar