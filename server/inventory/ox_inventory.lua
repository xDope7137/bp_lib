Inventory = {
    AddItem = function(source, item, amount, metadata) 
        local canCarry = exports[Config.InventoryResource]:CanCarryItem(source, item, amount)
        if not canCarry then return false end
        return exports[Config.InventoryResource]:AddItem(source, item, amount, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        return exports[Config.InventoryResource]:RemoveItem(source, item, amount, metadata)
    end,
    CanCarryItem = function(source, item, amount)
        return exports[Config.InventoryResource]:CanCarryItem(source, item, amount)
    end,
    GetItem = function(source, item, metadata)
        local itemData = exports[Config.InventoryResource]:GetItem(source, item, metadata)
        if not itemData then return nil end
        return {
            item = itemData.name,
            count = itemData.count,
            metadata = itemData.metadata,
        }
    end,
    GetItems = function(source)
        local items = exports[Config.InventoryResource]:GetInventoryItems(source)
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
        local item = exports[Config.InventoryResource]:GetItem(source, item)
        if not item then return false end
        if not count and item then return true end
        return count <= item.count
    end,
    RegisterUsableItem = function(item, callback)
        if Config.Framework == "qb" then
            QBCore.Functions.CreateUseableItem(item, callback)
        elseif Config.Framework == "esx" then
            ESX.RegisterUsableItem(item, callback)
        elseif Config.Framework == "qbx" then
            exports.qbx_core:CreateUseableItem(item, callback)
        end
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

Core.Framework.RegisterCallback("bp_lib:inventory:RegisterStash", function(player, cb, data)
    exports[Config.InventoryResource]:RegisterStash(data.stashName, data.stashName, data.slots, data.weight)
    cb(true)
end)

return Inventory