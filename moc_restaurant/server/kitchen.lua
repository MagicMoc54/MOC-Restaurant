local function getPlayer(src)
    return QBCore and QBCore.Functions.GetPlayer(src)
end

local function invSystem()
    return MOCInventory.GetSystem()
end

local function hasItem(src, item, amount)
    amount = amount or 1
    if invSystem() == "ox_inventory" then
        return (exports.ox_inventory:Search(src, "count", item) or 0) >= amount
    end

    local player = getPlayer(src)
    if not player then return false end
    local found = player.Functions.GetItemByName(item)
    return found and found.amount >= amount
end

local function removeItem(src, item, amount)
    if invSystem() == "ox_inventory" then
        return exports.ox_inventory:RemoveItem(src, item, amount)
    end
    local player = getPlayer(src)
    return player and player.Functions.RemoveItem(item, amount)
end

local function authorizedForRestaurant(src, restaurantId)
    if Config.BusinessManagement and Config.BusinessManagement.Enabled then
        return exports.moc_restaurant:HasRestaurantPermission(src, restaurantId, "kitchen", true)
    end

    local restaurant = GetRestaurant(restaurantId)
    local player = getPlayer(src)
    if not restaurant or not player then return false end
    if HasPermission(src) then return true end
    return restaurant.job and restaurant.job ~= "" and player.PlayerData.job.name == restaurant.job
end

lib.callback.register("moc_restaurant:canCraft", function(source, restaurantId, recipeName)
    if not Config.Kitchen.Enabled or not authorizedForRestaurant(source, tonumber(restaurantId)) then
        return false, "Not authorized."
    end

    local recipe = Config.Recipes[recipeName]
    if not recipe then return false, "Recipe not found." end

    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if not hasItem(source, ingredient.item, ingredient.amount) then
            return false, ("Missing %sx %s"):format(ingredient.amount, ingredient.item)
        end
    end
    return true
end)

RegisterNetEvent("moc_restaurant:finishCraft", function(restaurantId, recipeName)
    local src = source
    if not authorizedForRestaurant(src, tonumber(restaurantId)) then return end
    local recipe = Config.Recipes[recipeName]
    if not recipe then return end

    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if not hasItem(src, ingredient.item, ingredient.amount) then
            TriggerClientEvent("ox_lib:notify", src, {title="MOC Restaurant", description="Ingredients changed; craft cancelled.", type="error"})
            return
        end
    end

    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if not removeItem(src, ingredient.item, ingredient.amount) then return end
    end

    if not MOCInventory.AddItem(src, recipeName, 1, { restaurant = tonumber(restaurantId) }) then
        TriggerClientEvent("ox_lib:notify", src, {title="MOC Restaurant", description="Could not add crafted item.", type="error"})
        return
    end

    TriggerClientEvent("ox_lib:notify", src, {title="MOC Restaurant", description=recipe.label.." prepared.", type="success"})
end)
