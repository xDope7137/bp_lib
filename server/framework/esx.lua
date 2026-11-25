ESX = nil

if Config.IsOldESX then 
    TriggerEvent('esx:getSharedObject', function(obj) 
        ESX = obj 
    end)
else 
    ESX = exports[Config.FrameworkResource]:getSharedObject()
end

Framework = {
    Name = "esx",
    RegisterCallback = function(name, cb, ...)
        ESX.RegisterServerCallback(name, cb, ...)
    end,
    GetIdentifier = function(player)
        local xPlayer = ESX.GetPlayerFromId(player)
        if not xPlayer then return end
        return xPlayer.getIdentifier()
    end,
    GetIdentifierID = function(identifier)
        local player = ESX.GetPlayerFromIdentifier(identifier)
        if not player then return false end
        return player.playerId
    end,
    GetCharName = function(player)
        local xPlayer = ESX.GetPlayerFromId(player)
        if not xPlayer then return end
        local firstname, lastname = string.match(xPlayer.getName(), "([^%s]+) ([^%s]+)")
        return {
            first = firstname,
            last = lastname,
            full = xPlayer.getName()
        }
    end,
    GetJobPlayerCount = function(jobs)
        local count = 0

        if jobs ~= nil and type(jobs) ~= "table" then
            jobs = { jobs }
        end

        for id, _ in pairs(ESX.GetPlayers()) do 
            local xPlayer = ESX.GetPlayerFromId(id)
            if not xPlayer then goto continue end

            for _, job in pairs(jobs) do 
                if xPlayer.getJob().name == job then 
                    count += 1
                end
            end
            :: continue ::
        end
        return count
    end,
    GetPlayers = function()
        return ESX.GetPlayers()
    end,
    HasGroup = function(player, group)
        local xPlayer = ESX.GetPlayerFromId(player)
        if not xPlayer then return end
        return xPlayer.getGroup() == group
    end,
    -- Offline lookups below read the framework's own tables through Core.Database.
    -- (0.11.0) ESX keeps no dead, last stand or cuffed field on the server (esx_ambulancejob
    -- writes users.is_dead, esx_policejob keeps cuffs on the client): Core.Framework.Condition
    -- reads state bags and health only.
    ConditionMeta = function() return nil end,
    SetMetadata = function(player, key, value)
        local xPlayer = ESX.GetPlayerFromId(player)
        if not xPlayer or not xPlayer.setMeta then return end
        xPlayer.setMeta(key, value)
        return true
    end,
    CharacterExists = function(identifier)
        return Core.Database.ScalarSync("SELECT 1 FROM users WHERE identifier = ?", { identifier }) ~= nil
    end,
    -- { [identifier] = { first, last, full } } for the given identifiers, or every character when nil.
    GetCharacterNames = function(identifiers)
        local rows
        if identifiers then
            if #identifiers == 0 then return {} end
            rows = Core.Database.FetchSync(("SELECT identifier, firstname, lastname FROM users WHERE identifier IN (%s)"):format(
                string.rep("?", #identifiers, ",")), identifiers)
        else
            rows = Core.Database.FetchSync("SELECT identifier, firstname, lastname FROM users", {})
        end

        -- users rows without a created character have NULL names.
        local names = {}
        for _, row in ipairs(rows or {}) do
            local first, last = row.firstname or "Unknown", row.lastname or ""
            names[row.identifier] = { first = first, last = last, full = ("%s %s"):format(first, last) }
        end
        return names
    end,
    Vehicles = {
        PlateExists = function(plate)
            return Core.Database.ScalarSync("SELECT 1 FROM owned_vehicles WHERE plate = ?", { plate }) ~= nil
        end,
        IsOwner = function(identifier, plate)
            return Core.Database.ScalarSync("SELECT 1 FROM owned_vehicles WHERE plate = ? AND owner = ?", { plate, identifier }) ~= nil
        end,
        -- { { plate, model }, ... }
        -- ESX keeps only the model hash in the props JSON and there is no server-side
        -- hash-to-name lookup, so the plate stands in for the model.
        GetOwned = function(identifier)
            local list = {}
            local rows = Core.Database.FetchSync("SELECT plate FROM owned_vehicles WHERE owner = ?", { identifier }) or {}
            for i = 1, #rows do
                list[i] = { plate = rows[i].plate, model = rows[i].plate }
            end
            return list
        end,
        -- Registers a stored vehicle in the given garage. Returns the insert id or nil.
        -- garage_id is jg-advancedgarages; parking is esx_garage.
        Add = function(player, identifier, model, plate, garage)
            local props = json.encode({ model = joaat(model), plate = plate })
            local hasGarageId = Core.Database.ScalarSync(
                "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'owned_vehicles' AND column_name = 'garage_id'", {})
            if hasGarageId and hasGarageId > 0 then
                return Core.Database.InsertSync([[
                    INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored, in_garage, garage_id)
                    VALUES (?, ?, ?, 'car', 1, 1, ?)
                ]], { identifier, plate, props, garage })
            end
            return Core.Database.InsertSync([[
                INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored, parking)
                VALUES (?, ?, ?, 'car', 1, ?)
            ]], { identifier, plate, props, garage })
        end,
        -- Moves the plate column and the plate inside the vehicle props JSON. Returns affected rows.
        -- A changed row fires bp_lib:plateChanged (server/helpers.lua PlateChanged).
        SetPlate = function(identifier, oldPlate, newPlate)
            local row = Core.Database.SingleSync("SELECT vehicle FROM owned_vehicles WHERE plate = ? AND owner = ?", { oldPlate, identifier })
            local ok, props = pcall(json.decode, row and row.vehicle or "")
            local rows
            if ok and type(props) == "table" then
                props.plate = newPlate
                rows = Core.Database.UpdateSync("UPDATE owned_vehicles SET plate = ?, vehicle = ? WHERE plate = ? AND owner = ?",
                    { newPlate, json.encode(props), oldPlate, identifier })
            else
                rows = Core.Database.UpdateSync("UPDATE owned_vehicles SET plate = ? WHERE plate = ? AND owner = ?",
                    { newPlate, oldPlate, identifier })
            end
            return PlateChanged(rows, identifier, oldPlate, newPlate)
        end,
    },
    Money = {
        -- reason (0.11.0, optional, last): passed to ESX, which hands it to its money events.
        Give = function(player, amount, account, reason)
            if account ~= "money" and account ~= "cash" and account ~= "bank" and account ~= "black_money" then
                return error("Wrong money account: cash, bank, or black_money required.", 3)
            end

            if account == "cash" then account = "money" end

            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end

            if math.ceil(amount) <= 0 then return true end

            TriggerClientEvent("bp_lib:notify", player, locale("paid_title"), locale("you_got_paid"):format(math.ceil(amount)), "success")
            return xPlayer.addAccountMoney(account, math.ceil(amount), reason)
        end,
        Get = function(player, account)
            if account ~= "money" and account ~= "cash" and account ~= "bank" and account ~= "black_money" then
                return error("Wrong money account: cash, bank, or black_money required.", 3)
            end
            
            if account == "cash" then account = "money" end

            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end
            return xPlayer.getAccount(account).money
        end,
        Remove = function(player, amount, account, reason)
            if account ~= "money" and account ~= "cash" and account ~= "bank" and account ~= "black_money" then
                return error("Wrong money account: cash, bank, black_money required.", 3)
            end

            if account == "cash" then account = "money" end

            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end
            if xPlayer.getAccount(account).money < amount then return false end

            if math.ceil(amount) <= 0 then return true end
            -- es_extended 1.16.3 answers false when it refuses (rounding to 0, a bad balance, the
            -- ox_inventory money item short); older builds return nothing, which means done.
            local done = xPlayer.removeAccountMoney(account, math.ceil(amount), reason)
            if done == false then return false end
            return true
        end,
    },
    Job = {
        Set = function(player, job, grade)
            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end
            xPlayer.setJob(job, grade)
            return true
        end,
        Get = function(player)
            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end
            return xPlayer.getJob().name
        end,
        GetLabel = function(player)
            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end
            return xPlayer.getJob().label
        end,
        GetGrade = function(player)
            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end
            return xPlayer.getJob().grade
        end,
        GetGradeLabel = function(player)
            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return end
            return xPlayer.getJob().grade_label
        end
    },
    -- (0.11.0) Asks ESX to write the player's row now: the SavePlayer export of es_extended
    -- (1.16.3 has it), else ESX.SavePlayer when an older build has that. false when the
    -- player is not loaded or this ESX has neither.
    SavePlayer = function(player)
        local xPlayer = ESX.GetPlayerFromId(player)
        if not xPlayer then return false end
        local ok = pcall(function() exports[Config.FrameworkResource]:SavePlayer(player) end)
        if ok then return true end
        -- through the shared object a function is a callable table in the game, never type
        -- 'function' (bp_bank E2): test by value
        if ESX.SavePlayer ~= nil then
            return (pcall(ESX.SavePlayer, xPlayer))
        end
        return false
    end,
    -- (0.11.0, E1 of bp_bank's hardening) The player's accounts column, written by bp_lib itself
    -- and waited for (Core.Framework.SaveMoney): the same column and encoding as es_extended's own
    -- save (`accounts = json.encode(xPlayer.getAccounts(true))`, users row by identifier).
    MoneyStore = {
        columns = "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME IN ('accounts', 'identifier')",
        want = 2,
        probe = 'SELECT accounts FROM users WHERE accounts IS NOT NULL LIMIT 1',
        write = 'UPDATE users SET accounts = ? WHERE identifier = ?',
        row = function(player)
            local xPlayer = ESX.GetPlayerFromId(player)
            if not xPlayer then return nil end
            return xPlayer.getAccounts(true), xPlayer.identifier
        end,
        shape = function(v) return type(v) == 'table' and tonumber(v.bank) ~= nil and tonumber(v.money) ~= nil end,
    },
    -- (0.11.0) Read by Core.Framework.OnCharacter (server/extras.lua). es_extended fires
    -- esx:playerLoaded(playerId, xPlayer, isNew) when a character is in, and esx:playerDropped(
    -- playerId, reason) on a disconnect and on a logout (esx:playerLogout, reason
    -- 'esx_player_logout'), before its final save, while the xPlayer still exists.
    CharacterEvents = {
        loaded = {
            { name = 'esx:playerLoaded', read = function(playerId, xPlayer)
                if type(xPlayer) ~= 'table' then return playerId, nil end
                local id = xPlayer.identifier
                if id == nil and type(xPlayer.getIdentifier) == 'function' then id = xPlayer.getIdentifier() end
                return playerId, id
            end },
        },
        left = {
            { name = 'esx:playerDropped', read = function(playerId, reason)
                return playerId, reason == 'esx_player_logout' and 'logout' or 'drop'
            end },
        },
    },
    -- (0.11.0) Read by Core.Framework.OnMoneyChange (server/extras.lua). es_extended 1.16.3
    -- fires these after a change: (source, accountName, money, reason). Cash is the account
    -- 'money'. For esx:setAccountMoney the money is the new total. ESX has no offline player.
    MoneyEvents = {
        { name = 'esx:addAccountMoney', read = function(src, account, amount, reason)
            return src, account, amount, 'add', reason
        end },
        { name = 'esx:removeAccountMoney', read = function(src, account, amount, reason)
            return src, account, amount, 'remove', reason
        end },
        { name = 'esx:setAccountMoney', read = function(src, account, amount, reason)
            return src, account, amount, 'set', reason
        end },
    },
    -- (0.12.0) Read by Core.Framework.JobOf / OnJob / JobList (server/jobextras.lua). xPlayer.job:
    -- { name, label, grade, grade_name, grade_label, onDuty (newer es_extended) }. The boss is the grade
    -- named 'boss' (esx_society's rule). ESX has no gangs.
    JobData = {
        gangs = false,
        read = function(src, kind)
            if kind ~= 'job' then return nil end
            local x = ESX.GetPlayerFromId(src)
            local j = x and x.getJob and x.getJob()
            if type(j) ~= 'table' then return nil end
            return { name = j.name, label = j.label, grade = j.grade, gradeLabel = j.grade_label, boss = j.grade_name == 'boss',
                bankAuth = j.grade_name == 'boss',
                -- (0.12.1) a real boolean: es_extended without a duty field has no duty, so always on
                onDuty = j.onDuty ~= false }
        end,
        list = function(kind)
            if kind ~= 'job' then return nil end
            local raw = ESX.GetJobs and ESX.GetJobs() or {}
            local out = {}
            for name, j in pairs(raw) do
                local grades = {}
                for level, g in pairs(j.grades or {}) do grades[level] = { label = g.label, boss = g.name == 'boss', bankAuth = g.name == 'boss' } end
                out[name] = { label = j.label, grades = grades }
            end
            return out
        end,
        events = {
            { name = 'esx:setJob', kind = 'job', read = function(src, job)
                return src, 'job', type(job) == 'table' and job.name or nil, type(job) == 'table' and job.grade or nil
            end },
        },
        holders = { job = 'SELECT identifier AS cid FROM users WHERE job = ? AND identifier IN (?)' },
    },
}

return Framework