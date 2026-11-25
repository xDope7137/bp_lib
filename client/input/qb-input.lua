Input = function(header, options)
    local input = {}

    for _, v in pairs(options) do
        input[#input + 1] = {
            text = v.title,
            name = v.name,
            type = v.type,
            isRequired = v.isRequired or false,
            default = v.default,
            options = v.options or nil,
        }
    end

    return exports[Config.InputResource]:ShowInput({
        header = header,
        submitText = Core.Locale('input_confirm'),
        inputs = input,
    })
end 

return Input