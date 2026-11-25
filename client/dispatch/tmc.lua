Dispatch = function(data)
    TMC.Functions.TriggerServerEvent('dispatch:server:addCall', {
        title = data.dispatch_code.." - "..data.message,
        description = data.message,
        jobType = data.police_jobs,
        position = data.pos.xyz,
        urgency = 3,
        limits = {'Drug Activity'}
    })
end 

return Dispatch