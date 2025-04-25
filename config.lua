Config = {}

-- xResul Albania Hunting Script
-- List of animals and possibilities for meat and skin
Config.Animals = {
    [-832573324] = { -- pig
        meat = 'boar_meat',
        skin = 'boar_skin',
        meatAmount = { min = 7, max = 10 },
        skinChance = 70
    },
    [-664053099] = { -- deer
        meat = 'deer_meat',
        skin = 'deer_skin',
        meatAmount = { min = 8, max = 12 },
        skinChance = 80
    },
    [1682622302] = { -- Coyote
        meat = 'coyote_meat',
        skin = 'coyote_skin',
        meatAmount = { min = 5, max = 8 },
        skinChance = 60
    },
    [-541762431] = { -- rabbit
        meat = 'rabbit_meat',
        skin = 'rabbit_skin',
        meatAmount = { min = 3, max = 5 },
        skinChance = 50
    },
    [-50684386] = { -- cow
        meat = 'cow_meat',
        skin = 'cow_skin',
        meatAmount = { min = 15, max = 20 },
        skinChance = 20
    }
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
    cow_skin = 200   
}

-- Ped for selling products
Config.SellPed = {
    model = 'csb_chef', 
    coords = vector4(224.72, -441.26, 45.25, 151.32) 
}