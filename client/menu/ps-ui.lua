Menu = function(title, options)
    local menu = {}

    for k, v in pairs(options) do
        menu[#menu + 1] = {
            header = v.title,
            text = v.description or nil,
            icon = v.icon or false,
            event = v.event or nil,
            args = v.args or nil,
            server = v.isServer,
            disabled = v.disabled or false,
        }
    end

    exports[Config.MenuResource]:CreateMenu(menu)
end

return Menu