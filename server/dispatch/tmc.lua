Dispatch = function(data)
    TMC.Functions.TriggerEvent('dispatch:server:addCall', {
        title = data.dispatch_code.." - "..data.message,
        description = data.message,
        jobType = data.police_jobs,
        position = data.pos.xyz,
        urgency = 3,
    })
end 

return Dispatch