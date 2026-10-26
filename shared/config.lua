Config = {}

Config.Debug = false -- Adds additional prints and enables all other resource debug options | true or false
Config.Language = 'en' -- Language file name, this means, that it will only load files from script locales folders that contain this name, 
                       -- if this is an invalid locale name on a resource it will default to english

Config.Framework = 'auto'
Config.IsOldESX = false --This option is needed if you are running an older version of ESX
Config.FrameworkResource = nil -- Framework resource name (auto-filled when using 'auto')
--SUPPORTED FRAMEWORK NAMES TO PUT IN: Config.Framework = ""
--[[
    'auto' - (RECOMMENDED) Scans your server and picks the correct framework automatically
    esx    - (default resource name: es_extended)
    qb     - (default resource name: qb-core)
    qbx    - (Uncomment qbx_core export in bp_lib/fxmanifest.lua file)
    ox     - (Uncomment ox_core imports in fxmanifest.lua file)
    tmc    - (default resource name: core)
]]

Config.SQLConnector = 'auto'
--SUPPORTED SQL CONNECTOR NAMES TO PUT IN: Config.SQLConnector = ""
--[[
    'auto'       - (RECOMMENDED) Scans your server and picks the correct SQL connector automatically
    oxmysql
    mysql-async
    ghmattimysql
]]

Config.Inventory = 'auto'
Config.InventoryResource = nil -- The inventory system folder name that you're using (auto-filled when using 'auto')
Config.CarryItemsEnabled = true -- Should the Carry Items system be enabled
--SUPPORTED INVENTORY SCRIPT NAMES TO PUT IN: Config.Inventory = ""
--[[
    'auto'            - (RECOMMENDED) Scans your server and picks the correct inventory automatically
    tmc
    avp_inv_4
    mf-inventory
    esx_inventory
    qb-inventory
    qb-inventory-new  (for new versions of qb-inventory)
    ox_inventory
    qs-inventory
    tgiann-inventory
    codem-inventory
    origen_inventory
    jaksam_inventory
]]

Config.Target = 'auto'
Config.TargetResource = nil -- The target system folder name that you're using (auto-filled when using 'auto')
--SUPPORTED TARGET SCRIPT NAMES TO PUT IN: Config.Target  = ""
--[[
    'auto'    - (RECOMMENDED) Scans your server and picks the correct target system automatically
    qb-target
    ox_target
    qtarget
]]

Config.ProgessBar = 'auto'
Config.ProgessBarResource = nil -- The progress bar system folder name that you're using (auto-filled when using 'auto')
--SUPPORTED PROGRESS BAR SCRIPT NAMES TO PUT IN: Config.ProgessBar = ""
--[[
    'auto'  - (RECOMMENDED) Scans your server and picks the correct progress bar automatically
    tmc
    ox_lib  - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
    qb
    tgiann
]]

Config.Menu = 'auto'
Config.MenuResource = nil -- The menu system folder name that you're using (auto-filled when using 'auto')
--SUPPORTED MENU SCRIPT NAMES TO PUT IN: Config.Menu = ""
--[[
    'auto'          - (RECOMMENDED) Scans your server and picks the correct menu system automatically
    tmc
    ps-ui
    ox_lib          - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
    qb
    nh-context
    esx_menu_default
    esx_context
]]

Config.Input = 'auto'
Config.InputResource = nil -- The input system folder name that you're using (auto-filled when using 'auto')
--SUPPORTED INPUT SCRIPT NAMES TO PUT IN: Config.Input = ""
--[[
    'auto'    - (RECOMMENDED) Scans your server and picks the correct input system automatically
    ox_lib    - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
    qb-input
    nh-keyboard
]]

Config.TextUI = 'auto'
Config.TextUIResource = nil -- The TextUI system folder name that you're using (auto-filled when using 'auto')
--SUPPORTED TEXT UI SCRIPT NAMES TO PUT IN: Config.TextUI = ""
--[[
    'auto'      - (RECOMMENDED) Scans your server and picks the correct TextUI system automatically
    ps-ui
    ox_lib      - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
    okokTextUI
    jg-textui
    qb
]]

Config.Poly = 'auto'
Config.PolyResource = nil -- The Polyzone system folder name that you're using (auto-filled when using 'auto')
--SUPPORTED ZONE SCRIPT NAMES TO PUT IN: Config.Poly = ""
--[[
    'auto'    - (RECOMMENDED) Scans your server and picks the correct zone system automatically
    polyzone
    ox_lib    - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
    qb
]]

