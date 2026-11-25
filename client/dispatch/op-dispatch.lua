Dispatch = function(data)
    for _, job in pairs(data.police_jobs) do 
        local text = data.message
        local coords = data.pos.xyz
        local id = GetPlayerServerId(PlayerId())
        local title = data.dispatch_code
        local panic = true

        TriggerServerEvent('Opto_dispatch:Server:SendAlert', job, title, text, coords, panic, id)
    end
end 

return Dispatch