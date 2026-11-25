Dispatch = function(data)
    local alert = {
        code = data.dispatch_code, -- string -> The alert code, can be for example '10-64' or a little bit longer sentence like '10-64 - Shop robbery'
        default_priority = 'high', -- 'low' | 'medium' | 'high' -> The alert priority
        coords = data.pos.xyz, -- vector3 -> The coords of the alert
        job = data.police_jobs, -- string | table -> The job, for example 'police' or a table {'police', 'ambulance'}
        text = data.dispatch_code.." - "..data.message, -- string -> The alert text
        type = 'alerts', -- alerts | shop_robbery | car_robbery | bank_robbery -> The alert type to track stats
        blip_time = data.time * 1000, -- number (optional) -> The time until the blip fades
        blip = { -- Blip table (optional)
            sprite = data.sprite, -- number -> The blip sprite: Find them here (https://docs.fivem.net/docs/game-references/blips/#blips)
            colour = data.color, -- number -> The blip colour: Find them here (https://docs.fivem.net/docs/game-references/blips/#blip-colors)
            scale = data.scale, -- number -> The blip scale
            text = data.dispatch_code.." - "..data.message, -- number (optional) -> The blip text
            flashes = false, -- boolean (optional) -> Make the blip flash
            radius = 0, -- number (optional) -> Create a radius blip instead of a normal one
        }
    }
    TriggerServerEvent('rcore_dispatch:server:sendAlert', alert)
end 

return Dispatch