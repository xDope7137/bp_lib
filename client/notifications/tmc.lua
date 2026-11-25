function Notify(title, desc, type)
    if not desc then
        TMC.Functions.SimpleNotify(title, type, 5000)
    else
        TMC.Functions.SimpleNotify({text = title, caption = desc}, type, 5000)
    end
end

return Notify