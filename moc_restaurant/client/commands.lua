local function getRestaurantOptions(restaurants, callback)
    local options = {}
    for _, restaurant in ipairs(restaurants) do
        options[#options + 1] = {
            title = restaurant.name,
            description = ("Job: %s | Type: %s"):format(
                restaurant.job or "None",
                restaurant.type or "custom"
            ),
            icon = "utensils",
            onSelect = function()
                callback(restaurant)
            end
        }
    end
    return options
end

RegisterCommand(Config.Commands.Create, function()
    local input = lib.inputDialog(
        "Create Restaurant",
        {
            { type = "input", label = "Restaurant Name", required = true },
            { type = "input", label = "Job Name", required = false },
            {
                type = "select",
                label = "Type",
                required = true,
                options = {
                    { label = "Fast Food", value = "fastfood" },
                    { label = "Coffee Shop", value = "coffee" },
                    { label = "Pizza Restaurant", value = "pizza" },
                    { label = "Custom Restaurant", value = "custom" }
                }
            },
            {
                type = "number",
                label = "Map Blip Sprite ID",
                description = "Enter the GTA/FiveM blip sprite number for this restaurant.",
                default = Config.RestaurantBlips.DefaultSprite or 52,
                min = Config.RestaurantBlips.MinSprite or 1,
                max = Config.RestaurantBlips.MaxSprite or 1000,
                required = true
            },
            {
                type = "number",
                label = "Map Blip Color ID",
                description = "Enter the GTA/FiveM blip color number for this restaurant.",
                default = Config.RestaurantBlips.DefaultColor or 2,
                min = Config.RestaurantBlips.MinColor or 0,
                max = Config.RestaurantBlips.MaxColor or 85,
                required = true
            },
            {
                type = "number",
                label = "Blip Scale",
                default = Config.RestaurantBlips.DefaultScale or 0.75,
                min = 0.25,
                max = 2.0,
                step = 0.05,
                required = true
            }
        }
    )

    if not input then return end

    local coords = GetEntityCoords(PlayerPedId())

    TriggerServerEvent("moc_restaurant:create", {
        name = input[1],
        job = input[2],
        type = input[3],
        blipSprite = tonumber(input[4]),
        blipColor = tonumber(input[5]),
        blipScale = tonumber(input[6]),
        blipCoords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    })
end, false)

