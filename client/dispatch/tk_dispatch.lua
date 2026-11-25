Dispatch = function(data)
    exports[Config.DispatchResource]:addCall({
        coords = data.pos.xyz,
        title = data.message,
        code = data.dispatch_code,
        showTime = data.time,
        blip = {
            sprite = data.sprite,
            color = data.color,
            scale = data.scale,
            shortRange = true,
            flash = true
        },
        jobs = data.police_jobs
    })
end 

return Dispatch