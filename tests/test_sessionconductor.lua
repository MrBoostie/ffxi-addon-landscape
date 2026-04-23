package.path = '../tests/?.lua;../libs/?.lua;../addons/SessionConductor/?.lua;' .. package.path

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

dofile('../addons/SessionConductor/sessionconductor.lua')

-- test help
mock.fire_event('addon command', 'help')
local log = mock.get_chat_log()
check('help produces output', #log > 0)

-- test status
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'status')
log = mock.get_chat_log()
check('status produces output', #log > 0)

-- test ping
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'ping')
local ipc = mock.get_ipc_messages()
check('ping sends ipc', #ipc > 0)
check('ping ipc has SC2', ipc[1] and ipc[1]:find('SC2') ~= nil)

-- test auto toggle
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'auto', 'off')
log = mock.get_chat_log()
check('auto off acknowledged', #log > 0)

mock.fire_event('addon command', 'auto', 'on')
log = mock.get_chat_log()
check('auto on acknowledged', #log > 1)

-- test mode
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'mode', 'emergency')
log = mock.get_chat_log()
check('mode set acknowledged', #log > 0)
check('mode mentions emergency', log[#log] and log[#log].text:find('emergency') ~= nil)

-- test trace
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'trace', 'on')
log = mock.get_chat_log()
check('trace on acknowledged', #log > 0)

-- test emit
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'emit', 'test.event')
log = mock.get_chat_log()
check('emit acknowledged', #log > 0)

-- test rules list
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'rules', 'list')
log = mock.get_chat_log()
check('rules list produces output', #log > 0)

-- test events tail
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'emit', 'foo.bar')
mock.fire_event('addon command', 'events', 'tail', '5')
log = mock.get_chat_log()
check('events tail produces output', #log > 0)

-- test sensor display
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'sensor')
log = mock.get_chat_log()
check('sensor shows distance', #log > 0)

-- test roster list
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'roster', 'list')
log = mock.get_chat_log()
check('roster list produces output', #log > 0)

-- test remotecmd toggle
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'remotecmd', 'on')
log = mock.get_chat_log()
check('remotecmd on acknowledged', #log > 0)

-- test unknown command
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('addon command', 'zzz_unknown')
log = mock.get_chat_log()
check('unknown cmd gives message', #log > 0)

-- test IPC pong response
mock.reset()
mock.install()
dofile('../addons/SessionConductor/sessionconductor.lua')
mock.fire_event('ipc message', 'SC2R|op=pong&from=OtherPlayer')
log = mock.get_chat_log()
check('pong shows source', #log > 0)

print(('\n%d/%d tests passed, %d failed'):format(pass, total, fail))
os.exit(fail > 0 and 1 or 0)
