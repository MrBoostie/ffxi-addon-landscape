package.path = '../addons/AddonHealth/?.lua;../tests/?.lua;' .. package.path

local mock = require('mock_windower')
mock.reset()
mock.install()
mock.set_addon_path('../addons/AddonHealth/')
mock.set_addons({
    { name = 'TravelRouter', loaded = true, path = '../addons/TravelRouter/' },
    { name = 'SessionConductor', loaded = true, path = '../addons/SessionConductor/' },
    { name = 'GearSwap', loaded = false, path = '../addons/GearSwap/' },
    utility = true,
})

assert(loadfile('../addons/AddonHealth/addonhealth.lua'))()

mock.fire_event('addon command', 'check')
local log = mock.get_chat_log()
assert(#log > 0, 'expected health output')

local saw_severity, saw_unknown = false, false
for _, entry in ipairs(log) do
    if entry.text:find('Severity:') then saw_severity = true end
    if entry.text:find('Unknown Loaded Addons: utility') then saw_unknown = true end
end
assert(saw_severity, 'expected severity line')
assert(saw_unknown, 'expected unknown addon coverage line')

local custom_file = '../addons/AddonHealth/data/addons.user.lua'
local custom = io.open(custom_file, 'w')
assert(custom, 'expected to create addons.user.lua')
custom:write([[return {
  { name = 'XIPivot', critical = true, deps = { 'Config' } },
  { name = 'Treasury', critical = true, deps = {} },
}
]])
custom:close()

mock.fire_event('addon command', 'reload')
mock.fire_event('addon command', 'status')

local saw_reload, saw_monitored, saw_alert = false, false, false
for _, entry in ipairs(mock.get_chat_log()) do
    if entry.text:find('catalog reloaded %(11 monitored addons%)') then saw_reload = true end
    if entry.text:find('monitored=11') then saw_monitored = true end
    if entry.text:find('status=alert') then saw_alert = true end
end
assert(saw_reload, 'expected reload acknowledgement')
assert(saw_monitored, 'expected monitored count after reload')
assert(saw_alert, 'expected alert severity from custom critical addon override')

os.remove(custom_file)
mock.fire_event('addon command', 'reload')

mock.fire_event('addon command', 'watch', 'on', '5')
local registered_before = mock.get_registered_events()
local prerender_count = 0
for _, entry in pairs(registered_before) do
    if entry.name == 'prerender' then prerender_count = prerender_count + 1 end
end
assert(prerender_count == 1, 'expected single prerender registration')

mock.fire_event('unload')
local registered_after = mock.get_registered_events()
for _, entry in pairs(registered_after) do
    assert(entry.name ~= 'prerender', 'expected prerender to be unregistered on unload')
end

print('test_addonhealth.lua: ok')
