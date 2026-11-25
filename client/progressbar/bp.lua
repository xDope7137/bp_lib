--[[
    bp_lib's own progress bar (Config.ProgessBar = 'bp', the default). Drawn with natives in the look of
    Core.Prompt (Config.ProgressStyle), so it needs no NUI page and no other resource.

    The bar module contract (every file in client/progressbar/ returns this):
        Run(label, time, o) -> true when the time ran out, false when cancelled. Blocks (needs a thread).
                               o = { canCancel, useWhileDead, disable = { move, car, combat, mouse, sprint } }
                               It never plays an animation: client/progress/main.lua does that.
        Cancel()            ends the running bar, if any.
    Cancel key: +bp_progress_cancel, a key mapping players can rebind (default Config.ProgressCancelKey).
]]

local M = {}
local cur = nil
local keyReady = false

local function style()
    local s = Config.ProgressStyle or {}
    return {
        font = s.font or 4, scale = s.scale or 0.36,
        text = s.text or { 255, 255, 255 }, back = s.back or { 17, 24, 29 }, backAlpha = s.backAlpha or 220,
        track = s.track or { 255, 255, 255 }, fill = s.fill or { 86, 229, 184 },
        x = s.x or 0.5, y = s.y or 0.9, width = s.width or 0.18,
        cancelText = s.cancelText or 'Cancel',
    }
end

local function ensureKey()
    if keyReady then return end
    keyReady = true
    RegisterCommand('+bp_progress_cancel', function()
        if cur and cur.canCancel then cur.cancelled = true end
    end, false)
    RegisterCommand('-bp_progress_cancel', function() end, false)
    RegisterKeyMapping('+bp_progress_cancel', 'Cancel action (progress bar)', 'keyboard', Config.ProgressCancelKey or 'X')
end

local function text(S, str, x, y, scale, colour, centre)
    SetTextFont(S.font)
    SetTextScale(0.0, scale)
    SetTextColour(colour[1], colour[2], colour[3], 255)
    SetTextCentre(centre)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayText(x, y)
end

local function textWidth(S, str, scale)
    BeginTextCommandGetWidth('STRING')
    AddTextComponentSubstringPlayerName(str)
    SetTextFont(S.font)
    SetTextScale(0.0, scale)
    return EndTextCommandGetWidth(true)
end

local function rect(x, y, width, height, colour, alpha)
    DrawRect(x, y, width, height, colour[1], colour[2], colour[3], alpha)
end

local function draw(S, label, frac, hint)
    local x, y, w = S.x, S.y, S.width
    local left, right = x - w / 2, x + w / 2
    local top = y - 0.014 - S.scale * 0.065
    local bottom = hint and y + 0.016 + S.scale * 0.043 or y + 0.012
    rect(x, (top + bottom) / 2, w + 0.016, bottom - top, S.back, S.backAlpha)
    text(S, label, left, top + 0.003, S.scale, S.text, false)
    text(S, ('%d%%'):format(math.floor(frac * 100)), right - S.percentWidth / 2,
        top + 0.003, S.scale, S.fill, true)

    rect(x, y, w, 0.006, S.track, 48)
    local filled = w * frac
    if filled > 0 then
        rect(left + filled / 2, y, filled, 0.006, S.fill, 255)
        local tip = math.min(filled, 0.0015)
        rect(left + filled - tip / 2, y, tip, 0.006, S.text, 200)
    end
    for i = 1, 3 do
        rect(left + w * i / 4, y, 0.001, 0.006, S.back, 210)
    end
    if hint then
        text(S, hint, x, y + 0.006, S.scale * 0.8, S.text, true)
    end
end

function M.Run(label, time, o)
    if cur then return false end
    ensureKey()
    local me = { canCancel = o.canCancel == true, cancelled = false }
    cur = me
    local S = style()
    local hint
    if me.canCancel then
        local hash = joaat('+bp_progress_cancel') | 0x80000000
        hint = ('~INPUT_%08X~ %s'):format(hash & 0xFFFFFFFF, S.cancelText)
    end
    S.percentWidth = textWidth(S, '100%', S.scale)
    S.width = math.max(S.width, textWidth(S, label, S.scale) + S.percentWidth + 0.012)
    if hint then S.width = math.max(S.width, textWidth(S, hint, S.scale * 0.8)) end
    local start = GetGameTimer()
    time = math.max(tonumber(time) or 0, 0)
    while not me.cancelled do
        local frac = time > 0 and (GetGameTimer() - start) / time or 1.0
        if frac >= 1.0 then break end
        draw(S, label, frac, hint)
        Wait(0)
    end
    if cur == me then cur = nil end
    return not me.cancelled
end

function M.Cancel()
    if cur then cur.cancelled = true end
end

return M
