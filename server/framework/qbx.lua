--[[
    ox_lib server callbacks run in a coroutine context where nesting `Citizen.Await(promise)`
    after `lib.callback.await` on the client can break the script host. We bridge the legacy
    `function(source, cb, ...)` style by capturing `cb(...)` synchronously and returning the
    value from the lib handler (ox_lib's supported pattern).

    ox_lib's `lib.callback.register` calls RegisterNetEvent, which APPENDS handlers rather
    than replacing them. If a consumer script restarts, the previous handler (with a now-dead
    user callback reference) stays registered and fires alongside the new one, printing
    "Execution of function reference in script host failed:" on every invocation. We work
    around this by registering the ox_lib handler exactly once per callback name and mutating
    the captured `userCb` slot on subsequent registrations.
]]
local registeredCallbacks = {}

AddEventHandler('onResourceStop', function(resourceName)
    for _, entry in pairs(registeredCallbacks) do
        if entry.owner == resourceName then
            entry.cb = nil
            entry.owner = nil
        end
    end
end)

local function registerLibCallback(name, userCb)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local entry = registeredCallbacks[name]
    if entry then
        entry.cb = userCb
        entry.owner = owner
        return
    end

    entry = { cb = userCb, owner = owner }
    registeredCallbacks[name] = entry

    lib.callback.register(name, function(source, ...)
        local currentCb = entry.cb
        if not currentCb then return nil end

        local ret
        local done = false
        local function finish(...)
            if done then return end
            done = true
            local n = select('#', ...)
            if n == 0 then
                ret = nil
            elseif n == 1 then
                ret = select(1, ...)
            else
                ret = table.pack(...)
            end
        end

        local ok, err = pcall(currentCb, source, finish, ...)
        if not ok then
            print(('^1[bp_lib]^0 RegisterCallback %q failed: %s'):format(tostring(name), tostring(err)))
            return nil
        end
        if not done then
            print(('^1[bp_lib]^0 RegisterCallback %q never called cb()'):format(tostring(name)))
            return nil
        end
        return ret
    end)
end

Framework = {
    Name = "qbx",
    RegisterCallback = function(name, cb, ...)
        registerLibCallback(name, cb)
    end,
    GetIdentifier = function(player)
        local Player = exports.qbx_core:GetPlayer(player)
        if not Player then return end
        return Player.PlayerData.citizenid
    end,
    GetIdentifierID = function(identifier)
        local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
        if not player then return false end
        return player.PlayerData.source
    end,
    GetCharName = function(player)
        local Player = exports.qbx_core:GetPlayer(player)
        if not Player then return end
        return {
            first = Player.PlayerData.charinfo.firstname,
            last = Player.PlayerData.charinfo.lastname,
            full = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
        }
    end,
    GetJobPlayerCount = function(jobs)
        local count = 0

        for _, job in pairs(jobs) do
            count += exports.qbx_core:GetDutyCountJob(job)
        end
        return count
    end,
    GetPlayers = function()
        return exports.qbx_core:GetQBPlayers()
    end,
    HasGroup = function(player, group)
        return exports.qbx_core:HasPermission(player, group)
    end,
    -- Offline lookups below read the framework's own tables through Core.Database.
    -- (0.11.0) Read by Core.Framework.Condition: qbx_core metadata isdead, inlaststand, ishandcuffed
    -- (defaults in qbx_core CreatePlayer; set by medical and police scripts through SetMetaData).
    ConditionMeta = function(player)
        local Player = exports.qbx_core:GetPlayer(player)
        local md = Player and Player.PlayerData.metadata
        if not md then return nil end
        return { dead = md.isdead == true, lastStand = md.inlaststand == true, cuffed = md.ishandcuffed == true }
    end,
    SetMetadata = function(player, key, value)
        local Player = exports.qbx_core:GetPlayer(player)
        if not Player then return end
        Player.Functions.SetMetaData(key, value)
        return true
    end,
    CharacterExists = function(identifier)
        return Core.Database.ScalarSync("SELECT 1 FROM players WHERE citizenid = ?", { identifier }) ~= nil
    end,
    -- { [identifier] = { first, last, full } } for the given identifiers, or every character when nil.
    GetCharacterNames = function(identifiers)
        local rows
        if identifiers then
            if #identifiers == 0 then return {} end
            rows = Core.Database.FetchSync(("SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)"):format(
                string.rep("?", #identifiers, ",")), identifiers)
        else
            rows = Core.Database.FetchSync("SELECT citizenid, charinfo FROM players", {})
        end

        local names = {}
        for _, row in ipairs(rows or {}) do
            local ok, charinfo = pcall(json.decode, row.charinfo or "")
            if ok and type(charinfo) == "table" then
                local first, last = charinfo.firstname or "Unknown", charinfo.lastname or ""
                names[row.citizenid] = { first = first, last = last, full = ("%s %s"):format(first, last) }
            end
        end
        return names
    end,
    -- Writes charinfo.phone. Returns true, oldNumber | false, message.
    SetPhoneNumber = function(player, number)
        if Core.Database.ScalarSync("SELECT 1 FROM players WHERE charinfo LIKE ?", { ('%%"phone":"%s"%%'):format(number) }) then
            return false, "This phone number is already registered to another citizen."
        end
        local Player = exports.qbx_core:GetPlayer(player)
        if not Player then return false, "Player could not be found." end

        local charinfo = Player.PlayerData.charinfo
        local oldNumber = charinfo.phone
        charinfo.phone = number
        Player.Functions.SetPlayerData('charinfo', charinfo)
        exports.qbx_core:Save(player)
        return true, oldNumber
    end,
    Vehicles = {
        PlateExists = function(plate)
            return Core.Database.ScalarSync("SELECT 1 FROM player_vehicles WHERE plate = ?", { plate }) ~= nil
        end,
        IsOwner = function(identifier, plate)
            return Core.Database.ScalarSync("SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?", { plate, identifier }) ~= nil
        end,
        -- { { plate, model }, ... }
        GetOwned = function(identifier)
            local list = {}
            local rows = Core.Database.FetchSync("SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ?", { identifier }) or {}
            for i = 1, #rows do
                list[i] = { plate = rows[i].plate, model = rows[i].vehicle }
            end
            return list
        end,
        -- Registers a stored vehicle in the given garage. Returns the insert id or nil.
        Add = function(player, identifier, model, plate, garage)
            local Player = exports.qbx_core:GetPlayer(player)
            return Core.Database.InsertSync([[
                INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]], { Player and Player.PlayerData.license, identifier, model, joaat(model),
                json.encode({ model = joaat(model), plate = plate }), plate, garage, 1 })
        end,
        -- Moves the plate column and the plate inside the mods JSON. Returns affected rows.
        -- A changed row fires bp_lib:plateChanged (server/helpers.lua PlateChanged).
        SetPlate = function(identifier, oldPlate, newPlate)
            local row = Core.Database.SingleSync("SELECT mods FROM player_vehicles WHERE plate = ? AND citizenid = ?", { oldPlate, identifier })
            local ok, mods = pcall(json.decode, row and row.mods or "")
            local rows
            if ok and type(mods) == "table" then
                mods.plate = newPlate
                rows = Core.Database.UpdateSync("UPDATE player_vehicles SET plate = ?, mods = ? WHERE plate = ? AND citizenid = ?",
                    { newPlate, json.encode(mods), oldPlate, identifier })
            else
                rows = Core.Database.UpdateSync("UPDATE player_vehicles SET plate = ? WHERE plate = ? AND citizenid = ?",
                    { newPlate, oldPlate, identifier })
            end
            return PlateChanged(rows, identifier, oldPlate, newPlate)
        end,
    },
    Money = {
        -- reason (0.11.0, optional, last): shown in the framework's money log and events.
        Give = function(player, amount, account, reason)

            if account == "black_money" then
                return Inventory.AddItem(player, "black_money", amount)
            end

            if account ~= "cash" and account ~= "bank" then
                return error("Wrong money account: cash or bank required.", 3)
            end

            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end

            return Player.Functions.AddMoney(account, amount, reason)
        end,
        Get = function(player, account)
            if account == "black_money" then
                local item = Inventory.GetItem(player, "black_money")
                if not item then return 0 end
                return item.count
            end

            if account ~= "cash" and account ~= "bank" then
                return error("Wrong money account: cash or bank required.", 3)
            end

            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end
            return Player.Functions.GetMoney(account)
        end,
        -- Refuses (false, takes nothing) when the balance is lower than the amount, like qb and esx:
        -- qbx_core itself lets bank go below zero (its dontAllowMinus is cash and crypto only).
        Remove = function(player, amount, account, reason)
            if account == "black_money" then
                return Inventory.RemoveItem(player, "black_money", amount)
            end

            if account ~= "cash" and account ~= "bank" then
                return error("Wrong money account: cash or bank required.", 3)
            end

            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end
            if (tonumber(Player.Functions.GetMoney(account)) or 0) < (tonumber(amount) or 0) then return false end
            return Player.Functions.RemoveMoney(account, amount, reason)
        end,
    },
    Job = {
        Set = function(player, job, grade)
            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end
            Player.Functions.SetJob(job, grade)
            return true
        end,
        Get = function(player)
            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.name
        end,
        GetLabel = function(player)
            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.label
        end,
        GetGrade = function(player)
            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.grade.level
        end,
        GetGradeLabel = function(player)
            local Player = exports.qbx_core:GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.grade.name
        end
    },
    -- (0.11.0) Asks qbx_core to write the player's row now (exports.qbx_core:Save; the
    -- write itself runs in qbx_core's own thread). false when the player is not loaded.
    SavePlayer = function(player)
        if not exports.qbx_core:GetPlayer(player) then return false end
        exports.qbx_core:Save(player)
        return true
    end,
    -- (0.11.0, E1 of bp_bank's hardening) The player's money column, written by bp_lib itself and
    -- waited for (Core.Framework.SaveMoney in server/extras.lua): the same column and the same
    -- encoding as qbx_core (storage.upsertPlayerEntity)'s own save (`money = json.encode(PlayerData.money)`, players row by
    -- citizenid). Checked once against the database before it is used; else SaveMoney asks the
    -- framework to save, as SavePlayer does.
    MoneyStore = {
        columns = "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME IN ('money', 'citizenid')",
        want = 2,
        probe = 'SELECT money FROM players WHERE money IS NOT NULL LIMIT 1',
        write = 'UPDATE players SET money = ? WHERE citizenid = ?',
        row = function(player)
            local P = exports.qbx_core:GetPlayer(player)
            if not P then return nil end
            return P.PlayerData.money, P.PlayerData.citizenid
        end,
        shape = function(v) return type(v) == 'table' and tonumber(v.cash) ~= nil and tonumber(v.bank) ~= nil end,
    },
    -- (0.11.0) Read by Core.Framework.OnCharacter (server/extras.lua). qbx_core fires
    -- QBCore:Server:PlayerLoaded(player) at the end of CreatePlayer (Login, a character switch
    -- too) and QBCore:Server:OnPlayerUnload(source) in Logout, while the player still exists.
    -- A disconnect fires neither: qbx_core's playerDropped saves and forgets the player, and
    -- extras.lua answers it from its own playerDropped handler.
    CharacterEvents = {
        loaded = {
            { name = 'QBCore:Server:PlayerLoaded', read = function(player)
                local d = type(player) == 'table' and player.PlayerData
                if d then return d.source, d.citizenid end
            end },
        },
        left = {
            { name = 'QBCore:Server:OnPlayerUnload', read = function(src) return src, 'logout' end },
        },
    },
    -- (0.11.0) Read by Core.Framework.OnMoneyChange (server/extras.lua). qbx_core fires this
    -- after a change, online players only: (source, moneyType, amount, 'add'|'remove'|'set',
    -- reason). For 'set' the amount is the new total. Offline changes fire nothing.
    -- (0.11.0) qbx_core's default sendPaycheck (config/server.lua) calls AddMoney('bank', payment)
    -- with no reason. A bank credit with no reason whose amount is exactly the character's job
    -- payment (the same lookup as qbx_core's pay(): the grade's payment, else job.payment) is
    -- reported as 'paycheck', with inferred = 'job_payment' on the change.
    InferReason = function(src, account, amount, action)
        if account ~= 'bank' or action ~= 'add' then return nil end
        local Player = exports.qbx_core:GetPlayer(src)
        local job = Player and Player.PlayerData.job
        if not job then return nil end
        local payment
        local ok, j = pcall(function() return exports.qbx_core:GetJob(job.name) end)
        if ok and type(j) == 'table' and type(j.grades) == 'table' and job.grade then
            local g = j.grades[job.grade.level]
            payment = g and g.payment
        end
        payment = tonumber(payment or job.payment)
        if payment and payment > 0 and tonumber(amount) == payment then return 'paycheck', 'job_payment' end
        return nil
    end,
    MoneyEvents = {
        { name = 'QBCore:Server:OnMoneyChange', read = function(src, account, amount, action, reason)
            return src, account, amount, action, reason
        end },
    },
    -- (0.12.0) Read by Core.Framework.JobOf / GangOf / OnJob / JobList (server/jobextras.lua).
    -- PlayerData.job / .gang: { name, label, isboss, bankAuth, onduty, grade = { name, level } }.
    -- Only the active job (Qbox's other job slots live in player_groups and give nothing here).
    JobData = {
        gangs = true,
        read = function(src, kind)
            local P = exports.qbx_core:GetPlayer(src)
            local j = P and P.PlayerData[kind]
            if type(j) ~= 'table' then return nil end
            local g = type(j.grade) == 'table' and j.grade or {}
            -- (0.12.1) a real boolean on jobs, none on gangs: `kind == 'job' and j.onduty or nil` turned
            -- false (off duty) into nil, and an off-duty player read as "no duty field"
            local duty = nil
            if kind == 'job' then duty = j.onduty == true end
            return { name = j.name, label = j.label, grade = g.level, gradeLabel = g.name, boss = j.isboss == true,
                bankAuth = j.bankAuth == true, onDuty = duty }
        end,
        list = function(kind)
            local raw = kind == 'gang' and exports.qbx_core:GetGangs() or exports.qbx_core:GetJobs()
            local out = {}
            for name, j in pairs(raw or {}) do
                local grades = {}
                for level, g in pairs(j.grades or {}) do grades[level] = { label = g.name, boss = g.isboss == true, bankAuth = g.bankAuth == true } end
                out[name] = { label = j.label, grades = grades }
            end
            return out
        end,
        events = {
            { name = 'QBCore:Server:OnJobUpdate', kind = 'job', read = function(src, job)
                return src, 'job', type(job) == 'table' and job.name or nil, type(job) == 'table' and type(job.grade) == 'table' and job.grade.level or nil
            end },
            { name = 'QBCore:Server:OnGangUpdate', kind = 'gang', read = function(src, gang)
                return src, 'gang', type(gang) == 'table' and gang.name or nil, type(gang) == 'table' and type(gang.grade) == 'table' and gang.grade.level or nil
            end },
            -- a group added, changed or removed in any slot (the active one may be among them)
            { name = 'qbx_core:server:onGroupUpdate', kind = 'job', read = function(src, name, grade) return src, nil, name, grade end },
        },
        paycheckSociety = function()
            local cfg = exports.qbx_core:GetConfig()
            local m = type(cfg) == 'table' and cfg.money
            if type(m) ~= 'table' or m.paycheckSociety == nil then return nil end
            return m.paycheckSociety == true
        end,
        -- every slot: Qbox keeps each job and gang a character holds in player_groups
        holders = {
            job = "SELECT citizenid AS cid FROM player_groups WHERE type = 'job' AND `group` = ? AND citizenid IN (?)",
            gang = "SELECT citizenid AS cid FROM player_groups WHERE type = 'gang' AND `group` = ? AND citizenid IN (?)",
        },
    },
}

local function spawnVehicleCallback(player, model, pos)
    local netId = qbx.spawnVehicle({ model = model, spawnSource = pos })
    return netId
end

lib.callback.register('bp_lib:SpawnVehicle', spawnVehicleCallback)

return Framework