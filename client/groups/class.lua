Groups = {
    Blips = {},

    ---Checks if a blip with this name is already created
    ---@param name string
    ---@return string
    DoesBlipExist = function(name)
        for blip,_ in pairs(Groups.Blips) do 
            if blip == name then 
                return blip
            end
        end
        return nil
    end,

    ---Removes blip
    ---@param name string
    RemoveBlip = function(name)
        local blip = Groups.DoesBlipExist(name)
        if blip then
            SetBlipRoute(blip, false)
            RemoveBlip(blip)
            Groups.Blip[blip] = nil
        end
    end
}

return Groups