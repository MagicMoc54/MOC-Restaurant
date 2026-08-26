local InteractiveLocations = {}
local OrderRestaurant = nil

local function refreshInteractiveLocations()
    InteractiveLocations = lib.callback.await("moc_restaurant:getInteractiveLocations", false) or {}
end

local function buildCart(menu)
    local fields = {}
    for _, item in ipairs(menu) do
        fields[#fields + 1] = {
            type = "number",
            label = ("%s - $%s"):format(item.label, item.price),
            description = item.category,
            default = 0,
            min = 0,
            max = Config.Ordering.MaxQuantityPerItem or 20
        }
    end

    fields[#fields + 1] = {
        type = "select",
        label = "Payment Type",
        required = true,
        default = Config.Ordering.DefaultPayment,
        options = {
            { label = "Cash", value = "cash" },
            { label = "Bank", value = "bank" }
        }
    }

    local input = lib.inputDialog("Place Order", fields)
    if not input then return nil end

    local items = {}
    for index, item in ipairs(menu) do
        local qty = math.floor(tonumber(input[index]) or 0)
        if qty > 0 then
            items[#items + 1] = {
                menuId = item.id,
                quantity = qty
            }
        end
    end

    return items, input[#fields]
end

local function openCustomerMenu(restaurantId, orderType)
    local menu = lib.callback.await("moc_restaurant:getMenu", false, restaurantId) or {}

    if #menu == 0 then
        lib.notify({
            title = "MOC Restaurant",
            description = "This restaurant does not have a menu configured yet.",
            type = "error"
        })
        return
    end

    local options = {}
    local currentCategory = nil
    for _, item in ipairs(menu) do
        if item.category ~= currentCategory then
            currentCategory = item.category
            options[#options + 1] = {
                title = currentCategory,
                disabled = true,
                icon = "list"
            }
        end

        options[#options + 1] = {
            title = item.label,
            description = ("$%s | %s"):format(item.price, item.item),
            icon = "burger"
        }
    end

    options[#options + 1] = {
        title = "Build Order",
        description = "Choose quantities and payment method.",
        icon = "cart-shopping",
        onSelect = function()
            local items, paymentType = buildCart(menu)
            if not items or #items == 0 then
                lib.notify({
                    title = "MOC Restaurant",
                    description = "No items selected.",
                    type = "error"
                })
                return
            end

            TriggerServerEvent("moc_restaurant:createOrder", {
                restaurantId = restaurantId,
                items = items,
                paymentType = paymentType,
                orderType = orderType or "counter"
            })
        end
    }

    lib.registerContext({
        id = "moc_restaurant_customer_menu",
        title = "Restaurant Menu",
        options = options
    })

    lib.showContext("moc_restaurant_customer_menu")
end

local function openOrderQueue(restaurantId, restaurantName)
    OrderRestaurant = restaurantId
    local orders = lib.callback.await("moc_restaurant:getOpenOrders", false, restaurantId) or {}
    local options = {}

    for _, order in ipairs(orders) do
        local lines = {}
        for _, item in ipairs(order.items or {}) do
            lines[#lines + 1] = ("%sx %s"):format(item.quantity or 1, item.label or item.item)
        end

        local nextStatus = nil
        if order.status == "pending" then
            nextStatus = "preparing"
        elseif order.status == "preparing" then
            nextStatus = "ready"
        elseif order.status == "ready" then
            nextStatus = "completed"
        end

        options[#options + 1] = {
            title = ("Order #%s - %s"):format(order.id, string.upper(order.status)),
            description = table.concat(lines, "\n"),
            icon = "receipt",
            onSelect = function()
                if not nextStatus then return end
                TriggerServerEvent(
                    "moc_restaurant:updateOrderStatus",
                    order.id,
                    restaurantId,
                    nextStatus
                )
            end
        }
    end

    if #options == 0 then
        options[1] = {
            title = "No open orders",
            description = "New paid orders will appear here.",
            disabled = true
        }
    end

    lib.registerContext({
        id = "moc_restaurant_order_queue",
        title = ("%s Kitchen Orders"):format(restaurantName or "Restaurant"),
        options = options
    })
    lib.showContext("moc_restaurant_order_queue")
end

RegisterCommand(Config.Commands.Orders, function()
    local restaurants = lib.callback.await("moc_restaurant:getInteractiveLocations", false) or {}
    local seen = {}
    local options = {}

    for _, loc in ipairs(restaurants) do
        if not seen[loc.restaurant_id] then
            seen[loc.restaurant_id] = true
            options[#options + 1] = {
                title = loc.restaurant_name,
                description = "Open kitchen order queue",
                icon = "clipboard-list",
                onSelect = function()
                    openOrderQueue(loc.restaurant_id, loc.restaurant_name)
                end
            }
        end
    end

    if #options == 0 then
        options[1] = { title = "No restaurants found", disabled = true }
    end

    lib.registerContext({
        id = "moc_restaurant_order_select",
        title = "MOC Restaurant Orders",
        options = options
    })
    lib.showContext("moc_restaurant_order_select")
end, false)

RegisterNetEvent("moc_restaurant:locationsChanged", function()
    refreshInteractiveLocations()
end)

RegisterNetEvent("moc_restaurant:ordersChanged", function(restaurantId)
    if OrderRestaurant and tonumber(OrderRestaurant) == tonumber(restaurantId) then
        -- Do not force-open UI while player is doing something else.
        OrderRestaurant = nil
    end
end)

CreateThread(function()
    Wait(1500)
    refreshInteractiveLocations()

    local textVisible = false
    local currentPrompt = nil
    local posOpen = false

    local function hidePrompt()
        if textVisible then
            lib.hideTextUI()
            textVisible = false
            currentPrompt = nil
        end
    end

    AddEventHandler("moc_restaurant:posState", function(state)
        posOpen = state == true

        if posOpen then
            hidePrompt()
        end
    end)

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local nearestLoc = nil
        local nearestDistance = nil

        for _, loc in ipairs(InteractiveLocations) do
            if loc.location_type == "register"
                or loc.location_type == "drive_speaker"
            then
                local locationCoords = vector3(
                    loc.x,
                    loc.y,
                    loc.z
                )

                local distance = #(playerCoords - locationCoords)

                if distance <= Config.Interactions.DrawDistance then
                    sleep = 0

                    DrawMarker(
                        2,
                        loc.x, loc.y, loc.z + 0.20,
                        0.0, 0.0, 0.0,
                        0.0, 180.0, 0.0,
                        Config.Interactions.MarkerScale.x,
                        Config.Interactions.MarkerScale.y,
                        Config.Interactions.MarkerScale.z,
                        255, 255, 255, 160,
                        false, true, 2, false, nil, nil, false
                    )
                end

                local interactionRadius = tonumber(loc.interaction_radius)
                    or Config.DefaultStationRadius
                    or Config.Interactions.InteractDistance
                    or 0.65

                if distance <= interactionRadius then
                    if not nearestDistance or distance < nearestDistance then
                        nearestDistance = distance
                        nearestLoc = loc
                    end
                end
            end
        end

        if posOpen or not nearestLoc then
            hidePrompt()
        else
            local prompt = nearestLoc.location_type == "drive_speaker"
                and ("[E] Order at %s Drive-Thru"):format(
                    nearestLoc.restaurant_name
                )
                or ("[E] View %s Menu"):format(
                    nearestLoc.restaurant_name
                )

            if not textVisible or currentPrompt ~= prompt then
                hidePrompt()
                lib.showTextUI(prompt)
                textVisible = true
                currentPrompt = prompt
            end

            if IsControlJustReleased(0, Config.Interactions.Key) then
                hidePrompt()

                if nearestLoc.location_type == "register"
                    and Config.POS
                    and Config.POS.UseNUI == true
                then
                    TriggerEvent(
                        "moc_restaurant:openNuiMenu",
                        nearestLoc.restaurant_id,
                        nearestLoc.restaurant_name
                    )
                else
                    openCustomerMenu(
                        nearestLoc.restaurant_id,
                        nearestLoc.location_type == "drive_speaker"
                            and "drive_thru"
                            or "counter"
                    )
                end

                Wait(350)
            end
        end

        Wait(sleep)
    end
end)