Config.Notifications = 'auto'
Config.NotificationsResource = nil -- The notification system folder name that you're using (auto-filled when using 'auto')
--SUPPORTED NOTIFICATION SCRIPT NAMES TO PUT IN: Config.Notifications = ""
--[[
    'auto'       - (RECOMMENDED) Scans your server and picks the correct notification system automatically
    tmc
    peuren_notify
    ps-ui
    ox_lib       - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
    qb
    esx
    okok
    mythic
    s1n_notify
    tgiann
    k5_notify
    vms_notifyv2
]]

Config.WeatherSync = 'auto'
Config.WeatherSyncResource = nil -- The weather sync system resource folder name (auto-filled when using 'auto')
--SUPPORTED WEATHER SYNC SCRIPT NAMES TO PUT IN: Config.WeatherSync = ""
--[[
    'auto'             - (RECOMMENDED) Scans your server and picks the correct weather sync automatically
    tmc
    renewed-weathersync
    qb-weathersync
    cd_easytime
    av_weather
    cs_weather
]]

Config.Dispatch = 'auto'
Config.DispatchResource = nil -- The dispatch system resource folder name (auto-filled when using 'auto')
--SUPPORTED DISPATCH SCRIPT NAMES TO PUT IN: Config.Dispatch = ""
--[[
    'auto'       - (RECOMMENDED) Scans your server and picks the correct dispatch system automatically
    tmc
    p_mdt
    lb-tablet
    codem-dispatch
    fea-dispatch
    origen_police
    rcore_dispatch
    cd_dispatch
    core_dispatch
    default      - standalone version, not recommended for production servers without code changes
    outwalter
    ps-dispatch
    qs-dispatch
    tk_dispatch
    redutzu-mdt
    op-dispatch
]]

Config.Fuel = 'auto'
Config.FuelResource = nil -- The fuel system resource folder name (auto-filled when using 'auto')
--SUPPORTED FUEL SCRIPT NAMES TO PUT IN: Config.Fuel = ""
--[[
    'auto'          - (RECOMMENDED) Scans your server and picks the correct fuel system automatically
    tmc
    okokGasStation
    LegacyFuel
    ox_fuel
    lj-fuel
    ti_fuel
    ND_fuel
    ps-fuel
    esx-sna-fuel
    cdn-fuel
    FRFuel
    renewed-fuel
    xFuel
    rcore_fuel
    qs-fuelstations
    lc_fuel
    sgx-fuel
    frkn-fuelstationv4
    lyre_fuel
]]

Config.VehicleKeys = 'auto'
Config.VehicleKeysResource = nil -- The vehicle key system resource folder name (auto-filled when using 'auto')
--SUPPORTED VEHICLE KEY SCRIPT NAMES TO PUT IN: Config.VehicleKeys = ""
--[[
    'auto'             - (RECOMMENDED) Scans your server and picks the correct vehicle key system automatically
    jaksam
    tmc
    MrNewbVehicleKeys
    mk_vehiclekeys
    okokGarage
    qs-vehiclekeys
    wasabi_carlock
    cd_garage
    t1ger_keys
    F_RealCarKeysSystem 
    fivecode_carkeys
    qb-vehiclekeys
    stasiek_vehiclekeys
    ti_vehicleKeys
    vehicles_keys
    xd_locksystem
    tgiann-hotwire
    dusa_vehiclekeys
    Renewed-Vehiclekeys
    ak47_vehiclekeys
]]

Config.Clothing = 'auto'
Config.ClothingResource = nil -- The clothing system resource folder name (auto-filled when using 'auto')
--SUPPORTED CLOTHING SCRIPT NAMES TO PUT IN: Config.Clothing = ""
--[[
    'auto'           - (RECOMMENDED) Scans your server and picks the correct clothing system automatically
    peuren_appearance
    tmc
    crm-appearance
    codem-appearance
    tgiann-clothing
    esx_skin
    fivem-appearance
    illenium-appearance
    ox_appearance
    qb-clothing
    rcore_clothing
]]

