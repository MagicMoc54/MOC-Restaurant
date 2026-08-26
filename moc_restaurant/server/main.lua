local VALID_STATUSES = {
    pending = true,
    preparing = true,
    ready = true,
    completed = true,
    cancelled = true
}

local function notify(src, description, ntype)
    TriggerClientEvent("ox_lib:notify", src, {
        title = "MOC Restaurant",
        description = description,
        type = ntype or "inform"
    })
end

local function playerCitizenId(src)
    local player = QBCore and QBCore.Functions.GetPlayer(src)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

local function playerHasRestaurantJob(src, restaurant)
    if HasPermission(src) then return true end
    local player = QBCore and QBCore.Functions.GetPlayer(src)
    if not player or not restaurant or not restaurant.job or restaurant.job == "" then
        return false
    end
    return player.PlayerData.job and player.PlayerData.job.name == restaurant.job
end

RegisterNetEvent("moc_restaurant:create", function(data)
    local src = source

    if not HasPermission(src) then
        notify(src, "You do not have permission to create restaurants.", "error")
        return
    end

    if type(data) ~= "table" or not data.name or data.name == "" or not data.type then
        notify(src, "Invalid restaurant data.", "error")
        return
    end

    data.blipSprite = math.floor(math.max(
        Config.RestaurantBlips.MinSprite or 1,
        math.min(
            Config.RestaurantBlips.MaxSprite or 1000,
            tonumber(data.blipSprite)
                or Config.RestaurantBlips.DefaultSprite
                or 52
        )
    ))

    data.blipColor = math.floor(math.max(
        Config.RestaurantBlips.MinColor or 0,
        math.min(
            Config.RestaurantBlips.MaxColor or 85,
            tonumber(data.blipColor)
                or Config.RestaurantBlips.DefaultColor
                or 2
        )
    ))

    data.blipScale = math.max(
        0.25,
        math.min(
            2.0,
            tonumber(data.blipScale)
                or Config.RestaurantBlips.DefaultScale
                or 0.75
        )
    )

    local id = CreateRestaurant(data)
    if not id then
        notify(src, "The restaurant could not be created.", "error")
        return
    end

    notify(src, ("Restaurant created successfully. ID: %s"):format(id), "success")
    TriggerClientEvent("moc_restaurant:locationsChanged", -1)
    TriggerClientEvent("moc_restaurant:refreshBlips", -1)
end)

lib.callback.register("moc_restaurant:getPublicRestaurants", function()
    return GetRestaurants()
end)


RegisterNetEvent("moc_restaurant:updateBlip", function(data)
    local src = source

    if not HasPermission(src)
        or type(data) ~= "table"
    then
        return
    end

    local restaurantId = tonumber(data.restaurantId)

    if not restaurantId then
        notify(src, "Invalid restaurant.", "error")
        return
    end

    local sprite = math.floor(math.max(
        Config.RestaurantBlips.MinSprite or 1,
        math.min(
            Config.RestaurantBlips.MaxSprite or 1000,
            tonumber(data.sprite)
                or Config.RestaurantBlips.DefaultSprite
                or 52
        )
    ))

    local color = math.floor(math.max(
        Config.RestaurantBlips.MinColor or 0,
        math.min(
            Config.RestaurantBlips.MaxColor or 85,
            tonumber(data.color)
                or Config.RestaurantBlips.DefaultColor
                or 2
        )
    ))

    local scale = math.max(
        0.25,
        math.min(
            2.0,
            tonumber(data.scale)
                or Config.RestaurantBlips.DefaultScale
                or 0.75
        )
    )

    local coords = type(data.coords) == "table"
        and data.coords
        or {}

    if data.moveToCurrent == true then
        MySQL.update.await([[
            UPDATE moc_restaurants
            SET blip_sprite = ?,
                blip_color = ?,
                blip_scale = ?,
                blip_x = ?,
                blip_y = ?,
                blip_z = ?
            WHERE id = ?
        ]], {
            sprite,
            color,
            scale,
            tonumber(coords.x),
            tonumber(coords.y),
            tonumber(coords.z),
            restaurantId
        })
    else
        MySQL.update.await([[
            UPDATE moc_restaurants
            SET blip_sprite = ?,
                blip_color = ?,
                blip_scale = ?
            WHERE id = ?
        ]], {
            sprite,
            color,
            scale,
            restaurantId
        })
    end

    notify(
        src,
        "Restaurant map blip updated.",
        "success"
    )

    TriggerClientEvent(
        "moc_restaurant:refreshBlips",
        -1
    )
end)




