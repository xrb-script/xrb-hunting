ESX = nil
QBCore = nil

-- Kontrollo framework-in dhe inicializo
if GetResourceState('es_extended') == 'started' then
    ESX = exports["es_extended"]:getSharedObject()
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local ox_inventory = exports.ox_inventory

-- ==================== CALLBACKS ====================
-- Kontrollo kapacitetin e inventarit (për klientin)
lib.callback.register('hunting:checkInventorySpace', function(source, animalData)
    local canCarryMeat = ox_inventory:CanCarryItem(source, animalData.meat, animalData.meatAmount.max)
    local canCarrySkin = ox_inventory:CanCarryItem(source, animalData.skin, 1)
    return (canCarryMeat and canCarrySkin)
end)

-- ==================== EVENTET ====================
-- Skinning
RegisterServerEvent('hunting:skinAnimal', function(animalData)
    local src = source
    local meatAmount = math.random(animalData.meatAmount.min, animalData.meatAmount.max)
    local skinChance = math.random(1, 100)

    -- Shto itemet në inventar
    if ox_inventory:CanCarryItem(src, animalData.meat, meatAmount) then
        ox_inventory:AddItem(src, animalData.meat, meatAmount)
    else
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You have no room for meat!' })
    end

    if skinChance <= animalData.skinChance then
        if ox_inventory:CanCarryItem(src, animalData.skin, 1) then
            ox_inventory:AddItem(src, animalData.skin, 1)
        else
            return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You have no room for skin!' })
        end
    end

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'I got it '..meatAmount..'x '..animalData.meat })
end)

-- Shitja e produkteve
RegisterServerEvent('hunting:sellProducts', function()
    local src = source
    local total = 0

    -- Llogarit totalin
    for itemName, price in pairs(Config.Prices) do
        local itemCount = exports.ox_inventory:GetItem(src, itemName, nil, true)
        if itemCount > 0 then
            exports.ox_inventory:RemoveItem(src, itemName, itemCount)
            total = total + (itemCount * price)
        end
    end

    -- Shpërnda paratë
    if total > 0 then
        if ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            xPlayer.addMoney(total)
        elseif QBCore then
            local Player = QBCore.Functions.GetPlayer(src)
            Player.Functions.AddMoney('cash', total)
        end
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Sell ​​products for $'..total })
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You have no products for sale!' })
    end
end)