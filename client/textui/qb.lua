TextUI = {
    Text = "",
    
    Draw = function(text, pos)
        if text ~= TextUI.Text then 
            TextUI.Text = text     
            exports[Config.TextUIResource]:DrawText(text, 'right')
        end
    end,
    Stop = function()
        TextUI.Text = ""
        exports[Config.TextUIResource]:HideText()
    end
}

return TextUI