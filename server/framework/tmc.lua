TMC = exports[Config.FrameworkResource]:getCoreObject()

Framework = {
    Name = "tmc",
    RegisterCallback = function(name, cb, ...)
        TMC.Functions.RegisterServerCallback(name, cb)
    end,
    GetIdentifier = function(player)
        local Player = TMC.Functions.GetPlayer(player)
        if not Player then return end
        return Player.PlayerData.citizenid
    end,
    GetIdentifierID = function(identifier)
        local player = TMC.Functions.GetPlayerByCitizenId(identifier)
        if not player then return false end
        return player.PlayerData.source
    end,
    GetCharName = function(player)
        local Player = TMC.Functions.GetPlayer(player)
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
            local jobCount = TMC.Common.OnlinePlayersWithJob(job, true)
            count = count + jobCount
        end
        
        return count
    end,
    GetPlayers = function()
        return TMC.Functions.GetPlayers()
    end,
    HasGroup = function(player, group)
        return TMC.Functions.HasPermission(player, group)
    end,
    Money = {
        Give = function(player, amount, account)
            local Player = TMC.Functions.GetPlayer(player)
            if not Player then return false end
            
            if account == "black_money" then
                if Inventory then
                    return Inventory.AddItem(player, "cash_roll", amount)
                else
                    Player.Functions.AddItem("cash_roll", amount)
                    return true
                end
            end

            if account == "cash" then
                Player.Functions.AddMoney(account, amount, 'Transaction')
                return true
            elseif account == "bank" then
                if TMC.Common.IsDepRunning('banking') and exports['banking']:AccountExists(Player.PlayerData.charinfo.account) then
                    exports['banking']:BankDeposit(Player.PlayerData.charinfo.account, amount, 'Transaction')
                    return true
                else
                    Player.Functions.AddMoney("bank", amount, 'Transaction')
                    return true
                end
            end
            return false
        end,
        Get = function(player, account)
            if account == "black_money" then
                if Inventory then
                    local item = Inventory.GetItem(player, "cash_roll")
                    if not item then return 0 end
                    return item.count
                else
                    local Player = TMC.Functions.GetPlayer(player)
                    if not Player then return 0 end
                    local item = Player.Functions.GetItemByName("cash_roll")
                    return item and item.amount or 0
                end
            end
            
            local Player = TMC.Functions.GetPlayer(player)
            if not Player then return 0 end

            if account == "cash" then
                return Player.PlayerData.money.cash or 0
            end

            if account == "bank" then
                if TMC.Common.IsDepRunning('banking') then
                    local bankData = exports["banking"]:GetAccount(Player.PlayerData.charinfo.account)
                    if bankData then
                        return bankData.balance or 0
                    end
                end
                return Player.PlayerData.money.bank or 0
            end

            return 0
        end,
        Remove = function(player, amount, account)
            local Player = TMC.Functions.GetPlayer(player)
            if not Player then return false end
            
            if account == "black_money" then
                if Inventory then
                    return Inventory.RemoveItem(player, "cash_roll", amount)
                else
                    Player.Functions.RemoveItem("cash_roll", amount)
                    return true
                end
            end

            if account == "cash" then
                Player.Functions.RemoveMoney(account, amount, 'Transaction')
                return true
            elseif account == "bank" then
                if TMC.Common.IsDepRunning('banking') and exports['banking']:AccountExists(Player.PlayerData.charinfo.account) then
                    exports['banking']:BankWithdraw(Player.PlayerData.charinfo.account, amount, 'Transaction')
                    return true
                else
                    Player.Functions.RemoveMoney("bank", amount, 'Transaction')
                    return true
                end
            end
            return false
        end,
    },
    Job = {
        Get = function(player)
            local Player = TMC.Functions.GetPlayer(player)
            if not Player then return end

            if Player.PlayerData.jobs then
                for k, v in pairs(Player.PlayerData.jobs) do
                    if v.onduty then
                        return v.name
                    end
                end

                for k, v in pairs(Player.PlayerData.jobs) do
                    return v.name
                end
            end
            
            return nil
        end,

        GetLabel = function(player)
            local Player = TMC.Functions.GetPlayer(player)
            if not Player then return end

            if Player.PlayerData.jobs then
                for k, v in pairs(Player.PlayerData.jobs) do
                    if v.onduty then
                        return v.label
                    end
                end

                for k, v in pairs(Player.PlayerData.jobs) do
                    return v.label
                end
            end
            
            return nil
        end,

        GetGrade = function(player)
            local Player = TMC.Functions.GetPlayer(player)
            if not Player then return 0 end

            if Player.PlayerData.jobs then
                for k, v in pairs(Player.PlayerData.jobs) do
                    if v.onduty then
                        return v.grade.level
                    end
                end

                for k, v in pairs(Player.PlayerData.jobs) do
                    return v.grade.level
                end
            end

            return 0
        end,

        GetGradeLabel = function(player)
            local Player = TMC.Functions.GetPlayer(player)
            if not Player then return end

            if Player.PlayerData.jobs then
                for k, v in pairs(Player.PlayerData.jobs) do
                    if v.onduty then
                        return v.grade.name
                    end
                end

                for k, v in pairs(Player.PlayerData.jobs) do
                    return v.grade.name
                end
            end
            
            return nil
        end,
    }
}

return Framework