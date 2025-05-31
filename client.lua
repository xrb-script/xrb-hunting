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
                -- You might want to get player data here if needed later
                -- AddEventHandler('esx:playerLoaded', function(xPlayer) PlayerData = xPlayer end)
                -- TriggerServerEvent('esx:getSharedObject', function(obj) ESX = obj end) -- Alternative way
            else
                print("[xrb-Hunting] ERROR: Could not get ESX Shared Object. Is es_extended started and updated?")
            end
        else
            print("[xrb-Hunting] ERROR: es_extended export not found. Is es_extended started?")
        end
    elseif Config.Framework == 'qbcore' then
        local qbcoreExport = exports['qb-core']
        if qbcoreExport then
            QBCore = qbcoreExport:GetCoreObject()
            if QBCore then
                print("[xrb-Hunting] QBCore Framework Detected and Initialized.")
                -- Get player data if needed
                -- AddEventHandler('QBCore:Client:OnPlayerLoaded', function() PlayerData = QBCore.Functions.GetPlayerData() end)
                -- RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() PlayerData = {} end)
                -- PlayerData = QBCore.Functions.GetPlayerData() -- Initial grab
            else
                 print("[xrb-Hunting] ERROR: Could not get QBCore Object. Is qb-core started and updated?")
            end
        else
             print("[xrb-Hunting] ERROR: qb-core export not found. Is qb-core started?")
        end
    else
        print("[xrb-Hunting] ERROR: Invalid framework specified in config.lua. Please set Config.Framework to 'esx' or 'qbcore'.")
    end
end)

local ox_inventory = exports.ox_inventory
local ox_target = exports.ox_target


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



local function skinAnimal(entity)
    local playerPed = PlayerPedId()

    if not DoesEntityExist(entity) then return Notify('The animal does not exist.', 'error') end

    if IsPedInAnyVehicle(playerPed, false) then
        return Notify('You cant get out of the car!', 'error')
    end

    local animalModelHash = GetEntityModel(entity)
    local animalData = Config.GetAnimalDataByHash(animalModelHash)

    if not animalData then return Notify('This animal cannot be skinned.', 'error') end


    if ox_inventory:Search('count', 'skining_knife') < 1 then
        return Notify('I need a skinning knife!', 'error')
    end
n
    lib.callback('hunting:checkInventorySpace', false, function(canCarry)
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
            -- ClearPedTasks(playerPed) -- No need to clear if progressbar handles cancellation anims
            return Notify('Skinning was stopped', 'error')
        end

        TriggerServerEvent('hunting:skinAnimal', animalData)
        DeleteEntity(entity)
    end, animalData)
end


CreateThread(function()
    Wait(1000)
    for hash, data in pairs(Config.Animals) do
        ox_target:addModel(data.modelHash, { 
            label = 'Skin ' .. (data.name or 'Animal'),
            icon = 'fa-solid fa-bone',
            distance = 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                return IsEntityDead(entity)
            end,
            onSelect = function(data)
                skinAnimal(data.entity)
            end
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

    -- Blip
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
        icon = 'fa-dollar-sign',
        distance = 2.5,
        onSelect = function()
            TriggerServerEvent('hunting:sellProducts')
        end
    })
     print("[xrb-Hunting] Sell Ped created.")
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("[xrb-Hunting] Resource stopping.")
    end
end)
