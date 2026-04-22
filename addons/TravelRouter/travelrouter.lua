_addon.name = 'TravelRouter'
_addon.author = 'boostie'
_addon.version = '0.2.0'
_addon.commands = {'troute', 'travelrouter'}
_addon.description = 'Content-aware travel route planner/executor with persistence and v2 IPC.'

local base_routes = require('data/routes')

local USER_ROUTE_FILE = (windower.addon_path or '') .. 'data/routes.user.lua'
local USER_STATE_FILE = (windower.addon_path or '') .. 'data/state.user.lua'

local routes = {}
local user_routes = {}
local state = { unlocks = { hp = true, sg = true, warp = true } }

local function msg(text)
    windower.add_to_chat(207, ('[TravelRouter] %s'):format(text))
end

local function join(tbl, sep, start_idx)
    local s = {}
    for i = start_idx or 1, #tbl do s[#s+1] = tbl[i] end
    return table.concat(s, sep or ' ')
end

local function normalize(s)
    return (s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalize_cmd(cmd)
    return (cmd or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^//', '')
end

local function copy_table(t)
    local out = {}
    for k, v in pairs(t or {}) do
        if type(v) == 'table' then out[k] = copy_table(v) else out[k] = v end
    end
    return out
end

local function safe_load(path)
    local ok, chunk = pcall(dofile, path)
    if ok and type(chunk) == 'table' then return chunk end
    return nil
end

local function serialize_value(v, indent)
    indent = indent or ''
    if type(v) == 'string' then return string.format('%q', v) end
    if type(v) == 'number' or type(v) == 'boolean' then return tostring(v) end
    if type(v) == 'table' then
        local next_indent = indent .. '  '
        local lines = {'{'}
        for k, vv in pairs(v) do
            local key = (type(k) == 'string' and k:match('^[%a_][%w_]*$')) and k or ('[' .. serialize_value(k) .. ']')
            lines[#lines+1] = next_indent .. key .. ' = ' .. serialize_value(vv, next_indent) .. ','
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

local function merge_routes()
    routes = copy_table(base_routes)
    for dest, route in pairs(user_routes) do routes[dest] = route end
end

local function load_user_files()
    user_routes = safe_load(USER_ROUTE_FILE) or {}
    state = safe_load(USER_STATE_FILE) or state
    if type(state.unlocks) ~= 'table' then state.unlocks = {} end
    merge_routes()
end

local function save_user_routes()
    local ok = write_table_file(USER_ROUTE_FILE, user_routes)
    msg(ok and ('Saved user routes to %s'):format(USER_ROUTE_FILE) or 'Failed to save user route file.')
end

local function save_user_state()
    local ok = write_table_file(USER_STATE_FILE, state)
    msg(ok and ('Saved state to %s'):format(USER_STATE_FILE) or 'Failed to save state file.')
end

local function route_candidates(dest)
    local route = routes[dest]
    if not route then return nil end
    if route.steps then return route.candidates or { route } end
    if route[1] and type(route[1]) == 'string' then return { { name = 'default', score = 10, steps = route } } end
    if route.candidates then return route.candidates end
    return nil
end

local function score_candidate(c)
    local score, reasons = (c.score or 10), {}
    for _, req in ipairs(c.requires or {}) do
        if state.unlocks[req] then
            score = score + 5
            reasons[#reasons+1] = ('+5 unlock:%s'):format(req)
        else
            score = score - 10
            reasons[#reasons+1] = ('-10 missing:%s'):format(req)
        end
    end
    local info = windower.ffxi.get_info() or {}
    if c.preferred_zone and info.zone == c.preferred_zone then
        score = score + 3
        reasons[#reasons+1] = '+3 zone-match'
    end
    return score, reasons
end

local function pick_plan(dest)
    local key = normalize(dest)
    local candidates = route_candidates(key)
    if not candidates then return nil, nil end

    local best, best_score, best_reasons = nil, -9999, {}
    for _, c in ipairs(candidates) do
        local score, reasons = score_candidate(c)
        if score > best_score then best, best_score, best_reasons = c, score, reasons end
    end
    return best, { score = best_score, reasons = best_reasons }
end

local function list_destinations()
    local keys = {}
    for k, _ in pairs(routes) do keys[#keys+1] = k end
    table.sort(keys)
    msg(('Known destinations (%d): %s'):format(#keys, table.concat(keys, ', ')))
end

local function print_plan(dest)
    local plan, meta = pick_plan(dest)
    if not plan then
        msg(('No route for "%s". Use //troute list or //troute add ...'):format(dest or ''))
        return false, nil
    end
    msg(('Route plan for "%s" via "%s" (score %d):'):format(dest, plan.name or 'default', meta.score or 0))
    if meta.reasons and #meta.reasons > 0 then msg('  rationale: ' .. table.concat(meta.reasons, ', ')) end
    for i, step in ipairs(plan.steps or {}) do msg(('  %d) %s'):format(i, step)) end
    return true, plan
end

local function execute_step(step)
    if step:sub(1,4) == 'say:' then msg(step:sub(5)); return end
    if step:sub(1,5) == 'wait:' then
        local sec = tonumber(step:sub(6)) or 0
        if sec > 0 then
            if coroutine and coroutine.sleep then
                coroutine.sleep(sec)
            else
                windower.send_command(('wait %.1f'):format(sec))
            end
            msg(('wait: %.1fs'):format(sec))
        end
        return
    end
    if step:sub(1,4) == 'cmd:' then
        local cmd = normalize_cmd(step:sub(5))
        windower.send_command(cmd)
        msg(('exec: %s'):format(cmd))
        return
    end
    msg(step)
end

local function run_plan(dest)
    local plan = pick_plan(dest)
    if not plan then msg(('No route for "%s".'):format(dest or '')); return false end
    msg(('Executing route "%s" (%s)...'):format(dest, plan.name or 'default'))
    for _, step in ipairs(plan.steps or {}) do execute_step(step) end
    return true
end

local function add_route(dest, payload)
    local key = normalize(dest)
    if key == '' then msg('Usage: //troute add <destination> <step1> ; <step2> ; ...'); return end
    local steps = {}
    for piece in (payload or ''):gmatch('([^;]+)') do
        local step = piece:gsub('^%s+', ''):gsub('%s+$', '')
        if step ~= '' then steps[#steps+1] = step end
    end
    if #steps == 0 then msg('No steps parsed. Example: //troute add jeuno say:go ; cmd:hp #1'); return end
    user_routes[key] = steps
    merge_routes()
    save_user_routes()
    msg(('Route "%s" saved with %d steps.'):format(key, #steps))
end

local function reset_route(dest)
    local key = normalize(dest)
    if user_routes[key] == nil then msg(('No user override exists for "%s".'):format(key)); return end
    user_routes[key] = nil
    merge_routes()
    save_user_routes()
    msg(('Removed user override for "%s".'):format(key))
end

local function unlock_cmd(action, token)
    local key = normalize(token)
    if action == 'list' then
        local keys = {}
        for k, v in pairs(state.unlocks) do if v then keys[#keys+1] = k end end
        table.sort(keys)
        msg('Unlocks: ' .. (#keys > 0 and table.concat(keys, ', ') or '(none)'))
        return
    end
    if key == '' then msg('Usage: //troute unlock add|remove <token>'); return end
    if action == 'add' then state.unlocks[key] = true; save_user_state(); msg('Unlock added: ' .. key); return end
    if action == 'remove' then state.unlocks[key] = nil; save_user_state(); msg('Unlock removed: ' .. key); return end
    msg('Usage: //troute unlock list|add|remove ...')
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
        if k then out[dec(k)] = dec(v) end
    end
    return out
end

local function handle_ipc(data)
    if type(data) ~= 'string' then return end

    local pfx, payload = data:match('^(TR2)%|(.*)$')
    if pfx == 'TR2' then
        local m = unpack_payload(payload)
        local op, dest = m.op, m.dest
        if op == 'plan' then
            local ok, plan = print_plan(dest)
            local steps = plan and #(plan.steps or {}) or 0
            windower.send_ipc_message(pack('TR2R', { op = 'plan', dest = dest, ok = ok and 1 or 0, steps = steps, by = 'TravelRouter' }))
        elseif op == 'run' then
            local ok = run_plan(dest)
            windower.send_ipc_message(pack('TR2R', { op = 'run', dest = dest, ok = ok and 1 or 0, by = 'TravelRouter' }))
        end
        return
    end

    local parts = {}
    for token in data:gmatch('([^|]+)') do parts[#parts+1] = token end
    if parts[1] ~= 'TRAVEL_ROUTER' then return end
    local op, dest = parts[2], parts[3]
    if op == 'plan' then
        local ok, plan = print_plan(dest)
        local step_count = plan and #(plan.steps or {}) or 0
        windower.send_ipc_message(('TRAVEL_ROUTER_REPLY|plan|%s|ok|%d|steps|%d'):format(dest or '', ok and 1 or 0, step_count))
    elseif op == 'run' then
        local ok = run_plan(dest)
        windower.send_ipc_message(('TRAVEL_ROUTER_REPLY|run|%s|ok|%d'):format(dest or '', ok and 1 or 0))
    end
end

load_user_files()
local ipc_event_id = windower.register_event('ipc message', handle_ipc)

windower.register_event('unload', function()
    if ipc_event_id then windower.unregister_event(ipc_event_id) end
end)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = normalize(args[1])

    if cmd == '' or cmd == 'help' then
        msg('Commands: list | plan <dest> | run <dest> | add <dest> <s1>;... | reset <dest> | unlock list|add|remove <k> | save')
        return
    end
    if cmd == 'list' then list_destinations(); return end
    if cmd == 'plan' then print_plan(join(args, ' ', 2)); return end
    if cmd == 'run' then run_plan(join(args, ' ', 2)); return end
    if cmd == 'add' then add_route(args[2], join(args, ' ', 3)); return end
    if cmd == 'reset' then reset_route(join(args, ' ', 2)); return end
    if cmd == 'save' then save_user_routes(); save_user_state(); return end
    if cmd == 'unlock' then unlock_cmd(normalize(args[2]), args[3]); return end

    msg(('Unknown command "%s"'):format(cmd))
end)
