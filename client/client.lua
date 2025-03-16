local RSGCore = exports['rsg-core']:GetCoreObject()

local CHECK_RADIUS = 2.0
local BED_PROPS = {
    {
        label = "Camp Cot",
        model = `p_cot01x`,
        offset = vector3(0.0, 0.0, 0.0),
        description = "A portable camping cot for resting"
    },
    {
        label = "Simple Mattress",
        model = `p_mattress04x`,
        offset = vector3(0.0, 0.0, 0.0),
        description = "A basic mattress for sleeping outdoors"
    },
    {
        label = "Bedroll",
        model = `s_bedrollopen01x`,
        offset = vector3(0.0, 0.0, 0.0),
        description = "A compact bedroll for travelers"
    },
    {
        label = "Comfortable Bed",
        model = `p_cot01x`, -- Primary model
        secondaryModel = `p_mattress04x`, -- Secondary model
        mattressZOffset = 0.55, -- Direct Z-offset for mattress (modify this value)
        description = "A comfortable bed with cot and mattress"
    }
}

-- Variables
local deployedBed = nil
local deployedBedExtra = nil -- For the secondary object in combined bed
local deployedOwner = nil
local currentBedData = nil
local isResting = false

local function ShowBedMenu()
    local bedOptions = {}
    
    for i, bed in ipairs(BED_PROPS) do
        table.insert(bedOptions, {
            title = bed.label,
            description = bed.description,
            icon = 'fas fa-bed',
            onSelect = function()
                TriggerEvent('rsg-beds:client:placeBed', i)
            end
        })
    end

    lib.registerContext({
        id = 'bed_selection_menu',
        title = 'Select Bed Style',
        options = bedOptions
    })
    
    lib.showContext('bed_selection_menu')
end

local function RegisterBedTargeting()
    local models = {}
    for _, bed in ipairs(BED_PROPS) do
        table.insert(models, bed.model)
        if bed.secondaryModel then
            table.insert(models, bed.secondaryModel)
        end
    end

    exports['ox_target']:addModel(models, {
        {
            name = 'pickup_bed',
            event = 'rsg-beds:client:pickupBed',
            icon = "fas fa-hand",
            label = "Pack Up Bed",
            distance = 2.0,
            canInteract = function(entity)
                return not isResting
            end
        },
        {
            name = 'rest_at_bed',
            event = 'rsg-beds:client:restAtBed',
            icon = "fas fa-bed",
            label = "Rest",
            distance = 2.0,
            canInteract = function(entity)
                return not isResting
            end
        }
    })
end

