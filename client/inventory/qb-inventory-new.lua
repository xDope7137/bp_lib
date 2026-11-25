Inventory = {
    GetItemLabel = function(item)
        if not QBCore.Shared.Items[item] then return "NO_LABEL" end
        return QBCore.Shared.Items[item].label
    end,
    AddCarriableItem = CarryItems.AddCarriableItem,
    RemoveCarriableItem = CarryItems.RemoveCarriableItem,
    OpenStash = function(stashName, maxWeight, slots)
        local data = { label = stashName, maxweight = maxWeight, slots = slots }
        TriggerServerEvent("bp_lib:qb-inventory-new:openStash", stashName, data)
    end
}

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

return Inventory
