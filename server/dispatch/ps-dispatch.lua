Dispatch = function(data)
    TriggerEvent('ps-dispatch:server:notify', {
        coords = data.pos.xyz,
        message = data.message,
        code = data.dispatch_code,        
        alertTime = data.time,
        alert = {
            displayCode = data.dispatch_code,
            description = data.message,
            sprite = data.sprite,
            color = data.color,
            scale = data.scale,
            length = data.time / 60,
            flash = true
        },
        jobs = data.police_jobs
    })
end 

return Dispatch