MOCAnimations = {}

local function loadDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

function MOCAnimations.Play(key, duration)
    local anim = Config.Animations[key]
    if not anim then return end

    loadDict(anim.dict)

    TaskPlayAnim(
        PlayerPedId(),
        anim.dict,
        anim.clip,
        8.0,
        -8.0,
        duration or 2500,
        49,
        0,
        false,
        false,
        false
    )
end
