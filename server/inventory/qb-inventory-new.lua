Inventory = {
    AddItem = function(source, item, amount, metadata)
        local Player = QBCore.Functions.GetPlayer(source)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add', amount)
        return Player.Functions.AddItem(item, amount, nil, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        local Player = QBCore.Functions.GetPlayer(source)
        local slot = nil
        if metadata then
            local items = Player.Functions.GetItemsByName(item)
            for k, v in pairs(items) do
                if Utils.CompareTables(v.info, metadata) then slot = v.slot end
            end
            -- nothing matches: take nothing (qb-inventory would take the first slot of that name)
            if not slot then return false end
        end
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove', amount)
        return Player.Functions.RemoveItem(item, amount, slot)
    end,
    CanCarryItem = function(source, item, amount)
        return exports[Config.InventoryResource]:CanAddItem(source, item, amount)
    end,
    GetItem = function(source, item, metadata)
        local Player = QBCore.Functions.GetPlayer(source)
        if not metadata then
            local item = Player.Functions.GetItemByName(item)
            if not item then return nil end
            return {
                item = item.name,
                count = item.amount,
                metadata = item.info,
            }
        else
            local items = Player.Functions.GetItemsByName(item)
            for k, v in pairs(items) do
                if Utils.CompareTables(v.info, metadata) then
                    return {
                        item = v.name,
                        count = v.amount,
                        metadata = v.info
                    }
                end
            end
        end

        return nil
    end,
    GetItems = function(source)
        local QPlayer = QBCore.Functions.GetPlayer(source)
        if not QPlayer then return {} end
        local items = QPlayer.PlayerData.items
        if not items then return {} end

        local formattedItems = {}
        for k, v in pairs(items) do
            formattedItems[#formattedItems + 1] = {
                item = v.name,
                count = v.amount,
                metadata = v.info,
            }
        end
        return formattedItems
    end,
    HasPlayerItem = function(source, itemName, count)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        local item = Player.Functions.GetItemByName(itemName)
        if not item then return false end
        if not count and item then return true end
        return count <= item.amount
    end,
    RegisterUsableItem = function(item, callback)
        QBCore.Functions.CreateUseableItem(item, callback)
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

RegisterNetEvent("bp_lib:qb-inventory-new:openStash", function(stashName, data)
    exports[Config.InventoryResource]:OpenInventory(source, stashName, data)
end)

return Inventory