Config.VehicleProperties = 'auto' -- Recommended to use ox_lib for vehicle properties, but you can use other resources as well.
Config.VehiclePropertiesResource = nil -- The vehicle properties system resource folder name (auto-filled when using 'auto')
--SUPPORTED VEHICLE PROPERTIES SCRIPT NAMES TO PUT IN: Config.VehicleProperties = ""
--[[
    'auto' - (RECOMMENDED) Scans your server and picks the correct vehicle properties system automatically
    ox_lib - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
    qb
    qbx
    esx

]]

Config.Logger = 'auto' -- Logger system resource name
--SUPPORTED LOGGER SCRIPT NAMES TO PUT IN: Config.Logger = ""
--[[
    'auto'  - (RECOMMENDED) Scans your server and picks the correct logger automatically
    discord
    ox_lib  - (Uncomment ox_lib import in bp_lib/fxmanifest.lua file)
]]


Config.SkillMenu = { -- Configuration for skill menu.
    Enabled = true, -- Should the Skill Menu be enabled
    Command = "skills" -- The comand which opens the skill menu. Set this to false to disable it. Skill menu can be also opened by using exports["bp_lib"]:OpenSkillMenu()
}

Config.Groups = { -- Configuration for multiplier jobs
    MemberLimit = 4,--Default maximum group member amount in a group
    Timeout = { min = 0, sec = 30 }, --The time in which the group owner has to return to game before assigning a new group leader
    password = {
        type = 'number',--number or char
        length = 6--code length
    }
}

--Enable this if you know how to use it, otherwise leave it disabled (Extra security feature)
Config.EnableVehicleWhiteList = false -- Enable vehicle whitelist for jobs, this will only allow vehicles that are in the job vehicle list to be spawned


-- !!! DO NOT TOUCH ANYTHING BELOW THIS UNLESS YOU KNOW WHAT YOU ARE DOING !!!

-- Sentinel value: any field set to this string (or left nil) will be auto-scanned.
local AUTO = 'auto'

local function ShouldAutoDetect(value)
    return value == nil or value == AUTO
end

local function AutoOption(module, resources)
    if type(resources) == "string" then
        resources = { resources }
    end

    return {
        module = module,
        resources = resources or { module }
    }
end

local function DebugPrint(message)
    if not Config.Debug then
        return
    end

    if Utils and Utils.Print then
        Utils.Print(message)
    else
        print(message)
    end
end

local function IsResourceActive(name)
    local state = GetResourceState(name)

    if not state then
        return false
    end

    return state == "started" or state == "starting" or state == "running" or state == "initializing"
end

local function DetectResource(option)
    for _, resourceName in ipairs(option.resources) do
        if IsResourceActive(resourceName) then
            return resourceName
        end
    end
end

