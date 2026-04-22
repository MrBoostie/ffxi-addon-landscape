_addon.name = 'SessionConductor'
_addon.author = 'boostie'
_addon.version = '0.1.0'
_addon.commands = {'conductor', 'sconduct'}
_addon.description = 'Multi-character command/travel orchestration (prototype).'

local function msg(text)
    windower.add_to_chat(121, ('[SessionConductor] %s'):format(text))
end

local function join(tbl, sep, start_idx)
    local s = {}
    for i = start_idx or 1, #tbl do
        s[#s+1] = tbl[i]
    end
    return table.concat(s, sep or ' ')
end

local function self_name()
    local p = windower.ffxi.get_player()
    return (p and p.name) or 'unknown'
end

local function call_travel_router(dest)
    if not dest or dest == '' then return false end
    windower.send_command(('troute run %s'):format(dest))
    return true
end

local function broadcast(payload)
    windower.send_ipc_message(payload)
end

local function on_ipc(data)
    if type(data) ~= 'string' then return end

    local parts = {}
    for token in data:gmatch('([^|]+)') do parts[#parts+1] = token end

    if parts[1] == 'SESSION_CONDUCTOR' then
        local op = parts[2]

        if op == 'travel' then
            local dest = parts[3]
            local from = parts[5] or 'unknown'
            if from == self_name() then return end
            msg(('Received travel order from %s -> %s'):format(from, dest or ''))
            call_travel_router(dest or '')
            return
        end

        if op == 'command' then
            local raw = parts[3] or ''
            local from = parts[5] or 'unknown'
            if from == self_name() then return end
            msg(('Received command from %s: %s'):format(from, raw))
            if raw ~= '' then
                windower.send_command(raw)
            end
            return
        end

        if op == 'ping' then
            local from = parts[4] or 'unknown'
            if from == self_name() then return end
            msg(('Ping from %s. replying pong.'):format(from))
            broadcast(('SESSION_CONDUCTOR_REPLY|pong|from|%s'):format(self_name()))
            return
        end
    end

    if parts[1] == 'SESSION_CONDUCTOR_REPLY' and parts[2] == 'pong' then
        local from = parts[4] or 'unknown'
        if from ~= self_name() then
            msg(('Pong from %s'):format(from))
        end
        return
    end

    if parts[1] == 'TRAVEL_ROUTER_REPLY' then
        -- passthrough visibility for debugging integration
        msg(('TravelRouter reply: %s'):format(data))
        return
    end
end

windower.register_event('ipc message', on_ipc)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = (args[1] or ''):lower()

    if cmd == '' or cmd == 'help' then
        msg('Commands: //conductor travel <dest> | command <raw> | follow <leader> | ping')
        return
    end

    if cmd == 'travel' then
        local dest = join(args, ' ', 2)
        if dest == '' then
            msg('Usage: //conductor travel <destination>')
            return
        end

        msg(('Dispatching travel plan: %s'):format(dest))
        call_travel_router(dest)
        broadcast(('SESSION_CONDUCTOR|travel|%s|from|%s'):format(dest, self_name()))
        return
    end

    if cmd == 'command' then
        local raw = join(args, ' ', 2)
        if raw == '' then
            msg('Usage: //conductor command <raw windower command>')
            return
        end
        msg(('Broadcasting command: %s'):format(raw))
        windower.send_command(raw)
        broadcast(('SESSION_CONDUCTOR|command|%s|from|%s'):format(raw, self_name()))
        return
    end

    if cmd == 'follow' then
        local leader = join(args, ' ', 2)
        if leader == '' then
            msg('Usage: //conductor follow <leaderName>')
            return
        end
        local follow_cmd = ('input /assist %s; wait 1; input /follow %s'):format(leader, leader)
        msg(('Coordinating follow on %s'):format(leader))
        windower.send_command(follow_cmd)
        broadcast(('SESSION_CONDUCTOR|command|%s|from|%s'):format(follow_cmd, self_name()))
        return
    end

    if cmd == 'ping' then
        msg('Broadcasting ping...')
        broadcast(('SESSION_CONDUCTOR|ping|from|%s'):format(self_name()))
        return
    end

    msg(('Unknown command "%s"'):format(cmd))
end)
