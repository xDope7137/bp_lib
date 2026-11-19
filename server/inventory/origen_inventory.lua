Inventory = {
    AddItem = function(source, item, amount, metadata) 
        return exports.origen_inventory:addItem(source, item, amount, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        return exports.origen_inventory:removeItem(source, item, amount, metadata)
    end,
    CanCarryItem = function(source, item, amount)
        return exports.origen_inventory:canCarryItem(source, item, amount)
    end,
    GetItem = function(source, item, metadata)
        local itemData = exports.origen_inventory:getItem(source, item, metadata)
        if not itemData then return nil end
        return {
            item = itemData.name,
            count = itemData.amount,
            metadata = itemData.metadata,
        }
    end,
    GetItems = function(source)
        local data = exports.origen_inventory:getItems(source)
        if not data then return {} end

        local formattedItems = {}
        for k, v in pairs(data.inventory) do
            if v.name then
                formattedItems[#formattedItems+1] = {
                    item = v.name,
                    count = v.amount,
                    metadata = v.metadata,
                }
            end
        end
        return formattedItems
    end,
    HasPlayerItem = function(source, item, count)
        local item = Inventory.GetItem(source, item)
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
    exports.origen_inventory:registerStash(data.stashName, {
        label = data.stashName,
        slots = data.slots,
        weight = data.weight
    })
    cb(true)
end)

return Inventory