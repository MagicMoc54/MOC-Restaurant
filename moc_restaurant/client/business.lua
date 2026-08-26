
local prompt=false
local menuOpen=false

local permOrder={
    {"pos","Use POS/Register"},
    {"kitchen","Use Kitchen Stations"},
    {"drinks","Use Drink Stations"},
    {"storage","Access Storage/Freezer"},
    {"drive_thru","Use Drive-Thru"},
    {"manage_employees","Manage Employees"},
    {"manage_ranks","Create/Edit Ranks"},
    {"manage_payroll","View Payroll"},
    {"view_sales","View Sales"},
    {"edit_restaurant","Edit Restaurant"},
    {"manage_deliveries","Manage Deliveries & Restocking"}
}

local function hide()
    if prompt then lib.hideTextUI(); prompt=false end
end

local function pfields(existing)
    local f={}
    for _,v in ipairs(permOrder) do
        f[#f+1]={type="checkbox",label=v[2],checked=existing and existing[v[1]]==true or false}
    end
    return f
end

local function pvalues(input,start)
    local p={}
    for i,v in ipairs(permOrder) do p[v[1]]=input[start+i-1]==true end
    return p
end

local function rankOptions(ranks)
    local o={}
    for _,r in ipairs(ranks) do
        if tonumber(r.protected)~=1 then o[#o+1]={label=r.label.." ($"..(r.pay or 0)..")",value=tostring(r.grade)} end
    end
    return o
end

local function openRanks(rid)
    local ranks=lib.callback.await("moc_restaurant:getBusinessRanks",false,rid) or {}
    local o={}
    for _,rr in ipairs(ranks) do
        local r=rr
        o[#o+1]={
            title=r.label.." | Grade "..r.grade,
            description="$"..(r.pay or 0)..(tonumber(r.protected)==1 and " | Protected" or ""),
            icon=tonumber(r.isboss)==1 and "crown" or "id-badge",
            onSelect=function()
                local f={
                    {type="input",label="Rank Label",default=r.label,required=true},
                    {type="number",label="Pay Per Payroll Interval",default=tonumber(r.pay) or 0,min=0,required=true}
                }
                for _,x in ipairs(pfields(r.permissions or {})) do f[#f+1]=x end
                local input=lib.inputDialog("Edit "..r.label,f)
                if input then
                    TriggerServerEvent("moc_restaurant:updateBusinessRank",{
                        restaurantId=rid,grade=r.grade,label=input[1],pay=input[2],permissions=pvalues(input,3)
                    })
                end
            end
        }
        if tonumber(r.protected)~=1 then
            o[#o+1]={
                title="Delete "..r.label,
                icon="trash",
                onSelect=function()
                    local c=lib.alertDialog({header="Delete Rank",content="Delete **"..r.label.."**?",centered=true,cancel=true})
                    if c=="confirm" then TriggerServerEvent("moc_restaurant:deleteBusinessRank",rid,r.grade) end
                end
            }
        end
    end
    o[#o+1]={
        title="Create New Rank",icon="plus",
        onSelect=function()
            local f={
                {type="input",label="Rank Label",placeholder="Bartender",required=true},
                {type="number",label="Pay Per Payroll Interval",default=50,min=0,required=true}
            }
            for _,x in ipairs(pfields(Config.BusinessManagement.DefaultPermissions or {})) do f[#f+1]=x end
            local input=lib.inputDialog("Create Restaurant Rank",f)
            if input then TriggerServerEvent("moc_restaurant:createBusinessRank",{restaurantId=rid,label=input[1],pay=input[2],permissions=pvalues(input,3)}) end
        end
    }
    lib.registerContext({id="moc_business_ranks",title="Job Ranks",menu="moc_business_main",options=o})
    lib.showContext("moc_business_ranks")
end

local function openEmployees(rid)
    local employees=lib.callback.await("moc_restaurant:getBusinessEmployees",false,rid) or {}
    local ranks=lib.callback.await("moc_restaurant:getBusinessRanks",false,rid) or {}
    local ro=rankOptions(ranks); local o={}
    for _,ee in ipairs(employees) do
        local e=ee
        o[#o+1]={
            title=e.citizenid,
            description=(e.rank_label or e.role or "Employee").." | "..(isClockedInValue(e.clocked_in) and "CLOCKED IN" or "Off Duty").." | "..(e.minutes_worked or 0).." min",
            icon="user",
            onSelect=function()
                if tonumber(e.protected)==1 then return end
                local input=lib.inputDialog("Employee Management",{
                    {type="select",label="Rank",options=ro,default=tostring(e.grade),required=true}
                })
                if input then TriggerServerEvent("moc_restaurant:setBusinessEmployeeRank",{restaurantId=rid,citizenid=e.citizenid,grade=tonumber(input[1])}) end
            end
        }
        if tonumber(e.protected)~=1 then
            o[#o+1]={
                title="Fire "..e.citizenid,icon="user-xmark",
                onSelect=function()
                    local c=lib.alertDialog({header="Fire Employee",content="Fire **"..e.citizenid.."**?",centered=true,cancel=true})
                    if c=="confirm" then TriggerServerEvent("moc_restaurant:fireBusinessEmployee",rid,e.citizenid) end
                end
            }
        end
    end
    o[#o+1]={
        title="Hire Online Player",icon="user-plus",
        onSelect=function()
            if #ro==0 then return lib.notify({title="MOC Restaurant",description="Create a non-owner rank first.",type="error"}) end
            local input=lib.inputDialog("Hire Employee",{
                {type="number",label="Player Server ID",required=true,min=1},
                {type="select",label="Starting Rank",options=ro,required=true}
            })
            if input then TriggerServerEvent("moc_restaurant:hireBusinessEmployee",{restaurantId=rid,targetServerId=tonumber(input[1]),grade=tonumber(input[2])}) end
        end
    }
    lib.registerContext({id="moc_business_employees",title="Employees",menu="moc_business_main",options=o})
    lib.showContext("moc_business_employees")
end

local function listHistory(id,title,rows,formatter)
    local o={}
    for _,row in ipairs(rows) do o[#o+1]=formatter(row) end
    if #o==0 then o[1]={title="No records yet",disabled=true} end
    lib.registerContext({id=id,title=title,menu="moc_business_main",options=o})
    lib.showContext(id)
end


local function deliverySummary(items)
    local lines = {}

    for _, item in ipairs(items or {}) do
        lines[#lines + 1] = ("%sx %s"):format(
            item.quantity or 0,
            item.label or item.item or "Item"
        )
    end

    return table.concat(lines, "\n")
end

local function openDeliveries(rid)
    local catalogOk, catalog = pcall(function()
        return lib.callback.await(
            "moc_restaurant:getDeliveryCatalog",
            false,
            rid
        )
    end)

    if not catalogOk then
        print(("[MOC Restaurant] Delivery catalog callback failed: %s"):format(
            tostring(catalog)
        ))

        lib.notify({
            title = "MOC Restaurant",
            description = "Delivery server module is not ready. Restart moc_restaurant and check the server console.",
            type = "error"
        })

        return
    end

    catalog = catalog or {}

    local deliveriesOk, deliveries = pcall(function()
        return lib.callback.await(
            "moc_restaurant:getRestaurantDeliveries",
            false,
            rid
        )
    end)

    if not deliveriesOk then
        print(("[MOC Restaurant] Delivery history callback failed: %s"):format(
            tostring(deliveries)
        ))

        lib.notify({
            title = "MOC Restaurant",
            description = "Delivery history could not load. Check the server console.",
            type = "error"
        })

        return
    end

    deliveries = deliveries or {}

    local options = {
        {
            title = "Place Supply Order",
            description = "Order restaurant ingredients using the business account.",
            icon = "cart-flatbed",
            disabled = #catalog == 0,
            onSelect = function()
                local itemOptions = {}

                for _, item in ipairs(catalog) do
                    itemOptions[#itemOptions + 1] = {
                        label = ("%s - $%s each"):format(
                            item.label,
                            item.unitPrice
                        ),
                        value = item.item
                    }
                end

                local input = lib.inputDialog(
                    "Restaurant Supply Order",
                    {
                        {
                            type = "select",
                            label = "Ingredient",
                            options = itemOptions,
                            required = true
                        },
                        {
                            type = "number",
                            label = "Quantity",
                            default = 10,
                            min = 1,
                            max = Config.Deliveries.MaxQuantityPerItem or 250,
                            required = true
                        }
                    }
                )

                if input then
                    TriggerServerEvent(
                        "moc_restaurant:createDeliveryOrder",
                        {
                            restaurantId = rid,
                            items = {
                                {
                                    item = input[1],
                                    quantity = tonumber(input[2]) or 1
                                }
                            }
                        }
                    )
                end
            end
        }
    }

    for _, row in ipairs(deliveries) do
        options[#options + 1] = {
            title = ("Delivery #%s - %s"):format(
                row.id,
                string.upper(row.status or "unknown")
            ),
            description = ("%s\nCost: $%s\nReady: %s"):format(
                deliverySummary(row.items),
                row.cost or 0,
                row.ready_at or "Pending"
            ),
            icon = row.status == "ready"
                and "truck-ramp-box"
                or row.status == "delivered"
                    and "box-open"
                    or "truck"
        }
    end

    lib.registerContext({
        id = "moc_business_deliveries",
        title = "Deliveries & Restocking",
        menu = "moc_business_main",
        options = options
    })

    lib.showContext("moc_business_deliveries")
end


local function isClockedInValue(value)
    if value == true then
        return true
    end

    if value == false or value == nil then
        return false
    end

    return tonumber(value) == 1
end

local function openBusinessAccountSetup(loc, profile)
    local currentJob = ""

    if profile
        and profile.restaurant
        and profile.restaurant.job
    then
        currentJob = tostring(profile.restaurant.job)
    end

    local input = lib.inputDialog(
        "Business Account / Job Setup",
        {
            {
                type = "input",
                label = "Restaurant Job / qb-banking Account Name",
                description = "Use the exact job/account key, for example vanillaunicorn or mcdoodles.",
                default = currentJob,
                required = true
            }
        }
    )

    if not input then
        return
    end

    TriggerServerEvent(
        "moc_restaurant:setBusinessAccountJob",
        loc.restaurant_id,
        input[1]
    )
end


local function openAutomaticBusinessSetup(loc)
    local status = lib.callback.await(
        "moc_restaurant:getAutomaticBusinessSetupStatus",
        false,
        loc.restaurant_id
    )

    if not status then
        lib.notify({
            title = "MOC Restaurant",
            description = "Unable to read business setup status.",
            type = "error"
        })
        return
    end

    local jobText =
        status.jobExists
        and "Ready"
        or "Missing"

    local bankText =
        status.bankExists
        and ("Ready - Balance $" ..
            tostring(
                status.bankBalance or 0
            ))
        or "Missing"

    local result = lib.alertDialog({
        header = "Automatic Business Setup",
        content = (
            "**Job / Account Key:** %s\n\n" ..
            "**QBCore Job:** %s\n\n" ..
            "**qb-banking Account:** %s\n\n" ..
            "Run automatic setup now?"
        ):format(
            tostring(
                status.jobName or "Not Set"
            ),
            jobText,
            bankText
        ),
        centered = true,
        cancel = true
    })

    if result == "confirm" then
        TriggerServerEvent(
            "moc_restaurant:runAutomaticBusinessSetup",
            loc.restaurant_id
        )
    end
end

local function renderPortal(loc, p)
    menuOpen=true; hide()
    if not p then
        menuOpen=false
        lib.notify({title="MOC Restaurant",description="Business Management profile was empty.",type="error"})
        return
    end
    local o={}
    if p.employee then
        local currentlyClockedIn = isClockedInValue(
            p.employee.clocked_in
        )

        o[#o+1] = {
            title = currentlyClockedIn
                and "Clock Out"
                or "Clock In",

            description = (
                "Rank: %s | Worked: %s minutes | Status: %s"
            ):format(
                p.employee.rank_label
                    or p.employee.role
                    or "Employee",
                p.employee.minutes_worked or 0,
                currentlyClockedIn
                    and "CLOCKED IN"
                    or "OFF DUTY"
            ),

            icon = currentlyClockedIn
                and "right-from-bracket"
                or "right-to-bracket",

            onSelect = function()
                hide()

                TriggerServerEvent(
                    "moc_restaurant:setClockState",
                    loc.restaurant_id,
                    not currentlyClockedIn
                )
            end
        }
    end

    if p.canManageEmployees then o[#o+1]={title="Employees",description="Hire, fire and rank staff.",icon="users",onSelect=function() openEmployees(loc.restaurant_id) end} end
    if p.canManageRanks then o[#o+1]={title="Job Ranks",description="Create ranks, pay and permissions.",icon="layer-group",onSelect=function() openRanks(loc.restaurant_id) end} end
    if p.isOwner or p.canManageRanks then
        o[#o+1]={
            title="Business Account / Job Setup",
            description=(
                p.restaurant
                and p.restaurant.job
                and p.restaurant.job ~= ""
            )
                and ("Current account/job: "..p.restaurant.job)
                or "Set the restaurant job/account used by QBCore and qb-banking.",
            icon="building-columns",
            onSelect=function()
                openBusinessAccountSetup(loc, p)
            end
        }
    end
    if p.isOwner or p.canManageRanks then
        o[#o+1]={
            title="Automatic Business Setup",
            description="Create/check the QBCore job and qb-banking business account.",
            icon="wand-magic-sparkles",
            onSelect=function()
                openAutomaticBusinessSetup(loc)
            end
        }
    end
    if p.isOwner or p.canManageRanks then
        o[#o+1]={
            title="Menu Management",
            description="Create this restaurant's food, drinks and recipes.",
            icon="utensils",
            onSelect=function()
                TriggerEvent("moc_restaurant:openRestaurantMenuManagement",loc.restaurant_id)
            end
        }
    end
    if p.canManageDeliveries then
        o[#o+1]={
            title="Deliveries & Restocking",
            description="Order wholesale ingredients and track shipments.",
            icon="truck",
            onSelect=function()
                openDeliveries(loc.restaurant_id)
            end
        }
    end
    if p.canManagePayroll then
        o[#o+1]={title="Payroll History",icon="money-check-dollar",onSelect=function()
            local rows=lib.callback.await("moc_restaurant:getPayrollHistory",false,loc.restaurant_id) or {}
            listHistory("moc_business_payroll","Payroll History",rows,function(x)
                return {title=x.citizenid.." | $"..x.amount,description="Grade "..x.grade.." | "..x.status.." | "..(x.created or ""),icon=x.status=="paid" and "money-check-dollar" or "triangle-exclamation"}
            end)
        end}
    end
    if p.canViewSales then
        o[#o+1]={title="Sales History",icon="chart-column",onSelect=function()
            local rows=lib.callback.await("moc_restaurant:getSalesHistory",false,loc.restaurant_id) or {}
            listHistory("moc_business_sales","Sales History",rows,function(x)
                return {title="Sale #"..x.id.." | $"..x.gross,description="Order "..(x.order_id or "N/A").." | "..(x.created or ""),icon="chart-line"}
            end)
        end}
    end
    if #o==0 then o[1]={title="No business access",disabled=true} end
    lib.registerContext({id="moc_business_main",title=(loc.restaurant_name or "Restaurant").." Business Management",options=o,onExit=function() menuOpen=false; hide() end})
    lib.showContext("moc_business_main")
end


RegisterNetEvent("moc_restaurant:openBusinessManagementDirect", function(restaurantId, restaurantName)
    restaurantId = tonumber(restaurantId)

    if not restaurantId then
        lib.notify({
            title = "MOC Restaurant",
            description = "Invalid restaurant selected.",
            type = "error"
        })
        return
    end

    lib.notify({
        title = "MOC Restaurant",
        description = "Opening Business Management...",
        type = "inform",
        duration = 2000
    })

    TriggerServerEvent(
        "moc_restaurant:requestBusinessManagementDirect",
        restaurantId,
        restaurantName
    )
end)

RegisterNetEvent("moc_restaurant:receiveBusinessManagementDirect", function(loc, profile)
    print(("[MOC Restaurant] Business Management response received for restaurant %s."):format(
        tostring(loc and loc.restaurant_id)
    ))

    if type(loc) ~= "table" or type(profile) ~= "table" then
        lib.notify({
            title = "MOC Restaurant",
            description = "Invalid Business Management response.",
            type = "error"
        })
        return
    end

    renderPortal(loc, profile)
end)


RegisterNetEvent("moc_restaurant:clockStateChanged", function(restaurantId, isClockedIn, restaurantName)
    menuOpen = false
    hide()

    print(("[MOC Restaurant] Clock state changed: restaurant=%s clockedIn=%s"):format(
        tostring(restaurantId),
        tostring(isClockedIn)
    ))

    -- Re-request the profile from the server so the next menu is based on
    -- the confirmed database state rather than stale client data.
    Wait(250)

    TriggerServerEvent(
        "moc_restaurant:requestBusinessManagementDirect",
        restaurantId,
        restaurantName
    )
end)


RegisterNetEvent("moc_restaurant:businessAccountUpdated", function(restaurantId, jobName, restaurantName)
    menuOpen = false
    hide()

    print(("[MOC Restaurant] Business account/job updated: %s"):format(
        tostring(jobName)
    ))

    Wait(250)

    TriggerServerEvent(
        "moc_restaurant:requestBusinessManagementDirect",
        restaurantId,
        restaurantName
    )
end)


RegisterNetEvent("moc_restaurant:automaticBusinessSetupFinished", function(restaurantId, restaurantName)
    menuOpen = false
    hide()

    Wait(250)

    TriggerServerEvent(
        "moc_restaurant:requestBusinessManagementDirect",
        restaurantId,
        restaurantName
    )
end)

CreateThread(function()
    Wait(3500)
    while true do
        local sleep=1000
        local locs=lib.callback.await("moc_restaurant:getInteractiveLocations",false) or {}
        local coords=GetEntityCoords(PlayerPedId()); local near,dist
        for _,loc in ipairs(locs) do
            if loc.location_type==(Config.BusinessManagement.ManagerStationType or "manager") then
                local d=#(coords-vector3(loc.x,loc.y,loc.z))
                if d<10.0 then sleep=0 end
                local rad=tonumber(loc.interaction_radius) or Config.DefaultStationRadius or 0.65
                if d<=rad and (not dist or d<dist) then near=loc; dist=d end
            end
        end
        if near and not menuOpen then
            if not prompt then lib.showTextUI("[E] "..near.restaurant_name.." Employee Portal"); prompt=true end
            if IsControlJustReleased(0,38) then
                hide()
                TriggerServerEvent(
                    "moc_restaurant:requestBusinessManagementDirect",
                    near.restaurant_id,
                    near.restaurant_name
                )
                Wait(500)
            end
        else hide() end
        Wait(sleep)
    end
end)
