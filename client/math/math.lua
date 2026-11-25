Math = {}

function Math.RandomStr(length)
    if length <= 0 then return '' end
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    local str = ''
    for _ = 1, length do
        local rand = math.random(#chars)
        str = str .. chars:sub(rand, rand)
    end
    return str
end

function Math.RandomInt(length)
    if length <= 0 then return '' end
    local str = ''
    for _ = 1, length do
        str = str .. tostring(math.random(0, 9))
    end
    return str
end

function Math.SplitStr(str, delimiter)
    local result = {}
    if not str then return result end
    for part in string.gmatch(str, '([^' .. delimiter .. ']+)') do
        result[#result + 1] = part
    end
    return result
end

function Math.Trim(value)
    if value == nil then return nil end
    return (tostring(value):gsub('^%s*(.-)%s*$', '%1'))
end

function Math.FirstToUpper(value)
    if not value then return value end
    value = tostring(value)
    return value:sub(1, 1):upper() .. value:sub(2)
end

function Math.Round(value, numDecimalPlaces)
    if not value then return 0 end
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(value * mult + 0.5) / mult
end

function Math.GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return Math.Trim(GetVehicleNumberPlateText(vehicle))
end

return Math
