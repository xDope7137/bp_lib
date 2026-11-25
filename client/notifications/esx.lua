function Notify(title, desc, type)
    local text = title
    if desc then text = title..": "..desc end
    ESX.ShowNotification(text, type, 5000)
end

return Notify