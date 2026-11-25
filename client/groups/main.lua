
---Event that creates a blip
---@param name string
---@param data table
RegisterNetEvent("bp_lib:Groups:CreateBlip", function(name, data)
    if not data or name then return end

    if Groups.DoesBlipExist(name) then
        Groups.RemoveBlip(name)
    end

    local blip = nil
    if data.entity then
        blip = AddBlipForEntity(data.entity)
    elseif data.netId then 
        blip = AddBlipForEntity(NetworkGetEntityFromNetworkId(data.netId))
    elseif data.radius then
        blip = AddBlipForRadius(data.pos.x, data.pos.y, data.pos.z, data.radius)
    else
        blip = AddBlipForCoord(data.pos)
    end

    if data.color == nil then data.color = 1 end
    if data.alpha == nil then data.alpha = 255 end

    if not data.radius then
        if data.sprite == nil then data.sprite = 1 end
        if data.scale == nil then data.scale = 0.7 end
        if data.label == nil then data.label = "NO LABEL FOUND" end

        SetBlipSprite(blip, data.sprite)
        SetBlipScale(blip, data.scale)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(data.label)
        EndTextCommandSetBlipName(blip)
    end

    SetBlipColour(blip, data.color)
    SetBlipAlpha(blip, data.alpha)

    if data.route then 
        SetBlipRoute(blip, true)
        if not data.routeColor then data.routeColor = data.color end
        SetBlipRouteColour(blip, data.routeColor)
    end
    Groups.Blips[name] = { name = name, blip = blip }
end)

---Event that removes blip
---@param name string
RegisterNetEvent('bp_lib:Groups:RemoveBlip', function(name)
    Groups.RemoveBlip(name)
end)