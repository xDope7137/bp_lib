--[[
    0.12.0 additions on the server Core (job and gang reads), attached by server/main.lua after
    AttachServerExtras. The framework module gives one table, `JobData` (see qbx.lua, qb.lua,
    esx.lua); this file turns it into one shape for every framework:

      Core.Framework.JobOf(src)            the active job:  { name, label, grade, gradeLabel, boss, bankAuth, onDuty }
      Core.Framework.GangOf(src)           the gang (QBCore and Qbox): the same shape, onDuty nil
      Core.Framework.OnJob(cb) / OffJob    cb({ source, citizenid, kind = 'job' | 'gang', name, grade }) after a change
      Core.Framework.JobList(kind)         { [name] = { label, grades = { [level] = { label, boss, bankAuth } } } }
      Core.Framework.PaycheckSociety()     true / false: paychecks come from the job's society account; nil = unknown
      Core.Framework.CharactersWithJob(cids, name, kind)   which of these characters hold it (any slot), one query

    Reads only: nothing here changes a job. Memory reads (JobOf, GangOf, JobList) never query.
]]

local KINDS = { job = true, gang = true }

local function callable(cb)
    return type(cb) == 'function' or (type(cb) == 'table' and getmetatable(cb) ~= nil and getmetatable(cb).__call ~= nil)
end

-- one shape out of whatever the module read (never trusts its types)
local function seatOf(j, kind)
    if type(j) ~= 'table' or type(j.name) ~= 'string' or j.name == '' then return nil end
    local out = {
        name = j.name,
        label = type(j.label) == 'string' and j.label ~= '' and j.label or j.name,
        grade = math.tointeger(tonumber(j.grade)) or 0,
        gradeLabel = type(j.gradeLabel) == 'string' and j.gradeLabel or tostring(j.grade or 0),
        boss = j.boss == true,
        bankAuth = j.bankAuth == true or j.boss == true,
    }
    if kind == 'job' and j.onDuty ~= nil then out.onDuty = j.onDuty == true end
    return out
end

local function listOf(raw)
    if type(raw) ~= 'table' then return nil end
    local out = {}
    for name, j in pairs(raw) do
        if type(name) == 'string' and type(j) == 'table' then
            local grades = {}
            for level, g in pairs(type(j.grades) == 'table' and j.grades or {}) do
                local n = math.tointeger(tonumber(level))
                if n and type(g) == 'table' then
                    grades[n] = { label = type(g.label) == 'string' and g.label or tostring(g.name or n),
                        boss = g.boss == true, bankAuth = g.bankAuth == true or g.boss == true }
                end
            end
            out[name] = { label = type(j.label) == 'string' and j.label ~= '' and j.label or name, grades = grades }
        end
    end
    return out
end

local jobListeners, jobNextId, jobWired = {}, 0, false