local function getLiveRestaurantMenu(restaurantId)
    restaurantId = tonumber(restaurantId)
    if not restaurantId then
        return {}
    end

    return MySQL.query.await([[
        SELECT
            id,
            item_name AS item,
            item_name AS name,
            label,
            category,
            price
        FROM moc_restaurant_menu_items
        WHERE restaurant_id = ?
          AND enabled = 1
        ORDER BY category, sort_order, label
    ]], {
        restaurantId
    }) or {}
end

lib.callback.register("moc_restaurant:getPOSMenu", function(_, restaurantId)
    return getLiveRestaurantMenu(restaurantId)
end)

lib.callback.register("moc_restaurant:getRestaurants", function(source)
    if not HasPermission(source) then return {} end
    return GetRestaurants()
end)

lib.callback.register("moc_restaurant:getLocations", function(source, restaurantId)
    if not HasPermission(source) then return {} end
    return GetRestaurantLocations(tonumber(restaurantId))
end)

lib.callback.register("moc_restaurant:getInteractiveLocations", function()
    return GetAllInteractiveLocations()
end)

lib.callback.register("moc_restaurant:getMenu", function(_, restaurantId)
    return getLiveRestaurantMenu(restaurantId)
end)

lib.callback.register("moc_restaurant:getOpenOrders", function(source, restaurantId)
    restaurantId = tonumber(restaurantId)
    if not restaurantId then return {} end

    local restaurant = GetRestaurant(restaurantId)
    if not playerHasRestaurantJob(source, restaurant) then return {} end

    local rows = GetOpenOrders(restaurantId)
    for _, row in ipairs(rows) do
        row.items = row.items and json.decode(row.items) or {}
    end
    return rows
end)

RegisterNetEvent("moc_restaurant:addLocation", function(data)
    local src = source
    if not HasPermission(src) then
        notify(src, "You do not have permission to edit restaurants.", "error")
        return
    end

    if type(data) ~= "table"
        or not tonumber(data.restaurantId)
        or type(data.locationType) ~= "string"
        or type(data.coords) ~= "table"
    then
        notify(src, "Invalid location data.", "error")
        return
    end

    local coords = {
        x = tonumber(data.coords.x),
        y = tonumber(data.coords.y),
        z = tonumber(data.coords.z)
    }

    if not coords.x or not coords.y or not coords.z then
        notify(src, "Invalid coordinates.", "error")
        return
    end

    local radius = tonumber(data.interactionRadius)
        or Config.DefaultStationRadius
        or 0.65

    radius = math.max(
        Config.MinStationRadius or 0.25,
        math.min(
            Config.MaxStationRadius or 3.0,
            radius
        )
    )

    local id = AddRestaurantLocation(
        tonumber(data.restaurantId),
        data.locationType,
        coords,
        tonumber(data.heading) or 0.0,
        radius
    )

    if id then
        notify(src, "Location saved.", "success")
        TriggerClientEvent("moc_restaurant:builderRefresh", src)
        TriggerClientEvent("moc_restaurant:locationsChanged", -1)
    else
        notify(src, "Unable to save the location.", "error")
    end
end)

RegisterNetEvent("moc_restaurant:deleteLocation", function(locationId)
    local src = source
    if not HasPermission(src) then
        notify(src, "You do not have permission to edit restaurants.", "error")
        return
    end

    locationId = tonumber(locationId)
    if not locationId then return end

    DeleteRestaurantLocation(locationId)
    notify(src, "Location deleted.", "success")
    TriggerClientEvent("moc_restaurant:builderRefresh", src)
    TriggerClientEvent("moc_restaurant:locationsChanged", -1)
end)

