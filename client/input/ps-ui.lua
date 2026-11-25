Input = function(header, options)
    local input = {}

    for _, v in pairs(options) do
        input[#input + 1] = {
            text = v.title,
            placeholder = v.name,
            type = v.type,
            isRequired = v.isRequired or false,
            default = v.default,
            options = v.options or nil,
        }
    end

    local result = exports[Config.InputResource]:Input({
        title = header or "Input value",
        inputs = input
    })

    return { amount = result[1] }
end 

return Input