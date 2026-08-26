local function notify(src, message, kind)
    TriggerClientEvent("ox_lib:notify", src, {
        title = "MOC Restaurant",
        description = message,
        type = kind or "inform"
    })
end

local function normalizeIngredients(value)
    if type(value) == "table" then
        return value
    end

    if type(value) == "string" and value ~= "" then
        local ok, data = pcall(json.decode, value)
        if ok and type(data) == "table" then
            return data
        end
    end

    return {}
end

local function getRecipe(restaurantId, outputItem, stationType)
    local row = MySQL.single.await([[
        SELECT *
        FROM moc_restaurant_recipes
        WHERE restaurant_id = ?
          AND output_item = ?
          AND enabled = 1
          AND station_type = ?
        LIMIT 1
    ]], {
        restaurantId,
        outputItem,
        stationType
    })

    if row then
        row.ingredients = normalizeIngredients(row.ingredients)
    end

    return row
end

local function hasProductionPermission(src, restaurantId)
    if HasPermission(src) then
        return true
    end

    return exports.moc_restaurant:HasRestaurantPermission(
        src,
        restaurantId,
        "kitchen",
        Config.KitchenProduction.RequireClockIn == true
    )
end

local function hasIngredient(src, itemName, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return true
    end

    local system = MOCInventory.GetSystem()

    if system == "ox_inventory" then
        local count = exports.ox_inventory:Search(
            src,
            "count",
            itemName
        ) or 0

        return count >= amount
    end

    if system == "qb-inventory" then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then
            return false
        end

        local item = player.Functions.GetItemByName(itemName)
        return item and tonumber(item.amount) >= amount or false
    end

    return false
end

local function normalizeStationType(stationType)
    stationType = tostring(stationType or "")

    if stationType == "drinks" then
        return "drink"
    end

    return stationType
end


local function getIngredientCount(src, itemName)
    local system = MOCInventory.GetSystem()

    if system == "ox_inventory" then
        return exports.ox_inventory:Search(src, "count", itemName) or 0
    end

    if system == "qb-inventory" then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return 0 end
        local item = player.Functions.GetItemByName(itemName)
        return item and tonumber(item.amount) or 0
    end

    return 0
end

lib.callback.register(
    "moc_restaurant:getProductionRecipes",
    function(source, restaurantId, stationType)
        restaurantId = tonumber(restaurantId)
        stationType = normalizeStationType(stationType)

        if not restaurantId or stationType == "" then
            return {
                recipes = {},
                canCraft = false
            }
        end

        local rows = MySQL.query.await([[
            SELECT *
            FROM moc_restaurant_recipes
            WHERE restaurant_id = ?
              AND enabled = 1
              AND (
                    station_type = ?
                    OR (? = 'drink' AND station_type = 'drinks')
              )
            ORDER BY label
        ]], {
            restaurantId,
            stationType,
            stationType
        }) or {}

        for _, row in ipairs(rows) do
            row.ingredients = normalizeIngredients(row.ingredients)
            row.ingredient_status = {}

            for itemName, amount in pairs(row.ingredients or {}) do
                local needed = tonumber(amount) or 0
                local current = getIngredientCount(source, itemName)

                row.ingredient_status[itemName] = {
                    needed = needed,
                    current = current,
                    enough = current >= needed
                }
            end
        end

        print(("[MOC Restaurant] Kitchen recipe lookup restaurant=%s station=%s recipes=%s canCraft=%s"):format(
            tostring(restaurantId),
            tostring(stationType),
            tostring(#rows),
            tostring(hasProductionPermission(source, restaurantId))
        ))

        return {
            recipes = rows,
            canCraft = hasProductionPermission(source, restaurantId)
        }
    end
)

RegisterNetEvent(
    "moc_restaurant:craftRestaurantRecipe",
    function(data)
        local src = source

        if not Config.KitchenProduction.Enabled
            or type(data) ~= "table"
        then
            return
        end

        local restaurantId = tonumber(data.restaurantId)
        local outputItem = tostring(data.outputItem or "")
        local stationType = normalizeStationType(data.stationType)

        if not restaurantId
            or outputItem == ""
            or stationType == ""
        then
            notify(src, "Invalid recipe request.", "error")
            return
        end

        if not hasProductionPermission(src, restaurantId) then
            notify(
                src,
                "You must be clocked in and authorized to use this kitchen.",
                "error"
            )
            return
        end

        local recipe = getRecipe(
            restaurantId,
            outputItem,
            stationType
        )

        if not recipe then
            notify(
                src,
                "That recipe is not available at this restaurant/station.",
                "error"
            )
            return
        end

        local ingredients = recipe.ingredients or {}

        for itemName, amount in pairs(ingredients) do
            amount = tonumber(amount) or 0

            if amount > 0
                and not hasIngredient(src, itemName, amount)
            then
                notify(
                    src,
                    ("Missing ingredient: %sx %s"):format(
                        amount,
                        itemName
                    ),
                    "error"
                )
                return
            end
        end

        local removed = {}

        for itemName, amount in pairs(ingredients) do
            amount = tonumber(amount) or 0

            if amount > 0 then
                local success = MOCInventory.RemoveItem(
                    src,
                    itemName,
                    amount,
                    nil
                )

                if not success then
                    for _, rollback in ipairs(removed) do
                        MOCInventory.AddItem(
                            src,
                            rollback.item,
                            rollback.amount,
                            nil
                        )
                    end

                    notify(
                        src,
                        "Ingredient removal failed. Items were restored.",
                        "error"
                    )
                    return
                end

                removed[#removed + 1] = {
                    item = itemName,
                    amount = amount
                }
            end
        end

        local outputAmount = math.max(
            1,
            math.floor(
                tonumber(recipe.output_amount) or 1
            )
        )

        if not MOCInventory.AddItem(
            src,
            recipe.output_item,
            outputAmount,
            {
                restaurant = restaurantId,
                crafted = true
            }
        ) then
            for _, rollback in ipairs(removed) do
                MOCInventory.AddItem(
                    src,
                    rollback.item,
                    rollback.amount,
                    nil
                )
            end

            notify(
                src,
                "Your inventory cannot hold the finished item. Ingredients restored.",
                "error"
            )
            return
        end

        notify(
            src,
            ("Made %sx %s."):format(
                outputAmount,
                recipe.label
            ),
            "success"
        )
    end
)

print("^2[MOC Restaurant]^7 v3.2.1 Kitchen Production server loaded.")
