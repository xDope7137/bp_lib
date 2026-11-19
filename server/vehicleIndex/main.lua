--[[
    Vehicle index (Core.Vehicles): answers "which entity carries this plate" and "is this
    spot free" without a loop over every vehicle per question.

    How it stays cheap:
      - Nothing runs and nothing is stored until a script asks its first question. After
        UNLOAD without a question the index is thrown away again, so a server that does not
        use it pays nothing.
      - entityCreated / entityRemoved keep the list of vehicles. The game's own list
        (GetAllVehicles) is only used to catch cars no event announced: one call per sweeper
        pass and at most one a second on a miss or a spot check. No native runs per car there.
      - Plates are indexed. A hit is re-read before it is returned, so a hit is always true.
        A miss re-reads only what can have changed: with the car's model, the cars of that
        model; without it, cars with no plate yet, cars younger than SETTLE, and cars not
        read for longer than the caller's maxAge.
      - Positions sit in a grid of CELL metre squares. A spot check reads the few cars in
        the squares around it, the cars that were moving at their last read, and the cars
        players sit in. Parked cars elsewhere are never touched.
      - One sweeper re-reads a slice of the list every TICK: a full pass takes about CYCLE,
        and a slice is never more than SLICE cars, so its cost has a ceiling however big
        the server is (past 4800 cars the pass gets longer instead). It sleeps when nobody
        has asked anything for IDLE.

    Memory: 0.3 to 0.8 KB per vehicle (measured when the index loads, shown by `bp_vehicles`).
    One small record per car; a plate or a grid square
    that holds one car stores the entity itself, not a table.

    Plates compare trimmed and in upper case. Entity handles are the server's, the same in
    every resource.
]]

local TICK = 250         -- ms between sweeper slices
local CYCLE = 8000       -- ms for one full pass
local SLICE = 150        -- most cars one slice reads
local IDLE = 120000      -- ms without a question before the sweeper sleeps
local UNLOAD = 900000    -- ms without a question before the index is thrown away
local SETTLE = 30000     -- ms a new car's plate is not trusted (scripts set it after the spawn)
local PLATE_AGE = 10000  -- default maxAge of Find
local POS_AGE = 15000    -- a grid position older than this is read again before a spot check
local RECONCILE = 1000   -- ms: a miss or a spot check asks the game for unannounced cars at most this often
local CELL = 64.0
local MARGIN = 32.0      -- how far a parked car may have rolled since its last read
local MOVED = 1.0        -- metres between two reads that make a car "moving"

VehicleIndex = {}

local recs = {}     -- [entity] = { plate, plateAt, pos, posAt }
local count = 0
local modelOf = {}  -- [entity] = model hash, unsigned
local rawOf = {}    -- [entity] = plate text as the game gives it, only when it differs from plate
local byPlate = {}  -- [PLATE] = entity, or { [entity] = true } when several carry it
local cells = {}    -- [cell key] = entity, or { [entity] = true }
local byModel = {}  -- [model] = { [entity] = true }
local unread = {}   -- [entity] = true, plate still empty
local young = {}    -- [entity] = time it was created, while younger than SETTLE
local moving = {}   -- [entity] = true, moved between its last two reads (or never read twice)

local started, running, asleep = false, false, false
local cursor, lastUse, reconciledAt = nil, 0, 0
-- For `bp_vehicles`: what keeping the index costs. Reading the clock costs more than a
-- lookup does, so only one slice in 16 and one lookup in 64 is timed. os.clock() is the
-- whole server process, so on a busy server these are upper bounds.
local cost = { slices = 0, sweep = 0, timedSlices = 0, lookups = 0, lookup = 0, timedLookups = 0, perCar = 0.3 }

