function Notify(title, desc, type)
    if type == "info" then type = "inform" end
    lib.notify({
        title = title,
        description = desc,
        type = type
    })
end

return Notify