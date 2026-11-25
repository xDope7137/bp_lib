-- tgiann's progress bar: exports[resource]:Progress(data, cb(cancelled)). No animation or prop is passed:
-- bp_lib plays them. Contract: client/progressbar/bp.lua.
local M = {}
local function res() return Config.ProgessBarResource or 'tgiann' end

function M.Run(label, time, o)
    local p = promise.new()
    exports[res()]:Progress({
        name = 'bp_lib',
        duration = time,
        label = label,
        useWhileDead = o.useWhileDead,
        canCancel = o.canCancel,
        controlDisables = {
            car = o.disable.car,
            move = o.disable.move,
            combat = o.disable.combat,
            mouse = o.disable.mouse,
        },
        prop = {},
        propTwo = {},
    }, function(cancelled) p:resolve(not cancelled) end)
    return Citizen.Await(p) == true
end

function M.Cancel() end

return M
