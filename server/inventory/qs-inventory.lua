Inventory = {
    AddItem = function(source, item, amount, metadata) 
        return exports[Config.InventoryResource]:AddItem(source, item, amount, nil, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        return exports[Config.InventoryResource]:RemoveItem(source, item, amount, nil, metadata)
    end,
    CanCarryItem = function(source, item, amount)
        return exports[Config.InventoryResource]:CanCarryItem(source, item, amount)
    end,
    GetItem = function(source, item)
        local amount = exports[Config.InventoryResource]:GetItemTotalAmount(source, item)
        return {
            item = item,
            count = amount,
            metadata = nil,
        }
    end,
    GetItems = function(source)
        local items = exports[Config.InventoryResource]:GetInventory(source)
        if not items then return {} end

        local formattedItems = {}
        for k, v in pairs(items) do
            formattedItems[#formattedItems+1] = {
                item = v.name,
                count = v.amount,
                metadata = v.info,
            }
        end
        return formattedItems
    end,
    HasPlayerItem = function(source, item, count)     
        local amount = exports[Config.InventoryResource]:GetItemTotalAmount(source, item)
        if not amount then return false end
        if not count and amount then return true end
        return count <= amount
    end,
    RegisterUsableItem = function(item, callback)
        exports[Config.InventoryResource]:CreateUsableItem(item, callback)
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

Core.Framework.RegisterCallback("bp_lib:inventory:RegisterStash", function(player, cb, data)
    exports[Config.InventoryResource]:RegisterStash(player, data.stashName, data.slots, data.weight) 
    cb(true)
end)

return Inventory