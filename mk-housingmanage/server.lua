-- mk-housingmanage Server Script
-- Server-side logic for React UI housing management

ESX = exports["es_extended"]:getSharedObject()

-- Config
local Config = {
    TaxPerDay = 500, -- Default tax per day
    MaxResidents = 4
}

local function EnsureWorkshopColumn()
    -- Ensure mk_houses has workshop_level column (safety for old schemas)
    MySQL.Async.fetchAll("SHOW COLUMNS FROM mk_houses LIKE 'workshop_level'", {}, function(result)
        if not result or not result[1] then
            MySQL.Async.execute("ALTER TABLE mk_houses ADD COLUMN workshop_level INT DEFAULT 0", {})
        end
    end)
end

EnsureWorkshopColumn()

-- Get all houses owned by a player (for house selection screen)
ESX.RegisterServerCallback('mk-housingmanage:getPlayerHouses', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({})
        return
    end

    -- Query mk_houses table (from mk-housing dependency)
    MySQL.Async.fetchAll('SELECT * FROM mk_houses WHERE owner_identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier
    }, function(houses)
        if not houses or #houses == 0 then
            cb({})
            return
        end

        local formattedHouses = {}
        for _, house in ipairs(houses) do
            -- Get resident count
            local residentCount = 0
        if house.residents then
            local residents = json.decode(house.residents)
            if residents then
                residentCount = #residents
            end
        end
            
            local dailyTax = math.max(100, math.floor((house.price or 0) * 0.01))
            local image = house.image_url or 'html/placeholder.svg'

            table.insert(formattedHouses, {
                id = house.id,
                address = house.street or house.label or ('House #' .. tostring(house.id)),
                area = house.area or 'Unknown Area',
                price = house.price or 0,
                garageSpots = house.garage_spaces or house.garageSpaces or 1,
                maxResidents = house.max_residents or house.maxResidents or Config.MaxResidents,
                currentResidents = residentCount,
                paidUntil = house.due_at and os.date('%d.%m.%Y', house.due_at) or 'N/A',
                paidTime = house.due_at and os.date('%H:%M', house.due_at) or '',
                isLocked = house.locked == 1 or house.locked == true,
                ownerName = xPlayer.getName(),
                dailyTaxCost = dailyTax,
                houseNumber = house.house_number or house.id,
                imageUrl = image
            })
        end
        
        cb(formattedHouses)
    end)
end)

