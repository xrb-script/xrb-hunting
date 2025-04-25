ESX = nil
QBCore = nil

if GetResourceState('es_extended') == 'started' then
    ESX = exports["es_extended"]:getSharedObject()
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local ox_inventory = exports.ox_inventory
local ox_target = exports.ox_target

-- Funksioni i njoftimeve
local function Notify(msg, type)
    if ESX then
        ESX.ShowNotification(msg)
    elseif QBCore then
        TriggerEvent('QBCore:Notify', msg, type)
    else
        -- Përdor ox_lib si fallback
        lib.notify({ description = msg, type = type and 'error' or 'success' })
    end
end


-- Funksioni kryesor për skinning
local function skinAnimal(entity)
    if not DoesEntityExist(entity) then return Notify('The animal does not exist.', 'error') end

    if IsPedInAnyVehicle(playerPed, false) then
        return Notify('You cant get out of the car!', 'error')
    end

    local animalModel = GetEntityModel(entity)
    local animalData = Config.Animals[animalModel]

    if not animalData then return Notify('This animal cannot be skinned.', 'error') end

    -- Kontrollo nëse ka thikë
    if ox_inventory:Search('count', 'skining_knife') < 1 then
        return Notify('I need a skinning knife.!', 'error')
    end

    -- Kontrollo kapacitetin e inventarit (në server)
    lib.callback('hunting:checkInventorySpace', false, function(canCarry)
        if not canCarry then return Notify('You have no space in your inventory.', 'error') end

        -- Nis skinning
        local success = lib.progressBar({
            duration = 5000,
            label = 'Skining...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = false, combat = true },
            anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }
        })

        if not success then
            ClearPedTasks(cache.ped)
            return Notify('Skinning was stopped', 'error')
        end

        -- Nëse kalon të gjitha kontrollet
        TriggerServerEvent('hunting:skinAnimal', animalData)
        DeleteEntity(entity)
    end, animalData)
end

-- Shto targetet për kafshët
CreateThread(function()
    for modelName in pairs(Config.Animals) do
        ox_target:addModel(joaat(modelName), {
            label = 'Skin Animal',
            icon = 'fa-paw',
            distance = 2.0,
            onSelect = function(data)
                skinAnimal(data.entity)
            end
        })
    end
end)

-- Krijo ped për shitje
CreateThread(function()
    local ped = Config.SellPed
    RequestModel(ped.model)
    while not HasModelLoaded(ped.model) do Wait(10) end

    local sellPed = CreatePed(4, ped.model, ped.coords.xyz, ped.coords.w, false, false)
    FreezeEntityPosition(sellPed, true)
    SetEntityInvincible(sellPed, true)
    SetBlockingOfNonTemporaryEvents(sellPed, true)

    -- Blip
    local blip = AddBlipForCoord(ped.coords.xyz)
    SetBlipSprite(blip, 141)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Meat Seller')
    EndTextCommandSetBlipName(blip)

    -- Target për shitje
    ox_target:addLocalEntity(sellPed, {
        label = 'Sell ​​Products',
        icon = 'fa-dollar-sign',
        distance = 2.0,
        onSelect = function()
            TriggerServerEvent('hunting:sellProducts')
        end
    })
end)