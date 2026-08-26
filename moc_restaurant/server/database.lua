function CreateRestaurant(data)
    return MySQL.insert.await([[
        INSERT INTO moc_restaurants
        (
            name,
            job,
            type,
            owner,
            blip_sprite,
            blip_color,
            blip_scale,
            blip_x,
            blip_y,
            blip_z
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.name,
        data.job,
        data.type,
        data.owner,
        tonumber(data.blipSprite)
            or Config.RestaurantBlips.DefaultSprite
            or 52,
        tonumber(data.blipColor)
            or Config.RestaurantBlips.DefaultColor
            or 2,
        tonumber(data.blipScale)
            or Config.RestaurantBlips.DefaultScale
            or 0.75,
        data.blipCoords and tonumber(data.blipCoords.x) or nil,
        data.blipCoords and tonumber(data.blipCoords.y) or nil,
        data.blipCoords and tonumber(data.blipCoords.z) or nil
    })
end

function GetRestaurants()
    return MySQL.query.await('SELECT * FROM moc_restaurants ORDER BY name ASC')
end

function GetRestaurant(restaurantId)
    return MySQL.single.await(
        'SELECT * FROM moc_restaurants WHERE id = ? LIMIT 1',
        { restaurantId }
    )
end

function GetRestaurantLocations(restaurantId)
    return MySQL.query.await(
        'SELECT * FROM moc_locations WHERE restaurant_id = ? ORDER BY id ASC',
        { restaurantId }
    )
end

function GetAllInteractiveLocations()
    return MySQL.query.await([[
        SELECT l.*, r.name AS restaurant_name, r.job AS restaurant_job, r.type AS restaurant_type
        FROM moc_locations l
        INNER JOIN moc_restaurants r ON r.id = l.restaurant_id
        ORDER BY l.id ASC
    ]])
end

function AddRestaurantLocation(restaurantId, locationType, coords, heading, interactionRadius)
    return MySQL.insert.await(
        'INSERT INTO moc_locations (restaurant_id, location_type, x, y, z, heading, interaction_radius) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            restaurantId,
            locationType,
            coords.x,
            coords.y,
            coords.z,
            heading or 0.0,
            interactionRadius or Config.DefaultStationRadius or 0.65
        }
    )
end

function DeleteRestaurantLocation(locationId)
    return MySQL.update.await(
        'DELETE FROM moc_locations WHERE id = ?',
        { locationId }
    )
end

function GetRestaurantMenu(restaurantId)
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

function CountRestaurantMenu(restaurantId)
    local row = MySQL.single.await(
        'SELECT COUNT(*) AS total FROM moc_menu WHERE restaurant_id = ?',
        { restaurantId }
    )
    return row and tonumber(row.total) or 0
end

function InsertMenuItem(restaurantId, item)
    return MySQL.insert.await(
        'INSERT INTO moc_menu (restaurant_id, item, label, price, category, enabled) VALUES (?, ?, ?, ?, ?, 1)',
        { restaurantId, item.item, item.label, item.price, item.category or 'Menu' }
    )
end

function CreateOrder(data)
    return MySQL.insert.await([[
        INSERT INTO moc_orders
        (restaurant_id, customer, employee, status, order_type, payment_type, subtotal, tax, total, items)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.restaurantId,
        data.customer,
        data.employee,
        data.status or 'pending',
        data.orderType or 'counter',
        data.paymentType,
        data.subtotal,
        data.tax,
        data.total,
        json.encode(data.items)
    })
end

function GetOpenOrders(restaurantId)
    return MySQL.query.await([[
        SELECT *
        FROM moc_orders
        WHERE restaurant_id = ?
          AND status IN ('pending', 'preparing', 'ready')
        ORDER BY created ASC
    ]], { restaurantId })
end

function UpdateOrderStatus(orderId, restaurantId, status)
    return MySQL.update.await(
        'UPDATE moc_orders SET status = ? WHERE id = ? AND restaurant_id = ?',
        { status, orderId, restaurantId }
    )
end
