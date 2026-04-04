local Framework = nil
local QBCore = nil
local ESX = nil

local ox_inventory = exports.ox_inventory
local ox_target = exports.ox_target

local huntingZoneBlips = {}
local spawnedAnimals = {}
local sellPed = nil

local huntingLevel = 1
local huntingXp = 0
local nextLevelXp = -1
local huntingTalents = {}
local talentPoints = { available = 0, earned = 0, spent = 0 }
local huntingUiOpen = false
local huntingIsAdmin = false
local adminPlayers = {}

local function detectFramework()
    Framework = XRB.DetectFramework(Config.Framework)

    local core = XRB.GetCoreObject(Config.Framework)
    if Framework == 'qb' then
        QBCore = core
    elseif Framework == 'esx' then
        ESX = core
    elseif Framework == 'standalone' then
        Framework = 'none'
    end
end

detectFramework()

local function notify(message, msgType)
    XRB.Notify(nil, {
        description = message,
        type = msgType or 'inform'
    })
end

local function confirmItemUse(header, content, confirmLabel)
    local result = lib.alertDialog({
        header = header or 'Confirm',
        content = content or 'Are you sure?',
        centered = true,
        cancel = true,
        labels = {
            confirm = confirmLabel or 'Confirm',
            cancel = 'Cancel'
        }
    })

    return result == 'confirm'
end

local function requestHuntingProfile()
    TriggerServerEvent('xrb-hunting:requestProfile')
end

local function applyAdminAction(targetId, action, value)
    TriggerServerEvent('xrb-hunting:admin:applyAction', targetId, action, value)
end

local function getTalentValue(effectName, cap)
    if not Config.TalentSystem or not Config.TalentSystem.Enabled then
        return 0
    end

    local total = 0
    local talents = Config.TalentSystem.Talents or {}
    for i = 1, #talents do
        local talent = talents[i]
        local effects = talent.effects or {}
        local rank = tonumber(huntingTalents[talent.id] or 0) or 0
        if rank > 0 and effects[effectName] then
            total = total + ((tonumber(effects[effectName]) or 0) * rank)
        end
    end

    if cap then
        total = math.min(total, cap)
    end

    return total
end

local function getSkinningDuration()
    local levelCfg = Config.LevelSystem or {}
    local baseDuration = tonumber(levelCfg.BaseSkinningDuration) or 5000
    local minDuration = tonumber(levelCfg.MinSkinningDuration) or 2500
    local maxBonus = tonumber((Config.TalentSystem or {}).MaxSkinningSpeedBonus) or 0.35
    local speedBonus = getTalentValue('skinningSpeedBonusPerRank', maxBonus)

    local duration = math.floor(baseDuration * (1.0 - speedBonus))
    if duration < minDuration then
        duration = minDuration
    end

    return duration
end

local function getMaxAnimalsForPlayer()
    local base = tonumber(Config.MaxAnimalsPerZone) or 8
    local bonus = math.floor(getTalentValue('spawnCapBonusPerRank', tonumber((Config.TalentSystem or {}).MaxSpawnBonus) or 3))
    return base + bonus
end

local function getPlayerZone()
    if not Config.UseSpecificHuntingZones then
        return nil, nil
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local zones = Config.HuntingZones or {}
    for i = 1, #zones do
        local zone = zones[i]
        if #(playerCoords - zone.coords) <= zone.radius then
            return zone, i
        end
    end

    return nil, nil
end

local function removeTrackedAnimal(entity)
    for i = #spawnedAnimals, 1, -1 do
        if spawnedAnimals[i].entity == entity then
            table.remove(spawnedAnimals, i)
            return
        end
    end
end

