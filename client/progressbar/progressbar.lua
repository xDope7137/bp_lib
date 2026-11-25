-- The standalone progressbar resource (qbcore-framework/progressbar and its forks):
-- exports.progressbar:Progress(data, cb(cancelled)). No animation or prop is passed: bp_lib plays them.
local M = {}
local function res() return Config.ProgessBarResource or 'progressbar' end

function M.Run(label, time, o)
    local p = promise.new()
    exports[res()]:Progress({
        name = 'bp_lib',
        duration = time,
        label = label,
        useWhileDead = o.useWhileDead,
        canCancel = o.canCancel,
        controlDisables = {
            disableMovement = o.disable.move,
            disableCarMovement = o.disable.car,
            disableMouse = o.disable.mouse,
            disableCombat = o.disable.combat,
        },
    }, function(cancelled) p:resolve(not cancelled) end)
    return Citizen.Await(p) == true
end

function M.Cancel() TriggerEvent('progressbar:client:cancel') end

return M
