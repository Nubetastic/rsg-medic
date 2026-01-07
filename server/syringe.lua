local RSGCore = exports['rsg-core']:GetCoreObject()

-- Server event to handle syringe revive
RegisterNetEvent('rsg-medic:server:SyringeRevivePlayer', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    -- Check if the reviver is still alive
    if Player.PlayerData.metadata.isdead then
        TriggerClientEvent('ox_lib:notify', src, {title = "You cannot revive while dead", type = 'error', duration = 5000 })
        return
    end

    if not Patient then 
        TriggerClientEvent('ox_lib:notify', src, {title = "Revive failed - player not found", type = 'error', duration = 5000 })
        return 
    end
    
    -- Check if the patient is actually dead
    if not Patient.PlayerData.metadata.isdead then
        TriggerClientEvent('ox_lib:notify', src, {title = "Player is not dead", type = 'error', duration = 5000 })
        return
    end
    
    -- Check if player has the syringe item
    local hasItem = Player.Functions.GetItemByName(SyringeConfig.ItemName)
    if not hasItem then
        TriggerClientEvent('ox_lib:notify', src, {title = "You don't have a syringe", type = 'error', duration = 5000 })
        return
    end
    
    -- Remove the syringe item only when we're sure the revive will happen
    if Player.Functions.RemoveItem(SyringeConfig.ItemName, 1) then
        -- Notify the player that the item was used
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[SyringeConfig.ItemName], 'remove')
        
        -- Trigger the revive on the patient
        TriggerClientEvent('rsg-medic:client:SyringeRevive', Patient.PlayerData.source)
        
        -- Notify the player that the revive was successful
        TriggerClientEvent('ox_lib:notify', src, {title = "Revive successful", type = 'success', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', src, {title = "Failed to use syringe", type = 'error', duration = 5000 })
    end
end)

-- Callback to get player status (for ox_target)
RSGCore.Functions.CreateCallback('rsg-medic:server:GetPlayerStatus', function(source, cb, playerId)
    local Player = RSGCore.Functions.GetPlayer(playerId)
    
    if Player then
        cb({
            metadata = Player.PlayerData.metadata
        })
    else
        cb(nil)
    end
end)