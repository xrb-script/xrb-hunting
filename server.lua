local ESX = nil
local QBCore = nil


if Config.Framework == 'esx' then
    local esxExport = exports.es_extended
    if esxExport then
        ESX = esxExport:getSharedObject()
        if ESX then
            print("[xrb-Hunting] ESX Framework Detected and Initialized (Server).")
        else
            print("[xrb-Hunting] ERROR: Could not get ESX Shared Object on Server. Is es_extended started and updated?")
        end
    else
         print("[xrb-Hunting] ERROR: es_extended export not found on Server. Is es_extended started?")
    end
elseif Config.Framework == 'qbcore' then
    local qbcoreExport = exports['qb-core']
    if qbcoreExport then
        QBCore = qbcoreExport:GetCoreObject()
        if QBCore then
             print("[xrb-Hunting] QBCore Framework Detected and Initialized (Server).")
        else
             print("[xrb-Hunting] ERROR: Could not get QBCore Object on Server. Is qb-core started and updated?")
        end
    else
        print("[xrb-Hunting] ERROR: qb-core export not found on Server. Is qb-core started?")
    end
else
    print("[xrb-Hunting] ERROR: Invalid framework specified in config.lua. Please set Config.Framework to 'esx' or 'qbcore'.")
end

local ox_inventory = exports.ox_inventory

-- ==================== UTILITY FUNCTION ====================

local function NotifyClient(source, msg, notificationType) 
    local oxLibType = 'inform' 
    if notificationType == 'error' then
        oxLibType = 'error' 
    elseif notificationType == 'success' then
        oxLibType = 'success' 
    end
    TriggerClientEvent('ox_lib:notify', source, { description = msg, type = oxLibType })
end

-- ==================== CALLBACKS ====================
lib.callback.register('hunting:checkInventorySpace', function(source, animalData)
    if not animalData or not animalData.meat or not animalData.skin or not animalData.meatAmount then
        print(('[xrb-Hunting] Error in checkInventorySpace callback: Invalid animalData received from source %s'):format(source))
        return false
    end
    local canCarryMeat = ox_inventory:CanCarryItem(source, animalData.meat, animalData.meatAmount.max)
    local canCarrySkin = ox_inventory:CanCarryItem(source, animalData.skin, 1)
    return (canCarryMeat and canCarrySkin)
end)

-- ==================== EVENTET ====================
RegisterServerEvent('hunting:skinAnimal', function(animalData)
    local src = source
    if not animalData or not animalData.meat or not animalData.skin or not animalData.meatAmount then
         print(('[xrb-Hunting] Error in hunting:skinAnimal event: Invalid animalData received from source %s'):format(src))
         NotifyClient(src, 'An error occurred during skinning.', 'error') 
         return
    end

    local meatAmount = math.random(animalData.meatAmount.min, animalData.meatAmount.max)
    local skinChanceRoll = math.random(1, 100)
    local gotSkin = (skinChanceRoll <= animalData.skinChance)

    local canCarryMeat = ox_inventory:CanCarryItem(src, animalData.meat, meatAmount)
    local canCarrySkin = not gotSkin or ox_inventory:CanCarryItem(src, animalData.skin, 1)

    if not canCarryMeat then
        NotifyClient(src, 'You don\'t have enough space for the meat!', 'error')
        return
    end
    if gotSkin and not canCarrySkin then
         NotifyClient(src, 'You don\'t have enough space for the skin!', 'error') 
         return
    end

    local successMeat = ox_inventory:AddItem(src, animalData.meat, meatAmount)
    local successSkin = false
    if gotSkin then
        successSkin = ox_inventory:AddItem(src, animalData.skin, 1)
    end

    if not successMeat or (gotSkin and not successSkin) then
        NotifyClient(src, 'Failed to add items to inventory, try again.', 'error')
        if successMeat then ox_inventory:RemoveItem(src, animalData.meat, meatAmount) end
        if successSkin then ox_inventory:RemoveItem(src, animalData.skin, 1) end
        return
    end

    -- Notify success
    local meatLabel = ox_inventory:Items(animalData.meat)?.label or animalData.meat 
    local skinLabel = ox_inventory:Items(animalData.skin)?.label or animalData.skin
    local message = ('Skinned %sx %s'):format(meatAmount, meatLabel)
    if gotSkin and successSkin then
        message = message .. (' and 1x %s'):format(skinLabel)
    end
    NotifyClient(src, message, 'success')

    -- Add XP or other logic here if desired
end)


RegisterServerEvent('hunting:sellProducts', function()
    local src = source
    local total = 0
    local itemsSold = {} 


    for itemName, price in pairs(Config.Prices) do
        local itemCount = ox_inventory:GetItemCount(src, itemName, nil, false)
        if itemCount > 0 then
            local removed = ox_inventory:RemoveItem(src, itemName, itemCount)
            if removed >= itemCount then 
                local itemValue = itemCount * price
                total = total + itemValue
                itemsSold[itemName] = itemCount 
                print(("[xrb-Hunting] Player %s sold %d x %s for $%d"):format(src, itemCount, itemName, itemValue))
            else
                 NotifyClient(src, ('Failed to remove %s from inventory.'):format(ox_inventory:Items(itemName)?.label or itemName), 'error')
                 print(("[xrb-Hunting] ERROR: Failed to remove %d x %s for player %s"):format(itemCount, itemName, src))
                 return
            end
        end
    end

    if total > 0 then
        local moneyAdded = false
        if Config.Framework == 'esx' and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.addAccountMoney('cash', total) -- Use 'cash' or 'bank' as needed
                moneyAdded = true
            else
                 print(("[xrb-Hunting] ERROR: Could not get xPlayer for source %s to add money."):format(src))
            end
        elseif Config.Framework == 'qbcore' and QBCore then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                Player.Functions.AddMoney('cash', total, "Sold hunting products")
                moneyAdded = true
            else
                 print(("[xrb-Hunting] ERROR: Could not get QBCore Player for source %s to add money."):format(src))
            end
        else
             print(("[xrb-Hunting] ERROR: Cannot distribute money. Invalid or uninitialized framework (Source: %s)."):format(src))
        end

        if moneyAdded then
            NotifyClient(src, ('Sold products for $%s'):format(total), 'success') 
        else
            NotifyClient(src, 'Sold products, but there was an error adding money. Items removed. Contact an admin.', 'error')
        end
    else
        NotifyClient(src, 'You have no products to sell!', 'inform') 
    end
end)
