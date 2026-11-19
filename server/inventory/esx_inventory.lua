Inventory = {
    AddItem = function(source, item, amount, metadata)
        if metadata then 
            warn("You're using an inventory that does not support metadata. Some things might not work ar even break! Please refer to the documentation for supported resources.")
        end
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer.canCarryItem(item, amount) then return false end
        xPlayer.addInventoryItem(item, amount)
        return true
    end,
    RemoveItem = function(source, item, amount, metadata)
        if metadata then 
            warn("You're using an inventory that does not support metadata. Some things might not work ar even break! Please refer to the documentation for supported resources.")
        end
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer.getInventoryItem(item).count < amount then return false end
        xPlayer.removeInventoryItem(item, amount)
        return true
    end,
    CanCarryItem = function(source, item, amount)
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer.canCarryItem(item, amount)
    end,
    GetItem = function(source, item)
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer.getInventoryItem(item)
    end,
    GetItem = function(source, item, metadata)
        if metadata then 
            warn("You're using an inventory that does not support metadata. Some things might not work ar even break! Please refer to the documentation for supported resources.")
        end
        local xPlayer = ESX.GetPlayerFromId(source)
        local itemData = xPlayer.getInventoryItem(item)
        if not itemData then return nil end
        return {
            item = itemData.name,
            count = itemData.count,
            metadata = nil,
        }
    end,
    GetItems = function(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        local items = xPlayer.getInventory(true)
        if not items then return {} end

        local formattedItems = {}
        for k, v in pairs(items) do
            formattedItems[#formattedItems+1] = {
                item = v.name,
                count = v.count,
                metadata = v.metadata,
            }
        end
        return formattedItems
    end,
    HasPlayerItem = function(source, item, count)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        local item = xPlayer.getInventoryItem(item)
        if not item then return false end
        if not count and item then return true end
        return count <= item.count
    end,
    RegisterUsableItem = function(item, callback)
        ESX.RegisterUsableItem(item, callback)
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

return Inventory