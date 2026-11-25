-- ox_lib's bar (lib.progressBar). bp_lib plays and clears the animation itself (client/progress/main.lua):
-- ox_lib gets no anim and no prop. Contract: client/progressbar/bp.lua.
local M = {}

function M.Run(label, time, o)
    return lib.progressBar({
        duration = time,
        label = label,
        useWhileDead = o.useWhileDead,
        allowRagdoll = o.allowRagdoll,
        allowFalling = o.allowFalling,
        allowSwimming = o.allowSwimming,
        allowCuffed = o.allowCuffed,
        canCancel = o.canCancel,
        disable = o.disable,
    }) == true
end

function M.Cancel()
    if lib.progressActive() then pcall(lib.cancelProgress) end
end

return M
