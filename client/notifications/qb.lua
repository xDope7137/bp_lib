function Notify(title, desc, type)
    if not desc then
        QBCore.Functions.Notify(title, type, 5000)
    else
        QBCore.Functions.Notify({text = title, caption = desc}, type, 5000)
    end
end

return Notify