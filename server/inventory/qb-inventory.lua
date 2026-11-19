Inventory = {
    AddItem = function(source, item, amount, metadata) 
        local Player = QBCore.Functions.GetPlayer(source)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add', amount)
        return Player.Functions.AddItem(item, amount, nil, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        local Player = QBCore.Functions.GetPlayer(source)
        local slot = nil
        if metadata then
            local items = Player.Functions.GetItemsByName(item)
            for k, v in pairs(items) do
                if Utils.CompareTables(v.info, metadata) then slot = v.slot end
            end
            -- nothing matches: take nothing (qb-inventory would take the first slot of that name)
            if not slot then return false end
        end
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove', amount)
        return Player.Functions.RemoveItem(item, amount, slot)
    end,
    GetSlots = function(identifier)
        local inventory, maxSlots
        local player = QBCore.Functions.GetPlayer(identifier)
        local playerInv = exports[Config.InventoryResource]:GetInventory(identifier)

        if player then
            inventory = player.PlayerData.items
            maxSlots = Config.MaxSlots
        elseif playerInv then
            inventory = playerInv.items
            maxSlots = playerInv.slots
        end

        if not inventory then return 0, maxSlots end
        local slotsUsed = 0

        for _, v in pairs(inventory) do
            if v then
                slotsUsed = slotsUsed + 1
            end
        end

        local slotsFree = maxSlots - slotsUsed
        return slotsUsed, slotsFree
    end,
    GetTotalWeight = function(items)
        if not items then return 0 end
        local weight = 0
        for _, item in pairs(items) do
            local amount = item.amount
            if type(amount) ~= "number" then
                amount = 1
            end
    
            weight = weight + (item.weight * amount)
        end
        return tonumber(weight)
    end,
    CanCarryItem = function(source, item, amount)
        local id = Framework.GetIdentifier(source)
        if not id then return end

        local player = QBCore.Functions.GetPlayer(source)
        local playerInv = exports[Config.InventoryResource]:GetInventory(id)

        local itemData = QBCore.Shared.Items[item:lower()]
        if not itemData then return false end
    
        local inventory, items
        if player then
            inventory = {
                maxweight = Config.MaxWeight,
                slots = Config.MaxSlots
            }
            items = player.PlayerData.items
        elseif playerInv then
            inventory = playerInv
            items = playerInv.items
        end
    
        if not inventory then
            print('CanAddItem: Inventory not found')
            return false
        end
    
        local weight = itemData.weight * amount
        local totalWeight = Inventory.GetTotalWeight(items) + weight
        if totalWeight > inventory.maxweight then
            return false, 'weight'
        end
    
        local slotsUsed, _ = Inventory.GetSlots(id)
    
        if slotsUsed >= inventory.slots then
            return false, 'slots'
        end
        return true
    end,
    GetItem = function(source, item, metadata)
        local Player = QBCore.Functions.GetPlayer(source)
        if not metadata then
            local item = Player.Functions.GetItemByName(item)
            if not item then return nil end
            return {
                item = item.name,
                count = item.amount,
                metadata = item.info,
            }
        else
            local items = Player.Functions.GetItemsByName(item)
            for k, v in pairs(items) do
                if Utils.CompareTables(v.info, metadata) then 
                    return {
                        item = v.name,
                        count = v.amount,
                        metadata = v.info
                    }
                end
            end
        end

        return nil
    end,
    GetItems = function(source)
        local QPlayer = QBCore.Functions.GetPlayer(source)
        if not QPlayer then return {} end
        local items = QPlayer.PlayerData.items
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
    HasPlayerItem = function(source, itemName, count)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        local item = Player.Functions.GetItemByName(itemName)
        if not item then return false end
        if not count and item then return true end
        return count <= item.amount
    end,
    RegisterUsableItem = function(item, callback)
        QBCore.Functions.CreateUseableItem(item, callback)
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

return Inventory