_addon.name = 'SessionConductor'
_addon.author = 'boostie'
_addon.version = '1.1.0'
_addon.commands = {'conductor', 'sconduct'}
_addon.description = 'Event-driven multi-character orchestration with rules, ACKs, and safety rails.'

local USER_ROSTER_FILE = (windower.addon_path or '') .. 'data/roster.user.lua'
local DEFAULT_RULES_FILE = (windower.addon_path or '') .. 'data/rules.default.lua'
local USER_RULES_FILE = (windower.addon_path or '') .. 'data/rules.user.lua'
local EVENT_LOG_FILE = (windower.addon_path or '') .. 'data/events.log'

local state = {
    target = 'all',
    timeoutSec = 10,
    allowRemoteCommand = false,
    rosters = { all = {} },
    pending = {},

    autoEnabled = true,
    mode = 'normal',
    pauseUntil = 0,

    rulesById = {},
    ruleOrder = {},
    ruleStats = {},
    lockouts = {},

    eventSeq = 0,
    eventHistory = {},
    historyLimit = 200,
    trace = false,

    globalActionWindowSec = 10,
    globalActionMax = 5,
    actionTimestamps = {},

    monitor = {
        lastTick = 0,
        lastZone = nil,
        lastStatus = nil,
        lastTargetId = nil,
        lowHpSeen = {},
        koSeen = {},
    },
}

math.randomseed(os.time())

local function msg(text)
    windower.add_to_chat(121, ('[SessionConductor] %s'):format(text))
end

local function trace(text)
    if state.trace then msg('[trace] ' .. text) end
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

local function now()
    return os.time()
end

local function get_info()
    return windower.ffxi.get_info() or {}
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

local function load_table(path)
    local ok, t = pcall(dofile, path)
    if ok and type(t) == 'table' then return t end
    return nil
end

local function append_event_log(line)
    local f = io.open(EVENT_LOG_FILE, 'a')
    if not f then return end
    f:write(line, '\n')
    f:close()
end

local function load_roster()
    local t = load_table(USER_ROSTER_FILE)
    if not t then return end
    state.rosters = t.rosters or state.rosters
    state.target = t.target or state.target
    state.timeoutSec = t.timeoutSec or state.timeoutSec
    if t.allowRemoteCommand ~= nil then state.allowRemoteCommand = t.allowRemoteCommand end
    if t.autoEnabled ~= nil then state.autoEnabled = t.autoEnabled end
end

local function save_roster()
    local ok = write_table_file(USER_ROSTER_FILE, {
        rosters = state.rosters,
        target = state.target,
        timeoutSec = state.timeoutSec,
        allowRemoteCommand = state.allowRemoteCommand,
        autoEnabled = state.autoEnabled,
    })
    msg(ok and 'Roster saved.' or 'Failed to save roster file.')
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

local function call_travel_router(dest)
    if not dest or dest == '' then return false end
    windower.send_command(('troute run %s'):format(dest))
    return true
end

local function start_pending(op, target, payload)
    local req = tostring(now()) .. '-' .. tostring(math.random(1000, 9999))
    state.pending[req] = {
        op = op,
        target = target,
        sentAt = now(),
        acks = {},
        retries = 0,
        maxRetries = 2,
        payload = payload or {},
        exhausted = false,
    }
    return req
end

local function add_ack(req, from, status)
    local p = state.pending[req]
    if not p then return end
    p.acks[normalize(from)] = status or 'ok'
end

local function expected_count(target)
    if target == 'all' then return nil end
    return #(state.rosters[target] or {})
end

local function get_field(obj, path)
    if not obj or not path then return nil end
    local cur = obj
    for part in tostring(path):gmatch('[^%.]+') do
        if type(cur) ~= 'table' then return nil end
        cur = cur[part]
    end
    return cur
end

local function compare(op, left, right)
    if op == '==' then return left == right end
    if op == '!=' then return left ~= right end
    if op == '>' then return tonumber(left) and tonumber(right) and tonumber(left) > tonumber(right) end
    if op == '>=' then return tonumber(left) and tonumber(right) and tonumber(left) >= tonumber(right) end
    if op == '<' then return tonumber(left) and tonumber(right) and tonumber(left) < tonumber(right) end
    if op == '<=' then return tonumber(left) and tonumber(right) and tonumber(left) <= tonumber(right) end
    if op == 'contains' then return tostring(left or ''):find(tostring(right or ''), 1, true) ~= nil end
    if op == 'not_contains' then return tostring(left or ''):find(tostring(right or ''), 1, true) == nil end
    if op == 'matches' then return tostring(left or ''):match(tostring(right or '')) ~= nil end
    if op == 'in' and type(right) == 'table' then
        for _, v in ipairs(right) do if left == v then return true end end
        return false
    end
    if op == 'not_in' and type(right) == 'table' then
        for _, v in ipairs(right) do if left == v then return false end end
        return true
    end
    return false
