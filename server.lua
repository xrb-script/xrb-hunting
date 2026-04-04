local playerHuntingData = {}
local ox_inventory = exports.ox_inventory

local function getWebhookConfig()
    return Config.Webhooks or {}
end

local function notify(source, message, msgType)
    XRB.Notify(source, {
        description = message,
        type = msgType or 'inform'
    })
end

local function getPlayerIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for i = 1, #identifiers do
        local id = identifiers[i]
        if id:find('license:', 1, true) then
            return id
        end
    end

    return ('src:%s'):format(src)
end

local function getIdentifierByPrefix(src, prefix)
    local identifiers = GetPlayerIdentifiers(src)
    local needle = tostring(prefix or '')
    for i = 1, #identifiers do
        local id = identifiers[i]
        if id:find(needle, 1, true) == 1 then
            return id
        end
    end

    return 'N/A'
end

local function getDiscordMention(src)
    local discord = getIdentifierByPrefix(src, 'discord:')
    local discordId = discord:match('discord:(%d+)')
    return discordId and ('<@%s>'):format(discordId) or 'N/A'
end

local function formatItemMap(items)
    if type(items) ~= 'table' then
        return 'N/A'
    end

    local parts = {}
    for label, amount in pairs(items) do
        parts[#parts + 1] = ('%sx %s'):format(math.max(math.floor(tonumber(amount) or 0), 0), tostring(label))
    end

    table.sort(parts)
    return #parts > 0 and table.concat(parts, '\n') or 'N/A'
end

local function getPlayerLogFields(src)
    local ped = GetPlayerPed(src)
    local coords = ped and ped > 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)

    return {
        { name = 'Player', value = ('%s (%s)'):format(GetPlayerName(src) or 'Unknown', src), inline = true },
        { name = 'License', value = getIdentifierByPrefix(src, 'license:'), inline = false },
        { name = 'Discord', value = getDiscordMention(src), inline = true },
        { name = 'Steam', value = getIdentifierByPrefix(src, 'steam:'), inline = true },
        { name = 'IP', value = GetPlayerEndpoint(src) or 'N/A', inline = true },
        { name = 'Coords', value = ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z), inline = false }
    }
end

