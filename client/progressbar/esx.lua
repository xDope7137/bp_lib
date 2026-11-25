-- esx_progressbar: exports.esx_progressbar:Progressbar(message, length, { onFinish, onCancel }).
-- No animation is passed and the player is never frozen: bp_lib plays the animation and blocks the
-- controls itself. Contract: client/progressbar/bp.lua.
local M = {}
local function res() return Config.ProgessBarResource or 'esx_progressbar' end

function M.Run(label, time, o)
    local p = promise.new()
    local started = exports[res()]:Progressbar(label, time, {
        FreezePlayer = false,
        onFinish = function() p:resolve(true) end,
        onCancel = function() p:resolve(false) end,
    })
    if started == false then return false end
    return Citizen.Await(p) == true
end

function M.Cancel() pcall(function() exports[res()]:CancelProgressbar() end) end

return M
