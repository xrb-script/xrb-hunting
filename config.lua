Config = {}

-- xResul Albania Hunting Script

Config.Framework = 'qbcore' -- Change to 'qbcore' if you use QBCore
Config.UseSpecificHuntingZones = true -- Set to true to enable specific hunting zones, false for entire map
Config.HuntingZones = {
    {
        name = 'Great Chaparral Hunting Grounds',
        coords = vector3(2500.0, 3300.0, 40.0), -- Central point for the blip
        radius = 500.0, -- Radius of the zone
        blip = {
            sprite = 119, -- icon
            color = 3, -- color
            scale = 0.8,
            shortRange = true,
            label = 'Hunting Zone: Great Chaparral'
        }
    },
    {
        name = 'Paleto Forest Hunting Area',
        coords = vector3(-300.0, 5800.0, 40.0),
        radius = 700.0,
        blip = {
            sprite = 119,
            color = 11,
            scale = 0.8,
            shortRange = true,
            label = 'Hunting Zone: Paleto Forest'
        }
    },
    {
        name = 'Mount Josiah Foothills',
        coords = vector3(-1500.0, 4400.0, 50.0),
        radius = 400.0,
        blip = {
            sprite = 119,
            color = 46,
            scale = 0.8,
            shortRange = true,
            label = 'Hunting Zone: Mount Josiah'
        }
    }
    -- Add more hunting zones as needed
}

-- List of animals and possibilities for meat and skin
Config.Animals = {
    [-832573324] = { -- Boar
        name = 'Boar',
        modelHash = -832573324,
        meat = 'boar_meat',
        skin = 'boar_skin',
        meatAmount = { min = 7, max = 10 },
        skinChance = 70
    },
    [-664053099] = { -- deer
        name = 'Deer',
        modelHash = -664053099,
        meat = 'deer_meat',
        skin = 'deer_skin',
        meatAmount = { min = 8, max = 12 },
        skinChance = 80
    },
    [1682622302] = { -- Coyote
        name = 'Coyote',
        modelHash = 1682622302,
        meat = 'coyote_meat',
        skin = 'coyote_skin',
        meatAmount = { min = 5, max = 8 },
        skinChance = 60
    },
    [-541762431] = { -- rabbit
        name = 'Rabbit',
        modelHash = -541762431,
        meat = 'rabbit_meat',
        skin = 'rabbit_skin',
        meatAmount = { min = 3, max = 5 },
        skinChance = 50
    },
    [-50684386] = { -- cow
        name = 'Cow',
        modelHash = -50684386,
        meat = 'cow_meat',
        skin = 'cow_skin',
        meatAmount = { min = 15, max = 20 },
        skinChance = 20
    },
    [1794449327] = { -- Chicken
    name = 'chicken',
    modelHash = 1794449327,
    meat = 'chicken_meat',
    skin = 'chicken_skin',
    meatAmount = { min = 1, max = 3 },
    skinChance = 10
    },
    [-1323586730] = { -- pig
    name = 'Pig',
    modelHash = -1323586730,
    meat = 'pig_meat',
    skin = 'pig_skin',
    meatAmount = { min = 7, max = 10 },
    skinChance = 20
    }
    -- Add more animals here using their model hash as the key
}

-- Prices for meat and leather
Config.Prices = {
    boar_meat = 50,
    boar_skin = 100,
    deer_meat = 70,
    deer_skin = 150,
    coyote_meat = 40,
    coyote_skin = 80,
    rabbit_meat = 30,
    rabbit_skin = 60,
    cow_meat = 100,
    cow_skin = 200,
    chicken_meat = 50,
    chicken_skin = 500,
    pig_meat = 60,
    pig_skin = 150
}

-- Ped for selling products
Config.SellPed = {
    model = 'csb_chef',
    coords = vector4(224.72, -441.26, 44.25, 150.32)
}

function Config.GetAnimalDataByHash(hash)
    for _, data in pairs(Config.Animals) do
        if data.modelHash == hash then
            return data
        end
    end
    return nil 
end

function Config.IsPlayerInHuntingZone()
    if not Config.UseSpecificHuntingZones then
        return true
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, zone in pairs(Config.HuntingZones) do
        local dist = GetDistanceBetweenCoords(playerCoords, zone.coords, true)
        if dist <= zone.radius then
            return true
        end
    end
    return false
end

