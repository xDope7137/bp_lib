Menu = function(title, options)
    local menu = {}

    menu[#menu + 1] = {
        header = title,
        isMenuHeader = true
    }

    for k, v in pairs(options) do
        menu[#menu + 1] = {
            header = v.title,
            txt = v.description or nil,
            icon = v.icon or false,
            disabled = v.disabled or false,
            hidden = v.hidden or false,
            params = {
                isServer = v.isServer or nil,
                event = v.event or nil,
                args = v.args or nil
            }
        }
    end 

    exports[Config.MenuResource]:openMenu(menu)
end

return Menu