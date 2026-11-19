CarryItems = {
    Items = {},
    InInventory = {},
    Current = {
        prop = nil,
        item = nil,
        options = nil
    },

    AddCarriableItem = function(itemName, options)
        if not Config.CarryItemsEnabled then return end

        CarryItems.Items[itemName] = options
    end,

    RemoveCarriableItem = function(itemName)
        if not Config.CarryItemsEnabled then return end

        CarryItems.Items[itemName] = nil
        
        CarryItems.ItemRemoved(itemName)
    end,

    ItemAdded = function(itemName)
        if not Config.CarryItemsEnabled then return end

        if not CarryItems.Items[itemName] then return end

        CarryItems.InInventory[itemName] = true
        TriggerEvent('bp_lib:AddedItem', itemName)
    end,

    ItemRemoved = function(itemName)
        if not Config.CarryItemsEnabled then return end
        if not CarryItems.InInventory[itemName] then return end

        CarryItems.InInventory[itemName] = nil

        if CarryItems.Current.item ~= itemName then
            return
        end    

        if CarryItems.Current.options.clothing then 
            local options = CarryItems.Current.options
            if not options then return end
            local clohting = IsPedMale(PlayerPedId()) and options.clothing.male or options.clothing.female
            SetPedComponentVariation(PlayerPedId(), clohting.id, 0, 0, 0)
        end

        DeleteEntity(CarryItems.Current.prop)
        CarryItems.Current.prop = nil
        CarryItems.Current.item = nil
        CarryItems.Current.options = nil

        ClearPedTasks(PlayerPedId())
        TriggerEvent('bp_lib:RemovedItem', itemName)
    end,

    UpdateAnimation = function()
        if not Config.CarryItemsEnabled then return end
        if CarryItems.Current.item then return end

        if CarryItems.Current.prop then 
            DeleteEntity(CarryItems.Current.prop)
        end
        
        local key, value = next(CarryItems.InInventory)
        if not key then return end

        if not CarryItems.Items[key] then return end

        local options = CarryItems.Items[key]

        if options.anim then
            while not HasAnimDictLoaded(options.animDict) do
                RequestAnimDict(options.animDict)
                Wait(10)
            end

            TaskPlayAnim(PlayerPedId(), options.animDict, options.anim, 2.0, 2.0, -1, 51, 0, false, false, false)
        elseif options.clothing then
            local clohting = IsPedMale(PlayerPedId()) and options.clothing.male or options.clothing.female
            SetPedComponentVariation(PlayerPedId(), clohting.id, clohting.drawable, clohting.texture, 0)
        end

        CarryItems.Current.item = key
        CarryItems.Current.options = options

        local pCoords = GetEntityCoords(PlayerPedId())

        CarryItems.Current.prop = CreateObject(GetHashKey(options.prop), pCoords.x, pCoords.y, pCoords.z + 0.2,  true,  true, true)
        while not DoesEntityExist(CarryItems.Current.prop) do
            Citizen.Wait(10)
        end
        AttachEntityToEntity(CarryItems.Current.prop, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), options.boneIndex), options.offsets[1], options.offsets[2], options.offsets[3], options.offsets[4], options.offsets[5], options.offsets[6], true, true, false, true, 1, true)
    end
}

Citizen.CreateThread(function()
    if not Config.CarryItemsEnabled then return end
    while true do
        if CarryItems.Current.item then
            if CarryItems.Current.options.anim ~= nil then
                local options = CarryItems.Current.options
                if not IsEntityPlayingAnim(PlayerPedId(), options.animDict, options.anim, 3) then
                    TaskPlayAnim(PlayerPedId(), options.animDict, options.anim, 2.0, 2.0, -1, 51, 0, false, false, false)
                end
            end

            if CarryItems.Current.options.disableSprint then
                DisableControlAction(0, 21, true)
            end

            if CarryItems.Current.options.disableJump then
                DisableControlAction(0, 22, true)
            end

            if CarryItems.Current.options.disableFight then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
            end
        else
            Citizen.Wait(1000)
        end

        Citizen.Wait(1)
    end
end)

AddEventHandler("onResourceStop", function(rName)
    if rName == GetCurrentResourceName() then
        if CarryItems.Current.prop then 
            DeleteEntity(CarryItems.Current.prop)
        end
        ClearPedTasks(PlayerPedId())
    end
end)

Citizen.CreateThread(function()
    while not Core do Citizen.Wait(100) end
    while not Core.Framework.PlayerLoaded do
        Citizen.Wait(100)
    end

    Citizen.Wait(10000)

    local playerInventory = Core.Framework.Callbacks.Trigger("bp_lib:GetPlayerInventory")
    
    for k, v in pairs(playerInventory) do
        if v.item then
            CarryItems.ItemAdded(v.item)
        else
            print('[ERROR] - ITEM NOT FOUND:', json.encode(v, {indent = true}))
        end
    end

    CarryItems.UpdateAnimation()
end)

exports('GetCarryItem', function()
    return CarryItems.Current.item
end)

exports('RemoveCarryItem', function(item)
    if not item then return end
    CarryItems.ItemRemoved(item)
    CarryItems.UpdateAnimation()
end)

exports('AddCarryItem', function(item)
    if not item then return end
    CarryItems.ItemAdded(item)
    CarryItems.UpdateAnimation()
end)