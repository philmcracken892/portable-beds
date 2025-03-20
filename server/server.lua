local RSGCore = exports['rsg-core']:GetCoreObject()


RSGCore.Functions.CreateUseableItem("bedroll", function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    TriggerClientEvent('rsg-beds:client:openBedMenu', source)
   
end)


RegisterNetEvent('rsg-beds:server:returnBed', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.AddItem("bedroll", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["bedroll"], "add")
end)

RegisterNetEvent('rsg-beds:server:placeBed', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.RemoveItem("bedroll", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["bedroll"], "remove")
end)