local function AutoDetectConfig()
    local categories = {
        { key = "Framework", resourceKey = "FrameworkResource", options = {
            AutoOption("esx", { "es_extended", "esx" }),
            AutoOption("qbx", { "qbx_core" }),
            AutoOption("qb", { "qb-core" }),
            AutoOption("ox", { "ox_core" }),
            AutoOption("tmc", { "core" })
        }},
        { key = "SQLConnector", options = {
            AutoOption("oxmysql"),
            AutoOption("mysql-async"),
            AutoOption("ghmattimysql")
        }},
        { key = "Inventory", resourceKey = "InventoryResource", options = {
            AutoOption("ox_inventory"),
            AutoOption("qb-inventory-new", { "qb-inventory", "qb-inventory-new" }),
            AutoOption("qb-inventory", { "qb-inventory", "qb" }),
            AutoOption("esx_inventory"),
            AutoOption("mf-inventory"),
            AutoOption("avp_inv_4"),
            AutoOption("qs-inventory"),
            AutoOption("tgiann-inventory"),
            AutoOption("codem-inventory"),
            AutoOption("origen_inventory"),
            AutoOption("tmc"),
            AutoOption("jaksam_inventory")
        }},
        { key = "Target", resourceKey = "TargetResource", options = {
            AutoOption("ox_target"),
            AutoOption("qb-target"),
            AutoOption("qtarget")
        }},
        { key = "ProgessBar", resourceKey = "ProgessBarResource", options = {
            AutoOption("ox_lib"),
            AutoOption("qb", { "qb-core" }),
            AutoOption("tgiann"),
            AutoOption("tmc")
        }},
        { key = "Menu", resourceKey = "MenuResource", options = {
            AutoOption("ox_lib"),
            AutoOption("ps-ui"),
            AutoOption("qb", { "qb-core" }),
            AutoOption("nh-context"),
            AutoOption("esx_menu_default"),
            AutoOption("esx_context"),
            AutoOption("tmc")
        }},
        { key = "Input", resourceKey = "InputResource", options = {
            AutoOption("ox_lib"),
            AutoOption("qb-input"),
            AutoOption("ps-ui")
        }},
        { key = "TextUI", resourceKey = "TextUIResource", options = {
            AutoOption("ox_lib"),
            AutoOption("ps-ui"),
            AutoOption("okokTextUI"),
            AutoOption("jg-textui"),
            AutoOption("qb", { "qb-core" })
        }},
        { key = "Poly", resourceKey = "PolyResource", options = {
            AutoOption("ox_lib"),
            AutoOption("polyzone"),
            AutoOption("okokTextUI"),
            AutoOption("qb", { "qb-core" })
        }},
        { key = "Notifications", resourceKey = "NotificationsResource", options = {
            AutoOption("ox_lib"),
            AutoOption("tmc"),
            AutoOption("peuren_notify"),
            AutoOption("ps-ui"),
            AutoOption("qb", { "qb-core" }),
            AutoOption("esx", { "es_extended" }),
            AutoOption("okok"),
            AutoOption("mythic"),
            AutoOption("s1n_notify"),
            AutoOption("tgiann"),
            AutoOption("k5_notify"),
            AutoOption("vms_notifyv2")
        }},
        { key = "WeatherSync", options = {
            AutoOption("tmc"),
            AutoOption("renewed-weathersync"),
            AutoOption("qb-weathersync"),
            AutoOption("cd_easytime"),
            AutoOption("av_weather"),
            AutoOption("cs_weather")
        }},
        { key = "Dispatch", resourceKey = "DispatchResource", options = {
            AutoOption("cd_dispatch"),
            AutoOption("core_dispatch"),
            AutoOption("rcore_dispatch"),
            AutoOption("codem-dispatch"),
            AutoOption("fea-dispatch"),
            AutoOption("origen_police"),
            AutoOption("outwalter"),
            AutoOption("ps-dispatch"),
            AutoOption("qs-dispatch"),
            AutoOption("tk_dispatch"),
            AutoOption("redutzu-mdt"),
            AutoOption("tmc"),
            AutoOption("op-dispatch"),
            AutoOption("lb-tablet"),
            AutoOption("p_mdt")
        }},
        { key = "Fuel", resourceKey = "FuelResource", options = {
            AutoOption("LegacyFuel"),
            AutoOption("ox_fuel"),
            AutoOption("lj-fuel"),
            AutoOption("ti_fuel"),
            AutoOption("ND_Fuel", { "ND_Fuel", "ND_fuel" }),
            AutoOption("ps-fuel"),
            AutoOption("esx-sna-fuel"),
            AutoOption("cdn-fuel"),
            AutoOption("FRFuel"),
            AutoOption("renewed-fuel"),
            AutoOption("xFuel"),
            AutoOption("rcore_fuel"),
            AutoOption("qs-fuelstations"),
            AutoOption("lc_fuel"),
            AutoOption("sgx-fuel"),
            AutoOption("frkn-fuelstationv4"),
            AutoOption("okokGasStation"),
            AutoOption("tmc"),
            AutoOption("lyre_fuel")
        }},
        { key = "VehicleKeys", resourceKey = "VehicleKeysResource", options = {
            AutoOption("qb-vehiclekeys"),
            AutoOption("qs-vehiclekeys"),
            AutoOption("cd_garage"),
            AutoOption("okokGarage"),
            AutoOption("wasabi_carlock"),
            AutoOption("t1ger_keys"),
            AutoOption("MrNewbVehicleKeys"),
            AutoOption("mk_vehiclekeys"),
            AutoOption("jaksam"),
            AutoOption("F_RealCarKeysSystem"),
            AutoOption("fivecode_carkeys"),
            AutoOption("stasiek_vehiclekeys"),
            AutoOption("ti_vehicleKeys"),
            AutoOption("vehicles_keys"),
            AutoOption("xd_locksystem"),
            AutoOption("tgiann-hotwire"),
            AutoOption("dusa_vehiclekeys"),
            AutoOption("Renewed-Vehiclekeys"),
            AutoOption("ak47_vehiclekeys"),
            AutoOption("tmc")
        }},
        { key = "Clothing", resourceKey = "ClothingResource", options = {
            AutoOption("peuren_appearance"),
            AutoOption("qb-clothing"),
            AutoOption("codem-appearance"),
            AutoOption("crm-appearance"),
            AutoOption("tgiann-clothing"),
            AutoOption("esx_skin"),
            AutoOption("fivem-appearance"),
            AutoOption("illenium-appearance"),
            AutoOption("ox_appearance"),
            AutoOption("rcore_clothing"),
            AutoOption("tmc")
        }},
        { key = "VehicleProperties", resourceKey = "VehiclePropertiesResource", options = {
            AutoOption("ox_lib"),
            AutoOption("qb", { "qb-core" }),
            AutoOption("qbx", { "qbx_core" }),
            AutoOption("esx", { "es_extended" })
        }},
        { key = "Logger", options = {
            AutoOption("ox_lib"),
            AutoOption("discord")
        }}
    }

    Config.AutoDetected = Config.AutoDetected or {}

    -- Track which keys were explicitly set to 'auto' so we can warn on miss
    local explicitAuto = {}

    for _, category in ipairs(categories) do
        local currentValue = Config[category.key]

        if ShouldAutoDetect(currentValue) then
            -- Record if the customer explicitly wrote 'auto' (vs just leaving it nil)
            if currentValue == AUTO then
                explicitAuto[category.key] = true
            end

            -- Run detection
            for _, option in ipairs(category.options) do
                local detectedResource = DetectResource(option)

                if detectedResource then
                    Config[category.key] = option.module

                    if category.resourceKey and (Config[category.resourceKey] == nil or Config[category.resourceKey] == "") then
                        Config[category.resourceKey] = detectedResource
                    end

                    Config.AutoDetected[category.key] = option.module

                    DebugPrint(string.format("[bp_lib] Auto-detected %s -> %s (%s)", category.key, option.module, detectedResource))
                    break
                end
            end

            -- Warn when the customer explicitly requested 'auto' but nothing was found
            if explicitAuto[category.key] and Config[category.key] == AUTO then
                print(string.format("^3[bp_lib] WARNING: Config.%s is set to 'auto' but no supported resource was detected. The module will be disabled.^0", category.key))
                Config[category.key] = nil -- normalise to nil so LoadModule skips gracefully
            end
        end
    end

    -- Dispatch special-case: fall back to 'default' (built-in) when still unresolved
    if ShouldAutoDetect(Config.Dispatch) or Config.Dispatch == AUTO then
        Config.Dispatch = "default"

        if Config.DispatchResource == nil or Config.DispatchResource == "" then
            Config.DispatchResource = GetCurrentResourceName and GetCurrentResourceName() or "bp_lib"
        end

        Config.AutoDetected.Dispatch = "default"
        DebugPrint("[bp_lib] Auto-detected Dispatch -> default (fallback)")
    end

    -- ── Startup resolution summary (always visible, not gated by Debug) ──────
    local resourceName = (GetCurrentResourceName and GetCurrentResourceName()) or "bp_lib"
    print(string.format("^5[%s] ^2Auto-configuration complete:^0", resourceName))

    local summaryOrder = {
        "Framework", "SQLConnector", "Inventory", "Target", "ProgessBar",
        "Menu", "Input", "TextUI", "Poly", "Notifications",
        "WeatherSync", "Dispatch", "Fuel", "VehicleKeys",
        "Clothing", "VehicleProperties", "Logger"
    }

    for _, key in ipairs(summaryOrder) do
        local value = Config[key]
        local wasAuto = Config.AutoDetected[key] ~= nil

        if value == nil then
            if explicitAuto[key] then
                -- Already warned above; show as disabled in summary
                print(string.format("  ^1%-20s -> NOT FOUND (disabled)^0", key))
            end
            -- silently skip keys that were never set and still nil (user intentionally omitted)
        elseif wasAuto then
            print(string.format("  ^2%-20s -> %s ^8(auto-detected)^0", key, value))
        else
            print(string.format("  ^7%-20s -> %s ^8(manual)^0", key, value))
        end
    end
end

AutoDetectConfig()

exports("GetConfig", function()
    return Config
end)