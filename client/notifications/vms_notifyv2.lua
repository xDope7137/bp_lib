function Notify(title, desc, type)
    if type == "info" then type = "inform" end
    exports[Config.NotificationsResource]:Notification({
        title = title,
        description = desc,
        time = 5000, -- Miliseconds
    })
end

return Notify