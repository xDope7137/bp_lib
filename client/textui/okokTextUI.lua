TextUI = {
    Text = "",

    Draw = function(text, pos)
        if text ~= TextUI.Text then 
            TextUI.Text = text
            exports[Config.TextUIResource]:Open(text, 'lightgrey', 'right', false)     
        end
    end,
    Stop = function()
        TextUI.Text = ""
        exports[Config.TextUIResource]:Close()
    end
}

return TextUI