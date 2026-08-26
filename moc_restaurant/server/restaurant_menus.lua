local function canEdit(src, rid)
    if HasPermission(src) then return true end
    return exports.moc_restaurant:HasRestaurantPermission(src, rid, "edit_restaurant", false)
end


local function notifyMenu(src, message, kind)
    TriggerClientEvent("ox_lib:notify", src, {
        title = "MOC Restaurant",
        description = message,
        type = kind or "inform"
    })
end

RegisterNetEvent("moc_restaurant:requestMenuManagement", function(restaurantId)
    local src = source
    local rid = tonumber(restaurantId)

    print(("[MOC Restaurant] Menu Management request: player=%s restaurant=%s"):format(
        tostring(src),
        tostring(rid)
    ))

    if not rid then
        notifyMenu(src, "Invalid restaurant selected.", "error")
        return
    end

    local ok, result = pcall(function()
        if not canEdit(src, rid) then
            return {
                data = nil,
                error = "You do not have permission to edit this restaurant's menu."
            }
        end

        local restaurant = GetRestaurant(rid)
        if not restaurant then
            return {
                data = nil,
                error = "Restaurant not found."
            }
        end

        local menu = MySQL.query.await([[
            SELECT *
            FROM moc_restaurant_menu_items
            WHERE restaurant_id = ?
            ORDER BY category, sort_order, label
        ]], {rid}) or {}

        local recipes = MySQL.query.await([[
            SELECT *
            FROM moc_restaurant_recipes
            WHERE restaurant_id = ?
            ORDER BY station_type, label
        ]], {rid}) or {}

        return {
            data = {
                restaurant = restaurant,
                menu = menu,
                recipes = recipes
            }
        }
    end)

    if not ok then
        print(("[MOC Restaurant] Menu Management ERROR for restaurant %s: %s"):format(
            tostring(rid),
            tostring(result)
        ))

        notifyMenu(
            src,
            "Menu Management failed to load. Check the server console.",
            "error"
        )
        return
    end

    if not result or not result.data then
        notifyMenu(
            src,
            result and result.error or "Menu Management data was unavailable.",
            "error"
        )
        return
    end

    local data = result.data

    print(("[MOC Restaurant] Menu Management data ready: restaurant=%s menuItems=%s recipes=%s"):format(
        tostring(rid),
        tostring(#(data.menu or {})),
        tostring(#(data.recipes or {}))
    ))

    TriggerClientEvent(
        "moc_restaurant:receiveMenuManagement",
        src,
        rid,
        data
    )
end)

lib.callback.register("moc_restaurant:getRestaurantMenu", function(src, rid)
    rid = tonumber(rid)
    if not rid then return {} end

    return MySQL.query.await([[
        SELECT id,item_name,label,category,price,enabled,sort_order
        FROM moc_restaurant_menu_items
        WHERE restaurant_id=? AND enabled=1
        ORDER BY category,sort_order,label
    ]], {rid}) or {}
end)

lib.callback.register("moc_restaurant:getMenuManagementData", function(src, rid)
    rid = tonumber(rid)
    if not rid or not canEdit(src, rid) then return nil end

    local restaurant = GetRestaurant(rid)
    if not restaurant then return nil end

    return {
        restaurant = restaurant,
        menu = MySQL.query.await(
            "SELECT * FROM moc_restaurant_menu_items WHERE restaurant_id=? ORDER BY category,sort_order,label",
            {rid}
        ) or {},
        recipes = MySQL.query.await(
            "SELECT * FROM moc_restaurant_recipes WHERE restaurant_id=? ORDER BY station_type,label",
            {rid}
        ) or {}
    }
end)

RegisterNetEvent("moc_restaurant:saveRestaurantMenuItem", function(data)
    local src = source
    if type(data) ~= "table" then return end

    local rid = tonumber(data.restaurantId)
    if not rid or not canEdit(src, rid) then return end

    MySQL.insert.await([[
        INSERT INTO moc_restaurant_menu_items
        (restaurant_id,item_name,label,category,price,enabled,sort_order)
        VALUES (?,?,?,?,?,1,0)
        ON DUPLICATE KEY UPDATE
        label=VALUES(label),category=VALUES(category),price=VALUES(price),enabled=1
    ]], {
        rid,
        tostring(data.item_name or ""):sub(1,100),
        tostring(data.label or ""):sub(1,100),
        tostring(data.category or "Food"):sub(1,50),
        math.max(0, math.floor(tonumber(data.price) or 0))
    })

    TriggerClientEvent("ox_lib:notify", src, {
        title = "MOC Restaurant",
        description = "Menu item saved and POS updated.",
        type = "success"
    })

    TriggerClientEvent(
        "moc_restaurant:posMenuChanged",
        -1,
        rid
    )

end)

RegisterNetEvent("moc_restaurant:saveRestaurantRecipe", function(data)
    local src = source
    if type(data) ~= "table" then return end

    local rid = tonumber(data.restaurantId)
    if not rid or not canEdit(src, rid) then return end

    MySQL.insert.await([[
        INSERT INTO moc_restaurant_recipes
        (restaurant_id,output_item,label,station_type,output_amount,ingredients,enabled)
        VALUES (?,?,?,?,?,?,1)
        ON DUPLICATE KEY UPDATE
        label=VALUES(label),station_type=VALUES(station_type),
        output_amount=VALUES(output_amount),ingredients=VALUES(ingredients),enabled=1
    ]], {
        rid,
        tostring(data.output_item or ""):sub(1,100),
        tostring(data.label or ""):sub(1,100),
        tostring(data.station_type or ""):sub(1,50),
        math.max(1, math.floor(tonumber(data.output_amount) or 1)),
        json.encode(type(data.ingredients) == "table" and data.ingredients or {})
    })
end)


RegisterNetEvent("moc_restaurant:deleteRestaurantRecipe", function(restaurantId, outputItem)
    local src = source
    restaurantId = tonumber(restaurantId)

    if not restaurantId
        or not canEdit(src, restaurantId)
    then
        return
    end

    MySQL.update.await(
        "DELETE FROM moc_restaurant_recipes WHERE restaurant_id=? AND output_item=?",
        {
            restaurantId,
            tostring(outputItem or "")
        }
    )
end)


RegisterNetEvent("moc_restaurant:deleteRestaurantMenuItem", function(restaurantId, itemIdentifier)
    local src = source
    local rid = tonumber(restaurantId)

    if not rid or not canEdit(src, rid) then
        notifyMenu(
            src,
            "You do not have permission to edit this restaurant's menu.",
            "error"
        )
        return
    end

    local numericId = tonumber(itemIdentifier)
    local row = nil

    if numericId then
        row = MySQL.single.await([[
            SELECT id, restaurant_id, item_name, label
            FROM moc_restaurant_menu_items
            WHERE restaurant_id = ?
              AND id = ?
            LIMIT 1
        ]], {
            rid,
            numericId
        })
    else
        row = MySQL.single.await([[
            SELECT id, restaurant_id, item_name, label
            FROM moc_restaurant_menu_items
            WHERE restaurant_id = ?
              AND item_name = ?
            LIMIT 1
        ]], {
            rid,
            tostring(itemIdentifier or "")
        })
    end

    if not row then
        print((
            "[MOC Restaurant] POS menu delete FAILED: "
            .. "restaurant=%s identifier=%s row not found."
        ):format(
            tostring(rid),
            tostring(itemIdentifier)
        ))

        notifyMenu(
            src,
            "That menu item was not found in the restaurant's live POS menu.",
            "error"
        )
        return
    end

    local affected = MySQL.update.await([[
        DELETE FROM moc_restaurant_menu_items
        WHERE restaurant_id = ?
          AND id = ?
    ]], {
        rid,
        row.id
    }) or 0

    if tonumber(affected) < 1 then
        print((
            "[MOC Restaurant] POS menu delete FAILED: "
            .. "restaurant=%s id=%s delete affected 0 rows."
        ):format(
            tostring(rid),
            tostring(row.id)
        ))

        notifyMenu(
            src,
            "Menu item could not be deleted from the live POS menu.",
            "error"
        )
        return
    end

    -- Verify the exact record is gone.
    local remaining = MySQL.single.await([[
        SELECT id
        FROM moc_restaurant_menu_items
        WHERE restaurant_id = ?
          AND id = ?
        LIMIT 1
    ]], {
        rid,
        row.id
    })

    if remaining then
        print((
            "[MOC Restaurant] POS menu delete VERIFICATION FAILED: "
            .. "restaurant=%s id=%s still exists."
        ):format(
            tostring(rid),
            tostring(row.id)
        ))

        notifyMenu(
            src,
            "The menu item delete could not be verified.",
            "error"
        )
        return
    end

    print((
        "[MOC Restaurant] POS menu item deleted: "
        .. "restaurant=%s id=%s item=%s label=%s"
    ):format(
        tostring(rid),
        tostring(row.id),
        tostring(row.item_name),
        tostring(row.label)
    ))

    notifyMenu(
        src,
        "Menu item removed and POS updated.",
        "success"
    )

    TriggerClientEvent(
        "moc_restaurant:posMenuChanged",
        -1,
        rid
    )

    TriggerClientEvent(
        "moc_restaurant:menuItemDeleted",
        src,
        rid
    )
end)
