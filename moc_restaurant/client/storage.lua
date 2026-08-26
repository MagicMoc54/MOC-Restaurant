local storagePromptVisible = false
local storageBusy = false

local function getInventorySystem()
    if Config.Inventory ~= "auto" then
        return Config.Inventory
    end

    if GetResourceState("ox_inventory") == "started" then
        return "ox_inventory"
    end

    if GetResourceState("qb-inventory") == "started" then
        return "qb-inventory"
    end

    return nil
end

local function hideStoragePrompt()
    if storagePromptVisible then
        lib.hideTextUI()
        storagePromptVisible = false
    end
end

local function openStorage(loc)
    if storageBusy then return end
    storageBusy = true
    hideStoragePrompt()

    local system = getInventorySystem()

    local stashId = lib.callback.await(
        "moc_restaurant:getStorageId",
        false,
        loc.restaurant_id,
        loc.id
    )

    if not stashId then
        lib.notify({
            title = "MOC Restaurant",
            description = "Unable to determine this storage ID.",
            type = "error"
        })
        storageBusy = false
        return
    end

    if system == "ox_inventory" then
        local opened = exports.ox_inventory:openInventory(
            "stash",
            stashId
        )

        if opened == false then
            lib.notify({
                title = "MOC Restaurant",
                description = "The storage inventory could not be opened.",
                type = "error"
            })
        end

    elseif system == "qb-inventory" then
        -- Current qb-inventory opens stashes through its SERVER export.
        TriggerServerEvent(
            "moc_restaurant:openQBStorage",
            loc.restaurant_id,
            loc.id
        )

    else
        lib.notify({
            title = "MOC Restaurant",
            description = "No supported inventory resource was detected.",
            type = "error"
        })
    end

    Wait(700)
    storageBusy = false
end

CreateThread(function()
    Wait(3000)

    if GetResourceState("ox_inventory") == "started" then
        TriggerServerEvent("moc_restaurant:registerOxStashes")
    end

    while true do
        local sleep = 1000
        local locations = lib.callback.await(
            "moc_restaurant:getInteractiveLocations",
            false
        ) or {}

        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestStorage = nil
        local nearestDistance = nil

        for _, loc in ipairs(locations) do
            if loc.location_type == "storage"
                or loc.location_type == "freezer"
            then
                local distance = #(
                    playerCoords - vector3(loc.x, loc.y, loc.z)
                )

                if distance < 10.0 then
                    sleep = 0
                end

                local interactionRadius = tonumber(loc.interaction_radius)
                    or Config.DefaultStationRadius
                    or 0.65

                if distance < interactionRadius then
                    if not nearestDistance or distance < nearestDistance then
                        nearestDistance = distance
                        nearestStorage = loc
                    end
                end
            end
        end

        if nearestStorage and not storageBusy then
            if not storagePromptVisible then
                lib.showTextUI(
                    ("[E] Open %s"):format(
                        nearestStorage.location_type
                    )
                )
                storagePromptVisible = true
            end

            if IsControlJustReleased(0, 38) then
                openStorage(nearestStorage)
            end
        else
            hideStoragePrompt()
        end

        Wait(sleep)
    end
end)
