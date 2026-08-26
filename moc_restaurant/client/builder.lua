local Builder = {
    restaurant = nil,
    locations = {},
    placing = false,
    placingType = nil
}

local function getLocationLabel(locationType)
    for _, item in ipairs(Config.LocationTypes or {}) do
        if item.value == locationType then
            return item.label
        end
    end
    return locationType
end

local function refreshLocations()
    if not Builder.restaurant then return end

    Builder.locations = lib.callback.await(
        "moc_restaurant:getLocations",
        false,
        Builder.restaurant.id
    ) or {}
end

local function cancelPlacement()
    Builder.placing = false
    Builder.placingType = nil
    lib.hideTextUI()
end

local function startPlacement(locationType)
    if not Builder.restaurant or Builder.placing then return end

    Builder.placing = true
    Builder.placingType = locationType

    lib.hideContext()

    lib.notify({
        title = "MOC Restaurant",
        description = ("Placement mode started for %s. Walk to the exact spot, face the direction you want, then press E. Press BACKSPACE to cancel."):format(
            getLocationLabel(locationType)
        ),
        type = "inform",
        duration = 7000
    })

    CreateThread(function()
        while Builder.placing do
            Wait(0)

            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            DrawMarker(
                2,
                coords.x, coords.y, coords.z + 0.25,
                0.0, 0.0, 0.0,
                0.0, 180.0, 0.0,
                0.25, 0.25, 0.25,
                255, 255, 255, 190,
                false, true, 2, false, nil, nil, false
            )

            lib.showTextUI(
                ("[E] Place %s  |  [BACKSPACE] Cancel"):format(
                    getLocationLabel(Builder.placingType)
                )
            )

            if IsControlJustReleased(0, 177) then -- BACKSPACE
                cancelPlacement()
                lib.notify({
                    title = "MOC Restaurant",
                    description = "Placement cancelled.",
                    type = "inform"
                })
                return
            end

            if IsControlJustReleased(0, 38) then -- E
                local finalCoords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)
                local placingType = Builder.placingType

                cancelPlacement()

                local placement = lib.inputDialog(
                    "Confirm " .. getLocationLabel(placingType),
                    {
                        {
                            type = "number",
                            label = "Interaction Radius",
                            description = "Smaller values prevent nearby stations from conflicting. 0.50-0.75 is recommended for counters.",
                            default = Config.DefaultStationRadius or 0.65,
                            min = Config.MinStationRadius or 0.25,
                            max = Config.MaxStationRadius or 3.0,
                            step = 0.05,
                            required = true
                        }
                    }
                )

                if placement then
                    TriggerServerEvent("moc_restaurant:addLocation", {
                        restaurantId = Builder.restaurant.id,
                        locationType = placingType,
                        coords = {
                            x = finalCoords.x,
                            y = finalCoords.y,
                            z = finalCoords.z
                        },
                        heading = heading,
                        interactionRadius = tonumber(placement[1])
                            or Config.DefaultStationRadius
                            or 0.65
                    })
                else
                    lib.notify({
                        title = "MOC Restaurant",
                        description = "Location was not saved.",
                        type = "inform"
                    })
                end
                return
            end
        end
    end)
end

local function openPlacementMenu()
    local options = {}

    for _, locationType in ipairs(Config.LocationTypes or {}) do
        local value = locationType.value
        local label = locationType.label

        options[#options + 1] = {
            title = label,
            description = "Enter placement mode for this location.",
            icon = "location-dot",
            onSelect = function()
                startPlacement(value)
            end
        }
    end

    lib.registerContext({
        id = "moc_restaurant_place_location",
        title = "Place Restaurant Location",
        menu = "moc_restaurant_builder",
        options = options
    })

    lib.showContext("moc_restaurant_place_location")
end

local function openSavedLocations()
    refreshLocations()

    local options = {}

    for _, location in ipairs(Builder.locations) do
        options[#options + 1] = {
            title = ("%s #%s"):format(
                getLocationLabel(location.location_type),
                location.id
            ),
            description = ("%.2f, %.2f, %.2f | H %.2f | Radius %.2f"):format(
                location.x,
                location.y,
                location.z,
                location.heading,
                tonumber(location.interaction_radius)
                    or Config.DefaultStationRadius
                    or 0.65
            ),
            icon = "map-pin"
        }
    end

    if #options == 0 then
        options[1] = {
            title = "No locations saved",
            description = "Use Place Location to add your first station.",
            disabled = true
        }
    end

    lib.registerContext({
        id = "moc_restaurant_saved_locations",
        title = "Saved Locations",
        menu = "moc_restaurant_builder",
        options = options
    })

    lib.showContext("moc_restaurant_saved_locations")
end

