Dispatch = function(data)
    for _, job in pairs(data.police_jobs) do
        TriggerServerEvent("SendAlert:police", {
            coords = data.pos.xyz,
            title = data.dispatch_code,
            type = 'GENERAL',
            message = data.message,
            job = job,
            metadata = {}
        })
    end
end 

return Dispatch