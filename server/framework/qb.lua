QBCore = exports[Config.FrameworkResource]:GetCoreObject()

Framework = {
    Name = "qb",
    RegisterCallback = function(name, cb, ...)
        QBCore.Functions.CreateCallback(name, cb, ...)
    end,
    GetIdentifier = function(player)
        local Player = QBCore.Functions.GetPlayer(player)
        if not Player then return end
        return Player.PlayerData.citizenid
    end,
    GetIdentifierID = function(identifier)
        local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
        if not player then return false end
        return player.PlayerData.source
    end,
    GetCharName = function(player)
        local Player = QBCore.Functions.GetPlayer(player)
        if not Player then return end
        return {
            first = Player.PlayerData.charinfo.firstname,
            last = Player.PlayerData.charinfo.lastname,
            full = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
        }
    end,
    GetJobPlayerCount = function(jobs)
        local players = QBCore.Functions.GetPlayers()
        local count = 0

        if jobs ~= nil and type(jobs) ~= "table" then
            jobs = { jobs }
        end

        for _, id in pairs(players) do
            local player = QBCore.Functions.GetPlayer(id)
            if not player then goto continue end

            for _, job in pairs(jobs) do
                if player.PlayerData.job.name == job then
                    if player.PlayerData.job.onduty then
                        count += 1
                    end
                end
            end

            :: continue ::
        end

        return count
    end,
    GetPlayers = function()
        return QBCore.Functions.GetPlayers()
    end,
    HasGroup = function(player, group)
        return QBCore.Functions.HasPermission(player, group)
    end,
    -- Offline lookups below read the framework's own tables through Core.Database.
    -- (0.11.0) Read by Core.Framework.Condition: QBCore metadata isdead, inlaststand, ishandcuffed
    -- (set by qb-ambulancejob and qb-policejob through SetMetaData).
    ConditionMeta = function(player)
        local Player = QBCore.Functions.GetPlayer(player)
        local md = Player and Player.PlayerData.metadata
        if not md then return nil end
        return { dead = md.isdead == true, lastStand = md.inlaststand == true, cuffed = md.ishandcuffed == true }
    end,
    SetMetadata = function(player, key, value)
        local Player = QBCore.Functions.GetPlayer(player)
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
        local Player = QBCore.Functions.GetPlayer(player)
        if not Player then return false, "Player could not be found." end

        local charinfo = Player.PlayerData.charinfo
        local oldNumber = charinfo.phone
        charinfo.phone = number
        Player.Functions.SetPlayerData('charinfo', charinfo)
        Player.Functions.Save()
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
            local Player = QBCore.Functions.GetPlayer(player)
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

            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end

            TriggerClientEvent("bp_lib:notify", player, locale("paid_title"), locale("you_got_paid"):format(amount), "success")
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

            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end
            return Player.Functions.GetMoney(account)
        end,
        Remove = function(player, amount, account, reason)
            if account == "black_money" then
                return Inventory.RemoveItem(player, "black_money", amount)
            end

            if account == "money" then account = "cash" end

            if account ~= "cash" and account ~= "bank" then
                return error("Wrong money account: cash or bank required.", 3)
            end

            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end
            if Player.Functions.GetMoney(account) < amount then return false end
            return Player.Functions.RemoveMoney(account, amount, reason)
        end,
    },
    Job = {
        Set = function(player, job, grade)
            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end
            Player.Functions.SetJob(job, grade)
            return true
        end,
        Get = function(player)
            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.name
        end,
        GetLabel = function(player)
            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.label
        end,
        GetGrade = function(player)
            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.grade.level
        end,
        GetGradeLabel = function(player)
            local Player = QBCore.Functions.GetPlayer(player)
            if not Player then return end
            return Player.PlayerData.job.grade.name
        end
    },
    -- (0.11.0) Asks qb-core to write the player's row now (Player.Functions.Save). false when
    -- the player is not loaded.
    SavePlayer = function(player)
        local Player = QBCore.Functions.GetPlayer(player)
        if not Player then return false end
        Player.Functions.Save()
        return true
    end,
    -- (0.11.0, E1 of bp_bank's hardening) The player's money column, written by bp_lib itself and
    -- waited for (Core.Framework.SaveMoney in server/extras.lua): the same column and the same
    -- encoding as qb-core (QBCore.Player.Save)'s own save (`money = json.encode(PlayerData.money)`, players row by
    -- citizenid). Checked once against the database before it is used; else SaveMoney asks the
    -- framework to save, as SavePlayer does.
    MoneyStore = {
        columns = "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME IN ('money', 'citizenid')",
        want = 2,
        probe = 'SELECT money FROM players WHERE money IS NOT NULL LIMIT 1',
        write = 'UPDATE players SET money = ? WHERE citizenid = ?',
        row = function(player)
            local P = QBCore.Functions.GetPlayer(player)
            if not P then return nil end
            return P.PlayerData.money, P.PlayerData.citizenid
        end,
        shape = function(v) return type(v) == 'table' and tonumber(v.cash) ~= nil and tonumber(v.bank) ~= nil end,
    },
    -- (0.11.0) Read by Core.Framework.OnCharacter (server/extras.lua). qb-core fires
    -- QBCore:Server:PlayerLoaded(player) in CreatePlayer (Login), QBCore:Server:OnPlayerUnload(source)
    -- in Logout, and on a disconnect QBCore:Server:PlayerDropped(source) then OnPlayerUnload(source)
    -- from its playerDropped handler (after the save, before it forgets the player).
    CharacterEvents = {
        loaded = {
            { name = 'QBCore:Server:PlayerLoaded', read = function(player)
                local d = type(player) == 'table' and player.PlayerData
                if d then return d.source, d.citizenid end
            end },
        },
        left = {
            { name = 'QBCore:Server:PlayerDropped', read = function(src) return src, 'drop' end },
            { name = 'QBCore:Server:OnPlayerUnload', read = function(src) return src, 'logout' end },
        },
    },
    -- (0.11.0) Read by Core.Framework.OnMoneyChange (server/extras.lua). qb-core fires this
    -- after a change, online players only: (source, moneytype, amount, 'add'|'remove'|'set',
    -- reason). For 'set' the amount is the new total. Offline changes fire nothing.
    MoneyEvents = {
        { name = 'QBCore:Server:OnMoneyChange', read = function(src, account, amount, action, reason)
            return src, account, amount, action, reason
        end },
    },
    -- (0.12.0) Read by Core.Framework.JobOf / GangOf / OnJob / JobList (server/jobextras.lua).
    -- PlayerData.job / .gang: { name, label, isboss, bankAuth (newer qb-core), onduty, grade = { name, level } }.
    JobData = {
        gangs = true,
        read = function(src, kind)
            local P = QBCore.Functions.GetPlayer(src)
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
            local raw = kind == 'gang' and QBCore.Shared.Gangs or QBCore.Shared.Jobs
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
        },
        paycheckSociety = function()
            local m = QBCore.Config and QBCore.Config.Money
            if type(m) ~= 'table' or m.PayCheckSociety == nil then return nil end
            return m.PayCheckSociety == true
        end,
        -- QBCore keeps one job and one gang per character, as JSON on the players row
        holders = {
            job = "SELECT citizenid AS cid FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ? AND citizenid IN (?)",
            gang = "SELECT citizenid AS cid FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(gang, '$.name')) = ? AND citizenid IN (?)",
        },
    },
}

return Framework