local function createHuntingZoneBlips()
    if not Config.UseSpecificHuntingZones then
        return
    end

    for i = 1, #Config.HuntingZones do
        local zone = Config.HuntingZones[i]
        local blipCfg = zone.blip or {}
        local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(blip, blipCfg.sprite or 496)
        SetBlipColour(blip, blipCfg.color or 3)
        SetBlipScale(blip, blipCfg.scale or 0.8)
        SetBlipAsShortRange(blip, blipCfg.shortRange ~= false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(blipCfg.label or zone.name or 'Hunting Zone')
        EndTextCommandSetBlipName(blip)
        huntingZoneBlips[#huntingZoneBlips + 1] = blip
    end
end

local function removeHuntingZoneBlips()
    for i = 1, #huntingZoneBlips do
        RemoveBlip(huntingZoneBlips[i])
    end
    huntingZoneBlips = {}
end

local function getZoneAnimalCount(zoneIndex)
    local count = 0
    for i = #spawnedAnimals, 1, -1 do
        local entry = spawnedAnimals[i]
        if not DoesEntityExist(entry.entity) then
            table.remove(spawnedAnimals, i)
        elseif entry.zoneIndex == zoneIndex and not IsEntityDead(entry.entity) then
            count = count + 1
        end
    end
    return count
end

local function cleanupAnimals()
    local playerCoords = GetEntityCoords(PlayerPedId())

    for i = #spawnedAnimals, 1, -1 do
        local entry = spawnedAnimals[i]
        local entity = entry.entity

        if not DoesEntityExist(entity) then
            table.remove(spawnedAnimals, i)
        else
            local entityCoords = GetEntityCoords(entity)
            local tooFar = #(playerCoords - entityCoords) > Config.DespawnRadiusFromPlayer
            if tooFar and (not IsEntityDead(entity) or #(playerCoords - entityCoords) > (Config.DespawnRadiusFromPlayer + 25.0)) then
                DeleteEntity(entity)
                table.remove(spawnedAnimals, i)
            end
        end
    end
end

local function chooseAnimalHash(zone)
    local spawnChances = zone.spawnChances or {}
    local totalChance = 0

    for i = 1, #spawnChances do
        totalChance = totalChance + (tonumber(spawnChances[i].chance) or 0)
    end

    if totalChance <= 0 then
        return nil
    end

    local roll = math.random(1, totalChance)
    local accumulated = 0

    for i = 1, #spawnChances do
        accumulated = accumulated + (tonumber(spawnChances[i].chance) or 0)
        if roll <= accumulated then
            return spawnChances[i].animal
        end
    end

    return nil
end

local function findSpawnCoords(zone)
    local playerCoords = GetEntityCoords(PlayerPedId())

    for _ = 1, 12 do
        local offsetX = math.random() * (Config.SpawnRadiusFromPlayer * 2.0) - Config.SpawnRadiusFromPlayer
        local offsetY = math.random() * (Config.SpawnRadiusFromPlayer * 2.0) - Config.SpawnRadiusFromPlayer
        local attempt = vector3(playerCoords.x + offsetX, playerCoords.y + offsetY, playerCoords.z + 50.0)

        if #(vector2(attempt.x, attempt.y) - vector2(zone.coords.x, zone.coords.y)) <= zone.radius then
            local found, groundZ = GetGroundZFor_3dCoord(attempt.x, attempt.y, attempt.z, false)
            if found then
                return vector3(attempt.x, attempt.y, groundZ)
            end
        end
    end

    return nil
end

local function spawnRandomAnimalInZone(zone, zoneIndex)
    local chosenAnimalHash = chooseAnimalHash(zone)
    if not chosenAnimalHash then
        return nil
    end

    local coords = findSpawnCoords(zone)
    if not coords then
        return nil
    end

    RequestModel(chosenAnimalHash)
    while not HasModelLoaded(chosenAnimalHash) do
        Wait(10)
    end

    local animal = CreatePed(28, chosenAnimalHash, coords.x, coords.y, coords.z, math.random() * 360.0, true, true)
    if animal == 0 or not DoesEntityExist(animal) then
        SetModelAsNoLongerNeeded(chosenAnimalHash)
        return nil
    end

    SetEntityAsMissionEntity(animal, true, true)
    SetPedAsNoLongerNeeded(animal)
    SetBlockingOfNonTemporaryEvents(animal, false)
    SetPedFleeAttributes(animal, 0, true)
    SetPedRelationshipGroupHash(animal, GetHashKey('WILD_ANIMAL'))
    TaskWanderStandard(animal, 10.0, 10)

    spawnedAnimals[#spawnedAnimals + 1] = {
        entity = animal,
        zoneIndex = zoneIndex
    }

    SetModelAsNoLongerNeeded(chosenAnimalHash)
    return animal
end

local function sanitizeTalentDefs()
    local defs = {}
    local talents = (Config.TalentSystem and Config.TalentSystem.Talents) or {}

    for i = 1, #talents do
        local talent = talents[i]
        defs[#defs + 1] = {
            id = talent.id,
            name = talent.name,
            description = talent.description,
            maxRank = talent.maxRank,
            icon = talent.icon,
            requires = talent.requires or {},
            ui = talent.ui or { col = i, row = 1 }
        }
    end

    return defs
end

local function pushAdminDataToUi()
    if not huntingUiOpen then
        return
    end

    SendNUIMessage({
        action = 'adminData',
        data = {
            players = adminPlayers
        }
    })
end

local function updateHuntingUi()
    if not huntingUiOpen then
        return
    end

    SendNUIMessage({
        action = 'update',
        data = {
            level = huntingLevel,
            xp = huntingXp,
            nextXp = nextLevelXp,
            talentPoints = talentPoints,
            talents = huntingTalents,
            isAdmin = huntingIsAdmin,
            adminPlayers = adminPlayers
        }
    })
end

local function openHuntingUi()
    if not (Config.TalentSystem and Config.TalentSystem.Enabled) then
        notify('Talent system is disabled.', 'warning')
        return
    end

    huntingUiOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'open',
        data = {
            level = huntingLevel,
            xp = huntingXp,
            nextXp = nextLevelXp,
            talentPoints = talentPoints,
            talents = huntingTalents,
            defs = sanitizeTalentDefs(),
            isAdmin = huntingIsAdmin,
            adminPlayers = adminPlayers
        }
    })

    if huntingIsAdmin then
        TriggerServerEvent('xrb-hunting:admin:requestData')
    end
end

local function skinAnimal(entity)
    local playerPed = PlayerPedId()
    if not DoesEntityExist(entity) then
        notify('The animal does not exist.', 'error')
        return
    end

    if not IsEntityDead(entity) then
        notify('The animal must be dead first.', 'error')
        return
    end

    if IsPedInAnyVehicle(playerPed, false) then
        notify('Leave the vehicle first.', 'error')
        return
    end

    if Config.UseSpecificHuntingZones and not getPlayerZone() then
        notify('You can only skin animals in hunting zones.', 'error')
        return
    end

    local animalData = Config.GetAnimalDataByHash(GetEntityModel(entity))
    if not animalData then
        notify('This animal cannot be skinned.', 'error')
        return
    end

    if (ox_inventory:Search('count', 'skining_knife') or 0) < 1 then
        notify('You need a skinning knife.', 'error')
        return
    end

    lib.callback('xrb-hunting:checkInventorySpace', false, function(canCarry)
        if not canCarry then
            notify('You do not have enough inventory space.', 'error')
            return
        end

        local success = lib.progressBar({
            duration = getSkinningDuration(),
            label = ('Skinning %s'):format(animalData.name),
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }
        })

        if not success then
            notify('Skinning cancelled.', 'error')
            return
        end

        TriggerServerEvent('xrb-hunting:skinAnimal', animalData.modelHash)
        removeTrackedAnimal(entity)
        DeleteEntity(entity)
    end, animalData.modelHash)
