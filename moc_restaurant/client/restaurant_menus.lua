local function ingredientTable(raw)
    local result = {}

    for pair in tostring(raw or ""):gmatch("[^,]+") do
        local item, qty = pair:match("^%s*([^:]+)%s*:%s*(%d+)%s*$")
        if item and qty then
            result[item] = tonumber(qty)
        end
    end

    return result
end

local function renderMenuManagement(rid, data)
    if type(data) ~= "table"
        or type(data.restaurant) ~= "table"
    then
        lib.notify({
            title = "MOC Restaurant",
            description = "Invalid Menu Management data received.",
            type = "error"
        })
        return
    end

    print(("[MOC Restaurant] Rendering Menu Management for restaurant %s."):format(
        tostring(rid)
    ))

    local options = {
        {
            title = "Add / Update Food or Drink",
            description = "Add an item to this restaurant's customer menu.",
            icon = "utensils",
            onSelect = function()
                local input = lib.inputDialog(
                    "Restaurant Menu Item",
                    {
                        {
                            type = "input",
                            label = "QBCore Item Name",
                            required = true
                        },
                        {
                            type = "input",
                            label = "Display Label",
                            required = true
                        },
                        {
                            type = "select",
                            label = "Category",
                            options = {
                                {label = "Food", value = "Food"},
                                {label = "Drinks", value = "Drinks"},
                                {label = "Sides", value = "Sides"},
                                {label = "Desserts", value = "Desserts"}
                            },
                            required = true
                        },
                        {
                            type = "number",
                            label = "Price",
                            min = 0,
                            default = 5,
                            required = true
                        }
                    }
                )

                if input then
                    TriggerServerEvent(
                        "moc_restaurant:saveRestaurantMenuItem",
                        {
                            restaurantId = rid,
                            item_name = input[1],
                            label = input[2],
                            category = input[3],
                            price = input[4]
                        }
                    )
                end
            end
        },
        {
            title = "Add / Update Recipe",
            description = "Create a restaurant-specific Grill/Fryer/Prep/Drink recipe.",
            icon = "book-open",
            onSelect = function()
                local input = lib.inputDialog(
                    "Restaurant Recipe",
                    {
                        {
                            type = "input",
                            label = "Output Item",
                            required = true
                        },
                        {
                            type = "input",
                            label = "Recipe Label",
                            required = true
                        },
                        {
                            type = "select",
                            label = "Station",
                            options = {
                                {label = "Grill", value = "grill"},
                                {label = "Fryer", value = "fryer"},
                                {label = "Prep", value = "prep"},
                                {label = "Drink Station", value = "drink"}
                            },
                            required = true
                        },
                        {
                            type = "number",
                            label = "Output Amount",
                            default = 1,
                            min = 1,
                            required = true
                        },
                        {
                            type = "input",
                            label = "Ingredients (item:qty, item:qty)",
                            placeholder = "burger_bun:1, burger_patty:1",
                            required = true
                        }
                    }
                )

                if input then
                    TriggerServerEvent(
                        "moc_restaurant:saveRestaurantRecipe",
                        {
                            restaurantId = rid,
                            output_item = input[1],
                            label = input[2],
                            station_type = input[3],
                            output_amount = input[4],
                            ingredients = ingredientTable(input[5])
                        }
                    )
                end
            end
        }
    }

    if #(data.menu or {}) > 0 then
        options[#options + 1] = {
            title = "Existing Menu Items",
            description = "Select a food or drink below to remove it from this restaurant and its POS.",
            disabled = true
        }

        for _, sourceItem in ipairs(data.menu or {}) do
            local menuItem = sourceItem

            options[#options + 1] = {
                title = ("%s - $%s"):format(
                    menuItem.label or menuItem.item_name or "Menu Item",
                    tostring(menuItem.price or 0)
                ),
                description = ("%s | %s"):format(
                    menuItem.category or "Menu",
                    menuItem.item_name or "unknown_item"
                ),
                icon = "receipt",
                onSelect = function()
                    local result = lib.alertDialog({
                        header = "Remove Menu Item",
                        content = (
                            "Remove **%s** from this restaurant?\n\n"
                            .. "This will also remove it from the POS."
                        ):format(
                            menuItem.label
                                or menuItem.item_name
                                or "this item"
                        ),
                        centered = true,
                        cancel = true
                    })

                    if result == "confirm" then
                        print((
                            "[MOC Restaurant] Requesting menu item delete. "
                            .. "restaurant=%s id=%s item=%s"
                        ):format(
                            tostring(rid),
                            tostring(menuItem.id),
                            tostring(menuItem.item_name)
                        ))

                        TriggerServerEvent(
                            "moc_restaurant:deleteRestaurantMenuItem",
                            rid,
                            menuItem.id
                                or menuItem.item_name
                        )
                    end
                end
            }
        end
    end

    if #(data.recipes or {}) > 0 then
        options[#options + 1] = {
            title = "Existing Recipes",
            description = "Select a recipe below to remove it.",
            disabled = true
        }

        for _, sourceRecipe in ipairs(data.recipes or {}) do
            local recipe = sourceRecipe

            options[#options + 1] = {
                title = recipe.label,
                description = ("%s -> %s"):format(
                    recipe.station_type,
                    recipe.output_item
                ),
                icon = "book",
                onSelect = function()
                    local result = lib.alertDialog({
                        header = "Remove Recipe",
                        content = ("Remove **%s** from this restaurant?"):format(
                            recipe.label
                        ),
                        centered = true,
                        cancel = true
                    })

                    if result == "confirm" then
                        TriggerServerEvent(
                            "moc_restaurant:deleteRestaurantRecipe",
                            rid,
                            recipe.output_item
                        )
                    end
                end
            }
        end
    end

    lib.registerContext({
        id = "moc_restaurant_menu_management",
        title = (data.restaurant.name or "Restaurant") .. " Menu Management",
        menu = "moc_business_main",
        options = options
    })

    lib.showContext("moc_restaurant_menu_management")
end

RegisterNetEvent("moc_restaurant:openRestaurantMenuManagement", function(rid)
    rid = tonumber(rid)

    if not rid then
        lib.notify({
            title = "MOC Restaurant",
            description = "Invalid restaurant selected.",
            type = "error"
        })
        return
    end

    lib.notify({
        title = "MOC Restaurant",
        description = "Opening Menu Management...",
        type = "inform",
        duration = 1500
    })

    TriggerServerEvent(
        "moc_restaurant:requestMenuManagement",
        rid
    )
end)

RegisterNetEvent("moc_restaurant:receiveMenuManagement", function(rid, data)
    renderMenuManagement(
        tonumber(rid),
        data
    )
end)


RegisterNetEvent("moc_restaurant:menuItemDeleted", function(restaurantId)
    restaurantId = tonumber(restaurantId)
    if not restaurantId then return end

    print(("[MOC Restaurant] Menu item deletion confirmed for restaurant %s."):format(
        tostring(restaurantId)
    ))

    Wait(200)

    TriggerServerEvent(
        "moc_restaurant:requestMenuManagement",
        restaurantId
    )
end)
