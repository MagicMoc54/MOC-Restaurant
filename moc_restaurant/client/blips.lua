local restaurantBlips = {}

local function clearRestaurantBlips()
    for _, blip in pairs(restaurantBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    restaurantBlips = {}
end

local function refreshRestaurantBlips()
    if not Config.RestaurantBlips
        or not Config.RestaurantBlips.Enabled
    then
        clearRestaurantBlips()
        return
    end

    local restaurants = lib.callback.await(
        "moc_restaurant:getPublicRestaurants",
        false
    ) or {}

    clearRestaurantBlips()

    for _, restaurant in ipairs(restaurants) do
        local x = tonumber(restaurant.blip_x)
        local y = tonumber(restaurant.blip_y)
        local z = tonumber(restaurant.blip_z)

        if x and y and z then
            local blip = AddBlipForCoord(
                x,
                y,
                z
            )

            SetBlipSprite(
                blip,
                tonumber(restaurant.blip_sprite)
                    or Config.RestaurantBlips.DefaultSprite
                    or 52
            )

            SetBlipColour(
                blip,
                tonumber(restaurant.blip_color)
                    or Config.RestaurantBlips.DefaultColor
                    or 2
            )

            SetBlipScale(
                blip,
                tonumber(restaurant.blip_scale)
                    or Config.RestaurantBlips.DefaultScale
                    or 0.75
            )

            SetBlipAsShortRange(
                blip,
                Config.RestaurantBlips.ShortRange ~= false
            )

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(
                restaurant.name or "Restaurant"
            )
            EndTextCommandSetBlipName(blip)

            restaurantBlips[restaurant.id] = blip
        end
    end

    print(("[MOC Restaurant] Restaurant blips refreshed: %s"):format(
        tostring(#restaurants)
    ))
end

RegisterNetEvent(
    "moc_restaurant:refreshBlips",
    function()
        CreateThread(function()
            Wait(300)
            refreshRestaurantBlips()
        end)
    end
)

CreateThread(function()
    Wait(3500)

    print("^2[MOC Restaurant]^7 v3.3.0 Restaurant Blips loaded.")

    refreshRestaurantBlips()
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            == GetCurrentResourceName()
        then
            clearRestaurantBlips()
        end
    end
)
