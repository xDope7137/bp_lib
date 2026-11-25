Inventory = {
    GetItemLabel = function(item)
        if not ItemLabels[item] then return "NO_LABEL" end
        return ItemLabels[item]
    end,
    AddCarriableItem = CarryItems.AddCarriableItem,
    RemoveCarriableItem = CarryItems.RemoveCarriableItem
}

if Config.Framework == 'esx' then
    RegisterNetEvent('esx:addInventoryItem', function(itemName, totalCount) 
        if totalCount > 0 then
            CarryItems.ItemAdded(itemName)
        else
            CarryItems.ItemRemoved(itemName)
        end

        CarryItems.UpdateAnimation()
    end)

    RegisterNetEvent('esx:removeInventoryItem', function(itemName, totalCount) 
        if totalCount > 0 then
            CarryItems.ItemAdded(itemName)
        else
            CarryItems.ItemRemoved(itemName)
        end

        CarryItems.UpdateAnimation()
    end)
else
    RegisterNetEvent('qb-inventory:client:itemAdded', function(source, item, amount, totalAmount)
        if totalAmount > 0 then
            CarryItems.ItemAdded(item)
        else
            CarryItems.ItemRemoved(item)
        end
    
        CarryItems.UpdateAnimation()
    end)
    
    RegisterNetEvent('qb-inventory:client:itemRemoved', function(source, item, amount, totalAmount)
        if totalAmount > 0 then
            CarryItems.ItemAdded(item)
        else
            CarryItems.ItemRemoved(item)
        end
    
        CarryItems.UpdateAnimation()
    end)
end

return Inventory