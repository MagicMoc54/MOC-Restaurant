local function makeStorageId(restaurantId, locationId)
    return ("moc_restaurant_%s_%s"):format(
        restaurantId,
        locationId
    )
end

local function getStorageLocation(restaurantId, locationId)
    local locations = GetRestaurantLocations(restaurantId)

    for _, location in ipairs(locations or {}) do
        if tonumber(location.id) == tonumber(locationId)
            and (
                location.location_type == "storage"
                or location.location_type == "freezer"
            )
        then
            return location
        end
    end

    return nil
end

lib.callback.register(
    "moc_restaurant:getStorageId",
    function(source, restaurantId, locationId)
        restaurantId = tonumber(restaurantId)
        locationId = tonumber(locationId)

        if not restaurantId or not locationId then
            return nil
        end

        local restaurant = GetRestaurant(restaurantId)
        if not restaurant then
            return nil
        end

        local location = getStorageLocation(
            restaurantId,
            locationId
        )

        if not location then
            return nil
        end

        return makeStorageId(
            restaurantId,
            locationId
        )
    end
)

RegisterNetEvent(
    "moc_restaurant:openQBStorage",
    function(restaurantId, locationId)
        local src = source

        restaurantId = tonumber(restaurantId)
        locationId = tonumber(locationId)

        if not restaurantId or not locationId then
            return
        end

        if GetResourceState("qb-inventory") ~= "started" then
            TriggerClientEvent(
                "ox_lib:notify",
                src,
                {
                    title = "MOC Restaurant",
                    description = "qb-inventory is not running.",
                    type = "error"
                }
            )
            return
        end

        local restaurant = GetRestaurant(restaurantId)
        local location = getStorageLocation(
            restaurantId,
            locationId
        )

        if not restaurant or not location then
            return
        end

        local stashId = makeStorageId(
            restaurantId,
            locationId
        )

        exports["qb-inventory"]:OpenInventory(
            src,
            stashId,
            {
                label = ("%s %s"):format(
                    restaurant.name,
                    location.location_type == "freezer"
                        and "Freezer"
                        or "Storage"
                ),
                maxweight = Config.Storage.DefaultWeight,
                slots = Config.Storage.DefaultSlots
            }
        )
    end
)

RegisterNetEvent(
    "moc_restaurant:registerOxStashes",
    function()
        local src = source

        if GetResourceState("ox_inventory") ~= "started" then
            return
        end

        local locations = GetAllInteractiveLocations()

        for _, loc in ipairs(locations) do
            if loc.location_type == "storage"
                or loc.location_type == "freezer"
            then
                local stashId = makeStorageId(
                    loc.restaurant_id,
                    loc.id
                )

                -- RegisterStash can error if a stash is registered twice after
                -- some resource restart patterns, so protect the resource.
                pcall(function()
                    exports.ox_inventory:RegisterStash(
                        stashId,
                        ("%s %s"):format(
                            loc.restaurant_name,
                            loc.location_type == "freezer"
                                and "Freezer"
                                or "Storage"
                        ),
                        Config.Storage.DefaultSlots,
                        Config.Storage.DefaultWeight,
                        false
                    )
                end)
            end
        end

        TriggerClientEvent(
            "moc_restaurant:storageReady",
            src
        )
    end
)
