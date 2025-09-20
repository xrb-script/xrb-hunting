local ESX = nil
local QBCore = nil
local PlayerData = {}

CreateThread(function()
    Wait(500)
    if Config.Framework == 'esx' then
        local esxExport = exports.es_extended
        if esxExport then
            ESX = esxExport:getSharedObject()
            if ESX then
                print("[xrb-Hunting] ESX Framework Detected and Initialized.")
            else
                print("[xrb-Hunting] ERROR: Could not get ESX Shared Object.")
            end
        end
    elseif Config.Framework == 'qbcore' then
        local qbcoreExport = exports['qb-core']
        if qbcoreExport then
            QBCore = qbcoreExport:GetCoreObject()
            if QBCore then
                print("[xrb-Hunting] QBCore Framework Detected and Initialized.")
            else
                print("[xrb-Hunting] ERROR: Could not get QBCore Object.")
            end
        end
    else
        print("[xrb-Hunting] ERROR: Invalid framework specified.")
    end
end)

local ox_inventory = exports.ox_inventory
local ox_target = exports.ox_target

local huntingZoneBlips = {}

local function Notify(msg, type)
    local notificationType = type or 'inform'
    local isError = (type == 'error')
    if Config.Framework == 'esx' and ESX then
        ESX.ShowNotification(msg) 
    elseif Config.Framework == 'qbcore' and QBCore then
        QBCore.Functions.Notify(msg, notificationType) 
    else
        lib.notify({ description = msg, type = isError and 'error' or 'success' })
    end
end

local function CreateHuntingZoneBlips()
    if Config.UseSpecificHuntingZones and next(Config.HuntingZones) ~= nil then
        for i, zone in pairs(Config.HuntingZones) do
            local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(blip, zone.blip.sprite)
            SetBlipColour(blip, zone.blip.color)
            SetBlipScale(blip, zone.blip.scale)
            SetBlipAsShortRange(blip, zone.blip.shortRange)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(zone.blip.label)
            EndTextCommandSetBlipName(blip)
            table.insert(huntingZoneBlips, blip)
        end
        print("[xrb-Hunting] Hunting zone blips created.")
    else
        print("[xrb-Hunting] Specific hunting zones are disabled or not configured. No blips created.")
    end
end

local function RemoveHuntingZoneBlips()
    for _, blip in ipairs(huntingZoneBlips) do
        RemoveBlip(blip)
    end
    huntingZoneBlips = {}
    print("[xrb-Hunting] Hunting zone blips removed.")
end

local function skinAnimal(entity)
    local playerPed = PlayerPedId()
    if not DoesEntityExist(entity) then return Notify('The animal does not exist.', 'error') end
    if IsPedInAnyVehicle(playerPed, false) then
        return Notify('You cant get out of the car!', 'error')
    end

    if not Config.IsPlayerInHuntingZone() then
        return Notify('You can only skin animals in designated hunting zones!', 'error')
    end

    local animalModelHash = GetEntityModel(entity)
    local animalData = Config.GetAnimalDataByHash(animalModelHash)
    if not animalData then return Notify('This animal cannot be skinned.', 'error') end

    if ox_inventory:Search('count', 'skining_knife') < 1 then
        return Notify('I need a skinning knife!', 'error')
    end

    lib.callback('xrb-hunting:checkInventorySpace', false, function(canCarry)
        if not canCarry then return Notify('You have no space in your inventory.', 'error') end

        local success = lib.progressBar({
            duration = 5000,
            label = 'Skining...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }
        })

        if not success then
            return Notify('Skinning was stopped', 'error')
        end

        TriggerServerEvent('xrb-hunting:skinAnimal', animalData)
        DeleteEntity(entity)
    end, animalData)
end

CreateThread(function()
    Wait(1000)
    CreateHuntingZoneBlips()

    for hash, data in pairs(Config.Animals) do
        ox_target:addModel(data.modelHash, { 
            label = 'Skin ' .. (data.name or 'Animal'),
            icon = 'fa-solid fa-bone',
            distance = 2.0,
            canInteract = function(entity) 
                if Config.UseSpecificHuntingZones and not Config.IsPlayerInHuntingZone() then
                    return false
                end
                return IsEntityDead(entity) 
            end,
            onSelect = function(data) skinAnimal(data.entity) end
        })
    end
    print("[xrb-Hunting] Animal targets added.")
end)

CreateThread(function()
    local pedInfo = Config.SellPed
    RequestModel(pedInfo.model)
    while not HasModelLoaded(pedInfo.model) do Wait(10) end

    local sellPed = CreatePed(4, pedInfo.model, pedInfo.coords.xyz, pedInfo.coords.w, false, true)
    FreezeEntityPosition(sellPed, true)
    SetEntityInvincible(sellPed, true)
    SetBlockingOfNonTemporaryEvents(sellPed, true)
    SetEntityAsMissionEntity(sellPed, true, true)

    local blip = AddBlipForCoord(pedInfo.coords.xyz)
    SetBlipSprite(blip, 141)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Meat Seller')
    EndTextCommandSetBlipName(blip)

    ox_target:addLocalEntity(sellPed, {
        label = 'Sell Products',
        icon = 'fa-solid fa-dollar-sign',
        distance = 2.5,
        onSelect = function()
            TriggerServerEvent('xrb-hunting:sellProducts')
        end
    })

    print("[xrb-Hunting] Sell Ped created.")
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        RemoveHuntingZoneBlips()
        print("[xrb-Hunting] Resource stopping.")
    end
end)
