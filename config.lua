Config = {}

Config.Framework = 'auto'

Config.EnableAnimalSpawning = true
Config.MaxAnimalsPerZone = 8
Config.SpawnCheckInterval = 12000
Config.SpawnRadiusFromPlayer = 95.0
Config.DespawnRadiusFromPlayer = 170.0
Config.UseSpecificHuntingZones = true

Config.HuntingZones = {
    {
        name = 'Great Chaparral Hunting Grounds',
        coords = vector3(2493.56, 3281.8, 52.95),
        radius = 320.0,
        blip = {
            sprite = 496,
            color = 3,
            scale = 0.8,
            shortRange = true,
            label = 'Hunting Zone: Great Chaparral'
        },
        spawnChances = {
            { animal = -832573324, chance = 40 },
            { animal = -664053099, chance = 45 },
            { animal = 1682622302, chance = 15 }
        }
    },
    {
        name = 'Paleto Forest Hunting Area',
        coords = vector3(-300.0, 5800.0, 40.0),
        radius = 700.0,
        blip = {
            sprite = 496,
            color = 3,
            scale = 0.8,
            shortRange = true,
            label = 'Hunting Zone: Paleto Forest'
        },
        spawnChances = {
            { animal = -664053099, chance = 60 },
            { animal = -832573324, chance = 20 },
            { animal = -541762431, chance = 20 }
        }
    },
    {
        name = 'Mount Josiah Foothills',
        coords = vector3(-1500.0, 4400.0, 50.0),
        radius = 400.0,
        blip = {
            sprite = 496,
            color = 3,
            scale = 0.8,
            shortRange = true,
            label = 'Hunting Zone: Mount Josiah'
        },
        spawnChances = {
            { animal = 1682622302, chance = 50 },
            { animal = -541762431, chance = 50 }
        }
    }
}

Config.Animals = {
    [-832573324] = {
        name = 'Boar',
        modelHash = -832573324,
        meat = 'boar_meat',
        skin = 'boar_skin',
        meatAmount = { min = 7, max = 10 },
        skinChance = 0.70,
        xp = 18
    },
    [-664053099] = {
        name = 'Deer',
        modelHash = -664053099,
        meat = 'deer_meat',
        skin = 'deer_skin',
        meatAmount = { min = 8, max = 12 },
        skinChance = 0.80,
        xp = 20
    },
    [1682622302] = {
        name = 'Coyote',
        modelHash = 1682622302,
        meat = 'coyote_meat',
        skin = 'coyote_skin',
        meatAmount = { min = 5, max = 8 },
        skinChance = 0.60,
        xp = 16
    },
    [-541762431] = {
        name = 'Rabbit',
        modelHash = -541762431,
        meat = 'rabbit_meat',
        skin = 'rabbit_skin',
        meatAmount = { min = 3, max = 5 },
        skinChance = 0.50,
        xp = 12
    },
    [-50684386] = {
        name = 'Cow',
        modelHash = -50684386,
        meat = 'cow_meat',
        skin = 'cow_skin',
        meatAmount = { min = 15, max = 20 },
        skinChance = 0.20,
        xp = 25
    },
    [1794449327] = {
        name = 'Chicken',
        modelHash = 1794449327,
        meat = 'chicken_meat',
        skin = 'chicken_skin',
        meatAmount = { min = 1, max = 3 },
        skinChance = 0.10,
        xp = 8
    },
    [-1323586730] = {
        name = 'Pig',
        modelHash = -1323586730,
        meat = 'pig_meat',
        skin = 'pig_skin',
        meatAmount = { min = 7, max = 10 },
        skinChance = 0.20,
        xp = 17
    }
}

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

Config.SellPed = {
    model = 'csb_chef',
    coords = vector4(224.72, -441.26, 44.25, 150.32)
}

Config.Admin = {
    MenuCommand = 'huntingadmin',
    AcePermission = 'xrbhunting.admin',
    AllowedLicenses = {
       -- 'license:'
    }
}

