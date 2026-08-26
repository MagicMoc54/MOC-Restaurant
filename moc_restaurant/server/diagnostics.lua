CreateThread(function()
    Wait(2000)

    for _, resource in ipairs({"qb-core", "oxmysql", "ox_lib"}) do
        if GetResourceState(resource) ~= "started" then
            print(("[MOC Restaurant] WARNING: required resource '%s' is not started."):format(resource))
        end
    end

    local inv = MOCInventory.GetSystem()

    if not inv then
        print("[MOC Restaurant] WARNING: no supported inventory detected.")
    else
        print(("[MOC Restaurant] Inventory bridge: %s"):format(inv))
    end

    print("^2[MOC Restaurant]^7 v3.0.0 production diagnostics loaded.")
end)
