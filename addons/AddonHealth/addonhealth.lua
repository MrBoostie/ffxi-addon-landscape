_addon.name = 'AddonHealth'
_addon.author = 'boostie'
_addon.version = '0.1.0'
_addon.commands = {'addonhealth', 'ahealth'}
_addon.description = 'In-game health dashboard for Windower addon stack status and diagnostics.'

local DATA_DIR = (windower.addon_path or '') .. 'data/'
local CHECKS_DIR = (windower.addon_path or '') .. 'checks/'

local state = {
    watching = false,
    watchInterval = 60,
    lastWatchTick = 0,
    lastReport = nil,
    suppressUntil = 0,
}

local function msg(text)
    windower.add_to_chat(6, ('[AddonHealth] %s'):format(text))
end

local function warn(text)
    windower.add_to_chat(167, ('[AddonHealth] WARN: %s'):format(text))
end

local function normalize(s)
    return (s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function join(tbl, sep, start_idx)
    local s = {}
    for i = start_idx or 1, #tbl do s[#s+1] = tbl[i] end
    return table.concat(s, sep or ' ')
end

local function now()
    return os.time()
end

local function get_loaded_addons()
    local loaded = {}
    local addons_path = windower.windower_path .. 'addons/'
    local listing = windower.get_dir(addons_path)
    if not listing then return loaded end

    for _, name in ipairs(listing) do
        local init_path = addons_path .. name .. '/init.lua'
        local alt_path = addons_path .. name .. '/' .. name:lower() .. '.lua'
        local f1 = io.open(init_path, 'r')
        local f2 = io.open(alt_path, 'r')
        local has_file = false
        if f1 then f1:close(); has_file = true end
        if f2 then f2:close(); has_file = true end
        if has_file then
            loaded[#loaded+1] = { name = name, path = addons_path .. name }
        end
    end
    return loaded
end

local function check_loaded_list()
    local results = {}
    local addons = get_loaded_addons()
    results.addon_count = #addons
    results.addons = {}
    for _, a in ipairs(addons) do
        results.addons[#results.addons+1] = a.name
    end
    table.sort(results.addons)
    return results
end

local function check_duplicates()
    local results = { duplicates = {} }
    local seen = {}
    local addons = get_loaded_addons()
    for _, a in ipairs(addons) do
        local key = a.name:lower()
        if seen[key] then
            results.duplicates[#results.duplicates+1] = a.name
        end
        seen[key] = true
    end
    return results
end

local function check_data_dirs()
    local results = { missing_data = {}, writable_issues = {} }
    local addons = get_loaded_addons()
    for _, a in ipairs(addons) do
        local data_path = a.path .. '/data/'
        local dir = windower.get_dir(data_path)
        if not dir then
            results.missing_data[#results.missing_data+1] = a.name
        end
    end
    return results
end

local function check_known_conflicts()
    local conflicts = {
        {'GearSwap', 'GearSwap2'},
        {'DressUp', 'DressMe'},
        {'Shortcuts', 'ShortCommand'},
    }
    local results = { conflicts = {} }
    local addons = get_loaded_addons()
    local loaded_set = {}
    for _, a in ipairs(addons) do loaded_set[a.name:lower()] = true end

    for _, pair in ipairs(conflicts) do
        local a, b = pair[1]:lower(), pair[2]:lower()
        if loaded_set[a] and loaded_set[b] then
            results.conflicts[#results.conflicts+1] = ('%s + %s'):format(pair[1], pair[2])
        end
    end
    return results
end

local function check_player_state()
    local results = {}
    local player = windower.ffxi.get_player()
    if not player then
        results.player_available = false
        return results
    end
    results.player_available = true
    results.name = player.name
    results.main_job = player.main_job or '?'
    results.main_job_level = player.main_job_level or 0
    results.sub_job = player.sub_job or '?'

    local info = windower.ffxi.get_info() or {}
    results.zone = info.zone or 0
    results.logged_in = info.logged_in or false

    local party = windower.ffxi.get_party() or {}
    local count = 0
    for i = 0, 5 do
        local m = party['p' .. i]
        if m and m.mob and m.mob.name then count = count + 1 end
    end
    results.party_size = count
    return results
end

local function run_all_checks()
    local report = {
        ts = now(),
        loaded = check_loaded_list(),
        duplicates = check_duplicates(),
        data_dirs = check_data_dirs(),
        conflicts = check_known_conflicts(),
        player = check_player_state(),
    }
    state.lastReport = report
    return report
end

local function format_report(report)
    local lines = {}
    lines[#lines+1] = ('--- AddonHealth Report (%s) ---'):format(os.date('%Y-%m-%d %H:%M:%S', report.ts))

    if report.player and report.player.player_available then
        local p = report.player
        lines[#lines+1] = ('Player: %s (%s%d/%s%d) Zone:%d Party:%d'):format(
            p.name or '?', p.main_job or '?', p.main_job_level or 0,
            p.sub_job or '?', 0, p.zone or 0, p.party_size or 0)
    else
        lines[#lines+1] = 'Player: not available (not logged in?)'
    end

    local loaded = report.loaded or {}
    lines[#lines+1] = ('Addons detected: %d'):format(loaded.addon_count or 0)

    local dups = report.duplicates or {}
    if #(dups.duplicates or {}) > 0 then
        lines[#lines+1] = ('WARN: Duplicate addons: %s'):format(table.concat(dups.duplicates, ', '))
    end

    local conflicts = report.conflicts or {}
    if #(conflicts.conflicts or {}) > 0 then
        lines[#lines+1] = ('WARN: Known conflicts: %s'):format(table.concat(conflicts.conflicts, ', '))
    end

    local data = report.data_dirs or {}
    if #(data.missing_data or {}) > 0 then
        lines[#lines+1] = ('Note: Addons without data/ dir: %s'):format(table.concat(data.missing_data, ', '))
    end

    lines[#lines+1] = '--- End Report ---'
    return lines
end

local function print_report(report)
    local lines = format_report(report)
    for _, line in ipairs(lines) do msg(line) end
end

local function print_addon_list(report)
    local loaded = report.loaded or {}
    local addons = loaded.addons or {}
    msg(('Detected addons (%d):'):format(#addons))
    for i, name in ipairs(addons) do
        msg(('  %d) %s'):format(i, name))
    end
end

local function export_report(report)
    local lines = format_report(report)
    local filename = DATA_DIR .. ('addonhealth-report-%s.txt'):format(os.date('%Y%m%d-%H%M%S', report.ts))
    local f = io.open(filename, 'w')
    if not f then
        msg('Failed to write report file.')
        return
    end
    for _, line in ipairs(lines) do f:write(line, '\n') end

    local loaded = report.loaded or {}
    f:write('\nAddon list:\n')
    for _, name in ipairs(loaded.addons or {}) do f:write('  - ', name, '\n') end
    f:close()
    msg(('Report exported to %s'):format(filename))
end

local function watch_tick()
    if not state.watching then return end
    local t = os.clock()
    if t - state.lastWatchTick < state.watchInterval then return end
    state.lastWatchTick = t

    local report = run_all_checks()
    local dups = report.duplicates or {}
    local conflicts = report.conflicts or {}
    local issues = #(dups.duplicates or {}) + #(conflicts.conflicts or {})

    if issues > 0 and now() > state.suppressUntil then
        warn(('%d issue(s) detected. Run //addonhealth check for details.'):format(issues))
    end
end

windower.register_event('prerender', watch_tick)

windower.register_event('addon command', function(...)
    local args = {...}
    local cmd = normalize(args[1])

    if cmd == '' or cmd == 'help' then
        msg('Commands: check | list | watch on|off [interval] | export | status')
        return
    end

    if cmd == 'check' then
        local report = run_all_checks()
        print_report(report)
        return
    end

    if cmd == 'list' then
        local report = state.lastReport or run_all_checks()
        print_addon_list(report)
        return
    end

    if cmd == 'watch' then
        local flag = normalize(args[2])
        if flag == 'on' then
            state.watching = true
            local interval = tonumber(args[3])
            if interval and interval >= 10 then state.watchInterval = interval end
            msg(('Watch enabled (interval %ds)'):format(state.watchInterval))
        elseif flag == 'off' then
            state.watching = false
            msg('Watch disabled.')
        else
            msg('Usage: //addonhealth watch on|off [interval_sec]')
        end
        return
    end

    if cmd == 'export' then
        local report = state.lastReport or run_all_checks()
        export_report(report)
        return
    end

    if cmd == 'status' then
        msg(('watch=%s interval=%ds lastReport=%s'):format(
            tostring(state.watching),
            state.watchInterval,
            state.lastReport and os.date('%H:%M:%S', state.lastReport.ts) or 'none'))
        return
    end

    if cmd == 'suppress' then
        local sec = tonumber(args[2] or 300) or 300
        state.suppressUntil = now() + sec
        msg(('Suppressing alerts for %ds'):format(sec))
        return
    end

    msg(('Unknown command "%s". Try //addonhealth help'):format(cmd))
end)

msg('AddonHealth v0.1.0 loaded. Use //addonhealth check to run diagnostics.')
