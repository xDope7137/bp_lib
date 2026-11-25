function Notify(title, desc, type)
    if type == "inform" then type = "info" end
    exports[Config.NotificationsResource]:notify(title, desc, type)
end

return Notify