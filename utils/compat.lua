local function resolvePlayerRef(framework, player)
    if type(player) == 'string' then
        if framework.GetIdentifierID then
            local src = framework.GetIdentifierID(player)
            if not src or src == false then return nil end
            return src
        end
        return nil
    end
    return player
end

function ApplyServerCompat(core)
    if core.Framework then
        if core.Framework.GetIdentifierID and not core.Framework.GetPlayerByCitizenId then
            core.Framework.GetPlayerByCitizenId = function(identifier)
                local src = core.Framework.GetIdentifierID(identifier)
                if not src then return nil end
                return { source = src }
            end
        end

        if core.Framework.Money then
            local money = core.Framework.Money
            core.Framework.Money = {
                Give = function(player, amount, account, ...)
                    local src = resolvePlayerRef(core.Framework, player)
                    if not src then return end
                    return money.Give(src, amount, account, ...)
                end,
                Get = function(player, account, ...)
                    local src = resolvePlayerRef(core.Framework, player)
                    if not src then return 0 end
                    return money.Get(src, account, ...)
                end,
                Remove = function(player, amount, account, ...)
                    local src = resolvePlayerRef(core.Framework, player)
                    if not src then return end
                    return money.Remove(src, amount, account, ...)
                end,
            }
        end
    end

    core.Player = {
        GetPlayer = function(source)
            if not source then return nil end
            local isAdmin = core.Framework and core.Framework.HasGroup
                and (core.Framework.HasGroup(source, 'admin')
                    or core.Framework.HasGroup(source, 'god')
                    or core.Framework.HasGroup(source, 'superadmin'))
            return { Permission = isAdmin and 'admin' or 'user', source = source }
        end,
        RemoveItem = function(source, item, count)
            if not core.Inventory or not core.Inventory.RemoveItem then return false end
            return core.Inventory.RemoveItem(source, item, count or 1)
        end,
    }
end

function ApplyClientCompat(core)
    core.Math = core.Math or (function()
        local chunk = LoadResourceFile(GetCurrentResourceName(), 'client/math/math.lua')
        if not chunk then return nil end
        local fn, err = load(chunk, '@@bp_lib/client/math/math.lua')
        if not fn then
            print(('^1[bp_lib]^0 Failed to load Math module: %s'):format(err))
            return nil
        end
        return fn()
    end)()

    if core.Framework then
        if core.Framework.Job and core.Framework.Job.Get and not core.Framework.GetPlayerJob then
            core.Framework.GetPlayerJob = core.Framework.Job.Get
        end

        if core.VehicleProperties then
            if not core.Framework.GetVehicleProperties and core.VehicleProperties.Get then
                core.Framework.GetVehicleProperties = core.VehicleProperties.Get
            end
            if not core.Framework.SetVehicleProperties and core.VehicleProperties.Set then
                core.Framework.SetVehicleProperties = core.VehicleProperties.Set
            end
        end
    end

    if core.Target then
        if core.Target.AddEntity and not core.Target.AddLocalEntity then
            core.Target.AddLocalEntity = core.Target.AddEntity
        end
        if core.Target.RemoveEntityZone and not core.Target.RemoveEntity then
            core.Target.RemoveEntity = core.Target.RemoveEntityZone
        end
        if core.Target.AddVehicle and not core.Target.AddGlobalVehicle then
            core.Target.AddGlobalVehicle = core.Target.AddVehicle
        end
    end
end
