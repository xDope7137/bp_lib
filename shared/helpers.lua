--[[
    Small helpers that BP scripts used to copy into every resource. Loaded on both sides;
    client/main.lua and server/main.lua copy them onto Core, so scripts call lib.Say(...),
    lib.Plate.Normalize(...) and so on. Side-only helpers live in client/helpers.lua and
    server/helpers.lua.

    Anything that prints or keeps state finds the calling script with GetInvokingResource(),
    so two scripts never share a tag, a cache or a rate limit.
]]

Helpers = {}

local libResource = GetCurrentResourceName()

--- The script that called into bp_lib (bp_lib itself when called from inside).
function Helpers.Caller()
    return GetInvokingResource() or libResource
end

-- ----------------------------------------------------------------- console --

--- Console line tagged with the calling script. No colour: cyan tag, plain text.
--- With a colour ('^1' red, '^3' yellow ...) the whole line takes it.
function Helpers.Say(msg, colour)
    local tag = Helpers.Caller()
    if colour then
        print(('%s[%s] %s^0'):format(colour, tag, tostring(msg)))
    else
        print(('^5[%s]^0 %s'):format(tag, tostring(msg)))
    end
end

--- Debug console line, only when `enabled` is truthy. Parts are joined with spaces.
function Helpers.Debug(enabled, ...)
    if not enabled then return end
    local parts = table.pack(...)
    for i = 1, parts.n do parts[i] = tostring(parts[i]) end
    print(('^5[%s:debug]^0 %s'):format(Helpers.Caller(), table.concat(parts, ' ', 1, parts.n)))
end

-- -------------------------------------------------------------------- text --

--- String without leading and trailing whitespace. nil stays nil; other values go through tostring.
function Helpers.Trim(value)
    if value == nil then return nil end
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- ----------------------------------------------------------------- numbers --

--- tonumber(n) held between lo and hi. Not a number (or NaN) gives `default`.
function Helpers.Clamp(n, lo, hi, default)
    n = tonumber(n)
    if not n or n ~= n then return default end
    if lo and n < lo then n = lo end
    if hi and n > hi then n = hi end
    return n
end

--- Rounds half up to `decimals` places (0 when left out). Not a number gives 0.
function Helpers.Round(n, decimals)
    n = tonumber(n)
    if not n or n ~= n then return 0 end
    local mult = 10 ^ (decimals or 0)
    local r = math.floor(n * mult + 0.5) / mult
    if (decimals or 0) == 0 then return math.tointeger(r) or r end
    return r
end

-- 2^53 - 1: the largest whole number a double (JSON, the NUI, MySQL DOUBLE) holds exactly.
local MAX_EXACT = 9007199254740991

--- (0.11.0) The strict money rule. Returns n as an integer when it is a number, finite, whole,
--- at least `min` (1 when left out) and at most `max` (2^53 - 1 when left out). Anything else
--- returns nil plus why: 'not_number', 'not_finite', 'not_whole', 'too_small', 'too_large',
--- 'bad_limits'. Never rounds, clamps or converts: "100", 1.5, -1, 0, NaN, inf, tables and
--- numbers past 2^53 are all refused.
function Helpers.Amount(n, min, max)
    if min == nil then min = 1 end
    if max == nil then max = MAX_EXACT end
    if type(min) ~= 'number' or type(max) ~= 'number' or min ~= min or max ~= max then
        return nil, 'bad_limits'
    end
    if type(n) ~= 'number' then return nil, 'not_number' end
    if n ~= n or n == math.huge or n == -math.huge then return nil, 'not_finite' end
    if math.type(n) == 'float' and n ~= math.floor(n) then return nil, 'not_whole' end
    if n < min then return nil, 'too_small' end
    if n > max or n > MAX_EXACT or n < -MAX_EXACT then return nil, 'too_large' end
    return math.tointeger(n)
end

-- ------------------------------------------------------------------ plates --

local Plate = {}
Helpers.Plate = Plate

--- Trimmed upper case plate, or nil when there is nothing left. Use it before comparing
--- or storing any plate: the game pads plates with spaces, garages store them trimmed.
function Plate.Normalize(plate)
    if type(plate) ~= 'string' and type(plate) ~= 'number' then return nil end
    local p = Helpers.Trim(plate):upper()
    if p == '' then return nil end
    return p
end

--- What the game shows: the normalized plate cut to 8 characters.
function Plate.World(plate)
    local p = Plate.Normalize(plate)
    return p and (p:sub(1, 8):gsub('%s+$', ''))
end

--- Every spelling a garage script may have stored: as given, normalized, and padded with
--- spaces to 8 characters every way round. For SQL lookups by plate.
function Plate.Spellings(plate)
    local raw = tostring(plate or '')
    local core = Plate.Normalize(plate) or ''
    local list, seen = {}, {}
    local function add(p)
        if not seen[p] then seen[p] = true; list[#list + 1] = p end
    end
    add(raw)
    add(core)
    local pad = 8 - #core
    if core ~= '' and pad > 0 then
        for left = 0, pad do add((' '):rep(left) .. core .. (' '):rep(pad - left)) end
    end
    return list
end

--- Normalized plate of a vehicle entity, or nil for no entity.
function Plate.Of(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    return Plate.Normalize(GetVehicleNumberPlateText(entity))
end

--- The names copied onto Core on both sides.
Helpers.Shared = { 'Say', 'Debug', 'Trim', 'Clamp', 'Round', 'Plate', 'Amount' }
