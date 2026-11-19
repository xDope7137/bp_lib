--[[
    0.11.0 additions on the server Core, attached by server/main.lua after ApplyServerCompat:

      Core.Framework.Money.TryRemove     a take that is true only when the money really left
      Core.Framework.OnMoneyChange       one shape for the frameworks' money events
      Core.Framework.OffMoneyChange
      Core.Framework.OnCharacter         one shape for "a character finished loading" and "left"
      Core.Framework.OffCharacter
      Core.Framework.OnlineCharacters    who is in right now (catching up after a restart)
      Core.Framework.SavePlayer          (qbx/qb/esx in their own module; false elsewhere)
      Core.Framework.SaveMoney           the money column written by bp_lib and waited for (else asked)
      Core.Framework.MoneySaveMode       'direct' | 'asked', why
      Core.Database.Transaction          all or nothing, with an optional row count per query
      Core.Database.BatchInsert          many rows in one INSERT statement
      Core.Inventory.GiveWithMeta / FindWithMeta / RemoveWithMeta, Core.ItemMetaSupport
      Core.Inventory.OnUseWithMeta       (0.13.0) a used item's metadata to a callback

    Additions only: Money.Give and Money.Remove keep their arguments and results. They are
    wrapped so a money event fired while they run can say which script asked for the change.
]]

-- --------------------------------------------------------------- money: who --

-- Calls into Money.Give / Remove / TryRemove that are running right now. A framework fires
-- its money event inside the call; the event handler gives the call's script name (`by`) to
-- the one event that matches it: same player, account, direction and amount. One call tags
-- one event, then its tag is spent, so a change some other code makes to the same player's
-- money while the call runs (a hook, a nested handler) is never tagged with our caller.
-- Two identical changes running at once may swap names; the count stays right.
local inFlight = {}
local listeners, nextId, wired = {}, 0, false   -- OnMoneyChange listeners; wired = money events watched

local function normAccount(account)
    if account == 'money' then return 'cash' end
    return account
end

local function resolveSrc(fw, player)
    if type(player) == 'string' then
        if not fw.GetIdentifierID then return nil end
        local ok, src = pcall(fw.GetIdentifierID, player)
        return ok and tonumber(src) or nil
    end
    return tonumber(player)
end

local function newEntry(fw, player, dir, amount, account)
    return { src = resolveSrc(fw, player), by = Helpers.Caller(), dir = dir, amount = tonumber(amount),
        account = normAccount(account), spent = false }
end

