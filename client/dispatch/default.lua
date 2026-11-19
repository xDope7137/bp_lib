Dispatch = function(data)
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", false, 0, true)

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(data.message)
    EndTextCommandThefeedPostTicker(true, false)

    local alpha = 250
    local blip = AddBlipForCoord(data.pos.x, data.pos.y, data.pos.z)
    SetBlipSprite(blip, data.sprite)
    SetBlipScale(blip, data.scale)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.dispatch_code.." - "..data.message)
    SetBlipAlpha(blip, alpha)
    SetBlipColour(blip, data.color)
    PulseBlip(blip)
    while alpha ~= 0 do
        Wait(data.time * 4)
        alpha = alpha - 1
        SetBlipAlpha(blip, alpha)
        if alpha == 0 then
            SetBlipSprite(blip, 2)
            RemoveBlip(blip)
            return
        end
    end
end 

RegisterNetEvent('bp_lib:SendDispatchAlert', function(data)
    Dispatch(data)
end)

return Dispatch