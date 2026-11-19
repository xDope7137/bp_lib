--[[
    BP Development announcements (0.13.0+). Server console only, never shown to players.

    Reads https://tebex.bhavikp.in/announcements.json and prints each live entry (new script
    launches, discount codes, news) as a box in the server console: 45 s after start, then
    only entries not printed yet on each re-check. Publishing an entry needs no bp_lib release.

    An entry is skipped when its dates are not live (UTC), when this server already runs one of
    its `skip_if_running` scripts, or when it has `only_if_running` and none of those run.
    "Runs" means a started resource with that folder name or that `bp_script` fxmanifest entry.

    Server convars (server.cfg):
        set bp_announce 0             turn announcements off
        set bp_announce_hours 6       re-check interval in hours, 0 = start only

    Console command (or a principal with the command ACE):
        bp_announcements              print every live announcement again
]]

local FEED_URL = 'https://tebex.bhavikp.in/announcements.json'
local SCHEMA = 1
local MAX_SHOWN = 3

-- Links in the feed must point at these hosts, so a bad feed cannot send owners elsewhere.
local ALLOWED_HOSTS = {
    ['tebex.bhavikp.in'] = true,
    ['docs.bhavikp.in'] = true,
    ['bhavikp.in'] = true,
    ['www.youtube.com'] = true,
    ['youtu.be'] = true,
    ['discord.gg'] = true,
}

local KINDS = {
    launch   = { label = 'NEW SCRIPT', colour = '^2' },
    discount = { label = 'DISCOUNT',   colour = '^3' },
    update   = { label = 'UPDATE',     colour = '^5' },
    news     = { label = 'NEWS',       colour = '^5' },
}

local Announce = {}
local printed = {}
local live = {}

local function enabled()
    local value = GetConvar('bp_announce', 'true'):lower()
    return value ~= '0' and value ~= 'false' and value ~= 'off'
end

local function out(line)
    print(line .. '^0')
end