local function jobDispatch(core, src, kind, name, grade)
    src = tonumber(src)
    if not src or src <= 0 then return end
    local okC, cid = pcall(core.Framework.GetIdentifier, src)
    local list = {}
    for _, l in pairs(jobListeners) do list[#list + 1] = l end
    table.sort(list, function(a, b) return a.id < b.id end)
    for _, l in ipairs(list) do
        local ev = { source = src, citizenid = okC and cid or nil, kind = kind, name = name, grade = math.tointeger(tonumber(grade)) }
        local ok, err = pcall(l.cb, ev)
        if not ok then print(('^1[bp_lib] OnJob listener of %s failed: %s^0'):format(l.res, tostring(err))) end
    end
end

local function wireJobs(core, data)
    if jobWired then return true end
    if type(data.events) ~= 'table' or #data.events == 0 then return false end
    jobWired = true
    for _, ev in ipairs(data.events) do
        AddEventHandler(ev.name, function(...)
            if next(jobListeners) == nil then return end
            local ok, src, kind, name, grade = pcall(ev.read, ...)
            if ok and src then jobDispatch(core, src, KINDS[kind] and kind or ev.kind or 'job', name, grade) end
        end)
    end
    return true
end

AddEventHandler('onResourceStop', function(res)
    for id, l in pairs(jobListeners) do
        if l.res == res then jobListeners[id] = nil end
    end
end)

function AttachJobExtras(core)
    local fw = core.Framework
    local data = fw and fw.JobData
    if type(data) ~= 'table' then return end

    --- (0.12.0) The player's active job, read from the framework's memory (no query), or nil
    --- (no player, no job). Only the active job: Qbox's other job slots give nothing.
    fw.JobOf = function(src)
        src = tonumber(src)
        if not src or src <= 0 then return nil end
        local ok, j = pcall(data.read, src, 'job')
        return ok and seatOf(j, 'job') or nil
    end

    --- (0.12.0) The player's gang (QBCore and Qbox; nil on ESX).
    fw.GangOf = function(src)
        src = tonumber(src)
        if not src or src <= 0 or data.gangs ~= true then return nil end
        local ok, j = pcall(data.read, src, 'gang')
        return ok and seatOf(j, 'gang') or nil
    end

    --- (0.12.0) Does this framework have gangs?
    fw.HasGangs = function() return data.gangs == true end

    --- (0.12.0) cb(ev) after a player's job or gang changed, ev = { source, citizenid, kind, name,
    --- grade }. Feeds lists and pushes only: read JobOf again for access. Returns an id, or false
    --- plus 'unsupported' / 'bad_callback'.
    fw.OnJob = function(cb)
        if not callable(cb) then return false, 'bad_callback' end
        if not wireJobs(core, data) then return false, 'unsupported' end
        jobNextId = jobNextId + 1
        jobListeners[jobNextId] = { id = jobNextId, cb = cb, res = Helpers.Caller() }
        return jobNextId
    end

    --- (0.12.0) Stops a listener made by OnJob. true when there was one.
    fw.OffJob = function(id)
        if jobListeners[id] then jobListeners[id] = nil; return true end
        return false
    end

    --- (0.12.0) Every job ('job') or gang ('gang') the framework knows, with its grades:
    --- { [name] = { label, grades = { [level] = { label, boss, bankAuth } } } }, or nil.
    fw.JobList = function(kind)
        if not KINDS[kind] or (kind == 'gang' and data.gangs ~= true) then return nil end
        local ok, raw = pcall(data.list, kind)
        return ok and listOf(raw) or nil
    end

    --- (0.12.0) Do paychecks come out of the job's society account? true / false, nil = unknown.
    fw.PaycheckSociety = function()
        if not data.paycheckSociety then return nil end
        local ok, v = pcall(data.paycheckSociety)
        if not ok or v == nil then return nil end
        return v == true
    end

    --- (0.12.0) Which of these characters (citizen ids, at most 10) hold the job or gang `name`,
    --- in any slot, online or not. One query. -> list of citizen ids, or false plus 'unsupported'
    --- / 'invalid' / 'failed'.
    fw.CharactersWithJob = function(cids, name, kind)
        kind = kind or 'job'
        if not KINDS[kind] or type(name) ~= 'string' or name == '' or #name > 64 or type(cids) ~= 'table' then return false, 'invalid' end
        local list = {}
        for _, c in ipairs(cids) do
            if type(c) == 'string' and c ~= '' and #c <= 64 then list[#list + 1] = c end
            if #list >= 10 then break end
        end
        if #list == 0 then return {} end
        local q = type(data.holders) == 'table' and data.holders[kind]
        if not q or not core.Database or not core.Database.FetchSync then return false, 'unsupported' end
        local marks = ('?, '):rep(#list):sub(1, -3)
        local params = { name }
        for _, c in ipairs(list) do params[#params + 1] = c end
        local ok, rows = pcall(core.Database.FetchSync, q:gsub('%(%?%)', '(' .. marks .. ')', 1), params)
        if not ok or type(rows) ~= 'table' then return false, 'failed' end
        local out = {}
        for _, r in ipairs(rows) do
            local c = r.cid
            if type(c) == 'string' then out[#out + 1] = c end
        end
        return out
    end
end
