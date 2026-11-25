Clothing = {
    Set = function(outfit)
        if not outfit then return end 

        local ped = PlayerPedId()
        if not ped then return end

        local crm_clothing = {
            {crm_id = 3,    crm_style = outfit.torso_1,     crm_texture = outfit.torso_2    }, -- Torsos
            {crm_id = 4,    crm_style = outfit.pants_1,     crm_texture = outfit.pants_2    }, -- Legs
            {crm_id = 6,    crm_style = outfit.shoes_1,     crm_texture = outfit.shoes_2    }, -- Shoes
            {crm_id = 7,    crm_style = outfit.chain_1,     crm_texture = outfit.chain_2    }, -- Accessories
            {crm_id = 8,    crm_style = outfit.tshirt_1,    crm_texture = outfit.tshirt_2   }, -- Undershirts
            {crm_id = 9,    crm_style = outfit.vest_1,      crm_texture = outfit.vest_2     }, -- Vests
            {crm_id = 10,   crm_style = outfit.decals_1,    crm_texture = outfit.decals_2   }, -- Decals
        }
        
        local crm_accessories = {
            {crm_id = 0,    crm_style = outfit.hat_1,       crm_texture = outfit.hat_2      }, -- Hats
            {crm_id = 1,    crm_style = outfit.glasses_1,   crm_texture = outfit.glasses_2  }, -- Glasses
            {crm_id = 2,    crm_style = outfit.ears_1,      crm_texture = outfit.ears_2     }, -- Ears
        }
        
        exports[Config.ClothingResource]:crm_set_ped_clothing(ped, crm_clothing)
        exports[Config.ClothingResource]:crm_set_ped_accessories(ped, crm_accessories)
    end,

    Reset = function()
        TriggerEvent("crm-appearance:load-player-skin")
    end
}

return Clothing