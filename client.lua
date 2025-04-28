local ESX = nil
local QBCore = nil
local PlayerData = {} -- Store player data if needed (like job for QBCore)

-- Attempt to get framework object based on Config setting
CreateThread(function()
    Wait(500) -- Give framework time to load after resource start
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

-- Funksioni i njoftimeve (Updated)
local function Notify(msg, type)
    local notificationType = type or 'inform' -- Default type for QBCore/ox_lib
    local isError = (type == 'error') -- Helper for ox_lib

    if Config.Framework == 'esx' and ESX then
        ESX.ShowNotification(msg) -- ESX notification type is usually inferred or simpler
    elseif Config.Framework == 'qbcore' and QBCore then
        QBCore.Functions.Notify(msg, notificationType) -- Use QBCore's preferred function
    else
        -- Përdor ox_lib si fallback or if no framework selected/found
        lib.notify({ description = msg, type = isError and 'error' or 'success' })
    end
end


-- Funksioni kryesor për skinning
local function skinAnimal(entity)
    local playerPed = PlayerPedId() -- Get player ped inside function

    if not DoesEntityExist(entity) then return Notify('The animal does not exist.', 'error') end

    if IsPedInAnyVehicle(playerPed, false) then
        return Notify('You cant get out of the car!', 'error')
    end

    local animalModelHash = GetEntityModel(entity)
    -- Use the new config function to get data
    local animalData = Config.GetAnimalDataByHash(animalModelHash)

    if not animalData then return Notify('This animal cannot be skinned.', 'error') end

    -- Kontrollo nëse ka thikë
    if ox_inventory:Search('count', 'skining_knife') < 1 then
        return Notify('I need a skinning knife!', 'error') -- Corrected typo
    end

    -- Kontrollo kapacitetin e inventarit (në server)
    -- Pass animalData directly, server doesn't need the hash again
    lib.callback('hunting:checkInventorySpace', false, function(canCarry)
        if not canCarry then return Notify('You have no space in your inventory.', 'error') end

        -- Nis skinning
        local success = lib.progressBar({
            duration = 5000,
            label = 'Skining...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true }, -- Disable car movement too
            anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }
        })

        if not success then
            -- ClearPedTasks(playerPed) -- No need to clear if progressbar handles cancellation anims
            return Notify('Skinning was stopped', 'error')
        end

        -- Nëse kalon të gjitha kontrollet
        -- Send the specific animal data found in config
        TriggerServerEvent('hunting:skinAnimal', animalData)
        DeleteEntity(entity) -- Delete after successful skinning trigger
    end, animalData)
end

-- Shto targetet për kafshët
CreateThread(function()
    Wait(1000) -- Wait for config and framework init
    for hash, data in pairs(Config.Animals) do
        ox_target:addModel(data.modelHash, { -- Use the explicit modelHash from config
            label = 'Skin ' .. (data.name or 'Animal'), -- Use name from config if available
            icon = 'fa-solid fa-bone', -- Updated icon
            distance = 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                -- Add extra checks if needed, e.g., check if animal is dead
                return IsEntityDead(entity) -- Only allow skinning dead animals
            end,
            onSelect = function(data)
                skinAnimal(data.entity)
            end
        })
    end
    print("[xrb-Hunting] Animal targets added.")
end)

-- Krijo ped për shitje
CreateThread(function()
    local pedInfo = Config.SellPed
    RequestModel(pedInfo.model)
    while not HasModelLoaded(pedInfo.model) do Wait(10) end

    local sellPed = CreatePed(4, pedInfo.model, pedInfo.coords.xyz, pedInfo.coords.w, false, true) -- Use true for network sync
    FreezeEntityPosition(sellPed, true)
    SetEntityInvincible(sellPed, true)
    SetBlockingOfNonTemporaryEvents(sellPed, true)
    SetEntityAsMissionEntity(sellPed, true, true) -- Keep ped from despawning

    -- Blip
    local blip = AddBlipForCoord(pedInfo.coords.xyz)
    SetBlipSprite(blip, 141) -- Consider a more fitting sprite like 355 (Butcher) or 566 (Shop)
    SetBlipColour(blip, 2)   -- Red
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Meat Seller')
    EndTextCommandSetBlipName(blip)

    -- Target për shitje
    ox_target:addLocalEntity(sellPed, {
        label = 'Sell Products', -- Corrected label
        icon = 'fa-dollar-sign',
        distance = 2.5, -- Slightly larger distance for NPCs
        onSelect = function()
            TriggerServerEvent('hunting:sellProducts')
        end
    })
     print("[xrb-Hunting] Sell Ped created.")
end)

-- Cleanup on resource stop (optional but good practice)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Remove targets and peds if necessary (more complex to track all peds/targets)
        -- For simplicity, we'll assume server restart handles cleanup
        print("[xrb-Hunting] Resource stopping.")
    end
end)
