--[[
    Core.Prompt (0.15.0): a "press E" prompt at a bone of an entity, or at a place.

        local id = Core.Prompt.Add({ entity = veh, wheel = 'lf', face = 'out', label = 'Remove wheel',
                                     onPress = function(id, info) ... end })
        Core.Prompt.Update(id, { label = 'Fit wheel' })      Core.Prompt.Remove(id)

    How it runs:
      - one thread, alive only while a prompt exists. Every SCAN_MS it lists the prompts within their
        showDistance (the candidates). With none, nothing runs per frame.
      - with candidates, every frame: each candidate's point is read again (anchor.lua), ONE prompt is
        picked as live for the whole client, it is drawn and the key is read.
      - the pick: within useDistance, highest priority, then nearest. The live one keeps its place
        until another is clearly nearer for a moment, so it never flickers between two wheels.
      - a script that added a prompt is called only when something happens (onPress, onShow, onHide),
        never per frame: a call into another resource is slow, and dead once that resource stops.
      - prompts belong to the resource that added them and go when it stops.

    Keys: two slots, +bp_prompt (E) and +bp_prompt_alt (G), key mappings the player can rebind. The
    label drawn is the player's real key. On a controller the pickup / detonate controls stand in.
]]

local A, D, B = PromptAnchor, PromptDraw, PromptBox

local P = {}
Core.Prompt = P

local SCAN_MS   = 250     -- how often the candidates are listed
local COOL_MS   = 300     -- pause after a press
local SWAP_MS   = 150     -- how long another prompt must be clearly nearer before it takes over
local SWAP_GAIN = 0.85    -- "clearly nearer": under this share of the live prompt's distance
local SIGHT_MS  = 250     -- how long one line-of-sight answer is kept
local PRE_M     = 20.0    -- an entity farther than showDistance + this is not even measured
local EDGE      = 0.2     -- the mark fades in over this share of showDistance
local HORN      = 86      -- INPUT_VEH_HORN
local COST_FRAMES = 300   -- the debug read-out's own time per frame is the mean over this many frames

local prompts, total, nextId = {}, 0, 0
local cands = {}
local live = nil
local seated = false
local running = false
local debug = 0           -- bp_prompt_debug, read in every scan
local coolUntil = 0
local rival, rivalSince = nil, 0
local holdP, holdStart = nil, 0

local keyDefaults = Config.PromptKeys or {}
local keys = {
    { cmd = 'bp_prompt',     default = keyDefaults[1] or 'E', pad = 38, text = 'Interact (prompt)' },
    { cmd = 'bp_prompt_alt', default = keyDefaults[2] or 'G', pad = 47, text = 'Interact, second key (prompt)' },
}

local function xyz(v) return v.x + 0.0, v.y + 0.0, v.z + 0.0 end

local function debugLevel() return GetConvarInt('bp_prompt_debug', 0) end

-- The module's own time, for the debug read-out only (bp_prompt_debug >= 1; nothing is timed otherwise).
-- GetGameTimer is stamped once per frame (S1), so a finer clock: CfxLua's os.nanotime or os.microtime,
-- else os.clock.
local clockName, clock = 'none', nil
if os and os.nanotime then clockName, clock = 'nanotime', function() return os.nanotime() / 1e6 end
elseif os and os.microtime then clockName, clock = 'microtime', function() return os.microtime() / 1e3 end
elseif os and os.clock then clockName, clock = 'clock', function() return os.clock() * 1000.0 end end

local spent, costSince = {}, nil     -- spent: { frame, ms } per frame the module worked in, oldest first