local function sendWebhookLog(kind, title, description, color, extraFields)
    local cfg = getWebhookConfig()
    if not cfg.Enabled then
        return
    end

    local urls = cfg.Urls or {}
    local url = urls[kind]
    if type(url) ~= 'string' or url == '' then
        return
    end

    local fields = type(extraFields) == 'table' and extraFields or {}
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = cfg.Name or 'xrb Logs',
        avatar_url = cfg.AvatarUrl or '',
        embeds = {
            {
                title = title,
                description = description,
                color = color or cfg.Color or 3447003,
                fields = fields,
                footer = {
                    text = cfg.FooterText or 'xrb Logs'
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

local function kvpKeyForIdentifier(identifier)
    local safe = tostring(identifier or 'unknown'):gsub('[^%w_%-]', '_')
    return ('xrb_hunting:%s'):format(safe)
end

local function getLevelConfig()
    return Config.LevelSystem or {}
end

local function getTalentConfig()
    return Config.TalentSystem or {}
end

local function isLicenseAllowed(src)
    local allowed = (Config.Admin and Config.Admin.AllowedLicenses) or {}
    if #allowed == 0 then
        return false
    end

    local playerLicense = getPlayerIdentifier(src)
    for i = 1, #allowed do
        if tostring(allowed[i]) == playerLicense then
            return true
        end
    end

    return false
end

local function isAdmin(src)
    local ace = (Config.Admin and Config.Admin.AcePermission) or 'xrbhunting.admin'
    if isLicenseAllowed(src) then
        return true
    end

    return IsPlayerAceAllowed(src, ace)
end

local talentIndex = nil
local function getTalentIndex()
    if talentIndex then
        return talentIndex
    end

    talentIndex = {}
    local talents = getTalentConfig().Talents or {}
    for i = 1, #talents do
        local talent = talents[i]
        if talent and talent.id then
            talentIndex[talent.id] = talent
        end
    end

    return talentIndex
end

local function calculateLevel(xp)
    local levels = getLevelConfig().Levels or { 0 }
    local level = 1

    for i = 1, #levels do
        if xp >= levels[i] then
            level = i
        else
            break
        end
    end

    return level
end

local function loadPersistedData(identifier)
    local raw = GetResourceKvpString(kvpKeyForIdentifier(identifier))
    if not raw or raw == '' then
        return nil
    end

    local ok, decoded = pcall(function()
        return json.decode(raw)
    end)
    if not ok or type(decoded) ~= 'table' then
        return nil
    end

    return decoded
end

local function savePersistedData(identifier, data)
    SetResourceKvp(kvpKeyForIdentifier(identifier), json.encode({
        xp = math.max(math.floor(tonumber(data.xp) or 0), 0),
        level = math.max(math.floor(tonumber(data.level) or 1), 1),
        talents = type(data.talents) == 'table' and data.talents or {}
    }))
end

local function getHuntingData(src)
    local identifier = getPlayerIdentifier(src)
    if not playerHuntingData[identifier] then
        local data = {
            xp = 0,
            level = 1,
            talents = {}
        }

        local talentCfg = getTalentConfig()
        if talentCfg.Enabled and talentCfg.Persist then
            local persisted = loadPersistedData(identifier)
            if type(persisted) == 'table' then
                data.xp = math.max(math.floor(tonumber(persisted.xp) or 0), 0)
                data.talents = type(persisted.talents) == 'table' and persisted.talents or {}
            end
        end

        data.level = calculateLevel(data.xp)
        playerHuntingData[identifier] = data
    end

    return playerHuntingData[identifier], identifier
end

local function persistHuntingData(src, data, identifier)
    local cfg = getTalentConfig()
    if not (cfg.Enabled and cfg.Persist) then
        return
    end

    local ident = identifier or getPlayerIdentifier(src)
    local payload = data or select(1, getHuntingData(src))
    savePersistedData(ident, payload)
end

local function getTalentRank(data, talentId)
    if not data or type(data.talents) ~= 'table' then
        return 0
    end

    return math.max(math.floor(tonumber(data.talents[talentId]) or 0), 0)
end

local function getSpentTalentPoints(data)
    local spent = 0
    if not data or type(data.talents) ~= 'table' then
        return 0
    end

    for _, rank in pairs(data.talents) do
        spent = spent + math.max(math.floor(tonumber(rank) or 0), 0)
    end

    return spent
end

local function getEarnedTalentPoints(level)
    local perLevel = math.max(math.floor(tonumber(getTalentConfig().PointsPerLevel) or 1), 0)
    local lvl = math.max(math.floor(tonumber(level) or 1), 1)
    return math.max(lvl - 1, 0) * perLevel
end

local function getAvailableTalentPoints(data)
    local earned = getEarnedTalentPoints(data.level)
    local spent = getSpentTalentPoints(data)
    return math.max(earned - spent, 0), earned, spent
end

local sendHuntingData

local function addHuntingXp(target, xpAmount)
    local amount = math.max(math.floor(tonumber(xpAmount) or 0), 0)
    if amount <= 0 then
        return false, 'Invalid XP amount.'
    end

    local data, identifier = getHuntingData(target)
    local oldLevel = data.level
    data.xp = math.max(math.floor(tonumber(data.xp) or 0), 0) + amount
    data.level = calculateLevel(data.xp)
    persistHuntingData(target, data, identifier)
    sendHuntingData(target)

    local levels = getLevelConfig().Levels or { 0 }
    if data.level > oldLevel then
        notify(target, ('Hunting level up! You are now level %s.'):format(data.level), 'success')
        local pointsGained = getEarnedTalentPoints(data.level) - getEarnedTalentPoints(oldLevel)
        if pointsGained > 0 then
            local availablePoints = getAvailableTalentPoints(data)
            notify(target, ('Talent point(s) earned: +%s | Available: %s'):format(pointsGained, availablePoints), 'success')
        end
    else
        local nextXp = levels[data.level + 1] or -1
        if nextXp ~= -1 then
            notify(target, ('Hunting XP +%s | %s XP to next level'):format(amount, math.max(nextXp - data.xp, 0)), 'inform')
        else
            notify(target, ('Hunting XP +%s | Max level reached'):format(amount), 'success')
        end
    end

    return true, amount
end

local function resetTalentsForPlayer(target)
    local data, identifier = getHuntingData(target)
    local _, _, spent = getAvailableTalentPoints(data)
    data.talents = {}
    persistHuntingData(target, data, identifier)
    sendHuntingData(target)
    notify(target, 'Your hunting talents have been reset.', 'success')
    return true, spent
end

sendHuntingData = function(src)
    local data = select(1, getHuntingData(src))
    local levels = getLevelConfig().Levels or { 0 }
    local nextXp = levels[data.level + 1] or -1
    local available, earned, spent = getAvailableTalentPoints(data)

    TriggerClientEvent('xrb-hunting:updateProfile', src, {
        level = data.level,
        xp = data.xp,
        nextXp = nextXp,
        talents = data.talents or {},
        isAdmin = isAdmin(src),
        talentPoints = {
            available = available,
            earned = earned,
            spent = spent
        }
    })
end

local function rollChance(chance)
    local c = tonumber(chance) or 0
    if c <= 0 then
        return false
    end
    if c >= 1 then
        return true
    end
    return (math.random(0, 1000000) / 1000000) < c
end

local function getTalentEffectValue(data, effectName)
    local total = 0
    local talents = getTalentConfig().Talents or {}

    for i = 1, #talents do
        local talent = talents[i]
        local effects = talent.effects or {}
        local rank = getTalentRank(data, talent.id)
        if rank > 0 and effects[effectName] then
            total = total + ((tonumber(effects[effectName]) or 0) * rank)
        end
    end

    return total
end

local function getItemLabel(itemName)
    local items = ox_inventory:Items()
    local item = items and items[itemName]
    return (item and item.label) or itemName
end

local function getOnlinePlayerData()
    local players = GetPlayers()
    local out = {}

    for i = 1, #players do
        local playerSrc = tonumber(players[i])
        local data = select(1, getHuntingData(playerSrc))
        local available = getAvailableTalentPoints(data)
        out[#out + 1] = {
            id = playerSrc,
            name = GetPlayerName(playerSrc) or ('Player %s'):format(playerSrc),
            level = data.level,
            xp = data.xp,
            availableTalentPoints = available
        }
    end

    table.sort(out, function(a, b)
        return a.id < b.id
    end)

    return out
end

local function getMaxLevel()
    local levels = getLevelConfig().Levels or { 0 }
    return #levels
end

local function getMaxPossibleMeat(animalData)
    local maxMeat = math.max(math.floor(tonumber(animalData.meatAmount.max) or 0), 0)
    local talents = getTalentConfig().Talents or {}
    local extraPotential = 0

    for i = 1, #talents do
        local talent = talents[i]
        local effects = talent.effects or {}
        if effects.extraMeatChancePerRank and effects.extraMeatAmount then
            extraPotential = extraPotential + (math.max(math.floor(tonumber(talent.maxRank) or 0), 0) * math.max(math.floor(tonumber(effects.extraMeatAmount) or 0), 0))
        end
    end

    return maxMeat + extraPotential
end

local function getMaxPossibleSkins()
    local talents = getTalentConfig().Talents or {}
    local extraPotential = 0

    for i = 1, #talents do
        local talent = talents[i]
        local effects = talent.effects or {}
        if effects.extraSkinChancePerRank and effects.extraSkinAmount then
            extraPotential = extraPotential + (math.max(math.floor(tonumber(talent.maxRank) or 0), 0) * math.max(math.floor(tonumber(effects.extraSkinAmount) or 0), 0))
        end
    end

    return 1 + extraPotential
end

lib.callback.register('xrb-hunting:checkInventorySpace', function(source, animalModelHash)
    local animalData = Config.GetAnimalDataByHash(tonumber(animalModelHash) or 0)
    if not animalData then
        return false
    end

    local canCarryMeat = ox_inventory:CanCarryItem(source, animalData.meat, getMaxPossibleMeat(animalData))
    local canCarrySkin = ox_inventory:CanCarryItem(source, animalData.skin, getMaxPossibleSkins())
    return canCarryMeat and canCarrySkin
end)

RegisterServerEvent('xrb-hunting:requestProfile')
AddEventHandler('xrb-hunting:requestProfile', function()
    sendHuntingData(source)
end)

RegisterServerEvent('xrb-hunting:admin:requestData')
AddEventHandler('xrb-hunting:admin:requestData', function()
    local src = source
    if not isAdmin(src) then
        notify(src, 'You do not have permission for hunting admin.', 'error')
        return
    end

    TriggerClientEvent('xrb-hunting:admin:updateData', src, getOnlinePlayerData())
end)

RegisterServerEvent('xrb-hunting:admin:applyAction')
AddEventHandler('xrb-hunting:admin:applyAction', function(targetId, action, value)
    local src = source
    if not isAdmin(src) then
        notify(src, 'You do not have permission for this action.', 'error')
        sendWebhookLog('suspicious', 'Unauthorized Hunting Admin Action', 'A player tried to use hunting admin actions without permission.', getWebhookConfig().DangerColor, getPlayerLogFields(src))
        return
    end

    local target = tonumber(targetId)
    if not target or not GetPlayerName(target) then
        notify(src, 'Invalid target player.', 'error')
        sendWebhookLog('suspicious', 'Invalid Hunting Admin Target', 'A hunting admin action was attempted with an invalid target.', getWebhookConfig().WarningColor, getPlayerLogFields(src))
        return
    end

    local data, identifier = getHuntingData(target)
    local amount = tonumber(value) or 0

    if action == 'add_xp' then
        if amount <= 0 then
            notify(src, 'XP amount must be greater than 0.', 'error')
            return
        end
        data.xp = data.xp + math.floor(amount)
    elseif action == 'set_level' then
        local targetLevel = math.max(math.floor(amount), 1)
        local levels = getLevelConfig().Levels or { 0 }
        data.xp = levels[targetLevel] or levels[#levels] or 0
    elseif action == 'set_xp' then
        data.xp = math.max(math.floor(amount), 0)
    elseif action == 'reset_talents' then
        data.talents = {}
    elseif action == 'give_all_talents' then
        local talents = getTalentConfig().Talents or {}
        data.talents = {}
        for i = 1, #talents do
            local talent = talents[i]
            if talent and talent.id then
                data.talents[talent.id] = math.max(math.floor(tonumber(talent.maxRank) or 1), 1)
            end
        end
        data.level = math.max(data.level, getMaxLevel())
        local levels = getLevelConfig().Levels or { 0 }
        data.xp = levels[data.level] or data.xp
    elseif action == 'reset_all' then
        data.xp = 0
        data.talents = {}
    else
        notify(src, 'Unknown admin action.', 'error')
        return
    end

    data.level = calculateLevel(data.xp)
    persistHuntingData(target, data, identifier)
    sendHuntingData(target)
    TriggerClientEvent('xrb-hunting:admin:updateData', src, getOnlinePlayerData())
    notify(src, ('Updated %s successfully.'):format(GetPlayerName(target) or ('Player %s'):format(target)), 'success')
    notify(target, 'Your hunting data was updated by admin.', 'inform')
    local fields = getPlayerLogFields(src)
    fields[#fields + 1] = { name = 'Target', value = ('%s (%s)'):format(GetPlayerName(target) or 'Unknown', target), inline = true }
    fields[#fields + 1] = { name = 'Action', value = tostring(action), inline = true }
    fields[#fields + 1] = { name = 'Value', value = tostring(value or '0'), inline = true }
    fields[#fields + 1] = { name = 'Target XP / Level', value = ('XP %s | Level %s'):format(data.xp, data.level), inline = false }
    sendWebhookLog('admin', 'Hunting Admin Action', 'An admin changed hunting progression data.', getWebhookConfig().WarningColor, fields)
end)

RegisterServerEvent('xrb-hunting:talents:buy')
AddEventHandler('xrb-hunting:talents:buy', function(talentId)
    local src = source
    local cfg = getTalentConfig()
    if not cfg.Enabled then
        notify(src, 'Talent system is disabled.', 'error')
        return
    end

    local id = tostring(talentId or '')
    local def = getTalentIndex()[id]
    if not def then
        notify(src, 'Unknown talent.', 'error')
        return
    end

    local data, identifier = getHuntingData(src)
    local rank = getTalentRank(data, id)
    local maxRank = math.max(math.floor(tonumber(def.maxRank) or 1), 1)

    if rank >= maxRank then
        notify(src, 'Talent is already maxed.', 'error')
        return
    end

    local available = getAvailableTalentPoints(data)
    if available <= 0 then
        notify(src, 'No talent points available.', 'error')
        return
    end

    local reqs = def.requires or {}
    for i = 1, #reqs do
        local req = reqs[i]
        local reqId = tostring(req.id or '')
        local reqRank = math.max(math.floor(tonumber(req.rank) or 1), 1)
        if getTalentRank(data, reqId) < reqRank then
            notify(src, 'Talent is locked.', 'error')
            return
        end
    end

    data.talents[id] = rank + 1
    persistHuntingData(src, data, identifier)
    sendHuntingData(src)
    notify(src, ('Talent upgraded: %s (%s/%s)'):format(def.name or id, rank + 1, maxRank), 'success')
end)

RegisterServerEvent('xrb-hunting:skinAnimal')
AddEventHandler('xrb-hunting:skinAnimal', function(animalModelHash)
    local src = source
    local animalData = Config.GetAnimalDataByHash(tonumber(animalModelHash) or 0)
    if not animalData then
        notify(src, 'Invalid animal data.', 'error')
        sendWebhookLog('suspicious', 'Invalid Hunting Animal Request', 'A player attempted to skin with invalid animal data.', getWebhookConfig().DangerColor, getPlayerLogFields(src))
        return
    end

    local data, identifier = getHuntingData(src)
    local meatAmount = math.random(animalData.meatAmount.min, animalData.meatAmount.max)
    local extraMeat = 0
    local extraSkin = 0
    local skinChance = math.min(math.max(tonumber(animalData.skinChance) or 0, 0), 1)

    local talents = getTalentConfig().Talents or {}
    for i = 1, #talents do
        local talent = talents[i]
        local effects = talent.effects or {}
        local rank = getTalentRank(data, talent.id)
        if rank > 0 then
            if effects.extraMeatChancePerRank and effects.extraMeatAmount then
                local chance = (tonumber(effects.extraMeatChancePerRank) or 0) * rank
                local amount = math.max(math.floor(tonumber(effects.extraMeatAmount) or 0), 0)
                if amount > 0 and rollChance(chance) then
                    extraMeat = extraMeat + amount
                end
            end

            if effects.skinChanceBonusPerRank then
                skinChance = skinChance + ((tonumber(effects.skinChanceBonusPerRank) or 0) * rank)
            end

            if effects.extraSkinChancePerRank and effects.extraSkinAmount then
                local chance = (tonumber(effects.extraSkinChancePerRank) or 0) * rank
                local amount = math.max(math.floor(tonumber(effects.extraSkinAmount) or 0), 0)
                if amount > 0 and rollChance(chance) then
                    extraSkin = extraSkin + amount
                end
            end
        end
    end

    skinChance = math.min(skinChance, 1.0)
    meatAmount = meatAmount + extraMeat

    local skinCount = 0
    if rollChance(skinChance) then
        skinCount = 1 + extraSkin
    end

    if not ox_inventory:CanCarryItem(src, animalData.meat, meatAmount) then
        notify(src, 'You do not have enough space for the meat.', 'error')
        return
    end

    if skinCount > 0 and not ox_inventory:CanCarryItem(src, animalData.skin, skinCount) then
        notify(src, 'You do not have enough space for the hide.', 'error')
        return
    end

    local successMeat = ox_inventory:AddItem(src, animalData.meat, meatAmount)
    local successSkin = true
    if skinCount > 0 then
        successSkin = ox_inventory:AddItem(src, animalData.skin, skinCount)
    end

    if not successMeat or not successSkin then
        if successMeat then
            ox_inventory:RemoveItem(src, animalData.meat, meatAmount)
        end
        if successSkin and skinCount > 0 then
            ox_inventory:RemoveItem(src, animalData.skin, skinCount)
        end
        notify(src, 'Failed to add items to inventory.', 'error')
        return
    end

    local xpGain = math.max(math.floor(tonumber(animalData.xp) or 10), 0)
    local xpBonus = getTalentEffectValue(data, 'xpBonusPerRank')
    if xpBonus > 0 then
        xpGain = math.max(math.floor((xpGain * (1 + xpBonus)) + 0.5), 0)
    end

    local oldLevel = data.level
    data.xp = data.xp + xpGain
    data.level = calculateLevel(data.xp)
    persistHuntingData(src, data, identifier)
    sendHuntingData(src)

    local message = ('Skinned %sx %s'):format(meatAmount, getItemLabel(animalData.meat))
    if skinCount > 0 then
        message = message .. (' and %sx %s'):format(skinCount, getItemLabel(animalData.skin))
    end
    notify(src, message, 'success')

    local levels = getLevelConfig().Levels or { 0 }
    if data.level > oldLevel then
        notify(src, ('Hunting level up! You are now level %s.'):format(data.level), 'success')
        local pointsGained = getEarnedTalentPoints(data.level) - getEarnedTalentPoints(oldLevel)
        if pointsGained > 0 then
            local availablePoints = getAvailableTalentPoints(data)
            notify(src, ('Talent point(s) earned: +%s | Available: %s'):format(pointsGained, availablePoints), 'success')
        end
    else
        local nextXp = levels[data.level + 1] or -1
        if nextXp ~= -1 then
            notify(src, ('Hunting XP +%s | %s XP to next level'):format(xpGain, math.max(nextXp - data.xp, 0)), 'inform')
        else
            notify(src, ('Hunting XP +%s | Max level reached'):format(xpGain), 'success')
        end
    end

    local rewardItems = {
        [getItemLabel(animalData.meat)] = meatAmount
    }
    if skinCount > 0 then
        rewardItems[getItemLabel(animalData.skin)] = skinCount
    end

    local rewardFields = getPlayerLogFields(src)
    rewardFields[#rewardFields + 1] = { name = 'Animal', value = tostring(animalData.name or animalModelHash), inline = true }
    rewardFields[#rewardFields + 1] = { name = 'XP Gained', value = tostring(xpGain), inline = true }
    rewardFields[#rewardFields + 1] = { name = 'Level', value = ('%s -> %s'):format(oldLevel, data.level), inline = true }
    rewardFields[#rewardFields + 1] = { name = 'Items Received', value = formatItemMap(rewardItems), inline = false }
    sendWebhookLog('rewards', 'Hunting Reward Granted', 'A player skinned an animal and received hunting rewards.', getWebhookConfig().SuccessColor, rewardFields)
end)

RegisterServerEvent('xrb-hunting:sellProducts')
AddEventHandler('xrb-hunting:sellProducts', function()
    local src = source
    local total = 0
    local soldAnything = false
    local data = select(1, getHuntingData(src))
    local sellBonus = getTalentEffectValue(data, 'sellPriceBonusPerRank')
    local soldItems = {}

    for itemName, price in pairs(Config.Prices) do
        local count = ox_inventory:GetItemCount(src, itemName, nil, false)
        if count and count > 0 then
            local removed = ox_inventory:RemoveItem(src, itemName, count)
            if not removed then
                notify(src, ('Failed to remove %s from inventory.'):format(getItemLabel(itemName)), 'error')
                return
            end

            soldAnything = true
            local itemPrice = math.floor((count * price) * (1 + sellBonus) + 0.5)
            total = total + itemPrice
            soldItems[getItemLabel(itemName)] = count
        end
    end

    if not soldAnything or total <= 0 then
        notify(src, 'You have no hunting goods to sell.', 'inform')
        return
    end

    local moneyAdded = ox_inventory:AddItem(src, 'cash', total)
    if moneyAdded then
        notify(src, ('Sold hunting goods for $%s'):format(total), 'success')
        local saleFields = getPlayerLogFields(src)
        saleFields[#saleFields + 1] = { name = 'Items Sold', value = formatItemMap(soldItems), inline = false }
        saleFields[#saleFields + 1] = { name = 'Total Cash', value = ('$%s'):format(total), inline = true }
        saleFields[#saleFields + 1] = { name = 'Sell Bonus', value = ('%.2f%%'):format((sellBonus or 0) * 100), inline = true }
        sendWebhookLog('sales', 'Hunting Items Sold', 'A player sold hunting items for cash.', getWebhookConfig().Color, saleFields)
    else
        notify(src, 'Sold items but cash could not be added. Contact an admin.', 'error')
    end
end)

CreateThread(function()
    Wait(0)
    local cfg = getTalentConfig()
    local resetCfg = cfg.ResetItem or {}
    if not resetCfg.Enabled then return end
    if resetCfg.UseServerUsableItem ~= true then return end

    local itemName = tostring(resetCfg.ItemName or '')
    if itemName == '' then return end

    local ok = pcall(function()
        return exports.ox_inventory and exports.ox_inventory.RegisterUsableItem
    end)
    if not ok or not (exports.ox_inventory and exports.ox_inventory.RegisterUsableItem) then
        print(('[xrb-Hunting] WARNING: ResetItem is enabled but ox_inventory:RegisterUsableItem is not available. (%s)'):format(itemName))
        return
    end

    exports.ox_inventory:RegisterUsableItem(itemName, function(data)
        local src = (type(data) == 'table' and data.source) or source
        if not src or not GetPlayerName(src) then return end

        local success = resetTalentsForPlayer(src)
        if success and resetCfg.RemoveOnUse ~= false then
            exports.ox_inventory:RemoveItem(src, itemName, 1)
        end
    end)
end)

RegisterServerEvent('xrb-hunting-talentreset:server:useItem')
AddEventHandler('xrb-hunting-talentreset:server:useItem', function()
    local src = source
    local cfg = getTalentConfig()
    local resetCfg = cfg.ResetItem or {}

    if not resetCfg.Enabled then
        TriggerClientEvent('xrb-hunting-talentreset:client:failed', src, 'Talent reset is disabled.')
        return
    end

    local itemName = tostring(resetCfg.ItemName or 'hunting_talent_reset')
    local removeOnUse = (resetCfg.RemoveOnUse ~= false)
    local data = select(1, getHuntingData(src))
    local spent = getSpentTalentPoints(data)
    if spent <= 0 then
        TriggerClientEvent('xrb-hunting-talentreset:client:failed', src, 'You have no talents to reset.')
        return
    end

    if removeOnUse then
        local count = exports.ox_inventory:Search(src, 'count', itemName) or 0
        if count < 1 then
            TriggerClientEvent('xrb-hunting-talentreset:client:failed', src, 'You do not have a talent reset item.')
            return
        end

        local removed = exports.ox_inventory:RemoveItem(src, itemName, 1)
        if not removed then
            TriggerClientEvent('xrb-hunting-talentreset:client:failed', src, 'Failed to consume talent reset item.')
            return
        end
    end

    local success, refunded = resetTalentsForPlayer(src)
    if success then
        local resetFields = getPlayerLogFields(src)
        resetFields[#resetFields + 1] = { name = 'Item Used', value = itemName, inline = true }
        resetFields[#resetFields + 1] = { name = 'Refunded Points', value = tostring(refunded or spent), inline = true }
        sendWebhookLog('talentReset', 'Hunting Talent Reset Used', 'A player reset their hunting talents with an item.', getWebhookConfig().WarningColor, resetFields)
    end
    TriggerClientEvent('xrb-hunting-talentreset:client:used', src)
end)

RegisterCommand((getTalentConfig().ResetItem and getTalentConfig().ResetItem.AdminGiveCommand) or 'givehuntingreset', function(src, args)
    if src == 0 then return end

    local cfg = getTalentConfig()
    local resetCfg = cfg.ResetItem or {}
    if resetCfg.Enabled == false then
        notify(src, 'Talent reset is disabled.', 'error')
        return
    end

    local ace = (resetCfg.AdminAcePermission or 'xrbhunting.admin')
    if not IsPlayerAceAllowed(src, ace) then
        notify(src, 'No permission.', 'error')
        return
    end

    local amount = math.max(math.floor(tonumber(args and args[1]) or 1), 1)
    local itemName = tostring(resetCfg.ItemName or 'hunting_talent_reset')
    if exports.ox_inventory:AddItem(src, itemName, amount) then
        notify(src, ('Received %sx %s'):format(amount, itemName), 'success')
    else
        notify(src, 'Could not add item (inventory full?).', 'error')
    end
end, false)

RegisterServerEvent('xrb-hunting-xpboost:server:useItem')
AddEventHandler('xrb-hunting-xpboost:server:useItem', function()
    local src = source
    local cfg = Config.XPBoost or {}
    if cfg.Enabled == false then
        TriggerClientEvent('xrb-hunting-xpboost:client:failed', src, 'Hunting XP boost is disabled.')
        return
    end

    local itemName = tostring(cfg.ItemName or 'hunting_xpboost')
    local xpAmount = math.max(math.floor(tonumber(cfg.XpAmount) or 10000), 1)
    local count = exports.ox_inventory:Search(src, 'count', itemName) or 0
    if count < 1 then
        TriggerClientEvent('xrb-hunting-xpboost:client:failed', src, 'You do not have a hunting XP boost item.')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, itemName, 1)
    if not removed then
        TriggerClientEvent('xrb-hunting-xpboost:client:failed', src, 'Failed to consume hunting XP boost item.')
        return
    end

    local success = addHuntingXp(src, xpAmount)
    if not success then
        exports.ox_inventory:AddItem(src, itemName, 1)
        TriggerClientEvent('xrb-hunting-xpboost:client:failed', src, 'Failed to apply hunting XP boost.')
        return
    end

    local xpFields = getPlayerLogFields(src)
    xpFields[#xpFields + 1] = { name = 'Item Used', value = itemName, inline = true }
    xpFields[#xpFields + 1] = { name = 'XP Added', value = tostring(xpAmount), inline = true }
    local data = select(1, getHuntingData(src))
    xpFields[#xpFields + 1] = { name = 'New XP / Level', value = ('XP %s | Level %s'):format(data.xp, data.level), inline = false }
    sendWebhookLog('xpBoost', 'Hunting XP Boost Used', 'A player used a hunting XP boost item.', getWebhookConfig().SuccessColor, xpFields)

    TriggerClientEvent('xrb-hunting-xpboost:client:used', src, xpAmount)
end)

RegisterCommand((Config.XPBoost and Config.XPBoost.AdminGiveCommand) or 'givehuntingxp', function(src, args)
    if src == 0 then return end

    local cfg = Config.XPBoost or {}
    if cfg.Enabled == false then
        notify(src, 'Hunting XP boost is disabled.', 'error')
        return
    end

    local ace = (cfg.AdminAcePermission or 'xrbhunting.admin')
    if not IsPlayerAceAllowed(src, ace) then
        notify(src, 'No permission.', 'error')
        return
    end

    local amount = math.max(math.floor(tonumber(args and args[1]) or 1), 1)
    local itemName = tostring(cfg.ItemName or 'hunting_xpboost')
    if exports.ox_inventory:AddItem(src, itemName, amount) then
        notify(src, ('Received %sx %s'):format(amount, itemName), 'success')
    else
        notify(src, 'Could not add item (inventory full?).', 'error')
    end
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    local data, identifier = getHuntingData(src)
    persistHuntingData(src, data, identifier)
    if identifier then
        playerHuntingData[identifier] = nil
    end
end)
