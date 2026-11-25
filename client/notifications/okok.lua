function Notify(title, desc, type)
    if not desc then desc = "" end 
    if not title then title = "" end
    exports[Config.NotificationsResource]:Alert(title, desc, 5000, type, false)
end

return Notify