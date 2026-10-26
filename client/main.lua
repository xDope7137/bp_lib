local dir = "client/%s/%s.lua"
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

    local fn, err = load(chunk, ("@@%s/client/%s/%s.lua"):format(resource, module, string.lower(selection)))

    if not fn and err then
        return error(("Error loading module: %s - %s"):format(module, string.lower(selection)), 3)
    end

    return fn()
end

Core = {}
exports("Core", function()
    return Core
end)

Core.Framework = LoadModule("framework", Config.Framework)
Core.Inventory = LoadModule("inventory", Config.Inventory)
Core.VehicleKeys = LoadModule("vehiclekeys", Config.VehicleKeys)
Core.ProgressBar = LoadModule("progressbar", Config.ProgessBar)
Core.Notify = LoadModule("notifications", Config.Notifications)
Core.Weather = LoadModule("weathersync", Config.WeatherSync)
Core.Dispatch = LoadModule("dispatch", Config.Dispatch)
Core.Target = LoadModule("target", Config.Target)
Core.Input = LoadModule("input", Config.Input)
Core.Menu = LoadModule("menu", Config.Menu)
Core.Fuel = LoadModule("fuel", Config.Fuel)
Core.Poly = LoadModule("poly", Config.Poly)
Core.TextUI = LoadModule("textui", Config.TextUI)
Core.Clothing = LoadModule("clothing", Config.Clothing)
Core.VehicleProperties = LoadModule("vehicleproperties", Config.VehicleProperties)
Core.EntitySync = EntitySync
Core.LoadLocales = loadLocales
Core.GetLocales = getLocales
Core.Locale = locale
Core.Print = Utils.Print
Core.Utils = Utils

ApplyClientCompat(Core)

Core.LoadLocales()

if Core.Notify then
    RegisterNetEvent("bp_lib:notify", function(title, desc, type)
        Core.Notify(title, desc, type)
    end)
end
