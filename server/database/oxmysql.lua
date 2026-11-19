Database = {
    FetchSync = function(query, params)
        return exports.oxmysql:executeSync(query, params)
    end,
    ExecuteSync = function(query, params)
        return exports.oxmysql:executeSync(query, params)
    end,
    Insert = function(query, params, callback)
        exports.oxmysql:insert(query, params, callback)
    end,
    Execute = function(query, params, callback)
        exports.oxmysql:execute(query, params, callback)
    end,
    ScalarSync = function(query, params)
        return exports.oxmysql:scalarSync(query, params)
    end,
    SingleSync = function(query, params)
        return exports.oxmysql:singleSync(query, params)
    end,
    UpdateSync = function(query, params) -- returns affected rows
        return exports.oxmysql:updateSync(query, params)
    end,
    InsertSync = function(query, params) -- returns insert id
        return exports.oxmysql:insertSync(query, params)
    end
}

return Database