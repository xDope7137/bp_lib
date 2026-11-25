function Notify(title, desc, type)
    TriggerEvent("s1n_notify:notify", {
        type = type,     -- Modify the type by replacing "success" with the type you want (all listed above)
        title = title,   -- Replace "The title of the notifcation" with the title you want
        message = desc,  -- Replace "The text of the notification" with the text you want
        duration = 5000, -- The duration of the notification in milliseconds
        theme = "white", -- The theme of the notification (colorful or white)
        position =
        "top"            -- Modify the position of the notification by replacing "top-right" with the position you want (all listed above)
    })
end

return Notify