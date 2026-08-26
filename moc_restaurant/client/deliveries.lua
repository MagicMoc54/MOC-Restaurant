local receivingPromptVisible = false
local receivingMenuOpen = false

local function hideReceivingPrompt()
    if receivingPromptVisible then
        lib.hideTextUI()
        receivingPromptVisible = false
    end
end

local function lineSummary(items)
    local lines = {}

    for _, item in ipairs(items or {}) do
        lines[#lines + 1] = ("%sx %s"):format(
            item.quantity or 0,
            item.label or item.item or "Item"
        )
    end

    return table.concat(lines, "\n")
end

local function openReadyDeliveries(loc)
    receivingMenuOpen = true
    hideReceivingPrompt()

    local deliveries = lib.callback.await(
        "moc_restaurant:getRestaurantDeliveries",
        false,
        loc.restaurant_id
    ) or {}

    local options = {}

    for _, row in ipairs(deliveries) do
        if row.status == "ready" then
            local delivery = row

            options[#options + 1] = {
                title = ("Delivery #%s - READY"):format(delivery.id),
                description = ("%s\nCost: $%s"):format(
                    lineSummary(delivery.items),
                    delivery.cost or 0
                ),
                icon = "truck-ramp-box",
                onSelect = function()
                    print(("[MOC Restaurant] READY delivery #%s selected."):format(
                        tostring(delivery.id)
                    ))

                    lib.notify({
                        title = "MOC Restaurant",
                        description = ("Preparing delivery #%s..."):format(
                            delivery.id
                        ),
                        type = "inform",
                        duration = 2000
                    })

                    receivingMenuOpen = false
                    hideReceivingPrompt()

                    TriggerServerEvent(
                        "moc_restaurant:requestReceiveDelivery",
                        delivery.id
                    )
                end
            }
        end
    end

    if #options == 0 then
        options[1] = {
            title = "No deliveries are ready",
            description = "Ordered shipments will appear here when their delivery timer finishes.",
            disabled = true
        }
    end

    lib.registerContext({
        id = "moc_delivery_receiving",
        title = ("%s - Delivery Receiving"):format(
            loc.restaurant_name or "Restaurant"
        ),
        options = options,
        onExit = function()
            receivingMenuOpen = false
            hideReceivingPrompt()
        end
    })

    lib.showContext("moc_delivery_receiving")
end


RegisterNetEvent("moc_restaurant:deliveryReceiveConfirmed", function(deliveryId, message)
    receivingMenuOpen = false
    hideReceivingPrompt()

    print(("[MOC Restaurant] Delivery #%s receive confirmed."):format(
        tostring(deliveryId)
    ))

    lib.notify({
        title = "MOC Restaurant",
        description = message or ("Delivery #%s received."):format(deliveryId),
        type = "success"
    })
end)

RegisterNetEvent("moc_restaurant:deliveryReceiveFailed", function(deliveryId, message)
    receivingMenuOpen = false
    hideReceivingPrompt()

    print(("[MOC Restaurant] Delivery #%s receive failed: %s"):format(
        tostring(deliveryId),
        tostring(message)
    ))

    lib.notify({
        title = "MOC Restaurant",
        description = message or "Delivery could not be received.",
        type = "error"
    })
end)

CreateThread(function()
    Wait(3500)

    while true do
        local sleep = 1000

        if Config.Deliveries.Enabled then
            local locations = lib.callback.await(
                "moc_restaurant:getInteractiveLocations",
                false
            ) or {}

            local coords = GetEntityCoords(PlayerPedId())
            local nearest = nil
            local nearestDistance = nil

            for _, loc in ipairs(locations) do
                if loc.location_type == "delivery_receiving" then
                    local distance = #(
                        coords - vector3(loc.x, loc.y, loc.z)
                    )

                    if distance < 10.0 then
                        sleep = 0
                    end

                    local radius = tonumber(loc.interaction_radius)
                        or Config.Deliveries.DefaultInteractionRadius
                        or Config.DefaultStationRadius
                        or 0.75

                    if distance <= radius
                        and (not nearestDistance or distance < nearestDistance)
                    then
                        nearest = loc
                        nearestDistance = distance
                    end
                end
            end

            if nearest and not receivingMenuOpen then
                if not receivingPromptVisible then
                    lib.showTextUI(
                        ("[E] Receive Deliveries - %s"):format(
                            nearest.restaurant_name
                        )
                    )
                    receivingPromptVisible = true
                end

                if IsControlJustReleased(0, 38) then
                    openReadyDeliveries(nearest)
                    Wait(500)
                end
            else
                hideReceivingPrompt()
            end
        else
            hideReceivingPrompt()
        end

        Wait(sleep)
    end
end)