--- Plain one-line text: no colour codes, control characters or runs of spaces, at most `max` chars.
local function clean(value, max)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('%^%d', ''):gsub('[%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if value == '' then return nil end
    if #value > max then value = value:sub(1, max - 3) .. '...' end
    return value
end

local function safeUrl(value)
    if type(value) ~= 'string' or #value > 200 then return nil end
    local host = value:match('^https://([%w%.%-]+)$') or value:match('^https://([%w%.%-]+)[/?#]')
    if not host or not ALLOWED_HOSTS[host:lower()] then return nil end
    if value:find('[%s%c%^]') then return nil end
    return value
end

--- '2026-12-01' or '2026-12-01T18:00:00Z' -> comparable UTC string, nil when unreadable.
--- A date with no time means the start of that day for `starts`, the end of it for `ends`.
local function stamp(value, isEnd)
    if type(value) ~= 'string' then return nil end
    local d = value:match('^(%d%d%d%d%-%d%d%-%d%d)$')
    if d then return d .. (isEnd and 'T23:59:59Z' or 'T00:00:00Z') end
    local full = value:match('^(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d)Z$')
    if full then return full .. 'Z' end
    return nil
end

local function list(value)
    if type(value) == 'string' then return { value } end
    if type(value) ~= 'table' then return {} end
    local names = {}
    for _, name in ipairs(value) do
        if type(name) == 'string' and name ~= '' then names[#names + 1] = name end
    end
    return names
end

--- Started resources by folder name and by `bp_script` entry.
local function runningSet()
    local set = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            local state = GetResourceState(name)
            if state == 'started' or state == 'starting' then
                set[name] = true
                local id = GetResourceMetadata(name, 'bp_script', 0)
                if id and id ~= '' then set[id] = true end
            end
        end
    end
    return set
end

local function anyRunning(names, running)
    for _, name in ipairs(names) do
        if running[name] then return true end
    end
    return false
end

--- The entry ready to print, or nil plus why it is skipped.
function Announce.Prepare(entry, now, running)
    if type(entry) ~= 'table' then return nil, 'bad_entry' end
    local id = clean(entry.id, 64)
    local title = clean(entry.title, 80)
    if not id or not title then return nil, 'bad_entry' end
    local starts = entry.starts and stamp(entry.starts, false)
    local ends = entry.ends and stamp(entry.ends, true)
    if (entry.starts and not starts) or (entry.ends and not ends) then return nil, 'bad_date' end
    if starts and now < starts then return nil, 'not_started' end
    if ends and now > ends then return nil, 'ended' end
    if anyRunning(list(entry.skip_if_running), running) then return nil, 'already_running' end
    local only = list(entry.only_if_running)
    if #only > 0 and not anyRunning(only, running) then return nil, 'not_targeted' end
    return {
        id = id,
        kind = KINDS[entry.kind] and entry.kind or 'news',
        title = title,
        text = clean(entry.text, 400),
        code = clean(entry.code, 32),
        discount = clean(entry.discount, 40),
        url = safeUrl(entry.url),
        ends = ends and ends:sub(1, 10),
    }
end

--- Live entries from a decoded feed, in feed order, at most MAX_SHOWN.
function Announce.Select(doc, now, running)
    local picked = {}
    if type(doc) ~= 'table' or type(doc.announcements) ~= 'table' then return picked end
    for _, entry in ipairs(doc.announcements) do
        local item = Announce.Prepare(entry, now, running)
        if item then
            picked[#picked + 1] = item
            if #picked >= MAX_SHOWN then break end
        end
    end
    return picked
end

local function wrap(text, width, indent)
    local lines, line = {}, ''
    for word in tostring(text):gmatch('%S+') do
        if #line > 0 and #line + 1 + #word > width then
            lines[#lines + 1] = line
            line = word
        else
            line = #line > 0 and (line .. ' ' .. word) or word
        end
    end
    if #line > 0 then lines[#lines + 1] = line end
    return table.concat(lines, '\n' .. indent)
end

function Announce.Lines(item)
    local style = KINDS[item.kind]
    local lines = {}
    local rule = style.colour .. ('='):rep(72)
    lines[#lines + 1] = rule
    lines[#lines + 1] = ('%s[BP Development] %s^0  ^7%s'):format(style.colour, style.label, item.title)
    if item.text then lines[#lines + 1] = '  ' .. wrap(item.text, 96, '  ') end
    if item.code then
        local deal = item.discount and (' for ' .. item.discount) or ''
        local untilText = item.ends and (' (until ' .. item.ends .. ')') or ''
        lines[#lines + 1] = ('  Code: ^2%s^0%s%s'):format(item.code, deal, untilText)
    end
    if item.url then lines[#lines + 1] = '  ^4' .. item.url end
    lines[#lines + 1] = '  ^9set bp_announce 0 in server.cfg hides these notices'
    lines[#lines + 1] = rule
    return lines
end

local function show(item)
    for _, line in ipairs(Announce.Lines(item)) do out(line) end
end

local function nowUtc()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function fetch(cb)
    PerformHttpRequest(FEED_URL, function(status, body)
        if status ~= 200 or not body then return cb(nil) end
        local ok, doc = pcall(json.decode, body)
        if not ok or type(doc) ~= 'table' then return cb(nil) end
        if (tonumber(doc.schema) or 0) > SCHEMA then doc.newerSchema = true end
        cb(doc)
    end, 'GET', '', { ['Accept'] = 'application/json', ['User-Agent'] = 'bp_lib-announce/' .. SCHEMA })
end

local function check()
    if not enabled() then return end
    fetch(function(doc)
        if not doc then return end -- quiet: a missing feed is not the owner's problem
        live = Announce.Select(doc, nowUtc(), runningSet())
        for _, item in ipairs(live) do
            if not printed[item.id] then
                printed[item.id] = true
                show(item)
            end
        end
    end)
end

if IsDuplicityVersion and IsDuplicityVersion() and RegisterCommand then
    RegisterCommand('bp_announcements', function()
        fetch(function(doc)
            live = doc and Announce.Select(doc, nowUtc(), runningSet()) or live
            if #live == 0 then return out('^5[bp_lib]^0 no BP Development announcements right now') end
            for _, item in ipairs(live) do
                printed[item.id] = true
                show(item)
            end
        end)
    end, true)

    CreateThread(function()
        -- After the version notices, so it is not lost in start-up noise.
        Wait(45000)
        check()
        local hours = GetConvarInt('bp_announce_hours', 6)
        if hours <= 0 then return end
        while true do
            Wait(hours * 3600000)
            check()
        end
    end)
end

BpAnnounce = Announce
