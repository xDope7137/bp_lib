function Notify(title, desc, type)
    local text = title
    if desc then text = title..": "..desc end
    if type == "info" then type = "inform" end
    exports[Config.NotificationsResource]:SendAlert(type, title..": "..desc)
end

return Notify