local function spend(fc, ms)
    local last = spent[#spent]
    if last and last[1] == fc then last[2] = last[2] + ms else spent[#spent + 1] = { fc, ms } end
    while spent[1] and spent[1][1] <= fc - COST_FRAMES do table.remove(spent, 1) end
end

-- the module's mean time per game frame over the last COST_FRAMES frames (frames it did not run in count as 0)
local function cost()
    if not clock or not costSince then return nil, 0 end
    local now = GetFrameCount()
    local sum = 0.0
    for _, s in ipairs(spent) do if s[1] > now - COST_FRAMES then sum = sum + s[2] end end
    local n = math.min(COST_FRAMES, math.max(now - costSince, 1))
    return sum / n, n
end

local function timed(fn)
    if debug < 1 or not clock then
        if costSince then costSince, spent = nil, {} end
        return fn()
    end
    local fc = GetFrameCount()
    costSince = costSince or fc
    local t0 = clock()
    fn()
    spend(fc, clock() - t0)
end

-- calls back into the script that owns the prompt, in a thread of its own: the callee may wait
local function call(p, name, ...)
    local cb = p[name]
    if cb == nil then return end
    local args = table.pack(...)
    CreateThread(function()
        if p.dead or (prompts[p.id] ~= p and name ~= 'onHide') then return end
        local ok, err = pcall(cb, table.unpack(args, 1, args.n))
        if not ok and Config.Debug then print(('[bp_lib] prompt %s of %s: %s failed: %s'):format(p.id, p.owner, name, tostring(err))) end
    end)
end

local function modeOf(p)
    local m = p.mode or Config.Prompt or '3d'
    if m == 'textui' and not B.Usable() then return '3d' end
    return m == 'textui' and 'textui' or '3d'
end

-- The bound key's name from its instructional button label (S9): 't_E' is a key with a text name. A
-- 'b_' label is a glyph code: F1 to F12 read b_170 to b_181 (F10 = b_179). Any other glyph has no name
-- here: the 3D look draws it through GTA text (~INPUT_<hash>~ draws the bound key), the text box falls
-- back to the default letter.
local function keyName(raw)
    if raw:sub(1, 2) == 't_' and #raw > 2 then return raw:sub(3) end
    local n = tonumber(raw:match('^b_(%d+)$') or '')
    if n and n >= 170 and n <= 181 then return 'F' .. (n - 169) end
    return nil
end

local function readKeys()
    for _, k in ipairs(keys) do
        local label, glyph = k.default, nil
        local hash = joaat('+' .. k.cmd) | 0x80000000
        local ok, raw = pcall(GetControlInstructionalButton, 0, hash, true)
        if ok and type(raw) == 'string' then
            local name = keyName(raw)
            if name then label = name
            elseif raw:sub(1, 2) == 'b_' then glyph = ('~INPUT_%08X~'):format(hash & 0xFFFFFFFF) end
        end
        k.label, k.glyph = label, glyph
    end
end

local function setLive(p, why)
    if live == p then return end
    local old = live
    live = p
    rival = nil
    if old then
        old.shown = false
        if holdP == old then holdP = nil end
        call(old, 'onHide', old.id, why or old.why or 'other')
    end
    if p then
        p.shown, p.why = true, nil
        call(p, 'onShow', p.id)
    end
end

local function drop(p, why, quiet)
    if prompts[p.id] ~= p then return end
    p.why = why
    if quiet then p.dead = true end     -- its owner stopped: none of its callbacks is ever called again
    if live == p then
        if quiet then
            live, p.shown = nil, false
            if holdP == p then holdP = nil end
        else
            setLive(nil, why)
        end
    end
    prompts[p.id] = nil
    total = total - 1
end

-- ---------------------------------------------------------------- line of sight --

-- true when nothing stands between the camera and the prompt's point. One async ray, answer kept.
local function sight(p, t)
    local s = p.los
    if not s then
        s = { clear = false, at = -1000000 }
        p.los = s
    end
    if s.handle then
        local status, hit = GetShapeTestResult(s.handle)
        if status == 2 then
            s.clear = (hit == 0 or hit == false)
            s.handle = nil
        elseif status ~= 1 then
            s.handle = nil
        end
    end
    if not s.handle and t - s.at >= SIGHT_MS then
        local cx, cy, cz = xyz(GetFinalRenderedCamCoord())
        local dx, dy, dz = p.x - cx, p.y - cy, p.z - cz
        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
        if len > 0.2 then
            -- stop 10 cm short, so the surface the point lies on is not a hit
            local k = (len - 0.1) / len
            s.handle = StartShapeTestLosProbe(cx, cy, cz, cx + dx * k, cy + dy * k, cz + dz * k, 19, p.anchor.entity or 0, 4)
        else
            s.clear = true
        end
        s.at = t
    end
    return s.clear
end

-- ------------------------------------------------------------------------ scan --

local function scan()
    debug = debugLevel()
    local ped = PlayerPedId()
    local px, py, pz = xyz(GetEntityCoords(ped))
    local inVeh = IsPedInAnyVehicle(ped, false)
    seated = inVeh
    local fc = debug >= 1 and GetFrameCount() or nil
    local list, dead = {}, nil
    for _, p in pairs(prompts) do
        p.cand = false
        local a, why = p.anchor, nil
        if not p.enabled then
            why = 'disabled'
        elseif p.onFoot and inVeh then
            why = 'vehicle'
        else
            if p.netId then
                local ent = NetworkDoesNetworkIdExist(p.netId) and NetworkGetEntityFromNetworkId(p.netId) or 0
                if ent ~= 0 and DoesEntityExist(ent) then
                    if a.entity ~= ent then a.entity, a.model = ent, nil end
                else
                    a.entity, a.model = 0, nil
                end
            end
            local near = true
            if a.entity then
                if not DoesEntityExist(a.entity) then
                    near, why = false, 'gone'
                    if not p.netId then
                        dead = dead or {}
                        dead[#dead + 1] = p
                    end
                else
                    local ex, ey, ez = xyz(GetEntityCoords(a.entity))
                    local dx, dy, dz = ex - px, ey - py, ez - pz
                    local reach = p.showDistance + PRE_M
                    if dx * dx + dy * dy + dz * dz > reach * reach then near, why = false, 'far' end
                end
            end
            if near then
                local x, y, z, source = A.Resolve(a)
                if not x then
                    why = 'gone'
                else
                    local dx, dy, dz = x - px, y - py, z - pz
                    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                    p.x, p.y, p.z, p.source, p.dist, p.frame = x, y, z, source, d, fc
                    if d > p.showDistance then why = 'far' else
                        p.cand = true
                        list[#list + 1] = p
                    end
                end
            end
        end
        if why then p.why = why end
    end
    if dead then for _, p in ipairs(dead) do drop(p, 'gone') end end
    table.sort(list, function(p, q)
        if p.dist ~= q.dist then return p.dist < q.dist end
        return p.id < q.id
    end)
    for i = #list, D.MAX + 1, -1 do
        list[i].cand = false
        list[i].why = 'far'
        list[i] = nil
    end
    cands = list
    if live and not live.cand then setLive(nil, live.why) end
    if #list > 0 then readKeys() end
end

-- ----------------------------------------------------------------------- press --

local function fire(p)
    local t = GetGameTimer()
    if t < coolUntil then return end
    if prompts[p.id] ~= p or not p.enabled then return end
    -- the player may have stepped away since the frame that made this prompt live
    local ped = PlayerPedId()
    if p.onFoot and IsPedInAnyVehicle(ped, false) then return end
    local x, y, z, source = A.Resolve(p.anchor)
    if not x then return end
    local px, py, pz = xyz(GetEntityCoords(ped))
    local dx, dy, dz = x - px, y - py, z - pz
    if dx * dx + dy * dy + dz * dz > p.useDistance * p.useDistance then return end
    coolUntil = t + COOL_MS
    call(p, 'onPress', p.id, {
        entity = p.anchor.entity, bone = p.anchor.name, source = source, coords = vector3(x, y, z),
    })
end

local function blocked() return IsPauseMenuActive() or IsNuiFocused() end

-- One key press can come both ways: a keyboard E presses the key mapping AND the pickup control, and
-- IsUsingKeyboard(2) is false on a keyboard client until its first input (S9). The pause after a press
-- (COOL_MS) and a hold already running take the second one; tests/prompts.lua proves it ('pair').
local function press(slot)
    local p = live
    if not p or p.slot ~= slot or blocked() then return end
    if p.hold > 0 then
        if holdP ~= p then holdP, holdStart = p, GetGameTimer() end
    else
        fire(p)
    end
end

local function release(slot)
    if holdP and holdP.slot == slot then holdP = nil end
end

-- The two keys are registered at the first prompt, so a server whose scripts add none gets no
-- extra entries in the players' key settings.
local keysReady = false
local function ensureKeys()
    if keysReady then return end
    keysReady = true
    for slot, k in ipairs(keys) do
        RegisterCommand('+' .. k.cmd, function() press(slot) end, false)
        RegisterCommand('-' .. k.cmd, function() release(slot) end, false)
        RegisterKeyMapping('+' .. k.cmd, k.text, 'keyboard', k.default)
        k.label = k.default
    end
end

-- ----------------------------------------------------------------------- frame --

local function frame()
    if blocked() then
        if live then setLive(nil, 'busy') end
        B.Hide()
        return
    end
    local t = GetGameTimer()
    local fc = debug >= 1 and GetFrameCount() or nil
    local ped = PlayerPedId()
    local px, py, pz = xyz(GetEntityCoords(ped))
    -- read every frame: sitting down moves the player, and the hide must say 'vehicle', not 'far'
    seated = IsPedInAnyVehicle(ped, false)
    local best = nil
    for _, p in ipairs(cands) do
        p.ok, p.vis, p.lost = false, false, false
        if prompts[p.id] == p and p.enabled and not (p.onFoot and seated) then
            local x, y, z, source = A.Resolve(p.anchor)
            p.lost = x == nil
            if x then
                local dx, dy, dz = x - px, y - py, z - pz
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                p.x, p.y, p.z, p.source, p.dist, p.frame = x, y, z, source, d, fc
                p.vis = d <= p.showDistance and (not p.sight or sight(p, t))
                if p.vis and d <= p.useDistance then
                    p.ok = true
                    if not best or p.priority > best.priority or (p.priority == best.priority and p.dist < best.dist) then
                        best = p
                    end
                end
            end
        end
    end

    -- the live prompt holds its place until another is clearly nearer for SWAP_MS (or outranks it)
    local pick = best
    if live and best and best ~= live and live.ok and best.priority <= live.priority then
        if best.dist < live.dist * SWAP_GAIN then
            if rival ~= best then rival, rivalSince = best, t end
            if t - rivalSince < SWAP_MS then pick = live end
        else
            rival = nil
            pick = live
        end
    end
    if pick ~= live then
        local why = 'other'
        if live and not live.ok then
            if prompts[live.id] ~= live then why = 'removed'
            elseif not live.enabled then why = 'disabled'
            elseif live.onFoot and seated then why = 'vehicle'
            elseif live.lost then why = 'gone'
            elseif live.dist > live.useDistance then why = 'far'
            else why = 'sight' end
            live.why = why
        end
        setLive(pick, why)
    end

    if holdP then
        if holdP ~= live then
            holdP = nil
        elseif t - holdStart >= holdP.hold then
            local p = holdP
            holdP = nil
            fire(p)
        end
    end

    if live and not IsUsingKeyboard(2) then
        local c = keys[live.slot].pad
        if IsControlJustPressed(0, c) then press(live.slot) end
        if IsControlJustReleased(0, c) then release(live.slot) end
    end
    -- a prompt that shows in a vehicle: its key must not also sound the horn (E is the horn)
    if live and seated and not live.onFoot then DisableControlAction(0, HORN, true) end

    -- the text box look; while another script's text holds the box, the live prompt draws in 3D instead
    local liveMode = live and modeOf(live) or nil
    if liveMode == 'textui' then
        local label = live.label ~= '' and (' ' .. live.label) or ''
        if not B.Show(('[%s]%s'):format(keys[live.slot].label, label)) then liveMode = '3d' end
    else
        B.Hide()
    end
    if live then live.look = liveMode end

    D.Begin()
    local marks = Config.PromptMark ~= false
    local dots = debug >= 2
    for _, p in ipairs(cands) do
        if p.vis then
            if p == live and liveMode == '3d' then
                local hold = nil
                if holdP == p then hold = (t - holdStart) / p.hold end
                local k = keys[p.slot]
                D.Full(p.x, p.y, p.z, k.glyph or k.label, p.label, 255, hold, k.glyph ~= nil)
            elseif marks then
                local a = (p.showDistance - p.dist) / (p.showDistance * EDGE)
                if a > 1 then a = 1 end
                if a > 0 then D.Mark(p.x, p.y, p.z, math.floor(a * 220)) end
            end
            if dots then D.Dot(p.x, p.y, p.z) end
        end
    end
end

local function start()
    if running then return end
    running = true
    CreateThread(function()
        while total > 0 do
            timed(scan)
            if #cands == 0 then
                B.Hide()
                Wait(SCAN_MS)
            else
                local stop = GetGameTimer() + SCAN_MS
                repeat
                    timed(frame)
                    Wait(0)
                until GetGameTimer() >= stop or total == 0
            end
        end
        cands = {}
        B.Hide()
        running = false
    end)
end

-- ------------------------------------------------------------------ public API --

local SLOT = { e = 1, g = 2, ['1'] = 1, ['2'] = 2, alt = 2 }
local ANCHOR_FIELDS = { 'coords', 'entity', 'bone', 'wheel', 'face', 'offset', 'fallback' }

local function num(v, default, min)
    if type(v) ~= 'number' or v ~= v then return default end
    if min and v < min then return min end
    return v + 0.0
end

-- the fields that are not the anchor and not a callback
local function settle(p, o)
    if o.label ~= nil then p.label = tostring(o.label) end
    if o.key ~= nil then p.slot = SLOT[tostring(o.key):lower()] or 1 end
    if o.hold ~= nil then p.hold = num(o.hold, 0, 0) end
    if o.showDistance ~= nil then p.showDistance = num(o.showDistance, 6.0, 0.1) end
    if o.useDistance ~= nil then p.useDistance = num(o.useDistance, 1.5, 0.1) end
    if p.showDistance < p.useDistance then p.showDistance = p.useDistance end
    if o.onFoot ~= nil then p.onFoot = o.onFoot and true or false end
    if o.sight ~= nil then p.sight = o.sight and true or false; p.los = nil end
    if o.enabled ~= nil then p.enabled = o.enabled and true or false end
    if o.priority ~= nil then p.priority = num(o.priority, 0) end
    if o.mode ~= nil then p.mode = (o.mode == '3d' or o.mode == 'textui') and o.mode or nil end
end

local function buildAnchor(spec, netId)
    if netId ~= nil and A.Triple(spec.coords) == nil then
        if type(netId) ~= 'number' then return nil, 'bad_anchor' end
        local ent = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
        local s = {}
        for _, f in ipairs(ANCHOR_FIELDS) do s[f] = spec[f] end
        s.entity = (ent ~= 0 and DoesEntityExist(ent)) and ent or -1     -- -1: not here yet, the scan finds it
        return A.New(s)
    end
    if A.Triple(spec.coords) == nil then
        if type(spec.entity) ~= 'number' or not DoesEntityExist(spec.entity) then return nil, 'no_entity' end
    end
    return A.New(spec)
end

--- Adds a prompt. -> its id, or nil and 'bad_anchor' / 'no_entity' / 'no_bone' (strict only).
--- Every field is described in docs.md, "Core.Prompt".
function P.Add(o)
    if type(o) ~= 'table' then return nil, 'bad_anchor' end
    local spec = {}
    for _, f in ipairs(ANCHOR_FIELDS) do spec[f] = o[f] end
    local anchor, err = buildAnchor(spec, o.netId)
    if not anchor then return nil, err end
    if o.strict and anchor.bones and anchor.entity and DoesEntityExist(anchor.entity) then
        local _, _, _, source = A.Resolve(anchor)
        if source == 'fallback' or source == 'box' then return nil, 'no_bone' end
    end
    nextId = nextId + 1
    local p = {
        id = nextId, owner = GetInvokingResource() or GetCurrentResourceName(),
        anchor = anchor, spec = spec, netId = (anchor.entity and o.netId) or nil,
        label = '', slot = 1, hold = 0, showDistance = 6.0, useDistance = 1.5,
        onFoot = true, sight = false, enabled = true, priority = 0,
        onPress = o.onPress, onShow = o.onShow, onHide = o.onHide,
        shown = false, why = 'far', dist = math.huge,
    }
    settle(p, o)
    ensureKeys()
    prompts[p.id] = p
    total = total + 1
    start()
    return p.id
end

local function own(id)
    local p = prompts[id]
    if not p then return nil, 'no_prompt' end
    if p.owner ~= (GetInvokingResource() or GetCurrentResourceName()) then return nil, 'not_owner' end
    return p
end

--- Changes fields of a prompt of the calling script (any Add field except the callbacks and netId).
--- -> true, or false and 'no_prompt' / 'not_owner' / 'bad_anchor' / 'no_entity'.
function P.Update(id, o)
    local p, err = own(id)
    if not p then return false, err end
    if type(o) ~= 'table' then return false, 'bad_anchor' end
    local moved = false
    for _, f in ipairs(ANCHOR_FIELDS) do
        if o[f] ~= nil then
            p.spec[f] = o[f]
            moved = true
        end
    end
    if moved then
        if o.coords ~= nil then p.netId = nil end
        if o.entity ~= nil then p.netId, p.spec.coords = nil, nil end
        local anchor, why = buildAnchor(p.spec, p.netId)
        if not anchor then return false, why end
        p.anchor, p.los = anchor, nil
    end
    settle(p, o)
    return true
end

--- Removes a prompt of the calling script. -> true, or false and the reason.
function P.Remove(id)
    local p, err = own(id)
    if not p then return false, err end
    drop(p, 'removed')
    return true
end

--- Removes every prompt of the calling script. -> how many.
function P.RemoveAll()
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local mine = {}
    for _, p in pairs(prompts) do if p.owner == owner then mine[#mine + 1] = p end end
    for _, p in ipairs(mine) do drop(p, 'removed') end
    return #mine
end

--- The wheels of a vehicle, read from its bones (see anchor.lua, Wheels).
function P.Wheels(entity) return A.Wheels(entity) end

--- The world point of an anchor spec right now, with no prompt: for walking a ped to a wheel or
--- putting a prop there. -> vector3, source   or   nil, reason
function P.Point(spec)
    if type(spec) ~= 'table' then return nil, 'bad_anchor' end
    local s = {}
    for _, f in ipairs(ANCHOR_FIELDS) do s[f] = spec[f] end
    local anchor, err = buildAnchor(s, spec.netId)
    if not anchor then return nil, err end
    local x, y, z, source = A.Resolve(anchor)
    if not x then return nil, y end
    return vector3(x, y, z), source
end

--- Test read-out, only with `setr bp_prompt_debug 1` (2 also draws a magenta dot on every point).
--- -> a list, one row per prompt: id, owner, label, key, bone, source, x, y, z, frame (GetFrameCount
--- when x y z were worked out), dist, shown, cand, why, mode (asked) and look (drawn: a textui prompt
--- draws in 3D while another script's text holds the box), ms (see Cost).
function P.Debug()
    if debugLevel() < 1 then return nil end
    local ms = cost()
    local out = {}
    for _, p in pairs(prompts) do
        out[#out + 1] = {
            id = p.id, owner = p.owner, label = p.label, key = keys[p.slot].label, mode = modeOf(p),
            look = p.shown and p.look or nil,
            entity = p.anchor.entity, bone = p.anchor.name, source = p.source,
            x = p.x, y = p.y, z = p.z, frame = p.frame, dist = p.dist ~= math.huge and p.dist or nil,
            shown = p.shown, cand = p.cand or false, why = (not p.shown) and p.why or nil, ms = ms,
        }
    end
    table.sort(out, function(p, q) return p.id < q.id end)
    return out
end

--- The module's own time, only with `setr bp_prompt_debug 1`: { ms = mean per game frame over the last
--- frames (up to 300; frames it did not run in count as 0), frames = how many, clock = the timer used,
--- prompts = how many are registered }. ms is nil while nothing has been timed yet.
function P.Cost()
    if debugLevel() < 1 then return nil end
    local ms, n = cost()
    return { ms = ms, frames = n, clock = clockName, prompts = total }
end

-- a script that stops takes its prompts with it; nothing of it is called again
AddEventHandler('onClientResourceStop', function(res)
    if res == GetCurrentResourceName() then
        B.Hide()
        return
    end
    local mine = {}
    for _, p in pairs(prompts) do if p.owner == res then mine[#mine + 1] = p end end
    for _, p in ipairs(mine) do drop(p, 'removed', true) end
end)

return P
