Inventory = {
    GetItemLabel = function(item)
        local items = exports[Config.InventoryResource]:GetItemList()
        for k,v in pairs(items) do 
            if k == item then return v.label end
        end
        return "NO_LABEL"
    end,
    AddCarriableItem = CarryItems.AddCarriableItem,
    RemoveCarriableItem = CarryItems.RemoveCarriableItem,
    OpenStash = function(stashName, maxWeight, slots)
        TriggerServerEvent("inventory:server:OpenInventory", "stash", stashName, {
            maxweight = maxWeight,
            slots = slots
        })
        
        TriggerEvent("inventory:client:SetCurrentStash", stashName)
    end
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
        if not item or not totalAmount then return end

        if totalAmount > 0 then
            CarryItems.ItemAdded(item)
        else
            CarryItems.ItemRemoved(item)
        end
    
        CarryItems.UpdateAnimation()
    end)
    
    RegisterNetEvent('qb-inventory:client:itemRemoved', function(source, item, amount, totalAmount)
        if not item or not totalAmount then return end
        
        if totalAmount > 0 then
            CarryItems.ItemAdded(item)
        else
            CarryItems.ItemRemoved(item)
        end
    
        CarryItems.UpdateAnimation()
    end)
end

return Inventory