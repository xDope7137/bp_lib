Dispatch = function(data)
    TriggerEvent('wf-alerts:svNotify',{
        caller = 'Alarm',
        coords = data.pos.xyz,
        dispatchData = {
            displayCode = data.dispatch_code,
            description = data.message,
            isImportant = 0,
            recipientList = data.police_jobs,
            length = data.time * 1000,
            infoM = 'fa-info-circle',
            info = data.message,
        },
    })
end 

return Dispatch