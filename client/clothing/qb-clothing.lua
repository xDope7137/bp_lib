Clothing = {
    Set = function(outfit)
        if not outfit then return end 

        local ped = PlayerPedId()
        local chain = GetEntityModel(ped) == `mp_m_freemode_01` and "accessory" or "chain"

        local Data = {
            outfitData = {
                ["pants"]       = { item = outfit.pants_1,      texture = outfit.pants_2},
                ["arms"]        = { item = outfit.arms,         texture = 0},  
                ["t-shirt"]     = { item = outfit.tshirt_1,     texture = outfit.tshirt_2},  
                ["torso2"]      = { item = outfit.torso_1,      texture = outfit.torso_2}, 
                ["shoes"]       = { item = outfit.shoes_1,      texture = outfit.shoes_2},  
                [chain]         = { item = outfit.chain_1,      texture = outfit.chain_2},
                ["glass"]       = { item = outfit.glasses_1,    texture = outfit.glasses_2},  
                ["ear"]         = { item = outfit.ears_1,       texture = outfit.ears_2},
                ["decals"]      = { item = outfit.decals_1,      texture = outfit.decals_2},
            },
        }
        TriggerEvent('qb-clothing:client:loadOutfit', Data)
    end,

    Reset = function()
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    end
}

return Clothing