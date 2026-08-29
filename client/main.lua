local styles = { tooltip=true, advanced=true, location=true, right=true, left=true, top_banner=true,
    advanced_right=true, top=true, center=true, standard=true, bottom_right=true,
    mission_failed=true, dead_player=true, warning=true }
local fields = { style=true, message=true, title=true, duration=true, location=true, dictionary=true,
    icon=true, color=true, quality=true, audioSource=true, audioName=true }

local function Buffer(size) return string.rep('\0', math.max(41, size)) end
local function Set(buffer, offset, format, value)
    local packed, first = string.pack('<' .. format, value), offset + 1
    return buffer:sub(1, first - 1) .. packed .. buffer:sub(first + #packed)
end
local function Literal(value)
    return Citizen.InvokeNative(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', tostring(value or ''), Citizen.ResultAsLong())
end
local function Options(duration) return Set(Buffer(56), 0, 'i4', duration) end
local function Content(size, values)
    local content = Buffer(size)
    for _, value in ipairs(values) do content = Set(content, value[1], value[2], value[3]) end
    return content
end

local function Validate(request)
    if type(request) ~= 'table' then return NotifyResults.Err('invalid_input', 'Notification request must be a table.') end
    for key in pairs(request) do
        if not fields[key] then return NotifyResults.Err('invalid_input', 'Unknown notification field.', { field=key }) end
    end
    local value = {}
    value.style = request.style or 'right'
    if not styles[value.style] then return NotifyResults.Err('invalid_input', 'Notification style is unsupported.', { style=value.style }) end
    if type(request.message) ~= 'string' or request.message == '' or #request.message > Config.maxMessageLength then
        return NotifyResults.Err('invalid_input', 'Notification message is invalid.', { maxLength=Config.maxMessageLength })
    end
    value.message = request.message
    value.duration = tonumber(request.duration) or Config.defaultDurationMs
    if value.duration < 1 or value.duration > Config.maxDurationMs or value.duration % 1 ~= 0 then
        return NotifyResults.Err('invalid_input', 'Notification duration is invalid.', { maxDurationMs=Config.maxDurationMs })
    end
    for key in pairs(fields) do if request[key] ~= nil then value[key] = request[key] end end
    if (value.style == 'top_banner' or value.style == 'advanced' or value.style == 'mission_failed' or value.style == 'warning')
        and (type(value.title) ~= 'string' or value.title == '') then
        return NotifyResults.Err('invalid_input', 'This notification style requires a title.')
    end
    return NotifyResults.Ok(value)
end

local render = {}
local function Simple(hash, request, size, extra)
    local values = { { 8, 'i8', Literal(request.message) } }
    if extra then extra(values, request) end
    Citizen.InvokeNative(hash, Options(request.duration), Content(size or 24, values), 1)
end
render.tooltip = function(r) Simple(0x049D5C615BD38BAD, r) end
render.right = function(r) Simple(0xB2920B9760F0F36B, r) end
render.left = function(r) Citizen.InvokeNative(0xDD1232B332CBB9E7, 3, 1, 0); Simple(0xCEDBF17EFCC0E4A4, r) end
render.top = function(r) Simple(0x860DDFE97CC94DF0, r, 56) end
render.bottom_right = function(r) Simple(0x2024F4F333095FB1, r, 40) end
render.center = function(r) Simple(0x893128CDB4B81FBB, r, 32, function(v, x)
    v[#v+1] = { 16, 'i8', GetHashKey(x.color or 'COLOR_PURE_WHITE') }
end) end
render.standard = function(r)
    Citizen.InvokeNative(0xC927890AA64E9661, Options(r.duration), Content(48,
        { {8,'i8',Literal(r.message)}, {16,'i8',Literal(r.message)} }), 1, 1)
end
render.location = function(r)
    Citizen.InvokeNative(0xD05590C1AB38F068, Options(r.duration), Content(40,
        { {8,'i8',Literal(r.location)}, {16,'i8',Literal(r.message)} }), 0, 1)
end
render.top_banner = function(r)
    Citizen.InvokeNative(0xA6F4216AB10EB08E, Options(r.duration), Content(56,
        { {8,'i8',Literal(r.title)}, {16,'i8',Literal(r.message)} }), 1, 1)
end
render.advanced = function(r)
    Citizen.InvokeNative(0x26E87218390E6729, Options(r.duration), Content(64, {
        {8,'i8',Literal(r.title)}, {16,'i8',Literal(r.message)}, {32,'i8',GetHashKey(r.dictionary or '')},
        {40,'i8',GetHashKey(r.icon or '')}, {48,'i8',GetHashKey(r.color or 'COLOR_WHITE')} }), 1, 1)
end
render.advanced_right = function(r)
    local options = Options(r.duration)
    options = Set(options, 8, 'i8', Literal('Transaction_Feed_Sounds'))
    options = Set(options, 16, 'i8', Literal('Transaction_Positive'))
    Citizen.InvokeNative(0xB249EBCB30DD88E0, options, Content(80, {
        {8,'i8',Literal(r.message)}, {16,'i8',Literal(r.dictionary)}, {24,'i8',GetHashKey(r.icon or '')},
        {40,'i8',GetHashKey(r.color or 'COLOR_WHITE')}, {48,'i4',tonumber(r.quality) or 1} }), 1)
end
local function Timed(hash, r, mode)
    local options, values = Buffer(40), nil
    if mode == 'audio' then
        options = Set(options, 0, 'i8', Literal(r.audioSource)); options = Set(options, 8, 'i8', Literal(r.audioName))
        options = Set(options, 16, 'i2', 4)
        values = r.style == 'warning' and { {16,'i8',Literal(r.title)}, {24,'i8',Literal(r.message)} }
            or { {8,'i8',Literal(r.message)} }
    else values = { {8,'i8',Literal(r.title)}, {16,'i8',Literal(r.message)} } end
    local handle = Citizen.InvokeNative(hash, options, Content(72, values), 1)
    CreateThread(function() Wait(r.duration); Citizen.InvokeNative(0x00A15B94CBA4F76F, handle) end)
end
render.mission_failed = function(r) Timed(0x9F2CC2439A04E7BA, r) end
render.dead_player = function(r) Timed(0x815C4065AE6E6071, r, 'audio') end
render.warning = function(r) Timed(0x339E16B41780FC35, r, 'audio') end

local function Show(request)
    local validated = Validate(request)
    if not validated.ok then return validated end
    render[validated.value.style](validated.value)
    return NotifyResults.Ok({ displayed=true, style=validated.value.style })
end
exports('ShowNotification', Show)
RegisterNetEvent('feather-notify:show.v1', function(request) Show(request) end)
RegisterCommand('NotifyClientSmokeTest', function()
    local right = Show({style='right', message='Feather Notify right notification.', duration=2500})
    local banner = Show({style='top_banner', title='Feather Notify', message='Top banner presentation is working.', duration=2500})
    local invalid = Show({style='unknown', message='invalid'})
    print(('[NotifyClientSmokeTest] right=%s top_banner=%s invalid_rejected=%s'):format(
        tostring(right.ok), tostring(banner.ok), tostring(invalid.ok == false)))
end, false)

RegisterCommand('NotifyStyleSmokeTest', function()
    local samples = {
        {style='tooltip', message='Tooltip'}, {style='advanced', title='Advanced', message='Advanced', dictionary='generic_textures', icon='tick', color='COLOR_WHITE'},
        {style='location', message='Location message', location='Valentine'}, {style='right', message='Right'},
        {style='left', message='Left'}, {style='top_banner', title='Top Banner', message='Top banner'},
        {style='advanced_right', message='Advanced right', dictionary='generic_textures', icon='tick', color='COLOR_WHITE', quality=1},
        {style='top', message='Top'}, {style='center', message='Center', color='COLOR_PURE_WHITE'},
        {style='standard', message='Standard'}, {style='bottom_right', message='Bottom right'},
        {style='mission_failed', title='Mission Failed', message='Test presentation'},
        {style='dead_player', message='Dead player', audioSource='', audioName=''},
        {style='warning', title='Warning', message='Warning presentation', audioSource='', audioName=''}
    }
    CreateThread(function()
        local passed = 0
        for _, sample in ipairs(samples) do
            sample.duration = 1500
            local result = Show(sample)
            if result.ok then passed = passed + 1 end
            print(('[NotifyStyleSmokeTest] %-18s %s'):format(sample.style, result.ok and 'PASS' or 'FAIL'))
            Wait(1800)
        end
        print(('[NotifyStyleSmokeTest] done %d/%d dispatched; verify each presentation visually'):format(passed, #samples))
    end)
end, false)
