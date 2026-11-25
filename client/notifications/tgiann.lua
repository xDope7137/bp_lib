function Notify(title, desc, type)
    local text = title
    if desc then text = title..": "..desc end
    exports[Config.NotificationsResource]:Notif(text, type, 50000)
end

return Notify