--[[
    Core.Anim (0.15.0): animations, scenarios and held props, started AND cleaned up by bp_lib.
    No other script's animation code is used: a progress bar of another resource only draws its bar.

        local id = Core.Anim.Play({ dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1,
                                    props = { { model = 'prop_tool_wrench', bone = 57005,
                                                pos = vec3(0.1, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } } })
        ...
        Core.Anim.Stop(id)

    How it runs:
      - Play never waits: it checks the spec, returns an id, and loads the dictionary and the prop
        models in a bp_lib thread. What was stopped before it loaded is never played.
      - one animation task per ped: a newer Play on the same ped takes the task over. Stopping the
        older handle then only removes its props, it never clears the newer animation.
      - one watcher thread, alive only while a handle exists: it ends handles whose ped died or is
        gone, ends timed handles (`time`), and plays a `keep` animation again when something else
        cleared it (not while the ped is ragdolled, falling or in a vehicle).
      - a stop is checked: a clip still on the ped one frame after StopAnimTask, or a scenario still on it
        after its exit (EXIT_MS), is cleared with ClearPedTasks / ClearPedTasksImmediately (only while no
        newer handle owns the ped). Scenarios have enter and exit animations of their own: for work that
        must match a bar, use dict + clip (the bar sets `duration` to its own time).
      - handles belong to the resource that made them and end when it stops (props deleted, task
        cleared). When bp_lib itself stops, every handle ends.
]]

local A = {}
Core.Anim = A

local WATCH_MS = 250     -- how often the watcher looks
local LOAD_MS  = 5000    -- how long a dictionary or a model may take to load
local BONE     = 60309   -- SKEL_L_Hand, the default prop bone (as most scripts use)
local EXIT_MS  = 1500    -- a scenario still on the ped this long after its stop is cleared at once

local handles, count, nextId = {}, 0, 0
local onPed = {}         -- [ped] = id of the handle that owns its animation task
local dictUse = {}       -- [dict] = handles using it (removed from memory at 0)
local watching = false

local function owner() return GetInvokingResource() or GetCurrentResourceName() end

local function num(v, default) v = tonumber(v) return v ~= nil and v + 0.0 or default end

local function vec(v)
    if type(v) == 'table' or type(v) == 'vector3' then
        return num(v.x or v[1], 0.0), num(v.y or v[2], 0.0), num(v.z or v[3], 0.0)
    end
    return 0.0, 0.0, 0.0
end

local function loadDict(dict, until_)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > until_ then return false end
        Wait(0)
    end
    return true
end

local function loadModel(hash, until_)
    if HasModelLoaded(hash) then return true end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > until_ then return false end
        Wait(0)
    end
    return true
end

-- The spec in one shape. Old names are read too: animDict, anim, flags (Core.ProgressBar's animation).
local function normal(o)
    local s = {
        ped = o.ped,
        dict = o.dict or o.animDict,
        clip = o.clip or o.name or o.anim,
        flag = math.floor(tonumber(o.flag or o.flags) or 49),
        blendIn = num(o.blendIn, 3.0), blendOut = num(o.blendOut, 1.0),
        duration = math.floor(tonumber(o.duration) or -1),
        rate = num(o.rate or o.playbackRate, 0.0),
        lockX = o.lockX == true, lockY = o.lockY == true, lockZ = o.lockZ == true,
        scenario = o.scenario,
        enter = o.enter ~= false and o.playEnter ~= false,
        keep = o.keep == true,
        time = tonumber(o.time),
        network = o.network ~= false,
        props = {},
    }
    if type(s.dict) ~= 'string' or s.dict == '' then s.dict = nil end
    if type(s.scenario) ~= 'string' or s.scenario == '' then s.scenario = nil end
    local list = o.props or o.prop
    if type(list) == 'table' and (list.model ~= nil) then list = { list } end
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        if type(p) == 'table' and p.model ~= nil then
            local hash = type(p.model) == 'number' and p.model or joaat(tostring(p.model))
            local x, y, z = vec(p.pos or p.coords)
            local rx, ry, rz = vec(p.rot)
            s.props[#s.props + 1] = { hash = hash, bone = math.floor(tonumber(p.bone) or BONE),
                x = x, y = y, z = z, rx = rx, ry = ry, rz = rz, order = math.floor(tonumber(p.rotOrder) or 2) }
        end
    end
    return s
end

local function startTask(h)
    local s, ped = h.spec, h.ped
    if s.dict then
        TaskPlayAnim(ped, s.dict, s.clip, s.blendIn, s.blendOut, s.duration, s.flag, s.rate, s.lockX, s.lockY, s.lockZ)
    elseif s.scenario then
        TaskStartScenarioInPlace(ped, s.scenario, 0, s.enter)
    end
end

local function playing(h)
    local s = h.spec
    if s.dict then return IsEntityPlayingAnim(h.ped, s.dict, s.clip, 3) end
    if s.scenario then return IsPedUsingScenario(h.ped, s.scenario) or IsPedActiveInScenario(h.ped) end
    return true
end

local function makeProp(h, p)
    local c = GetEntityCoords(h.ped)
    local obj = CreateObject(p.hash, c.x, c.y, c.z + 0.2, h.spec.network, true, false)
    SetModelAsNoLongerNeeded(p.hash)
    if not obj or obj == 0 then return end
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, h.ped, GetPedBoneIndex(h.ped, p.bone), p.x, p.y, p.z, p.rx, p.ry, p.rz,
        true, true, false, true, p.order, true)
    h.objects[#h.objects + 1] = obj
end

local function useDict(dict, n)
    dictUse[dict] = (dictUse[dict] or 0) + n
    if dictUse[dict] <= 0 then
        dictUse[dict] = nil
        RemoveAnimDict(dict)
    end
end

local function finish(h, now)
    if h.dead then return end
    h.dead = true
    handles[h.id] = nil
    count = count - 1
    for _, obj in ipairs(h.objects) do
        if DoesEntityExist(obj) then
            DetachEntity(obj, true, false)
            DeleteEntity(obj)
        end
    end
    h.objects = {}
    local s, ped = h.spec, h.ped
    local mine = h.started and onPed[ped] == h.id
    if onPed[ped] == h.id then onPed[ped] = nil end
    if mine and DoesEntityExist(ped) then
        if s.dict then
            StopAnimTask(ped, s.dict, s.clip, now and 8.0 or s.blendOut)
        elseif s.scenario then
            if now then ClearPedTasksImmediately(ped) else ClearPedTasks(ped) end
        end
        -- the stop is checked: a clip that is still on the ped next frame (StopAnimTask can be dropped in the
        -- frame a task changes), a scenario still on after its exit, is cleared. Never once a newer handle
        -- owns the ped's task.
        CreateThread(function()
            Wait(s.dict and 0 or EXIT_MS)
            if onPed[ped] == nil and DoesEntityExist(ped) then
                if s.dict and IsEntityPlayingAnim(ped, s.dict, s.clip, 3) then
                    ClearPedTasks(ped)
                elseif s.scenario and IsPedUsingScenario(ped, s.scenario) then
                    ClearPedTasksImmediately(ped)
                end
            end
            if h.dictHeld then useDict(s.dict, -1) end
        end)
        return
    end
    if h.dictHeld then useDict(s.dict, -1) end
end

local function watch()
    if watching then return end
    watching = true
    CreateThread(function()
        while count > 0 do
            Wait(WATCH_MS)
            local t = GetGameTimer()
            local ends = {}
            for _, h in pairs(handles) do
                if not DoesEntityExist(h.ped) or IsEntityDead(h.ped) then
                    ends[#ends + 1] = h
                elseif h.until_ and t >= h.until_ then
                    ends[#ends + 1] = h
                elseif h.spec.keep and h.started and onPed[h.ped] == h.id and not playing(h)
                    and not IsPedRagdoll(h.ped) and not IsPedFalling(h.ped) and not IsPedInAnyVehicle(h.ped, false) then
                    startTask(h)
                end
            end
            for _, h in ipairs(ends) do finish(h, false) end
        end
        watching = false
    end)
end

--- Plays an animation (dict + clip) or a scenario on a ped, with props in its hands. Every field is in
--- docs.md, "Core.Anim". -> id, or nil and 'bad_anim' / 'no_ped' / 'no_dict' / 'no_model'.
function A.Play(o)
    if type(o) ~= 'table' then return nil, 'bad_anim' end
    local s = normal(o)
    local ped = tonumber(s.ped) or PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil, 'no_ped' end
    if s.dict and (type(s.clip) ~= 'string' or s.clip == '') then return nil, 'bad_anim' end
    if not s.dict and not s.scenario and #s.props == 0 then return nil, 'bad_anim' end
    if s.dict and not DoesAnimDictExist(s.dict) then return nil, 'no_dict' end
    for _, p in ipairs(s.props) do
        if not IsModelInCdimage(p.hash) then return nil, 'no_model' end
    end
    nextId = nextId + 1
    local h = { id = nextId, owner = owner(), ped = ped, spec = s, objects = {}, started = false,
        until_ = s.time and (GetGameTimer() + s.time) or nil }
    handles[h.id] = h
    count = count + 1
    if s.dict or s.scenario then onPed[ped] = h.id end -- taken now, so an older handle's Stop leaves it alone
    watch()
    CreateThread(function()
        local until_ = GetGameTimer() + LOAD_MS
        if s.dict then
            if not loadDict(s.dict, until_) then
                if Config.Debug then print(('[bp_lib] anim %s of %s: %s did not load'):format(h.id, h.owner, s.dict)) end
                finish(h, false)
                return
            end
            if h.dead then return end
            h.dictHeld = true
            useDict(s.dict, 1)
        end
        if h.dead then return end
        if (s.dict or s.scenario) and onPed[ped] == h.id then
            h.started = true
            startTask(h)
        end
        for _, p in ipairs(s.props) do
            if h.dead then return end
            if loadModel(p.hash, until_) and not h.dead then makeProp(h, p) end
        end
    end)
    return h.id
end

local function own(id)
    local h = handles[id]
    if not h then return nil, 'no_anim' end
    if h.owner ~= owner() then return nil, 'not_owner' end
    return h
end

--- Ends an animation of the calling script: the task (only while it is still this handle's) and its
--- props. now = true snaps out at once instead of blending. -> true, or false and 'no_anim' / 'not_owner'.
function A.Stop(id, now)
    local h, err = own(id)
    if not h then return false, err end
    finish(h, now == true)
    return true
end

--- Ends every animation of the calling script. -> how many.
function A.StopAll(now)
    local me, mine = owner(), {}
    for _, h in pairs(handles) do if h.owner == me then mine[#mine + 1] = h end end
    for _, h in ipairs(mine) do finish(h, now == true) end
    return #mine
end

--- true while the handle lives (loading, playing, or holding its props).
function A.Active(id) return handles[id] ~= nil end

--- true when the handle's animation or scenario is on its ped right now.
function A.Playing(id)
    local h = handles[id]
    return h ~= nil and h.started and onPed[h.ped] == h.id and playing(h) or false
end

--- true once the handle's animation or scenario was started on its ped (false while it loads, and always
--- for a props-only handle).
function A.Started(id)
    local h = handles[id]
    return h ~= nil and h.started == true
end

--- The props a handle holds, as entities (empty while they load).
function A.Props(id)
    local h = handles[id]
    local out = {}
    for i, obj in ipairs(h and h.objects or {}) do out[i] = obj end
    return out
end

-- inside bp_lib only (Core.ProgressBar): the same Play and Stop for a given owner
function A._PlayFor(res, o)
    local id, err = A.Play(o)
    if id then handles[id].owner = res end
    return id, err
end
function A._StopAny(id, now)
    local h = handles[id]
    if h then finish(h, now == true) end
end

AddEventHandler('onClientResourceStop', function(res)
    local all = res == GetCurrentResourceName()
    local mine = {}
    for _, h in pairs(handles) do if all or h.owner == res then mine[#mine + 1] = h end end
    for _, h in ipairs(mine) do finish(h, true) end
end)

return A
