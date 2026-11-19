-- No phone resource: the number lives in the framework's character data.
Phone = {
    -- Returns true, oldNumber, notice | false, message
    SetNumber = function(player, identifier, number)
        if not Core.Framework or not Core.Framework.SetPhoneNumber then
            return false, "No supported phone system is running."
        end
        return Core.Framework.SetPhoneNumber(player, number)
    end
}

return Phone
