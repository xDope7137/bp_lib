Dispatch = function(data)
    TriggerServerEvent('redutzu-mdt:server:addDispatchToMDT', {
        code = data.dispatch_code,
        title = data.message,
        vehicle = {},
        duration = data.time * 1000,
        coords = {
            x = data.pos.x,
            y = data.pos.y,
            z = data.pos.z
        }
    })
end 

return Dispatch