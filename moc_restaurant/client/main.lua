local function getRestaurantPOSMenu(restaurantId)
    return lib.callback.await(
        "moc_restaurant:getPOSMenu",
        false,
        restaurantId
    ) or {}
end

CreateThread(function()
    if Config.Debug then
        print('[MOC Restaurant] Client initialized')
    end
end)
