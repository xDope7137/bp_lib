Clothing = {
    Appearance = nil,

    Set = function(outfit)
        if not outfit then return end 

        local ped = PlayerPedId()
        if not ped then return end

        if not Clothing.Appearance then
            Clothing.Appearance = exports[Config.ClothingResource]:getPlayerSkin(true)
        end

        Wait(100)

        TriggerEvent('skinchanger:loadSkin', {
            sex       = GetEntityModel(ped) == `mp_m_freemode_01` and 0 or 1,
            tshirt_1  = outfit.tshirt_1,
            tshirt_2  = outfit.tshirt_2,
            arms      = outfit.arms,
            arms_2    = 0,
            torso_1   = outfit.torso_1,
            torso_2   = outfit.torso_2,
            pants_1   = outfit.pants_1,
            pants_2   = outfit.pants_2,
            shoes_1   = outfit.shoes_1,
            glasses_1 = outfit.glasses_1,
            decals_1  = outfit.decals_1,
            decals_2  = outfit.decals_2,
        })
    end,

    Reset = function()
        if Clothing.Appearance then
            exports[Config.ClothingResource]:setPlayerSkin(Clothing.Appearance, false)
            Clothing.Appearance = nil
        end
    end
}

return Clothing