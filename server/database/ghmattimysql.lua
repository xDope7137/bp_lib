Database = {
    FetchSync = function(query, params)
        return exports.ghmattimysql:execute(query, params)
    end,

    ExecuteSync = function(query, params)
        return exports.ghmattimysql:execute(query, params)
    end,

    Insert = function(query, params, callback)
        exports.ghmattimysql:execute(query, params, callback)
    end,

    Execute = function(query, params, callback)
        exports.ghmattimysql:execute(query, params, callback)
    end,

    ScalarSync = function(query, params)
        return exports.ghmattimysql:scalarSync(query, params)
    end,

    SingleSync = function(query, params)
        local rows = exports.ghmattimysql:executeSync(query, params)
        return rows and rows[1]
    end,

    UpdateSync = function(query, params) -- returns affected rows
        local result = exports.ghmattimysql:executeSync(query, params)
        return result and result.affectedRows
    end,

    InsertSync = function(query, params) -- returns insert id
        local result = exports.ghmattimysql:executeSync(query, params)
        return result and result.insertId
    end
}

return Database