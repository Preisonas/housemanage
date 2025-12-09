-- mk-housingmanage Client Script
-- React UI integration for housing management tablet

ESX = exports["es_extended"]:getSharedObject()

local isUIOpen = false
local currentHouseId = nil

-- Notify helper
local function notify(msg)
    ESX.ShowNotification(msg)
end

-- Open the housing UI (React version)
local function openHousingUI()
    if isUIOpen then return end
    
    ESX.TriggerServerCallback('mk-housingmanage:getPlayerHouses', function(houses)
        if not houses or #houses == 0 then
            notify('You do not own any houses.')
            return
        end
        
        isUIOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openUI',
            data = { houses = houses }
        })
    end)
end

-- Close the housing UI
local function closeHousingUI()
    isUIOpen = false
    currentHouseId = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
end

-- NUI Callbacks

RegisterNUICallback('closeUI', function(data, cb)
    closeHousingUI()
    cb({ success = true })
end)

RegisterNUICallback('getPlayerHouses', function(data, cb)
    ESX.TriggerServerCallback('mk-housingmanage:getPlayerHouses', function(houses)
        cb({ houses = houses or {} })
    end)
end)

RegisterNUICallback('selectHouse', function(data, cb)
    local houseId = data.houseId
    currentHouseId = houseId
    
    -- Use server callback to get formatted data (os.date works on server)
    ESX.TriggerServerCallback('mk-housingmanage:getHouseDetails', function(result)
        cb(result)
    end, houseId)
end)

RegisterNUICallback('toggleLock', function(data, cb)
    local houseId = data.houseId
    local locked = data.locked
    
    TriggerServerEvent('mk-housing:setLocked', houseId, locked)
    
    -- Play lock/unlock sound
    if locked then
        PlaySoundFrontend(-1, "DOOR_LOCK", "HUD_MINI_GAME_SOUNDSET", true)
    else
        PlaySoundFrontend(-1, "DOOR_UNLOCK", "HUD_MINI_GAME_SOUNDSET", true)
    end
    
    cb({ success = true })
end)

RegisterNUICallback('addResident', function(data, cb)
    local houseId = data.houseId
    local playerId = tonumber(data.playerId)
    
    if not playerId then
        cb({ success = false, error = 'Invalid player ID' })
        return
    end
    
    ESX.TriggerServerCallback('mk-housingmanage:addResident', function(success, residentData, errorMsg)
        if success then
            PlaySoundFrontend(-1, "CHALLENGE_UNLOCKED", "HUD_AWARDS", true)
            cb({ success = true, resident = residentData })
        else
            cb({ success = false, error = errorMsg or 'Failed to add resident' })
        end
    end, houseId, playerId)
end)

RegisterNUICallback('removeResident', function(data, cb)
    local houseId = data.houseId
    local residentId = data.residentId
    
    TriggerServerEvent('mk-housing:removeResident', houseId, tostring(residentId))
    cb({ success = true })
end)

RegisterNUICallback('payTax', function(data, cb)
    local houseId = data.houseId
    local days = data.days
    
    ESX.TriggerServerCallback('mk-housingmanage:payTax', function(success, newPaidUntil, errorMsg)
        if success then
            PlaySoundFrontend(-1, "PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET", true)
            cb({ 
                success = true, 
                newPaidUntil = newPaidUntil or 'N/A'
            })
        else
            cb({ success = false, error = errorMsg or 'Failed to pay tax' })
        end
    end, houseId, days)
end)

RegisterNUICallback('getWorkshopLevels', function(data, cb)
    local houseId = data.houseId
    
    ESX.TriggerServerCallback('mk-housingmanage:getWorkshopLevels', function(levels)
        cb({ levels = levels or {} })
    end, houseId)
end)

RegisterNUICallback('startConstruction', function(data, cb)
    local houseId = data.houseId
    local level = data.level
    
    ESX.TriggerServerCallback('mk-housingmanage:startConstruction', function(success, errorMsg)
        if success then
            PlaySoundFrontend(-1, "PROPERTY_PURCHASE", "HUD_AWARDS", true)
            cb({ success = true })
        else
            cb({ success = false, error = errorMsg or 'Failed to start construction' })
        end
    end, houseId, level)
end)

-- Escape key to close UI
CreateThread(function()
    while true do
        Wait(0)
        if isUIOpen then
            DisableControlAction(0, 200, true) -- Disable pause menu
            if IsControlJustReleased(0, 200) then -- ESC
                closeHousingUI()
            end
        end
    end
end)

-- Command to open housing tablet
RegisterCommand('housingtablet', function()
    openHousingUI()
end, false)

-- Keybind (optional)
RegisterKeyMapping('housingtablet', 'Open Housing Tablet', 'keyboard', 'F7')

-- Event to open UI from other scripts
RegisterNetEvent('mk-housingmanage:openUI')
AddEventHandler('mk-housingmanage:openUI', function()
    openHousingUI()
end)

-- Event to refresh data when something changes
RegisterNetEvent('mk-housing:refreshData')
AddEventHandler('mk-housing:refreshData', function()
    if isUIOpen and currentHouseId then
        ESX.TriggerServerCallback('mk-housingmanage:getHouseDetails', function(result)
            if result and result.house then
                SendNUIMessage({
                    action = 'updateHouse',
                    data = result
                })
            end
        end, currentHouseId)
    end
end)
