if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qb' then
    QBCore = exports['qb-core']:GetSharedObject()
elseif Config.Framework == 'qbx' then
    QBX = exports.qbx_core:GetCoreObject()
end

local function getPlayerTime(playerId)
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then return end
        local result = MySQL.scalar.await('SELECT playtime FROM users WHERE identifier = ?', {xPlayer.identifier})
        local playtime = result or 0
        local days = math.floor(playtime / 86400)
        local hours = math.floor((playtime % 86400) / 3600)
        local minutes = math.floor((playtime % 3600) / 60)
        local totalHours = (days * 24) + hours

        return {
            days = days,
            hours = hours,
            minutes = minutes,
            totalHours = totalHours,
            raw_playtime = playtime
        }
    elseif Config.Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if not Player then return end

        local result = MySQL.scalar.await('SELECT playtime FROM players WHERE citizenid = ?', {Player.PlayerData.citizenid})
        local playtime = result or 0
        local days = math.floor(playtime / 1440)
        local hours = math.floor((playtime % 1440) / 60)
        local minutes = playtime % 60
        local totalHours = math.floor(playtime / 60)

        return {
            days = days,
            hours = hours,
            minutes = minutes,
            totalHours = totalHours
        }
    elseif Config.Framework == 'qbx' then
        local Player = exports.qbx_core:GetPlayer(playerId)
        if not Player then return end

        local result = MySQL.scalar.await('SELECT playtime FROM players WHERE citizenid = ?', {Player.PlayerData.citizenid})
        local playtime = result or 0
        local days = math.floor(playtime / 1440)
        local hours = math.floor((playtime % 1440) / 60)
        local minutes = playtime % 60
        local totalHours = math.floor(playtime / 60)

        return {
            days = days,
            hours = hours,
            minutes = minutes,
            totalHours = totalHours
        }
    end
end

if Config.Framework == 'esx' then
    local function checkPlaytime(playerId)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then return end

        if Config.BypassJobs then
            for _, job in ipairs(Config.BypassJobs) do
                if xPlayer.job.name == job then
                    if Config.Debug then print("Player", playerId, "bypassed due to job:", job) end
                    return true
                end
            end
        end

        local time = getPlayerTime(playerId)
        if not time then return end
        if Config.Debug then print("Player", playerId, "has playtime:", time.totalHours, "required:", Config.RequiredHours) end

        if time.totalHours < Config.RequiredHours then
            local playtime_seconds = time.raw_playtime
            local required_seconds = Config.RequiredHours * 3600
            local missing_seconds = required_seconds - playtime_seconds
            local missing_hours = math.floor(missing_seconds / 3600)
            local missing_mins = math.floor((missing_seconds % 3600) / 60)
            if Config.Debug then print("Insufficient playtime for player", playerId, "missing", missing_hours, "hours", missing_mins, "minutes, disarming") end
            TriggerClientEvent('ox_inventory:disarm', playerId, false)
            TriggerClientEvent('chat:addMessage', playerId, {
                template = '^1[ ! ]^7 You dont have enough playtime to use a weapon, you are missing {0} hours and {1} minutes!',
                args = { missing_hours, missing_mins }
            })
            return false
        end
        if Config.Debug then print("Player has sufficient playtime") end
        return true
    end

    CreateThread(function()
        while true do
            Wait(60000)
            local xPlayers = ESX.GetPlayers()
            for i = 1, #xPlayers do
                local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
                if xPlayer then
                    MySQL.update('UPDATE users SET playtime = playtime + 60 WHERE identifier = ?', {xPlayer.identifier})
                end
            end
        end
    end)

    RegisterNetEvent('ragdoll-playtime:checkWeapon')
    AddEventHandler('ragdoll-playtime:checkWeapon', function(weapon)
        local playerId = source
        if Config.Debug then print("Server received checkWeapon for player", playerId, "weapon:", weapon and weapon.name or "none") end
        if not checkPlaytime(playerId) then
            Wait(100)
            TriggerClientEvent('ox_inventory:disarm', playerId, false)
        end
    end)