end

local function cleanup_action_timestamps()
    local cutoff = now() - state.globalActionWindowSec
    local keep = {}
    for _, t in ipairs(state.actionTimestamps) do
        if t >= cutoff then keep[#keep+1] = t end
    end
    state.actionTimestamps = keep
end

local function action_allowed()
    cleanup_action_timestamps()
    return #state.actionTimestamps < state.globalActionMax
end

local function mark_action()
    state.actionTimestamps[#state.actionTimestamps + 1] = now()
end

local function push_event_history(evt)
    state.eventHistory[#state.eventHistory + 1] = evt
    while #state.eventHistory > state.historyLimit do
        table.remove(state.eventHistory, 1)
    end
end

local function evaluate_where(evt, where)
    if type(where) ~= 'table' then return true end
    for _, cond in ipairs(where) do
        local left = get_field(evt, cond.field)
        if not compare(cond.op, left, cond.value) then
            return false
        end
    end
    return true
end

local function rule_enabled(rule)
    if not rule.enabled then return false end
    if rule.disabledUntil and now() < rule.disabledUntil then return false end
    return true
end

local function in_lockout(rule)
    if not rule.lockout_group then return false end
    local untilTs = state.lockouts[rule.lockout_group]
    return untilTs and now() < untilTs
end

local function set_lockout(rule)
    if not rule.lockout_group then return end
    local dur = tonumber(rule.lockout_sec or 2) or 2
    state.lockouts[rule.lockout_group] = now() + math.max(1, dur)
end

local function check_rule_event_match(rule, evt)
    local w = rule.when or {}
    if w.event and w.event ~= evt.type then return false end
    if not evaluate_where(evt, w.where) then return false end
    return true
end

local function execute_action(action, evt)
    if not action_allowed() then
        trace('Global action limit reached; dropping action.')
        return false
    end

    local k = action.kind
    if k == 'notify' then
        msg(action.text or ('rule action notify for event ' .. evt.type))
        mark_action()
        return true
    end

    if k == 'mode.set' then
        state.mode = action.mode or 'normal'
        msg('Mode set to ' .. state.mode)
        mark_action()
        return true
    end

    if k == 'broadcast.travel' then
        local dest = action.destination or (evt.payload and evt.payload.destination)
        if not dest or dest == '' then return false end
        local req = start_pending('travel', state.target, { dest = dest })
        call_travel_router(dest)
        windower.send_ipc_message(pack('SC2', { op = 'travel', from = self_name(), target = state.target, req = req, dest = dest }))
        mark_action()
        return true
    end

    if k == 'broadcast.command' then
        local cmd = normalize_command(action.cmd or '')
        if cmd == '' then return false end
        local req = start_pending('command', state.target, { raw = cmd })
        windower.send_command(cmd)
        windower.send_ipc_message(pack('SC2', { op = 'command', from = self_name(), target = state.target, req = req, raw = cmd }))
        mark_action()
        return true
    end

    if k == 'roster.target_set' then
        local t = normalize(action.target or '')
        if t == 'all' or state.rosters[t] then
            state.target = t
            save_roster()
            mark_action()
            return true
        end
        return false
    end

    if k == 'rule.disable' then
        local id = action.id
        local sec = tonumber(action.for_sec or 30) or 30
        local r = state.rulesById[id]
        if r then
            r.disabledUntil = now() + sec
            mark_action()
            return true
        end
    end

    return false
end

local function apply_rules(evt)
    if not state.autoEnabled then return end
    if now() < state.pauseUntil then return end

    for _, id in ipairs(state.ruleOrder) do
        local rule = state.rulesById[id]
        if rule and rule_enabled(rule) and not in_lockout(rule) and check_rule_event_match(rule, evt) then
            local stats = state.ruleStats[id] or { fires = 0, lastFired = 0 }
            state.ruleStats[id] = stats

            local cd = tonumber(rule.cooldown_sec or 0) or 0
            if cd > 0 and (now() - (stats.lastFired or 0)) < cd then
                trace(('Rule %s skipped by cooldown'):format(id))
                goto continue_rule
            end

            local maxFires = tonumber(rule.max_fires or 999999)
            if stats.fires >= maxFires then
                goto continue_rule
            end

            local any = false
            for _, action in ipairs(rule.then_actions or {}) do
                local ok = execute_action(action, evt)
                any = any or ok
            end

            if any then
                stats.fires = stats.fires + 1
                stats.lastFired = now()
                set_lockout(rule)
                trace(('Rule fired: %s on %s'):format(id, evt.type))
            end
        end
        ::continue_rule::
    end
end

local function emit_event(eventType, payload, source)
    state.eventSeq = state.eventSeq + 1
    local info = get_info()
    local evt = {
        id = ('evt-%d-%d'):format(now(), state.eventSeq),
        type = eventType,
        ts = now(),
        source = source or 'local',
        actor = self_name(),
        zone = info.zone,
        party = {
            leader = (windower.ffxi.get_party() or {}).party1_leader,
            size = 0,
        },
        payload = payload or {},
    }

    local party = windower.ffxi.get_party() or {}
    local count = 0
    for i = 0, 5 do
        local m = party['p' .. i]
        if m and m.mob and m.mob.name then count = count + 1 end
    end
    evt.party.size = count

    push_event_history(evt)
    append_event_log(('%d|%s|%s'):format(evt.ts, evt.type, serialize_value(evt.payload)))
    apply_rules(evt)
    return evt
end

local function merge_rules(defaultRules, userRules)
    local map, order = {}, {}

    local function put(rule)
        if not rule or not rule.id then return end
        map[rule.id] = rule
    end

    for _, r in ipairs(defaultRules or {}) do put(r) end
    for _, r in ipairs(userRules or {}) do put(r) end

    for id, _ in pairs(map) do order[#order+1] = id end
    table.sort(order, function(a, b)
        local pa = tonumber((map[a] and map[a].priority) or 0) or 0
        local pb = tonumber((map[b] and map[b].priority) or 0) or 0
        if pa == pb then return a < b end
        return pa > pb
    end)

    return map, order
end

local function load_rules()
    local defaults = load_table(DEFAULT_RULES_FILE) or {}
    local users = load_table(USER_RULES_FILE) or {}
    state.rulesById, state.ruleOrder = merge_rules(defaults, users)
    msg(('Loaded %d rules (default+user merge).'):format(#state.ruleOrder))
end

local function rules_list()
    for _, id in ipairs(state.ruleOrder) do
        local r = state.rulesById[id]
        local enabled = r and rule_enabled(r)
        msg(('%s [prio=%s enabled=%s event=%s]'):format(id, tostring(r.priority or 0), tostring(enabled), tostring(r.when and r.when.event or '*')))
    end
end

local function rules_explain(eventType)
    local tmp = { type = eventType, payload = {}, party = {}, source = 'local' }
    msg('Rule explain for event: ' .. eventType)
    for _, id in ipairs(state.ruleOrder) do
        local r = state.rulesById[id]
        local ok = r and rule_enabled(r) and not in_lockout(r) and check_rule_event_match(r, tmp)
        msg((' - %s => %s'):format(id, tostring(ok)))
    end
end

local function rules_toggle(id, enabled)
    local r = state.rulesById[id]
    if not r then msg('Rule not found: ' .. tostring(id)); return end
    r.enabled = enabled and true or false
    msg(('Rule %s set enabled=%s'):format(id, tostring(r.enabled)))
end

local function events_tail(n)
    n = tonumber(n or 10) or 10
    local start = math.max(1, #state.eventHistory - n + 1)
    for i = start, #state.eventHistory do
        local e = state.eventHistory[i]
        msg(('%s | %s | %s'):format(e.id, e.type, serialize_value(e.payload)))
    end
end

local function status_report()
    local nowTs = now()
    local count = 0
    for req, p in pairs(state.pending) do
        count = count + 1
        local ackCount = 0
        for _ in pairs(p.acks) do ackCount = ackCount + 1 end
        local exp = expected_count(p.target)
        local age = nowTs - p.sentAt
        local timeout = age >= state.timeoutSec
        msg(('req=%s op=%s target=%s age=%ss acks=%d%s%s retries=%d'):format(
            req, p.op, p.target, age, ackCount, exp and ('/' .. exp) or '/?', timeout and ' TIMEOUT' or '', p.retries or 0
        ))
    end
    if count == 0 then msg('No pending dispatches.') end
    msg(('auto=%s mode=%s paused=%s'):format(tostring(state.autoEnabled), state.mode, tostring(nowTs < state.pauseUntil)))
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

local function retry_pending()
    local ts = now()
    for req, p in pairs(state.pending) do
        local age = ts - p.sentAt
        local timeout = age >= state.timeoutSec
        if timeout then
            local exp = expected_count(p.target)
            local ackCount = 0
            for _ in pairs(p.acks) do ackCount = ackCount + 1 end
            local missing = (exp == nil) or (ackCount < exp)

            if missing then
                emit_event('system.ack_timeout', { req = req, op = p.op, target = p.target, retries = p.retries or 0 }, 'system')

                if (p.retries or 0) < (p.maxRetries or 2) then
                    p.retries = (p.retries or 0) + 1
                    p.sentAt = ts
                    if p.op == 'travel' then
                        local dest = p.payload.dest
                        if dest and dest ~= '' then
                            windower.send_ipc_message(pack('SC2', { op = 'travel', from = self_name(), target = p.target, req = req, dest = dest }))
                        end
                    elseif p.op == 'command' then
                        local raw = p.payload.raw
                        if raw and raw ~= '' then
                            windower.send_ipc_message(pack('SC2', { op = 'command', from = self_name(), target = p.target, req = req, raw = raw }))
                        end
                    end
                elseif not p.exhausted then
                    p.exhausted = true
                    emit_event('system.retry_exhausted', { req = req, op = p.op, target = p.target }, 'system')
                end
            end
        end
    end
end

local function monitor_tick()
    local t = os.clock()
    if t - (state.monitor.lastTick or 0) < 1.0 then return end
    state.monitor.lastTick = t

    local info = get_info()

    if state.monitor.lastZone and info.zone and state.monitor.lastZone ~= info.zone then
        emit_event('world.zone_changed', { zone_id = info.zone, prev_zone_id = state.monitor.lastZone }, 'system')
    end
    state.monitor.lastZone = info.zone

    if state.monitor.lastStatus and info.status and state.monitor.lastStatus ~= info.status then
        if info.status == 1 then emit_event('combat.engaged', {}, 'system') end
        if state.monitor.lastStatus == 1 and info.status ~= 1 then emit_event('combat.disengaged', {}, 'system') end
    end
    state.monitor.lastStatus = info.status

    local player = windower.ffxi.get_player() or {}
    local target = player.target_index or nil
    if state.monitor.lastTargetId and target and target ~= state.monitor.lastTargetId then
        emit_event('combat.target_changed', { prev_target_id = state.monitor.lastTargetId, target_id = target }, 'system')
    end
    state.monitor.lastTargetId = target

    local party = windower.ffxi.get_party() or {}
    for i = 0, 5 do
        local member = party['p' .. i]
        local mob = member and member.mob
        if mob and mob.name then
            local id = tostring(mob.id or mob.name)
            local hp = tonumber(member.hp) or tonumber(mob.hpp) or 0

            if hp <= 0 then
                if not state.monitor.koSeen[id] then
                    state.monitor.koSeen[id] = true
                    emit_event('party.member.ko', { member = mob.name, hp_pct = hp }, 'system')
                end
            else
                state.monitor.koSeen[id] = nil
            end

            if hp > 0 and hp <= 25 then
                if not state.monitor.lowHpSeen[id .. ':critical'] then
                    state.monitor.lowHpSeen[id .. ':critical'] = true
                    emit_event('party.member.hp_critical', { member = mob.name, hp_pct = hp, threshold = 25 }, 'system')
                end
            else
                state.monitor.lowHpSeen[id .. ':critical'] = nil
            end

            if hp > 0 and hp <= 40 then
                if not state.monitor.lowHpSeen[id .. ':low'] then
                    state.monitor.lowHpSeen[id .. ':low'] = true
                    emit_event('party.member.hp_low', { member = mob.name, hp_pct = hp, threshold = 40 }, 'system')
                end
            else
                state.monitor.lowHpSeen[id .. ':low'] = nil
            end
        end
    end

    retry_pending()
end

local function broadcast_v2(op, data)
    local payload = { op = op, from = self_name(), target = state.target }
    for k, v in pairs(data or {}) do payload[k] = v end
    windower.send_ipc_message(pack('SC2', payload))
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
        emit_event('system.peer_unreachable', { req = req, peer = from, travel = dest, status = ok and 'ok' or 'fail' }, 'remote')
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
            trace(('ACK req=%s from=%s status=%s'):format(m.req, m.from or 'unknown', m.status or 'ok'))
        elseif m.op == 'pong' then
            msg(('Pong from %s'):format(m.from or 'unknown'))
        end
        return
    end

    -- legacy support
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

local function dispatch_travel(dest)
    local req = start_pending('travel', state.target, { dest = dest })
    call_travel_router(dest)
    broadcast_v2('travel', { dest = dest, req = req })
    msg(('Dispatch travel req=%s target=%s dest=%s'):format(req, state.target, dest))
end

local function dispatch_command(raw)
    local req = start_pending('command', state.target, { raw = raw })
    windower.send_command(raw)
    broadcast_v2('command', { raw = raw, req = req })
    msg(('Dispatch command req=%s target=%s'):format(req, state.target))
end

-- init
load_roster()
load_rules()

local ipc_event_id = windower.register_event('ipc message', on_ipc)
local monitor_event_id = windower.register_event('prerender', monitor_tick)

windower.register_event('unload', function()
    if ipc_event_id then windower.unregister_event(ipc_event_id) end
    if monitor_event_id then windower.unregister_event(monitor_event_id) end
end)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = normalize(args[1])

    if cmd == '' or cmd == 'help' then
        msg('Commands: travel|command|follow|ping|target|roster|status|timeout|remotecmd|auto|mode|pause|rule|rules|events|trace|emit')
        return
    end

    if cmd == 'travel' then
        local dest = join(args, ' ', 2)
        if dest == '' then msg('Usage: //conductor travel <destination>'); return end
        dispatch_travel(dest)
        return
    end

    if cmd == 'command' then
        local raw = normalize_command(join(args, ' ', 2))
        if raw == '' then msg('Usage: //conductor command <raw windower command>'); return end
        dispatch_command(raw)
        return
    end

    if cmd == 'follow' then
        local leader = join(args, ' ', 2)
        if leader == '' then msg('Usage: //conductor follow <leaderName>'); return end
        if not valid_name(leader) then msg('Invalid leader name format.'); return end
        local follow_cmd = ('input /assist %s; wait 1; input /follow %s'):format(leader, leader)
        dispatch_command(follow_cmd)
        msg(('Coordinated follow on %s'):format(leader))
        return
    end

    if cmd == 'ping' then
        broadcast_v2('ping', {})
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

    if cmd == 'auto' then
        local flag = normalize(args[2])
        if flag ~= 'on' and flag ~= 'off' then msg('Usage: //conductor auto on|off'); return end
        state.autoEnabled = (flag == 'on')
        save_roster()
        msg('Automation set to ' .. tostring(state.autoEnabled))
        return
    end

    if cmd == 'mode' then
        local m = normalize(args[2])
        if m == '' then msg('Usage: //conductor mode <normal|recovery|emergency|travel>'); return end
        state.mode = m
        msg('Mode set to ' .. state.mode)
        return
    end

    if cmd == 'pause' then
        local sec = tonumber(args[2] or '')
        if not sec or sec < 1 then msg('Usage: //conductor pause <seconds>'); return end
        state.pauseUntil = now() + sec
        msg(('Automation paused for %ss'):format(sec))
        return
    end

    if cmd == 'rule' then
        local op = normalize(args[2])
        local id = args[3]
        if op == 'enable' then rules_toggle(id, true); return end
        if op == 'disable' then rules_toggle(id, false); return end
        msg('Usage: //conductor rule enable|disable <id>')
        return
    end

    if cmd == 'rules' then
        local op = normalize(args[2])
        if op == 'list' or op == '' then rules_list(); return end
        if op == 'explain' then
            local evt = args[3]
            if not evt then msg('Usage: //conductor rules explain <eventType>'); return end
            rules_explain(evt)
            return
        end
        if op == 'reload' then load_rules(); return end
        msg('Usage: //conductor rules list|explain <eventType>|reload')
        return
    end

    if cmd == 'events' then
        local op = normalize(args[2])
        if op == 'tail' or op == '' then events_tail(args[3] or 10); return end
        msg('Usage: //conductor events tail [N]')
        return
    end

    if cmd == 'trace' then
        local flag = normalize(args[2])
        if flag ~= 'on' and flag ~= 'off' then msg('Usage: //conductor trace on|off'); return end
        state.trace = (flag == 'on')
        msg('Trace set to ' .. tostring(state.trace))
        return
    end

    if cmd == 'emit' then
        local evt = args[2]
        if not evt then msg('Usage: //conductor emit <eventType>'); return end
        emit_event(evt, { manual = true }, 'local')
        msg('Emitted event ' .. evt)
        return
    end

    if cmd == 'status' then
        status_report()
        return
    end

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