Config.LevelSystem = {
    Enabled = true,
    BaseSkinningDuration = 5000,
    MinSkinningDuration = 2500,
    Levels = {
        0, 450, 1000, 1700, 2550, 3550, 4700, 6000, 7450, 9050,
        10800, 12700, 14750, 16950, 19300, 21800, 24450, 27250, 30200, 33300,
        36550, 39950, 43500, 47200, 51050, 55050, 59200, 63500, 67950, 72550,
        77300, 82200, 87250, 92450, 97800, 103300, 108950, 114750, 120700, 126800,
        133050, 139450, 146000, 152700, 159550, 166550, 173700, 181000, 188450, 196050
    }
}

Config.TalentSystem = {
    Enabled = true,
    Persist = true,
    PointsPerLevel = 1,
    MaxSkinningSpeedBonus = 0.35,
    MaxSpawnBonus = 3,
    ResetItem = {
        Enabled = true,
        ItemName = 'hunting_talent_reset',
        RemoveOnUse = true,
        UseServerUsableItem = false,
        AdminGiveCommand = 'givehuntingreset',
        AdminAcePermission = 'xrbhunting.admin'
    },
    Talents = {
        {
            id = 'hunter_basics',
            name = 'Hunter Basics',
            description = 'Unlock the hunting talent tree.',
            icon = 'icons/bow.svg',
            maxRank = 1,
            requires = {},
            ui = { col = 2, row = 1 },
            effects = {}
        },
        {
            id = 'butcher_basics',
            name = 'Field Butchery',
            description = 'Unlock hide and harvest talents.',
            icon = 'icons/knife.svg',
            maxRank = 1,
            requires = { { id = 'hunter_basics', rank = 1 } },
            ui = { col = 4, row = 1 },
            effects = {}
        },
        {
            id = 'tracking_1',
            name = 'Silent Step I',
            description = 'Skin animals a little faster.',
            icon = 'icons/tracks.svg',
            maxRank = 3,
            requires = { { id = 'hunter_basics', rank = 1 } },
            ui = { col = 1, row = 2 },
            effects = { skinningSpeedBonusPerRank = 0.03 }
        },
        {
            id = 'tracking_2',
            name = 'Silent Step II',
            description = 'Skin animals even faster.',
            icon = 'icons/target.svg',
            maxRank = 2,
            requires = { { id = 'tracking_1', rank = 3 } },
            ui = { col = 1, row = 3 },
            effects = { skinningSpeedBonusPerRank = 0.04 }
        },
        {
            id = 'meat_1',
            name = 'Clean Harvest I',
            description = 'Chance to get +1 extra meat.',
            icon = 'icons/meat.svg',
            maxRank = 3,
            requires = { { id = 'hunter_basics', rank = 1 } },
            ui = { col = 2, row = 2 },
            effects = { extraMeatChancePerRank = 0.08, extraMeatAmount = 1 }
        },
        {
            id = 'meat_2',
            name = 'Clean Harvest II',
            description = 'Chance to get +2 extra meat.',
            icon = 'icons/satchel.svg',
            maxRank = 2,
            requires = { { id = 'meat_1', rank = 3 } },
            ui = { col = 2, row = 3 },
            effects = { extraMeatChancePerRank = 0.04, extraMeatAmount = 2 }
        },
        {
            id = 'xp_1',
            name = 'Trail Knowledge I',
            description = 'Gain more hunting XP.',
            icon = 'icons/xp_hunt.svg',
            maxRank = 2,
            requires = { { id = 'hunter_basics', rank = 1 } },
            ui = { col = 3, row = 2 },
            effects = { xpBonusPerRank = 0.06 }
        },
        {
            id = 'xp_2',
            name = 'Trail Knowledge II',
            description = 'Gain much more hunting XP.',
            icon = 'icons/trophy.svg',
            maxRank = 2,
            requires = { { id = 'xp_1', rank = 2 } },
            ui = { col = 3, row = 3 },
            effects = { xpBonusPerRank = 0.08 }
        },
        {
            id = 'hide_1',
            name = 'Hide Mastery I',
            description = 'Better chance to get a clean hide.',
            icon = 'icons/hide.svg',
            maxRank = 3,
            requires = { { id = 'butcher_basics', rank = 1 } },
            ui = { col = 4, row = 2 },
            effects = { skinChanceBonusPerRank = 0.07 }
        },
        {
            id = 'hide_2',
            name = 'Hide Mastery II',
            description = 'Small chance to get an extra hide.',
            icon = 'icons/hide_plus.svg',
            maxRank = 2,
            requires = { { id = 'hide_1', rank = 3 } },
            ui = { col = 4, row = 3 },
            effects = { extraSkinChancePerRank = 0.06, extraSkinAmount = 1 }
        },
        {
            id = 'lure_1',
            name = 'Predator Lure I',
            description = 'More animals can be active in your zone.',
            icon = 'icons/deer.svg',
            maxRank = 2,
            requires = { { id = 'butcher_basics', rank = 1 } },
            ui = { col = 5, row = 2 },
            effects = { spawnCapBonusPerRank = 1 }
        },
        {
            id = 'lure_2',
            name = 'Predator Lure II',
            description = 'A little more wildlife around you.',
            icon = 'icons/deer_head.svg',
            maxRank = 1,
            requires = { { id = 'lure_1', rank = 2 } },
            ui = { col = 5, row = 3 },
            effects = { spawnCapBonusPerRank = 1 }
        },
        {
            id = 'market_1',
            name = 'Trader Eye',
            description = 'Sell hunting goods for more money.',
            icon = 'icons/coin.svg',
            maxRank = 2,
            requires = { { id = 'butcher_basics', rank = 1 } },
            ui = { col = 3, row = 4 },
            effects = { sellPriceBonusPerRank = 0.05 }
        },
        {
            id = 'stalker_1',
            name = 'Apex Stalker',
            description = 'Faster skinning and more XP.',
            icon = 'icons/target.svg',
            maxRank = 2,
            requires = { { id = 'tracking_2', rank = 2 }, { id = 'xp_2', rank = 1 } },
            ui = { col = 2, row = 4 },
            effects = { skinningSpeedBonusPerRank = 0.03, xpBonusPerRank = 0.04 }
        },
        {
            id = 'harvester_1',
            name = 'Master Harvester',
            description = 'Better meat and hide yields.',
            icon = 'icons/satchel.svg',
            maxRank = 1,
            requires = { { id = 'meat_2', rank = 2 }, { id = 'hide_2', rank = 2 } },
            ui = { col = 4, row = 4 },
            effects = {
                extraMeatChancePerRank = 0.12,
                extraMeatAmount = 2,
                skinChanceBonusPerRank = 0.10,
                extraSkinChancePerRank = 0.08,
                extraSkinAmount = 1
            }
        },
        {
            id = 'legend_1',
            name = 'Legend of the Wild',
            description = 'Powerful all-around hunting bonuses.',
            icon = 'icons/trophy.svg',
            maxRank = 1,
            requires = { { id = 'stalker_1', rank = 2 }, { id = 'harvester_1', rank = 1 }, { id = 'market_1', rank = 2 } },
            ui = { col = 3, row = 5 },
            effects = {
                skinningSpeedBonusPerRank = 0.04,
                xpBonusPerRank = 0.10,
                sellPriceBonusPerRank = 0.08
            }
        }
    }
}

Config.XPBoost = {
    Enabled = true,
    ItemName = 'hunting_xpboost',
    XpAmount = 10000,
    AdminGiveCommand = 'givehuntingxp',
    AdminAcePermission = 'xrbhunting.admin'
}

Config.Webhooks = {
    Enabled = true,
    Name = 'xrb-Hunting Logs',
    AvatarUrl = '',
    FooterText = 'xrb-Hunting',
    Color = 3447003,
    SuccessColor = 3066993,
    WarningColor = 15105570,
    DangerColor = 15158332,
    Urls = {
        xpBoost = '',
        talentReset = '',
        rewards = '',
        sales = '',
        admin = '',
        suspicious = ''
    }
}

function Config.GetAnimalDataByHash(hash)
    local animal = Config.Animals[hash]
    if animal then
        return animal
    end

    for _, data in pairs(Config.Animals) do
        if data.modelHash == hash then
            return data
        end
    end

    return nil
end
