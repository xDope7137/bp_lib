Dispatch = function(data)
    for _, job in pairs(data.police_jobs) do
        exports[Config.DispatchResource]:addCall(
            data.dispatch_code,
            data.message,
            {},
            { data.pos.x, data.pos.y, data.pos.z },
            job,
            data.time * 1000,
            data.sprite,
            data.color,
            true
        )
    end
end 

return Dispatch