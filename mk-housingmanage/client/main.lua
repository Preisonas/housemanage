ESX = exports["es_extended"]:getSharedObject()

local function formatDue(dueAt)
    if dueAt then
        local num = tonumber(dueAt)
        if num then
            return ('Due at: %s'):format(num)
        end
    end
    return 'No tax due set'
end

local function notify(msg)
    ESX.ShowNotification(msg)
end

local function openHousingTablet()
    ESX.TriggerServerCallback('mk-housingmanage:getPlayerHouse', function(data)
        if not data or not data.houseId then
            notify('You do not own a house.')
            return
        end

        local houseId = data.houseId

        ESX.TriggerServerCallback('mk-housing:getHouseState', function(state)
            if not state then
                notify('House not found.')
                return
            end

            if not state.isOwner then
                notify('You are not the owner of this house.')
                return
            end

            local locked = state.locked or false
            local menuId = 'mk_housing_tablet'
            local dueAt = tonumber(state.dueAt)
            local dueText = formatDue(dueAt)
            local dailyTax = math.max(100, math.floor((state.price or 0) * 0.01))
            local residentCount = (state.residents and #state.residents) or 0
            local residentsMenuId = 'mk_housing_residents'

            local residentOptions = {}
            if state.residents and #state.residents > 0 then
                for i = 1, #state.residents do
                    local identifier = tostring(state.residents[i])
                    local label = identifier:sub(1, 12)
                    residentOptions[#residentOptions + 1] = {
                        title = ('Remove %s'):format(label),
                        description = identifier,
                        onSelect = function()
                            TriggerServerEvent('mk-housing:removeResident', houseId, identifier)
                        end
                    }
                end
            else
                residentOptions[#residentOptions + 1] = {
                    title = 'No residents',
                    disabled = true
                }
            end

            lib.registerContext({
                id = residentsMenuId,
                title = 'Residents',
                options = residentOptions
            })

            local infoMenuId = 'mk_housing_info'
            lib.registerContext({
                id = infoMenuId,
                title = ('House #%s Info'):format(state.houseNumber or houseId),
                options = {
                    {
                        title = 'Taxes',
                        description = ('Due: %s | Daily: $%s'):format(dueText, dailyTax),
                        disabled = true
                    },
                    {
                        title = 'Residents',
                        description = ('%s / %s'):format(residentCount, state.maxResidents or '?'),
                        menu = residentsMenuId
                    },
                    {
                        title = 'Garage',
                        description = ('Spots: %s'):format(state.garageSpaces or '?'),
                        disabled = true
                    }
                }
            })

            local workshopMenuId = 'mk_housing_workshop'
            lib.registerContext({
                id = workshopMenuId,
                title = 'Workshop Upgrades',
                options = {
                    {
                        title = 'Level 1 Upgrade',
                        description = 'Requires: $100 bank, Water x5, Lockpick x1',
                        onSelect = function()
                            TriggerServerEvent('mk-housing:workshopUpgrade', houseId, 1)
                        end
                    }
                }
            })

            lib.registerContext({
                id = menuId,
                title = ('House #%s'):format(state.houseNumber or houseId),
                options = {
                    {
                        title = state.street or 'Unknown street',
                        description = (state.ownerName and ('Owner: ' .. state.ownerName) or 'Owned') .. ' | Due: ' .. dueText,
                        disabled = true
                    },
                    {
                        title = 'Information',
                        description = 'Taxes, residents, garage',
                        menu = infoMenuId
                    },
                    {
                        title = locked and 'Unlock house' or 'Lock house',
                        description = locked and 'Currently locked' or 'Currently unlocked',
                        onSelect = function()
                            TriggerServerEvent('mk-housing:setLocked', houseId, not locked)
                        end
                    },
                    {
                        title = 'Add resident',
                        description = 'Allow another player to enter when unlocked',
                        onSelect = function()
                            local input = lib.inputDialog('Add Resident', {
                                { type = 'number', label = 'Player ID', placeholder = 'Server ID', required = true }
                            })
                            if input and input[1] then
                                TriggerServerEvent('mk-housing:addResident', houseId, tonumber(input[1]))
                            end
                        end
                    },
                    {
                        title = 'Pay taxes',
                        description = ('Pay days at $500/day (current daily: $%s)'):format(dailyTax),
                        onSelect = function()
                            local input = lib.inputDialog('Pay Taxes', {
                                { type = 'number', label = 'Days to pay', placeholder = 'e.g. 1', required = true, min = 1, max = 30 }
                            })
                            if input and input[1] then
                                local days = math.floor(tonumber(input[1]) or 0)
                                if days > 0 then
                                    TriggerServerEvent('mk-housing:payTaxes', houseId, days)
                                end
                            end
                        end
                    },
                    {
                        title = 'Workshop',
                        description = 'Upgrade options',
                        menu = workshopMenuId
                    }
                }
            })

            lib.showContext(menuId)
        end, houseId)
    end)
end

RegisterCommand('housingtablet', function()
    openHousingTablet()
end, false)