end

local function adminSpawnZoneAnimals()
    local zone, zoneIndex = getPlayerZone()
    if not zone or not zoneIndex then
        notify('You are not inside a hunting zone.', 'error')
        return false
    end

    local currentAnimals = getZoneAnimalCount(zoneIndex)
    local maxAnimals = getMaxAnimalsForPlayer()
    local spawned = 0

    if currentAnimals >= maxAnimals then
        notify('This zone is already full of animals.', 'inform')
        return true
    end

    for _ = 1, (maxAnimals - currentAnimals) do
        if not spawnRandomAnimalInZone(zone, zoneIndex) then
            break
        end
        spawned = spawned + 1
        Wait(100)
    end

    notify(('Spawned %s animals in the current zone.'):format(spawned), 'success')
    return true
end

local function adminClearZoneAnimals()
    local zone, zoneIndex = getPlayerZone()
    if not zone or not zoneIndex then
        notify('You are not inside a hunting zone.', 'error')
        return false
    end

    local removed = 0
    for i = #spawnedAnimals, 1, -1 do
        local entry = spawnedAnimals[i]
        if entry.zoneIndex == zoneIndex then
            if DoesEntityExist(entry.entity) then
                DeleteEntity(entry.entity)
            end
            table.remove(spawnedAnimals, i)
            removed = removed + 1
        end
    end

    notify(('Cleared %s animals from the current zone.'):format(removed), 'success')
    return true
