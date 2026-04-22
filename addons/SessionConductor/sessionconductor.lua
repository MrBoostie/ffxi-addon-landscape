_addon.name = 'SessionConductor'
_addon.author = 'boostie'
_addon.version = '0.2.1'
_addon.commands = {'conductor', 'sconduct'}
_addon.description = 'Multi-character command/travel orchestration with roster + ACK tracking.'

local USER_ROSTER_FILE = (windower.addon_path or '') .. 'data/roster.user.lua'

local state = {
    target = 'all',
    timeoutSec = 10,
    allowRemoteCommand = false,
    rosters = { all = {} },
    pending = {},
}

local function msg(text)
    windower.add_to_chat(121, ('[SessionConductor] %s'):format(text))
end

local function join(tbl, sep, start_idx)
    local s = {}
    for i = start_idx or 1, #tbl do s[#s+1] = tbl[i] end
    return table.concat(s, sep or ' ')
end

local function normalize(s)
    return (s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalize_command(raw)
    return (raw or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^//', '')
end

local function valid_name(name)
    return type(name) == 'string' and name:match('^[A-Za-z][A-Za-z0-9_%-]+$') ~= nil
end

local function self_name()
    local p = windower.ffxi.get_player()
    return (p and p.name) or 'unknown'
end

local function serialize_value(v, indent)
    indent = indent or ''
    if type(v) == 'string' then return string.format('%q', v) end
    if type(v) == 'number' or type(v) == 'boolean' then return tostring(v) end
    if type(v) == 'table' then
        local n = indent .. '  '
        local lines = {'{'}
        for k, vv in pairs(v) do
            local key = (type(k) == 'string' and k:match('^[%a_][%w_]*$')) and k or ('[' .. serialize_value(k) .. ']')
            lines[#lines+1] = n .. key .. ' = ' .. serialize_value(vv, n) .. ','
        end
        lines[#lines+1] = indent .. '}'
        return table.concat(lines, '\n')
    end
    return 'nil'
end

local function write_table_file(path, t)
    local f = io.open(path, 'w')
    if not f then return false end
    f:write('return ', serialize_value(t), '\n')
    f:close()
    return true
end

local function load_roster()
    local ok, t = pcall(dofile, USER_ROSTER_FILE)
    if ok and type(t) == 'table' then
        state.rosters = t.rosters or state.rosters
        state.target = t.target or state.target
        state.timeoutSec = t.timeoutSec or state.timeoutSec
        if t.allowRemoteCommand ~= nil then state.allowRemoteCommand = t.allowRemoteCommand end
    end
end

local function save_roster()
    local ok = write_table_file(USER_ROSTER_FILE, {
        rosters = state.rosters,
        target = state.target,
        timeoutSec = state.timeoutSec,
        allowRemoteCommand = state.allowRemoteCommand,
    })
    msg(ok and 'Roster saved.' or 'Failed to save roster file.')
end

local function call_travel_router(dest)
    if not dest or dest == '' then return false end
    windower.send_command(('troute run %s'):format(dest))
    return true
end

local function enc(s)
    return tostring(s or ''):gsub('([^%w%-_%.~ ])', function(c) return string.format('%%%02X', string.byte(c)) end):gsub(' ', '+')
end
local function dec(s)
    s = (s or ''):gsub('+', ' ')
    return s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
end
local function pack(prefix, t)
    local parts = {}
    for k, v in pairs(t or {}) do parts[#parts+1] = enc(k) .. '=' .. enc(v) end
    return prefix .. '|' .. table.concat(parts, '&')
end
local function unpack_payload(s)
    local out = {}
    for pair in (s or ''):gmatch('([^&]+)') do
        local k, v = pair:match('([^=]+)=(.*)')
        if k then out[dec(k)] = dec(v or '') end
    end
    return out
end

local function split_pipe_preserve(s)
    local out, start = {}, 1
    while true do
        local i = string.find(s, '|', start, true)
        if not i then
            out[#out+1] = string.sub(s, start)
            break
        end
        out[#out+1] = string.sub(s, start, i - 1)
        start = i + 1
    end
    return out
end

local function in_target_group(name, target)
    if target == 'all' or target == '' then return true end
    local group = state.rosters[target] or {}
    for _, n in ipairs(group) do if normalize(n) == normalize(name) then return true end end
    return false
end

local function sender_trusted(name)
    if normalize(name) == normalize(self_name()) then return true end
    for _, names in pairs(state.rosters) do
        for _, n in ipairs(names) do
            if normalize(n) == normalize(name) then return true end
        end
    end
    return false
end

local function start_pending(op, target)
    local req = tostring(os.time()) .. '-' .. tostring(math.random(1000, 9999))
    state.pending[req] = { op = op, target = target, sentAt = os.time(), acks = {} }
    return req
end

local function add_ack(req, from, status)
    if not state.pending[req] then return end
    state.pending[req].acks[normalize(from)] = status or 'ok'
end

local function expected_count(target)
    if target == 'all' then return nil end
    return #(state.rosters[target] or {})
end

local function status_report()
    local now = os.time()
    local count = 0
    for req, p in pairs(state.pending) do
        count = count + 1
        local ackCount = 0
        for _ in pairs(p.acks) do ackCount = ackCount + 1 end
        local exp = expected_count(p.target)
        local age = now - p.sentAt
        local timeout = age >= state.timeoutSec
        msg(('req=%s op=%s target=%s age=%ss acks=%d%s%s'):format(req, p.op, p.target, age, ackCount, exp and ('/' .. exp) or '/?', timeout and ' TIMEOUT' or ''))
    end
    if count == 0 then msg('No pending dispatches.') end
end

local function roster_add(group, name)
    group, name = normalize(group), name
    if group == '' or (name or '') == '' then msg('Usage: //conductor roster add <group> <name>'); return end
    if not valid_name(name) then msg('Invalid name format.'); return end
    state.rosters[group] = state.rosters[group] or {}
    for _, n in ipairs(state.rosters[group]) do if normalize(n) == normalize(name) then msg('Already in group.'); return end end
    table.insert(state.rosters[group], name)
    save_roster()
    msg(('Added %s to group %s'):format(name, group))
end

local function roster_remove(group, name)
    group, name = normalize(group), name
    local g = state.rosters[group]
    if not g then msg('Unknown group: ' .. group); return end
    for i, n in ipairs(g) do
        if normalize(n) == normalize(name) then
            table.remove(g, i)
            save_roster()
            msg(('Removed %s from %s'):format(name, group))
            return
        end
    end
    msg('Name not found in group.')
end

local function roster_list()
    for g, names in pairs(state.rosters) do
        msg(('%s: %s'):format(g, (#names > 0 and table.concat(names, ', ') or '(empty)')))
    end
    msg(('active target=%s timeout=%ss remote-cmd=%s'):format(state.target, state.timeoutSec, tostring(state.allowRemoteCommand)))
end

local function broadcast_v2(op, data)
    local payload = { op = op, from = self_name(), target = state.target }
    for k, v in pairs(data or {}) do payload[k] = v end
    windower.send_ipc_message(pack('SC2', payload))
end

local function broadcast_v1(op, raw)
    if op == 'travel' then
        windower.send_ipc_message(('SESSION_CONDUCTOR|travel|%s|from|%s'):format(raw, self_name()))
    elseif op == 'command' then
        windower.send_ipc_message(('SESSION_CONDUCTOR|command|%s|from|%s'):format(raw, self_name()))
    elseif op == 'ping' then
        windower.send_ipc_message(('SESSION_CONDUCTOR|ping|from|%s'):format(self_name()))
    end
end

local function handle_sc2(payload)
    local m = unpack_payload(payload)
    local op, from, target = m.op, m.from or 'unknown', normalize(m.target or 'all')
    if normalize(from) == normalize(self_name()) then return end
    if not sender_trusted(from) then return end
    if not in_target_group(self_name(), target) then return end

    if op == 'travel' then
        local dest, req = m.dest or '', m.req or ''
        local ok = call_travel_router(dest)
        windower.send_ipc_message(pack('SC2R', { op = 'ack', req = req, from = self_name(), status = ok and 'ok' or 'fail' }))
        return
    end

    if op == 'command' then
        local raw, req = normalize_command(m.raw or ''), m.req or ''
        local ok = false
        if state.allowRemoteCommand and raw ~= '' then windower.send_command(raw); ok = true end
        windower.send_ipc_message(pack('SC2R', { op = 'ack', req = req, from = self_name(), status = ok and 'ok' or 'blocked' }))
        return
    end

    if op == 'ping' then
        windower.send_ipc_message(pack('SC2R', { op = 'pong', from = self_name() }))
    end
end

local function on_ipc(data)
    if type(data) ~= 'string' then return end

    local pfx, payload = data:match('^(SC2)%|(.*)$')
    if pfx == 'SC2' then handle_sc2(payload); return end

    local rpfx, rpayload = data:match('^(SC2R)%|(.*)$')
    if rpfx == 'SC2R' then
        local m = unpack_payload(rpayload)
        if m.op == 'ack' and m.req then
            add_ack(m.req, m.from or 'unknown', m.status or 'ok')
            msg(('ACK req=%s from=%s status=%s'):format(m.req, m.from or 'unknown', m.status or 'ok'))
        elseif m.op == 'pong' then
            msg(('Pong from %s'):format(m.from or 'unknown'))
        end
        return
    end

    local parts = split_pipe_preserve(data)
    if parts[1] == 'SESSION_CONDUCTOR' then
        local op = parts[2]
        if op == 'travel' then
            local dest, from = parts[3] or '', parts[5] or 'unknown'
            if from ~= self_name() and sender_trusted(from) and in_target_group(self_name(), state.target) then call_travel_router(dest) end
            return
        elseif op == 'command' then
            local raw, from = normalize_command(parts[3] or ''), parts[5] or 'unknown'
            if from ~= self_name() and sender_trusted(from) and state.allowRemoteCommand and raw ~= '' and in_target_group(self_name(), state.target) then windower.send_command(raw) end
            return
        elseif op == 'ping' then
            local from = parts[4] or 'unknown'
            if from ~= self_name() then windower.send_ipc_message(('SESSION_CONDUCTOR_REPLY|pong|from|%s'):format(self_name())) end
            return
        end
    end

    if parts[1] == 'SESSION_CONDUCTOR_REPLY' and parts[2] == 'pong' then
        local from = parts[4] or 'unknown'
        if from ~= self_name() then msg(('Pong(v1) from %s'):format(from)) end
        return
    end
end

load_roster()
local ipc_event_id = windower.register_event('ipc message', on_ipc)

windower.register_event('unload', function()
    if ipc_event_id then windower.unregister_event(ipc_event_id) end
end)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = normalize(args[1])

    if cmd == '' or cmd == 'help' then
        msg('Commands: travel|command|follow|ping|target|roster|status|timeout|remotecmd')
        return
    end

    if cmd == 'travel' then
        local dest = join(args, ' ', 2)
        if dest == '' then msg('Usage: //conductor travel <destination>'); return end
        local req = start_pending('travel', state.target)
        call_travel_router(dest)
        broadcast_v2('travel', { dest = dest, req = req })
        broadcast_v1('travel', dest)
        msg(('Dispatch travel req=%s target=%s dest=%s'):format(req, state.target, dest))
        return
    end

    if cmd == 'command' then
        local raw = normalize_command(join(args, ' ', 2))
        if raw == '' then msg('Usage: //conductor command <raw windower command>'); return end
        local req = start_pending('command', state.target)
        windower.send_command(raw)
        broadcast_v2('command', { raw = raw, req = req })
        broadcast_v1('command', raw)
        msg(('Dispatch command req=%s target=%s'):format(req, state.target))
        return
    end

    if cmd == 'follow' then
        local leader = join(args, ' ', 2)
        if leader == '' then msg('Usage: //conductor follow <leaderName>'); return end
        if not valid_name(leader) then msg('Invalid leader name format.'); return end
        local follow_cmd = ('input /assist %s; wait 1; input /follow %s'):format(leader, leader)
        windower.send_command(follow_cmd)
        local req = start_pending('follow', state.target)
        broadcast_v2('command', { raw = follow_cmd, req = req })
        broadcast_v1('command', follow_cmd)
        msg(('Coordinated follow on %s [req=%s]'):format(leader, req))
        return
    end

    if cmd == 'ping' then
        broadcast_v2('ping', {})
        broadcast_v1('ping', '')
        msg('Broadcasting ping...')
        return
    end

    if cmd == 'target' then
        local t = normalize(args[2])
        if t == '' then msg('Usage: //conductor target <group|all>'); return end
        if t ~= 'all' and not state.rosters[t] then msg('Unknown group. Use roster add first.'); return end
        state.target = t
        save_roster()
        msg('Target group set to ' .. t)
        return
    end

    if cmd == 'timeout' then
        local sec = tonumber(args[2] or '')
        if not sec or sec < 1 then msg('Usage: //conductor timeout <seconds>'); return end
        state.timeoutSec = sec
        save_roster()
        msg(('Timeout set to %ss'):format(sec))
        return
    end

    if cmd == 'remotecmd' then
        local flag = normalize(args[2])
        if flag ~= 'on' and flag ~= 'off' then msg('Usage: //conductor remotecmd on|off'); return end
        state.allowRemoteCommand = (flag == 'on')
        save_roster()
        msg('Remote command execution set to ' .. tostring(state.allowRemoteCommand))
        return
    end

    if cmd == 'status' then status_report(); return end

    if cmd == 'roster' then
        local op = normalize(args[2])
        if op == 'add' then roster_add(args[3], args[4]); return end
        if op == 'remove' then roster_remove(args[3], args[4]); return end
        if op == 'list' or op == '' then roster_list(); return end
        msg('Usage: //conductor roster add|remove|list ...')
        return
    end

    msg(('Unknown command "%s"'):format(cmd))
end)
