Config = {}

Config.Debug = false

Config.Framework = "qb"
Config.Target = "auto"
Config.Inventory = "auto"

Config.AdminPermission = "admin"

Config.Commands = {
    MainMenu = "mocrestaurant",
    Create = "moccreate",
    Orders = "mocorders"
}

Config.RestaurantTypes = {
    ["fastfood"] = "Fast Food",
    ["coffee"] = "Coffee Shop",
    ["pizza"] = "Pizza Restaurant",
    ["custom"] = "Custom Restaurant"
}

Config.Builder = {
    DrawDistance = 20.0,
    MarkerScale = vector3(0.25, 0.25, 0.25)
}

Config.Interactions = {
    DrawDistance = 15.0,
    InteractDistance = 0.65,
    MarkerScale = vector3(0.22, 0.22, 0.22),
    Key = 38 -- E
}

Config.Ordering = {
    TaxPercent = 0,
    DefaultPayment = "cash",
    AllowCash = true,
    AllowBank = true,
    MaxQuantityPerItem = 20
}

Config.LocationTypes = {
    { value = "register", label = "Register" },
    { value = "grill", label = "Grill" },
    { value = "fryer", label = "Fryer" },
    { value = "prep", label = "Prep Station" },
    { value = "drinks", label = "Drink Station" },
    { value = "storage", label = "Dry Storage" },
    { value = "freezer", label = "Freezer" },
    { value = "tray", label = "Tray Pickup" },
    { value = "manager", label = "Manager Station" },
    { value = "drive_speaker", label = "Drive-Thru Speaker" },
    { value = "drive_payment", label = "Drive-Thru Payment Window" },
    { value = "drive_pickup", label = "Drive-Thru Pickup Window" },
    { value = "delivery_receiving", label = "Delivery Receiving" }
}

-- Starter menu templates. These are copied into SQL from /mocrestaurant > Seed Menu.
Config.StarterMenus = {
    fastfood = {
        { item = "moc_classic_burger", label = "Classic Burger", price = 8, category = "Burgers" },
        { item = "moc_cheeseburger", label = "Cheeseburger", price = 10, category = "Burgers" },
        { item = "moc_fries", label = "Fries", price = 4, category = "Sides" },
        { item = "moc_cola", label = "Cola", price = 3, category = "Drinks" }
    },
    coffee = {
        { item = "moc_coffee", label = "Coffee", price = 4, category = "Drinks" },
        { item = "moc_latte", label = "Latte", price = 6, category = "Drinks" },
        { item = "moc_muffin", label = "Muffin", price = 5, category = "Food" }
    },
    pizza = {
        { item = "moc_cheese_pizza", label = "Cheese Pizza", price = 14, category = "Pizza" },
        { item = "moc_pepperoni_pizza", label = "Pepperoni Pizza", price = 17, category = "Pizza" },
        { item = "moc_cola", label = "Cola", price = 3, category = "Drinks" }
    },
    custom = {}
}

Config.Kitchen = {
    Enabled = true,
    RequireRestaurantJob = true
}

Config.Recipes = {
    moc_classic_burger = {
        label = "Classic Burger",
        station = "grill",
        time = 7000,
        ingredients = {
            { item = "burger_bun", amount = 1 },
            { item = "burger_patty", amount = 1 }
        }
    },
    moc_fries = {
        label = "Fries",
        station = "fryer",
        time = 6000,
        ingredients = {
            { item = "raw_fries", amount = 1 }
        }
    },
    moc_cola = {
        label = "Cola",
        station = "drinks",
        time = 3500,
        ingredients = {
            { item = "empty_cup", amount = 1 }
        }
    }
}

Config.Storage = {
    Enabled = true,
    DefaultSlots = 80,
    DefaultWeight = 200000
}

Config.POS = {
    UseNUI = true,
    Title = "MOC Restaurant"
}

-- Per-location interaction radius fallback.
Config.DefaultStationRadius = 0.65
Config.MinStationRadius = 0.25
Config.MaxStationRadius = 3.0

Config.KDS = {
    Enabled = true,
    DefaultSort = "oldest"
}

