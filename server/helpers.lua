--[[
    Server-only helpers (see shared/helpers.lua). server/main.lua copies them onto Core.
    They read Core.Framework at call time, so they work whatever framework module loaded.
]]

-- ------------------------------------------------------------------ admins --

--- Is src an admin? access = { ace = 'perm.name', groups = { 'admin', ... }, console = bool }.
--- The ACE permission wins, then any framework group. The console (src 0) counts only
--- with console = true.
function Helpers.IsAdmin(src, access)
    access = type(access) == 'table' and access or {}
    src = tonumber(src)
    if not src or src < 0 then return false end
    if src == 0 then return access.console == true end
    if type(access.ace) == 'string' and access.ace ~= '' and IsPlayerAceAllowed(src, access.ace) then
        return true
    end
    local fw = Core and Core.Framework
    if type(access.groups) == 'table' and fw and fw.HasGroup then
        for _, group in ipairs(access.groups) do
            local ok, has = pcall(fw.HasGroup, src, group)
            if ok and has then return true end
        end
    end
    return false
end

-- ----------------------------------------------------------------- players --

--- Character id (qb/qbx citizenid, esx identifier) as a string, or nil for a player who
--- is not loaded. Never throws.
function Helpers.Identifier(src)
    src = tonumber(src)
    local fw = Core and Core.Framework
    if not src or src <= 0 or not (fw and fw.GetIdentifier) then return nil end
    local ok, id = pcall(fw.GetIdentifier, src)
    if not ok or id == nil or id == false or id == '' then return nil end
    return tostring(id)
end

--- Name to show for a player: the character's full name, else the FiveM name, else
--- "player <id>". Trimmed and cut to `max` characters (64 when left out).
function Helpers.DisplayName(src, max)
    src = tonumber(src)
    if not src or src <= 0 then return 'console' end
    local fw = Core and Core.Framework
    local name
    if fw and fw.GetCharName then
        local ok, n = pcall(fw.GetCharName, src)
        if ok then
            if type(n) == 'table' then n = n.full or n.first end
            if type(n) == 'string' then name = Helpers.Trim(n) end
        end
    end
    if not name or name == '' then name = GetPlayerName(src) or ('player ' .. src) end
    return tostring(name):sub(1, max or 64)
end

-- ------------------------------------------------------------- rate limits --

local gaps = {}     -- [resource][src][key] = GetGameTimer() of the last allowed call
local buckets = {}  -- [resource][src][key] = { times }

local function slot(store, src)
    local res = Helpers.Caller()
    local mine = store[res]
    if not mine then mine = {}; store[res] = mine end
    local player = mine[src]
    if not player then player = {}; mine[src] = player end
    return player
end

--- true when `key` was not allowed for this player in the last `ms` milliseconds (the call
--- is then counted), false when it comes too soon. Kept per calling script.
function Helpers.RateLimit(src, key, ms)
    local now, player = GetGameTimer(), slot(gaps, src)
    local last = player[key]
    if last and now - last < (tonumber(ms) or 0) then return false end
    player[key] = now
    return true
end