elseif Config.Framework == 'qb' or Config.Framework == 'qbx' then
    CreateThread(function()
        while true do
            local players
            if Config.Framework == 'qb' then
                players = QBCore.Functions.GetQBPlayers()
            elseif Config.Framework == 'qbx' then
                players = exports.qbx_core:GetQBPlayers()
            end
            for _, Player in pairs(players) do
                MySQL.update('UPDATE players SET playtime = playtime + 1 WHERE citizenid = ?', {Player.PlayerData.citizenid})
            end
            Wait(60000)
        end
    end)

    local function checkPlaytime(playerId)
        local Player
        if Config.Framework == 'qb' then
            Player = QBCore.Functions.GetPlayer(playerId)
        elseif Config.Framework == 'qbx' then
            Player = exports.qbx_core:GetPlayer(playerId)
        end
        if not Player then return end

        if Config.BypassJobs then
            for _, job in ipairs(Config.BypassJobs) do
                if Player.PlayerData.job.name == job then
                    if Config.Debug then print("Player", playerId, "bypassed due to job:", job) end
                    return true
                end
            end
        end

        local time = getPlayerTime(playerId)
        if not time then return end
        if Config.Debug then print("Player", playerId, "has playtime:", time.totalHours, "required:", Config.RequiredHours) end

        if time.totalHours < Config.RequiredHours then
            local playtime_minutes = time.raw_playtime
            local required_minutes = Config.RequiredHours * 60
            local missing_minutes = required_minutes - playtime_minutes
            local missing_hours = math.floor(missing_minutes / 60)
            local missing_mins = missing_minutes % 60
            if Config.Debug then print("Insufficient playtime for player", playerId, "missing", missing_hours, "hours", missing_mins, "minutes, disarming") end
            TriggerClientEvent('ox_inventory:disarm', playerId, false)
            TriggerClientEvent('chat:addMessage', playerId, {
                template = '^1[ ! ]^7 You dont have enough playtime to use a weapon, you are missing {0} hours and {1} minutes!',
                args = { missing_hours, missing_mins }
            })
            return false
        end
        if Config.Debug then print("Player has sufficient playtime") end
        return true
    end

    RegisterNetEvent('ragdoll-playtime:checkWeapon')
    AddEventHandler('ragdoll-playtime:checkWeapon', function(weapon)
        local playerId = source
        if Config.Debug then print("Server received checkWeapon for player", playerId, "weapon:", weapon and weapon.name or "none") end
        if not checkPlaytime(playerId) then
            Wait(100)
            TriggerClientEvent('ox_inventory:disarm', playerId, false)
        end
    end)
end

lib.addCommand({'pt', 'playtime'}, {
    help = 'Check your playtime'
}, function(source, args, raw)
    local time = getPlayerTime(source)
    if time then
        TriggerClientEvent('chat:addMessage', source, {
            template = '^1[ ! ]^7 Your current playtime is ^3{0} days, {1} hours, {2} minutes.^7',
            args = { time.days, time.hours, time.minutes }
        })
    end
end)

lib.addCommand('setplaytime', {
    help = 'Set playtime for a player (admin)',
    restricted = 'admin'
}, function(source, args, raw)
    if #args < 2 then
        TriggerClientEvent('chat:addMessage', source, {
            template = '^1[ ! ]^7 Usage: /setplaytime <playerId> <hours>'
        })
        return
    end
    local targetId = tonumber(args[1])
    local hours = tonumber(args[2])
    if not targetId or not hours then
        TriggerClientEvent('chat:addMessage', source, {
            template = '^1[ ! ]^7 Invalid arguments.'
        })
        return
    end
    if Config.Framework == 'qb' or Config.Framework == 'qbx' then
        local Player
        if Config.Framework == 'qb' then
            Player = QBCore.Functions.GetPlayer(targetId)
        elseif Config.Framework == 'qbx' then
            Player = exports.qbx_core:GetPlayer(targetId)
        end
        if not Player then
            TriggerClientEvent('chat:addMessage', source, {
                template = '^1[ ! ]^7 Player not found.'
            })
            return
        end
        MySQL.update('UPDATE players SET playtime = ? WHERE citizenid = ?', {hours * 60, Player.PlayerData.citizenid})
        TriggerClientEvent('chat:addMessage', source, {
            template = '^2[ ! ]^7 Set playtime for player {0} to {1} hours.',
            args = {targetId, hours}
        })
    elseif Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(targetId)
        if not xPlayer then
            TriggerClientEvent('chat:addMessage', source, {
                template = '^1[ ! ]^7 Player not found.'
            })
            return
        end
        MySQL.update('UPDATE users SET playtime = ? WHERE identifier = ?', {hours * 3600, xPlayer.identifier})
        TriggerClientEvent('chat:addMessage', source, {
            template = '^2[ ! ]^7 Set playtime for player {0} to {1} hours.',
            args = {targetId, hours}
        })
    end
end)
