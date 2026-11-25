Menu = function(title, options)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    local menu = {}

    ESX.CloseContext()

    menu[#menu + 1] = {
        title = title,
        unselectable = true
    }

    for k,v in pairs(options) do 
        menu[#menu + 1] = {
            isServer = v.isServer,
            unselectable = v.disabled or nil,
            description = v.description or nil,
            title = v.title,
            event = v.event,
            args = v.args,
            icon = v.icon,
            value = k,
        }
    end

    ESX.OpenContext("right", menu, function(element, data)
        for k,v in pairs(menu) do
            if data.value == v.value then 
                ESX.CloseContext()
                if v.isServer then 
                    TriggerServerEvent(v.event, v.args)
                else 
                    TriggerEvent(v.event, v.args)
                end
            end 
        end
    end)	
end 

return Menu