local function openDeleteMenu()
    refreshLocations()

    if #Builder.locations == 0 then
        lib.notify({
            title = "MOC Restaurant",
            description = "This restaurant has no saved locations.",
            type = "inform"
        })
        return
    end

    local options = {}

    for _, location in ipairs(Builder.locations) do
        local locationId = location.id
        local locationType = location.location_type

        options[#options + 1] = {
            title = ("%s #%s"):format(
                getLocationLabel(locationType),
                locationId
            ),
            description = ("%.2f, %.2f, %.2f"):format(
                location.x,
                location.y,
                location.z
            ),
            icon = "trash",
            onSelect = function()
                local result = lib.alertDialog({
                    header = "Delete Location",
                    content = ("Delete **%s #%s**?"):format(
                        getLocationLabel(locationType),
                        locationId
                    ),
                    centered = true,
                    cancel = true
                })

                if result == "confirm" then
                    TriggerServerEvent(
                        "moc_restaurant:deleteLocation",
                        locationId
                    )
                end
            end
        }
    end

    lib.registerContext({
        id = "moc_restaurant_delete_locations",
        title = "Delete Saved Location",
        menu = "moc_restaurant_builder",
        options = options
    })

    lib.showContext("moc_restaurant_delete_locations")
end

local function openBuilderMenu()
    if not Builder.restaurant then return end

    refreshLocations()

    lib.registerContext({
        id = "moc_restaurant_builder",
        title = ("Restaurant Builder - %s"):format(
            Builder.restaurant.name
        ),
        options = {
            {
                title = "Place Location",
                description = "Place registers, cooking stations, storage and drive-thru points.",
                icon = "location-crosshairs",
                onSelect = openPlacementMenu
            },
            {
                title = "Saved Locations",
                description = ("%s location(s) currently saved."):format(
                    #Builder.locations
                ),
                icon = "list",
                onSelect = openSavedLocations
            },
            {
                title = "Delete Location",
                description = "Delete a misplaced restaurant point.",
                icon = "trash",
                onSelect = openDeleteMenu
            },
            {
                title = "Choose Different Restaurant",
                icon = "arrow-right-arrow-left",
                onSelect = function()
                    TriggerEvent("moc_restaurant:openBuilder")
                end
            },
            {
                title = "Back to MOC Restaurant",
                icon = "arrow-left",
                onSelect = function()
                    ExecuteCommand(Config.Commands.MainMenu)
                end
            }
        }
    })

    lib.showContext("moc_restaurant_builder")
end

RegisterNetEvent("moc_restaurant:openBuilder", function()
    if Builder.placing then
        cancelPlacement()
    end

    local restaurants = lib.callback.await(
        "moc_restaurant:getRestaurants",
        false
    ) or {}

    if #restaurants == 0 then
        lib.notify({
            title = "MOC Restaurant",
            description = "Create a restaurant first with /" .. Config.Commands.Create,
            type = "error"
        })
        return
    end

    local options = {}

    for _, restaurant in ipairs(restaurants) do
        local selectedRestaurant = restaurant

        options[#options + 1] = {
            title = selectedRestaurant.name,
            description = ("Job: %s | Type: %s"):format(
                selectedRestaurant.job or "None",
                selectedRestaurant.type or "custom"
            ),
            icon = "utensils",
            onSelect = function()
                Builder.restaurant = selectedRestaurant
                openBuilderMenu()
            end
        }
    end

    lib.registerContext({
        id = "moc_restaurant_select_builder",
        title = "Select Restaurant to Configure",
        options = options
    })

    lib.showContext("moc_restaurant_select_builder")
end)

RegisterNetEvent("moc_restaurant:builderRefresh", function()
    if Builder.restaurant and not Builder.placing then
        refreshLocations()
        openBuilderMenu()
    end
end)

CreateThread(function()
    while true do
        local sleep = 1500

        if Config.Debug and Builder.restaurant and #Builder.locations > 0 then
            local playerCoords = GetEntityCoords(PlayerPedId())

            for _, location in ipairs(Builder.locations) do
                local pos = vector3(location.x, location.y, location.z)
                local distance = #(playerCoords - pos)

                if distance <= (Config.Builder.DrawDistance or 20.0) then
                    sleep = 0

                    DrawMarker(
                        2,
                        location.x,
                        location.y,
                        location.z + 0.25,
                        0.0, 0.0, 0.0,
                        0.0, 180.0, 0.0,
                        (Config.Builder.MarkerScale and Config.Builder.MarkerScale.x) or 0.25,
                        (Config.Builder.MarkerScale and Config.Builder.MarkerScale.y) or 0.25,
                        (Config.Builder.MarkerScale and Config.Builder.MarkerScale.z) or 0.25,
                        255, 255, 255, 180,
                        false, true, 2, false, nil, nil, false
                    )
                end
            end
        end

        Wait(sleep)
    end
end)