end

local function adminResetZoneAnimals()
    if not adminClearZoneAnimals() then
        return false
    end

    Wait(150)
    return adminSpawnZoneAnimals()
end

RegisterNetEvent('xrb-hunting:updateProfile', function(data)
    if not data then
        return
    end

    huntingLevel = tonumber(data.level) or 1
    huntingXp = tonumber(data.xp) or 0
    nextLevelXp = tonumber(data.nextXp) or -1
    huntingTalents = data.talents or {}
    talentPoints = data.talentPoints or talentPoints
    huntingIsAdmin = data.isAdmin == true
    updateHuntingUi()
end)

RegisterNetEvent('xrb-hunting:admin:updateData', function(players)
    adminPlayers = players or {}
    pushAdminDataToUi()
end)

RegisterNetEvent('xrb-hunting-xpboost:client:useItem', function()
    if not confirmItemUse('Use Hunting XP Boost', 'Do you want to use this item and gain hunting XP?', 'Use Item') then
        return
    end

    TriggerServerEvent('xrb-hunting-xpboost:server:useItem')
end)

RegisterNetEvent('xrb-hunting-xpboost:client:used', function(xpAmount)
    notify(('Hunting XP boost used: +%s XP'):format(math.max(math.floor(tonumber(xpAmount) or 0), 0)), 'success')
end)

RegisterNetEvent('xrb-hunting-xpboost:client:failed', function(message)
    notify(message or 'Failed to use hunting XP boost.', 'error')
end)

RegisterNetEvent('xrb-hunting-talentreset:client:useItem', function()
    if not confirmItemUse('Reset Hunting Talents', 'Do you want to reset all your hunting talents?', 'Reset Talents') then
        return
    end

    TriggerServerEvent('xrb-hunting-talentreset:server:useItem')
end)

RegisterNetEvent('xrb-hunting-talentreset:client:used', function()
    notify('Hunting talents have been reset.', 'success')
end)

RegisterNetEvent('xrb-hunting-talentreset:client:failed', function(message)
    notify(message or 'Failed to use hunting talent reset.', 'error')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    requestHuntingProfile()
end)

RegisterNetEvent('esx:playerLoaded', function()
    requestHuntingProfile()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Wait(1500)
    requestHuntingProfile()
end)

CreateThread(function()
    Wait(3000)
    requestHuntingProfile()
end)

CreateThread(function()
    Wait(1000)
    createHuntingZoneBlips()

    for _, data in pairs(Config.Animals) do
        ox_target:addModel(data.modelHash, {
            {
                label = 'Skin ' .. (data.name or 'Animal'),
                icon = 'fa-solid fa-bone',
                distance = 2.0,
                canInteract = function(entity)
                    if Config.UseSpecificHuntingZones and not getPlayerZone() then
                        return false
                    end
                    return DoesEntityExist(entity) and IsEntityDead(entity)
                end,
                onSelect = function(targetData)
                    skinAnimal(targetData.entity)
                end
            }
        })
    end
end)