RegisterCommand(Config.Commands.MainMenu, function()
    local restaurants = lib.callback.await("moc_restaurant:getRestaurants", false) or {}

    lib.registerContext({
        id = "moc_restaurant_admin_main",
        title = "MOC Restaurant Admin",
        options = {
            {
                title = "Create Restaurant",
                description = "Create a new restaurant record.",
                icon = "plus",
                onSelect = function()
                    ExecuteCommand(Config.Commands.Create)
                end
            },
{
                title = "Edit Restaurant Blip",
                description = "Change a restaurant's map blip sprite, color, scale, or move it to your current position.",
                icon = "map-location-dot",
                disabled = #restaurants == 0,
                onSelect = function()
                    lib.registerContext({
                        id = "moc_restaurant_blip_select",
                        title = "Select Restaurant",
                        menu = "moc_restaurant_admin_main",
                        options = getRestaurantOptions(restaurants, function(restaurant)
                            local input = lib.inputDialog(
                                "Edit Restaurant Blip",
                                {
                                    {
                                        type = "number",
                                        label = "Blip Sprite ID",
                                        default = tonumber(restaurant.blip_sprite)
                                            or Config.RestaurantBlips.DefaultSprite
                                            or 52,
                                        min = Config.RestaurantBlips.MinSprite or 1,
                                        max = Config.RestaurantBlips.MaxSprite or 1000,
                                        required = true
                                    },
                                    {
                                        type = "number",
                                        label = "Blip Color ID",
                                        default = tonumber(restaurant.blip_color)
                                            or Config.RestaurantBlips.DefaultColor
                                            or 2,
                                        min = Config.RestaurantBlips.MinColor or 0,
                                        max = Config.RestaurantBlips.MaxColor or 85,
                                        required = true
                                    },
                                    {
                                        type = "number",
                                        label = "Blip Scale",
                                        default = tonumber(restaurant.blip_scale)
                                            or Config.RestaurantBlips.DefaultScale
                                            or 0.75,
                                        min = 0.25,
                                        max = 2.0,
                                        step = 0.05,
                                        required = true
                                    },
                                    {
                                        type = "checkbox",
                                        label = "Move blip to my current position",
                                        checked = false
                                    }
                                }
                            )

                            if input then
                                local coords = GetEntityCoords(PlayerPedId())

                                TriggerServerEvent(
                                    "moc_restaurant:updateBlip",
                                    {
                                        restaurantId = restaurant.id,
                                        sprite = tonumber(input[1]),
                                        color = tonumber(input[2]),
                                        scale = tonumber(input[3]),
                                        moveToCurrent = input[4] == true,
                                        coords = {
                                            x = coords.x,
                                            y = coords.y,
                                            z = coords.z
                                        }
                                    }
                                )
                            end
                        end)
                    })

                    lib.showContext("moc_restaurant_blip_select")
                end
            },
            {
                title = "Open Builder",
                description = "Place registers, kitchen stations, storage and drive-thru points.",
                icon = "hammer",
                onSelect = function()
                    TriggerEvent("moc_restaurant:openBuilder")
                end
            },
            {
                title = "Business Management",
                description = "Open a restaurant's employee/business management without needing a Manager Station.",
                icon = "briefcase",
                disabled = #restaurants == 0,
                onSelect = function()
                    lib.registerContext({
                        id = "moc_restaurant_business_select",
                        title = "Select Restaurant",
                        menu = "moc_restaurant_admin_main",
                        options = getRestaurantOptions(restaurants, function(restaurant)
                            TriggerEvent(
                                "moc_restaurant:openBusinessManagementDirect",
                                restaurant.id,
                                restaurant.name
                            )
                        end)
                    })

                    lib.showContext("moc_restaurant_business_select")
                end
            },
            {
                title = "Assign Restaurant Owner",
                description = "Admin: assign owner by Citizen ID.",
                icon = "crown",
                disabled = #restaurants == 0,
                onSelect = function()
                    lib.registerContext({
                        id = "moc_restaurant_owner_select",
                        title = "Select Restaurant",
                        menu = "moc_restaurant_admin_main",
                        options = getRestaurantOptions(restaurants, function(restaurant)
                            local input = lib.inputDialog("Assign Restaurant Owner", {
                                { type = "input", label = "Owner Citizen ID", required = true }
                            })
                            if input then
                                TriggerServerEvent("moc_restaurant:setRestaurantOwner", restaurant.id, input[1])
                            end
                        end)
                    })
                    lib.showContext("moc_restaurant_owner_select")
                end
            },
            {
                title = "Seed Starter Menu",
                description = "Copy the restaurant type's starter menu into SQL.",
                icon = "book-open",
                disabled = #restaurants == 0,
                onSelect = function()
                    lib.registerContext({
                        id = "moc_restaurant_seed_select",
                        title = "Select Restaurant",
                        menu = "moc_restaurant_admin_main",
                        options = getRestaurantOptions(restaurants, function(restaurant)
                            TriggerServerEvent("moc_restaurant:seedMenu", restaurant.id)
                        end)
                    })
                    lib.showContext("moc_restaurant_seed_select")
                end
            }
        }
    })

    lib.showContext("moc_restaurant_admin_main")
end, false)


RegisterCommand("moclocationtypes", function()
    print("^3[MOC Restaurant]^7 Builder location types:")

    for _, locationType in ipairs(Config.LocationTypes or {}) do
        print(("[MOC Restaurant] %s = %s"):format(
            tostring(locationType.value),
            tostring(locationType.label)
        ))
    end
end, false)


RegisterCommand("moclocationtypescheck", function()
    print("^3[MOC Restaurant]^7 ===== Final LocationTypes Check =====")

    local seen = {}

    for _, locationType in ipairs(Config.LocationTypes or {}) do
        print(("[MOC Restaurant] %s = %s"):format(
            tostring(locationType.value),
            tostring(locationType.label)
        ))

        if seen[locationType.value] then
            print(("^1[MOC Restaurant]^7 DUPLICATE location type: %s"):format(
                tostring(locationType.value)
            ))
        end

        seen[locationType.value] = true
    end

    print(("[MOC Restaurant] Delivery Receiving present: %s"):format(
        tostring(seen["delivery_receiving"] == true)
    ))

    print(("[MOC Restaurant] Ingredient Supplier present: %s"):format(
        tostring(seen["ingredient_supplier"] == true)
    ))

    print("^3[MOC Restaurant]^7 ===================================")
end, false)