local function norm(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper()
end

--- Model as one unsigned hash: a spawn name, a number in a string, or a signed hash.
local function modelKey(model)
    local n = type(model) == 'number' and model or tonumber(model)
    if not n then n = joaat(tostring(model)) end
    return math.floor(n) % 4294967296
end

local function cellOf(pos)
    return (math.floor(pos.x / CELL) + 2048) * 4096 + math.floor(pos.y / CELL) + 2048
end

-- A slot holds nothing, one entity (the number itself) or a set of entities.
local function put(map, key, entity)
    local cur = map[key]
    if cur == nil then
        map[key] = entity
    elseif type(cur) == 'table' then
        cur[entity] = true
    elseif cur ~= entity then
        map[key] = { [cur] = true, [entity] = true }
    end
end

local function take(map, key, entity)
    local cur = map[key]
    if cur == entity then
        map[key] = nil
    elseif type(cur) == 'table' then
        cur[entity] = nil
        local one = next(cur)
        if one == nil then map[key] = nil elseif next(cur, one) == nil then map[key] = one end
    end
end

local function drop(entity)
    local rec = recs[entity]
    if not rec then return end
    if cursor == entity then cursor = next(recs, entity) end   -- keep the sweeper's place
    if rec.plate ~= '' then take(byPlate, rec.plate, entity) end
    if rec.pos then take(cells, cellOf(rec.pos), entity) end
    local model = modelOf[entity]
    if model then
        local same = byModel[model]
        same[entity] = nil
        if next(same) == nil then byModel[model] = nil end
    end
    recs[entity], modelOf[entity], rawOf[entity] = nil, nil, nil
    unread[entity], young[entity], moving[entity] = nil, nil, nil
    count = count - 1
end

--- Reads the plate again. false when the entity is gone (and now forgotten).
local function readPlate(entity, rec, now)
    if not DoesEntityExist(entity) then drop(entity) return false end
    local raw = GetVehicleNumberPlateText(entity)
    if raw ~= (rawOf[entity] or rec.plate) then   -- same text as last time: nothing to do
        local plate = norm(raw)
        rawOf[entity] = raw ~= plate and raw or nil
        if plate ~= rec.plate then
            if rec.plate ~= '' then take(byPlate, rec.plate, entity) end
            rec.plate = plate
            if plate ~= '' then put(byPlate, plate, entity) end
        end
        unread[entity] = plate == '' or nil
    end
    rec.plateAt = now
    local born = young[entity]
    if born and now - born > SETTLE then young[entity] = nil end
    return true
end

--- Reads the position again. Returns it, or nil when the entity is gone.
local function readPos(entity, rec, now)
    if not DoesEntityExist(entity) then drop(entity) return nil end
    local pos = GetEntityCoords(entity)
    local old = rec.pos
    local cell = cellOf(pos)
    if not old then
        put(cells, cell, entity)
    else
        local was = cellOf(old)
        if was ~= cell then
            take(cells, was, entity)
            put(cells, cell, entity)
        end
    end
    -- A car is "moving" until two reads in a row find it in the same place.
    moving[entity] = (not old or #(pos - old) > MOVED) or nil
    rec.pos, rec.posAt = pos, now
    return pos
end

local function add(entity, now, isNew)
    if recs[entity] then return end
    local rec = { plate = '', plateAt = now, pos = false, posAt = now }
    recs[entity] = rec
    count = count + 1
    unread[entity] = true
    if isNew then young[entity] = now end
    if readPlate(entity, rec, now) then
        local model = modelKey(GetEntityModel(entity))
        modelOf[entity] = model
        local same = byModel[model]
        if not same then same = {}; byModel[model] = same end
        same[entity] = true
        readPos(entity, rec, now)
    end
end

AddEventHandler('entityCreated', function(entity)
    if started and DoesEntityExist(entity) and GetEntityType(entity) == 2 then add(entity, GetGameTimer(), true) end
end)

AddEventHandler('entityRemoved', function(entity)
    if started then drop(entity) end
end)

local function clear()
    recs, modelOf, rawOf, byPlate, cells, byModel, unread, young, moving = {}, {}, {}, {}, {}, {}, {}, {}, {}
    count, cursor = 0, nil
end

--- Builds the index from the game. Returns the number of vehicles.
function VehicleIndex.Resync()
    clear()
    started = true
    collectgarbage()
    local before = collectgarbage('count')
    local now = GetGameTimer()
    for _, entity in ipairs(GetAllVehicles()) do
        add(entity, now, false)   -- only cars we see being created are known to be new
    end
    reconciledAt = now
    if count >= 50 then
        collectgarbage()
        cost.perCar = math.max(0.1, (collectgarbage('count') - before) / count)
    end
    return count
end

--- Adds what the events did not announce. FXServer sends no entityCreated for a car made
--- with CreateVehicleServerSetter, so the game's own list is checked here: one
--- GetAllVehicles() call and a table lookup per car, no native per car.
local function reconcile(now)
    reconciledAt = now
    local all = GetAllVehicles()
    for i = 1, #all do
        if not recs[all[i]] then add(all[i], now, true) end
    end
end

local function sweep()
    cost.slices = cost.slices + 1
    local t = cost.slices % 16 == 0 and os.clock()
    local now = GetGameTimer()
    for _ = 1, math.min(count, SLICE, math.max(10, math.ceil(count * TICK / CYCLE))) do
        cursor = next(recs, cursor)
        if cursor == nil then
            reconcile(now)   -- once per full pass
            cursor = next(recs)
            if cursor == nil then break end
        end
        local entity, rec = cursor, recs[cursor]
        if readPlate(entity, rec, now) then readPos(entity, rec, now) end
    end
    if t then cost.sweep, cost.timedSlices = cost.sweep + (os.clock() - t), cost.timedSlices + 1 end
end

--- Every question calls this: it builds the index on the first one and keeps the sweeper awake.
local function touch()
    lastUse = GetGameTimer()
    if not started then VehicleIndex.Resync() end
    if running then return end
    running = true
    CreateThread(function()
        while true do
            local quiet = GetGameTimer() - lastUse
            if quiet >= UNLOAD then
                started = false
                clear()
                break
            elseif quiet >= IDLE then
                asleep = true
                Wait(5000)
            else
                asleep = false
                sweep()
                Wait(TICK)
            end
        end
        running, asleep = false, false
    end)
end

--- Tell the index about a car right after spawning it on the server, so it is known
--- before the next catch-up. Does nothing while no script uses the index.
function VehicleIndex.Add(entity)
    if started and type(entity) == 'number' and DoesEntityExist(entity) and GetEntityType(entity) == 2 then
        add(entity, GetGameTimer(), true)
    end
end

local function carrying(key, now)
    local hits = byPlate[key]
    if hits == nil then return {} end
    local found = {}
    if type(hits) == 'number' then
        local rec = recs[hits]
        if readPlate(hits, rec, now) and rec.plate == key then found[1] = hits end
        return found
    end
    local check = {}
    for entity in pairs(hits) do check[#check + 1] = entity end
    for i = 1, #check do
        local entity = check[i]
        local rec = recs[entity]
        if rec and readPlate(entity, rec, now) and rec.plate == key then found[#found + 1] = entity end
    end
    return found
end

local function find(plate, maxAge, model)
    local key = norm(plate)
    if key == '' then return {} end
    local now = GetGameTimer()
    local found = carrying(key, now)
    if #found > 0 then return found end

    maxAge = tonumber(maxAge) or PLATE_AGE
    if maxAge <= 0 or now - reconciledAt >= RECONCILE then reconcile(now) end
    for entity in pairs(model ~= nil and (byModel[modelKey(model)] or {}) or recs) do
        local rec = recs[entity]
        if rec.plate == '' or young[entity] or now - rec.plateAt >= maxAge then
            readPlate(entity, rec, now)
        end
    end
    return carrying(key, now)
end

--- Entities whose plate is `plate`, as an array (empty when none).
--- maxAge (ms, default 10000): how old a plate reading may be before a miss is believed.
--- 0 re-reads on every miss: use it where money depends on "the car is gone".
--- model (spawn name or hash, optional): the model of the car you are looking for. A miss
--- then re-reads only the cars of that model, a handful instead of the whole server, and
--- with maxAge 0 it is still exact for that car. Give it whenever you know it.
function VehicleIndex.Find(plate, maxAge, model)
    touch()
    cost.lookups = cost.lookups + 1
    if cost.lookups % 64 ~= 0 then return find(plate, maxAge, model) end
    local t = os.clock()
    local found = find(plate, maxAge, model)
    cost.lookup, cost.timedLookups = cost.lookup + (os.clock() - t), cost.timedLookups + 1
    return found
end

--- Model hashes of the vehicles whose plate still reads empty (no client has owned them
--- yet). Any of them could be the car a plate search missed.
function VehicleIndex.UnreadModels()
    touch()
    local now = GetGameTimer()
    reconcile(now)
    local models = {}
    for entity in pairs(unread) do
        local rec = recs[entity]
        if readPlate(entity, rec, now) and rec.plate == '' then models[#models + 1] = modelOf[entity] end
    end
    return models
end

--- True when a vehicle of this model has a plate that still reads empty: it could be the
--- car a plate search missed. Reads only the cars of that model.
function VehicleIndex.Unread(model)
    touch()
    local now = GetGameTimer()
    reconcile(now)
    local same = byModel[modelKey(model)]
    if not same then return false end
    local any = false
    for entity in pairs(same) do
        if unread[entity] then
            local rec = recs[entity]
            if readPlate(entity, rec, now) and rec.plate == '' then any = true end
        end
    end
    return any
end

--- A parked car (by the grid) within `radius` of `at`, read live.
local function parkedAt(entity, at, radius, reach, seen)
    return not seen[entity] and #(recs[entity].pos - at) <= reach
        and DoesEntityExist(entity) and #(GetEntityCoords(entity) - at) <= radius
end

local function firstFree(points, radius)
    radius = tonumber(radius) or 2.5
    local now = GetGameTimer()
    -- Cars no event announced. A script that spawns on the server calls Add, so this only
    -- has to catch other scripts' cars, and at most once a second.
    if now - reconciledAt >= RECONCILE then reconcile(now) end

    -- Positions we do not trust the grid for, read now: stale ones (the sweeper slept),
    -- cars that were moving, and cars players are in (they may have set off since).
    local live, seen = {}, {}
    for entity, rec in pairs(recs) do
        if moving[entity] or now - rec.posAt > POS_AGE then
            seen[entity] = true
            live[#live + 1] = readPos(entity, rec, now)
        end
    end
    for _, src in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(src)
        local entity = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        local rec = entity ~= 0 and not seen[entity] and recs[entity]
        if rec then
            seen[entity] = true
            live[#live + 1] = readPos(entity, rec, now)
        end
    end

    local reach = radius + MARGIN
    for index = 1, #points do
        local p = points[index]
        local at = vector3(p.x, p.y, p.z)
        local free = true
        for i = 1, #live do
            if #(live[i] - at) <= radius then free = false break end
        end
        if free then
            for cx = math.floor((at.x - reach) / CELL), math.floor((at.x + reach) / CELL) do
                for cy = math.floor((at.y - reach) / CELL), math.floor((at.y + reach) / CELL) do
                    local here = cells[(cx + 2048) * 4096 + cy + 2048]
                    if type(here) == 'number' then
                        if parkedAt(here, at, radius, reach, seen) then free = false end
                    elseif here then
                        for entity in pairs(here) do
                            if parkedAt(entity, at, radius, reach, seen) then free = false break end
                        end
                    end
                    if not free then break end
                end
                if not free then break end
            end
        end
        if free then return index end
    end
    return nil
end

--- Index of the first point with no vehicle within `radius`, or nil when all are taken.
--- points: array of anything with x, y, z.
function VehicleIndex.FirstFree(points, radius)
    touch()
    cost.lookups = cost.lookups + 1
    if cost.lookups % 64 ~= 0 then return firstFree(points, radius) end
    local t = os.clock()
    local index = firstFree(points, radius)
    cost.lookup, cost.timedLookups = cost.lookup + (os.clock() - t), cost.timedLookups + 1
    return index
end

--- True when a vehicle stands within `radius` of the point.
function VehicleIndex.Near(point, radius)
    return VehicleIndex.FirstFree({ point }, radius) == nil
end

--- Every vehicle entity, as an array. For a one-time pass (a script start), not for lookups.
function VehicleIndex.All()
    touch()
    local all = {}
    for entity in pairs(recs) do all[#all + 1] = entity end
    return all
end

--- Counts, and what the index costs: memoryKB (estimate), sweeperUsPerSecond (while awake),
--- lookups and lookupUs (average of the sampled ones). Does not start the index.
function VehicleIndex.Stats()
    local function size(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
    return { loaded = started, vehicles = count, plates = size(byPlate), unread = size(unread), young = size(young),
        moving = size(moving), cells = size(cells), models = size(byModel), sweeping = running and not asleep,
        memoryKB = count * cost.perCar,
        sweeperUsPerSecond = cost.timedSlices > 0 and cost.sweep * 1e6 / cost.timedSlices * 1000 / TICK or 0,
        lookups = cost.lookups, lookupUs = cost.timedLookups > 0 and cost.lookup * 1e6 / cost.timedLookups or 0 }
end

-- `bp_vehicles bench`: times the old way (GetAllVehicles + a loop) against the index on this
-- server's real world. It only reads; it spawns and changes nothing.
local function bench()
    local all = GetAllVehicles()
    local plates, models = {}, {}
    for _, e in ipairs(all) do
        local p = norm(GetVehicleNumberPlateText(e))
        if p ~= '' then plates[#plates + 1] = p; models[#models + 1] = GetEntityModel(e) end
    end
    VehicleIndex.Find('NOPE')   -- load the index and wake the sweeper, as on a server in use
    local st = VehicleIndex.Stats()
    print(('[bp_lib] bench: %d vehicles in the game, %d in the index, %d without a plate, %d new, %d models'):format(
        #all, st.vehicles, st.unread, st.young, st.models))
    if #plates == 0 then print('[bp_lib] bench: no plated vehicle to look up') return end

    local function oldFind(plate)
        local found = {}
        for _, e in ipairs(GetAllVehicles()) do
            if DoesEntityExist(e) and norm(GetVehicleNumberPlateText(e)) == plate then found[#found + 1] = e end
        end
        return found
    end
    local function oldNear(at, radius)
        for _, e in ipairs(GetAllVehicles()) do
            if DoesEntityExist(e) and #(GetEntityCoords(e) - at) <= radius then return true end
        end
        return false
    end
    local function time(runs, fn)
        local t = os.clock()
        for i = 1, runs do fn(i) end
        return (os.clock() - t) * 1000000 / runs   -- microseconds per call
    end
    local runs = 300
    local spots = {}
    for i = 1, runs do
        -- Half the spots sit next to a real car, as garage spawn points do.
        local near = i % 2 == 0 and GetEntityCoords(all[(i * 31) % #all + 1])
        spots[i] = near and vector3(near.x + 6.0, near.y, near.z) or vector3(math.random(-3000, 3000) + 0.0, math.random(-3000, 3000) + 0.0, 30.0)
    end
    local function pick(i) return (i * 7919) % #plates + 1 end
    local old = {
        out = time(runs, function(i) oldFind(plates[pick(i)]) end),
        gone = time(runs, function(i) oldFind('NOPE' .. i) end),
        spot = time(runs, function(i) oldNear(spots[i], 2.5) end),
    }
    local rows = {
        { 'car is out', old.out, time(runs, function(i) VehicleIndex.Find(plates[pick(i)]) end) },
        { 'car is gone, model known (lists)', old.gone, time(runs, function(i) VehicleIndex.Find('NOPE' .. i, nil, models[pick(i)]) end) },
        { 'car is gone, model known (claims, exact)', old.gone, time(runs, function(i) VehicleIndex.Find('NOPE' .. i, 0, models[pick(i)]) end) },
        { 'car is gone, no model (lists)', old.gone, time(runs, function(i) VehicleIndex.Find('NOPE' .. i) end) },
        { 'car is gone, no model (exact)', old.gone, time(runs, function(i) VehicleIndex.Find('NOPE' .. i, 0) end) },
        { 'spot check', old.spot, time(runs, function(i) VehicleIndex.Near(spots[i], 2.5) end) },
    }
    for _, r in ipairs(rows) do
        print(('[bp_lib] bench: %-42s old %9.1f us   index %8.1f us   %5.1f%% less time (%.1fx)'):format(
            r[1], r[2], r[3], (1 - r[3] / r[2]) * 100, r[2] / math.max(r[3], 0.001)))
    end
    print(('[bp_lib] bench: one reconcile (GetAllVehicles + table lookups) %.1f us'):format(time(50, function() reconcile(GetGameTimer()) end)))
    -- What the sweeper costs while awake: one slice, four times a second.
    local slice = time(40, sweep)
    print(('[bp_lib] bench: sweeper slice %.1f us, %.1f us per second while awake (%.4f%% of one core)'):format(slice, slice * 1000 / TICK, slice * 1000 / TICK / 10000))
end

-- `bp_vehicles check`: compares the index with a full scan of the game, to prove it is in
-- step. Cars the game has and the index does not ("missing") are fine for up to a second
-- after a server-side spawn; plates may lag by one sweeper pass.
local function check()
    touch()
    local now = GetGameTimer()
    local all = GetAllVehicles()
    local missing, stale, oldPlate, oldPos = 0, 0, 0, 0
    for i = 1, #all do
        local entity = all[i]
        local rec = recs[entity]
        if not rec then
            missing = missing + 1
        else
            if norm(GetVehicleNumberPlateText(entity)) ~= rec.plate then stale = stale + 1 end
            oldPlate, oldPos = math.max(oldPlate, now - rec.plateAt), math.max(oldPos, now - rec.posAt)
        end
    end
    local ghosts = 0
    for entity in pairs(recs) do
        if not DoesEntityExist(entity) then ghosts = ghosts + 1 end
    end
    print(('[bp_lib] check: game %d, index %d, missing %d, ghosts %d, stale plates %d, oldest plate reading %d ms, oldest position %d ms, bp_lib memory %.0f KB'):format(
        #all, count, missing, ghosts, stale, oldPlate, oldPos, collectgarbage('count')))
end

-- Console: `bp_vehicles` prints the index and what it costs, `bp_vehicles resync` rebuilds it from the game,
-- `bp_vehicles find <plate>` shows where the cars with that plate are, `bp_vehicles bench`
-- times the index against a GetAllVehicles() loop, `bp_vehicles check` compares it with the game.
RegisterCommand('bp_vehicles', function(src, args)
    if src ~= 0 then return end
    if args[1] == 'resync' then VehicleIndex.Resync() end
    if args[1] == 'bench' then
        CreateThread(bench)
        return
    end
    if args[1] == 'check' then return check() end
    if args[1] == 'find' then
        local plate = table.concat(args, ' ', 2)
        local found = VehicleIndex.Find(plate, 0)
        print(('[bp_lib] %d vehicle(s) with plate "%s"'):format(#found, norm(plate)))
        for _, entity in ipairs(found) do
            local at = GetEntityCoords(entity)
            print(('[bp_lib]   entity %d at %.1f, %.1f, %.1f, spot taken: %s'):format(entity, at.x, at.y, at.z,
                tostring(VehicleIndex.Near(at, 2.5))))
        end
        return
    end
    local s = VehicleIndex.Stats()
    if not s.loaded then
        print('[bp_lib] vehicle index: not loaded (no script has asked it anything): costs nothing')
        return
    end
    print(('[bp_lib] vehicle index: %d vehicles, %d plates, %d unread, %d new, %d moving, %d cells, %d models, sweeper %s'):format(
        s.vehicles, s.plates, s.unread, s.young, s.moving, s.cells, s.models, s.sweeping and 'awake' or 'asleep'))
    print(('[bp_lib] cost: about %.0f KB of memory (all of bp_lib: %.0f KB), sweeper %.1f us per second while awake (%.4f%% of one core), %d lookups at about %.1f us each'):format(
        s.memoryKB, collectgarbage('count'), s.sweeperUsPerSecond, s.sweeperUsPerSecond / 10000, s.lookups, s.lookupUs))
    local some = {}
    for plate in pairs(byPlate) do
        some[#some + 1] = plate
        if #some == 5 then break end
    end
    if #some > 0 then print('[bp_lib] some plates: ' .. table.concat(some, ', ')) end
end, true)
