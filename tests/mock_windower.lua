local mock = {}

local chat_log = {}
local ipc_messages = {}
local sent_commands = {}
local registered_events = {}
local event_counter = 0

local player = { name = 'TestPlayer', target_index = nil, buffs = {} }
local info = { zone = 100, status = 0 }
local party_data = {}
local addons = {}
local addon_path = nil

local function default_addon_path()
    local cwd = os.getenv('ODIN_TEST_REPO_ROOT') or '.'
    cwd = cwd:gsub('/+$', '')
    return cwd .. '/tests/fixtures/'
end

function mock.reset()
    chat_log = {}
    ipc_messages = {}
    sent_commands = {}
    registered_events = {}
    event_counter = 0
    player = { name = 'TestPlayer', target_index = nil, buffs = {} }
    info = { zone = 100, status = 0 }
    party_data = {}
    addons = {}
    addon_path = nil
end

function mock.set_player(p) player = p end
function mock.set_info(i) info = i end
function mock.set_party(p) party_data = p end
function mock.set_addons(a) addons = a or {} end
function mock.set_addon_path(path) addon_path = path end
function mock.get_chat_log() return chat_log end
function mock.get_ipc_messages() return ipc_messages end
function mock.get_sent_commands() return sent_commands end
function mock.get_registered_events() return registered_events end

function mock.install()
    _G.windower = {
        addon_path = addon_path or default_addon_path(),
        add_to_chat = function(color, text)
            chat_log[#chat_log+1] = { color = color, text = text }
        end,
        send_command = function(cmd)
            sent_commands[#sent_commands+1] = cmd
        end,
        send_ipc_message = function(data)
            ipc_messages[#ipc_messages+1] = data
        end,
        register_event = function(name, fn)
            event_counter = event_counter + 1
            registered_events[event_counter] = { id = event_counter, name = name, fn = fn }
            return event_counter
        end,
        unregister_event = function(id)
            registered_events[id] = nil
        end,
        get_addons = function()
            return addons
        end,
        ffxi = {
            get_player = function() return player end,
            get_info = function() return info end,
            get_party = function() return party_data end,
        },
    }
    _G._addon = {}
end

function mock.fire_event(name, ...)
    for _, entry in pairs(registered_events) do
        if entry.name == name then
            entry.fn(...)
        end
    end
end

return mock
