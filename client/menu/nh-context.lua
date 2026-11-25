Menu = function(title, options)
    local menu = {}

    menu[#menu + 1] = {
        header = title,
        disabled = true
    }

    for k, v in pairs(options) do
        menu[#menu + 1] = {
            header = v.title,
            icon = v.icon or false,
            context = v.description or nil,
            disabled = v.disabled or false,
            server = v.isServer or nil,
            hidden = v.hidden or false,
            event = v.event or nil,
            args = v.args or nil,
        }
    end 

    exports[Config.MenuResource]:ContextMenu(menu)
end

return Menu