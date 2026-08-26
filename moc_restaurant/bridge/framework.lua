QBCore = QBCore or nil

CreateThread(function()
    if Config.Framework == "qb" then
        QBCore = exports['qb-core']:GetCoreObject()
    end
end)
