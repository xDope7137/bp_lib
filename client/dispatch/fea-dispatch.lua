Dispatch = function(data)
    TriggerServerEvent('fae-dispatch:alert', data.dispatch_code.." - "..data.message, data.message, data.pos.xyz, exports[Config.DispatchResource]:CoordToString(data.pos.xyz))
end 

RegisterNetEvent('fea-dispatch:bp_lib:alert', function(data)
    Dispatch(data)
end)

return Dispatch