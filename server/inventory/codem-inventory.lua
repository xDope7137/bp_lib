Inventory = {
    AddItem = function(source, item, amount, metadata) 
        return exports[Config.InventoryResource]:AddItem(source, item, amount, nil, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        return exports[Config.InventoryResource]:RemoveItem(source, item, amount)
    end,
    GetItem = function(source, item, metadata)
        local itemData = exports[Config.InventoryResource]:GetItemByName(source, item)
        if not itemData then return nil end
        return {
            item = itemData.name,
            count = itemData.amount,
            metadata = itemData.info,
        }
    end,
    GetItems = function(source)
        local id = Framework.GetIdentifier(source)
        local items = exports[Config.InventoryResource]:GetInventory(id, source)
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
        local result = exports[Config.InventoryResource]:HasItem(source, item, count)
        if not result then return false end
        if not count and result then return true end
        return result
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