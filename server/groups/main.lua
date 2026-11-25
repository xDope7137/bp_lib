AddEventHandler('onResourceStop', function(resource)
    if Groups.Data[resource] then
        Groups.Data[resource] = nil
    end
end)

AddEventHandler('playerDropped', function()
    Groups.MemberDisconnected(source)
end)