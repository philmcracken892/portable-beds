local RSGCore = exports['rsg-core']:GetCoreObject()

-- Bed item setup
RSGCore.Functions.CreateUseableItem("bedroll", function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    TriggerClientEvent('rsg-beds:client:openBedMenu', source)
    -- RemoveItem should be triggered after successful bed placement
end)

-- Return bed to inventory
RegisterNetEvent('rsg-beds:server:returnBed', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.AddItem("bedroll", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["bed"], "add")
end)

RegisterNetEvent('rsg-beds:server:placeBed', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.RemoveItem("bedroll", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["bed"], "remove")
end)