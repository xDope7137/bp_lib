local TMC = exports.core:getCoreObject()

Menu = function(title, options)
    local menuElements = {}
    
    for k, v in pairs(options) do
        local element = {
            type = 'button', -- Menu items are buttons by default
            name = 'option_' .. k, -- Each element needs a unique name
            label = v.title,
            description = v.description,
            icon = v.icon,
            disabled = v.disabled,
            value = k -- Store the index for reference in callback
        }
        
        table.insert(menuElements, element)
    end
    
    TMC.Functions.OpenMenu({
        namespace = 'peulib',
        title = title,
        canCancel = true,
        form = false -- Not a form, just a standard menu
    }, menuElements, 
    function(close, confirmed) 
        -- This is the close handler - triggered when menu is closed or form is submitted
        -- Not needed for basic menu functionality
    end, 
    function(select) 
        -- This is the select handler - triggered when a menu item is selected
        if not select or not select.value then return end
        
        local selectedIndex = select.value
        local selectedOption = options[selectedIndex]
        
        if not selectedOption then return end
        
        if selectedOption.isServer then
            TMC.Functions.TriggerServerEvent(selectedOption.serverEvent, table.unpack(selectedOption.args or {}))
        else
            TriggerEvent(selectedOption.event, table.unpack(selectedOption.args or {}))
        end
    end,
    function(change)
        -- This is the change handler - triggered when form elements change
        -- Not needed for basic menu functionality
    end)
end

return Menu