Config.Packaging = {
    Enabled = true,
    BagItem = "moc_food_bag",
    TrayItem = "moc_food_tray"
}

Config.DriveThru = {
    Enabled = true,
    RequireVehicleAtSpeaker = true,
    MaxSpeakerDistance = 2.0
}

Config.Animations = {
    Enabled = true,
    Handoff = { dict = "mp_common", clip = "givetake1_a" },
    Prep = { dict = "amb@prop_human_bbq@male@base", clip = "base" }
}

Config.Business = {
    Enabled = true,
    AllowPlayerOwnership = true,
    PayrollIntervalMinutes = 30,
    SkipPayIfInsufficientFunds = true
}


Config.BusinessManagement = {
    Enabled = true,
    ManagerStationType = "manager",
    PayrollIntervalMinutes = 30,
    RequireClockInForWorkPermissions = true,
    UseBusinessAccountForPayroll = true,
    SyncRanksToQBCore = true,

    DefaultPermissions = {
        pos = true,
        kitchen = true,
        drinks = true,
        storage = true,
        drive_thru = true,
        manage_employees = false,
        manage_ranks = false,
        manage_payroll = false,
        view_sales = false,
        edit_restaurant = false,
        manage_deliveries = false
    },

    OwnerPermissions = {
        pos = true,
        kitchen = true,
        drinks = true,
        storage = true,
        drive_thru = true,
        manage_employees = true,
        manage_ranks = true,
        manage_payroll = true,
        view_sales = true,
        edit_restaurant = true,
        manage_deliveries = true
    }
}

Config.Deliveries = {
    Enabled = true,

    -- Minutes between placing an order and being able to receive it.
    DefaultLeadMinutes = 10,

    -- Delivery Receiving station interaction.
    DefaultInteractionRadius = 0.75,

    -- Orders are charged to the restaurant's business account.
    RequireBusinessAccount = true,

    -- Maximum quantity of one catalog item in a single delivery order.
    MaxQuantityPerItem = 250,

    -- Starter wholesale catalog. Add more ingredients here as needed.
    Items = {
        { item = "burger_bun", label = "Burger Bun", unitPrice = 1 },
        { item = "burger_patty", label = "Raw Burger Patty", unitPrice = 3 },
        { item = "raw_fries", label = "Raw Fries", unitPrice = 2 },
        { item = "empty_cup", label = "Empty Drink Cup", unitPrice = 1 }
    }
}

Config.AutomaticBusinessSetup = {
    Enabled = true,

    -- Automatically create/update the runtime QBCore job from MOC ranks.
    CreateQBCoreJob = true,

    -- Automatically create a qb-banking job account when possible.
    CreateQBBankingAccount = true,

    -- Balance used only when creating a brand-new business account.
    StartingBusinessBalance = 0,

    -- If the account already exists, MOC leaves its balance untouched.
    PreserveExistingAccountBalance = true
}

Config.Advanced = {
    SelfServiceKiosks = false,
    Loyalty = false,
    Catering = false,
    NPCustomers = false,
    FoodQuality = false
}

Config.Production = {
    StrictValidation = true,
    LogWarnings = true
}

Config.MenuTemplates = {
    Enabled = true,
    AllowOwnerMenuManagement = true,
    AutoGenerateRestaurantKeyFromJob = true
}


Config.KitchenProduction = {
    Enabled = true,
    RequireClockIn = true,
    DefaultCraftTimeMs = 5000,

    StationLabels = {
        grill = "Grill",
        fryer = "Fryer",
        prep = "Prep Station",
        drinks = "Drink Station",
        drink = "Drink Station"
    }
}


Config.RestaurantBlips = {
    Enabled = true,

    DefaultSprite = 52,
    DefaultColor = 2,
    DefaultScale = 0.75,
    ShortRange = true,

    -- Input validation ranges.
    MinSprite = 1,
    MaxSprite = 1000,
    MinColor = 0,
    MaxColor = 85
}


Config.RecipeDisplay = {
    ShowIngredientRequirements = true,
    ShowCurrentInventoryCounts = true
}
