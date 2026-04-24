package.path = '../tests/?.lua;../lib/?.lua;../addons/TravelRouter/?.lua;' .. package.path

local mock = require('mock_windower')
mock.reset()
mock.install()

local pass, fail, total = 0, 0, 0
local function check(label, cond)
    total = total + 1
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        io.stderr:write(('FAIL: %s\n'):format(label))
    end
end

dofile('../addons/TravelRouter/travelrouter.lua')

-- test list command
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('addon command', 'list')
local log = mock.get_chat_log()
check('list produces output', #log > 0)
check('list mentions destinations', log[1] and log[1].text:find('destinations') ~= nil)

-- test plan with known destination
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('addon command', 'plan', 'jeuno')
log = mock.get_chat_log()
check('plan produces output', #log > 0)
check('plan mentions jeuno', log[1] and log[1].text:find('jeuno') ~= nil)

-- test explain with known destination
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('addon command', 'explain', 'jeuno')
log = mock.get_chat_log()
check('explain produces output', #log > 1)
check('explain includes candidate scoring header', log[1] and log[1].text:find('Candidate scoring') ~= nil)
check('explain includes selected marker note', log[#log] and log[#log].text:find('top%-ranked option') ~= nil)

-- test plan with unknown destination
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('addon command', 'plan', 'nonexistent')
log = mock.get_chat_log()
check('unknown plan gives message', #log > 0)
check('unknown plan mentions no route', log[1] and log[1].text:find('No route') ~= nil)

-- test help command
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('addon command', 'help')
log = mock.get_chat_log()
check('help produces output', #log > 0)

-- test unlock list
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('addon command', 'unlock', 'list')
log = mock.get_chat_log()
check('unlock list produces output', #log > 0)

-- test IPC v2
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('ipc message', 'TR2|op=plan&dest=jeuno')
local ipc = mock.get_ipc_messages()
check('ipc plan sends reply', #ipc > 0)
check('ipc reply has TR2R prefix', ipc[1] and ipc[1]:sub(1,4) == 'TR2R')

-- test unknown command
mock.reset()
mock.install()
dofile('../addons/TravelRouter/travelrouter.lua')

mock.fire_event('addon command', 'bogus')
log = mock.get_chat_log()
check('unknown cmd gives message', #log > 0)
check('unknown cmd mentions unknown', log[1] and log[1].text:find('Unknown') ~= nil)

print(('\n%d/%d tests passed, %d failed'):format(pass, total, fail))
os.exit(fail > 0 and 1 or 0)
