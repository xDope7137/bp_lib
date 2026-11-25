Inventory = {
    GetItemLabel = function(item)
        local items = exports[Config.InventoryResource]:GetItemList()
        for k,v in pairs(items) do 
            if k == item or v.name == item then return v.label end
        end
        return "NO_LABEL"
    end,
    AddCarriableItem = CarryItems.AddCarriableItem,
    RemoveCarriableItem = CarryItems.RemoveCarriableItem,
    OpenStash = function(stashName, maxWeight, slots)
        TriggerServerEvent('inventory:server:OpenInventory', 'stash', stashName,  {
            maxweight = maxWeight,
            slots = slots
        })
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
    RegisterNetEvent('QBCore:Player:SetPlayerData', function(PlayerData)
        local carriableItems = {}
        for k, v in pairs(PlayerData.items) do
            if CarryItems.Items[v.name] then
                carriableItems[v.name] = true
            end
        end
    
        for k, v in pairs(CarryItems.InInventory) do
            if not carriableItems[k] then
                CarryItems.ItemRemoved(k)
            end
        end
    
        for k, v in pairs(carriableItems) do
            if not CarryItems.InInventory[k] then
                CarryItems.ItemAdded(k)
            end
        end
    
        CarryItems.UpdateAnimation()
    end)
end

return Inventory