local function push(entry) inFlight[#inFlight + 1] = entry end
local function pop(entry)
    for i = #inFlight, 1, -1 do
        if inFlight[i] == entry then table.remove(inFlight, i); break end
    end
end

local function callTagged(fw, fn, dir, player, amount, account, ...)
    local entry = newEntry(fw, player, dir, amount, account)
    push(entry)
    local result = table.pack(pcall(fn, player, amount, account, ...))
    pop(entry)
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

local function sameAmount(asked, got)
    if not asked or not got then return false end
    return asked == got or math.ceil(asked) == got or math.floor(asked + 0.5) == got
end

-- The newest unspent call that this change answers, spent on the way out.
local function claimTag(src, account, action, amount)
    if action ~= 'add' and action ~= 'remove' then return nil end
    for i = #inFlight, 1, -1 do
        local e = inFlight[i]
        if not e.spent and e.src == src and e.dir == action and e.account == account and sameAmount(e.amount, amount) then
            e.spent = true
            return e
        end
    end
    return nil
end

-- ----------------------------------------------------------- money: try take --

-- TryRemove calls running now, per player and account: a second one is refused as busy, so
-- two takes never overlap even when a framework hook waits inside the first.
local taking = {}

local function tryRemove(fw, get, give, remove, entry, player, amount, account, reason)
    local n = Helpers.Amount(amount, 1)
    if not n then return false, 'bad_amount' end
    if type(player) == 'string' then
        if not resolveSrc(fw, player) then return false, 'no_player' end
    elseif not tonumber(player) then
        return false, 'no_player'
    end
    local ok, before = pcall(get, player, account)
    if not ok then return false, 'bad_account' end
    before = tonumber(before)
    if not before then return false, 'no_player' end
    if before < n then return false, 'insufficient' end
    entry.amount = n

    local done, said = pcall(remove, player, n, account, reason)
    local okA, after = pcall(get, player, account)
    after = okA and tonumber(after) or nil
    -- Taken: the framework reported this exact remove, or the balance dropped by exactly n.
    -- A remove that threw after it subtracted (a logger inside the framework) still counts.
    local taken = entry.spent or (after ~= nil and after == before - n)
    if not taken then
        if done and said == false then return false, 'refused' end
        if after == before then return false, done and 'refused' or 'error' end
        -- The framework reports every remove it makes; none came for this one, so the balance
        -- moved for another reason (another script during a hook that waited).
        if wired and done then return false, 'refused' end
        print(('^1[bp_lib] Money.TryRemove: %s %s was %s, asked to take %s, now %s. Check this player\'s money.^0')
            :format(tostring(player), tostring(account), tostring(before), tostring(n), tostring(after)))
        return false, 'mismatch'
    end
    if after and after < 0 then
        -- Overdrawn: something else took money while a framework hook waited. Put it back.
        local okG = pcall(give, player, n, account, reason)
        local _, now = pcall(get, player, account)
        if okG and tonumber(now) == after + n then return false, 'insufficient' end
        print(('^1[bp_lib] Money.TryRemove: %s %s went below zero (%s) and could not be put back. Check this player\'s money.^0')
            :format(tostring(player), tostring(account), tostring(after)))
    end
    return true
end

-- ------------------------------------------------------------ money: try give --

-- Given: the framework reported this exact add (the call's tag), or Give answered true. A
-- balance difference never decides it: another script that takes $1 inside the money event
-- (a loan, a tax) makes the balance rise by n - 1 although the money arrived. Without either
-- signal the outcome is 'unknown' (the caller keeps it for a person, never pays it again), except
-- on a framework without money events, where a rise of exactly n is all there is to go on.
local function tryGive(get, give, entry, player, amount, account, reason)
    local n = Helpers.Amount(amount, 1)
    if not n then return false, 'bad_amount' end
    if not entry.src then return false, 'no_player' end
    local ok, before = pcall(get, player, account)
    if not ok then return false, 'bad_account' end
    before = tonumber(before)
    if not before then return false, 'no_player' end
    entry.amount = n
    local done, said = pcall(give, player, n, account, reason)
    if entry.spent or (done and said == true) then return true end
    local okA, after = pcall(get, player, account)
    after = okA and tonumber(after) or nil
    if after == before then return false, done and 'refused' or 'error' end
    if not wired and done and after == before + n then return true end
    print(('^1[bp_lib] Money.TryGive: %s %s was %s, asked to give %s, now %s, and the framework reported no add for it. Check this player\'s money.^0')
        :format(tostring(player), tostring(account), tostring(before), tostring(n), tostring(after)))
    return false, 'unknown'
end

-- ---------------------------------------------------------- money: listening --

-- es_extended with ox_inventory moves cash through the money item and reports the new total
-- with this reason before its own add/remove event (classes/overrides/oxinventory.lua).
local SYNC_REASON = 'Sync account with item'

local function dispatch(core, src, account, amount, action, reason, by)
    src, amount = tonumber(src), tonumber(amount)
    if not src or src <= 0 or type(account) ~= 'string' or not amount then return end
    if action ~= 'add' and action ~= 'remove' and action ~= 'set' then return end
    account = normAccount(account)
    local sync = action == 'set' and reason == SYNC_REASON or nil
    if type(reason) ~= 'string' or reason == '' or reason:lower() == 'unknown' then reason = nil end
    -- (0.11.0) a framework that pays some things without a reason may name them (Qbox paychecks)
    local inferred
    if not reason and not by and action == 'add' and core.Framework.InferReason then
        local ok, r, how = pcall(core.Framework.InferReason, src, account, amount, action)
        if ok and type(r) == 'string' then reason, inferred = r, how or true end
    end

    local balance
    if action == 'set' then
        balance = amount
    else
        local ok, value = pcall(core.Framework.Money.Get, src, account)
        balance = ok and tonumber(value) or nil
    end
    local citizenid = Helpers.Identifier(src)

    local list = {}
    for _, l in pairs(listeners) do list[#list + 1] = l end
    table.sort(list, function(a, b) return a.id < b.id end)
    for _, l in ipairs(list) do
        local change = {
            source = src, citizenid = citizenid, account = account, action = action,
            amount = action ~= 'set' and amount or nil,
            delta = action == 'add' and amount or action == 'remove' and -amount or nil,
            balance = balance, reason = reason, by = by, framework = core.Framework.Name, sync = sync,
            inferred = inferred,
        }
        local ok, err = pcall(l.cb, change)
        if not ok then
            print(('^1[bp_lib] OnMoneyChange listener of %s failed: %s^0'):format(l.res, tostring(err)))
        end
    end
end

-- The money events are watched from the start: TryRemove reads them to tell whether its take
-- happened, and every event spends the tag of the call it answers even with no listener.
local function wire(core)
    if wired then return true end
    local events = core.Framework and core.Framework.MoneyEvents
    if type(events) ~= 'table' or #events == 0 then return false end
    wired = true
    for _, ev in ipairs(events) do
        AddEventHandler(ev.name, function(...)
            local src, account, amount, action, reason = ev.read(...)
            local tag = claimTag(tonumber(src), normAccount(account), action, tonumber(amount))
            if next(listeners) == nil then return end
            dispatch(core, src, account, amount, action, reason, tag and tag.by or nil)
        end)
    end
    return true
end

AddEventHandler('onResourceStop', function(res)
    for id, l in pairs(listeners) do
        if l.res == res then listeners[id] = nil end
    end
end)

-- ---------------------------------------------------------- characters --

-- Who is in, by player id: src -> citizen id. Kept from the frameworks' own events, so a left
-- event can still name the character when the framework has already forgotten the player
-- (Qbox's playerDropped forgets before other resources hear of it). Filled from the players
-- online when bp_lib starts, so a restart of bp_lib keeps it right.
local chars = {}
local charListeners, charNextId, charsWired = {}, 0, false

local function charDispatch(core, kind, src, cid, reason)
    local list = {}
    for _, l in pairs(charListeners) do list[#list + 1] = l end
    if #list == 0 then return end
    table.sort(list, function(a, b) return a.id < b.id end)
    for _, l in ipairs(list) do
        local ev = { event = kind, source = src, citizenid = cid, reason = reason, framework = core.Framework.Name }
        local ok, err = pcall(l.cb, ev)
        if not ok then
            print(('^1[bp_lib] OnCharacter listener of %s failed: %s^0'):format(l.res, tostring(err)))
        end
    end
end

local function charLeft(core, src, reason)
    src = tonumber(src)
    if not src then return end
    local cid = chars[src]
    if not cid then return end        -- never seen in, or its left event already went out
    chars[src] = nil
    charDispatch(core, 'left', src, cid, reason)
end

local function charLoaded(core, src, cid)
    src = tonumber(src)
    if not src or src <= 0 or cid == nil or cid == '' then return end
    cid = tostring(cid)
    local was = chars[src]
    if was == cid then return end                      -- the same character told twice
    if was then charLeft(core, src, 'switch') end      -- a new character without a left first
    chars[src] = cid
    charDispatch(core, 'loaded', src, cid, nil)
end

local function wireCharacters(core)
    if charsWired then return true end
    local ev = core.Framework and core.Framework.CharacterEvents
    if type(ev) ~= 'table' or type(ev.loaded) ~= 'table' or type(ev.left) ~= 'table' then return false end
    charsWired = true
    for _, e in ipairs(ev.loaded) do
        AddEventHandler(e.name, function(...) charLoaded(core, e.read(...)) end)
    end
    for _, e in ipairs(ev.left) do
        AddEventHandler(e.name, function(...) charLeft(core, e.read(...)) end)
    end
    -- a disconnect the framework itself does not announce (Qbox), or announced before we saw it
    AddEventHandler('playerDropped', function()
        local src = source
        charLeft(core, src, 'drop')
    end)
    -- players already in when bp_lib (re)starts: known, but no event is sent for them
    for _, s in ipairs(GetPlayers and GetPlayers() or {}) do
        local src = tonumber(s)
        local cid = src and Helpers.Identifier(src)
        if cid then chars[src] = cid end
    end
    return true
end

AddEventHandler('onResourceStop', function(res)
    for id, l in pairs(charListeners) do
        if l.res == res then charListeners[id] = nil end
    end
end)

-- ------------------------------------------------------------------ database --

-- Fails its statement when the statement before it did not touch exactly ? rows: a subquery
-- that returns two rows is an error, and the error rolls the whole transaction back.
-- ROW_COUNT() counts matched rows under oxmysql (mysql2 connects with FOUND_ROWS).
local GUARD_SQL = 'SELECT (SELECT n FROM (SELECT 1 AS n UNION ALL SELECT 2) AS bp_guard WHERE n = 1 OR ROW_COUNT() <> ?)'
-- With mysql_debug on, oxmysql runs a profiler query after every 100th statement, which
-- would reset ROW_COUNT(). Guarded transactions stay below that.
local MAX_GUARDED = 99
local MAX_PLACEHOLDERS = 65535

local function isName(name)
    return type(name) == 'string' and name:match('^[%a_][%w_]*$') ~= nil
end

local function transaction(queries)
    if type(queries) ~= 'table' or #queries == 0 then return false, 'invalid' end
    if Config.SQLConnector ~= 'oxmysql' then return false, 'unsupported' end
    local list, guarded = {}, false
    for _, q in ipairs(queries) do
        if type(q) ~= 'table' then return false, 'invalid' end
        local sql, params = q.query or q[1], q.params or q.values or q[2] or {}
        if type(sql) ~= 'string' or sql == '' or type(params) ~= 'table' then return false, 'invalid' end
        list[#list + 1] = { query = sql, values = params }
        if q.expect ~= nil then
            local n = Helpers.Amount(q.expect, 0)
            if not n then return false, 'invalid' end
            list[#list + 1] = { query = GUARD_SQL, values = { n } }
            guarded = true
        end
    end
    if guarded and #list > MAX_GUARDED then return false, 'too_many' end
    local ok, done = pcall(function() return exports.oxmysql:transactionSync(list) end)
    if ok and done == true then return true end
    return false, 'failed'
end

local MODES = {
    add = '`%s` = `%s` + VALUES(`%s`)',
    set = '`%s` = VALUES(`%s`)',
    max = '`%s` = GREATEST(`%s`, VALUES(`%s`))',
}

-- The same updates with MySQL's row alias (`... VALUES (...) AS new ON DUPLICATE KEY UPDATE c = new.c`):
-- MySQL 8.0.20+ warns that VALUES(c) is deprecated (1287), and MariaDB has no row alias. rowAlias()
-- reads VERSION() once: the alias form on MySQL 8.0.19 and later, MODES everywhere else.
-- ({c} the column, {t} the table: MySQL calls a bare column beside the alias ambiguous)
local MODES_ALIAS = {
    add = '`{c}` = `{t}`.`{c}` + `new`.`{c}`',
    set = '`{c}` = `new`.`{c}`',
    max = '`{c}` = GREATEST(`{t}`.`{c}`, `new`.`{c}`)',
}

local aliasKnown, aliasOn = false, false
local function rowAlias(db)
    if aliasKnown then return aliasOn end
    local ok, v = pcall(db.ScalarSync, 'SELECT VERSION()', {})
    if not ok or v == nil then return false end      -- ask again next time
    v = tostring(v)
    local a, b, c = v:match('^(%d+)%.(%d+)%.(%d+)')
    local num = a and (tonumber(a) * 10000 + tonumber(b) * 100 + tonumber(c)) or 0
    aliasOn = not v:lower():find('mariadb') and num >= 80019
    aliasKnown = true
    return aliasOn
end

local function batchInsert(db, tableName, columns, rows, opts)
    opts = type(opts) == 'table' and opts or {}
    if not isName(tableName) or type(columns) ~= 'table' or #columns == 0 or type(rows) ~= 'table' then
        return false, 'invalid'
    end
    local cols, seen = {}, {}
    for i, c in ipairs(columns) do
        if not isName(c) or seen[c] then return false, 'invalid' end
        seen[c] = true
        cols[i] = '`' .. c .. '`'
    end
    if #rows == 0 then return 0 end
    if #rows * #columns > MAX_PLACEHOLDERS then return false, 'too_many' end

    local groups, params = {}, {}
    for r, row in ipairs(rows) do
        if type(row) ~= 'table' then return false, 'invalid' end
        local marks = {}
        for i, c in ipairs(columns) do
            local v = row[c]
            if v == nil then v = row[i] end
            local kind = type(v)
            if v == nil then
                marks[i] = 'NULL'
            elseif kind == 'number' or kind == 'string' or kind == 'boolean' then
                if kind == 'number' and (v ~= v or v == math.huge or v == -math.huge) then return false, 'invalid' end
                marks[i] = '?'
                params[#params + 1] = v
            else
                return false, 'invalid'
            end
        end
        groups[r] = '(' .. table.concat(marks, ',') .. ')'
    end

    local sql = ('INSERT %sINTO `%s` (%s) VALUES %s'):format(opts.ignore and 'IGNORE ' or '', tableName,
        table.concat(cols, ','), table.concat(groups, ','))
    if type(opts.update) == 'table' then
        local sets, aliasCols = {}, {}
        for _, c in ipairs(columns) do
            local mode = opts.update[c]
            if mode ~= nil then
                if not MODES[mode] then return false, 'invalid' end
                sets[#sets + 1] = MODES[mode]:format(c, c, c)
                aliasCols[#sets] = { c, mode }
            end
        end
        for c in pairs(opts.update) do
            if not seen[c] then return false, 'invalid' end
        end
        if #sets > 0 and rowAlias(db) then
            for i, c in ipairs(aliasCols) do
                sets[i] = MODES_ALIAS[c[2]]:gsub('{(%a)}', { c = c[1], t = tableName })
            end
            sql = sql .. ' AS `new`'
        end
        if #sets > 0 then sql = sql .. ' ON DUPLICATE KEY UPDATE ' .. table.concat(sets, ',') end
    end

    local ok, affected = pcall(db.UpdateSync, sql, params)
    if not ok or type(affected) ~= 'number' then return false, 'failed' end
    return affected
end

-- ----------------------------------------------------------------- inventory --

local function matches(meta, match)
    if match == nil or next(match) == nil then return true end
    if type(meta) ~= 'table' then return false end
    for k, v in pairs(match) do
        if meta[k] ~= v then return false end
    end
    return true
end

local function collect(items, item, match, slotOf, countOf, metaOf)
    local found = {}
    for _, it in pairs(items or {}) do
        if type(it) == 'table' and it.name == item and matches(metaOf(it), match) then
            found[#found + 1] = { slot = slotOf(it), count = countOf(it), metadata = metaOf(it) }
        end
    end
    table.sort(found, function(a, b) return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0) end)
    return found
end

-- One table per inventory: give(src, item, meta) -> bool, why; list(src, item) -> raw items;
-- take(src, item, count, slot) -> bool. Signatures read from the inventories' own source
-- (ox_inventory 2.49.0, qb-inventory 2.2.3) and, for qs-inventory, from scripts that call it.
local Adapters = {}

Adapters['ox_inventory'] = function(res)
    local inv = exports[res]
    return {
        give = function(src, item, meta)
            if not inv:CanCarryItem(src, item, 1, meta) then return false, 'cannot_carry' end
            local ok = inv:AddItem(src, item, 1, meta)
            return ok and true or false, (not ok) and 'failed' or nil
        end,
        find = function(src, item, match)
            return collect(inv:GetSlotsWithItem(src, item), item, match,
                function(it) return it.slot end, function(it) return it.count end, function(it) return it.metadata end)
        end,
        take = function(src, item, count, slot)
            return inv:RemoveItem(src, item, count, nil, slot) and true or false
        end,
        known = function(item) return inv:Items(item) ~= nil end,
    }
end

local function qbAdapter()
    return {
        give = function(src, item, meta, reason)
            local data = QBCore and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item]
            if not data then return false, 'unknown_item' end
            -- qb-inventory stacks a non-unique item into the first slot of that name and
            -- drops the new metadata, so a card would merge into another card.
            if not data.unique then return false, 'not_unique' end
            local Player = QBCore.Functions.GetPlayer(src)
            if not Player then return false, 'no_player' end
            local ok = Player.Functions.AddItem(item, 1, nil, meta, reason)
            if not ok then return false, 'cannot_carry' end
            TriggerClientEvent('inventory:client:ItemBox', src, data, 'add', 1)
            return true
        end,
        find = function(src, item, match)
            local Player = QBCore and QBCore.Functions.GetPlayer(src)
            if not Player then return {} end
            return collect(Player.Functions.GetItemsByName(item), item, match,
                function(it) return it.slot end, function(it) return it.amount end, function(it) return it.info end)
        end,
        take = function(src, item, count, slot)
            local Player = QBCore and QBCore.Functions.GetPlayer(src)
            if not Player then return false end
            local ok = Player.Functions.RemoveItem(item, count, slot)
            if ok then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove', count)
            end
            return ok and true or false
        end,
        known = function(item)
            return (QBCore and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item]) ~= nil
        end,
    }
end
Adapters['qb-inventory'] = qbAdapter
Adapters['qb-inventory-new'] = qbAdapter

Adapters['qs-inventory'] = function(res)
    local inv = exports[res]
    return {
        give = function(src, item, meta)
            if not inv:CanCarryItem(src, item, 1) then return false, 'cannot_carry' end
            local ok = inv:AddItem(src, item, 1, nil, meta)
            return ok and true or false, (not ok) and 'failed' or nil
        end,
        find = function(src, item, match)
            return collect(inv:GetInventory(src), item, match,
                function(it) return it.slot end, function(it) return it.amount end, function(it) return it.info end)
        end,
        take = function(src, item, count, slot)
            return inv:RemoveItem(src, item, count, slot) and true or false
        end,
        known = function(item)
            local list = inv:GetItemList()
            return type(list) == 'table' and list[item] ~= nil
        end,
    }
end

-- Where each adapter's inventory keeps an item's metadata (OnUseWithMeta).
local META_FIELD = { ox_inventory = 'metadata', ['qb-inventory'] = 'info', ['qb-inventory-new'] = 'info', ['qs-inventory'] = 'info' }

local function metaSupport(core)
    if not core.Inventory then return false, 'no_inventory' end
    local name = Config.Inventory
    if Adapters[name] then return name end
    return false, 'unsupported_inventory'
end

local function attachInventory(core)
    local inventory = core.Inventory
    local adapter
    local name = Config.Inventory
    local function get()
        if adapter == nil then
            local make = Adapters[name]
            adapter = make and make(Config.InventoryResource or name) or false
        end
        return adapter
    end
    local function check(src, item)
        src = tonumber(src)
        if not src or src <= 0 then return nil, 'no_player' end
        if type(item) ~= 'string' or item == '' then return nil, 'bad_item' end
        local a = get()
        if not a then return nil, 'unsupported_inventory' end
        return a, src
    end

    --- (0.11.0) Whether the inventory defines `item` (read only). true or false, or nil plus
    --- 'bad_item' / 'unsupported_inventory' (an inventory without an adapter: nothing is known).
    inventory.ItemKnown = function(item)
        if type(item) ~= 'string' or item == '' then return nil, 'bad_item' end
        local a = get()
        if not a then return nil, 'unsupported_inventory' end
        local ok, known = pcall(a.known, item)
        if not ok then return nil, 'failed' end
        return known and true or false
    end

    --- (0.11.0) Gives one `item` carrying `metadata`. true, or false plus why:
    --- 'cannot_carry', 'not_unique' (qb: the item must be unique), 'unknown_item',
    --- 'bad_metadata', 'unsupported_inventory', 'failed'.
    inventory.GiveWithMeta = function(src, item, metadata, reason)
        local a, s = check(src, item)
        if not a then return false, s end
        if type(metadata) ~= 'table' then return false, 'bad_metadata' end
        local ok, done, why = pcall(a.give, s, item, metadata, reason)
        if not ok then return false, 'failed' end
        if done then return true end
        return false, why or 'failed'
    end

    --- (0.11.0) Every slot holding `item` whose metadata has every key = value of `match`
    --- (all of them for an empty match): { { slot, count, metadata }, ... } by slot.
    --- nil plus why when it cannot look.
    inventory.FindWithMeta = function(src, item, match)
        local a, s = check(src, item)
        if not a then return nil, s end
        if match ~= nil and type(match) ~= 'table' then return nil, 'bad_match' end
        local ok, found = pcall(a.find, s, item, match)
        if not ok then return nil, 'failed' end
        return found
    end

    --- (0.11.0) Removes `count` (1) of the first slot whose metadata matches. The match
    --- may not be empty. true, or false plus why: 'not_found', 'not_enough', 'bad_match',
    --- 'unsupported_inventory', 'failed'.
    inventory.RemoveWithMeta = function(src, item, match, count)
        local a, s = check(src, item)
        if not a then return false, s end
        if type(match) ~= 'table' or next(match) == nil then return false, 'bad_match' end
        count = Helpers.Amount(count == nil and 1 or count, 1)
        if not count then return false, 'bad_count' end
        local ok, found = pcall(a.find, s, item, match)
        if not ok then return false, 'failed' end
        local first = found[1]
        if not first then return false, 'not_found' end
        if (tonumber(first.count) or 0) < count then return false, 'not_enough' end
        local okTake, taken = pcall(a.take, s, item, count, first.slot)
        if okTake and taken then return true end
        return false, 'failed'
    end

    --- (0.13.0) Calls `fn(src, metadata, slot)` (in pcall) when a player uses one `item`; `metadata` is always a
    --- table (empty when the item has none). Registered through the inventory's usable-item hook (Core.Inventory
    --- .RegisterUsableItem: the framework's for ox_inventory, the inventory's own for qs). The metadata is read
    --- from `item.metadata` (ox_inventory) or `item.info` (qb-inventory, qb-inventory-new, qs-inventory).
    --- true, or false plus 'bad_item' / 'unsupported_inventory' / 'failed'. No Off: frameworks cannot
    --- unregister, so register once at start. `fn` may be a function or a function reference (exports).
    inventory.OnUseWithMeta = function(item, fn)
        if type(item) ~= 'string' or item == '' then return false, 'bad_item' end
        local field = META_FIELD[name]
        if not field or not Adapters[name] or inventory.RegisterUsableItem == nil then return false, 'unsupported_inventory' end
        if fn == nil then return false, 'failed' end
        local ok = pcall(inventory.RegisterUsableItem, item, function(src, it, extra)
            local data = type(it) == 'table' and it or (type(extra) == 'table' and extra) or {}
            local meta = data[field]
            if type(meta) ~= 'table' then meta = {} end
            local okF, err = pcall(fn, tonumber(src), meta, data.slot)
            if not okF then print(('^3[bp_lib] OnUseWithMeta(%s): %s^7'):format(item, tostring(err))) end
        end)
        if not ok then return false, 'failed' end
        return true
    end
end

-- -------------------------------------------------------------------- attach --

-- ------------------------------------------------------------- condition --
-- State bag keys set by the scripts in use (read from their source on the dev box, 2026-11-17):
-- xd_ambulancejob and wasabi_ambulance 'dead' and 'isDead', luxu_admin 'isDead', wasabi_police
-- 'cuffed', jobs_creator 'isHandcuffed' (entity), others 'isCuffed' / 'handcuffed'.
local CONDITION_KEYS = {
    dead = { 'isDead', 'dead' },
    lastStand = { 'inLastStand', 'isInLastStand', 'laststand', 'inlaststand' },
    cuffed = { 'cuffed', 'isCuffed', 'handcuffed', 'isHandcuffed' },
}
local DEAD_BELOW = 100

local function bagValue(bag, key)
    if not bag then return nil end
    local ok, v = pcall(function() return bag[key] end)
    return ok and v or nil
end

local function condition(fw, src)
    src = tonumber(src)
    if not src or src <= 0 then return nil, 'no_player' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, 'no_player' end
    local out = { dead = false, lastStand = false, cuffed = false, from = {} }
    local function set(field, where)
        if not out[field] then out[field], out.from[field] = true, where end
    end
    if fw.ConditionMeta then
        local ok, m = pcall(fw.ConditionMeta, src)
        if ok and type(m) == 'table' then
            for _, f in ipairs({ 'dead', 'lastStand', 'cuffed' }) do if m[f] then set(f, 'metadata') end end
        end
    end
    local pbag, ebag
    pcall(function() pbag = Player(src).state end)
    pcall(function() ebag = Entity(ped).state end)
    for _, f in ipairs({ 'dead', 'lastStand', 'cuffed' }) do
        for _, key in ipairs(CONDITION_KEYS[f] or {}) do
            if bagValue(pbag, key) then set(f, 'state:' .. key) end
            if bagValue(ebag, key) then set(f, 'entity:' .. key) end
        end
    end
    local okH, health = pcall(GetEntityHealth, ped)
    health = okH and tonumber(health) or nil
    if health and health < DEAD_BELOW then set('dead', 'health') end
    return out
end

function AttachServerExtras(core)
    local fw = core.Framework
    if fw then
        local money = fw.Money
        if money then
            local give, remove, get = money.Give, money.Remove, money.Get
            money.Give = function(player, ...) return callTagged(fw, give, 'add', player, ...) end
            money.Remove = function(player, ...) return callTagged(fw, remove, 'remove', player, ...) end
            wire(core)

            --- (0.11.0) Takes `amount` from the account only when it is all there. true when
            --- the money really left, false plus why when it did not: 'bad_amount' (fails
            --- Core.Amount), 'no_player', 'bad_account', 'insufficient', 'busy' (a TryRemove for
            --- the same player and account is still running), 'refused' (the framework or a
            --- hook said no), 'error', 'mismatch' (the balance moved by some other amount).
            money.TryRemove = function(player, amount, account, reason)
                local entry = newEntry(fw, player, 'remove', nil, account)
                local key = entry.src and (entry.src .. ':' .. tostring(entry.account)) or nil
                if key and taking[key] then return false, 'busy' end
                if key then taking[key] = true end
                push(entry)
                local result = table.pack(pcall(tryRemove, fw, get, money.Give, remove, entry, player, amount, account, reason))
                pop(entry)
                if key then taking[key] = nil end
                if not result[1] then return false, 'error' end
                return table.unpack(result, 2, result.n)
            end

            --- (0.11.0) Gives `amount`. true when the money arrived: the framework reported this
            --- exact add, or Give answered true. false plus why: 'bad_amount', 'no_player',
            --- 'bad_account', 'refused' (nothing arrived), 'error' (failed before anything moved),
            --- 'unknown' (the balance moved but nothing says this add happened: never pay it again,
            --- leave it for a person).
            money.TryGive = function(player, amount, account, reason)
                local entry = newEntry(fw, player, 'add', nil, account)
                push(entry)
                local result = table.pack(pcall(tryGive, get, give, entry, player, amount, account, reason))
                pop(entry)
                if not result[1] then return false, 'error' end
                return table.unpack(result, 2, result.n)
            end
        end

        local save = fw.SavePlayer
        --- (0.11.0) Asks the framework to write the player's row now. true when asked.
        fw.SavePlayer = function(src)
            src = tonumber(src)
            if not src or src <= 0 or not save then return false end
            local ok, done = pcall(save, src)
            return ok and done == true
        end

        -- (0.11.0, bp_bank hardening E1) The framework's own save is fire-and-forget (qbx_core
        -- Save runs its upsert in a new thread; qb-core and es_extended do not wait either), so a
        -- caller that must have the money on disk before its own write cannot rely on it.
        -- SaveMoney writes the money column itself (the framework module's MoneyStore: the same
        -- column and encoding as the framework's save) and waits for it. The store is checked once
        -- against the database (both columns there, a stored value of the shape it would write);
        -- when it is not, or the connector is not oxmysql, SaveMoney only asks the framework to
        -- save, like SavePlayer, and says so. Never a guess at an unknown schema.
        local store = fw.MoneyStore
        local mode, why = nil, nil
        local function storeMode()
            if mode then return mode, why end
            if Config.SQLConnector ~= 'oxmysql' then mode, why = 'asked', 'the connector is not oxmysql'
            elseif type(store) ~= 'table' then mode, why = 'asked', 'no money column known for this framework'
            else
                local okC, n = pcall(function() return exports.oxmysql:scalarSync(store.columns, {}) end)
                if not okC or tonumber(n) ~= store.want then
                    mode, why = 'asked', 'the money table or column is not there'
                else
                    local okP, raw = pcall(function() return exports.oxmysql:scalarSync(store.probe, {}) end)
                    local okD, v = false, nil
                    if okP and raw ~= nil then okD, v = pcall(json.decode, raw) end
                    if not okP then mode, why = 'asked', 'the money column could not be read'
                    elseif raw ~= nil and not (okD and store.shape(v)) then mode, why = 'asked', 'a stored value has another shape'
                    else mode, why = 'direct', nil end
                end
            end
            return mode, why
        end

        --- (0.11.0) Writes the player's money to the framework's own row now and waits for it.
        --- -> true, 'direct' (on disk), or true, 'asked' (the framework was asked to save, as
        --- SavePlayer: not waited for), or false (no such player). The framework's own save is
        --- not replaced: callers still call SavePlayer for the rest of the row.
        fw.SaveMoney = function(src)
            src = tonumber(src)
            if not src or src <= 0 then return false end
            if storeMode() == 'direct' then
                local okR, value, key = pcall(store.row, src)
                if okR and value ~= nil and key ~= nil then
                    local okE, enc = pcall(json.encode, value)
                    if okE and type(enc) == 'string' then
                        local ok, n = pcall(function() return exports.oxmysql:updateSync(store.write, { enc, key }) end)
                        if ok and tonumber(n) == 1 then return true, 'direct' end
                    end
                elseif okR then
                    return false
                end
            end
            local asked = fw.SavePlayer(src)
            return asked, asked and 'asked' or nil
        end

        --- (0.11.0) Which save SaveMoney uses: 'direct' (written and waited for) or 'asked', and
        --- why when asked. Read by doctors.
        fw.MoneySaveMode = function() return storeMode() end

        --- (0.11.0) cb(change) after every money change the framework reports, where change =
        --- { source, citizenid, account ('cash', 'bank', ...), action ('add', 'remove', 'set'),
        ---   amount, delta, balance, reason, by, framework, sync }. `sync` is true on the ESX
        ---   with ox_inventory "Sync account with item" set (see docs.md). Returns an id, or
        ---   false plus 'unsupported' / 'bad_callback'.
        fw.OnMoneyChange = function(cb)
            if type(cb) ~= 'function' and not (type(cb) == 'table' and getmetatable(cb) and getmetatable(cb).__call) then
                return false, 'bad_callback'
            end
            if not wire(core) then return false, 'unsupported' end
            nextId = nextId + 1
            listeners[nextId] = { id = nextId, cb = cb, res = Helpers.Caller() }
            return nextId
        end

        --- (0.11.0) Stops a listener made by OnMoneyChange. true when there was one.
        fw.OffMoneyChange = function(id)
            if listeners[id] then listeners[id] = nil; return true end
            return false
        end

        wireCharacters(core)

        --- (0.11.0) cb(ev) when a character finished loading or left, where ev = { event =
        --- 'loaded' | 'left', source, citizenid, reason, framework }. reason on 'left': 'logout'
        --- (logout or the character menu), 'drop' (disconnect), 'switch' (a new character
        --- loaded on the same player id with no left before it). One 'left' per 'loaded'. No
        --- event is sent for players already in when the listener registers (a restart):
        --- read OnlineCharacters() once after registering. Do not wait inside cb (start a
        --- thread). Returns an id, or false plus 'unsupported' / 'bad_callback'.
        fw.OnCharacter = function(cb)
            if type(cb) ~= 'function' and not (type(cb) == 'table' and getmetatable(cb) and getmetatable(cb).__call) then
                return false, 'bad_callback'
            end
            if not wireCharacters(core) then return false, 'unsupported' end
            charNextId = charNextId + 1
            charListeners[charNextId] = { id = charNextId, cb = cb, res = Helpers.Caller() }
            return charNextId
        end

        --- (0.11.0) Stops a listener made by OnCharacter. true when there was one.
        fw.OffCharacter = function(id)
            if charListeners[id] then charListeners[id] = nil; return true end
            return false
        end

        --- (0.11.0) Every character in right now: { { source, citizenid }, ... } by player id.
        --- Players online without a loaded character are left out. false plus 'unsupported'
        --- where the framework module has no CharacterEvents.
        fw.OnlineCharacters = function()
            if not wireCharacters(core) then return false, 'unsupported' end
            local out = {}
            for _, s in ipairs(GetPlayers and GetPlayers() or {}) do
                local src = tonumber(s)
                local cid = src and (Helpers.Identifier(src) or chars[src])
                if cid then
                    if not chars[src] then chars[src] = cid end
                    out[#out + 1] = { source = src, citizenid = cid }
                end
            end
            table.sort(out, function(a, b) return a.source < b.source end)
            return out
        end
    end

    --- (0.11.0) Is this player dead, in last stand, or restrained (cuffed) right now? Server side.
    --- -> { dead, lastStand, cuffed, from = { dead = 'metadata' | 'state:<key>' | 'entity:<key>' | 'health', ... } }
    --- or nil plus 'no_player'. Reads, in order: the framework's own fields (Qbox and QBCore
    --- metadata isdead, inlaststand, ishandcuffed; ESX keeps none on the server), the player
    --- state bag and the ped's entity state bag under the keys common scripts use (CONDITION_KEYS),
    --- and the ped's health (below 100 = dead in GTA). It cannot know a state a script keeps only
    --- on the client (esx_policejob and qb-policejob keep "cuffed" in a client variable) or under
    --- a key not in the list: add yours to CONDITION_KEYS in server/extras.lua.
    if fw then fw.Condition = function(src) return condition(fw, src) end end

    local db = core.Database
    if db then
        --- (0.11.0) See docs.md: all queries in one transaction; `expect` = rows it must touch.
        db.Transaction = function(queries) return transaction(queries) end
        --- (0.11.0) See docs.md: one multi-row INSERT; returns the affected row count.
        db.BatchInsert = function(tableName, columns, rows, opts) return batchInsert(db, tableName, columns, rows, opts) end
    end

    if core.Inventory then attachInventory(core) end
    --- (0.11.0) The inventory name when item metadata helpers work here, else false plus
    --- 'no_inventory' or 'unsupported_inventory'.
    core.ItemMetaSupport = function() return metaSupport(core) end
end
