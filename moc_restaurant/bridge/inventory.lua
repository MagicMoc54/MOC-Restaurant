MOCInventory = {}

function MOCInventory.GetSystem()
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

function MOCInventory.AddItem(src, item, amount, metadata)
    local system = MOCInventory.GetSystem()

    if system == "ox_inventory" then
        return exports.ox_inventory:AddItem(src, item, amount, metadata)
    end

    if system == "qb-inventory" then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddItem(item, amount, false, metadata)
    end

    return false
end


function MOCInventory.RemoveItem(src, item, amount, metadata)
    local system = MOCInventory.GetSystem()

    if system == "ox_inventory" then
        return exports.ox_inventory:RemoveItem(src, item, amount, metadata)
    end

    if system == "qb-inventory" then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return false end
        return player.Functions.RemoveItem(item, amount, false)
    end

    return false
end
