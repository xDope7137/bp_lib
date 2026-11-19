Inventory = {
    AddItem = function(source, item, amount, metadata) 
        exports[Config.InventoryResource]:AddItem(source, item, amount, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        return exports[Config.InventoryResource]:RemoveItemBy(source, amount, { name = item })
    end,
    GetItem = function(source, item)
        local amount = exports[Config.InventoryResource]:GetItemQuantityBy(source, { name = item })        
        return {
            item = item,
            count = amount,
            metadata = nil,
        }
    end,
    GetItems = function(source)
        local items = exports[Config.InventoryResource]:GetInventoryItems(source)
        if not items then return {} end

        local formattedItems = {}
        for k, v in pairs(items) do
            formattedItems[#formattedItems+1] = {
                item = v.name,
                count = v.quantity,
                metadata = v.meta,
            }
        end
        return formattedItems
    end,
    HasPlayerItem = function(source, item, count)    
        local id = Framework.GetIdentifier(source) 
        if not id then return end
        local result = exports[Config.InventoryResource]:GetItemBy(source, { name = item, quantity = count })
        if not result then return false end
        if not count and result then return true end
        return count <= result.count
    end,
    RegisterUsableItem = function(item, callback)
        if Config.Framework == "qb" then
            QBCore.Functions.CreateUseableItem(item, callback)
        elseif Config.Framework == "esx" then
            ESX.RegisterUsableItem(item, callback)
        end
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

return Inventory