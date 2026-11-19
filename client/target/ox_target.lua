function TransformOnSelect(callback)
    return function(data)
        callback(data?.entity)
    end
end

Target = {
    Zones = {},

    AddEntity = function(entities, options, distance)
        if type(entities) == 'table' then
            for k,v in pairs(entities) do 
                if not DoesEntityExist(v) and NetworkDoesEntityExistWithNetworkId(v) then
                    entities[k] = NetworkGetEntityFromNetworkId(v)
                end
            end
        else 
            if not DoesEntityExist(entities) and NetworkDoesEntityExistWithNetworkId(entities) then 
                entities = NetworkGetEntityFromNetworkId(entities)
            end
        end

        local tOptions = {}
        for k, v in pairs(options) do
            tOptions[#tOptions + 1] = {
                name = v.name,
                icon = v.icon,
                label = v.label,
                items = v.item,
                canInteract = v.canInteract,
                onSelect = TransformOnSelect(v.onSelect),
                distance = distance,
                groups = v.jobs,
            }
        end
        return exports[Config.TargetResource]:addLocalEntity(entities, tOptions)
    end,
    AddNetworkedEntity = function(netId, options, distance)
        local tOptions = {}
        for k, v in pairs(options) do
            tOptions[#tOptions + 1] = {
                name = v.name,
                icon = v.icon,
                label = v.label,
                items = v.item,
                canInteract = v.canInteract,
                onSelect = TransformOnSelect(v.onSelect),
                distance = distance,
                groups = v.jobs,
            }
        end

        return exports.ox_target:addEntity(netId, tOptions)
    end,
    AddBone = function(bones, options, distance)
        local tOptions = {}
        for k, v in pairs(options) do
            tOptions[#tOptions + 1] = {
                name = v.name,
                icon = v.icon,
                label = v.label,
                items = v.item,
                canInteract = v.canInteract,
                onSelect = TransformOnSelect(v.onSelect),
                bones = v.bones,
                distance = distance,
                groups = v.jobs,
            }
        end
        return exports[Config.TargetResource]:addGlobalVehicle(tOptions)
    end,
    AddModel = function(models, options, distance)
        local tOptions = {}
        for k, v in pairs(options) do
            tOptions[#tOptions + 1] = {
                name = v.name,
                icon = v.icon,
                label = v.label,
                items = v.item,
                canInteract = v.canInteract,
                onSelect = TransformOnSelect(v.onSelect),
                distance = distance,
                groups = v.jobs,
            }
        end
        return exports[Config.TargetResource]:addModel(models, tOptions)
    end,
    AddBoxZone = function(boxData, options, distance)
        local tOptions = {}
        for k, v in pairs(options) do
            tOptions[#tOptions + 1] = {
                name = v.name,
                icon = v.icon,
                label = v.label,
                items = v.item,
                canInteract = v.canInteract,
                onSelect = TransformOnSelect(v.onSelect),
                distance = distance,
                groups = v.jobs,
            }
        end

        local zoneDebug = boxData.debug == true or Config.Debug == true

        local id = exports[Config.TargetResource]:addBoxZone({
            name = boxData.name,
            coords = vector3(boxData.coords.x, boxData.coords.y, boxData.coords.z + boxData.size.z / 2),
            size = vector3(boxData.size.y, boxData.size.x, boxData.size.z),
            rotation = boxData.heading,
            options = tOptions,
            debug = zoneDebug,
            resource = GetInvokingResource(),
            drawSprite = zoneDebug,
        })

        Target.Zones[id] = true
        return id
    end,
    AddPlayer = function(options, distance)
        local tOptions = {}
        for k, v in pairs(options) do
            tOptions[#tOptions + 1] = {
                name = v.name,
                icon = v.icon,
                label = v.label,
                items = v.item,
                canInteract = v.canInteract,
                onSelect = TransformOnSelect(v.onSelect),
                distance = distance,
                groups = v.jobs,
            }
        end

        return exports[Config.TargetResource]:addGlobalPlayer(tOptions)
    end,
    AddVehicle = function(options, distance)
        local tOptions = {}
        for k, v in pairs(options) do
            tOptions[#tOptions + 1] = {
                name = v.name,
                icon = v.icon,
                label = v.label,
                items = v.item,
                canInteract = v.canInteract,
                onSelect = TransformOnSelect(v.onSelect),
                distance = distance,
                groups = v.jobs,
            }
        end

        return exports[Config.TargetResource]:addGlobalVehicle(tOptions)
    end,
    RemoveZone = function(data)
        if not Target.Zones[data] then return end
        exports[Config.TargetResource]:removeZone(data)
        Target.Zones[data] = nil
    end,
    RemoveEntityZone = function(entities, names)
        if type(entities) == 'table' then
            for k,v in pairs(entities) do 
                if not DoesEntityExist(v) and NetworkDoesEntityExistWithNetworkId(v) then
                    entities[k] = NetworkGetEntityFromNetworkId(v)
                end
            end
        else 
            if not DoesEntityExist(entities) and NetworkDoesEntityExistWithNetworkId(entities) then 
                entities = NetworkGetEntityFromNetworkId(entities)
            end
        end        
        exports[Config.TargetResource]:removeLocalEntity(entities, names)
    end,
    RemoveBone = function(bones, names)
        exports[Config.TargetResource]:removeGlobalVehicle(bones)
    end,
    RemovePlayer = function(names) 
        exports[Config.TargetResource]:removeGlobalPlayer(names)
    end,
    RemoveVehicle = function(names)
        exports[Config.TargetResource]:removeGlobalVehicle(names)
    end
}

