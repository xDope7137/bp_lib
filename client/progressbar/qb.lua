-- QBCore.Functions.Progressbar (needs the progressbar resource). No animation or prop is passed:
-- bp_lib plays them itself. Contract: client/progressbar/bp.lua.
local M = {}

function M.Run(label, time, o)
    local p = promise.new()
    QBCore.Functions.Progressbar('bp_lib', label, time, o.useWhileDead, o.canCancel, {
        disableMovement = o.disable.move,
        disableCarMovement = o.disable.car,
        disableMouse = o.disable.mouse,
        disableCombat = o.disable.combat,
    }, {}, {}, {}, function() p:resolve(true) end, function() p:resolve(false) end)
    return Citizen.Await(p) == true
end

function M.Cancel() TriggerEvent('progressbar:client:cancel') end

return M