RegisterNetEvent('rsg-beds:client:placeBed', function(bedIndex)
    if deployedBed then
        lib.notify({
            title = "Bed Already Placed",
            description = "You already have a bed placed.",
            type = 'error'
        })
        return
    end

    local bedData = BED_PROPS[bedIndex]
    if not bedData then return end

    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local forward = GetEntityForwardVector(PlayerPedId())
    
    local offsetDistance = 2.0
    local x = coords.x + forward.x * offsetDistance
    local y = coords.y + forward.y * offsetDistance
    local z = coords.z

    -- Load the primary model
    RequestModel(bedData.model)
    while not HasModelLoaded(bedData.model) do
        Wait(100)
    end

    -- Load the secondary model if it exists
    if bedData.secondaryModel then
        RequestModel(bedData.secondaryModel)
        while not HasModelLoaded(bedData.secondaryModel) do
            Wait(100)
        end
    end

    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    Wait(2000)
    
    -- Create the primary bed object
    local bedObject = CreateObject(bedData.model, x, y, z, true, false, false)
    PlaceObjectOnGroundProperly(bedObject)
    SetEntityHeading(bedObject, heading)
    FreezeEntityPosition(bedObject, true)
    
    deployedBed = bedObject
    currentBedData = bedData
    deployedOwner = GetPlayerServerId(PlayerId())
    
    -- If this is a combined bed, create the secondary object
    if bedData.secondaryModel then
        -- Get the updated position of the bed after PlaceObjectOnGroundProperly
        local bedCoords = GetEntityCoords(bedObject)
        
        -- Get the Z offset for the mattress (default 0.35 if not specified)
        local zOffset = bedData.mattressZOffset or 0.35
        
        -- Create the mattress with a direct Z offset from the bed's position
        local mattressObject = CreateObject(
            bedData.secondaryModel, 
            bedCoords.x, 
            bedCoords.y, 
            bedCoords.z + zOffset, -- Direct Z offset from bed position
            true, false, false
        )
        
        -- Match rotation with the bed
        SetEntityHeading(mattressObject, heading)
        
        -- Don't freeze or attach - we're going to use native SetEntityCoords
        -- for maximum control over positioning
        
        -- Store the mattress object
        deployedBedExtra = mattressObject
        
        -- Debug info
        print("Bed position: " .. vec3(bedCoords.x, bedCoords.y, bedCoords.z))
        print("Mattress position: " .. vec3(bedCoords.x, bedCoords.y, bedCoords.z + zOffset))
        print("Z offset used: " .. zOffset)
    end
    
    TriggerServerEvent('rsg-beds:server:placeBed')
    
    Wait(500)
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('rsg-beds:client:pickupBed', function()
    if not deployedBed then
        lib.notify({
            title = "No Bed!",
            description = "There's no bed to pack up.",
            type = 'error'
        })
        return
    end

    if isResting then
        lib.notify({
            title = "Cannot Pack Up",
            description = "You can't pack up the bed while resting.",
            type = 'error'
        })
        return
    end

    local ped = PlayerPedId()
    
    LocalPlayer.state:set('inv_busy', true, true)
    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    Wait(2000)

    if deployedBed then
        if deployedBedExtra then
            DeleteObject(deployedBedExtra)
            deployedBedExtra = nil
        end
        
        DeleteObject(deployedBed)
        deployedBed = nil
        currentBedData = nil
        TriggerServerEvent('rsg-beds:server:returnBed')
        deployedOwner = nil
    end

    ClearPedTasks(ped)
    LocalPlayer.state:set('inv_busy', false, true)

    lib.notify({
        title = 'Bed Packed',
        description = 'You have packed up your bed.',
        type = 'success'
    })
end)

RegisterNetEvent('rsg-beds:client:restAtBed', function()
    if isResting then return end
    
    isResting = true
    LocalPlayer.state:set('inv_busy', true, true)
    
    -- Get the bed type for enhanced benefits
    local isComfortableBed = currentBedData and currentBedData.secondaryModel ~= nil
    local restDuration = 10000 -- Base duration (10 seconds)
    local benefitMultiplier = 1.0
    
    -- Enhanced benefits for comfortable beds
    if isComfortableBed then
        benefitMultiplier = 1.5 -- 50% boost to benefits
        restDuration = 8000 -- Rest quicker (8 seconds)
    end
    
    -- Position the player properly on the bed
    local ped = PlayerPedId()
    local bedCoords = GetEntityCoords(deployedBed)
    local bedHeading = GetEntityHeading(deployedBed)
    
    local zOffset = 0.5 -- Default height above bed for player
    
    -- If comfortable bed, position player above the mattress
    if isComfortableBed and deployedBedExtra then
        local mattressCoords = GetEntityCoords(deployedBedExtra)
        -- Position player slightly above the mattress
        zOffset = 0.15 -- Lower offset since we're already above the mattress
        
        SetEntityCoordsNoOffset(ped, 
            mattressCoords.x, 
            mattressCoords.y, 
            mattressCoords.z + zOffset,
            true, true, true
        )
    else
        -- For regular beds, position player above the bed
        SetEntityCoordsNoOffset(ped, 
            bedCoords.x, 
            bedCoords.y, 
            bedCoords.z + zOffset,
            true, true, true
        )
    end
    
    -- Set player facing direction
    SetEntityHeading(ped, bedHeading + 180.0) -- Face opposite direction of bed
    
    -- Use proper sleep animation based on bed type
    local sleepScenario = isComfortableBed 
        and 'WORLD_HUMAN_SLEEP_GROUND_PILLOW' -- Better animation for comfortable bed
        or 'WORLD_HUMAN_SLEEP_GROUND_ARM'     -- Basic sleep animation
        
    TaskStartScenarioInPlace(ped, GetHashKey(sleepScenario), 0, true, false, false, false)
    
    -- Wait for the player to fully lie down before starting progress bar
    local animDelay = 10000 -- 10 seconds for animation to complete
    Wait(animDelay)
    
    -- Progress bar with heart Unicode symbol
    local label = isComfortableBed and 'Resting Comfortably' or 'Resting'
    local heartIcon = '❤️' -- Heart icon for health restoration
    
    -- Show progress bar
    if lib.progressBar then
        lib.progressBar({
            duration = restDuration,
            label = label,
            useWhileDead = false,
            canCancel = false,
            disable = {
                car = true,
                combat = true,
                move = true,
            },
            anim = {
                dict = nil, -- We're using scenario instead
                clip = nil  -- We're using scenario instead
            },
            prop = {},
            icon = heartIcon
        })
    else
        -- Fallback if lib.progressBar isn't available
        Wait(restDuration)
    end
    
    ClearPedTasks(ped)
    isResting = false
    LocalPlayer.state:set('inv_busy', false, true)
    
    -- Apply benefits from config with multiplier
    local stressReduction = math.floor(Config.RestBenefits.stressReduction * benefitMultiplier)
    local healthIncrease = math.floor(Config.RestBenefits.healthIncrease * benefitMultiplier)
    local staminaBoostDuration = math.floor(Config.RestBenefits.staminaBoostDuration * benefitMultiplier)
    
    TriggerServerEvent('hud:server:RelieveStress', stressReduction)
    
    -- Health increase
    local currentHealth = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    local newHealth = math.min(currentHealth + healthIncrease, maxHealth)
    SetEntityHealth(ped, newHealth)
    
    -- Stamina boost (if enabled)
    if Config.RestBenefits.staminaBoost then
        TriggerEvent('rsg-beds:client:applyStaminaBoost', staminaBoostDuration)
    end
    
    -- Notification with details on benefits
    local benefitText = isComfortableBed 
        and 'You feel exceptionally refreshed from the comfortable bed!'
        or 'You feel refreshed from resting'
    
    lib.notify({
        title = 'Well Rested',
        description = benefitText,
        type = 'success'
    })
end)

-- Stamina boost implementation
RegisterNetEvent('rsg-beds:client:applyStaminaBoost', function(duration)
    -- Implement your stamina boost logic here
    -- This is a placeholder and should be adapted to your stamina system
    TriggerEvent('stamina:applyBoost', duration)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if deployedBedExtra then
        DeleteObject(deployedBedExtra)
    end
    
    if deployedBed then
        DeleteObject(deployedBed)
    end
end)

CreateThread(function()
    RegisterBedTargeting()
end)

RegisterNetEvent('rsg-beds:client:openBedMenu', function()
    ShowBedMenu()
end)