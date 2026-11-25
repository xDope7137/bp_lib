Dispatch = function(data)
    for _, job in pairs(data.police_jobs) do
        exports[Config.DispatchResource]:addCall(data.dispatch_code, data.message, {}, data.pos.xyz, job, data.time * 1000, data.sprite, data.color)
    end
end

return Dispatch