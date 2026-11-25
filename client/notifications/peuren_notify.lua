function Notify(title, desc, type)
    exports[Config.NotificationsResource]:Notify({
        title = title,
        description = desc,
        severity = type,
        life = 5000,
        position = "topright"
    })
end

return Notify