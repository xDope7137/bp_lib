Dispatch = function(data)
    for _,job in pairs(data.police_jobs) do
        exports[Config.DispatchResource]:AddDispatch({
            priority = 'high',
            code = data.dispatch_code,
            title = data.message,
            description = data.dispatch_code.." - "..data.message,
            location = {
                label = '',
                coords = vec2(data.pos.x, data.pos.y)
            },
            time = data.time,
            job = job,
            sound = true,
            blip = {
                handle = 1,
                sprite = data.sprite,
                size = data.scale,
                color = data.color,
                shortRange = false,
                label = data.dispatch_code.." - "..data.message,
            }
        })
    end
end

RegisterNetEvent('bp_lib:server:dispatch:send', function(data)
    Dispatch(data)
end)

return Dispatch