RegisterCommand("mocrecipecheck", function()
    local locations = lib.callback.await(
        "moc_restaurant:getInteractiveLocations",
        false
    ) or {}

    local coords = GetEntityCoords(PlayerPedId())
    local nearest, nearestDistance

    for _, loc in ipairs(locations) do
        if loc.location_type == "grill"
            or loc.location_type == "fryer"
            or loc.location_type == "prep"
            or loc.location_type == "drinks"
        then
            local distance = #(coords - vector3(
                tonumber(loc.x) or 0.0,
                tonumber(loc.y) or 0.0,
                tonumber(loc.z) or 0.0
            ))

            if not nearestDistance or distance < nearestDistance then
                nearest = loc
                nearestDistance = distance
            end
        end
    end

    if not nearest then
        print("^1[MOC Restaurant]^7 No kitchen station was returned by the server.")
        return
    end

    local stationType = nearest.location_type == "drinks"
        and "drink"
        or nearest.location_type

    local data = lib.callback.await(
        "moc_restaurant:getProductionRecipes",
        false,
        nearest.restaurant_id,
        stationType
    ) or {recipes = {}}

    print("^3[MOC Restaurant]^7 ===== Recipe Check =====")
    print(("[MOC Restaurant] Restaurant ID: %s"):format(tostring(nearest.restaurant_id)))
    print(("[MOC Restaurant] Station: %s"):format(tostring(stationType)))
    print(("[MOC Restaurant] Distance: %.2f"):format(tonumber(nearestDistance) or 0.0))
    print(("[MOC Restaurant] Recipes returned: %s"):format(tostring(#(data.recipes or {}))))

    for _, recipe in ipairs(data.recipes or {}) do
        print(("[MOC Restaurant] Recipe: %s | output=%s | station=%s"):format(
            tostring(recipe.label),
            tostring(recipe.output_item),
            tostring(recipe.station_type)
        ))
    end

    print("^3[MOC Restaurant]^7 ========================")
end, false)


RegisterCommand("mocposmenucheck", function(_, args)
    local restaurantId = tonumber(args[1])

    if not restaurantId then
        print("^1[MOC Restaurant]^7 Usage: mocposmenucheck <restaurantId>")
        return
    end

    local menu = lib.callback.await(
        "moc_restaurant:getPOSMenu",
        false,
        restaurantId
    ) or {}

    print(("^3[MOC Restaurant]^7 POS Menu Check for restaurant %s: %s item(s)"):format(
        tostring(restaurantId),
        tostring(#menu)
    ))

    for _, item in ipairs(menu) do
        print(("[MOC Restaurant] id=%s item=%s label=%s price=%s category=%s"):format(
            tostring(item.id),
            tostring(item.item),
            tostring(item.label),
            tostring(item.price),
            tostring(item.category)
        ))
    end
end, false)


RegisterCommand("mocpossourcecheck", function(_, args)
    local restaurantId = tonumber(args[1])

    if not restaurantId then
        print("^1[MOC Restaurant]^7 Usage: mocpossourcecheck <restaurantId>")
        return
    end

    local live = lib.callback.await(
        "moc_restaurant:getPOSMenu",
        false,
        restaurantId
    ) or {}

    print("^3[MOC Restaurant]^7 ===== POS SOURCE CHECK =====")
    print(("[MOC Restaurant] Restaurant ID: %s"):format(
        tostring(restaurantId)
    ))
    print(("[MOC Restaurant] Live Menu Management rows: %s"):format(
        tostring(#live)
    ))

    for _, item in ipairs(live) do
        print(("[MOC Restaurant] id=%s item=%s label=%s price=%s category=%s"):format(
            tostring(item.id),
            tostring(item.item),
            tostring(item.label),
            tostring(item.price),
            tostring(item.category)
        ))
    end

    print("^3[MOC Restaurant]^7 POS source: moc_restaurant_menu_items ONLY")
    print("^3[MOC Restaurant]^7 ===========================")
end, false)
