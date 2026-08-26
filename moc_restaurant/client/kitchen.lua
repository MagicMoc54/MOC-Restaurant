local legacyKitchenInteractionDisabled = true

local function openKitchenStation(loc)
    local options = {}
    for recipeName, recipe in pairs(Config.Recipes) do
        if recipe.station == loc.location_type then
            options[#options+1] = {
                title = recipe.label,
                description = ("Prepare in %.1f seconds"):format((recipe.time or 5000)/1000),
                icon = "utensils",
                onSelect = function()
                    local ok, reason = lib.callback.await("moc_restaurant:canCraft", false, loc.restaurant_id, recipeName)
                    if not ok then
                        lib.notify({title="MOC Restaurant", description=reason or "Cannot craft.", type="error"})
                        return
                    end
                    if lib.progressCircle({
                        duration = recipe.time or 5000,
                        label = "Preparing "..recipe.label,
                        position = "bottom",
                        canCancel = true,
                        disable = { move = true, combat = true }
                    }) then
                        TriggerServerEvent("moc_restaurant:finishCraft", loc.restaurant_id, recipeName)
                    end
                end
            }
        end
    end
    if #options == 0 then options[1]={title="No recipes for this station",disabled=true} end
    lib.registerContext({id="moc_kitchen_station", title=loc.restaurant_name.." Kitchen", options=options})
    lib.showContext("moc_kitchen_station")
end

CreateThread(function()
    if legacyKitchenInteractionDisabled then return end
Wait(2500)
    while true do
        local sleep=1200
        local locs=lib.callback.await("moc_restaurant:getInteractiveLocations", false) or {}
        local coords=GetEntityCoords(PlayerPedId())
        for _,loc in ipairs(locs) do
            if loc.location_type=="grill" or loc.location_type=="fryer" or loc.location_type=="prep" or loc.location_type=="drinks" then
                local pos=vector3(loc.x,loc.y,loc.z)
                local dist=#(coords-pos)
                if dist < 12.0 then
                    sleep=0
                    DrawMarker(2,loc.x,loc.y,loc.z+0.2,0,0,0,0,180.0,0,0.2,0.2,0.2,255,255,255,150,false,true,2,false,nil,nil,false)
                    local interactionRadius = tonumber(loc.interaction_radius)
                        or Config.DefaultStationRadius
                        or 0.65
                    if dist < interactionRadius then
                        lib.showTextUI(("[E] Use %s station"):format(loc.location_type))
                        if IsControlJustReleased(0,38) then
                            lib.hideTextUI()
                            openKitchenStation(loc)
                            Wait(500)
                        end
                    end
                end
            end
        end
        if sleep>0 then lib.hideTextUI() end
        Wait(sleep)
    end
end)
