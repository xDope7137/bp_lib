Dispatch = function(data)
    TriggerServerEvent('p_mdt/createAlert', {
        priority = 'high',
        code = data.dispatch_code,
        title = data.message,
        description = data.dispatch_code.." - "..data.message,
        coords = data.pos,
        fields = {},
        alertTime = data.time,
        blip = {
            sprite = data.sprite,
            color = data.color,
            scale = data.scale,
            shortRange = true,
            name = data.message
        }
    })
end

return Dispatch