local resourceName = GetCurrentResourceName()
local supportedStyles = {
    tooltip=true, advanced=true, location=true, right=true, left=true, top_banner=true,
    advanced_right=true, top=true, center=true, standard=true, bottom_right=true,
    mission_failed=true, dead_player=true, warning=true
}

local function Capabilities()
    return NotifyResults.Ok({
        resource = resourceName,
        contract = 1,
        version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        state = 'ready',
        features = { presentation = 1, provider = 1, styles = supportedStyles }
    })
end

local function InstallProvider()
    local called, result = pcall(function()
        return exports['feather-core']:RegisterNotificationProvider('feather-notify', {
            Send = function(request)
                local presentation = {}
                for key, value in pairs(request) do
                    if key ~= 'source' then presentation[key] = value end
                end
                TriggerClientEvent('feather-notify:show.v1', request.source, presentation)
                return NotifyResults.Ok({ delivered = true, style = request.style })
            end
        }, {
            contract = 1,
            default = true,
            capabilities = { styles = supportedStyles }
        })
    end)
    return called and type(result) == 'table' and result.ok == true, result
end

exports('GetCapabilities', Capabilities)

local installing = false
local function InstallWhenCoreReady()
    if installing then return end
    installing = true
    CreateThread(function()
        while GetResourceState('feather-core') ~= 'started' do Wait(250) end
        while true do
            local called, ready = pcall(function() return exports['feather-core']:AwaitReady(0) end)
            if called and type(ready) == 'table' and ready.ok == true then break end
            Wait(250)
        end
        Wait(0)
        local installed, result = InstallProvider()
        installing = false
        if not installed then
            print(('[feather-notify] provider registration failed code=%s message=%s'):format(
                tostring(type(result) == 'table' and result.code or 'export_failed'),
                tostring(type(result) == 'table' and result.message or result)))
        end
    end)
end

InstallWhenCoreReady()
AddEventHandler('onResourceStart', function(startedResource)
    if startedResource == 'feather-core' then InstallWhenCoreReady() end
end)

RegisterCommand('NotifyContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    local capabilities = Capabilities()
    local provider = exports['feather-core']:GetProvider('notification', 'feather-notify', 1)
    local delivered = target and exports['feather-core']:SendNotification({
        source = target, style = 'right', message = 'Feather Notify provider is working.', duration = 2500
    }) or NotifyResults.Err('invalid_input', 'A connected source is required.')
    local invalid = target and exports['feather-core']:SendNotification({
        source = target, style = 'unknown', message = 'invalid'
    }) or delivered
    local tests = {
        { 'capabilities', capabilities.ok and capabilities.value.contract == 1 },
        { 'provider registered', provider.ok and provider.value.provider.owner == resourceName },
        { 'delivery envelope', delivered.ok and delivered.value.delivered == true },
        { 'invalid style rejected', invalid.ok == false and invalid.code == 'invalid_input' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[NotifyContractSmokeTest] %-24s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[NotifyContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, #tests, tostring(target or 'none')))
end, true)
