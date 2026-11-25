TextUI = {
    Text = "",

    Draw = function(text, pos)
        if text ~= TextUI.Text then 
            TextUI.Text = text
            lib.showTextUI(text)            
        end
    end,
    Stop = function()
        TextUI.Text = ""
        lib.hideTextUI()
    end
}

return TextUI