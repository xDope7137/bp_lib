Dispatch = function(data)
    local type = GetInvokingResource() == 'peuren_burglary' and 'HouseRobbery' or nil
    local Data = {
        type = type or data.dispatch_code,
        header = data.dispatch_code.." - "..data.message,
        coords = data.pos.xyz,
        pos = data.pos.xyz,
        text = data.message,
        code = data.dispatch_code,
        blip = {
            sprite = data.sprite, 
            scale = data.scale, 
            colour = data.color,
            flashes = true,
            text = data.dispatch_code.." - "..data.message,
            time = data.time * 1000,
            sound = 1,
        }
    }
    exports[Config.DispatchResource]:CustomDispatch(Data)
end

RegisterNetEvent('bp_lib:sendDispatchAlert', function(Data)
    Dispatch(Data)
end)

return Dispatch