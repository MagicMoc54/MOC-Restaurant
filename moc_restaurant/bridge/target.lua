MOCTarget = {}

function MOCTarget.GetSystem()
    if Config.Target ~= "auto" then
        return Config.Target
    end

    if GetResourceState("ox_target") == "started" then
        return "ox_target"
    end

    if GetResourceState("qb-target") == "started" then
        return "qb-target"
    end

    return nil
end
