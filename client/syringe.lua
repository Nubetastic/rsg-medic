local RSGCore = exports['rsg-core']:GetCoreObject()
local syringeCooldown = false

---------------------------------------------------------------------
-- Exportable PlayerRevive function
---------------------------------------------------------------------

exports('PlayerRevive', function()
    PlayerReviveCall()
end)


function PlayerReviveCall()
    -- This function replicates the functionality of 'rsg-medic:client:playerRevive' event
    -- but is available as an export for other resources to use directly
    local pos = GetEntityCoords(cache.ped, true)

    DoScreenFadeOut(500)

    Wait(1000)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, Config.MedicReviveHealth) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 0) -- SetAttributeCoreValue
    LocalPlayer.state:set('health', math.round(Config.MaxHealth * (Config.MedicReviveHealth / 100)), true)

    -- Reset Outlaw Status on respawn
    if Config.ResetOutlawStatus then
        TriggerServerEvent('rsg-prison:server:resetoutlawstatus')
    end

    -- Reset Death Timer by triggering an event to client.lua
    -- This ensures we properly reset the timer display and respawn code
    TriggerEvent('rsg-medic:client:resetDeathTimer')

    Wait(1500)

    DoScreenFadeIn(1800)

    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
    LocalPlayer.state:set('isDead', false, true)
end

-- Function to play the syringe animation
function PlayAnimSyringe(propName)
    local playerCoords = GetEntityCoords(cache.ped)
    local dict = "mech_revive@unapproved"
    local anim = "revive"

    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end

    local hashItem = GetHashKey(propName)
    local prop = CreateObject(hashItem, playerCoords.x, playerCoords.y, playerCoords.z, true, true, false)
    local boneIndex = GetEntityBoneIndexByName(cache.ped, "SKEL_R_HAND")

    ClearPedTasks(cache.ped)
    ClearPedSecondaryTask(cache.ped)
    ClearPedTasksImmediately(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    TaskPlayAnim(cache.ped, dict, anim, 1.0, 1.0, -1, 0, false, false, false)
    AttachEntityToEntity(prop, cache.ped, boneIndex, 0.10, 0.0, 0.03, 0.0, -80.0, -90.0, true, true, false, true, 1, true)
    
    Wait(3000)

    DeleteObject(prop)
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
end

-- Function to start the syringe cooldown
local function StartSyringeCooldown()
    syringeCooldown = true
    
    Citizen.CreateThread(function()
        Citizen.Wait(SyringeConfig.CooldownTime * 1000)
        syringeCooldown = false
    end)
end

-- Function to handle the revive process
local function HandleSyringeRevive(targetId)
    if syringeCooldown then
        lib.notify({ title = SyringeConfig.Notifications.CooldownActive, type = 'error', duration = 5000 })
        return
    end
    
    -- Start the revive process
    lib.notify({ title = SyringeConfig.Notifications.ReviveInProgress, type = 'info', duration = SyringeConfig.ReviveTime })
    
    -- Create a thread to check if player dies during the revive process
    local reviveInProgress = true
    local reviveSuccessful = false
    
    -- Also check if the target player is still dead
    local targetStillDead = true
    
    -- Monitor player health during revive
    Citizen.CreateThread(function()
        while reviveInProgress do
            if LocalPlayer.state.isDead or GetEntityHealth(PlayerPedId()) == 0 then
                reviveInProgress = false
                lib.notify({ title = SyringeConfig.Notifications.ReviveFailed, type = 'error', duration = 5000 })
                return
            end
            
            -- Check if target is still dead (optional, requires server callback)
            RSGCore.Functions.TriggerCallback('rsg-medic:server:GetPlayerStatus', function(result)
                if result and not result.metadata.isdead then
                    targetStillDead = false
                end
            end, targetId)
            
            Citizen.Wait(100)
        end
    end)
    
    -- Play the animation
    PlayAnimSyringe(SyringeConfig.PropName)
    
    -- Check if player is still alive after animation and target is still dead
    if not LocalPlayer.state.isDead and GetEntityHealth(PlayerPedId()) > 0 and targetStillDead then
        -- Trigger the revive on the server
        -- We pass the target player ID to the server for revive
        -- The server will handle removing the item only on successful revive
        TriggerServerEvent('rsg-medic:server:SyringeRevivePlayer', targetId)
        reviveSuccessful = true
    elseif not targetStillDead then
        lib.notify({ title = "Player is already alive", type = 'error', duration = 5000 })
    end
    
    reviveInProgress = false
    
    -- Start cooldown only if revive was successful
    if reviveSuccessful then
        StartSyringeCooldown()
    end
end

-- Event handler for receiving a syringe revive
RegisterNetEvent('rsg-medic:client:SyringeRevive')
AddEventHandler('rsg-medic:client:SyringeRevive', function()
    -- Check if player is still dead before proceeding with revive
    if not LocalPlayer.state.isDead and GetEntityHealth(cache.ped) > 0 then
        lib.notify({ title = SyringeConfig.Notifications.ReviveFailed, type = 'error', duration = 5000 })
        return
    end
    
    -- Use our local PlayerReviveCall function directly
    PlayerReviveCall()
    
    -- Notify player
    lib.notify({ title = SyringeConfig.Notifications.ReviveComplete, type = 'success', duration = 5000 })
end)

-- Initialize ox_target for dead players
CreateThread(function()
    -- Add target option for dead players
    exports.ox_target:addGlobalPlayer({
        {
            name = 'revive_player',
            icon = 'fas fa-syringe',
            label = 'Revive Player',
            canInteract = function(entity, distance, coords, name, bone)
                -- Check if target player is dead
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                local player = RSGCore.Functions.GetPlayerData()
                
                -- Get target player data
                local targetPlayer = nil
                RSGCore.Functions.TriggerCallback('rsg-medic:server:GetPlayerStatus', function(result)
                    targetPlayer = result
                end, targetId)
                
                -- Wait for the callback to return
                local timeout = 50
                while targetPlayer == nil and timeout > 0 do
                    Wait(10)
                    timeout = timeout - 1
                end
                
                -- Check if player is within range and target is dead
                if distance <= SyringeConfig.ReviveDistance and targetPlayer and targetPlayer.metadata.isdead then
                    return true
                end
                
                return false
            end,
            onSelect = function(data)
                -- Get target player ID
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                
                -- Handle the revive process
                HandleSyringeRevive(targetId)
            end
        }
    })
end)