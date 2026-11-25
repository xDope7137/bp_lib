Input = function(title, options)
    local input = {}

    for _, v in pairs(options) do
        if v.type == "number" or v.type == "input" then
            input[#input + 1] = {
                type = v.type,
                label = v.label,
                name = v.name,
                default = v.default or nil,
            }
        elseif v.type == "checkbox" then
            input[#input + 1] = {
                type = 'checkbox',
                label = v.label,
                name = v.name,
                default = v.default or false,
            }
        elseif v.type == "select" then
            local data = {}

            for _, option in pairs(v.options) do
                data[#data + 1] = { value = option.value, name = v.name, label = option.text }
            end

            input[#input + 1] = {
                type = 'select',
                label = v.label,
                name = v.name,
                options = data,
            }
        end
    end

    if not next(input) then return end

    local inputValues = lib.inputDialog(title, input)
    local returnValues = {}

    if not inputValues then return end

    for k, v in pairs(inputValues) do
        returnValues[options[k].name] = v
    end

    return returnValues
end 

return Input