local productionOpen = false
local productionBusy = false

local stationTypes = {
    grill = true,
    fryer = true,
    prep = true,
    drinks = true
}

local function stationRecipeType(locationType)
    if locationType == "drinks" then
        return "drink"
    end

    return locationType
end

local function drawHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function ingredientDescription(recipe)
    local lines = {"Required Ingredients:"}
    local ingredients = recipe.ingredients or {}
    local status = recipe.ingredient_status or {}
    local keys = {}

    for itemName,_ in pairs(ingredients) do
        keys[#keys+1] = itemName
    end
    table.sort(keys)

    if #keys == 0 then
        lines[#lines+1] = "No ingredients configured."
    else
        for _,itemName in ipairs(keys) do
            local needed = tonumber(ingredients[itemName]) or 0
            local entry = status[itemName] or {}
            local current = tonumber(entry.current) or 0

            lines[#lines+1] = ("%s - %s/%s %s"):format(
                itemName,
                current,
                needed,
                entry.enough == true and "✓" or "✗"
            )
        end
    end

    lines[#lines+1] = ""
    lines[#lines+1] = ("Output: %sx %s"):format(
        tonumber(recipe.output_amount) or 1,
        recipe.label or recipe.output_item or "Item"
    )

    return table.concat(lines, "\n")
end

local function openProductionMenu(loc)
    if productionOpen or productionBusy then
        return
    end

    productionOpen = true

    local recipeStation =
        stationRecipeType(loc.location_type)

    local productionData = lib.callback.await(
        "moc_restaurant:getProductionRecipes",
        false,
        loc.restaurant_id,
        recipeStation
    ) or {
        recipes = {},
        canCraft = false
    }

    local recipes = productionData.recipes or {}
    local canCraft = productionData.canCraft == true
    local options = {}

    print(("[MOC Restaurant] Kitchen menu restaurant=%s station=%s recipes=%s canCraft=%s"):format(
        tostring(loc.restaurant_id),
        tostring(recipeStation),
        tostring(#recipes),
        tostring(canCraft)
    ))

    for _, sourceRecipe in ipairs(recipes) do
        local recipe = sourceRecipe

        options[#options + 1] = {
            title = recipe.label,
            description = ingredientDescription(recipe)
                .. (canCraft and "" or "\nClock in to prepare this item."),
            icon = "utensils",
            disabled = not canCraft,
            onSelect = function()
                productionBusy = true

                local completed = lib.progressCircle({
                    duration =
                        Config.KitchenProduction.DefaultCraftTimeMs
                        or 5000,
                    label = ("Preparing %s"):format(
                        recipe.label
                    ),
                    position = "bottom",
                    canCancel = true,
                    disable = {
                        move = true,
                        combat = true,
                        car = true
                    }
                })

                if completed then
                    TriggerServerEvent(
                        "moc_restaurant:craftRestaurantRecipe",
                        {
                            restaurantId =
                                loc.restaurant_id,
                            outputItem =
                                recipe.output_item,
                            stationType =
                                recipeStation
                        }
                    )
                end

                productionBusy = false
                productionOpen = false
            end
        }
    end

    if #options == 0 then
        options[1] = {
            title = "No recipes for this station",
            description = "Add restaurant-specific recipes in Business Management -> Menu Management.",
            disabled = true
        }
    end

    lib.registerContext({
        id = "moc_kitchen_production",
        title = ("%s - %s"):format(
            loc.restaurant_name
                or "Restaurant",
            Config.KitchenProduction.StationLabels[
                loc.location_type
            ] or "Kitchen"
        ),
        options = options,
        onExit = function()
            productionOpen = false
            productionBusy = false
        end
    })

    lib.showContext("moc_kitchen_production")
end




CreateThread(function()
    Wait(3500)

    print("^2[MOC Restaurant]^7 v3.2.4 Kitchen Production interaction loaded. Legacy kitchen prompt disabled.")

    while true do
        local sleep = 900

        if Config.KitchenProduction
            and Config.KitchenProduction.Enabled
        then
            local locations = lib.callback.await(
                "moc_restaurant:getInteractiveLocations",
                false
            ) or {}

            local coords = GetEntityCoords(PlayerPedId())
            local nearest = nil
            local nearestDistance = nil

            for _, loc in ipairs(locations) do
                if stationTypes[loc.location_type] then
                    local x = tonumber(loc.x)
                    local y = tonumber(loc.y)
                    local z = tonumber(loc.z)

                    if x and y and z then
                        local distance = #(
                            coords - vector3(x, y, z)
                        )

                        if distance < 8.0 then
                            sleep = 0
                        end

                        local radius =
                            tonumber(
                                loc.interaction_radius
                            )
                            or Config.DefaultStationRadius
                            or 0.65

                        radius = math.max(
                            radius,
                            0.70
                        )

                        if distance <= radius
                            and (
                                not nearestDistance
                                or distance
                                    < nearestDistance
                            )
                        then
                            nearest = loc
                            nearestDistance = distance
                        end
                    end
                end
            end

            if nearest
                and not productionOpen
                and not productionBusy
            then
                drawHelpText(
                    ("Press ~INPUT_CONTEXT~ to use %s"):format(
                        Config.KitchenProduction.StationLabels[
                            nearest.location_type
                        ] or "Kitchen Station"
                    )
                )

                if IsControlJustReleased(0, 38) then
                    openProductionMenu(nearest)
                    Wait(350)
                end
            end
        end

        Wait(sleep)
    end
end)
