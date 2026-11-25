--[[
    Core.ProgressBar / Core.Progress (0.15.0): a timed action with a bar, an animation and props.

        local done = Core.ProgressBar('Fixing engine', 5000, {
            canCancel = true, disable = { move = true, combat = true },
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
            props = { { model = 'prop_tool_wrench', bone = 57005, pos = vec3(0.1, 0, 0), rot = vec3(0, 0, 0) } },
        })

    The bar is drawn by Config.ProgessBar: bp_lib's own ('bp', the default) or another script (ox_lib,
    qb, progressbar, mythic_progbar, esx, lation_ui, tgiann, tmc). Whatever draws the bar, bp_lib does
    the rest itself, the same on every server: the animation and props start through Core.Anim and are
    cleaned up when the bar ends, the controls are blocked here every frame, and the bar ends early when
    the player dies, ragdolls, falls, swims or is cuffed (each can be allowed).
    The other script never gets the animation: its own animation code is never used.

    In step with the bar: the bar starts once the animation is on the ped (at most START_MS for the
    dictionary to load), a dict + clip animation without its own `duration` gets the bar's time (the game
    itself ends it with the bar), and it is stopped the moment the bar ends.
]]

local START_MS = 1000

local bar = nil
do
    local ok, m = pcall(LoadModule, 'progressbar', Config.ProgessBar or 'bp')
    if ok and type(m) == 'table' and m.Run then bar = m
    else
        if Config.ProgessBar and Config.ProgessBar ~= 'bp' then
            print(('^3[bp_lib] Progress bar "%s" could not be used (%s), bp_lib\'s own bar is used instead.^0')
                :format(tostring(Config.ProgessBar), ok and 'bad module' or tostring(m)))
        end
        bar = LoadModule('progressbar', 'bp')
    end
end

local P = {}
local cur = nil

-- INPUT_ numbers, as ox_lib blocks them
local MOUSE  = { 1, 2, 106 }
local MOVE   = { 21, 30, 31, 36 }
local CAR    = { 63, 64, 71, 72, 75 }
local COMBAT = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 257, 263, 264 }

local function owner() return GetInvokingResource() or GetCurrentResourceName() end

-- Both option styles in one shape: { disable = {...} } and the old disableMovement / disableCarMovement /
-- disableMouse / disableCombat.
local function normal(o)
    local d = type(o.disable) == 'table' and o.disable or {}
    return {
        canCancel = o.canCancel == true,
        useWhileDead = o.useWhileDead == true,
        allowRagdoll = o.allowRagdoll == true,
        allowFalling = o.allowFalling == true,
        allowSwimming = o.allowSwimming == true,
        allowCuffed = o.allowCuffed == true,
        disable = {
            move = d.move == true or o.disableMovement == true,
            car = d.car == true or o.disableCarMovement == true,
            mouse = d.mouse == true or o.disableMouse == true,
            combat = d.combat == true or o.disableCombat == true,
            sprint = d.sprint == true,
        },
    }
end

-- The animation part of the options: anim (Core.Anim spec) or the old animation { animDict, anim, flags },
-- a scenario, prop / props. -> a Core.Anim spec, or nil when there is nothing to play.
local function animSpec(o)
    local a = type(o.anim) == 'table' and o.anim or type(o.animation) == 'table' and o.animation or nil
    local s = {}
    if a then for k, v in pairs(a) do s[k] = v end end
    s.scenario = s.scenario or o.scenario
    s.props = s.props or s.prop or o.props or o.prop
    s.prop = nil
    local hasProps = type(s.props) == 'table' and next(s.props) ~= nil
    if not (s.dict or s.animDict) and not s.scenario and not hasProps then return nil end
    return s
end

local function interrupted(o)
    local ped = PlayerPedId()
    if not o.useWhileDead and IsEntityDead(ped) then return true end
    if not o.allowRagdoll and IsPedRagdoll(ped) then return true end
    if not o.allowFalling and IsPedFalling(ped) then return true end
    if not o.allowSwimming and IsPedSwimming(ped) then return true end
    if not o.allowCuffed and IsPedCuffed(ped) then return true end
    return false
end

local function block(list) for _, c in ipairs(list) do DisableControlAction(0, c, true) end end

local function controls(o)
    local d = o.disable
    if d.mouse then block(MOUSE) end
    if d.move then block(MOVE) elseif d.sprint then DisableControlAction(0, 21, true) end
    if d.car then block(CAR) end
    if d.combat then
        block(COMBAT)
        DisablePlayerFiring(PlayerId(), true)
    end
end

--- Runs a bar. Blocks the calling thread until it ends. -> true when it ran to the end, false when it
--- was cancelled, interrupted, or another bar was already running.
function P.Run(label, time, options)
    options = type(options) == 'table' and options or {}
    if cur then return false end
    local o = normal(options)
    if interrupted(o) then return false end
    local me = { over = false, done = false, cancelled = false }
    cur = me
    local spec = animSpec(options)
    time = math.floor(tonumber(time) or 0)
    if spec and (spec.dict or spec.animDict) and spec.duration == nil then spec.duration = time end
    local animId = spec and Core.Anim._PlayFor(owner(), spec) or nil
    if animId and (spec.dict or spec.animDict or spec.scenario) then
        local until_ = GetGameTimer() + START_MS
        while Core.Anim.Active(animId) and not Core.Anim.Started(animId) and GetGameTimer() < until_ do
            controls(o)
            Wait(0)
        end
    end
    CreateThread(function()
        local ok, done = pcall(bar.Run, tostring(label or ''), time, o)
        if not ok and Config.Debug then print(('[bp_lib] progress bar %s failed: %s'):format(tostring(Config.ProgessBar), tostring(done))) end
        me.done = ok and done == true
        me.over = true
    end)
    while not me.over and not me.cancelled do
        controls(o)
        if interrupted(o) then
            me.cancelled = true
            pcall(bar.Cancel)
        end
        Wait(0)
    end
    if cur == me then cur = nil end
    if animId then Core.Anim._StopAny(animId) end
    return me.done and not me.cancelled
end

--- Ends the running bar as cancelled (its Run returns false).
function P.Cancel()
    if not cur then return false end
    cur.cancelled = true
    pcall(bar.Cancel)
    return true
end

--- true while a bar runs.
function P.Active() return cur ~= nil end

Core.Progress = P
Core.ProgressBar = P.Run

return P
