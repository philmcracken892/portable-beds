local RSGCore = exports['rsg-core']:GetCoreObject()

local CHECK_RADIUS = 2.0
local BED_PROPS = {
    {
        label = "fur bedroll",
        model = `s_bedrollfurlined01x`,
        offset = vector3(0.0, 0.0, 0.0),
        description = "A portable bedroll lined for resting"
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
        label = "indian bed sheets",
        model = `p_bedindian04x`,
        offset = vector3(0.0, 0.0, 0.0),
        description = "A compact bed for travelers"
    }
	
    
}

-- Variables
local deployedBed = nil
local deployedBedExtra = nil 
local deployedOwner = nil



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
    
    
    local offsetDistance = 1.0
    local x = coords.x + forward.x * offsetDistance
    local y = coords.y + forward.y * offsetDistance
    local z = coords.z
    
    RequestModel(bedData.model)
    while not HasModelLoaded(bedData.model) do
        Wait(100)
    end
    
    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    Wait(2000)
    
    local bedObject = CreateObject(bedData.model, x, y, z, true, false, false)
    PlaceObjectOnGroundProperly(bedObject)
    SetEntityHeading(bedObject, heading)
    FreezeEntityPosition(bedObject, true)
    
    deployedBed = bedObject
    currentBedData = bedData
    deployedOwner = GetPlayerServerId(PlayerId())
    
   
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
