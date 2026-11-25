Database = {
    FetchSync = function(query, params)
        return MySQL.Sync.fetchAll(query, params)
    end,
    
    ExecuteSync = function(query, params)
        return MySQL.Sync.execute(query, params)
    end,

    Insert = function(query, params, callback)
        MySQL.Async.insert(query, params, callback)
    end,
    
    Execute = function(query, params, callback)
        MySQL.Async.execute(query, params, callback)
    end,

    ScalarSync = function(query, params)
        return MySQL.Sync.fetchScalar(query, params)
    end,

    SingleSync = function(query, params)
        local rows = MySQL.Sync.fetchAll(query, params)
        return rows and rows[1]
    end,

    UpdateSync = function(query, params) -- returns affected rows
        return MySQL.Sync.execute(query, params)
    end,

    InsertSync = function(query, params) -- returns insert id
        return MySQL.Sync.insert(query, params)
    end
}

return Database