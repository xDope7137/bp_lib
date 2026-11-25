Clothing = {
    Set = function(outfit)
        if not outfit then return end

        TriggerEvent('skinchanger:getSkin', function(skin)           
            TriggerEvent('skinchanger:loadClothes', skin, outfit)
        end)
    end,

    Reset = function()
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
            TriggerEvent('skinchanger:loadSkin', skin)
        end)
    end
}

return Clothing