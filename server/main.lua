local dir = "server/%s/%s.lua"
local resource = GetCurrentResourceName()

function LoadModule(module, selection)
    if not selection then
        print(("No selection provided for module: %s. Please set the correct resource or install one of the supported resources"):format(module))
        return nil
    end
    local chunk = LoadResourceFile(resource, dir:format(module, string.lower(selection)))
    if not chunk then
        return error(("Couldn't load module file: %s - %s"):format(module, string.lower(selection)), 3)
    end

    local fn, err = load(chunk, ("@@%s/server/%s/%s.lua"):format(resource, module, string.lower(selection)))

    if not fn and err then
        return error(("Error loading module: %s - %s"):format(module, string.lower(selection)), 3)
    end

    return fn()
end

function VersionCheck(repository)
	local resource = GetInvokingResource() or GetCurrentResourceName()

	local currentVersion = GetResourceMetadata(resource, 'version', 0)

	if currentVersion then
		currentVersion = currentVersion:match('%d+%.%d+%.%d+')
	end

	if not currentVersion then return print(("^1Unable to determine current resource version for '%s' ^0"):format(resource)) end

	SetTimeout(1000, function()
		PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(repository), function(status, response)
			if status ~= 200 then return end

			response = json.decode(response)
			if response.prerelease then return end

			local latestVersion = response.tag_name:match('%d+%.%d+%.%d+')
			if not latestVersion or latestVersion == currentVersion then return end

            local cv = { string.strsplit('.', currentVersion) }
            local lv = { string.strsplit('.', latestVersion) }

            for i = 1, #cv do
                local current, minimum = tonumber(cv[i]), tonumber(lv[i])

                if current ~= minimum then
                    if current < minimum then
                        return print(('^3An update is available for %s (current version: %s)\r\n%s^0'):format(resource, currentVersion, response.html_url))
                    else break end
                end
            end
		end, 'GET')
	end)
end

-- bp_lib's own update check is bp_versioncheck.lua, against tebex.bhavikp.in/versions.
-- VersionCheck stays exported as Core.Version for scripts that still pass a GitHub repo.

Core = {}
exports("Core", function()
    return Core
end)

Core.Locale = locale
loadLocales(resource)
Core.Framework = LoadModule("framework", Config.Framework)
Core.Database = LoadModule("database", Config.SQLConnector)
Core.Inventory = LoadModule("inventory", Config.Inventory)
Core.Dispatch = LoadModule("dispatch", Config.Dispatch)
Core.Phone = LoadModule("phone", Config.Phone)
Core.Weather = LoadModule("weathersync", Config.WeatherSync)
Core.Logs = LoadModule("logger", Config.Logger)
Core.EntitySync = EntitySync
Core.Groups = Groups
Core.Vehicles = VehicleIndex
Core.Version = VersionCheck
Core.LoadLocales = loadLocales
Core.GetLocales = getLocales
Core.Print = Utils.Print
Core.Utils = Utils

-- Shared helpers (shared/helpers.lua, server/helpers.lua): lib.Say, lib.Plate.Normalize ...
-- 1 = 0.10.0 helpers. 2 = 0.11.0: Amount, Lock, IsNear, Role, Money.TryRemove, OnMoneyChange,
-- SavePlayer, Database.Transaction and BatchInsert, the inventory metadata helpers.
-- 3 = 0.12.0: the job and gang reads (Framework.JobOf, GangOf, OnJob, JobList, PaycheckSociety,
-- CharactersWithJob; server/jobextras.lua).
Core.HelpersVersion = 3
for _, list in ipairs({ Helpers.Shared, Helpers.Server }) do
    for _, name in ipairs(list) do Core[name] = Helpers[name] end
end

ApplyServerCompat(Core)
AttachServerExtras(Core)
AttachJobExtras(Core)

if Core.Framework and Core.Framework.RegisterCallback then
    Core.Framework.RegisterCallback("bp_lib:GetSkillData", function(source, cb)
        local skillData = {}

        if GetResourceState("peuren_fishing") == "started" then
            local pData = exports["peuren_fishing"]:GetPlayerData(source)

            skillData[#skillData+1] = {
                locale = "peuren_fishing",
                xp = pData.Skill.xp,
                level = pData.Skill.level
            }
        end

        if GetResourceState("peuren_burglary") == "started" then
            local hacking = exports["peuren_burglary"]:GetPlayerSkill(source, "hacking")

            skillData[#skillData+1] = {
                locale = "peuren_burglary_hacking",
                xp = hacking.XP,
                level = hacking.Level
            }

            local lockpicking = exports["peuren_burglary"]:GetPlayerSkill(source, "lockpicking")

            skillData[#skillData+1] = {
                locale = "peuren_burglary_lockpicking",
                xp = lockpicking.XP,
                level = lockpicking.Level
            }

            local looting = exports["peuren_burglary"]:GetPlayerSkill(source, "looting")

            skillData[#skillData+1] = {
                locale = "peuren_burglary_looting",
                xp = looting.XP,
                level = looting.Level
            }
        end

        cb(skillData)
    end)

    Core.Framework.RegisterCallback('bp_lib:CreateEntity', function(source, cb, model, pos, args)
        if not source or not model or not pos then return cb(false) end

        local result = EntitySync.CreateEntity(model, pos, args or {})
        if not result then return cb(false) end

        cb(result)
    end)

    Core.Framework.RegisterCallback('bp_lib:CreatePed', function(source, cb, model, pos, args)
        if not source or not model or not pos then return cb(false) end

        local result = EntitySync.CreatePed(model, pos, args or {})
        if not result then return cb(false) end

        cb(result)
    end)

    Core.Framework.RegisterCallback('bp_lib:CreateVehicle', function(source, cb, model, pos, args)
        if not source or not model or not pos then return cb(false) end

        local result = EntitySync.CreateVehicle(model, pos, args or {})
        if not result then return cb(false) end

        cb(result)
    end)
end

exports('GetResourceSessionToken', function(resourceName)
    if not resourceName then return nil end

    return resourceName
end)

exports('ValidateResourceAccess', function(resourceName)
    if not resourceName then return nil end

    return resourceName
end)
