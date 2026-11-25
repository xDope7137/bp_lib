local TMC = exports.core:getCoreObject()
Inventory = {
    GetItemLabel = function(item)
        if not TMC.Shared.Items[item] then return "NO_LABEL" end
        return TMC.Shared.Items[item].label
    end,
    AddCarriableItem = CarryItems.AddCarriableItem,
    RemoveCarriableItem = CarryItems.RemoveCarriableItem,
    OpenStash = function(stashName, maxWeight, slots)
        TMC.Functions.TriggerServerEvent("inventory:server:OpenInventory", "stash", stashName, {
            maxweight = maxWeight,
            slots = slots,
        })
    end
}

RegisterNetEvent('TMC:Player:UpdateClientInventoryCache', function(itemCache)
    local carriableItems = {}

    for _, cache in pairs(itemCache) do
        for _, item in pairs(cache) do
            if CarryItems.Items[item.name] then
                carriableItems[item.name] = true
            end
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