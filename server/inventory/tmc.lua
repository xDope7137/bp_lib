Inventory = {
    AddItem = function(source, item, amount, metadata)
        local Player = TMC.Functions.GetPlayer(source)
        return Player.Functions.AddItem(item, amount, nil, metadata)
    end,
    RemoveItem = function(source, item, amount, metadata)
        local Player = TMC.Functions.GetPlayer(source)
        if item then
            return Player.Functions.RemoveItem(item, amount, nil)
        end
    end,
    GetItem = function(source, item, metadata)
        local Player = TMC.Functions.GetPlayer(source)
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
        local Player = TMC.Functions.GetPlayer(source)
        if not Player then return {} end

        local items = Player.PlayerData.items
        if not items then return {} end

        local formattedItems = {}

        for slot, slotData in pairs(items) do
            if type(slotData) == "table" and slotData.name then
                formattedItems[#formattedItems+1] = {
                    item = slotData.name,
                    count = slotData.amount,
                    metadata = slotData.info,
                    slot = slot,
                    index = slotData.index or 0
                }
            else
                for index, itemData in pairs(slotData) do
                    if type(itemData) == "table" and itemData.name then
                        formattedItems[#formattedItems+1] = {
                            item = itemData.name,
                            count = itemData.amount,
                            metadata = itemData.info,
                            slot = slot,
                            index = index
                        }
                    end
                end
            end
        end

        return formattedItems
    end,
    HasPlayerItem = function(source, itemName, count)
        local Player = TMC.Functions.GetPlayer(source)
        if not Player then return false end

        if not count then
            return Player.Functions.HasItem(itemName)
        else
            return Player.Functions.HasItem(itemName, count)
        end
    end,
    RegisterUsableItem = function(item, callback)
        TMC.Functions.CreateUseableItem(item, callback)
    end
}

Core.Framework.RegisterCallback("bp_lib:GetPlayerInventory", function(player, cb)
    cb(Inventory.GetItems(player))
end)

return Inventory