Dispatch = function(data)
    for _, job in pairs(data.police_jobs) do 
        local text = data.message
        local coords = data.pos.xyz
        local title = data.dispatch_code
        local panic = true

        TriggerEvent('Opto_dispatch:Server:SendAlert', job, title, text, coords, panic)
    end
end 

return Dispatch