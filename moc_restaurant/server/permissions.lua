function HasPermission(src)
    if not QBCore then
        return false
    end

    local player = QBCore.Functions.GetPlayer(src)

    if not player then
        return false
    end

    if QBCore.Functions.HasPermission(src, Config.AdminPermission) then
        return true
    end

    return false
end
