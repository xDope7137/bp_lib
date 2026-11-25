local TMC = exports.core:getCoreObject()

Clothing = {
    Set = function(outfit)
        if not outfit then return end

        local outfitData = {
            hat = { item = outfit.helmet_1 or outfit.hat_1 or -1, texture = outfit.helmet_2 or outfit.hat_2 or 0 },
            glasses = { item = outfit.glasses_1 or -1, texture = outfit.glasses_2 or 0 },
            mask = { item = outfit.mask_1 or -1, texture = outfit.mask_2 or 0 },
            torso = { item = outfit.torso_1 or -1, texture = outfit.torso_2 or 0 },
            tshirt = { item = outfit.tshirt_1 or -1, texture = outfit.tshirt_2 or 0 },
            arms = { item = outfit.arms or -1, texture = 0 },
            pants = { item = outfit.pants_1 or -1, texture = outfit.pants_2 or 0 },
            shoes = { item = outfit.shoes_1 or -1, texture = outfit.shoes_2 or 0 },
            ears = { item = outfit.ears_1 or -1, texture = outfit.ears_2 or 0 },
            chain = { item = outfit.chain_1 or -1, texture = outfit.chain_2 or 0 },
            bags = { item = outfit.bags_1 or -1, texture = outfit.bags_2 or 0 },
            decals = { item = outfit.decals_1 or -1, texture = outfit.decals_2 or 0 },
            watches = { item = outfit.watches_1 or -1, texture = outfit.watches_2 or 0 },
            bracelets = { item = outfit.bracelets_1 or -1, texture = outfit.bracelets_2 or 0 }
        }

        TriggerEvent("clothing:client:setOutfit", "outfit", outfitData)
    end,
    
    Reset = function()
        local playerPed = PlayerPedId()
        local playerData = TMC.Functions.GetPlayerData()

        if playerData.skin and playerData.clothing then
            TriggerEvent("clothing:client:loadPlayerClothing", playerPed, playerData.skin, playerData.clothing)
        else

            TMC.Functions.TriggerServerEvent("character:server:loadPlayerCharacter")
        end
    end,

    GetCurrentOutfit = function()
        local playerData = TMC.Functions.GetPlayerData()
        if playerData and playerData.clothing then
            return playerData.clothing
        end
        return nil
    end
}

return Clothing