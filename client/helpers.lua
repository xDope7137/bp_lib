--[[
    Client-only helpers (see shared/helpers.lua). client/main.lua copies them onto Core.
]]

-- ------------------------------------------------------------------ notify --

--- Notifies with a locale key of the calling script. kind: 'info' (default), 'success',
--- 'error', 'warning'.
function Helpers.NotifyKey(key, kind, ...)
    if Core and Core.Notify then Core.Notify(locale(key, ...), nil, kind or 'info') end
end

-- ------------------------------------------------------------------ locale --

local uiCache = {}  -- [resource][prefix list] = { key = text }

--- Every key in the calling script's locales/en.json, translated to the server language,
--- for its NUI. prefixes (optional): only keys starting with one of them, like { 'ui_', 'err_' }.
function Helpers.UILocale(prefixes)
    local res = Helpers.Caller()
    local id = type(prefixes) == 'table' and table.concat(prefixes, '|') or '*'
    uiCache[res] = uiCache[res] or {}
    if uiCache[res][id] then return uiCache[res][id] end
    local out = {}
    local ok, keys = pcall(json.decode, LoadResourceFile(res, 'locales/en.json') or '{}')
    for key in pairs(ok and type(keys) == 'table' and keys or {}) do
        local take = type(prefixes) ~= 'table'
        if not take then
            for _, p in ipairs(prefixes) do
                if key:sub(1, #p) == p then take = true; break end
            end
        end
        if take then out[key] = locale(key) end
    end
    uiCache[res][id] = out
    return out
end

AddEventHandler('onClientResourceStop', function(res) uiCache[res] = nil end)

-- --------------------------------------------------------------- streaming --

--- Loads a model (name or hash). Returns the hash once loaded, or nil when the model does
--- not exist or did not load within `timeout` ms (5000 when left out). Needs a thread.
function Helpers.RequestModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(tostring(model))
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(10)
    end
    return hash
end

--- Loads an animation dictionary. true once loaded, false when it does not exist or did
--- not load within `timeout` ms (5000 when left out). Needs a thread.
function Helpers.RequestAnimDict(dict, timeout)
    if type(dict) ~= 'string' or not DoesAnimDictExist(dict) then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

Helpers.Client = { 'NotifyKey', 'UILocale', 'RequestModel', 'RequestAnimDict' }
