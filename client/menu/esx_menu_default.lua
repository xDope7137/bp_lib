Menu = function(title, options)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    local menu = {}

    ESX.UI.Menu.CloseAll()

    for k,v in pairs(options) do 
        menu[#menu + 1] = {
            isServer = v.isServer,
            label = v.title,
            event = v.event,
            args = v.args,
            value = k,
        }
    end

	ESX.UI.Menu.Open('default', resource, 'bp_lib', {
		title = title,
		align = 'right',
		elements = menu
	}, function(data, element)
        for k,v in pairs(menu) do
            if data.current.value == v.value then 
                element.close()
                if v.isServer then 
                    TriggerServerEvent(v.event, v.args)
                else 
                    TriggerEvent(v.event, v.args)
                end
            end  
        end
    end, function(data, element)
		element.close()
	end)
end 

return Menu