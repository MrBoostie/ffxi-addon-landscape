_addon.name = 'TravelRouter'
_addon.author = 'boostie'
_addon.version = '0.1.0'
_addon.commands = {'troute', 'travelrouter'}
_addon.description = 'Content-aware travel route planner/executor (prototype).'

local routes = require('data/routes')

local function msg(text)
    windower.add_to_chat(207, ('[TravelRouter] %s'):format(text))
end

local function join(tbl, sep, start_idx)
    local s = {}
    for i = start_idx or 1, #tbl do
        s[#s+1] = tbl[i]
    end
    return table.concat(s, sep or ' ')
end

local function normalize_dest(dest)
    return (dest or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalize_command(cmd)
    cmd = (cmd or ''):gsub('^%s+', ''):gsub('%s+$', '')
    cmd = cmd:gsub('^//', '')
    return cmd
end

local function list_destinations()
    local keys = {}
    for k, _ in pairs(routes) do keys[#keys+1] = k end
    table.sort(keys)
    msg(('Known destinations (%d): %s'):format(#keys, table.concat(keys, ', ')))
end

local function get_plan(dest)
    return routes[normalize_dest(dest)]
end

local function print_plan(dest)
    local plan = get_plan(dest)
    if not plan then
        msg(('No route for "%s". Use //troute list or //troute add ...'):format(dest or ''))
        return false
    end

    msg(('Route plan for "%s" (%d steps):'):format(dest, #plan))
    for i, step in ipairs(plan) do
        msg(('  %d) %s'):format(i, step))
    end
    return true
end

local function execute_step(step)
    if step:sub(1,4) == 'say:' then
        msg(step:sub(5))
        return
    end

    if step:sub(1,4) == 'cmd:' then
        local cmd = normalize_command(step:sub(5))
        windower.send_command(cmd)
        msg(('exec: %s'):format(cmd))
        return
    end

    -- fallback = print only
    msg(step)
end

local function run_plan(dest)
    local plan = get_plan(dest)
    if not plan then
        msg(('No route for "%s".'):format(dest or ''))
        return false
    end

    msg(('Executing route "%s"...'):format(dest))
    for _, step in ipairs(plan) do
        execute_step(step)
    end

    return true
end

local function add_route(dest, payload)
    local key = normalize_dest(dest)
    if key == '' then
        msg('Usage: //troute add <destination> <step1> ; <step2> ; ...')
        return
    end

    local steps = {}
    for piece in payload:gmatch('([^;]+)') do
        local step = piece:gsub('^%s+', ''):gsub('%s+$', '')
        if step ~= '' then steps[#steps+1] = step end
    end

    if #steps == 0 then
        msg('No steps parsed. Example: //troute add jeuno say:go ; cmd:hp #1')
        return
    end

    routes[key] = steps
    msg(('Route "%s" updated with %d steps (runtime only).'):format(key, #steps))
end

-- IPC protocol used by SessionConductor
local function handle_ipc(data)
    if type(data) ~= 'string' then return end
    local parts = {}
    for token in data:gmatch('([^|]+)') do parts[#parts+1] = token end
    if parts[1] ~= 'TRAVEL_ROUTER' then return end

    local op = parts[2]
    local dest = parts[3]

    if op == 'plan' then
        local ok = print_plan(dest)
        local step_count = ok and #(get_plan(dest) or {}) or 0
        windower.send_ipc_message(('TRAVEL_ROUTER_REPLY|plan|%s|ok|%d|steps|%d'):format(dest or '', ok and 1 or 0, step_count))
    elseif op == 'run' then
        local ok = run_plan(dest)
        windower.send_ipc_message(('TRAVEL_ROUTER_REPLY|run|%s|ok|%d'):format(dest or '', ok and 1 or 0))
    end
end

windower.register_event('ipc message', handle_ipc)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = (args[1] or ''):lower()

    if cmd == '' or cmd == 'help' then
        msg('Commands: //troute list | plan <dest> | run <dest> | add <dest> <step1> ; <step2>')
        return
    end

    if cmd == 'list' then
        list_destinations()
        return
    end

    if cmd == 'plan' then
        print_plan(join(args, ' ', 2))
        return
    end

    if cmd == 'run' then
        run_plan(join(args, ' ', 2))
        return
    end

    if cmd == 'add' then
        local dest = args[2]
        local payload = join(args, ' ', 3)
        add_route(dest, payload)
        return
    end

    msg(('Unknown command "%s"'):format(cmd))
end)
