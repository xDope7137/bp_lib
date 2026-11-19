-- Ids come from a counter and are freed on remove: random ids from 100-999 were never freed,
-- so after enough zones (garage restarts, Setup saves) every id was taken and Add* recursed forever.
local zoneSeq = 0
local function NextZoneId()
    zoneSeq = zoneSeq + 1
    return "bp_lib:" .. zoneSeq
end

Poly = {
    Data = {},
    ResourceZones = {},

    AddBoxZone = function(pos, height, width, heading, cb, debugOverride)
        local invokingResource = GetInvokingResource() or GetCurrentResourceName()
        local id = NextZoneId()

        if Poly.Data[id] then return Poly.AddBoxZone(pos, height, width, heading, cb, debugOverride) end

        local zoneDebug = debugOverride == true or Config.Debug == true
        
        Poly.Data[id] = BoxZone:Create(pos, height, width, {
            name = id,
            heading = heading,
            debugPoly = zoneDebug,
            minZ = pos.z - height,
            maxZ = pos.z + height
        })

        Poly.Data[id]:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
            cb(isPointInside, point)
        end)

        if not Poly.ResourceZones[invokingResource] then Poly.ResourceZones[invokingResource] = {} end
        Poly.ResourceZones[invokingResource][id] = id

        return id
    end, 

    AddCircularZone = function(pos, radius, cb)
        local invokingResource = GetInvokingResource() or GetCurrentResourceName()
        local id = NextZoneId()

        if Poly.Data[id] then return Poly.AddCircularZone(pos, radius, cb) end

        Poly.Data[id] = CircleZone:Create(pos, radius, {
            name = id,
            debugPoly = Config.Debug,
            useZ = true
        })

        Poly.Data[id]:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
            cb(isPointInside, point)
        end)

        if not Poly.ResourceZones[invokingResource] then Poly.ResourceZones[invokingResource] = {} end
        Poly.ResourceZones[invokingResource][id] = id

        return id
    end,

    AddPolyZone = function(points, cb)
        local invokingResource = GetInvokingResource() or GetCurrentResourceName()
        local id = NextZoneId()

        if Poly.Data[id] then return Poly.AddPolyZone(points, cb) end

        Poly.Data[id] = PolyZone:Create(points, {
            name = id,
            debugGrid = Config.Debug,
        })

        Poly.Data[id]:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
            cb(isPointInside, point)
        end)

        if not Poly.ResourceZones[invokingResource] then Poly.ResourceZones[invokingResource] = {} end
        Poly.ResourceZones[invokingResource][id] = id

        return id
    end,

    RemoveZone = function(id)
        local invokingResource = GetInvokingResource() or GetCurrentResourceName()
        if not id then return end 
        if not Poly.Data[id] then return end 
        Poly.Data[id]:destroy()
        Poly.Data[id] = nil

        if Poly.ResourceZones[invokingResource] then
            Poly.ResourceZones[invokingResource][id] = nil
        end
    end,
}

RegisterNetEvent("onResourceStop", function(resName)
    local list = Poly.ResourceZones[resName]
    if not list then return end
    for k in pairs(list) do
        if Poly.Data[k] then Poly.Data[k]:destroy() end
        Poly.Data[k] = nil
    end
    Poly.ResourceZones[resName] = nil
end)

return Poly