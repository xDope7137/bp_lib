Inventory = {
    AddItem = function(source, item, amount, metadata) 
        local canCarry = exports[Config.InventoryResource]:canCarryItem(source, item, amount)
        if not canCarry then return false end
        return exports[Config.InventoryResource]:addItem(source, item, amount, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        return exports[Config.InventoryResource]:removeItem(source, item, amount, metadata)
    end,
    CanCarryItem = function(source, item, amount)
        return exports[Config.InventoryResource]:canCarryItem(source, item, amount)
    end,
    GetItem = function(source, item, metadata)
        local items = exports[Config.InventoryResource]:getInventory(source)?.items
        if not items then return false end

        for k, v in pairs(items) do
            if item == v.name then
                return {
                    item = v.name,
                    count = v.amount,
                    metadata = v.metadata,
                }
            end
        end
        return false
    end,
    GetItems = function(source)
        local items = exports[Config.InventoryResource]:getInventory(source)?.items
        if not items then return {} end

        local formattedItems = {}
        for k, v in pairs(items) do
            formattedItems[#formattedItems + 1] = {
                item = v.name,
                count = v.amount,
                metadata = v.metadata,
            }
        end
        return formattedItems
    end,
    HasPlayerItem = function(source, item, count)
        return exports[Config.InventoryResource]:hasItem(source, item, count)
    end,
    RegisterUsableItem = function(item, callback)
        exports[Config.InventoryResource]:registerUsableItem(item, callback)
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

return Inventory