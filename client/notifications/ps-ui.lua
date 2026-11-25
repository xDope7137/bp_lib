function Notify(title, desc, type)
    if not desc then
        exports[Config.NotificationsResource]:Notify(title, type)
    else
        exports[Config.NotificationsResource]:Notify(desc, type)
    end
end

return Notify