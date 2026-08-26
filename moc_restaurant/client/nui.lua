local function getRestaurantPOSMenu(restaurantId)
    return lib.callback.await(
        "moc_restaurant:getPOSMenu",
        false,
        restaurantId
    ) or {}
end

local posOpen = false

CreateThread(function()
    Wait(1000)

    print("^2[MOC Restaurant]^7 v1.5.3 NUI client loaded.")

    lib.notify({
        title = "MOC Restaurant",
        description = "v1.5.3 POS client loaded.",
        type = "success",
        duration = 4000
    })
end)

local function log(message)
    print(("^3[MOC Restaurant POS]^7 %s"):format(message))
end

local function setPosState(state)
    posOpen = state == true

    log(("Set POS state: %s"):format(tostring(posOpen)))

    SetNuiFocus(posOpen, posOpen)
    TriggerEvent("moc_restaurant:posState", posOpen)

    if not posOpen then
        SendNUIMessage({
            action = "close"
        })
    end
end

local function sendPosOpen(restaurantId, restaurantName, menu)
    log(("Sending NUI open message. Restaurant ID: %s, menu items: %s"):format(
        tostring(restaurantId),
        tostring(#menu)
    ))

    setPosState(true)

    Wait(100)

    SendNUIMessage({
        action = "open",
        restaurantId = restaurantId,
        restaurantName = restaurantName or "MOC Restaurant",
        menu = menu
    })

    lib.notify({
        title = "MOC Restaurant",
        description = ("POS open message sent with %s menu item(s)."):format(#menu),
        type = "inform",
        duration = 3500
    })
end

RegisterNUICallback("ready", function(_, cb)
    log("NUI JavaScript reported READY.")
    cb({
        ok = true
    })
end)

RegisterNUICallback("close", function(_, cb)
    log("NUI close callback received.")
    setPosState(false)

    cb({
        ok = true
    })
end)

RegisterNUICallback("pay", function(data, cb)
    log("NUI pay callback received.")

    if type(data) ~= "table"
        or not tonumber(data.restaurantId)
        or type(data.items) ~= "table"
    then
        log("Rejected invalid NUI order.")

        cb({
            ok = false,
            error = "invalid_order"
        })

        return
    end

    local paymentType = data.paymentType == "bank"
        and "bank"
        or "cash"

    TriggerServerEvent("moc_restaurant:createOrder", {
        restaurantId = tonumber(data.restaurantId),
        items = data.items,
        paymentType = paymentType,
        orderType = "counter"
    })

    setPosState(false)

    cb({
        ok = true
    })
end)

RegisterNetEvent("moc_restaurant:openNuiMenu", function(restaurantId, restaurantName)
    log(("openNuiMenu event fired. ID=%s, name=%s"):format(
        tostring(restaurantId),
        tostring(restaurantName)
    ))

    restaurantId = tonumber(restaurantId)

    if not restaurantId then
        log("Invalid restaurant ID.")
        return
    end

    local menu = lib.callback.await(
        "moc_restaurant:getPOSMenu",
        false,
        restaurantId
    ) or {}

    log(("Live POS menu callback returned %s item(s)."):format(#menu))

    if #menu == 0 then
        lib.notify({
            title = "MOC Restaurant",
            description = "This restaurant has no live Menu Management items configured.",
            type = "error"
        })

        return
    end

    sendPosOpen(
        restaurantId,
        restaurantName,
        menu
    )
end)

-- Pure NUI test. Does NOT use SQL or restaurant locations.
RegisterCommand("mocuitest", function()
    log("/mocuitest executed.")

    sendPosOpen(
        999999,
        "MOC POS UI TEST",
        {
            {
                id = 1,
                label = "Test Burger",
                price = 10,
                category = "Food",
                item = "test_burger"
            },
            {
                id = 2,
                label = "Test Fries",
                price = 5,
                category = "Sides",
                item = "test_fries"
            },
            {
                id = 3,
                label = "Test Cola",
                price = 3,
                category = "Drinks",
                item = "test_cola"
            }
        }
    )
end, false)

local function openFirstSavedRegister()
    log("Saved-register POS test started.")

    local locations = lib.callback.await(
        "moc_restaurant:getInteractiveLocations",
        false
    ) or {}

    log(("Interactive location callback returned %s location(s)."):format(#locations))

    for _, loc in ipairs(locations) do
        if loc.location_type == "register" then
            log(("Found register ID %s for restaurant %s."):format(
                tostring(loc.id),
                tostring(loc.restaurant_name)
            ))

            TriggerEvent(
                "moc_restaurant:openNuiMenu",
                loc.restaurant_id,
                loc.restaurant_name
            )

            return
        end
    end

    lib.notify({
        title = "MOC Restaurant",
        description = "No saved register location was found.",
        type = "error"
    })

    log("No register location found.")
end

RegisterCommand("mocpostest", openFirstSavedRegister, false)

-- Alias for the typo used during testing.
RegisterCommand("mocpoctest", openFirstSavedRegister, false)

RegisterCommand("mocposclose", function()
    log("/mocposclose executed.")
    setPosState(false)
end, false)

CreateThread(function()
    while true do
        if posOpen then
            Wait(0)

            if IsControlJustReleased(0, 200)
                or IsControlJustReleased(0, 177)
            then
                setPosState(false)
            end
        else
            Wait(500)
        end
    end
end)