-- ox_target removes by option name among the options bp_lib registered; bp_lib sends each name as
-- '<script>:<name>', unique to the script that added it
local UNIQUE_NAMES = true
local function REMOVE_MODEL(model, names) exports[Config.TargetResource]:removeModel(model, names) end

-- (0.11.0) Model options are remembered by the resource that added them (Target.ModelOwners), so
-- that resource can take them off again with RemoveModel. All of them are registered with the
-- target resource under bp_lib's name, so the target resource cannot tell scripts apart: bp_lib does.
Target.ModelOwners = {}
do
    local add = Target.AddModel
    local function hashOf(m) return type(m) == 'string' and joaat(m) or m end
    local function listOf(models)
        local out = {}
        for _, m in ipairs(type(models) == 'table' and models or { models }) do out[#out + 1] = hashOf(m) end
        return out
    end
    -- removes the owner's records that match; -> how many came off, labels kept because another
    -- script still has them on that model
    local function removeFor(owner, models, names)
        local want, inList = nil, {}
        if names ~= nil then
            want = {}
            for _, n in ipairs(type(names) == 'table' and names or { names }) do want[n] = true end
        end
        if models then for _, h in ipairs(listOf(models)) do inList[h] = true end end
        local mine, keep = {}, {}
        for _, r in ipairs(Target.ModelOwners) do
            if r.owner == owner and (not models or inList[r.model]) and (not want or want[r.name]) then
                mine[#mine + 1] = r
            else
                keep[#keep + 1] = r
            end
        end
        Target.ModelOwners = keep
        local byModel, n, shared = {}, 0, {}
        for _, r in ipairs(mine) do
            local busy = false
            if not UNIQUE_NAMES then
                -- the target removes by label: never take a label another script still has here
                for _, o in ipairs(keep) do
                    if o.model == r.model and o.label == r.label then busy = true; break end
                end
            end
            if busy then
                shared[#shared + 1] = r.label
            else
                local e = byModel[r.model]
                if not e then e = { names = {}, labels = {} }; byModel[r.model] = e end
                e.names[#e.names + 1] = r.sent
                e.labels[#e.labels + 1] = r.label
                n = n + 1
            end
        end
        for model, e in pairs(byModel) do pcall(REMOVE_MODEL, model, e.names, e.labels) end
        return n, shared
    end
    Target.AddModel = function(models, options, distance)
        local owner = GetInvokingResource() or GetCurrentResourceName()
        local sent, recs = {}, {}
        for i, v in pairs(options) do
            local o = {}
            for k, x in pairs(v) do o[k] = x end
            local name = v.name or tostring(v.label or i)
            -- ox_target: a name of this script's own, so another script's option is never replaced or removed
            o.name = UNIQUE_NAMES and (owner .. ':' .. name) or name
            sent[i] = o
            recs[#recs + 1] = { name = name, sent = o.name, label = v.label }
        end
        local r = add(models, sent, distance)
        for _, h in ipairs(listOf(models)) do
            for _, x in ipairs(recs) do
                Target.ModelOwners[#Target.ModelOwners + 1] = { owner = owner, model = h, name = x.name, sent = x.sent, label = x.label }
            end
        end
        return r
    end
    --- RemoveModel(models, names): takes the caller's own options off these models. names: one
    --- option name, a list, or nil for every option the caller added to them.
    --- -> how many came off, and the labels left on because another script still has them there
    --- (qb-target and qtarget remove by label).
    Target.RemoveModel = function(models, names)
        return removeFor(GetInvokingResource() or GetCurrentResourceName(), models, names)
    end
    if UNIQUE_NAMES then
        -- ox_target: names are this script's own, so removing them when it stops touches nothing else
        AddEventHandler('onClientResourceStop', function(res)
            if res ~= GetCurrentResourceName() then removeFor(res, nil, nil) end
        end)
    end
end

return Target
