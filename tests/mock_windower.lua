local mock = {}

local chat_log = {}
local ipc_messages = {}
local sent_commands = {}
local registered_events = {}
local event_counter = 0

local player = { name = 'TestPlayer', target_index = nil, buffs = {} }
local info = { zone = 100, status = 0 }
local party_data = {}

function mock.reset()
    chat_log = {}
    ipc_messages = {}
    sent_commands = {}
    registered_events = {}
    event_counter = 0
    player = { name = 'TestPlayer', target_index = nil, buffs = {} }
    info = { zone = 100, status = 0 }
    party_data = {}
end

function mock.set_player(p) player = p end
function mock.set_info(i) info = i end
function mock.set_party(p) party_data = p end
function mock.get_chat_log() return chat_log end
function mock.get_ipc_messages() return ipc_messages end
function mock.get_sent_commands() return sent_commands end

function mock.install()
    _G.windower = {
        addon_path = '/tmp/ffxi-addon-landscape-1776909766/tests/fixtures/',
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
            registered_events[event_counter] = { name = name, fn = fn }
            return event_counter
        end,
        unregister_event = function(id)
            registered_events[id] = nil
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
