ESX = exports["es_extended"]:getSharedObject()

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
