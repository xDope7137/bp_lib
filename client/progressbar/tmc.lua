-- TMC's progress bar. No animation is passed: bp_lib plays it. Contract: client/progressbar/bp.lua.
local TMC = exports.core:getCoreObject()
local M = {}

function M.Run(label, time, o)
    local p = promise.new()
    TMC.Functions.ProgressBar(function(complete) p:resolve(complete == true) end, time, label, {}, {
        canCancel = o.canCancel,
        disableMovement = o.disable.move,
        disableCarMovement = o.disable.car,
        disableMouse = o.disable.mouse,
        disableCombat = o.disable.combat,
        useWhileDead = o.useWhileDead,
    })
    return Citizen.Await(p) == true
end

function M.Cancel() end

return M