RegisterNetEvent("moc_restaurant:seedMenu", function(restaurantId)
    local src = source
    if not HasPermission(src) then
        notify(src, "You do not have permission to seed menus.", "error")
        return
    end

    restaurantId = tonumber(restaurantId)
    local restaurant = restaurantId and GetRestaurant(restaurantId)
    if not restaurant then
        notify(src, "Restaurant not found.", "error")
        return
    end

    if CountRestaurantMenu(restaurantId) > 0 then
        notify(src, "This restaurant already has menu items.", "error")
        return
    end

    local template = Config.StarterMenus[restaurant.type] or {}
    if #template == 0 then
        notify(src, "No starter menu exists for this restaurant type.", "error")
        return
    end

    for _, item in ipairs(template) do
        InsertMenuItem(restaurantId, item)
    end

    notify(src, ("Added %s starter menu items."):format(#template), "success")
end)


local function findLiveMenuItem(menu, requested)
    if type(requested) ~= "table" then
        return nil
    end

    local requestedId = tonumber(requested.id)
    local requestedName = tostring(
        requested.item
        or requested.name
        or requested.item_name
        or ""
    )

    for _, menuItem in ipairs(menu or {}) do
        if requestedId
            and tonumber(menuItem.id) == requestedId
        then
            return menuItem
        end

        if requestedName ~= ""
            and (
                tostring(menuItem.item or "") == requestedName
                or tostring(menuItem.name or "") == requestedName
            )
        then
            return menuItem
        end
    end

    return nil
end

RegisterNetEvent("moc_restaurant:createOrder", function(data)
    local src = source
    if type(data) ~= "table" or not tonumber(data.restaurantId) or type(data.items) ~= "table" then
        notify(src, "Invalid order.", "error")
        return
    end

    local restaurantId = tonumber(data.restaurantId)
    local restaurant = GetRestaurant(restaurantId)
    if not restaurant then
        notify(src, "Restaurant not found.", "error")
        return
    end

    local paymentType = data.paymentType == "bank" and "bank" or "cash"
    if paymentType == "cash" and not Config.Ordering.AllowCash then paymentType = "bank" end
    if paymentType == "bank" and not Config.Ordering.AllowBank then paymentType = "cash" end

    local menuRows = getLiveRestaurantMenu(restaurantId)
    local menuById = {}
    for _, row in ipairs(menuRows) do
        menuById[tonumber(row.id)] = row
    end

    local normalized = {}
    local subtotal = 0

    for _, requested in ipairs(data.items) do
        local menuId = tonumber(requested.menuId)
        local quantity = math.floor(tonumber(requested.quantity) or 0)
        local menuItem = menuById[menuId]

        if menuItem and quantity > 0 then
            quantity = math.min(quantity, Config.Ordering.MaxQuantityPerItem or 20)
            local lineTotal = tonumber(menuItem.price) * quantity
            subtotal = subtotal + lineTotal
            normalized[#normalized + 1] = {
                menuId = menuId,
                item = menuItem.item,
                label = menuItem.label,
                price = tonumber(menuItem.price),
                quantity = quantity,
                total = lineTotal
            }
        end
    end

    if #normalized == 0 or subtotal <= 0 then
        notify(src, "Your order is empty.", "error")
        return
    end

    local tax = math.floor((subtotal * (Config.Ordering.TaxPercent or 0)) / 100)
    local total = subtotal + tax

    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    if not player.Functions.RemoveMoney(paymentType, total, "moc-restaurant-order") then
        notify(src, ("Not enough %s for this order."):format(paymentType), "error")
        return
    end

    local orderId = CreateOrder({
        restaurantId = restaurantId,
        customer = playerCitizenId(src),
        employee = nil,
        status = "pending",
        orderType = data.orderType == "drive_thru" and "drive_thru" or "counter",
        paymentType = paymentType,
        subtotal = subtotal,
        tax = tax,
        total = total,
        items = normalized
    })

    if not orderId then
        player.Functions.AddMoney(paymentType, total, "moc-restaurant-order-refund")
        notify(src, "Order creation failed. Your payment was refunded.", "error")
        return
    end

    MySQL.insert.await(
        'INSERT INTO moc_sales (restaurant_id, order_id, gross) VALUES (?, ?, ?)',
        { restaurantId, orderId, total }
    )

    notify(src, ("Order #%s placed for $%s."):format(orderId, total), "success")
    TriggerClientEvent("moc_restaurant:ordersChanged", -1, restaurantId)
end)

RegisterNetEvent("moc_restaurant:updateOrderStatus", function(orderId, restaurantId, status)
    local src = source
    orderId = tonumber(orderId)
    restaurantId = tonumber(restaurantId)

    if not orderId or not restaurantId or not VALID_STATUSES[status] then
        return
    end

    local restaurant = GetRestaurant(restaurantId)
    if not playerHasRestaurantJob(src, restaurant) then
        notify(src, "You are not authorized to manage these orders.", "error")
        return
    end

    UpdateOrderStatus(orderId, restaurantId, status)
    TriggerClientEvent("moc_restaurant:ordersChanged", -1, restaurantId)
end)