-- Get house details (formatted for UI)
ESX.RegisterServerCallback('mk-housingmanage:getHouseDetails', function(source, cb, houseId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({ house = nil, residents = {} })
        return
    end

    MySQL.Async.fetchAll('SELECT * FROM mk_houses WHERE id = @id', {
        ['@id'] = houseId
    }, function(houses)
        if not houses or #houses == 0 then
            cb({ house = nil, residents = {} })
            return
        end
        
        local house = houses[1]
        local residents = {}
        local residentCount = 0
        
        if house.residents then
            local resData = json.decode(house.residents)
            if resData then
                for i, entry in ipairs(resData) do
                    local identifier = entry.identifier or entry
                    local name = entry.name or identifier:sub(1, 12)
                    local movedIn = entry.movedIn or entry.moved_in or 'Unknown'
                    residentCount = residentCount + 1
                    table.insert(residents, {
                        id = identifier,
                        name = name,
                        surname = '',
                        movedIn = movedIn
                    })
                end
            end
        end
        
        local dailyTax = math.max(100, math.floor((house.price or 0) * 0.01))
        local image = house.image_url or 'html/placeholder.svg'
        
        local houseData = {
            id = house.id,
            address = house.street or house.label or ('House #' .. tostring(house.id)),
            area = house.area or 'Unknown Area',
            price = house.price or 0,
            garageSpots = house.garage_spaces or house.garageSpaces or 1,
            maxResidents = house.max_residents or house.maxResidents or 4,
            currentResidents = residentCount,
            paidUntil = house.due_at and os.date('%d.%m.%Y', house.due_at) or 'N/A',
            paidTime = house.due_at and os.date('%H:%M', house.due_at) or '',
            isLocked = house.locked == 1 or house.locked == true,
            ownerName = xPlayer.getName(),
            dailyTaxCost = dailyTax,
            houseNumber = house.house_number or house.id,
            imageUrl = image
        }
        
        cb({ house = houseData, residents = residents })
    end)
end)

-- Get player's single house (for compatibility with original script)
ESX.RegisterServerCallback('mk-housingmanage:getPlayerHouse', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(nil)
        return
    end

    MySQL.Async.fetchScalar('SELECT id FROM mk_houses WHERE owner_identifier = @identifier LIMIT 1', {
        ['@identifier'] = xPlayer.identifier
    }, function(houseId)
        if not houseId then
            cb(nil)
            return
        end
        cb({ houseId = houseId })
    end)
end)

-- Add resident to house
ESX.RegisterServerCallback('mk-housingmanage:addResident', function(source, cb, houseId, playerId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local targetPlayer = ESX.GetPlayerFromId(playerId)
    
    if not xPlayer then
        cb(false, nil, 'Invalid source')
        return
    end
    
    if not targetPlayer then
        cb(false, nil, 'Player not found or not online')
        return
    end
    
    -- Verify ownership
    MySQL.Async.fetchAll('SELECT * FROM mk_houses WHERE id = @id AND owner_identifier = @owner', {
        ['@id'] = houseId,
        ['@owner'] = xPlayer.identifier
    }, function(houses)
        if not houses or #houses == 0 then
            cb(false, nil, 'You do not own this house')
            return
        end
        
        local house = houses[1]
        local residents = {}
        if house.residents then
            residents = json.decode(house.residents) or {}
        end
        
        local maxResidents = house.max_residents or house.maxResidents or Config.MaxResidents
        if #residents >= maxResidents then
            cb(false, nil, 'Maximum residents reached')
            return
        end
        
        -- Check if already a resident
        local targetIdentifier = targetPlayer.identifier
        for _, res in ipairs(residents) do
            if res == targetIdentifier then
                cb(false, nil, 'Player is already a resident')
                return
            end
        end
        
        -- Add resident
        table.insert(residents, targetIdentifier)
        
        MySQL.Async.execute('UPDATE mk_houses SET residents = @residents WHERE id = @id', {
            ['@residents'] = json.encode(residents),
            ['@id'] = houseId
        }, function()
            cb(true, {
                id = #residents,
                name = targetPlayer.getName():sub(1, 12),
                surname = '',
                movedIn = os.date('%d.%m.%Y')
            }, nil)
            
            -- Notify target player
            TriggerClientEvent('esx:showNotification', playerId, 'You have been added as a resident to a house!')
        end)
    end)
end)

-- Pay house tax
ESX.RegisterServerCallback('mk-housingmanage:payTax', function(source, cb, houseId, days)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false, nil, 'Invalid source')
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM mk_houses WHERE id = @id AND owner_identifier = @owner', {
        ['@id'] = houseId,
        ['@owner'] = xPlayer.identifier
    }, function(houses)
        if not houses or #houses == 0 then
            cb(false, nil, 'House not found')
            return
        end
        
        local house = houses[1]
        local dailyTax = math.max(100, math.floor((house.price or 0) * 0.01))
        local totalCost = dailyTax * days
        
        -- Check bank account
        local bankMoney = xPlayer.getAccount('bank').money
        if bankMoney < totalCost then
            cb(false, nil, 'Insufficient funds in bank')
            return
        end
        
        -- Deduct money
        xPlayer.removeAccountMoney('bank', totalCost, 'Housing tax payment')
        
        -- Calculate new due date
        local currentDue = house.due_at or os.time()
        if currentDue < os.time() then
            currentDue = os.time()
        end
        local newDueAt = currentDue + (days * 24 * 60 * 60)
        
        MySQL.Async.execute('UPDATE mk_houses SET due_at = @dueAt WHERE id = @id', {
            ['@dueAt'] = newDueAt,
            ['@id'] = houseId
        }, function()
            local formattedDate = os.date('%d.%m.%Y %H:%M', newDueAt)
            cb(true, formattedDate, nil)
        end)
    end)
end)

