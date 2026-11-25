-- lation_ui: exports.lation_ui:progressBar(data) -> true / false. No animation or prop is passed:
-- bp_lib plays them. Contract: client/progressbar/bp.lua.
local M = {}
local function res() return Config.ProgessBarResource or 'lation_ui' end

function M.Run(label, time, o)
    return exports[res()]:progressBar({
        label = label,
        duration = time,
        useWhileDead = o.useWhileDead,
        canCancel = o.canCancel,
        disable = o.disable,
    }) == true
end

function M.Cancel() pcall(function() exports[res()]:cancelProgress() end) end

return M
