-- lb-phone keeps its own number per character; every lb-phone table references
-- phone_phones.phone_number with ON UPDATE CASCADE, so one update moves it all.
Phone = {
    -- Returns true, oldNumber, notice | false, message
    SetNumber = function(player, identifier, number)
        if not number:match("^[0-9]+$") then
            return false, "Phone numbers can only contain digits."
        end

        local current = Core.Database.SingleSync(
            "SELECT phone_number FROM phone_phones WHERE owner_id = ? ORDER BY last_seen DESC LIMIT 1",
            { identifier }
        )
        if not current or not current.phone_number then
            return false, "You don't have a phone set up yet. Open your phone first."
        end
        if #number ~= #current.phone_number then
            return false, ("Your phone number must be exactly %d digits."):format(#current.phone_number)
        end
        if Core.Database.ScalarSync("SELECT 1 FROM phone_phones WHERE phone_number = ?", { number }) then
            return false, "This phone number is already registered to another citizen."
        end

        local updated = Core.Database.UpdateSync(
            "UPDATE phone_phones SET phone_number = ? WHERE phone_number = ? AND owner_id = ?",
            { number, current.phone_number, identifier }
        )
        if not updated or updated < 1 then
            return false, "Failed to write the new phone number."
        end

        -- lb-phone caches the number of a loaded phone until the player reconnects.
        return true, current.phone_number, "Reconnect for your phone to show it."
    end
}

return Phone
