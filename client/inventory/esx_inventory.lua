Inventory = {
    GetItemLabel = function(item)
        if not ItemLabels[item] then return "NO_LABEL" end
        return ItemLabels[item]
    end,
    AddCarriableItem = CarryItems.AddCarriableItem,
    RemoveCarriableItem = CarryItems.RemoveCarriableItem
}

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

return Inventory