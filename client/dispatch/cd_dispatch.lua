Dispatch = function(data)
    TriggerServerEvent('cd_dispatch:AddNotification',{
        job_table = data.police_jobs, 
        coords = data.pos.xyz,
        title = data.dispatch_code.." - "..data.message,
        message = data.message,
        flash = 1,
        unique_id = tostring(math.random(0000000,9999999)),
        blip = {
            sprite = data.sprite, 
            scale = data.scale, 
            colour = data.color,
            flashes = true,
            text = data.dispatch_code.." - "..data.message,
            time = data.time * 1000,
            sound = 1,
        }
    })
end 

return Dispatch