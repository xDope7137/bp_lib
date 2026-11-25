Dispatch = function(data)
    TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
        job = data.police_jobs,
        callLocation = data.pos.xyz,
        callCode = { code = data.dispatch_code, snippet = data.message },
        message = data.message,
        flashes = true, -- you can set to true if you need call flashing sirens...
        blip = {
            sprite = data.sprite, --blip sprite
            scale = data.scale, -- blip scale
            colour = data.color, -- blio colour
            flashes = true, -- blip flashes
            text = data.dispatch_code.." - "..data.message, -- blip text
            time = data.time, --blip fadeout time (1 * 60000) = 1 minute
        },
        otherData = {}
    })
end 

return Dispatch