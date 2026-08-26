
local function notify(src,msg,kind)
    TriggerClientEvent("ox_lib:notify",src,{title="MOC Restaurant",description=msg,type=kind or "inform"})
end

local function P(src) return QBCore and QBCore.Functions.GetPlayer(src) end
local function CID(src)
    local p=P(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function perms(v)
    if type(v)=="table" then return v end
    if type(v)=="string" and v~="" then
        local ok,d=pcall(json.decode,v)
        if ok and type(d)=="table" then return d end
    end
    return {}
end

local function employeeByCid(rid,cid)
    return MySQL.single.await([[
        SELECT e.*, r.label rank_label, r.pay, r.isboss, r.protected, r.permissions
        FROM moc_employees e
        LEFT JOIN moc_job_ranks r ON r.restaurant_id=e.restaurant_id AND r.grade=e.grade
        WHERE e.restaurant_id=? AND e.citizenid=? LIMIT 1
    ]],{rid,cid})
end

local function employee(src,rid)
    local cid=CID(src)
    return cid and employeeByCid(rid,cid) or nil
end

local function ranks(rid)
    local rows=MySQL.query.await("SELECT * FROM moc_job_ranks WHERE restaurant_id=? ORDER BY grade ASC",{rid}) or {}
    for _,v in ipairs(rows) do v.permissions=perms(v.permissions) end
    return rows
end

local function maxGrade(rid)
    local row=MySQL.single.await("SELECT MAX(grade) max_grade FROM moc_job_ranks WHERE restaurant_id=?",{rid})
    return row and tonumber(row.max_grade) or -1
end

local function audit(rid,src,action,details)
    MySQL.insert.await("INSERT INTO moc_business_audit (restaurant_id,actor_citizenid,action,details) VALUES (?,?,?,?)",
        {rid,src and CID(src) or nil,action,details and json.encode(details) or nil})
end

local function ensureOwner(rid)
    local restaurant=GetRestaurant(rid)
    if not restaurant or not restaurant.owner or restaurant.owner=="" then return end
    local row=MySQL.single.await("SELECT * FROM moc_job_ranks WHERE restaurant_id=? AND isboss=1 ORDER BY grade DESC LIMIT 1",{rid})
    local grade
    if row then
        grade=tonumber(row.grade)
        MySQL.update.await("UPDATE moc_job_ranks SET protected=1,permissions=? WHERE id=?",
            {json.encode(Config.BusinessManagement.OwnerPermissions or {}),row.id})
    else
        grade=maxGrade(rid)+1
        MySQL.insert.await([[
            INSERT INTO moc_job_ranks (restaurant_id,grade,name,label,pay,isboss,protected,permissions)
            VALUES (?,?,'owner','Owner',0,1,1,?)
        ]],{rid,grade,json.encode(Config.BusinessManagement.OwnerPermissions or {})})
    end
    MySQL.insert.await([[
        INSERT INTO moc_employees (restaurant_id,citizenid,role,grade,clocked_in,minutes_worked)
        VALUES (?,?,'owner',?,0,0)
        ON DUPLICATE KEY UPDATE role='owner',grade=VALUES(grade)
    ]],{rid,restaurant.owner,grade})
end

local function allowed(src,rid,key,clocked)
    if HasPermission(src) then return true end
    local restaurant=GetRestaurant(rid)
    local cid=CID(src)
    if not restaurant or not cid then return false end
    if restaurant.owner==cid then return true end
    local e=employeeByCid(rid,cid)
    if not e then return false end
    if clocked and Config.BusinessManagement.RequireClockInForWorkPermissions and tonumber(e.clocked_in)~=1 then return false end
    return perms(e.permissions)[key]==true
end

exports("HasRestaurantPermission",allowed)

lib.callback.register("moc_restaurant:hasBusinessPermission",function(src,rid,key,clocked)
    return allowed(src,tonumber(rid),tostring(key),clocked==true)
end)

lib.callback.register("moc_restaurant:getBusinessProfile",function(src,rid)
    rid=tonumber(rid); local restaurant=rid and GetRestaurant(rid)
    if not restaurant then return nil end
    ensureOwner(rid)
    return {
        restaurant=restaurant,
        employee=employee(src,rid),
        isOwner=restaurant.owner==CID(src),
        canManageEmployees=allowed(src,rid,"manage_employees",false),
        canManageRanks=allowed(src,rid,"manage_ranks",false),
        canManagePayroll=allowed(src,rid,"manage_payroll",false),
        canViewSales=allowed(src,rid,"view_sales",false),
        canManageDeliveries=allowed(src,rid,"manage_deliveries",false)
    }
end)


local function buildBusinessProfileSafe(src, rid)
    local restaurant = rid and GetRestaurant(rid)
    if not restaurant then
        return nil, "Restaurant not found."
    end

    ensureOwner(rid)

    local currentEmployee = employee(src, rid)
    local cid = CID(src)

    return {
        restaurant = restaurant,
        employee = currentEmployee,
        isOwner = cid ~= nil and restaurant.owner == cid,
        canManageEmployees = allowed(src, rid, "manage_employees", false),
        canManageRanks = allowed(src, rid, "manage_ranks", false),
        canManagePayroll = allowed(src, rid, "manage_payroll", false),
        canViewSales = allowed(src, rid, "view_sales", false),
        canManageDeliveries = allowed(src, rid, "manage_deliveries", false)
    }
end

RegisterNetEvent("moc_restaurant:requestBusinessManagementDirect", function(restaurantId, restaurantName)
    local src = source
    local rid = tonumber(restaurantId)

    print(("[MOC Restaurant] Business Management open request from %s for restaurant %s."):format(
        tostring(src),
        tostring(rid)
    ))

    if not rid then
        notify(src, "Invalid restaurant selected.", "error")
        return
    end

    local ok, profile, reason = pcall(function()
        local result, err = buildBusinessProfileSafe(src, rid)
        return result, err
    end)

    if not ok then
        print(("[MOC Restaurant] Business Management ERROR for restaurant %s: %s"):format(
            tostring(rid),
            tostring(profile)
        ))
        notify(src, "Business Management failed to load. Check the server console.", "error")
        return
    end

    if not profile then
        print(("[MOC Restaurant] Business Management profile unavailable: %s"):format(
            tostring(reason)
        ))
        notify(src, reason or "Business Management profile unavailable.", "error")
        return
    end

    print(("[MOC Restaurant] Business Management profile ready. owner=%s employee=%s manageEmployees=%s manageRanks=%s"):format(
        tostring(profile.isOwner),
        tostring(profile.employee ~= nil),
        tostring(profile.canManageEmployees),
        tostring(profile.canManageRanks)
    ))

    TriggerClientEvent(
        "moc_restaurant:receiveBusinessManagementDirect",
        src,
        {
            restaurant_id = rid,
            restaurant_name = restaurantName or profile.restaurant.name or "Restaurant"
        },
        profile
    )
end)

lib.callback.register("moc_restaurant:getBusinessEmployees",function(src,rid)
    rid=tonumber(rid)
    if not allowed(src,rid,"manage_employees",false) then return {} end
    return MySQL.query.await([[
        SELECT e.*,r.label rank_label,r.pay,r.isboss,r.protected
        FROM moc_employees e LEFT JOIN moc_job_ranks r
        ON r.restaurant_id=e.restaurant_id AND r.grade=e.grade
        WHERE e.restaurant_id=? ORDER BY e.grade DESC,e.citizenid
    ]],{rid}) or {}
end)

lib.callback.register("moc_restaurant:getBusinessRanks",function(src,rid)
    rid=tonumber(rid); local restaurant=GetRestaurant(rid)
    if not restaurant then return {} end
    local cid=CID(src)
    if not HasPermission(src) and restaurant.owner~=cid and not employee(src,rid) then return {} end
    return ranks(rid)
end)

lib.callback.register("moc_restaurant:getPayrollHistory",function(src,rid)
    rid=tonumber(rid)
    if not allowed(src,rid,"manage_payroll",false) then return {} end
    return MySQL.query.await("SELECT * FROM moc_payroll WHERE restaurant_id=? ORDER BY id DESC LIMIT 100",{rid}) or {}
end)

lib.callback.register("moc_restaurant:getSalesHistory",function(src,rid)
    rid=tonumber(rid)
    if not allowed(src,rid,"view_sales",false) then return {} end
    return MySQL.query.await("SELECT * FROM moc_sales WHERE restaurant_id=? ORDER BY id DESC LIMIT 100",{rid}) or {}
end)


local function normalizeJobName(value)
    value = tostring(value or ""):lower()
    value = value:gsub("%s+", "_")
    value = value:gsub("[^%w_]", "")
    value = value:gsub("_+", "_")
    return value:sub(1, 50)
end


local function buildRuntimeJob(restaurantId)
    local restaurant = GetRestaurant(restaurantId)
    if not restaurant or not restaurant.job or restaurant.job == "" then
        return nil
    end

    local rankRows = ranks(restaurantId)
    local grades = {}

    for _, rank in ipairs(rankRows) do
        grades[tostring(rank.grade)] = {
            name = rank.label,
            payment = tonumber(rank.pay) or 0,
            isboss = tonumber(rank.isboss) == 1
        }
    end

    if next(grades) == nil then
        grades["0"] = {
            name = "Employee",
            payment = 0,
            isboss = false
        }
    end

    return {
        label = restaurant.name,
        defaultDuty = true,
        offDutyPay = false,
        grades = grades
    }
end

local function ensureQBCoreJob(restaurantId)
    if not Config.AutomaticBusinessSetup
        or not Config.AutomaticBusinessSetup.Enabled
        or not Config.AutomaticBusinessSetup.CreateQBCoreJob
    then
        return true, "disabled"
    end

    local restaurant = GetRestaurant(restaurantId)
    if not restaurant or not restaurant.job or restaurant.job == "" then
        return false, "missing_job"
    end

    local jobData = buildRuntimeJob(restaurantId)
    if not jobData then
        return false, "job_build_failed"
    end

    local jobName = restaurant.job

    if QBCore.Shared
        and QBCore.Shared.Jobs
        and QBCore.Shared.Jobs[jobName]
    then
        -- Job exists already. Try to refresh it through the runtime API when available.
        if QBCore.Functions.AddJob then
            pcall(function()
                QBCore.Functions.AddJob(jobName, jobData)
            end)
        elseif QBCore.Functions.AddJobs then
            pcall(function()
                QBCore.Functions.AddJobs({
                    [jobName] = jobData
                })
            end)
        end

        return true, "existing"
    end

    if QBCore.Functions.AddJob then
        local ok, result = pcall(function()
            return QBCore.Functions.AddJob(jobName, jobData)
        end)

        if ok and result ~= false then
            return true, "created"
        end
    elseif QBCore.Functions.AddJobs then
        local ok, result = pcall(function()
            return QBCore.Functions.AddJobs({
                [jobName] = jobData
            })
        end)

        if ok and result ~= false then
            return true, "created"
        end
    end

    return false, "qbcore_addjob_unavailable"
end

local function qbBankingAccountExists(accountName)
    if GetResourceState("qb-banking") ~= "started" then
        return false, "qb-banking_not_started"
    end

    -- Current qb-banking exposes GetAccountBalance. If the account is missing
    -- this commonly returns nil/false, depending on the build.
    local ok, result = pcall(function()
        return exports["qb-banking"]:GetAccountBalance(accountName)
    end)

    if ok and result ~= nil and result ~= false then
        return true, tonumber(result) or 0
    end

    return false, nil
end

local function ensureQBBankingAccount(restaurantId)
    if not Config.AutomaticBusinessSetup
        or not Config.AutomaticBusinessSetup.Enabled
        or not Config.AutomaticBusinessSetup.CreateQBBankingAccount
    then
        return true, "disabled"
    end

    if GetResourceState("qb-banking") ~= "started" then
        return false, "qb-banking_not_started"
    end

    local restaurant = GetRestaurant(restaurantId)
    if not restaurant or not restaurant.job or restaurant.job == "" then
        return false, "missing_job"
    end

    local accountName = restaurant.job
    local exists, balance = qbBankingAccountExists(accountName)

    if exists then
        return true, "existing", balance
    end

    local startingBalance = math.max(
        0,
        math.floor(
            tonumber(
                Config.AutomaticBusinessSetup.StartingBusinessBalance
            ) or 0
        )
    )

    local ok, result = pcall(function()
        return exports["qb-banking"]:CreateJobAccount(
            accountName,
            startingBalance
        )
    end)

    if ok and result ~= false then
        return true, "created", startingBalance
    end

    -- Some qb-banking builds may create job accounts automatically from
    -- QBCore jobs after resource restart. Report this clearly rather than
    -- failing silently.
    return false, "create_export_failed"
end

local function ensureBusinessJobAndBanking(restaurantId)
    local restaurant = GetRestaurant(restaurantId)

    if not restaurant then
        return {
            ok = false,
            error = "restaurant_not_found"
        }
    end

    local jobOk, jobStatus = ensureQBCoreJob(restaurantId)
    local bankOk, bankStatus, bankBalance = ensureQBBankingAccount(restaurantId)

    print(("[MOC Restaurant] Automatic business setup for restaurant %s: job=%s/%s bank=%s/%s"):format(
        tostring(restaurantId),
        tostring(jobOk),
        tostring(jobStatus),
        tostring(bankOk),
        tostring(bankStatus)
    ))

    return {
        ok = jobOk and bankOk,
        jobOk = jobOk,
        jobStatus = jobStatus,
        bankOk = bankOk,
        bankStatus = bankStatus,
        bankBalance = bankBalance
    }
end

lib.callback.register(
    "moc_restaurant:getAutomaticBusinessSetupStatus",
    function(source, restaurantId)
        restaurantId = tonumber(restaurantId)

        if not restaurantId then
            return nil
        end

        local restaurant = GetRestaurant(restaurantId)
        if not restaurant then
            return nil
        end

        local cid = CID(source)
        local isOwner = cid and restaurant.owner == cid

        if not HasPermission(source)
            and not isOwner
            and not allowed(
                source,
                restaurantId,
                "edit_restaurant",
                false
            )
        then
            return nil
        end

        local jobExists = false
        if QBCore.Shared
            and QBCore.Shared.Jobs
            and restaurant.job
            and restaurant.job ~= ""
        then
            jobExists =
                QBCore.Shared.Jobs[restaurant.job] ~= nil
        end

        local bankExists = false
        local bankBalance = nil

        if restaurant.job
            and restaurant.job ~= ""
            and GetResourceState("qb-banking")
                == "started"
        then
            bankExists, bankBalance =
                qbBankingAccountExists(
                    restaurant.job
                )
        end

        return {
            restaurantId = restaurantId,
            jobName = restaurant.job,
            jobExists = jobExists,
            bankExists = bankExists,
            bankBalance = bankBalance
        }
    end
)

RegisterNetEvent(
    "moc_restaurant:runAutomaticBusinessSetup",
    function(restaurantId)
        local src = source
        restaurantId = tonumber(restaurantId)

        if not restaurantId then
            return
        end

        local restaurant =
            GetRestaurant(restaurantId)

        if not restaurant then
            notify(
                src,
                "Restaurant not found.",
                "error"
            )
            return
        end

        local cid = CID(src)
        local isOwner =
            cid and restaurant.owner == cid

        if not HasPermission(src)
            and not isOwner
            and not allowed(
                src,
                restaurantId,
                "edit_restaurant",
                false
            )
        then
            notify(
                src,
                "You do not have permission to run business setup.",
                "error"
            )
            return
        end

        if not restaurant.job
            or restaurant.job == ""
        then
            notify(
                src,
                "Set the Business Account / Job name first.",
                "error"
            )
            return
        end

        local result =
            ensureBusinessJobAndBanking(
                restaurantId
            )

        local messages = {}

        messages[#messages + 1] =
            ("QBCore Job: %s"):format(
                result.jobOk
                    and result.jobStatus
                    or ("FAILED (" ..
                        tostring(
                            result.jobStatus
                        ) ..
                        ")")
            )

        messages[#messages + 1] =
            ("qb-banking Account: %s"):format(
                result.bankOk
                    and result.bankStatus
                    or ("FAILED (" ..
                        tostring(
                            result.bankStatus
                        ) ..
                        ")")
            )

        notify(
            src,
            table.concat(messages, "\n"),
            result.ok
                and "success"
                or "error"
        )

        TriggerClientEvent(
            "moc_restaurant:automaticBusinessSetupFinished",
            src,
            restaurantId,
            restaurant.name
        )
    end
)

RegisterNetEvent("moc_restaurant:setBusinessAccountJob", function(restaurantId, jobName)
    local src = source
    restaurantId = tonumber(restaurantId)

    if not restaurantId then
        notify(src, "Invalid restaurant.", "error")
        return
    end

    local restaurant = GetRestaurant(restaurantId)
    if not restaurant then
        notify(src, "Restaurant not found.", "error")
        return
    end

    local cid = CID(src)
    local isOwner = cid and restaurant.owner == cid

    if not HasPermission(src)
        and not isOwner
        and not allowed(src, restaurantId, "edit_restaurant", false)
    then
        notify(src, "You do not have permission to edit the business account.", "error")
        return
    end

    jobName = normalizeJobName(jobName)

    if jobName == "" then
        notify(src, "A business job/account name is required.", "error")
        return
    end

    MySQL.update.await(
        "UPDATE moc_restaurants SET job = ? WHERE id = ?",
        { jobName, restaurantId }
    )

    local refreshed = GetRestaurant(restaurantId)

    print(("[MOC Restaurant] Restaurant %s business job/account set to '%s'."):format(
        tostring(restaurantId),
        tostring(jobName)
    ))

    TriggerEvent("moc_restaurant:syncRestaurantJob", restaurantId)

    local setupResult =
        ensureBusinessJobAndBanking(
            restaurantId
        )

    notify(
        src,
        ("Business job/account set to '%s'."):format(jobName),
        "success"
    )

    if not setupResult.ok then
        notify(
            src,
            "Job/account saved, but automatic QBCore/qb-banking setup needs attention. Open Business Setup Status.",
            "error"
        )
    end

    TriggerClientEvent(
        "moc_restaurant:businessAccountUpdated",
        src,
        restaurantId,
        jobName,
        refreshed and refreshed.name or restaurant.name
    )
end)

RegisterNetEvent("moc_restaurant:setRestaurantOwner",function(rid,targetCid)
    local src=source; rid=tonumber(rid)
    if not rid or not HasPermission(src) then return end
    targetCid=tostring(targetCid or "")
    if targetCid=="" then return notify(src,"Citizen ID required.","error") end
    MySQL.update.await("UPDATE moc_restaurants SET owner=? WHERE id=?",{targetCid,rid})
    ensureOwner(rid); audit(rid,src,"set_owner",{citizenid=targetCid})
    notify(src,"Restaurant owner updated.","success")
end)

RegisterNetEvent("moc_restaurant:createBusinessRank",function(data)
    local src=source; if type(data)~="table" then return end
    local rid=tonumber(data.restaurantId)
    if not rid or not allowed(src,rid,"manage_ranks",false) then return notify(src,"No rank permission.","error") end
    local label=tostring(data.label or ""):sub(1,100)
    if label=="" then return notify(src,"Rank label required.","error") end
    local grade=maxGrade(rid)+1
    local name=tostring(data.name or label:lower():gsub("[^%w]+","_")):sub(1,50)
    local pay=math.max(0,math.floor(tonumber(data.pay) or 0))
    MySQL.insert.await([[
        INSERT INTO moc_job_ranks (restaurant_id,grade,name,label,pay,isboss,protected,permissions)
        VALUES (?,?,?,?,?,0,0,?)
    ]],{rid,grade,name,label,pay,json.encode(data.permissions or Config.BusinessManagement.DefaultPermissions or {})})
    audit(rid,src,"create_rank",{grade=grade,label=label,pay=pay})
    TriggerEvent("moc_restaurant:syncRestaurantJob",rid)
    notify(src,"Rank created.","success")
end)

RegisterNetEvent("moc_restaurant:updateBusinessRank",function(data)
    local src=source; if type(data)~="table" then return end
    local rid,grade=tonumber(data.restaurantId),tonumber(data.grade)
    if not rid or grade==nil or not allowed(src,rid,"manage_ranks",false) then return end
    local row=MySQL.single.await("SELECT * FROM moc_job_ranks WHERE restaurant_id=? AND grade=? LIMIT 1",{rid,grade})
    if not row then return end
    local ps=data.permissions or perms(row.permissions)
    if tonumber(row.protected)==1 then ps=Config.BusinessManagement.OwnerPermissions or ps end
    MySQL.update.await("UPDATE moc_job_ranks SET label=?,pay=?,permissions=? WHERE restaurant_id=? AND grade=?",
        {tostring(data.label or row.label):sub(1,100),math.max(0,math.floor(tonumber(data.pay) or tonumber(row.pay) or 0)),json.encode(ps),rid,grade})
    audit(rid,src,"update_rank",{grade=grade}); TriggerEvent("moc_restaurant:syncRestaurantJob",rid)
    notify(src,"Rank updated.","success")
end)

RegisterNetEvent("moc_restaurant:deleteBusinessRank",function(rid,grade)
    local src=source; rid,grade=tonumber(rid),tonumber(grade)
    if not rid or grade==nil or not allowed(src,rid,"manage_ranks",false) then return end
    local row=MySQL.single.await("SELECT * FROM moc_job_ranks WHERE restaurant_id=? AND grade=? LIMIT 1",{rid,grade})
    if not row then return end
    if tonumber(row.protected)==1 or tonumber(row.isboss)==1 then return notify(src,"Owner rank cannot be deleted.","error") end
    local c=MySQL.single.await("SELECT COUNT(*) count FROM moc_employees WHERE restaurant_id=? AND grade=?",{rid,grade})
    if c and tonumber(c.count)>0 then return notify(src,"Move employees out of this rank first.","error") end
    MySQL.update.await("DELETE FROM moc_job_ranks WHERE restaurant_id=? AND grade=?",{rid,grade})
    audit(rid,src,"delete_rank",{grade=grade}); TriggerEvent("moc_restaurant:syncRestaurantJob",rid)
    notify(src,"Rank deleted.","success")
end)

RegisterNetEvent("moc_restaurant:hireBusinessEmployee",function(data)
    local src=source; if type(data)~="table" then return end
    local rid,targetId,grade=tonumber(data.restaurantId),tonumber(data.targetServerId),tonumber(data.grade)
    if not rid or not targetId or grade==nil or not allowed(src,rid,"manage_employees",false) then return end
    local target=P(targetId); if not target then return notify(src,"Player not online.","error") end
    local rank=MySQL.single.await("SELECT * FROM moc_job_ranks WHERE restaurant_id=? AND grade=? LIMIT 1",{rid,grade})
    if not rank or tonumber(rank.protected)==1 then return notify(src,"Invalid rank.","error") end
    local cid=target.PlayerData.citizenid
    MySQL.insert.await([[
        INSERT INTO moc_employees (restaurant_id,citizenid,role,grade,clocked_in,minutes_worked)
        VALUES (?,?,?,?,0,0) ON DUPLICATE KEY UPDATE role=VALUES(role),grade=VALUES(grade)
    ]],{rid,cid,rank.name,grade})
    local restaurant=GetRestaurant(rid)
    if restaurant and restaurant.job and restaurant.job~="" then pcall(function() target.Functions.SetJob(restaurant.job,grade) end) end
    audit(rid,src,"hire_employee",{citizenid=cid,grade=grade})
    notify(src,"Employee hired.","success"); notify(targetId,"You were hired by "..(restaurant and restaurant.name or "a restaurant")..".","success")
end)

RegisterNetEvent("moc_restaurant:setBusinessEmployeeRank",function(data)
    local src=source; if type(data)~="table" then return end
    local rid,cid,grade=tonumber(data.restaurantId),tostring(data.citizenid or ""),tonumber(data.grade)
    if not rid or cid=="" or grade==nil or not allowed(src,rid,"manage_employees",false) then return end
    local restaurant=GetRestaurant(rid)
    if restaurant and restaurant.owner==cid then return notify(src,"Owner rank cannot be changed here.","error") end
    local rank=MySQL.single.await("SELECT * FROM moc_job_ranks WHERE restaurant_id=? AND grade=? LIMIT 1",{rid,grade})
    if not rank or tonumber(rank.protected)==1 then return notify(src,"Invalid rank.","error") end
    MySQL.update.await("UPDATE moc_employees SET grade=?,role=? WHERE restaurant_id=? AND citizenid=?",{grade,rank.name,rid,cid})
    audit(rid,src,"change_employee_rank",{citizenid=cid,grade=grade})
    notify(src,"Employee rank updated.","success")
end)

RegisterNetEvent("moc_restaurant:fireBusinessEmployee",function(rid,cid)
    local src=source; rid=tonumber(rid); cid=tostring(cid or "")
    if not rid or cid=="" or not allowed(src,rid,"manage_employees",false) then return end
    local restaurant=GetRestaurant(rid)
    if restaurant and restaurant.owner==cid then return notify(src,"Owner cannot be fired.","error") end
    MySQL.update.await("DELETE FROM moc_employees WHERE restaurant_id=? AND citizenid=?",{rid,cid})
    audit(rid,src,"fire_employee",{citizenid=cid}); notify(src,"Employee fired.","success")
end)

local function normalizeClockValue(value)
    if value == true then
        return 1
    end

    if value == false or value == nil then
        return 0
    end

    return tonumber(value) == 1 and 1 or 0
end

RegisterNetEvent("moc_restaurant:setClockState", function(restaurantId, requestedState)
    local src = source
    local rid = tonumber(restaurantId)

    if not rid then
        notify(src, "Invalid restaurant.", "error")
        return
    end

    local desiredState = requestedState == true and 1 or 0

    ensureOwner(rid)

    local e = employee(src, rid)

    if not e then
        notify(src, "You are not employed by this restaurant.", "error")
        return
    end

    local restaurant = GetRestaurant(rid)

    if not restaurant then
        notify(src, "Restaurant not found.", "error")
        return
    end

    local currentState = normalizeClockValue(e.clocked_in)

    if currentState == desiredState then
        notify(
            src,
            desiredState == 1
                and "You are already clocked in."
                or "You are already clocked out.",
            "inform"
        )

        TriggerClientEvent(
            "moc_restaurant:clockStateChanged",
            src,
            rid,
            desiredState == 1,
            restaurant.name
        )

        return
    end

    local changed = MySQL.update.await([[
        UPDATE moc_employees
        SET clocked_in = ?,
            last_clock_in = CASE
                WHEN ? = 1 THEN CURRENT_TIMESTAMP
                ELSE last_clock_in
            END
        WHERE restaurant_id = ?
          AND citizenid = ?
    ]], {
        desiredState,
        desiredState,
        rid,
        e.citizenid
    })

    if not changed or tonumber(changed) < 1 then
        print(("[MOC Restaurant] Clock update FAILED for %s at restaurant %s. Desired=%s"):format(
            tostring(e.citizenid),
            tostring(rid),
            tostring(desiredState)
        ))

        notify(
            src,
            "Clock state could not be saved. Check the server console.",
            "error"
        )

        return
    end

    local refreshed = employee(src, rid)
    local actualState = refreshed and normalizeClockValue(refreshed.clocked_in) or -1

    if actualState ~= desiredState then
        print(("[MOC Restaurant] Clock verification FAILED for %s. Desired=%s Actual=%s Raw=%s"):format(
            tostring(e.citizenid),
            tostring(desiredState),
            tostring(actualState),
            tostring(refreshed and refreshed.clocked_in)
        ))

        notify(
            src,
            "Clock state did not verify correctly.",
            "error"
        )

        return
    end

    local qbPlayer = P(src)

    if qbPlayer
        and restaurant.job
        and restaurant.job ~= ""
        and qbPlayer.PlayerData.job
        and qbPlayer.PlayerData.job.name == restaurant.job
        and qbPlayer.Functions.SetJobDuty
    then
        pcall(function()
            qbPlayer.Functions.SetJobDuty(desiredState == 1)
        end)
    end

    audit(
        rid,
        src,
        desiredState == 1 and "clock_in" or "clock_out"
    )

    notify(
        src,
        desiredState == 1
            and "You are now clocked in."
            or "You are now clocked out.",
        "success"
    )

    TriggerClientEvent(
        "moc_restaurant:clockStateChanged",
        src,
        rid,
        desiredState == 1,
        restaurant.name
    )
end)

local function bankBalance(account)
    if GetResourceState("qb-banking")~="started" then return nil end
    local ok,v=pcall(function() return exports["qb-banking"]:GetAccountBalance(account) end)
    return ok and tonumber(v) or nil
end

local function bankRemove(account,amount)
    if GetResourceState("qb-banking")~="started" then return false end
    local ok,v=pcall(function() return exports["qb-banking"]:RemoveMoney(account,amount,"MOC Restaurant Payroll") end)
    return ok and v~=false
end

CreateThread(function()
    while true do
        Wait(60000)
        if Config.BusinessManagement.Enabled then
            MySQL.update.await("UPDATE moc_employees SET minutes_worked=minutes_worked+1 WHERE clocked_in=1")
            local interval=math.max(1,tonumber(Config.BusinessManagement.PayrollIntervalMinutes) or 30)
            local rows=MySQL.query.await([[
                SELECT e.*,r.pay FROM moc_employees e
                INNER JOIN moc_job_ranks r ON r.restaurant_id=e.restaurant_id AND r.grade=e.grade
                WHERE e.clocked_in=1 AND (e.last_payroll IS NULL OR TIMESTAMPDIFF(MINUTE,e.last_payroll,CURRENT_TIMESTAMP)>=?)
            ]],{interval}) or {}
            for _,e in ipairs(rows) do
                local restaurant=GetRestaurant(e.restaurant_id)
                local pay=math.max(0,math.floor(tonumber(e.pay) or 0))
                local status="paid"; local online
                for _,id in ipairs(GetPlayers()) do
                    local pp=P(tonumber(id))
                    if pp and pp.PlayerData.citizenid==e.citizenid then online=pp break end
                end
                if not online then status="failed_offline"
                elseif Config.BusinessManagement.UseBusinessAccountForPayroll then
                    local account=restaurant and restaurant.job
                    local bal=account and bankBalance(account) or nil
                    if bal==nil then status="failed_banking_unavailable"
                    elseif bal<pay then status="failed_insufficient_funds"
                    elseif not bankRemove(account,pay) then status="failed_withdrawal" end
                end
                if status=="paid" and online then online.Functions.AddMoney("bank",pay,"moc-restaurant-payroll") end
                MySQL.insert.await("INSERT INTO moc_payroll (restaurant_id,citizenid,grade,amount,status) VALUES (?,?,?,?,?)",
                    {e.restaurant_id,e.citizenid,e.grade,pay,status})
                MySQL.update.await("UPDATE moc_employees SET last_payroll=CURRENT_TIMESTAMP WHERE restaurant_id=? AND citizenid=?",
                    {e.restaurant_id,e.citizenid})
                if online then
                    notify(online.PlayerData.source,status=="paid" and ("Restaurant paycheck: $"..pay) or ("Payroll failed: "..status),
                        status=="paid" and "success" or "error")
                end
            end
        end
    end
end)

AddEventHandler("moc_restaurant:syncRestaurantJob",function(rid)
    if not Config.BusinessManagement.SyncRanksToQBCore then return end
    local restaurant=GetRestaurant(tonumber(rid)); if not restaurant or not restaurant.job or restaurant.job=="" then return end
    local grades={}
    for _,r in ipairs(ranks(restaurant.id)) do
        grades[tostring(r.grade)]={name=r.label,payment=tonumber(r.pay) or 0,isboss=tonumber(r.isboss)==1}
    end
    local job={label=restaurant.name,defaultDuty=true,offDutyPay=false,grades=grades}
    if QBCore.Functions.AddJob then pcall(function() QBCore.Functions.AddJob(restaurant.job,job) end)
    elseif QBCore.Functions.AddJobs then pcall(function() QBCore.Functions.AddJobs({[restaurant.job]=job}) end) end
end)


-- ============================================================
-- v2.2.4 Deliveries & Restocking
-- Embedded in business.lua so callbacks share the proven
-- Business Management server execution path.
-- ============================================================

local function getDeliveryCatalogItem(itemName)
    for _, item in ipairs(Config.Deliveries.Items or {}) do
        if item.item == itemName then
            return item
        end
    end
    return nil
end

local function canManageDeliveryOrders(src, restaurantId)
    if HasPermission(src) then
        return true
    end

    return allowed(
        src,
        restaurantId,
        "manage_deliveries",
        false
    )
end

local function canReceiveDeliveryOrders(src, restaurantId)
    if HasPermission(src) then
        return true
    end

    return allowed(
        src,
        restaurantId,
        "storage",
        true
    ) or allowed(
        src,
        restaurantId,
        "manage_deliveries",
        true
    )
end

local function deliveryBusinessBalance(account)
    if not account or account == "" then
        return nil
    end

    if GetResourceState("qb-banking") ~= "started" then
        return nil
    end

    local ok, result = pcall(function()
        return exports["qb-banking"]:GetAccountBalance(account)
    end)

    return ok and tonumber(result) or nil
end

local function deliveryRemoveBusinessMoney(account, amount)
    if GetResourceState("qb-banking") ~= "started" then
        return false
    end

    local ok, result = pcall(function()
        return exports["qb-banking"]:RemoveMoney(
            account,
            amount,
            "MOC Restaurant Supply Delivery"
        )
    end)

    return ok and result ~= false
end

local function deliveryAddBusinessMoney(account, amount)
    if GetResourceState("qb-banking") ~= "started" then
        return false
    end

    local ok, result = pcall(function()
        return exports["qb-banking"]:AddMoney(
            account,
            amount,
            "MOC Restaurant Delivery Refund"
        )
    end)

    return ok and result ~= false
end

local function refreshDeliveryStatuses(restaurantId)
    if restaurantId then
        MySQL.update.await([[
            UPDATE moc_deliveries
            SET status = 'ready'
            WHERE restaurant_id = ?
              AND status = 'ordered'
              AND ready_at IS NOT NULL
              AND ready_at <= CURRENT_TIMESTAMP
        ]], { restaurantId })
    else
        MySQL.update.await([[
            UPDATE moc_deliveries
            SET status = 'ready'
            WHERE status = 'ordered'
              AND ready_at IS NOT NULL
              AND ready_at <= CURRENT_TIMESTAMP
        ]])
    end
end

local function nearDeliveryReceivingStation(src, restaurantId)
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then
        return false
    end

    local coords = GetEntityCoords(ped)

    for _, loc in ipairs(GetRestaurantLocations(restaurantId) or {}) do
        if loc.location_type == "delivery_receiving" then
            local dx = coords.x - tonumber(loc.x)
            local dy = coords.y - tonumber(loc.y)
            local dz = coords.z - tonumber(loc.z)
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

            if distance <= 4.0 then
                return true
            end
        end
    end

    return false
end

lib.callback.register(
    "moc_restaurant:getDeliveryCatalog",
    function(source, restaurantId)
        restaurantId = tonumber(restaurantId)

        if not restaurantId
            or not canManageDeliveryOrders(source, restaurantId)
        then
            return {}
        end

        return Config.Deliveries.Items or {}
    end
)

lib.callback.register(
    "moc_restaurant:getRestaurantDeliveries",
    function(source, restaurantId)
        restaurantId = tonumber(restaurantId)

        if not restaurantId then
            return {}
        end

        if not canManageDeliveryOrders(source, restaurantId)
            and not canReceiveDeliveryOrders(source, restaurantId)
        then
            return {}
        end

        refreshDeliveryStatuses(restaurantId)

        local rows = MySQL.query.await([[
            SELECT *
            FROM moc_deliveries
            WHERE restaurant_id = ?
            ORDER BY id DESC
            LIMIT 100
        ]], { restaurantId }) or {}

        for _, row in ipairs(rows) do
            local ok, items = pcall(
                json.decode,
                row.items or "[]"
            )

            row.items = ok and items or {}
        end

        return rows
    end
)

RegisterNetEvent(
    "moc_restaurant:createDeliveryOrder",
    function(data)
        local src = source

        if not Config.Deliveries.Enabled
            or type(data) ~= "table"
        then
            return
        end

        local restaurantId = tonumber(data.restaurantId)

        if not restaurantId
            or not canManageDeliveryOrders(src, restaurantId)
        then
            notify(
                src,
                "You do not have permission to order restaurant supplies.",
                "error"
            )
            return
        end

        local restaurant = GetRestaurant(restaurantId)

        if not restaurant then
            notify(src, "Restaurant not found.", "error")
            return
        end

        local requestedItems =
            type(data.items) == "table"
            and data.items
            or {}

        local normalized = {}
        local total = 0

        for _, requested in ipairs(requestedItems) do
            local catalog =
                getDeliveryCatalogItem(requested.item)

            local quantity =
                math.floor(
                    tonumber(requested.quantity) or 0
                )

            if catalog and quantity > 0 then
                quantity = math.min(
                    quantity,
                    Config.Deliveries.MaxQuantityPerItem
                        or 250
                )

                local unitPrice = math.max(
                    0,
                    math.floor(
                        tonumber(catalog.unitPrice) or 0
                    )
                )

                local lineTotal =
                    unitPrice * quantity

                total = total + lineTotal

                normalized[#normalized + 1] = {
                    item = catalog.item,
                    label = catalog.label,
                    quantity = quantity,
                    unitPrice = unitPrice,
                    total = lineTotal
                }
            end
        end

        if #normalized == 0 or total <= 0 then
            notify(
                src,
                "Your supply order is empty.",
                "error"
            )
            return
        end

        local account = restaurant.job

        if Config.Deliveries.RequireBusinessAccount then
            if GetResourceState("qb-banking")
                ~= "started"
            then
                notify(
                    src,
                    "qb-banking is not running.",
                    "error"
                )
                return
            end

            if not account or account == "" then
                notify(
                    src,
                    "This restaurant does not have a business-account job name. Set it in Business Management -> Business Account / Job Setup.",
                    "error"
                )
                return
            end

            local balance =
                deliveryBusinessBalance(account)

            if balance == nil then
                notify(
                    src,
                    "The restaurant business account could not be found.",
                    "error"
                )
                return
            end

            if balance < total then
                notify(
                    src,
                    ("Business account needs $%s but only has $%s."):format(
                        total,
                        balance
                    ),
                    "error"
                )
                return
            end

            if not deliveryRemoveBusinessMoney(
                account,
                total
            ) then
                notify(
                    src,
                    "Unable to charge the restaurant business account.",
                    "error"
                )
                return
            end
        end

        local leadMinutes = math.max(
            0,
            math.floor(
                tonumber(data.leadMinutes)
                    or tonumber(
                        Config.Deliveries.DefaultLeadMinutes
                    )
                    or 10
            )
        )

        local deliveryId = MySQL.insert.await([[
            INSERT INTO moc_deliveries
            (
                restaurant_id,
                requested_by,
                status,
                items,
                cost,
                ready_at
            )
            VALUES
            (
                ?,
                ?,
                'ordered',
                ?,
                ?,
                DATE_ADD(
                    CURRENT_TIMESTAMP,
                    INTERVAL ? MINUTE
                )
            )
        ]], {
            restaurantId,
            CID(src),
            json.encode(normalized),
            total,
            leadMinutes
        })

        if not deliveryId then
            if Config.Deliveries.RequireBusinessAccount
                and account
            then
                deliveryAddBusinessMoney(
                    account,
                    total
                )
            end

            notify(
                src,
                "Delivery creation failed. Charge refunded.",
                "error"
            )
            return
        end

        notify(
            src,
            ("Supply order #%s placed for $%s. Estimated arrival: %s minute(s)."):format(
                deliveryId,
                total,
                leadMinutes
            ),
            "success"
        )
    end
)


RegisterNetEvent("moc_restaurant:requestReceiveDelivery", function(deliveryId)
    local src = source
    deliveryId = tonumber(deliveryId)

    print(("[MOC Restaurant] Receive delivery request: player=%s delivery=%s"):format(
        tostring(src),
        tostring(deliveryId)
    ))

    if not deliveryId then
        TriggerClientEvent(
            "moc_restaurant:deliveryReceiveFailed",
            src,
            deliveryId,
            "Invalid delivery ID."
        )
        return
    end

    refreshDeliveryStatuses()

    local delivery = MySQL.single.await([[
        SELECT *
        FROM moc_deliveries
        WHERE id = ?
        LIMIT 1
    ]], { deliveryId })

    if not delivery then
        print(("[MOC Restaurant] Delivery #%s not found."):format(
            tostring(deliveryId)
        ))

        TriggerClientEvent(
            "moc_restaurant:deliveryReceiveFailed",
            src,
            deliveryId,
            "Delivery not found."
        )
        return
    end

    local restaurantId = tonumber(delivery.restaurant_id)

    print(("[MOC Restaurant] Delivery #%s status=%s restaurant=%s"):format(
        tostring(deliveryId),
        tostring(delivery.status),
        tostring(restaurantId)
    ))

    if not canReceiveDeliveryOrders(src, restaurantId) then
        TriggerClientEvent(
            "moc_restaurant:deliveryReceiveFailed",
            src,
            deliveryId,
            "You are not authorized to receive this delivery."
        )
        return
    end

    if delivery.status ~= "ready" then
        TriggerClientEvent(
            "moc_restaurant:deliveryReceiveFailed",
            src,
            deliveryId,
            ("This delivery is currently '%s', not READY."):format(
                tostring(delivery.status)
            )
        )
        return
    end

    if not nearDeliveryReceivingStation(src, restaurantId) then
        TriggerClientEvent(
            "moc_restaurant:deliveryReceiveFailed",
            src,
            deliveryId,
            "You must be at this restaurant's Delivery Receiving station."
        )
        return
    end

    local ok, items = pcall(
        json.decode,
        delivery.items or "[]"
    )

    if not ok or type(items) ~= "table" or #items == 0 then
        TriggerClientEvent(
            "moc_restaurant:deliveryReceiveFailed",
            src,
            deliveryId,
            "This delivery contains invalid item data."
        )
        return
    end

    local added = {}

    for _, item in ipairs(items) do
        local quantity = tonumber(item.quantity) or 0

        if quantity <= 0 then
            TriggerClientEvent(
                "moc_restaurant:deliveryReceiveFailed",
                src,
                deliveryId,
                "This delivery contains an invalid quantity."
            )
            return
        end

        print(("[MOC Restaurant] Adding delivery item: %sx %s"):format(
            tostring(quantity),
            tostring(item.item)
        ))

        local success = MOCInventory.AddItem(
            src,
            item.item,
            quantity,
            {
                restaurant = restaurantId,
                delivery = deliveryId
            }
        )

        if not success then
            print(("[MOC Restaurant] Inventory rejected %sx %s for delivery #%s."):format(
                tostring(quantity),
                tostring(item.item),
                tostring(deliveryId)
            ))

            for _, rollback in ipairs(added) do
                MOCInventory.RemoveItem(
                    src,
                    rollback.item,
                    rollback.quantity,
                    nil
                )
            end

            TriggerClientEvent(
                "moc_restaurant:deliveryReceiveFailed",
                src,
                deliveryId,
                "Your inventory cannot hold the full shipment, or one of the ingredient items does not exist."
            )
            return
        end

        added[#added + 1] = {
            item = item.item,
            quantity = quantity
        }
    end

    local changed = MySQL.update.await([[
        UPDATE moc_deliveries
        SET status = 'delivered',
            delivered_at = CURRENT_TIMESTAMP
        WHERE id = ?
          AND status = 'ready'
    ]], { deliveryId })

    if not changed or tonumber(changed) < 1 then
        -- Roll back inventory if SQL delivery state could not be finalized.
        for _, rollback in ipairs(added) do
            MOCInventory.RemoveItem(
                src,
                rollback.item,
                rollback.quantity,
                nil
            )
        end

        TriggerClientEvent(
            "moc_restaurant:deliveryReceiveFailed",
            src,
            deliveryId,
            "The shipment could not be finalized in the database. Items were rolled back."
        )
        return
    end

    print(("[MOC Restaurant] Delivery #%s successfully received."):format(
        tostring(deliveryId)
    ))

    TriggerClientEvent(
        "moc_restaurant:deliveryReceiveConfirmed",
        src,
        deliveryId,
        ("Delivery #%s received. Move the ingredients into restaurant storage."):format(
            deliveryId
        )
    )
end)

CreateThread(function()
    while true do
        Wait(60000)

        if Config.Deliveries
            and Config.Deliveries.Enabled
        then
            refreshDeliveryStatuses()
        end
    end
end)


CreateThread(function()
    Wait(5000)

    if Config.AutomaticBusinessSetup
        and Config.AutomaticBusinessSetup.Enabled
    then
        for _, restaurant
            in ipairs(GetRestaurants() or {})
        do
            if restaurant.job
                and restaurant.job ~= ""
            then
                ensureBusinessJobAndBanking(
                    restaurant.id
                )
            end
        end

        print("^2[MOC Restaurant]^7 Automatic business setup startup pass complete.")
    end
end)


print("^2[MOC Restaurant]^7 v2.2.8 delivery callbacks registered inside business.lua.")

CreateThread(function()
    Wait(2500)
    for _,restaurant in ipairs(GetRestaurants() or {}) do
        ensureOwner(restaurant.id)
        TriggerEvent("moc_restaurant:syncRestaurantJob",restaurant.id)
    end
    print("^2[MOC Restaurant]^7 v2.2.4 Business Management + Deliveries loaded.")
end)