--- true when the player made fewer than `max` calls of `key` in the last `windowMs`
--- milliseconds (this call is then counted), false when the bucket is full.
function Helpers.Bucket(src, key, max, windowMs)
    local now, player = GetGameTimer(), slot(buckets, src)
    local kept = {}
    for _, t in ipairs(player[key] or {}) do
        if now - t < windowMs then kept[#kept + 1] = t end
    end
    if #kept >= max then player[key] = kept; return false end
    kept[#kept + 1] = now
    player[key] = kept
    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    for _, store in ipairs({ gaps, buckets }) do
        for _, mine in pairs(store) do mine[src] = nil end
    end
end)

-- ------------------------------------------------------------------- locks --

local locks = {}    -- [resource][key] = { at = GetGameTimer(), ttl = ms, token = {} }

local function lockKeys(keys)
    if type(keys) ~= 'table' then keys = { keys } end
    local list, seen = {}, {}
    for _, key in pairs(keys) do
        local kind = type(key)
        if kind ~= 'string' and kind ~= 'number' then return nil end
        if kind == 'number' then
            if key ~= key or key == math.huge or key == -math.huge then return nil end
            key = math.tointeger(key) or key   -- 7.0 locks the same key as 7
        end
        key = tostring(key)
        if not seen[key] then seen[key] = true; list[#list + 1] = key end
    end
    if #list == 0 then return nil end
    table.sort(list)
    return list
end

--- (0.11.0) Runs fn() while holding every key in `keys` (one key or a list of strings and
--- numbers), kept per calling script. The keys are sorted and taken in that order, all or
--- none: when any of them is held, fn does not run and the call returns false, 'busy'.
--- Otherwise returns true followed by what fn returned. The keys are released when fn
--- returns and when it throws (the error is raised again). A lock older than `ttl`
--- milliseconds (30000 when left out) counts as free, so a stuck holder can never block a
--- key for good. Not re-entrant: taking a key you already hold returns false, 'busy'.
function Helpers.Lock(keys, fn, ttl)
    local list = lockKeys(keys)
    if not list then return false, 'bad_keys' end
    if type(fn) ~= 'function' and not (type(fn) == 'table' and getmetatable(fn) and getmetatable(fn).__call) then
        return false, 'bad_function'
    end
    ttl = tonumber(ttl) or 30000
    if ttl <= 0 or ttl ~= ttl then ttl = 30000 end

    local res = Helpers.Caller()
    local mine = locks[res]
    if not mine then mine = {}; locks[res] = mine end
    local now = GetGameTimer()
    for _, key in ipairs(list) do
        local held = mine[key]
        if held and now - held.at < held.ttl then return false, 'busy' end
    end
    local token = {}
    for _, key in ipairs(list) do mine[key] = { at = now, ttl = ttl, token = token } end

    local result = table.pack(pcall(fn))
    for _, key in ipairs(list) do
        local held = mine[key]
        if held and held.token == token then mine[key] = nil end
    end
    if not result[1] then error(result[2], 0) end
    return true, table.unpack(result, 2, result.n)
end

--- (0.11.0) true when any of `keys` is held by the calling script right now.
function Helpers.IsLocked(keys)
    local list = lockKeys(keys)
    local mine = list and locks[Helpers.Caller()]
    if not mine then return false end
    local now = GetGameTimer()
    for _, key in ipairs(list) do
        local held = mine[key]
        if held and now - held.at < held.ttl then return true end
    end
    return false
end

-- ---------------------------------------------------------------- distance --

local function xyz(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' and type(c) ~= 'userdata' then return nil end
    local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
    if not (x and y and z) then return nil end
    return x, y, z
end

--- (0.11.0) Is the player's ped within `radius` metres of `coords` (vector3, vector4 or
--- { x, y, z })? Uses the server's copy of the ped's position: a page, event or callback that
--- only claims a place is not believed. It cannot catch a teleport or position cheat: under
--- OneSync that copy comes from the client's own sync data. Returns true or false, then the
--- distance (nil when it could not be measured: no player, no ped, bad coords or radius).
function Helpers.IsNear(src, coords, radius)
    src = tonumber(src)
    radius = tonumber(radius)
    if not src or src <= 0 or not radius or radius < 0 or radius ~= radius then return false end
    local cx, cy, cz = xyz(coords)
    if not cx then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local px, py, pz = xyz(GetEntityCoords(ped))
    if not px then return false end
    local dx, dy, dz = px - cx, py - cy, pz - cz
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    return dist <= radius, dist
end

-- ------------------------------------------------------------------- roles --

local function holds(src, spec, fw)
    if type(spec) ~= 'table' then return false end
    if type(spec.ace) == 'string' and spec.ace ~= '' and IsPlayerAceAllowed(src, spec.ace) then return true end
    if type(spec.groups) == 'table' and fw and fw.HasGroup then
        for _, group in ipairs(spec.groups) do
            local ok, has = pcall(fw.HasGroup, src, group)
            if ok and has then return true end
        end
    end
    return false
end

-- Role names from highest to lowest: staff.order when given, else by `rank` (higher first),
-- then by name so the answer never depends on table order.
local function roleOrder(roles, order)
    local list, seen = {}, {}
    if type(order) == 'table' then
        for _, name in ipairs(order) do
            if roles[name] and not seen[name] then seen[name] = true; list[#list + 1] = name end
        end
    end
    local rest = {}
    for name in pairs(roles) do
        if type(name) == 'string' and not seen[name] then rest[#rest + 1] = name end
    end
    table.sort(rest, function(a, b)
        local ra, rb = tonumber(roles[a].rank) or -math.huge, tonumber(roles[b].rank) or -math.huge
        if ra ~= rb then return ra > rb end
        return a < b
    end)
    for _, name in ipairs(rest) do list[#list + 1] = name end
    return list
end

--- (0.11.0) The highest staff role a player holds, from ACE rights and framework groups.
--- staff = {
---   owner = { ace = 'my.owner' },                          -- optional, always the top
---   roles = { admin = { ace = 'my.admin', groups = { 'admin', 'god' } }, mod = { ... } },
---   order = { 'admin', 'mod', 'trial' },                   -- highest first (or a `rank` per role)
---   console = true,                                        -- src 0 counts as owner
--- }
--- Returns the role name and its place (0 = owner, 1 = the highest role in the order, ...),
--- or nil when the player holds none. Each role is checked like Core.IsAdmin.
function Helpers.Role(src, staff)
    src = tonumber(src)
    if not src or src < 0 or type(staff) ~= 'table' then return nil end
    if src == 0 then
        if staff.console == true then return 'owner', 0 end
        return nil
    end
    local fw = Core and Core.Framework
    if holds(src, staff.owner, fw) then return 'owner', 0 end
    local roles = type(staff.roles) == 'table' and staff.roles or {}
    for place, name in ipairs(roleOrder(roles, staff.order)) do
        if holds(src, roles[name], fw) then return name, place end
    end
    return nil
end

AddEventHandler('onResourceStop', function(res)
    gaps[res], buckets[res] = nil, nil
    locks[res] = nil
end)

-- ------------------------------------------------------------------ notify --

--- Notifies a player with a locale key of the calling script. kind: 'info' (default),
--- 'success', 'error', 'warning'.
function Helpers.NotifyKey(src, key, kind, ...)
    if not src then return end
    TriggerClientEvent('bp_lib:notify', src, locale(key, ...), nil, kind or 'info')
end

--- The notification bridge (0.11.0). An important note for one online player: inside BP Laptop
--- when it is running and the calling script has an app this player can see there (stored, in
--- the bell list, unread badge, toast), else the normal notify. Never both. opts = { app?, data? }:
--- app picks one of the script's laptop apps (default its first), data goes back to that app when
--- the player opens the note. Returns 'laptop' or 'notify' (false for no player).
function Helpers.Alert(src, title, body, kind, opts)
    src = tonumber(src)
    if not src or src <= 0 or type(title) ~= 'string' or title == '' then return false end
    if body ~= nil and type(body) ~= 'string' then body = tostring(body) end
    if body == '' then body = nil end
    opts = type(opts) == 'table' and opts or {}
    if GetResourceState('bp_laptop') == 'started' then
        local resource = GetInvokingResource() or 'bp_lib'
        -- the laptop sees bp_lib as its caller, so name the script; it trusts that only from bp_lib
        local ok, id = pcall(function()
            return exports.bp_laptop:Alert(src, { title = title, body = body, app = opts.app, data = opts.data }, resource)
        end)
        if ok and id then return 'laptop' end
    end
    TriggerClientEvent('bp_lib:notify', src, title, body, kind or 'info')
    return 'notify'
end

-- ----------------------------------------------------------------- discord --

--- Posts one embed to a Discord webhook. embed = { title, description, color, fields,
--- footer } (footer may be a string). Returns false when there is no url.
function Helpers.Webhook(url, embed, username)
    if type(url) ~= 'string' or not url:find('^https?://') then return false end
    embed = type(embed) == 'table' and embed or { description = tostring(embed) }
    if type(embed.footer) == 'string' then embed.footer = { text = embed.footer } end
    embed.footer = embed.footer or { text = os.date('%Y-%m-%d %H:%M:%S') }
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = username or 'BP Development',
        embeds = { embed },
    }), { ['Content-Type'] = 'application/json' })
    return true
end

Helpers.Server = { 'IsAdmin', 'Identifier', 'DisplayName', 'RateLimit', 'Bucket', 'NotifyKey', 'Alert', 'Webhook',
    'Lock', 'IsLocked', 'IsNear', 'Role' }