-- Get workshop levels
ESX.RegisterServerCallback('mk-housingmanage:getWorkshopLevels', function(source, cb, houseId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({})
        return
    end
    
    local bankMoney = xPlayer.getAccount('bank').money
    
    MySQL.Async.fetchScalar('SELECT workshop_level FROM mk_houses WHERE id = @id', {
        ['@id'] = houseId
    }, function(workshopLevel)
        workshopLevel = workshopLevel or 0
        
        -- Get inventory items for requirements
        local waterCount = GetItemCount(xPlayer, 'water')
        local lockpickCount = GetItemCount(xPlayer, 'lockpick')
        local materialsCount = GetItemCount(xPlayer, 'construction_materials')
        local equipmentCount = GetItemCount(xPlayer, 'construction_equipment')
        
        local levels = {
            {
                level = 1,
                name = 'Basic Workshop',
                description = 'Home workshop for creating items of basic complexity.',
                availableItems = {'P.C.C.I Level 1', 'Server System Level 1', 'Encryption Level 1', 'Electronic Door Cable', 'Turbo Decoder', 'ECU Programmer'},
                buildTime = '6 hours',
                requirements = {
                    { id = 'money', name = 'Bank Account', current = bankMoney, required = 100, isMet = bankMoney >= 100 },
                    { id = 'water', name = 'Water', current = waterCount, required = 5, isMet = waterCount >= 5 },
                    { id = 'lockpick', name = 'Lockpick', current = lockpickCount, required = 1, isMet = lockpickCount >= 1 }
                },
                isAvailable = workshopLevel == 0,
                isUnlocked = workshopLevel >= 1
            },
            {
                level = 2,
                name = 'Advanced Workshop',
                description = 'Advanced workshop for complex manufacturing.',
                availableItems = {'P.C.C.I Level 2', 'Server System Level 2', 'Encryption Level 2'},
                buildTime = '12 hours',
                requirements = {
                    { id = 'money', name = 'Bank Account', current = bankMoney, required = 50000, isMet = bankMoney >= 50000 },
                    { id = 'materials', name = 'Construction Materials', current = materialsCount, required = 24, isMet = materialsCount >= 24 },
                    { id = 'equipment', name = 'Construction Equipment', current = equipmentCount, required = 15, isMet = equipmentCount >= 15 }
                },
                isAvailable = workshopLevel == 1,
                isUnlocked = workshopLevel >= 2
            },
            {
                level = 3,
                name = 'Professional Workshop',
                description = 'Professional workshop for high-end production.',
                availableItems = {'P.C.C.I Level 3', 'Server System Level 3', 'Advanced Electronics'},
                buildTime = '24 hours',
                requirements = {
                    { id = 'money', name = 'Bank Account', current = bankMoney, required = 150000, isMet = bankMoney >= 150000 },
                    { id = 'materials', name = 'Construction Materials', current = materialsCount, required = 48, isMet = materialsCount >= 48 },
                    { id = 'equipment', name = 'Construction Equipment', current = equipmentCount, required = 30, isMet = equipmentCount >= 30 }
                },
                isAvailable = workshopLevel == 2,
                isUnlocked = workshopLevel >= 3
            }
        }
        
        cb(levels)
    end)
end)

-- Start workshop construction
ESX.RegisterServerCallback('mk-housingmanage:startConstruction', function(source, cb, houseId, level)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false, 'Invalid source')
        return
    end
    
    local bankMoney = xPlayer.getAccount('bank').money
    
    -- Level 1 requirements: $100, Water x5, Lockpick x1
    -- Level 2 requirements: $50000, Construction Materials x24, Construction Equipment x15
    -- Level 3 requirements: $150000, Construction Materials x48, Construction Equipment x30
    
    local requirements = {
        [1] = { money = 100, items = { { name = 'water', count = 5 }, { name = 'lockpick', count = 1 } } },
        [2] = { money = 50000, items = { { name = 'construction_materials', count = 24 }, { name = 'construction_equipment', count = 15 } } },
        [3] = { money = 150000, items = { { name = 'construction_materials', count = 48 }, { name = 'construction_equipment', count = 30 } } }
    }
    
    local req = requirements[level]
    if not req then
        cb(false, 'Invalid workshop level')
        return
    end
    
    -- Check money
    if bankMoney < req.money then
        cb(false, 'Insufficient funds')
        return
    end
    
    -- Check items
    for _, item in ipairs(req.items) do
        if GetItemCount(xPlayer, item.name) < item.count then
            cb(false, ('Not enough %s'):format(item.name))
            return
        end
    end
    
    -- Deduct money and items
    xPlayer.removeAccountMoney('bank', req.money, 'Workshop upgrade')
    for _, item in ipairs(req.items) do
        xPlayer.removeInventoryItem(item.name, item.count)
    end
    
    -- Update workshop level
    MySQL.Async.execute('UPDATE mk_houses SET workshop_level = @level WHERE id = @id', {
        ['@level'] = level,
        ['@id'] = houseId
    }, function()
        cb(true, nil)
    end)
end)

-- Helper function to get item count
function GetItemCount(xPlayer, itemName)
    local item = xPlayer.getInventoryItem(itemName)
    return item and item.count or 0
end