CreateThread(function()
    local pedInfo = Config.SellPed
    local model = joaat(pedInfo.model)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    sellPed = CreatePed(4, model, pedInfo.coords.x, pedInfo.coords.y, pedInfo.coords.z - 1.0, pedInfo.coords.w, false, true)
    FreezeEntityPosition(sellPed, true)
    SetEntityInvincible(sellPed, true)
    SetBlockingOfNonTemporaryEvents(sellPed, true)
    SetEntityAsMissionEntity(sellPed, true, true)
    SetModelAsNoLongerNeeded(model)

    local blip = AddBlipForCoord(pedInfo.coords.x, pedInfo.coords.y, pedInfo.coords.z)
    SetBlipSprite(blip, 141)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Hunting Trader')
    EndTextCommandSetBlipName(blip)

    ox_target:addLocalEntity(sellPed, {
        {
            label = 'Sell Hunting Goods',
            icon = 'fa-solid fa-dollar-sign',
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('xrb-hunting:sellProducts')
            end
        },
        {
            label = 'Open Hunting Talents',
            icon = 'fa-solid fa-tree',
            distance = 2.5,
            onSelect = function()
                openHuntingUi()
            end
        }
    })
end)

CreateThread(function()
    if not Config.EnableAnimalSpawning then
        return
    end

    while true do
        Wait(Config.SpawnCheckInterval)

        cleanupAnimals()

        local zone, zoneIndex = getPlayerZone()
        if zone and zoneIndex then
            local currentAnimals = getZoneAnimalCount(zoneIndex)
            local maxAnimals = getMaxAnimalsForPlayer()

            if currentAnimals < maxAnimals then
                local toSpawn = maxAnimals - currentAnimals
                for _ = 1, toSpawn do
                    if not spawnRandomAnimalInZone(zone, zoneIndex) then
                        break
                    end
                    Wait(350)
                end
            end
        end
    end
end)

CreateThread(function()
    if not Config.UseSpecificHuntingZones then
        return
    end

    local lastAlert = 0

    while true do
        Wait(1000)

        local now = GetGameTimer()
        if now - lastAlert >= 7000 and not getPlayerZone() then
            local weapon = GetSelectedPedWeapon(PlayerPedId())
            local weaponGroup = GetWeapontypeGroup(weapon)
            if weaponGroup == `WEAPONGROUP_RIFLE`
                or weaponGroup == `WEAPONGROUP_SNIPER`
                or weaponGroup == `WEAPONGROUP_SHOTGUN` then
                notify('You are not in a designated hunting zone.', 'warning')
                lastAlert = now
            end
        end
    end
end)

RegisterCommand('hunting', function()
    openHuntingUi()
end, false)

RegisterNUICallback('close', function(_, cb)
    huntingUiOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback('confirmTalents', function(data, cb)
    local ids = data and data.ids
    if type(ids) == 'table' then
        for i = 1, #ids do
            local id = ids[i]
            if type(id) == 'string' and id ~= '' then
                TriggerServerEvent('xrb-hunting:talents:buy', id)
            end
        end
    end

    cb({ ok = true })
end)

RegisterNUICallback('openAdminMenu', function(_, cb)
    TriggerServerEvent('xrb-hunting:admin:requestData')
    cb({ ok = true })
end)

RegisterNUICallback('adminApplyAction', function(data, cb)
    if not huntingIsAdmin then
        cb({ ok = false })
        return
    end

    local targetId = data and data.targetId
    local action = data and data.action
    local value = data and data.value

    if targetId and action then
        applyAdminAction(targetId, action, value)
    end

    cb({ ok = true })
end)

RegisterNUICallback('adminZoneAction', function(data, cb)
    if not huntingIsAdmin then
        cb({ ok = false })
        return
    end

    local action = data and data.action
    local ok = false

    if action == 'spawn_animals' then
        ok = adminSpawnZoneAnimals()
    elseif action == 'clear_animals' then
        ok = adminClearZoneAnimals()
    elseif action == 'reset_zone' then
        ok = adminResetZoneAnimals()
    end

    cb({ ok = ok })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    removeHuntingZoneBlips()

    for i = 1, #spawnedAnimals do
        local entity = spawnedAnimals[i].entity
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    if sellPed and DoesEntityExist(sellPed) then
        DeleteEntity(sellPed)
    end
end)
